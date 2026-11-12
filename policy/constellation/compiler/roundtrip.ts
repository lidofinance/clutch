// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The round-trip check (ADR 004, decision 13; INV-016): rebuilds what each Roles modifier stores from the events
 * that it emitted, and compares the outcome with a policy artifact.
 *
 *   bun compiler/roundtrip.ts check --artifact <ref> --events <file>
 *   bun compiler/roundtrip.ts check --artifact <ref> --rpc [URL] --from-block N [--to-block N]
 *   bun compiler/roundtrip.ts rehearsal --dir .roundtrip
 *
 * An events file holds one log on each line, as JSON with `address`, `topics` and `data`, in the order of
 * emission. The fork suite writes such files (test/RoundTrip.t.sol), and `rehearsal` checks them: the enabling
 * vote against the committed artifact, a motion that the `motion` command built against its head policy, and an
 * emergency revoke, which the check must report.
 *
 * The check reads events only. It does not read the modifier's storage, which holds the trees in a packed form,
 * so it trusts the deployed Roles code to store what it emits.
 */
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { getAddress, Interface, JsonRpcProvider } from "ethers";
import { Clearance, rolesAbi } from "zodiac-roles-sdk";
import type { Artifact } from "./compile";
import { load } from "./motion";
import { exampleHead } from "./motion.example";

const ROLES = new Interface(rolesAbi as any);
/** The deployed mastercopy emits the initializer's event with a uint64, and the SDK's ABI lists it with a uint8. */
const INITIALIZED = new Interface(["event Initialized(uint64 version)"]).getEvent("Initialized")!.topicHash;
const MAX_UINT128 = (1n << 128n) - 1n;

/** One log of a modifier, as a node returns it. */
export type Log = { address: string; topics: string[]; data: string };
type Cond = { parent: number; paramType: number; operator: number; compValue: string };
type Fn = { wildcarded: boolean; executionOptions: number; conditions: Cond[] };
type Budget = { balance: bigint; maxRefill: bigint; refill: bigint; period: bigint; timestamp: bigint; spent: boolean };

/** What one modifier stores, rebuilt from its events. */
export type Rebuilt = {
  events: number;
  owner: string | null;
  avatar: string | null;
  target: string | null;
  members: Map<string, Set<string>>;
  targets: Map<string, Map<string, { clearance: number; executionOptions: number }>>;
  functions: Map<string, Map<string, Fn>>;
  budgets: Map<string, Budget>;
  /** Events that no policy of Clutch emits, such as an unwrap adapter or a default role. */
  foreign: string[];
  /** Logs that are no event of the Roles modifier. */
  unknown: number;
};

const lower = (value: string) => value.toLowerCase();
const fresh = (): Rebuilt => ({ events: 0, owner: null, avatar: null, target: null, members: new Map(), targets: new Map(), functions: new Map(), budgets: new Map(), foreign: [], unknown: 0 });
const slot = <V>(map: Map<string, V>, key: string, make: () => V): V => {
  if (!map.has(key)) map.set(key, make());
  return map.get(key)!;
};

/** Rebuilds the stored state of each modifier in `modifiers` from `logs`, which are in the order of emission. */
export function rebuild(logs: Log[], modifiers: string[]): Map<string, Rebuilt> {
  const out = new Map(modifiers.map((address) => [lower(address), fresh()] as const));
  for (const log of logs) {
    const state = out.get(lower(log.address));
    if (!state) continue;
    let event;
    try {
      event = ROLES.parseLog({ topics: log.topics, data: log.data });
    } catch {
      event = null;
    }
    if (!event) {
      if (log.topics[0] !== INITIALIZED) state.unknown++;
      continue;
    }
    state.events++;
    const a = event.args;
    const key = () => lower(String(a[0]));
    const target = () => lower(String(a[1]));
    switch (event.name) {
      case "AssignRoles":
        (a[1] as string[]).forEach((role, i) => {
          const members = slot(state.members, lower(role), () => new Set<string>());
          if (a[2][i]) members.add(lower(a[0]));
          else members.delete(lower(a[0]));
        });
        break;
      case "ScopeTarget":
        slot(state.targets, key(), () => new Map()).set(target(), { clearance: Clearance.Function, executionOptions: 0 });
        break;
      case "AllowTarget":
        slot(state.targets, key(), () => new Map()).set(target(), { clearance: Clearance.Target, executionOptions: Number(a[2]) });
        break;
      case "RevokeTarget":
        slot(state.targets, key(), () => new Map()).delete(target());
        break;
      case "AllowFunction":
        slot(state.functions, key(), () => new Map()).set(`${target()}:${lower(a[2])}`, { wildcarded: true, executionOptions: Number(a[3]), conditions: [] });
        break;
      case "ScopeFunction":
        slot(state.functions, key(), () => new Map()).set(`${target()}:${lower(a[2])}`, {
          wildcarded: false,
          executionOptions: Number(a[4]),
          conditions: (a[3] as any[]).map((n) => ({ parent: Number(n[0]), paramType: Number(n[1]), operator: Number(n[2]), compValue: lower(n[3]) })),
        });
        break;
      case "RevokeFunction":
        slot(state.functions, key(), () => new Map()).delete(`${target()}:${lower(a[2])}`);
        break;
      case "SetAllowance":
        state.budgets.set(key(), { balance: a[1], maxRefill: a[2], refill: a[3], period: a[4], timestamp: a[5], spent: false });
        break;
      case "ConsumeAllowance": {
        const budget = state.budgets.get(key());
        if (budget) {
          budget.balance = a[2];
          budget.spent = true;
        } else {
          state.foreign.push(`a budget that was never set is spent: ${key()}`);
        }
        break;
      }
      case "RolesModSetup":
        state.owner = lower(a[1]);
        state.avatar = lower(a[2]);
        state.target = lower(a[3]);
        break;
      case "OwnershipTransferred":
        state.owner = lower(a[1]);
        break;
      case "AvatarSet":
        state.avatar = lower(a[1]);
        break;
      case "TargetSet":
        state.target = lower(a[1]);
        break;
      case "SetUnwrapAdapter":
        state.foreign.push(`an unwrap adapter is set for ${a[1]} on ${a[0]}: ${a[2]}`);
        break;
      case "SetDefaultRole":
        state.foreign.push(`a default role is set for ${a[0]}: ${a[1]}`);
        break;
      default:
        // the modifier's own module list, its setup and its executions change no permission
        break;
    }
  }
  return out;
}

export type Report = {
  /** Where the chain differs from the policy. Empty if the chain holds the policy. */
  differences: string[];
  /** What the check saw and did not compare, such as a budget that was spent since it was set. */
  notes: string[];
};

/** Compares what the modifiers store with the policy. */
export function compare(policy: Artifact, chain: Map<string, Rebuilt>): Report {
  const differences: string[] = [];
  const notes: string[] = [];
  const names = new Map<string, string>();
  for (const m of policy.modifiers) {
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
  const sameFn = (x: Fn, y: Fn) =>
    x.wildcarded === y.wildcarded &&
    x.executionOptions === y.executionOptions &&
    lower(JSON.stringify(x.conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue]))) ===
      lower(JSON.stringify(y.conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue])));

  for (const modifier of policy.modifiers) {
    const where = modifier.label;
    const state = chain.get(lower(modifier.address));
    if (!state || state.events === 0) {
      differences.push(`${where}: the modifier emitted no event`);
      continue;
    }
    for (const field of ["owner", "avatar", "target"] as const) {
      if (state[field] === null) notes.push(`${where}: its ${field} is not in the events, so it is not compared`);
      else if (state[field] !== lower(modifier[field])) differences.push(`${where}: its ${field} is ${state[field]}, and the policy says ${modifier[field]}`);
    }
    for (const line of state.foreign) differences.push(`${where}: ${line}`);
    if (state.unknown > 0) notes.push(`${where}: ${state.unknown} log(s) are no event of the Roles modifier`);

    // budgets
    const wanted = new Map(modifier.allowances.map((a) => [lower(a.key), a] as const));
    for (const [key, want] of wanted) {
      const got = state.budgets.get(key);
      if (!got) {
        differences.push(`${where}: the budget ${want.name} is not set`);
        continue;
      }
      const maxRefill = BigInt(want.maxRefill) === 0n ? MAX_UINT128 : BigInt(want.maxRefill);
      if (got.maxRefill !== maxRefill || got.refill !== BigInt(want.refill) || got.period !== BigInt(want.period)) {
        differences.push(`${where}: the budget ${want.name} refills ${got.refill} every ${got.period} seconds up to ${got.maxRefill}, and the policy says ${want.refill} every ${want.period} seconds up to ${maxRefill}`);
      }
      if (BigInt(want.timestamp) !== 0n && got.timestamp !== BigInt(want.timestamp)) differences.push(`${where}: the budget ${want.name} has another timestamp`);
      if (got.spent) notes.push(`${where}: the budget ${want.name} was spent since it was set; ${got.balance} is left, and its balance is not compared`);
      else if (got.balance !== BigInt(want.balance)) differences.push(`${where}: the budget ${want.name} is ${got.balance}, and the policy says ${want.balance}`);
    }
    for (const [key, got] of state.budgets) {
      if (wanted.has(key) || (got.balance === 0n && got.refill === 0n)) continue;
      differences.push(`${where}: the budget ${key} is set, and the policy has no such budget`);
    }

    // roles
    const keys = new Set([...modifier.roles.map((r) => lower(r.key)), ...state.members.keys(), ...state.targets.keys(), ...state.functions.keys()]);
    for (const key of keys) {
      const want = modifier.roles.find((r) => lower(r.key) === key);
      const role = `${where}, role ${name(key)}`;
      const members = state.members.get(key) ?? new Set<string>();
      const targets = state.targets.get(key) ?? new Map<string, { clearance: number; executionOptions: number }>();
      const functions = state.functions.get(key) ?? new Map<string, Fn>();
      if (!want) {
        if (members.size + targets.size + functions.size > 0) differences.push(`${role}: the role holds ${members.size} member(s), ${targets.size} target(s) and ${functions.size} function(s), and the policy has no such role`);
        continue;
      }
      const wantMembers = new Set<string>(want.members.map((m: { address: string }) => lower(m.address)));
      for (const member of wantMembers) if (!members.has(member)) differences.push(`${role}: ${name(member)} is no member`);
      for (const member of members) if (!wantMembers.has(member)) differences.push(`${role}: ${name(member)} is a member, and the policy does not list it`);

      const stored = (target: string) => [...functions.keys()].filter((id) => id.startsWith(`${target}:`));
      const wantTargets = new Map(want.targets.map((t) => [lower(t.address), t] as const));
      for (const [address, target] of wantTargets) {
        const got = targets.get(address);
        if (!got) {
          const kept = stored(address).length;
          differences.push(`${role}: ${name(address)} is no target on chain${kept > 0 ? `; its ${kept} function(s) stay stored, and a scope of the target brings them back` : ""}`);
          continue;
        }
        if (got.clearance !== target.clearance || got.executionOptions !== target.executionOptions) differences.push(`${role}: ${name(address)} has another clearance or other execution options`);
        for (const fn of target.functions) {
          const have = functions.get(`${address}:${fn.selector}`);
          if (!have) differences.push(`${role}: ${name(fn.selector)} on ${name(address)} is missing`);
          else if (!sameFn(have, { wildcarded: fn.wildcarded, executionOptions: fn.executionOptions, conditions: fn.conditions })) differences.push(`${role}: ${name(fn.selector)} on ${name(address)} has other conditions or other execution options`);
        }
      }
      for (const address of targets.keys()) {
        if (!wantTargets.has(address)) differences.push(`${role}: ${name(address)} is a target on chain, and the policy has no such target`);
      }
      for (const id of functions.keys()) {
        const [address, selector] = id.split(":");
        if (wantTargets.get(address)?.functions.some((f) => f.selector === selector)) continue;
        differences.push(`${role}: ${name(selector)} on ${name(address)} is stored${targets.has(address) ? "" : " under a target that is not scoped"}, and the policy has no such function`);
      }
    }
  }
  return { differences, notes };
}

/** The round-trip check: the logs of the policy's modifiers, rebuilt and compared with the policy. */
export function roundTrip(policy: Artifact, logs: Log[]): Report {
  return compare(policy, rebuild(logs, policy.modifiers.map((m) => m.address)));
}

// ---------------------------------------------------------------------------------------------------------------
// Where the logs come from
// ---------------------------------------------------------------------------------------------------------------

/** The logs of an events file: one JSON log on each line, in the order of emission. */
export function readEvents(file: string): Log[] {
  return readFileSync(file, "utf8")
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line, i) => {
      const log = JSON.parse(line) as Log;
      if (typeof log.address !== "string" || !Array.isArray(log.topics) || typeof log.data !== "string") throw new Error(`${file}, line ${i + 1}: not a log`);
      return log;
    });
}

type NodeLog = Log & { blockNumber: number | string; index?: number; logIndex?: number | string };
export type GetLogs = (filter: { address: string[]; fromBlock: number; toBlock: number }) => Promise<NodeLog[]>;

/**
 * Every log of `addresses` from `fromBlock` to `toBlock`, in the order of emission. It asks for `span` blocks at a
 * time and halves the span when the node refuses a range.
 */
export async function fetchLogs(getLogs: GetLogs, addresses: string[], fromBlock: number, toBlock: number, span = 50_000): Promise<Log[]> {
  const all: NodeLog[] = [];
  let from = fromBlock;
  let step = span;
  while (from <= toBlock) {
    const to = Math.min(toBlock, from + step - 1);
    try {
      all.push(...(await getLogs({ address: addresses, fromBlock: from, toBlock: to })));
      from = to + 1;
    } catch (error) {
      if (step === 1) throw error;
      step = Math.max(1, Math.floor(step / 2));
    }
  }
  const position = (log: NodeLog) => [Number(log.blockNumber), Number(log.index ?? log.logIndex ?? 0)] as const;
  all.sort((x, y) => position(x)[0] - position(y)[0] || position(x)[1] - position(y)[1]);
  return all.map(({ address, topics, data }) => ({ address, topics: [...topics], data }));
}

// ---------------------------------------------------------------------------------------------------------------
// The command line
// ---------------------------------------------------------------------------------------------------------------

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

function print(title: string, report: Report, events: number): boolean {
  const ok = report.differences.length === 0;
  console.log(`${ok ? "PASS" : "FAIL"}: ${title} (${events} logs)`);
  for (const line of report.differences) console.log(`  difference: ${line}`);
  for (const line of report.notes) console.log(`  note: ${line}`);
  return ok;
}

/** The differences that the rehearsal's emergency revoke must show, and no other (test/RoundTrip.t.sol). */
export const REVOKE_DIFFERENCES = [
  "Clutch operator modifier, role operator: approve(address,uint256) on USDC is missing",
  "Clutch operator modifier, role operator: sUSDS is no target on chain; its 3 function(s) stay stored, and a scope of the target brings them back",
];

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  const opts = options(rest);
  const network = opts.network ?? "rehearsal-26249900";

  if (command === "rehearsal") {
    const dir = opts.dir ?? ".roundtrip";
    const policy = load(path.resolve(import.meta.dir, "..", "artifacts", `${network}.json`), network).policy;
    const file = (name: string) => {
      const full = path.join(dir, name);
      if (!existsSync(full)) throw new Error(`${full} is missing: run the fork test first (just round-trip)`);
      return readEvents(full);
    };
    const vote = file("enabling-vote.ndjson");
    const motion = file("example-motion.ndjson");
    const revoke = file("emergency-revoke.ndjson");
    let ok = print("after the enabling vote, the modifiers hold the committed policy", roundTrip(policy, vote), vote.length);
    ok = print("after the example motion, the modifiers hold its head policy", roundTrip(exampleHead(policy), motion), motion.length) && ok;
    const drift = roundTrip(policy, revoke);
    const seen = JSON.stringify([...drift.differences].sort()) === JSON.stringify([...REVOKE_DIFFERENCES].sort());
    console.log(`${seen ? "PASS" : "FAIL"}: after an emergency revoke, the check reports the revoke and nothing else (${revoke.length} logs)`);
    for (const line of drift.differences) console.log(`  reported: ${line}`);
    for (const line of drift.notes) console.log(`  note: ${line}`);
    return ok && seen ? 0 : 1;
  }

  if (command !== "check" || !opts.artifact) {
    console.error("usage: roundtrip.ts check --artifact <ref> [--network <name>] (--events <file> | --rpc [URL] --from-block N [--to-block N])");
    console.error("       roundtrip.ts rehearsal [--dir .roundtrip]");
    return 2;
  }
  const source = load(opts.artifact, network);
  let logs: Log[];
  if (opts.events) {
    logs = readEvents(opts.events);
  } else {
    const url = opts.rpc === undefined || opts.rpc === "true" || opts.rpc === "env" ? process.env.RPC : opts.rpc;
    if (opts.rpc === undefined || !url) throw new Error("--events, or --rpc with a URL or RPC in the environment, is needed");
    if (opts["from-block"] === undefined) throw new Error("--from-block is needed: the block of the first modifier's deployment");
    const provider = new JsonRpcProvider(url);
    try {
      const to = opts["to-block"] !== undefined ? Number(opts["to-block"]) : await provider.getBlockNumber();
      const addresses = source.policy.modifiers.map((m) => getAddress(m.address));
      logs = await fetchLogs((filter) => provider.getLogs(filter) as unknown as Promise<NodeLog[]>, addresses, Number(opts["from-block"]), to);
    } finally {
      provider.destroy();
    }
  }
  return print(`the modifiers hold the policy of ${source.ref}`, roundTrip(source.policy, logs), logs.length) ? 0 : 1;
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
