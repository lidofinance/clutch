// SPDX-License-Identifier: AGPL-3.0-or-later
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { getAddress, keccak256 } from "ethers";
import network from "./network.json";

type Rpc = (method: string, params: unknown[]) => Promise<any>;

/** Quote execution fees from public RPC pricing, using only rehearsal gas units. */
export async function quoteFees(rpc: Rpc, stages: Record<string, { gasUsed: number }>) {
  // eth_gasPrice on this RPC returned 21 wei while recent included tips were ~1 gwei.
  const history = await rpc("eth_feeHistory", ["0xa", "latest", [50]]);
  if (!Array.isArray(history.baseFeePerGas) || !Array.isArray(history.reward) || !history.reward.length
      || history.baseFeePerGas.length !== history.reward.length + 1
      || history.reward.some((row: unknown) => !Array.isArray(row) || row.length !== 1)) {
    throw new Error("Invalid RPC fee history");
  }
  const baseFeePerGasWei = BigInt(history.baseFeePerGas.at(-1));
  const rewards = history.reward.map((row: string[]) => BigInt(row[0])) as bigint[];
  if (baseFeePerGasWei < 0n || rewards.some(tip => tip < 0n)) throw new Error("Invalid RPC fee history");
  rewards.sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
  const priorityFeePerGasWei = rewards[Math.floor(rewards.length / 2)];
  const maxFeePerGasWei = 2n * baseFeePerGasWei + priorityFeePerGasWei;
  if (maxFeePerGasWei <= 0n) throw new Error("RPC fee estimate must be positive");
  const quotes = Object.fromEntries(Object.entries(stages).map(([stage, { gasUsed }]) => {
    if (!Number.isSafeInteger(gasUsed) || gasUsed <= 0) throw new Error(`${stage}: invalid rehearsal gas use`);
    return [stage, { gasUnits: gasUsed, feeWei: (BigInt(gasUsed) * maxFeePerGasWei).toString() }];
  }));
  return { observedAt: new Date().toISOString(), baseFeePerGasWei: baseFeePerGasWei.toString(),
    priorityFeePerGasWei: priorityFeePerGasWei.toString(), maxFeePerGasWei: maxFeePerGasWei.toString(), stages: quotes };
}

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
  let sequence = 0;
  const rpc: Rpc = async (method, params) => {
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: ++sequence, method, params }),
        signal: AbortSignal.timeout(20_000),
      });
      if (!response.ok) throw new Error();
      const body = await response.json() as any;
      if (body.error || body.id !== sequence || body.result === undefined) throw new Error();
      return body.result;
    } catch {
      // RPC errors can contain credentials from the endpoint URL.
      throw new Error(`${method}: RPC request failed; endpoint and raw response suppressed`);
    }
  };
  const state = await inspect(rpc, sender);
  const root = path.resolve(import.meta.dir, "../../..");
  const rehearsalPath = path.join(root, "cache/sepolia/rehearsal/result.json");
  const rehearsal = existsSync(rehearsalPath) ? JSON.parse(readFileSync(rehearsalPath, "utf8")) : null;
  if (rehearsal && (rehearsal.chainId !== network.chainId || rehearsal.localOnly !== true)) {
    throw new Error("Expected a local Sepolia rehearsal report");
  }
  const feeQuote = rehearsal ? await quoteFees(rpc, rehearsal.stages) : null;
  const report = { ...state, feeQuote };
  mkdirSync(path.join(root, "cache/sepolia"), { recursive: true });
  writeFileSync(path.join(root, "cache/sepolia/preflight.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(`Sepolia block ${report.block}: ${Object.keys(report.contracts).length} dependency hashes match.`);
  console.log(`Deployer ${report.sender}; balance ${report.balanceWei} wei.`);
  if (feeQuote) {
    for (const [stage, quote] of Object.entries(feeQuote.stages)) console.log(`${stage}: ${quote.feeWei} wei at fee-history estimate ${feeQuote.maxFeePerGasWei} wei/gas.`);
    console.log("Fee estimates exclude ETH transferred or wrapped. Refresh before signing; Foundry selects the transaction fee.");
  } else console.log("Run rehearse to measure gas units before quoting public fees.");
}
