// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { id } from "ethers";
import { Clearance } from "zodiac-roles-sdk";
import { checkProtected, compileManifest, refuseHosted, render, unguarded } from "./compile";
import type { Artifact } from "./compile";

const ROOT = path.resolve(import.meta.dir, "..");
const MANIFEST = path.join(ROOT, "manifests/fork-25946643.json");
const ARTIFACT = path.join(ROOT, "artifacts/fork-25946643.json");
const APPROVE = "0x095ea7b3";
const EQUAL_TO = 16;
const LESS_THAN = 18;
const WITHIN_ALLOWANCE = 28;

const artifact = await compileManifest(MANIFEST);
const role = (name: string) => artifact.modifiers.flatMap((m) => m.roles).find((r) => r.name === name)!;
const approvals = (name: string) =>
  role(name).targets.flatMap((t) => t.functions.filter((f) => f.selector === APPROVE).map((f) => ({ token: t.address, f })));

test("refuses an entry that only the hosted app can compile", () => {
  const swap = { label: "swap", action: { type: "swap", sell: [], buy: [] } };
  const preset = { label: "preset", annotation: "https://example.org/permissions" };
  expect(() => refuseHosted("action", swap)).toThrow(/only the hosted app/);
  expect(() => refuseHosted("preset", preset)).toThrow(/only the hosted app/);
  expect(() => refuseHosted("ref", { targetAddress: "$asset_safe", selector: APPROVE })).toThrow(/node reference/);
});

test("the committed artifact equals a fresh compile", () => {
  expect(readFileSync(ARTIFACT, "utf8")).toBe(render(artifact));
});

test("a compile is deterministic", async () => {
  expect(render(await compileManifest(MANIFEST))).toBe(render(artifact));
});

test("every operator approval spends a budget key or stays below a ceiling", () => {
  // In every Matches branch of approve(spender, amount), the second child
  // bounds the amount. The SDK may merge spenders that share a bound into one
  // branch, which keeps this true.
  const MATCHES = 5;
  for (const { f } of approvals("operator")) {
    const branches = f.conditions.flatMap((n, i) => (n.operator === MATCHES ? [i] : []));
    expect(branches.length).toBeGreaterThan(0);
    for (const b of branches) {
      const children = f.conditions.filter((n, i) => i !== b && n.parent === b);
      expect(children.length).toBe(2);
      expect([WITHIN_ALLOWANCE, LESS_THAN]).toContain(children[1].operator);
    }
  }
});

test("the emergency role can zero every approval the operator can give", () => {
  const spendersOf = (name: string) =>
    new Set(
      approvals(name).flatMap(({ f }) =>
        f.conditions.filter((n) => n.operator === EQUAL_TO && n.compValue !== "0x" + "0".repeat(64)).map((n) => n.compValue),
      ),
    );
  const operatorTokens = new Set(approvals("operator").map(({ token }) => token));
  const emergencyTokens = new Set(approvals("emergency").map(({ token }) => token));
  for (const token of operatorTokens) expect(emergencyTokens.has(token)).toBe(true);
  const emergencySpenders = spendersOf("emergency");
  for (const spender of spendersOf("operator")) expect(emergencySpenders.has(spender)).toBe(true);
});

// OD-38: the governance role refuses, as the administered target, the Asset
// Safe and every module that the manifest lists, and the compiler refuses a
// policy or a manifest that breaks this.
const manifest = artifact.manifest;
const protectedAccounts = [manifest.assetSafe, ...manifest.modules];
const GRANTS = ["scopeTarget(bytes32,address)", "allowFunction(bytes32,address,bytes4,uint8)",
  "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"];
const pad = (a: string) => "0x" + a.slice(2).toLowerCase().padStart(64, "0");
const grant = (modifiers: typeof artifact.modifiers, signature: string) =>
  modifiers.flatMap((m) => m.roles).find((r) => r.name === "governance")!.targets[0].functions.find((f) => f.signature === signature)!;

test("the manifest lists both modifiers as modules of the Asset Safe", () => {
  expect(manifest.modules).toEqual([manifest.operatorModifier, manifest.safetyModifier]);
});

test("every governance grant refuses the Asset Safe and every module as its target", () => {
  for (const signature of GRANTS) expect(unguarded(grant(artifact.modifiers, signature).conditions, protectedAccounts)).toEqual([]);
});

test("the compiler refuses a grant that leaves a module unguarded", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const scope = grant(modifiers, GRANTS[0]);
  const child = scope.conditions.find((n) => n.compValue.toLowerCase() === pad(manifest.safetyModifier))!;
  child.compValue = pad("0x000000000000000000000000000000000000dEaD");
  expect(() => checkProtected(modifiers, manifest)).toThrow(`scopeTarget(bytes32,address) must refuse ${manifest.safetyModifier}`);
});

test("the compiler refuses a manifest that misses a module", () => {
  expect(() => checkProtected(artifact.modifiers, { ...manifest, modules: [manifest.operatorModifier] })).toThrow(/must list safety_modifier/);
  expect(() => checkProtected(artifact.modifiers, { ...manifest, modules: undefined })).toThrow(/must list every module/);
});

test("the compiler refuses a call outside the fixed set on a module", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const target = modifiers.flatMap((m) => m.roles).find((r) => r.name === "governance")!.targets[0];
  const signature = "assignRoles(address,bytes32[],bool[])";
  target.functions.push({ ...target.functions[0], selector: id(signature).slice(0, 10) as `0x${string}`, signature });
  expect(() => checkProtected(modifiers, manifest)).toThrow(/assignRoles\(address,bytes32\[\],bool\[\]\) is not allowed/);
});

test("the compiler refuses access to every function of the Asset Safe", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const emergency = modifiers.flatMap((m) => m.roles).find((r) => r.name === "emergency")!;
  emergency.targets.find((t) => t.address === manifest.assetSafe)!.clearance = Clearance.Target;
  expect(() => checkProtected(modifiers, manifest)).toThrow(/may not call every function of a vault Safe/);
});

// ADR 005, decisions 25 and 26: the emergency role holds the switch, and no
// emergency role restores what it stopped. A motion restarts (ADR 013,
// decision 12).
const DISABLE_MODULE = id("disableModule(address,address)").slice(0, 10) as `0x${string}`;

test("the emergency role holds the switch, pinned to the operator modifier", () => {
  const onSafe = role("emergency").targets.filter((t) => t.address === manifest.assetSafe);
  expect(onSafe.length).toBe(1);
  expect(onSafe[0].functions.map((f) => f.selector)).toEqual([DISABLE_MODULE]);
  const pinned = onSafe[0].functions[0].conditions.filter((n) => n.operator === EQUAL_TO).map((n) => n.compValue.toLowerCase());
  expect(pinned).toEqual([pad(manifest.operatorModifier)]);
  for (const r of artifact.modifiers.flatMap((m) => m.roles)) {
    if (r.name !== "emergency" && r.name !== "restart") expect(r.targets.some((t) => t.address === manifest.assetSafe)).toBe(false);
  }
});

test("every approval of the emergency role is zero", () => {
  const ZERO = "0x" + "0".repeat(64);
  const all = approvals("emergency");
  expect(all.length).toBeGreaterThan(0);
  for (const { f } of all) {
    const params = f.conditions.flatMap((n, i) => (i !== 0 && n.parent === 0 ? [n] : []));
    expect(params.length).toBe(2);
    expect(params[1].operator).toBe(EQUAL_TO);
    expect(params[1].compValue).toBe(ZERO);
  }
});

test("the compiler refuses a grant or a budget for the emergency role", () => {
  for (const signature of [GRANTS[0], "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)"]) {
    const modifiers = structuredClone(artifact.modifiers);
    const governance = modifiers.flatMap((m) => m.roles).find((r) => r.name === "governance")!;
    const emergency = modifiers.flatMap((m) => m.roles).find((r) => r.name === "emergency")!;
    const lent = governance.targets[0].functions.find((f) => f.signature === signature)!;
    emergency.targets.find((t) => t.address === manifest.operatorModifier)!.functions.push(structuredClone(lent));
    const name = signature.replace(/[()[\]]/g, "\\$&");
    expect(() => checkProtected(modifiers, manifest)).toThrow(new RegExp(`${name} would let a role that stops restore authority`));
  }
});

// ADR 013, decision 12: the restart role, which the Easy Track executor holds,
// may only enable the operator modifier on the Asset Safe.
const ENABLE_MODULE = id("enableModule(address)").slice(0, 10) as `0x${string}`;
const restartFunction = (modifiers: typeof artifact.modifiers) =>
  modifiers.flatMap((m) => m.roles).find((r) => r.name === "restart")!.targets.find((t) => t.address === manifest.assetSafe)!.functions[0];

test("the restart role holds only enableModule, pinned to the operator modifier", () => {
  const restart = role("restart");
  expect(restart.members.map((m: { address: string }) => m.address)).toEqual([manifest.easyTrackExecutor]);
  expect(restart.targets.map((t) => t.address)).toEqual([manifest.assetSafe]);
  expect(restart.targets[0].functions.map((f) => f.selector)).toEqual([ENABLE_MODULE]);
  const pinned = restart.targets[0].functions[0].conditions.filter((n) => n.operator === EQUAL_TO).map((n) => n.compValue.toLowerCase());
  expect(pinned).toEqual([pad(manifest.operatorModifier)]);
});

test("the compiler gives enableModule to the restart role alone", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const emergency = modifiers.flatMap((m) => m.roles).find((r) => r.name === "emergency")!;
  emergency.targets.find((t) => t.address === manifest.assetSafe)!.functions.push(structuredClone(restartFunction(modifiers)));
  expect(() => checkProtected(modifiers, manifest)).toThrow(/enableModule\(address\) belongs to the restart role alone/);
});

test("the compiler refuses a restart that is not pinned to the operator modifier", () => {
  for (const other of [manifest.safetyModifier, "0x000000000000000000000000000000000000dEaD"]) {
    const modifiers = structuredClone(artifact.modifiers);
    restartFunction(modifiers).conditions[1].compValue = pad(other);
    expect(() => checkProtected(modifiers, manifest)).toThrow(/must pin its argument to the operator modifier/);
  }
  const modifiers = structuredClone(artifact.modifiers);
  const fn = restartFunction(modifiers);
  fn.conditions = [fn.conditions[0]];
  fn.wildcarded = true;
  expect(() => checkProtected(modifiers, manifest)).toThrow(/must pin its argument|needs a condition/);
});

// ADR 013, decision 9: a budget motion may set a launch key, or a key that
// the factory derives for a new spender, which starts with "k:".
test("a budget motion may set a launch key or a derived key, and no other", () => {
  const BITMASK = 21;
  const OR = 2;
  const setAllowance = grant(artifact.modifiers, "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)");
  const keyParam = setAllowance.conditions.flatMap((n, i) => (i !== 0 && n.parent === 0 ? [i] : []))[0];
  expect(setAllowance.conditions[keyParam].operator).toBe(OR);
  const branches = setAllowance.conditions.filter((n) => n.parent === keyParam);
  const derived = branches.filter((n) => n.operator === BITMASK);
  expect(derived.map((n) => n.compValue as string)).toEqual(["0x0000ffff" + "00".repeat(13) + "6b3a" + "00".repeat(13)]);
  // Every launch key of the operator modifier: the three venue keys and the six orders budgets (ADR 007, decision 18).
  const operatorModifier = artifact.modifiers.find((m) => m.ref === "operator_modifier")!;
  expect(branches.filter((n) => n.operator === EQUAL_TO).length).toBe(operatorModifier.allowances.length);
  expect(operatorModifier.allowances.length).toBe(9);
});

// ADR 014, decision 7: insurance money moves only to the first-loss Safe.
test("the insurance-funding role transfers only to the first-loss Safe", () => {
  const TRANSFER = id("transfer(address,uint256)").slice(0, 10) as `0x${string}`;
  const funding = role("insurance-funding");
  expect(funding.members.map((m: { address: string }) => m.address)).toEqual([manifest.easyTrackExecutor]);
  expect(funding.targets.length).toBeGreaterThan(0);
  for (const target of funding.targets) {
    expect(target.functions.map((f) => f.selector)).toEqual([TRANSFER]);
    const pinned = target.functions[0].conditions.filter((n) => n.operator === EQUAL_TO).map((n) => n.compValue.toLowerCase());
    expect(pinned).toEqual([pad(manifest.firstLossSafe)]);
  }
});

// ADR 007: the orders account. The kit's manifest names no orders modifier, so these checks read the committed
// rehearsal artifact, which CI compares with a fresh compile.
const REHEARSAL = JSON.parse(
  readFileSync(path.join(ROOT, "artifacts/rehearsal-26249900.json"), "utf8"),
) as Artifact;
const ORDER_SIGNER = "0x23dA9AdE38E4477b23770DeD512fD37b12381FAB";
const ORDER = "(address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32)";
const SIGN_ORDER = id(`signOrder(${ORDER},uint32,uint256)`).slice(0, 10);
const UNSIGN_ORDER = id(`unsignOrder(${ORDER})`).slice(0, 10);
const ordersRole = (name: string) =>
  REHEARSAL.modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === name)!;
const signOrderOf = (name: string) =>
  ordersRole(name).targets.find((t) => t.address === ORDER_SIGNER)!.functions.find((f) => f.selector === SIGN_ORDER)!;

test("the rehearsal artifact passes the checks, the orders account included", () => {
  expect(() => checkProtected(REHEARSAL.modifiers, REHEARSAL.manifest)).not.toThrow();
});

test("every delegatecall is the orders account's call of the order signer", () => {
  const delegatecalls = REHEARSAL.modifiers.flatMap((m) =>
    m.roles.flatMap((r) =>
      r.targets.flatMap((t) => t.functions.filter((f) => (f.executionOptions & 2) !== 0).map((f) => ({ m: m.ref, t: t.address, f }))),
    ),
  );
  expect(delegatecalls.length).toBe(4);
  for (const d of delegatecalls) {
    expect(d.m).toBe("orders_modifier");
    expect(d.t).toBe(ORDER_SIGNER);
    expect([SIGN_ORDER, UNSIGN_ORDER]).toContain(d.f.selector);
  }
});

test("operator orders pay the Asset Safe for 90 days at most; recovery orders pay the Agent for 1 day at most", () => {
  const receiverAndLife = (name: string) => {
    const f = signOrderOf(name);
    const order = f.conditions.findIndex((n, i) => i !== 0 && n.parent === 0);
    const fields = f.conditions.flatMap((n, i) => (i !== order && n.parent === order ? [i] : []));
    const life = f.conditions.filter((n, i) => i !== 0 && n.parent === 0)[1];
    return { receiver: f.conditions[fields[2]], life };
  };
  const operator = receiverAndLife("operator");
  expect(operator.receiver.operator).toBe(EQUAL_TO);
  expect(operator.receiver.compValue).toBe(pad(REHEARSAL.manifest.assetSafe));
  expect(operator.life.operator).toBe(LESS_THAN);
  expect(BigInt(operator.life.compValue)).toBe(90n * 86400n + 1n);
  const recovery = receiverAndLife("emergency");
  expect(recovery.receiver.compValue).toBe(pad(REHEARSAL.manifest.agent));
  expect(BigInt(recovery.life.compValue)).toBe(86400n + 1n);
});

test("the compiler refuses a delegatecall to anything but the order signer", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const operator = modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === "operator")!;
  operator.targets.find((t) => t.functions.some((f) => f.signature?.startsWith("transfer")))!.functions[0].executionOptions = 2;
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/only the orders account may delegatecall/);
});

test("the compiler refuses the order signer's delegatecall from the Asset Safe", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const signer = structuredClone(ordersRole("operator").targets.find((t) => t.address === ORDER_SIGNER)!);
  modifiers.find((m) => m.ref === "operator_modifier")!.roles.find((r) => r.name === "operator")!.targets.push(signer);
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/only the orders account may delegatecall/);
});

test("the compiler refuses any call on the orders account itself", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const operator = modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === "operator")!;
  const target = structuredClone(operator.targets.find((t) => t.functions.some((f) => f.signature?.startsWith("transfer")))!);
  target.address = REHEARSAL.manifest.ordersAccount;
  operator.targets.push(target);
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/is not allowed on a vault Safe or one of its modules/);
});

test("the orders account's emergency role only removes authority on the orders modifier", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const emergency = modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === "emergency")!;
  const onModifier = emergency.targets.find((t) => t.address === REHEARSAL.manifest.ordersModifier)!;
  expect(onModifier.functions.map((f) => f.signature).sort()).toEqual(
    ["revokeFunction(bytes32,address,bytes4)", "revokeTarget(bytes32,address)"],
  );
  onModifier.functions.push({ ...onModifier.functions[0], selector: id("scopeTarget(bytes32,address)").slice(0, 10) as `0x${string}`, signature: "scopeTarget(bytes32,address)" });
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/would let a role that stops restore authority/);
});

test("every governance grant also refuses the orders account and its modifier", () => {
  const scopeTarget = grant(REHEARSAL.modifiers, "scopeTarget(bytes32,address)");
  const { ordersAccount, ordersModifier } = REHEARSAL.manifest as Record<string, string>;
  expect(unguarded(scopeTarget.conditions, [ordersAccount, ordersModifier])).toEqual([]);
});

// A missing pinned address would leave a transfer open, so the constellation refuses the manifest.
test("the constellation refuses a manifest that misses a pinned address", async () => {
  const { checkManifest } = await import("../constellation/addresses");
  const complete = JSON.parse(readFileSync(MANIFEST, "utf8"));
  expect(() => checkManifest(complete)).not.toThrow();
  for (const field of ["firstLossSafe", "ordersAccount", "agent"]) {
    const { [field]: _missing, ...partial } = complete;
    expect(() => checkManifest(partial)).toThrow(new RegExp(`must name ${field}`));
  }
  expect(() => checkManifest({ ...complete, ordersModifier: "orders" })).toThrow(/ordersModifier must be an address/);
});

// ADR 007, decision 43 (OD-116): no signed fee. The order's own fee field is pinned to zero for both roles, and so
// is the signer's fee bound, which alone would let the fee reach 1 wei.
test("every signer order signs no fee", () => {
  for (const name of ["operator", "emergency"]) {
    const f = signOrderOf(name);
    const params = f.conditions.flatMap((n, i) => (i !== 0 && n.parent === 0 ? [i] : []));
    const fields = f.conditions.flatMap((n, i) => (i !== params[0] && n.parent === params[0] ? [i] : []));
    expect(fields.length).toBe(12);
    const fee = f.conditions[fields[7]];
    expect(fee.operator).toBe(EQUAL_TO);
    expect(BigInt(fee.compValue)).toBe(0n);
    const bound = f.conditions[params[2]];
    expect(bound.operator).toBe(EQUAL_TO);
    expect(BigInt(bound.compValue)).toBe(0n);
  }
});
