// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { keccak256 } from "ethers";
import { inspect } from "./preflight";

const sender = "0x4CAE8fd384bbe8dec68CdFbC2CbE4b398902E03c";
const code = "0x60006000";
const dependency = { test: { address: sender, codeBytes: 4, codeHash: keccak256(code) } };

test("wrong chain refuses before any dependency read", async () => {
  const calls: string[] = [];
  await expect(inspect(async (method) => { calls.push(method); return "0x1"; }, sender, dependency as any)).rejects.toThrow("Expected Sepolia");
  expect(calls).toEqual(["eth_chainId"]);
});

test("all reads use the selected block; no write method is called", async () => {
  const calls: [string, unknown[]][] = [];
  const result = await inspect(async (method, params) => {
    calls.push([method, params]);
    return ({ eth_chainId: "0xaa36a7", eth_blockNumber: "0x64", eth_getCode: code, eth_getBalance: "0x0" } as any)[method];
  }, sender, dependency as any);
  expect(result.block).toBe(100);
  expect(result.balanceWei).toBe("0");
  expect(calls).toEqual([
    ["eth_chainId", []], ["eth_blockNumber", []],
    ["eth_getCode", [sender, "0x64"]], ["eth_getBalance", [sender, "0x64"]],
  ]);
});

test.each(["0x", "0x0", "bad"])("missing or malformed bytecode refuses: %s", async (value) => {
  const rpc = async (method: string) => ({ eth_chainId: "0xaa36a7", eth_blockNumber: "0x64", eth_getCode: value } as any)[method];
  await expect(inspect(rpc, sender, dependency as any)).rejects.toThrow("missing or malformed");
});

test("a different runtime refuses", async () => {
  const rpc = async (method: string) => ({ eth_chainId: "0xaa36a7", eth_blockNumber: "0x64", eth_getCode: "0x60016000" } as any)[method];
  await expect(inspect(rpc, sender, dependency as any)).rejects.toThrow("runtime hash differs");
});
