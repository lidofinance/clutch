// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests of the `motion` command and its checker (ADR 013). The expected calls are encoded here from their
// signatures, apart from the command's own encoder.
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, encodeBytes32String, Interface } from "ethers";
import type { Artifact } from "./compile";
import { checkZeroing } from "./compile";
import { acceptedByRole, checkMotion, decodeMotion, encodeMotion, EXAMPLE_MOTION, exampleMotion, MAX_WRITES, pinnedKeys, planMotion } from "./motion";
import type { Write } from "./motion";
import { derivedKey, EXAMPLE_EARN_USD_BUDGET, EXAMPLE_VAULT, EXAMPLE_WETH_BUDGET, exampleFund, exampleHead, FUND_CAP, FUND_PAYOUT, USDT, WETH } from "./motion.example";

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
// through the exit-governance role, the zeroing of the new approval among them.
test("the example onboarding is these eleven writes, in this order", () => {
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
    // the new approval's zeroing, for any spender: the emergency role can take the approval away
    write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, WETH, APPROVE, [node(0, 5, 5), node(0, 1, 0), node(0, 1, 16, AbiCoder.defaultAbiCoder().encode(["uint256"], [0]))], 0]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeTarget", [EMERGENCY, EXAMPLE_VAULT]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, EXAMPLE_VAULT, REDEEM, avatarReceiverAndOwner, 0]),
    write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, EXAMPLE_VAULT, TRANSFER, [node(0, 5, 5), node(0, 1, 16, address32(AGENT))], 0]),
  ];
  const plan = planMotion(base, head);
  expect(plan.needsVote).toEqual([]);
  expect(strip(plan.writes)).toEqual(expected);
  expect(checkMotion(base, head, expected)).toMatchObject({ ok: true, problems: [], differences: [], actions: [] });
});

// ADR 014, decision 6: a fund is the insurance role's transfer, pinned to the payout address, and a cap that never
// refills, both written by the insurance-governance role.
test("a fund with a fixed payout address is three writes of the insurance-governance role", () => {
  const fund = exampleFund(base);
  const flMod = modifierOf(base, "first_loss_modifier").address;
  const cap = derivedKey(USDT, FUND_PAYOUT);
  const plan = planMotion(base, fund);
  expect(plan.needsVote).toEqual([]);
  expect(strip(plan.writes)).toEqual([
    write(flMod, key("insurance-governance"), "setAllowance", [cap, String(FUND_CAP), 0, 0, 0, 0]),
    write(flMod, key("insurance-governance"), "scopeTarget", [key("insurance"), USDT]),
    write(flMod, key("insurance-governance"), "scopeFunction", [key("insurance"), USDT, TRANSFER, [node(0, 5, 5), node(0, 1, 16, address32(FUND_PAYOUT)), node(0, 1, 28, cap)], 0]),
  ]);
  expect(checkMotion(base, fund, strip(plan.writes))).toMatchObject({ ok: true, problems: [], differences: [], notes: [] });
  // a cap that refills is no fund: the role's policy refuses it
  const refills = exampleFund(base);
  modifierOf(refills, "first_loss_modifier").allowances.find((a) => a.name === "fund_usdt_example")!.refill = "1";
  expect(planMotion(base, refills).needsVote[0]).toContain("the policy of the role insurance-governance refuses this write");
});

// ADR 005, decision 34: an onboarding that gives the operator an approval of a new token also gives the emergency
// role its zeroing. The compiler's rule holds for the example's policy, and fails without the zeroing.
test("the example onboarding keeps the rule that the emergency role can zero every operator approval", () => {
  expect(() => checkZeroing(head.modifiers, head.manifest as Record<string, any>)).not.toThrow();
  const without = clone(head);
  const weth = roleOf(without, "safety_modifier", "emergency").targets.find((t) => lower(t.address) === lower(WETH))!;
  weth.functions = weth.functions.filter((f) => f.signature !== "approve(address,uint256)");
  expect(() => checkZeroing(without.modifiers, without.manifest as Record<string, any>)).toThrow("the operator can approve WETH, and the emergency role cannot set that approval to zero");
});

test("the committed example motion equals a fresh build", () => {
  expect(readFileSync(EXAMPLE_MOTION, "utf8")).toBe(exampleMotion());
  const file = JSON.parse(exampleMotion());
  expect(decodeMotion(file.calldata).writes.length).toBe(11);
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
  // the modifier scopes a target without execution options, so a scoped target cannot get any
  expect(reasons((p) => (targetOf(p, "operator_modifier", "operator", SUSDS).executionOptions = 1))[0]).toContain("as a scoped target with execution options");
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
  const noExit = checkMotion(base, head, good.slice(0, 10));
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

  // a call that may send ETH in place of a plain call: the role's policy accepts it, and the head policy does not hold it
  const send = clone(good);
  send[4] = write(opMod, GOVERNANCE, "scopeFunction", [OPERATOR, EXAMPLE_VAULT, DEPOSIT, [node(0, 5, 5), node(0, 1, 0), node(0, 1, 15)], 1]);
  const sends = checkMotion(base, head, send);
  expect(sends.problems).toEqual([]);
  expect(sends.differences).toEqual(["Clutch operator modifier, role operator: deposit(uint256,address) on example ERC-4626 vault has other conditions or other execution options"]);

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

// The guards of each motion role (ADR 006, decisions 8 to 10 and 13; ADR 007, decision 44; ADR 009, decision 15;
// ADR 014, decision 6; INV-004, INV-012, INV-025, INV-040). The check evaluates the role's condition tree on the
// whole call. The fork suite compares these answers with the deployed modifier's (`just round-trip`).
test("the check evaluates the motion role's policy on the whole call", () => {
  const answer = (ref: string, role: string, fn: string, args: unknown[]) => {
    const modifier = modifierOf(base, ref);
    return acceptedByRole(base, modifier, key(role), modifier.address, lower(ROLES.encodeFunctionData(fn, args)));
  };
  const WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
  const any = [node(0, 5, 5), node(0, 1, 0), node(0, 1, 0)];
  const assetSafe = base.manifest.assetSafe as string;
  const derived = derivedKey(WBTC, STRANGER);
  const op = "operator_modifier";

  // a budget: the refill period is at least 30 days, and the key is a launch key or starts with "k:"
  expect(answer(op, "governance", "setAllowance", [key("earn_usd_deposit"), 1, 1, 1, MONTH, 0])).toBe(true);
  expect(answer(op, "governance", "setAllowance", [key("earn_usd_deposit"), 1, 1, 1, MONTH - 1, 0])).toBe(false);
  expect(answer(op, "governance", "setAllowance", [key("earn_usd_deposit"), 1, 1, 1, 0, 0])).toBe(false);
  expect(answer(op, "governance", "setAllowance", [key("foreign"), 1, 1, 1, MONTH, 0])).toBe(false);
  expect(answer(op, "governance", "setAllowance", [derived, 1, 1, 1, MONTH, 0])).toBe(true);
  expect(answer(op, "governance", "setAllowance", ["0x00" + derived.slice(2, 64), 1, 1, 1, MONTH, 0])).toBe(false);

  // a permission: only under the operator's key, never on a vault account or a modifier, never a delegatecall
  expect(answer(op, "governance", "scopeTarget", [OPERATOR, WBTC])).toBe(true);
  expect(answer(op, "governance", "scopeTarget", [EMERGENCY, WBTC])).toBe(false);
  expect(answer(op, "governance", "scopeTarget", [GOVERNANCE, WBTC])).toBe(false);
  for (const account of [assetSafe, opMod, safetyMod, ordersMod, base.manifest.ordersAccount as string]) {
    expect(answer(op, "governance", "scopeTarget", [OPERATOR, account])).toBe(false);
    expect(answer(op, "governance", "scopeFunction", [OPERATOR, account, TRANSFER, any, 0])).toBe(false);
    expect(answer(op, "governance", "allowFunction", [OPERATOR, account, TRANSFER, 0])).toBe(false);
  }
  expect(answer(op, "governance", "scopeFunction", [OPERATOR, WBTC, TRANSFER, any, 0])).toBe(true);
  expect(answer(op, "governance", "scopeFunction", [OPERATOR, WBTC, TRANSFER, any, 1])).toBe(true);
  expect(answer(op, "governance", "scopeFunction", [OPERATOR, WBTC, TRANSFER, any, 2])).toBe(false);
  expect(answer(op, "governance", "scopeFunction", [OPERATOR, WBTC, TRANSFER, any, 3])).toBe(false);
  expect(answer(op, "governance", "allowFunction", [OPERATOR, WBTC, TRANSFER, 2])).toBe(false);
  expect(answer(op, "governance", "revokeTarget", [OPERATOR, SUSDS])).toBe(true);
  expect(answer(op, "governance", "revokeTarget", [EMERGENCY, SUSDS])).toBe(false);
  // no membership, and no write by a role that holds no such grant
  expect(answer(op, "governance", "assignRoles", [STRANGER, [OPERATOR], [true]])).toBe(false);
  expect(answer(op, "insurance-funding", "scopeTarget", [OPERATOR, WBTC])).toBe(false);
  expect(answer(op, "operator", "scopeTarget", [OPERATOR, WBTC])).toBe(false);

  // exit governance: only the emergency role's exits, each tree pinned whole
  const sf = "safety_modifier";
  const toAgent = [node(0, 5, 5), node(0, 1, 16, address32(AGENT))];
  const toStranger = [node(0, 5, 5), node(0, 1, 16, address32(STRANGER))];
  expect(answer(sf, "exit-governance", "scopeTarget", [EMERGENCY, WBTC])).toBe(true);
  expect(answer(sf, "exit-governance", "scopeTarget", [OPERATOR, WBTC])).toBe(false);
  expect(answer(sf, "exit-governance", "scopeTarget", [EMERGENCY, assetSafe])).toBe(false);
  expect(answer(sf, "exit-governance", "scopeFunction", [EMERGENCY, WBTC, TRANSFER, toAgent, 0])).toBe(true);
  expect(answer(sf, "exit-governance", "scopeFunction", [EMERGENCY, WBTC, TRANSFER, toStranger, 0])).toBe(false);
  expect(answer(sf, "exit-governance", "scopeFunction", [EMERGENCY, WBTC, TRANSFER, any, 0])).toBe(false);
  expect(answer(sf, "exit-governance", "scopeFunction", [EMERGENCY, WBTC, TRANSFER, toAgent, 1])).toBe(false);
  expect(answer(sf, "exit-governance", "scopeFunction", [EMERGENCY, WBTC, APPROVE, toAgent, 0])).toBe(false);
  expect(answer(sf, "exit-governance", "allowFunction", [EMERGENCY, WBTC, TRANSFER, 0])).toBe(false);
  expect(answer(sf, "exit-governance", "revokeTarget", [EMERGENCY, SUSDS])).toBe(false);
  expect(answer(sf, "exit-governance", "setAllowance", [derived, 1, 1, 1, MONTH, 0])).toBe(false);

  // the orders modifier: its three keys, never its own key, and the relayer approval pinned whole
  const relayer = targetOf(base, "orders_modifier", "approvals", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48").functions[0].conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue]);
  expect(answer("orders_modifier", "governance", "scopeTarget", [OPERATOR, WBTC])).toBe(true);
  expect(answer("orders_modifier", "governance", "scopeTarget", [key("approvals"), WBTC])).toBe(true);
  expect(answer("orders_modifier", "governance", "scopeTarget", [GOVERNANCE, WBTC])).toBe(false);
  expect(answer("orders_modifier", "governance", "scopeFunction", [key("approvals"), WBTC, APPROVE, relayer, 0])).toBe(true);
  expect(answer("orders_modifier", "governance", "scopeFunction", [key("approvals"), WBTC, APPROVE, toStranger, 0])).toBe(false);
  expect(answer("orders_modifier", "governance", "scopeFunction", [OPERATOR, WBTC, TRANSFER, any, 2])).toBe(false);
  expect(answer("orders_modifier", "governance", "revokeTarget", [OPERATOR, WBTC])).toBe(false);

  // a fund: a cap that never refills, under a derived key, and never a first-loss share token
  const fl = "first_loss_modifier";
  const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  const earnEthShare = "0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4";
  expect(answer(fl, "insurance-governance", "setAllowance", [derived, 5, 0, 0, 0, 0])).toBe(true);
  expect(answer(fl, "insurance-governance", "setAllowance", [derived, 5, 0, 1, 0, 0])).toBe(false);
  expect(answer(fl, "insurance-governance", "setAllowance", [derived, 5, 5, 0, 0, 0])).toBe(false);
  expect(answer(fl, "insurance-governance", "setAllowance", [key("foreign"), 5, 0, 0, 0, 0])).toBe(false);
  expect(answer(fl, "insurance-governance", "scopeTarget", [key("insurance"), USDT])).toBe(true);
  expect(answer(fl, "insurance-governance", "scopeTarget", [key("insurance"), earnEthShare])).toBe(false);
  expect(answer(fl, "insurance-governance", "scopeTarget", [key("first-loss"), USDT])).toBe(false);
  expect(answer(fl, "insurance-governance", "scopeFunction", [key("insurance"), USDT, TRANSFER, toStranger, 0])).toBe(true);
  expect(answer(fl, "insurance-governance", "scopeFunction", [key("insurance"), USDT, APPROVE, toStranger, 0])).toBe(false);
  expect(answer(fl, "insurance-governance", "scopeFunction", [key("insurance"), USDT, TRANSFER, toStranger, 2])).toBe(false);

  // a call of another contract is not evaluated here
  const erc20 = new Interface(["function approve(address spender, uint256 amount)"]);
  const orders = modifierOf(base, "orders_modifier");
  expect(acceptedByRole(base, orders, key("approvals"), "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", lower(erc20.encodeFunctionData("approve", [STRANGER, 1])))).toBeNull();
});

test("a write that the role's policy refuses: the builder says that it needs a vote, and the check fails it", () => {
  // a budget with a refill period of 29 days: the governance role refuses it (ADR 009, decision 15)
  const short = clone(base);
  const budget = modifierOf(short, "operator_modifier").allowances[0];
  budget.period = String(MONTH - 24 * 60 * 60);
  const plan = planMotion(base, short);
  expect(plan.writes).toEqual([]);
  expect(plan.needsVote.length).toBe(1);
  expect(plan.needsVote[0]).toContain(`set the budget ${budget.name}`);
  expect(plan.needsVote[0]).toContain("the policy of the role governance refuses this write");
  // the same write, made by hand: the check fails it
  const byHand = [write(opMod, GOVERNANCE, "setAllowance", [budget.key, budget.balance, budget.maxRefill, budget.refill, budget.period, 0])];
  const verdict = checkMotion(base, short, byHand);
  expect(verdict.ok).toBe(false);
  expect(verdict.problems).toEqual(["write 1: the policy of the role governance refuses this call of setAllowance"]);

  // a budget under a key that is no launch key and no derived key
  const rogue = clone(base);
  modifierOf(rogue, "operator_modifier").allowances.push({ name: "rogue", key: key("rogue") as `0x${string}`, balance: "1", maxRefill: "1", refill: "1", period: String(MONTH), timestamp: "0" });
  expect(planMotion(base, rogue).writes).toEqual([]);
  expect(planMotion(base, rogue).needsVote[0]).toContain("the policy of the role governance refuses this write");

  // an exit for the emergency role that pays a stranger
  const exit = clone(head);
  const added = roleOf(exit, "safety_modifier", "emergency").targets.find((t) => lower(t.address) === lower(EXAMPLE_VAULT))!;
  added.functions.find((f) => f.selector === TRANSFER)!.conditions[1].compValue = address32(STRANGER) as `0x${string}`;
  const planned = planMotion(base, exit);
  expect(planned.writes.length).toBe(10);
  expect(planned.needsVote.length).toBe(1);
  expect(planned.needsVote[0]).toContain("the policy of the role exit-governance refuses this write");
  const tampered = example();
  tampered[9] = write(safetyMod, EXIT_GOVERNANCE, "scopeFunction", [EMERGENCY, EXAMPLE_VAULT, TRANSFER, [node(0, 5, 5), node(0, 1, 16, address32(STRANGER))], 0]);
  const bad = checkMotion(base, exit, tampered);
  expect(bad.ok).toBe(false);
  expect(bad.problems).toEqual(["write 10: the policy of the role exit-governance refuses this call of scopeFunction"]);
  // the example's writes are all evaluated: the check leaves no note
  expect(checkMotion(base, head, example()).notes).toEqual([]);
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
