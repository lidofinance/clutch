// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the two modifiers of ADR 005 and the
// four roles. See PROVENANCE.md.
import { manifest } from "./addresses";
import { operatorRolesNode, safetyRolesNode } from "./nodes";
import { emergency, governance, operator, technical } from "./roles";
import { earn_eth_deposit_wsteth, earn_usd_deposit, sky_savings_usds } from "./allowances";

/**
 * The operator modifier: the operator role and the governance role that
 * administers it, with the operator's budgets. The Asset Safe is its owner,
 * avatar and target, so a permitted call executes as the Asset Safe.
 */
export const operator_modifier = operatorRolesNode({
  address: manifest.operatorModifier as `0x${string}`,
  owner: manifest.assetSafe as `0x${string}`,
  avatar: manifest.assetSafe as `0x${string}`,
  target: manifest.assetSafe as `0x${string}`,
  roles: { operator, governance },
  allowances: { sky_savings_usds, earn_usd_deposit, earn_eth_deposit_wsteth },
});

/**
 * The safety modifier: the emergency and technical roles. They sit on a
 * separate module, so that disabling the operator modifier does not disarm
 * recovery (ADR 005).
 */
export const safety_modifier = safetyRolesNode({
  address: manifest.safetyModifier as `0x${string}`,
  owner: manifest.assetSafe as `0x${string}`,
  avatar: manifest.assetSafe as `0x${string}`,
  target: manifest.assetSafe as `0x${string}`,
  roles: { emergency, technical },
});
