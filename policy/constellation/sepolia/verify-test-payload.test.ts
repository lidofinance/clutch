// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { capturePayload, createNodes } from "./constellation";
import { key } from "../constellation/lib";
import { verifyTestPayload } from "./verify-test-payload";
import manifest from "../../../scripts/fixtures/sepolia-stand-manifest.json";

const fundingAllowances = ["orders_weth", "orders_usdc"].map((name) => ({
  modifier: manifest.operatorModifier, key: key(name), balance: "100", timestamp: "1000",
}));
const snapshot = { block: 11988411, blockHash: "0x" + "ab".repeat(32), fundingAllowances };
const { payload } = await capturePayload(createNodes(manifest, "11111111-1111-4111-8111-111111111111", fundingAllowances));
const raw = Buffer.from(JSON.stringify(payload));

test("serialized declaration recompiles with the pinned funding readback and hashes exact bytes", () => {
  const proof = verifyTestPayload(raw, manifest, snapshot);
  expect(proof).toEqual({ ...snapshot, payloadSha256: createHash("sha256").update(raw).digest("hex"), compiledCalls: 63 });
  const spaced = Buffer.from(JSON.stringify(payload, null, 2));
  expect(verifyTestPayload(spaced, manifest, snapshot).payloadSha256).not.toBe(proof.payloadSha256);
});

test.each(["balance", "timestamp"] as const)("stale saved allowance %s refuses the declaration", (field) => {
  for (let index = 0; index < fundingAllowances.length; index++) {
    const changed = structuredClone(snapshot); changed.fundingAllowances[index][field] = "101";
    expect(() => verifyTestPayload(raw, manifest, changed)).toThrow("differs from the Sepolia policy");
  }
});

test("missing funding readback and a changed call cannot get a proof", () => {
  expect(() => verifyTestPayload(raw, manifest, { ...snapshot, fundingAllowances: [] })).toThrow("Missing allowance readback");
  const changed = structuredClone(payload);
  const node = changed.specification.find((n: any) => n.type === "ROLES");
  node.roles[Object.keys(node.roles)[0]].members = [];
  expect(() => verifyTestPayload(Buffer.from(JSON.stringify(changed)), manifest, snapshot)).toThrow("differs from the Sepolia policy");
});
