// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { EARN_ETH, EARN_USD, USDC, WSTETH } from "../../addresses";

const ZERO = "0x0000000000000000000000000000000000000000";

/** Each Earn vault's deposit queue with the token that it takes. */
export const INSURANCE_DEPOSITS: readonly { token: string; queue: string }[] = [
  { token: USDC, queue: EARN_USD.depositQueue },
  { token: WSTETH, queue: EARN_ETH.depositQueue },
];

/**
 * The insurance deposit for Lido Earn (ADR 014, decision 12): insurance money
 * that the first-loss Safe holds goes into earnUSD or earnETH. The approval
 * pins the deposit queue as its spender, and the deposit names no referral.
 * The queue credits the depositor, which is the first-loss Safe, so the new
 * shares join the first-loss shares and follow their rules: a burn by motion,
 * and a redemption that pays the Asset Safe (ADR 008, decisions 21 and 23).
 * The role holds no transfer, and no call of a share token.
 */
export default INSURANCE_DEPOSITS.flatMap(({ token, queue }) => [
  call(token, "approve(address,uint256)", queue),
  call(queue, "deposit(uint224,address,bytes32[])", undefined, ZERO),
]) satisfies Permissions;
