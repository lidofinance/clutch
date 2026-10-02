---
type: Specification
title: Invariants
description: Draft invariants of the Clutch permission system, each tied to the ADR that sets it and mapped to a named kit test where one exists.
tags: [specs, invariants, testing]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T13:35:00Z
verified: []
sources:
  - id: s1
    resource: /adr/index.md
    title: Decision records that set each invariant
  - id: s2
    resource: "https://github.com/lidofinance/clutch/tree/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test"
    title: Kit test suites at 370e20a
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md"
    title: Kit harness README at 370e20a — known divergence from the design
---

# Invariants

The invariants below come from ADR 005 to ADR 011 [s1]. The kit's tests predate them. The mapping pairs each invariant with the kit test that checks it, by name and by a read of the test body [s2]. It is not yet a CI check.

State "Draft" means the ADR is proposed. State "Pending" means the invariant depends on an open decision or on work that is not built. "Violated" means the kit's policy currently breaks the invariant, as its README records [s3].

| ID | Invariant | Set by | State | Kit test |
|---|---|---|---|---|
| INV-001 | The Aragon Agent is the only owner of the Asset Safe, with threshold one. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | None: the harness sets this up but does not assert it |
| INV-002 | No role except the DAO path can move an asset out of the Asset Safe, with three exceptions: the emergency role to the Aragon Agent or to a recovery swap instance; and the operator to a rebalancing swap instance. A token that enters a rebalancing instance leaves it only as proceeds to the Asset Safe or as a recovery to the Aragon Agent. | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: swap instances | `test_D4_emergency_flow`, `test_D6_adversarial` cover the Agent-only part |
| INV-003 | Every receiver, owner and beneficiary argument in an operator permission is pinned to the avatar. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | `test_D3_operator_cannot_route_around_avatar` |
| INV-004 | The governance role cannot change role membership, cannot touch the emergency role, cannot give the operator an administrative target, and cannot set an allowance outside the operator's budget keys. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | the four `test_p0_policyadmin_cannot_*` tests |
| INV-005 | Easy Track enacts a motion only if the rebuilt script matches the stored hash. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_D1_substituted_script_rejected_at_enactment` (mock Easy Track) |
| INV-006 | Every emitted script uses the production format: spec id `0x00000001` and a `uint32` length per call. Any other encoding is rejected. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_D1_production_callscript_encoding_accepted`, `test_D1_nonstandard_length_encoding_rejected`, `test_D1_malformed_length_rejected` |
| INV-007 | Withdrawing a role key from the toggle factory's allowlist makes every queued motion for that key fail at enactment. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_factory_only_dao_withdrawal_kills_a_queued_motion` |
| INV-008 | An operator approval is zero or below its per-token ceiling. After the emergency role revokes the approve permission, the operator cannot restore any approval. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Pending: ceiling values, OD-08 | `test_p0_operator_cannot_set_unlimited_relayer_approval`, `test_p0_emergency_can_durably_stop_operator_reapproval` |
| INV-009 | Only the technical role can disable a module, only the operator modifier, and the safety modifier stays enabled and working afterwards. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | `test_D4_module_disabling_is_technical_only_and_pinned` |
| INV-010 | The operator Safe executes a transaction only with the screening vendor's single-use approval, or through the guard's 10-day removal path. It has no modules. No vendor code is on the path of the safety modifier, the technical role or the DAO. | [ADR 010](/adr/010-pre-execution-screening.md) | Pending: the kit tests the rejected module-guard route | None for this route; the three `test_D7_*` tests cover the rejected route |
| INV-011 | A budget is consumed only by a successful call, never beyond its balance, and it refills per elapsed period up to its maximum. Keys of different assets and decimals are independent. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Draft | `test_D5_budget_enforcement_and_refill`, `test_FX4_per_asset_budgets_ARE_expressible`, `test_regression_18_decimal_supply_draws_own_budget` |
| INV-012 | A budget change by motion stays within the per-key ceilings and cannot set a refill period below the floor. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Pending: floor value, OD-08 | `test_native_allowance_bounds_including_period_floor` |
| INV-013 | The operator holds no order pre-signing permission and no approval to the CoW relayer. It swaps only by transfer to a pinned rebalancing instance. | [ADR 007](/adr/007-swapping-through-stonks.md) | Violated: the kit grants pre-signing [s3] | None yet |
| INV-014 | The emergency role swaps only by transfer to a pinned recovery instance, whose receiver and recovery address are the Aragon Agent and whose manager is the emergency Safe. | [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: swap instances | None yet |
| INV-015 | The operator's permissions cover only the launch scope: no sDAI, no Aave and no other third-party lending market. | [ADR 011](/adr/011-launch-scope.md) | Violated: the kit grants Aave v3 and sDAI [s3] | None yet |
| INV-016 | The conditions read back from each modifier equal the policy data file. | [ADR 004](/adr/004-specifications-and-policy-as-data.md) | Pending: data file and compiler | None yet |
