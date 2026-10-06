---
type: Specification
title: Invariants
description: Draft invariants of the Clutch permission system, each tied to the ADR that sets it and mapped to a named kit test where one exists.
tags: [specs, invariants, testing]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T13:05:14Z
verified: []
sources:
  - id: s1
    resource: /adr/index.md
    title: Decision records that set each invariant
  - id: s2
    resource: "https://github.com/lidofinance/clutch/tree/7a8c6613602a0078807298b1cebb513af2d74bd5/test"
    title: Kit test suites at 7a8c661
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/README.md"
    title: Kit harness README at 7a8c661 — what the policy follows, and what the kit still lacks
---

# Invariants

The invariants below come from ADR 004 to ADR 011 [s1]. On 2026-10-05 the kit's policy and tests were brought in line with the decisions. The mapping pairs each invariant with the kit test that checks it, by name and by a read of the test body [s2]. It is not yet a CI check.

State "Draft" means the ADR is proposed. State "Pending" means the invariant depends on an open decision or on work that is not built. "Violated" would mean that the kit's policy breaks the invariant; no invariant is in that state. The harness README lists what the kit still lacks [s3].

| ID | Invariant | Set by | State | Kit test |
|---|---|---|---|---|
| INV-001 | The Aragon Agent is the only owner of the Asset Safe, with threshold one. It authorizes Asset Safe transactions only by `approveHash` or by sending them itself, never by a contract signature. The Asset Safe has no fallback handler. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | `test_asset_safe_shape` checks the owner, the threshold and the missing fallback handler. The harness executes through `approveHash`, but no test asserts that the Agent never signs with a contract signature |
| INV-002 | No role except the DAO path can move an asset out of the Asset Safe, with three exceptions: the emergency role to the Aragon Agent or to a recovery swap instance; and the operator to a rebalancing swap instance. A token that enters a rebalancing instance leaves it only as proceeds to the Asset Safe or as a recovery to the Aragon Agent. A deposit, conversion, stake or withdrawal request whose receiver, owner or beneficiary is the Asset Safe is not a move out (INV-003). | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: swap instances | `test_D4_emergency_flow` and `test_D4_emergency_weth_route_to_agent` cover the Agent-only part |
| INV-003 | Every receiver, owner and beneficiary argument in an operator permission is pinned to the avatar. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | `test_D3_operator_cannot_route_around_avatar`, `test_D3_dai_usds_conversion_pays_the_asset_safe`, `test_D3_withdrawal_queue_round_trip_buys_weth` |
| INV-004 | The governance role cannot change role membership, cannot touch the emergency role, cannot give the operator delegatecall or an administrative target, and cannot set an allowance outside the operator's budget keys. The administrative targets are the Asset Safe and every module that it enables, the safety modifier included (OD-38). It holds no `assignRoles` permission. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_policyadmin_cannot_change_role_membership`, `test_policyadmin_cannot_touch_the_emergency_role`, `test_policyadmin_cannot_grant_operator_admin_targets`, `test_policyadmin_cannot_grant_operator_the_safety_modifier`, `test_policyadmin_refuses_every_module_of_the_asset_safe`, `test_policyadmin_cannot_grant_operator_delegatecall`, `test_policyadmin_cannot_raise_a_foreign_allowance_key` |
| INV-005 | Easy Track enacts a motion only if the rebuilt script matches the stored hash. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_D1_substituted_script_rejected_at_enactment` (mock Easy Track) |
| INV-006 | Every emitted script uses the production format: spec id `0x00000001` and a `uint32` length per call. Any other encoding is rejected. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_D1_production_callscript_encoding_accepted`, `test_D1_nonstandard_length_encoding_rejected`, `test_D1_malformed_length_rejected` |
| INV-007 | Retired on 2026-10-05: the design has no role-toggle factory (OD-09). It said that withdrawing a key from the toggle factory's allowlist makes every queued motion for that key fail at enactment. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Retired | None: the toggle factory and its tests left the kit on 2026-10-05 |
| INV-008 | An operator approval to a protocol spender is zero, or it spends the budget of the key that the spender serves. The stETH approvals to the wstETH contract and to Lido's withdrawal queue, and the DAI and USDS approvals to Sky's DAI–USDS converter, are zero or below one TM Floor Value in that token. After the emergency role revokes the approve permission, the operator cannot restore any approval. | [ADR 007](/adr/007-swapping-through-stonks.md), [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), [ADR 011](/adr/011-launch-scope.md) | Draft | `test_operator_approval_is_bounded_by_key_or_ceiling`, `test_D5_budget_enforcement_and_refill`, `test_D3_dai_usds_conversion_pays_the_asset_safe`, `test_D3_withdrawal_queue_round_trip_buys_weth`, with dry-run stand-ins for the ceilings; `test_emergency_can_durably_stop_operator_reapproval` covers the last sentence |
| INV-009 | Only the technical role can disable a module, only the operator modifier, and the safety modifier stays enabled and working afterwards. | [ADR 005](/adr/005-account-graph-and-roles.md) | Draft | `test_D4_module_disabling_is_technical_only_and_pinned` |
| INV-010 | The operator Safe executes a transaction only with the screening vendor's single-use approval, or through the guard's 10-day removal path. Its guard's bypass mode is off, and the guard holds no standing approval except its two built-in timelock approvals. It has no modules. No vendor code is on the path of the safety modifier, the technical role or the DAO. | [ADR 010](/adr/010-pre-execution-screening.md) | Pending: the harness has no operator Safe and no guard | None |
| INV-011 | A budget is consumed only by a successful call, never beyond its balance, and it refills per elapsed period up to its maximum. Keys of different assets and decimals are independent. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Draft | `test_D5_budget_enforcement_and_refill`, `test_budget_keys_of_different_assets_are_independent` |
| INV-012 | A budget change by motion stays within the ceilings of its key and cannot set a refill period below 30 days. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Pending: the per-key ceilings need the attested figures | `test_policyadmin_cannot_set_a_refill_period_below_30_days` and `test_D1_budget_motion_cannot_shorten_the_refill_period` cover the floor; `test_budget_motion_bounds_are_expressible_per_key` shows per-key ceilings |
| INV-013 | The operator holds no order pre-signing permission and no approval to the CoW relayer. It swaps only by transfer to a pinned rebalancing instance. | [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: swap instances | `test_D6_out_of_scope_venues_are_refused` and `test_policy_names_no_out_of_scope_venue` cover the first sentence |
| INV-014 | The emergency role swaps only by transfer to a pinned recovery instance, whose receiver and recovery address are the Aragon Agent and whose manager is the emergency Safe. | [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: swap instances | None yet |
| INV-015 | The operator's permissions cover only the launch scope: no sDAI, no Aave and no other third-party lending market. | [ADR 011](/adr/011-launch-scope.md) | Draft | `test_D6_out_of_scope_venues_are_refused`, `test_policy_names_no_out_of_scope_venue` |
| INV-016 | The trees rebuilt from each modifier's events on a fork equal the committed artifact, and the committed artifact equals a fresh compile of the constellation. | [ADR 004](/adr/004-specifications-and-policy-as-data.md) | Pending: the round-trip check | None yet |
| INV-017 | A top-up motion pays only the Asset Safe, only in an allowed token, and never more than its funding registry's remaining limit in the month of enactment. Only the operator Safe can create one. Only the DAO changes a funding registry's limit, period or recipients. | [ADR 008](/adr/008-funding-through-existing-payments.md) | Pending: registries and factories not built | None yet |
| INV-018 | Every operator permission lives under the `operator` role key, and the operator Safe holds no other role key. The emergency role's revoke therefore reaches every operator permission. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Draft | `test_D6_operator_holds_only_the_operator_key`, `test_operator_holds_only_the_operator_key` |
| INV-019 | The Asset Safe, the operator Safe and the emergency Safe run the Safe v1.5.0 singleton pinned in the LIP. A change of any of their singletons is a critical alert. | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 010](/adr/010-pre-execution-screening.md) | Pending: the Safes are not deployed | `test_asset_safe_shape` checks the harness Asset Safe's singleton; the operator and emergency Safes are stand-ins |
| INV-020 | The vault's converter allows exactly the tokens of the vault's swap instances. Every one of them is configured on the Stonks price router and in sync when the enabling vote starts. | [ADR 007](/adr/007-swapping-through-stonks.md) | Pending: the converter and the feeds are not set | None yet |
