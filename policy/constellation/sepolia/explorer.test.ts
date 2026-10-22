// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { AbiCoder, keccak256, toUtf8Bytes } from "ethers";
import { checkPackage, exactSourceStatus, inspectSources, sourceStatus, submission, submitSources } from "./explorer";

// Etherscan getsourcecode response fields, including its unverified-contract sentinel.
const unverified = { status: "1", message: "OK", result: [{ SourceCode: "", ABI: "Contract source code not verified", SimilarMatch: "" }] };
const verified = { status: "1", message: "OK", result: [{ SourceCode: "contract Test {}", ABI: "[]", SimilarMatch: "" }] };
// Captured claim-token response: source exists via the objection token, without its own constructor arguments.
const similar = { ...verified, result: [{ ...verified.result[0], SimilarMatch: "0xf5f05f6bae35e6471e29b44913f2f4bdcc181b44", ConstructorArguments: "" }] };

async function fixture(run: (root: string, manifest: any, seal: () => void) => void | Promise<void>) {
  const root = mkdtempSync(`${tmpdir()}/sepolia-explorer-`);
  const source = "contract Test {}";
  const settings = { optimizer: { enabled: true, runs: 200 }, evmVersion: "cancun", viaIR: true };
  const entry = { label: "test", address: "0x0000000000000000000000000000000000000002", contract: "Test.sol:Test",
    compilerVersion: "0.8.24+commit.e11b9ed9", input: `${root}/input.json`, constructorArgsFile: `${root}/args.hex` };
  const manifest = { chainId: 11155111, contracts: [entry], inputs: { Test: { file: entry.input } } };
  writeFileSync(entry.input, JSON.stringify({ sources: { "Test.sol": { content: source } }, settings }));
  writeFileSync(`${root}/manifest.json`, JSON.stringify(manifest));
  writeFileSync(entry.constructorArgsFile, AbiCoder.defaultAbiCoder().encode(["address"], [entry.address]));
  writeFileSync(`${root}/compiled.json`, JSON.stringify({ [entry.contract]: { constructorTypes: ["address"], metadata: {
    compiler: { version: entry.compilerVersion }, sources: { "Test.sol": { keccak256: keccak256(toUtf8Bytes(source)) } }, settings } } }));
  const seal = () => writeFileSync(`${root}/checksums.json`, JSON.stringify(Object.fromEntries(
    [entry.input, entry.constructorArgsFile, `${root}/manifest.json`, `${root}/compiled.json`]
      .map(file => [file, createHash("sha256").update(readFileSync(file)).digest("hex")]))));
  seal();
  try { await run(root, manifest, seal); } finally { rmSync(root, { recursive: true, force: true }); }
}

test("frozen package works without current sources or build artifacts", () => fixture((root, manifest) => {
  expect(checkPackage(root).contracts[0].address).toBe(manifest.contracts[0].address);
  expect(submission(manifest.contracts[0]).compilerversion).toBe("v0.8.24+commit.e11b9ed9");
  expect(submission(manifest.contracts[0]).constructorArguments.startsWith("0x")).toBe(false);
}));

test("changed frozen source refuses", () => fixture((root, manifest) => {
  writeFileSync(manifest.contracts[0].input, "{}");
  expect(() => checkPackage(root)).toThrow("Frozen file changed");
}));

test.each(["source", "settings", "chain", "constructor"])("invalid %s refuses even with matching file checksums", kind => fixture((root, manifest, seal) => {
  const file = manifest.contracts[0].input;
  const input = JSON.parse(readFileSync(file, "utf8"));
  if (kind === "source") input.sources["Test.sol"].content += " ";
  if (kind === "settings") input.settings.optimizer.runs = 1;
  writeFileSync(file, JSON.stringify(input));
  if (kind === "chain") writeFileSync(`${root}/manifest.json`, JSON.stringify({ ...manifest, chainId: 1 }));
  if (kind === "constructor") writeFileSync(manifest.contracts[0].constructorArgsFile, "0x00");
  seal();
  expect(() => checkPackage(root)).toThrow();
}));

test("source status distinguishes source presence from HTTP/API success", async () => {
  expect(sourceStatus(unverified)).toBe(false);
  expect(sourceStatus(verified)).toBe(true);
  expect(() => sourceStatus({ status: "0", result: "Max rate limit reached" })).toThrow("suppressed");
  expect(() => sourceStatus({ status: "1", result: [] })).toThrow("suppressed");
  const calls: string[] = [];
  const result = await inspectSources({ chainId: 11155111, inputs: {}, contracts: [{ address: "0x2", label: "test" } as any] }, async action => {
    calls.push(action); return unverified;
  });
  expect(result[0].verified).toBe(false);
  expect(calls).toEqual(["getsourcecode"]);
});

test("source submission refuses before network access without opt-in", async () => {
  let calls = 0;
  await expect(submitSources({ chainId: 11155111, inputs: {}, contracts: [] }, async () => { calls++; }, "/unused", "0")).rejects.toThrow("SEPOLIA_PUBLISH_SOURCES");
  expect(calls).toBe(0);
});

test("SimilarMatch is recognized source but not exact verification", () => {
  expect(sourceStatus(similar)).toBe(true);
  expect(exactSourceStatus(similar)).toBe(false);
  expect(exactSourceStatus(verified)).toBe(true);
});

test("submit upgrades a similar match using that instance's frozen arguments", () => fixture(async (root, manifest) => {
  const calls: string[] = [];
  await submitSources(manifest, async (action, fields) => {
    calls.push(action);
    if (action === "getsourcecode") return similar;
    if (action === "verifysourcecode") {
      expect(fields.constructorArguments).toBe(submission(manifest.contracts[0]).constructorArguments);
      return { status: "1", result: "claimTokenGuid" };
    }
    return { status: "1", result: "Pass - Verified" };
  }, root, "1");
  expect(calls).toEqual(["getsourcecode", "verifysourcecode", "checkverifystatus"]);
}));

test("a completed source match updates the saved pending GUID", () => fixture(async (root, manifest) => {
  const key = manifest.contracts[0].address.toLowerCase();
  writeFileSync(`${root}/submissions.json`, JSON.stringify({ [key]: { guid: "pendingGuid", verified: false } }));
  await submitSources(manifest, async action => {
    expect(action).toBe("getsourcecode");
    return verified;
  }, root, "1");
  expect(JSON.parse(readFileSync(`${root}/submissions.json`, "utf8"))[key].verified).toBe(true);
}));

test("interrupted status check preserves the GUID and retry does not resubmit", () => fixture(async (root, manifest) => {
  const guid = "verificationGuid123";
  const key = manifest.contracts[0].address.toLowerCase();
  const calls: string[] = [];
  await expect(submitSources(manifest, async action => {
    calls.push(action);
    if (action === "getsourcecode") return unverified;
    if (action === "verifysourcecode") return { status: "1", result: guid };
    throw new Error("Mock status-check interruption");
  }, root, "1")).rejects.toThrow("Mock status-check interruption");
  expect(calls).toEqual(["getsourcecode", "verifysourcecode", "checkverifystatus"]);
  expect(JSON.parse(readFileSync(`${root}/submissions.json`, "utf8"))[key]).toEqual({ guid, verified: false });
  calls.length = 0;
  await submitSources(manifest, async (action, fields) => {
    calls.push(action);
    if (action === "getsourcecode") return unverified;
    if (action === "checkverifystatus") {
      expect(fields).toEqual({ guid });
      return { status: "1", result: "Pass - Verified" };
    }
    throw new Error("Retry must reuse the saved GUID");
  }, root, "1");
  expect(calls).toEqual(["getsourcecode", "checkverifystatus"]);
  expect(JSON.parse(readFileSync(`${root}/submissions.json`, "utf8"))[key]).toEqual({ guid, verified: true });
}));
