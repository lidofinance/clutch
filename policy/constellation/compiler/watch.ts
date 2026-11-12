// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The two detectors of the vault's policy (ADR 013, decision 19; ADR 009, decision 7):
 *
 *   - the drift detector: the modifiers hold the policy that the repository says they hold;
 *   - the motion detector: every open motion of the universal factory is the repository's pending motion.
 *
 *   bun compiler/watch.ts check --events <file>                          a fork's logs
 *   bun compiler/watch.ts check --rpc [URL] --from-block N [--json]      a chain's logs
 *   bun compiler/watch.ts settle --events <file> | --rpc …               record an enacted pending motion
 *   bun compiler/watch.ts rehearsal --dir .roundtrip                     the fork suite's scenarios
 *
 * The repository says which policy the chain holds. With no pending motion, it is the committed artifact. With
 * a pending motion (`pending/<network>/`), it is the motion's base policy until Easy Track enacts a motion with
 * exactly the pending calldata, and the committed artifact after. So the chain is the anchor: a motion file with
 * a base that the chain does not hold fails, whatever the file says. Every enacted motion of the factory must be
 * the pending motion or in the repository's record (`enacted/<network>/`); any other one stays an alert.
 *
 * The command exits with 1 on an alert. Lido's monitoring runs it on a clone of `main` and pages on that exit
 * code; this file holds no schedule and sends no page.
 */
import { existsSync, mkdirSync, readFileSync, renameSync, rmSync } from "node:fs";
import path from "node:path";
import { getAddress, Interface, JsonRpcProvider } from "ethers";
import type { Artifact } from "./compile";
import { acceptedByRole, checkMotion, decodeMotion, ENACTED_DIR, EXAMPLE_NETWORK, exampleMotion, load, loadEnacted, loadPending, PENDING_DIR } from "./motion";
import type { Pending } from "./motion";
import { exampleHead } from "./motion.example";
import { fetchLogs, readEvents, REVOKE_DIFFERENCES, roundTrip } from "./roundtrip";
import type { GetLogs, Log } from "./roundtrip";

const ROOT = path.resolve(import.meta.dir, "..");
/** Lido's Easy Track on mainnet. */
export const EASY_TRACK = "0xF0211b7660680B49De1A7E9f25C65660F0a13Fea";
const TRACK = new Interface([
  "event MotionCreated(uint256 indexed _motionId, address _creator, address indexed _evmScriptFactory, bytes _evmScriptCallData, bytes _evmScript)",
  "event MotionEnacted(uint256 indexed _motionId)",
  "event MotionCanceled(uint256 indexed _motionId)",
  "event MotionRejected(uint256 indexed _motionId)",
]);

const lower = (value: string) => value.toLowerCase();

export type Motion = { id: string; creator: string; calldata: string; status: "open" | "enacted" | "cancelled" | "rejected" };
export type OpenMotion = { id: string; creator: string; calldata: string };

/** Every motion of `factory` that Easy Track created, with what became of it, in the order of creation. */
export function motionsOf(logs: Log[], easyTrack: string, factory: string): Motion[] {
  const motions = new Map<string, Motion>();
  for (const log of logs) {
    if (lower(log.address) !== lower(easyTrack)) continue;
    let event;
    try {
      event = TRACK.parseLog({ topics: log.topics, data: log.data });
    } catch {
      event = null;
    }
    if (!event) continue;
    const id = String(event.args[0]);
    if (event.name === "MotionCreated") {
      if (lower(event.args[2]) === lower(factory)) motions.set(id, { id, creator: getAddress(event.args[1]), calldata: lower(event.args[3]), status: "open" });
      continue;
    }
    const motion = motions.get(id);
    if (motion) motion.status = event.name === "MotionEnacted" ? "enacted" : event.name === "MotionCanceled" ? "cancelled" : "rejected";
  }
  return [...motions.values()];
}

/** The motions of `factory` that Easy Track created and that are not enacted, cancelled or rejected. */
export function openMotions(logs: Log[], easyTrack: string, factory: string): OpenMotion[] {
  return motionsOf(logs, easyTrack, factory)
    .filter((m) => m.status === "open")
    .map(({ id, creator, calldata }) => ({ id, creator, calldata }));
}

export type Watch = {
  /** True if the chain does not hold the expected policy, an open motion fails, or an enacted motion has no record. */
  alert: boolean;
  /** The policy that the chain is compared with: the pending motion's base, or the committed artifact. */
  expected: "base" | "head";
  /** Where the chain differs from the expected policy. */
  drift: string[];
  notes: string[];
  /** The Easy Track id of the pending motion's enactment, if the chain shows it and holds the committed artifact. */
  settle: string | null;
  /** The open motions of the factory. */
  motions: { id: string; creator: string; ok: boolean; problems: string[] }[];
  /** The enacted motions of the factory that are neither in the repository's record nor the pending motion. */
  unrecorded: { id: string; creator: string; problem: string }[];
};

/**
 * Both detectors on one set of logs: the modifiers' and Easy Track's, in the order of emission. `head` is the
 * committed artifact, `pending` is the repository's pending motion, if it has one, and `recorded` is the
 * repository's record of enacted motions: the calldata of each, by its Easy Track id.
 *
 * The pending motion counts as enacted only if Easy Track enacted a motion with exactly its calldata. The
 * chain's state alone does not show it: another motion can make the same permission writes and one more action.
 */
export function watch(head: Artifact, pending: Pending | null, recorded: Map<string, string>, logs: Log[], easyTrack = EASY_TRACK): Watch {
  const all = motionsOf(logs, easyTrack, head.manifest.universalFactory as string);
  const enacted = all.filter((m) => m.status === "enacted");
  const own = pending ? enacted.find((m) => m.calldata === lower(pending.calldata) && !recorded.has(m.id)) : undefined;
  const expected: "base" | "head" = pending && !own ? "base" : "head";
  const report = roundTrip(expected === "base" ? pending!.base : head, logs);
  const notes = [...report.notes];
  const settle = own && report.differences.length === 0 ? own.id : null;
  if (own) notes.push(`the pending motion is enacted as motion ${own.id}: record it and remove its pending files (just motion-settle)`);

  const unrecorded = enacted
    .filter((m) => m !== own && recorded.get(m.id) !== m.calldata)
    .map((m) => ({
      id: m.id,
      creator: m.creator,
      problem: recorded.has(m.id) ? "it was enacted, and its calldata is not the calldata that the repository records for it" : "it was enacted, and the repository holds no record of it",
    }));

  const live = pending && !own ? pending : null;
  const motions = all
    .filter((m) => m.status === "open")
    .map((motion) => {
      const problems: string[] = [];
      if (!live) {
        problems.push(own ? "the repository's pending motion is already enacted, and this motion is another one" : "the repository holds no pending motion");
      } else {
        if (motion.calldata !== lower(live.calldata)) problems.push("its calldata is not the pending motion's");
        try {
          const verdict = checkMotion(live.base, head, decodeMotion(motion.calldata).writes, live.actions);
          problems.push(...verdict.problems, ...verdict.differences);
        } catch {
          problems.push("its calldata does not decode as a motion of the factory");
        }
      }
      if (report.differences.length > 0) problems.push("the chain does not hold the policy that the motion starts from");
      return { id: motion.id, creator: motion.creator, ok: problems.length === 0, problems };
    });
  const alert = report.differences.length > 0 || motions.some((m) => !m.ok) || unrecorded.length > 0;
  return { alert, expected, drift: report.differences, notes, settle, motions, unrecorded };
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

/** The logs of the modifiers and of Easy Track, from an events file or from a node. The RPC URL is never printed. */
async function logsOf(opts: Record<string, string>, head: Artifact, easyTrack: string): Promise<Log[]> {
  if (opts.events) return readEvents(opts.events);
  const url = opts.rpc === undefined || opts.rpc === "true" || opts.rpc === "env" ? process.env.RPC : opts.rpc;
  if (opts.rpc === undefined || !url) throw new Error("--events, or --rpc with a URL or RPC in the environment, is needed");
  if (opts["from-block"] === undefined) throw new Error("--from-block is needed: the block of the first modifier's deployment");
  const provider = new JsonRpcProvider(url);
  try {
    const to = opts["to-block"] !== undefined ? Number(opts["to-block"]) : await provider.getBlockNumber();
    const addresses = [...head.modifiers.map((m) => getAddress(m.address)), getAddress(easyTrack)];
    return await fetchLogs((filter) => provider.getLogs(filter) as unknown as ReturnType<GetLogs>, addresses, Number(opts["from-block"]), to);
  } finally {
    provider.destroy();
  }
}

function print(title: string, result: Watch): void {
  console.log(`${result.alert ? "ALERT" : "OK"}: ${title}`);
  console.log(`  the chain is compared with ${result.expected === "base" ? "the pending motion's base policy" : "the committed artifact"}`);
  for (const line of result.drift) console.log(`  drift: ${line}`);
  for (const line of result.notes) console.log(`  note: ${line}`);
  for (const motion of result.motions) {
    console.log(`  motion ${motion.id}, open, created by ${motion.creator}: ${motion.ok ? "it is the pending motion" : "FAIL"}`);
    for (const line of motion.problems) console.log(`    problem: ${line}`);
  }
  for (const motion of result.unrecorded) console.log(`  motion ${motion.id}, created by ${motion.creator}: FAIL: ${motion.problem}`);
  if (result.motions.length === 0) console.log("  no motion of the factory is open");
}

/** The fork suite's scenarios (test/RoundTrip.t.sol), each with what the detectors must say. */
function rehearsal(dir: string): number {
  const policy = load(path.join(ROOT, "artifacts", `${EXAMPLE_NETWORK}.json`), EXAMPLE_NETWORK).policy;
  const head = exampleHead(policy);
  const calldata = JSON.parse(exampleMotion()).calldata as string;
  const pending: Pending = { base: policy, calldata, actions: [] };
  const none = new Map<string, string>();
  const file = (name: string) => {
    const full = path.join(dir, name);
    if (!existsSync(full)) throw new Error(`${full} is missing: run the fork test first (just round-trip)`);
    return readEvents(full);
  };
  const same = (x: unknown, y: unknown) => JSON.stringify(x) === JSON.stringify(y);
  let ok = true;
  const expect = (title: string, result: Watch, holds: boolean) => {
    console.log(`${holds ? "PASS" : "FAIL"}: ${title}`);
    if (!holds) print("the detectors said", result);
    ok = ok && holds;
  };

  const quiet = watch(policy, null, none, file("enabling-vote.ndjson"));
  expect("after the enabling vote, with no pending motion: no alert and no open motion", quiet, !quiet.alert && quiet.motions.length === 0 && quiet.expected === "head");

  const open = watch(head, pending, none, file("watch-example-open.ndjson"));
  expect(
    "the pending motion is open: no alert, the chain holds its base, and the cancelled motion is skipped",
    open,
    !open.alert && open.expected === "base" && open.motions.length === 1 && open.motions[0].ok && open.settle === null,
  );

  const unknown = watch(policy, null, none, file("watch-widening-open.ndjson"));
  expect(
    "a motion is open and the repository holds none: alert",
    unknown,
    unknown.alert && unknown.drift.length === 0 && unknown.motions.length === 1 && same(unknown.motions[0].problems, ["the repository holds no pending motion"]),
  );

  const other = watch(head, pending, none, file("watch-widening-open.ndjson"));
  expect(
    "a motion is open that is not the pending one: alert, with what it would write",
    other,
    other.alert && other.motions.length === 1 && other.motions[0].problems[0] === "its calldata is not the pending motion's" && other.motions[0].problems.some((p) => p.includes("transfer(address,uint256) on WETH")),
  );

  const enactedLogs = file("example-motion.ndjson");
  const enacted = watch(head, pending, none, enactedLogs);
  expect(
    "the pending motion is enacted: no alert, and a note to record it and to remove its files",
    enacted,
    !enacted.alert && enacted.settle !== null && enacted.motions.length === 0 && enacted.expected === "head" && enacted.unrecorded.length === 0,
  );

  const settled = watch(head, null, new Map([[enacted.settle ?? "", calldata.toLowerCase()]]), enactedLogs);
  expect("after the motion is recorded and its pending files are removed: no alert", settled, !settled.alert && settled.settle === null && settled.unrecorded.length === 0);

  const forgotten = watch(head, null, none, enactedLogs);
  expect(
    "an enacted motion without a record: alert, though the chain holds the artifact",
    forgotten,
    forgotten.alert && forgotten.drift.length === 0 && forgotten.unrecorded.length === 1 && forgotten.unrecorded[0].problem === "it was enacted, and the repository holds no record of it",
  );

  const usurped = watch(head, pending, none, file("watch-other-enacted.ndjson"));
  expect(
    "another motion enacted the pending motion's writes and one more action: alert, and no settlement",
    usurped,
    usurped.alert && usurped.settle === null && usurped.expected === "base" && usurped.drift.length > 0 && usurped.unrecorded.length === 1,
  );

  const revoked = watch(head, pending, none, file("watch-revoke-example-open.ndjson"));
  expect(
    "the pending motion is open after an emergency revoke: alert on the drift and on the motion",
    revoked,
    revoked.alert && same(revoked.drift, [REVOKE_DIFFERENCES[1]]) && revoked.motions.length === 1 && same(revoked.motions[0].problems, ["the chain does not hold the policy that the motion starts from"]),
  );

  // the motion check's evaluation of a role's conditions against the deployed modifier's own answers
  const cases = readFileSync(path.join(dir, "guard-cases.ndjson"), "utf8")
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => JSON.parse(line) as { modifier: string; role: string; to: string; data: string; accepted: boolean; malformedTree: boolean });
  const answer = (c: (typeof cases)[number]) => acceptedByRole(policy, policy.modifiers.find((m) => m.address.toLowerCase() === c.modifier.toLowerCase())!, c.role, c.to, c.data);
  const wellFormed = cases.filter((c) => !c.malformedTree);
  const wrong = wellFormed.filter((c) => answer(c) !== c.accepted);
  const guards = wrong.length === 0 && wellFormed.some((c) => c.accepted) && wellFormed.some((c) => !c.accepted);
  console.log(`${guards ? "PASS" : "FAIL"}: the motion check and the deployed modifiers agree on ${wellFormed.length} writes of the motion roles: ${wellFormed.filter((c) => c.accepted).length} accepted, ${wellFormed.filter((c) => !c.accepted).length} refused`);
  for (const c of wrong) console.log(`  the modifier ${c.accepted ? "accepts" : "refuses"}, and the check says ${answer(c)}: role ${c.role} on ${c.modifier}, data ${c.data.slice(0, 74)}…`);
  const malformed = cases.filter((c) => c.malformedTree);
  const limit = malformed.length > 0 && malformed.every((c) => !c.accepted && answer(c) === true);
  console.log(`${limit ? "PASS" : "FAIL"}: the known limit holds: the modifier refuses a malformed tree that the role's policy accepts, and the check does not see it (${malformed.length} case)`);
  return ok && guards && limit ? 0 : 1;
}

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  const opts = options(rest);
  if (command === "rehearsal") return rehearsal(opts.dir ?? ".roundtrip");
  if (command !== "check" && command !== "settle") {
    console.error("usage: watch.ts check|settle [--network <name>] (--events <file> | --rpc [URL] --from-block N [--to-block N]) [--easy-track <address>] [--json]");
    console.error("       watch.ts rehearsal [--dir .roundtrip]");
    return 2;
  }
  const network = opts.network ?? EXAMPLE_NETWORK;
  const easyTrack = opts["easy-track"] ?? EASY_TRACK;
  const head = load(path.join(ROOT, "artifacts", `${network}.json`), network).policy;
  const pending = loadPending(network);
  const result = watch(head, pending, loadEnacted(network), await logsOf(opts, head, easyTrack), easyTrack);

  if (command === "settle") {
    if (!pending) {
      console.log(`No motion is pending for ${network}.`);
      return 0;
    }
    if (result.settle === null) {
      console.log("Nothing is recorded or removed. Easy Track must have enacted a motion with the pending motion's calldata, and the chain must hold the committed artifact.");
      for (const line of result.drift) console.log(`  drift: ${line}`);
      for (const motion of result.unrecorded) console.log(`  motion ${motion.id}: ${motion.problem}`);
      return 1;
    }
    const record = path.join(ENACTED_DIR, network, `${result.settle}.json`);
    mkdirSync(path.dirname(record), { recursive: true });
    renameSync(path.join(PENDING_DIR, network, "motion.json"), record);
    rmSync(path.join(PENDING_DIR, network), { recursive: true });
    console.log(`Easy Track enacted the pending motion as motion ${result.settle}, and the chain holds the committed artifact.`);
    console.log(`Recorded it as enacted/${network}/${result.settle}.json and removed pending/${network}/. Commit both.`);
    return 0;
  }

  if (opts.json !== undefined) console.log(JSON.stringify(result, null, 2));
  else print(`the policy of ${network} on chain`, result);
  return result.alert ? 1 : 0;
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
