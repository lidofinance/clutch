---
type: Guide
title: Sepolia stand test plan
description: Test cases, execution commands and public transaction sequences for the stand and its protocol integrations.
tags: [sepolia, testing, roles, cow, first-loss]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-25T19:35:38Z
verified: []
sources:
  - id: s1
    resource: /specs/sepolia-setup-checklist.md
    title: Complete coverage obligations and their status
  - id: s2
    resource: /adr/013-tests-on-sepolia.md
    title: Sepolia account-specific roles and execution boundaries
  - id: s3
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: Current-stand runner and Sepolia stand, coverage and operational tests
  - id: s4
    resource: urn:clutch:source:mainnet-protocol-tests
    title: Mainnet protocol tests in test/Mainnet*Coverage.t.sol, test/EnablingVoteRehearsal.t.sol and test/Drills.t.sol
  - id: s5
    resource: /research/sepolia-test-results.md
    title: Recorded runs, transaction receipts, findings and limitations
  - id: s6
    resource: /specs/sepolia-stand-plan.md
    title: Stand addresses, funding and guarded public execution procedures
---

# Sepolia stand test plan

[Coverage and status](sepolia-setup-checklist.md) · [Results and findings](../research/sepolia-test-results.md) · [Stand and addresses](sepolia-stand-plan.md) [s1][s5][s6]

## Run

Use the existing Sepolia manifest and account-specific keys: asset-operator, orders-operator, asset-emergency and orders-emergency. Keep RPC settings in the ignored .env [s2][s3].

```sh
just --justfile sepolia.just constellation <workspace-uuid>
just --justfile sepolia.just test-current
just test-fork
just --justfile sepolia.just check
```

For a historical replay, use the recorded block with its matching manifest, declaration and source revision [s3]:

```sh
SEPOLIA_STAND_BLOCK=<recorded-block> just --justfile sepolia.just test-current
```

Check the expected error origin, rollback and nonce behavior. For public calls, check the receipt, Safe outcome and exact token/budget deltas. For settlement, reconcile the UID, Trade event and receiver balance. Record outcomes and limitations in the results file [s1][s3][s5].

## Sepolia cases

The test families below cover the current-stand suite. The [runner](../../scripts/sepolia_test_current.py) defines its exact required function set [s3].

| Case | What to test | Tests |
|---|---|---|
| Configuration | Exact owners, thresholds, modules, guards, handlers, runtime code and initial approvals; Safe nonce/hash/signature replay | [Stand](../../test/SepoliaStand.t.sol): `test_account_graph_and_domain_verifier`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_CFG_*` [s3] |
| Roles | Four account keys, holders and avatars; old/wrong-account keys, non-members and every actor/modifier combination | [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_role_keys_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_CFG_actor_matrix_*` [s3] |
| Funding | WETH/USDC Asset→Orders; zero/partial/exact/excess, decimals, recipient, refill boundaries, rollback and no refund after return | [Stand](../../test/SepoliaStand.t.sol): `test_funding_budget_*`; [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_usdc_budget_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_FUND_*` [s3] |
| Orders | Sign/unsign; both token directions, BUY/SELL and partial/full; EIP-712 fields, domain, UID, expiry, duration, fee and receiver bounds | [Stand](../../test/SepoliaStand.t.sol): `test_typed_order_*`; [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_order_boundaries_*`, `test_quote_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_ORD_*` [s3] |
| Settlement | Marketable and resting orders; exact deltas, indexed prices, rounding/fees, overfill, cancellation, partial remainder, missing funds/approval and retry | [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_market_and_limit_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_SETTLE_*` [s3] |
| TWAP | Two settled parts; daily/weekly schedules, interval edges, typed fields/proofs, replay, remove/recreate, cached signatures and forbidden handlers | [Stand](../../test/SepoliaStand.t.sol): `test_twap_two_parts_*`; [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_twap_settles_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_TWAP_*` [s3] |
| First-loss redemption | Both stand shares: request, synthetic settlement, claim to Agent, partial/multiple timestamps, duplicate/empty/double claim and forbidden routes | [Stand](../../test/SepoliaStand.t.sol): `test_first_loss_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_FL_*` [s3] |
| Burn motions | Trusted caller/factory, both stand shares, exact window, objection threshold, cancellation, removed factory, failed execution and supply accounting | [Stand](../../test/SepoliaStand.t.sol): `test_burn_motion_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_ET_*` [s3] |
| Governance | Target/function changes, key/target restrictions, CALL/delegatecall, allowance bounds/timestamps, atomic batches and stale owner restoration | [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_governance_executor_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_GOV_*` [s3] |
| Emergency | Asset switch; Orders revocations; cancel orders/TWAP; recovery to Agent; sweeps and zero approvals; repeated stops and Voting restart | [Stand](../../test/SepoliaStand.t.sol): `test_emergency_stops_*`; [CurrentStand](../../test/SepoliaCurrentStand.t.sol): `test_emergency_recovery_*`; [Coverage](../../test/SepoliaCoverage.t.sol): `test_EM_*` [s3] |
| Configuration drift | Owner/threshold/module/guard changes must produce a diff | [diff tests](../../policy/constellation/sepolia/diff.test.ts) [s3] |
| Submission/retry | Lost submission, mined response timeout, nonce replacement, funding interruption/resume and duplicate-send refusal | [workflow tests](../../scripts/test_sepolia_workflow.py) [s3] |
| Operational guards | Wrong chain, branch, dirty/unpushed state, missing opt-in/account, CI and forbidden credentials | [guard tests](../../scripts/test_sepolia_operational_guards.py) [s3] |
| Result integrity | Exact required cases, canonical block, source/payload hashes, current allowances and failed preparation clearing old success | [workflow tests](../../scripts/test_sepolia_workflow.py); [payload tests](../../policy/constellation/sepolia/verify-test-payload.test.ts) [s3] |
| CoW API/fees | Quote→zero-legacy-fee order conversion; actual fee policies, executed amounts and settlement-buffer ledgers | [order tests](../../scripts/test_sepolia_cow_order.py); [fee tests](../../scripts/test_sepolia_protocol_fees.py) [s3] |

## Mainnet integration cases

Run these against deployed protocol contracts on a pinned fork. A dash means the required case has no dedicated implementation in this table. Completion and remaining variants are recorded in the checklist and results [s1][s4][s5].

| ID | Required test | Test file |
|---|---|---|
| MAIN-01 | ETH↔WETH amounts, balances/events, failures, role differences and stop/restart | [MainnetWethCoverage](../../test/MainnetWethCoverage.t.sol): `test_MAIN01_*` [s4] |
| MAIN-02 | Lido submit, referral, exact shares, zero/missing ETH, pause/resume, stake limit and recovery | [MainnetLidoCoverage](../../test/MainnetLidoCoverage.t.sol): `test_MAIN02_*` [s4] |
| MAIN-03 | stETH↔wstETH rounding/dust, approvals/zeroing, custody, rollback and Emergency unwrap | [MainnetWstethCoverage](../../test/MainnetWstethCoverage.t.sol): `test_MAIN03_*` [s4] |
| MAIN-04 | DAI↔USDS both ways, zero/excess/max, exact supply/Vat, approvals, dependency failure and recovery | [MainnetConverterCoverage](../../test/MainnetConverterCoverage.t.sol): `test_MAIN04_*` [s4] |
| MAIN-05 | sUSDS deposit/redeem/withdraw, exact shares/yield, maxima, approval budget, rollback and Emergency exit | [MainnetSavingsCoverage](../../test/MainnetSavingsCoverage.t.sol): `test_MAIN05_*` [s4] |
| MAIN-06 | Earn deposits for each allowed asset, request/cancel, report/claim, proof/account gates, caps, pause and liquidity failures | [MainnetEarnCoverage](../../test/MainnetEarnCoverage.t.sol): `test_MAIN06_*` [s4] |
| MAIN-07 | Earn Asset and separate First-loss redemptions: report delay, batches, liquidity and token-transfer failure/retry, claim variants, fee/rounding boundaries and no double claim | Asset: [MainnetEarnCoverage](../../test/MainnetEarnCoverage.t.sol): `test_MAIN07_*`; First-loss: [MainnetFirstLossCoverage](../../test/MainnetFirstLossCoverage.t.sol): `test_MAIN07_first_loss_*` [s1][s4] |
| MAIN-08 | Real First-loss burn: trusted factory, full motion lifecycle, snapshot objections/threshold boundaries and exact shares/supply | [MainnetFirstLossCoverage](../../test/MainnetFirstLossCoverage.t.sol): `test_MAIN08_*` [s1][s4] |
| MAIN-09 | Treasury registries/funding: assets, recipient, permissions, creator, monthly limit, objection/cancel and paused-payment retry | [EnablingVoteRehearsal](../../test/EnablingVoteRehearsal.t.sol): `test_02_enabling_vote_end_to_end`, `test_03_ramp_up`, `test_06_the_payment_rewrite_changes_only_usds`, `test_MAIN09_*` [s1][s4] |
| MAIN-10 | Governance templates, creation/enactment, narrow permissions, complete removal, stale recovery and Emergency exit | — [s1] |
| MAIN-11 | Full launch swap/recovery token matrix, decimals, rounding, approvals/transfers and refusal of non-launch tokens | [MainnetCowCoverage](../../test/MainnetCowCoverage.t.sol): `test_MAIN11_*` for the Settlement/token matrix [s1][s4] |
| MAIN-12 | Committee guard: exact build, full transaction/nonce binding, replay/bypass, outage/removal and independent Emergency/Voting | — [s1] |
| MAIN-13 | Signing UI: approval state/latency, rejection, timeout, changed payload and other Committee duties | — [s1] |
| MAIN-14 | Production signers/thresholds, Voting/Dual Governance/Agent ACL, enabling-vote atomicity and configuration alerts | — [s1] |
| MAIN-15 | Attested valuation, caps/headroom/buffer, stale/missing data, Asset+Orders totals, First-loss exclusion and alerts | — [s1] |
| MAIN-16 | Lido Lend/Morpho onboarding, full lifecycle and Emergency exit after the target exists | — [s1] |

## Public Sepolia transaction sequences

Links identify recorded executions of each sequence. Fork calls and read-only refusals have no public transaction. Detailed receipts, UIDs, balances and findings are in the results file [s5].

| Case | Transaction sequence | Recorded transactions |
|---|---|---|
| WETH funding | Committee → Asset Roles → WETH.transfer(Orders, amount) | [transfer](https://sepolia.etherscan.io/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec) [s5] |
| UI funding/return batch | Committee → MultiSendCallOnly → asset-operator transfers one raw WETH unit to Orders → orders-operator returns it to Asset; review the UI envelope and then verify balances, budget, nonce and events | — [s5] |
| Presign/cancel | Committee → Orders Roles → delegatecall signer.signOrder / unsignOrder | [sign](https://sepolia.etherscan.io/tx/0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1) → [unsign](https://sepolia.etherscan.io/tx/0x84abc74edc3e375cc28e061da3668bf4e5a3c268db5e7ffa1d70d248e0fc8db2) [s5] |
| Full SELL | Fund Orders → presign → public solver settles to Asset | [WETH→USDC fill](https://sepolia.etherscan.io/tx/0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9) → [USDC→WETH fill](https://sepolia.etherscan.io/tx/0x75df586f42d7a43dc91b9ef7452aa716a1b89bdd6d1a7d64b67447f60b9751c2) [s5] |
| Partial SELL | USDC funding → presign → half-fill → unsign remainder | [fund](https://sepolia.etherscan.io/tx/0xa11a4c13fbb78cf5edb65d0264bd803ebd52e36c60c3f85b12bdbd5fc30a77bf) → [sign](https://sepolia.etherscan.io/tx/0x0aeab6092dda720a0d7c440fc58b71dfe0ce971324a69a0aed4ac2f4a8abb418) → [fill](https://sepolia.etherscan.io/tx/0x227e8c6fd9eda88f0dac28222d59cbf03ff20054d9b4e6ace9b7ff3ea4304753) → [unsign](https://sepolia.etherscan.io/tx/0xd83ede41504d1967fd43e3d4b650b84362b6e0c445f42da576d11a3570b6303d) [s5] |
| Fixed-target BUY | Fund maximum input → presign BUY → fill → return unused input | [fund](https://sepolia.etherscan.io/tx/0x19768633e82cee24133f4fe94e66230ded0db0cbb72c70694cd330f0c70e6e55) → [sign](https://sepolia.etherscan.io/tx/0xaed7d46caf6d2c96e1f72116edb2c3e0d16cb8dd9418e469feaeca5efc2d3c33) → [fill](https://sepolia.etherscan.io/tx/0x68865292541bb369ae0a1f0aef566f5fb5d3ed64e0ca3e1b84117ef82b2c0edc) → [return](https://sepolia.etherscan.io/tx/0xcd07f14b9619ebfda1e0a52550a3974773c9263b6f2b2af2efb34f4787e4b1ef) [s5] |
| Resting limit | Fund → presign unmarketable order → unsign → return input | [fund](https://sepolia.etherscan.io/tx/0xb50d5c705f739b3803c230c0cb0e2a857d9032f3a24db9cf1f490e24759a0962) → [sign](https://sepolia.etherscan.io/tx/0xcbac486b4a95e589bcd2446e50a6fae78b88b9bc4f245084401ab7e9e73800ee) → [unsign](https://sepolia.etherscan.io/tx/0x351c7473ec3d973e326b41675e820f36c4720d90e694bfaba2a17cdb2e90de85) → [return](https://sepolia.etherscan.io/tx/0x3ce5965fdfe145c4979c621538b28c836114cfe18be559902f3ed749a7c4e2a8) [s5] |
| TWAP | Create conditional order → generate each part → solver settles each part | [part 1 fill](https://sepolia.etherscan.io/tx/0xbb54da9c6ecb83deafbc3f829ca130f26defb0858c8571d308b8cfa1beb62788) → [part 2 fill](https://sepolia.etherscan.io/tx/0x58aa3328d61db7c0b28fb4754e518415e8891319a42686453dbc9a051b82e013) [s5] |
| TWAP cancellation | Create a separate conditional order → remove before execution → reject cached signature | [create](https://sepolia.etherscan.io/tx/0x344af8237e7f4c94934ddfba022d4c50bc4bdd473346aa8a0c2fbd3df24b1522) → [remove](https://sepolia.etherscan.io/tx/0x55f42b367c4ac31a726d0ed1e349f711c1a2d5f6f0fb9ed1210adfd9e465034c) [s5] |
| Stand First-loss USD | first-loss role: redeem → test queue settlement → claim(Agent) | [request](https://sepolia.etherscan.io/tx/0x5fdd027bf11b73c23e871ec740b1dd36d62e6928aabf95ea2cd2d3e7e3e1911b) → [settle](https://sepolia.etherscan.io/tx/0x5e01052b037a8a8562055dda98133d1055369bf119af1651b23ef68b1eacdcc2) → [claim](https://sepolia.etherscan.io/tx/0xf205056dab54fbbd21c4ee01834c0a460f8c0a2db1ebf6d01a195eae0652b46e) [s5] |
| Stand First-loss ETH | first-loss role: redeem → test queue settlement → claim(Agent) | [request](https://sepolia.etherscan.io/tx/0x3cc6cbcb01114626aa5c3099a76a84dcc5568057730b437b65b6c49393333573) → [settle](https://sepolia.etherscan.io/tx/0x9b64cec0c1a00b417294173436083acd186e46bbff43590f55ab5c472c09b5dc) → [claim](https://sepolia.etherscan.io/tx/0x6ea6e38d5eb1fb1d140e736dfacdcc1f1f5833b94481faa089b8113b04959c18) [s5] |
| Stand USD burn | createMotion → wait → enactMotion | [create](https://sepolia.etherscan.io/tx/0x53ffc68c9082a952cb86aa71003db34fd590bbe0a5a89b7ea29ebc07609c34cf) → [enact](https://sepolia.etherscan.io/tx/0x5e88f532647de580ce0e7dd4af0c1c73480de2ad3882e80aefbaf6d3f6a97e7e) [s5] |
| Stand USD burn objection | createMotion → objectToMotion | [create](https://sepolia.etherscan.io/tx/0xcdd88f444fd0bb26b0fdd8a4b637b2337543adc90aa01f80859f5cd717b4b166) → [object](https://sepolia.etherscan.io/tx/0x6517b4becbbeb1e75ef42e95386a1468bee2dfb1089bbc59e08e492404d7da9b) [s5] |
| Stand USD burn cancellation | createMotion → test Voting cancels motion | [create](https://sepolia.etherscan.io/tx/0x059759bc9abc43316d0c993f7236c1314fe09467999807b2cc7bbecf587499b5) → [cancel](https://sepolia.etherscan.io/tx/0x8a78d07bffc0844e2081c7334114275eee9bbe22d0ea170630fe8486e63f8176) [s5] |
| Stand ETH burn | createMotion → wait → enactMotion | [create](https://sepolia.etherscan.io/tx/0xbf595ac2631c9d256e1da1a43b2a8768c9b42fa9e703ab1da5841a4fa4448334) → [enact](https://sepolia.etherscan.io/tx/0x3de8da61bcdd1000e055e5d52038cb86562cd9cc55f5a3aeef73a510c27ca7c5) [s5] |
| Stand ETH burn objection | createMotion → objectToMotion | [create](https://sepolia.etherscan.io/tx/0xefd849d99b831651d3d2f304f07d91c5519419f1e12fa88cd8b31791cbcd5d49) → [object](https://sepolia.etherscan.io/tx/0xe2acf6b927496530298bf185beca84958814ba7e129adf1a9b507b53133990d2) [s5] |
| Stand ETH burn cancellation | createMotion → test Voting cancels motion | [create](https://sepolia.etherscan.io/tx/0x50c9fd72e0d23f6c5470fdc1e7f4e1b76edb4d5e3c43c0844fb24b9878c011d5) → [cancel](https://sepolia.etherscan.io/tx/0x2d2e072fda13dd558ae18aeb587ffe3e8bf5440359dad12d743b5c0e18e86a6e) [s5] |
| Asset stop | Emergency → safety modifier → Safe.disableModule(operator) | [disable](https://sepolia.etherscan.io/tx/0xb926d29b1ef443543491a2cf43c2abfb0d447d051252332e03890016a00ab4fb) [s5] |
| Orders stop | Emergency revokes the four operator targets | [revoke 1](https://sepolia.etherscan.io/tx/0x87987768fa9d2b825cbfaf34e8082a961eb3c503bcd7c92be2cf452e7a77e5de) → [revoke 2](https://sepolia.etherscan.io/tx/0x38774559212359c8674c7562dc89272e73ac0ecf7bf35b512fca3d91d17c5a06) → [revoke 3](https://sepolia.etherscan.io/tx/0x16cfec3d8c95101cd43a3ed9f57f2e773627b807e7c688d85df4cd2713ba0130) → [revoke 4](https://sepolia.etherscan.io/tx/0x990d9109ceff8d1cde0ddc723cbd9b131b6121d4e99132b1d5c2618b59858df0) [s5] |
| Recovery settlement | Fund → stop operator paths → recovery sign → solver pays Agent | [fund](https://sepolia.etherscan.io/tx/0xe3645922565ac1b644ef13933a405380ce6afab00f4ef2071fabc365c7e9e792) → [sign](https://sepolia.etherscan.io/tx/0x5c7df438849a8c3f2ab6a592b868305d4f1f3bc50fcd816e83143354166014f3) → [fill](https://sepolia.etherscan.io/tx/0x1fb3284c9e2a31a8620264a1e74684ae3fb46063da86b43f1c3c69f43bca548e) [s5] |
| Approval removal | Emergency zeros Orders relayer approvals | [WETH zero](https://sepolia.etherscan.io/tx/0x4299065d00a4667796780ca15a62b44fc0062794b8afe190d2e48c1482b631c7) → [USDC zero](https://sepolia.etherscan.io/tx/0x37d056b295c7566f5cccc2943beac347c2528a4e6cefef06f861305fa4c5f000) [s5] |
| Voting restart | Test Voting approves and executes the reviewed four-account restoration | [approve 1](https://sepolia.etherscan.io/tx/0xa789fe774cb7be7938086b6cd130a6c717c3b29bc3538b71c52b5aacc07b1367) → [restore 1](https://sepolia.etherscan.io/tx/0xb14421a250355c4d46cb71787e889a48f6a0f34f75c49c32553824e01f79aa7b) → [approve 2](https://sepolia.etherscan.io/tx/0x76a6fe0a6052372d974d4c31c9e7cb6218b857709302c5e325845fdd94b6da65) → [restore 2](https://sepolia.etherscan.io/tx/0x475ca91a79a5a941337f6c724e9c010e81e78e605e3125a9086257e3a214c665) → [approve 3](https://sepolia.etherscan.io/tx/0x46e57e5ba30a8faf9b8c89fd81814b036e121cab16da2a4655a99113f5d3da06) → [restore 3](https://sepolia.etherscan.io/tx/0xc26930957206cc42d27c790d6dbeac50bf31b73b1019bfafbcc5ec30472d6574) → [approve 4](https://sepolia.etherscan.io/tx/0x02a0eac5faef40fac871cc2c61f3d8181097bc28c05f2d9c96b0d213e11247bc) → [restore 4](https://sepolia.etherscan.io/tx/0xb7dafaec7d27260d57eb5d802d18ecc55efda7dc5dc724cfd3f314b549279db1) [s5] |
| Funding interruption/resume | Wrap → interruption → resume only missing WETH/share transfers | [wrap](https://sepolia.etherscan.io/tx/0xb4f47a30c5b6acbd4ad377a1aa14ba5fb51af5ea63a47d3ad842971ae7ca712e) → [Asset WETH](https://sepolia.etherscan.io/tx/0xe45e1d44e1275d33feb5423d7465899d5ddbb4ff32e3f080b1525606ba7926ea) → [First-loss USD](https://sepolia.etherscan.io/tx/0xf800d0a4d626098061c858437b2a271d4c4b4089b2117af9be08520459507992) → [First-loss ETH](https://sepolia.etherscan.io/tx/0x021e631171ed441266575f0ca6c1dd7850538fd5511887cc865485083f6eac06) [s5] |
| Submission failures | Lost submission → identical raw resume; mined response timeout; legacy/EIP-1559 pending replacement | [resume](https://sepolia.etherscan.io/tx/0x20752a5159e0f499c7864188c20e9f9682d5022552a16be7ec309b81e8f7b2e2) → [timeout](https://sepolia.etherscan.io/tx/0x1e621f229691b74d259d25f4f90e50974bb3ad2aadc7f30b1f774dfe6a4ac30d) → [legacy](https://sepolia.etherscan.io/tx/0x23a62e73fc112e4ab09253e4fe97169eeef85bd78e3ed7d4beca586ed860e2c7) → [EIP-1559](https://sepolia.etherscan.io/tx/0x05b08210d07de4459c29d586e8cdf9d6893b2747403efd06891d10776c92a5d7) [s5] |
