// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The accounts that no grant may administer (OD-38). Pinning only the role key leaves an indirect escalation: a
 * motion grants the operator a permission whose target is the Asset Safe or one of its modules, and the operator
 * then reaches owner-only administration through the avatar. A fork probe did this with the safety modifier
 * (OD-38). So every grant of a governance role refuses, as the administered target, the Asset Safe, every module
 * that the manifest lists, the orders account and its modifier (ADR 007), with Nor, and the compiler checks the
 * guard. This deny-list is necessary and not sufficient: the universal factory's shapes carry the positive rules
 * (ADR 013).
 */
import { noneOf } from "./lib";
import { EARN_ETH, EARN_USD, manifest } from "./addresses";

if (!Array.isArray(manifest.modules) || manifest.modules.length === 0) {
  throw new Error("the manifest must list every module of the Asset Safe in `modules` (OD-38)");
}

export const NOT_ADMINISTRATION = noneOf(
  manifest.assetSafe,
  ...manifest.modules,
  manifest.ordersAccount,
  ...(manifest.ordersModifier ? [manifest.ordersModifier] : []),
);

/**
 * The accounts that no grant on the first-loss modifier may administer (ADR 014, decision 6): the vault's Safes and
 * modifiers, the first-loss Safe and its modifier included, and the two Earn share tokens, so that no motion gives
 * a role a transfer of the first-loss shares (ADR 008, decision 21).
 */
export const NOT_FIRST_LOSS_ADMINISTRATION = noneOf(
  manifest.assetSafe,
  ...manifest.modules,
  manifest.ordersAccount,
  ...(manifest.ordersModifier ? [manifest.ordersModifier] : []),
  manifest.firstLossSafe,
  ...(manifest.firstLossModifier ? [manifest.firstLossModifier] : []),
  EARN_ETH.share,
  EARN_USD.share,
);
