// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The orders detector (ADR 009, decision 49): the price of each order of the orders account against a market
 * price. Nothing on chain bounds an order's price (ADR 007, decision 44), and a solver may fill an order at its
 * limit, so the detector reports:
 *
 *   - an open order whose limit lies further below the market than the threshold;
 *   - a fill whose price lies further below the market than the threshold;
 *   - an open order that it cannot read, and a token that has no price.
 *
 * The chain is the anchor. The settlement's events say which orders the account signed, cancelled and filled,
 * but a signed order's event carries only its identifier. The caller gives the orders' fields, from CoW's order
 * book or from the signing transaction, and the detector takes a record only when its identifier, computed from
 * the fields, is one that the account signed. A TWAP order's fields are in ComposableCoW's event.
 *
 * The caller also gives the prices and the threshold. This file fetches no price and holds no threshold.
 */
import { AbiCoder, getAddress, Interface, solidityPacked, TypedDataEncoder } from "ethers";
import type { Log } from "./roundtrip";

export const COW_SETTLEMENT = "0x9008D19f58AAbD9eD0D60971565AA8510560ab41";
export const COMPOSABLE_COW = "0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74";
export const TWAP_HANDLER = "0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5";

const SETTLEMENT = new Interface([
  "event PreSignature(address indexed owner, bytes orderUid, bool signed)",
  "event Trade(address indexed owner, address sellToken, address buyToken, uint256 sellAmount, uint256 buyAmount, uint256 feeAmount, bytes orderUid)",
  "event OrderInvalidated(address indexed owner, bytes orderUid)",
]);
const COMPOSABLE = new Interface(["event ConditionalOrderCreated(address indexed owner, (address handler, bytes32 salt, bytes staticInput) params)"]);
/** ComposableCoW's `TWAPOrder.Data`. */
const TWAP_DATA = ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"];

/** CoW's `GPv2Order.Data`, with amounts as decimal strings and the kind and balances as their names. */
export type OrderRecord = {
  sellToken: string;
  buyToken: string;
  receiver: string;
  sellAmount: string;
  buyAmount: string;
  validTo: number;
  appData: string;
  feeAmount: string;
  kind: "sell" | "buy";
  partiallyFillable: boolean;
  sellTokenBalance: string;
  buyTokenBalance: string;
};
/** A token's decimals and its market price in one common unit, as a decimal string. */
export type Prices = Record<string, { decimals: number; price: string }>;
export type OrderAlert = { kind: "limit" | "fill" | "unreadable" | "unpriced"; order: string; text: string; belowBps?: number };
export type OrdersWatch = { alert: boolean; open: string[]; fills: number; alerts: OrderAlert[] };
export type OrdersOptions = { maxBelowBps: number; now: number; chainId?: number; settlement?: string; composableCow?: string };

const lower = (value: string) => value.toLowerCase();
const ORDER_TYPES = {
  Order: [
    { name: "sellToken", type: "address" },
    { name: "buyToken", type: "address" },
    { name: "receiver", type: "address" },
    { name: "sellAmount", type: "uint256" },
    { name: "buyAmount", type: "uint256" },
    { name: "validTo", type: "uint32" },
    { name: "appData", type: "bytes32" },
    { name: "feeAmount", type: "uint256" },
    { name: "kind", type: "string" },
    { name: "partiallyFillable", type: "bool" },
    { name: "sellTokenBalance", type: "string" },
    { name: "buyTokenBalance", type: "string" },
  ],
};

/** An order's identifier at the settlement: its EIP-712 digest, its owner and its `validTo`. */
export function orderUid(order: OrderRecord, owner: string, chainId = 1, settlement = COW_SETTLEMENT): string {
  const domain = { name: "Gnosis Protocol", version: "v2", chainId, verifyingContract: getAddress(settlement) };
  const digest = TypedDataEncoder.hash(domain, ORDER_TYPES, order);
  return lower(solidityPacked(["bytes32", "address", "uint32"], [digest, getAddress(owner), order.validTo]));
}

/** A decimal string as an integer scaled by 10^18. */
function scaled(decimal: string): bigint {
  if (!/^\d+(\.\d+)?$/.test(decimal)) throw new Error(`not a decimal price: ${decimal}`);
  const [whole, fraction = ""] = decimal.split(".");
  if (fraction.length > 18) throw new Error(`a price has at most 18 decimals: ${decimal}`);
  return BigInt(whole) * 10n ** 18n + BigInt(fraction.padEnd(18, "0"));
}

/**
 * How far the bought value lies below the sold value, in basis points of the sold value; 0 when it is equal or
 * above. Null when a token has no price, or a price or the sold amount is zero.
 */
export function belowMarketBps(sellToken: string, sellAmount: bigint, buyToken: string, buyAmount: bigint, prices: Prices): number | null {
  const sell = prices[lower(sellToken)];
  const buy = prices[lower(buyToken)];
  if (!sell || !buy) return null;
  // both values in the common unit, scaled by 10^(18 + 36) to keep the precision of either token's decimals
  const sold = sellAmount * scaled(sell.price) * 10n ** BigInt(36 - sell.decimals);
  const bought = buyAmount * scaled(buy.price) * 10n ** BigInt(36 - buy.decimals);
  if (sold === 0n || scaled(buy.price) === 0n) return null;
  if (bought >= sold) return 0;
  return Number(((sold - bought) * 10_000n) / sold);
}

/**
 * The alerts for the orders of `owner`, from the logs of the settlement and of ComposableCoW in the order of
 * emission. `records` are the fields of signed orders; a record that matches no signed identifier is ignored.
 */
export function watchOrders(logs: Log[], owner: string, records: OrderRecord[], prices: Prices, options: OrdersOptions): OrdersWatch {
  const settlement = lower(options.settlement ?? COW_SETTLEMENT);
  const composable = lower(options.composableCow ?? COMPOSABLE_COW);
  const account = lower(getAddress(owner));
  const known = new Map(records.map((record) => [orderUid(record, owner, options.chainId ?? 1, settlement), record]));
  const signed = new Map<string, boolean>();
  const invalidated = new Set<string>();
  const sold = new Map<string, bigint>();
  const bought = new Map<string, bigint>();
  const alerts: OrderAlert[] = [];
  let fills = 0;
  const judge = (kind: "limit" | "fill", order: string, what: string, sellToken: string, sellAmount: bigint, buyToken: string, buyAmount: bigint) => {
    const below = belowMarketBps(sellToken, sellAmount, buyToken, buyAmount, prices);
    if (below === null) {
      alerts.push({ kind: "unpriced", order, text: `${what} has no market price to compare with: ${sellToken} for ${buyToken}` });
    } else if (below > options.maxBelowBps) {
      alerts.push({ kind, order, belowBps: below, text: `${what} lies ${below} basis points below the market; the threshold is ${options.maxBelowBps}` });
    }
  };

  for (const log of logs) {
    const emitter = lower(log.address);
    if (emitter === settlement) {
      const event = SETTLEMENT.parseLog(log);
      if (!event || lower(event.args.owner) !== account) continue;
      const uid = lower(event.args.orderUid);
      if (event.name === "PreSignature") signed.set(uid, event.args.signed);
      if (event.name === "OrderInvalidated") invalidated.add(uid);
      if (event.name === "Trade") {
        fills++;
        sold.set(uid, (sold.get(uid) ?? 0n) + event.args.sellAmount);
        bought.set(uid, (bought.get(uid) ?? 0n) + event.args.buyAmount);
        judge("fill", uid, `a fill of order ${uid.slice(0, 18)}…`, event.args.sellToken, event.args.sellAmount, event.args.buyToken, event.args.buyAmount);
      }
    } else if (emitter === composable) {
      const event = COMPOSABLE.parseLog(log);
      if (!event || lower(event.args.owner) !== account) continue;
      const { handler, salt, staticInput } = event.args.params;
      const order = `conditional order ${String(salt).slice(0, 18)}…`;
      if (lower(handler) !== lower(TWAP_HANDLER)) {
        alerts.push({ kind: "unreadable", order: lower(salt), text: `${order} uses a handler that the detector cannot read: ${handler}` });
        continue;
      }
      const [sellToken, buyToken, , partSellAmount, minPartLimit] = AbiCoder.defaultAbiCoder().decode(TWAP_DATA, staticInput);
      judge("limit", lower(salt), `the limit of each part of ${order}`, sellToken, partSellAmount, buyToken, minPartLimit);
    }
  }

  const open: string[] = [];
  for (const [uid, isSigned] of signed) {
    const validTo = Number.parseInt(uid.slice(-8), 16);
    if (!isSigned || invalidated.has(uid) || validTo <= options.now) continue;
    const record = known.get(uid);
    if (!record) {
      // a filled order needs no record: its fill was judged above
      if (!sold.has(uid)) {
        open.push(uid);
        alerts.push({ kind: "unreadable", order: uid, text: `order ${uid.slice(0, 18)}… is signed and open, and the detector has no record of its fields` });
      }
      continue;
    }
    const done =
      record.kind === "sell"
        ? (sold.get(uid) ?? 0n) >= (record.partiallyFillable ? BigInt(record.sellAmount) : 1n)
        : (bought.get(uid) ?? 0n) >= (record.partiallyFillable ? BigInt(record.buyAmount) : 1n);
    if (done) continue;
    open.push(uid);
    judge("limit", uid, `the limit of open order ${uid.slice(0, 18)}…`, record.sellToken, BigInt(record.sellAmount), record.buyToken, BigInt(record.buyAmount));
  }
  return { alert: alerts.length > 0, open, fills, alerts };
}
