---
type: Guide
title: Sepolia setup coverage checklist
description: Inventory the setup, integration paths, boundaries, failure states and recovery cases that the stand must exercise.
tags: [sepolia, testing, coverage, integrations]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-23T15:44:44Z
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
    resource: /adr/013-tests-on-sepolia.md
    title: Account keys and Sepolia execution boundaries
  - id: s9
    resource: /specs/sepolia-test-plan.md
    title: Execution plan, named tests, evidence and first transfer
  - id: s10
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: Current Sepolia tests, fixture, compiler profile, receipt guards and runner
  - id: s11
    resource: urn:clutch:evidence:2026-10-23:sepolia-current-stand-fork
    title: Fourteen fork cases at block 11977122 with source hashes
  - id: s12
    resource: urn:clutch:evidence:2026-10-23:sepolia-first-transfer
    title: Exact first-transfer payload and two fork tests at block 11977379
  - id: s13
    resource: /research/cow-orders-account-2026-10-06.md
    title: Verified signer source observations — expiry comparison and proportional fee ceiling
---

# Sepolia setup coverage checklist

## How to use the checklist

This is the coverage inventory for the execution plan [s9].
Each row is an obligation, not a claim that the integration passed.
Enumerate paths from the specifications, then compare the deployed grants with that inventory.
An unexpected grant needs a refusal case or a design decision.
Do not infer an intended permission from the compiler alone [s1][s2][s3][s4][s8].

Use these evidence states [s9][s10]:

- **F**: the stated case passed on a pinned fork. The evidence must name the test and its assertions.
- **P**: a named subset passed; the remaining variants are open. A whole row is not complete.
- **O**: no matching execution evidence has been recorded for this obligation.
- **D**: the dependency is absent from this stand. Verify it on the owning deployment or mainnet fork.
- **X**: excluded from launch. Test refusal where applicable; do not implement a positive path.

The tables record fork coverage as of blocks `11977122` and `11977379` on 2026-10-23.
No public execution result for the first transfer or the later flows is recorded here.
Public status remains **open** until canonical receipts, state deltas and the exact case ID are recorded.
Configuration observations, simulated calls and real signed transactions have separate evidence records [s9][s11][s12].

For each row, expand the applicable variants below into separately recorded checks.
Do not check a parent row until its required variants pass [s1][s3][s5][s9]:

| Axis | Required variants |
|---|---|
| Caller | Committee Safe, Emergency Safe, executor, Voting owner path, owner EOA directly, unrelated EOA |
| Role and account | Correct key; old key; another account's key; missing role; wrong modifier; wrong avatar |
| Input | Valid; zero; minimum; exact limit; one raw unit outside limit; malformed data; wrong token, spender, handler or receiver |
| State | Before use; after partial use; exhausted; expired; revoked; module disabled; approval zeroed; restored |
| Execution | CALL; required delegatecall; forbidden delegatecall; nonzero ETH; single call; batch with a failing member |
| Evidence | Correct error origin; receipt and Safe outcome; exact token/allowance deltas; no unintended state changes; retry and replay |

This defines finite input classes and state transitions.
It does not claim exhaustive coverage of every possible calldata byte sequence.
Use parameterized tests for the cross-account authorization matrix and amount/time boundaries.
Use sequences for interactions between cancellation, revocation, approvals and restart [s1][s3][s5][s9].

## A. Deployment, identities and authority

Basis: account graph, launch configuration and migrated role keys [s1][s6][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| CFG-01 | Chain ID, pinned block/hash, manifest network and unique addresses agree; wrong network or missing code stops the run | P: runner pins chain/block; complete runtime inventory open |
| CFG-02 | Exact singleton and runtime hashes match the approved manifest for every Safe, modifier and protocol dependency | O |
| CFG-03 | Exact owner sets and thresholds match for all five Safes; an extra owner must fail the check | P: account test checks first owners and Committee/Emergency thresholds |
| CFG-04 | Exact module sets match for every Safe, including no unexpected Committee/Emergency module | P: account test checks expected module presence, not set equality |
| CFG-05 | Asset and First-loss have the intended guard/fallback state; Orders has the pinned fallback and domain verifier | P: CoW domain mapping is asserted; full storage inventory open |
| CFG-06 | Each Roles instance has the correct owner, avatar and target, and only the intended member/role mappings | P: owner/avatar/target and selected executions pass; full membership enumeration open |
| CFG-07 | Four new keys execute, four old role instances fail; wrong-account keys and a direct controller fail | F: `test_role_keys_reject_old_wrong_account_and_non_member` |
| CFG-08 | No unexpected default role, unwrap adapter, target, selector or execution option exists; event reconstruction agrees with getters and declaration | O: needs a fresh full snapshot for the run |
| CFG-09 | Direct controller-to-role refusal remains distinct from successful controller-to-Committee-to-role execution | F: first-transfer positive and negative tests |
| CFG-10 | Only test Voting owns the vault Safes; test Agent is the recovery recipient, not an alternative owner | P: first owner and distinct Voting/Agent asserted; exact sets open |
| CFG-11 | Owner-signature failure, insufficient signatures, stale nonce, replay, wrong Safe and wrong chain fail without unintended execution | O |
| CFG-12 | Exact initial relayer approvals exist only on Orders for the configured tokens; other approvals are inventoried | O |

## B. Funding, transfers and allowances

Basis: pinned receiver and per-token budgets; successful-call accounting [s3][s5][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| FUND-01 | First transfer of 0.01 WETH through the actual Committee payload debits Asset, credits Orders, consumes the same budget and increments Committee nonce | F: `TC-SEP-001` in the execution plan |
| FUND-02 | WETH and USDC funding each reach the exact budget boundary; an extra raw unit fails in the allowance condition | F: named WETH and USDC budget cases |
| FUND-03 | Wrong receiver fails with sufficient token balance and unspent budget; isolate zero, controller, Agent and another Safe | O: shared WETH probe follows budget exhaustion and cannot isolate receiver enforcement |
| FUND-04 | Unknown token, wrong selector, wrong operation and nonzero ETH fail at their respective permission checks | O |
| FUND-05 | Several partial transfers consume the sum; another transfer at the remaining balance succeeds; the next unit fails | O |
| FUND-06 | WETH and USDC keys are independent; raw units respect 18 versus 6 decimals; one key's use/refill changes no other key | O |
| FUND-07 | Refill at period minus one, exact period and plus one; multiple periods; maximum clamp; spent and untouched budgets | P: another transfer after 30 days passes; exact edges and clamp open |
| FUND-08 | Insufficient token balance or a reverted token call rolls back allowance consumption and token changes | O |
| FUND-09 | Zero transfers and empty batches have an explicit expected result; repeat, duplicate and reordered batches cannot conceal consumption | O: specify zero behavior before implementation |
| FUND-10 | A batch's later failure has the intended atomicity; test both revert-on-failure and non-reverting module modes and inspect the outer Safe outcome | O |
| FUND-11 | Orders returns WETH and USDC only to Asset under operator authority; arbitrary receiver and token fail; return does not refund the spent funding budget | P: small WETH return passes; complete token/receiver matrix and no-refund assertion open |
| FUND-12 | Public funding wraps and transfers once; partial runs resume recorded transactions without double funding | O: balances were observed; receipt-based funding acceptance remains open |

## C. Typed CoW orders and signer

Basis: operator and recovery signer restrictions, lifetime and cancellation [s3][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| ORD-01 | WETH→USDC and USDC→WETH; sell and buy kinds; fill-or-kill and partial fills; exact recipient and signed order owner; classify same-token orders against the intended specification | P: WETH→USDC sell/fill-or-kill passes |
| ORD-02 | Fresh quote uses Orders as owner and the intended receiver; request, returned order and submitted typed fields agree | O: public API case |
| ORD-03 | Signer runs as the required delegatecall from Orders; CALL, wrong signer target and Asset execution fail | P: required path and Asset refusal pass; CALL-target matrix open |
| ORD-04 | Operator duration: zero, minimum, 90-day boundary and one second over; signer requires validTo strictly before timestamp + validDuration; test just below/equal/above, and expired-order signer acceptance separately from settlement refusal | P: 90-day duration acceptance and excess refusal pass; remaining expiry edges open |
| ORD-05 | Unknown sell/buy tokens, wrong receiver, zero amounts, unsupported kind, nonzero appData and wrong balance modes fail for the expected reason | P: unknown tokens, receiver and excess fee sampled; full field matrix open |
| ORD-06 | Fee parameter at zero, boundary and one unit over; order fee below/at/above its proportional ceiling, raw-unit rounding and arithmetic limits; a lower fee is valid, not a field mismatch | P: zero passes and excess parameter fails; exact order-fee ceiling and rounding open |
| ORD-07 | Presign UID binds chain, settlement domain, owner, tokens, amounts, expiry and receiver; changing any signed field invalidates it | P: exact digest presigned; mutation/replay matrix open |
| ORD-08 | Operator cancels its allowed orders; Emergency cancels operator and recovery orders; repeated cancellation has a defined result | P: operator unsign and emergency operator unsign pass; recovery/repeat variants open |
| ORD-09 | Wrong order cancellation cannot cancel a different UID; cancel after a partial fill blocks the remainder; re-sign semantics for the same UID are explicit | P: cancelled exact UID is rejected before and after restart; partial-fill, re-sign and wrong-UID isolation open |
| ORD-10 | Existing signed orders remain executable after permission revocation until explicitly cancelled, expired or blocked by approval; prove the distinction by attempted settlement | P: presign remains present after revocation; settlement in that intermediate state open |
| ORD-11 | Submit market and resting limit orders through the public API; observe status, rejection, expiry, partial fill, cancellation and settlement UID | O |

ORD-04 and ORD-06 must use the pinned signer's exact expiry comparison and fee calculation.
The fee parameter is a ceiling relative to the sell amount, not a requirement that two fee fields be equal.
Derive the raw-unit boundary independently from that source before implementing the new tests [s13].

## D. ComposableCoW, fallback handler and TWAP

Basis: only TWAP at launch, timestamp context and bounded schedule [s3].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| TWAP-01 | Correct handler, timestamp factory, empty context data, dispatch and start-at-creation produce a valid order | F: shared signature case and settlement case |
| TWAP-02 | Reject another handler, factory, start time, unexpected data, dispatch flag and malformed staticInput; stop-loss stays forbidden | O |
| TWAP-03 | Daily schedule: minimum parts, 90 parts at one day, plus one part and plus one second; calculate final end independently | P: two parts pass and 91 parts fail; exact schedule matrix open |
| TWAP-04 | Weekly schedule: 12 parts at seven days; just-over boundaries; reject combinations beyond both allowed branches | O |
| TWAP-05 | Before first part, exact interval, just before/after interval, skipped intervals and after the final part; no future part or replay can settle | P: sequential interval advance passes; edge/replay cases open |
| TWAP-06 | Each part has the expected amount, receiver, expiry and UID; two parts settle through the actual Safe fallback/domain verifier | P: two parts settle and digests differ; independent schedule/amount assertions remain open |
| TWAP-07 | Changed order hash, owner, domain, staticInput, proof and stale cached signature fail with the intended verifier error | O |
| TWAP-08 | Operator and Emergency removal each disable generation and cached-signature settlement; unrelated order remains valid | P: both removal roles exercised; unrelated-order isolation and exact errors open |
| TWAP-09 | Duplicate salt/params, remove then recreate and several simultaneous TWAPs have explicit identity and cancellation semantics | O |
| TWAP-10 | Insufficient balance or zero relayer approval blocks settlement without consuming a part; recover/retry without double fill | O |
| TWAP-11 | Public watcher/order submission discovers and submits each part; save both actual settlement receipts and cancellation state | O |

## E. Settlement and relayer approvals

Basis: real settlement outcomes and approval restoration by owner authority [s3][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| SETTLE-01 | Authorized solver settles an exact presigned order; Asset receives the buy token and filledAmount updates | F: synthetic-liquidity market/limit case |
| SETTLE-02 | Price below the signed limit fails with no fill or sell-token debit; exact limit succeeds | F: market/limit case |
| SETTLE-03 | Unknown solver, unsigned/cancelled/expired order, overfill and replay fail at the expected layer | P: cancelled presign refusal passes; other cases open |
| SETTLE-04 | Sell/buy and partial/full orders account for executed amount, fee, rounding, remaining amount and receiver balance | P: sell/full with synthetic prices only |
| SETTLE-05 | Missing balance and missing approval each fail without changing filledAmount or balances; restored prerequisites permit one fill | O |
| SETTLE-06 | Both tokens' approvals can be zeroed only to the configured relayer; positive amount, another spender and operator approval fail | P: both zeroed and positive reapproval refused; spender matrix open |
| SETTLE-07 | Voting restores the exact approval; Emergency/Committee cannot; recovery transfers still work while approval is zero | P: owner WETH restoration and emergency positive refusal pass; transfer while zero open |
| SETTLE-08 | Public settlement receipt matches submitted UID, execution amounts, fee, receiver and final API status | O |

## F. First-loss shares and queues

Run every applicable case separately for test USD and test ETH shares.
These are permission and lifecycle checks on synthetic queues, not Earn economics [s4][s9].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| FL-01 | Shares reference the correct queue; queue/share/claim-asset/controller relationships match the manifest and have no cross-asset substitution | O |
| FL-02 | Committee redeems each share, the queue receives the requested shares, and claim after fixture settlement credits Agent by the requested amount | F: both-assets redeem/claim case; supply accounting is FL-08/ET-03 |
| FL-03 | Wrong receiver fails before claim; direct share transfer, approve and burn by Committee fail; Emergency has no share path | P: Committee prohibitions for both shares and Emergency USD redeem refusal pass; full Emergency matrix open |
| FL-04 | Zero request, amount at balance and excess; multiple requests in one timestamp and different timestamps have defined accounting | O |
| FL-05 | Claim before settlement, duplicate/empty/out-of-order timestamps, double claim and partial timestamp sets cannot overpay; a zero return is not incorrectly required to revert | O |
| FL-06 | Only the fixture controller settles; settle twice/wrong account/wrong timestamp fails; each share changes no other queue | O |
| FL-07 | Redeem, pending claim, emergency stop, Voting cancellation/restart and later claim preserve independently controlled First-loss state | O |
| FL-08 | A failed claim or burn leaves shares, supply, queue requests and claimable amounts in the expected unchanged state | O |

## G. Burn factory, Easy Track and executor

Basis: trusted caller, objection window, script hash and burn-only executor role [s2][s4].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| ET-01 | Factory is allowlisted and pinned to Committee, the First-loss modifier and both shares; only Committee creates a burn motion | P: Committee creation passes; exact wiring and unauthorized creators open |
| ET-02 | Wrong share, zero amount, malformed data, unregistered factory and excessive burn fail at the correct factory/enactment stage | O |
| ET-03 | Each share burns after the configured window; early enactment fails; supply and First-loss balance decrease exactly | P: both balances and timing pass; totalSupply delta open |
| ET-04 | Time just before/exactly at/after enactment boundary; unchanged payload succeeds, substituted payload/script fails | P: early and elapsed-window cases pass; exact edges/substitution open |
| ET-05 | Objection below/exactly at/above threshold; no-weight account; multiple objectors; repeated objector and snapshot-weight semantics | P: controller objection rejects motion; remaining semantics open and fixture divergence must be recorded |
| ET-06 | Creator cancellation and Voting cancellation; unauthorized cancellation, repeated cancellation and enact-after-cancel fail | P: Voting cancellation and enact refusal pass; creator/unauthorized/repeat variants open |
| ET-07 | Re-enactment, concurrent motions competing for shares and failed burn cannot silently duplicate a motion; create a motion, remove its factory, then test enactment and record whether removal stops pending actions | O |
| ET-08 | Executor accepts only Easy Track; valid CallsScript executes; malformed spec/length, failing chunk and mixed batch have explicit atomicity | O: current-stand executor encoding/failure matrix not recorded |
| ET-09 | Caller, factory input and script are bound at creation/enactment; Committee cannot use first-loss-burn directly | P: direct Committee burn-role refusal passes; full motion binding open |
| ET-10 | Pending burn is cancelled through Voting before restart and remains unenactable after restart | F: emergency/restart sequence |

The stand's objection mock reads current token balances and does not enforce one objection per objector.
Its snapshot date is not proof of historical voting weight.
ET-05 cannot close the corresponding production Easy Track requirement [s4][s10].
The mock checks factory allowlisting at creation, not again at enactment.
ET-07 must distinguish this behavior from the intended production revocation procedure [s2][s10].

## H. Asset governance and owner authority

Basis: seven-role graph, no Orders governance, scoped grants and period floor [s1][s2][s5][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| GOV-01 | Executor can scope/revoke targets and allow/scope/revoke functions only for asset-operator; round-trip preserves unrelated functions and conditions | P: revokeFunction positive passes; remaining five admin paths open |
| GOV-02 | Every admin selector rejects old, emergency, First-loss and Orders keys, across every protected Safe and module target | P: old/Orders keys and one protected target sampled |
| GOV-03 | None/Send options follow specification; DelegateCall/Both fail for every grant selector; pre-existing delegatecall cannot be widened | P: one allowFunction delegatecall refusal passes |
| GOV-04 | Membership, default role, owner/avatar/target, adapters, Safe modules, guard, fallback and singleton cannot be changed through governance | P: assignRoles refusal passes; complete selector matrix open |
| GOV-05 | Both known budget keys allow the intended period/balance changes; foreign keys, period below floor and wrong timestamp behavior are rejected or specified | P: foreign key and period-floor negatives pass; positive budget updates and per-key ceilings open |
| GOV-06 | Orders has neither governance nor approval-management role; executor cannot gain owner authority by another call route | P: one Orders governance call is refused; alternate routes open |
| GOV-07 | Governance operates only while its Asset modifier is enabled; after disable, Voting alone performs the reviewed owner restoration | P: owner restart passes; governance-while-disabled case open |
| GOV-08 | Full governance motion → factory → executor path validates script and enactment; executor impersonation alone is insufficient | D: suitable governance factory absent from this stand |
| GOV-09 | Direct Voting owner path succeeds; non-owner cannot drive Voting; failed owner batch is atomic; owner restoration never restores a later revoked permission by accident | O: migration evidence is a separate pre-migration case, not this current-state acceptance |
| GOV-10 | Create a policy-expansion motion, stop the Asset modifier before enactment, then restart: an uncancelled pending motion must be identified as a reactivation hazard; cancel it before restoring execution | D: production lifecycle needs the missing governance factory; burn cancellation is not a substitute |

## I. Emergency, cancellation and restart sequences

Basis: stop-only emergency authority and DAO restart [s1][s3][s4][s8].

| ID | Required check and acceptance | Fork coverage |
|---|---|---|
| EM-01 | Asset switch disables only the intended operator modifier; safety still executes; wrong prev/module cannot disable another control | P: positive switch and working safety pass; wrong predecessor/module variants open |
| EM-02 | Asset and Orders revokeTarget and revokeFunction each stop the selected operator permission; unrelated permissions remain usable | P: Orders target revocation in restart sequence; complete account/selector matrix open |
| EM-03 | Emergency cannot grant, enable, change members, increase approvals or create a budget; confirm each selector and key | P: enable, scope and positive approval refusals pass; complete matrix open |
| EM-04 | Emergency transfers each listed token from Asset to Orders/Agent and from Orders to Asset/Agent; all other receivers fail | P: WETH recovery to Agent passes; remaining combinations open |
| EM-05 | Recovery signer buys only allowed recovery tokens, pays Agent and respects the one-day bound | P: WETH→USDC recovery settles; wrong receiver and excess duration refused; remaining fields/directions open |
| EM-06 | Stop new operator calls, cancel resting presigns/TWAPs, handle pending burn motions, recover assets, zero approvals, then verify no executable leftovers | P: one combined sequence passes; complete outstanding-item inventory open |
| EM-07 | Test alternate stop orderings: zero approval before cancel, revoke before cancel, switch while a burn is pending, repeated stop, interrupted recovery and retry | O |
| EM-08 | Selective Voting restore enables only reviewed modules, targets and approvals; Committee operates again; cancelled signatures/motions stay invalid; repeat stop/restart and execute a new settlement | P: WETH restart plus cancelled order/TWAP/burn refusal passes; selective-state, second-cycle and new-settlement checks open |
| EM-09 | Already-filled orders cannot replay after restart; already-claimed queues cannot pay twice; frozen governance cannot grant a bypass during recovery | O |

## J. UI, declarations, scripts and evidence handling

Basis: usable signing path, honest execution status and recovery of interrupted runs [s5][s6][s8][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| OPS-01 | Safe and Zodiac identify the correct chain, vault, role, caller, token, recipient, amount and operation before signature | O: payload prepared; actual browser signing not recorded |
| OPS-02 | UI limitations for Nor/WithinAllowance are explicit; RPC amounts are checked at the same block; Unsupported Condition never counts as a policy failure or pass | O |
| OPS-03 | Imported builder payload decodes to the reviewed call; any MultiSend envelope contains only the intended calls and operation types | P: direct Committee payload simulated; UI-produced envelope open |
| OPS-04 | Stale nonce, concurrent proposal, old cancelled workspace proposal and wrong owner route are detected before signing | O |
| OPS-05 | Fresh RPC diff detects changed membership, role, condition, target, allowance configuration, owner, guard or module; budget consumption is not misclassified as drift | O: policy-only diff cannot close Safe/guard checks |
| OPS-06 | Round-trip compile/serialize/resolve preserves Nor, recipients, limits, keys and live allowance storage; UI metadata changes have no unintended on-chain calls | P: existing local compiler/publisher regressions; exact current-run acceptance open |
| OPS-07 | Timeout, invalid API result, stale cache, partial snapshot and lost response never produce a false success; retain previous evidence and identify its age | P: existing publisher/snapshot regressions; UI and end-to-end retry cases open |
| OPS-08 | Receipt status 1 with Safe failure is rejected; compare canonical chain, sender, destination, input, nonce, block/hash, logs and resulting state | P: saved-run guards reject Safe failure; full public receipt/state check open |
| OPS-09 | Broadcast timeout after mining, dropped/replaced transaction, duplicate retry and partial batches resume exactly once without resetting policy/budgets | O: current workflow needs dedicated fault drills |
| OPS-10 | Wrong branch/dirty/unpushed state, wrong workspace/chain, CI and missing authorization fail applicable guards; keys never enter outputs | P: offline guard tests exist; complete operational drill open |
| OPS-11 | Every run checks exact named cases, no missing/skipped tests, matching source/payload hashes and canonical block; failed preparation invalidates old success | P: runner and output-validator checks; first-transfer evidence is a separate cached test |
| OPS-12 | Each important configuration change and order lifecycle generates the expected alert; duplicate/reorg/outage handling and notification destination are exercised | D: monitoring integration not exercised by this stand's contract suite |
| OPS-13 | Teardown inventories pending orders/motions/claims, sweeps intended balances and disables only reviewed modules; evidence remains reproducible | O |

## K. Launch integrations absent from the reduced Sepolia profile

These remain required in the full system plan.
Use a mainnet fork or the owning deployment; do not label a synthetic Sepolia case as coverage of them.
Existing mainnet harness tests can supply partial evidence after their exact assertions are mapped [s4][s5][s6][s7][s9].

| ID | Integration and required paths | State |
|---|---|---|
| MAIN-01 | ETH↔WETH: wrap/unwrap, value and amount boundaries, correct balance deltas, missing ETH/WETH, operator/emergency differences, stop/restart | D |
| MAIN-02 | Lido submit: operator and Emergency, zero referral, nonzero value, minted shares/rebase-aware accounting, wrong referral, pause/failure and recovery | D |
| MAIN-03 | stETH↔wstETH: wrap/unwrap, approval ceiling and zeroing, conversion rounding, receiver custody, operator/emergency differences and restart | D |
| MAIN-04 | DAI↔USDS converter: both directions, fixed approval ceilings, exact recipient, zero/maximum/excess, paused/upgraded dependency, emergency exit | D |
| MAIN-05 | sUSDS: deposit, redeem and withdraw; receiver/owner pins, share/asset rounding, max limits, approval budget, failed-call rollback and emergency exit | D |
| MAIN-06 | EarnUSD and EarnETH deposits: each supported asset, approvals, request and any deployed cancellation path, pricing/settlement, claim to Asset, proof/caller fields, caps, queue pause and insufficient liquidity; record absent API paths rather than inventing them | D |
| MAIN-07 | EarnUSD and EarnETH redemptions: normal Asset positions and separate First-loss positions, pricing/report delay, multiple requests, claim variants, liquidity shortage, emergency completion and no double claim | D |
| MAIN-08 | Real First-loss burn: trusted factory, exact supply/share accounting and motion lifecycle; do not substitute the stand's unrestricted controller-mintable token | D |
| MAIN-09 | Treasury funding: stablecoin and stETH registries, allowed assets/recipient, shared payment permissions, trusted creator, monthly enactment limits, objection/cancel, paused payments, owner-only limit changes and enabling vote | D |
| MAIN-10 | Governance templates and exit-governance: each in-scope template's creation/enactment validation, narrow target/selector/receiver, complete-tree removal, stale-state recovery, emergency exit and forbidden admin/delegatecall | D |
| MAIN-11 | Full CoW launch token matrix: allowed sell/buy/recovery pairs, USDC and USDT recovery, decimals, rounding and token-specific approval/transfer behavior; non-launch tokens refused | D |
| MAIN-12 | Committee screening at cap lift: correct guard/build, no modules or bypass, one-use approval tied to full transaction/nonce, no replay/standing approval, outage, ten-day removal path and independent Emergency/Voting paths | D |
| MAIN-13 | Signing UI and screening: approval request/state, pending approval latency alert, rejection, timeout, changed payload and non-vault Committee duties | D |
| MAIN-14 | Production signer sets and thresholds, Voting/Dual Governance/Agent ACL boundaries, enabling-vote atomicity, singleton/module/guard alerts | D |
| MAIN-15 | Attested valuation, funding headroom, caps, buffer and reporting: fixed source block/price/rule version, stale/missing data, Asset+Orders accounting, First-loss exclusion and actionable alerts | D |
| MAIN-16 | Lido Lend: onboarding motion, Morpho-compatible lifecycle and emergency exit after the actual target exists; separate post-launch gate | D: post-launch |

Excluded positive flows: LDO, Lido withdrawal queue, stop-loss, Stonks/router swaps, Aave, sDAI, insurance-fund roles/third registry, token and restore templates.
Keep refusal tests for forbidden calls and selectors.
Do not revive superseded ADR decisions to fill this checklist [s2][s3][s4][s7].

## Coverage review findings and dispositions

The requested completeness and adversarial reviews concern this test inventory.
They do not change permissions, approve parameters or close implementation work [s1][s8][s9].

| Review challenge | Disposition |
|---|---|
| Expected first owner/module presence can pass with extra owners or modules | CFG-03/04 remain partial; require exact sets |
| Wrong-recipient probe runs after exhausting allowance, so a generic ConditionViolation can hide the recipient defect | FUND-03 stays open; isolate budget and decode the relevant condition before marking it passed |
| A green 14-test run is mistaken for all variants of each integration | Record exact assertions per row; broad families remain partial or open |
| Disabling a role does not invalidate an already signed order | ORD-10 and EM-06/07 require intermediate-state execution and explicit cancellation |
| Fixture settlement, solver impersonation and executor impersonation are mistaken for full external integration | Keep public API, real Earn and full governance motion gates separate |
| Cancelling a burn motion is mistaken for clearing frozen policy-expansion motions before restart | GOV-10 remains unavailable on the reduced stand; require the actual governance lifecycle |
| Current-balance objections in the mock are mistaken for production snapshot voting | ET-05 remains partial; record the fixture's repeat-objection and historical-weight differences |
| Factory removal is mistaken for cancellation of pending motions | ET-07 tests removal after creation; require an explicit pending-motion revocation procedure |
| A proportional fee bound is mistaken for equality, or expiry boundaries are inferred from a duration limit | ORD-04/06 require the exact signer comparison and independent boundary calculations |
| An ERC-20 budget rollback case can pass on insufficient balance instead of the intended allowance bound | FUND-02/08 use independent prerequisites and distinguish error origins |
| Historical designs expand the test list with removed features | Section K uses current decisions and lists excluded positive paths |
| A successful receipt or present presignature is mistaken for completed settlement | SETTLE-08 and OPS-08 require canonical execution and observed state deltas |

Close each review item only with its named evidence.
No new cases in this inventory have been executed merely by adding the checklist [s9][s10].
