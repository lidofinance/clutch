// SPDX-License-Identifier: AGPL-3.0-or-later
/** The token lists of the orders account (ADR 007). */
import { DAI, manifest, STETH, SUSDS, USDC, USDS, USDT, WETH, WSTETH } from "./addresses";
import { anyOf, call, unique } from "./lib";

/** The operator's order tokens, on the sell side and the buy side (ADR 007, decision 22; LDO left by OD-91). */
export const ORDER_TOKENS = [STETH, WSTETH, WETH, USDC, USDT, USDS];

/**
 * What a recovery order sells: every asset that the Asset Safe holds, except Earn shares, which leave by their
 * redeem queues (ADR 007, decisions 2 and 15). ETH is staked first.
 */
export const RECOVERY_SELL = [STETH, WSTETH, WETH, USDC, USDT, DAI, USDS, SUSDS];

/** What a recovery order buys: USDC, with USDT second (ADR 007, decision 5). */
export const RECOVERY_BUY = [USDC, USDT];

/**
 * The tokens that CoW's vault relayer may pull from the orders account: every token that an order sells. The
 * enabling vote approves each, and the approvals role may raise each again (ADR 007, decision 41).
 */
export const RELAYER_TOKENS = unique([...ORDER_TOKENS, ...RECOVERY_SELL]);

/**
 * A transfer of `token` out of the orders account, pinned to the Asset Safe or the Aragon Agent: the operator's
 * return (ADR 014, decision 9) and the emergency role's sweep (ADR 007, decision 19) take the same two receivers.
 */
export function returnTransfer(token: string) {
  return call(token, "transfer(address,uint256)", anyOf([manifest.assetSafe, manifest.agent]));
}
