// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, Interface } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import type { Artifact } from "./compile";
import { callsOf, LAUNCH_FILE, LAUNCH_PROTOCOLS, launchFile, onboarding, outside, removalCalls, RETIRE_FILE, retired, retireFile, without, withoutLeaves, words } from "./launch";
import { checkMotion, decodeMotion, MAX_WRITES, planMotion } from "./motion";

const ROOT = path.resolve(import.meta.dir, "..");
const read = (name: string) => JSON.parse(readFileSync(path.join(ROOT, "artifacts", name), "utf8")) as Artifact;
const policy = read("rehearsal-26249900.json");
const ROLES = new Interface(rolesAbi as any);
const clone = <T>(value: T) => JSON.parse(JSON.stringify(value)) as T;
const roleOf = (p: Artifact, ref: string, name: string) => p.modifiers.find((m) => m.ref === ref)!.roles.find((r) => r.name === name)!;
const fnOf = (p: Artifact, ref: string, role: string, target: string, start: string) =>
  roleOf(p, ref, role).targets.find((t) => t.name === target)!.functions.find((f) => f.signature!.startsWith(start))!;
const protocol = (key: string) => LAUNCH_PROTOCOLS.find((p) => p.key === key)!;
/** Each protocol's onboarding, built once. */
const built = new Map(LAUNCH_PROTOCOLS.map((p) => [p.key, onboarding(policy, p)]));
const of = (key: string) => built.get(key)!;
const TRANSFER = "transfer(address,uint256)";

// ---------------------------------------------------------------------------------------------------------------
// The launch protocols as parts of the policy
// ---------------------------------------------------------------------------------------------------------------

test("the calls of an artifact, built again from its modifiers, are the compiler's calls", () => {
  expect(callsOf(policy)).toEqual(policy.calls);
  const kit = read("fork-25946643.json");
  expect(callsOf(kit)).toEqual(kit.calls);
});

test("each part of a launch protocol is a permission of the policy, and no two protocols share one", () => {
  const seen = new Set<string>();
  for (const p of LAUNCH_PROTOCOLS) {
    expect(() => without(policy, p.parts, p.budgets, false)).not.toThrow();
    for (const part of p.parts) {
      expect(seen.has(words(part))).toBe(false);
      seen.add(words(part));
    }
  }
  expect(() => without(policy, [{ modifier: "operator_modifier", role: "operator", target: "stETH", signature: "burn(uint256)" }], [])).toThrow("the policy holds no burn(uint256) on stETH");
  expect(() => without(policy, [], ["no_such_budget"])).toThrow("the policy holds no budget no_such_budget");
});

// A new permission of the operator or of the emergency role on the Asset Safe must join a protocol, or be one of
// these: a token's transfer, and the emergency role's stop of the operator.
test("outside the launch protocols are only the tokens' transfers and the emergency role's stop of the operator", () => {
  const rest = outside(policy);
  const stop = rest.filter((part) => part.signature !== TRANSFER);
  expect(stop.map(words).sort()).toEqual([
    "disableModule(address,address) on Asset Safe for the role emergency",
    "revokeFunction(bytes32,address,bytes4) on operator modifier for the role emergency",
    "revokeTarget(bytes32,address) on operator modifier for the role emergency",
  ]);
  const tokens = ["stETH", "wstETH", "WETH", "USDC", "USDT", "DAI", "USDS"];
  expect(rest.filter((part) => part.signature === TRANSFER && part.role === "operator").map((part) => part.target).sort()).toEqual(tokens.filter((t) => t !== "DAI").sort());
  expect(rest.filter((part) => part.signature === TRANSFER && part.role === "emergency").map((part) => part.target).sort()).toEqual(tokens.sort());
  // every budget of the operator modifier belongs to a protocol or to the orders account
  const budgets = policy.modifiers.find((m) => m.ref === "operator_modifier")!.allowances.map((a) => a.name);
  const owned = LAUNCH_PROTOCOLS.flatMap((p) => p.budgets);
  expect(budgets.filter((name) => !owned.includes(name)).every((name) => name.startsWith("orders_"))).toBe(true);
});

// ---------------------------------------------------------------------------------------------------------------
// The onboarding motions
// ---------------------------------------------------------------------------------------------------------------

// ADR 006, decision 13: one motion onboards a protocol with its emergency exits.
test("each launch protocol is one motion: the operator's permissions, the budget and the emergency exits", () => {
  const counts: Record<string, number> = {};
  for (const p of LAUNCH_PROTOCOLS) {
    const { base, writes } = of(p.key);
    counts[p.key] = writes.length;
    expect(writes.length).toBeLessThanOrEqual(MAX_WRITES);
    expect(checkMotion(base, policy, writes)).toMatchObject({ ok: true, problems: [], differences: [] });
    // the base policy holds nothing of what the motion writes
    const back = planMotion(policy, base);
    expect(back.writes.length + back.needsVote.length).toBeGreaterThan(0);
    // the exits go through the exit-governance role, and the rest through the governance role
    const names = writes.map((w) => w.about.split(":")[0]);
    expect(new Set(names)).toEqual(new Set(["Clutch operator modifier, as governance", "Clutch safety modifier, as exit-governance"]));
  }
  expect(counts).toEqual({ lido: 5, weth: 3, sky: 15, earnUsd: 17, earnEth: 17 });
});

test("the onboarding of an Earn vault writes the budget, the approval, the two queues, and the share's way to the Agent", () => {
  const { base, writes } = of("earnUsd");
  const calls = writes.map((w) => ROLES.parseTransaction({ data: w.data })!.name);
  expect(calls.filter((name) => name === "setAllowance").length).toBe(1);
  expect(calls.filter((name) => name === "scopeTarget").length).toBe(5);
  expect(writes.some((w) => w.about.endsWith("add transfer(address,uint256) on earnUSD share for the role emergency, with 2 condition nodes"))).toBe(true);
  // without the protocol, the operator holds no queue and no approval of USDC, and the budget is gone
  const operator = roleOf(base, "operator_modifier", "operator");
  expect(operator.targets.some((t) => t.name?.startsWith("earnUSD"))).toBe(false);
  expect(operator.targets.find((t) => t.name === "USDC")!.functions.map((f) => f.signature)).toEqual([TRANSFER]);
  expect(base.modifiers.find((m) => m.ref === "operator_modifier")!.allowances.some((a) => a.name === "earn_usd_deposit")).toBe(false);
  // the other Earn vault stays whole
  expect(roleOf(base, "operator_modifier", "operator").targets.filter((t) => t.name?.startsWith("earnETH")).length).toBe(2);
});

// What only a vote gives: the exit-governance role writes an approval set to zero only for any spender, and it
// grants no call with ETH.
test("no motion writes the emergency role's zeroing in the launch form, or its staking of ETH", () => {
  const stays = Object.fromEntries(LAUNCH_PROTOCOLS.map((p) => [p.key, of(p.key).stays.map((s) => words(s.part))]));
  expect(stays).toEqual({
    lido: ["submit(address) on stETH for the role emergency", "approve(address,uint256) on stETH for the role emergency"],
    weth: [],
    sky: ["approve(address,uint256) on DAI for the role emergency", "approve(address,uint256) on USDS for the role emergency"],
    earnUsd: ["approve(address,uint256) on USDC for the role emergency"],
    earnEth: ["approve(address,uint256) on wstETH for the role emergency"],
  });
  for (const p of LAUNCH_PROTOCOLS) {
    const { base, stays: list } = of(p.key);
    for (const { part, why } of list) {
      expect(why).toContain("the policy of the role exit-governance refuses this write");
      // a part that stays is in the base policy
      expect(() => without(base, [part], [], false)).not.toThrow();
    }
  }
});

test("the owner's removal revokes each function, each target that keeps none, and sets each budget to zero", () => {
  const { removal } = of("weth");
  const calls = removal.data.map((data) => ROLES.parseTransaction({ data })!);
  expect(calls.map((c) => c.name)).toEqual(["revokeFunction", "revokeFunction", "revokeFunction"]);
  const sky = of("sky").removal;
  const names = sky.data.map((data) => ROLES.parseTransaction({ data })!.name);
  // seven permissions of the operator and three of the emergency role; the two zeroings stay
  expect(names.filter((n) => n === "revokeFunction").length).toBe(10);
  // the converter, DAI and sUSDS for the operator, and sUSDS for the emergency role, keep no function
  expect(names.filter((n) => n === "revokeTarget").length).toBe(4);
  expect(names.filter((n) => n === "setAllowance").length).toBe(1);
  const budget = ROLES.parseTransaction({ data: sky.data[sky.data.length - 1] })!;
  expect(budget.args.slice(1).map(String)).toEqual(["0", "0", "0", "0", "0"]);
  expect(removalCalls(policy, [], []).data).toEqual([]);
});

test("a protocol whose budget no motion can set is refused, with the reason", () => {
  const noBudgets = clone(policy);
  const governance = roleOf(noBudgets, "operator_modifier", "governance");
  const own = governance.targets.find((t) => t.name === "operator modifier")!;
  own.functions = own.functions.filter((f) => !f.signature!.startsWith("setAllowance("));
  expect(() => onboarding(noBudgets, protocol("sky"))).toThrow("sky: the motion needs a vote");
});

test("the committed onboarding motions equal a fresh build", () => {
  expect(readFileSync(LAUNCH_FILE, "utf8")).toBe(launchFile());
  const file = JSON.parse(launchFile());
  expect(Object.keys(file.protocols)).toEqual(["lido", "weth", "sky", "earnUsd", "earnEth"]);
  for (const p of LAUNCH_PROTOCOLS) {
    const motion = decodeMotion(file.protocols[p.key].calldata);
    expect(motion.epoch).toBe(0n);
    expect(motion.policyVersion).toBe(0n);
    expect(motion.writes.length).toBe(file.protocols[p.key].writes.length);
  }
});

// ---------------------------------------------------------------------------------------------------------------
// The retirement of an order token
// ---------------------------------------------------------------------------------------------------------------

const head = retired(policy);
const usds = roleOf(policy, "operator_modifier", "operator").targets.find((t) => t.name === "USDS")!.address;
const pinned = AbiCoder.defaultAbiCoder().encode(["address"], [usds]).toLowerCase();
const lists = (fn: { conditions: { compValue: string }[] }, value: string) => fn.conditions.filter((n) => n.compValue.toLowerCase() === value).length;

// ADR 013, decision 4: a motion takes a token out of the order lists, because it writes the order trees again
// without the token. It revokes nothing on the orders modifier.
test("the retirement of a token is four writes, and none is a revoke", () => {
  const plan = planMotion(policy, head);
  expect(plan.needsVote).toEqual([]);
  expect(plan.writes.map((w) => w.about)).toEqual([
    "Clutch operator modifier, as governance: set the budget orders_usds to 0, with a refill of 0 every 2592000 seconds",
    "Clutch operator modifier, as governance: change transfer(address,uint256) on USDS for the role operator, with 2 condition nodes",
    "Clutch orders modifier, as governance: change signOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32),uint32,uint256) on CoW order signer for the role operator, with 26 condition nodes",
    "Clutch orders modifier, as governance: change createWithContext((address,bytes32,bytes),address,bytes,bool) on ComposableCoW for the role operator, with 48 condition nodes",
  ]);
  expect(plan.writes.map((w) => ROLES.parseTransaction({ data: w.data })!.name)).toEqual(["setAllowance", "scopeFunction", "scopeFunction", "scopeFunction"]);
  expect(checkMotion(policy, head, plan.writes)).toMatchObject({ ok: true, problems: [], differences: [] });
});

test("after the retirement, the operator's order trees list the token on neither side, and the other tokens stay", () => {
  // a signer order lists the token as a sell token and as a buy token; a TWAP order does so in each of its two shapes
  expect(lists(fnOf(policy, "orders_modifier", "operator", "CoW order signer", "signOrder("), pinned)).toBe(2);
  expect(lists(fnOf(policy, "orders_modifier", "operator", "ComposableCoW", "createWithContext("), pinned)).toBe(4);
  expect(lists(fnOf(head, "orders_modifier", "operator", "CoW order signer", "signOrder("), pinned)).toBe(0);
  expect(lists(fnOf(head, "orders_modifier", "operator", "ComposableCoW", "createWithContext("), pinned)).toBe(0);
  const usdc = AbiCoder.defaultAbiCoder().encode(["address"], [roleOf(policy, "operator_modifier", "operator").targets.find((t) => t.name === "USDC")!.address]).toLowerCase();
  expect(lists(fnOf(head, "orders_modifier", "operator", "CoW order signer", "signOrder("), usdc)).toBe(2);
  expect(lists(fnOf(head, "orders_modifier", "operator", "ComposableCoW", "createWithContext("), usdc)).toBe(4);
  // every node's parent is before it, so the tree is still in the modifier's order
  for (const start of ["signOrder(", "createWithContext("]) {
    const target = start === "signOrder(" ? "CoW order signer" : "ComposableCoW";
    const tree = fnOf(head, "orders_modifier", "operator", target, start).conditions;
    expect(tree.every((n, i) => (i === 0 ? n.parent === 0 : n.parent < i))).toBe(true);
    expect(tree.map((n) => n.parent)).toEqual([...tree.map((n) => n.parent)].sort((a, b) => a - b));
  }
});

test("a tree without a token's leaves numbers the parents of the later nodes again", () => {
  const T = "0x" + "11".repeat(32);
  const other = (n: number) => "0x" + String(n).padStart(64, "0");
  const node = (parent: number, paramType: number, operator: number, compValue = "0x") => ({ parent, paramType, operator, compValue: compValue as `0x${string}` });
  // two lists under the root: the second list's node comes after the first list's leaves
  const tree = [node(0, 5, 5), node(0, 0, 2), node(0, 3, 5), node(1, 1, 16, other(1)), node(1, 1, 16, T), node(1, 1, 16, other(2)), node(2, 0, 2), node(6, 1, 16, other(3)), node(6, 1, 16, T), node(6, 1, 16, other(4))];
  expect(withoutLeaves(tree, T)).toEqual([node(0, 5, 5), node(0, 0, 2), node(0, 3, 5), node(1, 1, 16, other(1)), node(1, 1, 16, other(2)), node(2, 0, 2), node(5, 1, 16, other(3)), node(5, 1, 16, other(4))]);
  // a value that is pinned outside a list stays: only a list loses it
  const alone = [node(0, 5, 5), node(0, 1, 16, T), node(0, 0, 2), node(2, 1, 16, T), node(2, 1, 16, other(1)), node(2, 1, 16, other(2))];
  expect(withoutLeaves(alone, T)).toEqual([node(0, 5, 5), node(0, 1, 16, T), node(0, 0, 2), node(2, 1, 16, other(1)), node(2, 1, 16, other(2))]);
});

test("a retired token keeps its returns, its relayer approval, its recovery orders and its exit", () => {
  // on the Asset Safe: the transfer goes to the Aragon Agent only, and the budget is zero under the same key
  const transfer = fnOf(head, "operator_modifier", "operator", "USDS", "transfer(");
  expect(transfer.conditions).toEqual(fnOf(policy, "safety_modifier", "emergency", "earnUSD share", "transfer(").conditions);
  const budget = (p: Artifact) => p.modifiers.find((m) => m.ref === "operator_modifier")!.allowances.find((a) => a.name === "orders_usds")!;
  expect(budget(head)).toEqual({ ...budget(policy), balance: "0", maxRefill: "0", refill: "0" });
  // the governance role's policy lists the launch budget keys, so the key stays
  expect(roleOf(head, "operator_modifier", "governance")).toEqual(roleOf(policy, "operator_modifier", "governance"));
  // on the orders account: the return, the emergency role, the approvals role and the governance role are the same
  expect(fnOf(head, "orders_modifier", "operator", "USDS", "transfer(")).toEqual(fnOf(policy, "orders_modifier", "operator", "USDS", "transfer("));
  for (const role of ["emergency", "approvals", "governance"]) expect(roleOf(head, "orders_modifier", role)).toEqual(roleOf(policy, "orders_modifier", role));
  // the safety modifier and the first-loss modifier are the same
  for (const ref of ["safety_modifier", "first_loss_modifier"]) expect(head.modifiers.find((m) => m.ref === ref)).toEqual(policy.modifiers.find((m) => m.ref === ref));
});

test("a retirement that drops the token's return on the orders account needs a vote", () => {
  const dropped = clone(head);
  const operator = roleOf(dropped, "orders_modifier", "operator");
  operator.targets = operator.targets.filter((t) => t.name !== "USDS");
  const plan = planMotion(policy, dropped);
  expect(plan.needsVote.length).toBe(2);
  expect(plan.needsVote[0]).toContain("no motion role can call revokeFunction on the Clutch orders modifier");
  expect(plan.needsVote[1]).toContain("no motion role can call revokeTarget on the Clutch orders modifier");
});

test("the retirement refuses a token that the lists do not hold, and a list that would keep one token", () => {
  expect(() => retired(policy, { name: "LDO", budget: "orders_usds" })).toThrow("the operator holds no LDO");
  expect(() => retired(policy, { name: "DAI", budget: "orders_usds" })).toThrow("the tree does not list the token");
  expect(() => retired(head)).toThrow("the tree does not list the token");
  expect(() => retired(policy, { name: "USDS", budget: "orders_dai" })).toThrow("the policy holds no budget orders_dai");
  // with two tokens left on a side, a third retirement would leave one, which the compiler writes without a list
  let p = policy;
  const budgets: Record<string, string> = { USDS: "orders_usds", USDT: "orders_usdt", USDC: "orders_usdc", WETH: "orders_weth", wstETH: "orders_wsteth" };
  for (const name of ["USDS", "USDT", "USDC", "WETH"]) p = retired(p, { name, budget: budgets[name] });
  expect(() => retired(p, { name: "wstETH", budget: budgets.wstETH })).toThrow("a list would keep fewer than two tokens");
});

test("the committed retirement motion equals a fresh build", () => {
  expect(readFileSync(RETIRE_FILE, "utf8")).toBe(retireFile());
  const file = JSON.parse(retireFile());
  expect(decodeMotion(file.calldata).writes.length).toBe(4);
  expect(file.epoch).toBe("0");
  expect(file.policyVersion).toBe("0");
});
