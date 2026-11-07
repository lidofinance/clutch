// SPDX-License-Identifier: AGPL-3.0-or-later
import { anyOf, call, key } from "../../lib";
import { COW_VAULT_RELAYER, manifest } from "../../addresses";
import { removeConditionalOrder, signOrder, unsignOrder } from "../../cow";
import { RECOVERY_BUY, RECOVERY_SELL } from "../../orders";
import { RECOVERY_LIFE_MAX } from "../../parameters";

/** The kit deploys no orders modifier; a manifest without one never compiles this role. */
const MODIFIER = manifest.ordersModifier ?? "0x0000000000000000000000000000000000000000";
const OPERATOR = key("operator");

/**
 * What the emergency Safe may do on the orders account (ADR 007, decisions 19, 25, 26 and 30): recovery orders
 * through the order signer, which buy USDC or USDT, pay the Aragon Agent and live at most 1 day; cancel any
 * order; stop the operator by revoking its targets and functions, with the role key pinned; set CoW's relayer
 * approval to zero; and send any token to the Aragon Agent or back to the Asset Safe. It cannot raise an
 * approval or grant anything, and a recovery order has no price floor on chain (decision 26).
 */
export default [
  signOrder({ sell: RECOVERY_SELL, buy: RECOVERY_BUY, receiver: manifest.agent, life: RECOVERY_LIFE_MAX }),
  unsignOrder(),
  removeConditionalOrder(),
  call(MODIFIER, "revokeTarget(bytes32,address)", OPERATOR),
  call(MODIFIER, "revokeFunction(bytes32,address,bytes4)", OPERATOR),
  ...RECOVERY_SELL.map((token) => call(token, "approve(address,uint256)", COW_VAULT_RELAYER, 0n)),
  ...RECOVERY_SELL.map((token) => call(token, "transfer(address,uint256)", anyOf([manifest.agent, manifest.assetSafe]))),
] satisfies Permissions;
