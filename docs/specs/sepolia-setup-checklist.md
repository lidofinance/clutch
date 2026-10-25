---
type: Guide
title: Sepolia setup coverage checklist
description: Inventory the setup, integration paths, boundaries, failure states and recovery cases that the stand must exercise.
tags: [sepolia, testing, coverage, integrations]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-25T20:11:26Z
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
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-transfer
    title: Refreshed 0.01 WETH payload, successful eth_call and two fork tests at block 11984953
  - id: s13
    resource: /research/cow-orders-account-2026-10-06.md
    title: Verified signer source observations — expiry comparison and proportional fee ceiling
  - id: s14
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork
    title: Expanded current-stand run — 64 tests across 12 suites at block 11984762
  - id: s15
    resource: https://eth-sepolia.blockscout.com/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec
    title: Public first-transfer receipt and logs at block 11985108
  - id: s16
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork
    title: Final current-stand fork run passed 65 tests across 12 suites at block 11985708
  - id: s17
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-order-expiry-1724014
    title: CoW API confirms quote 1724014 expired with zero execution; latest competition excludes its UID
  - id: s18
    resource: urn:clutch:evidence:2026-10-24:sepolia-direct-role-call-denied
    title: User-run read-only Sepolia cast call to asset-operator reverted with NotAuthorized(controller)
  - id: s23
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-safe-and-token-state
    title: Safe-service configuration and Blockscout Safe balance and Orders relayer allowance snapshot
  - id: s27
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-211959
    title: All 65 current-stand fork tests passed at pinned Sepolia block 11986397
  - id: s28
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2155
    title: All 65 current-stand fork tests passed at pinned Sepolia block 11986574 after the cancellation
  - id: s29
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-first-loss-burn
    title: Public synthetic USD and ETH burn, objection, Voting cancellation and replay refusal
  - id: s30
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-emergency
    title: Public stop, sweep, zero approvals, exact Voting restart, current policy snapshots and canonical audit of 47 burn/emergency receipts
  - id: s31
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2301
    title: All 65 tests passed at block 11986901 after public burns and restart
  - id: s32
    resource: https://github.com/cowprotocol/services/blob/v2.384.6/crates/database/src/orders.rs#L688-L698
    title: CoW derives invalidation and pending presign from independent records
  - id: s33
    resource: urn:clutch:evidence:2026-10-24:sepolia-twap-public-settlement
    title: Two public TWAP settlements with matched Trade UIDs, signed fees, exact token transfer deltas and API status
  - id: s34
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-loss-redemption
    title: Public USD and ETH redeem, settle and claim to Agent with exact balance and supply changes
  - id: s35
    resource: https://github.com/cowprotocol/services/blob/v2.384.6/crates/orderbook/src/database/orders.rs#L556-L578
    title: CoW order status precedence after unsign and expiry
  - id: s36
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-market-limit-order
    title: Fresh verified quote, exact zero-fee UID, public admission and subsequent unsign without execution
  - id: s37
    resource: urn:clutch:evidence:2026-10-25:sepolia-current-stand-boundaries
    title: Ten new boundary cases and all 75 named tests passed at block 11987022
  - id: s38
    resource: urn:clutch:evidence:2026-10-25:sepolia-zodiac-ui
    title: Read-only Zodiac route, condition rendering, old proposal refusal and pinned allowance reads
  - id: s40
    resource: urn:clutch:evidence:2026-10-25:sepolia-governance-emergency-matrix
    title: Full 79-case run, governance cross-products, delegatecall downgrade, timestamp hazard and emergency recipients
  - id: s41
    resource: urn:clutch:evidence:2026-10-25:sepolia-emergency-matrix
    title: Both emergency administration matrices and combined filled-order/claimed-queue/frozen-governance restart passed in the 82-case run
  - id: s42
    resource: urn:clutch:evidence:2026-10-25:sepolia-all-public-receipts
    title: Canonical audit of 67 public receipts and 47 exact nonce-derived Safe execution hashes
  - id: s43
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-ordinary-sell
    title: Corrected quote conversion, ordinary public settlement and exact direct-controller refusal
  - id: s44
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-recovery
    title: Actual recovery settlement after stop, sweep, zero approvals and exact Voting restore
  - id: s45
    resource: urn:clutch:evidence:2026-10-25:sepolia-post-correction-fork
    title: All 82 cases pass after USDC budget/allowance regressions; 22 workflow and three quote tests pass
  - id: s46
    resource: urn:clutch:evidence:2026-10-25:sepolia-reverse-and-final-inventory
    title: Actual reverse sell, final inventory, all approval pairs and 101 public receipts with 70 Safe hashes
  - id: s47
    resource: urn:clutch:evidence:2026-10-25:sepolia-stop-ordering
    title: Two stop-ordering cases and all 84 named fork tests across 13 suites
  - id: s48
    resource: urn:clutch:evidence:2026-10-25:sepolia-lost-response
    title: One mined public transaction with an injected failed response and duplicate-send refusal
  - id: s49
    resource: urn:clutch:evidence:2026-10-25:sepolia-config-inventory
    title: Pinned inventory of 37 manifest labels, 84 passing fork cases and 30 offline workflow checks
  - id: s50
    resource: urn:clutch:evidence:2026-10-25:sepolia-funding-resume
    title: Four canonical FundSepolia transactions, interruption after wrap, Foundry resume and duplicate-send refusal
  - id: s51
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-partial
    title: Actual half-fill, canonical Trade and balance deltas, remainder cancellation and exact live settlement refusal
  - id: s52
    resource: urn:clutch:evidence:2026-10-25:sepolia-conditional-entry
    title: All 86 fork cases pass, including alternative conditional entrypoints and StopLoss-payload refusal
  - id: s53
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-buy
    title: Actual BUY exact target/cap/refund and replay checks plus independent capped/volume fee computations
  - id: s54
    resource: urn:clutch:evidence:2026-10-25:sepolia-rounding-boundaries
    title: Both directions/kinds exercise nonzero remainders, cumulative partial-fill rounding and proportional fees
  - id: s55
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-resting
    title: Resting order open across canonical blocks, cancel/full return and API-reported legacy class semantics
  - id: s56
    resource: urn:clutch:evidence:2026-10-25:sepolia-nonce-faults
    title: Drop/resume, post-mining HTTP timeout, both fee-type replacements and all saved funding receipt subsets
  - id: s57
    resource: urn:clutch:evidence:2026-10-25:sepolia-stale-owner-restore
    title: Stale owner grant re-arms a later revocation, selective restart preserves it and all 88 fork cases pass
  - id: s58
    resource: urn:clutch:evidence:2026-10-25:sepolia-safe-config-drift
    title: Safe configuration drift reproduced on a pinned fork, verifier corrected and 44 regression cases passed
  - id: s59
    resource: urn:clutch:evidence:2026-10-25:sepolia-protocol-fee-reconciliation
    title: Seven canonical fills, fourteen protocol fee amounts and fourteen settlement buffer token/block ledgers reconciled
  - id: s60
    resource: urn:clutch:evidence:2026-10-25:sepolia-operational-guards
    title: Real temporary-Git CLI refusals, blocked transport, public recipe env guard and wrong-chain funding dry-run
  - id: s61
    resource: urn:clutch:evidence:2026-10-25:sepolia-payload-binding
    title: Stale payload refuses before Forge and clears old success; refreshed declaration and all 88 fork tests pass with bound input hashes
  - id: s62
    resource: urn:clutch:evidence:2026-10-25:mainnet-protocol-paths
    title: Five mainnet WETH boundary/recovery cases and explicit partial mapping for staking, wrappers, converter and savings
  - id: s63
    resource: urn:clutch:evidence:2026-10-25:mainnet-lido-submit
    title: Six real Lido v4 fork cases with exact share accounting, pause, stake-limit exhaustion and recovery
  - id: s64
    resource: urn:clutch:evidence:2026-10-25:mainnet-wsteth-paths
    title: Five real wstETH fork cases for exact share rounding, approvals, rollback and emergency recovery
  - id: s65
    resource: urn:clutch:evidence:2026-10-25:mainnet-converter-paths
    title: Seven real DaiUsds fork cases for exact token and Vat accounting, approvals, rollback and dependency recovery
  - id: s66
    resource: urn:clutch:evidence:2026-10-25:mainnet-savings-paths
    title: Eight real sUSDS fork cases for exact rounding, approvals and budgets, pending yield, rollback and emergency exit
  - id: s67
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-deposit-paths
    title: Eight real Earn deposit cases with oracle settlement, exact claims, cancellations, proof/account gates and caps
  - id: s68
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-redemption-paths
    title: Seven real Earn Asset redemption cases with report, batch, custody, pause and emergency assertions
  - id: s69
    resource: urn:clutch:evidence:2026-10-25:mainnet-first-loss-redemption
    title: Both real Earn shares from a separate First-loss Safe to Agent with exact claims, refusals and membership recovery
  - id: s70
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-redemption-boundaries
    title: Bounded batches, restrictions, oracle rollback, nonzero fee conservation and injected hook faults
  - id: s71
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-fee-extremes
    title: Both-venue fee exemption, rounding, zero-payout removal and maximum-fee zero-net request cleanup
  - id: s72
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-usdc-blacklist
    title: USDC blocks the real EarnUSD hook transfer to a blacklisted queue; batch state rolls back and retries
  - id: s73
    resource: urn:clutch:evidence:2026-10-25:mainnet-first-loss-burn
    title: Six First-loss burn motion cases use real Earn shares and Easy Track on the pinned fork
  - id: s74
    resource: urn:clutch:evidence:2026-10-25:mainnet-enabling-vote-rehearsal
    title: Live Easy Track and Finance top-ups, local registries and the payment permission rewrite on a pinned fork
  - id: s75
    resource: urn:clutch:evidence:2026-10-25:mainnet-main09-paused
    title: Paused-USDC top-up refusal, atomic rollback and retry through live Easy Track and Finance
  - id: s76
    resource: urn:clutch:evidence:2026-10-25:mainnet-main09-boundaries
    title: Trusted creator and recipient, Voting-only limit changes, objections, cancellation, monthly limit race and rollover
  - id: s78
    resource: /research/sepolia-test-results.md
    title: Recorded Sepolia results and diagnostics
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
- **L**: the stated case passed against public Sepolia. The evidence must identify the live reads, API responses or transaction receipts and their scope.
- **P**: a named subset passed; the remaining variants are open. A whole row is not complete.
- **O**: no matching execution evidence has been recorded for this obligation.
- **D**: the dependency is absent from this stand. Verify it on the owning deployment or mainnet fork.
- **X**: excluded from launch. Test refusal where applicable; do not implement a positive path.

The current-stand suite records coverage through block `11984762` on 2026-10-24.
The refreshed first-transfer payload and its two fork tests use block `11984953`, hash `0x0c69ff03f22045638e2f65f2ec50b8225f2213964819f166e79e8b88de4307e0` [s12][s14].
The first Committee transfer has a successful public receipt and matching WETH and allowance logs at block `11985108` [s15]. An earlier public snapshot reported Committee nonce `4`, Asset and Orders WETH of `0.01` each, no token-balance entries for the three remaining Safes, and Safe service configuration that matches expected owners, modules, thresholds, fallback handlers and versions. Direct token contract reads show max WETH and USDC allowances from Orders to the CoW Vault Relayer [s23]. Later public snapshots and complete policy event reconstruction supersede those balance and nonce observations [s30].
Configuration observations, simulated calls, fork results and public transaction receipts have separate evidence records [s9][s11][s12][s15][s23].

The expanded fork suite passed 64 tests across 12 suites at block `11984762` on 2026-10-24.
The runner checked the test names, source and manifest hashes, and canonical block hash [s14].
Three earlier full current-stand runs passed 65 tests across 12 suites, with no failures or skips: blocks `11985708` [s16], `11986397` [s27] and `11986574` [s28].
The user-run direct owner-EOA simulation returned `NotAuthorized(controller)` without broadcasting a transaction [s18].
At `2026-10-24T20:37:48Z`, CoW reported UID `0x2d3b…1610` expired with zero executed amounts; trades were empty and the account order list also reported expired. The per-order status endpoint still returned `active`. A newer public solver competition excluded the UID; current auction data remains permissioned [s17].
The post-restart run passed all 65 tests at block `11986901`, hash `0xbedf3b2febae2292664f6fabc5e088cfe50e8265487a7e8a60acf37ac6425a24`, after public burns and emergency restart. The final policy and refreshed local UI payload match current state. Actual burn/emergency receipts were checked against canonical headers, sender, destination and calldata; 31 Safe executions also matched their nonce-derived transaction hash and ExecutionSuccess event [s30][s31].
The boundary run passed all 75 named tests across 12 suites at block `11987022`, hash `0xe4df2126c659d33158548fda3de5a53104e3171f7e653ecf530e56c43feadfdd`, with zero failures or skips. The execution plan maps the ten added tests to their assertions and records the failed preparation attempts [s9][s37].
The governance run passed all 79 tests at block `11987139`, hash `0x4b9d9a4024ba49c928637732c50b1feef494afd6ebdc8ca5eae8bfc4372c354e`, with no failures or skips. The plan maps six governance/emergency cases to their assertions and records the reproduced maximum-timestamp configuration hazard [s9][s40].
The pre-correction run passed all 82 tests at block `11987194`, hash `0x4ab04fb74cf093fa225d68d39265c1a40787aef336a860be13db861ad838517b`, with no failures or skips. Both emergency administration matrices and the combined recovery sequence passed [s41]. The expanded public receipt audit checked 67 transactions and 47 Safe execution hashes [s42].
The post-correction run passed all 82 cases at block `11987444`, hash `0xb704697d396e1b1c354ad5fc9b6872f22e0acb4c7e0f957cb699d27f9897f32e`. Corrected ordinary, stopped recovery and reverse sells settled publicly. The final inventory is clear and the root audit covers 101 receipts and 70 exact Safe hashes [s43][s44][s45][s46].
The stop-ordering run passed all 84 named cases across 13 suites at block `11987576`. The two added cases cover alternate stop orderings, repeated stops and pending burns. A public after-mining failed-response drill confirmed one execution and duplicate-send refusal [s47][s48].
The inventory run passed all 84 cases at block `11987612`. Its inventory covers 37 labels and 36 distinct addresses; the only permitted alias is WETH. Thirty workflow tests passed, including failed-preparation guards [s49].
The public funding interruption/resume completed four canonical transactions without a repeated wrap or transfer. Both completed-run guards refused resubmission. The post-funding fork passed all 84 cases across 13 suites at block `11987655`, without failures or skips [s50].
The latest fork passed all 86 names across 14 suites at block `11987763`. It closes the remaining conditional-entrypoint/StopLoss refusal subset in TWAP-02. The public half-fill and cancelled remainder retain separate live evidence [s51][s52].
The post-BUY run passed all 87 names across 15 suites at block `11987846` after a failed RPC-dependent attempt. It used the same source/manifest hashes and pinned block. The BUY and nonzero-remainder rounding cases narrow SETTLE-04; its remaining fee variants stay open [s53][s54].
The fully funded resting-limit case and corrected legacy-class expectation complete ORD-11. It remained open and unfilled across canonical observations, then cancelled and returned all input [s55].
The post-resting run passed all 87 names across 15 suites at block `11987961`, without failures or skips. The root audit covers 118 canonical transactions and 81 exact Safe hashes [s55].
The submission-loss, HTTP-timeout and pending-replacement cases complete OPS-09 with the earlier funding resume. The stored receipt-state test covers all 16 subsets of the captured four-transaction run [s56].
The post-fault fork passed all 87 names across 15 suites at block `11988143`, without failures or skips. The root audit covers 124 canonical transactions and 85 Safe hashes [s56].
The stale-owner-restore run passed all 88 cases across 15 suites at block `11988226`, with no failures or skips. GOV-09 remains partial: selective restart preserves the later revocation, but an old owner grant can re-arm it and pre-signature detection is unverified [s57].
OPS-05 closes after the Safe-configuration verifier correction and local owner/threshold/guard/module mutation drill. Production signer sets and alert delivery remain open [s58].
OPS-11 closes after the actual stale-payload refusal and the refreshed, hash-bound 88-case fork run at block `11988436`. A rerun at block `11992758` passes all 88 cases; run details and diagnostics are recorded in the results [s61][s78]. Local declaration validation remains separate from hosted publication.
The updates close only their stated assertions and public cases. Missing production dependencies remain separate [s9][s14].

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

| ID | Required check and acceptance | Coverage |
|---|---|---|
| CFG-01 | Chain ID, pinned block/hash, manifest network and unique addresses agree; wrong network or missing code stops the run | L: pinned block 11987612 inventory checks 37 labels, 36 unique addresses and code presence; offline refusals cover wrong network, missing code/account, invalid address, alias and future deployment [s49] |
| CFG-02 | Exact singleton and runtime hashes match the approved manifest for every Safe, modifier and protocol dependency | P: 13 declared dependency hashes, four Roles proxy runtimes and five singleton slots checked. All 12 stand runtimes match frozen constructor replays; both queue child-address links pass. Approval of stand artifact baselines and the USDC implementation baseline remains open [s49][s78] |
| CFG-03 | Exact owner sets and thresholds match for all five Safes; an extra owner must fail the check | F: `test_CFG_exact_owners_thresholds_modules_guards_handlers_and_runtimes` checks exact sets and thresholds |
| CFG-04 | Exact module sets match for every Safe, including no unexpected Committee/Emergency module | F: same test paginates all five Safe module sets and checks exact membership |
| CFG-05 | Asset and First-loss have the intended guard/fallback state; Orders has the pinned fallback and domain verifier | F: exact guard/fallback slots and Orders domain verifier are checked |
| CFG-06 | Each Roles instance has the correct owner, avatar and target, and only the intended member/role mappings | L: all four modifier owner/avatar/target getters and the complete seven-role membership history match the declaration at block 11986901; zero policy differences [s30] |
| CFG-07 | Four new keys execute, four old role instances fail; wrong-account keys and a direct controller fail | F: the named current-stand test executes all four new keys, rejects all four legacy account/role instances and all four wrong-account keys with NoMembership, and refuses the direct controller with NotAuthorized. Rechecked in the 82-case run [s10][s41] |
| CFG-08 | No unexpected default role, unwrap adapter, target, selector or execution option exists; event reconstruction agrees with getters and declaration | L: complete target/function/options/default-role/unwrap event reconstruction agrees with live getters and declaration at block 11986901; RPC event-history completeness remains the documented source assumption [s30] |
| CFG-09 | Direct controller-to-role refusal remains distinct from successful controller-to-Committee-to-role execution | L: the corrected Orders role call refuses the direct controller with exact NotAuthorized(controller), while the same controller succeeds through Committee and the ordinary order settles [s43] |
| CFG-10 | Only test Voting owns the vault Safes; test Agent is the recovery recipient, not an alternative owner | F: exact owner sets and recovery recipient are asserted |
| CFG-11 | Owner-signature failure, insufficient signatures, stale nonce, replay, wrong Safe and wrong chain fail without unintended execution | F: `test_CFG_approved_hash_nonce_replay_wrong_safe_chain_and_signatures` |
| CFG-12 | Exact initial relayer approvals exist only on Orders for the configured tokens; other approvals are inventoried | F: all five Safes are checked; WETH max is fixed, and USDC current allowance equals its independently reconstructed max Approval minus later gross settle trades. All observed approval pairs are inventoried; no unexpected nonzero pair exists [s45][s46] |

## B. Funding, transfers and allowances

Basis: pinned receiver and per-token budgets; successful-call accounting [s3][s5][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| FUND-01 | First transfer of 0.01 WETH through the actual Committee payload debits Asset, credits Orders, consumes the same budget and increments Committee nonce | F: exact-payload tests and `test_FUND_first_transfer_logs_nonces_and_unchanged_configuration` |
| FUND-02 | WETH and USDC funding each reach the exact budget boundary; an extra raw unit fails in the allowance condition | F: named WETH and USDC budget cases |
| FUND-03 | Wrong receiver fails with sufficient token balance and unspent budget; isolate zero, controller, Agent and another Safe | F: both tokens and all four receivers fail at condition 7 with balances and budgets unchanged |
| FUND-04 | Unknown token, wrong selector, wrong operation and nonzero ETH fail at their respective permission checks | F: `test_FUND_wrong_token_selector_operation_value_and_malformed_data` |
| FUND-05 | Several partial transfers consume the sum; another transfer at the remaining balance succeeds; the next unit fails | F: both token budgets are consumed across partial transfers and the next raw unit fails |
| FUND-06 | WETH and USDC keys are independent; raw units respect 18 versus 6 decimals; one key's use/refill changes no other key | F: both keys, distinct caps and untouched-key hashes are checked |
| FUND-07 | Refill at period minus one, exact period and plus one; multiple periods; maximum clamp; spent and untouched budgets | F: both tokens test period−1, exact, +1, multi-period refill and the configured cap |
| FUND-08 | Insufficient token balance or a reverted token call rolls back allowance consumption and token changes | F: failed token calls preserve budget, Orders balance and expected Safe outcome |
| FUND-09 | Zero transfers and empty batches have an explicit expected result; repeat, duplicate and reordered batches cannot conceal consumption | F: zero and empty calls, duplicate/reordered batches and resulting consumption are asserted |
| FUND-10 | A batch's later failure has the intended atomicity; test both revert-on-failure and non-reverting module modes and inspect the outer Safe outcome | F: reverting and non-reverting batch modes assert Safe outcome and atomic state |
| FUND-11 | Orders returns WETH and USDC only to Asset under operator authority; arbitrary receiver and token fail; return does not refund the spent funding budget | F: both tokens return to Asset; other receivers fail and budget remains spent |
| FUND-12 | Public funding wraps and transfers once; partial runs resume recorded transactions without double funding | L: actual FundSepolia wrap confirmed, proxy interrupted before transfers, Foundry --resume sent only the three remaining calls. Canonical nonces 274–277, exact raw-unit balance deltas, unchanged budgets/Safe nonces and complete-run duplicate refusal passed [s50] |

## C. Typed CoW orders and signer

Basis: operator and recovery signer restrictions, lifetime and cancellation [s3][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| ORD-01 | WETH→USDC and USDC→WETH; sell and buy kinds; fill-or-kill and partial fills; exact recipient and signed order owner; classify same-token orders against the intended specification | F: both directions, kinds and fill modes pass; same-token acceptance is recorded |
| ORD-02 | Fresh quote uses Orders as owner and the intended receiver; request, returned order and submitted typed fields agree | L: corrected fresh sell quotes retain total sellAmountBeforeFee by adding the quote fee before setting order feeAmount to zero. Ordinary, recovery and reverse orders bind the intended owner/receiver/minimum and settle under their exact submitted UIDs [s43][s44][s46] |
| ORD-03 | Signer runs as the required delegatecall from Orders; CALL, wrong signer target and Asset execution fail | F: required delegatecall succeeds; CALL, wrong target and Asset signing fail |
| ORD-04 | Operator duration: zero, minimum, 90-day boundary and one second over; signer requires validTo strictly before timestamp + validDuration; test just below/equal/above, and expired-order signer acceptance separately from settlement refusal | F: minimum/maximum durations, strict expiry boundary and expired settlement refusal pass |
| ORD-05 | Unknown sell/buy tokens, wrong receiver, zero amounts, unsupported kind, nonzero appData and wrong balance modes fail for the expected reason | F: each listed typed field fails before presigning |
| ORD-06 | Fee parameter at zero, boundary and one unit over; order fee below/at/above its proportional ceiling, raw-unit rounding and arithmetic limits; a lower fee is valid, not a field mismatch | F: zero/100/101 bp, rounding boundaries, below/at/above ceiling and overflow pass |
| ORD-07 | Presign UID binds chain, settlement domain, owner, tokens, amounts, expiry and receiver; changing any signed field invalidates it | F: independent EIP-712 chain and verifying-contract domains and all 12 typed-field mutations select unpresigned UIDs; original marker remains set [s37] |
| ORD-08 | Operator cancels its allowed orders; Emergency cancels operator and recovery orders; repeated cancellation has a defined result | F: operator and Emergency cancellation, recovery cancellation, repeated unsign, unrelated-order isolation and exact settlement refusal pass. Public cancellation and API semantics also passed [s30][s32][s35][s36][s37] |
| ORD-09 | Wrong order cancellation cannot cancel a different UID; cancel after a partial fill blocks the remainder; re-sign semantics for the same UID are explicit | F: UID isolation, partial-fill cancellation and re-sign behavior pass |
| ORD-10 | Existing signed orders remain executable after permission revocation until explicitly cancelled, expired or blocked by approval; prove the distinction by attempted settlement | F: a signed partial order settles after permission revocation; cancellation then blocks its remainder |
| ORD-11 | Submit market and resting limit orders through the public API; observe status, rejection, expiry, partial fill, cancellation and settlement UID | L: taking quoted SELL/BUY and fully funded resting-limit paths pass. Resting observations span 96 seconds, followed by cancel/full return and exact settlement refusal; prior rejection, expiry and partial/full fills retain evidence. API-reported commit always serializes legacy class as limit, so class market is not a valid expectation [s43][s46][s51][s53][s55] |

ORD-04 and ORD-06 must use the pinned signer's exact expiry comparison and fee calculation.
The fee parameter is a ceiling relative to the sell amount, not a requirement that two fee fields be equal.
Derive the raw-unit boundary independently from that source before implementing the new tests [s13].

## D. ComposableCoW, fallback handler and TWAP

Basis: only TWAP at launch, timestamp context and bounded schedule [s3].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| TWAP-01 | Correct handler, timestamp factory, empty context data, dispatch and start-at-creation produce a valid order | F: shared signature case and settlement case |
| TWAP-02 | Reject another handler, factory, start time, unexpected data, dispatch flag and malformed staticInput; stop-loss stays forbidden | F: shape/dispatch variants pass; `test_TWAP_alternative_creation_roots_and_guard_setters_are_denied` blocks create/root/context/guard bypasses for both roles, and `test_TWAP_stop_loss_payload_cannot_use_pinned_or_foreign_handler` rejects StopLoss-shaped input without registry/context changes [s52] |
| TWAP-03 | Daily schedule: minimum parts, 90 parts at one day, plus one part and plus one second; calculate final end independently | F: daily minimum, 90-part limit, plus-one part and spacing boundary pass |
| TWAP-04 | Weekly schedule: 12 parts at seven days; just-over boundaries; reject combinations beyond both allowed branches | F: 12-part weekly limit, plus-one part and spacing boundary pass |
| TWAP-05 | Before first part, exact interval, just before/after interval, skipped intervals and after the final part; no future part or replay can settle | F: before-first and after-final exact errors, interval boundaries, skipped parts and stale-signature replay pass [s37] |
| TWAP-06 | Each part has the expected amount, receiver, expiry and UID; two parts settle through the actual Safe fallback/domain verifier | F: all 104 parts of minimum, daily and weekly schedules match independently constructed fields and UIDs at both interval edges; each signature validates. Two-part settlement also passes [s37] |
| TWAP-07 | Changed order hash, owner, domain, staticInput, proof and stale cached signature fail with the intended verifier error | F: existing field/domain mutations plus changed Merkle proof fail generation, signature verification and settlement at the intended layer; failed settlement preserves balances and fill state [s37] |
| TWAP-08 | Operator and Emergency removal each disable generation and cached-signature settlement; unrelated order remains valid | F: both removal roles make cached signature verification and settlement revert SingleOrderNotAuthed; no debit or fill occurs and a distinct unrelated order still settles [s37] |
| TWAP-09 | Duplicate salt/params, remove then recreate and several simultaneous TWAPs have explicit identity and cancellation semantics | F: same-block duplicate keeps UID and signature valid; later duplicate refreshes context and invalidates the old signature. Existing simultaneous and remove/recreate cases also pass [s37] |
| TWAP-10 | Insufficient balance or zero relayer approval blocks settlement without consuming a part; recover/retry without double fill | F: missing balance and approval preserve fill state; restored prerequisites permit one fill |
| TWAP-11 | Public watcher/order submission discovers and submits each part; save both actual settlement receipts and cancellation state | L: the watcher submitted both parts; both UIDs fulfilled with actual settlement receipts. A separate TWAP was removed before its next part; cached EIP-1271 fails before and after restart. API metadata is independent of registry removal [s30][s33] |

## E. Settlement and relayer approvals

Basis: real settlement outcomes and approval restoration by owner authority [s3][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| SETTLE-01 | Authorized solver settles an exact presigned order; Asset receives the buy token and filledAmount updates | F: synthetic-liquidity market/limit case |
| SETTLE-02 | Price below the signed limit fails with no fill or sell-token debit; exact limit succeeds | F: market/limit case |
| SETTLE-03 | Unknown solver, unsigned/cancelled/expired order, overfill and replay fail at the expected layer | F: existing authorization, cancellation, expiry and replay cases plus sell/buy overfill before and after a partial fill pass; overfill leaves balances and fill unchanged [s37] |
| SETTLE-04 | Sell/buy and partial/full orders account for executed amount, fee, rounding, remaining amount and receiver balance | P: fork covers both directions/kinds, partial/full, legacy fees and nonzero-remainder rounding. All seven public fills reconcile 14 protocol fees, network-fee equations and settlement-buffer transfer/balance ledgers. Six SELL fills use improvement-bound priceImprovement; BUY uses its volume cap. Zero improvement, cap equality, other unobserved combinations/policies and weekly payout remain open [s51][s53][s54][s59] |
| SETTLE-05 | Missing balance and missing approval each fail without changing filledAmount or balances; restored prerequisites permit one fill | F: both failures preserve state and retry succeeds once |
| SETTLE-06 | Both tokens' approvals can be zeroed only to the configured relayer; positive amount, another spender and operator approval fail | F: both tokens, five spender classes and zero/one/max amounts pass; Committee cannot approve and Emergency can only zero the relayer allowance [s37] |
| SETTLE-07 | Voting restores the exact approval; Emergency/Committee cannot; recovery transfers still work while approval is zero | F: both tokens transfer to Agent with zero relayer allowance; owner restores the exact amount and unauthorized approval paths fail [s37] |
| SETTLE-08 | Public settlement receipt matches submitted UID, execution amounts, fee, receiver and final API status | L: both TWAP parts plus corrected ordinary, recovery and reverse Trades match UID, owner, amounts, zero signed fee and exact token deltas. API status is fulfilled and competition-by-transaction includes each new UID [s33][s43][s44][s46] |

## F. First-loss shares and queues

Run every applicable case separately for test USD and test ETH shares.
These are permission and lifecycle checks on synthetic queues, not Earn economics [s4][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| FL-01 | Shares reference the correct queue; queue/share/claim-asset/controller relationships match the manifest and have no cross-asset substitution | F: both share/queue/asset/controller graphs match the stand |
| FL-02 | Committee redeems each share, the queue receives the requested shares, and claim after fixture settlement credits Agent by the requested amount | F: both-assets redeem/claim case; public USD and ETH each completed 3e18 redeem, controller settlement and claim to Agent with exact queue/share/supply state [s34] |
| FL-03 | Wrong receiver fails before claim; direct share transfer, approve and burn by Committee fail; Emergency has no share path | F: both shares reject direct routes and wrong receivers; Emergency has no redeem path |
| FL-04 | Zero request, amount at balance and excess; multiple requests in one timestamp and different timestamps have defined accounting | F: request boundaries and same/different-timestamp accounting pass |
| FL-05 | Claim before settlement, duplicate/empty/out-of-order timestamps, double claim and partial timestamp sets cannot overpay; a zero return is not incorrectly required to revert | F: pre-settlement, duplicate, empty, out-of-order and repeated claims preserve exact payout |
| FL-06 | Only the fixture controller settles; settle twice/wrong account/wrong timestamp fails; each share changes no other queue | F: only controller settles; wrong timestamp, wrong caller and repeat fail for both queues |
| FL-07 | Pending redeem and claim survive Asset stop, Voting cancellation of a separate burn motion, restart and later claim; First-loss state remains independent | F: both pending redeems survive Voting cancellation of a separate burn motion and Asset stop/restart; subsequent settlement and claim preserve expected supply and payout [s37] |
| FL-08 | A failed claim or burn leaves shares, supply, queue requests and claimable amounts in the expected unchanged state | F: both shares retain motion, supply, request, claimable and balance state after oversized burn or illiquid claim failure; restoring liquidity permits exactly one claim [s37] |

## G. Burn factory, Easy Track and executor

Basis: trusted caller, objection window, script hash and burn-only executor role [s2][s4].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| ET-01 | Factory is allowlisted and pinned to Committee, the First-loss modifier and both shares; only Committee creates a burn motion | F: exact factory wiring, allowlist and creator restriction pass |
| ET-02 | Wrong share, zero amount, malformed data, unregistered factory and excessive burn fail at the correct factory/enactment stage | F: all listed factory/enactment failures are exercised |
| ET-03 | Each share burns after the configured window; early enactment fails; supply and First-loss balance decrease exactly | F: both shares balance/totalSupply assertions; public motions 0 and 3 each burned 2e18 after the window, with early refusal pinned to the creation block [s29] |
| ET-04 | Time just before/exactly at/after enactment boundary; unchanged payload succeeds, substituted payload/script fails | F: before/exact boundary, valid enactment and substituted input pass |
| ET-05 | Objection below/exactly at/above threshold; no-weight account; multiple objectors; repeated objector and snapshot-weight semantics | F: two named MAIN-08 cases test the exact raw-unit boundary, two-objector accumulation, duplicate refusal and post-snapshot transfers through real Easy Track/LDO for both shares. The Sepolia mock's current-balance cases remain separate [s78] |
| ET-06 | Creator cancellation and Voting cancellation; unauthorized cancellation, repeated cancellation and enact-after-cancel fail | F: creator, Voting, unauthorized, repeat and post-cancel fork paths pass; public rejected/cancelled USD and ETH motions also refuse enactment after the window [s29] |
| ET-07 | Re-enactment, concurrent motions competing for shares and failed burn cannot silently duplicate a motion; create a motion, remove its factory, then test enactment and record whether removal stops pending actions | F: competing/failed motions and factory removal are tested; an existing motion still enacts after removal |
| ET-08 | Executor accepts only Easy Track; valid CallsScript executes; malformed spec/length, failing chunk and mixed batch have explicit atomicity | F: caller, malformed scripts, valid CallsScript and failing-chunk atomicity pass |
| ET-09 | Caller, factory input and script are bound at creation/enactment; Committee cannot use first-loss-burn directly | F: bound caller/input/script and direct burn-role refusal pass |
| ET-10 | Pending burn is cancelled through Voting before restart and remains unenactable after restart | F: public pending burn motion 6 was cancelled through test Voting while Asset operator was disabled; it remained unenactable after restart [s30] |

The stand's objection mock reads current token balances and does not enforce one objection per objector.
Its snapshot date is not proof of historical voting weight.
ET-05 cannot close the corresponding production Easy Track requirement [s4][s10].
The mock checks factory allowlisting at creation, not again at enactment.
ET-07 must distinguish this behavior from the intended production revocation procedure [s2][s10].

## H. Asset governance and owner authority

Basis: seven-role graph, no Orders governance, scoped grants and period floor [s1][s2][s5][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| GOV-01 | Executor can scope/revoke targets and allow/scope/revoke functions only for asset-operator; round-trip preserves unrelated functions and conditions | F: every target/function admin path and options round-trip pass |
| GOV-02 | Every admin selector rejects old, emergency, First-loss and Orders keys, across every protected Safe and module target | F: five admin selectors cross all 11 key values and ten targets; all 545 forbidden combinations fail in Roles and preserve account configuration [s40] |
| GOV-03 | None/Send options follow specification; DelegateCall/Both fail for every grant selector; pre-existing delegatecall cannot be widened | F: None/Send replace existing DelegateCall/Both for allowFunction and scopeFunction across eight combinations; delegatecall then fails while CALL succeeds; governance widening attempts fail [s40] |
| GOV-04 | Membership, default role, owner/avatar/target, adapters, Safe modules, guard, fallback and singleton cannot be changed through governance | F: existing membership/owner/avatar/target/adapter/module/guard refusals plus fallback setter, legacy upgrade selector and module delegatecall probes fail in Roles; configuration and singleton storage remain unchanged [s40] |
| GOV-05 | Both known budget keys allow the intended period/balance changes; foreign keys, period below floor and wrong timestamp behavior are rejected or specified | F: both key and period restrictions pass; zero/past/current/future/max timestamps are specified. Max uint64 is accepted but budget use panics on timestamp-plus-period overflow; Voting correction restores transfer without affecting the other key [s40] |
| GOV-06 | Orders has neither governance nor approval-management role; executor cannot gain owner authority by another call route | F: Orders rejects governance/approval administration; executor also fails direct owner, Safe hash approval, module CALL/delegatecall and Voting/Agent routes with exact errors and unchanged configuration [s40] |
| GOV-07 | Governance operates only while its Asset modifier is enabled; after disable, Voting alone performs the reviewed owner restoration | F: disabled modifier rejects governance; Voting restores the reviewed state |
| GOV-08 | Full governance motion → factory → executor path validates script and enactment; executor impersonation alone is insufficient | D: suitable governance factory absent from this stand |
| GOV-09 | Direct Voting owner path succeeds; non-owner cannot drive Voting; failed owner batch is atomic; owner restoration never restores a later revoked permission by accident | P: owner/non-owner and atomic batch paths pass. The new fork case proves that an old owner grant re-arms a later revocation, while selective restore preserves it. Pre-signature detection/refusal of an outdated restore remains open [s57] |
| GOV-10 | Create a policy-expansion motion, stop the Asset modifier before enactment, then restart: an uncancelled pending motion must be identified as a reactivation hazard; cancel it before restoring execution | D: production lifecycle needs the missing governance factory; burn cancellation is not a substitute |

## I. Emergency, cancellation and restart sequences

Basis: stop-only emergency authority and DAO restart [s1][s3][s4][s8].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| EM-01 | Asset switch disables only the intended operator modifier; safety still executes; wrong prev/module cannot disable another control | F: switch, safety, wrong predecessor and module paths pass |
| EM-02 | Asset and Orders revokeTarget and revokeFunction each stop the selected operator permission; unrelated permissions remain usable | F: both accounts revoke target/function and preserve unrelated permission paths |
| EM-03 | Emergency cannot grant, enable, change members, increase approvals or create a budget; confirm each selector and key | F: both accounts refuse all seven keyed grant/member/budget selectors across 13 key values and four modifiers, both membership booleans, ownership probes, all five Safe/four module enable pairs and both tokens positive approvals; account configuration and both budgets remain unchanged [s41] |
| EM-04 | Emergency transfers each listed token from Asset to Orders/Agent and from Orders to Asset/Agent; all other receivers fail | F: both tokens and accounts check 21 recipients; eight allowed routes execute and 76 forbidden calls fail at the receiver condition with no balance change [s40] |
| EM-05 | Recovery signer buys only allowed recovery tokens, pays Agent and respects the one-day bound | P: WETH→USDC path and one-day bound pass; USDC→WETH is refused; USDT is absent from this stand |
| EM-06 | Stop new operator calls, cancel resting presigns/TWAPs, handle pending burn motions, recover assets, zero approvals, then verify no executable leftovers | L: public cancellation cases, the corrected stopped recovery settlement to Agent, sweeps, zero approvals, exact Voting restore and Committee smoke passed. Final inventory has no executable unfilled presign, active TWAP, pending motion or pending claim [s30][s44][s46] |
| EM-07 | Test alternate stop orderings: zero approval before cancel, revoke before cancel, switch while a burn is pending, repeated stop, interrupted recovery and retry | F: both token directions cover zero/revoke before cancel, repeated stop, pending burn enactment/cancellation and restart in `test_EM_zero_and_revoke_before_cancel_repeated_stop_and_retry` and `test_EM_repeated_switch_pending_burn_cancel_and_restart`; public interrupted recovery and resumed restore passed [s30][s47] |
| EM-08 | Selective Voting restore enables only reviewed modules, targets and approvals; Committee operates again; cancelled signatures/motions stay invalid; repeat stop/restart and execute a new settlement | F: named fork tests cover repeated cycles and a new settlement. Public selective restore recovered the exact module set, four targets and two prior approvals; policy returned from five planned differences to zero, smoke calls passed and cancelled states stayed unusable [s30][s31] |
| EM-09 | Already-filled orders cannot replay after restart; already-claimed queues cannot pay twice; frozen governance cannot grant a bypass during recovery | F: combined sequence fills an order and claims both queues, stops governance and approval, refuses a governance bypass, restores through Voting, rejects filled-UID replay, pays zero on repeated claims and settles a fresh UID [s41] |

## J. UI, declarations, scripts and evidence handling

Basis: usable signing path, honest execution status and recovery of interrupted runs [s5][s6][s8][s9].

| ID | Required check and acceptance | Coverage |
|---|---|---|
| OPS-01 | Safe and Zodiac identify the correct chain, vault, role, caller, token, recipient, amount and operation before signature | P: browser shows chain, vault, role and caller route; wallet is disconnected and Pilot is absent. Valid payload amount/recipient review and browser signing remain open [s38] |
| OPS-02 | UI limitations for Nor/WithinAllowance are explicit; RPC amounts are checked at the same block; Unsupported Condition never counts as a policy failure or pass | L: governance Nor renders Unsupported Condition with operator 3 JSON; funding WithinAllowance renders its key. Both numeric budgets were read at the same pinned block 11987022; the UI supplies no numeric balance or block tag [s38] |
| OPS-03 | Imported builder payload decodes to the reviewed call; any MultiSend envelope contains only the intended calls and operation types | P: direct Committee payload and two-call funding/return reference pass exact simulation, balance/budget/nonce/event checks and failed-return rollback. UI-produced envelope remains open [s78] |
| OPS-04 | Stale nonce, concurrent proposal, old cancelled workspace proposal and wrong owner route are detected before signing | P: the old Outstanding proposal simulates TargetAddressNotAllowed before signing. Stale nonce and concurrent proposal detection remain open; no proposal was changed [s38] |
| OPS-05 | Fresh RPC diff detects changed membership, role, condition, target, allowance configuration, owner, guard or module; budget consumption is not misclassified as drift | F: public policy reconstruction detected four target revocations and one disabled module, then zero after restore. The local fork now detects owner, threshold, both guards and extra-module mutations at exact paths; all 44 diff regressions pass, including consumption/configuration separation. Production alerts and signer sets remain separate [s30][s58] |
| OPS-06 | Round-trip compile/serialize/resolve preserves Nor, recipients, limits, keys and live allowance storage; UI metadata changes have no unintended on-chain calls | P: current local serialize/compile preserves 63 reviewed calls and live allowance values; final payload matches. Hosted UI resolve/metadata acceptance remains open [s30] |
| OPS-07 | Timeout, invalid API result, stale cache, partial snapshot and lost response never produce a false success; retain previous evidence and identify its age | P: publisher/snapshot regressions and public RPC lost/drop/timeout/replacement reconciliation pass. UI invalid-result, stale-cache and partial-snapshot cases remain open [s56] |
| OPS-08 | Receipt status 1 with Safe failure is rejected; compare canonical chain, sender, destination, input, nonce, block/hash, logs and resulting state | P: 124 saved/user-identified public receipts match canonical headers/root fields; 85 Safe nonce-derived hashes match ExecutionSuccess and seven solver roots are checked. Complete historical state-delta/request-linkage variants remain separate [s46][s51][s53][s55][s56] |
| OPS-09 | Broadcast timeout after mining, dropped/replaced transaction, duplicate retry and partial batches resume exactly once without resetting policy/budgets | L: controlled lost submission resumes the same raw once; actual post-mining HTTP timeout needs no resend; legacy/EIP-1559 replacements execute once and reject unreconciled receipt mappings. Completed-run retries refuse. Public funding resumes its remaining three calls, and offline guards cover all 16 receipt subsets. Budgets/policy are not reset; arbitrary real-node eviction is not claimed [s48][s50][s56] |
| OPS-10 | Wrong branch/dirty/unpushed state, wrong workspace/chain, CI and missing authorization fail applicable guards; keys never enter outputs | P: 21 actual local CLI/recipe scenarios use real temporary Git state, blocked transport and test-only credentials. Wrong chain is refused by the publisher and the funding script dry-run. A real hosted apply/workspace session and public signer boundary remain unexercised [s60] |
| OPS-11 | Every run checks exact named cases, no missing/skipped tests, matching source/payload hashes and canonical block; failed preparation invalidates old success | F: all 88 names and 15 suites pass at 11988436. Saved payload recompiles to 63 calls with same-block funding readback; exact bytes and 12 source/template/lockfile inputs plus manifest stay hash-bound. The old stale payload was refused before Forge and removed prior success. Canonicality and independently derived USDC approval still pass [s45][s47][s49][s52][s54][s55][s56][s57][s61] |
| OPS-12 | Each important configuration change and order lifecycle generates the expected alert; duplicate/reorg/outage handling and notification destination are exercised | D: monitoring integration not exercised by this stand's contract suite |
| OPS-13 | Teardown inventories pending orders/motions/claims, sweeps intended balances and disables only reviewed modules; evidence remains reproducible | L: final signed UIDs are expired or fully filled, seven motions terminal and both queues clear at 33 timestamps. All 124 Orders Safe traces yield four unregistered conditional identities and zero Merkle root. Only reviewed approval pairs remain; Orders/Agent balances are zero after recovery and reverse replenishment [s46] |

## K. Launch integrations absent from the reduced Sepolia profile

These remain required in the full system plan.
Use a mainnet fork or the owning deployment; do not label a synthetic Sepolia case as coverage of them.
Existing mainnet harness tests can supply partial evidence after their exact assertions are mapped [s4][s5][s6][s7][s9].

| ID | Integration and required paths | State |
|---|---|---|
| MAIN-01 | ETH↔WETH: wrap/unwrap, value and amount boundaries, correct balance deltas, missing ETH/WETH, operator/emergency differences, stop/restart | P: five named WETH fork cases cover zero/one/full balance, shortage/excess/max, exact events/backing, policy vs protocol refusal, legacy short-ABI behavior and stop/recovery/restart. The committed harness uses legacy keys and EOA role holders; the production role graph remains unverified [s62] |
| MAIN-02 | Lido submit: operator and Emergency, zero referral, nonzero value, minted shares/rebase-aware accounting, wrong referral, pause/failure and recovery | P: six real Lido cases cover both roles, exact internal shares/post-submit balances, one-wei/full-balance boundaries, zero/missing ETH, forbidden routes, actual pause/resume with fork-only ACL grants, stake-limit exhaustion/refill and stop/restart. Production role/pause authority and full oracle report/rebase/fee distribution remain open [s63] |
| MAIN-03 | stETH↔wstETH: wrap/unwrap, approval ceiling and zeroing, conversion rounding, receiver custody, operator/emergency differences and restart | P: five real wstETH cases check exact shares, conversion dust, Safe/backing custody, approval boundaries/zeroing, missing allowance/balance rollback, both unwrap roles, forbidden routes and stop/recovery/restart. Production role/signing graph and a full oracle-induced rebase cycle remain open [s64] |
| MAIN-04 | DAI↔USDS converter: both directions, fixed approval ceilings, exact recipient, zero/maximum/excess, paused/upgraded dependency, emergency exit | P: seven real converter cases cover both routes, exact balances/supply/Vat RAD, zero/one/full/approval-limit amounts, approval boundaries/zeroing, failed-call rollback, forbidden receivers/operations, Emergency return, stop/restart and real USDS mint-permission loss/rely recovery. Five known actors fail DaiJoin cage; no positive cage is claimed. Production role/signing graph and replacement USDS implementation behavior remain open [s65] |
| MAIN-05 | sUSDS: deposit, redeem and withdraw; receiver/owner pins, share/asset rounding, max limits, approval budget, failed-call rollback and emergency exit | P: eight real sUSDS cases cover exact deposit/redeem/withdraw rounding and custody/events, zero/one/partial/full/max boundaries, approvals and complete key accounting, forbidden owners/receivers/routes, atomic failure with pending drip, one-second yield and stop/Emergency exit/restart. Production role/signing graph, replacement implementation and longer-period rate/governance scenarios remain open [s66] |
| MAIN-06 | EarnUSD and EarnETH deposits: each supported asset, approvals, request and any deployed cancellation path, pricing/settlement, claim to Asset, proof/caller fields, caps, queue pause and insufficient liquidity; record absent API paths rather than inventing them | P: eight real USDC/EarnUSD and wstETH/EarnETH deposit cases cover exact requests/cancel/refunds, actual early/eligible Oracle→Vault→Queue→Hook reports, exact allocated/active shares, both claimers, no double claim, auto-claim, referral/open-root behavior, proof/account independence, vault-cap boundary, pause/whitelist, atomic refusals and stop/restart. Controlled proof/cap parameters and grants exist only on the fork. Further amount/fee and hook/liquidity failures, production role graph and report consensus/valuation remain open [s67] |
| MAIN-07 | EarnUSD and EarnETH redemptions: normal Asset positions and separate First-loss positions, pricing/report delay, multiple requests, claim variants, liquidity shortage, emergency completion and no double claim | P: sixteen Asset and four controlled First-loss cases cover real request/report/batch/claim ledgers, delays, multiple timestamps, bounded FIFO batches, replay, receiver/role pins, restrictions, oracle rollback, Emergency completion, fee conservation/exemption/extremes, rounding and zero-net cleanup. A USDC blacklist causes the real hook path to fail at token transfer, roll back and retry. Organic hook/subvault failure, production policies/signing and external valuation/consensus remain open [s68][s69][s70][s71][s72] |
| MAIN-08 | Real First-loss burn: trusted factory, exact supply/share accounting and motion lifecycle; do not substitute the stand's unrestricted controller-mintable token | P: eight cases exercise both real Earn share tokens through the deployed Easy Track executor, exact window, objection thresholds and snapshot transfers, creator/Voting cancel, failure recovery, exact burn accounting and replay refusal. The factory and First-loss role graph are local fork fixtures registered by impersonating Voting; production factory registration and signing remain open [s73][s78] |
| MAIN-09 | Treasury funding: stablecoin and stETH registries, allowed assets/recipient, shared payment permissions, trusted creator, monthly enactment limits, objection/cancel, paused payments, owner-only limit changes and enabling vote | P: live Voting, Easy Track and Finance cover USDC/stETH/USDS top-ups, payment permissions, trusted creator/recipient, Voting-only limit changes, cancellation, LDO objection, concurrent monthly-limit enforcement and calendar rollover, plus paused-USDC rollback/retry. Registry deployments and limits are local stand-ins; production registry values remain open [s74][s75][s76] |
| MAIN-10 | Governance templates and exit-governance: each in-scope template's creation/enactment validation, narrow target/selector/receiver, complete-tree removal, stale-state recovery, emergency exit and forbidden admin/delegatecall | D |
| MAIN-11 | Full CoW launch token matrix: allowed sell/buy/recovery pairs, USDC and USDT recovery, decimals, rounding and token-specific approval/transfer behavior; non-launch tokens refused | P: 30 distinct pairs to Asset, 10 stablecoin-destination pairs to Agent, decimals and exact per-token allowance deltas pass through live Settlement on a mainnet fork. Production Orders policy, non-launch refusal and remaining amount/fee/failure variants remain open [s78] |
| MAIN-12 | Committee screening at cap lift: correct guard/build, no modules or bypass, one-use approval tied to full transaction/nonce, no replay/standing approval, outage, ten-day removal path and independent Emergency/Voting paths | D |
| MAIN-13 | Signing UI and screening: approval request/state, pending approval latency alert, rejection, timeout, changed payload and non-vault Committee duties | D |
| MAIN-14 | Production signer sets and thresholds, Voting/Dual Governance/Agent ACL boundaries, enabling-vote atomicity, singleton/module/guard alerts | D |
| MAIN-15 | Attested valuation, funding headroom, caps, buffer and reporting: fixed source block/price/rule version, stale/missing data, Asset+Orders accounting, First-loss exclusion and actionable alerts | D |
| MAIN-16 | Lido Lend: onboarding motion, Morpho-compatible lifecycle and emergency exit after the actual target exists; separate post-launch gate | D: post-launch |

Excluded positive flows: LDO, Lido withdrawal queue, stop-loss, Stonks/router swaps, Aave, sDAI, insurance-fund roles/third registry, token and restore templates.
Keep refusal tests for forbidden calls and selectors.
Do not revive superseded ADR decisions to fill this checklist [s2][s3][s4][s7].

## Review evidence

Coverage review findings and their dispositions are in the [results](../research/sepolia-test-results.md#coverage-review-findings-and-dispositions) [s78].
