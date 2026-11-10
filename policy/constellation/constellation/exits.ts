// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The emergency role's exits on the Asset Safe, one builder for each kind (ADR 006, decision 13; OD-49). The
 * emergency role's own permissions use them for the launch venues, and the exit-governance role pins each tree
 * whole, so a motion writes an exit for a new target only in one of these forms. No exit enters a position, pays
 * anyone but the Asset Safe, the Aragon Agent or the orders account, or gives a non-zero approval.
 */
import { anyOf, c, call } from "./lib";
import { manifest } from "./addresses";

/** A transfer to the Aragon Agent. */
export function toAgent(token: string) {
  return call(token, "transfer(address,uint256)", manifest.agent);
}

/**
 * A transfer to the Aragon Agent or to the orders account, for a token that a recovery order sells: its recovery
 * order pays the Agent (ADR 007, decisions 19 and 45).
 */
export function toAgentOrOrders(token: string) {
  return call(token, "transfer(address,uint256)", anyOf([manifest.agent, manifest.ordersAccount]));
}

/** An approval set to zero, for any spender: it can only take authority away. */
export function zeroApproval(token: string) {
  return call(token, "approve(address,uint256)", undefined, 0n);
}

/** An ERC-4626 redeem from the Asset Safe's own shares, paid to the Asset Safe. */
export function vaultRedeem(vault: string) {
  return call(vault, "redeem(uint256,address,address)", undefined, c.avatar, c.avatar);
}

/** An ERC-4626 withdrawal from the Asset Safe's own shares, paid to the Asset Safe. */
export function vaultWithdraw(vault: string) {
  return call(vault, "withdraw(uint256,address,address)", undefined, c.avatar, c.avatar);
}

/** A queue's claim of a priced deposit, paid to the Asset Safe. */
export function queueClaim(queue: string) {
  return call(queue, "claim(address)", c.avatar);
}

/** A redeem queue's claim of priced requests, paid to the Asset Safe. */
export function queueClaimRequests(queue: string) {
  return call(queue, "claim(address,uint32[])", c.avatar);
}

/**
 * The exits that take no condition, because each acts only for the calling Safe: cancel a pending deposit, ask a
 * redeem queue to redeem, unwrap a wrapper such as wstETH, and unwrap WETH.
 */
export const PLAIN_EXITS = ["cancelDepositRequest()", "redeem(uint256)", "unwrap(uint256)", "withdraw(uint256)"] as const;
