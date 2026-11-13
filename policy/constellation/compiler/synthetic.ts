// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Logs for the tests of the round-trip check and of the detectors, built from a policy artifact's calls with the
 * events' signatures. They stand apart from the decoders under test. The fork suite gives those decoders the
 * deployed contracts' real logs (test/RoundTrip.t.sol).
 */
import { encodeBytes32String, Interface } from "ethers";
import type { Artifact } from "./compile";
import type { Log } from "./roundtrip";

export const CALLS = new Interface([
  "function scopeTarget(bytes32 roleKey, address targetAddress)",
  "function revokeTarget(bytes32 roleKey, address targetAddress)",
  "function allowTarget(bytes32 roleKey, address targetAddress, uint8 options)",
  "function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options)",
  "function revokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector)",
  "function scopeFunction(bytes32 roleKey, address targetAddress, bytes4 selector, (uint8 parent, uint8 paramType, uint8 operator, bytes compValue)[] conditions, uint8 options)",
  "function setAllowance(bytes32 key, uint128 balance, uint128 maxRefill, uint128 refill, uint64 period, uint64 timestamp)",
  "function assignRoles(address module, bytes32[] roleKeys, bool[] memberOf)",
]);
export const EVENTS = new Interface([
  "event ScopeTarget(bytes32 roleKey, address targetAddress)",
  "event RevokeTarget(bytes32 roleKey, address targetAddress)",
  "event AllowTarget(bytes32 roleKey, address targetAddress, uint8 options)",
  "event AllowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options)",
  "event RevokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector)",
  "event ScopeFunction(bytes32 roleKey, address targetAddress, bytes4 selector, (uint8 parent, uint8 paramType, uint8 operator, bytes compValue)[] conditions, uint8 options)",
  "event SetAllowance(bytes32 allowanceKey, uint128 balance, uint128 maxRefill, uint128 refill, uint64 period, uint64 timestamp)",
  "event ConsumeAllowance(bytes32 allowanceKey, uint128 consumed, uint128 newBalance)",
  "event AssignRoles(address module, bytes32[] roleKeys, bool[] memberOf)",
  "event EnabledModule(address module)",
  "event DisabledModule(address module)",
  "event RolesModSetup(address indexed initiator, address indexed owner, address indexed avatar, address target)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
  "event Initialized(uint64 version)",
  "event SetUnwrapAdapter(address to, bytes4 selector, address adapter)",
  "event SetDefaultRole(address module, bytes32 defaultRoleKey)",
]);
export const MAX_UINT128 = (1n << 128n) - 1n;
export const BLOCK_TIME = 1_800_000_000n;
export const ZERO = "0x0000000000000000000000000000000000000000";
export const STRANGER = "0x000000000000000000000000000000000000dEaD";
export const SUSDS = "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD";
export const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
export const OPERATOR = encodeBytes32String("operator");
export const APPROVE = "0x095ea7b3";
export const TRANSFER = "0xa9059cbb";

export const lower = (value: string) => value.toLowerCase();
export const event = (address: string, name: string, values: unknown[]): Log => {
  const { topics, data } = EVENTS.encodeEventLog(name, values);
  return { address, topics, data };
};
export const title = (fn: string) => fn[0].toUpperCase() + fn.slice(1);

/** The log that the Roles modifier emits for one administrative call, as its source says. */
export function emitted(to: string, data: string): Log[] {
  const call = CALLS.parseTransaction({ data })!;
  const args = [...call.args];
  if (call.name === "setAllowance") {
    // the modifier stores no maximum of zero and no timestamp of zero
    if (args[2] === 0n) args[2] = MAX_UINT128;
    if (args[5] === 0n) args[5] = BLOCK_TIME;
  }
  const logs = [event(to, title(call.name), args)];
  if (call.name === "assignRoles") logs.unshift(event(to, "EnabledModule", [args[0]]));
  return logs;
}

/** Every log of the vault's modifiers after the enabling vote: the setup of each modifier, then the policy's calls. */
export function launch(policy: Artifact): Log[] {
  const logs: Log[] = [];
  for (const m of policy.modifiers) {
    logs.push(event(m.address, "OwnershipTransferred", [ZERO, m.owner]));
    logs.push(event(m.address, "RolesModSetup", [STRANGER, m.owner, m.avatar, m.target]));
    logs.push(event(m.address, "Initialized", [1]));
  }
  policy.calls.to.forEach((to, i) => logs.push(...emitted(to, policy.calls.data[i])));
  return logs;
}
