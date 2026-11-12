// SPDX-License-Identifier: AGPL-3.0-or-later
import { id } from "ethers";
import { call, derivedKey, key } from "../../lib";
import { manifest } from "../../addresses";
import { NOT_FIRST_LOSS_ADMINISTRATION } from "../../administration";

/** The kit deploys no first-loss modifier; a manifest without one never compiles this role. */
const MODIFIER = manifest.firstLossModifier ?? "0x0000000000000000000000000000000000000000";
const INSURANCE = key("insurance");
const TRANSFER = id("transfer(address,uint256)").slice(0, 10);

/** The execution options of a grant, as the modifier numbers them: a plain call. */
const CALL = 0n;

/**
 * What an enacted Easy Track motion may do, as the governance role on the first-loss modifier (ADR 014, decision
 * 6): create a fund with a fixed payout address. It writes, under the insurance role's key only, a `transfer` of
 * the fund's token, as a plain call, and it sets the fund's cap as a budget key that never refills: the refill and
 * its ceiling are pinned to zero. The key is one that the universal factory derives, for the token and the payout
 * address. The content of the transfer's tree, which pins the payout address and the key, is the universal
 * factory's shape (ADR 013).
 *
 * Every grant refuses the vault's Safes and modifiers and the two Earn share tokens as the administered target, so
 * no motion gives a role a transfer of the first-loss shares. The role holds no membership setter, no
 * `allowTarget`, no `allowFunction` and no revoke, and it never writes under its own key or under the keys of the
 * `first-loss` and `first-loss-burn` roles.
 */
export default [
  call(MODIFIER, "scopeTarget(bytes32,address)", INSURANCE, NOT_FIRST_LOSS_ADMINISTRATION),
  call(
    MODIFIER,
    "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)",
    INSURANCE,
    NOT_FIRST_LOSS_ADMINISTRATION,
    TRANSFER,
    undefined,
    CALL,
  ),
  call(MODIFIER, "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)", derivedKey, undefined, 0n, 0n),
] satisfies Permissions;
