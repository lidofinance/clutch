// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { getAddress, Interface, keccak256, toQuantity, ZeroAddress, ZeroHash, zeroPadValue } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import type { build } from "./compile";
import { diffPolicy } from "./diff";

const ABI = new Interface([...rolesAbi, "event Initialized(uint64 version)", "function getOwners() view returns(address[])", "function getThreshold() view returns(uint256)"]);
const A = (number: number) => getAddress("0x" + number.toString(16).padStart(40, "0"));
const K = (number: number) => zeroPadValue(toQuantity(number).replace(/^0x([0-9a-f])$/, "0x0$1"), 32);
const H = (number: number) => "0x" + number.toString(16).padStart(64, "0");
const PIN = 2100;
const SENTINEL = A(1);
const CODE = "0x6000";

// Events use the pinned SDK ABI. Transitions follow PermissionBuilder/Roles@820e5bc:
// revokeTarget retains functions, scopeTarget resets options, assignRoles(false) does not disable a module.
function fixture() {
  const manifest = {
    chainId: 11155111, simulationBlock: 100, assetSafe: A(10), ordersSafe: A(11), firstLossSafe: A(12),
    operatorSafe: A(13), emergencySafe: A(14), controller: A(15), voting: A(16),
    dependencies: { contracts: { roles: { address: A(900), codeHash: keccak256(CODE) } } },
  };
  const conditions = [{ parent: 0, paramType: 5, operator: 5, compValue: "0x" }, { parent: 0, paramType: 1, operator: 16, compValue: H(123) }];
  const specs = [
    { address: A(20), avatar: manifest.assetSafe, roles: [["operator", K(1), manifest.operatorSafe], ["governance", K(2), A(30)]] },
    { address: A(21), avatar: manifest.assetSafe, roles: [["emergency", K(3), manifest.emergencySafe]] },
    { address: A(22), avatar: manifest.ordersSafe, roles: [["operator", K(1), manifest.operatorSafe], ["emergency", K(3), manifest.emergencySafe]] },
    { address: A(23), avatar: manifest.firstLossSafe, roles: [["first-loss", K(4), manifest.operatorSafe], ["first-loss-burn", K(5), A(30)]] },
  ];
  const modifiers = specs.map((spec, i) => ({
    ref: `modifier${i}`, address: spec.address, owner: spec.avatar, avatar: spec.avatar, target: spec.avatar,
    allowances: i === 0 ? [{ name: "budget", key: K(100), balance: "100", maxRefill: "100", refill: "20", period: "60", timestamp: "0" }] : [],
    roles: spec.roles.map(([name, key, member], j) => ({
      name, key, members: [{ address: member, name: null }],
      targets: [{ address: A(100 + i * 10 + j), name: null, clearance: 2, executionOptions: 0, functions: [{ selector: "0xaabbccdd", signature: "fixture(uint256)", executionOptions: 0, wildcarded: false, conditions: structuredClone(conditions) }] }],
    })),
  }));
  const artifact = { manifest, modifiers } as unknown as ReturnType<typeof build>;
  const logs: any[] = [];
  const emit = (modifier: string, name: string, args: unknown[], block = 101) => {
    const encoded = ABI.encodeEventLog(ABI.getEvent(name)!, args);
    logs.push({ address: modifier, ...encoded, blockNumber: toQuantity(block), blockHash: H(block), transactionIndex: "0x0", logIndex: toQuantity(logs.length), transactionHash: H(500 + logs.length), removed: false });
  };
  const lists = new Map<string, string[]>();
  const owners = new Map<string, string>();
  const defaults = new Map<string, string>();
  const adapters = new Map<string, string>();
  let allowance = [20n, 100n, 60n, 100n, 1000n];
  for (const mod of modifiers) {
    emit(mod.address, "RolesModSetup", [A(901), mod.owner, mod.avatar, mod.target], 100);
    // Raw event captured from all four public deployment receipts. It differs from SDK Initialized(uint8).
    logs.push({ address: mod.address, topics: ["0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2"], data: H(1), blockNumber: "0x64", blockHash: H(100), transactionIndex: "0x0", logIndex: toQuantity(logs.length), transactionHash: H(500 + logs.length), removed: false });
    owners.set(mod.address.toLowerCase(), mod.owner);
    const members = [...new Set(mod.roles.flatMap((role) => role.members.map((member) => member.address)))];
    lists.set(mod.address.toLowerCase(), members);
    for (const member of members) emit(mod.address, "EnabledModule", [member]);
    for (const role of mod.roles) {
      emit(mod.address, "AssignRoles", [role.members[0].address, [role.key], [true]]);
      for (const target of role.targets) {
        emit(mod.address, "ScopeTarget", [role.key, target.address]);
        for (const fn of target.functions) emit(mod.address, "ScopeFunction", [role.key, target.address, fn.selector, fn.conditions, fn.executionOptions]);
      }
    }
    for (const a of mod.allowances) emit(mod.address, "SetAllowance", [a.key, 100n, 100n, 20n, 60n, 1000n]);
  }
  for (const safe of [manifest.assetSafe, manifest.ordersSafe, manifest.firstLossSafe, manifest.operatorSafe, manifest.emergencySafe]) {
    lists.set(safe.toLowerCase(), modifiers.filter((mod) => mod.avatar === safe).map((mod) => mod.address));
  }
  const safeOwners = new Map([manifest.assetSafe, manifest.ordersSafe, manifest.firstLossSafe, manifest.operatorSafe, manifest.emergencySafe].map((safe) => [safe.toLowerCase(), [safe === manifest.operatorSafe || safe === manifest.emergencySafe ? manifest.controller : manifest.voting]]));
  const thresholds = new Map([...safeOwners.keys()].map((safe) => [safe, 1n]));
  const storage = new Map<string, string>();
  const calls: [string, unknown[]][] = [];
  const control = { wrongChain: false, reorg: false, oldCode: false, unsupportedLogs: false, wrongLogHash: false };
  let snapshotReads = 0;
  const rpc = async (method: string, params: any[]) => {
    calls.push([method, params]);
    switch (method) {
      case "eth_chainId": return control.wrongChain ? "0x1" : "0xaa36a7";
      case "eth_blockNumber": return toQuantity(PIN);
      case "eth_getBlockByNumber": {
        const number = Number(BigInt(params[0]));
        if (number === PIN) snapshotReads++;
        return { number: params[0], timestamp: toQuantity(1000 + number), hash: H(number + (control.reorg && number === PIN && snapshotReads > 1 ? 1 : 0)) };
      }
      case "eth_getCode": {
        if (params[1] === "0x63") return control.oldCode ? CODE : "0x";
        if (params[0].toLowerCase() === A(900).toLowerCase()) return CODE;
        return `0x363d3d373d3d3d363d73${A(900).slice(2)}5af43d82803e903d91602b57fd5bf3`;
      }
      case "eth_getLogs": {
        if (control.unsupportedLogs) throw new Error("https://example.invalid/private-key");
        const filter = params[0];
        return logs.filter((log) => log.address.toLowerCase() === filter.address.toLowerCase() && BigInt(log.blockNumber) >= BigInt(filter.fromBlock) && BigInt(log.blockNumber) <= BigInt(filter.toBlock)).map((log) => control.wrongLogHash ? { ...log, blockHash: H(999) } : log);
      }
      case "eth_getStorageAt": {
        expect(params[2]).toBe(toQuantity(PIN));
        return storage.get(`${params[0].toLowerCase()}:${params[1].toLowerCase()}`) ?? ZeroHash;
      }
      case "eth_call": {
        expect(params[1]).toBe(toQuantity(PIN));
        const { to, data } = params[0];
        const query = ABI.parseTransaction({ data })!;
        const mod = modifiers.find((item) => item.address.toLowerCase() === to.toLowerCase());
        let result: unknown[];
        switch (query.name) {
          // Shape captured from all five deployed Safe getters on the pinned Sepolia fork.
          case "getOwners": result = [safeOwners.get(to.toLowerCase())]; break;
          case "getThreshold": result = [thresholds.get(to.toLowerCase())]; break;
          case "owner": result = [owners.get(to.toLowerCase())]; break;
          case "avatar": case "target": result = [mod![query.name]]; break;
          case "getModulesPaginated": {
            const all = lists.get(to.toLowerCase())!;
            const start = query.args[0].toLowerCase() === SENTINEL.toLowerCase() ? 0 : all.findIndex((member) => member.toLowerCase() === query.args[0].toLowerCase()) + 1;
            const page = all.slice(start, start + 100);
            result = [page, start + page.length === all.length ? SENTINEL : page[page.length - 1]];
            break;
          }
          case "defaultRoles": result = [defaults.get(query.args[0].toLowerCase()) ?? ZeroHash]; break;
          case "unwrappers": result = [adapters.get(query.args[0].toLowerCase()) ?? ZeroAddress]; break;
          case "allowances": result = allowance; break;
          default: throw new Error(`Unexpected getter ${query.name}`);
        }
        return ABI.encodeFunctionResult(query.name, result);
      }
      default: throw new Error(`Unexpected RPC ${method}`);
    }
  };
  return { manifest, artifact, modifiers, rpc, calls, logs, emit, lists, owners, safeOwners, thresholds, storage, defaults, adapters, control, setAllowance: (value: bigint[]) => allowance = value };
}

test("seven roles and four modifiers match; timestamp zero is initialization, not drift", async () => {
  const f = fixture(); const report = await diffPolicy(f.rpc, f.manifest, f.artifact);
  expect(report.matches).toBe(true); expect(report.differences).toEqual([]);
  expect(report.block).toBe(PIN); expect(report.blockHash).toBe(H(PIN)); expect(report.fromBlock).toBe(100);
  expect(report.allowances[0]).toMatchObject({ modifier: A(20), key: K(100), refill: "20", maxRefill: "100", period: "60", balance: "100", timestamp: "1000" });
  const ranges = f.calls.filter(([method]) => method === "eth_getLogs").map(([, params]) => params[0] as any);
  expect(ranges).toHaveLength(12);
  expect(ranges.every((range) => BigInt(range.toBlock) - BigInt(range.fromBlock) < 1000n)).toBe(true);
  expect(f.calls.every(([method]) => ["eth_chainId", "eth_blockNumber", "eth_getBlockByNumber", "eth_getCode", "eth_getLogs", "eth_call", "eth_getStorageAt"].includes(method))).toBe(true);
});

test("consumed balance and accrued timestamp remain observations, while refill configuration drifts", async () => {
  const f = fixture(); f.emit(A(20), "ConsumeAllowance", [K(100), 30n, 70n]);
  f.setAllowance([20n, 100n, 60n, 70n, 1060n]);
  const report = await diffPolicy(f.rpc, f.manifest, f.artifact);
  expect(report.matches).toBe(true);
  expect(report.allowances[0]).toMatchObject({ balance: "70", timestamp: "1060", consumedSinceLastSet: "30", consumedTotal: "30", balanceBelowInitial: "30" });
  f.setAllowance([21n, 101n, 61n, 70n, 1060n]);
  expect((await diffPolicy(f.rpc, f.manifest, f.artifact)).differences.map((item) => item.path.split(".").at(-1))).toEqual(["refill", "maxRefill", "period"]);
});

test("extra member, role, target and function are reported", async () => {
  const f = fixture(), role = f.modifiers[0].roles[0];
  f.emit(A(20), "EnabledModule", [A(99)]); f.lists.get(A(20).toLowerCase())!.push(A(99));
  f.emit(A(20), "AssignRoles", [A(99), [role.key, K(99)], [true, true]]);
  f.emit(A(20), "ScopeTarget", [role.key, A(333)]);
  f.emit(A(20), "AllowFunction", [role.key, role.targets[0].address, "0x01020304", 0]);
  const paths = (await diffPolicy(f.rpc, f.manifest, f.artifact)).differences.map((item) => item.path);
  expect(paths.some((path) => path.endsWith(".members"))).toBe(true);
  expect(paths.some((path) => path.endsWith(`.roles.${K(99)}`))).toBe(true);
  expect(paths.some((path) => path.endsWith(`.targets.${A(333).toLowerCase()}`))).toBe(true);
  expect(paths.some((path) => path.endsWith(".functions.0x01020304"))).toBe(true);
});

test.each(["membership", "target", "function", "wildcard", "conditions", "options"])("permission changes are detected: %s", async (change) => {
  const f = fixture(), role = f.modifiers[0].roles[0], target = role.targets[0], fn = target.functions[0];
  if (change === "membership") f.emit(A(20), "AssignRoles", [role.members[0].address, [role.key], [false]]);
  if (change === "target") f.emit(A(20), "RevokeTarget", [role.key, target.address]);
  if (change === "function") f.emit(A(20), "RevokeFunction", [role.key, target.address, fn.selector]);
  if (change === "wildcard") f.emit(A(20), "AllowFunction", [role.key, target.address, fn.selector, 0]);
  if (change === "conditions") f.emit(A(20), "ScopeFunction", [role.key, target.address, fn.selector, [{ ...fn.conditions[0] }, { ...fn.conditions[1], compValue: H(124) }], 0]);
  if (change === "options") f.emit(A(20), "ScopeFunction", [role.key, target.address, fn.selector, fn.conditions, 2]);
  expect((await diffPolicy(f.rpc, f.manifest, f.artifact)).matches).toBe(false);
});

test("revoking then scoping a target preserves its old function entries and resets options", async () => {
  const f = fixture(), role = f.modifiers[0].roles[0], target = role.targets[0];
  f.emit(A(20), "AllowTarget", [role.key, target.address, 3]);
  f.emit(A(20), "RevokeTarget", [role.key, target.address]);
  f.emit(A(20), "ScopeTarget", [role.key, target.address]);
  expect((await diffPolicy(f.rpc, f.manifest, f.artifact)).matches).toBe(true);
});

test("member pagination reads every page and detects modules without role assignments", async () => {
  const f = fixture();
  for (let i = 0; i < 101; i++) {
    f.lists.get(A(20).toLowerCase())!.push(A(400 + i));
    f.emit(A(20), "EnabledModule", [A(400 + i)]);
  }
  const report = await diffPolicy(f.rpc, f.manifest, f.artifact);
  expect(report.matches).toBe(false);
  expect(report.differences.some((item) => item.path.endsWith(".enabledMembers") && (item.actual as string[]).length === 103)).toBe(true);
  const secondPage = f.calls.filter(([method, params]) => method === "eth_call" && ABI.parseTransaction({ data: (params[0] as any).data })?.name === "getModulesPaginated")
    .some(([, params]) => ABI.parseTransaction({ data: (params[0] as any).data })!.args[0].toLowerCase() !== SENTINEL.toLowerCase());
  expect(secondPage).toBe(true);
});

test("disabling a member changes enabled status without erasing role membership", async () => {
  const f = fixture();
  f.emit(A(20), "DisabledModule", [f.manifest.operatorSafe]);
  f.lists.set(A(20).toLowerCase(), [A(30)]);
  const report = await diffPolicy(f.rpc, f.manifest, f.artifact);
  expect(report.differences.map((item) => item.path.split(".").at(-1))).toEqual(["enabledMembers"]);
});

test("proxy code cannot be replaced while retaining a seemingly valid event history", async () => {
  const f = fixture();
  const rpc = async (method: string, params: unknown[]) => method === "eth_getCode" && params[0] === A(20) && params[1] === toQuantity(PIN) ? "0x6001" : f.rpc(method, params);
  await expect(diffPolicy(rpc, f.manifest, f.artifact)).rejects.toThrow("Unexpected Roles proxy runtime");
});

test("unexpected default roles, unwrap adapters, Safe modules and ownership changes are reported", async () => {
  const f = fixture();
  f.defaults.set(A(13).toLowerCase(), K(1)); f.emit(A(20), "SetDefaultRole", [A(13), K(1)]);
  const key = `${A(555).toLowerCase()}aabbccdd${"0".repeat(16)}`;
  f.adapters.set(key, A(556)); f.emit(A(20), "SetUnwrapAdapter", [A(555), "0xaabbccdd", A(556)]);
  f.lists.get(A(10).toLowerCase())!.push(A(99)); f.owners.set(A(21).toLowerCase(), A(99));
  const paths = (await diffPolicy(f.rpc, f.manifest, f.artifact)).differences.map((item) => item.path);
  expect(paths.some((path) => path.includes(".defaultRoles."))).toBe(true);
  expect(paths.some((path) => path.includes(".unwrappers."))).toBe(true);
  expect(paths.some((path) => path.endsWith(".enabledModules"))).toBe(true);
  expect(paths.some((path) => path.endsWith(".owner"))).toBe(true);
});

test.each(["wrong chain", "reorg", "old code", "omitted setup", "noncanonical logs", "unsupported logs"])("cannot claim complete history: %s", async (failure) => {
  const f = fixture();
  if (failure === "wrong chain") f.control.wrongChain = true;
  if (failure === "reorg") f.control.reorg = true;
  if (failure === "old code") f.control.oldCode = true;
  if (failure === "omitted setup") f.logs.splice(f.logs.findIndex((log) => log.topics[0] === ABI.getEvent("RolesModSetup")!.topicHash), 1);
  if (failure === "noncanonical logs") f.control.wrongLogHash = true;
  if (failure === "unsupported logs") f.control.unsupportedLogs = true;
  let error = "";
  try { await diffPolicy(f.rpc, f.manifest, f.artifact); } catch (caught) { error = (caught as Error).message; }
  expect(error.length).toBeGreaterThan(0); expect(error).not.toContain("private-key");
  if (failure === "wrong chain") expect(f.calls.map(([method]) => method)).toEqual(["eth_chainId"]);
});

test("a missing permission event becomes missing configuration rather than an assumed match", async () => {
  const f = fixture(); f.logs.splice(f.logs.findIndex((log) => log.topics[0] === ABI.getEvent("ScopeFunction")!.topicHash), 1);
  expect((await diffPolicy(f.rpc, f.manifest, f.artifact)).matches).toBe(false);
});

// Safe getter shapes were captured at block 11988226. Local self-calls to the
// deployed Safes reproduce owner/threshold/guard mutations independently of this mock.
for (const safeName of ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe"] as const) {
  test.each(["owners", "threshold", "guard", "moduleGuard"])(`Safe ${safeName} configuration drift is reported: %s`, async (field) => {
    const f = fixture(), safe = f.manifest[safeName];
    if (field === "owners") f.safeOwners.set(safe.toLowerCase(), [A(99)]);
    if (field === "threshold") f.thresholds.set(safe.toLowerCase(), 2n);
    if (field === "guard" || field === "moduleGuard") {
      const slot = field === "guard" ? "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8" : "0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947";
      f.storage.set(`${safe.toLowerCase()}:${slot}`, zeroPadValue(A(99), 32));
    }
    const report = await diffPolicy(f.rpc, f.manifest, f.artifact);
    expect(report.matches).toBe(false);
    expect(report.differences.map((item) => item.path)).toEqual([`safes.${safe}.${field}`]);
  });
}

test.each([null, "0x0", "0x" + "gg".repeat(32)])("invalid Safe storage response stops verification: %s", async (value) => {
  const f = fixture();
  const rpc = (method: string, params: any[]) => method === "eth_getStorageAt" ? Promise.resolve(value) : f.rpc(method, params);
  await expect(diffPolicy(rpc, f.manifest, f.artifact)).rejects.toThrow("Invalid Safe storage response");
});
