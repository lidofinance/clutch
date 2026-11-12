// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { EARN_ETH, EARN_USD } from "../../addresses";

/**
 * The first-loss burn (ADR 008, decision 23): the holder's own burn of earnETH
 * or earnUSD shares. `burn(uint256)` burns the caller's shares, and the caller
 * is the first-loss Safe, so the role reaches no other holder's shares. It
 * holds no transfer and no approval.
 */
export default [EARN_ETH, EARN_USD].map((vault) => call(vault.share, "burn(uint256)")) satisfies Permissions;
