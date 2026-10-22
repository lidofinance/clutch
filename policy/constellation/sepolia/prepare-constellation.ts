// SPDX-License-Identifier: AGPL-3.0-or-later
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { build } from "./compile";
import { capturePayload, checkPayload, createNodes, workspacePolicyIssues } from "./constellation";
import { diffPolicy } from "./diff";

const ROOT = path.resolve(import.meta.dir, "../../..");
const OUTPUT = path.join(ROOT, "cache/sepolia/constellation");
const READS = new Set(["eth_chainId", "eth_blockNumber", "eth_getBlockByNumber", "eth_getCode", "eth_getLogs", "eth_call"]);

function save(name: string, value: unknown) {
  const temporary = path.join(OUTPUT, `.${name}.${process.pid}.tmp`);
  try {
    writeFileSync(temporary, JSON.stringify(value, null, 2) + "\n", { flag: "wx" });
    renameSync(temporary, path.join(OUTPUT, name));
  } finally { rmSync(temporary, { force: true }); }
}

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
    const command = process.argv[2];
    if (command !== "--diff" && !command) throw new Error("usage: prepare-constellation.ts <workspace UUID> | --diff");
    const endpoint = process.env.SEPOLIA_RPC;
    if (!endpoint) throw new Error("Set SEPOLIA_RPC in the local environment");
    mkdirSync(OUTPUT, { recursive: true });
    const manifest = JSON.parse(readFileSync(process.env.SEPOLIA_MANIFEST ?? path.join(ROOT, "cache/sepolia/manifest.json"), "utf8"));
    const artifact = build(manifest);
    const report = await diffPolicy(readOnlyRpc(endpoint), manifest, artifact);
    let preparedPayloadMatchesCurrent = true;
    let policyIssues: string[] = [];
    if (command !== "--diff") {
      const captured = await capturePayload(createNodes(manifest, command, report.allowances));
      checkPayload(captured.payload, manifest, report.allowances);
      policyIssues = workspacePolicyIssues(captured.payload);
      save("payload.json", captured.payload);
      save("context.json", { workspace: command, manifest, allowances: report.allowances, block: report.block, blockHash: report.blockHash });
      console.log("Prepared 3 existing Safes and 4 existing Roles modifiers with 7 original roles. No deployment nonces or Safe overrides.");
      console.log("Serialized permissions recompile to the same 63 policy calls; current allowance balances and timestamps are preserved.");
    } else {
      try {
        const payload = JSON.parse(readFileSync(path.join(OUTPUT, "payload.json"), "utf8"));
        checkPayload(payload, manifest, report.allowances);
        policyIssues = workspacePolicyIssues(payload);
      } catch {
        preparedPayloadMatchesCurrent = false;
        console.error("Prepared payload is missing or differs from the current policy or allowance values. Run constellation <workspace UUID> again.");
      }
    }
    save("diff.json", { ...report, preparedPayloadMatchesCurrent, workspacePolicyIssues: policyIssues });
    console.log(`Sepolia block ${report.block} (${report.blockHash}): ${report.differences.length} policy differences; ${report.history.events} events checked.`);
    for (const difference of report.differences) console.log(`Difference: ${difference.path}`);
    for (const issue of policyIssues) console.error(`Workspace policy issue: ${issue}`);
    console.log("Report: cache/sepolia/constellation/diff.json. No hosted Zodiac calls or transactions.");
    process.exitCode = report.matches && preparedPayloadMatchesCurrent && !policyIssues.length ? 0 : 1;
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Constellation preparation failed");
    process.exitCode = 1;
  }
}
