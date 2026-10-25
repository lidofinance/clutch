// SPDX-License-Identifier: AGPL-3.0-or-later
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { checkPayload, type RuntimeAllowance } from "./constellation";

export function verifyTestPayload(raw: Buffer, manifest: Record<string, any>, snapshot: {
  block: number; blockHash: string; fundingAllowances: RuntimeAllowance[];
}) {
  const artifact = checkPayload(JSON.parse(raw.toString()), manifest, snapshot.fundingAllowances);
  return { block: snapshot.block, blockHash: snapshot.blockHash,
    payloadSha256: createHash("sha256").update(raw).digest("hex"),
    compiledCalls: artifact.calls.to.length, fundingAllowances: snapshot.fundingAllowances };
}

if (import.meta.main) {
  try {
    const [manifest, payload, snapshot] = process.argv.slice(2);
    if (!manifest || !payload || !snapshot) throw new Error("usage: verify-test-payload.ts <manifest> <payload> <snapshot>");
    console.log(JSON.stringify(verifyTestPayload(readFileSync(payload),
      JSON.parse(readFileSync(manifest, "utf8")), JSON.parse(readFileSync(snapshot, "utf8")))));
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Payload verification failed");
    process.exitCode = 1;
  }
}
