// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * CoW orders from the orders account (ADR 007): the order signer's market and limit orders, and TWAP orders
 * through ComposableCoW. Each builder returns a permission entry that pins what the order may do; the roles
 * on the orders modifier fill in their own tokens, receiver and life.
 *
 * Two fields are pinned for every order:
 * - The app data is zero (ADR 007, decision 42; OD-115). An order's app data can carry hooks, which are calls run
 *   with the swap, and a partner fee of up to 100 basis points of its volume, which CoW pays to the partner that
 *   the app data names. Zero app data carries neither.
 * - The signed fee is zero (ADR 007, decision 43; OD-116): the order's own fee field is zero, and so is the order
 *   signer's fee bound, which alone would let the fee reach 1 wei. CoW's order book refuses a signed fee, and CoW
 *   takes its fees inside the execution, within the order's limit.
 */
import { id, zeroPadValue } from "ethers";
import { anyOf, c, call } from "./lib";
import { COMPOSABLE_COW, ORDER_SIGNER, TIMESTAMP_FACTORY, TWAP_HANDLER } from "./addresses";
import { TWAP_SHAPES } from "./parameters";

/** CoW's `GPv2Order.Data`, as the order signer takes it. */
export const ORDER = "(address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32)";

/** `GPv2Order.BALANCE_ERC20`: the order uses plain ERC-20 balances, not Balancer vault balances. */
export const ERC20_BALANCE = id("erc20") as `0x${string}`;

/** Zero app data: no hooks and no partner fee. */
export const NO_APP_DATA = zeroPadValue("0x", 32) as `0x${string}`;

/** ComposableCoW's TWAP order data, `TWAPOrder.Data`: ten static fields. */
const TWAP_DATA = ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"];

type Order = { sell: readonly string[]; buy: readonly string[]; receiver: string; life: bigint };

/**
 * A market or limit order through the order signer, by delegatecall: listed tokens, a pinned receiver, plain
 * ERC-20 balances, zero app data, a `validDuration` of at most `life`, a signed fee of zero and a fee bound of
 * zero. The signer refuses an order whose `validTo` lies beyond `validDuration`. Amounts, kind and partial fills
 * stay open.
 */
export function signOrder({ sell, buy, receiver, life }: Order) {
  return {
    ...call(
      ORDER_SIGNER,
      `signOrder(${ORDER},uint32,uint256)`,
      c.matches([
        anyOf(sell),
        anyOf(buy),
        receiver,
        c.pass,
        c.pass,
        c.pass,
        NO_APP_DATA,
        0n,
        c.pass,
        c.pass,
        ERC20_BALANCE,
        ERC20_BALANCE,
      ]),
      c.lte(life),
      0n,
    ),
    delegatecall: true as const,
  };
}

/** Cancel an order of the orders account, by delegatecall. It can only withdraw the account's own signatures. */
export function unsignOrder() {
  return { ...call(ORDER_SIGNER, `unsignOrder(${ORDER})`), delegatecall: true as const };
}

/**
 * A TWAP order through ComposableCoW: CoW's TWAP handler, listed tokens, a pinned receiver and zero app data.
 * The start is zero and the value factory is CoW's current-timestamp factory, so the order starts at its
 * creation. Its parts and their spacing take one of the two shapes of decision 29.
 */
export function twapOrder({ sell, buy, receiver }: Omit<Order, "life">) {
  const shape = (parts: bigint, spacing: bigint) =>
    c.abiEncodedMatches(
      [anyOf(sell), anyOf(buy), receiver, c.pass, c.pass, 0n, c.lte(parts), c.lte(spacing), c.pass, NO_APP_DATA],
      TWAP_DATA,
    );
  const shapes = TWAP_SHAPES.map(({ parts, spacing }) => shape(parts, spacing));
  return call(
    COMPOSABLE_COW,
    "createWithContext((address,bytes32,bytes),address,bytes,bool)",
    c.matches([TWAP_HANDLER, c.pass, (c.or as unknown as (...b: unknown[]) => unknown)(...shapes)]),
    TIMESTAMP_FACTORY,
  );
}

/** Cancel a conditional order of the orders account. ComposableCoW keys it by its owner, the caller. */
export function removeConditionalOrder() {
  return call(COMPOSABLE_COW, "remove(bytes32)");
}
