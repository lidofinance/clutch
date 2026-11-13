// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { decodeBytes32String, getAddress, id, Interface } from "ethers";
import { build } from "./compile";
import network from "./network.json";
import { unguarded } from "../compiler/compile";

const names = ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrackExecutor", "agent", "usdQueue", "ethQueue", "usdShare", "ethShare", "universalFactory", "usdDepositQueue", "ethDepositQueue"];
const manifest: Record<string, any> = { network: "sepolia", chainId: 11155111, dependencies: network };
names.forEach((name, i) => manifest[name] = getAddress("0x" + (i + 256).toString(16).padStart(40, "0")));
manifest.modules = [manifest.operatorModifier, manifest.safetyModifier];

const artifact = build(manifest);
test("Sepolia compiles four modifiers and sends each configuration call through its avatar", () => {
  expect(artifact.modifiers.length).toBe(4);
  artifact.calls.to.forEach((to, i) => expect(artifact.calls.avatar[i]).toBe(artifact.modifiers.find((m) => m.address === to)!.avatar));
});
test("refuses a wrong chain and overlapping authority accounts", () => {
  expect(() => build({ ...manifest, chainId: 1 })).toThrow("Sepolia manifest");
  expect(() => build({ ...manifest, dependencies: { ...network, chainId: 1 } })).toThrow("Sepolia manifest");
  expect(() => build({ ...manifest, ordersSafe: manifest.assetSafe })).toThrow("addresses must differ");
});
test("governance cannot grant access to any Safe or modifier", () => {
  const protectedAccounts = names.slice(0, 9).map((name) => manifest[name]);
  const grants = ["scopeTarget(bytes32,address)", "allowFunction(bytes32,address,bytes4,uint8)", "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"].map((s) => id(s).slice(0, 10));
  const governance = artifact.modifiers[0].roles.find((r) => r.name === "governance")!;
  for (const fn of governance.targets.flatMap((t) => t.functions).filter((f) => grants.includes(f.selector))) expect(unguarded(fn.conditions, protectedAccounts)).toEqual([]);
});
test("first-loss holder cannot burn, approve or transfer shares", () => {
  const firstLoss = artifact.modifiers.find((m) => m.avatar === manifest.firstLossSafe)!;
  const holder = firstLoss.roles.find((r) => r.name === "first-loss")!;
  expect(holder.targets.map((t) => t.address).sort()).toEqual([manifest.usdQueue, manifest.ethQueue].sort());
});

test("the universal factory holds every motion role, and the Easy Track executor loses its old ones", () => {
  const motionRoles = ["governance", "insurance-funding", "restart", "exit-governance", "approvals", "first-loss-burn", "insurance", "insurance-governance"];
  const held = artifact.modifiers.flatMap((m) => m.roles.filter((r) => motionRoles.includes(r.name)).map((r) => [m.ref, r.name, r.members.map((x: { address: string }) => x.address)]));
  expect(held).toHaveLength(9);
  for (const [, , members] of held) expect(members).toEqual([manifest.universalFactory]);
  const roles = new Interface(["function assignRoles(address,bytes32[],bool[])"]);
  const retired = artifact.calls.data.slice(-2).map((data, i) => [artifact.calls.to.at(i - 2), ...roles.decodeFunctionData("assignRoles", data)]);
  expect(retired.map(([to, member, keys, values]) => [to, member, keys.map(decodeBytes32String), [...values]])).toEqual([
    [manifest.operatorModifier, manifest.easyTrackExecutor, ["governance"], [false]],
    [manifest.firstLossModifier, manifest.easyTrackExecutor, ["first-loss-burn"], [false]],
  ]);
});

test("OD-152: each account has its own operator and emergency keys", () => {
  expect(artifact.modifiers.map((m) => m.roles.map((r) => r.name))).toEqual([
    ["asset-operator", "governance", "insurance-funding"], ["asset-emergency", "restart", "exit-governance"],
    ["orders-operator", "orders-emergency", "governance", "approvals"], ["first-loss", "first-loss-burn", "insurance", "insurance-governance"],
  ]);
});
