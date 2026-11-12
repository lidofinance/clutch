// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { EARN_ETH, EARN_USD, manifest } from "../../addresses";

/**
 * What the committee's Safe may do with the DAO's first-loss shares (ADR 008,
 * decision 21): request their redemption on the Earn vault's redeem queue, and
 * claim it with the receiver pinned to the Asset Safe (ADR 014, decision 10).
 * A request names no receiver: the queue takes the shares from the first-loss
 * Safe, and only the claim pays. The role holds no call of a share token, so it
 * cannot transfer, approve or burn the shares.
 */
export default [EARN_ETH, EARN_USD].flatMap((vault) => [
  call(vault.redeemQueue, "redeem(uint256)"),
  call(vault.redeemQueue, "claim(address,uint32[])", manifest.assetSafe),
]) satisfies Permissions;
