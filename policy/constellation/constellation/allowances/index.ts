// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: one key per protocol spender (OD-08),
// with dry-run stand-ins. See PROVENANCE.md.
import { MONTH } from "../parameters";

/**
 * Budget keys on the operator modifier, one per protocol spender (ADR 009,
 * OD-08). An approval to the spender spends the key; a deposit spends
 * nothing, because a spender can pull an approval without any deposit call.
 *
 * A budget counts one token's units, so each key serves one token. `balance`
 * starts full, and `refill` is added every `period`, up to `maxRefill`.
 *
 * The amounts are dry-run stand-ins. The production figures come from the
 * attested computation and are not in this repository.
 */

/** USDS approved to sUSDS. */
export const sky_savings_usds = budget("sky_savings_usds", 1_000n * 10n ** 18n);

/** USDC approved to the earnUSD deposit queue. */
export const earn_usd_deposit = budget("earn_usd_deposit", 500n * 10n ** 6n);

/** wstETH approved to the earnETH deposit queue. */
export const earn_eth_deposit_wsteth = budget("earn_eth_deposit_wsteth", 10n ** 18n);

/**
 * The orders budgets: what the operator sends to the orders account for its orders, one key per order token
 * (ADR 007, decision 18). The transfer spends the key, because the orders account can sell all it holds.
 */
export const orders_steth = budget("orders_steth", 10n * 10n ** 18n);
export const orders_wsteth = budget("orders_wsteth", 10n * 10n ** 18n);
export const orders_weth = budget("orders_weth", 10n * 10n ** 18n);
export const orders_usdc = budget("orders_usdc", 10_000n * 10n ** 6n);
export const orders_usdt = budget("orders_usdt", 10_000n * 10n ** 6n);
export const orders_usds = budget("orders_usds", 10_000n * 10n ** 18n);

function budget(label: string, perMonth: bigint) {
  return {
    key: label,
    refill: perMonth,
    maxRefill: perMonth,
    period: MONTH,
    balance: perMonth,
    timestamp: 0n,
  };
}
