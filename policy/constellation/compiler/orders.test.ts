// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { AbiCoder, Interface, zeroPadValue } from "ethers";
import { belowMarketBps, COMPOSABLE_COW, COW_SETTLEMENT, orderUid, TWAP_HANDLER, watchOrders } from "./orders";
import type { OrderRecord, Prices } from "./orders";
import type { Log } from "./roundtrip";

const OWNER = "0x00000000000000000000000000000000000000A1";
const STRANGER = "0x00000000000000000000000000000000000000B2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const NOW = 1_800_000_000;
const PRICES: Prices = {
  [USDC.toLowerCase()]: { decimals: 6, price: "1" },
  [USDT.toLowerCase()]: { decimals: 6, price: "1.001" },
  [WETH.toLowerCase()]: { decimals: 18, price: "2500" },
};
const OPTIONS = { maxBelowBps: 100, now: NOW };
const SETTLEMENT = new Interface([
  "event PreSignature(address indexed owner, bytes orderUid, bool signed)",
  "event Trade(address indexed owner, address sellToken, address buyToken, uint256 sellAmount, uint256 buyAmount, uint256 feeAmount, bytes orderUid)",
  "event OrderInvalidated(address indexed owner, bytes orderUid)",
]);
const COMPOSABLE = new Interface(["event ConditionalOrderCreated(address indexed owner, (address handler, bytes32 salt, bytes staticInput) params)"]);

const order = (sellToken: string, buyToken: string, sellAmount: bigint, buyAmount: bigint, more: Partial<OrderRecord> = {}): OrderRecord => ({
  sellToken,
  buyToken,
  receiver: OWNER,
  sellAmount: String(sellAmount),
  buyAmount: String(buyAmount),
  validTo: NOW + 3600,
  appData: zeroPadValue("0x", 32),
  feeAmount: "0",
  kind: "sell",
  partiallyFillable: false,
  sellTokenBalance: "erc20",
  buyTokenBalance: "erc20",
  ...more,
});
const log = (address: string, iface: Interface, name: string, args: unknown[]): Log => {
  const { topics, data } = iface.encodeEventLog(name, args);
  return { address, topics, data };
};
const sign = (o: OrderRecord, signed = true, owner = OWNER) => log(COW_SETTLEMENT, SETTLEMENT, "PreSignature", [owner, orderUid(o, owner), signed]);
const trade = (o: OrderRecord, sellAmount: bigint, buyAmount: bigint, owner = OWNER) =>
  log(COW_SETTLEMENT, SETTLEMENT, "Trade", [owner, o.sellToken, o.buyToken, sellAmount, buyAmount, 0n, orderUid(o, owner)]);

test("an order's identifier is CoW's: a known order of mainnet gives its known identifier's shape and binds every field", () => {
  const o = order(USDC, USDT, 1_000_000n, 990_000n);
  const uid = orderUid(o, OWNER);
  expect(uid).toMatch(/^0x[0-9a-f]{112}$/);
  expect(uid.slice(66, 106)).toBe(OWNER.slice(2).toLowerCase());
  expect(Number.parseInt(uid.slice(-8), 16)).toBe(o.validTo);
  // every field that changes the order changes the identifier
  for (const change of [{ buyAmount: "1" }, { receiver: STRANGER }, { feeAmount: "1" }, { kind: "buy" as const }, { partiallyFillable: true }, { appData: zeroPadValue("0x01", 32) }]) {
    expect(orderUid({ ...o, ...change }, OWNER)).not.toBe(uid);
  }
  expect(orderUid(o, STRANGER)).not.toBe(uid);
  expect(orderUid(o, OWNER, 11155111)).not.toBe(uid);
});

test("the distance below the market is in basis points of the sold value, across decimals", () => {
  expect(belowMarketBps(USDC, 1_000_000n, USDT, 999_001n, PRICES)).toBe(0);
  expect(belowMarketBps(USDC, 1_000_000n, USDT, 989_011n, PRICES)).toBe(99);
  expect(belowMarketBps(USDC, 1_000_000n, USDT, 500_000n, PRICES)).toBe(4995);
  expect(belowMarketBps(WETH, 10n ** 18n, USDC, 2_500_000_000n, PRICES)).toBe(0);
  expect(belowMarketBps(WETH, 10n ** 18n, USDC, 2_450_000_000n, PRICES)).toBe(200);
  expect(belowMarketBps(WETH, 10n ** 18n, USDC, 1n, PRICES)).toBe(9999);
  expect(belowMarketBps(USDC, 2_600_000_000n, WETH, 10n ** 18n, PRICES)).toBe(384);
  expect(belowMarketBps(WETH, 1n, STRANGER, 1n, PRICES)).toBeNull();
  expect(belowMarketBps(USDC, 0n, USDT, 1n, PRICES)).toBeNull();
  expect(() => belowMarketBps(USDC, 1n, USDT, 1n, { ...PRICES, [USDT.toLowerCase()]: { decimals: 6, price: "1e3" } })).toThrow(/not a decimal price/);
});

test("an open order with a limit far below the market is an alert, and a fair one is not", () => {
  const fair = order(USDC, USDT, 2_000_000_000n, 1_990_000_000n);
  const bad = order(USDC, USDT, 4_000_000_000n, 2_000_000_000n);
  const result = watchOrders([sign(fair), sign(bad)], OWNER, [fair, bad], PRICES, OPTIONS);
  expect(result.open).toEqual([orderUid(fair, OWNER), orderUid(bad, OWNER)]);
  expect(result.alerts.map((a) => [a.kind, a.order, a.belowBps])).toEqual([["limit", orderUid(bad, OWNER), 4995]]);
  expect(result.alert).toBe(true);
  expect(watchOrders([sign(fair)], OWNER, [fair], PRICES, OPTIONS).alert).toBe(false);
});

test("an unsigned, invalidated, expired or filled order is not open", () => {
  const bad = order(USDC, USDT, 4_000_000_000n, 2_000_000_000n);
  const none = (logs: Log[], now = NOW) => watchOrders(logs, OWNER, [bad], PRICES, { ...OPTIONS, now });
  expect(none([sign(bad), sign(bad, false)]).open).toEqual([]);
  expect(none([sign(bad), sign(bad, false)]).alert).toBe(false);
  expect(none([sign(bad), log(COW_SETTLEMENT, SETTLEMENT, "OrderInvalidated", [OWNER, orderUid(bad, OWNER)])]).alert).toBe(false);
  expect(none([sign(bad)], bad.validTo).alert).toBe(false);
  expect(none([sign(bad)], bad.validTo - 1).alert).toBe(true);
  // signed again after a cancel: open again
  expect(none([sign(bad), sign(bad, false), sign(bad)]).open).toHaveLength(1);
  // filled: no open order, and the fill itself is the alert
  const filled = none([sign(bad), trade(bad, 4_000_000_000n, 2_000_000_000n)]);
  expect(filled.open).toEqual([]);
  expect(filled.alerts.map((a) => a.kind)).toEqual(["fill"]);
});

test("a partly filled order stays open until its whole amount is sold", () => {
  const part = order(USDC, USDT, 4_000_000_000n, 2_000_000_000n, { partiallyFillable: true });
  const half = watchOrders([sign(part), trade(part, 2_000_000_000n, 1_999_000_000n)], OWNER, [part], PRICES, OPTIONS);
  expect(half.open).toHaveLength(1);
  expect(half.alerts.map((a) => a.kind)).toEqual(["limit"]);
  const whole = watchOrders([sign(part), trade(part, 2_000_000_000n, 1_999_000_000n), trade(part, 2_000_000_000n, 1_999_000_000n)], OWNER, [part], PRICES, OPTIONS);
  expect(whole.open).toEqual([]);
  expect(whole.alert).toBe(false);
  expect(whole.fills).toBe(2);
});

test("a fill far below the market is an alert, with or without a record", () => {
  const worse = order(WETH, USDC, 10n ** 18n, 1_250_000_000n);
  const logs = [sign(worse), trade(worse, 10n ** 18n, 1_250_000_000n)];
  for (const records of [[worse], []]) {
    const result = watchOrders(logs, OWNER, records, PRICES, OPTIONS);
    expect(result.alerts.map((a) => [a.kind, a.belowBps])).toEqual([["fill", 5000]]);
  }
  // a fill at the market is quiet
  expect(watchOrders([sign(worse), trade(worse, 10n ** 18n, 2_499_000_000n)], OWNER, [], PRICES, OPTIONS).alert).toBe(false);
});

test("a signed order without a record is an alert, and a record that the account did not sign is ignored", () => {
  const bad = order(USDC, USDT, 4_000_000_000n, 2_000_000_000n);
  const unread = watchOrders([sign(bad)], OWNER, [], PRICES, OPTIONS);
  expect(unread.alerts.map((a) => a.kind)).toEqual(["unreadable"]);
  // a record with one changed field has another identifier: it cannot stand in for the signed order
  const forged = watchOrders([sign(bad)], OWNER, [{ ...bad, buyAmount: "3999000000" }], PRICES, OPTIONS);
  expect(forged.alerts.map((a) => a.kind)).toEqual(["unreadable"]);
  expect(watchOrders([], OWNER, [bad], PRICES, OPTIONS)).toEqual({ alert: false, open: [], fills: 0, alerts: [] });
});

test("another account's orders and fills are not this account's", () => {
  const bad = order(USDC, USDT, 4_000_000_000n, 2_000_000_000n, { receiver: STRANGER });
  const logs = [sign(bad, true, STRANGER), trade(bad, 4_000_000_000n, 2_000_000_000n, STRANGER)];
  expect(watchOrders(logs, OWNER, [bad], PRICES, OPTIONS)).toEqual({ alert: false, open: [], fills: 0, alerts: [] });
});

test("a token without a price is an alert, for an open order and for a fill", () => {
  const exotic = order(STRANGER, USDC, 1n, 1n);
  expect(watchOrders([sign(exotic)], OWNER, [exotic], PRICES, OPTIONS).alerts.map((a) => a.kind)).toEqual(["unpriced"]);
  expect(watchOrders([sign(exotic), trade(exotic, 1n, 1n)], OWNER, [exotic], PRICES, OPTIONS).alerts.map((a) => a.kind)).toEqual(["unpriced"]);
});

test("a TWAP order's part limit is read from ComposableCoW's event, and another handler is an alert", () => {
  const twap = (partSell: bigint, minPart: bigint, handler = TWAP_HANDLER, owner = OWNER) =>
    log(COMPOSABLE_COW, COMPOSABLE, "ConditionalOrderCreated", [
      owner,
      [
        handler,
        zeroPadValue("0x07", 32),
        AbiCoder.defaultAbiCoder().encode(
          ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"],
          [USDC, USDT, OWNER, partSell, minPart, 0, 2, 86400, 0, zeroPadValue("0x", 32)],
        ),
      ],
    ]);
  expect(watchOrders([twap(1_000_000_000n, 995_000_000n)], OWNER, [], PRICES, OPTIONS).alert).toBe(false);
  expect(watchOrders([twap(1_000_000_000n, 500_000_000n)], OWNER, [], PRICES, OPTIONS).alerts.map((a) => [a.kind, a.belowBps])).toEqual([["limit", 4995]]);
  expect(watchOrders([twap(1_000_000_000n, 500_000_000n, STRANGER)], OWNER, [], PRICES, OPTIONS).alerts.map((a) => a.kind)).toEqual(["unreadable"]);
  expect(watchOrders([twap(1_000_000_000n, 500_000_000n, TWAP_HANDLER, STRANGER)], OWNER, [], PRICES, OPTIONS).alert).toBe(false);
});
