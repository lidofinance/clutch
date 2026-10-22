// SPDX-License-Identifier: AGPL-3.0-or-later
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { reconstructPermissions } from "zodiac-roles-sdk";
import { compile } from "../compiler/compile";
import { build } from "./compile";
import { checkPayload, workspacePolicyIssues, type RuntimeAllowance } from "./constellation";
import { diffPolicy } from "./diff";
import { readOnlyRpc } from "./prepare-constellation";
import { checkBefore } from "./prepare-migration";
import { checkMigrationPackage, checkMigrationPayload, migrationManifest, normalizedMigrationPayload } from "./role-migration";

const ROOT = path.resolve(import.meta.dir, "../../..");
const BRANCH = "testnet/sepolia";
const DEFAULT_API = "https://app.zodiac.eco/api/v1";

export type Git = { branch: string; dirty: boolean; pushed: boolean; commit: string };
export type Snapshot = { block: number; blockHash: string; allowances: RuntimeAllowance[] };
export type Deps = {
  env: Record<string, string | undefined>;
  git: () => Git;
  snapshot: (manifest: Record<string, any>, migration?: any) => Promise<Snapshot>;
  fetch: typeof fetch;
  input: string;
  output: string;
  manifestFile: string;
  now: () => Date;
};

/** ADR 013: a human publishes to the Sepolia workspace from a pushed, clean testnet/sepolia. */
export function sepoliaRefusals(env: Record<string, string | undefined>, git: Git, workspace: string): string[] {
  const reasons: string[] = [];
  if (env.CLUTCH_SEPOLIA_PUSH !== "1") reasons.push("set CLUTCH_SEPOLIA_PUSH=1 to confirm a human publication to the Sepolia workspace");
  if (env.CI) reasons.push("CI never calls the hosted app");
  if (git.branch !== BRANCH) reasons.push(`check out ${BRANCH}, not ${git.branch || "a detached HEAD"}`);
  if (git.dirty) reasons.push("commit or remove the local changes first");
  if (!git.pushed) reasons.push(`push the commit to origin/${BRANCH} first`);
  if (!env.SEPOLIA_ZODIAC_API_KEY) reasons.push("set SEPOLIA_ZODIAC_API_KEY to the key for the Sepolia workspace");
  if (env.SEPOLIA_ZODIAC_WORKSPACE !== workspace) reasons.push("set SEPOLIA_ZODIAC_WORKSPACE to the workspace of the prepared payload");
  if (!(env.SEPOLIA_ZODIAC_API_URL ?? DEFAULT_API).startsWith("https://")) reasons.push("SEPOLIA_ZODIAC_API_URL must use https");
  return reasons;
}

const lower = (value: unknown) => String(value).toLowerCase();
const sameSet = (actual: unknown, expected: string[]) =>
  Array.isArray(actual) && JSON.stringify(actual.map(lower).sort()) === JSON.stringify(expected.map(lower).sort());
const label = (key: string) => Buffer.from(key.slice(2), "hex").toString("utf8").replace(/\0+$/, "");

/** Differences between the hosted resolution and the prepared payload; empty when they agree. */
export function resolvedDifferences(result: unknown, payload: any, manifest: Record<string, any>, allowances?: RuntimeAllowance[]): string[] {
  if (!Array.isArray(result)) return ["the resolution has no node list"];
  const expected = new Map<string, any>(payload.specification.map((node: any) => [node.ref, node]));
  const resolved = new Map<string, any>(result.map((node: any) => [node?.ref, node]));
  const differences: string[] = [];
  for (const ref of new Set([...expected.keys(), ...resolved.keys()])) {
    const want = expected.get(ref), got = resolved.get(ref);
    if (!want || !got) differences.push(`${ref}: ${want ? "missing from" : "added by"} the resolution`);
    else if (got.type !== want.type || got.chain !== want.chain || lower(got.address) !== lower(want.address)) differences.push(`${ref}: type, chain or address differs`);
  }
  if (differences.length) return differences;
  // The resolver reads each Safe from the chain; the policy comparison does not cover owners or modules.
  const modules: Record<string, string[]> = {
    asset_safe: [manifest.operatorModifier, manifest.safetyModifier], orders_safe: [manifest.ordersModifier], first_loss_safe: [manifest.firstLossModifier],
  };
  for (const [ref, want] of Object.entries(modules)) {
    const safe = resolved.get(ref);
    if (safe.threshold !== 1 || !sameSet(safe.owners, [manifest.voting]) || !sameSet(safe.modules, want)) differences.push(`${ref}: owners, threshold or modules differ from the stand`);
  }
  const nodes: Record<string, any> = {};
  for (const node of result.filter((n: any) => n.type === "ROLES")) {
    if (JSON.stringify(node.multisend) !== "[]") differences.push(`${node.ref}: unexpected transaction unwrappers`);
    const roles = Object.fromEntries((node.roles ?? []).map((r: any) => {
      if (!Array.isArray(r.targets) || JSON.stringify(r.annotations) !== "[]") differences.push(`${node.ref}.${label(r.key)}: expected targets with empty annotations`);
      return [label(r.key), { members: r.members, permissions: reconstructPermissions(r.targets ?? []) }];
    }));
    const nodeAllowances = Object.fromEntries((node.allowances ?? []).map((a: any) => [label(a.key), { ...a, key: label(a.key) }]));
    nodes[node.ref] = { ...node, roles, allowances: nodeAllowances };
  }
  if (differences.length) return differences;
  // The resolver may list roles and targets in another order; the calls and the wiring must be the same.
  const calls = (artifact: ReturnType<typeof compile>) => artifact.calls.to.map((to, i) => `${lower(to)}:${artifact.calls.data[i]}`).sort();
  const wiring = (artifact: ReturnType<typeof compile>) => artifact.modifiers.map(({ ref, address, owner, avatar, target }) => [ref, address, owner, avatar, target].map(lower).join(":")).sort();
  try {
    const expected = checkPayload(payload, manifest, allowances);
    const candidate = compile(nodes, manifest, {});
    if (JSON.stringify(calls(candidate)) !== JSON.stringify(calls(expected))) differences.push("the resolution compiles to other policy calls");
    if (JSON.stringify(wiring(candidate)) !== JSON.stringify(wiring(expected))) differences.push("the resolution wires the modifiers differently");
  } catch (error) {
    differences.push(error instanceof Error ? error.message : "the resolution differs from the Sepolia policy");
  }
  return differences;
}

export async function run(command: string, deps: Deps): Promise<number> {
  if (command !== "resolve" && command !== "apply") throw new Error("usage: publish-constellation.ts resolve | apply");
  const raw = readFileSync(path.join(deps.input, "payload.json"));
  const context = JSON.parse(readFileSync(path.join(deps.input, "context.json"), "utf8"));
  const git = deps.git();
  const reasons = sepoliaRefusals(deps.env, git, context.workspace);
  if (reasons.length) throw new Error(`Refused (ADR 013): ${reasons.join("; ")}.`);
  const manifest = JSON.parse(readFileSync(deps.manifestFile, "utf8"));
  if (JSON.stringify(manifest) !== JSON.stringify(context.manifest)) throw new Error("The prepared context uses another manifest; run constellation <workspace UUID> again");
  const payload = JSON.parse(raw.toString());
  const sha = createHash("sha256").update(raw).digest("hex");
  // A fresh comparison: the chain still matches the policy, and the payload still carries the current allowances.
  const migration = context.migration === true ? JSON.parse(readFileSync(path.join(deps.input, "package.json"), "utf8")) : undefined;
  if (migration) {
    checkMigrationPackage(migration);
    if (migration.workspace !== context.workspace || sha !== migration.payloadSha256 || sha !== context.payloadSha256 || JSON.stringify(migration.sourceManifest) !== JSON.stringify(manifest)) throw new Error("The migration context or payload differs from its package");
  }
  const state = await deps.snapshot(manifest, migration);
  if (migration) checkMigrationPayload(payload, manifest, state.allowances);
  else checkPayload(payload, manifest, state.allowances);
  const api = (deps.env.SEPOLIA_ZODIAC_API_URL ?? DEFAULT_API).replace(/\/$/, "");
  const base = { workspace: context.workspace, origin: new URL(api).origin, commit: git.commit, payloadSha256: sha, block: state.block, blockHash: state.blockHash };
  mkdirSync(deps.output, { recursive: true });

  async function call(endpoint: "resolve" | "apply") {
    const startedAt = deps.now().toISOString();
    const record: Record<string, any> = { ...base, endpoint, startedAt };
    try {
      const response = await deps.fetch(`${api}/workspace/${context.workspace}/constellation/${endpoint}`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${deps.env.SEPOLIA_ZODIAC_API_KEY}` },
        body: raw.toString(), signal: AbortSignal.timeout(60_000),
      });
      record.status = response.status;
      record.body = await response.text();
    } catch (error) {
      // The error name only: a message can carry request details.
      record.error = error instanceof Error ? error.name : "unknown";
    }
    record.finishedAt = deps.now().toISOString();
    const file = `${endpoint}-${startedAt.replace(/[:.]/g, "")}-${sha.slice(0, 12)}.json`;
    writeFileSync(path.join(deps.output, file), JSON.stringify(record, null, 2) + "\n", { flag: "wx" });
    let json: any;
    try { json = JSON.parse(record.body); } catch { json = undefined; }
    const ok = !record.error && typeof record.status === "number" && record.status >= 200 && record.status < 300;
    const status = [record.status !== undefined ? `HTTP ${record.status}` : undefined, record.error].filter(Boolean).join("; ");
    console.log(`${endpoint}: ${status}; saved ${path.relative(ROOT, path.join(deps.output, file))}`);
    return { ok, json };
  }

  const resolved = await call("resolve");
  if (!resolved.ok) return 1;
  const differences = resolvedDifferences(resolved.json?.result,
    migration ? normalizedMigrationPayload(payload, manifest, state.allowances) : payload,
    migration ? migrationManifest(manifest) : manifest, state.allowances);
  for (const difference of differences) console.error(`Resolution difference: ${difference}`);
  if (differences.length) return 1;
  console.log(`The resolution matches the ${migration ? "proposed migration; its source state was checked" : "payload, Sepolia policy and chain"} at block ${state.block}.`);
  if (command === "resolve") return 0;
  const attemptKey = createHash("sha256").update(JSON.stringify([api, context.workspace, sha])).digest("hex");
  try {
    writeFileSync(path.join(deps.output, `apply-attempt-${attemptKey}.json`), JSON.stringify({ ...base, startedAt: deps.now().toISOString() }, null, 2) + "\n", { flag: "wx" });
  } catch {
    throw new Error("This payload was already sent to apply for this API and workspace; inspect the workspace before any retry");
  }
  const applied = await call("apply");
  if (!applied.ok) return 1;
  if (typeof applied.json?.id !== "string" || !applied.json.id.trim() || typeof applied.json?.url !== "string" || !applied.json.url.trim()) {
    console.error("apply returned an invalid publication result; inspect the workspace before any retry");
    return 1;
  }
  console.log(applied.json.url);
  return 0;
}

function gitState(): Git {
  const git = (...args: string[]) => Bun.spawnSync(["git", ...args], { cwd: ROOT });
  return {
    branch: git("rev-parse", "--abbrev-ref", "HEAD").stdout.toString().trim(),
    dirty: git("status", "--porcelain").stdout.toString().trim() !== "",
    pushed: git("merge-base", "--is-ancestor", "HEAD", `origin/${BRANCH}`).exitCode === 0,
    commit: git("rev-parse", "HEAD").stdout.toString().trim(),
  };
}

async function snapshot(manifest: Record<string, any>, migration?: any): Promise<Snapshot> {
  const endpoint = process.env.SEPOLIA_RPC;
  if (!endpoint) throw new Error("Set SEPOLIA_RPC in the local environment");
  const report = migration ? await checkBefore(readOnlyRpc(endpoint), migration, manifest) : await diffPolicy(readOnlyRpc(endpoint), manifest, build(manifest));
  if (!report.matches) throw new Error(`${report.differences.length} policy differences at block ${report.block}; run constellation-diff`);
  return { block: report.block, blockHash: report.blockHash, allowances: report.allowances };
}

if (import.meta.main) {
  try {
    if (process.argv[3] !== undefined && process.argv[3] !== "--migration") throw new Error("Only --migration is supported after the command");
    const input = path.join(ROOT, process.argv[3] === "--migration" ? "cache/sepolia/role-key-migration" : "cache/sepolia/constellation");
    if (process.argv[2] === "apply") {
      const payload = JSON.parse(readFileSync(path.join(input, "payload.json"), "utf8"));
      const issues = workspacePolicyIssues(payload);
      if (issues.length) throw new Error(`Workspace policies cannot be published: ${issues.join("; ")}`);
    }
    process.exitCode = await run(process.argv[2] ?? "", {
      env: process.env, git: gitState, snapshot, fetch,
      input,
      output: path.join(input, "hosted"),
      manifestFile: process.env.SEPOLIA_MANIFEST ?? path.join(ROOT, "cache/sepolia/manifest.json"),
      now: () => new Date(),
    });
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Publication failed");
    process.exitCode = 1;
  }
}
