---
type: Research Note
title: Sepolia test results
description: Recorded runs, public transactions, findings and coverage limits for the Sepolia stand.
tags: [sepolia, testing, roles, cow, first-loss]
status: draft
valid_as_of: 2026-11-16
stale_after: 2026-12-16T00:00:00Z
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-16T17:53:48Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account isolation, emergency stop and DAO restart
  - id: s2
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — governance factory scope and implementation status
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — First-loss redemption, burn motions and objection
  - id: s4
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — attested budgets, valuation, reporting and monitoring
  - id: s5
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — screening guard behaviour, approval binding and deployment gate
  - id: s6
    resource: /adr/011-launch-scope.md
    title: ADR 011 — launch scope, Lido Lend onboarding and Morpho fork tests
  - id: s7
    resource: /specs/sepolia-stand.md
    title: Sepolia stand — accounts, roles, recipes and test cases
  - id: s8
    resource: /specs/sepolia-setup-checklist.md
    title: Sepolia setup coverage checklist — coverage IDs and states
  - id: s9
    resource: /registers/decision-log.md
    title: Decision log — the stand owner's choices of 2026-11-13 and 2026-11-16
  - id: s10
    resource: /test/README.md
    title: Fork harness — no screening guard, no wallet signing, test budgets
  - id: s11
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: test/SepoliaStand.t.sol, test/SepoliaCurrentStand.t.sol, test/SepoliaCoverage.t.sol, test/SepoliaMotionCoverage.t.sol and scripts/sepolia_test_current.py
  - id: s12
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2Settlement.sol
    title: CoW settlement — limit-price checks, filled amounts, clearing-price rounding
  - id: s13
    resource: urn:clutch:evidence:2026-10-20:sepolia-public-deployment
    title: Public deployment — 39 successful receipts, readback at block 11955151 and 12 exact Etherscan source matches
  - id: s14
    resource: urn:clutch:evidence:2026-10-20:sepolia-policy-interruption
    title: Interrupted policy run — DNS failure, 101 canonical receipts and recovery of the nonce-139 transaction
  - id: s15
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-snapshot
    title: 126 saved apply receipts and zero RPC policy differences at block 11956623
  - id: s16
    resource: urn:clutch:evidence:2026-10-22:sepolia-constellation-deployed
    title: Publication from dacf262, Nothing to deploy in Zodiac and zero RPC differences at block 11970750
  - id: s17
    resource: urn:clutch:evidence:2026-10-23:sepolia-role-key-migration
    title: Two canonical migration receipts; zero policy differences at block 11976825
  - id: s18
    resource: urn:clutch:evidence:2026-11-12:factory-migration
    title: Local factory-migration and rehearsal runs, logs in cache/sepolia/factory-migration/ and cache/sepolia/rehearsal/
  - id: s19
    resource: urn:clutch:evidence:2026-11-13:factory-migration-public
    title: Public run of 2026-11-13 — factory, policy, caps motion, burn-factory removal, executor module, comparison at block 12127573 and test-current at block 12127646
  - id: s20
    resource: urn:clutch:evidence:2026-11-16:factory-motions-public
    title: Public motions, the rename of the orders governance role and the publication of the 14 roles, 2026-11-16
  - id: s21
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-transfer
    title: First Committee transfer — payload, eth_call, fork tests and receipt at block 11985108
  - id: s22
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-orderbook-flow
    title: Quotes, presign receipts and CoW orderbook errors in cache/sepolia/cow-orderbook-flow-2026-10-24/
  - id: s23
    resource: urn:clutch:evidence:2026-10-24:sepolia-cow-unsign-1724014
    title: Corrected unsign payload with the literal role key, receipt and zero presign
  - id: s24
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-ordinary-sell
    title: Captured-quote regression, corrected Committee sell, settlement and direct-controller refusal
  - id: s25
    resource: urn:clutch:evidence:2026-10-25:sepolia-corrected-recovery
    title: Stop, recovery settlement to Agent, zero approvals, exact Voting restore and Committee smoke
  - id: s26
    resource: urn:clutch:evidence:2026-10-25:sepolia-reverse-and-final-inventory
    title: Reverse sell, final inventory, approval inventory and 101-receipt audit
  - id: s27
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-partial
    title: Half-fill, Trade and balance deltas, remainder cancellation and live settlement refusal
  - id: s28
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-buy
    title: Fixed-target BUY, exact spend and refund, replay refusal and fee computations
  - id: s29
    resource: urn:clutch:evidence:2026-10-25:sepolia-public-resting
    title: Funded out-of-market limit order, open observations, cancel and return
  - id: s30
    resource: urn:clutch:evidence:2026-10-24:sepolia-twap-public-settlement
    title: Both public TWAP parts settled with exact Asset balance deltas
  - id: s31
    resource: urn:clutch:evidence:2026-10-24:sepolia-twap-cancel-before-next-part
    title: Emergency removed a separate TWAP; its cached signature is unusable
  - id: s32
    resource: urn:clutch:evidence:2026-10-24:sepolia-first-loss-redemption
    title: USD and ETH redeem, settle and claim to Agent with exact share and asset deltas
  - id: s33
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-first-loss-burn
    title: Burn enactment, early refusal, objection, Voting cancellation and replay refusal
  - id: s34
    resource: urn:clutch:evidence:2026-10-24:sepolia-public-emergency
    title: Stop, cancellation, sweeps, zero approvals, Voting restore and canonical audit of 47 receipts
  - id: s35
    resource: urn:clutch:evidence:2026-10-25:sepolia-funding-resume
    title: Four FundSepolia transactions, interruption after the wrap, Foundry resume and duplicate-send refusal
  - id: s36
    resource: urn:clutch:evidence:2026-10-25:sepolia-nonce-faults
    title: Lost submission, HTTP timeout after mining and both fee-type replacements
  - id: s37
    resource: urn:clutch:evidence:2026-10-25:sepolia-lost-response
    title: One mined transaction with an injected failed response and duplicate-send refusal
  - id: s38
    resource: urn:clutch:evidence:2026-10-25:sepolia-teardown-inventory
    title: Order, TWAP, motion and First-loss inventory with the TWAP cleanup receipt
  - id: s39
    resource: urn:clutch:evidence:2026-10-25:sepolia-ui-funding-return
    title: Prepared funding/return envelope at Committee nonce 51; simulation and two fork tests
  - id: s40
    resource: urn:clutch:evidence:2026-10-25:sepolia-zodiac-ui
    title: Zodiac read-only screenshots, condition rendering and pinned allowance snapshot
  - id: s41
    resource: https://docs.cow.fi/cow-protocol/reference/sdks/cow-sdk#low-level-sdk-usage-example
    title: CoW SDK example — add the quote fee to the sell amount, then set feeAmount to zero
  - id: s42
    resource: https://github.com/cowprotocol/services/blob/v2.384.6/crates/orderbook/src/database/orders.rs#L556-L578
    title: CoW order status precedence — fulfilled, cancelled, expired, presignaturePending and open
  - id: s43
    resource: https://github.com/cowprotocol/services/blob/12324c1d95e5e4499c28fb2a841de6e77f5a1aaf/crates/model/src/order.rs
    title: CoW API serializes the legacy order class as limit
  - id: s44
    resource: https://github.com/circlefin/stablecoin-evm/blob/master/contracts/v1/FiatTokenV1.sol
    title: Circle transferFrom consumes allowance even at uint256 max
  - id: s45
    resource: urn:clutch:evidence:2026-10-25:sepolia-post-correction-fork
    title: 82 contract cases pass with independent USDC allowance history
  - id: s46
    resource: urn:clutch:evidence:2026-10-25:sepolia-governance-emergency-matrix
    title: Governance cross-products, delegatecall downgrade and allowance timestamp hazard; 79 tests
  - id: s47
    resource: urn:clutch:evidence:2026-10-25:sepolia-stale-owner-restore
    title: A stale owner grant re-arms a later revocation; selective restart preserves it
  - id: s48
    resource: urn:clutch:evidence:2026-10-25:sepolia-safe-config-drift
    title: Safe configuration drift reproduced, verifier corrected and 44 regression cases passed
  - id: s49
    resource: urn:clutch:evidence:2026-10-25:sepolia-stop-ordering
    title: Two stop-ordering cases and 84 named fork tests across 13 suites
  - id: s50
    resource: urn:clutch:evidence:2026-10-25:sepolia-protocol-fee-reconciliation
    title: Seven fills, fourteen protocol fee amounts and settlement buffer ledgers reconciled
  - id: s51
    resource: urn:clutch:evidence:2026-10-25:sepolia-runtime-provenance
    title: Twelve frozen-constructor runtime matches and two queue child-address checks at block 11992803
  - id: s52
    resource: urn:clutch:evidence:2026-10-25:sepolia-payload-binding
    title: Stale payload refused before Forge; 88 fork tests pass with bound input hashes
  - id: s53
    resource: urn:clutch:evidence:2026-10-25:sepolia-operational-guards
    title: Temporary-Git CLI refusals, blocked transport, recipe env guard and wrong-chain funding dry-run
  - id: s54
    resource: urn:clutch:evidence:2026-10-25:mainnet-objection-snapshots
    title: Two real Easy Track and LDO objection tests pass on the mainnet fork
  - id: s55
    resource: urn:clutch:evidence:2026-10-25:sepolia-current-stand-11992758
    title: Current-stand fork, 88 cases at block 11992758
---

# Sepolia test results

This page holds the stand's evidence: runs, public transactions and findings.
The [stand guide](../specs/sepolia-stand.md) has the flow and the test cases. The [checklist](../specs/sepolia-setup-checklist.md) owns the coverage IDs [s7][s8].

## Latest state

| Check | Result | Block |
|---|---|---|
| `test-current` | 16 suites, 101 of 101 tests | `12148541` [s20] |
| Comparison of the chain with the artifact | 0 differences | `12148541` [s20] |
| Hosted resolve and apply, commit `494ed57` | Both matched the payload, the policy and the chain. Apply returned HTTP 200, revision `33271ee8-e7d7-4f70-9dd0-c2ef909e2790`. Zodiac then showed `Nothing to deploy` | `12148661` [s20] |
| Stand runtimes | 12 runtimes match the frozen deployment artifacts | `11992803` [s51] |
| Public CoW fills | Seven fills reconcile their protocol fees and settlement buffers | — [s50] |

## Public steps

| Date | Step | Blocks | Result |
|---|---|---|---|
| 2026-10-20 | Deployment | `11955109–11955147` | 39 of 39 receipts succeeded. Etherscan shows 12 exact source matches [s13] |
| 2026-10-20 | Policy | — | An RPC DNS failure stopped the first run. Recovery restored the nonce-139 transaction. 126 receipts succeeded; 0 differences at `11956623` [s14][s15] |
| 2026-10-22 | Publication of the first seven roles | — | Zodiac showed `Nothing to deploy`; 0 differences at `11970750` [s16] |
| 2026-10-23 | Role-key migration | `11976805–11976806` | 0 differences at `11976825` [s17] |
| 2026-11-13 | Deposit queues and universal factory | `12126368–12126371` | 4 of 4 receipts succeeded [s19] |
| 2026-11-13 | Policy of commit `7169df4` | `12126388–12126591` | 204 of 204 receipts succeeded [s19] |
| 2026-11-13 | Caps motion 7 | `12126985–12127004` | Created and enacted [s19] |
| 2026-11-13 | Burn factory removed from Easy Track | `12127372` | Succeeded [s19] |
| 2026-11-13 | Executor module disabled, commit `d2517bb` | `12127565–12127568` | 4 of 4 receipts; 0 differences in 310 events at `12127573`; 101 of 101 tests at `12127646` [s19] |
| 2026-11-16 | Motions 8 to 15 and the emergency stop | `12147161–12147925` | The stop disabled the operator at `12147875`. Motion 15 enabled the operator again. 0 differences; 101 of 101 tests at `12147931` [s20] |
| 2026-11-16 | Rename of the orders governance role, commit `d4fa275` | `12148520–12148539` | 20 of 20 receipts; 0 differences and 101 of 101 tests at `12148541` [s20] |
| 2026-11-16 | Publication of the 14 roles, commit `494ed57` | `12148661` | See [Latest state](#latest-state) [s20] |

Before the rename, the hosted resolve returned HTTP 400 three times.
At commit `54e3c9a`, the API refused permissions with `Nor` on `exit-governance` and `insurance-governance`.
The payload now sends each role with `Nor` as targets.
At commits `8da746f` and `2fda8fa`, the operator and orders modifiers both had a `governance` role.
The first commit put the two roles under one label, and the second commit put them under two labels [s20].
The decision log records the rename and its reason [s9].

## Public transactions

Fork calls and read-only refusals have no public transaction.

| Case | Transaction sequence | Recorded transactions |
|---|---|---|
| WETH funding | Committee → Asset Roles → WETH.transfer(Orders, amount) | [transfer](https://sepolia.etherscan.io/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec) [s21] |
| UI funding/return batch | Committee → MultiSendCallOnly → asset-operator transfers one raw WETH unit to Orders → orders-operator returns it to Asset; review the UI envelope and then verify balances, budget, nonce and events | — [s39] |
| Presign/cancel | Committee → Orders Roles → delegatecall signer.signOrder / unsignOrder | [sign](https://sepolia.etherscan.io/tx/0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1) → [unsign](https://sepolia.etherscan.io/tx/0x84abc74edc3e375cc28e061da3668bf4e5a3c268db5e7ffa1d70d248e0fc8db2) [s22][s23] |
| Full SELL | Fund Orders → presign → public solver settles to Asset | [WETH→USDC fill](https://sepolia.etherscan.io/tx/0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9) → [USDC→WETH fill](https://sepolia.etherscan.io/tx/0x75df586f42d7a43dc91b9ef7452aa716a1b89bdd6d1a7d64b67447f60b9751c2) [s24][s26] |
| Partial SELL | USDC funding → presign → half-fill → unsign remainder | [fund](https://sepolia.etherscan.io/tx/0xa11a4c13fbb78cf5edb65d0264bd803ebd52e36c60c3f85b12bdbd5fc30a77bf) → [sign](https://sepolia.etherscan.io/tx/0x0aeab6092dda720a0d7c440fc58b71dfe0ce971324a69a0aed4ac2f4a8abb418) → [fill](https://sepolia.etherscan.io/tx/0x227e8c6fd9eda88f0dac28222d59cbf03ff20054d9b4e6ace9b7ff3ea4304753) → [unsign](https://sepolia.etherscan.io/tx/0xd83ede41504d1967fd43e3d4b650b84362b6e0c445f42da576d11a3570b6303d) [s27] |
| Fixed-target BUY | Fund maximum input → presign BUY → fill → return unused input | [fund](https://sepolia.etherscan.io/tx/0x19768633e82cee24133f4fe94e66230ded0db0cbb72c70694cd330f0c70e6e55) → [sign](https://sepolia.etherscan.io/tx/0xaed7d46caf6d2c96e1f72116edb2c3e0d16cb8dd9418e469feaeca5efc2d3c33) → [fill](https://sepolia.etherscan.io/tx/0x68865292541bb369ae0a1f0aef566f5fb5d3ed64e0ca3e1b84117ef82b2c0edc) → [return](https://sepolia.etherscan.io/tx/0xcd07f14b9619ebfda1e0a52550a3974773c9263b6f2b2af2efb34f4787e4b1ef) [s28] |
| Resting limit | Fund → presign unmarketable order → unsign → return input | [fund](https://sepolia.etherscan.io/tx/0xb50d5c705f739b3803c230c0cb0e2a857d9032f3a24db9cf1f490e24759a0962) → [sign](https://sepolia.etherscan.io/tx/0xcbac486b4a95e589bcd2446e50a6fae78b88b9bc4f245084401ab7e9e73800ee) → [unsign](https://sepolia.etherscan.io/tx/0x351c7473ec3d973e326b41675e820f36c4720d90e694bfaba2a17cdb2e90de85) → [return](https://sepolia.etherscan.io/tx/0x3ce5965fdfe145c4979c621538b28c836114cfe18be559902f3ed749a7c4e2a8) [s29] |
| TWAP | Create conditional order → generate each part → solver settles each part | [part 1 fill](https://sepolia.etherscan.io/tx/0xbb54da9c6ecb83deafbc3f829ca130f26defb0858c8571d308b8cfa1beb62788) → [part 2 fill](https://sepolia.etherscan.io/tx/0x58aa3328d61db7c0b28fb4754e518415e8891319a42686453dbc9a051b82e013) [s30] |
| TWAP cancellation | Create a separate conditional order → remove before execution → reject cached signature | [create](https://sepolia.etherscan.io/tx/0x344af8237e7f4c94934ddfba022d4c50bc4bdd473346aa8a0c2fbd3df24b1522) → [remove](https://sepolia.etherscan.io/tx/0x55f42b367c4ac31a726d0ed1e349f711c1a2d5f6f0fb9ed1210adfd9e465034c) [s31] |
| Stand First-loss USD | first-loss role: redeem → test queue settlement → claim(Agent) | [request](https://sepolia.etherscan.io/tx/0x5fdd027bf11b73c23e871ec740b1dd36d62e6928aabf95ea2cd2d3e7e3e1911b) → [settle](https://sepolia.etherscan.io/tx/0x5e01052b037a8a8562055dda98133d1055369bf119af1651b23ef68b1eacdcc2) → [claim](https://sepolia.etherscan.io/tx/0xf205056dab54fbbd21c4ee01834c0a460f8c0a2db1ebf6d01a195eae0652b46e) [s32] |
| Stand First-loss ETH | first-loss role: redeem → test queue settlement → claim(Agent) | [request](https://sepolia.etherscan.io/tx/0x3cc6cbcb01114626aa5c3099a76a84dcc5568057730b437b65b6c49393333573) → [settle](https://sepolia.etherscan.io/tx/0x9b64cec0c1a00b417294173436083acd186e46bbff43590f55ab5c472c09b5dc) → [claim](https://sepolia.etherscan.io/tx/0x6ea6e38d5eb1fb1d140e736dfacdcc1f1f5833b94481faa089b8113b04959c18) [s32] |
| Stand USD burn | createMotion → wait → enactMotion | [create](https://sepolia.etherscan.io/tx/0x53ffc68c9082a952cb86aa71003db34fd590bbe0a5a89b7ea29ebc07609c34cf) → [enact](https://sepolia.etherscan.io/tx/0x5e88f532647de580ce0e7dd4af0c1c73480de2ad3882e80aefbaf6d3f6a97e7e) [s33] |
| Stand USD burn objection | createMotion → objectToMotion | [create](https://sepolia.etherscan.io/tx/0xcdd88f444fd0bb26b0fdd8a4b637b2337543adc90aa01f80859f5cd717b4b166) → [object](https://sepolia.etherscan.io/tx/0x6517b4becbbeb1e75ef42e95386a1468bee2dfb1089bbc59e08e492404d7da9b) [s33] |
| Stand USD burn cancellation | createMotion → test Voting cancels motion | [create](https://sepolia.etherscan.io/tx/0x059759bc9abc43316d0c993f7236c1314fe09467999807b2cc7bbecf587499b5) → [cancel](https://sepolia.etherscan.io/tx/0x8a78d07bffc0844e2081c7334114275eee9bbe22d0ea170630fe8486e63f8176) [s33] |
| Stand ETH burn | createMotion → wait → enactMotion | [create](https://sepolia.etherscan.io/tx/0xbf595ac2631c9d256e1da1a43b2a8768c9b42fa9e703ab1da5841a4fa4448334) → [enact](https://sepolia.etherscan.io/tx/0x3de8da61bcdd1000e055e5d52038cb86562cd9cc55f5a3aeef73a510c27ca7c5) [s33] |
| Stand ETH burn objection | createMotion → objectToMotion | [create](https://sepolia.etherscan.io/tx/0xefd849d99b831651d3d2f304f07d91c5519419f1e12fa88cd8b31791cbcd5d49) → [object](https://sepolia.etherscan.io/tx/0xe2acf6b927496530298bf185beca84958814ba7e129adf1a9b507b53133990d2) [s33] |
| Stand ETH burn cancellation | createMotion → test Voting cancels motion | [create](https://sepolia.etherscan.io/tx/0x50c9fd72e0d23f6c5470fdc1e7f4e1b76edb4d5e3c43c0844fb24b9878c011d5) → [cancel](https://sepolia.etherscan.io/tx/0x2d2e072fda13dd558ae18aeb587ffe3e8bf5440359dad12d743b5c0e18e86a6e) [s33] |
| Asset stop | Emergency → safety modifier → Safe.disableModule(operator) | [disable](https://sepolia.etherscan.io/tx/0xb926d29b1ef443543491a2cf43c2abfb0d447d051252332e03890016a00ab4fb) [s34] |
| Orders stop | Emergency revokes the four operator targets | [revoke 1](https://sepolia.etherscan.io/tx/0x87987768fa9d2b825cbfaf34e8082a961eb3c503bcd7c92be2cf452e7a77e5de) → [revoke 2](https://sepolia.etherscan.io/tx/0x38774559212359c8674c7562dc89272e73ac0ecf7bf35b512fca3d91d17c5a06) → [revoke 3](https://sepolia.etherscan.io/tx/0x16cfec3d8c95101cd43a3ed9f57f2e773627b807e7c688d85df4cd2713ba0130) → [revoke 4](https://sepolia.etherscan.io/tx/0x990d9109ceff8d1cde0ddc723cbd9b131b6121d4e99132b1d5c2618b59858df0) [s34] |
| Recovery settlement | Fund → stop operator paths → recovery sign → solver pays Agent | [fund](https://sepolia.etherscan.io/tx/0xe3645922565ac1b644ef13933a405380ce6afab00f4ef2071fabc365c7e9e792) → [sign](https://sepolia.etherscan.io/tx/0x5c7df438849a8c3f2ab6a592b868305d4f1f3bc50fcd816e83143354166014f3) → [fill](https://sepolia.etherscan.io/tx/0x1fb3284c9e2a31a8620264a1e74684ae3fb46063da86b43f1c3c69f43bca548e) [s25] |
| Approval removal | Emergency zeros Orders relayer approvals | [WETH zero](https://sepolia.etherscan.io/tx/0x4299065d00a4667796780ca15a62b44fc0062794b8afe190d2e48c1482b631c7) → [USDC zero](https://sepolia.etherscan.io/tx/0x37d056b295c7566f5cccc2943beac347c2528a4e6cefef06f861305fa4c5f000) [s34] |
| Voting restart | Test Voting approves and executes the reviewed four-account restoration | [approve 1](https://sepolia.etherscan.io/tx/0xa789fe774cb7be7938086b6cd130a6c717c3b29bc3538b71c52b5aacc07b1367) → [restore 1](https://sepolia.etherscan.io/tx/0xb14421a250355c4d46cb71787e889a48f6a0f34f75c49c32553824e01f79aa7b) → [approve 2](https://sepolia.etherscan.io/tx/0x76a6fe0a6052372d974d4c31c9e7cb6218b857709302c5e325845fdd94b6da65) → [restore 2](https://sepolia.etherscan.io/tx/0x475ca91a79a5a941337f6c724e9c010e81e78e605e3125a9086257e3a214c665) → [approve 3](https://sepolia.etherscan.io/tx/0x46e57e5ba30a8faf9b8c89fd81814b036e121cab16da2a4655a99113f5d3da06) → [restore 3](https://sepolia.etherscan.io/tx/0xc26930957206cc42d27c790d6dbeac50bf31b73b1019bfafbcc5ec30472d6574) → [approve 4](https://sepolia.etherscan.io/tx/0x02a0eac5faef40fac871cc2c61f3d8181097bc28c05f2d9c96b0d213e11247bc) → [restore 4](https://sepolia.etherscan.io/tx/0xb7dafaec7d27260d57eb5d802d18ecc55efda7dc5dc724cfd3f314b549279db1) [s34] |
| Funding interruption/resume | Wrap → interruption → resume only missing WETH/share transfers | [wrap](https://sepolia.etherscan.io/tx/0xb4f47a30c5b6acbd4ad377a1aa14ba5fb51af5ea63a47d3ad842971ae7ca712e) → [Asset WETH](https://sepolia.etherscan.io/tx/0xe45e1d44e1275d33feb5423d7465899d5ddbb4ff32e3f080b1525606ba7926ea) → [First-loss USD](https://sepolia.etherscan.io/tx/0xf800d0a4d626098061c858437b2a271d4c4b4089b2117af9be08520459507992) → [First-loss ETH](https://sepolia.etherscan.io/tx/0x021e631171ed441266575f0ca6c1dd7850538fd5511887cc865485083f6eac06) [s35] |
| Submission failures | Lost submission → identical raw resume; mined response timeout; legacy/EIP-1559 pending replacement | [resume](https://sepolia.etherscan.io/tx/0x20752a5159e0f499c7864188c20e9f9682d5022552a16be7ec309b81e8f7b2e2) → [timeout](https://sepolia.etherscan.io/tx/0x1e621f229691b74d259d25f4f90e50974bb3ad2aadc7f30b1f774dfe6a4ac30d) → [legacy](https://sepolia.etherscan.io/tx/0x23a62e73fc112e4ab09253e4fe97169eeef85bd78e3ed7d4beca586ed860e2c7) → [EIP-1559](https://sepolia.etherscan.io/tx/0x05b08210d07de4459c29d586e8cdf9d6893b2747403efd06891d10776c92a5d7) [s36] |
| Factory insurance funding | Committee createMotion → wait → enactMotion: universal factory → operator `insurance-funding` → WETH.transfer(First-loss, 0.005) | [create](https://sepolia.etherscan.io/tx/0xfdfd6f98da4dde2c377ba412683c9e56b013be95b4a0879bbf9be2f1a53ec252) → [enact](https://sepolia.etherscan.io/tx/0xc2b5c914609f15c1bcd317a8fb32a7b390457391a69e0dbc9c8f602eb1a14a02) [s20] |
| Factory insurance | Committee createMotion → wait → enactMotion: universal factory → first-loss `insurance` → WETH.approve and ETH queue deposit(0.005) | [create](https://sepolia.etherscan.io/tx/0x5dd20a6d3b176539eb42f8a4ab77962c672240f8091b74de6bf57aa3e89a91b3) → [enact](https://sepolia.etherscan.io/tx/0x2cc9822f33577c242a1b35b26f0cb540366eb5bd6960f02b378984e889fd2faf) [s20] |
| Factory First-loss burn | Committee createMotion → wait → enactMotion: universal factory → first-loss `first-loss-burn` → USD share burn(1) | [create](https://sepolia.etherscan.io/tx/0xc8477d86b006f0a30d13e6e4d90f45793b608a99319763dec597bb401d86a1fe) → [enact](https://sepolia.etherscan.io/tx/0x54540c3d9c58caaee05907f2a45e1a08aa708dc2080b8c21ad12f3983ce0490e) [s20] |
| Factory approvals | Committee createMotion → wait → enactMotion: universal factory → orders `approvals` → WETH.approve(relayer, max) | [create](https://sepolia.etherscan.io/tx/0x1fdf430846762dab01471a9d13eafa509afd8585b34a9c649854ca4b7fe8bf49) → [enact](https://sepolia.etherscan.io/tx/0x37e765c8c5b4ec4735d05484feb8c45e6a925ddc91cd1280db147fdccd735004) [s20] |
| Factory orders governance | Committee createMotion → wait → enactMotion: universal factory → orders `governance` (before the rename) → scopeTarget(orders-operator, WETH) | [create](https://sepolia.etherscan.io/tx/0x7a19e7e731429b7f2cd6ee178ddc69783ac3b7cedc16d94e4b4457ec91c7e439) → [enact](https://sepolia.etherscan.io/tx/0x0e14b820f652dd824a436ba2b8ace3d603db268d73ad69cbc497cf0264ff7fc4) [s20] |
| Factory exit governance | Committee createMotion → wait → enactMotion: universal factory → safety `exit-governance` → scopeTarget(asset-emergency, WETH) | [create](https://sepolia.etherscan.io/tx/0x9608968dc18c6b2063a7edddc11ffc8c1aa28d69d1c32bdc8a4e6fe09b34679f) → [enact](https://sepolia.etherscan.io/tx/0xb15d8a9183b6b463868ffdd4d475221ab8413567a2436f7ead3d453306d079dd) [s20] |
| Factory insurance governance | Committee createMotion → wait → enactMotion: universal factory → first-loss `insurance-governance` → scopeTarget(insurance, WETH) | [create](https://sepolia.etherscan.io/tx/0x619f116c316901935d352ae8a3d2681d45722fd479036a50740606158e2eaea9) → [enact](https://sepolia.etherscan.io/tx/0xdb48056491938b3c3df57a3831f42548bc75dafed628ff34313ae49e47177136) [s20] |
| Factory restart | Emergency → safety modifier → Safe.disableModule(operator); then universal factory → safety `restart` → Safe.enableModule(operator) | [disable](https://sepolia.etherscan.io/tx/0xe911ffa38837c33f455a6f01183e394a84ab03fb0f1524c9bfd5e259264d3ba1) → [create](https://sepolia.etherscan.io/tx/0x60643701dd8f3863601262de6f47ed8cd2640daef0ecbb94e61488c77c0946f0) → [enact](https://sepolia.etherscan.io/tx/0x78481d1a0ff513967a7927bb70d1455deb7f35fe52b250daa5e7c8a040bd1b7f) [s20] |
| Factory caps | Committee createMotion → wait → enactMotion: universal factory → operator `governance` → setAllowance of both insurance-funding caps | [create](https://sepolia.etherscan.io/tx/0xe402d64a04342007b667261cf1169fd42715bb12d70c6f2be98b4328c999db49) → [enact](https://sepolia.etherscan.io/tx/0x61a10b1b301eec75df0ff56c8e95b2cde4d8a8fb205ae3bf37019bad775b6f50) [s19] |
| Burn factory removal | Controller → Easy Track removeEVMScriptFactory(burn factory) | [remove](https://sepolia.etherscan.io/tx/0x839e5e714f357a39a1142bf9ac5b79840d2390312b968ba4ef236d51b1d45bf5) [s19] |
| Lost response | Committee zero-USDC transfer; mined, then an injected failed response; resend refused | [transfer](https://sepolia.etherscan.io/tx/0x0075c5eabac1f7462ca75e4ef0c30c9be154a71bc451f614a9d5168537828e32) [s37] |
| TWAP cleanup | Committee removes a completed TWAP schedule | [remove](https://sepolia.etherscan.io/tx/0x32e2ee4b11a78cbac6cff295b7003466598a5fa005ec4deecd53fb58e92bf20c) [s38] |

## Fork runs

Each run checked the exact test names, the source and manifest hashes and the canonical block hash. No run had a failure or a skip [s11].

| Block | Tests | Suites | Note |
|---|---|---|---|
| `11987139` | 79 | 12 | Governance and emergency matrices [s46] |
| `11987444` | 82 | 12 | After the corrected public sells [s45] |
| `11987576` | 84 | 13 | Stop orderings and pending burns [s49] |
| `11988436` | 88 | 15 | Result bound to the saved declaration [s52] |
| `11992758` | 88 | 15 | Rerun [s55] |
| `12126341` | 101 | — | Fork of the stand on the factory deploy day [s18] |
| `12127646`, `12147931`, `12148541` | 101 | 16 | After each public step of the factory move [s19][s20] |

## Findings

- **Order fee.** An order submitted to the CoW API must set `feeAmount` to zero. Add the quote's fee to the sell amount first. The first saved payloads did not add the fee [s24][s41].
- **App data.** The Orders signer rule accepts only a zero `appDataHash`. The API takes the zero hash as the legacy string `appData` [s22].
- **Role key encoding.** A role key is the literal `bytes32` string, not its `keccak256`. The wrong encoding returns `NoMembership` inside `GS013` [s23].
- **Unsign status.** After unsign, CoW reports `presignaturePending`, or `expired` when the order has expired. `invalidated` comes from separate records [s23][s42].
- **Order class.** The API serializes every legacy order class as `limit`. A test must not expect `market` [s29][s43].
- **Revocation is not cancellation.** A revoked signer permission leaves an existing presign usable. Zero approval blocks settlement. Only unsign or expiry ends the order [s49].
- **Pending burns.** An uncancelled burn motion still enacts while the Asset operator is stopped. Cancel it through Voting before a restart [s49].
- **USDC allowance.** Circle USDC consumes even a maximum allowance. WETH does not. The runner rebuilds the USDC allowance from Approval and Trade events [s44][s45].
- **Allowance timestamp.** Roles accepts the maximum `uint64` timestamp. The next budgeted transfer then reverts with `Panic(0x11)`. Voting can correct the timestamp [s46].
- **Stale restore.** An old owner grant re-arms a permission that the owner revoked later. A selective restore preserves the revocation. No check finds an outdated payload before signature (GOV-09) [s47].
- **Configuration drift.** The comparison missed owner and guard changes. It now checks owners, thresholds and both guard slots of the five Safes [s48].
- **Factory removal.** On the mock Easy Track, an open motion still enacts after its factory is removed. The Emergency Safe stops it with the universal factory's `raiseCounter()` [s11][s19].
- **Module after role removal.** `assignRoles` enables its module, even when it removes a role. The executor stayed an enabled module until a separate step disabled it [s19].
- **Public balance.** The `insurance-funding` motion left 0.0073 WETH on the Asset Safe. No stand suite checks the public balance [s20].
- **Zodiac UI.** The UI shows `Nor` as `Unsupported Condition` and shows a budget's key without its remaining amount. Read budgets through RPC [s40].
- **Protocol fees.** CoW keeps fees and buffers apart from the signed fee. The seven fills reconcile. Zero improvement, cap equality and weekly payout stay open (SETTLE-04) [s50].
- **Submission faults.** A lost submission, an HTTP timeout after mining and both fee-type replacements each executed once. The completed-run guards refuse a resend [s36][s37].
- **Objection snapshots.** The mock reads current balances. Two tests against the real Easy Track and LDO on a mainnet fork pass. ET-05 stays partial [s54].
- **Guards.** Local drills refuse a wrong branch, local changes, an unpushed commit, CI, a missing opt-in and a wrong chain. They do not run a real hosted apply (OPS-10) [s53].
- **Runtimes.** All 12 stand runtimes match their frozen artifacts. Nobody approved the baselines (CFG-02) [s51].
- **UI envelope.** A prepared two-call funding and return envelope passes simulation and two fork tests at Committee nonce 51. No wallet signed it (OPS-01, OPS-03) [s39].

## Mainnet-only cases

- MAIN-12 and MAIN-13: the harness has no screening guard, no signing UI and no vendor build. A mock guard would test only the mock [s5][s10].
- MAIN-14: the stand has one owner and threshold one. It proves no production signer set or ACL [s1][s10].
- MAIN-15: no attested computation ran for the stand. Its budgets are test values [s4][s10].
- MAIN-16: the Lido Lend target does not exist yet. It stays a post-launch gate [s6].

## Coverage review findings and dispositions

| Review challenge | Disposition |
|---|---|
| Checking the first owner or module can miss extra entries | The exact-set configuration test and the drift regressions cover CFG-03 and CFG-04 [s11][s48] |
| An exhausted budget can mask a wrong receiver | `test_FUND_receiver_checks_have_unspent_budget_and_exact_error` isolates balances and budget [s11] |
| A green suite is treated as all variants of an integration | The checklist records assertions per row [s8] |
| Disabling a role is treated as invalidating an existing signature | Settlement and emergency cases exercise the intermediate state and explicit cancellation [s11][s49] |
| Fixture settlement or impersonation is treated as full external integration | Public fills and the production gaps keep separate evidence [s7][s50] |
| Cancelling a burn is treated as clearing queued policy changes | GOV-10 still needs a governance factory and its motion lifecycle [s2] |
| Mock token balances are treated as historical voting weights | ET-05 stays partial [s54] |
| Proportional fees or expiry bounds are treated as field equality | The typed-order cases test the exact fee comparison and strict expiry [s11] |
| A budget rollback test fails on token balance instead of allowance | FUND-02 and FUND-08 isolate the prerequisites and check the error [s11] |
| Removed features expand positive test scope | The checklist lists excluded paths and keeps their refusal cases [s6][s8] |
| A successful receipt or presign is treated as settlement | Seven public fills reconcile Trade events, UIDs and receiver deltas [s50] |

## Coverage limits

- Fork settlement uses an impersonated solver with synthetic prices and liquidity. It does not test orderbook admission, solver competition or market pricing [s11][s12].
- Most fork role calls run as an impersonated Committee or Emergency Safe. Wallet signing, independent signers and the screening guard need separate coverage [s1][s7].
- Public First-loss cases use synthetic shares and queues with 1:1 settlement [s3][s7].
- The governance cases enter the test executor directly. They do not prove a governance factory's full motion lifecycle [s2][s11].
