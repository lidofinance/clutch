// SPDX-License-Identifier: AGPL-3.0-or-later
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { getAddress, Interface, keccak256, toQuantity, ZeroAddress } from "ethers";
import { build } from "./compile";
import { diffPolicy } from "./diff";
import { readOnlyRpc } from "./prepare-constellation";
import { captureMigration, checkMigrationPackage, migrationCalls, migrationManifest, migrationTransactions, payloadHash, MIGRATION_BATCH_EXECUTOR } from "./role-migration";

const ROOT = path.resolve(import.meta.dir, "../../..");
const OUT = path.join(ROOT, "cache/sepolia/role-key-migration");
const ABI = new Interface([
  "function getOwners() view returns(address[])", "function getThreshold() view returns(uint256)",
  "function nonce() view returns(uint256)", "function owner() view returns(address)",
  "function getModulesPaginated(address,uint256) view returns(address[],address)",
]);
const SENTINEL = "0x0000000000000000000000000000000000000001";
const SLOTS = {
  singleton: "0x0",
  guard: "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8",
  moduleGuard: "0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947",
  fallback: "0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5",
};
type Rpc = ReturnType<typeof readOnlyRpc>;

function save(name: string, value: unknown) {
  const temporary = path.join(OUT, `.${name}.${process.pid}.tmp`);
  try {
    writeFileSync(temporary, JSON.stringify(value, null, 2) + "\n", { flag: "wx" });
    renameSync(temporary, path.join(OUT, name));
  } finally { rmSync(temporary, { force: true }); }
}

export async function safeSnapshot(rpc: Rpc, manifest: Record<string, any>, block: number) {
  const tag = toQuantity(block);
  if (keccak256(await rpc("eth_getCode", [MIGRATION_BATCH_EXECUTOR.address, tag])) !== MIGRATION_BATCH_EXECUTOR.codeHash) throw new Error("Pinned MultiSendCallOnly runtime differs");
  async function call(to: string, fn: string, args: unknown[] = []) {
    const result = ABI.decodeFunctionResult(fn, await rpc("eth_call", [{ to, data: ABI.encodeFunctionData(fn, args) }, tag]));
    return result[0];
  }
  if ((await call(manifest.voting, "owner")).toLowerCase() !== manifest.controller.toLowerCase()) throw new Error("Test Voting controller differs");
  const states = [];
  for (const name of ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe"]) {
    const address = manifest[name];
    const owners = [...await call(address, "getOwners")].map((a: string) => a.toLowerCase()).sort();
    const expectedOwner = ["operatorSafe", "emergencySafe"].includes(name) ? manifest.controller : manifest.voting;
    const threshold = Number(await call(address, "getThreshold"));
    if (owners.length !== 1 || owners[0] !== expectedOwner.toLowerCase() || threshold !== 1) throw new Error(`Safe owner/threshold differs: ${name}`);
    const modulesResult = ABI.decodeFunctionResult("getModulesPaginated", await rpc("eth_call", [{ to: address, data: ABI.encodeFunctionData("getModulesPaginated", [SENTINEL, 100]) }, tag]));
    if (modulesResult[1].toLowerCase() !== SENTINEL) throw new Error("Unexpected Safe module pagination");
    const slots: Record<string, string> = {};
    for (const [key, slot] of Object.entries(SLOTS)) slots[key] = await rpc("eth_getStorageAt", [address, slot, tag]);
    if ([slots.guard, slots.moduleGuard].some((v) => BigInt(v) !== 0n)) throw new Error(`Unexpected Safe guard: ${name}`);
    const fallback = getAddress("0x" + slots.fallback.slice(-40));
    if (fallback !== (name === "ordersSafe" ? getAddress(manifest.dependencies.contracts.fallbackHandler.address) : ZeroAddress)) throw new Error(`Safe fallback differs: ${name}`);
    states.push({ name, address, owners, threshold, nonce: String(await call(address, "nonce")), modules: [...modulesResult[0]].map((a: string) => a.toLowerCase()).sort(), slots });
  }
  return states;
}

const allowanceState = (values: any[]) => values.map(({ modifier, key, refill, maxRefill, period, balance, timestamp }) => ({ modifier, key, refill, maxRefill, period, balance, timestamp }));
const same = (a: unknown, b: unknown) => JSON.stringify(a).toLowerCase() === JSON.stringify(b).toLowerCase();

export async function checkBefore(rpc: Rpc, pkg: any, manifest: Record<string, any>) {
  checkMigrationPackage(pkg);
  if (!same(manifest, pkg.sourceManifest)) throw new Error("Source manifest changed; prepare the migration again");
  const report = await diffPolicy(rpc, manifest, build(manifest));
  if (!report.matches) throw new Error(`Source policy has ${report.differences.length} differences`);
  if (!same(allowanceState(pkg.allowances), allowanceState(report.allowances))) throw new Error("Allowance storage changed; prepare the migration again");
  if (!same(pkg.safes, await safeSnapshot(rpc, manifest, report.block))) throw new Error("Safe state or nonce changed; prepare the migration again");
  const old = await rpc("eth_getBlockByNumber", [toQuantity(pkg.block), false]);
  if (old?.hash?.toLowerCase() !== pkg.blockHash.toLowerCase()) throw new Error("Migration snapshot is no longer canonical");
  return report;
}

if (import.meta.main) {
  try {
    const [command, argument, flag] = process.argv.slice(2);
    if (!process.env.SEPOLIA_RPC) throw new Error("Set SEPOLIA_RPC in the local environment");
    const rpc = readOnlyRpc(process.env.SEPOLIA_RPC);
    if (flag !== undefined && !(command === "verify" && flag === "--fork" && process.env.SEPOLIA_RPC === "http://127.0.0.1:8547")) throw new Error("--fork is only for verification on the owned local rehearsal node");
    const manifest = JSON.parse(readFileSync(process.env.SEPOLIA_MANIFEST ?? path.join(ROOT, "cache/sepolia/manifest.json"), "utf8"));
    mkdirSync(OUT, { recursive: true });
    if (command === "prepare") {
      if (!argument) throw new Error("usage: prepare-migration.ts prepare <workspace UUID>");
      const report = await diffPolicy(rpc, manifest, build(manifest));
      if (!report.matches) throw new Error(`Source policy has ${report.differences.length} differences`);
      const safes = await safeSnapshot(rpc, manifest, report.block);
      const captured = await captureMigration(manifest, argument, report.allowances);
      const pkg = {
        format: "clutch.sepolia-role-migration/1", workspace: argument,
        sourceManifest: manifest, manifest: migrationManifest(manifest),
        block: report.block, blockHash: report.blockHash, safes, allowances: report.allowances,
        batchExecutor: MIGRATION_BATCH_EXECUTOR, calls: migrationCalls(manifest), transactions: migrationTransactions(manifest),
        payload: captured.payload, payloadSha256: payloadHash(captured.payload),
      };
      checkMigrationPackage(pkg);
      await checkBefore(rpc, pkg, manifest);
      save("package.json", pkg);
      save("payload.json", captured.payload);
      save("context.json", { workspace: argument, manifest, migration: true, block: report.block, blockHash: report.blockHash, payloadSha256: pkg.payloadSha256 });
      save("target-manifest.json", pkg.manifest);
      console.log(`Prepared ${pkg.calls.length} configuration calls in two atomic Safe batches at Sepolia block ${pkg.block}.`);
      console.log(`Payload SHA-256: ${pkg.payloadSha256}`);
      console.log("Four explicit role deletions; seven policies; no allowance writes or new contracts. No hosted calls or public transactions.");
    } else if (command === "check") {
      const pkg = JSON.parse(readFileSync(path.join(OUT, "package.json"), "utf8"));
      const report = await checkBefore(rpc, pkg, manifest);
      console.log(`Migration package and source state match at block ${report.block}. No transaction sent.`);
    } else if (command === "verify") {
      const hashes = (argument ?? "").split(",");
      if (hashes.length !== 2 || hashes.some((h) => !/^0x[0-9a-f]{64}$/i.test(h))) throw new Error("usage: prepare-migration.ts verify <asset tx hash>,<orders tx hash>");
      const pkg = JSON.parse(readFileSync(path.join(OUT, "package.json"), "utf8"));
      checkMigrationPackage(pkg);
      const receiptBlocks = [];
      for (const [i, hash] of hashes.entries()) {
        const tx = await rpc("eth_getTransactionByHash", [hash]);
        const receipt = await rpc("eth_getTransactionReceipt", [hash]);
        if (!tx || !receipt || receipt.status !== "0x1" || !same(tx.to, pkg.transactions[i].to) || !same(tx.from, manifest.controller) || tx.input !== pkg.transactions[i].data || BigInt(tx.value) !== 0n || Number(BigInt(tx.chainId)) !== 11155111) throw new Error("Successful receipt for each exact migration transaction required");
        const canonical = await rpc("eth_getBlockByNumber", [receipt.blockNumber, false]);
        if (canonical?.hash !== receipt.blockHash) throw new Error("Noncanonical migration receipt");
        receiptBlocks.push(Number(BigInt(receipt.blockNumber)));
      }
      const report = await diffPolicy(rpc, pkg.manifest, build(pkg.manifest));
      const expectedSafes = pkg.safes.map((s: any) => ({ ...s, nonce: String(BigInt(s.nonce) + BigInt(pkg.transactions.filter((c: any) => c.avatar.toLowerCase() === s.address.toLowerCase()).length)) }));
      const safes = await safeSnapshot(rpc, pkg.manifest, report.block);
      const sameAllowances = same(allowanceState(pkg.allowances), allowanceState(report.allowances));
      const sameSafes = same(expectedSafes, safes);
      const verified = { ...report, localOnly: flag === "--fork", transactionHashes: hashes, receiptBlocks, sameAllowances, sameSafes, matches: report.matches && sameAllowances && sameSafes };
      save(flag === "--fork" ? "fork-verification.json" : "verification.json", verified);
      if (!verified.matches) throw new Error("Migration verification differs; inspect role-key-migration/verification.json");
      console.log(`Verified migration: zero policy differences at block ${report.block}; allowance storage and Safe configuration preserved.`);
      console.log("The target manifest is saved separately. The current manifest has not been changed.");
    } else throw new Error("usage: prepare-migration.ts prepare <workspace UUID> | check | verify <transaction hash>");
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Migration preparation failed");
    process.exitCode = 1;
  }
}
