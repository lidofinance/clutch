// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { decodeBytes32String, encodeBytes32String, getAddress, Interface, ZeroAddress } from "ethers";
import { rolesAbi } from "zodiac-roles-sdk";
import network from "./network.json";
import { build } from "./compile";
import { captureMigration, checkMigrationPayload, checkMigrationPackage, migrationCalls, migrationTransactions, MIGRATION_BATCH_EXECUTOR, payloadHash } from "./role-migration";

const names = ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrackExecutor", "agent", "usdQueue", "ethQueue", "usdShare", "ethShare", "voting", "controller"];
const source: Record<string, any> = { network: "sepolia", chainId: 11155111, dependencies: network };
names.forEach((name, i) => source[name] = getAddress("0x" + (i + 256).toString(16).padStart(40, "0")));
source.modules = [source.operatorModifier, source.safetyModifier];
const workspace = "25091c1a-4f37-48b1-8d35-f287550481a8";
const runtime = ["orders_weth", "orders_usdc"].map((name) => ({ modifier: source.operatorModifier, key: encodeBytes32String(name), balance: "37", timestamp: "123456" }));
const ABI = new Interface(rolesAbi);

test("migration declaration deletes all four old instances and omits allowance writes", async () => {
  const { payload } = await captureMigration(source, workspace, runtime);
  const roles = payload.specification.filter((n: any) => n.type === "ROLES");
  expect(roles.map((n: any) => Object.keys(n.roles))).toEqual([
    ["asset-operator", "governance", "operator"], ["asset-emergency", "emergency"],
    ["orders-operator", "orders-emergency", "operator", "emergency"], ["first-loss", "first-loss-burn"],
  ]);
  expect(roles.flatMap((n: any) => Object.values(n.roles).filter((r) => r === null))).toHaveLength(4);
  expect(roles.every((n: any) => !("allowances" in n))).toBe(true);
  expect(roles.flatMap((n: any) => Object.values(n.roles).filter(Boolean))).toHaveLength(7);
  expect(checkMigrationPayload(payload, source, runtime).calls.to).toHaveLength(63);
  for (const change of [
    (p: any) => delete p.specification.find((n: any) => n.ref === "operator_modifier").roles.operator,
    (p: any) => p.specification.find((n: any) => n.ref === "operator_modifier").roles["asset-operator"].members.push(source.controller),
    (p: any) => p.specification.find((n: any) => n.ref === "operator_modifier").allowances = {},
    (p: any) => p.specification.find((n: any) => n.ref === "first_loss_modifier").roles["first-loss"] = null,
  ]) {
    const bad = structuredClone(payload); change(bad);
    expect(() => checkMigrationPayload(bad, source, runtime)).toThrow();
  }
});

test("migration keeps action trees and members except for the three updated key references", () => {
  const before = build(source); const after = build({ ...source, roleKeyScheme: "account" });
  const replaceKeys = (value: unknown, replacements: [string, string][]) => {
    let text = JSON.stringify(value);
    for (const [a, b] of replacements) text = text.replaceAll(encodeBytes32String(a), encodeBytes32String(b));
    return JSON.parse(text);
  };
  const expectedNames = [["asset-operator", "governance"], ["asset-emergency"], ["orders-operator", "orders-emergency"], ["first-loss", "first-loss-burn"]];
  for (const [i, modifier] of before.modifiers.entries()) for (const [j, role] of modifier.roles.entries()) {
    const updated = after.modifiers[i].roles[j];
    const references: [string, string][] = role.name === "governance" || i === 1 ? [["operator", "asset-operator"]] : i === 2 && j === 1 ? [["operator", "orders-operator"]] : [];
    expect(updated.name).toBe(expectedNames[i][j]);
    expect(updated.members).toEqual(role.members);
    expect(updated.targets).toEqual(replaceKeys(role.targets, references));
  }
});

test("migration has no allowance or owner writes and clears functions as well as targets", () => {
  const calls = migrationCalls(source);
  const parsed = calls.map((c) => ({ ...c, parsed: ABI.parseTransaction({ data: c.data })! }));
  expect(parsed.some((c) => c.parsed.name === "setAllowance")).toBe(false);
  const assignments = parsed.filter((c) => c.parsed.name === "assignRoles");
  expect(assignments.filter((c) => c.parsed.args[2][0]).map((c) => decodeBytes32String(c.parsed.args[1][0]))).toEqual([
    "asset-emergency", "orders-emergency", "asset-operator", "orders-operator",
  ]);
  expect(assignments.filter((c) => !c.parsed.args[2][0])).toHaveLength(4);
  const before = build(source);
  for (const [index, oldKey] of [[0, "operator"], [1, "emergency"], [2, "operator"], [2, "emergency"]] as const) {
    const modifier = before.modifiers[index];
    const role = modifier.roles.find((r) => r.name === oldKey)!;
    for (const target of role.targets) {
      expect(parsed.some((c) => c.to === modifier.address && c.parsed.name === "revokeTarget" && c.parsed.args[0] === role.key && c.parsed.args[1] === target.address)).toBe(true);
      for (const fn of target.functions) expect(parsed.some((c) => c.to === modifier.address && c.parsed.name === "revokeFunction" && c.parsed.args[0] === role.key && c.parsed.args[1] === target.address && c.parsed.args[2] === fn.selector)).toBe(true);
    }
  }
  expect(new Set(calls.map((c) => c.avatar))).toEqual(new Set([source.assetSafe, source.ordersSafe]));
});

test("two account batches contain only owner-authorised calls with zero values and gas-price fields", () => {
  const transactions = migrationTransactions(source);
  const safe = new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)"]);
  const voting = new Interface(["function execute(address,uint256,bytes)"]);
  const multiSend = new Interface(["function multiSend(bytes)"]);
  expect(transactions.map((t) => t.avatar)).toEqual([source.assetSafe, source.ordersSafe]);
  const decoded: string[] = [];
  for (const tx of transactions) {
    expect(voting.decodeFunctionData("execute", tx.data).toArray()).toEqual([tx.avatar, 0n, tx.safeData]);
    expect(tx.to).toBe(source.voting); expect(tx.value).toBe("0");
    const a = safe.decodeFunctionData("execTransaction", tx.safeData);
    expect(a[0]).toBe("0xA83c336B20401Af773B6219BA5027174338D1836");
    expect([...a.slice(1, 2), ...a.slice(3, 7)]).toEqual([0n, 1n, 0n, 0n, 0n]);
    expect(a[7]).toBe(ZeroAddress); expect(a[8]).toBe(ZeroAddress);
    expect(getAddress("0x" + a[9].slice(26, 66))).toBe(source.voting);
    expect(a[9].slice(-2)).toBe("01");
    expect(multiSend.decodeFunctionData("multiSend", a[2])[0]).toBe(tx.batch);
    let cursor = 2;
    while (cursor < tx.batch.length) {
      expect(tx.batch.slice(cursor, cursor + 2)).toBe("00"); cursor += 2;
      const to = getAddress("0x" + tx.batch.slice(cursor, cursor + 40)); cursor += 40;
      expect(BigInt("0x" + tx.batch.slice(cursor, cursor + 64))).toBe(0n); cursor += 64;
      const size = Number(BigInt("0x" + tx.batch.slice(cursor, cursor + 64))); cursor += 64;
      const chunk = "0x" + tx.batch.slice(cursor, cursor + size * 2); cursor += size * 2;
      expect([source.operatorModifier, source.safetyModifier, source.ordersModifier]).toContain(to);
      decoded.push(chunk);
    }
    expect(cursor).toBe(tx.batch.length);
  }
  expect(decoded).toEqual([source.assetSafe, source.ordersSafe].flatMap((avatar) => migrationCalls(source).filter((c) => c.avatar === avatar).map((c) => c.data)));
});

test("package refuses a substituted transaction, manifest, payload or omitted deletion", async () => {
  const { payload } = await captureMigration(source, workspace, runtime);
  const pkg = { format: "clutch.sepolia-role-migration/1", workspace, block: 123, blockHash: "0x" + "11".repeat(32), batchExecutor: MIGRATION_BATCH_EXECUTOR, sourceManifest: source, manifest: { ...source, roleKeyScheme: "account" }, allowances: runtime, calls: migrationCalls(source), transactions: migrationTransactions(source), payload, payloadSha256: payloadHash(payload) };
  expect(() => checkMigrationPackage(pkg)).not.toThrow();
  for (const mutate of [
    (p: any) => p.transactions[0].to = source.controller,
    (p: any) => p.manifest.operatorSafe = source.controller,
    (p: any) => p.calls.pop(),
    (p: any) => p.payload.label = "unreviewed",
  ]) {
    const bad = structuredClone(pkg); mutate(bad);
    expect(() => checkMigrationPackage(bad)).toThrow();
  }
});
