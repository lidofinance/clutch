// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";
import { removeConditionalOrder, signOrder, twapOrder, unsignOrder } from "../../cow";
import { ORDER_TOKENS, returnTransfer } from "../../orders";
import { ORDER_LIFE_MAX } from "../../parameters";

/**
 * What the committee's Safe, as the operator, may do on the orders account (ADR 007, decisions 18, 29 and 39):
 * market and limit orders through the order signer and TWAP orders through ComposableCoW, each paying the
 * Asset Safe and living at most 90 days; their cancels; and transfers of an order token back to the Asset
 * Safe or to the Aragon Agent (ADR 014, decision 9). No stop-loss handler, no router and no other venue.
 */
export default [
  signOrder({ sell: ORDER_TOKENS, buy: ORDER_TOKENS, receiver: manifest.assetSafe, life: ORDER_LIFE_MAX }),
  unsignOrder(),
  twapOrder({ sell: ORDER_TOKENS, buy: ORDER_TOKENS, receiver: manifest.assetSafe }),
  removeConditionalOrder(),
  ...ORDER_TOKENS.map(returnTransfer),
] satisfies Permissions;
