// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, id } from "ethers";
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
  for (const roleName of ["emergency", "asset-emergency", "orders-emergency"]) for (const signature of [GRANTS[0], "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)"]) {
    const modifiers = structuredClone(artifact.modifiers);
    const governance = modifiers.flatMap((m) => m.roles).find((r) => r.name === "governance")!;
    const emergency = modifiers.flatMap((m) => m.roles).find((r) => r.name === "emergency")!;
    emergency.name = roleName;
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

// ADR 007, decision 41 (INV-040): the orders modifier's governance and approvals roles, both held by the Easy Track
// executor. Governance writes under the operator and emergency keys, and under the approvals key only the relayer
// approval; the one delegatecall that it grants is the order signer's; it holds no membership setter and refuses
// the vault's accounts as the administered target. The approvals role approves only CoW's vault relayer.
const COW_VAULT_RELAYER = "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110";
const COMPOSABLE_COW = "0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74";
const OR = 2;
const NOR = 3;
const MATCHES = 5;
const key32 = (label: string) => "0x" + Buffer.from(label).toString("hex").padEnd(64, "0");
const word = (n: bigint | number) => "0x" + BigInt(n).toString(16).padStart(64, "0");
const sel32 = (signature: string) => id(signature).slice(0, 10).padEnd(66, "0");
type Flat = { parent: number; paramType: number; operator: number; compValue: string };
const kids = (c: Flat[], i: number) => c.flatMap((n, j) => (j !== i && n.parent === i ? [j] : []));
const values = (c: Flat[], i: number) =>
  c[i].operator === EQUAL_TO ? [c[i].compValue.toLowerCase()] : kids(c, i).map((k) => c[k].compValue.toLowerCase());
const ordersModifierOf = (modifiers: typeof REHEARSAL.modifiers) => modifiers.find((m) => m.ref === "orders_modifier")!;
const ordersGrant = (modifiers: typeof REHEARSAL.modifiers, signature: string) =>
  ordersModifierOf(modifiers).roles.find((r) => r.name === "governance")!.targets[0].functions.find((f) => f.signature === signature)!;
/** The branches of a grant on the orders modifier, each with its parameters in order. */
const branchesOf = (c: Flat[]) => (c[0].operator === OR ? kids(c, 0) : [0]).map((b) => ({ b, params: kids(c, b) }));
const SCOPE_FUNCTION = GRANTS[2];
const ALLOW_FUNCTION = GRANTS[1];
const executor = REHEARSAL.manifest.easyTrackExecutor as string;

test("the executor holds the orders modifier's governance role, on the modifier alone, with three grants", () => {
  const governance = ordersRole("governance");
  expect(governance.members.map((m: { address: string }) => m.address)).toEqual([executor]);
  expect(governance.targets.map((t) => t.address)).toEqual([REHEARSAL.manifest.ordersModifier]);
  expect(governance.targets[0].functions.map((f) => f.signature).sort()).toEqual([...GRANTS].sort());
  // no membership setter, no allowTarget, no revoke and no setAllowance
  for (const f of governance.targets[0].functions) expect(f.executionOptions).toBe(0);
});

test("orders governance writes only under the operator, emergency and approvals keys, refusing the vault's accounts", () => {
  const { assetSafe, modules, ordersAccount, ordersModifier } = REHEARSAL.manifest as Record<string, any>;
  const vault = [assetSafe, ...modules, ordersAccount, ordersModifier];
  const allowed = ["operator", "emergency", "approvals"].map(key32);
  for (const signature of GRANTS) {
    const c = ordersGrant(REHEARSAL.modifiers, signature).conditions as Flat[];
    expect(unguarded(c, vault)).toEqual([]);
    for (const { params } of branchesOf(c)) {
      for (const k of values(c, params[0])) expect(allowed).toContain(k);
      expect(values(c, params[0])).not.toContain(key32("governance"));
    }
  }
});

/** A grant's branches by what they write: key, target, function and options, each as its fixed values. */
const grantsOf = (c: Flat[]) =>
  branchesOf(c).map(({ b, params }) => ({
    b,
    params,
    keys: values(c, params[0]),
    target: c[params[1]].operator === NOR ? "not the vault" : values(c, params[1]),
    fn: values(c, params[2]),
    options: values(c, params[4]),
  }));
const TRANSFER32 = sel32("transfer(address,uint256)");
const APPROVE32 = sel32("approve(address,uint256)");
const SIGN32 = sel32(`signOrder(${ORDER},uint32,uint256)`);

test("orders governance grants signer orders by delegatecall, TWAP orders, and pinned transfers and approvals", () => {
  const c = ordersGrant(REHEARSAL.modifiers, SCOPE_FUNCTION).conditions as Flat[];
  const summary = grantsOf(c).map(({ keys, target, fn, options }) => JSON.stringify({ keys: [...keys].sort(), target, fn, options }));
  const op = key32("operator");
  const em = key32("emergency");
  const both = [em, op].sort();
  const expected = [
    { keys: both, target: [pad(ORDER_SIGNER)], fn: [SIGN32], options: [word(2)] },
    { keys: [op], target: [pad(COMPOSABLE_COW)], fn: [sel32("createWithContext((address,bytes32,bytes),address,bytes,bool)")], options: [word(0)] },
    { keys: both, target: "not the vault", fn: [TRANSFER32], options: [word(0)] },
    { keys: [em], target: "not the vault", fn: [APPROVE32], options: [word(0)] },
    { keys: [key32("approvals")], target: "not the vault", fn: [APPROVE32], options: [word(0)] },
  ].map((s) => JSON.stringify(s));
  expect(summary.length).toBe(expected.length);
  expect(new Set(summary)).toEqual(new Set(expected));
});

test("the transfer and approval trees that orders governance writes are pinned to the roles' own trees", () => {
  const c = ordersGrant(REHEARSAL.modifiers, SCOPE_FUNCTION).conditions as Flat[];
  const encode = (conditions: Flat[]) =>
    AbiCoder.defaultAbiCoder().encode(["(uint8,uint8,uint8,bytes)[]"], [conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue])]);
  const pinned = (keyLabel: string, fn: string) => {
    const g = grantsOf(c).find((x) => x.keys.includes(key32(keyLabel)) && x.fn[0] === fn && x.target === "not the vault")!;
    expect(c[g.params[3]].operator).toBe(EQUAL_TO);
    return c[g.params[3]].compValue;
  };
  // every tree that a role holds for the function, on every token, is the pinned one
  const held = (roleName: string, selector: string) =>
    ordersRole(roleName).targets.flatMap((t) => t.functions.filter((f) => f.selector === selector).map((f) => encode(f.conditions as Flat[])));
  const TRANSFER = id("transfer(address,uint256)").slice(0, 10);
  for (const [roleName, keyLabel, selector, fn] of [
    ["operator", "operator", TRANSFER, TRANSFER32],
    ["emergency", "emergency", TRANSFER, TRANSFER32],
    ["emergency", "emergency", APPROVE, APPROVE32],
    ["approvals", "approvals", APPROVE, APPROVE32],
  ] as const) {
    const trees = new Set(held(roleName, selector));
    expect(trees.size).toBe(1);
    expect([...trees][0]).toBe(pinned(keyLabel, fn));
  }
});

test("orders governance restores only the operator's two functions without conditions", () => {
  const c = ordersGrant(REHEARSAL.modifiers, ALLOW_FUNCTION).conditions as Flat[];
  const restores = branchesOf(c).map(({ params }) => ({
    keys: values(c, params[0]),
    target: values(c, params[1]),
    fn: values(c, params[2]),
    options: values(c, params[3]),
  }));
  expect(restores).toEqual([
    { keys: [key32("operator")], target: [pad(ORDER_SIGNER)], fn: [sel32(`unsignOrder(${ORDER})`)], options: [word(2)] },
    { keys: [key32("operator")], target: [pad(COMPOSABLE_COW)], fn: [sel32("remove(bytes32)")], options: [word(0)] },
  ]);
  // and they are the operator's only functions without conditions on the orders account
  const wildcards = ordersRole("operator").targets.flatMap((t) => t.functions.filter((f) => f.wildcarded).map((f) => [t.address, f.selector]));
  expect(wildcards).toEqual([[ORDER_SIGNER, UNSIGN_ORDER], [COMPOSABLE_COW, id("remove(bytes32)").slice(0, 10)]]);
});

test("the approvals role approves only CoW's vault relayer, for every token that an order sells", () => {
  const approvalsRole = ordersRole("approvals");
  expect(approvalsRole.members.map((m: { address: string }) => m.address)).toEqual([executor]);
  for (const target of approvalsRole.targets) {
    expect(target.functions.map((f) => f.selector)).toEqual([APPROVE]);
    const c = target.functions[0].conditions as Flat[];
    expect(c.length).toBe(2);
    expect(c[1].operator).toBe(EQUAL_TO);
    expect(c[1].compValue.toLowerCase()).toBe(pad(COW_VAULT_RELAYER));
    expect(target.functions[0].executionOptions).toBe(0);
  }
  // every token that a signer order sells, for the operator or for recovery
  const sold = new Set<string>();
  for (const name of ["operator", "emergency"]) {
    const c = signOrderOf(name).conditions as Flat[];
    const order = kids(c, 0)[0];
    for (const v of values(c, kids(c, order)[0])) sold.add(v);
  }
  expect(new Set(approvalsRole.targets.map((t) => pad(t.address)))).toEqual(sold);
  expect(sold.size).toBe(8);
});

// The compiler refuses a motion's grant of delegatecall anywhere else, a grant under the granting role's own key or
// with the key left open, a grant that leaves a vault account open, and a signer order without a condition.
const mutate = (signature: string, change: (c: Flat[]) => void) => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  change(ordersGrant(modifiers, signature).conditions as Flat[]);
  return () => checkProtected(modifiers, REHEARSAL.manifest);
};
const branchWith = (c: Flat[], fn: string) => grantsOf(c).find((g) => g.fn[0] === fn)!;

test("the compiler refuses a motion's delegatecall to anything but the order signer's sign or unsign", () => {
  expect(mutate(SCOPE_FUNCTION, (c) => { c[branchWith(c, SIGN32).params[1]].compValue = pad(COMPOSABLE_COW); })).toThrow(/may grant delegatecall/);
  expect(mutate(SCOPE_FUNCTION, (c) => { c[branchWith(c, SIGN32).params[2]].compValue = TRANSFER32; })).toThrow(/may grant delegatecall/);
  // a plain-call branch whose options may carry the delegatecall bit
  expect(mutate(SCOPE_FUNCTION, (c) => { c[branchWith(c, TRANSFER32).params[4]].compValue = word(3); })).toThrow(/may grant delegatecall/);
  expect(mutate(SCOPE_FUNCTION, (c) => { const o = c[branchWith(c, TRANSFER32).params[4]]; o.operator = LESS_THAN; o.compValue = word(3); })).toThrow(/may grant delegatecall/);
  // signOrder without a condition, by allowFunction
  expect(mutate(ALLOW_FUNCTION, (c) => {
    const unsign = branchesOf(c).find(({ params }) => values(c, params[3])[0] === word(2))!;
    c[unsign.params[2]].compValue = sel32(`signOrder(${ORDER},uint32,uint256)`);
  })).toThrow(/may grant delegatecall/);
});

test("the compiler refuses the signer's delegatecall as a grant on the operator modifier", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const assetGovernance = modifiers.find((m) => m.ref === "operator_modifier")!.roles.find((r) => r.name === "governance")!;
  const fn = assetGovernance.targets[0].functions.find((f) => f.signature === SCOPE_FUNCTION)!;
  const c = fn.conditions as Flat[];
  const params = kids(c, 0);
  c[params[1]] = { ...c[params[1]], operator: EQUAL_TO, compValue: pad(ORDER_SIGNER) };
  for (const k of kids(c, params[1])) c[k].parent = -1;
  c[params[4]].compValue = word(3);
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/may grant delegatecall/);
});

test("the compiler refuses a grant under the granting role's own key, or with the key open", () => {
  expect(mutate(GRANTS[0], (c) => { c[kids(c, kids(c, 0)[0])[0]].compValue = key32("governance"); })).toThrow(/may not write under its own role's key/);
  expect(mutate(SCOPE_FUNCTION, (c) => {
    const keyNode = branchWith(c, TRANSFER32).params[0];
    c[keyNode].operator = 0;
    for (const k of kids(c, keyNode)) c[k].operator = 0;
  })).toThrow(/must pin the role key/);
});

test("the compiler refuses an orders grant that leaves the orders account open", () => {
  const { ordersAccount } = REHEARSAL.manifest as Record<string, string>;
  expect(mutate(SCOPE_FUNCTION, (c) => {
    const nor = branchWith(c, TRANSFER32).params[1];
    c[kids(c, nor).find((k) => c[k].compValue.toLowerCase() === pad(ordersAccount))!].compValue = pad("0x000000000000000000000000000000000000dEaD");
  })).toThrow(`must refuse ${ordersAccount}`);
});

test("the compiler refuses a signer order without a condition", () => {
  const modifiers = structuredClone(REHEARSAL.modifiers);
  const operator = ordersModifierOf(modifiers).roles.find((r) => r.name === "operator")!;
  const sign = operator.targets.find((t) => t.address === ORDER_SIGNER)!.functions.find((f) => f.selector === SIGN_ORDER)!;
  sign.wildcarded = true;
  sign.conditions = [];
  expect(() => checkProtected(modifiers, REHEARSAL.manifest)).toThrow(/needs a condition: a signer order without one pays anyone/);
});

// ADR 007, decision 41: a motion adds a token to the order lists. In the SDK's form, which the compiler writes, each
// list is an Or of EqualTo leaves sorted by value. Adding a token inserts one leaf in its sorted place in each list,
// and the TWAP order's two shapes keep their order, because they first differ in their part counts, before any
// token. A writer that follows this rule, such as a factory or the fork test's motion, keeps the compiler's form.
test("adding a token inserts one sorted leaf in each list, in the SDK's form", async () => {
  const { signOrder, twapOrder } = await import("../constellation/cow");
  const { ORDER_TOKENS, RECOVERY_BUY, RECOVERY_SELL } = await import("../constellation/orders");
  const { flattenCondition, processPermissions } = await import("zodiac-roles-sdk");
  const flat = (entry: Record<string, any>): Flat[] =>
    flattenCondition(processPermissions([entry] as any).targets[0].functions[0].condition!).map((n) => ({
      parent: n.parent,
      paramType: n.paramType,
      operator: n.operator,
      compValue: n.compValue ?? "0x",
    }));
  const insert = (c: Flat[], list: number, token: string): Flat[] => {
    const leaf = pad(token);
    const leaves = kids(c, list);
    const at = leaves.find((k) => c[k].compValue.toLowerCase() > leaf) ?? leaves[leaves.length - 1] + 1;
    const moved = c.map((n) => ({ ...n, parent: n.parent >= at ? n.parent + 1 : n.parent }));
    moved.splice(at, 0, { parent: list, paramType: 1, operator: EQUAL_TO, compValue: leaf });
    return moved;
  };
  const sides = (c: Flat[], node: number, count: number) => kids(c, node).slice(0, count);
  const receiver = "0x00000000000000000000000000000000000000aa";
  // a token that sorts first, one in the middle and one last; none is a decision
  for (const token of ["0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", "0xb000000000000000000000000000000000000001", "0xffffffffffffffffffffffffffffffffffffffff"]) {
    // the operator's signer orders: the sell side and the buy side
    let expected = flat(signOrder({ sell: ORDER_TOKENS, buy: ORDER_TOKENS, receiver, life: 90n * 86400n }));
    for (const side of [0, 1]) expected = insert(expected, sides(expected, kids(expected, 0)[0], 2)[side], token);
    expect(flat(signOrder({ sell: [...ORDER_TOKENS, token], buy: [...ORDER_TOKENS, token], receiver, life: 90n * 86400n }))).toEqual(expected);
    // recovery orders: the sell side only
    let recovery = flat(signOrder({ sell: RECOVERY_SELL, buy: RECOVERY_BUY, receiver, life: 86400n }));
    recovery = insert(recovery, kids(recovery, kids(recovery, 0)[0])[0], token);
    expect(flat(signOrder({ sell: [...RECOVERY_SELL, token], buy: RECOVERY_BUY, receiver, life: 86400n }))).toEqual(recovery);
    // TWAP orders: both sides of both shapes, which keep their order
    let twap = flat(twapOrder({ sell: ORDER_TOKENS, buy: ORDER_TOKENS, receiver }));
    for (const shape of [0, 1]) {
      for (const side of [0, 1]) {
        const shapes = twap.flatMap((n, i) => (n.paramType === 6 && n.operator === MATCHES ? [i] : []));
        twap = insert(twap, kids(twap, shapes[shape])[side], token);
      }
    }
    expect(flat(twapOrder({ sell: [...ORDER_TOKENS, token], buy: [...ORDER_TOKENS, token], receiver }))).toEqual(twap);
  }
});

// ADR 006, decision 13 (OD-49; INV-025): the exit-governance role on the safety modifier, held by the Easy Track
// executor, writes only the emergency role's exits, each tree pinned to the emergency role's own, as plain calls,
// and never on a vault account. The kit compiles the safety modifier, so these checks read the kit's artifact.
const exitRole = () => artifact.modifiers.find((m) => m.ref === "safety_modifier")!.roles.find((r) => r.name === "exit-governance")!;
const exitGrant = (modifiers: typeof artifact.modifiers, signature: string) =>
  modifiers.find((m) => m.ref === "safety_modifier")!.roles.find((r) => r.name === "exit-governance")!.targets[0].functions.find((f) => f.signature === signature)!;
const emergencyOnSafety = () => artifact.modifiers.find((m) => m.ref === "safety_modifier")!.roles.find((r) => r.name === "emergency")!;
const encodeTree = (conditions: Flat[]) =>
  AbiCoder.defaultAbiCoder().encode(["(uint8,uint8,uint8,bytes)[]"], [conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue])]);

test("the executor holds the exit-governance role, on the safety modifier alone, writing only under the emergency key", () => {
  const exit = exitRole();
  expect(exit.members.map((m: { address: string }) => m.address)).toEqual([manifest.easyTrackExecutor]);
  expect(exit.targets.map((t) => t.address)).toEqual([manifest.safetyModifier]);
  expect(exit.targets[0].functions.map((f) => f.signature).sort()).toEqual([...GRANTS].sort());
  for (const signature of GRANTS) {
    const c = exitGrant(artifact.modifiers, signature).conditions as Flat[];
    expect(unguarded(c, protectedAccounts)).toEqual([]);
    for (const { params } of branchesOf(c)) {
      expect(values(c, params[0])).toEqual([key32("emergency")]);
      if (signature !== GRANTS[0]) expect(values(c, params[signature === GRANTS[1] ? 3 : 4])).toEqual([word(0)]);
    }
  }
});

test("each exit tree that exit-governance writes is pinned to the emergency role's own tree", () => {
  const c = exitGrant(artifact.modifiers, SCOPE_FUNCTION).conditions as Flat[];
  const pinned = branchesOf(c).map(({ params }) => ({ fns: values(c, params[2]), tree: c[params[3]] }));
  expect(pinned.length).toBe(5);
  for (const { tree } of pinned) expect(tree.operator).toBe(EQUAL_TO);
  const held = (selector: string, on?: (address: string) => boolean) =>
    new Set(
      emergencyOnSafety()
        .targets.filter((t) => on === undefined || on(t.address))
        .flatMap((t) => t.functions.filter((f) => f.selector === selector && !f.wildcarded).map((f) => encodeTree(f.conditions as Flat[]))),
    );
  const treesFor = (signature: string) => new Set(pinned.filter((x) => x.fns.includes(sel32(signature))).map((x) => x.tree.compValue));
  const TRANSFER = id("transfer(address,uint256)").slice(0, 10);
  // the transfers: to the Agent for an Earn share, to the Agent or the orders account for a token that recovery sells
  expect(treesFor("transfer(address,uint256)")).toEqual(held(TRANSFER));
  // the ERC-4626 exits and the claims
  for (const signature of ["redeem(uint256,address,address)", "withdraw(uint256,address,address)", "claim(address)", "claim(address,uint32[])"]) {
    const own = held(id(signature).slice(0, 10));
    expect(own.size).toBe(1);
    expect(treesFor(signature)).toEqual(own);
  }
  // the zeroing: any spender, the amount zero
  const [zero] = [...treesFor("approve(address,uint256)")];
  const zeroNodes = AbiCoder.defaultAbiCoder().decode(["(uint8,uint8,uint8,bytes)[]"], zero)[0].map((n: any[]) => [Number(n[0]), Number(n[1]), Number(n[2]), n[3]]);
  expect(zeroNodes).toEqual([[0, 5, MATCHES, "0x"], [0, 1, 0, "0x"], [0, 1, EQUAL_TO, word(0)]]);
});

test("the exits without conditions are exactly the emergency role's own", () => {
  const c = exitGrant(artifact.modifiers, ALLOW_FUNCTION).conditions as Flat[];
  const [{ params }] = branchesOf(c);
  const own = new Set(emergencyOnSafety().targets.flatMap((t) => t.functions.filter((f) => f.wildcarded).map((f) => f.selector.padEnd(66, "0"))));
  expect(new Set(values(c, params[2]))).toEqual(own);
  expect(own.size).toBe(4);
});

test("the compiler keeps each modifier's keys: no motion writes under the restart key, or the emergency key on the operator modifier", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const c = exitGrant(modifiers, GRANTS[0]).conditions as Flat[];
  c[kids(c, 0)[0]].compValue = key32("restart");
  expect(() => checkProtected(modifiers, manifest)).toThrow(/may write under `restart`, which this modifier keeps from motions/);
  const assetModifiers = structuredClone(artifact.modifiers);
  const g = grant(assetModifiers, GRANTS[0]).conditions as Flat[];
  g[kids(g, 0)[0]].compValue = key32("emergency");
  expect(() => checkProtected(assetModifiers, manifest)).toThrow(/may write under `emergency`, which this modifier keeps from motions/);
});

test("the compiler refuses exit-governance's grant of delegatecall", () => {
  const modifiers = structuredClone(artifact.modifiers);
  const c = exitGrant(modifiers, ALLOW_FUNCTION).conditions as Flat[];
  c[branchesOf(c)[0].params[3]].compValue = word(2);
  expect(() => checkProtected(modifiers, manifest)).toThrow(/may grant delegatecall/);
});
