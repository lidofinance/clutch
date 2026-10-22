// SPDX-License-Identifier: AGPL-3.0-or-later
import { afterEach, beforeEach, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { getAddress } from "ethers";
import { processPermissions } from "zodiac-roles-sdk";
import { capturePayload, createNodes } from "./constellation";
import { resolvedDifferences, run, sepoliaRefusals, type Deps, type Git } from "./publish-constellation";
import { key } from "../constellation/lib";
import network from "./network.json";
import { captureMigration, migrationCalls, migrationManifest, migrationTransactions, MIGRATION_BATCH_EXECUTOR, normalizedMigrationPayload, payloadHash } from "./role-migration";

const workspace = "11111111-1111-4111-8111-111111111111";
const names = ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrackExecutor", "agent", "usdQueue", "ethQueue", "usdShare", "ethShare", "voting"];
const manifest: Record<string, any> = { network: "sepolia", chainId: 11155111, dependencies: network };
names.forEach((name, i) => manifest[name] = getAddress("0x" + (i + 256).toString(16).padStart(40, "0")));
manifest.modules = [manifest.operatorModifier, manifest.safetyModifier];
const allowances = [
  { modifier: manifest.operatorModifier, key: key("orders_weth"), balance: "400000000000000000", timestamp: "1792507104" },
  { modifier: manifest.operatorModifier, key: key("orders_usdc"), balance: "1000000000", timestamp: "1792507128" },
];
const apiKey = "test-key-not-a-secret";
const env = { CLUTCH_SEPOLIA_PUSH: "1", SEPOLIA_ZODIAC_API_KEY: apiKey, SEPOLIA_ZODIAC_WORKSPACE: workspace };
const git: Git = { branch: "testnet/sepolia", dirty: false, pushed: true, commit: "0".repeat(40) };
const payload = (await capturePayload(createNodes(manifest, workspace, allowances))).payload;
const lower = (value: string) => value.toLowerCase();

/** The shape that the hosted resolver returned on 2026-10-20: chain reads added, keys as bytes32, roles as targets. */
function resolvedFrom(source: any) {
  const addresses = Object.fromEntries(source.specification.map((n: any) => [n.ref, n.address]));
  const ref = (value: string) => value.startsWith("$") ? addresses[value.slice(1)] : value;
  const safeModules: Record<string, string[]> = {
    asset_safe: [manifest.safetyModifier, manifest.operatorModifier], orders_safe: [manifest.ordersModifier], first_loss_safe: [manifest.firstLossModifier],
  };
  return structuredClone(source.specification).map(({ vault: _vault, ...n }: any) => n.type === "SAFE"
    ? { ...n, prefixedAddress: `sep:${n.address}`, threshold: 1, owners: [lower(manifest.voting)], modules: safeModules[n.ref].map(lower) }
    : {
      ...n, prefixedAddress: `sep:${n.address}`, owner: ref(n.owner), avatar: ref(n.avatar), target: ref(n.target), modules: [], version: 2,
      allowances: Object.entries(n.allowances).map(([name, a]: [string, any]) => ({ ...a, key: key(name) })),
      roles: Object.entries(n.roles).map(([name, r]: [string, any]) => ({
        key: key(name), members: r.members, annotations: [], targets: r.targets ?? processPermissions(r.permissions).targets,
      })),
    });
}

const governance = (nodes: any[]) => nodes.find((n) => n.ref === "operator_modifier").roles.find((r: any) => r.key === key("governance"));
const norOf = (role: any) => role.targets[0].functions.map((f: any) => f.condition?.children?.[1]).find((c: any) => c?.operator === 3);

test("the Sepolia guard refuses each missing condition of ADR 013", () => {
  expect(sepoliaRefusals(env, git, workspace)).toEqual([]);
  const cases: [Record<string, string | undefined>, Partial<Git>, string][] = [
    [{ CLUTCH_SEPOLIA_PUSH: undefined }, {}, "CLUTCH_SEPOLIA_PUSH=1"],
    [{ CI: "true" }, {}, "CI never"],
    [{}, { branch: "main" }, "check out testnet/sepolia"],
    [{}, { dirty: true }, "local changes"],
    [{}, { pushed: false }, "push the commit"],
    [{ SEPOLIA_ZODIAC_API_KEY: undefined }, {}, "SEPOLIA_ZODIAC_API_KEY"],
    [{ SEPOLIA_ZODIAC_WORKSPACE: "22222222-2222-4222-8222-222222222222" }, {}, "SEPOLIA_ZODIAC_WORKSPACE"],
    [{ SEPOLIA_ZODIAC_API_URL: "http://app.zodiac.eco/api/v1" }, {}, "https"],
  ];
  for (const [envChange, gitChange, reason] of cases) {
    const refusals = sepoliaRefusals({ ...env, ...envChange }, { ...git, ...gitChange }, workspace);
    expect(refusals).toHaveLength(1);
    expect(refusals[0]).toContain(reason);
  }
});

test("a resolution that equals the payload and the stand has no differences", () => {
  expect(resolvedDifferences(resolvedFrom(payload), payload, manifest, allowances)).toEqual([]);
});

test("on-chain resolution need not echo the off-chain workspace vault flag", () => {
  const nodes = resolvedFrom(payload);
  expect(payload.specification.filter((n: any) => n.type === "SAFE").every((n: any) => n.vault === true)).toBe(true);
  expect(nodes.filter((n: any) => n.type === "SAFE").every((n: any) => !("vault" in n))).toBe(true);
  expect(resolvedDifferences(nodes, payload, manifest, allowances)).toEqual([]);
});

test("a resolution that lists roles in another order, as on 2026-10-20, has no differences", () => {
  const nodes = resolvedFrom(payload);
  for (const node of nodes) if (node.roles) node.roles.reverse();
  expect(resolvedDifferences(nodes, payload, manifest, allowances)).toEqual([]);
});

test("the resolution check refuses rewritten conditions, members, accounts, Safes and annotations", () => {
  const mutate = (change: (nodes: any[]) => void) => { const nodes = resolvedFrom(payload); change(nodes); return resolvedDifferences(nodes, payload, manifest, allowances); };
  // Nor (3) rewritten to And (1), as the earlier draft rewrote it.
  expect(mutate((nodes) => { norOf(governance(nodes)).operator = 1; })).toEqual([expect.stringContaining("(OD-38)")]);
  expect(mutate((nodes) => { norOf(governance(nodes)).children.pop(); })).toEqual([expect.stringMatching(/\(OD-38\)|other policy calls/)]);
  expect(mutate((nodes) => { governance(nodes).members = [lower(manifest.agent)]; })).toEqual(["the resolution compiles to other policy calls"]);
  expect(mutate((nodes) => { governance(nodes).annotations = [{ uri: "https://example.invalid", schema: "https://example.invalid" }]; })).toEqual([expect.stringContaining("annotations")]);
  expect(mutate((nodes) => { nodes.find((n) => n.ref === "operator_modifier").allowances[0].balance = "1"; })).toEqual(["the resolution compiles to other policy calls"]);
  expect(mutate((nodes) => { nodes.find((n) => n.ref === "orders_modifier").multisend = [lower(manifest.agent)]; })).toEqual(["orders_modifier: unexpected transaction unwrappers"]);
  expect(mutate((nodes) => { nodes.push({ ...nodes[0], ref: "extra_safe" }); })).toEqual(["extra_safe: added by the resolution"]);
  expect(mutate((nodes) => { nodes.find((n) => n.ref === "orders_safe").address = lower(manifest.agent); })).toEqual(["orders_safe: type, chain or address differs"]);
  expect(mutate((nodes) => { nodes.find((n) => n.ref === "asset_safe").owners = [lower(manifest.agent)]; })).toEqual(["asset_safe: owners, threshold or modules differ from the stand"]);
  expect(resolvedDifferences({ error: "x" }, payload, manifest, allowances)).toEqual(["the resolution has no node list"]);
});

let dir = "";
let calls: { url: string; init: any }[] = [];
beforeEach(() => {
  dir = mkdtempSync(path.join(tmpdir(), "clutch-publish-"));
  calls = [];
  writeFileSync(path.join(dir, "payload.json"), JSON.stringify(payload, null, 2) + "\n");
  writeFileSync(path.join(dir, "context.json"), JSON.stringify({ workspace, manifest }) + "\n");
  writeFileSync(path.join(dir, "manifest.json"), JSON.stringify(manifest));
});
afterEach(() => rmSync(dir, { recursive: true, force: true }));

type Reply = Response | (() => Promise<Response>);
let tick = 0;
function deps(replies: Record<string, Reply>, change: Partial<Deps> = {}): Deps {
  return {
    env, git: () => git, input: dir, output: path.join(dir, "hosted"), manifestFile: path.join(dir, "manifest.json"),
    snapshot: async () => ({ block: 11969893, blockHash: "0x" + "ab".repeat(32), allowances }),
    now: () => new Date(Date.UTC(2026, 9, 22, 16, 0, 0, tick++)),
    fetch: (async (url: string, init: any) => {
      calls.push({ url, init });
      const reply = replies[url.split("/").pop()!];
      return typeof reply === "function" ? reply() : reply.clone();
    }) as unknown as typeof fetch,
    ...change,
  };
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
// ApplyConstellationResult requires id and url.
const published = { id: "33333333-3333-4333-8333-333333333333", url: "https://app.zodiac.eco/workspace/x" };
const records = () => readdirSync(path.join(dir, "hosted")).sort();
const saved = (prefix: string) => JSON.parse(readFileSync(path.join(dir, "hosted", records().find((f) => f.startsWith(prefix))!), "utf8"));

test("the publication CLI stops conflicting policies before credentials, RPC or a hosted call", () => {
  const entry = path.join(dir, "policy/constellation/sepolia/publish-constellation.ts");
  mkdirSync(path.dirname(entry), { recursive: true });
  symlinkSync(path.resolve(import.meta.dir, "../node_modules"), path.join(dir, "policy/constellation/node_modules"), "dir");
  const source = readFileSync(path.join(import.meta.dir, "publish-constellation.ts"), "utf8")
    .replace(/from "(\.[^\"]+)"/g, (_, module: string) => `from ${JSON.stringify(path.resolve(import.meta.dir, module))}`);
  writeFileSync(entry, source);
  const output = path.join(dir, "cache/sepolia/constellation");
  mkdirSync(output, { recursive: true });
  writeFileSync(path.join(output, "payload.json"), JSON.stringify(payload));
  const preload = path.join(dir, "offline.ts");
  writeFileSync(preload, 'globalThis.fetch = async () => { throw new Error("Network forbidden"); };');
  const result = Bun.spawnSync([process.execPath, "--no-env-file", "--preload", preload, entry, "apply"], { env: {}, stdout: "pipe", stderr: "pipe" });
  expect(result.exitCode).toBe(1);
  expect(result.stderr.toString()).toContain("Workspace policies cannot be published");
  expect(result.stderr.toString()).toContain("operator: policy grants differ");
  expect(result.stderr.toString()).toContain("emergency: policy grants differ");
  expect(result.stderr.toString()).not.toContain("Network forbidden");
  expect(existsSync(path.join(output, "hosted"))).toBe(false);
});

test("resolve sends the exact payload to the SDK endpoint and saves the response without the key", async () => {
  expect(await run("resolve", deps({ resolve: json({ result: resolvedFrom(payload) }) }))).toBe(0);
  expect(calls).toHaveLength(1);
  expect(calls[0].url).toBe(`https://app.zodiac.eco/api/v1/workspace/${workspace}/constellation/resolve`);
  expect(calls[0].init.method).toBe("POST");
  expect(calls[0].init.headers.authorization).toBe(`Bearer ${apiKey}`);
  const sha = createHash("sha256").update(readFileSync(path.join(dir, "payload.json"))).digest("hex");
  expect(createHash("sha256").update(calls[0].init.body).digest("hex")).toBe(sha);
  const record = saved("resolve-");
  expect(record).toMatchObject({ workspace, payloadSha256: sha, status: 200, block: 11969893, origin: "https://app.zodiac.eco" });
  expect(JSON.stringify(record)).not.toContain(apiKey);
});

test("apply runs only after a matching resolution, once per payload", async () => {
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: json(published) };
  expect(await run("apply", deps(replies))).toBe(0);
  expect(calls.map((c) => c.url.split("/").pop())).toEqual(["resolve", "apply"]);
  expect(records().some((f) => f.startsWith("apply-attempt-"))).toBe(true);
  expect(saved("apply-2")).toMatchObject({ status: 200 });
  await expect(run("apply", deps(replies))).rejects.toThrow("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(1);
});

test("migration publication checks the legacy source and resolves the declared new roles and deletions", async () => {
  const migrationPayload = (await captureMigration(manifest, workspace, allowances)).payload;
  const pkg = {
    format: "clutch.sepolia-role-migration/1", workspace, block: 11969893, blockHash: "0x" + "ab".repeat(32),
    batchExecutor: MIGRATION_BATCH_EXECUTOR, sourceManifest: manifest, manifest: migrationManifest(manifest), allowances,
    calls: migrationCalls(manifest), transactions: migrationTransactions(manifest),
    payload: migrationPayload, payloadSha256: payloadHash(migrationPayload),
  };
  writeFileSync(path.join(dir, "payload.json"), JSON.stringify(migrationPayload, null, 2) + "\n");
  writeFileSync(path.join(dir, "context.json"), JSON.stringify({ workspace, manifest, migration: true, payloadSha256: pkg.payloadSha256 }));
  writeFileSync(path.join(dir, "package.json"), JSON.stringify(pkg));
  const resolved = resolvedFrom(normalizedMigrationPayload(migrationPayload, manifest, allowances));
  let checkedSource = false;
  const dependencies = deps({ resolve: json({ result: resolved }), apply: json(published) }, {
    snapshot: async (source, migration) => {
      expect(source).toEqual(manifest);
      expect(migration.payloadSha256).toBe(pkg.payloadSha256);
      checkedSource = true;
      return { block: 11969893, blockHash: pkg.blockHash, allowances };
    },
  });
  expect(await run("apply", dependencies)).toBe(0);
  expect(checkedSource).toBe(true);
  expect(JSON.parse(calls[1].init.body)).toEqual(migrationPayload);
  expect(calls.map((c) => c.url.split("/").pop())).toEqual(["resolve", "apply"]);
  const corrupted = structuredClone(resolved);
  const role = corrupted.find((n: any) => n.ref === "operator_modifier").roles.find((r: any) => r.key === key("asset-operator"));
  role.key = key("operator");
  calls = [];
  expect(await run("resolve", deps({ resolve: json({ result: corrupted }) }))).toBe(1);
  expect(calls).toHaveLength(1);
  const context = JSON.parse(readFileSync(path.join(dir, "context.json"), "utf8"));
  context.payloadSha256 = "00".repeat(32);
  writeFileSync(path.join(dir, "context.json"), JSON.stringify(context));
  calls = [];
  await expect(run("apply", dependencies)).rejects.toThrow("context or payload differs");
  expect(calls).toHaveLength(0);
});

test("two concurrent applies send one apply", async () => {
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: json(published) };
  const results = await Promise.allSettled([run("apply", deps(replies)), run("apply", deps(replies))]);
  const rejected = results.filter((r): r is PromiseRejectedResult => r.status === "rejected");
  expect(rejected).toHaveLength(1);
  expect(rejected[0].reason.message).toContain("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(1);
});

test("a differing resolution or a failed resolve sends no apply", async () => {
  const rewritten = resolvedFrom(payload);
  norOf(governance(rewritten)).operator = 1;
  expect(await run("apply", deps({ resolve: json({ result: rewritten }) }))).toBe(1);
  expect(await run("apply", deps({ resolve: json({ error: { message: "The constellation is not valid" } }, 400) }))).toBe(1);
  expect(await run("apply", deps({ resolve: new Response("<html>Bad gateway</html>", { status: 502 }) }))).toBe(1);
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(0);
  const statuses = records().filter((f) => f.startsWith("resolve-")).map((f) => JSON.parse(readFileSync(path.join(dir, "hosted", f), "utf8")).status);
  expect(statuses.sort()).toEqual([200, 400, 502]);
  expect(records().some((f) => f.startsWith("apply-attempt-"))).toBe(false);
});

test("an apply that fails or times out keeps its attempt and blocks a retry", async () => {
  const timeout = async () => { throw new DOMException("The operation timed out.", "TimeoutError"); };
  expect(await run("apply", deps({ resolve: json({ result: resolvedFrom(payload) }), apply: timeout }))).toBe(1);
  expect(saved("apply-2")).toMatchObject({ error: "TimeoutError" });
  expect(records().some((f) => f.startsWith("apply-attempt-"))).toBe(true);
  await expect(run("apply", deps({ resolve: json({ result: resolvedFrom(payload) }), apply: json(published) }))).rejects.toThrow("already sent");
});

test.each([
  ["empty body", new Response("", { status: 200 })],
  ["HTML", new Response("<html>Bad gateway</html>", { status: 200 })],
  ["null", json(null)],
  ["missing id", json({ url: published.url })],
  ["missing url", json({ id: published.id })],
  ["empty id", json({ ...published, id: " " })],
  ["empty url", json({ ...published, url: " " })],
  ["wrong field type", json({ ...published, id: 123 })],
] as const)("an unconfirmed HTTP 200 apply fails and blocks retries: %s", async (_, response) => {
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: response };
  expect(await run("apply", deps(replies))).toBe(1);
  expect(saved("apply-2")).toMatchObject({ status: 200, body: await response.clone().text() });
  await expect(run("apply", deps(replies))).rejects.toThrow("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(1);
});

test("a timeout while reading an HTTP 200 apply body fails and keeps its attempt", async () => {
  const response = json(published);
  Object.defineProperty(response, "text", { value: async () => { throw new DOMException("The body timed out.", "TimeoutError"); } });
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: async () => response };
  expect(await run("apply", deps(replies))).toBe(1);
  expect(saved("apply-2")).toMatchObject({ status: 200, error: "TimeoutError" });
  await expect(run("apply", deps(replies))).rejects.toThrow("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(1);
});

test("the same payload can be published once in each workspace", async () => {
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: json(published) };
  expect(await run("apply", deps(replies))).toBe(0);
  const otherWorkspace = "22222222-2222-4222-8222-222222222222";
  writeFileSync(path.join(dir, "context.json"), JSON.stringify({ workspace: otherWorkspace, manifest }));
  const change = { env: { ...env, SEPOLIA_ZODIAC_WORKSPACE: otherWorkspace } };
  expect(await run("apply", deps(replies, change))).toBe(0);
  await expect(run("apply", deps(replies, change))).rejects.toThrow("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(2);
});

test.each(["https://staging.example.invalid/api/v1", "https://app.zodiac.eco/staging/api/v1"])("the same payload can be published once per API URL: %s", async (api) => {
  const replies = { resolve: json({ result: resolvedFrom(payload) }), apply: json(published) };
  expect(await run("apply", deps(replies))).toBe(0);
  expect(await run("apply", deps(replies, { env: { ...env, SEPOLIA_ZODIAC_API_URL: api } }))).toBe(0);
  await expect(run("apply", deps(replies, { env: { ...env, SEPOLIA_ZODIAC_API_URL: api + "/" } }))).rejects.toThrow("already sent");
  expect(calls.filter((c) => c.url.endsWith("/apply"))).toHaveLength(2);
});

test("an apply with a body that is not JSON keeps the status and the text", async () => {
  expect(await run("apply", deps({ resolve: json({ result: resolvedFrom(payload) }), apply: new Response("", { status: 500 }) }))).toBe(1);
  expect(saved("apply-2")).toMatchObject({ status: 500, body: "" });
});

test("refusals, a stale payload and another manifest stop before any request", async () => {
  await expect(run("apply", deps({}, { env: { ...env, CI: "true" } }))).rejects.toThrow("Refused (ADR 013)");
  const stale = allowances.map((a, i) => i ? a : { ...a, balance: "1" });
  await expect(run("apply", deps({}, { snapshot: async () => ({ block: 1, blockHash: "0x00", allowances: stale }) }))).rejects.toThrow("differs");
  writeFileSync(path.join(dir, "manifest.json"), JSON.stringify({ ...manifest, voting: manifest.agent }));
  await expect(run("apply", deps({}))).rejects.toThrow("another manifest");
  await expect(run("deploy", deps({}))).rejects.toThrow("usage");
  expect(calls).toHaveLength(0);
  expect(existsSync(path.join(dir, "hosted"))).toBe(false);
});
