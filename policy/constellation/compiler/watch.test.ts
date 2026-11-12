// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests of the drift detector and the motion detector (ADR 013, decision 19). The logs are built here from the
// artifact's calls and from Easy Track's event signatures. The fork suite gives the detectors the real logs of
// the modifiers and of the live Easy Track (test/RoundTrip.t.sol, `just round-trip`).
import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { Interface } from "ethers";
import type { Artifact } from "./compile";
import { checkMotion, decodeMotion, encodeMotion, exampleMotion, loadPending, PENDING_DIR } from "./motion";
import type { Pending } from "./motion";
import { exampleHead } from "./motion.example";
import type { Log } from "./roundtrip";
import { emitted, event, launch, lower, OPERATOR, STRANGER, SUSDS, TRANSFER } from "./synthetic";
import { EASY_TRACK, openMotions, watch } from "./watch";

const ROOT = path.resolve(import.meta.dir, "..");
const policy = JSON.parse(readFileSync(path.join(ROOT, "artifacts/rehearsal-26249900.json"), "utf8")) as Artifact;
const head = exampleHead(policy);
const example = JSON.parse(exampleMotion());
const pending: Pending = { base: policy, calldata: example.calldata, actions: [] };
const factory = policy.manifest.universalFactory as string;
const committee = policy.manifest.operatorSafe as string;
const opMod = policy.modifiers.find((m) => m.ref === "operator_modifier")!.address;
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

const TRACK = new Interface([
  "event MotionCreated(uint256 indexed _motionId, address _creator, address indexed _evmScriptFactory, bytes _evmScriptCallData, bytes _evmScript)",
  "event MotionEnacted(uint256 indexed _motionId)",
  "event MotionCanceled(uint256 indexed _motionId)",
  "event MotionRejected(uint256 indexed _motionId)",
  "event MotionObjected(uint256 indexed _motionId, address indexed _objector, uint256 _weight, uint256 _newObjectionsAmount, uint256 _newObjectionsAmountPct)",
]);
const track = (name: string, values: unknown[], emitter = EASY_TRACK): Log => {
  const { topics, data } = TRACK.encodeEventLog(name, values);
  return { address: emitter, topics, data };
};
const created = (id: number, calldata: string, by = factory) => track("MotionCreated", [id, committee, by, calldata, "0x"]);
const LAUNCH = launch(policy);
/** The modifiers' logs of the example motion's enactment. */
const ENACTMENT = decodeMotion(example.calldata).writes.flatMap((w) => emitted(w.to, w.data));
/** A motion that no policy change holds: a transfer of WETH for the operator, with no condition. */
const WIDENING = encodeMotion(0n, 0n, [
  { modifier: opMod, role: lower(policy.modifiers.find((m) => m.ref === "operator_modifier")!.roles.find((r) => r.name === "governance")!.key), to: opMod, data: lower(new Interface(["function allowFunction(bytes32,address,bytes4,uint8)"]).encodeFunctionData("allowFunction", [OPERATOR, WETH, TRANSFER, 0])) },
]);

test("a motion is open from its creation until Easy Track enacts, cancels or rejects it", () => {
  const logs = [
    created(1, "0x01"),
    created(2, "0x02"),
    created(3, "0x03"),
    created(4, "0x04"),
    track("MotionObjected", [4, STRANGER, 1, 1, 1]),
    track("MotionEnacted", [1]),
    track("MotionCanceled", [2]),
    track("MotionRejected", [3]),
  ];
  expect(openMotions(logs, EASY_TRACK, factory)).toEqual([{ id: "4", creator: committee, calldata: "0x04" }]);
  // a motion of another factory, and a log of another contract with the same shape, do not count
  expect(openMotions([created(5, "0x05", STRANGER), { ...created(6, "0x06"), address: STRANGER }], EASY_TRACK, factory)).toEqual([]);
  // an enactment of a motion that the logs do not hold changes nothing
  expect(openMotions([track("MotionEnacted", [9]), created(7, "0x07")], EASY_TRACK, factory).map((m) => m.id)).toEqual(["7"]);
});

test("with no pending motion, the chain must hold the committed artifact", () => {
  expect(watch(policy, null, LAUNCH)).toEqual({ alert: false, expected: "head", drift: [], notes: [], settle: false, motions: [] });
  // a policy change that is merged with no pending motion: the chain does not hold the artifact
  const merged = watch(head, null, LAUNCH);
  expect(merged.alert).toBe(true);
  expect(merged.drift.length).toBeGreaterThan(0);
  // an emergency revoke
  const revoked = watch(policy, null, [...LAUNCH, event(opMod, "RevokeTarget", [OPERATOR, SUSDS])]);
  expect(revoked.alert).toBe(true);
  expect(revoked.drift).toEqual(["Clutch operator modifier, role operator: sUSDS is no target on chain; its 3 function(s) stay stored, and a scope of the target brings them back"]);
});

test("a pending motion that waits or is open raises no alert", () => {
  // merged, not created yet: the chain holds the base policy
  expect(watch(head, pending, LAUNCH)).toEqual({ alert: false, expected: "base", drift: [], notes: [], settle: false, motions: [] });
  const open = watch(head, pending, [...LAUNCH, created(11, example.calldata)]);
  expect(open.alert).toBe(false);
  expect(open.motions).toEqual([{ id: "11", creator: committee, ok: true, problems: [] }]);
});

test("after the pending motion enacts, the detector asks for the removal of its files, and does not alert", () => {
  const logs = [...LAUNCH, created(11, example.calldata), ...ENACTMENT, track("MotionEnacted", [11])];
  const enacted = watch(head, pending, logs);
  expect(enacted).toMatchObject({ alert: false, expected: "head", drift: [], settle: true, motions: [] });
  expect(enacted.notes).toEqual(["the pending motion is enacted: remove its files (just motion-settle)"]);
  expect(watch(head, null, logs)).toEqual({ alert: false, expected: "head", drift: [], notes: [], settle: false, motions: [] });
  // a second motion after the enactment is not the pending one, even with the same calldata
  const again = watch(head, pending, [...logs, created(12, example.calldata)]);
  expect(again.alert).toBe(true);
  expect(again.motions[0].problems).toEqual(["the repository's pending motion is already enacted, and this motion is another one"]);
});

// ADR 013, decision 19: a motion that the repository does not hold must page.
test("an open motion that is not the pending motion alerts", () => {
  const none = watch(policy, null, [...LAUNCH, created(21, WIDENING)]);
  expect(none.alert).toBe(true);
  expect(none.drift).toEqual([]);
  expect(none.motions).toEqual([{ id: "21", creator: committee, ok: false, problems: ["the repository holds no pending motion"] }]);

  const other = watch(head, pending, [...LAUNCH, created(22, WIDENING)]);
  expect(other.alert).toBe(true);
  expect(other.motions[0].problems[0]).toBe("its calldata is not the pending motion's");
  // the report says what the motion would write
  expect(other.motions[0].problems).toContain("Clutch operator modifier, role operator: transfer(address,uint256) on WETH has other conditions or other execution options");

  // the pending motion with one more write
  const writes = decodeMotion(example.calldata).writes;
  const extended = encodeMotion(0n, 0n, [...writes, decodeMotion(WIDENING).writes[0]]);
  expect(watch(head, pending, [...LAUNCH, created(23, extended)]).motions[0].ok).toBe(false);

  // the pending motion at another counter: the bytes differ, though the writes are the same
  const stale = watch(head, pending, [...LAUNCH, created(24, encodeMotion(1n, 0n, writes))]);
  expect(stale.motions[0].problems).toEqual(["its calldata is not the pending motion's"]);

  const garbage = watch(head, pending, [...LAUNCH, created(25, "0xdeadbeef")]);
  expect(garbage.motions[0].problems).toEqual(["its calldata is not the pending motion's", "its calldata does not decode as a motion of the factory"]);

  // two open motions: the pending one passes, and the other one alerts
  const two = watch(head, pending, [...LAUNCH, created(26, example.calldata), created(27, WIDENING)]);
  expect(two.alert).toBe(true);
  expect(two.motions.map((m) => m.ok)).toEqual([true, false]);
});

test("a pending motion alerts if the chain does not hold its base policy", () => {
  const logs = [...LAUNCH, event(opMod, "RevokeTarget", [OPERATOR, SUSDS]), created(31, example.calldata)];
  const result = watch(head, pending, logs);
  expect(result.alert).toBe(true);
  expect(result.expected).toBe("base");
  expect(result.drift.length).toBe(1);
  expect(result.motions[0].problems).toEqual(["the chain does not hold the policy that the motion starts from"]);
  // a base that the chain never held: the file cannot make the motion pass
  const forged: Pending = { base: head, calldata: example.calldata, actions: [] };
  expect(watch(head, forged, [...LAUNCH, created(32, example.calldata)]).alert).toBe(true);
});

test("pending files are both there or both absent, and a pending motion passes its own check", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "pending-"));
  expect(loadPending("rehearsal-26249900", dir)).toBeNull();
  mkdirSync(path.join(dir, "rehearsal-26249900"));
  writeFileSync(path.join(dir, "rehearsal-26249900", "motion.json"), exampleMotion());
  expect(() => loadPending("rehearsal-26249900", dir)).toThrow(/both base.json and motion.json/);
  writeFileSync(path.join(dir, "rehearsal-26249900", "base.json"), JSON.stringify(policy));
  const loaded = loadPending("rehearsal-26249900", dir)!;
  expect(loaded.calldata).toBe(example.calldata);
  expect(loaded.actions).toEqual([]);
  expect(checkMotion(loaded.base, head, decodeMotion(loaded.calldata).writes, loaded.actions).ok).toBe(true);
  writeFileSync(path.join(dir, "rehearsal-26249900", "motion.json"), "{}");
  expect(() => loadPending("rehearsal-26249900", dir)).toThrow(/no motion file/);
});

// The repository's own pending motions: each turns its base policy into the committed artifact of its network.
test("every pending motion in the repository turns its base policy into the committed artifact", () => {
  for (const network of ["rehearsal-26249900", "fork-25946643"]) {
    const live = loadPending(network, PENDING_DIR);
    if (!live) continue;
    const committed = JSON.parse(readFileSync(path.join(ROOT, "artifacts", `${network}.json`), "utf8")) as Artifact;
    const verdict = checkMotion(live.base, committed, decodeMotion(live.calldata).writes, live.actions);
    expect({ network, problems: verdict.problems, differences: verdict.differences }).toEqual({ network, problems: [], differences: [] });
  }
});
