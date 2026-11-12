// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests of the round-trip check (ADR 004, decision 13; INV-016). The logs here are built from the artifact's calls
// with the events' signatures, apart from the check's own decoder. The fork suite gives the check the deployed
// modifier's real logs (test/RoundTrip.t.sol, `just round-trip`).
import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { encodeBytes32String } from "ethers";
import type { Artifact } from "./compile";
import { decodeMotion, exampleMotion } from "./motion";
import { exampleHead } from "./motion.example";
import { fetchLogs, readEvents, roundTrip } from "./roundtrip";
import type { GetLogs, Log } from "./roundtrip";
import { APPROVE, BLOCK_TIME, emitted, event, EVENTS, launch, lower, MAX_UINT128, OPERATOR, STRANGER, SUSDS, TRANSFER, USDC } from "./synthetic";

const ROOT = path.resolve(import.meta.dir, "..");
const policy = JSON.parse(readFileSync(path.join(ROOT, "artifacts/rehearsal-26249900.json"), "utf8")) as Artifact;


const modifierOf = (ref: string) => policy.modifiers.find((m) => m.ref === ref)!;
const opMod = modifierOf("operator_modifier").address;
const LAUNCH = launch(policy);
const differences = (extra: Log[], drop: (log: Log) => boolean = () => false) => roundTrip(policy, [...LAUNCH.filter((log) => !drop(log)), ...extra]).differences;
const isEvent = (log: Log, name: string) => log.topics[0] === EVENTS.getEvent(name)!.topicHash;

test("the launch logs rebuild to the committed policy", () => {
  const logs = LAUNCH;
  expect(logs.length).toBe(policy.calls.to.length + 14 + 12);
  expect(roundTrip(policy, logs)).toEqual({ differences: [], notes: [] });
  // logs of other contracts do not count
  expect(roundTrip(policy, [event(STRANGER, "ScopeTarget", [OPERATOR, STRANGER]), ...logs])).toEqual({ differences: [], notes: [] });
});

test("a modifier without logs is reported", () => {
  const silent = LAUNCH.filter((log) => lower(log.address) !== lower(opMod));
  expect(roundTrip(policy, silent).differences).toEqual(["Clutch operator modifier: the modifier emitted no event"]);
});

// ADR 013, decisions 9 and 11: a motion's writes are raw, so the chain can hold more or less than the policy.
test("a permission that is missing, changed or added is reported", () => {
  const approve = (log: Log) => {
    if (!isEvent(log, "ScopeFunction") || lower(log.address) !== lower(opMod)) return false;
    const a = EVENTS.parseLog(log)!.args;
    return lower(a[0]) === lower(OPERATOR) && lower(a[1]) === lower(USDC) && a[2] === APPROVE;
  };
  expect(differences([], approve)).toEqual(["Clutch operator modifier, role operator: approve(address,uint256) on USDC is missing"]);

  const wide = [[0, 5, 5, "0x"]];
  expect(differences([event(opMod, "ScopeFunction", [OPERATOR, USDC, APPROVE, wide, 0])])).toEqual([
    "Clutch operator modifier, role operator: approve(address,uint256) on USDC has other conditions or other execution options",
  ]);
  // the same tree with a delegatecall
  const original = EVENTS.parseLog(LAUNCH.find(approve)!)!.args;
  expect(differences([event(opMod, "ScopeFunction", [OPERATOR, USDC, APPROVE, original[3], 2])]).length).toBe(1);
  // a function without conditions in place of a tree
  expect(differences([event(opMod, "AllowFunction", [OPERATOR, USDC, APPROVE, 0])]).length).toBe(1);

  expect(differences([event(opMod, "ScopeFunction", [OPERATOR, USDC, "0x23b872dd", wide, 0])])).toEqual([
    "Clutch operator modifier, role operator: 0x23b872dd on USDC is stored, and the policy has no such function",
  ]);
  expect(differences([event(opMod, "ScopeTarget", [OPERATOR, STRANGER]), event(opMod, "AllowFunction", [OPERATOR, STRANGER, TRANSFER, 0])])).toEqual([
    `Clutch operator modifier, role operator: ${lower(STRANGER)} is a target on chain, and the policy has no such target`,
    `Clutch operator modifier, role operator: transfer(address,uint256) on ${lower(STRANGER)} is stored, and the policy has no such function`,
  ]);
  // a function under a target that is not scoped: a later scope of the target makes it work
  expect(differences([event(opMod, "AllowFunction", [OPERATOR, STRANGER, TRANSFER, 0])])).toEqual([
    `Clutch operator modifier, role operator: transfer(address,uint256) on ${lower(STRANGER)} is stored under a target that is not scoped, and the policy has no such function`,
  ]);
  expect(differences([event(opMod, "AllowTarget", [OPERATOR, SUSDS, 0])])).toEqual(["Clutch operator modifier, role operator: sUSDS has another clearance or other execution options"]);
});

// ADR 005, decision 26: the emergency role revokes, and the modifier keeps the revoked target's functions.
test("a revoke is reported, with the functions that stay stored", () => {
  expect(differences([event(opMod, "RevokeTarget", [OPERATOR, SUSDS])])).toEqual([
    "Clutch operator modifier, role operator: sUSDS is no target on chain; its 3 function(s) stay stored, and a scope of the target brings them back",
  ]);
  expect(differences([event(opMod, "RevokeFunction", [OPERATOR, USDC, APPROVE])])).toEqual(["Clutch operator modifier, role operator: approve(address,uint256) on USDC is missing"]);
  // a restore puts the chain back on the policy
  expect(differences([event(opMod, "RevokeTarget", [OPERATOR, SUSDS]), event(opMod, "ScopeTarget", [OPERATOR, SUSDS])])).toEqual([]);
});

test("a membership that the policy does not list is reported, and so is a missing one", () => {
  const committee = modifierOf("operator_modifier").roles.find((r) => r.name === "operator")!.members[0].address;
  expect(differences([event(opMod, "AssignRoles", [STRANGER, [OPERATOR], [true]])])).toEqual([
    `Clutch operator modifier, role operator: ${lower(STRANGER)} is a member, and the policy does not list it`,
  ]);
  expect(differences([event(opMod, "AssignRoles", [committee, [OPERATOR], [false]])])).toEqual(["Clutch operator modifier, role operator: committee's Safe is no member"]);
  const other = encodeBytes32String("other");
  expect(differences([event(opMod, "AssignRoles", [STRANGER, [other], [true]])])).toEqual([
    `Clutch operator modifier, role ${lower(other)}: the role holds 1 member(s), 0 target(s) and 0 function(s), and the policy has no such role`,
  ]);
  // a member whose module the modifier disabled cannot act, though it is still a member
  const factory = policy.manifest.universalFactory as string;
  expect(differences([event(opMod, "DisabledModule", [factory])])).toEqual([
    "Clutch operator modifier, role governance: universal factory is a member, and the modifier has it disabled as a module, so it cannot act",
    "Clutch operator modifier, role insurance-funding: universal factory is a member, and the modifier has it disabled as a module, so it cannot act",
  ]);
  expect(differences([event(opMod, "DisabledModule", [factory]), event(opMod, "EnabledModule", [factory])])).toEqual([]);
  // a module that is enabled and holds no role is a note
  const idle = roundTrip(policy, [...LAUNCH, event(opMod, "EnabledModule", [STRANGER])]);
  expect(idle.differences).toEqual([]);
  expect(idle.notes).toEqual([`Clutch operator modifier: ${lower(STRANGER)} is enabled as a module and is no member of a role in the policy`]);
  // a member that was added and removed again leaves no difference
  expect(differences([event(opMod, "AssignRoles", [STRANGER, [OPERATOR], [true]]), event(opMod, "AssignRoles", [STRANGER, [OPERATOR], [false]])])).toEqual([]);
});

test("budgets: the settings are compared, and a spent balance is a note", () => {
  const key = encodeBytes32String("earn_usd_deposit");
  const set = (balance: bigint, maxRefill: bigint, refill: bigint, period: bigint) => event(opMod, "SetAllowance", [key, balance, maxRefill, refill, period, BLOCK_TIME]);
  const base = 500_000_000n;
  const month = 2_592_000n;
  expect(differences([set(base, base, base, month)])).toEqual([]);
  expect(differences([set(base, base, base * 2n, month)]).length).toBe(1);
  expect(differences([set(base, base, base, month - 1n)]).length).toBe(1);
  expect(differences([set(base, MAX_UINT128, base, month)]).length).toBe(1);
  expect(differences([set(base + 1n, base, base, month)])).toEqual(["Clutch operator modifier: the budget earn_usd_deposit is 500000001, and the policy says 500000000"]);

  const spent = roundTrip(policy, [...LAUNCH, event(opMod, "ConsumeAllowance", [key, 100_000_000n, 400_000_000n])]);
  expect(spent.differences).toEqual([]);
  expect(spent.notes).toEqual(["Clutch operator modifier: the budget earn_usd_deposit was spent since it was set; 400000000 is left, and its balance is not compared"]);

  const unset = (log: Log) => isEvent(log, "SetAllowance") && lower(EVENTS.parseLog(log)!.args[0]) === lower(key);
  expect(differences([], unset)).toEqual(["Clutch operator modifier: the budget earn_usd_deposit is not set"]);
  const foreign = encodeBytes32String("foreign");
  expect(differences([event(opMod, "SetAllowance", [foreign, 1n, 1n, 1n, month, BLOCK_TIME])])).toEqual([`Clutch operator modifier: the budget ${lower(foreign)} is set, and the policy has no such budget`]);
  // an emptied budget is no budget
  expect(differences([event(opMod, "SetAllowance", [foreign, 0n, MAX_UINT128, 0n, month, BLOCK_TIME])])).toEqual([]);
});

test("an unwrap adapter, a default role and another owner are reported", () => {
  expect(differences([event(opMod, "SetUnwrapAdapter", [STRANGER, "0x8d80ff0a", STRANGER])]).length).toBe(1);
  expect(differences([event(opMod, "SetDefaultRole", [STRANGER, OPERATOR])]).length).toBe(1);
  const m = modifierOf("operator_modifier");
  expect(differences([event(opMod, "OwnershipTransferred", [m.owner, STRANGER])])).toEqual([`Clutch operator modifier: its owner is ${lower(STRANGER)}, and the policy says ${m.owner}`]);
  const setup = (log: Log) => isEvent(log, "RolesModSetup") && lower(log.address) === lower(opMod);
  expect(differences([event(opMod, "RolesModSetup", [STRANGER, m.owner, STRANGER, m.target])], setup)).toEqual([`Clutch operator modifier: its avatar is ${lower(STRANGER)}, and the policy says ${m.avatar}`]);
});

// The `motion` command and the round-trip check agree: the example motion's writes, as the modifier's events,
// turn the launch state into the motion's head policy.
test("the example motion's events rebuild to its head policy", () => {
  const motion = decodeMotion(JSON.parse(exampleMotion()).calldata);
  const logs = [...LAUNCH, ...motion.writes.flatMap((w) => emitted(w.to, w.data))];
  expect(roundTrip(exampleHead(policy), logs)).toEqual({ differences: [], notes: [] });
  expect(roundTrip(policy, logs).differences.length).toBeGreaterThan(0);
  expect(roundTrip(exampleHead(policy), LAUNCH).differences.length).toBeGreaterThan(0);
});

test("an events file is read line by line, and a line that is no log fails", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "roundtrip-"));
  const file = path.join(dir, "events.ndjson");
  const logs = LAUNCH;
  writeFileSync(file, logs.map((log) => JSON.stringify(log)).join("\n") + "\n\n");
  expect(readEvents(file)).toEqual(logs);
  writeFileSync(file, '{"address":"0x00","topics":"none","data":"0x"}\n');
  expect(() => readEvents(file)).toThrow(/line 1: not a log/);
});

test("logs from a node are fetched in spans that the node accepts, and put in the order of emission", async () => {
  const chain = [
    { address: opMod, topics: ["0x01"], data: "0x", blockNumber: 105, index: 2 },
    { address: opMod, topics: ["0x02"], data: "0x", blockNumber: 105, index: 1 },
    { address: opMod, topics: ["0x03"], data: "0x", blockNumber: 100, index: 9 },
    { address: opMod, topics: ["0x04"], data: "0x", blockNumber: 2_000, index: 0 },
  ];
  const asked: [number, number][] = [];
  const node: GetLogs = async ({ fromBlock, toBlock }) => {
    asked.push([fromBlock, toBlock]);
    if (toBlock - fromBlock >= 1_000) throw new Error("the range is too wide");
    // in the node's own order, which is not the order of emission here
    return chain.filter((log) => log.blockNumber >= fromBlock && log.blockNumber <= toBlock);
  };
  const logs = await fetchLogs(node, [opMod], 100, 2_500, 4_000);
  expect(logs.map((log) => log.topics[0])).toEqual(["0x03", "0x02", "0x01", "0x04"]);
  const served = asked.filter(([from, to]) => to - from < 1_000);
  expect(served[0][0]).toBe(100);
  expect(served[served.length - 1][1]).toBe(2_500);
  for (let i = 1; i < served.length; i++) expect(served[i][0]).toBe(served[i - 1][1] + 1);
  // a node that always fails ends the fetch
  await expect(fetchLogs(async () => Promise.reject(new Error("down")), [opMod], 1, 10)).rejects.toThrow("down");
});
