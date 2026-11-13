// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { id, toQuantity } from "ethers";
import { type Broadcast, type Manifest, type Rpc, verificationExitCode, verifyDeployment, verifyReceipts } from "./verify-deployment";
import network from "./network.json";

const sender = "0x4cae8fd384bbe8dec68cdfbc2cbe4b398902e03c";
// Public Sepolia setQueue transactions at blocks 11955137–11955138, captured on 2026-10-20.
// Their nonzero starting nonce is intentional: verification must also work with an existing sender.
const captured: Broadcast = {
  chain: 11155111,
  transactions: [
    {
      hash: "0x6d9c9d068d5d71d383a95fa73e06be5e876db8a2aa260f03abb8e3884f368196", transactionType: "CALL",
      contractAddress: "0xf8956fe3a1afa82cca47bf4bc18cf0c947f14de3",
      transaction: { from: sender, to: "0xf8956fe3a1afa82cca47bf4bc18cf0c947f14de3", value: "0x0", input: "0xf3ee7e2c000000000000000000000000ab0c036cc97bb6139431c4559ff3139dfa90560b", nonce: "0x1c", chainId: "0xaa36a7" },
    },
    {
      hash: "0xfc99cdfa84eea5fa3fdb09f914c9c8c061be7018338531a00ee2afe9bc78a98b", transactionType: "CALL",
      contractAddress: "0x86c6e0d5723ed67f5537e71a92a857b6a3aa9290",
      transaction: { from: sender, to: "0x86c6e0d5723ed67f5537e71a92a857b6a3aa9290", value: "0x0", input: "0xf3ee7e2c00000000000000000000000022d549e6697042958678b6ae44ee955a726ceef5", nonce: "0x1d", chainId: "0xaa36a7" },
    },
  ],
  receipts: [
    {
      transactionHash: "0x6d9c9d068d5d71d383a95fa73e06be5e876db8a2aa260f03abb8e3884f368196",
      blockHash: "0x7fbc5d180b22f8f12073dba1003de09d392cba85175cbc44d51ec34dc4f067c3", blockNumber: "0xb66bc1",
      status: "0x1", from: sender, to: "0xf8956fe3a1afa82cca47bf4bc18cf0c947f14de3", contractAddress: null,
      gasUsed: "0x1ed50", effectiveGasPrice: "0x3b9ac9ff", logs: [],
    },
    {
      transactionHash: "0xfc99cdfa84eea5fa3fdb09f914c9c8c061be7018338531a00ee2afe9bc78a98b",
      blockHash: "0x8241fdbbf6e2c1ae63a7508402e5ac18ea66a6861a2fa241472785f4611e6219", blockNumber: "0xb66bc2",
      status: "0x1", from: sender, to: "0x86c6e0d5723ed67f5537e71a92a857b6a3aa9290", contractAddress: null,
      gasUsed: "0x1ed50", effectiveGasPrice: "0x3b9ac9ff", logs: [],
    },
  ],
};
const expected = { chainId: 11155111, controller: sender };
function replay(canonical = structuredClone(captured)) {
  const calls: [string, unknown[]][] = [];
  const rpc: Rpc = async (method, params) => {
    calls.push([method, params]);
    switch (method) {
      case "eth_chainId": return "0xaa36a7";
      case "eth_getTransactionReceipt": return canonical.receipts.find((receipt) => receipt.transactionHash === params[0]) ?? null;
      case "eth_getTransactionByHash": return canonical.transactions.find((tx) => tx.hash === params[0])?.transaction ?? null;
      case "eth_getBlockByNumber": return { hash: captured.receipts[1].blockHash };
      case "eth_getCode": return "0x";
      default: throw new Error(`Unexpected RPC: ${method}`);
    }
  };
  return { rpc, calls };
}

test("wrong chain stops before receipt or state reads", async () => {
  const calls: string[] = [];
  await expect(verifyReceipts(async (method) => { calls.push(method); return "0x1"; }, captured, expected)).rejects.toThrow("Expected Sepolia");
  expect(calls).toEqual(["eth_chainId"]);
});

test("captured receipts accept nonce 28 as baseline and record the actual block range", async () => {
  const { rpc, calls } = replay();
  const report = await verifyReceipts(rpc, captured, expected);
  expect(report.complete).toBe(true);
  expect(report.minedRange).toEqual({ first: 11955137, last: 11955138 });
  expect(report.block).toBe(11955138);
  expect(report.checks.filter((item) => !item.ok)).toEqual([]);
  expect(verificationExitCode(report)).toBe(0);
  expect(calls.every(([method]) => ["eth_chainId", "eth_getTransactionReceipt", "eth_getTransactionByHash"].includes(method))).toBe(true);
});

test.each(["unbroadcast", "missing receipt"])("an incomplete deployment fails: %s", async (reason) => {
  const local = structuredClone(captured);
  const canonical = structuredClone(captured);
  if (reason === "unbroadcast") local.transactions[1].hash = null;
  else canonical.receipts.pop();
  const report = await verifyReceipts(replay(canonical).rpc, local, expected);
  expect(report.complete).toBe(false);
  expect(report.incomplete).toHaveLength(1);
  expect(verificationExitCode(report)).toBe(1);
});

test.each(["failed receipt", "Safe execution failure"])("a mined failure fails verification: %s", async (reason) => {
  const canonical = structuredClone(captured);
  if (reason === "failed receipt") canonical.receipts[1].status = "0x0";
  else canonical.receipts[1].logs = [{ topics: [id("ExecutionFailure(bytes32,uint256)")] }];
  const report = await verifyReceipts(replay(canonical).rpc, captured, expected);
  expect(report.complete).toBe(false);
  expect(report.checks.filter((item) => !item.ok).map((item) => item.name)).toEqual([reason === "failed receipt" ? "tx1.success" : "tx1.safeFailures"]);
  expect(verificationExitCode(report)).toBe(1);
});

test("a nonce gap or a substituted transaction input fails", async () => {
  const canonical = structuredClone(captured);
  canonical.transactions[1].transaction.nonce = "0x1e";
  canonical.transactions[1].transaction.input = "0x12345678";
  const report = await verifyReceipts(replay(canonical).rpc, captured, expected);
  expect(report.complete).toBe(false);
  expect(report.checks.filter((item) => !item.ok).map((item) => item.name)).toEqual(["tx1.nonce", "tx1.inputHash"]);
});

test("initial deployment reads use the last receipt block, not the simulation block or latest state", async () => {
  const manifest: Manifest = { ...expected, deployBlock: 11955106, dependencies: network };
  const names = ["voting", "agent", "operatorSafe", "emergencySafe", "assetSafe", "ordersSafe", "firstLossSafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrack", "easyTrackExecutor", "objectionToken", "burnFactory", "usdShare", "ethShare", "usdQueue", "ethQueue", "usdClaimAsset", "ethClaimAsset"];
  names.forEach((name, i) => manifest[name] = "0x" + (i + 256).toString(16).padStart(40, "0"));
  const { rpc, calls } = replay();
  const report = await verifyDeployment(rpc, manifest, captured);
  expect(report.scope).toBe("initial-deployment");
  expect(report.simulationBlock).toBe(11955106);
  expect(report.block).toBe(11955138);
  const stateReads = calls.filter(([method]) => method === "eth_getCode");
  expect(stateReads).toHaveLength(21);
  expect(stateReads.every(([, params]) => params[1] === toQuantity(11955138))).toBe(true);
  expect(calls.some(([method]) => method === "eth_blockNumber")).toBe(false);
  expect(report.complete).toBe(false); // The negative fixture has no deployed code.
  expect(verificationExitCode(report)).toBe(1);
});
