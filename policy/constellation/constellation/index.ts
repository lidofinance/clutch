// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the two modifiers of ADR 005 and the
// four roles. See PROVENANCE.md.
// Changed for Clutch on 2026-10-13: the technical role merged into the
// emergency role (ADR 005, decision 25).
import { manifest } from "./addresses";
import { operatorRolesNode, ordersRolesNode, safetyRolesNode } from "./nodes";
import { emergency, governance, insuranceFunding, operator, ordersEmergency, ordersOperator, restart } from "./roles";
import {
  earn_eth_deposit_wsteth,
  earn_usd_deposit,
  orders_steth,
  orders_usdc,
  orders_usds,
  orders_usdt,
  orders_weth,
  orders_wsteth,
  sky_savings_usds,
} from "./allowances";

/**
 * The operator modifier: the operator role, the governance role that
 * administers it, and the insurance-funding role, with the operator's budgets. The Asset Safe is its owner,
 * avatar and target, so a permitted call executes as the Asset Safe.
 */
export const operator_modifier = operatorRolesNode({
  address: manifest.operatorModifier as `0x${string}`,
  owner: manifest.assetSafe as `0x${string}`,
  avatar: manifest.assetSafe as `0x${string}`,
  target: manifest.assetSafe as `0x${string}`,
  roles: { operator, governance, "insurance-funding": insuranceFunding },
  allowances: {
    sky_savings_usds,
    earn_usd_deposit,
    earn_eth_deposit_wsteth,
    orders_steth,
    orders_wsteth,
    orders_weth,
    orders_usdc,
    orders_usdt,
    orders_usds,
  },
});

/**
 * The safety modifier: the emergency role, and the restart role that enables
 * the operator modifier again after the switch (ADR 013, decision 12). It sits on a separate module, so
 * that the emergency role's switch, which disables the operator modifier,
 * does not disarm recovery (ADR 005).
 */
export const safety_modifier = safetyRolesNode({
  address: manifest.safetyModifier as `0x${string}`,
  owner: manifest.assetSafe as `0x${string}`,
  avatar: manifest.assetSafe as `0x${string}`,
  target: manifest.assetSafe as `0x${string}`,
  roles: { emergency, restart },
});

/**
 * The orders modifier: the operator and emergency roles on the orders account (ADR 007, decision 30). The
 * orders account is its owner, avatar and target, so a permitted call executes as the orders account. Only a
 * manifest that names the modifier compiles it: the kit deploys no orders account.
 */
export const orders_modifier = manifest.ordersModifier
  ? ordersRolesNode({
      address: manifest.ordersModifier as `0x${string}`,
      owner: manifest.ordersAccount as `0x${string}`,
      avatar: manifest.ordersAccount as `0x${string}`,
      target: manifest.ordersAccount as `0x${string}`,
      roles: { operator: ordersOperator, emergency: ordersEmergency },
    })
  : undefined;
