// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Computes each Safe batch's hash again, and checks what each batch does (enabling-vote spec; OD-92).
 *
 * The enabling vote approves the hash of each Safe batch, and anyone sends the batches after the vote. A hash
 * says nothing by itself, so a reviewer needs two answers before the vote: is this the hash of these calls, and
 * are these calls the compiled policy and the vault's setup, and nothing else?
 *
 *   bun compiler/batches.ts check --batches <file> [--artifact <ref>] [--rpc [URL]] [--json]
 *
 * The command takes the published batches: for each one its Safe, its nonce and its MultiSend data. It works
 * offline. It decodes the calls from the data, computes the Safe transaction hash as Safe v1.5.0 does, and fails
 * unless:
 *
 * - each batch is a delegatecall of Safe's MultiSendCallOnly from one of the vault's three Safes;
 * - the calls on a Safe's modifiers are the artifact's calls for those modifiers, all of them, in the artifact's
 *   order;
 * - every other call is a known setup call: a Safe enables its own modifier, and the orders account sets CoW's
 *   fallback handler, sets ComposableCoW as the verifier of CoW's settlement domain, and approves CoW's vault
 *   relayer for each token of the approvals role;
 * - the nonces of a Safe's batches follow each other, and each batch fits the transaction pool's size limit;
 * - a hash that the file states is the hash that the command computes.
 *
 * With `--rpc`, it also reads each Safe's nonce and fails if the first batch does not name it.
 *
 * The command does not say how much gas a batch needs: the fork rehearsal runs each batch under EIP-7825's cap
 * (test/EnablingVoteRehearsal.t.sol). It does not read the vote's script: compare each `approveHash` item of the
 * vote with the hashes that the command prints.
 */
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { AbiCoder, getAddress, Interface, JsonRpcProvider, keccak256, toUtf8Bytes } from "ethers";
import type { Artifact } from "./compile";
import { load } from "./motion";

export const BATCHES_FORMAT = "clutch.safe-batches/1";
const CODER = AbiCoder.defaultAbiCoder();
const lower = (value: string) => value.toLowerCase();
const same = (x: string, y: string) => lower(x) === lower(y);

/** Safe v1.5.0's MultiSendCallOnly. A batch is a delegatecall, so it may run no other code. */
export const MULTISEND_CALL_ONLY = "0xA83c336B20401Af773B6219BA5027174338D1836";
/** CoW Protocol's contracts that the orders account's setup names (ADR 007). */
export const COW_SETTLEMENT = "0x9008D19f58AAbD9eD0D60971565AA8510560ab41";
export const COW_VAULT_RELAYER = "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110";
export const COW_FALLBACK_HANDLER = "0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5";
export const COMPOSABLE_COW = "0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74";
/** The transaction pool refuses a transaction above 128 KiB. */
export const TX_SIZE_LIMIT = 128 * 1024;
const MAX_UINT256 = (1n << 256n) - 1n;

const SAFE = new Interface([
  "function multiSend(bytes transactions)",
  "function enableModule(address module)",
  "function setFallbackHandler(address handler)",
  "function setDomainVerifier(bytes32 domainSeparator, address newVerifier)",
  "function approve(address spender, uint256 amount)",
  "function approveHash(bytes32 hashToApprove)",
  "function nonce() view returns (uint256)",
  "function execTransaction(address to, uint256 value, bytes data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signatures)",
]);

// ---------------------------------------------------------------------------------------------------------------
// The hash of a Safe transaction, and the calls of a MultiSend
// ---------------------------------------------------------------------------------------------------------------

const DOMAIN_TYPEHASH = keccak256(toUtf8Bytes("EIP712Domain(uint256 chainId,address verifyingContract)"));
const SAFE_TX_TYPEHASH = keccak256(
  toUtf8Bytes("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"),
);
const ZERO = "0x0000000000000000000000000000000000000000";

/**
 * The hash that a Safe's owners approve for a batch: the EIP-712 hash of a delegatecall of `multiSend` with
 * `data`, with no value, no refund and the given nonce, in the Safe's own domain. It is what the Safe's
 * `getTransactionHash` returns; the fork suite compares the two for every batch of the rehearsal.
 */
export function safeTxHash(chainId: number | bigint, safe: string, multiSend: string, data: string, nonce: number | bigint): string {
  const domain = keccak256(CODER.encode(["bytes32", "uint256", "address"], [DOMAIN_TYPEHASH, chainId, safe]));
  const struct = keccak256(
    CODER.encode(
      ["bytes32", "address", "uint256", "bytes32", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"],
      [SAFE_TX_TYPEHASH, multiSend, 0, keccak256(data), 1, 0, 0, 0, ZERO, ZERO, nonce],
    ),
  );
  return keccak256("0x1901" + domain.slice(2) + struct.slice(2));
}

export type Call = { to: string; data: string };

/**
 * The calls of a `multiSend(bytes)` calldata. Each packed item is an operation of one byte, a target of 20, a
 * value of 32, a length of 32 and the call's data. Every item must be a plain call without value, and the items
 * must fill the bytes exactly.
 */
export function decodeMultiSend(data: string): Call[] {
  let packed: string;
  try {
    packed = (SAFE.decodeFunctionData("multiSend", data)[0] as string).slice(2);
  } catch {
    throw new Error("the data is no call of multiSend(bytes)");
  }
  // the encoding must be the canonical one, so that the hash covers nothing that this does not read
  if (lower(SAFE.encodeFunctionData("multiSend", ["0x" + packed])) !== lower(data)) throw new Error("the multiSend data is not in the canonical encoding");
  const calls: Call[] = [];
  let at = 0;
  while (at < packed.length) {
    if (packed.length - at < 170) throw new Error("the multiSend data ends inside an item");
    const operation = parseInt(packed.slice(at, at + 2), 16);
    const to = getAddress("0x" + packed.slice(at + 2, at + 42));
    const value = BigInt("0x" + packed.slice(at + 42, at + 106));
    const length = Number(BigInt("0x" + packed.slice(at + 106, at + 170)));
    if (operation !== 0) throw new Error(`call ${calls.length + 1} is no plain call: operation ${operation}`);
    if (value !== 0n) throw new Error(`call ${calls.length + 1} sends ETH`);
    if (packed.length - at - 170 < 2 * length) throw new Error("the multiSend data ends inside an item");
    calls.push({ to, data: "0x" + packed.slice(at + 170, at + 170 + 2 * length) });
    at += 170 + 2 * length;
  }
  if (calls.length === 0) throw new Error("the batch has no call");
  return calls;
}

/** The `multiSend(bytes)` calldata of a list of plain calls. */
export function encodeMultiSend(calls: Call[]): string {
  const packed = calls.map(({ to, data }) => "00" + lower(to).slice(2) + "0".repeat(64) + (data.length / 2 - 1).toString(16).padStart(64, "0") + data.slice(2)).join("");
  return SAFE.encodeFunctionData("multiSend", ["0x" + packed]);
}

/** The domain separator of CoW's settlement contract: its EIP-712 domain, "Gnosis Protocol" version "v2". */
export function cowDomain(chainId: number | bigint): string {
  const typehash = keccak256(toUtf8Bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
  return keccak256(
    CODER.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [typehash, keccak256(toUtf8Bytes("Gnosis Protocol")), keccak256(toUtf8Bytes("v2")), chainId, COW_SETTLEMENT]),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// The check
// ---------------------------------------------------------------------------------------------------------------

export type Batch = { safe: string; nonce: number; data: string; hash?: string; label?: string };
export type BatchFile = { format: string; network: string; chainId: number; multiSend: string; batches: Batch[] };

export type BatchReport = {
  safe: string;
  name: string;
  nonce: number;
  calls: number;
  /** The calls on the Safe's modifiers, which are the policy, and the others, which are the setup. */
  policyCalls: number;
  setup: string[];
  /** The size of the transaction that sends the batch with Aragon Voting's approval as its signature. */
  bytes: number;
  hash: string;
  /** The vote's item for this batch: the Safe's `approveHash` with the hash. */
  approveHash: string;
};

export type Report = { ok: boolean; problems: string[]; batches: BatchReport[] };

/** The vault's Safes that the enabling vote sets up, each with its modifiers. */
function safesOf(policy: Artifact): { address: string; name: string; modifiers: string[] }[] {
  const manifest = policy.manifest as Record<string, string | undefined>;
  const list = (name: string, address: string | undefined, modifiers: (string | undefined)[]) =>
    address ? [{ address, name, modifiers: modifiers.filter((m): m is string => m !== undefined) }] : [];
  return [
    ...list("Asset Safe", manifest.assetSafe, [manifest.operatorModifier, manifest.safetyModifier]),
    ...list("orders account", manifest.ordersAccount, [manifest.ordersModifier]),
    ...list("first-loss Safe", manifest.firstLossSafe, [manifest.firstLossModifier]),
  ].filter((safe) => safe.modifiers.length > 0);
}

/** The transaction that sends a batch: the Safe's `execTransaction` with Aragon Voting's approved hash as the signature. */
function sendSize(multiSend: string, data: string): number {
  const signature = "0x" + "00".repeat(64) + "01";
  return SAFE.encodeFunctionData("execTransaction", [multiSend, 0, data, 1, 0, 0, 0, ZERO, ZERO, signature]).length / 2 - 1;
}

/**
 * Checks the published batches against the policy. `nonces` holds each Safe's nonce on chain, if the caller read
 * it.
 */
export function checkBatches(file: BatchFile, policy: Artifact, nonces: Map<string, bigint> = new Map()): Report {
  const problems: string[] = [];
  const out: BatchReport[] = [];
  const manifest = policy.manifest as Record<string, unknown>;
  if (file.format !== BATCHES_FORMAT) problems.push(`the file's format is ${file.format}, not ${BATCHES_FORMAT}`);
  if (file.network !== manifest.network) problems.push(`the batches are of ${file.network}, and the policy is of ${manifest.network}`);
  if (Number(file.chainId) !== Number(manifest.chainId)) problems.push(`the batches name chain ${file.chainId}, and the policy chain ${manifest.chainId}`);
  if (!same(file.multiSend, MULTISEND_CALL_ONLY)) problems.push(`the batches delegatecall ${file.multiSend}, which is not Safe's MultiSendCallOnly ${MULTISEND_CALL_ONLY}`);
  if (!Array.isArray(file.batches) || file.batches.length === 0) return { ok: false, problems: [...problems, "the file holds no batch"], batches: out };

  const safes = safesOf(policy);
  const relayerTokens = (policy.modifiers.find((m) => same(m.address, String(manifest.ordersModifier ?? "")))?.roles.find((r) => r.name === "approvals")?.targets ?? []).map((t) => t.address);
  const domain = cowDomain(Number(manifest.chainId));
  // what each Safe still owes: the artifact's calls on its modifiers, in order, and its setup calls
  type Owed = { safe: (typeof safes)[number]; policyCalls: Call[]; next: number; setup: Map<string, string>; lastNonce: number | null };
  const state = new Map<string, Owed>(
    safes.map((safe): [string, Owed] => {
      const policyCalls = policy.calls.to.flatMap((to, i) => (safe.modifiers.some((m) => same(m, to)) ? [{ to, data: policy.calls.data[i] }] : []));
      const setup = new Map<string, string>(safe.modifiers.map((m) => [lower(`${safe.address}|${SAFE.encodeFunctionData("enableModule", [m])}`), `enable the module ${m}`]));
      if (safe.name === "orders account") {
        setup.set(lower(`${safe.address}|${SAFE.encodeFunctionData("setFallbackHandler", [COW_FALLBACK_HANDLER])}`), "set CoW's fallback handler");
        setup.set(lower(`${safe.address}|${SAFE.encodeFunctionData("setDomainVerifier", [domain, COMPOSABLE_COW])}`), "set ComposableCoW as the verifier of CoW's settlement domain");
        for (const token of relayerTokens) setup.set(lower(`${token}|${SAFE.encodeFunctionData("approve", [COW_VAULT_RELAYER, MAX_UINT256])}`), `approve CoW's vault relayer for ${token}`);
      }
      return [lower(safe.address), { safe, policyCalls, next: 0, setup, lastNonce: null }];
    }),
  );

  file.batches.forEach((batch, index) => {
    const where = `batch ${index + 1}`;
    const entry = state.get(lower(batch.safe ?? ""));
    if (!entry) {
      problems.push(`${where}: ${batch.safe} is none of the vault's Safes`);
      return;
    }
    const { safe } = entry;
    if (!Number.isInteger(batch.nonce) || batch.nonce < 0) {
      problems.push(`${where}: the nonce ${batch.nonce} is no whole number`);
      return;
    }
    if (entry.lastNonce === null) {
      const onChain = nonces.get(lower(safe.address));
      if (onChain !== undefined && onChain !== BigInt(batch.nonce)) problems.push(`${where}: the ${safe.name}'s nonce on chain is ${onChain}, and its first batch names ${batch.nonce}`);
    } else if (batch.nonce !== entry.lastNonce + 1) {
      problems.push(`${where}: the ${safe.name}'s batches must follow each other, and nonce ${batch.nonce} comes after ${entry.lastNonce}`);
    }
    entry.lastNonce = batch.nonce;

    let calls: Call[];
    try {
      calls = decodeMultiSend(batch.data);
    } catch (error) {
      problems.push(`${where}: ${error instanceof Error ? error.message : String(error)}`);
      return;
    }
    let policyCalls = 0;
    const setup: string[] = [];
    calls.forEach((call, i) => {
      const at = `${where}, call ${i + 1}`;
      if (safe.modifiers.some((m) => same(m, call.to))) {
        const expected = entry.policyCalls[entry.next];
        if (!expected) problems.push(`${at}: a call on a modifier after the policy's last call`);
        else if (!same(expected.to, call.to) || lower(expected.data) !== lower(call.data)) problems.push(`${at}: it is not call ${entry.next + 1} of the policy's calls for the ${safe.name}`);
        entry.next++;
        policyCalls++;
        return;
      }
      const key = lower(`${call.to}|${call.data}`);
      const known = entry.setup.get(key);
      if (known === undefined) {
        problems.push(`${at}: a call of ${call.to} with data ${call.data.slice(0, 74)}${call.data.length > 74 ? "…" : ""} is neither the policy nor a known setup call of the ${safe.name}`);
        return;
      }
      entry.setup.delete(key);
      setup.push(known);
    });

    const hash = safeTxHash(file.chainId, safe.address, file.multiSend, batch.data, batch.nonce);
    if (batch.hash !== undefined && lower(batch.hash) !== hash) problems.push(`${where}: the file states the hash ${batch.hash}, and the hash of this batch is ${hash}`);
    const bytes = sendSize(file.multiSend, batch.data);
    if (bytes > TX_SIZE_LIMIT) problems.push(`${where}: its transaction has ${bytes} bytes, above the transaction pool's limit of ${TX_SIZE_LIMIT}`);
    out.push({ safe: safe.address, name: safe.name, nonce: batch.nonce, calls: calls.length, policyCalls, setup, bytes, hash, approveHash: SAFE.encodeFunctionData("approveHash", [hash]) });
  });

  for (const { safe, policyCalls, next, setup, lastNonce } of state.values()) {
    if (lastNonce === null) problems.push(`no batch is for the ${safe.name}`);
    if (next < policyCalls.length) problems.push(`the ${safe.name}'s batches hold ${next} of the policy's ${policyCalls.length} calls for it`);
    for (const missing of setup.values()) problems.push(`the ${safe.name}'s batches do not ${missing}`);
  }
  return { ok: problems.length === 0, problems, batches: out };
}

// ---------------------------------------------------------------------------------------------------------------
// The command line
// ---------------------------------------------------------------------------------------------------------------

function options(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (!flag.startsWith("--")) throw new Error(`unexpected argument ${flag}`);
    const next = argv[i + 1];
    if (next !== undefined && !next.startsWith("--")) {
      out[flag.slice(2)] = next;
      i++;
    } else {
      out[flag.slice(2)] = "true";
    }
  }
  return out;
}

export function readBatches(file: string): BatchFile {
  if (!existsSync(file)) throw new Error(`${file} is missing`);
  const parsed = JSON.parse(readFileSync(file, "utf8")) as BatchFile;
  return { ...parsed, chainId: Number(parsed.chainId), batches: (parsed.batches ?? []).map((b) => ({ ...b, nonce: Number(b.nonce) })) };
}

/** Each Safe's nonce on chain. The RPC URL is never printed. */
async function readNonces(url: string, safes: string[]): Promise<Map<string, bigint>> {
  const provider = new JsonRpcProvider(url);
  try {
    const out = new Map<string, bigint>();
    for (const safe of safes) {
      if ((await provider.getCode(safe)) === "0x") throw new Error(`no contract at the Safe's address ${safe} on this chain`);
      out.set(lower(safe), BigInt(SAFE.decodeFunctionResult("nonce", await provider.call({ to: safe, data: SAFE.encodeFunctionData("nonce") }))[0]));
    }
    return out;
  } finally {
    provider.destroy();
  }
}

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  const opts = options(rest);
  if (command !== "check" || !opts.batches) {
    console.error("usage: batches.ts check --batches <file> [--artifact <ref>] [--network <name>] [--rpc [URL]] [--json]");
    return 2;
  }
  const network = opts.network ?? "rehearsal-26249900";
  const source = load(opts.artifact ?? path.relative(process.cwd(), path.resolve(import.meta.dir, "..", "artifacts", `${network}.json`)), network);
  const file = readBatches(opts.batches);
  let nonces = new Map<string, bigint>();
  if (opts.rpc !== undefined) {
    const url = opts.rpc === "true" || opts.rpc === "env" ? process.env.RPC : opts.rpc;
    if (!url) throw new Error("--rpc needs a URL, or RPC in the environment");
    nonces = await readNonces(url, safesOf(source.policy).map((safe) => safe.address));
  }
  const report = checkBatches(file, source.policy, nonces);
  if (opts.json !== undefined) {
    console.log(JSON.stringify({ policy: { ref: source.ref, commit: source.commit, sha256: source.sha256 }, ...report }, null, 2));
    return report.ok ? 0 : 1;
  }
  for (const batch of report.batches) {
    console.log(`${batch.name}, nonce ${batch.nonce}: ${batch.calls} calls, ${batch.policyCalls} of the policy and ${batch.setup.length} of the setup; ${batch.bytes} bytes`);
    for (const line of batch.setup) console.log(`  setup: ${line}`);
    console.log(`  hash: ${batch.hash}`);
    console.log(`  the vote's item: ${batch.safe} ${batch.approveHash}`);
  }
  console.log(
    report.ok
      ? `PASS: the ${report.batches.length} batches carry the policy of ${source.ref} (sha256 ${source.sha256}) and the vault's setup, and nothing else${opts.rpc === undefined ? "; the Safes' nonces on chain were not read" : ""}`
      : "FAIL",
  );
  for (const line of report.problems) console.log(`  problem: ${line}`);
  return report.ok ? 0 : 1;
}

if (import.meta.main) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (error) => {
      console.error(error instanceof Error ? error.message : String(error));
      process.exit(2);
    },
  );
}
