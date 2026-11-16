// SPDX-License-Identifier: AGPL-3.0-or-later
import { getAddress, keccak256 } from "ethers";
import network from "./network.json";
import { readOnlyRpc } from "./prepare-constellation";

type Rpc = (method: string, params: unknown[]) => Promise<any>;

/** Read one block consistently. This function sends no transaction. */
export async function inspect(rpc: Rpc, sender: string, dependencies = network.contracts) {
  const chainId = Number(BigInt(await rpc("eth_chainId", [])));
  if (chainId !== network.chainId) throw new Error("Expected Sepolia chain 11155111");
  const block = await rpc("eth_blockNumber", []);
  const contracts: Record<string, unknown> = {};
  for (const [name, expected] of Object.entries(dependencies)) {
    const code = await rpc("eth_getCode", [expected.address, block]);
    if (typeof code !== "string" || !/^0x(?:[0-9a-fA-F]{2})+$/.test(code)) {
      throw new Error(`${name}: contract code is missing or malformed`);
    }
    const codeHash = keccak256(code);
    if (codeHash !== expected.codeHash) throw new Error(`${name}: runtime hash differs from the recorded dependency`);
    contracts[name] = { address: expected.address, codeHash, codeBytes: (code.length - 2) / 2 };
  }
  const balanceWei = BigInt(await rpc("eth_getBalance", [sender, block])).toString();
  return { chainId, block: Number(BigInt(block)), sender: getAddress(sender), balanceWei, contracts };
}

if (import.meta.main) {
  const endpoint = process.env.SEPOLIA_RPC;
  const sender = process.env.SEPOLIA_SENDER;
  if (!endpoint || !sender) throw new Error("Set SEPOLIA_RPC and SEPOLIA_SENDER in the local .env");
  const report = await inspect(readOnlyRpc(endpoint), sender);
  console.log(`Sepolia block ${report.block}: ${Object.keys(report.contracts).length} dependency hashes match.`);
  console.log(`Deployer ${report.sender}; balance ${report.balanceWei} wei.`);
}
