// SPDX-License-Identifier: AGPL-3.0-or-later
import { c, call, derivedKeyOf } from "../../lib";
import { DAI, manifest, STETH, SUSDS, USDC, USDS, USDT, WETH, WSTETH } from "../../addresses";

/** The tokens that the Asset Safe holds and that can become insurance money. */
const FUNDABLE = [STETH, WSTETH, WETH, USDC, USDT, DAI, USDS, SUSDS];

/**
 * Insurance money by motion (ADR 014, decisions 7 and 11): a transfer from the
 * Asset Safe to the first-loss Safe, which Aragon Voting owns. The receiver is
 * pinned, so the role moves money only between two of the DAO's own Safes. The
 * amount spends the budget key that the universal factory derives for the
 * token and the first-loss Safe. A budget motion sets that key within the
 * token's budget ceiling, and until it does, no insurance money moves.
 */
export default FUNDABLE.map((token) =>
  call(
    token,
    "transfer(address,uint256)",
    manifest.firstLossSafe,
    c.withinAllowance(derivedKeyOf(token, manifest.firstLossSafe)),
  ),
) satisfies Permissions;
