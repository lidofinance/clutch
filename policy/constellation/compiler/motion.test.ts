// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests of the `motion` command and its checker (ADR 013). The expected calls are encoded here from their
// signatures, apart from the command's own encoder.
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, encodeBytes32String, Interface } from "ethers";
import type { Artifact } from "./compile";
import { checkMotion, decodeMotion, encodeMotion, EXAMPLE_MOTION, exampleMotion, MAX_WRITES, pinnedKeys, planMotion } from "./motion";
import type { Write } from "./motion";
import { derivedKey, EXAMPLE_EARN_USD_BUDGET, EXAMPLE_VAULT, EXAMPLE_WETH_BUDGET, exampleHead, WETH } from "./motion.example";

const ROOT = path.resolve(import.meta.dir, "..");
const base = JSON.parse(readFileSync(path.join(ROOT, "artifacts/rehearsal-26249900.json"), "utf8")) as Artifact;
const head = exampleHead(base);

const ROLES = new Interface([
  "function scopeTarget(bytes32 roleKey, address targetAddress)",
  "function revokeTarget(bytes32 roleKey, address targetAddress)",
  "function allowTarget(bytes32 roleKey, address targetAddress, uint8 options)",
  "function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options)",
  "function revokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector)",
  "function scopeFunction(bytes32 roleKey, address targetAddress, bytes4 selector, (uint8 parent, uint8 paramType, uint8 operator, bytes compValue)[] conditions, uint8 options)",
  "function setAllowance(bytes32 key, uint128 balance, uint128 maxRefill, uint128 refill, uint64 period, uint64 timestamp)",
  "function assignRoles(address module, bytes32[] roleKeys, bool[] memberOf)",
]);
const key = (name: string) => encodeBytes32String(name);
const OPERATOR = key("operator");
const EMERGENCY = key("emergency");
const GOVERNANCE = key("governance");
const EXIT_GOVERNANCE = key("exit-governance");
const MONTH = 30 * 24 * 60 * 60;
const SUSDS = "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD";
const AGENT = "0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c";
const STRANGER = "0x000000000000000000000000000000000000dEaD";
const APPROVE = "0x095ea7b3";
const TRANSFER = "0xa9059cbb";
const DEPOSIT = "0x6e553f65";
const WITHDRAW = "0xb460af94";
const REDEEM = "0xba087652";

const lower = (value: string) => value.toLowerCase();
const clone = <T>(value: T) => JSON.parse(JSON.stringify(value)) as T;
const modifierOf = (policy: Artifact, ref: string) => policy.modifiers.find((m) => m.ref === ref)!;
const roleOf = (policy: Artifact, ref: string, name: string) => modifierOf(policy, ref).roles.find((r) => r.name === name)!;
const targetOf = (policy: Artifact, ref: string, name: string, address: string) => roleOf(policy, ref, name).targets.find((t) => lower(t.address) === lower(address))!;
const opMod = modifierOf(base, "operator_modifier").address;
const safetyMod = modifierOf(base, "safety_modifier").address;
const ordersMod = modifierOf(base, "orders_modifier").address;
const strip = (writes: Write[]): Write[] => writes.map(({ modifier, role, to, data }) => ({ modifier, role, to, data }));
const write = (modifier: string, role: string, fn: string, args: unknown[]): Write => ({ modifier, role, to: modifier, data: lower(ROLES.encodeFunctionData(fn, args)) });
const address32 = (address: string) => AbiCoder.defaultAbiCoder().encode(["address"], [address]);
const node = (parent: number, paramType: number, operator: number, compValue = "0x") => [parent, paramType, operator, compValue];
const example = () => strip(planMotion(base, head).writes);

test("the calldata is the factory's: the counter, the policy version, and the writes", () => {
  const writes = example();
  const calldata = encodeMotion(3n, 7n, writes);
  const expected = AbiCoder.defaultAbiCoder().encode(
    ["uint256", "uint256", "tuple(address,bytes32,address,bytes)[]"],
    [3, 7, writes.map((w) => [w.modifier, w.role, w.to, w.data])],
  );
  expect(calldata).toBe(expected);
  const decoded = decodeMotion(calldata);
  expect(decoded.epoch).toBe(3n);
  expect(decoded.policyVersion).toBe(7n);
  expect(decoded.writes.map((w) => ({ ...w, modifier: lower(w.modifier), to: lower(w.to) }))).toEqual(writes.map((w) => ({ ...w, modifier: lower(w.modifier), to: lower(w.to) })));
});

test("two equal policies need no write", () => {
  const plan = planMotion(base, clone(base));
  expect(plan.writes).toEqual([]);
  expect(plan.needsVote).toEqual([]);
});

// ADR 013, decisions 9 and 11, and ADR 006, decision 13: an onboarding sets the new spender's budget under its
// derived key, writes the operator's permissions through the governance role, and writes the emergency exits
// through the exit-governance role.
test("the example onboarding is these ten writes, in this order", () => {
  const budgetKey = derivedKey(WETH, EXAMPLE_VAULT);
  expect(budgetKey).toBe(`0x6b3a${lower(EXAMPLE_VAULT).slice(2)}${lower(WETH).slice(2, 22)}`);
  const earnUsd = String(EXAMPLE_EARN_USD_BUDGET);
  const weth = String(EXAMPLE_WETH_BUDGET);
  const avatarReceiver = [node(0, 5, 5), node(0, 1, 0), node(0, 1, 15)];
  const avatarReceiverAndOwner = [node(0, 5, 5), node(0, 1, 0), node(0, 1, 15), node(0, 1, 15)];
  const expected = [
    write(opMod, GOVERNANCE, "setAllowance", [key("earn_usd_deposit"), earnUsd, earnUsd, earnUsd, MONTH, 0]),
    write(opMod, GOVERNANCE, "setAllowance", [budgetKey, weth, weth, weth, MONTH, 0]),
    write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, WETH, APPROVE, [node(0, 5, 5), node(0, 1, 16, address32(EXAMPLE_VAULT)), node(0, 1, 28, budgetKey)], 0]),
    write(opMod, GOVERNANCE, "scopeTarget", [OPERATOR, EXAMPLE_VAULT]),
    write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, EXAMPLE_VAULT, DEPOSIT, avatarReceiver, 0]),
    write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, EXAMPLE_VAULT, WITHDRAW, avatarReceiverAndOwner, 0]),
    write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, EXAMPLE_VAULT, REDEEM, avatarReceiverAndOwner, 0]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeTarget", [EMERGENCY, EXAMPLE_VAULT]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, EXAMPLE_VAULT, REDEEM, avatarReceiverAndOwner, 0]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, EXAMPLE_VAULT, TRANSFER, [node(0, 5, 5), node(0, 1, 16, address32(AGENT))], 0]),
  ];
  const plan = planMotion(base, head);
  expect(plan.needsVote).toEqual([]);
  expect(strip(plan.writes)).toEqual(expected);
  expect(checkMotion(base, head, expected)).toMatchObject({ ok: true, problems: [], differences: [], actions: [] });
});

test("the committed example motion equals a fresh build", () => {
  expect(readFileSync(EXAMPLE_MOTION, "utf8")).toBe(exampleMotion());
  const file = JSON.parse(exampleMotion());
  expect(decodeMotion(file.calldata).writes.length).toBe(10);
  expect(file.epoch).toBe("0");
  expect(file.policyVersion).toBe("0");
});

// ADR 006, decision 14: a routine removal revokes the permission.
test("a removal on the operator modifier revokes each function and then the target", () => {
  const without = clone(base);
  const operator = roleOf(without, "operator_modifier", "operator");
  operator.targets = operator.targets.filter((t) => lower(t.address) !== lower(SUSDS));
  const plan = planMotion(base, without);
  expect(plan.needsVote).toEqual([]);
  expect(strip(plan.writes)).toEqual([
    write(opMod, GOVERNANCE, "revokeFunction", [OPERATOR, SUSDS, DEPOSIT]),
    write(opMod, GOVERNANCE, "revokeFunction", [OPERATOR, SUSDS, WITHDRAW]),
    write(opMod, GOVERNANCE, "revokeFunction", [OPERATOR, SUSDS, REDEEM]),
    write(opMod, GOVERNANCE, "revokeTarget", [OPERATOR, SUSDS]),
  ]);
  expect(checkMotion(base, without, strip(plan.writes)).ok).toBe(true);

  // the target's revoke alone leaves its functions in the modifier's storage, where a later scope brings them back
  const lazy = checkMotion(base, without, [write(opMod, GOVERNANCE, "revokeTarget", [OPERATOR, SUSDS])]);
  expect(lazy.ok).toBe(false);
  expect(lazy.differences.length).toBe(3);
  expect(lazy.differences.every((d) => d.includes("stored under a revoked target"))).toBe(true);

  const oneLess = clone(base);
  const savings = targetOf(oneLess, "operator_modifier", "operator", SUSDS);
  savings.functions = savings.functions.filter((f) => f.selector !== WITHDRAW);
  expect(strip(planMotion(base, oneLess).writes)).toEqual([write(opMod, GOVERNANCE, "revokeFunction", [OPERATOR, SUSDS, WITHDRAW])]);
});

test("a budget that leaves the policy is emptied, and a changed one is set", () => {
  const without = clone(base);
  const modifier = modifierOf(without, "operator_modifier");
  modifier.allowances = modifier.allowances.filter((a) => a.name !== "earn_usd_deposit");
  const plan = planMotion(base, without);
  expect(strip(plan.writes)).toEqual([write(opMod, GOVERNANCE, "setAllowance", [key("earn_usd_deposit"), 0, 0, 0, MONTH, 0])]);
  expect(checkMotion(base, without, strip(plan.writes)).ok).toBe(true);
  // without the write, the budget of the base policy stays
  const kept = checkMotion(base, without, [write(opMod, GOVERNANCE, "setAllowance", [key("sky_savings_usds"), 1, 1, 1, MONTH, 0])]);
  expect(kept.ok).toBe(false);
  expect(kept.differences.some((d) => d.includes("earn_usd_deposit"))).toBe(true);
});

// ADR 013, decision 4, and the guards of each motion role: a motion writes no membership, no whole target, nothing
// under a motion role's own key, and no removal where the motion role has no revoke.
test("a change that no motion role can write needs a vote", () => {
  const reasons = (change: (policy: Artifact) => void) => {
    const next = clone(base);
    change(next);
    const plan = planMotion(base, next);
    expect(plan.writes).toEqual([]);
    return plan.needsVote;
  };
  expect(reasons((p) => roleOf(p, "operator_modifier", "operator").members.push({ address: STRANGER, name: null }))).toEqual([
    "the members of the role operator on the Clutch operator modifier change",
  ]);
  expect(reasons((p) => (targetOf(p, "operator_modifier", "operator", SUSDS).clearance = 1))[0]).toContain("as a whole target");
  // the governance role's own permissions: it never writes under its own key
  expect(reasons((p) => roleOf(p, "operator_modifier", "governance").targets[0].functions.pop())[0]).toContain("no motion role can call revokeFunction");
  // the exit-governance role and the orders modifier's governance role hold no revoke
  expect(
    reasons((p) => {
      const emergency = roleOf(p, "safety_modifier", "emergency");
      emergency.targets = emergency.targets.filter((t) => lower(t.address) !== lower(SUSDS));
    }).every((r) => r.includes("no motion role can call revoke")),
  ).toBe(true);
  expect(reasons((p) => modifierOf(p, "orders_modifier").roles.pop())[0]).toContain("goes");
  expect(reasons((p) => (p.manifest.universalFactory = STRANGER))[0]).toContain("the manifest changes");
});

test("the keys that a motion role writes under are read from its policy", () => {
  const grant = (ref: string, role: string, signature: string) => roleOf(base, ref, role).targets[0].functions.find((f) => f.signature?.startsWith(signature))!;
  expect(pinnedKeys(grant("operator_modifier", "governance", "scopeFunction"))).toEqual([lower(OPERATOR)]);
  expect(pinnedKeys(grant("safety_modifier", "exit-governance", "scopeTarget"))).toEqual([lower(EMERGENCY)]);
  expect(new Set(pinnedKeys(grant("orders_modifier", "governance", "scopeTarget")))).toEqual(new Set([OPERATOR, EMERGENCY, key("approvals")].map(lower)));
  expect(new Set(pinnedKeys(grant("safety_modifier", "exit-governance", "scopeFunction")))).toEqual(new Set([lower(EMERGENCY)]));
  expect(pinnedKeys({ wildcarded: true, executionOptions: 0, conditions: [] })).toBeNull();
});

// What the checker is for: the factory checks no write's content (ADR 013, decision 11), so a motion that widens
// beyond the merged policy change must fail here.
test("the checker refuses a motion that writes more, less or something else than the policy change", () => {
  const good = example();
  expect(checkMotion(base, head, good).ok).toBe(true);

  // one write more: a transfer of WETH to any address, with no budget
  const widened = checkMotion(base, head, [...good, write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, WETH, TRANSFER, [node(0, 5, 5)], 0])]);
  expect(widened.ok).toBe(false);
  expect(widened.differences).toEqual(["Clutch operator modifier, role operator: transfer(address,uint256) on WETH has other conditions or other execution options"]);

  // one write less: the emergency exit
  const noExit = checkMotion(base, head, good.slice(0, 9));
  expect(noExit.ok).toBe(false);
  expect(noExit.differences).toEqual(["Clutch safety modifier, role emergency: transfer(address,uint256) on example ERC-4626 vault is missing"]);

  // one node changed: the approval's spender
  const tampered = clone(good);
  tampered[2] = write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, WETH, APPROVE, [node(0, 5, 5), node(0, 1, 16, address32(STRANGER)), node(0, 1, 28, derivedKey(WETH, EXAMPLE_VAULT))], 0]);
  expect(checkMotion(base, head, tampered).differences).toEqual(["Clutch operator modifier, role operator: approve(address,uint256) on WETH has other conditions or other execution options"]);

  // a delegatecall in place of a call
  const delegate = clone(good);
  delegate[4] = write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, EXAMPLE_VAULT, DEPOSIT, [node(0, 5, 5), node(0, 1, 0), node(0, 1, 15)], 2]);
  expect(checkMotion(base, head, delegate).ok).toBe(false);

  // a larger budget than the policy's
  const budget = clone(good);
  budget[1] = write(opMod, GOVERNANCE, "setAllowance", [derivedKey(WETH, EXAMPLE_VAULT), 10n ** 30n, 10n ** 30n, 10n ** 30n, MONTH, 0]);
  const larger = checkMotion(base, head, budget);
  expect(larger.ok).toBe(false);
  expect(larger.differences.length).toBe(1);
  expect(larger.differences[0]).toContain("the budget weth_to_example_vault");
});

test("the checker refuses a write that a modifier would refuse, or that the factory would", () => {
  const good = example();
  const problems = (writes: Write[]) => checkMotion(base, head, writes).problems;

  // the wrong role for the call
  const wrongRole = clone(good);
  wrongRole[0].role = EXIT_GOVERNANCE;
  expect(problems(wrongRole)[0]).toContain("only the role governance can make this call");
  // a write under a key that the motion role does not write
  expect(problems([...good, write(opMod, GOVERNANCE, "scopeTarget", [EMERGENCY, WETH])])[0]).toContain("no motion role can call scopeTarget");
  // a membership
  expect(problems([...good, write(opMod, GOVERNANCE, "assignRoles", [STRANGER, [OPERATOR], [true]])])[0]).toContain("no motion role can call assignRoles");
  // a revoke on the safety modifier
  expect(problems([...good, write(safetyMod, EXIT_GOVERNANCE, "revokeTarget", [EMERGENCY, SUSDS])])[0]).toContain("no motion role can call revokeTarget");
  // a write on one modifier through another
  expect(problems([...good, { ...write(safetyMod, EXIT_GOVERNANCE, "scopeTarget", [EMERGENCY, WETH]), modifier: opMod }])[0]).toContain("through the Clutch operator modifier");
  // a modifier that is not the vault's
  expect(problems([...good, { ...good[0], modifier: STRANGER }])[0]).toContain("none of the vault's modifiers");
  // data that is no call of the modifier
  expect(problems([...good, { modifier: ordersMod, role: GOVERNANCE, to: ordersMod, data: "0xdeadbeef" }])[0]).toContain("no call of the Roles modifier");
  // the factory's limits
  expect(problems([])[0]).toBe("the motion has no write");
  const many = Array.from({ length: MAX_WRITES + 1 }, () => good[0]);
  expect(problems(many)[0]).toContain(`at most ${MAX_WRITES}`);
});

test("an action passes only if the motion's author declared it", () => {
  const good = example();
  const erc20 = new Interface(["function approve(address spender, uint256 amount)"]);
  const action: Write = { modifier: ordersMod, role: key("approvals"), to: WETH, data: lower(erc20.encodeFunctionData("approve", [STRANGER, 1])) };

  const undeclared = checkMotion(base, head, [...good, action]);
  expect(undeclared.ok).toBe(false);
  expect(undeclared.actions).toEqual([action]);
  expect(undeclared.problems[0]).toContain("an action is not declared");

  const declared = checkMotion(base, head, [...good, action], [action]);
  expect(declared.ok).toBe(true);
  expect(declared.actions).toEqual([action]);

  // a declared action that the motion does not carry, and the same action twice
  expect(checkMotion(base, head, good, [action]).problems).toEqual(["1 declared action(s) are not in the motion"]);
  expect(checkMotion(base, head, [...good, action, action], [action]).ok).toBe(false);
});
