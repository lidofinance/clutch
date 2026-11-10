// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: two Roles modifiers, bound by address,
// and no Safe node. See PROVENANCE.md.
// Changed for Clutch on 2026-11-07: the orders modifier (ADR 007, decision 30).
/**
 * The two modifiers of ADR 005. Clutch's own script deploys the Safes and the
 * modifiers, because the Safe node cannot set the Safe version, a guard or
 * the fallback handler (ADR 004). So the constellation binds each modifier
 * by address and declares no Safe. `index.ts` is the only place that fills
 * them in.
 */
const eth = constellation({
  workspace: "Default workspace",
  label: "Clutch",
  chain: 1, // ethereum
});

export const operatorRolesNode = eth.roles["Clutch operator modifier"];
export const safetyRolesNode = eth.roles["Clutch safety modifier"];
export const ordersRolesNode = eth.roles["Clutch orders modifier"];
