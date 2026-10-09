// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: rewritten to the emergency role of
// ADR 005 on the safety modifier, held by the emergency Safe. See PROVENANCE.md.
// Changed for Clutch on 2026-10-09: the withdrawal queue left the scope
// (ADR 007, decision 27).
import { anyOf, c, call, callWithValue, key, unique } from "../../lib";
import {
  DAI,
  EARN_ETH,
  EARN_USD,
  LDO,
  manifest,
  STETH,
  SUSDS,
  USDC,
  USDS,
  USDT,
  WETH,
  WSTETH,
} from "../../addresses";
import { APPROVALS } from "../operator/permissions";

const ZERO = "0x0000000000000000000000000000000000000000";

/** Every spender the operator can approve. The emergency role can set each approval back to zero. */
const SPENDERS = unique(APPROVALS.map((approval) => approval.spender));
const APPROVED_TOKENS = unique(APPROVALS.map((approval) => approval.token));

/** Assets the Asset Safe can hold, which the emergency role may return to the Agent. */
const RETURNABLE = [STETH, WSTETH, WETH, LDO, USDC, USDT, DAI, USDS, SUSDS, EARN_USD.share, EARN_ETH.share];

/**
 * What the emergency Safe may do, without a governance motion (ADR 005): zero
 * approvals, exit positions into the Asset Safe, and send assets to the
 * Agent, whose address is a literal. It may also revoke the operator's
 * targets and functions, which is how every removal happens (OD-09). It
 * cannot add a permission, give a non-zero approval, enter a venue except by
 * staking ETH, or choose a recipient.
 */
export default [
  ...APPROVED_TOKENS.map((token) => call(token, "approve(address,uint256)", anyOf(SPENDERS), 0n)),

  // Exits and conversions, paid to the Asset Safe.
  call(SUSDS, "redeem(uint256,address,address)", undefined, c.avatar, c.avatar),
  call(SUSDS, "withdraw(uint256,address,address)", undefined, c.avatar, c.avatar),
  call(WSTETH, "unwrap(uint256)"),
  // WETH goes through stETH: unwrap, stake, then send or swap (OD-20).
  call(WETH, "withdraw(uint256)"),
  callWithValue(STETH, "submit(address)", ZERO),

  // Lido Earn exits. A pending deposit is cancelled; a priced one is claimed
  // so that its shares can be redeemed. Claims pay the Asset Safe.
  ...[EARN_USD, EARN_ETH].flatMap((vault) => [
    call(vault.depositQueue, "cancelDepositRequest()"),
    call(vault.depositQueue, "claim(address)", c.avatar),
    call(vault.redeemQueue, "redeem(uint256)"),
    call(vault.redeemQueue, "claim(address,uint32[])", c.avatar),
  ]),

  // Block the operator: the revoking half of the operator modifier's admin
  // surface, with the role key pinned to the operator. The Asset Safe owns
  // that modifier, and a call through a role executes as the Asset Safe.
  call(manifest.operatorModifier, "revokeTarget(bytes32,address)", key("operator")),
  call(manifest.operatorModifier, "revokeFunction(bytes32,address,bytes4)", key("operator")),

  // Return to the treasury: every transfer is pinned to the Agent.
  ...RETURNABLE.map((token) => call(token, "transfer(address,uint256)", manifest.agent)),
] satisfies Permissions;
