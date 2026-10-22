// SPDX-License-Identifier: AGPL-3.0-or-later
import { createHash } from "node:crypto";
import { concat, decodeBytes32String, getAddress, Interface, keccak256, toBeHex, ZeroAddress } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import { build, ROLE_MIGRATION } from "./compile";
import { capturePayload, checkPayload, createNodes, workspacePolicyIssues, type RuntimeAllowance } from "./constellation";

const ROLES = new Interface(rolesAbi);
const SAFE = new Interface([
  "function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)",
]);
const VOTING = new Interface(["function execute(address,uint256,bytes)"]);
const MULTISEND = new Interface(["function multiSend(bytes)"]);
export const MIGRATION_BATCH_EXECUTOR = {
  address: "0xA83c336B20401Af773B6219BA5027174338D1836",
  codeHash: "0xcdbdcec38d2f1c7d961b0029ff8416b7e86e9974d6f0e9c9580c7d17fcfb6663",
};
const same = (a: unknown, b: unknown) => JSON.stringify(a).toLowerCase() === JSON.stringify(b).toLowerCase();

export function migrationManifest(source: Record<string, any>) {
  if (source.roleKeyScheme !== undefined) throw new Error("Migration requires the original role-key profile");
  return { ...source, roleKeyScheme: "account" };
}

/** The old keys must be declared null: omission leaves their on-chain roles untouched. */
export async function captureMigration(source: Record<string, any>, workspace: string, runtime: RuntimeAllowance[]) {
  const nodes = createNodes(migrationManifest(source), workspace, runtime, true);
  const captured = await capturePayload(nodes);
  checkMigrationPayload(captured.payload, source, runtime);
  return captured;
}

/** Restore omitted allowances only for local comparison, never in the outgoing payload. */
export function normalizedMigrationPayload(payload: any, source: Record<string, any>, runtime: RuntimeAllowance[]) {
  const normalized = structuredClone(payload);
  if (normalized.specification?.length !== 7 || new Set(normalized.specification.map((n: any) => n.ref)).size !== 7 || normalized.specification.filter((n: any) => n.type === "SAFE").length !== 3) throw new Error("Migration requires exactly three Safes and four modifiers");
  const expected = build(migrationManifest(source));
  const cleared: string[] = [];
  for (const node of normalized.specification.filter((n: any) => n.type === "ROLES")) {
    if ("allowances" in node) throw new Error("Migration must omit allowance writes");
    for (const [name, role] of Object.entries(node.roles ?? {})) if (role === null) {
      if (!ROLE_MIGRATION.some(([ref, key]) => ref === node.ref && key === name)) throw new Error("Unexpected role deletion");
      cleared.push(`${node.ref}.${name}`);
      delete node.roles[name];
    }
    const modifier = expected.modifiers.find((m) => m.ref === node.ref);
    if (!modifier) throw new Error("Unexpected migration modifier");
    node.allowances = Object.fromEntries(modifier.allowances.map((a) => {
      const observed = runtime.find((r) => r.modifier.toLowerCase() === modifier.address.toLowerCase() && r.key.toLowerCase() === a.key.toLowerCase());
      if (!observed) throw new Error(`Missing allowance readback: ${a.name}`);
      return [a.name, { key: a.name, refill: a.refill, maxRefill: a.maxRefill, period: a.period, balance: observed.balance, timestamp: observed.timestamp }];
    }));
  }
  if (!same(cleared.sort(), ROLE_MIGRATION.map(([ref, old]) => `${ref}.${old}`).sort())) throw new Error("All four old role instances must be deleted");
  return normalized;
}

export function checkMigrationPayload(payload: any, source: Record<string, any>, runtime: RuntimeAllowance[]) {
  const target = migrationManifest(source);
  const normalized = normalizedMigrationPayload(payload, source, runtime);
  const artifact = checkPayload(normalized, target, runtime);
  const issues = workspacePolicyIssues(payload);
  if (issues.length) throw new Error(`Migration policy conflicts: ${issues.join("; ")}`);
  return artifact;
}

/** Two atomic account batches, through the existing Safe MultiSendCallOnly 1.5.0. */
export function migrationCalls(source: Record<string, any>) {
  const before = build(source);
  const after = build(migrationManifest(source));
  const calls: { to: string; avatar: string; data: string; fn: string }[] = [];
  const memberCalls: typeof calls = [];
  const isNew = (to: string, key: string) => ROLE_MIGRATION.some(([ref, , name]) =>
    after.modifiers.find((m) => m.ref === ref)?.address === to && after.modifiers.find((m) => m.ref === ref)?.roles.find((r) => r.name === name)?.key === key);
  const oldData = new Set(before.calls.data);
  after.calls.to.forEach((to, i) => {
    const data = after.calls.data[i];
    const parsed = ROLES.parseTransaction({ data })!;
    const call = { to, avatar: after.calls.avatar[i], data, fn: after.calls.fn[i] };
    if (parsed.name === "assignRoles") {
      if (isNew(to, parsed.args[1][0])) memberCalls.push(call);
    } else if (isNew(to, parsed.args[0]) || parsed.name === "scopeFunction" && !oldData.has(data)) calls.push(call);
  });
  // Emergency members become active before operator members, including within the atomic batch.
  calls.push(...memberCalls.filter((c) => decodeBytes32String(ROLES.parseTransaction({ data: c.data })!.args[1][0]).endsWith("-emergency")));
  calls.push(...memberCalls.filter((c) => !calls.includes(c)));
  const emit = (to: string, avatar: string, fn: string, args: unknown[]) => calls.push({ to, avatar, fn, data: ROLES.encodeFunctionData(fn, args) });
  for (const [ref, oldKey] of ROLE_MIGRATION) {
    const modifier = before.modifiers.find((m) => m.ref === ref)!;
    const role = modifier.roles.find((r) => r.name === oldKey)!;
    for (const member of role.members) emit(modifier.address, modifier.avatar, "assignRoles", [member.address, [role.key], [false]]);
    for (const target of role.targets) {
      for (const fn of target.functions) emit(modifier.address, modifier.avatar, "revokeFunction", [role.key, target.address, fn.selector]);
      emit(modifier.address, modifier.avatar, "revokeTarget", [role.key, target.address]);
    }
  }
  if (calls.some((c) => ROLES.parseTransaction({ data: c.data })!.name === "setAllowance")) throw new Error("Migration resets allowances");
  return calls;
}

export function migrationTransactions(source: Record<string, any>, calls = migrationCalls(source)) {
  const signature = concat([toBeHex(BigInt(source.voting), 32), toBeHex(0, 32), "0x01"]);
  return [source.assetSafe, source.ordersSafe].map((avatar) => {
    const inner = calls.filter((c) => c.avatar === avatar);
    const batch = concat(inner.map((c) => concat(["0x00", getAddress(c.to), toBeHex(0, 32), toBeHex((c.data.length - 2) / 2, 32), c.data])));
    const data = SAFE.encodeFunctionData("execTransaction", [MIGRATION_BATCH_EXECUTOR.address, 0, MULTISEND.encodeFunctionData("multiSend", [batch]), 1, 0, 0, 0, ZeroAddress, ZeroAddress, signature]);
    return { to: source.voting, value: "0", avatar, calls: inner.length,
      data: VOTING.encodeFunctionData("execute", [avatar, 0, data]), safeData: data, batch, batchHash: keccak256(batch) };
  });
}

export const payloadHash = (payload: unknown) => createHash("sha256").update(JSON.stringify(payload, null, 2) + "\n").digest("hex");

export function checkMigrationPackage(pkg: any) {
  if (pkg.format !== "clutch.sepolia-role-migration/1" || !Number.isSafeInteger(pkg.block) || !/^0x[0-9a-f]{64}$/i.test(pkg.blockHash)) throw new Error("Invalid migration package");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(pkg.workspace)) throw new Error("Migration workspace UUID required");
  if (!same(pkg.manifest, migrationManifest(pkg.sourceManifest))) throw new Error("Migration changes the stand manifest");
  const calls = migrationCalls(pkg.sourceManifest);
  if (!same(pkg.batchExecutor, MIGRATION_BATCH_EXECUTOR) || !same(pkg.calls, calls) || !same(pkg.transactions, migrationTransactions(pkg.sourceManifest, calls))) throw new Error("Migration transaction differs from the reviewed role mapping");
  checkMigrationPayload(pkg.payload, pkg.sourceManifest, pkg.allowances);
  if (pkg.payloadSha256 !== payloadHash(pkg.payload)) throw new Error("Migration payload hash differs");
}
