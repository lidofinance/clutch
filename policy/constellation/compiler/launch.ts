// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The onboarding motion of each launch protocol, and the motion that takes a token out of the order lists
 * (ADR 006, decision 13; ADR 013).
 *
 * The enabling vote writes the whole launch policy, so no motion onboards a launch protocol at launch. These
 * motions show that a motion can: each turns the policy without one protocol into the committed policy, with the
 * operator's permissions, the budget, and the emergency exits through the exit-governance role. A new protocol of
 * the same form joins by the same writes, and a launch protocol that a DAO vote removed comes back by them.
 *
 *   bun compiler/launch.ts list              each protocol's motion, and what no motion can write
 *   bun compiler/launch.ts write [--check]   the committed files that the fork suite enacts
 *
 * A part of a protocol that no motion role can write stays in the policy that the motion starts from, and the
 * command lists it: only a DAO vote gives it.
 *
 * The retirement of a token is an example policy change: USDS leaves the operator's order lists. No decision
 * retires USDS.
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, Interface } from "ethers";
import { Clearance, rolesAbi } from "zodiac-roles-sdk";
import type { Artifact } from "./compile";
import { checkMotion, planMotion, render } from "./motion";
import type { PlannedWrite, Source } from "./motion";

const ROOT = path.resolve(import.meta.dir, "..");
const ROLES = new Interface(rolesAbi as any);
export const LAUNCH_FORMAT = "clutch.launch-onboarding/1";
export const LAUNCH_NETWORK = "rehearsal-26249900";
export const LAUNCH_FILE = path.join(ROOT, "artifacts", `launch-onboarding-${LAUNCH_NETWORK}.json`);
export const RETIRE_FILE = path.join(ROOT, "artifacts", `motion-retire-example-${LAUNCH_NETWORK}.json`);

type Modifier = Artifact["modifiers"][number];
type Role = Modifier["roles"][number];
type Target = Role["targets"][number];
type Fn = Target["functions"][number];
const lower = (value: string) => value.toLowerCase();
const clone = <T>(value: T) => JSON.parse(JSON.stringify(value)) as T;

// ---------------------------------------------------------------------------------------------------------------
// The launch protocols, as parts of the compiled policy
// ---------------------------------------------------------------------------------------------------------------

/** One function permission of the policy, by the names that the artifact gives. */
export type Part = { modifier: string; role: string; target: string; signature: string };
export type Protocol = { key: string; name: string; parts: Part[]; budgets: string[] };

const APPROVE = "approve(address,uint256)";
const TRANSFER = "transfer(address,uint256)";
const operator = (target: string, ...signatures: string[]): Part[] =>
  signatures.map((signature) => ({ modifier: "operator_modifier", role: "operator", target, signature }));
const emergency = (target: string, ...signatures: string[]): Part[] =>
  signatures.map((signature) => ({ modifier: "safety_modifier", role: "emergency", target, signature }));

/** An Earn vault: the asset's approval to the deposit queue, the two queues, and the share's way to the Agent. */
const earn = (key: string, name: string, asset: string, deposit: string, redeem: string, share: string, budget: string): Protocol => ({
  key,
  name,
  parts: [
    ...operator(asset, APPROVE),
    ...operator(deposit, "deposit(uint224,address,bytes32[])", "cancelDepositRequest()", "claim(address)"),
    ...operator(redeem, "redeem(uint256)", "claim(address,uint32[])"),
    ...emergency(asset, APPROVE),
    ...emergency(deposit, "cancelDepositRequest()", "claim(address)"),
    ...emergency(redeem, "redeem(uint256)", "claim(address,uint32[])"),
    ...emergency(share, TRANSFER),
  ],
  budgets: [budget],
});

/**
 * The protocols of the launch policy on the Asset Safe (ADR 011). Each owns whole function permissions of the
 * operator and of the emergency role, and its budgets. A token's transfers belong to no protocol: they fund the
 * orders account and return assets to the Aragon Agent.
 */
export const LAUNCH_PROTOCOLS: Protocol[] = [
  {
    key: "lido",
    name: "Lido staking: stake ETH, and wrap and unwrap stETH",
    parts: [
      ...operator("stETH", "submit(address)", APPROVE),
      ...operator("wstETH", "wrap(uint256)", "unwrap(uint256)"),
      ...emergency("stETH", "submit(address)", APPROVE),
      ...emergency("wstETH", "unwrap(uint256)"),
    ],
    budgets: [],
  },
  {
    key: "weth",
    name: "WETH: wrap and unwrap ETH",
    parts: [...operator("WETH", "deposit()", "withdraw(uint256)"), ...emergency("WETH", "withdraw(uint256)")],
    budgets: [],
  },
  {
    key: "sky",
    name: "Sky: the DAI–USDS converter and sUSDS savings",
    parts: [
      ...operator("DAI", APPROVE),
      ...operator("USDS", APPROVE),
      ...operator("DAI–USDS converter", "daiToUsds(address,uint256)", "usdsToDai(address,uint256)"),
      ...operator("sUSDS", "deposit(uint256,address)", "redeem(uint256,address,address)", "withdraw(uint256,address,address)"),
      ...emergency("DAI", APPROVE),
      ...emergency("USDS", APPROVE),
      ...emergency("sUSDS", "redeem(uint256,address,address)", "withdraw(uint256,address,address)", TRANSFER),
    ],
    budgets: ["sky_savings_usds"],
  },
  earn("earnUsd", "Lido earnUSD: deposit USDC and redeem", "USDC", "earnUSD USDC deposit queue", "earnUSD redeem queue", "earnUSD share", "earn_usd_deposit"),
  earn("earnEth", "Lido earnETH: deposit wstETH and redeem", "wstETH", "earnETH wstETH deposit queue", "earnETH redeem queue", "earnETH share", "earn_eth_deposit_wsteth"),
];

// ---------------------------------------------------------------------------------------------------------------
// A policy without some of its parts
// ---------------------------------------------------------------------------------------------------------------

function find(policy: Artifact, part: Part): { modifier: Modifier; role: Role; target: Target; fn: Fn } {
  const modifier = policy.modifiers.find((m) => m.ref === part.modifier);
  const role = modifier?.roles.find((r) => r.name === part.role);
  const target = role?.targets.find((t) => t.name === part.target);
  const fn = target?.functions.find((f) => f.signature === part.signature);
  if (!modifier || !role || !target || !fn) throw new Error(`the policy holds no ${words(part)}`);
  return { modifier, role, target, fn };
}

export const words = (part: Part) => `${part.signature} on ${part.target} for the role ${part.role}`;

/**
 * The calls that apply a policy to new modifiers, in the compiler's order: each budget, then each role's members,
 * targets and functions. The fork suite applies a policy by these calls, so a changed policy needs them again.
 */
export function callsOf(policy: Artifact): Artifact["calls"] {
  const calls = { to: [] as string[], data: [] as string[], fn: [] as string[] };
  const emit = (to: string, fn: string, args: unknown[]) => {
    calls.to.push(to);
    calls.data.push(ROLES.encodeFunctionData(fn, args));
    calls.fn.push(fn);
  };
  for (const modifier of policy.modifiers) {
    for (const a of modifier.allowances) emit(modifier.address, "setAllowance", [a.key, a.balance, a.maxRefill, a.refill, a.period, a.timestamp]);
    for (const role of modifier.roles) {
      for (const member of role.members) emit(modifier.address, "assignRoles", [member.address, [role.key], [true]]);
      for (const target of role.targets) {
        if (target.clearance === Clearance.Target) emit(modifier.address, "allowTarget", [role.key, target.address, target.executionOptions]);
        else emit(modifier.address, "scopeTarget", [role.key, target.address]);
        for (const fn of target.functions) {
          if (fn.wildcarded) emit(modifier.address, "allowFunction", [role.key, target.address, fn.selector, fn.executionOptions]);
          else emit(modifier.address, "scopeFunction", [role.key, target.address, fn.selector, fn.conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue]), fn.executionOptions]);
        }
      }
    }
  }
  return calls;
}

/**
 * The policy without the named parts and budgets. A target that keeps no function goes with its last function.
 * `calls` false leaves the artifact's calls as they are, for a policy that is only compared.
 */
export function without(policy: Artifact, parts: Part[], budgets: string[], calls = true): Artifact {
  const out = clone(policy);
  for (const part of parts) {
    const { role, target, fn } = find(out, part);
    target.functions.splice(target.functions.indexOf(fn), 1);
    if (target.functions.length === 0) role.targets.splice(role.targets.indexOf(target), 1);
  }
  for (const name of budgets) {
    const modifier = out.modifiers.find((m) => m.allowances.some((a) => a.name === name));
    if (!modifier) throw new Error(`the policy holds no budget ${name}`);
    modifier.allowances = modifier.allowances.filter((a) => a.name !== name);
  }
  if (calls) out.calls = callsOf(out);
  return out;
}

/**
 * The calls by which the owner of each modifier takes the parts and the budgets out of a deployed policy, as a
 * DAO vote would: a revoke of each function, a revoke of each target that keeps none, and each budget set to
 * zero. The fork suite runs them to reach the policy that a motion starts from.
 */
export function removalCalls(policy: Artifact, parts: Part[], budgets: string[]): { to: string[]; data: string[] } {
  const calls = { to: [] as string[], data: [] as string[] };
  const after = without(policy, parts, budgets, false);
  for (const part of parts) {
    const { modifier, role, target, fn } = find(policy, part);
    calls.to.push(modifier.address);
    calls.data.push(ROLES.encodeFunctionData("revokeFunction", [role.key, target.address, fn.selector]));
    const kept = after.modifiers.find((m) => m.ref === part.modifier)!.roles.find((r) => r.name === part.role)!.targets.some((t) => t.name === part.target);
    const revoke = ROLES.encodeFunctionData("revokeTarget", [role.key, target.address]);
    if (!kept && !calls.data.includes(revoke)) {
      calls.to.push(modifier.address);
      calls.data.push(revoke);
    }
  }
  for (const name of budgets) {
    const modifier = policy.modifiers.find((m) => m.allowances.some((a) => a.name === name))!;
    calls.to.push(modifier.address);
    calls.data.push(ROLES.encodeFunctionData("setAllowance", [modifier.allowances.find((a) => a.name === name)!.key, 0, 0, 0, 0, 0]));
  }
  return calls;
}

// ---------------------------------------------------------------------------------------------------------------
// The onboarding motion of a protocol
// ---------------------------------------------------------------------------------------------------------------

export type Onboarding = {
  protocol: Protocol;
  /** The policy that the motion starts from: the launch policy without what the motion writes. */
  base: Artifact;
  writes: PlannedWrite[];
  /** The parts of the protocol that no motion role can write, each with the reason. They stay in the base policy. */
  stays: { part: Part; why: string }[];
  /** The owner's calls that turn the launch policy into the base policy. */
  removal: { to: string[]; data: string[] };
};

/**
 * The motion that onboards `protocol`: from the policy without the protocol's parts that a motion can write, to
 * `policy`. A part is one that no motion can write if the motion from the policy without it needs a vote.
 */
export function onboarding(policy: Artifact, protocol: Protocol): Onboarding {
  const stays: Onboarding["stays"] = [];
  for (const part of protocol.parts) {
    const alone = planMotion(without(policy, [part], [], false), policy);
    if (alone.needsVote.length > 0) stays.push({ part, why: alone.needsVote.join("; ") });
  }
  const parts = protocol.parts.filter((part) => !stays.some((s) => s.part === part));
  const base = without(policy, parts, protocol.budgets);
  const plan = planMotion(base, policy);
  if (plan.needsVote.length > 0) throw new Error(`${protocol.key}: the motion needs a vote: ${plan.needsVote.join("; ")}`);
  const verdict = checkMotion(base, policy, plan.writes);
  if (!verdict.ok) throw new Error(`${protocol.key}: the motion fails its check: ${[...verdict.problems, ...verdict.differences].join("; ")}`);
  return { protocol, base, writes: plan.writes, stays, removal: removalCalls(policy, parts, protocol.budgets) };
}

/**
 * The function permissions of the operator on the operator modifier, and of the emergency role on the safety
 * modifier, that belong to no launch protocol. The tests hold this list to the tokens' transfers and the emergency
 * role's stop of the operator, so a new permission must join a protocol or this list's rule.
 */
export function outside(policy: Artifact): Part[] {
  const owned = new Set(LAUNCH_PROTOCOLS.flatMap((p) => p.parts.map(words)));
  const out: Part[] = [];
  for (const [modifier, role] of [["operator_modifier", "operator"], ["safety_modifier", "emergency"]] as const) {
    const r = policy.modifiers.find((m) => m.ref === modifier)!.roles.find((x) => x.name === role)!;
    for (const target of r.targets) {
      for (const fn of target.functions) {
        const part = { modifier, role, target: target.name ?? target.address, signature: fn.signature ?? fn.selector };
        if (!owned.has(words(part))) out.push(part);
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// The retirement of an order token
// ---------------------------------------------------------------------------------------------------------------

/** The example's token: USDS leaves the operator's order lists. No decision retires it. */
export const RETIRED_EXAMPLE = { name: "USDS", budget: "orders_usds" };

/** A flat condition tree without the leaves that pin `value` under an Or, with the parents numbered again. */
export function withoutLeaves(conditions: Fn["conditions"], value: string): Fn["conditions"] {
  const OR = 2;
  const EQUAL_TO = 16;
  const gone = conditions.flatMap((node, i) => (node.operator === EQUAL_TO && lower(node.compValue) === lower(value) && conditions[node.parent].operator === OR ? [i] : []));
  if (gone.length === 0) throw new Error("the tree does not list the token");
  for (const parent of new Set(gone.map((i) => conditions[i].parent))) {
    const left = conditions.filter((node, i) => i !== parent && node.parent === parent && !gone.includes(i)).length;
    if (left < 2) throw new Error("a list would keep fewer than two tokens, and the compiler writes such a list in another form");
  }
  const shift = (index: number) => index - gone.filter((i) => i < index).length;
  return conditions.filter((_, i) => !gone.includes(i)).map((node) => ({ ...node, parent: shift(node.parent) }));
}

/**
 * The policy `base` after the token leaves the operator's order lists, as the constellation compiles it when the
 * token moves from `ORDER_TOKENS` to `RETIRED_ORDER_TOKENS`, loses its funding, and has a budget of zero:
 *
 * - on the orders account, the operator's signer orders and TWAP orders list the token on neither side;
 * - on the Asset Safe, the operator's transfer of the token goes to the Aragon Agent only, and the token's orders
 *   budget is zero. The budget keeps its key: the governance role's policy lists the launch keys.
 *
 * The rest stays: the operator's return of the token from the orders account, the relayer's approval, the
 * emergency role's recovery orders and transfers, and the token's exit on the Asset Safe.
 */
export function retired(base: Artifact, token = RETIRED_EXAMPLE): Artifact {
  const head = clone(base);
  const role = (ref: string, name: string) => head.modifiers.find((m) => m.ref === ref)!.roles.find((r) => r.name === name)!;
  const address = role("operator_modifier", "operator").targets.find((t) => t.name === token.name)?.address;
  if (!address) throw new Error(`the operator holds no ${token.name}`);
  const pinned = AbiCoder.defaultAbiCoder().encode(["address"], [address]);

  const orders = role("orders_modifier", "operator");
  for (const [target, start] of [["CoW order signer", "signOrder("], ["ComposableCoW", "createWithContext("]] as const) {
    const fn = orders.targets.find((t) => t.name === target)!.functions.find((f) => f.signature?.startsWith(start))!;
    fn.conditions = withoutLeaves(fn.conditions, pinned);
  }

  // the transfer to the Aragon Agent alone, in the form of the emergency role's transfer of an Earn share
  const toAgent = role("safety_modifier", "emergency").targets.find((t) => t.name === "earnUSD share")!.functions.find((f) => f.signature === TRANSFER)!;
  const transfer = role("operator_modifier", "operator").targets.find((t) => t.name === token.name)!.functions.find((f) => f.signature === TRANSFER)!;
  transfer.conditions = clone(toAgent.conditions);

  // the budget keeps its key, because the governance role's own policy lists the launch keys, and no motion
  // writes that role's policy
  const budget = head.modifiers.find((m) => m.ref === "operator_modifier")!.allowances.find((a) => a.name === token.budget);
  if (!budget) throw new Error(`the policy holds no budget ${token.budget}`);
  budget.balance = budget.maxRefill = budget.refill = "0";
  head.calls = callsOf(head);
  return head;
}

// ---------------------------------------------------------------------------------------------------------------
// The committed files
// ---------------------------------------------------------------------------------------------------------------

function committed(): Source {
  const ref = `artifacts/${LAUNCH_NETWORK}.json`;
  const text = readFileSync(path.join(ROOT, ref), "utf8");
  return { ref, commit: null, sha256: createHash("sha256").update(text).digest("hex"), text, policy: JSON.parse(text) as Artifact };
}

/** The file of the launch protocols' onboarding motions, at a new factory: counter and policy version zero. */
export function launchFile(): string {
  const head = committed();
  const protocols: Record<string, unknown> = {};
  for (const protocol of LAUNCH_PROTOCOLS) {
    const { base, writes, stays, removal } = onboarding(head.policy, protocol);
    const text = JSON.stringify(base, null, 2) + "\n";
    const from: Source = { ref: `the policy without ${protocol.key}`, commit: null, sha256: createHash("sha256").update(text).digest("hex"), text, policy: base };
    const motion = JSON.parse(render(from, head, 0n, 0n, writes, []));
    protocols[protocol.key] = {
      name: protocol.name,
      baseSha256: from.sha256,
      stays: stays.map(({ part, why }) => ({ part: words(part), why })),
      removal,
      writes: motion.writes.map((w: PlannedWrite) => w.about),
      calldata: motion.calldata,
    };
  }
  return JSON.stringify({ format: LAUNCH_FORMAT, network: LAUNCH_NETWORK, policy: { ref: head.ref, sha256: head.sha256 }, epoch: "0", policyVersion: "0", protocols }, null, 2) + "\n";
}

/** The motion file of the example retirement, from the committed artifact, at a new factory. */
export function retireFile(): string {
  const base = committed();
  const policy = retired(base.policy);
  const text = JSON.stringify(policy, null, 2) + "\n";
  const head: Source = { ref: "compiler/launch.ts", commit: null, sha256: createHash("sha256").update(text).digest("hex"), text, policy };
  const plan = planMotion(base.policy, policy);
  if (plan.needsVote.length > 0) throw new Error(`the retirement needs a vote: ${plan.needsVote.join("; ")}`);
  const verdict = checkMotion(base.policy, policy, plan.writes);
  if (!verdict.ok) throw new Error(`the retirement fails its check: ${[...verdict.problems, ...verdict.differences].join("; ")}`);
  return render(base, head, 0n, 0n, plan.writes, []);
}

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  if (command === "list") {
    const policy = committed().policy;
    for (const protocol of LAUNCH_PROTOCOLS) {
      const { writes, stays } = onboarding(policy, protocol);
      console.log(`${protocol.key}: ${protocol.name}`);
      console.log(`  one motion of ${writes.length} writes`);
      for (const write of writes) console.log(`    ${write.about}`);
      for (const { part, why } of stays) console.log(`  no motion writes ${words(part)}: ${why}`);
    }
    return 0;
  }
  if (command === "write") {
    let ok = true;
    for (const [file, text] of [[LAUNCH_FILE, launchFile()], [RETIRE_FILE, retireFile()]] as const) {
      const name = path.relative(ROOT, file);
      if (rest.includes("--check")) {
        const same = existsSync(file) && readFileSync(file, "utf8") === text;
        console.log(same ? `${name} matches a fresh build.` : `${name} differs from a fresh build. Run \`just regen\`.`);
        ok &&= same;
      } else {
        writeFileSync(file, text);
        console.log(`wrote ${name}`);
      }
    }
    return ok ? 0 : 1;
  }
  console.error("usage: launch.ts list | write [--check]");
  return 2;
}

if (import.meta.main) process.exit(await main(process.argv.slice(2)));
