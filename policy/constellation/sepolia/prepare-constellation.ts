// SPDX-License-Identifier: AGPL-3.0-or-later
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { build } from "./compile";
import { capturePayload, checkPayload, createNodes } from "./constellation";
import { diffPolicy } from "./diff";

const ROOT = path.resolve(import.meta.dir, "../../..");
const OUTPUT = path.join(ROOT, "cache/sepolia/constellation");
const READS = new Set(["eth_chainId", "eth_blockNumber", "eth_getBlockByNumber", "eth_getCode", "eth_getLogs", "eth_getStorageAt", "eth_call"]);

export function readOnlyRpc(endpoint: string) {
  let sequence = 0;
  return async (method: string, params: unknown[]) => {
    if (!READS.has(method)) throw new Error(`RPC method refused: ${method}`);
    const id = ++sequence;
    try {
      const response = await fetch(endpoint, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id, method, params }), signal: AbortSignal.timeout(20_000),
      });
      const body = await response.json() as any;
      if (!response.ok || body.error || body.id !== id || body.result === undefined) throw new Error();
      return body.result;
    } catch { throw new Error(`${method}: RPC request failed; endpoint and response suppressed`); }
  };
}

if (import.meta.main) {
  try {
    const workspace = process.argv[2];
    if (!workspace) throw new Error("usage: prepare-constellation.ts <workspace UUID>");
    const endpoint = process.env.SEPOLIA_RPC;
    if (!endpoint) throw new Error("Set SEPOLIA_RPC in the local environment");
    const manifest = JSON.parse(readFileSync(process.env.SEPOLIA_MANIFEST ?? path.join(ROOT, "cache/sepolia/manifest.json"), "utf8"));
    const report = await diffPolicy(readOnlyRpc(endpoint), manifest, build(manifest));
    console.log(`Sepolia block ${report.block} (${report.blockHash}): ${report.differences.length} policy differences.`);
    for (const difference of report.differences) console.log(`Difference: ${difference.path}`);
    if (!report.matches) throw new Error("The chain differs from the policy; no payload prepared");
    const captured = await capturePayload(createNodes(manifest, workspace, report.allowances));
    checkPayload(captured.payload, manifest, report.allowances);
    mkdirSync(OUTPUT, { recursive: true });
    const save = (name: string, value: unknown) => writeFileSync(path.join(OUTPUT, name), JSON.stringify(value, null, 2) + "\n");
    save("payload.json", captured.payload);
    save("context.json", { workspace, manifest, allowances: report.allowances, block: report.block, blockHash: report.blockHash });
    console.log("Prepared 3 Safes and 4 Roles modifiers with 14 roles in cache/sepolia/constellation/. No hosted Zodiac calls or transactions.");
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Constellation preparation failed");
    process.exitCode = 1;
  }
}
