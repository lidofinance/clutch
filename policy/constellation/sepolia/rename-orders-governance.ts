// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The calls that move the orders modifier's governance role from the key `governance` to `orders-governance`.
 * Zodiac keeps one policy per role key, and `governance` on the operator modifier holds other grants.
 * The new key takes the artifact's calls; the old key then loses each function, each target and its member,
 * so the comparison with the artifact finds no role left under it.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { Interface } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import { build } from "./compile";
import { key } from "../constellation/lib";

const ROLES = new Interface(rolesAbi);

export function renameCalls(manifest: Record<string, any>) {
  const artifact = build(manifest);
  const orders = artifact.modifiers.find((mod) => mod.ref === "orders_modifier")!;
  const role = orders.roles.find((r) => r.name === "orders-governance")!;
  const own = key("orders-governance").slice(2).toLowerCase();
  const old = key("governance");
  const grant = artifact.calls.data.flatMap((data, i) =>
    artifact.calls.to[i] === orders.address && data.toLowerCase().includes(own) ? [data] : []);
  const revoke = [
    ...role.targets.flatMap((target) => [
      ...target.functions.map((fn) => ROLES.encodeFunctionData("revokeFunction", [old, target.address, fn.selector])),
      ROLES.encodeFunctionData("revokeTarget", [old, target.address]),
    ]),
    ...role.members.map((member: { address: string }) => ROLES.encodeFunctionData("assignRoles", [member.address, [old], [false]])),
  ];
  const data = [...grant, ...revoke];
  return {
    manifest: { chainId: manifest.chainId, controller: manifest.controller, voting: manifest.voting },
    calls: { to: data.map(() => orders.address), avatar: data.map(() => orders.avatar), data },
  };
}

if (import.meta.main) {
  const [input, output] = process.argv.slice(2);
  if (!input || !output) throw new Error("usage: rename-orders-governance.ts <manifest> <output>");
  writeFileSync(output, JSON.stringify(renameCalls(JSON.parse(readFileSync(input, "utf8"))), null, 2) + "\n");
}
