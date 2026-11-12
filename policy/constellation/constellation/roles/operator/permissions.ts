// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: rewritten to the launch scope of ADR 011
// and the approval rule of OD-08. See PROVENANCE.md.
// Changed for Clutch on 2026-10-09: the withdrawal queue left the scope
// (ADR 007, decision 27).
// Changed for Clutch on 2026-10-14: the committee's own Safe holds the
// operator role (ADR 005, decision 31).
// Changed for Clutch on 2026-10-21: the approval ceilings' stand-ins are named
// after the mandate size (OD-89).
// Changed for Clutch on 2026-11-07: the operator funds the orders account
// (ADR 007, decision 18).
// Changed for Clutch on 2026-11-11: the operator's return to the Aragon Agent
// (ADR 014, decision 9).
import { c, call, callWithValue } from "../../lib";
import {
  DAI,
  DAI_USDS,
  EARN_ETH,
  EARN_USD,
  manifest,
  STETH,
  SUSDS,
  USDC,
  USDS,
  USDT,
  WETH,
  WSTETH,
} from "../../addresses";
import {
  earn_eth_deposit_wsteth,
  earn_usd_deposit,
  orders_steth,
  orders_usdc,
  orders_usds,
  orders_usdt,
  orders_weth,
  orders_wsteth,
  sky_savings_usds,
} from "../../allowances";
import { SIZE_STANDIN_STETH, SIZE_STANDIN_USD } from "../../parameters";

const ZERO = "0x0000000000000000000000000000000000000000";

/**
 * Every approval the operator may give, one per token and spender (ADR 009,
 * OD-08). An approval to a spender with a budget key spends that key, so an
 * approval of zero spends nothing and stays allowed. A spender with no key
 * has a fixed ceiling, and the amount must stay below it. The SDK merges the
 * entries of one token into one Or, because a second scope on the same
 * function would replace the first.
 *
 * The emergency role can set each of these approvals to zero, so its list is
 * built from this one.
 */
export const APPROVALS: readonly { token: string; spender: string; budget?: string; ceiling?: bigint }[] = [
  { token: STETH, spender: WSTETH, ceiling: SIZE_STANDIN_STETH },
  { token: USDS, spender: SUSDS, budget: sky_savings_usds.key },
  { token: USDS, spender: DAI_USDS, ceiling: SIZE_STANDIN_USD }, // OD-22
  { token: DAI, spender: DAI_USDS, ceiling: SIZE_STANDIN_USD }, // OD-22
  { token: USDC, spender: EARN_USD.depositQueue, budget: earn_usd_deposit.key },
  { token: WSTETH, spender: EARN_ETH.depositQueue, budget: earn_eth_deposit_wsteth.key },
];

/**
 * How the operator funds the orders account for an order: one transfer per order token, pinned to the orders
 * account, under that token's orders budget (ADR 007, decision 18).
 */
export const ORDER_FUNDING: readonly { token: string; budget: string }[] = [
  { token: STETH, budget: orders_steth.key },
  { token: WSTETH, budget: orders_wsteth.key },
  { token: WETH, budget: orders_weth.key },
  { token: USDC, budget: orders_usdc.key },
  { token: USDT, budget: orders_usdt.key },
  { token: USDS, budget: orders_usds.key },
];

/**
 * What the committee's Safe, as the operator, may do with the Asset Safe. Default deny: anything
 * absent here is refused. Every receiver and owner is pinned to the Asset
 * Safe (`c.avatar`). The operator's only transfers fund the orders account,
 * pinned to it and under its orders budgets, or return an order token to the
 * Aragon Agent. So assets can move into and out of the approved venues, into
 * the orders account and back to the treasury, but nowhere else.
 */
export default [
  ...APPROVALS.map(({ token, spender, budget, ceiling }) =>
    call(
      token,
      "approve(address,uint256)",
      spender,
      budget !== undefined ? c.withinAllowance(budget) : c.lt(ceiling!),
    ),
  ),

  // Lido staking: stake ETH with no referral, and wrap and unwrap (OD-20).
  // The withdrawal queue left the scope (ADR 007, decision 27).
  callWithValue(STETH, "submit(address)", ZERO),
  call(WSTETH, "wrap(uint256)"),
  call(WSTETH, "unwrap(uint256)"),

  // WETH: wrap and unwrap (OD-20).
  callWithValue(WETH, "deposit()"),
  call(WETH, "withdraw(uint256)"),

  // Stablecoins: Sky's DAI–USDS converter, one to one, paid to the Asset
  // Safe (OD-22), and sUSDS savings.
  call(DAI_USDS, "daiToUsds(address,uint256)", c.avatar),
  call(DAI_USDS, "usdsToDai(address,uint256)", c.avatar),
  call(SUSDS, "deposit(uint256,address)", undefined, c.avatar),
  call(SUSDS, "redeem(uint256,address,address)", undefined, c.avatar, c.avatar),
  call(SUSDS, "withdraw(uint256,address,address)", undefined, c.avatar, c.avatar),

  // Lido Earn: asynchronous deposit and redeem. The approval spends the
  // budget, so the deposit itself is unbudgeted. Claims pay the Asset Safe.
  ...[EARN_USD, EARN_ETH].flatMap((vault) => [
    call(vault.depositQueue, "deposit(uint224,address,bytes32[])"),
    call(vault.depositQueue, "cancelDepositRequest()"),
    call(vault.depositQueue, "claim(address)", c.avatar),
    call(vault.redeemQueue, "redeem(uint256)"),
    call(vault.redeemQueue, "claim(address,uint32[])", c.avatar),
  ]),
  // The orders account, for CoW orders: each transfer spends its token's orders budget (ADR 007, decision 18).
  ...ORDER_FUNDING.map(({ token, budget }) =>
    call(token, "transfer(address,uint256)", manifest.ordersAccount, c.withinAllowance(budget)),
  ),
  // The return to the treasury: a transfer of an order token, of any amount, pinned to the Aragon Agent
  // (ADR 014, decision 9). The SDK merges it with the funding transfer into one Or, because a second
  // scope on the same function would replace the first.
  ...ORDER_FUNDING.map(({ token }) => call(token, "transfer(address,uint256)", manifest.agent)),
] satisfies Permissions;
