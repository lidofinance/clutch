// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { Interface, TypedDataEncoder } from "ethers";
import type { Artifact } from "./compile";
import {
  BATCHES_FORMAT,
  checkBatches,
  COMPOSABLE_COW,
  COW_FALLBACK_HANDLER,
  COW_SETTLEMENT,
  COW_VAULT_RELAYER,
  cowDomain,
  decodeMultiSend,
  encodeMultiSend,
  MULTISEND_CALL_ONLY,
  safeTxHash,
  TX_SIZE_LIMIT,
} from "./batches";
import type { BatchFile, Call } from "./batches";

const ROOT = path.resolve(import.meta.dir, "..");
const REPO = path.resolve(ROOT, "../..");
const policy = JSON.parse(readFileSync(path.join(ROOT, "artifacts/rehearsal-26249900.json"), "utf8")) as Artifact;
const fixture = JSON.parse(readFileSync(path.join(import.meta.dir, "batches.fixture.json"), "utf8"));
const manifest = policy.manifest as Record<string, any>;
const clone = <T>(value: T) => JSON.parse(JSON.stringify(value)) as T;
const lower = (value: string) => value.toLowerCase();
const STRANGER = "0x000000000000000000000000000000000000dEaD";
const MAX = (1n << 256n) - 1n;
const ABI = new Interface([
  "function enableModule(address module)",
  "function setFallbackHandler(address handler)",
  "function setDomainVerifier(bytes32 domainSeparator, address newVerifier)",
  "function approve(address spender, uint256 amount)",
  "function transfer(address to, uint256 amount)",
  "function multiSend(bytes transactions)",
]);

/** The calls of each Safe's batches, as the enabling vote's fixture builds them: the setup, then the policy. */
function callsOf(p: Artifact): Record<"asset" | "orders" | "firstLoss", Call[]> {
  const on = (...modifiers: string[]) => p.calls.to.flatMap((to, i) => (modifiers.some((m) => lower(m) === lower(to)) ? [{ to, data: p.calls.data[i] }] : []));
  const enable = (safe: string, modifier: string) => ({ to: safe, data: ABI.encodeFunctionData("enableModule", [modifier]) });
  const tokens = p.modifiers.find((m) => m.ref === "orders_modifier")!.roles.find((r) => r.name === "approvals")!.targets.map((t) => t.address);
  return {
    asset: [enable(manifest.assetSafe, manifest.operatorModifier), enable(manifest.assetSafe, manifest.safetyModifier), ...on(manifest.operatorModifier, manifest.safetyModifier)],
    orders: [
      { to: manifest.ordersAccount, data: ABI.encodeFunctionData("setFallbackHandler", [COW_FALLBACK_HANDLER]) },
      { to: manifest.ordersAccount, data: ABI.encodeFunctionData("setDomainVerifier", [cowDomain(1), COMPOSABLE_COW]) },
      enable(manifest.ordersAccount, manifest.ordersModifier),
      ...on(manifest.ordersModifier),
      ...tokens.map((token) => ({ to: token, data: ABI.encodeFunctionData("approve", [COW_VAULT_RELAYER, MAX]) })),
    ],
    firstLoss: [enable(manifest.firstLossSafe, manifest.firstLossModifier), ...on(manifest.firstLossModifier)],
  };
}

const SAFES = { asset: manifest.assetSafe, orders: manifest.ordersAccount, firstLoss: manifest.firstLossSafe } as const;

/** A batch file from lists of calls: each list is one batch of its Safe, and a Safe's nonces start at `first`. */
function fileOf(parts: [keyof typeof SAFES, Call[]][], first = 0): BatchFile {
  const next: Record<string, number> = {};
  return {
    format: BATCHES_FORMAT,
    network: manifest.network,
    chainId: 1,
    multiSend: MULTISEND_CALL_ONLY,
    batches: parts.map(([safe, calls]) => {
      const nonce = next[safe] ?? first;
      next[safe] = nonce + 1;
      return { safe: SAFES[safe], nonce, data: encodeMultiSend(calls) };
    }),
  };
}
const all = callsOf(policy);
const whole = (): [keyof typeof SAFES, Call[]][] => [["asset", all.asset], ["orders", all.orders], ["firstLoss", all.firstLoss]];
const problems = (file: BatchFile, p = policy, nonces = new Map<string, bigint>()) => checkBatches(file, p, nonces).problems;

// ---------------------------------------------------------------------------------------------------------------
// The hash and the MultiSend encoding
// ---------------------------------------------------------------------------------------------------------------

// OD-92: the vote approves a hash, so the command's hash must be the Safe's own.
test("the hash of a batch is the hash that the deployed Safe v1.5.0 returned on the fork", () => {
  expect(safeTxHash(fixture.chainId, fixture.safe, fixture.multiSend, fixture.data, fixture.nonce)).toBe(fixture.hash);
  // another nonce, another Safe, another chain or one changed byte gives another hash
  expect(safeTxHash(fixture.chainId, fixture.safe, fixture.multiSend, fixture.data, fixture.nonce + 1)).not.toBe(fixture.hash);
  expect(safeTxHash(fixture.chainId, STRANGER, fixture.multiSend, fixture.data, fixture.nonce)).not.toBe(fixture.hash);
  expect(safeTxHash(5, fixture.safe, fixture.multiSend, fixture.data, fixture.nonce)).not.toBe(fixture.hash);
  expect(safeTxHash(fixture.chainId, fixture.safe, STRANGER, fixture.data, fixture.nonce)).not.toBe(fixture.hash);
  const changed = fixture.data.slice(0, -1) + (fixture.data.endsWith("0") ? "1" : "0");
  expect(safeTxHash(fixture.chainId, fixture.safe, fixture.multiSend, changed, fixture.nonce)).not.toBe(fixture.hash);
});

test("the hash is the EIP-712 hash of the Safe transaction, as a second implementation computes it", () => {
  const types = {
    SafeTx: [
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
      { name: "data", type: "bytes" },
      { name: "operation", type: "uint8" },
      { name: "safeTxGas", type: "uint256" },
      { name: "baseGas", type: "uint256" },
      { name: "gasPrice", type: "uint256" },
      { name: "gasToken", type: "address" },
      { name: "refundReceiver", type: "address" },
      { name: "nonce", type: "uint256" },
    ],
  };
  const zero = "0x0000000000000000000000000000000000000000";
  const data = encodeMultiSend(all.firstLoss);
  const message = { to: MULTISEND_CALL_ONLY, value: 0, data, operation: 1, safeTxGas: 0, baseGas: 0, gasPrice: 0, gasToken: zero, refundReceiver: zero, nonce: 7 };
  expect(safeTxHash(1, manifest.firstLossSafe, MULTISEND_CALL_ONLY, data, 7)).toBe(TypedDataEncoder.hash({ chainId: 1, verifyingContract: manifest.firstLossSafe }, types, message));
});

test("the calls of a batch decode from its data, and encode to the same data", () => {
  const calls = decodeMultiSend(fixture.data);
  expect(calls.length).toBe(43);
  expect(calls[0]).toEqual({ to: manifest.firstLossSafe, data: ABI.encodeFunctionData("enableModule", [manifest.firstLossModifier]) });
  expect(encodeMultiSend(calls)).toBe(fixture.data);
  expect(decodeMultiSend(encodeMultiSend(all.orders))).toEqual(all.orders.map((c) => ({ to: c.to, data: lower(c.data) })));
});

test("a batch that is no list of plain calls is refused", () => {
  const item = (operation: string, value: string, data: string, length = data.length / 2) => operation + lower(STRANGER).slice(2) + value.padStart(64, "0") + length.toString(16).padStart(64, "0") + data;
  const packed = (hex: string) => ABI.encodeFunctionData("multiSend", ["0x" + hex]);
  expect(decodeMultiSend(packed(item("00", "0", "aabb")))).toEqual([{ to: STRANGER, data: "0xaabb" }]);
  expect(() => decodeMultiSend(packed(item("01", "0", "aabb")))).toThrow("call 1 is no plain call: operation 1");
  expect(() => decodeMultiSend(packed(item("00", "1", "aabb")))).toThrow("call 1 sends ETH");
  expect(() => decodeMultiSend(packed(item("00", "0", "aabb", 3)))).toThrow("the multiSend data ends inside an item");
  expect(() => decodeMultiSend(packed(item("00", "0", "aabb") + "00"))).toThrow("the multiSend data ends inside an item");
  expect(() => decodeMultiSend(packed(""))).toThrow("the batch has no call");
  expect(() => decodeMultiSend(ABI.encodeFunctionData("enableModule", [STRANGER]))).toThrow("the data is no call of multiSend(bytes)");
  // bytes after the encoded argument change the hash, so the data must hold nothing that the decoding skips
  expect(() => decodeMultiSend(packed(item("00", "0", "aabb")) + "00".repeat(32))).toThrow("not in the canonical encoding");
});

test("the constants are the deployment's: CoW's contracts, Safe's MultiSendCallOnly, and CoW's settlement domain", () => {
  const addresses = readFileSync(path.join(ROOT, "constellation/addresses.ts"), "utf8");
  const mainnet = readFileSync(path.join(REPO, "test/rehearsal/Mainnet.sol"), "utf8");
  for (const [name, value] of [["COW_SETTLEMENT", COW_SETTLEMENT], ["COW_VAULT_RELAYER", COW_VAULT_RELAYER], ["COMPOSABLE_COW", COMPOSABLE_COW]] as const) {
    expect(addresses).toContain(`export const ${name} = "${value}";`);
    expect(mainnet).toContain(`address internal constant ${name} = ${value};`);
  }
  expect(mainnet).toContain(`address internal constant COW_FALLBACK_HANDLER = ${COW_FALLBACK_HANDLER};`);
  expect(mainnet).toContain(`address internal constant MULTISEND_CALL_ONLY = ${MULTISEND_CALL_ONLY};`);
  // the domain separator that CoW's settlement contract returns on mainnet
  expect(cowDomain(1)).toBe("0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943");
});

// ---------------------------------------------------------------------------------------------------------------
// The batches against the policy
// ---------------------------------------------------------------------------------------------------------------

test("batches that carry the policy and the setup pass, with each batch's hash and the vote's item", () => {
  const file = fileOf(whole());
  const report = checkBatches(file, policy);
  expect(report.problems).toEqual([]);
  expect(report.ok).toBe(true);
  expect(report.batches.map((b) => [b.name, b.nonce, b.calls, b.policyCalls, b.setup.length])).toEqual([
    ["Asset Safe", 0, all.asset.length, all.asset.length - 2, 2],
    ["orders account", 0, all.orders.length, all.orders.length - 11, 11],
    ["first-loss Safe", 0, all.firstLoss.length, all.firstLoss.length - 1, 1],
  ]);
  // every call of the policy is in a batch
  expect(report.batches.reduce((n, b) => n + b.policyCalls, 0)).toBe(policy.calls.to.length);
  for (const [i, batch] of report.batches.entries()) {
    expect(batch.hash).toBe(safeTxHash(1, batch.safe, MULTISEND_CALL_ONLY, file.batches[i].data, batch.nonce));
    expect(batch.approveHash).toBe("0xd4d9bdcd" + batch.hash.slice(2));
    expect(batch.bytes).toBeLessThanOrEqual(TX_SIZE_LIMIT);
  }
  // the first-loss Safe's batch is the fork's batch, so its hash is the fork's hash
  expect(file.batches[2].data).toBe(fixture.data);
  expect(report.batches[2].hash).toBe(fixture.hash);
});

test("a Safe's calls may be split over batches whose nonces follow each other", () => {
  const half = Math.floor(all.asset.length / 2);
  const split: [keyof typeof SAFES, Call[]][] = [["asset", all.asset.slice(0, half)], ["orders", all.orders], ["asset", all.asset.slice(half)], ["firstLoss", all.firstLoss]];
  expect(problems(fileOf(split))).toEqual([]);
  const gap = fileOf(split);
  gap.batches[2].nonce = 2;
  expect(problems(gap)).toEqual(["batch 3: the Asset Safe's batches must follow each other, and nonce 2 comes after 0"]);
  const twice = fileOf(split);
  twice.batches[2].nonce = 0;
  expect(problems(twice)[0]).toContain("nonce 0 comes after 0");
  const fraction = fileOf(whole());
  fraction.batches[0].nonce = 0.5;
  expect(problems(fraction)[0]).toBe("batch 1: the nonce 0.5 is no whole number");
});

test("with the Safes' nonces from the chain, the first batch of each Safe must name its nonce", () => {
  const nonces = new Map([[lower(manifest.assetSafe), 0n], [lower(manifest.ordersAccount), 0n], [lower(manifest.firstLossSafe), 3n]]);
  expect(problems(fileOf(whole()), policy, nonces)).toEqual(["batch 3: the first-loss Safe's nonce on chain is 3, and its first batch names 0"]);
  expect(problems(fileOf(whole(), 3), policy, new Map([[lower(manifest.firstLossSafe), 3n]]))).toEqual([]);
});

test("a batch that leaves out, reorders or adds a policy call fails", () => {
  const without = (calls: Call[], index: number) => calls.filter((_, i) => i !== index);
  // the last policy call of the first-loss Safe is missing
  expect(problems(fileOf([["asset", all.asset], ["orders", all.orders], ["firstLoss", without(all.firstLoss, all.firstLoss.length - 1)]]))).toEqual([
    `the first-loss Safe's batches hold ${all.firstLoss.length - 2} of the policy's ${all.firstLoss.length - 1} calls for it`,
  ]);
  // a policy call in the middle is missing: the next call is not the expected one
  expect(problems(fileOf([["asset", without(all.asset, 10)], ["orders", all.orders], ["firstLoss", all.firstLoss]]))[0]).toBe("batch 1, call 11: it is not call 9 of the policy's calls for the Asset Safe");
  // two policy calls change places
  const swapped = [...all.asset];
  [swapped[5], swapped[6]] = [swapped[6], swapped[5]];
  expect(problems(fileOf([["asset", swapped], ["orders", all.orders], ["firstLoss", all.firstLoss]])).slice(0, 2)).toEqual([
    "batch 1, call 6: it is not call 4 of the policy's calls for the Asset Safe",
    "batch 1, call 7: it is not call 5 of the policy's calls for the Asset Safe",
  ]);
  // one more call on a modifier, after the policy's last call
  expect(problems(fileOf([["asset", [...all.asset, all.asset[all.asset.length - 1]]], ["orders", all.orders], ["firstLoss", all.firstLoss]]))).toEqual([
    `batch 1, call ${all.asset.length + 1}: a call on a modifier after the policy's last call`,
  ]);
  // a call of another Safe's modifier is no policy call of this Safe
  expect(problems(fileOf([["asset", [...all.asset, all.firstLoss[1]]], ["orders", all.orders], ["firstLoss", all.firstLoss]]))[0]).toContain("is neither the policy nor a known setup call of the Asset Safe");
});

test("a call that is neither the policy nor the setup fails, and so does a missing or repeated setup call", () => {
  const usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const withCall = (call: Call) => problems(fileOf([["asset", all.asset], ["orders", [...all.orders, call]], ["firstLoss", all.firstLoss]]));
  const unknown = "is neither the policy nor a known setup call of the orders account";
  expect(withCall({ to: usdc, data: ABI.encodeFunctionData("transfer", [STRANGER, 1]) })[0]).toContain(unknown);
  expect(withCall({ to: usdc, data: ABI.encodeFunctionData("approve", [STRANGER, MAX]) })[0]).toContain(unknown);
  expect(withCall({ to: manifest.ordersAccount, data: ABI.encodeFunctionData("enableModule", [STRANGER]) })[0]).toContain(unknown);
  expect(withCall({ to: manifest.ordersAccount, data: ABI.encodeFunctionData("setFallbackHandler", [STRANGER]) })[0]).toContain(unknown);
  expect(withCall({ to: manifest.ordersAccount, data: ABI.encodeFunctionData("setDomainVerifier", [cowDomain(1), STRANGER]) })[0]).toContain(unknown);
  // a setup call that is already made is not known a second time
  expect(withCall(all.orders[0])[0]).toContain(unknown);
  // the Asset Safe may not make the orders account's setup calls
  expect(problems(fileOf([["asset", [...all.asset, all.orders[all.orders.length - 1]]], ["orders", all.orders], ["firstLoss", all.firstLoss]]))[0]).toContain("is neither the policy nor a known setup call of the Asset Safe");

  // a relayer approval below the maximum, and a missing one
  const lowApproval = all.orders.map((c, i) => (i === all.orders.length - 1 ? { to: c.to, data: ABI.encodeFunctionData("approve", [COW_VAULT_RELAYER, MAX - 1n]) } : c));
  const low = problems(fileOf([["asset", all.asset], ["orders", lowApproval], ["firstLoss", all.firstLoss]]));
  expect(low[0]).toContain(unknown);
  expect(low[1]).toBe(`the orders account's batches do not approve CoW's vault relayer for ${all.orders[all.orders.length - 1].to}`);
  expect(problems(fileOf([["asset", all.asset.slice(1)], ["orders", all.orders], ["firstLoss", all.firstLoss]]))).toEqual([`the Asset Safe's batches do not enable the module ${manifest.operatorModifier}`]);
  expect(problems(fileOf([["asset", all.asset], ["orders", all.orders.slice(1)], ["firstLoss", all.firstLoss]]))).toEqual(["the orders account's batches do not set CoW's fallback handler"]);
});

test("a wrong Safe, another MultiSend, another network, a wrong stated hash and a missing Safe fail", () => {
  const stranger = fileOf(whole());
  stranger.batches[0].safe = STRANGER;
  expect(problems(stranger)).toEqual([`batch 1: ${STRANGER} is none of the vault's Safes`, "no batch is for the Asset Safe", `the Asset Safe's batches hold 0 of the policy's ${all.asset.length - 2} calls for it`, `the Asset Safe's batches do not enable the module ${manifest.operatorModifier}`, `the Asset Safe's batches do not enable the module ${manifest.safetyModifier}`]);

  const other = { ...fileOf(whole()), multiSend: STRANGER };
  expect(problems(other)).toEqual([`the batches delegatecall ${STRANGER}, which is not Safe's MultiSendCallOnly ${MULTISEND_CALL_ONLY}`]);
  expect(problems({ ...fileOf(whole()), network: "mainnet" })).toEqual([`the batches are of mainnet, and the policy is of ${manifest.network}`]);
  expect(problems({ ...fileOf(whole()), chainId: 5 })[0]).toBe("the batches name chain 5, and the policy chain 1");
  expect(problems({ ...fileOf(whole()), format: "clutch.safe-batches/0" })).toEqual([`the file's format is clutch.safe-batches/0, not ${BATCHES_FORMAT}`]);
  expect(problems({ ...fileOf(whole()), batches: [] })).toEqual(["the file holds no batch"]);

  const stated = fileOf(whole());
  stated.batches[2].hash = fixture.hash;
  expect(problems(stated)).toEqual([]);
  stated.batches[1].hash = fixture.hash;
  expect(problems(stated)[0]).toContain(`batch 2: the file states the hash ${fixture.hash}, and the hash of this batch is 0x`);

  const broken = fileOf(whole());
  broken.batches[0].data = "0x1234";
  expect(problems(broken)[0]).toBe("batch 1: the data is no call of multiSend(bytes)");
});

test("a batch above the transaction pool's size limit fails", () => {
  // a policy with the Asset Safe's calls twice makes a batch of twice the size
  const doubled = clone(policy);
  const extra = { to: [] as string[], data: [] as string[], fn: [] as string[] };
  policy.calls.to.forEach((to, i) => {
    if (lower(to) !== lower(manifest.operatorModifier)) return;
    extra.to.push(to);
    extra.data.push(policy.calls.data[i]);
    extra.fn.push(policy.calls.fn[i]);
  });
  doubled.calls = { to: [...policy.calls.to, ...extra.to], data: [...policy.calls.data, ...extra.data], fn: [...policy.calls.fn, ...extra.fn] };
  const calls = callsOf(doubled);
  const found = problems(fileOf([["asset", calls.asset], ["orders", calls.orders], ["firstLoss", calls.firstLoss]]), doubled);
  expect(found.length).toBe(1);
  expect(found[0]).toMatch(/^batch 1: its transaction has \d+ bytes, above the transaction pool's limit of 131072$/);
  // in two batches, it passes
  const half = Math.floor(calls.asset.length / 2);
  expect(problems(fileOf([["asset", calls.asset.slice(0, half)], ["asset", calls.asset.slice(half)], ["orders", calls.orders], ["firstLoss", calls.firstLoss]]), doubled)).toEqual([]);
});
