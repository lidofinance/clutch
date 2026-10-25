---
type: Research Note
title: Sepolia test results
description: Recorded test runs, public transactions, findings, failures and coverage limits for the Sepolia stand and mainnet forks.
tags: [sepolia, testing, roles, cow, first-loss]
status: draft
valid_as_of: 2026-10-25
stale_after: 2026-11-25T00:00:00Z
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-25T20:11:26Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account isolation, emergency stop and DAO restart
  - id: s2
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — CoW orders, TWAP, recipients, approvals and cancellation
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — First-loss redemption, burn motions and objection
  - id: s4
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — governance permissions and motion restrictions
  - id: s5
    resource: /adr/013-tests-on-sepolia.md
    title: ADR 013 — four account-specific keys and Sepolia execution boundaries
  - id: s6
    resource: /specs/sepolia-stand-plan.md
    title: Existing stand, funding procedure and recorded deployment evidence
  - id: s7
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: test/SepoliaStand.t.sol, test/SepoliaCurrentStand.t.sol, test/utils/SepoliaStandFixture.sol and scripts/sepolia_test_current.py
  - id: s8
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2Settlement.sol
    title: CoW primary source checked on 2026-10-23 — settlement, limit-price checks and filled amounts
  - id: s9
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/libraries/GPv2Trade.sol
    title: CoW primary source checked on 2026-10-23 — trade ABI and signature flags
  - id: s10
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/mixins/GPv2Signing.sol
    title: CoW primary source checked on 2026-10-23 — presign and EIP-1271 signatures
  - id: s11
    resource: urn:clutch:evidence:2026-10-23:sepolia-current-stand-fork
    title: Pinned existing-stand fork logs and result under cache/sepolia/current-stand/
  - id: s12
    resource: /specs/sepolia-setup-checklist.md
    title: Complete setup coverage inventory and assertion-level status
  - id: s13
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-transfer
    title: Refreshed 0.01 WETH payload, successful eth_call and two fork tests at block 11984953
  - id: s14
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork
    title: Expanded current-stand run — 64 tests across 12 suites at block 11984762
  - id: s15
    resource: https://eth-sepolia.blockscout.com/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec
    title: Public first-transfer receipt and logs at block 11985108
  - id: s18
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-transfer-post-state
    title: User-run cast reads of Committee nonce, WETH balances and orders_weth allowance
  - id: s19
    resource: https://sepolia.etherscan.io/tx/0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1
    title: Orders presign transaction and PreSignature event at block 11985509
  - id: s20
    resource: https://api.cow.fi/docs/#/default/createOrder
    title: CoW Sepolia order submission schema and AppData requirements checked on 2026-10-24
  - id: s21
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-orderbook-flow
    title: Quote responses, transaction receipt and CoW orderbook errors in cache/sepolia/cow-orderbook-flow-2026-10-24/record.md
  - id: s22
    resource: https://raw.githubusercontent.com/cowprotocol/services/v2.384.1/crates/orderbook/openapi.yml
    title: CoW Orderbook API schema checked on 2026-10-24 — quote network fee and zero-fee order fields
  - id: s23
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-zero-fee-policy-test
    title: Quote 1723885 test and 65 current-stand fork results under cache/sepolia/cow-orderbook-flow-2026-10-24/
  - id: s24
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-zero-fee-1723886
    title: Fresh verified quote 1723886 and simulated Committee Safe payload at block 11985723
  - id: s25
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-public-preflight-1723886
    title: Single-block Sepolia preflight for quote 1723886, expected UID and presign state at block 11985733
  - id: s26
    resource: https://sepolia.etherscan.io/tx/0xad7e6140102b41b19e4cd3b0913139bd1baacced2db67b2295fa47a660474063
    title: Committee presign receipt and PreSignature event for quote 1723886
  - id: s27
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-orderbook-1723886
    title: CoW API accepted order 1723886, then marked it expired with zero execution; responses in the local flow record
  - id: s28
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-quote-1724014
    title: Verified quote 1724014 accepted explicit validTo 1792874000 and remained valid until 19:43:39 UTC
  - id: s29
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-preflight-1724014
    title: Pinned Safe call and live balances for the longer-validity retry at block 11985888
  - id: s30
    resource: https://sepolia.etherscan.io/tx/0x8f24409dfef96a59f09125ecb48779154a6af164c0700b1121989d0a58e1befd
    title: Committee presign receipt for CoW quote 1724014 and expected UID
  - id: s31
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-orderbook-1724014
    title: CoW admitted UID 0x2d3b...1610 as open with zero executed amounts
  - id: s32
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-solver-lag-1724014
    title: Latest solver competition remains at block 11985499, excludes the open UID, while Sepolia is at block 11985932
  - id: s33
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-solver-lag-1724014-recheck
    title: At 20:10 UTC the same solver competition remained latest while Sepolia advanced to block 11986056
  - id: s34
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-solver-lag-1724014-recheck-2023
    title: At 20:23 UTC the same solver competition remained latest while Sepolia advanced to block 11986120
  - id: s35
    resource: https://raw.githubusercontent.com/cowprotocol/services/v2.384.6/crates/orderbook/openapi.yml
    title: CoW Orderbook API schema checked on 2026-10-24 — order status, trades, current auction and latest competition endpoints
  - id: s37
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-order-expiry-1724014
    title: CoW API confirms quote 1724014 expired with zero execution; latest competition excludes its UID
  - id: s38
    resource: https://raw.githubusercontent.com/cowprotocol/contracts/main/src/contracts/mixins/GPv2Signing.sol
    title: GPv2 preSignature stores the PRE_SIGNED hash marker, not boolean 1
  - id: s39
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-presign-expiry-recheck
    title: Live CoW API recheck and GPv2 preSignature marker match for expired quote 1724014
  - id: s40
    resource: https://api.safe.global/tx-service/sep/api/v1/safes/0x1d7fC39145bb81dE7b36729760F873396555420a/
    title: Safe Transaction Service current Committee Safe nonce is 4
  - id: s41
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-unsign-1724014-preparation
    title: Decoded Committee Safe payload to unsign expired CoW UID 1724014; not broadcast
  - id: s42
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-unsign-preflight
    title: Unsigned-order preflight blocked by the local Sepolia RPC DNS failure; no transaction sent
  - id: s43
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-safe-and-token-state
    title: Safe-service config and Blockscout on-chain Safe balances and Orders relayer allowance snapshot
  - id: s47
    resource: https://eth-sepolia.blockscout.com/tx/0x86d6286fb911dcac17a20d059e9549b63d9298554d9fe007c98b858c6caa2fc5
    title: Successful Sepolia transaction migrated Committee and Emergency Safe Orders roles at block 11976806
  - id: s49
    resource: urn:clutch:evidence:2026-10-24:sepolia-live-recheck-210553
    title: Account orders remain expired with zero execution and trades; Committee Safe nonce remains 4
  - id: s50
    resource: urn:clutch:evidence:2026-10-24:sepolia-test-attempts-210953
    title: Local workflow suites pass; current-stand and mainnet fork runs cannot reach configured RPCs
  - id: s51
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-unsign-call-not-authorized
    title: User reports NotAuthorized(controller) after the prepared Committee Safe unsign simulation command
  - id: s52
    resource: urn:clutch:evidence:2026-10-24:sepolia-live-recheck-211819
    title: CoW recheck confirms both test orders expired without execution; Safe nonce remains 4
  - id: s53
    resource: urn:clutch:evidence:2026-10-24:sepolia-quote-request-dns-failure
    title: New verified quote request did not reach the CoW API because local DNS could not resolve api.cow.fi
  - id: s54
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-211959
    title: All 65 current-stand fork tests passed at pinned Sepolia block 11986397
  - id: s55
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-unsign-1724014
    title: Corrected Committee Safe unsign payload, successful receipt, zero Settlement presign and captured CoW API state
  - id: s56
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2155
    title: All 65 current-stand fork tests passed at pinned Sepolia block 11986574 after the cancellation
  - id: s57
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-loss-redemption
    title: USD and ETH First-loss redeem, settle and claim receipts with verified share and asset deltas
  - id: s58
    resource: urn:clutch:evidence:2026-10-24:sepolia-twap-public-settlement
    title: Both public TWAP parts settled through CoW with exact Asset balance deltas; short-window attempts recorded
  - id: s59
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2214
    title: All 65 current-stand fork tests passed at block 11986664 after public TWAP and First-loss transactions
  - id: s60
    resource: urn:clutch:evidence:2026-10-24:sepolia-twap-cancel-before-next-part
    title: Emergency removed a separate TWAP before its next part; cached onchain signature is unusable and API status is recorded separately
  - id: s61
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2224
    title: All 65 current-stand fork tests passed at block 11986716 after TWAP part-two settlement and cancellation
  - id: s62
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-market-limit-order
    title: Verified ordinary-order quote, Orderbook admission and expected presignaturePending status after onchain unsign
  - id: s63
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2235
    title: All 65 current-stand fork tests passed at block 11986769 after public order admission and unsign
  - id: s64
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-first-loss-burn
    title: Public USD and ETH burn enactment, early refusal, objection, Voting cancellation and replay refusal; receipts and state in cache/sepolia/public-burn-2026-10-24/
  - id: s65
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-emergency
    title: Public stop, cancellation, recovery admission, sweeps, zero approvals, exact Voting restore and final state in cache/sepolia/public-emergency-2026-10-24/
  - id: s66
    resource: urn:clutch:evidence:2026-10-24:sepolia-current-stand-fork-2301
    title: All 65 current-stand fork tests passed at block 11986901 after public burn and emergency restart; final policy diff has zero differences
  - id: s67
    resource: https://github.com/cowprotocol/services/blob/v2.384.6/crates/database/src/orders.rs#L688-L698
    title: CoW primary source — independent invalidation and latest presign event predicates
  - id: s68
    resource: https://github.com/cowprotocol/services/blob/v2.384.6/crates/orderbook/src/database/orders.rs#L556-L578
    title: CoW primary source — fulfilled, cancelled, expired, presignaturePending and open status precedence
  - id: s69
    resource: urn:clutch:evidence:2026-10-25:sepolia-current-stand-boundaries
    title: Focused ten-case run, 75-case current-stand run and required general fork check
  - id: s70
    resource: https://github.com/cowprotocol/composable-cow/blob/main/src/types/twap/libraries/TWAPOrderMathLib.sol
    title: TWAP primary source for before-start, after-finish and part expiry rules
  - id: s71
    resource: urn:clutch:evidence:2026-10-25:sepolia-zodiac-ui
    title: Zodiac read-only screenshots, accessibility records and pinned allowance snapshot
  - id: s72
    resource: urn:clutch:evidence:2026-10-25:sepolia-teardown-inventory
    title: Canonical order, TWAP, motion and First-loss inventory with completed TWAP cleanup receipt
  - id: s73
    resource: urn:clutch:evidence:2026-10-25:sepolia-governance-emergency-matrix
    title: Six focused cases and all 79 named tests passed with captured source hashes and failure records
  - id: s74
    resource: https://github.com/gnosisguild/zodiac-modifier-roles/blob/820e5bc/packages/evm/contracts/PermissionBuilder.sol
    title: Pinned primary source for execution options replacement and allowance timestamp normalization
  - id: s75
    resource: https://github.com/gnosisguild/zodiac-modifier-roles/blob/820e5bc/packages/evm/contracts/AllowanceTracker.sol
    title: Pinned primary source for checked timestamp plus period arithmetic during accrual
  - id: s76
    resource: https://github.com/safe-global/safe-smart-account/blob/v1.5.0/contracts/Safe.sol
    title: Safe v1.5.0 primary source for approveHash non-owner error GS030
  - id: s77
    resource: urn:clutch:evidence:2026-10-25:sepolia-emergency-matrix
    title: Three emergency cases and all 82 named tests passed with source hashes
  - id: s78
    resource: urn:clutch:evidence:2026-10-25:sepolia-all-public-receipts
    title: Canonical audit of 67 saved or user-identified transactions and 47 exact Safe execution hashes
  - id: s79
    resource: https://docs.cow.fi/cow-protocol/reference/sdks/cow-sdk#low-level-sdk-usage-example
    title: CoW primary SDK example adds quote fee to sell amount before setting order feeAmount to zero
  - id: s80
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-ordinary-sell
    title: Captured-quote regression, corrected Committee sell, canonical settlement, auction inclusion and exact direct-controller refusal
  - id: s81
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-recovery
    title: Public stop, actual recovery settlement to Agent, zero approvals, exact Voting restore, return of funds and Committee smoke
  - id: s82
    resource: https://github.com/circlefin/stablecoin-evm/blob/master/contracts/v1/FiatTokenV1.sol
    title: Circle primary transferFrom source consumes allowance even at uint256 max
  - id: s83
    resource: urn:clutch:evidence:2026-10-25:sepolia-post-correction-fork
    title: All 82 contract cases pass with independent USDC allowance history plus 22 workflow and three quote regressions
  - id: s84
    resource: urn:clutch:evidence:2026-10-25:sepolia-reverse-and-final-inventory
    title: Canonical reverse sell, auction inclusion, final inventory, 124 call traces, approval inventory and 101-receipt audit
  - id: s85
    resource: urn:clutch:evidence:2026-10-25:sepolia-stop-ordering
    title: Two stop-ordering cases and all 84 named fork tests across 13 suites
  - id: s86
    resource: urn:clutch:evidence:2026-10-25:sepolia-lost-response
    title: One mined public transaction with an injected failed response and duplicate-send refusal
  - id: s87
    resource: urn:clutch:evidence:2026-10-25:sepolia-config-inventory
    title: Pinned inventory of 37 manifest labels, 84 passing fork cases and 30 offline workflow checks
  - id: s88
    resource: https://github.com/circlefin/stablecoin-evm/blob/master/contracts/upgradeability/UpgradeabilityProxy.sol
    title: Circle implementation-slot constant and storage lookup
  - id: s89
    resource: urn:clutch:evidence:2026-10-25:sepolia-funding-resume
    title: Four canonical FundSepolia transactions, interruption after wrap, Foundry resume and duplicate-send refusal
  - id: s90
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-partial
    title: Actual half-fill, canonical Trade and balance deltas, remainder cancellation and exact live settlement refusal
  - id: s91
    resource: urn:clutch:evidence:2026-10-25:sepolia-conditional-entry
    title: Conditional entrypoint assertions, compiler diagnosis and pinned execution evidence
  - id: s92
    resource: https://github.com/cowprotocol/composable-cow/blob/main/src/ComposableCoW.sol
    title: Primary create, root/context and swap-guard entrypoint signatures
  - id: s93
    resource: https://github.com/cowprotocol/composable-cow/blob/main/src/types/StopLoss.sol
    title: Primary StopLoss static-input ABI layout
  - id: s94
    resource: https://docs.cow.fi/cow-protocol/tutorials/cow-swap/limit
    title: CoW partial-fill limit semantics and remaining sell-token amounts
  - id: s95
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-buy
    title: Public fixed-target BUY, exact spend/refund, replay refusal and independent fee/clearing-price computations
  - id: s96
    resource: https://github.com/cowprotocol/services/blob/e226e3947ff5912173dbc47b278eb2791249dc4d/crates/shared/src/order_quoting.rs
    title: Primary BUY quote retains target and separate sell cost/network fee
  - id: s97
    resource: https://github.com/cowprotocol/services/blob/e226e3947ff5912173dbc47b278eb2791249dc4d/crates/driver/src/domain/competition/solution/fee.rs
    title: Primary sequential fee policies, cap, volume base and quote-limit adjustment
  - id: s98
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2Settlement.sol
    title: Primary per-trade clearing-price indices, BUY floor, SELL ceiling and proportional fee floor
  - id: s99
    resource: urn:clutch:evidence:2026-10-25:sepolia-rounding-boundaries
    title: Nonzero-remainder partial SELL/BUY, proportional fee floors and cumulative rounding assertions
  - id: s100
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-resting
    title: Fully funded out-of-market limit, two canonical open observations, cancel/return and classification correction
  - id: s101
    resource: https://github.com/cowprotocol/services/blob/12324c1d95e5e4499c28fb2a841de6e77f5a1aaf/crates/model/src/order.rs
    title: API-reported commit serializes legacy class as limit and defines within-market price comparison
  - id: s102
    resource: urn:clutch:evidence:2026-10-25:sepolia-nonce-faults
    title: Controlled dropped submission, real post-mining HTTP timeout, legacy/EIP1559 replacements and canonical reconciliation
  - id: s103
    resource: urn:clutch:evidence:2026-10-25:sepolia-funding-receipt-subsets
    title: Captured four-transaction funding fixture and all 16 saved-receipt subsets in 31 passing workflow tests
  - id: s104
    resource: urn:clutch:evidence:2026-10-25:sepolia-stale-owner-restore
    title: Stale owner grant re-arms a later revocation, selective restart preserves it and all 88 fork cases pass
  - id: s105
    resource: urn:clutch:evidence:2026-10-25:sepolia-safe-config-drift
    title: Safe configuration drift reproduced on a pinned fork, verifier corrected and 44 regression cases passed
  - id: s106
    resource: urn:clutch:evidence:2026-10-25:sepolia-protocol-fee-reconciliation
    title: Seven canonical fills, fourteen protocol fee amounts and fourteen settlement buffer token/block ledgers reconciled
  - id: s107
    resource: https://docs.cow.fi/cow-protocol/reference/core/auctions/accounting
    title: CoW accounting — protocol/network fees, settlement buffers and separate weekly payouts
  - id: s108
    resource: https://github.com/cowprotocol/services/blob/12324c1d95e5e4499c28fb2a841de6e77f5a1aaf/crates/autopilot/src/domain/settlement/trade/math.rs
    title: API-version source — reverse fee policies, uniform/custom prices and surplus-token accounting
  - id: s109
    resource: https://github.com/cowprotocol/services/blob/12324c1d95e5e4499c28fb2a841de6e77f5a1aaf/crates/database/src/trades.rs
    title: API SQL — sellAmountBeforeFees subtracts the signed legacy fee, not all protocol/network fees
  - id: s110
    resource: urn:clutch:evidence:2026-10-25:sepolia-operational-guards
    title: Real temporary-Git CLI refusals, blocked transport, public recipe env guard and wrong-chain funding dry-run
  - id: s111
    resource: urn:clutch:evidence:2026-10-25:sepolia-payload-binding
    title: Stale payload refuses before Forge and clears old success; refreshed declaration and all 88 fork tests pass with bound input hashes
  - id: s112
    resource: urn:clutch:evidence:2026-10-25:mainnet-protocol-paths
    title: Five mainnet WETH boundary/recovery cases and explicit partial mapping for staking, wrappers, converter and savings
  - id: s113
    resource: https://raw.githubusercontent.com/gnosis/canonical-weth/master/contracts/WETH9.sol
    title: Primary WETH9 behavior — zero deposits, caller custody, balance-bound withdrawals and transfer stipend
  - id: s114
    resource: urn:clutch:evidence:2026-10-25:mainnet-lido-submit
    title: Six real Lido v4 fork cases with independent share accounting, pause, stake limit and recovery
  - id: s115
    resource: https://raw.githubusercontent.com/lidofinance/core/v4.0.1/contracts/0.4.24/Lido.sol
    title: Lido v4.0.1 submit, internal share accounting and staking controls
  - id: s116
    resource: https://raw.githubusercontent.com/lidofinance/core/v4.0.1/contracts/0.4.24/StETH.sol
    title: StETH v4.0.1 internal and external share conversion
  - id: s117
    resource: https://github.com/lidofinance/core/blob/v4.0.1/deployed-mainnet.json
    title: Release deployment registry for the tested Lido implementation
  - id: s118
    resource: urn:clutch:evidence:2026-10-25:mainnet-wsteth-paths
    title: Five real wstETH fork cases for exact share rounding, approval boundaries, rollback and emergency recovery
  - id: s119
    resource: https://raw.githubusercontent.com/lidofinance/core/v4.0.1/contracts/0.6.12/WstETH.sol
    title: WstETH release source — wrapper mint, burn and stETH transfer paths
  - id: s120
    resource: urn:clutch:evidence:2026-10-25:mainnet-converter-paths
    title: Seven real DaiUsds fork cases for exact token and Vat accounting, approvals, rollback and dependency recovery
  - id: s121
    resource: https://raw.githubusercontent.com/sky-ecosystem/usds/master/src/DaiUsds.sol
    title: Primary DaiUsds converter source — immutable dependencies and both 1:1 routes
  - id: s122
    resource: https://raw.githubusercontent.com/sky-ecosystem/usds/master/README.md
    title: Primary USDS repository — converter scope, upgradeable token and unpermissioned adapters
  - id: s123
    resource: https://raw.githubusercontent.com/sky-ecosystem/usds/master/src/Usds.sol
    title: Primary USDS token source — mint wards, deny and rely
  - id: s124
    resource: https://raw.githubusercontent.com/sky-ecosystem/dss-exec-lib/master/src/DssExecLib.sol
    title: Official on-chain Chainlog address and dependency discovery
  - id: s125
    resource: urn:clutch:evidence:2026-10-25:mainnet-savings-paths
    title: Eight real sUSDS fork cases for exact share rounding, approvals and budgets, pending yield, rollback and emergency exit
  - id: s126
    resource: https://raw.githubusercontent.com/sky-ecosystem/sdai/susds/src/SUsds.sol
    title: Primary SUsds source — accumulator, share rounding, previews, limits and vault operations
  - id: s127
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-deposit-paths
    title: Eight real Earn deposit cases through existing Oracle/Vault/Queue/Hook, with exact claims, cancellation, proof/account gates and caps
  - id: s128
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/queues/DepositQueue.sol
    title: Pinned primary DepositQueue source — pending, cancellation, pricing and allocated claims
  - id: s129
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/oracles/Oracle.sol
    title: Pinned primary Oracle source — timeout, report validation and queue cutoffs
  - id: s130
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/managers/ShareManager.sol
    title: Pinned primary ShareManager source — independent Merkle/account checks and allocated shares
  - id: s131
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/managers/RiskManager.sol
    title: Pinned primary RiskManager source — pending assets, share conversion and vault cap
  - id: s132
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/managers/FeeManager.sol
    title: Pinned primary FeeManager source — deposit fee in D6
  - id: s133
    resource: /adr/011-launch-scope.md
    title: Launch venues and earlier policy-only asynchronous deposit coverage
  - id: s134
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-redemption-paths
    title: Seven real Earn redemption cases and all fifteen Earn deposit/redemption tests at block 25946643
  - id: s135
    resource: https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/queues/RedeemQueue.sol
    title: Pinned primary RedeemQueue source — locked shares, report cutoffs, batches and timestamp claims
  - id: s136
    resource: urn:clutch:evidence:2026-10-25:mainnet-first-loss-redemption
    title: Real EarnUSD/EarnETH First-loss Safe redemption, Agent-only claims, refusal and revocation recovery on block 25946643
  - id: s137
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-redemption-boundaries
    title: Five additional Earn batch, restriction, oracle rollback, nonzero fee and injected hook-fault cases
  - id: s138
    resource: https://github.com/mellow-finance/flexible-vaults/blob/685be8395aef17e41615cf0bfebfbfbd51c3b582/src/queues/RedeemQueue.sol
    title: Official RedeemQueue source with burn/mint redemption-fee accounting; full bytecode reproduction is not claimed
  - id: s139
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-fee-extremes
    title: Fee-recipient exemption, raw-share rounding, zero-asset claims and maximum-fee zero-net request cleanup on both real Earn venues
  - id: s140
    resource: https://raw.githubusercontent.com/mellow-finance/flexible-vaults/main/src/hooks/BasicRedeemHook.sol
    title: Mellow BasicRedeemHook source checked on 2026-10-25 — liquidity reads and pulls from allowed subvaults
  - id: s141
    resource: https://raw.githubusercontent.com/circlefin/stablecoin-evm/master/contracts/v1/Blacklistable.sol
    title: Circle USDC Blacklistable source checked on 2026-10-25 — blacklister controls account restrictions
  - id: s142
    resource: urn:clutch:evidence:2026-10-25:mainnet-earn-usdc-blacklist
    title: Pinned mainnet-fork run and failed permission probe; logs and source hashes in cache/sepolia/mainnet-earn-usdc-blacklist-2026-10-25/
  - id: s143
    resource: urn:clutch:evidence:2026-10-25:mainnet-first-loss-burn
    title: Six First-loss burn motion cases for both real Earn shares through deployed Easy Track; same pinned full-fork run
  - id: s144
    resource: /research/enabling-vote-rehearsal-2026-10-15.md
    title: Enabling-vote rehearsal evidence and limits for deployed registry factories, Finance, Easy Track and payment permissions
  - id: s145
    resource: urn:clutch:evidence:2026-10-25:mainnet-main09-paused
    title: Full fork run passes 126 tests; paused-USDC top-up rollback and retry with source and log hashes
  - id: s146
    resource: https://github.com/lidofinance/lido-improvement-proposals/blob/develop/LIPS/lip-19.md
    title: LIP-19 limits checks at motion creation and enactment and resets spent amount on first enactment in a new period
  - id: s147
    resource: urn:clutch:evidence:2026-10-25:mainnet-main09-boundaries
    title: Six MAIN-09 cases and full fork suite pass; initial motion-count and month-boundary assertions corrected
  - id: s148
    resource: /adr/006-governance-through-easy-track-factories.md
    title: Governance factory scope and implementation status
  - id: s149
    resource: /test/README.md
    title: Mainnet fork harness limitations and missing factory coverage
  - id: s150
    resource: /specs/sepolia-stand-plan.md
    title: Sepolia stand CoW test pair and public execution scope
  - id: s151
    resource: /adr/010-pre-execution-screening.md
    title: Required screening guard behavior, approval binding and deployment gate
  - id: s152
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: Attested budgets, valuation, reporting and monitoring requirements
  - id: s153
    resource: /adr/011-launch-scope.md
    title: Launch scope, Lido Lend onboarding and required Morpho fork tests
  - id: s154
    resource: /specs/lip-draft.md
    title: Current proposed account graph, budget/report requirements and Lido Lend gate
  - id: s155
    resource: urn:clutch:evidence:2026-10-25:mainnet-fork-confirmation-1128
    title: "Current working-tree fork rerun: 131 passed, 0 failed and 16 skipped across 30 suites"
  - id: s156
    resource: urn:clutch:evidence:2026-10-25:sepolia-check-1130
    title: "Sepolia local checks: 47 Python tests, 132 policy tests and TypeScript compile check pass"
  - id: s157
    resource: urn:clutch:evidence:2026-10-25:sepolia-current-stand-11990591
    title: Current Sepolia stand fork, 88 cases on block 11990591; payload and input hashes verified
  - id: s158
    resource: urn:clutch:evidence:2026-10-25:sepolia-current-stand-11992758
    title: Current Sepolia stand fork, 88 cases on block 11992758; payload and input hashes verified
  - id: s159
    resource: urn:clutch:evidence:2026-10-25:sepolia-check-1855
    title: "Sepolia local checks: 47 Python tests, 132 policy tests and TypeScript compile check pass"
  - id: s160
    resource: urn:clutch:evidence:2026-10-25:sepolia-runtime-provenance
    title: Twelve frozen-constructor runtime matches and two queue child-address checks at block 11992803
  - id: s161
    resource: urn:clutch:evidence:2026-10-25:mainnet-main11-cow
    title: Forty CoW launch-token settlement paths and decimals pass; full fork suite passes 134 tests
  - id: s162
    resource: urn:clutch:evidence:2026-10-25:sepolia-ui-prerequisites
    title: Zodiac workspace and rejected proposal visible; IAB lacks signer and Pilot, Brave requires sign-in
  - id: s163
    resource: urn:clutch:evidence:2026-10-25:mainnet-objection-snapshots
    title: Two real Easy Track and LDO objection tests pass; full fork suite passes 136 tests
  - id: s164
    resource: https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EasyTrack.sol
    title: Pinned Easy Track source for snapshot weights, objection accumulation and rejection threshold
  - id: s165
    resource: urn:clutch:evidence:2026-10-25:sepolia-ui-funding-return
    title: Prepared two-call funding/return envelope at Committee nonce 51; read-only simulation and two fork tests pass
  - id: s166
    resource: urn:clutch:evidence:2026-10-25:precommit-protocol-validation
    title: Full 136-test fork run after compiler repair and exact token allowance expectations
  - id: s167
    resource: https://raw.githubusercontent.com/circlefin/stablecoin-evm/v2.2.0/contracts/v1/FiatTokenV1.sol
    title: Circle transferFrom subtracts the transferred amount from allowance
  - id: s168
    resource: https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v3.4.0/contracts/token/ERC20/ERC20.sol
    title: OpenZeppelin ERC20 3.4.0 subtracts allowance on transferFrom
  - id: s169
    resource: https://sourcify.dev/server/v2/contract/1/0xdAC17F958D2ee523a2206206994597C13D831ec7?fields=all
    title: Verified USDT source, deployment and runtime metadata
  - id: s170
    resource: https://raw.githubusercontent.com/lidofinance/core/v4.0.1/package.json
    title: Lido release pins the wrapper's OpenZeppelin contracts dependency to 3.4.0
---

# Sepolia test results

The [test plan](../specs/sepolia-test-plan.md) contains the cases and transaction sequences. The [coverage checklist](../specs/sepolia-setup-checklist.md) records the status of each obligation. Keep run outcomes, findings and limitations here.

## Latest recorded runs

| Run | Recorded result | Evidence |
|---|---|---|
| Mainnet protocol fork before commit | 136 passed, no failures; 16 separate Sepolia/migration skips across 31 suites; full compilation and token-specific allowances pass | [s166] |
| Mainnet protocol fork with CoW token matrix | 134 passed, no failures; 16 separate Sepolia/migration suites skipped across 31 suites | [s161] |
| Sepolia runtime provenance | 12 exact runtime matches at creation and block 11992803; two queue child-address checks passed | [s160] |
| Current Sepolia stand fork | 88 passed, no failures or skips; block 11992758 | [s158] |
| Earlier current Sepolia stand fork | 88 passed, no failures or skips; block 11990591 | [s157] |
| Sepolia local checks rerun | 47 Python tests, 132 policy tests and strict TypeScript compile passed | [s159] |
| Sepolia local checks | 47 Python tests and 132 policy tests passed; TypeScript compile check passed; no public transactions sent | [s156] |
| Mainnet protocol fork | 131 passed, no failures; 16 separate Sepolia/migration cases skipped across 30 suites; Earn suites at block 25946643 and Treasury rehearsal at block 26249900 | [s147] |
| Mainnet protocol fork rerun | 131 passed, no failures; 16 skipped across 30 suites against the current test sources; source hashes in the result record | [s155] |
| Public CoW executions | Seven canonical fills and their protocol-fee/balance reconciliation | [s106] |

The Asset mainnet harness retains legacy role keys, EOA holders and mocked Clutch governance. Controlled Merkle/account/cap cases add permissions only inside local fork snapshots. These results do not verify the production account graph or external report consensus/signatures [s112][s127].

## Initial fork runs

The initial run at block `11977056`, hash `0xd348dd8716e26bfbc5f611e883d1209e7a9591448f4dc1774a87f62021eb6291`, failed all seven original cases.
The failures exposed obsolete role keys and missing First-loss funding assumptions.
The updated seven shared cases passed at the same block before the additional cases were added.
The initial output is retained as `before-role-update.log` [s11].

The earlier current-stand run on 2026-10-23 passed 14 named cases across three suites at block `11977122` [s11].
The expanded run on 2026-10-24 passed 64 tests across 12 suites, with no failures or skips.
It used block `11984762`, hash `0x20888a42e18d7b5db4fcacb8fd20033796419f18f2d1e89017d27eda14b7c903`.
The solver `0xe40cbca4d703642778b40e1e866ebfec1e619872` came from settlement transaction `0xca03df1e5ea8a3db51cbb65a97219a1a66249ec5b8bd3b091372b60b63f9ae02`.
The deployed authenticator confirmed its authorization at the pinned block.
The runner checked all 64 names, source and manifest hashes, and the canonical block hash after the tests [s7][s14].
The run changed state only inside Forge's local fork; it did not submit a Sepolia transaction [s7][s14].

At 21:05:53 UTC, a fresh CoW account query listed two expired test orders with zero execution, the trades query returned an empty list, and latest competition `78436999` still excluded the latest UID. Committee Safe nonce remained `4` [s49].
At 21:09 UTC, `just --justfile sepolia.just check` passed 17 workflow tests, 105 Sepolia policy tests and the TypeScript typecheck. `just check-docs` passed documentation validation, 38 validator tests, log and onboarding consistency checks. The first current-stand fork attempt failed before tests because the configured RPC could not resolve. A read-only retry later passed 65 tests across 12 suites at block `11986397`, with no failures or skips; the runner checked the block hash after execution and saved source hashes [s54]. `just test-fork` compiled but had 3 passing, 6 failing and 13 skipped tests because the configured `lb.drpc.live` endpoint failed DNS lookup before fork setup [s50].

## TC-SEP-001: First Committee funding transfer

**Public execution:** transaction `0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec` succeeded at block `11985108`, block hash `0xf75bf998d2f422e3ddb4e62272d9c3a2bc5476a9e3309c7c107e668013e4c444`. At the captured read, it had five confirmations. The receipt decoded as Committee `execTransaction` from the prepared owner. Logs show `ExecutionSuccess`, Asset `ExecutionFromModuleSuccess`, WETH transfer of `10000000000000000` from Asset to Orders, and `ConsumeAllowance` for `orders_weth` with `990000000000000000` remaining [s15]. Current `cast` reads show Committee nonce 1, Asset and Orders WETH balances of `10000000000000000` each, and `orders_weth` budget balance of `990000000000000000` [s18]. A public Safe Transaction Service snapshot lists nonce `4` for Committee, `0` for Emergency, `28` for Asset, `31` for Orders and `13` for First-loss. Its owners, thresholds, modules, fallback handlers, guards and Safe versions match the deployment manifest; Blockscout shows `0.01` WETH for Asset and Orders and no token-balance entries for the other three Safes. Direct `allowance` reads show Orders has `uint256.max` WETH and USDC allowances to the CoW Vault Relayer [s43]. The service snapshot does not prove Roles membership; direct chain role comparison and other token approvals remain open. Checks 01–05 and 07 pass. Check 08 is partial until the full role/approval inventory is verified.

**Recorded fork execution:** two exact-payload tests passed, none failed or skipped, at block `11984953`.
`test_exact_committee_transaction_moves_weth_and_consumes_budget` supplies checks 01–05.
`test_controller_cannot_call_the_committee_role_directly` supplies check 06.
The refreshed `eth_call` also succeeded, and a read-only RPC lookup confirmed that the prepared block hash is canonical.
The expanded suite also ran `test_FUND_first_transfer_logs_nonces_and_unchanged_configuration`, which checks the WETH Transfer and Committee Safe logs, token and budget deltas, both Safe nonces, and the unchanged Safe wiring and Orders relayer approvals hash [s14].
These tests use the real fork balances and existing permissions, without balance top-ups or policy application.
The owner is impersonated with a prevalidated Safe signature; browser signing and an actual wallet signature remain open [s13].
The original assertions compare relative deltas.
They do not assert the literal initial balances listed above.
The expanded runner checks the fork's canonical block hash, but it does not create a public transaction receipt.
The saved payload records the pre-state at block `11984953`; local fork results remain separate from the public receipt [s13][s14][s15].

**Evidence:** `cache/sepolia/first-transfer/transaction.json`, `safe-transaction-builder.json`, `FirstTransfer.t.sol`, `fork-tests.log` and `fork-result.json`.
The refreshed transaction file SHA-256 is `2a3fbbb3e164feac2d36319564dd95195df64ba7bd7ed8709ece6e64d6441698`.
The Safe Transaction Builder file SHA-256 is `c3bf3b7c7c6646b4e8d86e691f9227e363222ffe4edd793c995c6387c044ca25`.
The test-source SHA-256 is `9cc2f0cfaf3fe446e5338bbb016bfc8e5bac9f2600036f54fab345cf312e29e4`.
The fork log SHA-256 is `e45e4df3caa320f0af2de687b3d2dc9eb7005cfafe26e4f3d89db4582b284539` [s13].

**Public procedure:** refresh the preconditions; decode and compare the imported Committee transaction; run a fresh simulation; the owner reviews and signs; save the canonical receipt and read the post-state.
The receipt, logs and current token balances support public PASS for checks 01–04 and 07. The user-run read-only call also closes check 06. Keep checks 05 and 08 partial until the Safe nonce and complete configuration diff are read. Do not copy a fork PASS into the public column.
Record negative cases through simulation or on a fork unless a public failed transaction is needed.
Until these checks close, the public case is OPEN [s5][s12][s13].

## TC-SEP-002: Committee CoW presign and orderbook admission

The initial admitted orders expired without execution [s19][s20][s26][s27][s28][s30][s31][s37]. The corrected sell conversion later passed admission, auction inclusion and canonical public settlement to Asset [s79][s80].

The first API quote was verified and used `signingScheme: presign`, zero `appData`, and `validTo` `1792869401` (2026-10-24 19:16:41 UTC). Its API quote expiration was 18:18:41 UTC. The transaction was included at 18:18:48 UTC, before `validTo`; quote expiration and order expiration are separate [s19][s21].

The first simulation used the Asset `operatorModifier` (`0x6b3dB3a3B4D9cB4bd697256E9fb1f1D19992DAC3`) as the Orders modifier. It reverted with `NoMembership`; the outer Safe returned `GS013`. The corrected call used Orders `ordersModifier` (`0x05E79600EC4d5f2c36DFD863ABe62753f3c6447a`) and succeeded in transaction `0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1`. Its receipt emitted `PreSignature` with `signed: true` for the Orders Safe, `ExecutionFromModuleSuccess` for `ordersModifier`, and Safe `ExecutionSuccess` [s19][s21].

The first three orderbook payloads were rejected. Sending the zero hash as `appData` with a separate `appDataHash` returned `InvalidAppData` (`invalid type: integer 0, expected struct Root`). Omitting `appData` or sending `{ "appDataHash": "0x000…000" }` failed to deserialize as `OrderCreationAppData`. Sending the zero hash as the legacy string `appData`, without a separate `appDataHash`, passed app-data parsing and returned `NonZeroFee` (`Fee must be zero`). No submission returned an order UID [s20][s21].

A verified quote request with `onchainOrder: true` returned quote ID `1723883` and estimated network fee `59995100000000`. The API schema says quote `feeAmount` is an estimated network fee, but the order submitted to the API must set `feeAmount` to zero because solvers compute fees dynamically. The `NonZeroFee` response came from copying the quote's estimate into the order. The fast quote was unverified and had no quote ID, so it is not suitable [s21][s22].

A new quote with valid JSON `appData` returned hash `0xc990bae86208bfdfba8879b64ab68da5905e8bb97aa3da5c701ec1183317a6f6`. The subsequent Committee simulation and send estimation returned `GS013`. The Orders signer rule matches only zero `appDataHash`, so the new nonzero hash does not meet the deployed policy [s7][s21].

| Check ID | Acceptance | Public result |
|---|---|---|
| TC-SEP-002-01 | Committee reaches `orderSigner.signOrder` through Orders `orders-operator` and delegatecall | PASS: receipt and `PreSignature` event [s19][s21] |
| TC-SEP-002-02 | Correctly encode CoW order fields, quote and `appData` for API submission | PASS: quote `1723885` passed the full fork suite; quote `1723886` passed Committee Safe `eth_call`, public presign and CoW API admission [s7][s20][s21][s22][s23][s24][s25][s26][s27] |
| TC-SEP-002-03 | CoW accepts the order and returns a UID | PASS: CoW accepted UID `0xf6d2…07bd`; the order GET response is `open` [s27] |
| TC-SEP-002-04 | Order enters an auction, fills and settles to Asset | PASS: corrected quoted sell UID `0xedf5…5052` appears in auction 78438054 and settles in `0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9`, block 11987250. Onchain Trade, filled amount and exact Orders/Asset deltas match the API fulfilled record. Earlier expired UIDs remain historical failed attempts [s80] |
| TC-SEP-002-05 | Wrong modifier, wrong member and policy-mismatched appDataHash fail without state change | PASS: historical wrong modifier returned NoMembership and nonzero appDataHash returned GS013. A fresh public eth_call with the corrected order and direct controller returns the exact NotAuthorized(controller) ABI error; no transaction is sent [s19][s21][s80] |
| TC-SEP-002-06 | Committee unsigns the exact UID through `orders-operator`; Settlement presign becomes zero; API state follows the actual presign and expiry rules | PASS: the corrected literal `bytes32("orders-operator")` call succeeded in transaction `0x84abc74edc3e375cc28e061da3668bf4e5a3c268db5e7ffa1d70d248e0fc8db2`, block `11986562`, and cleared the Settlement marker. Its expired API status is consistent with expiry precedence. A separate still-valid public order changed to `presignaturePending` after unsign, with zero execution. `invalidated: true` is not an unsign requirement: CoW derives it from separate cancellation/invalidation records [s47][s55][s62][s67][s68]. The earlier unclassified `NotAuthorized(controller)` report remains an incident with no captured command [s51]. |

Live recheck at 21:18:19 UTC: CoW order GET and account orders show both UIDs expired, `invalidated: false`, and zero executed sell, buy and fee amounts. The trades endpoint is empty. Visible latest solver competition `78436999` does not include either UID; this does not establish whether an intermediate competition included them. Safe Transaction Service still reports Committee nonce `4`. The state snapshot and endpoint URLs are in `cache/sepolia/cow-orderbook-flow-2026-10-24/live-recheck-211712.json` [s52]. A separate quote-only request for `0.005` WETH with a six-hour order lifetime did not reach CoW because the local shell could not resolve `api.cow.fi`; no quote or order was created [s53].

The unsign trace exposed a key-encoding mistake in the prepared payload. The migration event records the role as the literal `bytes32("orders-operator")`, matching the stand's test code. The saved payload used `keccak256("orders-operator")`, so Roles returned `NoMembership()` and Safe wrapped it in `GS013`. Rebuilding with the literal bytes32 string passed the Safe simulation at block `11986558` and the cancellation transaction succeeded at block `11986562`. The Settlement `preSignature` became zero and Committee nonce became 5. CoW order GET reported `expired`, `invalidated: false`; `/status` reported `active`; trades were empty [s47][s55]. The earlier expectation that unsign must set `invalidated: true` was incorrect. CoW reads the latest presign event separately from its invalidation records; expiry takes precedence over `presignaturePending`. A deleted TWAP registry entry is checked by EIP-1271 and need not change the API invalidation flag [s60][s67][s68].

Quote `1723885` expired at 18:57:11 UTC. Quote `1723886` expired at 19:12:13 UTC, but its `validTo` remained active until 19:32:13 UTC. The presign and API admission succeeded after quote expiry, but the order expired with zero execution and no trades. Quote `1724014` was verified, quote API expiry was 19:43:39 UTC, and `validTo` is 20:33:20 UTC. The full Committee Safe `eth_call` passed at block `11985888`; presign transaction `0x8f24409dfef96a59f09125ecb48779154a6af164c0700b1121989d0a58e1befd` succeeded at block `11985918`. CoW admitted UID `0x2d3b…1610` at 19:42:13 UTC. At 20:23:36 UTC, it remained open with zero executed amounts and no trades. At 20:37:48 UTC, CoW order GET and account orders both reported `expired`, with zero execution; trades remained empty. Recheck at 20:42:54 UTC confirms `expired`, zero execution and empty trades, while `/status` still returns `active`. The on-chain `preSignature` read equals GPv2's `PRE_SIGNED` marker, `uint256(keccak256("GPv2Signing.Scheme.PreSign"))`; the nonzero value therefore confirms the order remains presigned after expiry. Latest competition `78436976` excluded the UID; the permissioned current-auction endpoint returned 403. The order expired without a public settlement; exact auction inclusion remains unknown [s7][s8][s20][s21][s22][s23][s24][s25][s26][s27][s28][s29][s30][s31][s32][s33][s34][s35][s37][s38][s39]. At 20:45:50 UTC, Safe Transaction Service reported Committee Safe nonce `4`, one owner (`0x4CAE…E03c`), and threshold `1`; Blockscout transaction history showed the successful presign as the latest Safe transaction. A Committee Safe payload for `unsignOrder` was encoded with the original typed order, Orders modifier, `orders-operator` key and prevalidated owner signature. Both outer Safe calldata and inner Roles calldata were decoded locally to validate targets, operation, role key and order fields. Fresh reads at 20:47:49 UTC confirmed the presign remained set and Safe nonce remained `4`. The local simulation failed before execution because the configured RPC hostname could not resolve; no transaction was sent [s40][s41][s42].

Quote `1723885` returned a verified estimate with expiration at 18:57:11 UTC. Its order fields with `feeAmount: 0` passed `test_quote_1723885_zero_fee_order_passes_deployed_policy` on the current stand fork at block `11985616`; a read-only `eth_call` of the full Committee Safe transaction returned `true` [s23].

The first full current-stand run at block `11985616` ran 64 tests: 61 passed and 3 funding tests failed because they assumed the full 1 WETH budget remained. The earlier public transfer consumed `0.01` WETH, leaving `0.99` WETH. The tests now use the current remainder and the stored refill timestamp; they do not change on-chain parameters. Full current-stand runs passed all 65 tests across 12 suites, without failures or skips: blocks `11985708`, `11986397`, `11986574`, `11986664`, `11986716` and `11986769`. The hash at block `11986769` is `0x0b4871e64a5dd2b4733f35d367af4a89bb415d634ae5e807c96129f62e848107` [s18][s23][s54][s56][s59][s61][s63].

Public TWAP salt `3` settled both parts. The Orders Safe's EIP-1271 signatures were valid, and the public orderbook reported each UID as `fulfilled`. Part one settlement transaction `0xbb54da9c6ecb83deafbc3f829ca130f26defb0858c8571d308b8cfa1beb62788` filled `0.005 WETH` for `192611792` USDC raw units. Part two transaction `0x58aa3328d61db7c0b28fb4754e518415e8891319a42686453dbc9a051b82e013` filled `0.005 WETH` for `193294323` USDC raw units. The Asset Safe's USDC balance increased from `192611792` to `385906115` across the second settlement, exactly the second trade amount [s58]. Earlier 60-second attempts expired before orderbook submission; a duplicate POST for part one returned `DuplicatedOrder` because the watcher had already submitted the same UID [s58].

The public First-loss redemption flow completed for both synthetic shares. USD transactions were redeem `0x5fdd027bf11b73c23e871ec740b1dd36d62e6928aabf95ea2cd2d3e7e3e1911b`, settle `0x5e01052b037a8a8562055dda98133d1055369bf119af1651b23ef68b1eacdcc2` and claim `0xf205056dab54fbbd21c4ee01834c0a460f8c0a2db1ebf6d01a195eae0652b46e`. ETH transactions were redeem `0x3cc6cbcb01114626aa5c3099a76a84dcc5568057730b437b65b6c49393333573`, settle `0x9b64cec0c1a00b417294173436083acd186e46bbff43590f55ab5c472c09b5dc` and claim `0x6ea6e38d5eb1fb1d140e736dfacdcc1f1f5833b94481faa089b8113b04959c18`. Each claim transferred exactly `3e18` synthetic claim units to Agent; each queue's claimable and request became zero, First-loss share balance decreased by `3e18`, queue share balance returned to zero and total supply decreased by `3e18`. Local preflight attempts with malformed Safe signatures returned `GS023` and `GS020`; no transactions were sent for those payloads. The next submission hit outer account `nonce too low`; it was resent after simulating with nonce `187` and succeeded. These errors did not alter chain state [s57].

## Public burn and emergency run

After public burns and the emergency restart, all 65 current-stand fork tests passed at block `11986901`, hash `0xbedf3b2febae2292664f6fabc5e088cfe50e8265487a7e8a60acf37ac6425a24`, with zero failures or skips. The runner saved the source and manifest hashes and checked canonicality. At the same block, the full policy event reconstruction matched all expected members, keys, targets, functions, options, adapters and allowance configuration; the refreshed local UI payload also matched [s65][s66].

The canonical receipt audit covers 47 public burn/emergency transactions. All 31 Safe executions matched their nonce-derived transaction hash and `ExecutionSuccess`; token and motion post-state checks are stored separately. Public recovery settlement remains open [s65].

- [x] Repeat a fresh policy and account-state comparison before signing. The public emergency drill saved the module, owner, balance and approval baseline; policy reconstruction had zero differences at block `11986816`. After restoration it again had zero differences at block `11986901` [s65][s66].
- [x] Settle an ordinary quoted sell order. The corrected full-fill order settled to Asset; its API class is limit. The resting-limit case and the API classification correction are recorded below [s80][s90][s100][s101].
- [x] Confirm API state after unsign. Settlement presign is zero; before expiry CoW reports `presignaturePending`, `invalidated: false`, and no trades. After expiry it reports `expired`. Both match the pinned status implementation [s62][s65][s67][s68].
- [x] Submit and settle both public TWAP parts; Asset received both exact USDC trade amounts [s58].
- [x] Cancel a separate order and TWAP before execution. The ordinary order's presign was cleared with zero trades. A separate TWAP was removed before its next part; its cached signature reverts `SingleOrderNotAuthed`, including after Voting restart. API metadata is recorded separately from the onchain signature check [s60][s62][s65][s67][s68].
- [x] Complete both First-loss redemption, synthetic queue settlement and claim paths [s57].
- [x] Run both synthetic First-loss burn paths. USD motion 0 and ETH motion 3 enacted after the 60-second window; each reduced First-loss balance and total supply by exactly 2e18. USD motion 1 and ETH motion 4 were rejected by objection; USD motion 2 and ETH motion 5 were cancelled through the test Voting contract. Early enactment failed at each creation block. After the window, rejected, cancelled and already enacted motions all rejected enactment with `ET: motion not pending` [s64].
- [x] Complete public recovery settlement to Agent while Asset operator and all four Orders operator targets are stopped. Sweep, zero approvals, restore the reviewed package through Voting and return funds to Asset; a real Committee funding/return smoke succeeds [s81].
- [x] Execute the separate baseline restoration package through test Voting and Safe approveHash/execTransaction. The module set, four Orders targets and both original relayer approvals were restored; Committee funding and return calls succeeded. Cancelled presigns, TWAP signature and burn motion remained unusable. Final Asset WETH/USDC and Agent balances equal the saved baseline; policy and local UI payload match current state [s65][s66].

## 2026-10-25 boundary and UI evidence

All 75 named current-stand tests passed across 12 suites at block `11987022`, hash `0xe4df2126c659d33158548fda3de5a53104e3171f7e653ecf530e56c43feadfdd`, with no failures or skips. The archived `cache/sepolia/governance-matrix-2026-10-25/previous-75-result.json` records canonicality and source/manifest hashes for that historical run. This is a local fork result [s69].

The ten added cases in `test/SepoliaCoverage.t.sol` close the following assertions [s7][s8][s10][s69][s70]:

| Named test | Assertions | Checklist |
|---|---|---|
| `test_ORD_chain_domain_and_every_typed_field_bind_presign` | Independently construct both EIP-712 domains; change chain, verifying contract and each of the 12 fields; changed UIDs have no presign and the original retains its marker | ORD-07 |
| `test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders` | Repeat Committee and Emergency recovery unsign twice; preserve another presign; settlement rejects with the exact presign error and unchanged balances | ORD-08 |
| `test_SETTLE_overfill_before_and_after_partial_fill_is_atomic` | Sell and buy orders reject total-plus-one and remaining-plus-one; preserve balances and fills; exact remainder settles | SETTLE-03 |
| `test_SETTLE_approval_spender_amount_matrix_and_zero_allowance_transfer` | Both tokens, five spender classes and zero/one/max; Emergency only zeroes relayer; Committee cannot approve; transfer works with zero approval; owner restores exact value | SETTLE-06, SETTLE-07 |
| `test_TWAP_before_start_and_complete_daily_weekly_uid_schedule` | Exact before/after errors; all 104 minimum/daily/weekly parts match independent fields, expiry and UID at interval start/end; EIP-1271 validates each | TWAP-05, TWAP-06 |
| `test_TWAP_changed_merkle_proof_fails_generation_signature_and_settlement` | Changed proof produces ProofNotAuthed in generation, signature and settlement; no debit/fill; original signature settles | TWAP-07 |
| `test_TWAP_both_removal_roles_reject_cached_settlement_and_preserve_other_order` | Both removers cause SingleOrderNotAuthed in cached signature and settlement; preserve balances/fill; distinct unrelated order settles | TWAP-08 |
| `test_TWAP_duplicate_create_preserves_identity_and_refreshes_context` | Same-block duplicate retains identity; later duplicate refreshes expiry/UID and rejects the old signature | TWAP-09 |
| `test_FL_failed_burn_and_claim_preserve_all_queue_and_share_state` | Both shares: oversized burn and illiquid claim fail with exact errors; motion, supply, request, claimable and balances roll back; replenished claim succeeds | FL-08 |
| `test_FL_pending_redeem_survives_cancelled_burn_and_restart` | Both shares: Voting cancels a separate burn while redeem is pending; request survives Asset stop/restart and later settles/claims with expected supply | FL-07 |

The initial focused run at block `11986901` passed five cases and failed three because of test harness errors: repeated manifest parsing exhausted the schedule test gas, and two expected-revert assertions intercepted argument-evaluation calls. Caching addresses/domain and calculating the digest before expectRevert fixed these harness errors. The corrected focused run passed all ten cases. Both logs remain in `cache/sepolia/current-stand/new-boundaries-first-run.log` and `new-boundaries-second-run.log` [s69].

The required `just test-fork` also exited zero: 60 passed, zero failed and 13 skipped across 20 suites. The log and exit record are `required-mainnet-fork-check.log` and `required-mainnet-fork-check-result.json` in the same directory. The 13 skips are setup skips for the separately gated Sepolia suites and migration suite. The dedicated current-stand runner executed all 75 cases without skips. Skipped tests provide no completion evidence [s69].

Read-only Zodiac checks saved screenshots and accessibility text in `cache/sepolia/ui-drill-2026-10-25/`. Asset and Orders policies show the account-specific role keys and Committee caller route. WETH funding renders WithinAllowance with its budget key. Governance renders Nor as Unsupported Condition and exposes operator 3 in JSON. This is a rendering limitation; deployed grants need their separate RPC and execution evidence [s71].

`allowances-pinned.json` records both budget keys at the same canonical block `11987022`. The browser shows neither numeric budget balances nor a block tag, so it cannot prove numerical UI/RPC agreement. The old Outstanding proposal `a7001419-4a97-46ef-b151-69fb4d3843cc` simulates TargetAddressNotAllowed through the Asset operator route. Its nonce was not displayed. The wallet was disconnected and Pilot was absent. No proposal, policy or wallet state was changed; actual UI signing and concurrent/stale-nonce cases remain open [s71].

### UI prerequisite recheck at 2026-10-25T19:14:20Z

The configured migration workspace `25091c1a-4f37-48b1-8d35-f287550481a8` loads in the in-app browser. It lists Asset, First-loss and Orders on Sepolia. The old Outstanding proposal still shows the controller → Committee Safe → asset-operator Roles → Asset route and `TargetAddressNotAllowed`. The wallet is disconnected, Sign is disabled and the page prompts for Pilot. A new Transfer dialog opens, but its From selector shows no options. The dialog was cancelled without creating a proposal. This observation does not establish why the selector is empty [s162].

The available Brave profile redirects the same workspace to Sign in. No credentials were entered. UI-produced payload, nonce/concurrent-proposal checks and actual browser signing therefore remain unverified. The native accessibility click first failed on shadow-root lookup; the documented Playwright locator opened navigation successfully. No proposal, policy or signature changed, and no public transaction was sent [s162].

Screenshots, the proposal DOM snapshot and a login-form observation with authentication-session URLs omitted are in `cache/sepolia/ui-prerequisites-2026-10-25/`. The verification record SHA-256 is `0b1cf56eae45b31e6a09ab3fbebab2fb901d6265aa013e2d50b13fc75e535cf9` [s162].

### Prepared UI funding/return test at 2026-10-25T19:35:38Z

After the user signed in, the Brave session reached the workspace and Sign Transaction Bundle page. Its settled state still reports Wallet disconnected, disables Sign and prompts for Pilot. Connect Wallet offers Browser Wallet, Rabby, Brave Wallet and MetaMask. The chooser remains open. An initial render briefly offered Load in Pilot before detection settled; that initial label does not prove extension availability. The old proposal still reports `TargetAddressNotAllowed` [s165].

A fresh reference envelope uses the Committee Safe, reviewed MultiSendCallOnly, asset-operator and orders-operator. Its two calls transfer one raw WETH unit from Asset to Orders and then return it to Asset. At pinned Sepolia block `11992957`, Committee nonce is `51`. Live checks validate the owner/threshold, modifier avatars/targets, funding prerequisites and batch-executor code hash. Exact `eth_call` execution succeeds. An independently calculated EIP-712 SafeTx hash matches the Safe getter: `0x9b28053a642d83fcdfcf16b22e5e01d51184d27a329dc24c186302199869328b` [s165].

Two tests execute this exact envelope on that fork. The positive case restores both token balances, spends one raw unit of the WETH funding budget, preserves the USDC budget and Asset/Orders nonces, increments the Committee nonce once, and emits the two expected Transfer events plus one Committee ExecutionSuccess. That success event matches the reviewed SafeTx hash and reports zero refund payment. The negative case first verifies that the reconstructed positive envelope equals the prepared bytes. It changes only the return receiver to the controller and confirms the Roles condition error (`0xd0a9bf58`, status `7`). The complete batch returns `GS013` and rolls back the first transfer, funding-budget debit and Committee nonce. Both tests pass without skips. The initial run emitted a cold-cache warning; the strengthened run also passes. Its initial source and log remain in `cache/sepolia/ui-funding-return-initial-2026-10-25/` [s165].

Artifacts are in `cache/sepolia/ui-funding-return-2026-10-25/`: `safe-transaction-builder.json`, `transaction.json`, the fork test, its log and wallet-screen evidence. The builder is for Committee Safe context; its calls already contain role wrappers. It is a prepared reference, not evidence that Zodiac produced the same envelope. No new UI proposal, signature or public transaction exists for this case. Before signing, recheck the live nonce and compare the UI's decoded calls and Safe hash with the reviewed request. OPS-03 remains partial [s165].

The verification record SHA-256 is `b88d991befd97a0966a3348ef4ef2f94dffd0605549d29e2f798252b7745931e`; the builder SHA-256 is `f3bad9265dd456ba0e8b31885d402cc9f83fdedbe0bfd4435cedf1afb686011b`; the fork-test SHA-256 is `b4780dcaba951eeee02bbdd889fccb12b3b3982ffbd24f1b0d0af62f8b5d24b1` [s165].

## 2026-10-25 teardown inventory

The read-only inventory at block `11987063`, hash `0x384989c117e94aa302bed3a078817583c699a1a29123fe119e0dd1dc71d72438`, scanned from deployment block `11955106`. It collected seven presign UIDs and four dispatched conditional-order identities for Orders. All seven presigns were expired; two retained nonzero markers, which do not bypass expiry. All seven motions were terminal: two enacted, two rejected and three cancelled. Both First-loss queues had zero requested and claimable amounts for all 33 timestamps derived from First-loss Safe logs; queue share and claim-asset balances were zero. The synthetic queues emit no request events, so the timestamp inventory uses the Safe's execution-log blocks [s72].

One dispatched TWAP remained registered. Its generator reverted `OrderNotValid("after twap finish")`. Committee removed that completed schedule in transaction `0x32e2ee4b11a78cbac6cff295b7003466598a5fa005ec4deecd53fb58e92bf20c`, block `11987072`, hash `0xa2ca1f1d9be128650b3ab07baf674951271a3606fa62c1883e90d75577dfa64d`. The exact Safe call passed eth_call before signing. Canonical receipt, sender, destination, calldata, ExecutionSuccess, nonce 28→29 and cleared registry entry were verified. Records and the read-only inventory script are in `cache/sepolia/inventory-2026-10-25/` [s72].

The post-cleanup inventory at block `11987074`, hash `0x6e2ea3d39dfb6dddca03b4310073e160e7101f324aa43c41cf47ffc6b449c023`, found all four dispatched identities unregistered. Module lists, token balances, queue entries, motions and presigns match the pre-cleanup snapshot [s72].

The initial inventory decoder failed because current cast JSON wraps ABI values in a data envelope. The corrected reader selects data; the error record is retained. No transaction was sent by the failed reader. The follow-up call-trace inventory covered all 102 transactions that emitted Orders Safe logs from deployment through the post-cleanup block. It excluded reverted branches, decoded successful ComposableCoW create/createWithContext calls from Orders and found the same four identities, with no dispatch-false creates. All four registry entries were false and the current Merkle root was zero. Canonical receipt checks, complete call trees and the summary are retained in `traces/` and `trace-inventory.json`. This closes the stand-scoped teardown inventory in OPS-13 [s72].

The required documentation and policy checks passed. Chromium initially failed to launch inside the sandbox with a macOS permission error. The browser check then passed outside the sandbox: 194 cases. Actionlint and offline zizmor also passed. Both attempts are retained in `cache/sepolia/current-stand/required-check-sandbox.log` and `required-browser-workflows-check.log` [s69].

## 2026-10-25 governance and emergency matrices

All 79 named tests passed across 12 suites at block `11987139`, hash `0x4b9d9a4024ba49c928637732c50b1feef494afd6ebdc8ca5eae8bfc4372c354e`, with zero failures or skips. The current runner checked exact test names, source/manifest hashes and canonicality. Six focused cases also passed at block `11987074`. Logs and pinned primary sources are in `cache/sepolia/governance-matrix-2026-10-25/`; the historical full-run result and log are archived as `previous-79-result.json` and `previous-79-drills.log` under `cache/sepolia/emergency-matrix-2026-10-25/` [s73].

| Named test | Observable assertions | Checklist |
|---|---|---|
| `test_GOV_all_admin_selectors_reject_wrong_keys_and_every_protected_target` | Five admin selectors across 11 key values and ten targets, excluding the valid operator/token pair: 545 forbidden calls fail in Roles; account configuration remains unchanged | GOV-02 |
| `test_GOV_existing_delegatecall_can_only_be_downgraded` | Owner grants DelegateCall/Both locally; both governance grant selectors reject those options; None/Send replace them, allow CALL and refuse delegatecall across eight combinations | GOV-03 |
| `test_GOV_fallback_and_singleton_routes_fail_at_policy_boundary` | Five Safes reject fallback setter, legacy upgrade selector and module delegatecall route in Roles; handlers, singleton storage, owners and modules remain unchanged. The legacy selector is a policy probe; this test does not claim the Safe implements it | GOV-04 |
| `test_GOV_executor_cannot_use_direct_owner_or_module_routes` | Executor cannot enable a module, approve a Safe hash, set a guard, use CALL/delegatecall module execution or drive Voting/Agent; exact owner/module errors and unchanged configuration are checked | GOV-06 |
| `test_GOV_allowance_timestamp_classes_and_overflow_recovery` | Both keys accept zero, past, current, future and maximum timestamps as specified below; failure preserves balances/budget and Voting correction restores transfer; the other key stays unchanged | GOV-05 |
| `test_EM_all_transfer_routes_tokens_and_forbidden_receivers` | Both tokens and both accounts check 21 named/zero/arbitrary recipients: eight allowed routes execute and 76 forbidden calls fail with the receiver-condition error and unchanged balances | EM-04 |

Allowance timestamps have a configuration hazard. Zero normalizes to the current block timestamp; nonzero past/current/future values persist. The maximum uint64 timestamp is accepted, but its addition to the refill period overflows. The next budgeted transfer reverts with `Panic(0x11)` before token movement or budget consumption. Voting can replace the timestamp and the transfer then succeeds. These expectations come from the pinned PermissionBuilder and AllowanceTracker sources and were reproduced for both budget keys on the fork. No public allowance or policy parameter was changed [s73][s74][s75].

The first focused run passed four cases and failed one because the test expected GS031 from approveHash. The captured trace and Safe v1.5.0 source require GS030 for a non-owner. Correcting that expectation produced the six-case pass above; the initial failure remains in focused.log. Existing compiler shadowing warnings and first-read fork-cache warnings were retained [s73][s76].

A parallel public API read used the incorrect v1 competition path and returned 404. The captured official CoW schema specifies v2. At `2026-10-24T23:51:05Z`, the documented v2 endpoint still returned auction `78437480`, ending at block `11986682`, with the earlier public TWAP part-two settlement transaction. This snapshot provides no new ordinary or recovery settlement evidence [s22][s73].

## 2026-10-25 emergency administration and combined recovery

All 82 named tests passed across 12 suites at block `11987194`, hash `0x4ab04fb74cf093fa225d68d39265c1a40787aef336a860be13db861ad838517b`, with no failures or skips. The runner checked test names, source/manifest hashes and canonicality. The three focused cases also passed at block `11987139`. Focused evidence is in `cache/sepolia/emergency-matrix-2026-10-25/`; the full result is in `cache/sepolia/current-stand/` [s77].

| Named test | Observable assertions | Checklist |
|---|---|---|
| `test_EM_asset_administration_selector_key_matrix` | Asset Emergency refuses seven keyed admin selectors across 13 named/zero/foreign key values and four modifiers, both membership booleans, ownership probes, module enables across five Safes/four modifiers and positive approvals for both tokens. Configuration, approvals and both budgets remain unchanged | EM-03 |
| `test_EM_orders_administration_selector_key_matrix` | Orders Emergency runs the same independent matrix through its own modifier and role, with the same unchanged-state assertions | EM-03 |
| `test_EM_combined_filled_order_claims_frozen_governance_and_restart` | Fill one UID and claim both synthetic queues; stop Asset operator and zero relayer approval; permitted governance scopeTarget fails GS104; Voting restores exact configuration; filled UID rejects replay, repeated claims pay zero, an ungranted target stays forbidden and a fresh order settles | EM-09 |

The full run also rechecked `test_role_keys_reject_old_wrong_account_and_non_member`: all four account-specific keys execute; four legacy instances and four wrong-account keys return NoMembership; direct controller use returns NotAuthorized. This existing named case supplies the complete CFG-07 assertions [s7][s77].

The repeated mock claims succeed with zero payout. The test checks Agent balance, request, claimable and supply; it does not invent a queue-level double-claim revert. Filled-order replay returns the exact GPv2 order-filled error. The fresh post-restart order has a distinct UID. These results cover the deployed stand and its synthetic queues [s7][s77].

## 2026-10-25 expanded public receipt audit

The auditor checked 67 unique saved or user-identified public transaction hashes, including the four hashes supplied in the conversation. Fresh receipts match canonical block headers. Available cached block hashes match; the reduced part-one settlement receipt has no saved blockHash, so its saved block number, status, sender, target and complete log sequence were compared with the canonical RPC receipt [s78].

All 47 Safe executions matched the reviewed envelope, signer route, role key, role operation and exact nonce-derived ExecutionSuccess hash. The nonce search covers the parent's nonce through the receipt block's nonce, so another execution in the same block does not produce a false mismatch. The audit also checked both public solver settlement root transactions. `cache/sepolia/receipt-audit-all-2026-10-25/` contains captured RPC evidence, the reader, auditor and result. Historical token/motion outcomes remain separate per-flow evidence; this root-transaction audit does not close all OPS-08 state-delta and request-linkage variants [s78].

Two preparation errors remain recorded: the first reader assumed every cached receipt included blockHash, and the first audit startup read current-stand/result.json while the active runner had invalidated it. The reader now validates the reduced record's available fields; the auditor uses the immutable archived solver observation. Neither failed attempt produced an audit success or sent a transaction [s78].

## 2026-10-25 corrected public sell and recovery

The console/test quote conversion contained a sell-amount error. The saved ordinary and recovery payloads copied quote.sellAmount and changed feeAmount to zero. CoW's primary example requires the signed sell amount to include the quote's estimated fee when the order feeAmount becomes zero. The corrected `scripts/sepolia_cow_order.py` preserves the requested total, quoted minimum buy and receiver. It accepts sell quotes; buy quote conversion requires its own implementation. The helper emits order fields and the existing Safe path signs them [s79][s80].

The captured quote 1723884 regression failed before correction and passed after it. Its expected total comes from the captured sellAmountBeforeFee request. The two original saved driver payloads also reproduce the incorrect conversion. Three quote tests cover the total/minimum, unchanged raw quote, metadata filtering, recovery receiver, zero quote fee and explicit rejection of buy-kind input. Corrected fills do not establish a unique cause for every historical expiry [s80].

| Public case | Direction and receiver | Settlement transaction | Block | API and auction |
|---|---|---|---|---|
| Committee quoted sell | WETH to USDC; Asset | `0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9` | 11987250 | fulfilled, limit; auction 78438054 |
| Emergency recovery after stop | WETH to USDC; Agent | `0x1fb3284c9e2a31a8620264a1e74684ae3fb46063da86b43f1c3c69f43bca548e` | 11987284 | fulfilled, limit; auction 78438089 |
| Committee reverse sell | USDC to WETH; Asset | `0x75df586f42d7a43dc91b9ef7452aa716a1b89bdd6d1a7d64b67447f60b9751c2` | 11987366 | fulfilled, limit; auction 78438172 |

Each receipt matches a canonical block. Decoded Trade UID, owner, token pair, signed fee, filled amount and exact seller/receiver balance deltas match the submitted order and API trade. Competition-by-transaction responses contain each UID and transaction hash. Signed feeAmount is zero; API protocol-fee records remain separate. A last-competition snapshot alone did not describe the current order's execution [s80][s81][s84].

The corrected recovery began with zero policy differences. Committee funded Orders before Emergency stopped the Asset operator and revoked its four Orders targets. The policy snapshot recorded exactly those five differences. Emergency presigned the corrected order to Agent and an authorized public solver settled it. Emergency swept remaining balances and zeroed both relayer approvals. Voting restored the four targets, both prior approvals and the Asset module; the module was enabled last. Agent returned recovered funds to Asset. Committee then funded and returned one raw USDC unit. Final policy reconstruction and refreshed local payload match the declaration [s81].

The first post-swap run exposed the USDC funding test's untouched-budget assumption. It failed with ConditionViolation 17 after the real smoke consumed one raw unit. The test now checks the declared refill/cap/period and computes the current available amount from the saved remainder and elapsed periods. The next run kept the funding test's required public WETH balance and failed because the two real sells had consumed it. The reverse flow used a verified buy quote only to estimate input, then submitted a verified sell quote whose minimum WETH output covers the existing funding-test amount. Its settlement replenished Asset [s83][s84].

The reverse sell also exposed the old max-approval assumption. Circle USDC subtracts transferFrom usage from a max allowance; WETH retains its max allowance. The runner now reconstructs USDC's expected remainder from the latest max Approval and later direct GPv2 settle Trade events. GPv2 emits gross sellAmount after adding the legacy fee, so the history reader consumes that field once. It refuses a missing baseline or unsupported transaction entrypoint. This independent event-derived value is compared with the actual allowance getter on the fork; no public approval was reset to make the test pass [s8][s82][s83].

Captured canonical Approval/Trade logs and independent historical getter observations form `scripts/fixtures/sepolia-usdc-allowance.json`. The workflow tests cover actual USDC consumption, WETH trades before a later reset, a source-derived nonzero legacy-fee boundary, missing approval and unknown entrypoint refusal. The fee-boundary test first detected double counting in the new history reader; correcting the reader made it pass. The logs retain the no-tests regex preparation attempt, the USDC-budget failure, the missing-WETH precondition and the max-USDC-approval failure. `just --justfile sepolia.just check` includes the quote and workflow regressions [s83].

The final contract run passed all 82 names across 12 suites at block `11987444`, hash `0xb704697d396e1b1c354ad5fc9b6872f22e0acb4c7e0f957cb699d27f9897f32e`, with no failures or skips. The runner stores source/manifest hashes and the USDC history proof in snapshot.json and result.json. Twenty-two workflow tests and three quote tests pass separately [s83].

At final inventory block `11987378`, all old unfilled presigns are expired and each remaining unexpired signed UID is fully filled. All seven motions are terminal; both queues have no pending requests or claimable amounts across all 33 execution timestamps. Four dispatched conditional identities are unregistered. The 124 Orders Safe call trees reveal no silent creates and a zero Merkle root. Approval history across all five Safes finds only the two reviewed token/relayer pairs, with no unexpected nonzero pair. Orders and Agent token balances are zero; Asset holds the returned/replenished assets. The final root-transaction audit covers 101 canonical receipts, 70 exact Safe hashes and five solver settlements. Per-flow state evidence remains separate from root-envelope validation [s84].

## Stop ordering and lost-response drills

All 84 named tests passed across 13 suites at block `11987576`, hash `0x94f22957d395f9e53b4e3ab90015cdf97ecf2dac33c9156f5e137ef281a02482`. The runner checked the exact names, source/manifest hashes and canonical block. The result is archived in `cache/sepolia/config-inventory-2026-10-25/previous-84-result.json`. The earlier 82-case result is archived under `cache/sepolia/stop-ordering-2026-10-25/previous-82-result.json` [s85].

`test_EM_zero_and_revoke_before_cancel_repeated_stop_and_retry` covers both token directions and two stop orderings after a partial fill. Revoking the signer permission leaves an existing presign usable. Zero approval prevents settlement without changing fills or balances. Repeated zeroing, revocation and cancellation preserve their intended state. Restoring approval and signer permission does not revive the cancelled UID. An explicit re-sign permits the remaining fill; replay then fails with `GPv2: order filled` [s85].

`test_EM_repeated_switch_pending_burn_cancel_and_restart` covers both First-loss shares. Repeating the Asset switch fails with `ModuleTransactionFailed()`. An uncancelled pending burn can still enact through the independent First-loss module while Asset is stopped. Voting cancellation prevents enactment before and after restart. The cancellation branch preserves share balances and supply [s85].

The initial focused run failed in the test constructor because the enlarged test contract exhausted its deployment gas. Moving these two tests into `SepoliaStopOrderingCoverageTest` produced a two-case pass without changing gas limits or assertions. Both preparation logs remain in `cache/sepolia/stop-ordering-2026-10-25/` [s85].

A public fault drill submitted one Committee Safe zero-USDC transfer. A local RPC proxy forwarded the signed transaction once, waited for successful mining, then replaced the success response with an injected JSON-RPC error. The client exited with code 1. Canonical transaction `0x0075c5eabac1f7462ca75e4ef0c30c9be154a71bc451f614a9d5168537828e32` succeeded at block `11987577`. Its nonce-derived Safe hash matches `ExecutionSuccess`; Committee nonce increased from 36 to 37. Token balances and funding budget remained unchanged. Both fresh and resume guards refused to send the completed run again. The extended canonical root audit passed for 102 receipts, 71 exact Safe hashes and five solver settlements; its result is archived in `cache/sepolia/funding-resume-2026-10-25/previous-102-receipt-audit.json` [s86].

The first preparation attempt used unsupported `cast mktx --data` and failed before signing or broadcast. The repaired command used the full Safe ABI signature. Logs, the proxy receipt, nonce checks and guard results are in `cache/sepolia/lost-response-2026-10-25/`. This drill covers a failed response after mining. Dropped/replaced transactions, a transport timeout and process interruption during partial batches remain open [s86].

The first general fork attempt failed during setup because the sandbox could not resolve the RPC host. The retry with network access passed 60 tests, with 14 setup-gated skips. The general run does not enable the separate Sepolia and migration suites. The first `just check` attempt reached the browser checks, then Chromium failed at macOS `bootstrap_check_in` with permission denied. These are execution-environment failures; the contract drill result above remains a separate record [s85].

## Manifest and runtime inventory

The runner checked 37 manifest labels at block `11987612`, hash `0xc54d14533531690b53fa28543b02c94491e75232b717867c35b773d24e7b4038`. They identify 36 distinct addresses. The only allowed alias is WETH under contracts and tokens. The controller has no code; each named contract has code. The saved inventory records each address, runtime size and keccak256 hash. Thirteen declared dependency hashes and sizes match their prior manifest expectations [s87].

Preparation rejects a wrong network or nested chain ID, a future deployment block, a missing named account, an invalid/zero address, unexpected aliases, inconsistent Asset module labels, missing runtime and a declared runtime mismatch. The runner stores the inventory in snapshot.json and result.json. Offline tests use a captured public manifest; synthetic code tests the refusal boundaries. A wrong-chain main-entry test also verifies that preparation removes an old success and never starts Forge [s87].

All 84 named fork cases passed across 13 suites at this block, with no failures or skips. Thirty offline workflow tests passed. The source and manifest hashes still match. The preceding 84-case run is archived in `cache/sepolia/config-inventory-2026-10-25/previous-84-result.json`. Current evidence is in `cache/sepolia/current-stand/` [s87].

CFG-01 is complete for this manifest. CFG-02 remains partial: runtime observation is not an approved baseline for the stand mocks or USDC implementation. The existing fork assertions also check the four Roles proxy runtimes and the five Safe singleton slots [s87].

A separate read at the same canonical block resolves the USDC implementation through the slot declared by Circle. It points to `0xda317c1d3e835dd5f1be459006471acaa1289068`, with 23464 runtime bytes and hash `0xf4898b096a273d86cda13cce6503404da4005565fae6026a94919b231229d85b`. The record is in `cache/sepolia/config-inventory-2026-10-25/usdc-implementation.json`. The runner inventories the named proxy; this separate observation inventories its implementation. Approved runtime expectations for the remaining dependencies remain open [s87][s88].

## Frozen deployment runtime replay — CFG-02 partial

All 12 stand-contract runtimes match the frozen deployment artifacts at their creation blocks and at Sepolia block `11992803` (`0xcd1f14959452e994c3b6505cb5d0e569ce3501af9a7cc8518c51ba0f38626f21`). The existing package checker also validates the frozen checksums, compiler metadata, source hashes, settings and constructor encodings [s160].

For each of the ten top-level creations, the read-only drill checks the canonical transaction and successful receipt, exact frozen initcode plus arguments, the sender nonce at the parent block, and absence of the target before creation. An `eth_call` replays that creation at the parent block. Its complete returned runtime equals the code at creation and at the pinned block, including immutable addresses [s160].

For the two internal claim tokens, the drill executes the frozen token constructor with the queue controller argument. Both complete runtimes match. A separate check confirms that each queue's `asset()` equals the address derived from its first `CREATE`. The two parent queue constructor replays also match. These checks bind the token runtime to the intended queue [s160].

The USDC proxy still resolves to implementation `0xda317c1d3e835dd5f1be459006471acaa1289068`, with runtime hash `0xf4898b096a273d86cda13cce6503404da4005565fae6026a94919b231229d85b`, as in the earlier observation. This checks drift from that observation. Approval of the stand artifact baselines and the USDC implementation baseline remains open, so CFG-02 stays partial [s88][s160].

The first attempt matched the ten top-level contracts, then failed in the evidence script. It read the child controller from the tail of a dynamic ABI encoding. Reading the third ABI head word corrected that assertion. The subsequent run matched all 12 runtimes, and both child-address checks passed. No public transaction was sent. The block remained canonical after the checks [s160].

Scripts, logs and records are in `cache/sepolia/runtime-provenance-2026-10-25/`. The runtime result SHA-256 is `0507dc04e177d7cee8656baaa3f506c50fd88a5b2974f1b5c7069f4e41f4bf35`; the child-link result SHA-256 is `7c04e4fac1a4821608073e7bcf3b9679729193692f6fcb4108d6aef6b42e7ec3` [s160].

## Public funding interruption and resume

The actual `FundSepolia` script wrapped one wei and planned three transfers of one raw unit each: WETH to Asset and each synthetic First-loss share to First-loss. A local RPC proxy forwarded only the wrap, then refused the second transaction before forwarding it. Foundry exited with an error after its retries. Its saved run retained four planned transactions and one successful receipt [s89].

The saved-run guard permitted resume. Foundry `--resume --broadcast --slow` reused the saved transaction list and sent the remaining three transfers. The proxy checked the exact signed target, input, value, chain ID and nonce before each forward. Each transaction passed a live `eth_call` before broadcast. The proxy forwarded four unique transactions in total [s89].

| Step | Transaction | Block | EOA nonce |
|---|---|---|---|
| Wrap one wei | `0xb4f47a30c5b6acbd4ad377a1aa14ba5fb51af5ea63a47d3ad842971ae7ca712e` | 11987645 | 274 |
| Transfer one raw WETH to Asset | `0xe45e1d44e1275d33feb5423d7465899d5ddbb4ff32e3f080b1525606ba7926ea` | 11987646 | 275 |
| Transfer one raw USD share to First-loss | `0xf800d0a4d626098061c858437b2a271d4c4b4089b2117af9be08520459507992` | 11987647 | 276 |
| Transfer one raw ETH share to First-loss | `0x021e631171ed441266575f0ca6c1dd7850538fd5511887cc865485083f6eac06` | 11987648 | 277 |

Each receipt and transaction matches its canonical block and planned call. At the final receipt block, the controller's WETH balance equals its starting balance; Asset WETH and WETH supply increased by one. Each controller share balance decreased by one, and each First-loss share balance increased by one. Share supplies, both funding budgets and all five Safe nonces stayed unchanged. The final EOA nonce is 278. Both fresh and resume guards refuse the completed run [s89].

The first final check failed on the immediate `latest` nonce read without recording the returned value. A later read-only reconciliation checked nonce after each canonical receipt block and pinned the final balances to block 11987648. It passed without resending a transaction. The resume log also records two provider-nonce retry warnings. The initial mismatch's exact cause remains unconfirmed [s89].

After funding, all 84 named tests passed across 13 suites at block `11987655`, hash `0xa83c53f2f75d544e3d6a1238dab3ff5ac32f0509e762fff1a20ebffb83521ae7`, with no failures or skips. Source/manifest hashes and canonicality passed. The result is archived as post-funding-result.json in the funding evidence directory [s89].

Evidence is in `cache/sepolia/funding-resume-2026-10-25/`: interrupted/complete Foundry records, proxy state, four receipts, pinned reconciliation and client logs. The proxy refused Foundry's anvil_nodeInfo probe; an upstream HTTP 400 and source-lookup/rate-limit warnings remain in the preparation logs. The successful resume uses an isolated broadcast directory and the same Foundry flags as `resume-fund`. It does not verify the recipe's branch, dirty-state or authorization guards. The expanded root audit passed for 106 canonical transactions, 71 Safe hashes and five solver settlements. Its result is archived as receipt-audit-106.json in the funding evidence directory. FUND-12 is complete; OPS-09 still requires its other fault classes [s89].

## Public partial fill and cancellation of the remainder

A verified quote priced 50000000 raw USDC. The test doubled both order amounts and set partiallyFillable to true. It funded Orders with only the quoted half. The independent limit order omitted quoteId; the quote supplied its proportional minimum. CoW documents partial fills for limit orders [s94]. CoW admitted UID `0x11d6246ee428f172842a9c1117592a0bf16d9a4f71359f41c13b2e896417922a84d6fff030e0899a7fbfe505e2dea199d7842cf06add654f` as class limit [s90].

| Path | Transaction | Result |
|---|---|---|
| Committee Safe → Asset modifier → USDC transfer to Orders | `0xa11a4c13fbb78cf5edb65d0264bd803ebd52e36c60c3f85b12bdbd5fc30a77bf` | Funds 50000000 raw USDC and consumes that funding budget amount |
| Committee Safe → Orders modifier → delegated signer → Settlement presign | `0x0aeab6092dda720a0d7c440fc58b71dfe0ce971324a69a0aed4ac2f4a8abb418` | Signs the partial order for 100000000 raw USDC |
| Authorized public solver → Settlement → Vault Relayer → Asset receiver | `0x227e8c6fd9eda88f0dac28222d59cbf03ff20054d9b4e6ace9b7ff3ea4304753` | Settles 50000000 raw USDC for 1255677006260144 raw WETH at block 11987697 |
| Committee Safe → Orders modifier → delegated unsign | `0xd83ede41504d1967fd43e3d4b650b84362b6e0c445f42da576d11a3570b6303d` | Clears presign for the remaining 50000000 raw USDC |

Auction 78438504 contains the exact UID and settlement transaction. The canonical Trade event, API trade, filledAmount and Orders/Asset token deltas agree. The actual buy amount satisfies the signed proportional minimum by integer cross-multiplication. The signed legacy fee is zero; the API separately reports price-improvement and volume protocol fees in the buy token. This case verifies the net receiver amount, not a separate reconciliation of every fee transfer [s90].

After the half-fill, CoW reported open with executedSellAmount 50000000. After unsign, it reported presignaturePending and retained the same executed amounts. Settlement presign is zero and filledAmount remains 50000000. A live eth_call from the authorized solver attempted one more raw unit of the same UID and failed with GPv2: order not presigned [s90].

Orders holds no WETH or USDC dust. Agent balances are unchanged. Asset's USDC decreased by the sold amount and its WETH increased by the event's buy amount. Funding consumption remains 50000000 raw USDC; cancellation does not refund it. The expanded canonical root audit passed for 110 transactions, 74 Safe hashes and six solver settlements [s90].

Evidence is in `cache/sepolia/public-partial-2026-10-25/`: quote and independent order, public receipts, settlement-verified.json, settlement-competition.json, cleanup-result.json and API observations. The resting-limit case below completes ORD-11, with its classification expectation corrected against the API-reported source commit [s100][s101]. The public BUY case below supplies buy-kind evidence. Further fee-accounting variants remain open under SETTLE-04 [s90][s95].

## Conditional-order entrypoint coverage

All 86 named tests passed across 14 suites at block `11987763`, hash `0xd965b015fb4c573f9944b3f7036a18d30a8895c8b6a7d35d32de3b9c87d3302b`, with no failures or skips. The runner checked exact names, source/manifest hashes and canonicality. The archived result is `cache/sepolia/conditional-entry-2026-10-25/result.json`. USDC approval history includes both public reverse and partial sells and matches the fork getter [s91].

The primary ComposableCoW ABI exposes create, setRoot, setRootWithContext and setSwapGuard in addition to the approved createWithContext path. All four selectors also appear in the deployed bytecode dispatcher; deployed-selectors.json records the pinned observation. A handler identifies the order type; StopLoss uses its own static-input layout [s92][s93].

`test_TWAP_alternative_creation_roots_and_guard_setters_are_denied` attempts all four alternative setters as Committee and Emergency. It requires the Roles FunctionNotAllowed condition and unchanged root, root context, order context, registry bit and swap guard after each refusal. Its positive control creates the approved TWAP, obtains a valid signature, then removes it and returns the observed state to baseline [s91][s92].

`test_TWAP_stop_loss_payload_cannot_use_pinned_or_foreign_handler` tests StopLoss-shaped staticInput with an unlisted handler address and with the pinned TWAP handler, for both roles. Each request must fail at the Roles boundary without registering an order or context. This is negative permission coverage. It does not deploy StopLoss, call an oracle or verify a StopLoss handler implementation [s91][s93].

Three focused preparation attempts failed at Solidity's Yul stack limit. Targeted standard-JSON compilation and optimized IR localized the overflow to the inherited First-loss share top-up loop. The first targeted input also missed the existing forge-std remapping; adding it resolved the import errors. A private helper extraction still inlined and reproduced the stack error. The shared fixture now keeps its default top-up helper; this new suite overrides the unused top-up with no work. Other suites retain the same First-loss preparation. The targeted new-contract compilation passes with the existing compiler/optimizer settings. No gas or compiler limit changed. Logs and preparation-errors.json are in `cache/sepolia/conditional-entry-2026-10-25/` [s91].

## Public fixed-target BUY

Verified BUY quote 1724025 requested 1000000000000000 raw WETH. The explicit test order preserved that target, added the separately quoted network fee to the sell maximum and set the signed legacy fee to zero. The signed USDC maximum was 43390199 raw units. The shared sell-only CLI still rejects BUY input; this case constructs its BUY bounds from the captured response [s95][s96].

| Step | Transaction | Block |
|---|---|---|
| Committee funds the maximum USDC input | `0x19768633e82cee24133f4fe94e66230ded0db0cbb72c70694cd330f0c70e6e55` | 11987808 |
| Committee presigns kind BUY through Orders | `0xaed7d46caf6d2c96e1f72116edb2c3e0d16cb8dd9418e469feaeca5efc2d3c33` | 11987809 |
| Public solver settles the fixed buy target | `0x68865292541bb369ae0a1f0aef566f5fb5d3ed64e0ca3e1b84117ef82b2c0edc` | 11987811 |
| Committee returns the unused USDC to Asset | `0xcd07f14b9619ebfda1e0a52550a3974773c9263b6f2b2af2efb34f4787e4b1ef` | 11987822 |

Auction 78438619 contains UID `0x0792f4525db4b4e0c6a76b6c10ea3a2338f692100bdab98ec7d30107ff87def184d6fff030e0899a7fbfe505e2dea199d7842cf06add6ad3` and the settlement transaction. CoW reports fulfilled, class limit. The canonical Trade and block-pinned token deltas show a spend of 40355515 raw USDC and receipt of the exact target. The remaining 3034684 raw USDC returned to Asset. Orders token balances are zero and Agent balances are unchanged [s95].

BUY filledAmount is denominated in the buy token: it equals 1000000000000000. Presign remains set for this filled UID. A live authorized-solver replay fails with GPv2: order filled. The funding budget consumed the full 43390199 transferred to Orders. Returning unused input does not refund that budget [s95].

The captured settlement has duplicate token addresses. The trade selects indices 2 and 3, not the first matching token entries. An independent integer computation uses those indexed prices to reproduce the executed sell amount and verify the signed cap. GPv2 uses floor division for BUY and ceiling division for SELL. An initial preparation note assumed BUY ceiling; the source corrected that expectation. This public BUY division has zero remainder, so it does not establish the nonzero-remainder boundary [s95][s98].

The BUY fee check solves the two fee equations from gross onchain spend and captured policy rates before comparing API amounts. It reproduces a capped price-improvement fee of 391567 and a volume fee of 8069, both in raw USDC. Integer floor equations pass in both forward and reverse directions. The source revision and input/source hashes are retained. These equations reproduce this captured API execution; they do not identify the deployed service build or prove later fee disbursement [s95][s97].

Evidence is in `cache/sepolia/public-buy-2026-10-25/`: quote/order, four receipts, settlement-verified.json, settlement-competition.json, result.json, fee-verification.json and clearing-price-verification.json. Pinned primary source captures are in `cache/sepolia/protocol-fee-review-2026-10-25/`. The root audit passed for 114 canonical transactions, 77 Safe hashes and seven solver settlements. Other protocol-fee branches and fee-transfer reconciliation remain open under SETTLE-04 [s95].

## Partial-fill rounding boundaries

The repeated full run passed all 87 names across 15 suites at block `11987846`, hash `0x9f83fe16d0bcca5d4027043bc441491ce582ed195792d6049f6bf146e5ad4f22`, with no failures or skips. Source/manifest hashes and canonicality passed. The failed and successful runs use the same block/hash and source/manifest hashes. The successful result is archived as post-buy-result.json in the BUY evidence directory [s99].

`test_SETTLE_nonzero_remainders_partial_fees_and_cumulative_rounding` covers both token directions and both order kinds. The signed amounts are sell 1001, buy 500 and legacy fee 10; clearing prices are sell 500 and buy 1001. Each order executes in two parts. The first part has nonzero remainders in both its token-price division and fee scaling [s99][s98].

For SELL, the two fills sell 501 and 500 before fees. Ceiling division yields 251 and 250 buy atoms. Proportional fee floors charge 5 and 4 sell atoms. The completed order therefore buys 501 atoms and debits 1010 sell atoms. For BUY, the two fills buy 251 and 249 atoms. Floor division spends 502 and 498 before fees, and the same fee floors charge 5 and 4. The completed order buys exactly 500 atoms and debits 1009 sell atoms. The assertions also check kind-specific filledAmount and exact order-filled replay refusal [s99][s98].

The new case passed in the first expanded run. That full run failed: Burn setup hit an account-read RPC timeout, and an Orders administration refusal returned empty data while the backend recorded a storage-read timeout. It ran 80 passing and two failing cases; the Burn setup failure prevented its remaining cases from running. The runner retained no successful result. Targeted reads of the same account/storage at the same block then succeeded. The failed log and retry probes are retained in `cache/sepolia/public-buy-2026-10-25/first-87-*` and retry-rpc-probes.json [s99].

## Public resting limit and API classification

The 2026-10-25 version endpoint returned v2.384.6@12324c1d95e5e4499c28fb2a841de6e77f5a1aaf. At that commit, OrderMetadata documents removed order classes and its serializer always emits class limit for compatibility. JIT liquidity uses isLiquidityOrder. Requiring class market was an incorrect test expectation [s100][s101].

The classification computation instead uses the source's integer price comparison and captured verified quotes. The earlier quoted BUY is within its reference market. The new independent SELL is outside its reference market because its buy minimum is ten times the verified quote for the same 10000000 raw USDC input. Both API records correctly serialize class limit. These predicates describe the captured references, not later market prices [s100][s101].

The new order is fill-or-kill and fully funded. Two canonical observations at blocks 11987928 and 11987936, 96 block-timestamp seconds apart, show API open, no trades, zero executed amounts, zero onchain filledAmount, the exact presign marker, the full sell balance and sufficient relayer allowance. API progress reports active. The observations do not establish auction inclusion or indefinite non-execution [s100].

| Step | Transaction |
|---|---|
| Committee funds Orders with 10000000 raw USDC | `0xb50d5c705f739b3803c230c0cb0e2a857d9032f3a24db9cf1f490e24759a0962` |
| Committee presigns resting UID | `0xcbac486b4a95e589bcd2446e50a6fae78b88b9bc4f245084401ab7e9e73800ee` |
| Committee unsigns the unfilled order | `0x351c7473ec3d973e326b41675e820f36c4720d90e694bfaba2a17cdb2e90de85` |
| Committee returns the entire input to Asset | `0x3ce5965fdfe145c4979c621538b28c836114cfe18be559902f3ed749a7c4e2a8` |

After cancellation, presign and filledAmount are zero. A live authorized-solver settlement call for that UID fails with GPv2: order not presigned. All Asset, Orders and Agent token balances equal the pre-test snapshot. The funding budget remains lower by the funded amount. CoW reports presignaturePending with zero executions and no trades [s100].

The initial API observation started before admission and returned 404. A second-observation GET later failed with ConnectionResetError; the first canonical snapshot was retained and only the read was repeated. An initial primary-source request also used the wrong path and returned 404; the source tree supplied the correct path. Errors and the classification correction are retained separately from successful results. Evidence is in `cache/sepolia/public-resting-2026-10-25/`, with version and source captures under `cache/sepolia/protocol-fee-review-2026-10-25/` [s100].

After cleanup, all 87 named cases passed across 15 suites at block `11987961`, hash `0x8535fe9a4a5ee185ad52aaf6bd2cdfbde9c964d79867f119a5bdc8f5e0a607d6`, with no failures or skips. The runner checked source/manifest hashes and canonicality. The result is archived as post-resting-result.json in the resting evidence directory [s100].

Together with the earlier taking quotes, rejection, expiry, full/partial settlements and cancellations, this completes ORD-11 for the stand. The completion uses actual order behavior and the deployed API's compatibility field semantics. The extended root audit passed for 118 canonical transactions, 81 Safe hashes and seven solver settlements [s100][s101].

## Submission loss, HTTP timeout and pending replacements

Four public operational fault cases use the same zero-USDC Committee call. Each signed transaction passes a live eth_call before submission. Across all cases, six canonical transactions produce four intended Safe executions and two zero-value EOA self-transfers. Committee nonce increases by four and EOA nonce by six. The other four Safe nonces, both funding-budget tuples and reviewed WETH/USDC balances across all five Safes and Agent remain unchanged [s102].

| Case | Canonical operation transaction | Block |
|---|---|---|
| Lost submission, then resume of the same raw | `0x20752a5159e0f499c7864188c20e9f9682d5022552a16be7ec309b81e8f7b2e2` | 11988047 |
| HTTP timeout after mining | `0x1e621f229691b74d259d25f4f90e50974bb3ad2aadc7f30b1f774dfe6a4ac30d` | 11988053 |
| Legacy pending replacement | `0x23a62e73fc112e4ab09253e4fe97169eeef85bd78e3ed7d4beca586ed860e2c7` | 11988065 |
| EIP-1559 pending replacement | `0x05b08210d07de4459c29d586e8cdf9d6893b2747403efd06891d10776c92a5d7` | 11988081 |

For lost submission, a controlled RPC proxy acknowledges the locally computed hash without forwarding the raw transaction. Receipt and transaction lookups return none, and latest/pending EOA nonces remain unchanged. The incomplete saved run permits resume. Sending the same raw once produces the canonical receipt. This models an acknowledged but lost submission; it does not establish real-node mempool eviction [s102].

For HTTP timeout, the proxy forwards once and observes the successful receipt after 5.013 seconds. It withholds the response. The HTTP client times out after 45.003 seconds. The operator reconciles the known signed hash without sending again. This is an actual transport timeout after mining, separate from the earlier injected JSON-RPC error [s102].

For each replacement, the operation first queues at nonce N+1 while N remains unused. A second raw keeps the same business calldata and nonce. Legacy gas price doubles; EIP-1559 max fee and priority fee both double. A zero-value self-transfer at N closes the gap. Only the replacement operation receives a receipt. The original remains unmined, its nonce is consumed and Safe execution occurs once. The two filler hashes are `0x65f5d5023704fad7d7f03c360fdf1ce78f3f63bbe5bda80086a350beaa4a841a` and `0x2367411f0494343d535bd27267714c5a4e606774208560b1fa3353c04ea7306c` [s102].

Submitting each old raw again returns ALREADY_EXISTS, not nonce-too-low. An earlier progress note attributed that rejection to nonce consumption; the exact RPC response is recorded here. Absence of the original receipt and the canonical consumed nonce establish the execution result. The local inspector rejects a replacement receipt against the unreconciled original saved hash. After exact sender/recipient/input/value/chain/nonce reconciliation, the canonical record replaces that mapping. Both fresh and resume guards refuse every completed run [s102].

The captured public FundSepolia run supplies the four-transaction fixture for receipt-state boundaries. The offline test enumerates all 16 receipt subsets, including holes. Every incomplete subset remains incomplete and refuses a fresh run; resume remains available for reconciliation. The full subset refuses resume. Thirty-one workflow tests pass. These local checks complement the actual interrupted funding and Foundry resume; they do not claim 16 additional public resumption runs [s103].

After these cases, all 87 names passed across 15 suites at block `11988143`, hash `0x6f77a44c0b6cd1323c0783c85c77284ee9178101b3468fbfed2fe9e5cdbbc794`, without failures or skips. The runner checked source/manifest hashes and canonicality. The archived result is post-fault-result.json in the fault evidence directory [s102].

This completes the stated OPS-09 fault classes together with the public four-step funding resume. A newly signed transaction at a new EOA nonce is a new action; persistent completed-run guards remain necessary. Evidence is in `cache/sepolia/nonce-faults-2026-10-25/`, with per-case prepared intents, proxy/client state, canonical receipts, before/after snapshots, unmapped-replacement rejection and aggregate result. The fixture contains only public transaction/receipt fields. The extended audit verifies 124 canonical transactions, 85 Safe hashes and seven solver settlements. A separate comparison checks 120 cached receipt files, 599 present core fields and 357 log records against newly fetched canonical data. Historical business-state deltas remain outside that receipt comparison [s102][s103].

## Owner restoration after a later revocation

GOV-09 requires a restart to preserve a permission revoked after the earlier restore payload was prepared. ADR 005 uses direct Voting items for restart and provides no restore template. Owner authority accepts a new grant even when it reverses a later removal [s1][s7].

The named fork case `test_GOV_stale_owner_restore_rearms_later_revocation_selective_restart_preserves_it` tests both sequences. Emergency revokes WETH transfer and disables the Asset operator module. Voting then revokes USDC transfer. Replaying a reconstructed earlier USDC grant and enabling the module permits a one-unit USDC transfer. This confirms that owner authority has no automatic freshness check [s104].

The alternative branch starts from the same stopped state. Voting restores only the reviewed WETH transfer and enables the module last. USDC transfer fails with the exact function-not-allowed condition, without changing balances. WETH transfer succeeds. Both budget tuples remain unchanged by restoration; the rejected USDC call also preserves its budget [s104].

The full current-stand run passed all 88 named tests across 15 suites at block `11988226`, hash `0xb2f2ddfdc9d1938cc6a0a3ed141cb38280008fa22a7a685ec7e68735a1466da6`, with no failures or skips. Evidence is in `cache/sepolia/stale-owner-restore-2026-10-25/`. The first direct invocation failed in setUp because SEPOLIA_TEST_SOLVER was absent; it did not execute the scenario. The standard runner supplied a canonically discovered solver for the successful full run. Foundry reported missing local RPC cache files; the full run completed successfully. The first repository check stopped at Chromium startup with EPERM and SIGTRAP inside the sandbox; its log is retained separately from contract failures [s104].

GOV-09 remains partial. The fork proves a reviewed selective sequence and demonstrates the stale-grant behavior. It does not prove that the signing procedure detects or refuses an outdated restoration payload before signature. No public policy mutation was performed for this case [s104].

## Safe configuration drift detection

OPS-05 requires the fresh comparison to detect Safe owner, guard and module changes. The earlier diffPolicy implementation compared modules and policy state but excluded Safe owners and guards. The local fork at block `11988226` reproduced four false matches: owner replacement, guard installation, module-guard installation and adding an owner with threshold two. The existing extra-module control reported a difference [s105].

The corrected verifier reads all five Safes at the report block. Committee and Emergency must have the stand controller as their only owner. Asset, Orders and First-loss must have test Voting as their only owner. Every threshold must equal one. Both guard slots must equal zero. These are reduced Sepolia profile requirements; they do not substitute for production signer sets or screening [s1][s105].

The five local mutations now report exactly the changed owners, threshold, guard, moduleGuard or enabledModules paths. Each case uses a snapshot and reverts after observation. The final baseline matches. Owner and module mutations use local impersonated Safe self-calls. Guard setters use a local interface stub; this tests detection of the stored guard address, not screening or guard execution. No public configuration transaction was sent [s105].

The regression tests use Safe getter response shapes captured from all five deployed Safes on the pinned fork. The 20 named Safe-configuration cases cover four fields on five Safes. Three more cases reject null, short or non-hex storage responses. Before the fix, these 23 checks failed while the existing 21 passed. After the fix, all 44 passed. Existing tests retain membership, role, target, condition, allowance-configuration and consumption checks [s105].

Evidence is in `cache/sepolia/safe-config-drift-2026-10-25/`: before/after reports, actual local receipts, captured getter responses, exact-path assertions and source hashes. The first drill read a local receipt before it was indexed; its snapshot was reverted. The revised drill waits for the submitted hash without resending. The first direct upstream check failed on eth_getCode and produced no successful report; the failure is retained [s105].

The repeat direct upstream read matched the live profile at block `11988276`, hash `0x56b6565e951282c0f9d76ea2e2c0b7ec488bdbfaff795afebd257e7b7013b638`. All 128 Sepolia TypeScript tests and the type check passed. The general fork passed 60 tests with 16 expected skips for separate Sepolia/migration cases [s105].

The policy comparison still excludes Safe versions, singleton and fallback slots, target behavior and transaction success. Configuration drift detection does not prove alert delivery or browser signing. OPS-12 and the production signer/screening requirements remain open [s105].

## Protocol fees and settlement buffer reconciliation

SETTLE-04 now has a separate accounting check for all seven public fills: the two TWAP parts, ordinary SELL, recovery SELL to Agent, reverse SELL, half-filled SELL and fixed-target BUY. Fresh API records contain priceImprovement followed by volume for each fill. The API still reports version `v2.384.6@12324c1d95e5e4499c28fb2a841de6e77f5a1aaf`; the accounting source is pinned to that commit [s106][s108].

The test derives each fee from executed amounts, signed limits, the policy quote and policy rates before comparing the reported fee amounts. It unwinds policies in reverse order. Six SELL executions use the improvement-bound branch; the BUY uses the volume cap. This covers both branches of priceImprovement, not a separate Surplus policy. Every reported fee uses the expected surplus token [s106][s108].

The test selects custom prices by the trade indices. It selects uniform prices from the separate uniform token vector. That vector has a different token order for WETH-selling trades. Uniform/custom price differences provide the total fee; subtracting the independently computed protocol fees gives the network fee. Actual Transfer logs reconcile those components with the surplus-token buffer change. Residual amounts in the other token remain separate [s106][s108].

Each receipt was fetched again and matched its canonical block and saved logs. For each token in each execution, before/after settlement balances match the full block event ledger. Separately fetched logs from the block's other transactions reconcile the transaction ledger with the block balance delta. No other transaction's buffer effect is attributed to the tested order [s106].

CoW accounts for fees and buffers separately from the user's signed legacy fee. Fees can remain in the settlement contract until accounting. A separate transfer to the DAO in each order's settlement is not required by that model. This check proves the captured buffer accounting; it does not prove a later weekly payout [s107].

Six offline tests cover all seven captured fills and reject a changed fee amount, wrong custom-price indices, missing receiver transfer, block balance mismatch or altered external transfer hidden as slippage. They run through `just --justfile sepolia.just check`. The public-only fixture is `scripts/fixtures/sepolia-protocol-fees.json`; evidence and pinned source captures are in `cache/sepolia/protocol-fee-reconciliation-2026-10-25/` [s106].

Two preparation assumptions were corrected. The first seven-fill check assumed the uniform and custom token vectors had the same order. Actual calldata contradicted it. An exploratory check also treated sellAmountBeforeFees as excluding all fees. The API SQL subtracts only trades.fee_amount, the signed legacy fee. The final test checks that definition separately and derives protocol/network fees from the accounting equations [s106][s109].

SETTLE-04 remains partial. These seven rational-rate calculations match the observed integer outputs; they do not establish exact f64 rounding at arbitrary boundaries. Zero-improvement, cap-equality and other unobserved kind/branch combinations, any separately applicable fee policy and weekly payout remain unverified. No new order or public transaction was needed for this reconciliation [s106][s108].

## Operational guard entrypoint drill

OPS-10 now has a local CLI drill. It copies the current Sepolia entrypoints into a disposable repository. It uses real Git commands, a local bare origin and an actual pushed fixture commit. The fixture uses synthetic addresses and a public network dependency manifest. It loads no local dotenv or credential file [s110].

The publisher resolve CLI refuses a wrong branch, detached HEAD, tracked dirty file, untracked file and unpushed commit before any transport request. Separate runs refuse missing human opt-in, CI, missing test API credential, mismatched workspace, insecure API origin and a changed prepared manifest. A clean/pushed run against a simulated chain 1 makes only eth_chainId, then refuses the chain. The preload intercepts every fetch and blocks hosted traffic; no resolve/apply API call is sent [s110].

The actual just _guard recipe accepts its complete test env as a positive control. It rejects missing opt-in, account, sender or RPC; opt-in value two; CI; PRIVATE_KEY; and EXECUTOR_KEY. Every refusal occurs without transport access or a signing command. Across these cases and the CLI cases, 21 scenarios run through three automated test methods. Test credentials must not appear in their output, and no hosted-attempt directory may be created [s110].

The funding script has a separate chain check. Its read-only simulation on chain-1 fork block `25946643`, hash `0x1101057a858f2a4beb0eac0b92ebe22f6aa16d2576f86be99c219fceda652c47`, with Sepolia opt-in set refuses with Sepolia opt-in required before funding. The invocation requests neither broadcast nor a keystore/account. Its source hash, fork block/hash and complete sanitized output are retained. Foundry source-map warnings are separate from the expected revert [s110].

The first local run expected the detached-HEAD error to contain a detached HEAD. Actual git rev-parse returns HEAD, and the CLI refuses with not HEAD. The assertion now checks that observed diagnostic; the production guard was unchanged [s110].

The three CLI tests run in just --justfile sepolia.just check. Evidence is in `cache/sepolia/operational-guards-2026-10-25/`. OPS-10 remains partial: these are local refusal cases and a wrong-chain simulation. They do not exercise a real hosted apply with human credentials, the real workspace session or a public signer prompt. Those boundaries remain separate from the successful synthetic guard checks [s110].

## Bind the current-stand result to its saved declaration

OPS-11 now includes the saved local SDK declaration. The runner reads both funding allowance tuples at the fork block and recompiles the serialized payload with those stored balances and timestamps. The verifier makes no network or hosted call and receives only PATH in its env. It returns the exact byte hash, compiled-call count, pinned block/hash and funding readback [s111].

The runner checks that proof against its own captured inputs before Forge. It hashes 12 test/validator/template/lockfile inputs plus the manifest and payload. It compares every hash before Forge and after all test cases. Missing, malformed, stale or changed inputs cannot produce a passed result. The canonical block check and exact named-case/suite checks remain in place [s111].

The old declaration matched its old allowance snapshot but failed against block `11988411`. The actual new runner rejected it before reaching Forge and removed the previous success report. Local declaration preparation then refreshed payload/context from block `11988432`; the policy diff was zero and no public permission or funding budget was reset [s111].

Final review found that the first hash capture happened after RPC preparation. A regression changes the payload, manifest or source during that preparation. All three variants reached validation before the fix; they now stop before validation or Forge and leave no old success. Source hashes are captured at the start; the manifest hash uses the exact parsed bytes, and the payload hash is captured before inventory reads [s111].

The refreshed run passed all 88 named cases across 15 suites at block `11988436`, hash `0x2a7b32a4a0981854da305f916762b68079a4d954632ece2f69325af2dadc9eaa`, without failures or skips. The saved proof recompiles 63 policy calls. Foundry missing-cache warnings are retained separately from the passing assertions [s111].

The offline workflow suite passed 35 tests. New cases cover exact funding tuple shape/widths and changes to payload, manifest and test source. Four TypeScript payload-proof cases check exact byte hashes, stale balance/timestamp for both budgets, missing readback and changed permissions. All 132 Sepolia TypeScript cases passed. Evidence is in `cache/sepolia/payload-binding-2026-10-25/`, including the old inputs, expected refusal, refreshed inputs and bound result [s111].

OPS-11 is complete for the current-stand runner. The proof covers the local serialized declaration and its relation to the pinned fork; it does not certify a hosted workspace state, a publication or a transaction executed from that declaration [s111].

## Mainnet protocol paths under the committed fork profile

The mainnet harness uses real protocol contracts at block `25946643`, hash `0x1101057a858f2a4beb0eac0b92ebe22f6aa16d2576f86be99c219fceda652c47`. Its Safe and Roles instances are local fixture deployments. Governance heads are mocks, and the role holders are EOA stand-ins. The committed artifact still uses operator and emergency. These results do not establish the account-specific production role graph or signer configuration [s112].

The new `MainnetWethCoverageTest` passes five named cases against mainnet WETH and the deployed Safe/Role implementations. Expected balances use native ETH conservation and one WETH unit per deposited wei. Expected events name the calling Asset Safe. The WETH backing balance must change by the same amount [s112][s113].

| Named case | Verified assertions |
|---|---|
| `test_MAIN01_operator_zero_one_and_full_balance_roundtrip_events` | Zero, one wei and the entire funded balance wrap and unwrap. Safe ETH/WETH and contract backing reconcile exactly. Deposit/Withdrawal topics and amounts match. |
| `test_MAIN01_missing_eth_and_excess_value_roll_back` | Missing ETH, balance-plus-one and max value fail at module execution with unchanged balances. Funding the prerequisite permits one wrap. |
| `test_MAIN01_both_unwrap_roles_zero_missing_excess_and_max_then_retry` | Both roles handle zero and one-unit unwrap. Missing tokens, balance-plus-one and max amount fail without debit. Exact remaining balance unwraps once. |
| `test_MAIN01_role_operation_value_fallback_and_malformed_routes` | Emergency cannot wrap. Value on withdraw, delegatecall, another withdraw selector and raw ETH fallback are refused by Roles. Selector-only withdraw executes as zero; a nonzero truncated argument fails inside the called route. |
| `test_MAIN01_stop_recovery_owner_restart_and_exact_final_balances` | The switch blocks operator wrap and unwrap with GS104. Emergency unwrap still works. The mock owner path restores the module; a new roundtrip restores exact initial balances and backing. |

All five passed with no skips. The deployed WETH runtime hash and a separate pinned eth_call confirm selector-only withdraw returns successfully. The first run incorrectly expected a missing ABI word to revert. It also used a one-call prank for a multi-call owner helper and received OWN: not owner. A second attempt expected FunctionSignatureTooShort for raw fallback; the actual Roles refusal is ConditionViolation. Tests now assert these observed layers and preserve the original failures/traces [s112].

The full mainnet fork passed 65 tests across 24 suites, with no failures. Its 16 skips belong to the separate Sepolia/migration cases. Each mapped test name below appears as PASS in that run. The mapping names only assertions present in the test bodies [s112].

| Checklist row | Existing evidence | Still required |
|---|---|---|
| MAIN-02 | Six `MainnetLidoCoverageTest` cases check exact shares/balances, one-wei and full-balance submission, zero/missing ETH, referral/admin refusal, pause/resume, stake-limit exhaustion/refill and stop/restart [s114]. | Production role graph and pause authority, full oracle report/rebase and fee distribution. |
| MAIN-03 | Five `MainnetWstethCoverageTest` cases check exact share conversion/dust, custody, approval ceiling/zeroing, failed-call rollback, both unwrap roles and stop/recovery/restart [s118]. | New production role/signing graph and wrapper accounting through a full oracle-induced rebase cycle. |
| MAIN-04 | Seven `MainnetConverterCoverageTest` cases cover exact balances/supply/Vat RAD, zero/one/full amounts, approval boundaries/zeroing, refusal rollback, mint-permission loss/retry and stop/recovery/restart [s120]. | Production role/signing graph and behavior after a replacement USDS implementation. |
| MAIN-05 | Eight `MainnetSavingsCoverageTest` cases cover exact deposit/redeem/withdraw rounding, custody/supply/events, maxima, full approval budget accounting, rollback, one-second yield and Emergency stop/exit/restart [s125]. | Production role/signing graph, replacement implementation and longer-period rate/governance scenarios. |

The first docs rebuild stopped on 11 stale onboarding source pins after INV-009 gained the WETH test mapping. Review confirmed that the invariant definition/state and the guide content hashes were unchanged. Only the 11 INV-009 source fingerprints were updated after checking the referenced statements. No human verification or review-status promotion was recorded [s112].

MAIN-01 through MAIN-05 remain partial. The five WETH cases cover the listed currency routes in the committed legacy-key profile; they do not replace the pending mainnet role migration or the production ownership/signing checks. No public transaction or policy update was made. Evidence is in `cache/sepolia/mainnet-paths-2026-10-25/` [s112].

## Lido submission boundaries and recovery

Six named cases in `MainnetLidoCoverage.t.sol` pass without skips at mainnet block `25946643`. The proxy reports version 4 and implementation `0x028271E30a695c0527A0C50cA30603feD004cDb0`, which matches the release registry. Captured runtime hashes and primary source files remain with the results [s114][s117].

Expected minted shares use floor(value × internalShares / internalEther). The test derives internal shares and ether by subtracting the external totals from the global totals. Both external totals are nonzero at the pin. Post-submit checks derive the external ether and Safe/observer balances from the new internal share rate. They also check native ETH, buffered ETH, unchanged observer shares, stake-limit debit and the Submitted event. One wei can mint zero shares [s114][s115][s116].

| Named case suffix | Verified assertions |
|---|---|
| `both_roles_exact_internal_share_math_one_wei_and_full_balance` | Both roles submit one wei, one ETH and the full funded balance with exact independently computed accounting. |
| `zero_and_missing_eth_fail_without_shares_or_buffer_changes` | Both roles fail with unchanged state; direct submission identifies ZERO_DEPOSIT; restored funding permits retry. |
| `referral_delegatecall_fallback_short_data_and_admin_are_refused` | Both roles reject nonzero referral, delegatecall, fallback and pause/resume selectors. Selector-only submit returns an empty revert inside Roles. |
| `real_acl_pause_preserves_state_resume_retries_both_roles` | Real ACL grants a fork-only prerequisite; actual pause blocks both roles; resume permits retry. |
| `stake_limit_plus_one_exact_exhaustion_and_next_block_retry` | Limit-plus-one fails; exact limit succeeds; the next wei fails; next-block refill permits a new submission. |
| `asset_switch_preserves_emergency_staking_and_owner_restart` | Stopped operator fails with GS104; Emergency can submit; owner restoration permits operator submission. |

The pause case uses the real DAO Agent permission manager to grant the fixture principal staking-pause/control permissions on the fork. It does not prove the production pause-holder graph. The first short-data assertion expected CalldataOutOfBounds; the trace showed an empty Roles revert before Safe or Lido execution. The corrected test asserts empty return data and unchanged state. The original failure and trace are retained [s114].

The combined mainnet fork passed 71 tests across 25 suites, with no failures. Its 16 skips are separate Sepolia/migration cases. All six named Lido cases appear as PASS, and their recorded source hashes match the tested files [s114].

MAIN-02 remains partial. The fixture uses legacy role keys, EOA holders and mocked governance heads. A complete oracle report, fee distribution and production role/signing graph remain open. No public transaction or ACL change was sent. Evidence is in `cache/sepolia/mainnet-lido-2026-10-25/` [s114].

## wstETH conversion, approvals and emergency recovery

Five named cases in `MainnetWstethCoverage.t.sol` pass without skips at mainnet block `25946643`. The tests use the real wrapper and stETH contracts, with the committed legacy-key fixture [s118].

Wrap checks independently derive minted wstETH and transferred backing shares from the internal stETH share rate. Unwrap derives the stETH output, then the shares transferred by that output. Both conversions round down. The tests check exact Safe shares, wrapper backing shares, wstETH balance and supply, allowance consumption and stETH custody balances. They check unchanged internal totals, Safe ETH and attacker wstETH [s118][s115][s116][s119].

| Named case suffix | Verified assertions |
|---|---|
| `exact_rounding_one_wei_partial_full_and_both_unwrap_roles` | One-wei, two-wei, one-ETH and full-balance wraps consume exact approvals. Both roles unwrap nonzero results. A one-wei wrap can mint zero; zero unwrap fails. |
| `approval_ceiling_zero_wrong_spender_and_emergency_authority` | Ceiling-minus-one succeeds; ceiling, ceiling-plus-one and max fail. Wrong spender fails. Operator and Emergency can zero the approval; Emergency cannot raise it. Reapproval permits wrap. |
| `missing_short_approval_balance_excess_max_and_retry` | Zero wrap, absent/short allowance, balance excess and max fail without changing tracked state. Both roles reject zero/excess/max unwrap. Restored prerequisites permit wrap and Emergency unwrap. |
| `emergency_wrap_value_delegatecall_fallback_and_receiver_variants_refused` | Emergency cannot wrap. Both roles reject value-bearing unwrap, delegatecall, raw ETH fallback and a receiver-bearing unwrap selector. |
| `stop_emergency_zero_approval_unwrap_owner_restart` | Operator unwrap fails with GS104 after module disable. Emergency can zero the allowance and unwrap. The safety module stays enabled. Owner restart permits operator reapproval and a new roundtrip. |

MAIN-03 remains partial. The tests retain the legacy role keys, EOA holders and mock owner/governance heads. The production account graph and a complete oracle-induced rebase cycle remain open. No public transaction or policy update was sent. Evidence is in `cache/sepolia/mainnet-wsteth-2026-10-25/`, with the primary source capture, runtime hash and test source hashes [s118].

## DAI and USDS converter paths and dependency failure

Seven named cases in `MainnetConverterCoverage.t.sol` pass without skips at mainnet block `25946643`. Setup reads the converter's token and adapter addresses and checks their common Vat. Both directions must exchange equal raw token amounts. Assertions independently track Asset balances, both token supplies, consumed approvals, converter token balances and each adapter's Vat credit. The converter event must identify the Asset Safe as caller and receiver [s120][s121].

| Named case suffix | Verified assertions |
|---|---|
| `both_directions_zero_one_partial_full_and_largest_single_approval` | Both routes accept zero, one raw unit, a partial amount, full fixture balance and the largest amount under one permitted approval. Exact ERC-20 and Vat deltas reconcile. |
| `both_approval_ceilings_zero_wrong_spender_and_emergency_zero` | Both tokens accept ceiling-minus-one and zero. Ceiling, ceiling-plus-one, max and a wrong spender fail. Emergency can zero each approval but cannot raise it. |
| `both_directions_missing_short_approval_balance_excess_max_and_retry` | Missing/short approval, balance-plus-one and max fail without changing tracked balances, supplies, allowances or Vat credit. Correct prerequisites permit full-balance conversion. |
| `both_directions_wrong_receivers_value_delegatecall_and_emergency_conversion_refused` | Both routes reject attacker/Agent recipients, nonzero value, delegatecall and Emergency conversion. |
| `stop_emergency_zero_and_return_both_tokens_owner_restart` | Operator conversion fails with GS104 after module disable. Emergency sends both tokens to the Agent. The safety module stays active. Owner restart and fixture funding permit another conversion. |
| `dai_join_cage_refuses_known_actors_without_balance_changes` | Asset, operator, Emergency, Chainlog Pause Proxy and current End each have ward zero and fail cage. live remains one; both conversions still work. |
| `usds_join_mint_permission_loss_reverse_exit_and_real_rely_retry` | The real Pause Proxy ward removes UsdsJoin's mint permission on the fork. DAI→USDS fails atomically with Usds/not-authorized; reverse conversion works. A real rely restores the forward route. |

The converter has immutable dependencies and no own pause or upgrade API. USDS is upgradeable. The primary repository states that production DaiJoin has no wards. This run verifies cage refusal for the five named callers; it does not prove an exhaustive authority graph. It does not grant a new cage permission or replace token code to force a positive case [s120][s121][s122][s123].

The first compile caught an address checksum error. An initial discovery probe used incorrect remembered addresses; the corrected on-chain Chainlog probe supplies the tested addresses. The first dependency run expected Pause Proxy to cage DaiJoin and failed at ward zero. Captured legacy and standard auth-event queries found no matching events. The final case records actual cage refusals. The successful USDS deny/rely drill uses a separately confirmed ward. Original compiler output, failed assertions and probes remain in the evidence [s120][s124].

MAIN-04 remains partial. The fixture retains legacy keys, EOA holders and mocked governance heads. Starting token balances use local deal; they do not prove Treasury funding. Behavior under a replacement USDS implementation and the production role/signing graph remain open. No public transaction or permission update was sent. Evidence is in `cache/sepolia/mainnet-converter-2026-10-25/` [s120].

## sUSDS vault accounting, budgets and exits

Eight named cases in `MainnetSavingsCoverage.t.sol` pass without skips at mainnet block `25946643`. Setup verifies the USDS asset and implementation `0x4e7991e5C547ce825BdEb665EE14a3274f9F61e0`. A public drip crystallizes existing accrual before the assertions. Initial USDS balances use local deal [s125].

Expected deposit shares round down from assets × RAY / chi. Expected redeem assets round down from shares × chi / RAY. Withdraw burns the ceiling of assets × RAY / chi. Tests compute these values before execution, then compare previews, exact Safe/vault balances, share supply, token allowance and Deposit/Withdraw events. Exit views must match independently calculated maximum shares and assets [s125][s126].

| Named case suffix | Verified assertions |
|---|---|
| `deposit_zero_one_partial_full_exact_shares_and_custody` | Zero, one raw unit, partial and full fixture balances deposit with exact custody and share deltas. maxDeposit advertises uint256 max; the other cases test execution constraints. |
| `both_roles_redeem_zero_one_partial_full_and_next_unit_failure` | Operator and Emergency redeem zero, one share, half and full balance. The next share after full redemption fails atomically. |
| `both_roles_withdraw_zero_one_partial_exact_max_and_plus_one` | Both roles withdraw zero, one raw unit, a partial amount and exact max assets. Max-plus-one fails without state changes. |
| `budget_counts_replaced_approvals_zero_is_free_and_deposit_is_unbudgeted` | Replacing an approval charges its full new amount. Exact budget exhaustion rejects one more unit. Zero approvals remain available to both roles; deposit and redemption do not debit the key. Unrelated budget tuples stay unchanged. |
| `failed_deposits_and_max_exits_preserve_balances_rates_and_budgets_then_retry` | Missing/short approval, insufficient assets and max deposit/exit arguments fail without changing tracked balances, supply, allowance, chi/rho or budget tuples. Restored funds permit retry. |
| `wrong_receivers_owners_referral_mint_value_delegatecall_and_emergency_deposit_refused` | Both roles reject wrong exit receivers/owners, value, delegatecall, referral deposit and mint. Emergency also rejects a valid-receiver deposit. |
| `one_second_pending_yield_preview_and_failed_drip_rollback_then_success` | One-second projected chi and minted USDS yield match independent arithmetic. A failed deposit rolls back drip as well as tokens/budgets. A funded call then accrues yield once and exits through Emergency. |
| `stop_emergency_zero_withdraw_redeem_and_owner_restart` | Stopped operator deposit fails with GS104. Emergency zeros approval, withdraws and redeems the remainder. The safety module stays enabled; owner restart permits reapproval and deposit. |

The pending-yield case uses exactly one second, so expected chi is ssr × previous chi / RAY. Expected new backing is the difference between the old and new total-share asset values. The test checks minted USDS supply and exact vault backing as well as the Asset's position. It does not copy the contract's multi-step exponentiation algorithm [s125][s126].

MAIN-05 remains partial. This fixture uses legacy role keys, EOA holders and mocked governance heads. The production role/signing graph, replacement implementation and longer-period rate/governance scenarios remain open. No public transaction, parameter or permission update was sent. Evidence is in `cache/sepolia/mainnet-savings-2026-10-25/`, including the pinned interface probe, primary source capture, runtime hashes and test results [s125].

## Real EarnUSD and EarnETH deposit queues

Eight named cases in `MainnetEarnCoverage.t.sol` pass without skips at mainnet block `25946643`. They extend the earlier policy-only deposit coverage in ADR 011. The tested paths are USDC→EarnUSD and wstETH→EarnETH. Setup reads queue registration, vault, token, share manager, risk manager, fee manager and oracle from the deployed contracts. USDC uses fixture funding. wstETH comes from actual Lido submit and wrap [s127][s133].

Deposit claim takes an account, and the queue mints that account’s own priced request. It cannot redirect another account’s deposit. Roles pins the argument to Asset [s127][s128].

Requests check exact Asset/queue token deltas, amount/timestamp, unclaimed count, pending risk assets, consumed token allowance and unchanged approval-budget tuples. Approval consumes its own key; cancellation does not refund the key. Priced claims use floor(amount × reduced report price / 1e18). Reduced price subtracts the independently calculated D6 fee. Claim must move the exact quantity from allocated shares to active Asset shares without changing total shares, token custody or risk pending state [s127][s128][s130][s131][s132].

| Named case suffix | Verified assertions |
|---|---|
| `both_venues_exact_request_duplicate_early_claim_both_cancellers_and_no_refund` | Both assets create exact requests. A duplicate fails with PendingRequestExists. Early claim preserves the request. Operator and Emergency cancel with exact refunds; repeated cancellation fails with NoPendingRequest. |
| `both_venues_real_oracle_early_eligible_reports_both_claimers_and_no_double_claim` | Real report-role holders submit through Oracle→Vault→Queue→Hook. An early cutoff leaves the request unpriced; a later eligible report prices it. Both roles claim exact shares. Claimable cancellation fails with ClaimableRequestExists; repeated claim changes nothing. |
| `both_venues_new_deposit_auto_claims_priced_request_referral_and_open_root_proof` | A new deposit claims the old priced request and creates one new pending request. Referral metadata pays no tokens or shares to the referral address. At the observed zero root, an arbitrary proof does not restrict deposit. |
| `both_venues_real_pause_cancel_retry_and_whitelist_flag_restoration` | Existing holders pause the queue and change the whitelist flag on the fork. Deposit fails with QueuePaused or DepositNotAllowed. Cancellation remains available while paused; restored configuration permits retry. |
| `both_venues_zero_missing_approval_balance_failure_and_policy_receiver_pins` | Zero fails with ZeroValue. Missing allowance and insufficient assets fail atomically. Emergency cannot deposit; both roles reject a claim account other than Asset. Restored funds permit deposit/cancel. |
| `both_venues_stopped_operator_emergency_cancel_or_claim_owner_restart` | Module disable blocks operator claim with GS104. Emergency cancels an unpriced request or claims a priced one. The safety module stays active. Owner restart permits a new request/cancel cycle. |
| `both_venues_merkle_proof_and_account_permission_are_independent` | A controlled nonzero two-leaf root rejects empty/wrong proofs. A valid proof still fails while the on-chain account permission is absent. Setting canDeposit permits the valid proof; cancellation returns funds. |
| `both_venues_vault_cap_exact_boundary_and_one_share_below_rolls_back` | The test independently converts aggregate pending assets into shares. A vault limit one share below the resulting balance fails with LimitExceeded and full rollback; the exact limit permits the request. |

Report, pause and flag calls impersonate holders that the deployed vault already lists. The tests check role membership before report submission. The proof/account and risk-cap cases need controlled fork preconditions: the existing default admin grants the required role to itself and changes only the test snapshot. These are not public grants, accepted production parameters or proof of the external report consensus/signature pipeline [s127].

The first run combined a wrong timing assumption with RPC storage connection resets. The oracle timeout is 72,000 seconds, longer than the deposit interval. The corrected early-report case creates its request near the next allowed report window, so the first valid report's cutoff precedes the request. No oracle parameter is shortened. All three failed storage slots returned values in separate pinned reads. A single-thread run then passed six cases; the final run passed eight cases after adding precise error-origin checks, proof/account separation and the cap boundary. Original failures and traces remain in the evidence [s127][s129].

MAIN-06 moves from deferred to partial. Remaining coverage includes further amount/fee boundaries, hook/liquidity failure variants, production account-specific roles and report consensus/valuation. Redemption batches and First-loss paths remain separate obligations. Evidence is in `cache/sepolia/mainnet-earn-2026-10-25/`, with captured interfaces, current role holders, pinned primary sources and runtime hashes. No public transaction or parameter change was sent [s127].

## Real Earn Asset redemption paths — MAIN-07 partial

Seven `test_MAIN07_*` cases in `test/MainnetEarnCoverage.t.sol` pass on the pinned mainnet fork. The complete Earn contract passes fifteen cases without failures or skips. The full fork run passes 106 cases, with no failures and sixteen separate Sepolia/migration skips. Each venue starts with a real deposit, report and deposit claim. Redemption then uses the deployed share manager, oracle, vault, hook and queue. No synthetic settlement or public transaction is used [s134].

| Test suffix | Verified behavior |
|---|---|
| `both_venues_both_roles_lock_report_batch_exact_claim_and_no_replay` | Operator and Emergency lock shares without ERC20 approval. Net queued shares include the deployed redemption fee. A report burns exactly the eligible locked shares and creates the independently calculated asset demand. Claim before handling pays zero. Handling funds the queue; claim pays Asset exactly once. |
| `both_venues_same_timestamp_merge_multiple_ids_empty_unknown_duplicate_and_partial_claim` | Requests at one timestamp merge. Another timestamp remains separate. Empty, unknown and duplicate timestamps do not double-pay. Claiming one request leaves the other claimable; the second claim completes it. |
| `both_venues_zero_excess_max_wrong_receiver_value_delegatecall_are_atomic` | Zero, balance plus one and maximum requests fail without state changes. Wrong receivers, nonzero ETH and delegatecall fail through both roles. A full-balance request succeeds. |
| `both_venues_queue_pause_existing_claim_and_resume_redeem` | A real queue pause blocks new requests from both roles. An existing funded claim remains payable. Restoring queue status permits a new request. |
| `both_venues_zero_batch_limit_controlled_cash_shortage_snapshot_restore_retry` | A zero batch limit changes no ledger. A controlled fork branch removes the redeem hook and leaves insufficient vault cash; handling does not fund the request and claim pays zero. Restoring the snapshot restores the actual hook, handling and payment. Repeated handling changes no ledger. |
| `both_venues_operator_stop_preserves_emergency_request_report_and_claim` | Disabling the operator module yields GS104 on a new operator request. Emergency requests redemption and completes report, handling and exact payment while its module remains enabled. |
| `both_venues_valid_early_report_keeps_request_unpriced_until_redeem_delay` | A valid report after the oracle timeout still has a cutoff before the new request. The request stays unpriced and claim changes no ledger. A later eligible report permits handling and payment. Oracle timing parameters are unchanged. |

Expected shares, fees, asset demand and per-request payouts use independent integer arithmetic before execution. Report checks compare pending shares, locked shares, total supply and demand. Handling checks queue funding, demand and the batch iterator. Claims check both Asset and queue token balances, remaining batch assets/shares and the deposit-budget tuple [s134][s135].

The first attempt failed compilation because a tuple mixed an existing variable with a new declaration. The next run passed four cases and exposed two test errors: a timestamp expression was re-evaluated after a fork time change, and `expectRevert` intercepted a queue registry read instead of the Roles call. Reading the stored request timestamp and resolving the queue before `expectRevert` corrected these errors. The following six-case run passed; adding delayed-report and exact supply assertions produced the final fifteen-case Earn run. Original logs and traces remain in `cache/sepolia/mainnet-earn-redeem-2026-10-25/` [s134].

MAIN-07 moves from deferred to partial. At this run, separate First-loss Safe redemption and claim-to-Agent had not been tested. The controlled probe below adds this coverage [s136]. Further boundaries include multiple report batches with bounded handling, nonzero fee settings, share burn/blacklist/lockup flags and an actual hook failure. The shortage case removes hooks only inside a local snapshot through a controlled admin grant; it does not prove a live venue liquidity outage. The legacy-key fixture and impersonated report holders do not prove production signing, external valuation or report consensus [s134].

Repository checks and Sepolia checks pass. The first repository check failed because the macOS sandbox denied Chromium a Mach port. The retry outside the sandbox passed all browser checks. Both logs are retained with the run evidence [s134].

The deposit queue interface now names its claim argument `account`: the call mints that account's own priced request. The redemption queue claim argument remains `receiver`, and its request identifiers are timestamps. These interface names do not change ABI selectors [s128][s135].

## Real First-loss redemption probe — MAIN-07 partial

Three `MainnetFirstLossCoverageTest` cases pass for both real EarnUSD and EarnETH at block 25946643. The fixture uses the deployed Safe and Roles singletons to create local proxies. The actual Aragon Agent is the First-loss Safe's sole owner. It transfers existing shares from the Growth Committee Safe and checks exact source and destination balances. It does not mint test shares or modify token storage [s136].

The fixture grants only the committee's redemption role on the two real queues. Its claim condition pins the receiver to Agent. These are handwritten local probe permissions. They are not the missing compiled mainnet First-loss policy. Setup impersonates the local Safe; operational calls impersonate the actual Committee Safe address. The test does not execute a DAO vote, Committee signatures or the Agent owner path [s3][s136].

| Test | Verified behavior |
|---|---|
| `test_MAIN07_first_loss_both_real_shares_report_claim_to_agent_and_no_double_payment` | Both real share tokens lock into their share manager without approval. An early claim changes no ledger. Actual oracle reports burn eligible shares and create batches with independently calculated asset demand. The real hook funds the queue. Claim pays Agent exactly, leaves First-loss asset balances unchanged and removes the request. Repeated claim changes no ledger. |
| `test_MAIN07_first_loss_claim_receiver_and_role_isolation_with_funded_request` | A funded request cannot pay First-loss, Committee or an unrelated address. An unrelated caller and Easy Track executor cannot use the redemption role. Committee cannot transfer, approve or burn shares through this role. Refusals preserve recorded queue, share and asset state. The valid Agent claim still succeeds. |
| `test_MAIN07_first_loss_owner_revocation_preserves_pending_claim_and_regrant_recovers` | Local owner configuration removes Committee membership after a request. Oracle processing still completes. Committee claim fails while membership is absent. Restoring membership permits the same request to pay Agent exactly. |

The first targeted run passes all three cases. Adding error-origin assertions exposed two wrong test expectations in the next full run: an unregistered caller returns NotAuthorized(address), while a previously registered Committee with removed role membership returns NoMembership(). Wrong receivers return ConditionViolation. The failed full run records 107 passed, two failed assertions and sixteen separate skips. The corrected tests use explicit expected selectors for each caller state. The final full run passes 109 tests across thirty suites, with no failures and sixteen separate Sepolia/migration skips. Evidence, source hashes and full-run output are retained in `cache/sepolia/mainnet-first-loss-2026-10-25/`. No public transaction or deployment was sent [s136].

MAIN-07 remains partial. Asset and separate First-loss claim paths now have real-venue evidence. Remaining work includes multiple report batches with bounded handling, nonzero fees, share restriction flags, actual hook failure and production account-specific policies/signing. MAIN-08 still requires its trusted burn factory and complete motion lifecycle; a direct role refusal does not cover that requirement [s3][s136].

## Earn redemption boundaries and injected hook faults — MAIN-07 partial

Five additional `test_MAIN07_*` cases pass for both EarnUSD and EarnETH in `MainnetEarnCoverageTest`. The tests use the actual deployed queues, share managers, fee managers, oracle and hook addresses. Restrictions and fee changes exist only in local fork snapshots [s137].

| Test suffix | Verified behavior |
|---|---|
| `both_venues_two_report_batches_bounded_fifo_and_reverse_claim_order` | Two requests enter separate oracle-report batches. Each handleBatches(1) advances one batch and funds its exact demand. The later request cannot claim before its batch is handled. After both are handled, later-first claim order pays both requests exactly and leaves neither pending. |
| `both_venues_burn_pause_blacklist_lockup_atomic_refusal_and_restore` | Burn pause, Safe blacklist and global lockup reject both operator and Emergency requests without ledger changes. Direct queue calls identify BurnPaused, Blacklisted and GlobalLockupNotExpired. Lockup still refuses one second before its timestamp and permits the exact timestamp. Restoring other restrictions permits a request. |
| `both_venues_pending_report_burn_pause_reverts_oracle_and_queue_then_retries` | Burn pause after a request rejects an eligible real oracle report. The oracle report record, queue, locked shares, supply and custody roll back. Restoring flags permits report, handling and exact Emergency claim. |
| `both_venues_nonzero_redemption_fee_exact_net_request_supply_conservation_and_no_locked_fee` | A controlled nonzero fee produces floor(gross × feeD6 / 1e6). Gross leaves Asset, fee goes to its recipient through burn/mint, net locks into the queue and supply stays unchanged at request. Report burns net eligible shares. No fee residue remains locked after handling and exact claim. Existing pending requests are included in the independent global locked-share reconciliation. |
| `both_venues_injected_hook_read_execution_faults_rollback_clear_and_retry` | Foundry injects distinct reverts at the actual hook's liquidity-read and delegatecall entry points. handleBatches propagates each exact error. Queue, vault custody, risk balance/limit, supply and request state roll back. Clearing the faults permits real handling and exact claim. |

The fee case exposed a source-version mismatch. The previously captured reference commit `735e085` omits the fee burn that appears in the pinned deployed execution trace. The trace shows lock(gross), burn(fee) from the share manager and mint(fee) to the fee recipient. The initial helper assumed gross stayed locked and supply increased; zero-fee cases could not distinguish these paths. The corrected helper instead checks net locked shares and unchanged total supply. The same correction applies to the First-loss request helper. The official `685be839` source includes this burn/mint path. No full source-to-bytecode reproduction is claimed; the deployed trace and balance/supply deltas are the execution evidence [s137][s138].

The first full run passed 111 tests and failed two test assertions. The lockup error uses `(uint256,uint32)`, and getter calls had consumed a one-shot owner prank before setFees. The second run passed 113 tests and failed the gross-versus-net fee assumption above. Original logs and traces remain in `cache/sepolia/mainnet-earn-boundaries-2026-10-25/`. Correcting the fee ledger produced a passing full run before the equivalent First-loss helper correction. The final run with both corrected helpers passes 114 tests across thirty suites, with no failures and sixteen separate Sepolia/migration skips [s137].

These cases narrow MAIN-07 without closing it. At this run, fee-recipient exemption and extreme fee/amount boundaries had not been tested. The following cases add this coverage [s139]. Hook faults are injected at real addresses; they do not prove an organically failing hook implementation or downstream dependency. Production account-specific policies/signatures and external oracle valuation/consensus remain open. No public transaction, parameter change or deployment was sent [s137].

## Earn fee exemption, rounding and maximum-fee cleanup — MAIN-07 partial

Three additional Asset cases and one First-loss case pass for both real Earn venues. The full fork run passes 118 tests across thirty suites, with no failures and sixteen separate Sepolia/migration skips. The Asset Earn contract now has twenty-three cases: eight deposits and fifteen redemptions. First-loss has four separate real-share probe cases. Logs and source hashes are in `cache/sepolia/mainnet-earn-fee-extremes-2026-10-25/` [s139].

| Test suffix | Verified behavior |
|---|---|
| `both_venues_fee_recipient_exemption_at_max_fee_both_roles` | A controlled local fee recipient is Asset. With the redemption fee at its maximum and other fees zero, both operator and Emergency request without a fee deduction. Gross locks, request shares equal gross and total supply is unchanged. Actual report/handling then pays Asset exactly. |
| `both_venues_minimum_share_fee_rounding_and_zero_asset_claim_removal` | The test uses one, three, four and 1,000,001 raw shares with a controlled D6 fee of 333,333. Independent floor arithmetic checks fee recipient shares and net requests. Report, handling and claim reconcile the independently calculated payout. A zero-asset claim still removes the request; replay pays nothing. All four USDC cases round to zero raw asset units. |
| `both_venues_max_fee_zero_net_request_report_reset_and_positive_request_cleanup` | A maximum redemption fee with other fees zero is accepted. Adding one fee unit above the total ceiling returns InvalidFees and preserves settings. Gross is entirely credited to the fee recipient, net pending shares are zero and request supply is conserved. An eligible report creates no new batch. Neither that report nor resetting fees clears the zero-net request. A later positive one-share request and eligible report permit both timestamps to be claimed and removed. |
| `first_loss_both_real_shares_nonzero_fee_and_recipient_exemption_pay_agent` | The separate First-loss Safe requests both real share tokens with a nonzero fee and, in a separate snapshot, with a maximum-fee recipient exemption. Exact net requests, fee-recipient shares and unchanged request supply reconcile. Actual reports and hooks process the requests. Agent receives the exact positive payout and First-loss receives no asset proceeds. |

Two boundary observations need to remain visible. First, a positive share request can have a zero underlying payout after integer rounding. The checked USDC requests complete and leave no request to reclaim later; the test does not interpret a successful claim as a positive payment. Second, the controlled maximum-fee profile accepts a zero-net request. That request remains listed after an eligible report and after the fee is reset, until a later positive request creates an eligible batch. Cleanup pays no assets for the zero-net timestamp and does not refund its fee. This is not the deployed default fee profile or a proposed production parameter [s139].

Both request helpers account for the fee-recipient exemption. The Asset exemption case executes the real branch through both roles. The dedicated First-loss case executes both fee and exemption branches from its separate Safe. Local fee and recipient changes use the actual fee manager owner only within snapshots. Production fee governance, all possible fee tuples, organic hook/dependency failure, production signing and external report valuation/consensus remain unverified [s139][s132][s138].

## USDC blacklist failure and retry — MAIN-07 partial

The full `just test-fork` run passes 125 tests across 30 suites, with 16 skips, at block 25946643. `test_MAIN07_usdc_queue_blacklist_reverts_hook_funding_atomically_then_retries` passes in this run. It uses the deployed EarnUSD queue, vault, BasicRedeemHook, subvaults and USDC. It blacklists the queue through USDC's blacklister inside a local fork snapshot [s140][s141][s142].

`handleBatches` runs the real hook. The hook pulls USDC from a subvault. USDC then rejects the transfer to the blacklisted queue with `Error(string)`. The transaction rolls back vault custody, risk accounting and queue batch state. After the test removes the blacklist entry, the same batch funds and pays the request. No public state changes [s142].

An earlier probe revoked every member of `PULL_LIQUIDITY_ROLE` and expected the hook pull to fail. It did not fail: the trace shows `hookPullAssets` and `handleBatches` completed. The probe used a role that does not block this executed path, so the test was removed. An exact revert-data hash assertion also caused a Yul compiler exception. The final test checks the `Error(string)` selector and passes. Both attempts and their outcomes are in the probe log [s142]. The USDC blacklist case tests a real downstream token refusal [s142].

The test covers the USDC blacklist path. It does not establish an organic hook implementation failure or a Mellow subvault pull failure. MAIN-07 remains partial for production permissions, signing, fee governance, and external report valuation/consensus [s1][s140][s142].

## Real First-loss burn motions — MAIN-08 partial

Six `test_MAIN08_*` cases pass for both real EarnUSD and EarnETH share tokens in the full 125-test fork run [s143]. The tests use the deployed Easy Track, executor, LDO token and share tokens. They deploy a local First-loss Safe and Roles modifier, then register `SepoliaFirstLossBurnFactory` with the deployed Easy Track by impersonating Voting. No public vote or registration occurs [s143].

Successful enactment burns the requested shares from First-loss. The test checks equal decreases in token supply and `totalShares`, unchanged `allocatedShares`, and unchanged Agent, queue and asset balances. It checks the exact three-day window and replay refusal. Other cases cover trusted creator and token/amount bounds, direct executor refusal, changed script data, creator and Voting cancellation, LDO snapshot objection, pause, removed factory, missing role, failure rollback/retry, excess-balance rollback/top-up and full-balance burn [s143].

MAIN-08 remains partial. The factory and First-loss policy are local test fixtures, not the production factory registration or signed governance path [s143].

## Real objection boundaries and snapshot transfers — ET-05

Two additional `MainnetFirstLossCoverageTest` cases pass at mainnet block `25946643`. They exercise deployed Easy Track and LDO for both real Earn share burn motions. The rejection boundary is calculated before execution as `ceil(snapshotTotalSupply * objectionsThreshold / 10000)`. Independent cross-products check that this is the first raw-unit weight that reaches the threshold [s163][s164].

| Test | Assertions |
|---|---|
| `test_MAIN08_both_real_shares_objection_threshold_minus_one_exact_and_plus_one` | For each share, weight one raw unit below the boundary leaves the motion pending with that exact accumulated weight. Weight at or one raw unit above the boundary rejects it. A repeated below-boundary objector receives `ALREADY_OBJECTED`. The objector flag, First-loss share balance and share supply match the expected state. |
| `test_MAIN08_both_real_shares_snapshot_transfers_no_weight_and_multiple_objectors` | Two holders own boundary-minus-one and one raw unit at the snapshot. Both transfer their full balances to a new recipient after the snapshot. The recipient now holds enough LDO to reach the threshold but receives `NOT_ENOUGH_BALANCE` because its snapshot weight is zero; the failed call leaves its objection flag false. The original holders retain their historical weights. Their two objections sum to the exact rejection boundary; a duplicate first objection fails. Both First-loss share balances and supplies remain unchanged. |

These eight scenario executions close ET-05's threshold, no-weight, repeated-objector, multiple-objector and historical-weight assertions against the owning protocol. The separate Sepolia mock continues to use current balances. The local factory registration and First-loss policy still limit MAIN-08; this result does not establish their production deployment or signing path [s143][s163].

The full `just test-fork` run passes 136 tests across 31 suites with zero failures and 16 separate Sepolia/migration skips. Both new tests pass on their first run. No public transaction was sent. Logs and source hashes are in `cache/sepolia/mainnet-objection-snapshots-2026-10-25/`. The verification record SHA-256 is `983640241e02602e77af5c129c78e54d1a32d23a299190ed62f0ee0469d6bf9b`; the test source SHA-256 is `01048ce2e8ffd2a96dbf8fc5af4d0c97f7f6b5977c363b679efb0ce2ae3df005`; the full log SHA-256 is `833385a37149046170bc71ff9d6c08729eecc3ce75b28546c3a5773a7313b0c1` [s163].

## Treasury registry and top-up rehearsal — MAIN-09 partial

The full fork run passes `test_02_enabling_vote_end_to_end`, `test_03_ramp_up` and `test_06_the_payment_rewrite_changes_only_usds`. These tests fork block 26249900 and use live Aragon Voting, ACL, Finance, Easy Track, registry factories and top-up factories [s142][s144].

The enabling vote registers stablecoin and stETH top-up factories and checks registry role assignments. The ramp-up test enacts USDC, stETH and USDS top-ups to the Asset Safe through Easy Track and Finance. The permission test checks 108 token/amount combinations before and after the vote. Only the USDS payment permissions change, with the 2,000,000-unit ceiling [s142][s144].

Six `test_MAIN09_*` cases pass against live Easy Track, Voting, Finance, the registered multi-token top-up factory and LDO, with a locally deployed registry and local test limits [s147]. They reject an untrusted creator and unlisted recipient, reject limit changes from non-Voting, permit the creator to cancel, and reject a motion after an LDO snapshot objection. The monthly-limit case creates concurrent motions, enacts 1.5 million USDC, rejects a competing 1 million USDC motion while 500,000 remains, then enacts exactly that remainder. It also verifies that a motion may be created near the calendar boundary for enactment in the next period; the first enactment resets the spent amount and records 1 million against the new period, leaving 1 million spendable [s146][s147].

The first targeted run reached the assertions but four tests assumed no unrelated motions were open at the pinned Easy Track block. The tests now compare against the pre-existing motion count. A later monthly-limit assertion expected an extra motion to fail after the cap was spent. The factory allowed it because its objection window crossed the period boundary; that follows the period-aware creation check. The corrected case asserts the boundary and enacts the motion in the new period. The final targeted run passes all six cases. The full `just test-fork` run passes 131 tests across 30 suites, with no failures and 16 skips [s147]. An earlier sandbox attempt failed before test setup because it could not resolve `lb.drpc.live`; the run completed after read-only network access was granted [s147].

The paused-USDC case pauses deployed USDC after a top-up motion passes. Enactment reverts at the token transfer. The motion remains open; Asset balance and registry spendable limit remain unchanged. After USDC is unpaused, the same motion enacts and transfers exactly 1 USDC [s145][s147]. Test source hashes are `6c61d6a10fcd79ae07684faa0cce379de015791e5b9770c7c523c11dc139cba5` for `test/EnablingVoteRehearsal.t.sol` and `f3a9c414f64d440de9fc56c76140a391cf0e039e18494b1c9590a7be992b1d13` for `test/rehearsal/RehearsalBase.sol`. The full-log hash is `23211730815438f2261e8e3cf22c1a6f70a3151673203c3dcda46cf8aab5a0a1`. Logs and JSON evidence are in `cache/sepolia/mainnet-main09-boundaries-2026-10-25/` [s147].

The first targeted run failed with `MOTION_NOT_PASSED` because the test attempted enactment before Easy Track's three-day window. The test now warps past `motionDuration()` before attempting enactment [s145].

The current working tree was rerun with `just test-fork`: all 30 suites completed with 131 passed, 0 failed and 16 skipped. The skip set is the separate Sepolia/migration coverage that requires its own runner. The result record includes SHA-256 hashes for all 25 Solidity test files in this working tree [s155]. The first sandboxed attempt failed before setup because DNS could not resolve `lb.drpc.live`; the read-only network-enabled rerun completed successfully [s155].

`just --justfile sepolia.just check` passed on the current working tree. Operational guards (3), protocol fees (6), CoW order conversion (3) and workflow recovery (35) Python tests passed; the Sepolia policy tests passed 132 cases across 10 files; TypeScript strict compile check passed. No public transaction was sent. Source hashes are recorded with the run [s156].

The registries and test limits are deployed inside the fork. These cases exercise monthly accounting and the production factory code path, but do not verify the production registry deployment, approved limit values or full production role graph. MAIN-09 remains partial [s74][s144][s145][s147].

## Governance templates and exit governance — MAIN-10 not testable yet

MAIN-10 has no implementation or executable integration test. The governance template factories, budget factory and exit-governance role remain unbuilt. Existing governance drills use a pass-through factory, so they do not validate template creation, execution, removal or emergency exits [s148][s149].

The required cases remain: validate each in-scope template at creation and enactment; pin targets, selectors and receivers; remove the full permission tree; recover from stale state; add emergency exits; and reject admin selectors and delegatecall. Add these tests when the factories and role exist. MAIN-10 remains open [s148].

## CoW launch-token settlement matrix — MAIN-11 partial

Three `MainnetCowCoverageTest` cases pass at mainnet block `25946643`. They exercise deployed GPv2 Settlement, Vault Relayer and stETH, wstETH, WETH, USDC, USDT and USDS. The public Sepolia stand continues to cover WETH/USDC [s2][s150][s161].

| Test | Assertions |
|---|---|
| `test_MAIN11_all_ordered_launch_token_pairs_settle_with_exact_deltas` | All 30 distinct directed token pairs settle to the local Asset Safe. Each UID fills for the signed sell amount. Non-rebasing token debits and receiver credits match exactly. stETH transfers reconcile internal shares. |
| `test_MAIN11_recovery_destinations_settle_launch_tokens_into_usdc_or_usdt` | All 10 distinct directions from the six-token list into USDC or USDT settle to the local Agent. The same fill, custody and allowance assertions apply. |
| `test_MAIN11_launch_token_decimals_match_the_order_unit_matrix` | The six tokens expose 18, 18, 18, 6, 6 and 18 decimals in the listed order. |

The test uses a local Orders Safe, owner-authorised approvals and direct owner presigning. An already authorised solver is impersonated inside the fork. Orders are full-fill SELL orders with zero signed legacy fee. Inputs use `10**sellDecimals + 1` and `2 * 10**buyDecimals + 1` raw units. Token funding and clearing prices are controlled within the fork. stETH funding calls real Lido `submit`; its expected transfer shares are calculated as `floor(amount * internalShares / internalEther)` from total and external ledgers, independently of the conversion getter [s115][s116][s161].

The initial matrix accepted either preservation of unlimited allowance or an exact sold-amount decrease. The later checks below pin that branch for each token. No Clutch Orders role policy or order signer is installed, so these results do not prove production pair allowlists, role restrictions or refusal of non-launch tokens. BUY, partial fills, fee variants, other rounding boundaries and token-specific failure/retry paths remain outside this matrix. MAIN-11 stays partial [s2][s161][s166].

Initial development attempts exposed a solver-address checksum error, `OWN: not owner` during Safe execution, failed `stdStorage` funding of rebasing stETH, an incorrect expectation that the presign marker equals one, and an incorrect expectation that every unlimited allowance stays unchanged. The corrected helper holds the Agent-principal context across the Safe execution, funds stETH through Lido and accepts the deployed nonzero marker and allowance modes. These earlier errors are recorded from the conversation outputs; their original logs are not included in this run record [s161].

That initial `just test-fork` run passes 134 tests across 31 suites with no failures and 16 separate Sepolia/migration skips. All three MAIN-11 cases pass on that recorded source. No public transaction was sent. Evidence is in `cache/sepolia/mainnet-main11-cow-2026-10-25/`. The verification record SHA-256 is `e7bebf6300b221b0dd18fcd8fb6327987b1dfca3f7f1db82cf5418631929b9e2`; the test source SHA-256 is `e48da2885144caa29bb7aab03dc66f14af748da35774cc517ba90c17a9a3ca15`; the full log SHA-256 is `2b3b8c6b226b0633b564dd25100f5f5e14a35ff2a911c2df9e72997b8135bad5` [s161].

## Token-specific allowances and full compilation before commit

All 40 MAIN-11 settlement paths now require the token's exact allowance behavior [s166]:

| Sell token | Expected relayer allowance after transfer |
|---|---|
| USDC | Decrease by the sold amount, including an initially unlimited approval [s167]. |
| wstETH | Decrease by the sold amount, including an initially unlimited approval; its release uses OpenZeppelin 3.4.0 [s119][s168][s170]. |
| stETH, WETH, USDT, USDS | Preserve the unlimited approval [s113][s116][s123][s169]. |

The USDT setup also checks runtime hash `0xb44fb4e949d0f78f87f79ee46428f23a2a5713ce6fc6e0beb3dda78c2ac1ea55` against the verified-source record and requires `deprecated() == false`. This pins the original transfer path. The initial Tether repository lookup returned 404 and the explorer source request returned 403; Sourcify supplied the verified source and runtime metadata [s166][s169].

A full recompile of 57 files exposed a Solc 0.8.24 Yul stack error before tests ran. The optimized IR localized it to the inlined Earn redemption payout model. The unchanged arithmetic now runs in an external pure test helper; production contracts and compiler settings are unchanged. The subsequent full compilation succeeds, and `just test-fork` passes 136 tests across 31 suites with zero failures and 16 separate Sepolia/migration skips. The strict CoW cases and all Earn deposit/redemption cases pass. The Sepolia local check also passes 47 Python tests, 132 policy tests and strict TypeScript compilation. No public transaction was sent [s166].

Evidence is in `cache/sepolia/precommit-2026-10-25/`, with primary source captures in `cache/sepolia/mainnet-cow-allowances-2026-10-25/`. The verification record SHA-256 is `8b9c370b4859f8db0d9362e3fb44d86d0f3fd9edc80fa718c1844f109d8d581e`. Test source hashes are `a12bce2a1adfc97233f1e8a79db79806cb2a83d9f1a3d3d093ba1eaa103b3d06` for the CoW matrix and `c84849a87b3ade728f7a5fb2208de1cd11e0670399d89d8b1c3db58ed403ea59` for Earn [s166].

## Pre-execution screening — MAIN-12 not testable with current harness

The repository's harness uses a plain operator address. It does not deploy the Committee Safe with the screening vendor's guard and explicitly has no guard test. Sepolia configuration checks confirm that the current stand has zero guard slots; those checks verify the reduced stand configuration only [s149][s151].

MAIN-12 requires the exact guard build and transaction-bound, one-use approval, including replay and bypass refusal, outage and removal behavior, and independent Emergency/Voting paths. ADR 010 also gates deployment on the vendor's written support and build requirements. No source, deployment or safe test fixture in the repository can establish those production behaviors. Keep MAIN-12 open until the vendor build and target Committee Safe are available; a mock guard would only test the mock [s151].

## Signing UI and screening — MAIN-13 not testable in this repository

The repository has no signing UI or vendor approval integration. Workflow tests cover local command guards and receipt recovery, but explicitly do not exercise wallet signing. The current operator is a plain address and has no screening guard, so UI request/state, approval latency, rejection, timeout, changed-payload and other Committee-duty paths have no executable target here [s149][s151]. MAIN-13 remains open pending the real signing and screening integration [s151].

## Production signers and ACL — MAIN-14 partial

The Sepolia harness verifies a reduced profile with one owner and threshold one. Mainnet protocol tests use legacy role keys, EOA holders and mocked Clutch governance. These tests do not establish production signer membership/thresholds, the production Voting/Dual Governance/Agent ACL graph, enabling-vote atomicity on production Safes or production alert delivery [s149][s154]. MAIN-14 remains open for those checks [s151][s154].

## Attested valuation and reporting — MAIN-15 not verified

The test README states that production budget figures come from an attested computation and are not in this repository; test budgets and fixed ceilings are stand-ins. ADR 009 also requires pinned-block valuation, two independent readings, cap/buffer reporting and monitoring. No attested computation run or report artifact is recorded in this test run, so the requested source block, prices, rule version, stale/missing data, cross-Safe totals, First-loss exclusion and actionable alert cases remain unverified [s149][s152][s154]. MAIN-15 remains open [s152].

## Lido Lend — MAIN-16 post-launch gate

The Lido Lend market target does not yet exist in the deployment evidence. ADR 011 says the Morpho-compatible template needs end-to-end fork tests against deployed Morpho Blue; the same ADR records that this test remains unbuilt. Therefore onboarding, market lifecycle and Emergency exit cannot yet be exercised against the actual target. Keep MAIN-16 as a post-launch gate [s153][s154].

## Current-stand fork rerun at block 11992758

The current-stand runner passed all 88 required tests across 15 suites at Sepolia block `11992758` (`0x91052aab93cd368262c53b99416e4093509226d340af59af309fe1e94e30dead`). It validated the manifest, payload, balance/timestamp readback and source hashes before Forge, and confirmed the fork block remained canonical after the run. No public transaction was sent [s158].

The first sandboxed attempt could not reach the configured RPC at `eth_chainId`; it stopped before running any tests. The read-only network-enabled retry completed. Forge reported a cold-cache warning for the pinned block after the passing suite summary. The result JSON records `passed: true`, all required test names and the verified payload/input hashes [s158]. The result JSON SHA-256 is `1007490484501a172186482c25d26543732c6872c96192d26d66cd1a2e898c93`; the drill log SHA-256 is `be3f72446404a94425f14f569842403871d9857ec4f9784fcbda7c74000a7ed4`; the payload validation log SHA-256 is `a1bf5b9c7580697631efce2ca49b49504ba4599be23bec58cb63d0f788cd4985` [s158].

The current-tree Sepolia local check also passed: 47 Python tests (3 operational guard, 6 protocol fee, 3 CoW order and 35 workflow), 132 policy tests across 10 files and strict TypeScript compilation. It sent no public transaction. Source hashes and counts are recorded in `cache/sepolia/sepolia-check-2026-10-25-1855/verification.json`, SHA-256 `27595dca5564b6ab90e5b61a673b29ea2e34a061a6ed89417091e6b13c692088` [s159].

The earlier current-stand run at block `11990591` remains recorded in [s157].

## Coverage review findings and dispositions

These findings concern test coverage. Each disposition applies only to its named assertions and deployment scope [s8][s158][s163].

| Review challenge | Disposition |
|---|---|
| Checking the first owner or module can miss extra entries | The exact-set configuration test and Safe configuration drift regressions cover CFG-03/04 [s7][s158]. |
| An exhausted budget can mask a wrong receiver | `test_FUND_receiver_checks_have_unspent_budget_and_exact_error` isolates balances and budget, then checks receiver condition status 7 [s7][s158]. |
| A green suite is treated as all variants of an integration | The checklist records assertions per row; broad integration families retain their remaining variants [s8]. |
| Disabling a role is treated as invalidating an existing signature | The settlement and emergency cases exercise the intermediate state and explicit order cancellation [s7][s158]. |
| Fixture settlement or impersonation is treated as full external integration | Public solver/API results and the production policy, signing and governance gaps retain separate evidence and limits [s106][s149][s150]. |
| Cancelling a burn is treated as clearing queued policy changes | GOV-10 still needs the missing governance factory and its motion lifecycle [s148]. |
| Mock token balances are treated as historical voting weights | The Sepolia mock uses current balances. ET-05 now has real Easy Track/LDO threshold, duplicate and post-snapshot-transfer evidence [s163][s164]. |
| Removing a factory is treated as cancelling its pending motions | The stand mock permits an existing motion after removal. The real MAIN-08 case instead checks `EVM_SCRIPT_FACTORY_NOT_FOUND`, unchanged motion state and retry after local re-registration [s7][s143]. |
| Proportional fees or expiry bounds are treated as field equality | The typed-order cases test the exact fee comparison and strict expiry boundaries [s7][s158]. |
| A budget rollback test fails on token balance instead of allowance | FUND-02/08 isolate the relevant prerequisites and check the error and rollback [s7][s158]. |
| Removed features expand positive test scope | The launch inventory lists excluded paths and keeps their refusal cases [s8][s153]. |
| A successful receipt or presign is treated as settlement | Seven public fills reconcile canonical Trade events, UIDs, receiver deltas and protocol-fee ledgers; unfilled orders remain separate [s106]. |

## Coverage limits

- Fork settlement uses an impersonated, already-authorized solver and synthetic prices and liquidity. It tests the deployed settlement, signature, transfer and receiver paths. It does not test orderbook admission, solver discovery, competition, market pricing or public settlement availability [s7][s8][s9][s10].
- Most role calls impersonate the Committee or Emergency Safe. The funding and burn-motion cases also execute through the Committee Safe. Browser-wallet signing, independent signers and the screening guard need separate coverage [s1][s6][s7].
- Public Sepolia First-loss cases use synthetic shares and queues with 1:1 settlement. The separate mainnet probe uses real Earn shares, oracle reports and hooks, with handwritten local permissions. The production First-loss policy and signatures remain unverified [s3][s6][s7][s136].
- The governance case enters the deployed test executor as Easy Track. It tests the executor-to-role path. It does not build a missing governance factory or prove its full motion lifecycle. The burn factory's motion lifecycle is tested separately [s4][s7].
- Mainnet staking, wrapper, converter, savings and Earn Asset deposit/redemption tests cover the committed legacy-key fixture. Production accounts/roles, Treasury/governance and remaining vault paths need additional mainnet-fork coverage. Stop-loss and the token template are outside the launch scope [s2][s4][s6][s112][s114][s118][s120][s125][s127].
