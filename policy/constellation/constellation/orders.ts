// SPDX-License-Identifier: AGPL-3.0-or-later
/** The token lists of the orders account (ADR 007). */
import { DAI, STETH, SUSDS, USDC, USDS, USDT, WETH, WSTETH } from "./addresses";

/** The operator's order tokens, on the sell side and the buy side (ADR 007, decision 22; LDO left by OD-91). */
export const ORDER_TOKENS = [STETH, WSTETH, WETH, USDC, USDT, USDS];

/**
 * What a recovery order sells: every asset that the Asset Safe holds, except Earn shares, which leave by their
 * redeem queues (ADR 007, decisions 2 and 15). ETH is staked first.
 */
export const RECOVERY_SELL = [STETH, WSTETH, WETH, USDC, USDT, DAI, USDS, SUSDS];

/** What a recovery order buys: USDC, with USDT second (ADR 007, decision 5). */
export const RECOVERY_BUY = [USDC, USDT];
