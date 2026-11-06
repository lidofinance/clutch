// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { DAI, manifest, STETH, SUSDS, USDC, USDS, USDT, WETH, WSTETH } from "../../addresses";

/** The tokens that the Asset Safe holds and that can become insurance money. */
const FUNDABLE = [STETH, WSTETH, WETH, USDC, USDT, DAI, USDS, SUSDS];

/**
 * Insurance money by motion (ADR 014, decision 7): a transfer from the Asset
 * Safe to the first-loss Safe, which Aragon Voting owns. The receiver is
 * pinned, so the role moves money only between two of the DAO's own Safes.
 */
export default FUNDABLE.map((token) =>
  call(token, "transfer(address,uint256)", manifest.firstLossSafe),
) satisfies Permissions;
