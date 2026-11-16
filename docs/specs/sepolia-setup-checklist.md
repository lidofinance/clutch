---
type: Guide
title: Sepolia setup coverage checklist
description: Inventory the setup, integration paths, boundaries, failure states and recovery cases that the stand must exercise.
tags: [sepolia, testing, coverage, integrations]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-16T17:54:56Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: Account ownership, emergency powers and restart
  - id: s2
    resource: /adr/006-governance-through-easy-track-factories.md
    title: Governance boundaries, CallsScript and factory scope
  - id: s3
    resource: /adr/007-swapping-through-an-orders-account.md
    title: Orders, signatures, TWAP, approvals and recovery
  - id: s4
    resource: /adr/008-funding-through-existing-payments.md
    title: Treasury funding and First-loss flows
  - id: s5
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: Allowances, caps, monitoring and operational controls
  - id: s6
    resource: /adr/010-pre-execution-screening.md
    title: Committee guard, bypass, outage and signing flow
  - id: s7
    resource: /adr/011-launch-scope.md
    title: Current launch integrations and exclusions
  - id: s8
    resource: /adr/015-tests-on-sepolia.md
    title: Account keys and Sepolia execution boundaries
  - id: s9
    resource: /specs/sepolia-stand.md
    title: Sepolia stand — accounts, 14 roles, recipes and test cases
  - id: s10
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: Current Sepolia tests, fixture, compiler profile, receipt guards and runner
  - id: s11
    resource: /research/cow-orders-account-2026-10-06.md
    title: Verified signer source observations — expiry comparison and proportional fee ceiling
  - id: s12
    resource: /research/sepolia-test-results.md
    title: Recorded Sepolia runs, public transactions and findings
---

# Sepolia setup coverage checklist

## How to use the checklist

This page is the coverage inventory for the [Sepolia stand](sepolia-stand.md) [s9].
Each row states an obligation.
A row does not claim that the integration passed.
Derive the paths from the specifications, then compare the deployed grants with that inventory.
Each unexpected grant needs a refusal case or a design decision.
Do not infer an intended permission from the compiler output alone [s1][s2][s3][s4][s8].

Use these evidence states [s9][s10]:

- **F**: The case passed on a pinned fork. The evidence must name the test and its assertions.
- **L**: The case passed on public Sepolia. The evidence must identify the live reads, API responses or transaction receipts, and their scope.
- **P**: A named subset of the variants passed. The other variants are open, so the row is not complete.
- **O**: No execution evidence for this obligation is recorded.
- **D**: This stand does not have the dependency. Verify it on the owning deployment or on a mainnet fork.
- **X**: The item is excluded from launch. Do not implement a positive path. Test the refusal where it applies.

The [results](../research/sepolia-test-results.md) hold the runs, transactions and findings behind each state.
The latest run passed 101 of 101 tests in 16 suites at block `12148541` [s12].

For each row, expand the applicable variants below into separate recorded checks.
Do not mark a parent row as complete until its required variants pass [s1][s3][s5][s9]:

| Axis | Required variants |
|---|---|
| Caller | Committee Safe, Emergency Safe, universal factory, Voting owner path, owner EOA directly, unrelated EOA |
| Role and account | Correct key; old key; another account's key; missing role; wrong modifier; wrong avatar |
| Input | Valid; zero; minimum; exact limit; one raw unit outside the limit; malformed data; wrong token, spender, handler or receiver |
| State | Before use; after partial use; exhausted; expired; revoked; module disabled; approval zeroed; restored |
| Execution | CALL; required delegatecall; forbidden delegatecall; nonzero ETH; single call; batch with one failing call |
| Evidence | Correct error origin; receipt and Safe outcome; exact token and allowance deltas; no unintended state changes; retry and replay |

These variants define finite input classes and state transitions.
They do not cover all possible calldata byte sequences.
Use parameterized tests for the authorization matrix across accounts and for the amount and time boundaries.
Use sequence tests for the interactions between cancellation, revocation, approvals and restart [s1][s3][s5][s9].

## A. Deployment, identities and authority

Basis: account graph, launch configuration and account-specific role keys [s1][s6][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| CFG-01 | Chain ID, pinned block and hash, manifest network and unique addresses agree. A wrong network or missing code stops the run | L: manifest inventory [s12] |
| CFG-02 | The singleton and runtime hashes of each Safe, modifier and protocol dependency match the approved manifest | P: runtimes match; the baselines are not approved [s12] |
| CFG-03 | The owner sets and thresholds of all five Safes match exactly. An extra owner must fail the check | F: `test_CFG_exact_owners_thresholds_modules_guards_handlers_and_runtimes` |
| CFG-04 | The module set of each Safe matches exactly, with no unexpected Committee or Emergency module | F: same test |
| CFG-05 | Asset and First-loss have the intended guard and fallback state. Orders has the pinned fallback handler and domain verifier | F: same test |
| CFG-06 | Each Roles modifier has the correct owner, avatar and target, and only the intended member and role mappings | L: the 14 roles match the artifact with 0 differences at block 12148541 [s12] |
| CFG-07 | The four new keys execute. The four old keys (`operator` and `emergency` on two modifiers each), the keys of another account and a direct controller call fail | F: `test_role_keys_reject_old_wrong_account_and_non_member` |
| CFG-08 | No unexpected default role, unwrap adapter, target, selector or execution option exists. Reconstruction from events agrees with the getters and the declaration | L: policy event reconstruction [s12] |
| CFG-09 | A direct controller-to-role call fails, and a controller-to-Committee-to-role call succeeds. The checks keep the two cases separate | L: corrected public sell [s12] |
| CFG-10 | Only test Voting owns the vault Safes. Test Agent is the recovery receiver, not another owner | F: owner sets and recovery receiver |
| CFG-11 | A failed owner signature, too few signatures, a stale nonce, a replay, a wrong Safe and a wrong chain each fail without unintended execution | F: `test_CFG_approved_hash_nonce_replay_wrong_safe_chain_and_signatures` |
| CFG-12 | The exact initial relayer approvals exist only on Orders, for the configured tokens. The inventory lists all other approvals | F: `test_CFG_exact_initial_token_approvals_and_fixture_wiring`: Orders holds the maximum WETH approval and a positive USDC approval; the other four Safes hold none [s12] |

## B. Funding, transfers and allowances

Basis: pinned receiver, per-token budgets and accounting of successful calls [s3][s5][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| FUND-01 | A first transfer of 0.01 WETH through the actual Committee payload debits Asset, credits Orders, consumes the `orders_weth` budget and increments the Committee nonce | F: `test_FUND_first_transfer_logs_nonces_and_unchanged_configuration` |
| FUND-02 | WETH funding and USDC funding each reach the exact budget limit. One more raw unit fails in the allowance condition | F: WETH and USDC budget cases |
| FUND-03 | A wrong receiver fails while the token balance is sufficient and the budget is unspent. Test zero, controller, Agent and another Safe separately | F: `test_FUND_receiver_checks_have_unspent_budget_and_exact_error` |
| FUND-04 | An unknown token, a wrong selector, a wrong operation and nonzero ETH each fail at their own permission check | F: `test_FUND_wrong_token_selector_operation_value_and_malformed_data` |
| FUND-05 | Several partial transfers consume their sum. A transfer of the remaining budget succeeds, and the next raw unit fails | F: `test_FUND_*` |
| FUND-06 | The WETH and USDC allowance keys are independent. Raw units follow 18 and 6 decimals. Use or refill of one allowance key changes no other allowance key | F: `test_FUND_*` |
| FUND-07 | Test a refill one second before the period ends, at the exact period and one second after it, over several periods, at the maximum clamp, and for spent and untouched budgets | F: `test_FUND_*` |
| FUND-08 | Insufficient token balance or a reverted token call rolls back the allowance consumption and the token changes | F: `test_FUND_*` |
| FUND-09 | Zero transfers and empty batches have an explicit expected result. Repeated, duplicate and reordered batches cannot hide consumption | F: `test_FUND_*` |
| FUND-10 | When a later call in a batch fails, the batch has the intended atomicity. Test the revert-on-failure and non-reverting module modes, and inspect the outer Safe outcome | F: `test_FUND_*` |
| FUND-11 | Under operator authority, Orders returns WETH and USDC only to Asset. Any other receiver or token fails. A return does not refund the spent funding budget | F: `test_FUND_*` |
| FUND-12 | Public funding wraps and transfers once. An interrupted run resumes its recorded transactions without double funding | L: funding interruption and resume [s12] |

## C. Typed CoW orders and signer

Basis: operator and recovery signer restrictions, order lifetime and cancellation [s3][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| ORD-01 | Cover WETH→USDC and USDC→WETH, sell and buy kinds, fill-or-kill and partial fills, and the exact receiver and signed order owner. Classify same-token orders against the intended specification | F: `test_ORD_*` |
| ORD-02 | A fresh quote uses Orders as owner and the intended receiver. The request, the returned order and the submitted typed fields agree | L: corrected public sells [s12] |
| ORD-03 | The signer runs as the required delegatecall from Orders. A CALL, a wrong signer target and execution from Asset fail | F: `test_ORD_*` |
| ORD-04 | Test the operator duration at zero, the minimum, the 90-day limit and one second over. The signer requires validTo strictly before timestamp + validDuration: test just below, equal and just above. Test signer acceptance of an expired order separately from settlement refusal | F: `test_order_boundaries_*`, `test_ORD_*` |
| ORD-05 | Unknown sell or buy tokens, a wrong receiver, zero amounts, an unsupported kind, nonzero appData and wrong balance modes each fail for the expected reason | F: `test_ORD_*` |
| ORD-06 | Test the fee parameter at zero, at the limit and one unit over. Test the order fee below, at and above its proportional ceiling, with raw-unit rounding and arithmetic limits. A lower fee is valid and is not a field mismatch | F: `test_ORD_*` |
| ORD-07 | The presign UID binds chain, settlement domain, owner, tokens, amounts, expiry and receiver. A change to any signed field invalidates it | F: `test_ORD_chain_domain_and_every_typed_field_bind_presign` |
| ORD-08 | The operator cancels its allowed orders. Emergency cancels operator and recovery orders. A repeated cancellation has a defined result | F: `test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders` |
| ORD-09 | A cancellation of the wrong order cannot cancel a different UID. A cancellation after a partial fill blocks the remainder. The re-sign behavior for the same UID is explicit | F: `test_ORD_*` |
| ORD-10 | Signed orders stay executable after permission revocation until cancellation, expiry or an approval block. Prove each case with an attempted settlement | F: `test_ORD_*` |
| ORD-11 | Submit market orders and resting limit orders through the public API. Observe status, rejection, expiry, partial fill, cancellation and settlement UID | L: public orders [s12] |

ORD-04 and ORD-06 must use the exact expiry comparison and fee calculation of the pinned signer.
The fee parameter is a ceiling relative to the sell amount.
It does not require two fee fields to be equal.
Derive the raw-unit limit independently from that source before you implement the new tests [s11].

## D. ComposableCoW, fallback handler and TWAP

Basis: TWAP only at launch, timestamp context and bounded schedule [s3].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| TWAP-01 | The correct handler, timestamp factory, empty context data, dispatch and start at creation produce a valid order | F: `test_twap_*` |
| TWAP-02 | Another handler, factory, start time, unexpected data, dispatch flag or malformed staticInput fails. Stop-loss stays forbidden | F: `test_TWAP_alternative_creation_roots_and_guard_setters_are_denied`, `test_TWAP_stop_loss_payload_cannot_use_pinned_or_foreign_handler` |
| TWAP-03 | Test the daily schedule at minimum parts, 90 parts at one day, one more part and one more second. Calculate the final end time independently | F: `test_TWAP_*` |
| TWAP-04 | Test the weekly schedule at 12 parts at seven days and just over these limits. Combinations outside both allowed branches fail | F: `test_TWAP_*` |
| TWAP-05 | Test before the first part, at the exact interval, just before and just after the interval, with skipped intervals and after the final part. No future part or replay can settle | F: `test_TWAP_before_start_and_complete_daily_weekly_uid_schedule` |
| TWAP-06 | Each part has the expected amount, receiver, expiry and UID. Two parts settle through the actual Safe fallback handler and domain verifier | F: same test |
| TWAP-07 | A changed order hash, owner, domain, staticInput or proof, and a stale cached signature, fail with the intended verifier error | F: `test_TWAP_changed_merkle_proof_fails_generation_signature_and_settlement` |
| TWAP-08 | Removal by the operator and removal by Emergency each disable generation and settlement with a cached signature. An unrelated order stays valid | F: `test_TWAP_both_removal_roles_reject_cached_settlement_and_preserve_other_order` |
| TWAP-09 | Duplicate salt and params, removal then re-creation, and several simultaneous TWAPs have explicit identity and cancellation behavior | F: `test_TWAP_duplicate_create_preserves_identity_and_refreshes_context` |
| TWAP-10 | Insufficient balance or zero relayer approval blocks settlement without consuming a part. Recovery and retry cause no double fill | F: `test_TWAP_*` |
| TWAP-11 | The public watcher and order submission discover and submit each part. Save the two actual settlement receipts and the cancellation state | L: public TWAP and its cancellation [s12] |

## E. Settlement and relayer approvals

Basis: real settlement outcomes and approval restoration through owner authority [s3][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| SETTLE-01 | An authorized solver settles an exact presigned order. Asset receives the buy token, and filledAmount updates | F: `test_market_and_limit_*` |
| SETTLE-02 | A price below the signed limit fails with no fill and no sell-token debit. The exact limit price succeeds | F: `test_market_and_limit_*` |
| SETTLE-03 | An unknown solver, an unsigned, cancelled or expired order, an overfill and a replay each fail at the expected layer | F: `test_SETTLE_overfill_before_and_after_partial_fill_is_atomic` |
| SETTLE-04 | Sell and buy orders, partial and full, account for the executed amount, fee, rounding, remaining amount and receiver balance | P: `test_SETTLE_nonzero_remainders_partial_fees_and_cumulative_rounding`; seven public fills reconciled; some fee cases open [s12] |
| SETTLE-05 | Missing balance and missing approval each fail without a change to filledAmount or balances. Restored prerequisites permit one fill | F: `test_SETTLE_*` |
| SETTLE-06 | The approvals of both tokens can be set to zero only for the configured relayer. A positive amount, another spender and an operator approval fail | F: `test_SETTLE_approval_spender_amount_matrix_and_zero_allowance_transfer` |
| SETTLE-07 | Voting restores the exact approval. Emergency and Committee cannot. Recovery transfers still work while the approval is zero | F: same test |
| SETTLE-08 | The public settlement receipt matches the submitted UID, execution amounts, fee, receiver and final API status | L: public fills [s12] |

## F. First-loss shares and queues

Run each applicable case separately for the test USD shares and the test ETH shares.
These cases check permissions and lifecycle on synthetic queues.
They do not test Earn economics [s4][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| FL-01 | Each share references the correct queue. The queue, share, claim asset and controller relationships match the manifest, with no substitution across assets | F: `test_FL_*` |
| FL-02 | Committee redeems each share, and the queue receives the requested shares. A claim after fixture settlement credits Agent with the requested amount | F: `test_first_loss_*`; L: public USD and ETH redemption [s12] |
| FL-03 | A wrong receiver fails before the claim. A direct share transfer, approve or burn by Committee fails. Emergency has no share path | F: `test_FL_*` |
| FL-04 | Test a zero request, an amount equal to the balance and an excess amount. Several requests at one timestamp and at different timestamps have defined accounting | F: `test_FL_*` |
| FL-05 | A claim before settlement, duplicate, empty or out-of-order timestamps, a double claim and partial timestamp sets cannot overpay. The checks do not require a zero return to revert | F: `test_FL_*` |
| FL-06 | Only the fixture controller settles. A second settle, a settle by a wrong account and a settle at a wrong timestamp fail. Each share changes no other queue | F: `test_FL_*` |
| FL-07 | A pending redeem and claim survive an Asset stop, Voting cancellation of a separate burn motion, a restart and a later claim. First-loss state stays independent | F: `test_FL_pending_redeem_survives_cancelled_burn_and_restart` |
| FL-08 | A failed claim or burn leaves shares, supply, queue requests and claimable amounts unchanged | F: `test_FL_failed_burn_and_claim_preserve_all_queue_and_share_state` |

## G. Burn motions and Easy Track

The universal factory creates all motions.
The Easy Track executor holds no role and is not a module of any modifier.
The burn factory is retired.
The rows below record the evidence for the burn factory.
`SepoliaMotionCoverageTest` creates one motion for each motion role [s9].

Basis: trusted caller, objection window and script hash [s2][s4].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| ET-01 | The factory is allowlisted and pinned to Committee, the First-loss modifier and both shares. Only Committee creates a burn motion | F: `test_ET_*`, `test_MOT_only_the_committee_creates_and_voting_cancels` |
| ET-02 | A wrong share, zero amount, malformed data, unregistered factory or excessive burn fails at the correct stage: factory or enactment | F: `test_ET_*` |
| ET-03 | Each share burns after the configured window. Early enactment fails. Supply and the First-loss balance decrease by the exact amount | F: `test_burn_motion_*`, `test_MOT_burn_motion_burns_first_loss_shares`; L: public burn motions [s12] |
| ET-04 | Test just before, exactly at and after the enactment time. The unchanged payload succeeds, and a substituted payload or script fails | F: `test_ET_*` |
| ET-05 | Test objections below, exactly at and above the threshold, an account with no weight, several objectors, a repeated objector and snapshot-weight behavior | P: the mock reads current balances [s12] |
| ET-06 | Creator cancellation and Voting cancellation succeed. Unauthorized cancellation, repeated cancellation and enactment after cancellation fail | F: `test_ET_*`; L: public cancelled motions [s12] |
| ET-07 | Re-enactment, concurrent motions for the same shares and a failed burn cannot silently duplicate a motion. Create a motion, remove its factory, test enactment, and record whether the removal stops pending actions | F: `test_ET_*`; an open motion still enacts after removal |
| ET-08 | The executor accepts calls only from Easy Track. A valid CallsScript executes. A malformed spec or length, a failing chunk and a mixed batch have explicit atomicity | F: `test_ET_*` |
| ET-09 | Caller, factory input and script are bound at creation and enactment. Committee cannot call first-loss-burn directly | F: `test_ET_*` |
| ET-10 | Voting cancels a pending burn before restart. The burn cannot be enacted after restart | L: public motion 6 [s12] |

The objection mock of the stand reads current token balances.
It does not limit each objector to one objection.
Its snapshot date does not prove historical voting weight.
For these reasons, ET-05 cannot close the matching production Easy Track requirement [s4][s10].
The mock checks the factory allowlist at creation, not again at enactment.
ET-07 must keep this behavior separate from the intended production revocation procedure [s2][s10].

## H. Asset governance and owner authority

Basis: the 14-role graph, `orders-governance` on the orders modifier, scoped grants and period floor [s1][s2][s5][s8][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| GOV-01 | The executor can scope and revoke targets, and allow, scope and revoke functions, only for asset-operator. A round trip preserves unrelated functions and conditions | F: `test_governance_executor_restricts_keys_membership_and_administrative_targets` |
| GOV-02 | Each admin selector rejects old, emergency, First-loss and Orders keys on each protected Safe and module target | F: `test_GOV_all_admin_selectors_reject_wrong_keys_and_every_protected_target` |
| GOV-03 | The None and Send options follow the specification. DelegateCall and Both fail for each grant selector. An existing delegatecall grant cannot be widened | F: `test_GOV_existing_delegatecall_can_only_be_downgraded` |
| GOV-04 | Governance cannot change membership, the default role, owner, avatar, target, adapters, Safe modules, guard, fallback handler or singleton | F: `test_GOV_fallback_and_singleton_routes_fail_at_policy_boundary` |
| GOV-05 | Both known allowance keys permit the intended period and balance changes. Foreign keys, a period below the floor and wrong timestamp behavior fail or have a specified result | F: `test_GOV_allowance_timestamp_classes_and_overflow_recovery` |
| GOV-06 | Only the universal factory holds `orders-governance` and `approvals` on Orders. The executor holds no role and cannot get owner authority through another call route | F: `test_MOT_executor_holds_no_motion_role`, `test_MOT_orders_governance_motion_restores_a_revoked_cancel`, `test_MOT_approvals_motion_sets_the_relayer_approval`, `test_GOV_executor_cannot_use_direct_owner_or_module_routes` |
| GOV-07 | Governance operates only while its Asset modifier is enabled. After the modifier is disabled, only Voting performs the reviewed owner restoration | F: `test_GOV_*` |
| GOV-08 | The full path, governance motion → factory → executor, validates the script and enactment. Impersonation of the executor alone is not sufficient | D: this stand has no suitable governance factory |
| GOV-09 | The direct Voting owner path succeeds. A non-owner cannot drive Voting. A failed owner batch is atomic. Owner restoration must not restore a permission that was revoked later | P: `test_GOV_stale_owner_restore_rearms_later_revocation_selective_restart_preserves_it`; no check before signature [s12] |
| GOV-10 | Create a policy-expansion motion, stop the Asset modifier before enactment, then restart. The check must flag an uncancelled pending motion as a reactivation hazard. Cancel the motion before execution is restored | D: the production lifecycle needs the missing governance factory; burn cancellation does not substitute for it |

## I. Emergency, cancellation and restart sequences

Basis: stop-only emergency authority and DAO restart [s1][s3][s4][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| EM-01 | The Asset switch disables only the intended operator modifier. The safety modifier still executes. A wrong prev or module argument cannot disable another control | F: `test_emergency_stops_*`, `test_EM_*` |
| EM-02 | revokeTarget and revokeFunction on Asset and on Orders each stop the selected operator permission. Unrelated permissions stay usable | F: `test_EM_*` |
| EM-03 | Emergency cannot grant, enable, change members, increase approvals or create a budget. Check each selector and key | F: `test_EM_asset_administration_selector_key_matrix`, `test_EM_orders_administration_selector_key_matrix` |
| EM-04 | Emergency transfers each listed token from Asset to Orders or Agent, and from Orders to Asset or Agent. All other receivers fail | F: `test_EM_all_transfer_routes_tokens_and_forbidden_receivers` |
| EM-05 | The recovery signer buys only allowed recovery tokens, pays Agent and keeps the one-day limit | P: WETH→USDC only; the stand has no USDT |
| EM-06 | Stop new operator calls, cancel resting presigns and TWAPs, handle pending burn motions, recover assets and zero approvals. Then verify that no executable leftovers remain | L: public emergency drills [s12] |
| EM-07 | Test other stop sequences: zero approval before cancel, revoke before cancel, switch while a burn is pending, repeated stop, interrupted recovery and retry | F: `test_EM_zero_and_revoke_before_cancel_repeated_stop_and_retry`, `test_EM_repeated_switch_pending_burn_cancel_and_restart` |
| EM-08 | A selective Voting restore enables only the reviewed modules, targets and approvals. Committee operates again. Cancelled signatures and motions stay invalid. Repeat stop and restart, then execute a new settlement | F: `test_emergency_recovery_*`; L: public restore [s12] |
| EM-09 | Filled orders cannot replay after restart. Claimed queues cannot pay twice. Frozen governance cannot grant a bypass during recovery | F: `test_EM_combined_filled_order_claims_frozen_governance_and_restart` |

## J. UI, declarations, scripts and evidence handling

Basis: usable signing path, honest execution status and recovery of interrupted runs [s5][s6][s8][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| OPS-01 | Safe and Zodiac show the correct chain, vault, role, caller, token, receiver, amount and operation before signature | P: no wallet signature yet [s12] |
| OPS-02 | The UI limits for Nor and WithinAllowance are explicit. The checks read RPC amounts at the same block. An Unsupported Condition never counts as a policy failure or a pass | L: the UI shows no budget amount [s12] |
| OPS-03 | An imported builder payload decodes to the reviewed call. A MultiSend envelope contains only the intended calls and operation types | P: reference envelope only; no UI envelope [s12] |
| OPS-04 | The checks detect a stale nonce, a concurrent proposal, an old cancelled workspace proposal and a wrong owner route before signing | P: old proposal only [s12] |
| OPS-05 | A fresh RPC diff detects a changed membership, role, condition, target, allowance configuration, owner, guard or module. The diff does not classify budget consumption as drift | F: policy diff tests [s12] |
| OPS-06 | A compile, serialize and resolve round trip preserves Nor, receivers, limits, keys and live allowance storage. UI metadata changes cause no unintended on-chain calls | P: the 100 calls of the artifact round-trip; hosted resolve and apply matched at block 12148661 [s12] |
| OPS-07 | A timeout, invalid API result, stale cache, partial snapshot or lost response never produces a false success. Keep the previous evidence and show its age | P: UI cases open [s12] |
| OPS-08 | Reject a receipt with status 1 and a Safe failure. Compare canonical chain, sender, destination, input, nonce, block and hash, logs and resulting state | P: root receipt audit [s12] |
| OPS-09 | A broadcast timeout after mining, a dropped or replaced transaction, a duplicate retry and a partial batch each resume exactly once, without a reset of policy or budgets | L: submission faults [s12] |
| OPS-10 | A wrong branch, a dirty or unpushed tree, a wrong workspace or chain, CI and missing authorization fail the applicable guards. Keys never enter outputs | P: local guard drill [s12] |
| OPS-11 | Each run pins one block and checks the suite count, at least one passed test per suite, and no failed or skipped test | F: `DrillResults` in `scripts/test_sepolia_workflow.py`; `test-current` passed 16 suites, 101 of 101, at block 12148541 [s12] |
| OPS-12 | Each important configuration change and order lifecycle generates the expected alert. Test the handling of duplicates, reorgs and outages, and the notification destination | D: this stand's contract suite does not exercise the monitoring integration |
| OPS-13 | Teardown inventories pending orders, motions and claims, sweeps the intended balances and disables only reviewed modules. The evidence stays reproducible | L: teardown inventory [s12] |

## K. Launch integrations absent from the reduced Sepolia profile

The full system plan still requires these integrations.
Test them on a mainnet fork or on the owning deployment.
Do not label a synthetic Sepolia case as their coverage.
Existing mainnet harness tests can give partial evidence after their exact assertions are mapped [s4][s5][s6][s7][s9].

| ID | Integration and required paths | State |
|---|---|---|
| MAIN-10 | Governance templates and exit-governance: creation and enactment validation for each in-scope template, narrow target, selector and receiver, removal of the complete tree, stale-state recovery, emergency exit, and forbidden admin and delegatecall calls | D |
| MAIN-12 | Committee screening at cap lift: correct guard and build, no modules or bypass, one-use approval tied to the full transaction and nonce, no replay or standing approval, outage, ten-day removal path, and independent Emergency and Voting paths | D |
| MAIN-13 | Signing UI and screening: approval request and state, an alert for pending approval latency, rejection, timeout, changed payload, and Committee duties outside the vault | D |
| MAIN-14 | Production signer sets and thresholds, ACL boundaries of Voting, Dual Governance and Agent, atomicity of the enabling vote, and alerts for singleton, module and guard | D |
| MAIN-15 | Attested valuation, funding headroom, caps, buffer and reporting: fixed source block, price and rule version, stale or missing data, Asset plus Orders accounting, First-loss exclusion and actionable alerts | D |
| MAIN-16 | Lido Lend: onboarding motion, Morpho-compatible lifecycle and emergency exit, after the actual target exists. It has a separate post-launch gate | D: post-launch |

Excluded positive flows: LDO, the Lido withdrawal queue, stop-loss, Stonks and router swaps, Aave, sDAI, insurance-fund roles and the third registry, and the token and restore templates.
Keep refusal tests for forbidden calls and selectors.
Do not revive replaced ADR decisions to fill this checklist [s2][s3][s4][s7].

## Review evidence

The [results](../research/sepolia-test-results.md#coverage-review-findings-and-dispositions) record the coverage review findings and their dispositions [s12].
