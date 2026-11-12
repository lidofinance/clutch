// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Builds and checks a motion of the universal factory (ADR 013).
 *
 * A motion is a list of raw writes, and the factory checks no write's content. So two commands carry the review:
 *
 *   bun compiler/motion.ts build --base <ref> --head <ref> --epoch 0 --policy-version 0
 *       The writes that turn the policy artifact of <base> into the one of <head>, as the motion's calldata.
 *   bun compiler/motion.ts check --base <ref> --head <ref> --calldata 0x…
 *       Applies a motion's writes to the policy of <base> and fails unless the result is the policy of <head>.
 *
 * A <ref> is a commit, a tag or a branch, whose committed artifact the command reads, or the path of an artifact
 * file. The two commands share no logic for the comparison: `build` computes a difference, and `check` runs the
 * writes on a model of the Roles modifier and compares the outcome. `check` also evaluates the motion role's
 * condition tree on each write of a modifier on itself, and fails a write that the role's policy refuses. A
 * change that no motion role can write, such as a membership, needs a DAO vote, and `build` refuses it.
 *
 * Both commands take the chain's state to be the base artifact. They do not read the modifiers. `check` does not
 * evaluate an action, and it does not test that a submitted tree is well-formed: the modifier refuses a malformed
 * tree. The fork suite replays a pending motion on the deployed Roles code (test/MotionReplay.t.sol).
 */
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, getAddress, Interface, JsonRpcProvider } from "ethers";
import type { ParamType } from "ethers";
import { Clearance, rolesAbi } from "zodiac-roles-sdk";
import type { Artifact } from "./compile";
import { exampleHead } from "./motion.example";

export const MOTION_FORMAT = "clutch.motion/1";
/** The factory's limit on the writes of one motion. */
export const MAX_WRITES = 64;

const ROOT = path.resolve(import.meta.dir, "..");
const REPO = path.resolve(ROOT, "../..");
const ROLES = new Interface(rolesAbi as any);
const CODER = AbiCoder.defaultAbiCoder();
const MOTION_TYPES = ["uint256", "uint256", "tuple(address modifier_, bytes32 role, address to, bytes data)[]"];
const FACTORY = new Interface(["function epoch() view returns (uint256)", "function policyVersion() view returns (uint256)"]);

/** The Roles operators and parameter types that the role-key check reads. */
const OR = 2;
const MATCHES = 5;
const EQUAL_TO = 16;
const CALLDATA = 5;

/** One call that the factory makes through a modifier, as a motion role. */
export type Write = { modifier: string; role: string; to: string; data: string };
/** A write with what it does, for a reader. */
export type PlannedWrite = Write & { about: string };
type Modifier = Artifact["modifiers"][number];
type Role = Modifier["roles"][number];
type Cond = { parent: number; paramType: number; operator: number; compValue: string };
type Fn = { wildcarded: boolean; executionOptions: number; conditions: Cond[] };
type Allowance = { balance: string; maxRefill: string; refill: string; period: string; timestamp: string };

const lower = (value: string) => value.toLowerCase();
const same = (x: string, y: string) => lower(x) === lower(y);
const selectorOf = (fn: string) => ROLES.getFunction(fn)!.selector;

// ---------------------------------------------------------------------------------------------------------------
// The motion's calldata
// ---------------------------------------------------------------------------------------------------------------

/** The calldata of a motion: the counter and the policy version that it read, and its writes. */
export function encodeMotion(epoch: bigint, policyVersion: bigint, writes: Write[]): string {
  return CODER.encode(MOTION_TYPES, [epoch, policyVersion, writes.map((w) => [w.modifier, w.role, w.to, w.data])]);
}

export function decodeMotion(calldata: string): { epoch: bigint; policyVersion: bigint; writes: Write[] } {
  const [epoch, policyVersion, writes] = CODER.decode(MOTION_TYPES, calldata);
  return {
    epoch,
    policyVersion,
    writes: (writes as any[]).map((w) => ({ modifier: getAddress(w[0]), role: lower(w[1]), to: getAddress(w[2]), data: lower(w[3]) })),
  };
}

// ---------------------------------------------------------------------------------------------------------------
// Which motion role makes a write
// ---------------------------------------------------------------------------------------------------------------

/**
 * The role keys that a grant of a motion role lets it write under: the values of the call's first argument. Null
 * if the grant's tree has a form that this cannot read, or pins no key.
 */
export function pinnedKeys(fn: Fn): string[] | null {
  const c = fn.conditions;
  if (fn.wildcarded || c.length === 0) return null;
  const kids = (index: number) => c.flatMap((node, i) => (i !== index && node.parent === index ? [i] : []));
  const branches = c[0].operator === MATCHES ? [0] : c[0].operator === OR ? kids(0) : [];
  if (branches.length === 0) return null;
  const keys: string[] = [];
  for (const branch of branches) {
    if (c[branch].paramType !== CALLDATA || c[branch].operator !== MATCHES) return null;
    const first = kids(branch)[0];
    if (first === undefined) return null;
    const leaves = c[first].operator === OR ? kids(first) : [first];
    for (const leaf of leaves) {
      if (c[leaf].operator !== EQUAL_TO) return null;
      keys.push(lower(c[leaf].compValue));
    }
  }
  return keys;
}

/**
 * The motion role that can make `fn` on `modifier`, under `writtenKey` for a permission write. The universal
 * factory is its only member, and its policy lets it call `fn` on the modifier itself. An error message otherwise.
 */
function motionRole(policy: Artifact, modifier: Modifier, fn: string, writtenKey: string | null): Role | string {
  const factory = policy.manifest.universalFactory as string;
  const selector = selectorOf(fn);
  const grants = modifier.roles.flatMap((role) => {
    if (role.members.length !== 1 || !same(role.members[0].address, factory)) return [];
    const own = role.targets.find((target) => same(target.address, modifier.address));
    const grant = own?.functions.find((f) => f.selector === selector);
    return grant ? [{ role, grant }] : [];
  });
  if (grants.length === 0) return `no motion role can call ${fn} on the ${modifier.label}`;
  for (const { role, grant } of grants) {
    const keys = writtenKey === null ? null : pinnedKeys(grant);
    if (keys === null || keys.includes(lower(writtenKey!))) return role;
  }
  return `no motion role can call ${fn} on the ${modifier.label} under the key of that role`;
}

// ---------------------------------------------------------------------------------------------------------------
// Whether a motion role's policy accepts a write
// ---------------------------------------------------------------------------------------------------------------

/** The Roles operators that the evaluation below knows, as the deployed mastercopy numbers them. */
const PASS = 0;
const AND = 1;
const NOR = 3;
const GREATER_THAN = 17;
const LESS_THAN = 18;
const BITMASK = 21;
const STATIC = 1;
const NONE = 0;

/** Or, And and Nor over answers that can be unknown: null means that a part could not be evaluated. */
const any = (answers: (boolean | null)[]) => (answers.includes(true) ? true : answers.includes(null) ? null : false);
const all = (answers: (boolean | null)[]) => (answers.includes(false) ? false : answers.includes(null) ? null : true);

/**
 * Evaluates the condition tree of a grant on a call's arguments, as the Roles modifier does, for the operators
 * that the motion roles' grants use. Null if the tree has a part that this cannot evaluate.
 *
 * A static argument is compared as its 32-byte word. An array or a tuple is compared with EqualTo as its whole
 * ABI encoding, which is how the policy pins a whole tree. The fork suite checks this evaluation
 * against the deployed modifier, case by case (test/RoundTrip.t.sol, `just round-trip`).
 */
function evaluate(conditions: Cond[], inputs: readonly ParamType[], values: readonly unknown[]): boolean | null {
  const kids = (index: number) => conditions.flatMap((node, i) => (i !== index && node.parent === index ? [i] : []));
  const argument = (index: number, type: ParamType, value: unknown): boolean | null => {
    const node = conditions[index];
    if (node.paramType === NONE) {
      const answers = kids(index).map((kid) => argument(kid, type, value));
      if (node.operator === OR) return any(answers);
      if (node.operator === AND) return all(answers);
      if (node.operator === NOR) {
        const one = any(answers);
        return one === null ? null : !one;
      }
      return null;
    }
    if (node.operator === PASS) return true;
    const encoded = CODER.encode([type], [value]);
    if (node.paramType === STATIC) {
      if (encoded.length !== 66) return null;
      if (node.operator === EQUAL_TO) return lower(encoded) === lower(node.compValue);
      if (node.operator === GREATER_THAN) return BigInt(encoded) > BigInt(node.compValue);
      if (node.operator === LESS_THAN) return BigInt(encoded) < BigInt(node.compValue);
      if (node.operator === BITMASK) {
        // two bytes of shift, fifteen of mask, fifteen of expected value; the masked bytes start at the shift
        const comp = node.compValue.slice(2);
        const shift = parseInt(comp.slice(0, 4), 16);
        if (shift >= 32) return false;
        const word = (encoded.slice(2 + 2 * shift) + "0".repeat(64)).slice(0, 30);
        return (BigInt("0x" + word) & BigInt("0x" + comp.slice(4, 34))) === BigInt("0x" + comp.slice(34, 64));
      }
      return null;
    }
    // an array, a tuple or bytes: only a pin of the whole value. The artifact holds the pinned value's ABI encoding,
    // which the modifier hashes when it stores the tree.
    if (node.operator === EQUAL_TO) return lower(encoded) === lower(node.compValue);
    return null;
  };
  const branch = (index: number): boolean | null => {
    const node = conditions[index];
    if (node.paramType !== CALLDATA || node.operator !== MATCHES) return null;
    const children = kids(index);
    if (children.length > inputs.length) return null;
    return all(children.map((kid, i) => argument(kid, inputs[i], values[i])));
  };
  if (conditions.length === 0) return null;
  if (conditions[0].paramType === NONE && conditions[0].operator === OR) return any(kids(0).map(branch));
  return branch(0);
}

/**
 * Whether the policy lets `roleKey` on `modifier` make the plain call `data` on `to`. True or false for a call of
 * the Roles modifier on itself; null if the call cannot be evaluated here, such as a call of another contract.
 */
export function acceptedByRole(policy: Artifact, modifier: Modifier, roleKey: string, to: string, data: string): boolean | null {
  const role = modifier.roles.find((r) => same(r.key, roleKey));
  if (!role) return false;
  const target = role.targets.find((t) => same(t.address, to));
  if (!target) return false;
  if (target.clearance === Clearance.Target) return true;
  const grant = target.functions.find((f) => f.selector === lower(data).slice(0, 10));
  if (!grant) return false;
  if (grant.wildcarded) return true;
  if (!same(to, modifier.address)) return null;
  let call;
  try {
    call = ROLES.parseTransaction({ data });
  } catch {
    call = null;
  }
  if (!call) return null;
  return evaluate(grant.conditions, call.fragment.inputs, call.args);
}

// ---------------------------------------------------------------------------------------------------------------
// build: the writes that turn one policy into another
// ---------------------------------------------------------------------------------------------------------------

export type Plan = { writes: PlannedWrite[]; needsVote: string[] };

const flat = (fn: Fn) => fn.conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue]);
const sameFn = (x: Fn, y: Fn) =>
  x.wildcarded === y.wildcarded && x.executionOptions === y.executionOptions && lower(JSON.stringify(flat(x))) === lower(JSON.stringify(flat(y)));
const sameAllowance = (x: Allowance, y: Allowance) =>
  x.balance === y.balance && x.maxRefill === y.maxRefill && x.refill === y.refill && x.period === y.period && x.timestamp === y.timestamp;

/**
 * The writes that turn the policy `base` into the policy `head`, in an order that the modifiers accept, and the
 * parts of the change that no motion can make.
 */
export function planMotion(base: Artifact, head: Artifact): Plan {
  const writes: PlannedWrite[] = [];
  const needsVote: string[] = [];
  if (JSON.stringify(base.manifest) !== JSON.stringify(head.manifest)) needsVote.push("the manifest changes: a motion writes on the deployed accounts only");

  for (const after of head.modifiers) {
    const before = base.modifiers.find((m) => same(m.address, after.address));
    if (!before) {
      needsVote.push(`the ${after.label} is new`);
      continue;
    }
    for (const field of ["owner", "avatar", "target"] as const) {
      if (!same(before[field], after[field])) needsVote.push(`the ${after.label} changes its ${field}`);
    }
    const emit = (fn: string, args: unknown[], writtenKey: string | null, about: string) => {
      const role = motionRole(base, before, fn, writtenKey);
      if (typeof role === "string") {
        needsVote.push(`${about}: ${role}`);
        return;
      }
      const data = lower(ROLES.encodeFunctionData(fn, args));
      // a write that the motion role's own policy refuses is no motion's to make
      if (acceptedByRole(base, before, role.key, after.address, data) === false) {
        needsVote.push(`${about}: the policy of the role ${role.name} refuses this write`);
        return;
      }
      writes.push({ modifier: after.address, role: role.key, to: after.address, data, about: `${after.label}, as ${role.name}: ${about}` });
    };

    // budgets
    for (const allowance of after.allowances) {
      const old = before.allowances.find((a) => a.key === allowance.key);
      if (old && sameAllowance(old, allowance)) continue;
      const { key, balance, maxRefill, refill, period, timestamp } = allowance;
      emit("setAllowance", [key, balance, maxRefill, refill, period, timestamp], null, `set the budget ${allowance.name} to ${balance}, with a refill of ${refill} every ${period} seconds`);
    }
    for (const old of before.allowances) {
      if (after.allowances.some((a) => a.key === old.key)) continue;
      emit("setAllowance", [old.key, 0, 0, 0, old.period, 0], null, `empty the budget ${old.name}`);
    }

    // permissions
    for (const role of after.roles) {
      const old = before.roles.find((r) => r.key === role.key);
      if (!old) {
        needsVote.push(`the role ${role.name} on the ${after.label} is new`);
        continue;
      }
      const members = (r: Role) => r.members.map((m: { address: string }) => lower(m.address)).sort().join(",");
      if (members(old) !== members(role)) needsVote.push(`the members of the role ${role.name} on the ${after.label} change`);
      const name = (t: { address: string; name: string | null }) => t.name ?? t.address;
      const sig = (f: { selector: string; signature: string | null }) => f.signature ?? f.selector;

      // removals first
      for (const target of old.targets) {
        const kept = role.targets.find((t) => same(t.address, target.address));
        for (const fn of target.functions) {
          if (kept?.functions.some((f) => f.selector === fn.selector)) continue;
          emit("revokeFunction", [role.key, target.address, fn.selector], role.key, `remove ${sig(fn)} on ${name(target)} from the role ${role.name}`);
        }
        if (!kept) emit("revokeTarget", [role.key, target.address], role.key, `remove ${name(target)} from the role ${role.name}`);
      }
      // then additions and changes
      for (const target of role.targets) {
        const was = old.targets.find((t) => same(t.address, target.address));
        if (target.clearance !== Clearance.Function) {
          if (!was || was.clearance !== target.clearance || was.executionOptions !== target.executionOptions) {
            needsVote.push(`the role ${role.name} on the ${after.label} gets ${name(target)} as a whole target`);
          }
          continue;
        }
        if (target.executionOptions !== 0) {
          // the modifier scopes a target without execution options, so no write gives a scoped target any
          needsVote.push(`the role ${role.name} on the ${after.label} has ${name(target)} as a scoped target with execution options, which no write can set`);
          continue;
        }
        if (!was || was.clearance !== Clearance.Function || was.executionOptions !== 0) {
          emit("scopeTarget", [role.key, target.address], role.key, `add ${name(target)} to the role ${role.name}`);
        }
        for (const fn of target.functions) {
          const prior = was?.functions.find((f) => f.selector === fn.selector);
          if (prior && sameFn(prior, fn)) continue;
          const verb = prior ? "change" : "add";
          if (fn.wildcarded) {
            emit("allowFunction", [role.key, target.address, fn.selector, fn.executionOptions], role.key, `${verb} ${sig(fn)} on ${name(target)} for the role ${role.name}, without conditions`);
          } else {
            emit("scopeFunction", [role.key, target.address, fn.selector, flat(fn), fn.executionOptions], role.key, `${verb} ${sig(fn)} on ${name(target)} for the role ${role.name}, with ${fn.conditions.length} condition nodes`);
          }
        }
      }
    }
    for (const old of before.roles) {
      if (!after.roles.some((r) => r.key === old.key)) needsVote.push(`the role ${old.name} on the ${after.label} goes`);
    }
  }
  for (const before of base.modifiers) {
    if (!head.modifiers.some((m) => same(m.address, before.address))) needsVote.push(`the ${before.label} goes`);
  }
  return { writes, needsVote };
}

// ---------------------------------------------------------------------------------------------------------------
// check: run a motion's writes on a model of the modifiers, and compare the outcome
// ---------------------------------------------------------------------------------------------------------------

/**
 * What a Roles modifier stores for its roles and budgets. A target's clearance and a function's permission are
 * stored apart, as the modifier stores them: a revoked target keeps its functions, and they work again when the
 * target is scoped again.
 */
type ModifierState = {
  allowances: Map<string, Allowance>;
  roles: Map<string, { targets: Map<string, { clearance: number; executionOptions: number }>; functions: Map<string, Fn> }>;
};
type State = Map<string, ModifierState>;

function stateOf(policy: Artifact): State {
  const state: State = new Map();
  for (const modifier of policy.modifiers) {
    const entry: ModifierState = { allowances: new Map(), roles: new Map() };
    for (const a of modifier.allowances) {
      entry.allowances.set(lower(a.key), { balance: a.balance, maxRefill: a.maxRefill, refill: a.refill, period: a.period, timestamp: a.timestamp });
    }
    for (const role of modifier.roles) {
      const stored = { targets: new Map<string, { clearance: number; executionOptions: number }>(), functions: new Map<string, Fn>() };
      for (const target of role.targets) {
        stored.targets.set(lower(target.address), { clearance: target.clearance, executionOptions: target.executionOptions });
        for (const fn of target.functions) {
          stored.functions.set(`${lower(target.address)}:${fn.selector}`, { wildcarded: fn.wildcarded, executionOptions: fn.executionOptions, conditions: fn.conditions });
        }
      }
      entry.roles.set(lower(role.key), stored);
    }
    state.set(lower(modifier.address), entry);
  }
  return state;
}

/** Applies one administrative call to a modifier's state, as the Roles modifier does. An error message if it cannot. */
function applyCall(modifier: ModifierState, data: string): string | null {
  let call;
  try {
    call = ROLES.parseTransaction({ data });
  } catch {
    call = null;
  }
  if (!call) return "it is no call of the Roles modifier";
  const a = call.args;
  if (call.name === "setAllowance") {
    modifier.allowances.set(lower(a[0]), { balance: String(a[1]), maxRefill: String(a[2]), refill: String(a[3]), period: String(a[4]), timestamp: String(a[5]) });
    return null;
  }
  const writesRole = ["scopeTarget", "revokeTarget", "allowTarget", "allowFunction", "revokeFunction", "scopeFunction"];
  if (!writesRole.includes(call.name)) return `${call.name} is no permission or budget write`;
  const key = lower(a[0]);
  if (!modifier.roles.has(key)) modifier.roles.set(key, { targets: new Map(), functions: new Map() });
  const role = modifier.roles.get(key)!;
  const target = lower(a[1]);
  if (call.name === "scopeTarget") role.targets.set(target, { clearance: Clearance.Function, executionOptions: 0 });
  if (call.name === "allowTarget") role.targets.set(target, { clearance: Clearance.Target, executionOptions: Number(a[2]) });
  if (call.name === "revokeTarget") role.targets.delete(target);
  if (call.name === "revokeFunction") role.functions.delete(`${target}:${lower(a[2])}`);
  if (call.name === "allowFunction") role.functions.set(`${target}:${lower(a[2])}`, { wildcarded: true, executionOptions: Number(a[3]), conditions: [] });
  if (call.name === "scopeFunction") {
    const conditions = (a[3] as any[]).map((n) => ({ parent: Number(n[0]), paramType: Number(n[1]), operator: Number(n[2]), compValue: lower(n[3]) }));
    role.functions.set(`${target}:${lower(a[2])}`, { wildcarded: false, executionOptions: Number(a[4]), conditions });
  }
  return null;
}

/** An empty budget: nothing to spend and nothing to refill. The check reads it as no budget. */
const empty = (a: Allowance | undefined) => !a || (BigInt(a.balance) === 0n && BigInt(a.refill) === 0n);

/** Every difference between two states, in words. Empty if the states are the same policy. */
function differences(got: State, want: State, policies: Artifact[]): string[] {
  const out: string[] = [];
  const labels = new Map<string, string>();
  const names = new Map<string, string>();
  for (const m of policies.flatMap((policy) => policy.modifiers)) {
    labels.set(lower(m.address), m.label);
    for (const a of m.allowances) names.set(lower(a.key), a.name);
    for (const r of m.roles) {
      names.set(lower(r.key), r.name);
      for (const member of r.members) if (member.name) names.set(lower(member.address), member.name);
      for (const t of r.targets) {
        if (t.name) names.set(lower(t.address), t.name);
        for (const f of t.functions) if (f.signature) names.set(f.selector, f.signature);
      }
    }
  }
  const name = (value: string) => names.get(lower(value)) ?? value;
  for (const address of new Set([...got.keys(), ...want.keys()])) {
    const g = got.get(address);
    const w = want.get(address);
    const where = labels.get(address) ?? address;
    if (!g || !w) {
      out.push(`${where}: the modifier is in one policy only`);
      continue;
    }
    for (const key of new Set([...g.allowances.keys(), ...w.allowances.keys()])) {
      const x = g.allowances.get(key);
      const y = w.allowances.get(key);
      if (empty(x) && empty(y)) continue;
      if (!x || !y || !sameAllowance(x, y)) out.push(`${where}: the budget ${name(key)} is ${x ? JSON.stringify(x) : "not set"}, and the policy says ${y ? JSON.stringify(y) : "no budget"}`);
    }
    for (const key of new Set([...g.roles.keys(), ...w.roles.keys()])) {
      const x = g.roles.get(key) ?? { targets: new Map(), functions: new Map() };
      const y = w.roles.get(key) ?? { targets: new Map(), functions: new Map() };
      const role = `${where}, role ${name(key)}`;
      for (const target of new Set([...x.targets.keys(), ...y.targets.keys()])) {
        const a = x.targets.get(target);
        const b = y.targets.get(target);
        if (!a) out.push(`${role}: ${name(target)} is missing`);
        else if (!b) out.push(`${role}: ${name(target)} is a target, and the policy has no such target`);
        else if (a.clearance !== b.clearance || a.executionOptions !== b.executionOptions) out.push(`${role}: ${name(target)} has another clearance or other execution options`);
      }
      for (const id of new Set([...x.functions.keys(), ...y.functions.keys()])) {
        const a = x.functions.get(id);
        const b = y.functions.get(id);
        const [target, selector] = id.split(":");
        const fn = `${name(selector)} on ${name(target)}`;
        if (!a) out.push(`${role}: ${fn} is missing`);
        else if (!b) out.push(`${role}: ${fn} is stored${x.targets.has(target) ? "" : " under a revoked target"}, and the policy has no such function`);
        else if (!sameFn(a, b)) out.push(`${role}: ${fn} has other conditions or other execution options`);
      }
    }
  }
  return out;
}

export type Verdict = {
  ok: boolean;
  /** Writes that a modifier would refuse, or that break a rule of the factory. */
  problems: string[];
  /** Where the policy after the motion differs from the head policy. */
  differences: string[];
  /** The writes on a target that is no modifier: the motion's actions. */
  actions: Write[];
  /** What the check did not evaluate, such as a role's conditions on an action. */
  notes: string[];
};

/**
 * Runs a motion's writes on the base policy and compares the outcome with the head policy. A write on a target
 * that is no modifier is an action, such as a burn or a relayer approval. The check passes an action only if
 * `declared` lists it, and it says nothing about what the action does.
 */
export function checkMotion(base: Artifact, head: Artifact, writes: Write[], declared: Write[] = []): Verdict {
  const problems: string[] = [];
  const notes: string[] = [];
  const actions: Write[] = [];
  const state = stateOf(base);
  const modifiers = new Map(base.modifiers.map((m) => [lower(m.address), m] as const));
  if (writes.length === 0) problems.push("the motion has no write");
  if (writes.length > MAX_WRITES) problems.push(`the motion has ${writes.length} writes, and the factory takes at most ${MAX_WRITES}`);

  writes.forEach((write, i) => {
    const where = `write ${i + 1}`;
    const modifier = modifiers.get(lower(write.modifier));
    if (!modifier) {
      problems.push(`${where}: ${write.modifier} is none of the vault's modifiers`);
      return;
    }
    if (!modifiers.has(lower(write.to))) {
      actions.push(write);
      return;
    }
    if (!same(write.to, write.modifier)) {
      problems.push(`${where}: it writes on the ${modifiers.get(lower(write.to))!.label} through the ${modifier.label}`);
      return;
    }
    let call;
    try {
      call = ROLES.parseTransaction({ data: write.data });
    } catch {
      call = null;
    }
    if (!call) {
      problems.push(`${where}: it is no call of the Roles modifier`);
      return;
    }
    const writtenKey = call.name === "setAllowance" ? null : String(call.args[0]);
    let role: Role | string;
    try {
      role = motionRole(base, modifier, call.name, writtenKey);
    } catch {
      role = `${call.name} is no permission or budget write`;
    }
    if (typeof role === "string") {
      problems.push(`${where}: ${role}`);
      return;
    }
    if (!same(role.key, write.role)) {
      problems.push(`${where}: it names the role ${write.role}, and only the role ${role.name} can make this call`);
      return;
    }
    // the role's policy on the whole call, as the modifier evaluates it
    const accepted = acceptedByRole(base, modifier, write.role, write.to, write.data);
    if (accepted === false) {
      problems.push(`${where}: the policy of the role ${role.name} refuses this call of ${call.name}`);
      return;
    }
    if (accepted === null) notes.push(`${where}: the conditions of the role ${role.name} on ${call.name} are not evaluated here; the fork replay must show that the modifier accepts the write`);
    const failure = applyCall(state.get(lower(modifier.address))!, write.data);
    if (failure) problems.push(`${where}: ${failure}`);
  });

  const key = (w: Write) => lower(`${w.modifier}|${w.role}|${w.to}|${w.data}`);
  const open = declared.map(key);
  for (const action of actions) {
    const at = open.indexOf(key(action));
    if (at < 0) problems.push(`an action is not declared: ${action.to} through ${action.modifier}, as the role ${action.role}, data ${action.data}`);
    else open.splice(at, 1);
  }
  if (open.length > 0) problems.push(`${open.length} declared action(s) are not in the motion`);

  const diffs = differences(state, stateOf(head), [base, head]);
  if (actions.length > 0) notes.push(`${actions.length} action(s) are not evaluated: the check does not say whether a modifier accepts them, or what they do`);
  return { ok: problems.length === 0 && diffs.length === 0, problems, differences: diffs, actions, notes };
}

// ---------------------------------------------------------------------------------------------------------------
// The command line
// ---------------------------------------------------------------------------------------------------------------

export type Source = { ref: string; commit: string | null; sha256: string; text: string; policy: Artifact };

/** The committed example motion, which the fork suite enacts (test/MotionReplay.t.sol). */
export const EXAMPLE_NETWORK = "rehearsal-26249900";
export const EXAMPLE_MOTION = path.join(ROOT, "artifacts", `motion-example-${EXAMPLE_NETWORK}.json`);

function git(args: string[]): string {
  return execFileSync("git", args, { cwd: REPO, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 64 * 1024 * 1024 });
}

/** The artifact of a commit, or of a file. */
export function load(ref: string, network: string): Source {
  let text: string;
  let commit: string | null = null;
  if (existsSync(ref)) {
    text = readFileSync(ref, "utf8");
  } else {
    commit = git(["rev-parse", "--verify", `${ref}^{commit}`]).trim();
    text = git(["show", `${commit}:policy/constellation/artifacts/${network}.json`]);
  }
  return source(ref, commit, text);
}

function source(ref: string, commit: string | null, text: string): Source {
  return { ref, commit, sha256: createHash("sha256").update(text).digest("hex"), text, policy: JSON.parse(text) as Artifact };
}

/**
 * The pending motion of a network (ADR 013, decision 19): `pending/<network>/motion.json`, which `build --pending`
 * writes, and `base.json`, the policy that the motion starts from. The pull request that changes the policy
 * commits both, and the pull request after the enactment removes both. While they are there, the chain holds the
 * base policy, and the committed artifact is the policy after the motion.
 */
export const PENDING_DIR = path.join(ROOT, "pending");
export type Pending = { base: Artifact; calldata: string; actions: Write[] };

export function loadPending(network: string, dir = PENDING_DIR): Pending | null {
  const base = path.join(dir, network, "base.json");
  const motion = path.join(dir, network, "motion.json");
  if (!existsSync(base) && !existsSync(motion)) return null;
  if (!existsSync(base) || !existsSync(motion)) throw new Error(`${path.join(dir, network)} must hold both base.json and motion.json, or neither`);
  const file = JSON.parse(readFileSync(motion, "utf8"));
  if (file.format !== MOTION_FORMAT || typeof file.calldata !== "string") throw new Error(`${motion} is no motion file`);
  const actions = ((file.actions ?? []) as Write[]).map((w) => ({ modifier: getAddress(w.modifier), role: lower(w.role), to: getAddress(w.to), data: lower(w.data) }));
  return { base: JSON.parse(readFileSync(base, "utf8")) as Artifact, calldata: file.calldata, actions };
}

/**
 * The record of a network's enacted motions: `enacted/<network>/<motion id>.json`, the motion's file under its
 * Easy Track id. `watch.ts settle` moves a pending motion's file there once the chain shows its enactment. The
 * motion detector reports every enacted motion of the factory that the record does not hold.
 */
export const ENACTED_DIR = path.join(ROOT, "enacted");

/** The recorded calldata of each enacted motion, by its Easy Track id. */
export function loadEnacted(network: string, dir = ENACTED_DIR): Map<string, string> {
  const out = new Map<string, string>();
  const folder = path.join(dir, network);
  if (!existsSync(folder)) return out;
  for (const name of readdirSync(folder).sort()) {
    const match = /^(\d+)\.json$/.exec(name);
    if (!match) throw new Error(`${path.join(folder, name)}: a record of an enacted motion is named <motion id>.json`);
    const file = JSON.parse(readFileSync(path.join(folder, name), "utf8"));
    if (file.format !== MOTION_FORMAT || typeof file.calldata !== "string") throw new Error(`${path.join(folder, name)} is no motion file`);
    out.set(match[1], lower(file.calldata));
  }
  return out;
}

/** The example motion's file: from the committed rehearsal artifact to the example change, at a new factory. */
export function exampleMotion(): string {
  const base = source(`artifacts/${EXAMPLE_NETWORK}.json`, null, readFileSync(path.join(ROOT, "artifacts", `${EXAMPLE_NETWORK}.json`), "utf8"));
  const head = source("compiler/motion.example.ts", null, JSON.stringify(exampleHead(base.policy), null, 2) + "\n");
  const plan = planMotion(base.policy, head.policy);
  if (plan.needsVote.length > 0) throw new Error(`the example change needs a vote: ${plan.needsVote.join("; ")}`);
  return render(base, head, 0n, 0n, plan.writes, []);
}

/** True if the commit is in the history of the main branch, so that its policy change is merged. */
function merged(source: Source, main: string): boolean {
  if (!source.commit) return false;
  try {
    git(["merge-base", "--is-ancestor", source.commit, main]);
    return true;
  } catch {
    return false;
  }
}

function options(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (!flag.startsWith("--")) throw new Error(`unexpected argument ${flag}`);
    const next = argv[i + 1];
    if (next !== undefined && !next.startsWith("--")) {
      out[flag.slice(2)] = next;
      i++;
    } else {
      out[flag.slice(2)] = "true";
    }
  }
  return out;
}

/** The factory's counter and policy version, from the flags or from the chain. The RPC URL is never printed. */
async function numbers(opts: Record<string, string>, factory: string): Promise<{ epoch: bigint; policyVersion: bigint } | null> {
  if (opts.epoch !== undefined && opts["policy-version"] !== undefined) return { epoch: BigInt(opts.epoch), policyVersion: BigInt(opts["policy-version"]) };
  if (opts.rpc === undefined) return null;
  const url = opts.rpc === "true" || opts.rpc === "env" ? process.env.RPC : opts.rpc;
  if (!url) throw new Error("--rpc needs a URL, or RPC in the environment");
  const provider = new JsonRpcProvider(url);
  try {
    if ((await provider.getCode(factory)) === "0x") throw new Error(`no contract at the factory's address ${factory} on this chain; pass --epoch and --policy-version`);
    const read = async (fn: string) => BigInt(FACTORY.decodeFunctionResult(fn, await provider.call({ to: factory, data: FACTORY.encodeFunctionData(fn) }))[0]);
    return { epoch: await read("epoch"), policyVersion: await read("policyVersion") };
  } finally {
    provider.destroy();
  }
}

function readActions(file: string | undefined): Write[] {
  if (!file) return [];
  const list = JSON.parse(readFileSync(file, "utf8")) as Write[];
  return list.map((w) => ({ modifier: getAddress(w.modifier), role: lower(w.role), to: getAddress(w.to), data: lower(w.data) }));
}

/** The motion file: the writes with what each does, the calldata, and the same writes as columns for the fork run. */
export function render(base: Source, head: Source, epoch: bigint, policyVersion: bigint, planned: PlannedWrite[], actions: Write[]) {
  const all: PlannedWrite[] = [...planned, ...actions.map((a) => ({ ...a, about: "an action that the motion's author declared" }))];
  const writes: Write[] = all.map(({ modifier, role, to, data }) => ({ modifier, role, to, data }));
  const file = {
    format: MOTION_FORMAT,
    network: head.policy.manifest.network,
    factory: head.policy.manifest.universalFactory,
    base: { ref: base.ref, commit: base.commit, sha256: base.sha256 },
    head: { ref: head.ref, commit: head.commit, sha256: head.sha256 },
    epoch: String(epoch),
    policyVersion: String(policyVersion),
    writes: all,
    actions,
    calldata: encodeMotion(epoch, policyVersion, writes),
    budgetCount: head.policy.modifiers.reduce((n, m) => n + m.allowances.length, 0),
    budgets: {
      modifier: head.policy.modifiers.flatMap((m) => m.allowances.map(() => m.address)),
      key: head.policy.modifiers.flatMap((m) => m.allowances.map((a) => a.key)),
      balance: head.policy.modifiers.flatMap((m) => m.allowances.map((a) => a.balance)),
      refill: head.policy.modifiers.flatMap((m) => m.allowances.map((a) => a.refill)),
      period: head.policy.modifiers.flatMap((m) => m.allowances.map((a) => a.period)),
    },
  };
  return JSON.stringify(file, null, 2) + "\n";
}

/** A draft of the motion's forum post. The author fills the parts in angle brackets (ADR 006, decision 4). */
function post(base: Source, head: Source, planned: PlannedWrite[], actions: Write[], calldata: string): string {
  const lines = [
    "# Motion: <title>",
    "",
    "**Event.** <the event that this motion follows: a new mandate size, a new spender, a product's unlock, or another reason>",
    "",
    "**Diligence.** <the target's audits, its upgrade path and its owners; the monitoring that is set up for it>",
    "",
    "## What changes",
    "",
    ...planned.map((w, i) => `${i + 1}. ${w.about}`),
    ...(actions.length > 0 ? ["", `The motion also makes ${actions.length} action(s) that no policy change implies: <say what each does>.`] : []),
    "",
    "## How to verify",
    "",
    `- Policy before: ${base.commit ? "commit" : "file"} \`${base.commit ?? base.ref}\`, artifact sha256 \`${base.sha256}\`.`,
    `- Policy after: ${head.commit ? "commit" : "file"} \`${head.commit ?? head.ref}\`, artifact sha256 \`${head.sha256}\`.`,
    `- Run \`just motion-check ${base.commit ?? base.ref} ${head.commit ?? head.ref} <the motion's calldata from Easy Track>\`. It fails unless the motion turns the first policy into the second.`,
    "",
    "## Calldata",
    "",
    "```",
    calldata,
    "```",
    "",
  ];
  return lines.join("\n");
}

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  if (command === "example") {
    const text = exampleMotion();
    if (rest.includes("--check")) {
      if (existsSync(EXAMPLE_MOTION) && readFileSync(EXAMPLE_MOTION, "utf8") === text) {
        console.log(`${path.relative(ROOT, EXAMPLE_MOTION)} matches a fresh build.`);
        return 0;
      }
      console.error(`${path.relative(ROOT, EXAMPLE_MOTION)} differs from a fresh build. Run \`just regen\`.`);
      return 1;
    }
    writeFileSync(EXAMPLE_MOTION, text);
    console.log(`wrote ${path.relative(ROOT, EXAMPLE_MOTION)}`);
    return 0;
  }
  if (command !== "build" && command !== "check") {
    console.error("usage: motion.ts example [--check]");
    console.error("       motion.ts build|check --base <ref> --head <ref> [--network <name>] [--epoch N --policy-version N | --rpc [URL]]");
    console.error("       build: [--actions file] [--out file] [--post file] [--pending]    check: --calldata 0x… | --motion file | --pending, [--actions file] [--allow-unmerged]");
    return 2;
  }
  const opts = options(rest);
  const network = opts.network ?? "rehearsal-26249900";
  const committed = path.join(ROOT, "artifacts", `${network}.json`);
  if (opts.pending !== undefined && command === "check") {
    // the repository's pending motion against its base policy and the committed artifact
    const pending = loadPending(network);
    if (!pending) {
      console.log(`No motion is pending for ${network}.`);
      return 0;
    }
    const verdict = checkMotion(pending.base, load(committed, network).policy, decodeMotion(pending.calldata).writes, pending.actions);
    console.log(verdict.ok ? `PASS: the pending motion turns its base policy into the committed artifact of ${network}, and writes nothing else.` : "FAIL");
    for (const line of verdict.problems) console.log(`  problem: ${line}`);
    for (const line of verdict.differences) console.log(`  difference: ${line}`);
    for (const line of verdict.notes) console.log(`  note: ${line}`);
    return verdict.ok ? 0 : 1;
  }
  if (opts.pending !== undefined) {
    // a pending motion goes from a merged policy to the working tree's artifact, into the repository
    opts.head ??= committed;
    opts.out = path.join(PENDING_DIR, network, "motion.json");
  }
  if (!opts.base || !opts.head) throw new Error("--base and --head are needed");
  const main = opts.main ?? "origin/main";
  const base = load(opts.base, network);
  const head = load(opts.head, network);
  const actions = readActions(opts.actions);
  const isMerged = merged(head, main);

  if (command === "build") {
    const plan = planMotion(base.policy, head.policy);
    if (plan.needsVote.length > 0) {
      console.error("This change needs a DAO vote. No motion can make these parts of it:");
      for (const reason of plan.needsVote) console.error(`  - ${reason}`);
      return 1;
    }
    if (plan.writes.length + actions.length === 0) {
      console.error("The two policies are the same: there is nothing to write.");
      return 1;
    }
    if (plan.writes.length + actions.length > MAX_WRITES) {
      console.error(`The change needs ${plan.writes.length + actions.length} writes, and the factory takes at most ${MAX_WRITES}. Split the policy change.`);
      return 1;
    }
    const read = await numbers(opts, head.policy.manifest.universalFactory);
    if (!read) throw new Error("pass --epoch and --policy-version, or --rpc to read them from the factory");
    const text = render(base, head, read.epoch, read.policyVersion, plan.writes, actions);
    const file = JSON.parse(text);
    // the command checks its own output with the other implementation
    const verdict = checkMotion(base.policy, head.policy, decodeMotion(file.calldata).writes, actions);
    if (!verdict.ok) {
      console.error("The built motion does not pass its own check:");
      for (const line of [...verdict.problems, ...verdict.differences]) console.error(`  - ${line}`);
      return 1;
    }
    plan.writes.forEach((w, i) => console.log(`${String(i + 1).padStart(2)}. ${w.about}`));
    actions.forEach((a, i) => console.log(`${String(plan.writes.length + i + 1).padStart(2)}. action: ${a.to} through ${a.modifier}, as the role ${a.role}`));
    console.log(`\ncounter ${read.epoch}, policy version ${read.policyVersion}, ${file.writes.length} writes, calldata ${(file.calldata.length - 2) / 2} bytes`);
    if (!isMerged && opts.pending === undefined) console.log(`Warning: ${head.ref} is not in the history of ${main}. Create a motion only from a merged policy change.`);
    if (opts.out) {
      mkdirSync(path.dirname(path.resolve(opts.out)), { recursive: true });
      writeFileSync(opts.out, text);
      // the base policy beside it, so that the fork run can apply it before the motion
      writeFileSync(path.join(path.dirname(path.resolve(opts.out)), "base.json"), base.text);
      console.log(`wrote ${opts.out}`);
    } else {
      console.log(`\n${file.calldata}`);
    }
    if (opts.post) {
      writeFileSync(opts.post, post(base, head, plan.writes, actions, file.calldata));
      console.log(`wrote ${opts.post}`);
    }
    return 0;
  }

  // the calldata itself, or @file for a file that holds it, or --motion for a motion file of `build`
  const given = opts.calldata?.startsWith("@") ? readFileSync(opts.calldata.slice(1), "utf8").trim() : opts.calldata;
  const calldata = opts.motion ? (JSON.parse(readFileSync(opts.motion, "utf8")).calldata as string) : given;
  if (!calldata || calldata === "true") throw new Error("--calldata or --motion is needed");
  const motion = decodeMotion(calldata);
  const verdict = checkMotion(base.policy, head.policy, motion.writes, actions);
  const problems = [...verdict.problems];
  if (!isMerged && opts["allow-unmerged"] === undefined) problems.push(`${head.ref} is not in the history of ${main}: the policy change is not merged`);
  const read = await numbers(opts, head.policy.manifest.universalFactory);
  if (read && read.epoch !== motion.epoch) problems.push(`the motion names the counter ${motion.epoch}, and the factory's is ${read.epoch}`);
  if (read && read.policyVersion !== motion.policyVersion) problems.push(`the motion names the policy version ${motion.policyVersion}, and the factory's is ${read.policyVersion}`);

  console.log(`${motion.writes.length} writes, ${verdict.actions.length} of them actions; counter ${motion.epoch}, policy version ${motion.policyVersion}`);
  if (problems.length === 0 && verdict.differences.length === 0) {
    console.log(`PASS: the motion turns the policy of ${base.ref} into the policy of ${head.ref}, and writes nothing else.`);
    for (const line of verdict.notes) console.log(`  note: ${line}`);
    return 0;
  }
  console.log("FAIL");
  for (const line of problems) console.log(`  problem: ${line}`);
  for (const line of verdict.differences) console.log(`  difference: ${line}`);
  return 1;
}

if (import.meta.main) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (error) => {
      console.error(error instanceof Error ? error.message : String(error));
      process.exit(2);
    },
  );
}
