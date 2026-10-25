// SPDX-License-Identifier: AGPL-3.0-or-later
import { getAddress, Interface, keccak256, toQuantity, ZeroAddress, ZeroHash } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import type { build } from "./compile";

type Rpc = (method: string, params: unknown[]) => Promise<any>;
type Artifact = ReturnType<typeof build>;
type Condition = { parent: number; paramType: number; operator: number; compValue: string };
type FunctionState = { selector: string; executionOptions: number; wildcarded: boolean; conditions: Condition[] };
type TargetState = { clearance: number; executionOptions: number; functions: Map<string, FunctionState> };
type RoleState = { members: Set<string>; targets: Map<string, TargetState> };
type Log = { address: string; topics: string[]; data: string; blockNumber: string; blockHash: string; transactionIndex: string; logIndex: string; transactionHash: string; removed: boolean };
type Header = { number: string; hash: string; timestamp: string };
type AllowanceHistory = { initialBalance: bigint; configuredTimestamp: bigint; consumedSinceLastSet: bigint; consumedTotal: bigint; configured: boolean };
type Difference = { path: string; expected: unknown; actual: unknown };
export type AllowanceObservation = {
  modifier: string; key: string; name?: string;
  refill: string; maxRefill: string; period: string; balance: string; timestamp: string;
  initialBalance: string; configuredTimestamp: string; consumedSinceLastSet: string; consumedTotal: string; balanceBelowInitial: string;
};

// The deployed proxies emit OZ's uint64 Initialized event; the pinned SDK still declares uint8.
const ABI = new Interface([...rolesAbi, "event Initialized(uint64 version)",
  "function getOwners() view returns(address[])", "function getThreshold() view returns(uint256)"]);
const SENTINEL = "0x0000000000000000000000000000000000000001";
const GUARD_SLOT = "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8";
const MODULE_GUARD_SLOT = "0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947";
const LOG_RANGE = 1000;
const lower = (value: string) => value.toLowerCase();
const sorted = (values: Iterable<string>) => [...values].map(lower).sort();
const encode = (value: unknown) => JSON.stringify(value, (_, item) => typeof item === "bigint" ? item.toString() : item);
const normalizeConditions = (values: readonly any[]): Condition[] => values.map((value) => ({
  parent: Number(value.parent), paramType: Number(value.paramType), operator: Number(value.operator), compValue: lower(value.compValue),
}));

/** Current policy, reconstructed from the pinned mastercopy's events and checked against live getters. */
export async function diffPolicy(rpc: Rpc, manifest: any, artifact: Artifact) {
  async function read(method: string, params: unknown[]) {
    try { return await rpc(method, params); }
    catch { throw new Error(`${method}: policy read failed; RPC details suppressed`); }
  }
  if (Number(BigInt(await read("eth_chainId", []))) !== 11155111 || manifest.chainId !== 11155111 || artifact.manifest.chainId !== 11155111) {
    throw new Error("Sepolia RPC, manifest and artifact required");
  }
  const block = Number(BigInt(await read("eth_blockNumber", [])));
  const fromBlock = manifest.simulationBlock ?? manifest.deployBlock;
  if (!Number.isSafeInteger(fromBlock) || fromBlock < 1 || fromBlock > block) throw new Error("Invalid deployment history start");
  const tag = toQuantity(block);
  const snapshot = await read("eth_getBlockByNumber", [tag, false]) as Header;
  if (!snapshot || Number(BigInt(snapshot.number)) !== block || !snapshot.hash) throw new Error("Invalid snapshot header");
  const differences: Difference[] = [];
  const allowances: AllowanceObservation[] = [];
  const compare = (path: string, expected: unknown, actual: unknown) => {
    if (encode(expected).toLowerCase() !== encode(actual).toLowerCase()) differences.push({ path, expected, actual });
  };
  const headers = new Map<number, Header>([[block, snapshot]]);
  async function header(number: number) {
    if (!headers.has(number)) {
      const value = await read("eth_getBlockByNumber", [toQuantity(number), false]) as Header;
      if (!value || Number(BigInt(value.number)) !== number || !value.hash) throw new Error("Missing canonical log header");
      headers.set(number, value);
    }
    return headers.get(number)!;
  }
  async function call<T = any>(to: string, name: string, args: unknown[] = []): Promise<T> {
    const result = await read("eth_call", [{ to, data: ABI.encodeFunctionData(name, args) }, tag]);
    try {
      const decoded = ABI.decodeFunctionResult(name, result);
      return (decoded.length === 1 ? decoded[0] : decoded) as T;
    } catch { throw new Error(`Invalid ${name} response at ${to}`); }
  }
  async function modules(to: string) {
    const found = new Set<string>();
    const cursors = new Set<string>();
    let cursor = SENTINEL;
    for (let page = 0; page < 100; page++) {
      if (cursors.has(lower(cursor))) throw new Error("Module pagination cycle");
      cursors.add(lower(cursor));
      const [members, next] = await call<[string[], string]>(to, "getModulesPaginated", [cursor, 100]);
      for (const member of members) {
        const value = lower(getAddress(member));
        if (value === lower(ZeroAddress) || value === SENTINEL || found.has(value)) throw new Error("Invalid module pagination");
        found.add(value);
      }
      if (lower(next) === SENTINEL) return found;
      if (!members.length || lower(next) !== lower(members[members.length - 1])) throw new Error("Incomplete module pagination");
      cursor = getAddress(next);
    }
    throw new Error("Module pagination limit exceeded");
  }

  const mastercopy = manifest.dependencies.contracts.roles;
  const masterCode = await read("eth_getCode", [mastercopy.address, tag]);
  if (keccak256(masterCode) !== mastercopy.codeHash) throw new Error("Pinned Roles mastercopy runtime differs");
  const modifiers = artifact.modifiers;
  if (modifiers.length !== 4 || modifiers.reduce((count, modifier) => count + modifier.roles.length, 0) !== 7) throw new Error("Expected four Sepolia modifiers and seven roles");
  if (new Set(modifiers.map((modifier) => lower(modifier.address))).size !== modifiers.length) throw new Error("Duplicate modifier in artifact");
  let eventCount = 0;
  for (const modifier of modifiers) {
    const address = getAddress(modifier.address);
    const prefix = `modifiers.${address}`;
    const before = await read("eth_getCode", [address, toQuantity(fromBlock - 1)]);
    if (before !== "0x") throw new Error(`History starts after modifier creation: ${address}`);
    const code = await read("eth_getCode", [address, tag]);
    const proxy = `0x363d3d373d3d3d363d73${mastercopy.address.slice(2)}5af43d82803e903d91602b57fd5bf3`;
    if (lower(code) !== lower(proxy)) throw new Error(`Unexpected Roles proxy runtime: ${address}`);
    for (const field of ["owner", "avatar", "target"] as const) compare(`${prefix}.${field}`, modifier[field], await call(address, field));

    const logs: Log[] = [];
    const positions = new Set<string>();
    for (let first = fromBlock; first <= block; first += LOG_RANGE) {
      const last = Math.min(first + LOG_RANGE - 1, block);
      const batch = await read("eth_getLogs", [{ address, fromBlock: toQuantity(first), toBlock: toQuantity(last) }]);
      if (!Array.isArray(batch)) throw new Error("Invalid event history response");
      for (const log of batch as Log[]) {
        const number = Number(BigInt(log.blockNumber));
        const position = `${number}:${BigInt(log.transactionIndex)}:${BigInt(log.logIndex)}`;
        if (lower(log.address) !== lower(address) || log.removed || number < first || number > last || positions.has(position)) throw new Error("Invalid or duplicate event history");
        positions.add(position);
        if (lower((await header(number)).hash) !== lower(log.blockHash)) throw new Error("Noncanonical event history");
        logs.push(log);
      }
    }
    logs.sort((a, b) => Number(BigInt(a.blockNumber) - BigInt(b.blockNumber)) || Number(BigInt(a.transactionIndex) - BigInt(b.transactionIndex)) || Number(BigInt(a.logIndex) - BigInt(b.logIndex)));
    eventCount += logs.length;
    const roles = new Map<string, RoleState>();
    const enabled = new Set<string>();
    const defaultRoles = new Map<string, string>();
    const adapters = new Map<string, string>();
    const history = new Map<string, AllowanceHistory>();
    let setups = 0;
    const role = (key: string) => {
      key = lower(key);
      if (!roles.has(key)) roles.set(key, { members: new Set(), targets: new Map() });
      return roles.get(key)!;
    };
    const target = (key: string, to: string) => {
      const targets = role(key).targets;
      to = lower(to);
      if (!targets.has(to)) targets.set(to, { clearance: 0, executionOptions: 0, functions: new Map() });
      return targets.get(to)!;
    };
    const allowance = (key: string) => {
      key = lower(key);
      if (!history.has(key)) history.set(key, { initialBalance: 0n, configuredTimestamp: 0n, consumedSinceLastSet: 0n, consumedTotal: 0n, configured: false });
      return history.get(key)!;
    };
    for (const log of logs) {
      let event;
      try { event = ABI.parseLog(log); } catch { throw new Error("Malformed Roles event history"); }
      if (!event) throw new Error("Unknown Roles event in pinned proxy history");
      const a = event.args;
      switch (event.name) {
        case "RolesModSetup": setups++; break;
        case "EnabledModule": enabled.add(lower(a.module)); break;
        case "DisabledModule": enabled.delete(lower(a.module)); break;
        case "AssignRoles":
          if (a.roleKeys.length !== a.memberOf.length) throw new Error("Malformed AssignRoles history");
          a.roleKeys.forEach((key: string, i: number) => a.memberOf[i] ? role(key).members.add(lower(a.module)) : role(key).members.delete(lower(a.module)));
          break;
        case "AllowTarget": case "ScopeTarget": case "RevokeTarget": {
          const state = target(a.roleKey, a.targetAddress);
          state.clearance = event.name === "AllowTarget" ? 1 : event.name === "ScopeTarget" ? 2 : 0;
          state.executionOptions = event.name === "AllowTarget" ? Number(a.options) : 0;
          break;
        }
        case "AllowFunction": case "ScopeFunction":
          target(a.roleKey, a.targetAddress).functions.set(lower(a.selector), { selector: lower(a.selector), executionOptions: Number(a.options), wildcarded: event.name === "AllowFunction", conditions: event.name === "ScopeFunction" ? normalizeConditions(a.conditions) : [] });
          break;
        case "RevokeFunction": target(a.roleKey, a.targetAddress).functions.delete(lower(a.selector)); break;
        case "SetDefaultRole": defaultRoles.set(lower(a.module), lower(a.defaultRoleKey)); break;
        case "SetUnwrapAdapter": adapters.set(`${lower(a.to)}${a.selector.slice(2).toLowerCase()}${"0".repeat(16)}`, lower(a.adapter)); break;
        case "SetAllowance": {
          const state = allowance(a.allowanceKey);
          state.initialBalance = a.balance; state.configuredTimestamp = a.timestamp;
          state.consumedSinceLastSet = 0n; state.configured = true;
          break;
        }
        case "ConsumeAllowance": {
          const state = allowance(a.allowanceKey);
          state.consumedSinceLastSet += a.consumed; state.consumedTotal += a.consumed;
          break;
        }
      }
    }
    if (setups !== 1) throw new Error(`Incomplete creation event history: ${address}`);
    const actualModules = await modules(address);
    compare(`${prefix}.eventMembers`, sorted(enabled), sorted(actualModules));
    compare(`${prefix}.enabledMembers`, sorted(new Set(modifier.roles.flatMap((item) => item.members.map((member: { address: string }) => member.address)))), sorted(actualModules));
    for (const member of new Set([...defaultRoles.keys(), ...actualModules])) {
      const value = await call<string>(address, "defaultRoles", [member]);
      compare(`${prefix}.defaultRoleHistory.${member}`, defaultRoles.get(member) ?? ZeroHash, value);
      compare(`${prefix}.defaultRoles.${member}`, ZeroHash, value);
    }
    for (const [key, adapter] of adapters) {
      compare(`${prefix}.unwrapHistory.${key}`, adapter, await call(address, "unwrappers", [key]));
      compare(`${prefix}.unwrappers.${key}`, ZeroAddress, adapter);
    }

    const expectedRoles = new Map(modifier.roles.map((item) => [lower(item.key), item]));
    // A fully revoked empty role has no remaining configuration to compare.
    for (const [key, state] of roles) {
      for (const [to, value] of state.targets) if (value.clearance === 0 && value.functions.size === 0) state.targets.delete(to);
      if (!state.members.size && !state.targets.size) roles.delete(key);
    }
    for (const key of new Set([...expectedRoles.keys(), ...roles.keys()])) {
      const expected = expectedRoles.get(key);
      const actual = roles.get(key);
      const where = `${prefix}.roles.${key}`;
      if (!expected || !actual) { compare(where, expected ? "configured" : null, actual ? "configured" : null); continue; }
      compare(`${where}.members`, sorted(expected.members.map((member: { address: string }) => member.address)), sorted(actual.members));
      const targets = new Map(expected.targets.map((item) => [lower(item.address), item]));
      for (const to of new Set([...targets.keys(), ...actual.targets.keys()])) {
        const e = targets.get(to); const a = actual.targets.get(to);
        const targetPath = `${where}.targets.${to}`;
        if (!e || !a) { compare(targetPath, e ? "configured" : null, a ? "configured" : null); continue; }
        compare(`${targetPath}.clearance`, e.clearance, a.clearance);
        compare(`${targetPath}.executionOptions`, e.executionOptions, a.executionOptions);
        const functions = new Map(e.functions.map((fn) => [lower(fn.selector), fn]));
        for (const selector of new Set([...functions.keys(), ...a.functions.keys()])) {
          const expectedFunction = functions.get(selector);
          compare(`${targetPath}.functions.${selector}`, expectedFunction ? { selector, executionOptions: expectedFunction.executionOptions, wildcarded: expectedFunction.wildcarded, conditions: normalizeConditions(expectedFunction.conditions) } : null, a.functions.get(selector) ?? null);
        }
      }
    }
    const expectedAllowances = new Map(modifier.allowances.map((item) => [lower(item.key), item]));
    for (const key of new Set([...expectedAllowances.keys(), ...history.keys()])) {
      const expected = expectedAllowances.get(key);
      const h = allowance(key);
      const [refill, maxRefill, period, balance, timestamp] = await call<bigint[]>(address, "allowances", [key]);
      if (!expected) compare(`${prefix}.allowances.${key}`, null, "unexpected allowance history");
      else {
        compare(`${prefix}.allowances.${key}.configured`, true, h.configured);
        compare(`${prefix}.allowances.${key}.refill`, BigInt(expected.refill).toString(), refill.toString());
        compare(`${prefix}.allowances.${key}.maxRefill`, (BigInt(expected.maxRefill) || (1n << 128n) - 1n).toString(), maxRefill.toString());
        compare(`${prefix}.allowances.${key}.period`, BigInt(expected.period).toString(), period.toString());
      }
      allowances.push({ modifier: address, key, ...(expected ? { name: expected.name } : {}), refill: refill.toString(), maxRefill: maxRefill.toString(), period: period.toString(), balance: balance.toString(), timestamp: timestamp.toString(), initialBalance: h.initialBalance.toString(), configuredTimestamp: h.configuredTimestamp.toString(), consumedSinceLastSet: h.consumedSinceLastSet.toString(), consumedTotal: h.consumedTotal.toString(), balanceBelowInitial: (h.initialBalance > balance ? h.initialBalance - balance : 0n).toString() });
    }
  }
  for (const address of new Set([manifest.assetSafe, manifest.ordersSafe, manifest.firstLossSafe, manifest.operatorSafe, manifest.emergencySafe] as string[])) {
    compare(`safes.${address}.enabledModules`, sorted(modifiers.filter((item) => lower(item.avatar) === lower(address)).map((item) => item.address)), sorted(await modules(address)));
    const owner = [manifest.operatorSafe, manifest.emergencySafe].some((safe) => lower(safe) === lower(address)) ? manifest.controller : manifest.voting;
    compare(`safes.${address}.owners`, sorted([owner]), sorted(await call<string[]>(address, "getOwners")));
    compare(`safes.${address}.threshold`, "1", (await call<bigint>(address, "getThreshold")).toString());
    for (const [name, slot] of [["guard", GUARD_SLOT], ["moduleGuard", MODULE_GUARD_SLOT]]) {
      const value = await read("eth_getStorageAt", [address, slot, tag]);
      if (typeof value !== "string" || !/^0x[0-9a-fA-F]{64}$/.test(value)) throw new Error("Invalid Safe storage response");
      compare(`safes.${address}.${name}`, ZeroHash, lower(value));
    }
  }
  const final = await read("eth_getBlockByNumber", [tag, false]) as Header;
  if (!final || lower(final.hash) !== lower(snapshot.hash)) throw new Error("Policy snapshot changed during reads; retry after reorg");
  return {
    scope: "current-sepolia-policy", chainId: 11155111, block, blockHash: snapshot.hash, fromBlock,
    matches: differences.length === 0, differences, allowances,
    history: { modifiers: modifiers.length, rolesExpected: 7, events: eventCount, maxBlocksPerRequest: LOG_RANGE },
    limitations: [
      "Permission mappings are reconstructed from canonical RPC logs; completeness beyond creation/getter cross-checks relies on the RPC log service.",
      "Stored function entries are compared even under revoked targets; fully empty revoked roles are omitted.",
      "Safe owners and threshold follow the reduced Sepolia profile; both guard slots must be zero. Safe versions, singleton/fallback slots, target behavior and executable transaction success are outside this comparison.",
      "No default roles or transaction unwrappers are expected.",
      "Allowance balance and timestamp are observations, not configuration drift. Consumption totals come from events; no financial valuation is computed.",
    ],
  };
}
