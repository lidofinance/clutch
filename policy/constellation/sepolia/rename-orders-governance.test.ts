// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { Interface } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import { build } from "./compile";
import { renameCalls } from "./rename-orders-governance";
import { key } from "../constellation/lib";
import manifest from "../../../scripts/fixtures/sepolia-stand-manifest.json";

const ROLES = new Interface(rolesAbi);

test("grants the orders governance policy under its own key, then empties the old key", () => {
  const { calls } = renameCalls(manifest);
  expect(new Set(calls.to)).toEqual(new Set([manifest.ordersModifier]));
  expect(new Set(calls.avatar)).toEqual(new Set([manifest.ordersSafe]));
  const decoded = calls.data.map((data) => ROLES.parseTransaction({ data })!);
  const [newKey, oldKey] = [key("orders-governance"), key("governance")].map((k) => k.toLowerCase());
  const roleKey = (tx: (typeof decoded)[number]) => (tx.name === "assignRoles" ? tx.args[1][0] : tx.args[0]).toLowerCase();
  const split = decoded.findIndex((tx) => roleKey(tx) === oldKey);
  expect(decoded.slice(0, split).every((tx) => roleKey(tx) === newKey)).toBe(true);
  expect(decoded.slice(split).every((tx) => roleKey(tx) === oldKey)).toBe(true);
  // Every grant of the role in the artifact, and a revocation of each function and target that it holds.
  const role = build(manifest).modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === "orders-governance")!;
  const functions = role.targets.flatMap((t) => t.functions.map((fn) => `${t.address.toLowerCase()}:${fn.selector}`));
  expect(decoded.slice(split).filter((tx) => tx.name === "revokeFunction").map((tx) => `${tx.args[1].toLowerCase()}:${tx.args[2]}`).sort()).toEqual(functions.sort());
  expect(decoded.slice(split).filter((tx) => tx.name === "revokeTarget").map((tx) => tx.args[1].toLowerCase())).toEqual(role.targets.map((t) => t.address.toLowerCase()));
  expect(decoded.slice(0, split).filter((tx) => tx.name !== "assignRoles")).toHaveLength(role.targets.length + functions.length);
  const member = (tx: (typeof decoded)[number]) => [tx.args[0], tx.args[2][0]];
  expect(member(decoded[0])).toEqual([manifest.universalFactory, true]);
  expect(member(decoded.at(-1)!)).toEqual([manifest.universalFactory, false]);
});
