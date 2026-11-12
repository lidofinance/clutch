// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the four roles of ADR 005. See PROVENANCE.md.
// Changed for Clutch on 2026-10-13: the technical role merged into the
// emergency role (ADR 005, decision 25).
export * as operator from "./operator";
export * as governance from "./governance";
export * as emergency from "./emergency";
// Added for Clutch on 2026-11-05: the Easy Track executor's restart and
// insurance-funding roles (ADR 013, decision 12; ADR 014, decision 7).
export * as restart from "./restart";
export * as insuranceFunding from "./insurance-funding";
// Added for Clutch on 2026-11-07: the roles of the orders account (ADR 007, decision 30).
export * as ordersOperator from "./orders-operator";
export * as ordersEmergency from "./orders-emergency";
// Added for Clutch on 2026-11-08: the Easy Track executor's roles on the orders account (ADR 007, decision 41).
export * as ordersGovernance from "./orders-governance";
export * as ordersApprovals from "./orders-approvals";
// Added for Clutch on 2026-11-08: the Easy Track executor's exit-governance role (ADR 006, decision 13; OD-49).
export * as exitGovernance from "./exit-governance";
// Changed for Clutch on 2026-11-08: the universal factory holds every motion role (ADR 013, decision 18).
// Added for Clutch on 2026-11-11: the roles of the first-loss Safe (ADR 008, decisions 21 and 23).
export * as firstLoss from "./first-loss";
export * as firstLossBurn from "./first-loss-burn";
// Added for Clutch on 2026-11-12: the insurance role of the first-loss Safe (ADR 014, decision 12).
export * as insurance from "./insurance";
