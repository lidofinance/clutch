---
type: Research Note
title: Sepolia stand coverage review, 2026-11-10
description: Independent rerun of the Sepolia stand fork tests, a check of the public transactions, the open gaps and the cases that can be tested now.
tags: [sepolia, testing, coverage, review, evidence]
status: draft
review_status: slop
valid_as_of: 2026-11-10
stale_after: 2026-11-19T14:38:00Z
generated:
  by: claude-code/fable-5.2
  at: 2026-11-10T12:52:04Z
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
    title: Stand accounts, owners and fixture values
  - id: s5
    resource: https://github.com/lidofinance/clutch/tree/24f7a52f50b7041c9bcfe2252932542a11b7f22b
    title: Repository at the reviewed commit - Sepolia tests, mocks, fork runner, Justfile and workflows
  - id: s6
    resource: urn:clutch:evidence:2026-11-10:sepolia-review-reruns
    title: Local checks and two fork runs of the current-stand suite, at blocks 11992758 and 12104452
  - id: s7
    resource: urn:clutch:evidence:2026-11-10:sepolia-review-chain-reads
    title: Receipts of 239 transactions, an event scan of two block ranges, state reads at block 12104452 and Safe signature decoding
---

# Sepolia stand coverage review

An independent review of the Sepolia stand tests on branch `testnet/sepolia`, commit `24f7a52`.
Identifiers such as `FUND-01` come from the [coverage checklist](../specs/sepolia-setup-checklist.md) [s1].

## Answer

- **Fork tests.** 88 of 88 pass at the recorded block `11992758` and at block `12104452` of 2026-11-10 [s6].
- **Real transactions.** All 65 transactions that the [test plan](../specs/sepolia-test-plan.md) cites, and the 171 setup transactions, are on Sepolia with status `1`. Their senders, targets and events agree with the plan [s2][s7].
- **Gaps.** The stand has no coverage of UI signing, independent signers, the governance motion path, the screening guard and monitoring [s1][s7].
- **CI.** No Sepolia check runs in CI, and the evidence is in the git-ignored `cache/` directory [s5].
- **Next.** Nine cases can be tested on the current stand without a change [s7].

## Context

The stand is a reduced copy of the Clutch account graph on Sepolia.
The Safe, Roles and CoW contracts are the real deployed contracts.
Voting, Agent, Easy Track, the share tokens and the redeem queues are test contracts [s4][s5].

| Account | Owner | Function |
|---|---|---|
| Committee Safe | Controller, 1 of 1 | The operator: transfers, orders, First-loss redemptions, burn motions |
| Emergency Safe | Controller, 1 of 1 | The stop authority. It cannot grant a permission or restart |
| Asset Safe | Test Voting | Holds the treasury tokens |
| Orders Safe | Test Voting | Holds the tokens for sale and signs CoW orders |
| First-loss Safe | Test Voting | Holds the two test share tokens |
| Test Voting, Agent, Easy Track | Controller | Voting restores permissions after a stop. The Agent receives recovered tokens |

The controller is one externally owned account [s4][s7].

## 1. Fork tests

A fork test runs on a local copy of the Sepolia state at one block.
It uses the deployed contracts and sends nothing to the network.
It impersonates the Safe owners and the solver, and it can add token balances [s5].
Thus a fork test proves the policy and the contract behaviour, not a real signature or a real solver.

### 1.1. Runs

| Run | Result [s6] |
|---|---|
| `SEPOLIA_STAND_BLOCK=11992758 just --justfile sepolia.just test-current` | 88 of 88 tests in 15 suites, 0 skipped. The recorded result of 2026-10-25 is reproducible |
| `just --justfile sepolia.just test-current`, block `12104452` | 88 of 88 tests in 15 suites, 0 skipped. The stand state is still correct |
| `just --justfile sepolia.just check` | 47 Python tests, 132 policy tests and the type check pass. These local tests cover the script guards, the resume logic, the configuration diff and the CoW quote conversion |

The runner requires the exact set of 88 test names. It fails if a test is absent or skipped [s5].

### 1.2. Coverage by area

| Area | Tests | Allowed paths | Limits and refusals |
|---|---|---|---|
| Configuration and roles, `CFG` | 9 | Exact owners, thresholds, modules, guards and runtime hashes. The four account-specific role keys execute | Old keys and the keys of the other account fail. Each caller with each key on each modifier. Safe replay, the wrong Safe and the wrong chain fail |
| Funding, `FUND` | 11 | WETH and USDC transfers to Orders. Partial transfers. Return to Asset | One unit above the budget fails. Refill at the period boundary. The wrong receiver, token or operation fails. A failed call consumes no budget |
| Orders, `ORD` | 10 | Sign and cancel in both directions, sell and buy, full and partial | A change of each of the 12 typed fields gives a different order. An order life above 90 days and a fee above 100 basis points fail. Signing from Asset fails |
| Settlement, `SETTLE` | 7 | Market and limit fills with exact token changes. Rounding with remainders | Overfill, missing funds, missing approval and an unknown solver fail. Only the Emergency Safe can set the relayer approval to zero |
| TWAP | 14 | Two parts settle. All 104 parts of the minimum, daily and weekly schedules have the expected fields | Schedules above the limit, changed proofs, other entry points and stop-loss payloads fail. A removed TWAP cannot settle |
| First-loss, `FL` | 7 | Redeem and claim to the Agent for both shares | Zero and excess requests fail. A repeated claim pays nothing. Transfer, approve and burn are denied |
| Burn motions, `ET` | 7 | Enactment after the window, objection and Voting cancellation for both shares | The wrong creator or share fails. Enactment one second early fails. A substituted script fails |
| Governance, `GOV` | 11 | The executor changes the operator permissions and budgets. Voting restores after a stop | 545 forbidden administration calls fail. The executor cannot get owner authority. A disabled module blocks governance |
| Emergency, `EM` | 12 | Stop, revoke, sweep, zero approvals, recovery order, restart. Two stop and restart cycles | The Emergency Safe cannot grant, enable a module or raise an approval. 76 forbidden receivers fail. A filled order cannot settle again |

The tests are in `test/SepoliaStand.t.sol`, `test/SepoliaCurrentStand.t.sol` and `test/SepoliaCoverage.t.sol` [s5].

## 2. Real transactions on Sepolia

The stand owner sent these transactions from 2026-10-20 to 2026-10-25, in blocks `11955109` to `11988081`.
The controller sent each of them, except seven solver settlements [s7].
Refusals have no public transaction. The recorded procedure tests them on a fork [s3].

### 2.1. Checks

| Check | Result [s7] |
|---|---|
| Receipts of the 65 cited transactions and of 3 more | All have status `1` and are in canonical blocks |
| Receipts of the setup: deployment 39, policy 126, funding 4, role migration 2 | All have status `1`. No Safe execution failed |
| Event scan of the two emergency drills | 64 transactions. The test plan does not cite 45 of them |
| Safe signatures of 115 decoded executions | Each is a pre-validated owner signature. None is an ECDSA signature |
| State at block `12104452` | The Committee nonce and both budgets have the recorded values. The stand did not change after 2026-10-25 |

### 2.2. Transactions by flow

A star (\*) marks a transaction that the test plan does not cite [s2][s7].

**Setup**

| Flow and result | ID | Transactions |
|---|---|---|
| Deployment, policy and initial funding. 169 transactions with status `1` | `CFG-01` to `CFG-06` | Blocks `11955109–11977292`\*. The hashes are in the local `broadcast/` records |
| Role migration to the four account-specific keys | `CFG-07` | [Asset](https://sepolia.etherscan.io/tx/0x9c3ce9a4ce85c36afe5bffbee8338f560d7d25c548c0560de941db606ef276a5)\* · [Orders](https://sepolia.etherscan.io/tx/0x86d6286fb911dcac17a20d059e9549b63d9298554d9fe007c98b858c6caa2fc5)\* |
| 0.01 WETH from Asset to Orders. The budget has 0.99 WETH left | `FUND-01` | [transfer](https://sepolia.etherscan.io/tx/0x30868fa4e30e9cc57b6fc49b1e4f8c43b97b209f0d677984bc4474c338a200ec) |

**CoW orders and TWAP**

| Flow and result | ID | Transactions |
|---|---|---|
| Sign and cancel an order | `ORD-03`, `ORD-08` | [sign](https://sepolia.etherscan.io/tx/0xf9d1a107930865237839da6809e49ee6d91d8af0550497939543de9b6095a8d1) · [cancel](https://sepolia.etherscan.io/tx/0x84abc74edc3e375cc28e061da3668bf4e5a3c268db5e7ffa1d70d248e0fc8db2) |
| Full sell in both directions. 0.005 WETH gives 193.554742 USDC. 399.335355 USDC gives 0.010075739790126343 WETH | `SETTLE-01`, `SETTLE-08` | [WETH to USDC](https://sepolia.etherscan.io/tx/0xf980f0f35a1b1a0198d6f1cc2514048ce92f220a37c400526e943d99dca045b9) · [USDC to WETH](https://sepolia.etherscan.io/tx/0x75df586f42d7a43dc91b9ef7452aa716a1b89bdd6d1a7d64b67447f60b9751c2) |
| Partial sell. One fill of 50 USDC, then a cancellation of the remainder | `ORD-09` | [fund](https://sepolia.etherscan.io/tx/0xa11a4c13fbb78cf5edb65d0264bd803ebd52e36c60c3f85b12bdbd5fc30a77bf) · [sign](https://sepolia.etherscan.io/tx/0x0aeab6092dda720a0d7c440fc58b71dfe0ce971324a69a0aed4ac2f4a8abb418) · [fill](https://sepolia.etherscan.io/tx/0x227e8c6fd9eda88f0dac28222d59cbf03ff20054d9b4e6ace9b7ff3ea4304753) · [cancel](https://sepolia.etherscan.io/tx/0xd83ede41504d1967fd43e3d4b650b84362b6e0c445f42da576d11a3570b6303d) |
| Buy order. Asset receives exactly 0.001 WETH. Orders returns the unused 3.034684 USDC | `SETTLE-04`, `FUND-11` | [fund](https://sepolia.etherscan.io/tx/0x19768633e82cee24133f4fe94e66230ded0db0cbb72c70694cd330f0c70e6e55) · [sign](https://sepolia.etherscan.io/tx/0xaed7d46caf6d2c96e1f72116edb2c3e0d16cb8dd9418e469feaeca5efc2d3c33) · [fill](https://sepolia.etherscan.io/tx/0x68865292541bb369ae0a1f0aef566f5fb5d3ed64e0ca3e1b84117ef82b2c0edc) · [return](https://sepolia.etherscan.io/tx/0xcd07f14b9619ebfda1e0a52550a3974773c9263b6f2b2af2efb34f4787e4b1ef) |
| Resting limit order. It stays open, then the operator cancels it and returns 10 USDC | `ORD-11` | [fund](https://sepolia.etherscan.io/tx/0xb50d5c705f739b3803c230c0cb0e2a857d9032f3a24db9cf1f490e24759a0962) · [sign](https://sepolia.etherscan.io/tx/0xcbac486b4a95e589bcd2446e50a6fae78b88b9bc4f245084401ab7e9e73800ee) · [cancel](https://sepolia.etherscan.io/tx/0x351c7473ec3d973e326b41675e820f36c4720d90e694bfaba2a17cdb2e90de85) · [return](https://sepolia.etherscan.io/tx/0x3ce5965fdfe145c4979c621538b28c836114cfe18be559902f3ed749a7c4e2a8) |
| TWAP of two parts. Asset receives 192.611792 and 193.294323 USDC | `TWAP-06`, `TWAP-11` | [part 1](https://sepolia.etherscan.io/tx/0xbb54da9c6ecb83deafbc3f829ca130f26defb0858c8571d308b8cfa1beb62788) · [part 2](https://sepolia.etherscan.io/tx/0x58aa3328d61db7c0b28fb4754e518415e8891319a42686453dbc9a051b82e013) |
| TWAP removal. The Emergency Safe removes an active TWAP. The Committee Safe removes a completed one | `TWAP-08` | [create](https://sepolia.etherscan.io/tx/0x344af8237e7f4c94934ddfba022d4c50bc4bdd473346aa8a0c2fbd3df24b1522) · [Emergency](https://sepolia.etherscan.io/tx/0x55f42b367c4ac31a726d0ed1e349f711c1a2d5f6f0fb9ed1210adfd9e465034c) · [Committee](https://sepolia.etherscan.io/tx/0x32e2ee4b11a78cbac6cff295b7003466598a5fa005ec4deecd53fb58e92bf20c)\* |

**First-loss and burn motions**

The test tokens emit no events. The review read the balances and the supply at the blocks before and after [s7].

| Flow and result | ID | Transactions |
|---|---|---|
| Redeem, settle and claim for both shares. Each time, the Agent receives 3 claim units | `FL-02` | USD: [redeem](https://sepolia.etherscan.io/tx/0x5fdd027bf11b73c23e871ec740b1dd36d62e6928aabf95ea2cd2d3e7e3e1911b) · [settle](https://sepolia.etherscan.io/tx/0x5e01052b037a8a8562055dda98133d1055369bf119af1651b23ef68b1eacdcc2) · [claim](https://sepolia.etherscan.io/tx/0xf205056dab54fbbd21c4ee01834c0a460f8c0a2db1ebf6d01a195eae0652b46e). ETH: [redeem](https://sepolia.etherscan.io/tx/0x3cc6cbcb01114626aa5c3099a76a84dcc5568057730b437b65b6c49393333573) · [settle](https://sepolia.etherscan.io/tx/0x9b64cec0c1a00b417294173436083acd186e46bbff43590f55ab5c472c09b5dc) · [claim](https://sepolia.etherscan.io/tx/0x6ea6e38d5eb1fb1d140e736dfacdcc1f1f5833b94481faa089b8113b04959c18) |
| Burn after the window. For each share, the supply changes from 97 to 95 | `ET-03` | USD: [create](https://sepolia.etherscan.io/tx/0x53ffc68c9082a952cb86aa71003db34fd590bbe0a5a89b7ea29ebc07609c34cf) · [enact](https://sepolia.etherscan.io/tx/0x5e88f532647de580ce0e7dd4af0c1c73480de2ad3882e80aefbaf6d3f6a97e7e). ETH: [create](https://sepolia.etherscan.io/tx/0xbf595ac2631c9d256e1da1a43b2a8768c9b42fa9e703ab1da5841a4fa4448334) · [enact](https://sepolia.etherscan.io/tx/0x3de8da61bcdd1000e055e5d52038cb86562cd9cc55f5a3aeef73a510c27ca7c5) |
| One objection rejects the motion | `ET-05`, mock rules | USD: [create](https://sepolia.etherscan.io/tx/0xcdd88f444fd0bb26b0fdd8a4b637b2337543adc90aa01f80859f5cd717b4b166) · [object](https://sepolia.etherscan.io/tx/0x6517b4becbbeb1e75ef42e95386a1468bee2dfb1089bbc59e08e492404d7da9b). ETH: [create](https://sepolia.etherscan.io/tx/0xefd849d99b831651d3d2f304f07d91c5519419f1e12fa88cd8b31791cbcd5d49) · [object](https://sepolia.etherscan.io/tx/0xe2acf6b927496530298bf185beca84958814ba7e129adf1a9b507b53133990d2) |
| Test Voting cancels the motion | `ET-06` | USD: [create](https://sepolia.etherscan.io/tx/0x059759bc9abc43316d0c993f7236c1314fe09467999807b2cc7bbecf587499b5) · [cancel](https://sepolia.etherscan.io/tx/0x8a78d07bffc0844e2081c7334114275eee9bbe22d0ea170630fe8486e63f8176). ETH: [create](https://sepolia.etherscan.io/tx/0x50c9fd72e0d23f6c5470fdc1e7f4e1b76edb4d5e3c43c0844fb24b9878c011d5) · [cancel](https://sepolia.etherscan.io/tx/0x2d2e072fda13dd558ae18aeb587ffe3e8bf5440359dad12d743b5c0e18e86a6e) |
| Test Voting cancels a pending motion while the Asset operator is stopped | `ET-10` | [create](https://sepolia.etherscan.io/tx/0x76182697557f59f6bd7074879207fcf277b20b6b3aedf8916747c5a5e0959a7f)\* · [cancel](https://sepolia.etherscan.io/tx/0x8d35e28c89e41a60fc53ba37305bf3fbe465f29e1b3dee3037f656ceea5d4658)\* |

**Emergency stop and restart**

The stand owner ran the stop and restart two times. The table cites the first drill. The second drill, in blocks `11987277–11987311`, adds the recovery order of the last row [s7].

| Flow and result | ID | Transactions |
|---|---|---|
| Stop on Asset. The Emergency Safe disables the operator module | `EM-01` | [disable](https://sepolia.etherscan.io/tx/0xb926d29b1ef443543491a2cf43c2abfb0d447d051252332e03890016a00ab4fb) |
| Stop on Orders. The Emergency Safe revokes the four operator targets | `EM-02` | [WETH](https://sepolia.etherscan.io/tx/0x87987768fa9d2b825cbfaf34e8082a961eb3c503bcd7c92be2cf452e7a77e5de) · [USDC](https://sepolia.etherscan.io/tx/0x38774559212359c8674c7562dc89272e73ac0ecf7bf35b512fca3d91d17c5a06) · [order signer](https://sepolia.etherscan.io/tx/0x16cfec3d8c95101cd43a3ed9f57f2e773627b807e7c688d85df4cd2713ba0130) · [ComposableCoW](https://sepolia.etherscan.io/tx/0x990d9109ceff8d1cde0ddc723cbd9b131b6121d4e99132b1d5c2618b59858df0) |
| The Emergency Safe cancels an order, signs its own order and cancels it | `ORD-08` | [cancel](https://sepolia.etherscan.io/tx/0x7963225816515aa857049144806c219b7bfa1bd8c00f8edd5f2c9bb77785d126)\* · [sign](https://sepolia.etherscan.io/tx/0x83135a17a52881758ef6a94f53578ae4a3f54d4ba387762b0cabb2c47f437df5)\* · [cancel](https://sepolia.etherscan.io/tx/0x9c291cea16438e96ca451d6cf6bc5b652b1233e9aace9808c710e9e9ab9646fc)\* |
| Sweep to the Agent: 0.005 WETH from Asset, 0.005 WETH from Orders, 385.906115 USDC from Asset | `EM-04` | [Asset WETH](https://sepolia.etherscan.io/tx/0x67b55925699b0aeac9a43932ad30f2c782472584c981bc042f5d6959277c98be)\* · [Orders WETH](https://sepolia.etherscan.io/tx/0xe289a425dbf944eb13f82b4de3328d8c3765ff9fb416074ccebdefded9562163)\* · [Asset USDC](https://sepolia.etherscan.io/tx/0xf992f4c5b506a7049078833a657c2ea9fa21fa65e8479302f70f53aceb2c6757)\* |
| Both relayer approvals set to zero | `SETTLE-06` | [WETH](https://sepolia.etherscan.io/tx/0x4299065d00a4667796780ca15a62b44fc0062794b8afe190d2e48c1482b631c7) · [USDC](https://sepolia.etherscan.io/tx/0x37d056b295c7566f5cccc2943beac347c2528a4e6cefef06f861305fa4c5f000) |
| Restart through test Voting: the Asset module, four targets, two approvals | `EM-08` | [module](https://sepolia.etherscan.io/tx/0xb14421a250355c4d46cb71787e889a48f6a0f34f75c49c32553824e01f79aa7b) · [WETH](https://sepolia.etherscan.io/tx/0x475ca91a79a5a941337f6c724e9c010e81e78e605e3125a9086257e3a214c665) · [USDC](https://sepolia.etherscan.io/tx/0xc26930957206cc42d27c790d6dbeac50bf31b73b1019bfafbcc5ec30472d6574) · [order signer](https://sepolia.etherscan.io/tx/0xb7dafaec7d27260d57eb5d802d18ecc55efda7dc5dc724cfd3f314b549279db1) · [ComposableCoW](https://sepolia.etherscan.io/tx/0x834a4209d7a8c691e7f4f338f49e20726dc2e570769f29c25842ad26355b11eb)\* · [approve WETH](https://sepolia.etherscan.io/tx/0x545ce83d0db417ba88f3c52209d06a31214f32364894bbec83ebd30b8535ba66)\* · [approve USDC](https://sepolia.etherscan.io/tx/0x8eeb9a256e6987517e8b1f779e526e25c734c1d930b46add6664801364681b0a)\* |
| The Agent returns the tokens to Asset. The Committee Safe moves one raw WETH unit to Orders and back | `EM-06`, `EM-08` | [Agent WETH](https://sepolia.etherscan.io/tx/0xeb64ece3d945ddea0db695645e76f2ce32da5da1a8bc5c8584fe9bb7c07f4242)\* · [Agent USDC](https://sepolia.etherscan.io/tx/0x268f6e04943435e79b73423d4345aa4b11c4bd612d6d66897851cefe50968292)\* · [fund](https://sepolia.etherscan.io/tx/0xcd715924bfdd18abbce4cfb332917bc509848bc1b26d6a0f05549eecea1aa9c0)\* · [return](https://sepolia.etherscan.io/tx/0x7446c5a22172631a605154ba1e0b39c60c1821171aaff31e17de0ffae75864d4)\* |
| Recovery order during a stop. The Emergency Safe sells 0.005 WETH. The solver pays 193.237414 USDC to the Agent | `EM-05`, `EM-06` | [sign](https://sepolia.etherscan.io/tx/0x5c7df438849a8c3f2ab6a592b868305d4f1f3bc50fcd816e83143354166014f3) · [fill](https://sepolia.etherscan.io/tx/0x1fb3284c9e2a31a8620264a1e74684ae3fb46063da86b43f1c3c69f43bca548e) |

**Script faults**

| Flow and result | ID | Transactions |
|---|---|---|
| The funding script stops after the first transaction. The resume sends only the three remaining transfers | `FUND-12` | [1](https://sepolia.etherscan.io/tx/0xb4f47a30c5b6acbd4ad377a1aa14ba5fb51af5ea63a47d3ad842971ae7ca712e) · [2](https://sepolia.etherscan.io/tx/0xe45e1d44e1275d33feb5423d7465899d5ddbb4ff32e3f080b1525606ba7926ea) · [3](https://sepolia.etherscan.io/tx/0xf800d0a4d626098061c858437b2a271d4c4b4089b2117af9be08520459507992) · [4](https://sepolia.etherscan.io/tx/0x021e631171ed441266575f0ca6c1dd7850538fd5511887cc865485083f6eac06) |
| Lost response, lost submission, timeout and nonce replacement. Each transaction executed one time | `OPS-09` | [lost response](https://sepolia.etherscan.io/tx/0x0075c5eabac1f7462ca75e4ef0c30c9be154a71bc451f614a9d5168537828e32)\* · [resume](https://sepolia.etherscan.io/tx/0x20752a5159e0f499c7864188c20e9f9682d5022552a16be7ec309b81e8f7b2e2) · [timeout](https://sepolia.etherscan.io/tx/0x1e621f229691b74d259d25f4f90e50974bb3ad2aadc7f30b1f774dfe6a4ac30d) · [legacy](https://sepolia.etherscan.io/tx/0x23a62e73fc112e4ab09253e4fe97169eeef85bd78e3ed7d4beca586ed860e2c7) · [EIP-1559](https://sepolia.etherscan.io/tx/0x05b08210d07de4459c29d586e8cdf9d6893b2747403efd06891d10776c92a5d7) |

## 3. Cases without coverage

No fork test and no transaction:

- [ ] **UI signing (`OPS-01`, `OPS-03`, `OPS-04`).** The UI batch of the test plan has no transaction. The Committee nonce is still `51`, the value of the prepared envelope [s2][s3][s7].
- [ ] **Signers and thresholds (`MAIN-14`).** Each of the five Safes has a threshold of 1. One controller owns both operating Safes and every test governance contract [s4][s7].
- [ ] **Governance through a motion (`GOV-08`, `GOV-10`).** The stand has no governance factory. The fork tests impersonate the executor [s1][s5].
- [ ] **Screening and the Committee guard (`MAIN-12`, `MAIN-13`).** The guard slot of each Safe is zero [s7].
- [ ] **Monitoring and alerts (`OPS-12`).** No test [s1].

Partial coverage:

- [ ] **`GOV-09`.** A fork test reproduces a defect: an old owner payload restores a permission that the owner revoked later. No check detects such a payload before the signature [s1][s5].
- [ ] **`EM-05`.** The recovery order is tested from WETH to USDC only. The stand has no USDT [s1].
- [ ] **`ET-05`.** The mock Easy Track reads the current balance, not a snapshot, and counts one objector more than one time [s5].
- [ ] **`SETTLE-04`.** Some protocol-fee cases are open [s1].
- [ ] **`CFG-02`.** Nobody approved the runtime baselines [s1].
- [ ] **First-loss economics.** The test queues settle at 1:1. They do not model prices, fees or liquidity [s5].

The launch integrations `MAIN-01` to `MAIN-11` are not on the stand. Only the mainnet fork tests them, and this review did not run those suites [s1].

## 4. Cases that can be tested now

Each case below has a fork test but no real transaction. The current stand can run it without a change [s5][s7].

| Case | Closes | Current state |
|---|---|---|
| Funding and return in one batch through the UI, with a wallet signature | `OPS-01`, `OPS-03` | The envelope is in `cache/sepolia/ui-funding-return-2026-10-25/`. The nonce did not change, so its hash is still valid |
| Two competing proposals for one nonce | `OPS-04` | Not tested |
| The Committee Safe cancels its own burn motion | `ET-06` | All public cancellations went through test Voting |
| The Emergency Safe revokes one function, not a full target | `EM-02` | The drills used the full-target revoke only |
| The other permitted Emergency routes: Asset to Orders, Orders to Asset, USDC from Orders to the Agent | `EM-04` | The drills moved tokens from Asset and WETH from Orders to the Agent only |
| The operator removes an active TWAP before its next part | `TWAP-08` | The Emergency Safe removed the active one |
| Buy from WETH to USDC, partial fill from WETH to USDC, TWAP from USDC to WETH | `SETTLE-04` | The seven public fills do not include these variants |
| A real budget refill after `2026-11-19T14:38Z` | `FUND-07` | Both budgets have a 30-day period from `2026-10-20T14:38Z` |
| Use of a budget to its exact limit | `FUND-02` | `orders_weth` has 0.975 of 1 WETH. Asset must receive more tokens first |

Without public transactions:

- Add `just --justfile sepolia.just check` to CI. An edit of `.github/` needs an explicit human request.
- Replace the `cache/` inputs of the fork suite with committed fixtures. Then run the suite in CI at block `11992758`.
- Add the starred transactions of section 2.2 to the test plan.
- Add a check of an owner payload against the current policy before the signature (`GOV-09`).

After a stand change:

- Different signers and a threshold above 1 on the Committee and Emergency Safes (`MAIN-14`). The acceptor selects the signers.
- A governance factory, for the full motion path (`GOV-08`, `GOV-10`).
- A test USDT, for the recovery order (`EM-05`).

## 5. Review findings

1. **No Sepolia check runs in CI.** The `Justfile` and the workflows call no Sepolia recipe. The fork tests skip when `SEPOLIA_STAND_BLOCK` is not set. A regression does not block a merge [s5].
2. **The evidence is local.** The evidence of the three Sepolia pages is in the git-ignored `cache/` directory. Two fork tests and the fork runner read files from it. A clean clone cannot repeat the fork run [s3][s5].
3. **The transaction table of the test plan is incomplete.** It cites four of the seven restore steps. It does not cite the sweeps, the second drill, the deployment or the role migration [s2][s7].
4. **The two drills restore in a different order.** The first drill enabled the Asset operator module first. The second drill enabled it [last](https://sepolia.etherscan.io/tx/0x9140fc8a7dabf70e56ee6ce884f262c0c83105c783561312df6d043dac6057d5), after the targets and approvals. The restart procedure should specify one order [s7].

## Method

The review ran these commands on 2026-11-10. The logs and scripts are in `cache/sepolia/review-2026-11-10/` [s6][s7].

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

The scripts call `eth_getTransactionReceipt`, `eth_getLogs`, `eth_call` and `eth_getStorageAt` on the archive RPC of the local `.env`.
The review did not repeat the mainnet fork suites, the claims that come from the CoW API and the UI screenshots [s3].
The event scan covers the two emergency drills only.
