// SPDX-License-Identifier: AGPL-3.0-or-later
/** The token lists of the orders account (ADR 007). */
import { DAI, manifest, STETH, SUSDS, USDC, USDS, USDT, WETH, WSTETH } from "./addresses";
import { anyOf, call, unique } from "./lib";

/** The operator's order tokens, on the sell side and the buy side (ADR 007, decision 22; LDO left by OD-91). */
export const ORDER_TOKENS = [STETH, WSTETH, WETH, USDC, USDT, USDS];

/**
 * The tokens that left the operator's lists. The operator signs no order in a retired token and sends none to the
 * orders account. It still returns the token from the orders account, and from the Asset Safe to the Aragon Agent,
 * and CoW's vault relayer keeps its approval, because an order that was signed before can still fill. A motion can
 * so take a token out of the lists: it writes the order trees again without the token, and no revoke on the orders
 * modifier, whose motion roles hold none (ADR 013, decision 4). Empty at launch.
 */
export const RETIRED_ORDER_TOKENS: string[] = [];

/**
 * What a recovery order sells: every asset that the Asset Safe holds, except Earn shares, which leave by their
 * redeem queues (ADR 007, decisions 2 and 15). ETH is staked first.
 */
export const RECOVERY_SELL = [STETH, WSTETH, WETH, USDC, USDT, DAI, USDS, SUSDS];

/** What a recovery order buys: USDC, with USDT second (ADR 007, decision 5). */
export const RECOVERY_BUY = [USDC, USDT];

/**
 * The tokens that CoW's vault relayer may pull from the orders account: every token that an order sells or sold. The
 * enabling vote approves each, and the approvals role may raise each again (ADR 007, decision 41).
 */
export const RELAYER_TOKENS = unique([...ORDER_TOKENS, ...RETIRED_ORDER_TOKENS, ...RECOVERY_SELL]);

/**
 * A transfer of `token` out of the orders account, pinned to the Asset Safe or the Aragon Agent: the operator's
 * return (ADR 014, decision 9) and the emergency role's sweep (ADR 007, decision 19) take the same two receivers.
 */
export function returnTransfer(token: string) {
  return call(token, "transfer(address,uint256)", anyOf([manifest.assetSafe, manifest.agent]));
}
