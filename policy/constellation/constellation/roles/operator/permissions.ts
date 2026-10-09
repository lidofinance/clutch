// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: rewritten to the launch scope of ADR 011
// and the approval rule of OD-08. See PROVENANCE.md.
// Changed for Clutch on 2026-10-09: the withdrawal queue left the scope
// (ADR 007, decision 27).
import { c, call, callWithValue } from "../../lib";
import {
  DAI,
  DAI_USDS,
  EARN_ETH,
  EARN_USD,
  STETH,
  SUSDS,
  USDC,
  USDS,
  WETH,
  WSTETH,
} from "../../addresses";
import { earn_eth_deposit_wsteth, earn_usd_deposit, sky_savings_usds } from "../../allowances";
import { FLOOR_STANDIN_STETH, FLOOR_STANDIN_USD } from "../../parameters";

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
  { token: STETH, spender: WSTETH, ceiling: FLOOR_STANDIN_STETH },
  { token: USDS, spender: SUSDS, budget: sky_savings_usds.key },
  { token: USDS, spender: DAI_USDS, ceiling: FLOOR_STANDIN_USD }, // OD-22
  { token: DAI, spender: DAI_USDS, ceiling: FLOOR_STANDIN_USD }, // OD-22
  { token: USDC, spender: EARN_USD.depositQueue, budget: earn_usd_deposit.key },
  { token: WSTETH, spender: EARN_ETH.depositQueue, budget: earn_eth_deposit_wsteth.key },
];

/**
 * What the operator Safe may do with the Asset Safe. Default deny: anything
 * absent here is refused. Every receiver and owner is pinned to the Asset
 * Safe (`c.avatar`), and the operator holds no `transfer`, so assets can
 * move into and out of the approved venues but not leave the Asset Safe.
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
] satisfies Permissions;
