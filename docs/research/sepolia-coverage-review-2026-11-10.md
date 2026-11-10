---
type: Research Note
title: Sepolia stand coverage review, 2026-11-10
description: Independent rerun of the Sepolia stand tests, a transaction-level checklist of covered cases, the open gaps and the cases that can be tested now.
tags: [sepolia, testing, coverage, review, evidence]
status: draft
review_status: slop
valid_as_of: 2026-11-10
stale_after: 2026-11-19T14:38:00Z
generated:
  by: claude-code/fable-5.2
  at: 2026-11-10T12:39:52Z
verified: []
sources:
  - id: s1
    resource: /specs/sepolia-setup-checklist.md
    title: Coverage obligations, their identifiers and their recorded states
  - id: s2
    resource: /specs/sepolia-test-plan.md
    title: Test cases, named tests and the table of public transactions
  - id: s3
    resource: /research/sepolia-test-results.md
    title: Recorded runs, findings and limits
  - id: s4
    resource: /specs/sepolia-stand-plan.md
    title: Stand accounts, owners, fixture values and the deployment record
  - id: s5
    resource: /specs/sepolia-role-key-migration.md
    title: The four account-specific role keys and the migration procedure
  - id: s6
    resource: urn:clutch:evidence:2026-11-10:sepolia-review-reruns
    title: Local checks and two fork runs of the current-stand suite, at blocks 11992758 and 12104452
  - id: s7
    resource: urn:clutch:evidence:2026-11-10:sepolia-review-chain-reads
    title: Receipts of 239 transactions, an event scan of two block ranges, state reads at block 12104452 and Safe signature decoding
  - id: s8
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/test/SepoliaCoverage.t.sol
    title: Coverage tests of the stand, 73 cases
  - id: s9
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/test/SepoliaCurrentStand.t.sol
    title: Current-stand tests and the settlement fixture, 8 cases
  - id: s10
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/test/SepoliaStand.t.sol
    title: The seven original stand drills
  - id: s11
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/test/utils/SepoliaStandFixture.sol
    title: Fork setup, the skip gate and the manifest path
  - id: s12
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/scripts/sepolia_test_current.py
    title: Runner of the fork suite - required test names, input hashes and block checks
  - id: s13
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/src/mocks/MockEasyTrack.sol
    title: Mock Easy Track - objection weight and motion states
  - id: s14
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/src/mocks/SepoliaStand.sol
    title: Test tokens, test shares, redeem queues and the burn factory
  - id: s15
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/Justfile
    title: The checks that CI runs
  - id: s16
    resource: https://github.com/lidofinance/clutch/tree/24f7a52f50b7041c9bcfe2252932542a11b7f22b/.github/workflows
    title: CI workflows
  - id: s17
    resource: https://github.com/lidofinance/clutch/blob/24f7a52f50b7041c9bcfe2252932542a11b7f22b/sepolia.just
    title: Sepolia recipes - local checks, the fork runner and the guarded public writes
---

# Sepolia stand coverage review

This note is an independent review of the Sepolia stand tests on branch `testnet/sepolia`, commit `24f7a52`.
It answers three questions.
Which cases have a test and a public transaction?
Which cases have no coverage?
Which cases can be tested now?

Related pages: [coverage checklist](../specs/sepolia-setup-checklist.md) · [test plan](../specs/sepolia-test-plan.md) · [recorded results](sepolia-test-results.md) · [stand plan](../specs/sepolia-stand-plan.md)

## Answer

- The fork suite passes 88 of 88 tests at the recorded block `11992758` and at block `12104452` of 2026-11-10. The local checks pass: 47 Python tests, 132 policy tests and the type check [s6].
- All 65 transactions that the test plan cites are on Sepolia with status `1`. Their senders, targets and events agree with the plan. The 171 setup transactions also have status `1` and no Safe failure [s2][s7].
- The stand did not change between 2026-10-25 and 2026-11-10. The Committee Safe nonce is `51` and both funding budgets have the recorded values [s3][s6][s7].
- The stand has no coverage of UI signing, independent signers, thresholds above 1, the governance motion path, the screening guard and monitoring [s1][s7].
- The two emergency drills contain 45 transactions that the test plan does not cite. This note lists them [s2][s7].
- No Sepolia check runs in CI. The evidence and three test inputs are in the git-ignored `cache/` directory [s8][s12][s15][s16].
- Eleven cases can be tested on the current stand without a change. One of them, the real budget refill, becomes possible at `2026-11-19T14:38Z` [s7].

Contents:

1. [How to read this note](#how-to-read-this-note)
2. [Test runs](#1-test-runs)
3. [Covered cases](#2-covered-cases)
4. [Cases without coverage](#3-cases-without-coverage)
5. [Cases that can be tested now](#4-cases-that-can-be-tested-now)
6. [Review findings](#5-review-findings)
7. [Method](#method)

## How to read this note

### The stand

The stand is a reduced copy of the Clutch account graph on Sepolia, chain `11155111`.
The stand owner deployed it on 2026-10-20 [s4][s7].
The Safe, Roles and CoW contracts are the real deployed contracts.
Voting, Agent, Easy Track, the share tokens and the redeem queues are test contracts [s4][s14].

| Account | Owner on the stand | Function |
|---|---|---|
| Committee Safe | Controller, 1 of 1 | The operator. It moves tokens from Asset to Orders, signs CoW orders, redeems First-loss shares and creates burn motions [s4] |
| Emergency Safe | Controller, 1 of 1 | The stop authority. It disables the operator, cancels orders, moves tokens to the Agent and sets relayer approvals to zero. It cannot grant a permission or restart [s4][s8] |
| Asset Safe | Test Voting | Holds the treasury tokens. The operator modifier and the safety modifier act on it [s4] |
| Orders Safe | Test Voting | Holds the tokens that are for sale. It signs CoW orders and holds the approvals to the CoW Vault Relayer [s4] |
| First-loss Safe | Test Voting | Holds the two test share tokens [s4] |
| Test Voting | Controller | Replaces the DAO vote. It is the owner path that restores permissions after a stop [s4] |
| Test Agent | Controller | The recovery recipient [s4] |
| Mock Easy Track and its executor | Controller | Burn motions with a 60-second objection window and a threshold of 1 test VOTE [s4][s13] |
| Controller | One externally owned account, `0x4CAE8fd384bbe8dec68CdFbC2CbE4b398902E03c` | Owns both 1-of-1 Safes and controls every test governance contract [s4] |

Seven roles connect these accounts [s5][s8]:

| Role key | Member | Modifier | Permission |
|---|---|---|---|
| `asset-operator` | Committee Safe | Operator, on Asset | Transfer WETH and USDC to Orders, inside the budgets `orders_weth` and `orders_usdc` |
| `governance` | Easy Track executor | Operator, on Asset | Change the `asset-operator` permissions and the two budgets |
| `asset-emergency` | Emergency Safe | Safety, on Asset | Disable the operator modifier, revoke permissions, move tokens to Orders or the Agent |
| `orders-operator` | Committee Safe | Orders | Sign and cancel orders, create and remove TWAP orders, return tokens to Asset |
| `orders-emergency` | Emergency Safe | Orders | Cancel orders, revoke operator targets, sign a recovery order to the Agent, set approvals to zero |
| `first-loss` | Committee Safe | First-loss | Redeem shares and claim to the Agent |
| `first-loss-burn` | Easy Track executor | First-loss | Burn shares through an enacted motion |

Each budget is 1 test WETH or 1,000 test USDC for each 30-day period [s4][s7].

### Evidence levels

This note uses three levels.

- **Public transaction.** A transaction that is on Sepolia. This review read its receipt and compared the status, block, sender, target and events with the description [s7].
- **Fork test.** A Forge test that runs on a local copy of the Sepolia state at one block. It uses the deployed contracts and the real balances. It impersonates the Safes and the solver. It sends no transaction to the network [s11][s12].
- **Local test.** A Python or TypeScript test that does not read the chain. It covers scripts, guards, the policy compiler and the configuration diff [s17].

A refusal case has no public transaction.
The recorded procedure tests negative cases by simulation or on a fork [s3].
Thus "fork test only" is the planned level for a refusal.

### Identifiers and terms

The identifiers come from the coverage checklist [s1].

| Prefix | Area |
|---|---|
| `CFG` | Deployment, identities and authority |
| `FUND` | Funding, transfers and budgets |
| `ORD` | Typed CoW orders and the order signer |
| `TWAP` | Conditional TWAP orders |
| `SETTLE` | Settlement and relayer approvals |
| `FL` | First-loss shares and queues |
| `ET` | Burn factory, Easy Track and executor |
| `GOV` | Asset governance and owner authority |
| `EM` | Emergency stop, cancellation and restart |
| `OPS` | UI, scripts and evidence handling |
| `MAIN` | Launch integrations that the stand does not have |

| Term | Meaning in this note |
|---|---|
| Presign | A call that marks one order as signed in the CoW Settlement contract. The contract emits `PreSignature` |
| Unsign | The opposite call. It cancels the order on-chain |
| Fill | The settlement transaction of a CoW solver. The contract emits `Trade` |
| TWAP | A conditional order that releases one part for each interval |
| Budget | A Roles allowance that limits the transfers from Asset to Orders in one period |
| Stop | The Emergency Safe disables the operator modifier on Asset and revokes the operator targets on Orders |
| Sweep | An Emergency transfer of tokens to the Agent |
| Restart | Test Voting enables the module again and restores the targets and approvals |
| Burn motion | An Easy Track motion that burns First-loss shares after the objection window |
| Pre-validated signature | A Safe signature with `v = 1`. The Safe accepts it because the owner is the sender. It contains no ECDSA signature |

Token amounts come from event logs and state reads [s7].
WETH has 18 decimals. USDC has 6 decimals. The test shares have 18 decimals [s14].
A star (\*) marks a transaction that the test plan does not cite [s2].

## 1. Test runs

### 1.1. Runs made for this review

All runs are from 2026-11-10 [s6][s7].

| Run | Command | Result | What it shows |
|---|---|---|---|
| Local checks | `just --justfile sepolia.just check` | 47 Python tests (3, 6, 3 and 35), 132 policy tests in 10 files, type check. No failure [s6] | The scripts, guards and policy tooling work |
| Fork suite at the recorded block | `SEPOLIA_STAND_BLOCK=11992758 just --justfile sepolia.just test-current` | 88 of 88 tests in 15 suites, 0 skipped. Block hash `0x91052aab…0dead` [s6] | The recorded result of 2026-10-25 is reproducible |
| Fork suite at the current block | `just --justfile sepolia.just test-current` | 88 of 88 tests in 15 suites, 0 skipped. Block `12104452`, hash `0x50f34d3d…ab49` [s6] | The stand state is still correct on 2026-11-10 |
| Receipts of the cited transactions | `verify_txs.py` with three more hashes | 68 receipts, all status `1`, all in canonical blocks [s7] | The transactions in the test plan are real and do what the plan says |
| Receipts of the setup | `verify_setup.py` | 171 receipts: deployment 39, policy 126, funding 4, role migration 2. All status `1`, no `ExecutionFailure` [s7] | The deployment and the policy application completed |
| Event scan | `scan.py 11986840-11986910 11987270-11987380` | 33 and 31 transactions. 45 are not in the test plan [s7] | The emergency drills contain more steps than the plan lists |
| State reads | `state.py 12104452` | Claim and burn results, nonces, thresholds, owners, guards, balances, budgets, motion states [s7] | Results that events cannot show |
| Signature decoding | `signatures.py` | 115 `execTransaction` calls, each with one pre-validated signature [s7] | No public transaction used an ECDSA Safe signature |

The stored values of `orders_weth` and `orders_usdc` are equal at blocks `11992758` and `12104452` [s6].
Thus no funding transfer occurred after 2026-10-25.

### 1.2. The fork suite

The runner requires an exact set of 88 test names.
It fails if a test is absent or skipped.
It also compares the hashes of 12 source files, the manifest and the saved payload, and it checks the block hash after the run [s12].

| Suite | File | Tests | Subject |
|---|---|---|---|
| `SepoliaStandTest` | `test/SepoliaStand.t.sol` [s10] | 7 | The seven original drills: account graph, funding, order signing, TWAP, First-loss, burn motion, emergency stop |
| `SepoliaCurrentStandTest` | `test/SepoliaCurrentStand.t.sol` [s9] | 6 | Migrated role keys, USDC budget, order limits, governance limits, emergency recovery and restart |
| `SepoliaCoWSettlementTest` | same file [s9] | 2 | Settlement of market, limit and TWAP orders with a real solver address |
| `SepoliaConfigurationCoverageTest` | `test/SepoliaCoverage.t.sol` [s8] | 7 | Owners, thresholds, modules, guards, runtime hashes, the actor matrix, Safe replay |
| `SepoliaFundingCoverageTest` | same file [s8] | 9 | Budget limits, refill, receivers, failed calls, batches |
| `SepoliaOrderCoverageTest` | same file [s8] | 7 | Each typed order field, expiry, fee ceiling, cancellation |
| `SepoliaSettlementCoverageTest` | same file [s8] | 5 | Overfill, missing funds or approval, approval matrix |
| `SepoliaSettlementRoundingCoverageTest` | same file [s8] | 1 | Rounding with nonzero remainders |
| `SepoliaTwapCoverageTest` | same file [s8] | 10 | Schedules, proofs, removal, replay |
| `SepoliaConditionalEntryCoverageTest` | same file [s8] | 2 | Other ComposableCoW entry points and stop-loss payloads |
| `SepoliaFirstLossCoverageTest` | same file [s8] | 6 | Request limits, claims, denied routes |
| `SepoliaBurnCoverageTest` | same file [s8] | 6 | Factory inputs, objection window, cancellation, executor |
| `SepoliaGovernanceCoverageTest` | same file [s8] | 10 | Governance selectors, keys and targets, budget timestamps, owner restore |
| `SepoliaEmergencyCoverageTest` | same file [s8] | 8 | Emergency limits, transfer routes, revokes, restart cycles |
| `SepoliaStopOrderingCoverageTest` | same file [s8] | 2 | Different stop orders, repeated stops, pending burns |

### 1.3. Public runs on Sepolia

The dates are the block timestamps in UTC [s7].
The column "Checked" gives the number of transactions that this review read.

| Date | Run | Blocks | Checked |
|---|---|---|---|
| 2026-10-20 | Stand deployment, script `DeploySepolia` | `11955109–11955147` | 39 [s7] |
| 2026-10-20 | Policy application, script `ApplySepolia` | `11955941–11956316` | 126 [s7] |
| 2026-10-23 | Role migration to the account-specific keys, script `MigrateRolesSepolia` | `11976805–11976806` | 2 [s7] |
| 2026-10-23 | Initial funding, script `FundSepolia` | `11977287–11977292` | 4 [s7] |
| 2026-10-24 | First Committee transfer | `11985108` | 1 [s7] |
| 2026-10-24 | Order presign, admission to the CoW order book, unsign | `11985509–11986562` | 3 [s7] |
| 2026-10-24 | Two-part TWAP, TWAP cancellation, First-loss redeem and claim | `11986630–11986706` | 10 [s7] |
| 2026-10-24 | Burn motions 0 to 5 | `11986790–11986804` | 12 [s7] |
| 2026-10-24 | First emergency drill: stop, sweep, zero approvals, restart, smoke transfer | `11986846–11986896` | 33 [s7] |
| 2026-10-24 | Teardown: the Committee Safe removes the completed TWAP | `11987072` | 1 [s7] |
| 2026-10-25 | Corrected sell orders and the second emergency drill, with a recovery order to the Agent | `11987250–11987366` | 32 [s7] |
| 2026-10-25 | Lost response after mining | `11987577` | 1 [s7] |
| 2026-10-25 | Interruption and resume of `FundSepolia` | `11987645–11987648` | 4 [s7] |
| 2026-10-25 | Partial sell, buy order, resting limit order | `11987694–11987944` | 12 [s7] |
| 2026-10-25 | Submission faults: resume, timeout, nonce replacement | `11988047–11988081` | 4 [s7] |

The controller sent each transaction, except the solver settlements [s7].
One solver, `0xe40cbca4d703642778b40e1e866ebfec1e619872`, sent all seven settlements [s7].

### 1.4. Recorded runs that this review did not repeat

- The mainnet fork suites `test/Mainnet*Coverage.t.sol` and `test/EnablingVoteRehearsal.t.sol`. The results record 136 passed tests [s3].
- `SepoliaRoleMigrationTest`, the rehearsal of the role migration [s3].
- The audit of 124 receipts and 85 Safe transaction hashes [s3].
- Each claim that comes from the CoW API: order status, auctions and the protocol-fee reconciliation [s3].
- The screenshots and reads of the Zodiac UI [s3].

## 2. Covered cases

### 2.1. Cases with a fork test and a public transaction

For each row, the fork test passed in both runs of this review [s6].
The receipt of each transaction has status `1` [s7].
The identifiers come from the checklist and the test names from the test plan [s1][s2].

#### Setup and configuration

The setup creates the accounts, applies the permission policy and moves the role keys to their final names.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 1 | Deployment and policy application. At block `12104452`, the owners, thresholds, modules, guards, fallback handlers and runtime hashes agree with the manifest | CFG-01 to CFG-06, CFG-10, CFG-12 | `test_CFG_exact_owners_thresholds_modules_guards_handlers_and_runtimes`, `test_CFG_exact_initial_token_approvals_and_fixture_wiring` [s6] | 39 and 126 transactions\*. The hashes are in the local `broadcast/` records only [s7] |
| 2 | Role migration. The four new keys execute. The old keys and the keys of the other account fail | CFG-07 | `test_role_keys_reject_old_wrong_account_and_non_member` [s6] | [Asset batch](https://sepolia.etherscan.io/tx/0x9c3ce9a4ce85c36afe5bffbee8338f560d7d25c548c0560de941db606ef276a5)\* · [Orders batch](https://sepolia.etherscan.io/tx/0x86d6286fb911dcac17a20d059e9549b63d9298554d9fe007c98b858c6caa2fc5)\* [s7] |
| 3 | Initial funding: wrap, WETH to Asset, both share tokens to First-loss | none | No dedicated test. Receipts only | [1](https://sepolia.etherscan.io/tx/0xcb4ff2657c9be0901a023b8683051700c965e4d8fc1508efc00e801cd51376d9)\* · [2](https://sepolia.etherscan.io/tx/0x58f103ba23b41a146dafe1441afa4df3bccf41f1e9d4ea1accf46e99070ee975)\* · [3](https://sepolia.etherscan.io/tx/0xb3832f826c72a128c41139daa24f0eef83eb8c5c0ffc14953b87e7dbf8aba910)\* · [4](https://sepolia.etherscan.io/tx/0xf98b145b12c83d120a0936c6f11f50105c0c7b9a058c4e04908260590243cce4)\* [s7] |

#### Funding

Funding is the transfer from Asset to Orders.
The `asset-operator` role permits it only to Orders and only inside the budget.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 4 | The Committee Safe moves 0.01 WETH from Asset to Orders. The event `ConsumeAllowance` shows 0.99 WETH left in `orders_weth` | FUND-01 | `test_FUND_first_transfer_logs_nonces_and_unchanged_configuration` [s6] | [transfer](https://sepolia.etherscan.io/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec) [s7] |

#### CoW orders

The Orders Safe signs an order on-chain.
A public solver then fills it and pays the bought token to Asset.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 5 | Presign and unsign through `orders-operator`. `PreSignature` is true, then false | ORD-03, ORD-08 | `test_typed_order_presign_unsign_and_receivers` [s6] | [sign](https://sepolia.etherscan.io/tx/0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1) · [unsign](https://sepolia.etherscan.io/tx/0x84abc74edc3e375cc28e061da3668bf4e5a3c268db5e7ffa1d70d248e0fc8db2) [s7] |
| 6 | Full sell, WETH to USDC. Orders sells 0.005 WETH. Asset receives 193.554742 USDC | SETTLE-01, SETTLE-08 | `test_market_and_limit_settlement_and_cancelled_order_refusal` [s6] | [fill](https://sepolia.etherscan.io/tx/0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9) [s7] |
| 7 | Full sell, USDC to WETH. Orders sells 399.335355 USDC. Asset receives 0.010075739790126343 WETH | SETTLE-01, SETTLE-08 | `test_SETTLE_both_directions_buy_sell_partial_full_and_exact_deltas` [s6] | [fund](https://sepolia.etherscan.io/tx/0x3f38de58e991593c47a5566edb1a38e348d390eb5366cfc3e07a7dca76549fbf)\* · [sign](https://sepolia.etherscan.io/tx/0xac76e1906f264df967fcc97a71f891c975e8dcffb0bb13403b0f8221fd9c354c)\* · [fill](https://sepolia.etherscan.io/tx/0x75df586f42d7a43dc91b9ef7452aa716a1b89bdd6d1a7d64b67447f60b9751c2) [s7] |
| 8 | Partial sell. One fill of 50 USDC, then an unsign of the remainder | ORD-09, ORD-11 | `test_SETTLE_overfill_before_and_after_partial_fill_is_atomic` [s6] | [fund](https://sepolia.etherscan.io/tx/0xa11a4c13fbb78cf5edb65d0264bd803ebd52e36c60c3f85b12bdbd5fc30a77bf) · [sign](https://sepolia.etherscan.io/tx/0x0aeab6092dda720a0d7c440fc58b71dfe0ce971324a69a0aed4ac2f4a8abb418) · [fill](https://sepolia.etherscan.io/tx/0x227e8c6fd9eda88f0dac28222d59cbf03ff20054d9b4e6ace9b7ff3ea4304753) · [unsign](https://sepolia.etherscan.io/tx/0xd83ede41504d1967fd43e3d4b650b84362b6e0c445f42da576d11a3570b6303d) [s7] |
| 9 | Buy order with a fixed target. Asset receives exactly 0.001 WETH for 40.355515 USDC. Orders returns the unused 3.034684 USDC to Asset | SETTLE-04, FUND-11 | `test_SETTLE_both_directions_buy_sell_partial_full_and_exact_deltas`, `test_FUND_partial_transfers_independent_decimals_zero_and_return_no_refund` [s6] | [fund](https://sepolia.etherscan.io/tx/0x19768633e82cee24133f4fe94e66230ded0db0cbb72c70694cd330f0c70e6e55) · [sign](https://sepolia.etherscan.io/tx/0xaed7d46caf6d2c96e1f72116edb2c3e0d16cb8dd9418e469feaeca5efc2d3c33) · [fill](https://sepolia.etherscan.io/tx/0x68865292541bb369ae0a1f0aef566f5fb5d3ed64e0ca3e1b84117ef82b2c0edc) · [return](https://sepolia.etherscan.io/tx/0xcd07f14b9619ebfda1e0a52550a3974773c9263b6f2b2af2efb34f4787e4b1ef) [s7] |
| 10 | Resting limit order. Orders receives 10 USDC, signs the order, cancels it and returns 10 USDC | ORD-11 | `test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders` [s6] | [fund](https://sepolia.etherscan.io/tx/0xb50d5c705f739b3803c230c0cb0e2a857d9032f3a24db9cf1f490e24759a0962) · [sign](https://sepolia.etherscan.io/tx/0xcbac486b4a95e589bcd2446e50a6fae78b88b9bc4f245084401ab7e9e73800ee) · [unsign](https://sepolia.etherscan.io/tx/0x351c7473ec3d973e326b41675e820f36c4720d90e694bfaba2a17cdb2e90de85) · [return](https://sepolia.etherscan.io/tx/0x3ce5965fdfe145c4979c621538b28c836114cfe18be559902f3ed749a7c4e2a8) [s7] |

#### TWAP

A TWAP order has no presign.
The Orders Safe registers it in ComposableCoW, and its fallback handler validates each part.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 11 | Two parts of 0.005 WETH each. Asset receives 192.611792 USDC and 193.294323 USDC | TWAP-06, TWAP-11 | `test_twap_settles_two_parts_and_cancelled_next_part_fails`, `test_TWAP_before_start_and_complete_daily_weekly_uid_schedule` [s6] | [part 1](https://sepolia.etherscan.io/tx/0xbb54da9c6ecb83deafbc3f829ca130f26defb0858c8571d308b8cfa1beb62788) · [part 2](https://sepolia.etherscan.io/tx/0x58aa3328d61db7c0b28fb4754e518415e8891319a42686453dbc9a051b82e013) [s7] |
| 12 | The Emergency Safe removes an active TWAP before its next part. The calldata contains `remove(bytes32)` | TWAP-08 | `test_TWAP_both_removal_roles_reject_cached_settlement_and_preserve_other_order` [s6] | [create](https://sepolia.etherscan.io/tx/0x344af8237e7f4c94934ddfba022d4c50bc4bdd473346aa8a0c2fbd3df24b1522) · [remove](https://sepolia.etherscan.io/tx/0x55f42b367c4ac31a726d0ed1e349f711c1a2d5f6f0fb9ed1210adfd9e465034c) [s7] |
| 13 | The Committee Safe removes a completed TWAP | TWAP-08, OPS-13 | same test [s6] | [remove](https://sepolia.etherscan.io/tx/0x32e2ee4b11a78cbac6cff295b7003466598a5fa005ec4deecd53fb58e92bf20c)\* [s7] |

#### First-loss shares

The Committee Safe redeems test shares.
The controller settles the test queue at 1:1.
The Committee Safe then claims to the Agent.
The test tokens emit no events [s14].
Thus this review read the balances and the supply at the blocks before and after [s7].

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 14 | USD share. The Agent balance of the claim asset changes from 0 to 3. The share supply changes from 100 to 97 | FL-02 | `test_first_loss_redeem_claim_both_assets_and_denied_bypass` [s6] | [redeem](https://sepolia.etherscan.io/tx/0x5fdd027bf11b73c23e871ec740b1dd36d62e6928aabf95ea2cd2d3e7e3e1911b) · [settle](https://sepolia.etherscan.io/tx/0x5e01052b037a8a8562055dda98133d1055369bf119af1651b23ef68b1eacdcc2) · [claim](https://sepolia.etherscan.io/tx/0xf205056dab54fbbd21c4ee01834c0a460f8c0a2db1ebf6d01a195eae0652b46e) [s7] |
| 15 | ETH share. The Agent balance of the claim asset changes from 0 to 3 | FL-02 | same test [s6] | [redeem](https://sepolia.etherscan.io/tx/0x3cc6cbcb01114626aa5c3099a76a84dcc5568057730b437b65b6c49393333573) · [settle](https://sepolia.etherscan.io/tx/0x9b64cec0c1a00b417294173436083acd186e46bbff43590f55ab5c472c09b5dc) · [claim](https://sepolia.etherscan.io/tx/0x6ea6e38d5eb1fb1d140e736dfacdcc1f1f5833b94481faa089b8113b04959c18) [s7] |

#### Burn motions

The Committee Safe creates a motion in the mock Easy Track.
After 60 seconds, any account can enact it, and the executor burns the shares.
An objection or a cancellation stops the motion.
At block `12104452`, the seven motions have the states Enacted, Rejected, Canceled, Enacted, Rejected, Canceled, Canceled [s7].

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 16 | USD share, motion 0. Enactment after the window. The supply changes from 97 to 95. The First-loss balance changes from 7 to 5 | ET-03 | `test_ET_window_exact_substituted_input_supply_and_reenactment_both_shares` [s6] | [create](https://sepolia.etherscan.io/tx/0x53ffc68c9082a952cb86aa71003db34fd590bbe0a5a89b7ea29ebc07609c34cf) · [enact](https://sepolia.etherscan.io/tx/0x5e88f532647de580ce0e7dd4af0c1c73480de2ad3882e80aefbaf6d3f6a97e7e) [s7] |
| 17 | ETH share, motion 3. The same result | ET-03 | same test [s6] | [create](https://sepolia.etherscan.io/tx/0xbf595ac2631c9d256e1da1a43b2a8768c9b42fa9e703ab1da5841a4fa4448334) · [enact](https://sepolia.etherscan.io/tx/0x3de8da61bcdd1000e055e5d52038cb86562cd9cc55f5a3aeef73a510c27ca7c5) [s7] |
| 18 | USD share, motion 1. One objection rejects the motion | ET-05, mock rules | `test_ET_objection_threshold_multiple_current_weight_and_repeated_objector_fixture` [s6] | [create](https://sepolia.etherscan.io/tx/0xcdd88f444fd0bb26b0fdd8a4b637b2337543adc90aa01f80859f5cd717b4b166) · [object](https://sepolia.etherscan.io/tx/0x6517b4becbbeb1e75ef42e95386a1468bee2dfb1089bbc59e08e492404d7da9b) [s7] |
| 19 | ETH share, motion 4. The same result | ET-05, mock rules | same test [s6] | [create](https://sepolia.etherscan.io/tx/0xefd849d99b831651d3d2f304f07d91c5519419f1e12fa88cd8b31791cbcd5d49) · [object](https://sepolia.etherscan.io/tx/0xe2acf6b927496530298bf185beca84958814ba7e129adf1a9b507b53133990d2) [s7] |
| 20 | USD share, motion 2. Test Voting cancels the motion | ET-06 | `test_ET_voting_cancel_unknown_nonpending_mixed_ids_are_atomic` [s6] | [create](https://sepolia.etherscan.io/tx/0x059759bc9abc43316d0c993f7236c1314fe09467999807b2cc7bbecf587499b5) · [cancel](https://sepolia.etherscan.io/tx/0x8a78d07bffc0844e2081c7334114275eee9bbe22d0ea170630fe8486e63f8176) [s7] |
| 21 | ETH share, motion 5. The same result | ET-06 | same test [s6] | [create](https://sepolia.etherscan.io/tx/0x50c9fd72e0d23f6c5470fdc1e7f4e1b76edb4d5e3c43c0844fb24b9878c011d5) · [cancel](https://sepolia.etherscan.io/tx/0x2d2e072fda13dd558ae18aeb587ffe3e8bf5440359dad12d743b5c0e18e86a6e) [s7] |
| 22 | Motion 6. The Committee Safe creates it before the stop. Test Voting cancels it while the Asset operator is disabled | ET-10 | `test_EM_repeated_switch_pending_burn_cancel_and_restart` [s6] | [create](https://sepolia.etherscan.io/tx/0x76182697557f59f6bd7074879207fcf277b20b6b3aedf8916747c5a5e0959a7f)\* · [cancel](https://sepolia.etherscan.io/tx/0x8d35e28c89e41a60fc53ba37305bf3fbe465f29e1b3dee3037f656ceea5d4658)\* [s7] |

#### First emergency drill: stop, sweep and restart

The drill shows the full emergency sequence.
The Emergency Safe stops the operator on both accounts, moves the tokens to the Agent and removes the relayer approvals.
Test Voting then restores the configuration.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 23 | Stop on Asset. The Emergency Safe disables the operator modifier through the safety modifier | EM-01 | `test_emergency_stops_asset_operator_but_cannot_restart` [s6] | [disable](https://sepolia.etherscan.io/tx/0xb926d29b1ef443543491a2cf43c2abfb0d447d051252332e03890016a00ab4fb) [s7] |
| 24 | Stop on Orders. Four `RevokeTarget` events for `orders-operator` | EM-02 | `test_EM_target_and_function_revokes_for_both_accounts_preserve_other_token` [s6] | [WETH](https://sepolia.etherscan.io/tx/0x87987768fa9d2b825cbfaf34e8082a961eb3c503bcd7c92be2cf452e7a77e5de) · [USDC](https://sepolia.etherscan.io/tx/0x38774559212359c8674c7562dc89272e73ac0ecf7bf35b512fca3d91d17c5a06) · [order signer](https://sepolia.etherscan.io/tx/0x16cfec3d8c95101cd43a3ed9f57f2e773627b807e7c688d85df4cd2713ba0130) · [ComposableCoW](https://sepolia.etherscan.io/tx/0x990d9109ceff8d1cde0ddc723cbd9b131b6121d4e99132b1d5c2618b59858df0) [s7] |
| 25 | The Emergency Safe cancels a presign, signs its own order and cancels it. `PreSignature` is false, true, false | ORD-08 | `test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders` [s6] | [unsign](https://sepolia.etherscan.io/tx/0x7963225816515aa857049144806c219b7bfa1bd8c00f8edd5f2c9bb77785d126)\* · [sign](https://sepolia.etherscan.io/tx/0x83135a17a52881758ef6a94f53578ae4a3f54d4ba387762b0cabb2c47f437df5)\* · [unsign](https://sepolia.etherscan.io/tx/0x9c291cea16438e96ca451d6cf6bc5b652b1233e9aace9808c710e9e9ab9646fc)\* [s7] |
| 26 | Sweep to the Agent: 0.005 WETH from Asset, 0.005 WETH from Orders, 385.906115 USDC from Asset | EM-04 | `test_EM_all_transfer_routes_tokens_and_forbidden_receivers` [s6] | [Asset WETH](https://sepolia.etherscan.io/tx/0x67b55925699b0aeac9a43932ad30f2c782472584c981bc042f5d6959277c98be)\* · [Orders WETH](https://sepolia.etherscan.io/tx/0xe289a425dbf944eb13f82b4de3328d8c3765ff9fb416074ccebdefded9562163)\* · [Asset USDC](https://sepolia.etherscan.io/tx/0xf992f4c5b506a7049078833a657c2ea9fa21fa65e8479302f70f53aceb2c6757)\* [s7] |
| 27 | The Emergency Safe sets both Orders approvals to the relayer to zero | SETTLE-06 | `test_SETTLE_approval_spender_amount_matrix_and_zero_allowance_transfer` [s6] | [WETH](https://sepolia.etherscan.io/tx/0x4299065d00a4667796780ca15a62b44fc0062794b8afe190d2e48c1482b631c7) · [USDC](https://sepolia.etherscan.io/tx/0x37d056b295c7566f5cccc2943beac347c2528a4e6cefef06f861305fa4c5f000) [s7] |
| 28 | Restart through test Voting: the Asset module, four targets, two approvals | EM-08, SETTLE-07 | `test_emergency_recovery_zero_approvals_and_voting_restart`, `test_EM_two_stop_restart_cycles_new_settlement_and_closed_uid_replay` [s6] | [module](https://sepolia.etherscan.io/tx/0xb14421a250355c4d46cb71787e889a48f6a0f34f75c49c32553824e01f79aa7b) · [WETH](https://sepolia.etherscan.io/tx/0x475ca91a79a5a941337f6c724e9c010e81e78e605e3125a9086257e3a214c665) · [USDC](https://sepolia.etherscan.io/tx/0xc26930957206cc42d27c790d6dbeac50bf31b73b1019bfafbcc5ec30472d6574) · [order signer](https://sepolia.etherscan.io/tx/0xb7dafaec7d27260d57eb5d802d18ecc55efda7dc5dc724cfd3f314b549279db1) · [ComposableCoW](https://sepolia.etherscan.io/tx/0x834a4209d7a8c691e7f4f338f49e20726dc2e570769f29c25842ad26355b11eb)\* · [approve WETH](https://sepolia.etherscan.io/tx/0x545ce83d0db417ba88f3c52209d06a31214f32364894bbec83ebd30b8535ba66)\* · [approve USDC](https://sepolia.etherscan.io/tx/0x8eeb9a256e6987517e8b1f779e526e25c734c1d930b46add6664801364681b0a)\* [s7] |
| 29 | The Agent returns 0.01 WETH and 385.906115 USDC to Asset | EM-06 | No dedicated test | [WETH](https://sepolia.etherscan.io/tx/0xeb64ece3d945ddea0db695645e76f2ce32da5da1a8bc5c8584fe9bb7c07f4242)\* · [USDC](https://sepolia.etherscan.io/tx/0x268f6e04943435e79b73423d4345aa4b11c4bd612d6d66897851cefe50968292)\* [s7] |
| 30 | Smoke transfer after the restart. The Committee Safe moves one raw WETH unit to Orders and back | EM-08 | `test_emergency_recovery_zero_approvals_and_voting_restart` [s6] | [fund](https://sepolia.etherscan.io/tx/0xcd715924bfdd18abbce4cfb332917bc509848bc1b26d6a0f05549eecea1aa9c0)\* · [return](https://sepolia.etherscan.io/tx/0x7446c5a22172631a605154ba1e0b39c60c1821171aaff31e17de0ffae75864d4)\* [s7] |

#### Second emergency drill: recovery order to the Agent

This drill adds the recovery order.
While the operator is stopped, the Emergency Safe sells the tokens that remain on Orders and the proceeds go to the Agent.

| No. | Case and observed result | ID | Fork test | Public transactions |
|---|---|---|---|---|
| 31 | The Committee Safe moves 0.005 WETH to Orders before the stop | FUND-01 | same as row 4 [s6] | [fund](https://sepolia.etherscan.io/tx/0xe3645922565ac1b644ef13933a405380ce6afab00f4ef2071fabc365c7e9e792) [s7] |
| 32 | Stop: the operator modifier is disabled and the four targets are revoked | EM-01, EM-02 | same as rows 23 and 24 [s6] | [disable](https://sepolia.etherscan.io/tx/0xe6617d59b18657af4948df611b5c6b9df1d5641d0319ec526342bee12d3c956c)\* · [WETH](https://sepolia.etherscan.io/tx/0x98e983f1396053239b93f21a6425e3e1794bab589d8b63516f19972bd123b1d8)\* · [USDC](https://sepolia.etherscan.io/tx/0x5bbf5e13085e145dc23d30c759fa0d53dbc5516f56095007ea720374fc45080f)\* · [order signer](https://sepolia.etherscan.io/tx/0x72cd2fee1520a0194ecb5d4602201e064b4da8c9a1c6d7d848dac0dbdee04416)\* · [ComposableCoW](https://sepolia.etherscan.io/tx/0xa1d56677d0e0a551ce8a0f94086c7ab10319a675795702741ff3a9c69508f6ca)\* [s7] |
| 33 | The Emergency Safe signs the recovery order. The solver pays 193.237414 USDC to the Agent for 0.005 WETH | EM-05, EM-06 | `test_EM_recovery_order_field_boundaries_and_token_directions` [s6] | [sign](https://sepolia.etherscan.io/tx/0x5c7df438849a8c3f2ab6a592b868305d4f1f3bc50fcd816e83143354166014f3) · [fill](https://sepolia.etherscan.io/tx/0x1fb3284c9e2a31a8620264a1e74684ae3fb46063da86b43f1c3c69f43bca548e) [s7] |
| 34 | Zero approvals and a sweep of 579.460857 USDC from Asset to the Agent | SETTLE-06, EM-04 | same as rows 26 and 27 [s6] | [WETH zero](https://sepolia.etherscan.io/tx/0xb5cbe7c527f0cfcc28e42f53267dc42ec5682aa2612631de459c8d363f0e149f)\* · [USDC zero](https://sepolia.etherscan.io/tx/0x88269d48a2ab899908d3f57d2bbe51d7b25bb1b18a19fccf7007b6345550f47c)\* · [sweep](https://sepolia.etherscan.io/tx/0xfc7cb9f8c33ddf3bf384ebe1380087c63e77af02b7be517ba6b0393ae7ded5b6)\* [s7] |
| 35 | Restart through test Voting: four targets, two approvals, then the Asset module as the last step | EM-08 | same as row 28 [s6] | [WETH](https://sepolia.etherscan.io/tx/0x78d44a953f7b46626d437d2427d6c43367d28c9e762b7f66580f0d065799ee37)\* · [USDC](https://sepolia.etherscan.io/tx/0x6a710bc68764b393688402b233ff15cf827b3fb4cf1789ca62adac31567c626d)\* · [order signer](https://sepolia.etherscan.io/tx/0x85a0235769f5e8b6423ef942915602778348a6ce2d94edc2fa23075a21788d94)\* · [ComposableCoW](https://sepolia.etherscan.io/tx/0xae43e5d4059e159d983e7adfca2d39caf1a58861abc49b172d4a410743d7ada5)\* · [approve WETH](https://sepolia.etherscan.io/tx/0x0060f811249b8bf4d099158d1a210e5f9d474921c560c65629ac4f27b62f68cb)\* · [approve USDC](https://sepolia.etherscan.io/tx/0x65cdf694046550f651297d965bd5f39e74904e42361bac4adb815008f5135a57)\* · [module](https://sepolia.etherscan.io/tx/0x9140fc8a7dabf70e56ee6ce884f262c0c83105c783561312df6d043dac6057d5)\* [s7] |
| 36 | The Agent returns 772.698271 USDC to Asset. Smoke transfer: one raw USDC unit to Orders and back | EM-06, EM-08 | same as row 30 [s6] | [return to Asset](https://sepolia.etherscan.io/tx/0x2c4526b7bb795e68b351378443fc38f643d047b828084c0bfc99c8e248f4ec62)\* · [fund](https://sepolia.etherscan.io/tx/0x3c4af2705b400647286437a3b226d48c3150c6f82f613ebe8a9868445df2b66a)\* · [return](https://sepolia.etherscan.io/tx/0x35b0fd0fd395c57299abd64875263d887136667f4ba192260d2ed6fc665bf1aa)\* [s7] |

#### Operational faults

These cases test the scripts, not the contracts.
A fault must not cause a second execution of the same transaction.

| No. | Case and observed result | ID | Check | Public transactions |
|---|---|---|---|---|
| 37 | `FundSepolia` stops after the wrap. The resume sends only the three remaining transfers. The sender nonces are 274 to 277 without a gap | FUND-12 | `scripts/test_sepolia_workflow.py` [s6] | [wrap](https://sepolia.etherscan.io/tx/0xb4f47a30c5b6acbd4ad377a1aa14ba5fb51af5ea63a47d3ad842971ae7ca712e) · [WETH](https://sepolia.etherscan.io/tx/0xe45e1d44e1275d33feb5423d7465899d5ddbb4ff32e3f080b1525606ba7926ea) · [USD share](https://sepolia.etherscan.io/tx/0xf800d0a4d626098061c858437b2a271d4c4b4089b2117af9be08520459507992) · [ETH share](https://sepolia.etherscan.io/tx/0x021e631171ed441266575f0ca6c1dd7850538fd5511887cc865485083f6eac06) [s7] |
| 38 | The response is lost after mining. The transaction executed one time | OPS-09 | same file [s6] | [transaction](https://sepolia.etherscan.io/tx/0x0075c5eabac1f7462ca75e4ef0c30c9be154a71bc451f614a9d5168537828e32)\* [s7] |
| 39 | Lost submission, HTTP timeout, legacy and EIP-1559 nonce replacement. Each transaction executed one time | OPS-09 | same file [s6] | [resume](https://sepolia.etherscan.io/tx/0x20752a5159e0f499c7864188c20e9f9682d5022552a16be7ec309b81e8f7b2e2) · [timeout](https://sepolia.etherscan.io/tx/0x1e621f229691b74d259d25f4f90e50974bb3ad2aadc7f30b1f774dfe6a4ac30d) · [legacy](https://sepolia.etherscan.io/tx/0x23a62e73fc112e4ab09253e4fe97169eeef85bd78e3ed7d4beca586ed860e2c7) · [EIP-1559](https://sepolia.etherscan.io/tx/0x05b08210d07de4459c29d586e8cdf9d6893b2747403efd06891d10776c92a5d7) [s7] |

### 2.2. Cases with a fork test only

These cases are limits and refusals.
The fork tests assert the exact error and the unchanged state.
No public transaction exists for them, as planned [s3].

| Area | ID | Tests | What the tests assert |
|---|---|---|---|
| Configuration | CFG-03 to CFG-05, CFG-09, CFG-11 | `test_CFG_*`, 7 tests [s8] | A matrix of 6 callers and 9 role keys on the four modifiers. Replay of a Safe hash and nonce. The wrong Safe, the wrong chain and a bad signature fail |
| Funding | FUND-02 to FUND-10 | `test_FUND_*`, 9 tests [s8]; `test_funding_budget_and_safe_owner_path` [s10]; `test_usdc_budget_boundary_and_refill` [s9] | The wrong receiver, token, selector and operation fail. A transfer of one unit above the budget fails. Refill at one second before the period end, at the end and after it. A failed token call consumes no budget. Empty, repeated and failing batches |
| Orders | ORD-01, ORD-04 to ORD-07, ORD-09, ORD-10 | `test_ORD_*`, 7 tests [s8]; `test_order_boundaries_and_asset_signing_are_restricted`, `test_quote_1723885_zero_fee_order_passes_deployed_policy` [s9] | Both directions, sell and buy, full and partial. A change of each of the 12 typed fields gives a different order UID. Order life of 0 seconds, 90 days, and 90 days plus 1 second. Fee ceiling of 100 and 101 basis points |
| Settlement | SETTLE-02, SETTLE-03, SETTLE-05, SETTLE-07 | `test_SETTLE_*`, 6 tests [s8] | Overfill before and after a partial fill. Missing funds, missing approval, missing signature, an unknown solver. Rounding with nonzero remainders |
| TWAP | TWAP-01 to TWAP-05, TWAP-07, TWAP-09, TWAP-10 | `test_TWAP_*`, 12 tests [s8]; `test_twap_two_parts_signature_and_cancellation` [s10] | All 104 parts of the minimum, daily and weekly schedules. 91 daily parts and 13 weekly parts fail. A changed proof fails. `create`, `setRoot` and `setSwapGuard` are denied. A stop-loss payload fails |
| First-loss | FL-01, FL-03 to FL-08 | `test_FL_*`, 6 tests [s8] | Zero and excess requests. Claim before settlement, repeated claim, duplicate timestamps. Transfer, approve, burn and other receivers are denied. A pending redeem survives a stop and a restart |
| Burn motions | ET-01, ET-02, ET-04, ET-07 to ET-09 | `test_ET_*`, 6 tests [s8]; `test_burn_motion_wait_objection_and_voting_cancellation` [s10] | The wrong creator, the wrong share and a zero amount fail. The exact window boundary. A substituted script fails. A removed factory. Executor atomicity |
| Governance | GOV-01 to GOV-07, GOV-09 | `test_GOV_*`, 10 tests [s8]; `test_governance_executor_restricts_keys_membership_and_administrative_targets` [s9] | 545 forbidden administration calls fail. A delegatecall option can only be reduced. The executor cannot get owner authority. Budget timestamp classes, with the overflow at the maximum value |
| Emergency | EM-03, EM-07, EM-09 | `test_EM_*`, 10 tests [s8] | The Emergency Safe cannot grant, enable a module or increase an approval. 76 forbidden receivers fail. Two stop orders. Two stop and restart cycles. A filled order cannot settle again |
| Configuration drift | OPS-05 | `policy/constellation/sepolia/diff.test.ts` [s6] | A changed owner, threshold, guard or module gives a diff |
| Local guards | OPS-10, OPS-11 | `scripts/test_sepolia_operational_guards.py`, `scripts/test_sepolia_workflow.py`, `policy/constellation/sepolia/verify-test-payload.test.ts` [s6] | The wrong chain, branch, a dirty tree, CI and forbidden credentials stop the script. A failed preparation removes the previous success |
| CoW quote conversion | ORD-02 | `scripts/test_sepolia_cow_order.py`, `scripts/test_sepolia_protocol_fees.py` [s6] | The quote fee is added to the sell amount and the order fee is zero |

## 3. Cases without coverage

### 3.1. Cases with no test and no transaction

- [ ] **UI signing (OPS-01, OPS-03, OPS-04).** The test plan has one case without a transaction: the funding and return batch through the UI [s2]. The Committee Safe nonce is still `51`, the value from the prepared envelope [s3][s7]. Thus nobody executed it. The recorded UI session had a disconnected wallet [s3]. All 115 decoded `execTransaction` calls carry a pre-validated signature [s7]. No public transaction tested an ECDSA signature or signature collection in the Safe UI.
- [ ] **Signers and thresholds (MAIN-14).** Each of the five Safes has a threshold of 1 [s7]. One controller owns the Committee and Emergency Safes and controls test Voting, the Agent, the queues and the objection token [s4]. The stand cannot show that the Committee and the Emergency signers are independent.
- [ ] **Governance through a motion (GOV-08, GOV-10).** The stand has no governance factory [s1]. The tests impersonate the executor [s8]. The path from a motion to the factory and the executor has no test. The hazard of a pending governance motion during a restart has no test.
- [ ] **Screening and the Committee guard (MAIN-12, MAIN-13).** The guard slot of each Safe is zero [s7].
- [ ] **Monitoring and alerts (OPS-12).** No test and no integration [s1].
- [ ] **Valuation, caps and reporting (MAIN-15).** No test [s1].
- [ ] **Governance templates and exit governance (MAIN-10).** No test [s1].
- [ ] **Lido Lend (MAIN-16).** A gate after launch [s1].

### 3.2. Cases with partial coverage

- [ ] **CFG-02.** The 12 stand runtimes agree with the frozen artifacts. Nobody approved these baselines or the USDC implementation baseline [s1].
- [ ] **SETTLE-04.** Some protocol-fee cases are open: zero price improvement, cap equality, other fee policies and the weekly payout [s1].
- [ ] **EM-05.** The recovery order is tested from WETH to USDC only. The policy refuses USDC to WETH. The stand has no USDT [s1][s8].
- [ ] **ET-05.** The mock Easy Track reads the current token balance, not a snapshot. It counts one objector more than one time [s13]. On Sepolia, one address with a weight above the threshold objected [s7]. The production rules are tested on the mainnet fork only [s1].
- [ ] **GOV-09.** A test reproduces a defect: an old owner payload restores a permission that the owner revoked later [s8]. No check detects such a payload before the signature [s1].
- [ ] **OPS-06.** The local serialization keeps 63 calls. The acceptance by the hosted UI is not tested [s1].
- [ ] **OPS-07.** An invalid UI result, a stale cache and a partial snapshot are not tested [s1].
- [ ] **OPS-08.** The recorded audit compares the root fields of the receipts. A full comparison of the state changes does not exist [s1].
- [ ] **OPS-10.** No real hosted apply session and no public signer boundary were tested [s1].
- [ ] **First-loss economics.** The queues are test contracts with a 1:1 settlement. They do not model prices, fees, liquidity or oracle reports [s14].

### 3.3. Integrations that the stand does not have

These integrations have tests on a mainnet fork only.
This review did not run those suites.
The states come from the checklist [s1].

| ID | Integration | Recorded state |
|---|---|---|
| MAIN-01 | ETH and WETH | Partial |
| MAIN-02 | Lido submit | Partial |
| MAIN-03 | stETH and wstETH | Partial |
| MAIN-04 | DAI and USDS converter | Partial |
| MAIN-05 | sUSDS | Partial |
| MAIN-06 | Earn deposits | Partial |
| MAIN-07 | Earn and First-loss redemptions | Partial |
| MAIN-08 | Real First-loss burn | Partial |
| MAIN-09 | Treasury registries and funding | Partial |
| MAIN-11 | Full CoW token matrix | Partial |

The rows have one gap in common.
The mainnet harness uses the old role keys and externally owned accounts as role holders.
The production role graph is not verified [s1][s3].

## 4. Cases that can be tested now

The groups show what each test needs.
In each group, the cases that close an open checklist row come first.

### 4.1. Cases on the current stand, without a change

These cases need only the stand owner and the stand key.
The contracts, the policy and the roles stay as they are.

| No. | Case | Closes | Current state | Procedure |
|---|---|---|---|---|
| A1 | Funding and return in one batch through the UI, with a wallet signature | OPS-01, OPS-03 | The envelope is in `cache/sepolia/ui-funding-return-2026-10-25/` [s3]. The Committee nonce is still `51`, so the Safe transaction hash did not change [s7] | Connect the wallet in the UI. Compare the decoded calls and the hash with the envelope. Simulate again. Sign. Save the receipt |
| A2 | Stale nonce and two competing proposals | OPS-04 | Only the old proposal was checked. Its simulation returns `TargetAddressNotAllowed` [s3] | Create two proposals for one nonce. Execute one. Confirm that the UI refuses the other before the signature |
| A3 | The creator cancels a burn motion: the Committee Safe calls `cancelMotion` | ET-06 | A fork test covers it [s8]. All three public cancellations went through test Voting [s7] | Create a motion. Cancel it from the Committee Safe. Check by `eth_call` that enactment fails after the window |
| A4 | The Emergency Safe revokes one function with `revokeFunction`, on Asset and on Orders | EM-02 | A fork test covers both modes [s8]. The public drills used `revokeTarget` and `disableModule` only [s7] | Revoke `transfer` for one token. Confirm that the other token still works. Restore through test Voting |
| A5 | The remaining permitted Emergency routes: Asset to Orders, Orders to Asset, USDC from Orders to the Agent | EM-04 | The two drills contain WETH from Asset to the Agent, WETH from Orders to the Agent and USDC from Asset to the Agent [s7] | One transfer for each route. Compare the balances |
| A6 | The operator removes an active TWAP before the next part | TWAP-08 | The Emergency Safe removed the active TWAP. The Committee Safe removed a completed one [s7] | Create a TWAP. After part 1, remove it from the Committee Safe. Confirm that the cached signature fails |
| A7 | Fill variants that have no public transaction: buy from WETH to USDC, partial fill from WETH to USDC, TWAP from USDC to WETH, TWAP of three parts with a skipped interval | SETTLE-04, TWAP-05 | Seven public fills exist. Sell in both directions. Partial and buy from USDC to WETH only. TWAP from WETH to USDC with two parts [s7] | One order for each variant. Each fill also adds a protocol-fee observation |
| A8 | A real budget refill after `2026-11-19T14:38Z` | FUND-07 | Both budgets have a 30-day period that started at `2026-10-20T14:38Z` [s7]. The refill is tested only on a fork with a changed clock [s8] | One transfer before the boundary and one after it. After the boundary, `ConsumeAllowance` must count from the full budget |
| A9 | Use of a budget to its exact limit, and a refusal of the next unit | FUND-02, FUND-05 | A fork test covers it [s8]. `orders_weth` has 0.974999999999999999 of 1 WETH. `orders_usdc` has 497.274445 of 1,000 USDC. Asset holds 0.012331416796386488 WETH and 283.007401 USDC [s7] | Add tokens to Asset. Use the budget to zero. Check the refusal of the next unit by `eth_call` |
| A10 | An objection below the threshold and a sum of two objectors | ET-05, mock rules | A fork test covers it [s8]. One address with a weight above the threshold objected publicly [s7] | Move the test token to two addresses. The value is low: the mock does not have the production rules [s13] |
| A11 | First-loss requests at different timestamps and a partial claim | FL-04, FL-05 | A fork test covers it [s8]. Each share has one public request [s7] | The value is low: the queues are test contracts [s14] |

### 4.2. Work without public transactions

| No. | Work | Closes | Current state |
|---|---|---|---|
| B1 | Add `just --justfile sepolia.just check` to CI | Finding 1 | The 47 Python tests and 132 policy tests pass locally [s6]. This review did not run them on a clean clone without `cache/` and without network access. An edit of `.github/` needs an explicit human request |
| B2 | Remove the `cache/` inputs from the fork tests | Finding 2 | Two tests read the batch executor address and code hash from `cache/sepolia/role-key-migration/package.json` [s8]. The runner reads `cache/sepolia/constellation/payload.json` [s12]. Committed fixtures can replace them |
| B3 | Run the fork suite in CI at block `11992758` | Finding 1 | After B2, the run needs only a secret with an archive RPC. The Forge run took 7 seconds at the recorded block and 82 seconds at the current block [s6] |
| B4 | Add the missing transactions to the test plan | Finding 3 | Section 2.1 marks them with a star |
| B5 | A check of an owner payload against the current policy before the signature | GOV-09 | A test reproduces the defect [s8]. No detection tool exists [s1] |
| B6 | A full comparison of the state changes for each public transaction | OPS-08 | This review compared the state for the claims and the burns [s7]. The archive RPC is available |
| B7 | Approval of the runtime baselines of the stand and of the USDC implementation | CFG-02 | The hashes are recorded [s1]. A human decision is necessary |
| B8 | Move the mainnet harness to the account-specific keys and to Safe role holders | MAIN-01 to MAIN-09 | The harness uses the old keys and externally owned accounts [s1] |
| B9 | Refusal of non-launch tokens in the CoW matrix | MAIN-11 | Open in the checklist [s1] |
| B10 | Human verification of the three Sepolia pages | Finding 5 | The pages have `review_status: slop` and `verified: []` [s1][s2][s3] |

### 4.3. Cases that need a stand change

Each case changes the stand configuration.
The acceptor selects the signer sets and the thresholds.

| No. | Case | Closes | Necessary change |
|---|---|---|---|
| C1 | Different signers and a threshold above 1 on the Committee and Emergency Safes, with signature collection in the Safe UI | MAIN-14 in part, OPS-01 | New owners and thresholds. The configuration test asserts one owner and a threshold of 1, so it must change too [s8] |
| C2 | The full governance path: motion, factory, executor | GOV-08 | A governance factory on the stand and its registration in the mock Easy Track [s1] |
| C3 | A pending governance motion during a stop and a restart | GOV-10 | The same change as C2 [s1] |
| C4 | A recovery order to USDT | EM-05 | A test USDT and a change of the `orders-emergency` policy [s1] |
| C5 | Alerts for configuration changes and for the order lifecycle | OPS-12 | The monitoring integration. The blocks `11986846–11986896` and `11987276–11987311` are a ready input [s7] |

### 4.4. Cases that cannot be tested now

- **Screening and the Committee guard (MAIN-12, MAIN-13).** The guard and its service are necessary [s1].
- **The other protocol-fee cases (SETTLE-04).** They depend on solver behaviour and on the weekly CoW payout. Case A7 adds observations but cannot force a combination [s1].
- **Earn economics, Lido, sUSDS, the converter and Treasury funding.** Sepolia does not have these protocols. Only the mainnet fork can test them [s1].
- **Valuation and caps (MAIN-15), Lido Lend (MAIN-16).** The target components do not exist [s1].

## 5. Review findings

1. **No Sepolia check runs in CI.** The `Justfile` and the workflows do not call a Sepolia recipe [s15][s16]. The fork tests skip when `SEPOLIA_STAND_BLOCK` is not set [s9][s11]. A regression in these tests does not block a merge.
2. **The evidence is local.** The `urn:clutch:evidence` sources of the three Sepolia pages point to the git-ignored `cache/` directory [s1][s3]. Two tests and the runner read files from it [s8][s12]. A clean clone cannot repeat the fork run. The manifest is an exception: `scripts/fixtures/sepolia-stand-manifest.json` is equal to the cached manifest [s7].
3. **The transaction table of the test plan is incomplete.** The row "Voting restart" cites four of seven restore steps. The table does not cite the sweeps, motion 6, the returns from the Agent, the smoke transfers, most of the second drill, the deployment, the policy application or the role migration [s2][s7].
4. **The two drills restore in a different order.** In the first drill, test Voting enabled the Asset operator module first, at block `11986878`, before the Orders targets and approvals. In the second drill, it enabled the module last, at block `11987308` [s7]. The test of the stale owner payload restores permissions first and enables execution last [s8]. The restart procedure should specify one order.
5. **A human verified none of the three Sepolia pages.** The checklist, the test plan and the results have `review_status: slop` and `verified: []` [s1][s2][s3]. An agent wrote the coverage states.

## Method

The review ran these commands on 2026-11-10, on branch `testnet/sepolia` at commit `24f7a52` [s6][s7]:

```sh
just --justfile sepolia.just check
SEPOLIA_STAND_BLOCK=11992758 just --justfile sepolia.just test-current
just --justfile sepolia.just test-current
python3 cache/sepolia/review-2026-11-10/verify_txs.py 0x32e2ee4b11a78cbac6cff295b7003466598a5fa005ec4deecd53fb58e92bf20c 0x0075c5eabac1f7462ca75e4ef0c30c9be154a71bc451f614a9d5168537828e32 0x8f24409dfef96a59f09125ecb48779154a6af164c0700b1121989d0a58e1befd
python3 cache/sepolia/review-2026-11-10/verify_setup.py
python3 cache/sepolia/review-2026-11-10/scan.py 11986840-11986910 11987270-11987380
python3 cache/sepolia/review-2026-11-10/state.py 12104452
python3 cache/sepolia/review-2026-11-10/signatures.py
```

- The first three commands are repository recipes [s17]. Their logs are `local-check.log`, `fork-pinned/` and `fork-latest/` in `cache/sepolia/review-2026-11-10/` [s6].
- `verify_txs.py` reads each transaction hash from the test plan. It calls `eth_getTransactionByHash`, `eth_getTransactionReceipt` and `eth_getBlockByNumber`, and it decodes the events. Log: `plan-receipts.log` [s7].
- `verify_setup.py` reads the hashes from the four local `broadcast/*/11155111/run-latest.json` records and makes the same calls. Log: `setup-receipts.log` [s7].
- `scan.py` calls `eth_getLogs` for the twelve stand accounts and for the WETH and USDC transfers and approvals of Asset, Orders and the Agent. Log: `drill-scan.log` [s7].
- `state.py` calls `eth_call` and `eth_getStorageAt` at the given block, and at the blocks before and after the claims and burns. Log: `state.log` [s7].
- `signatures.py` decodes the `signatures` argument of each cached `execTransaction` call. Log: `signatures.log` [s7].
- The RPC is the endpoint `SEPOLIA_RPC` of the local `.env`. It is an archive node. The scripts print no endpoint.

Limits of this review:

- The two fork runs replaced four files in `cache/sepolia/current-stand/`. The review restored the files of the recorded run at block `11992758`.
- The event scan covers the two block ranges of the emergency drills only. A transaction outside these ranges and outside the test plan was not read.
- The review did not decode the order UID of each presign. It compared the event, the caller and the role route.
- Section 1.4 lists the recorded runs that the review did not repeat.
