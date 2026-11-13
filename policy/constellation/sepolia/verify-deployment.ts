// SPDX-License-Identifier: AGPL-3.0-or-later
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { getAddress, id, Interface, keccak256, toQuantity } from "ethers";

export type Rpc = (method: string, params: unknown[]) => Promise<unknown>;
type Transaction = { from: string; to: string | null; input: string; nonce: string; chainId: string; value: string };
type Receipt = {
  transactionHash: string; blockHash: string; blockNumber: string; status: string;
  from: string; to: string | null; contractAddress: string | null;
  gasUsed: string; effectiveGasPrice: string; logs: { topics: string[] }[];
};
export type Broadcast = {
  chain: number;
  transactions: { hash: string | null; transactionType: string; contractAddress: string; transaction: Transaction }[];
  receipts: Receipt[];
};
export type Manifest = {
  chainId: number; controller: string; simulationBlock?: number; deployBlock?: number;
  dependencies: { contracts: Record<string, { address: string }>; tokens: Record<string, { address: string }> };
  [key: string]: unknown;
};
type Check = { name: string; ok: boolean; actual: unknown; expected: unknown };
type Report = {
  scope: "initial-deployment"; chainId: number; block: number | null; simulationBlock?: number;
  observedAt: string; planned: number; checks: Check[];
  receipts: { index: number; hash: string; block: number; gasUsed: string; feeWei: string }[];
  incomplete: { index: number; reason: string }[];
  minedRange: { first: number; last: number } | null;
  initialStateChecked: boolean; complete: boolean;
};

const json = (value: unknown) => JSON.stringify(value, (_, item) => typeof item === "bigint" ? item.toString() : item);
const equal = (a: unknown, b: unknown) => json(a).toLowerCase() === json(b).toLowerCase();
function check(report: Report, name: string, actual: unknown, expected: unknown) {
  report.checks.push({ name, ok: equal(actual, expected), actual, expected });
}
export const verificationExitCode = (report: { complete: boolean }) => report.complete ? 0 : 1;

/** Compare canonical receipts and transaction input with the saved broadcast, without recompiling sources. */
export async function verifyReceipts(rpc: Rpc, broadcast: Broadcast, manifest: Pick<Manifest, "chainId" | "controller">): Promise<Report> {
  const chainId = Number(BigInt(await rpc("eth_chainId", []) as string));
  if (chainId !== 11155111 || manifest.chainId !== chainId || broadcast.chain !== chainId) {
    throw new Error("Expected Sepolia chain 11155111 in RPC, manifest and broadcast");
  }
  const report: Report = {
    scope: "initial-deployment", chainId, block: null, observedAt: new Date().toISOString(),
    planned: broadcast.transactions.length, checks: [], receipts: [], incomplete: [],
    minedRange: null, initialStateChecked: false, complete: false,
  };
  check(report, "transactionsPresent", report.planned > 0, true);
  const baseline = broadcast.transactions[0] ? BigInt(broadcast.transactions[0].transaction.nonce) : 0n;
  for (const [index, tx] of broadcast.transactions.entries()) {
    check(report, `tx${index}.plannedNonce`, BigInt(tx.transaction.nonce), baseline + BigInt(index));
    if (!tx.hash) {
      report.incomplete.push({ index, reason: "not yet broadcast" });
      continue;
    }
    const receipt = await rpc("eth_getTransactionReceipt", [tx.hash]) as Receipt | null;
    const transaction = await rpc("eth_getTransactionByHash", [tx.hash]) as Transaction | null;
    if (!receipt || !transaction) {
      report.incomplete.push({ index, reason: "receipt or transaction not available" });
      continue;
    }
    check(report, `tx${index}.receiptHash`, receipt.transactionHash, tx.hash);
    check(report, `tx${index}.success`, receipt.status, "0x1");
    check(report, `tx${index}.from`, receipt.from, manifest.controller);
    check(report, `tx${index}.transactionFrom`, transaction.from, manifest.controller);
    check(report, `tx${index}.nonce`, BigInt(transaction.nonce), baseline + BigInt(index));
    check(report, `tx${index}.chain`, Number(BigInt(transaction.chainId)), chainId);
    check(report, `tx${index}.to`, transaction.to, tx.transaction.to);
    check(report, `tx${index}.value`, BigInt(transaction.value), BigInt(tx.transaction.value));
    check(report, `tx${index}.inputHash`, keccak256(transaction.input), keccak256(tx.transaction.input));
    if (tx.transactionType === "CREATE") check(report, `tx${index}.createdAddress`, receipt.contractAddress, tx.contractAddress);
    const local = broadcast.receipts.find((item) => equal(item.transactionHash, tx.hash));
    if (local) check(report, `tx${index}.canonicalBlockHash`, receipt.blockHash, local.blockHash);
    const failures = receipt.logs.filter((log) => log.topics[0] === id("ExecutionFailure(bytes32,uint256)"));
    check(report, `tx${index}.safeFailures`, failures.length, 0);
    report.receipts.push({
      index, hash: tx.hash, block: Number(BigInt(receipt.blockNumber)), gasUsed: BigInt(receipt.gasUsed).toString(),
      feeWei: (BigInt(receipt.gasUsed) * BigInt(receipt.effectiveGasPrice)).toString(),
    });
  }
  if (report.receipts.length) {
    const blocks = report.receipts.map((receipt) => receipt.block);
    report.minedRange = { first: Math.min(...blocks), last: Math.max(...blocks) };
    report.block = report.minedRange.last;
  }
  report.complete = report.incomplete.length === 0 && report.checks.every((item) => item.ok);
  return report;
}

const ABI = new Interface([
  "function getOwners() view returns(address[])", "function getThreshold() view returns(uint256)",
  "function VERSION() view returns(string)", "function getModulesPaginated(address,uint256) view returns(address[],address)",
  "function owner() view returns(address)", "function avatar() view returns(address)", "function target() view returns(address)",
  "function domainSeparator() view returns(bytes32)", "function domainVerifiers(address,bytes32) view returns(address)",
  "function allowance(address,address) view returns(uint256)", "function balanceOf(address) view returns(uint256)",
  "function controller() view returns(address)", "function queue() view returns(address)", "function share() view returns(address)",
  "function asset() view returns(address)", "function voting() view returns(address)", "function agent() view returns(address)",
  "function easyTrack() view returns(address)", "function evmScriptExecutor() view returns(address)",
  "function ldoToken() view returns(address)", "function motionDuration() view returns(uint256)",
  "function objectionThreshold() view returns(uint256)", "function evmScriptFactories(address) view returns(bool)",
  "function trustedCaller() view returns(address)", "function modifier_() view returns(address)",
  "function usdShare() view returns(address)", "function ethShare() view returns(address)", "function motionsCount() view returns(uint256)",
]);
const ZERO = "0x0000000000000000000000000000000000000000";
const SENTINEL = "0x0000000000000000000000000000000000000001";
const FALLBACK_SLOT = "0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5";
const GUARD_SLOT = "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8";
const MODULE_GUARD_SLOT = "0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947";

/** Read initial values at the last deployment block, even after later policy or funding transactions. */
export async function verifyDeployment(rpc: Rpc, manifest: Manifest, broadcast: Broadcast): Promise<Report> {
  const report = await verifyReceipts(rpc, broadcast, manifest);
  report.simulationBlock = manifest.simulationBlock ?? manifest.deployBlock;
  if (!report.complete || report.block === null) return report;
  const block = toQuantity(report.block);
  const header = await rpc("eth_getBlockByNumber", [block, false]) as { hash: string };
  const address = (name: string) => {
    if (typeof manifest[name] !== "string") throw new Error(`Missing manifest address: ${name}`);
    return getAddress(manifest[name] as string);
  };
  const dep = (name: string) => manifest.dependencies.contracts[name].address;
  const slotAddress = (value: string) => getAddress("0x" + value.slice(-40));
  async function call<T = unknown>(to: string, name: string, args: unknown[] = []): Promise<T> {
    try {
      const result = await rpc("eth_call", [{ to, data: ABI.encodeFunctionData(name, args) }, block]) as string;
      const decoded = ABI.decodeFunctionResult(name, result);
      return (decoded.length === 1 ? decoded[0] : decoded) as T;
    } catch {
      throw new Error(`Read failed: ${name} at ${to}`);
    }
  }
  const storage = async (to: string, slot: string) => await rpc("eth_getStorageAt", [to, slot, block]) as string;
  const record = (name: string, actual: unknown, expected: unknown) => check(report, name, actual, expected);
  const codes = new Map<string, string>();
  for (const [name, value] of Object.entries(manifest)) {
    if (name === "controller" || typeof value !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(value)) continue;
    const code = await rpc("eth_getCode", [value, block]) as string;
    codes.set(name, code);
    record(`${name}.codePresent`, /^0x(?:[0-9a-fA-F]{2})+$/.test(code), true);
  }
  const safes: [string, string, string, string[]][] = [
    ["operatorSafe", manifest.controller, "1.3.0", []], ["emergencySafe", manifest.controller, "1.5.0", []],
    ["assetSafe", address("voting"), "1.5.0", [address("operatorModifier"), address("safetyModifier")]],
    ["ordersSafe", address("voting"), "1.5.0", [address("ordersModifier")]],
    ["firstLossSafe", address("voting"), "1.5.0", [address("firstLossModifier")]],
  ];
  for (const [name, owner, version, modules] of safes) {
    if (codes.get(name) === "0x") continue;
    const safe = address(name);
    record(`${name}.owners`, Array.from(await call<string[]>(safe, "getOwners")), [owner]);
    record(`${name}.threshold`, await call(safe, "getThreshold"), 1n);
    record(`${name}.version`, await call(safe, "VERSION"), version);
    record(`${name}.singleton`, slotAddress(await storage(safe, "0x0")), dep(version === "1.3.0" ? "safe13" : "safe15"));
    const [members, next] = await call<[string[], string]>(safe, "getModulesPaginated", [SENTINEL, 10]);
    record(`${name}.modules`, Array.from(members).map((item) => item.toLowerCase()).sort(), modules.map((item) => item.toLowerCase()).sort());
    record(`${name}.moduleListEnd`, next, SENTINEL);
    record(`${name}.fallback`, slotAddress(await storage(safe, FALLBACK_SLOT)), name === "ordersSafe" ? dep("fallbackHandler") : ZERO);
    record(`${name}.guard`, slotAddress(await storage(safe, GUARD_SLOT)), ZERO);
    record(`${name}.moduleGuard`, slotAddress(await storage(safe, MODULE_GUARD_SLOT)), ZERO);
  }
  for (const [name, safe] of [["operatorModifier", "assetSafe"], ["safetyModifier", "assetSafe"], ["ordersModifier", "ordersSafe"], ["firstLossModifier", "firstLossSafe"]]) {
    if (codes.get(name) === "0x") continue;
    for (const field of ["owner", "avatar", "target"]) record(`${name}.${field}`, await call(address(name), field), address(safe));
    const [members, next] = await call<[string[], string]>(address(name), "getModulesPaginated", [SENTINEL, 10]);
    record(`${name}.initialMembers`, Array.from(members), []);
    record(`${name}.memberListEnd`, next, SENTINEL);
    const proxy = `0x363d3d373d3d3d363d73${dep("roles").slice(2)}5af43d82803e903d91602b57fd5bf3`;
    record(`${name}.proxyRuntime`, codes.get(name), proxy);
  }
  for (const name of ["voting", "agent"]) if (codes.get(name) !== "0x") record(`${name}.owner`, await call(address(name), "owner"), manifest.controller);
  if (codes.get("ordersSafe") !== "0x") {
    const domain = await call<string>(dep("settlement"), "domainSeparator");
    record("ordersSafe.domainVerifier", await call(dep("fallbackHandler"), "domainVerifiers", [address("ordersSafe"), domain]), dep("composableCow"));
    for (const [name, token] of Object.entries(manifest.dependencies.tokens)) record(`ordersSafe.${name}.relayerAllowance`, await call(token.address, "allowance", [address("ordersSafe"), dep("vaultRelayer")]), 2n ** 256n - 1n);
  }
  if (codes.get("easyTrack") !== "0x") {
    const values: [string, unknown][] = [["owner", manifest.controller], ["voting", address("voting")], ["evmScriptExecutor", address("easyTrackExecutor")], ["ldoToken", address("objectionToken")], ["motionDuration", 60n], ["objectionThreshold", 10n ** 18n], ["motionsCount", 0n]];
    for (const [getter, value] of values) record(`easyTrack.${getter}`, await call(address("easyTrack"), getter), value);
    record("easyTrack.burnFactoryRegistered", await call(address("easyTrack"), "evmScriptFactories", [address("burnFactory")]), true);
    record("executor.easyTrack", await call(address("easyTrackExecutor"), "easyTrack"), address("easyTrack"));
    record("executor.agent", await call(address("easyTrackExecutor"), "agent"), address("agent"));
  }
  for (const prefix of ["usd", "eth"]) {
    if (codes.get(prefix + "Share") === "0x" || codes.get(prefix + "Queue") === "0x") continue;
    record(`${prefix}.queue`, await call(address(prefix + "Share"), "queue"), address(prefix + "Queue"));
    record(`${prefix}.queueShare`, await call(address(prefix + "Queue"), "share"), address(prefix + "Share"));
    record(`${prefix}.claimAsset`, await call(address(prefix + "Queue"), "asset"), address(prefix + "ClaimAsset"));
    for (const suffix of ["Share", "Queue"]) record(`${prefix}${suffix}.controller`, await call(address(prefix + suffix), "controller"), manifest.controller);
    record(`${prefix}.controllerShares`, await call(address(prefix + "Share"), "balanceOf", [manifest.controller]), 100n * 10n ** 18n);
    record(`${prefix}.firstLossUnfunded`, await call(address(prefix + "Share"), "balanceOf", [address("firstLossSafe")]), 0n);
    record(`${prefix}.claimAssetController`, await call(address(prefix + "ClaimAsset"), "controller"), address(prefix + "Queue"));
  }
  if (codes.get("objectionToken") !== "0x") record("objectionToken.controllerBalance", await call(address("objectionToken"), "balanceOf", [manifest.controller]), 1000n * 10n ** 18n);
  if (codes.get("burnFactory") !== "0x") {
    for (const [getter, name] of [["trustedCaller", "operatorSafe"], ["modifier_", "firstLossModifier"], ["usdShare", "usdShare"], ["ethShare", "ethShare"]]) record(`burnFactory.${getter}`, await call(address("burnFactory"), getter), address(name));
  }
  const finalHeader = await rpc("eth_getBlockByNumber", [block, false]) as { hash: string };
  const lastReceipt = broadcast.receipts.find((receipt) => Number(BigInt(receipt.blockNumber)) === report.block);
  record("snapshot.canonicalHash", finalHeader.hash, header.hash);
  if (lastReceipt) record("snapshot.broadcastHash", finalHeader.hash, lastReceipt.blockHash);
  report.initialStateChecked = true;
  report.complete = report.checks.every((item) => item.ok);
  return report;
}

if (import.meta.main) {
  try {
    const root = path.resolve(import.meta.dir, "../../..");
    const output = path.join(root, "cache/sepolia/deployment-verification.json");
    rmSync(output, { force: true });
    const endpoint = process.env.SEPOLIA_RPC;
    if (!endpoint) throw new Error("Set SEPOLIA_RPC in the local environment");
    const manifest = JSON.parse(readFileSync(process.env.SEPOLIA_MANIFEST ?? path.join(root, "cache/sepolia/manifest.json"), "utf8")) as Manifest;
    const broadcast = JSON.parse(readFileSync(process.env.SEPOLIA_BROADCAST ?? path.join(root, "broadcast/DeploySepolia.s.sol/11155111/run-latest.json"), "utf8")) as Broadcast;
    if (process.env.SEPOLIA_SENDER && !equal(process.env.SEPOLIA_SENDER, manifest.controller)) throw new Error("Sender differs from manifest controller");
    let sequence = 0;
    const rpc: Rpc = async (method, params) => {
      const callId = ++sequence;
      try {
        const response = await fetch(endpoint, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: callId, method, params }), signal: AbortSignal.timeout(20_000) });
        const body = await response.json() as { id: number; error?: unknown; result?: unknown };
        if (!response.ok || body.error || body.id !== callId || body.result === undefined) throw new Error();
        return body.result;
      } catch {
        throw new Error(`${method}: RPC failed; endpoint and raw response suppressed`);
      }
    };
    const report = await verifyDeployment(rpc, manifest, broadcast);
    mkdirSync(path.dirname(output), { recursive: true });
    writeFileSync(output, JSON.stringify(report, (_, value) => typeof value === "bigint" ? value.toString() : value, 2) + "\n");
    console.log(JSON.stringify({ scope: report.scope, block: report.block, minedRange: report.minedRange, confirmed: report.receipts.length, planned: report.planned, failures: report.checks.filter((item) => !item.ok), incomplete: report.incomplete, initialStateChecked: report.initialStateChecked, complete: report.complete }, null, 2));
    process.exitCode = verificationExitCode(report);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Deployment verification failed");
    process.exitCode = 1;
  }
}
