---
type: Guide
title: Sepolia stand deployment plan
description: Prepare, deploy and test one Sepolia stand with Asset, Orders and First-loss Safes, CoW orders and test governance.
tags: [sepolia, deployment, testing, cow, first-loss]
status: draft
review_status: slop
generated:
  by: claude-code/sonnet-5.5
  at: 2026-11-12T12:27:25Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account owners, modifiers, role holders and emergency controls
  - id: s2
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — market, limit and TWAP orders, recipients, approvals and cancellation
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — first-loss shares, redemption, burn motions and the launch scope
  - id: s4
    resource: https://docs.cow.fi/cow-protocol/integrate/api
    title: CoW API — Sepolia endpoint, quotes, orders and trade records
  - id: s5
    resource: https://github.com/cowprotocol/composable-cow
    title: ComposableCoW — Safe configuration, conditional orders, TWAP and deployments
  - id: s6
    resource: https://docs.lido.fi/deployed-contracts/sepolia/
    title: Lido — deprecated Sepolia deployment and the Hoodi replacement
  - id: s7
    resource: https://github.com/lidofinance/clutch/blob/0b85af8ce131b64f1c5672a0dea26d8a3f87665c/CONTRIBUTING.md
    title: Contribution workflow — checks, generated files and signing accounts
  - id: s8
    resource: urn:clutch:evidence:2026-10-20:local-sepolia-rpc-and-keystore
    title: Local setup — RPC chain read, keystore creation output, sender checksum and local configuration checks
  - id: s9
    resource: urn:clutch:instruction:2026-10-20:sepolia-one-key
    title: Stand owner instruction — Committee and Emergency 1/1, one controller for test Voting
  - id: s10
    resource: https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement
    title: Ethereum Foundation — Sepolia Amsterdam activation and gas repricing
  - id: s11
    resource: urn:clutch:evidence:2026-10-20:sepolia-fork-rehearsal
    title: Local fork evidence — dependency probe, deployment receipts and seven CoW and First-loss drills
  - id: s12
    resource: urn:clutch:evidence:2026-10-20:sepolia-sender-funded
    title: Sepolia RPC — sender balance and nonce at block 11955105
  - id: s13
    resource: urn:clutch:evidence:2026-10-20:sepolia-public-deployment
    title: Public Sepolia deployment — 39 successful receipts and configuration readback at block 11955151
  - id: s14
    resource: urn:clutch:evidence:2026-10-20:sepolia-explorer-verification
    title: Etherscan API — 12 exact source matches and frozen compiler inputs
  - id: s15
    resource: urn:clutch:evidence:2026-10-20:sepolia-policy-interruption
    title: Interrupted policy run — DNS failure, 101 canonical receipts and recovery of the missing nonce-139 transaction
  - id: s16
    resource: urn:clutch:evidence:2026-10-20:sepolia-safe-roles-ui
    title: Browser readback — Safe version, Voting owner and two modules; operator targets and unsupported allowance rendering in Zodiac Roles
  - id: s17
    resource: urn:clutch:evidence:2026-10-20:sepolia-zodiac-workspace-import
    title: Zodiac workspace — three imported vaults, six saved policies and the governance import error
  - id: s18
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-snapshot
    title: Local Constellation — existing accounts, SDK serialization, 126 saved apply receipts and zero RPC policy differences at block 11956623
  - id: s19
    resource: urn:clutch:evidence:2026-10-20:zodiac-workspace-plan-limits
    title: Workspace usage screenshot — six policies against a limit of three; three vaults against a limit of three
  - id: s20
    resource: urn:clutch:evidence:2026-10-20:zodiac-address-book
    title: Address Book — 36 saved names, addresses and Sepolia chain assignments checked against the local manifest and dependencies
  - id: s21
    resource: urn:clutch:evidence:2026-10-20:sepolia-published-constellation
    title: Published Clutch Sepolia draft — existing accounts, original role keys and unapplied governance condition differences
  - id: s22
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-deployment-started
    title: Started Constellation deployment — five pending calls checked against the local policy and a successful read-only simulation through test Voting
  - id: s23
    resource: urn:clutch:evidence:2026-10-22:sepolia-pending-review
    title: Zodiac readback — cancelled deployment and two proposals remaining in Outstanding
  - id: s24
    resource: urn:clutch:evidence:2026-10-22:sepolia-legacy-export-regression
    title: Local export regression — original Nor conditions, legacy governance format and unchanged configuration calls
  - id: s25
    resource: urn:clutch:evidence:2026-10-22:sepolia-snapshot-retention
    title: CLI regression tests — failed RPC preparation preserves saved payload, context and diff
  - id: s26
    resource: /adr/015-tests-on-sepolia.md
    title: ADR 015 — proposed Sepolia permissions, role-key migration and mainnet design dependencies, OD-132 to OD-137
  - id: s27
    resource: urn:clutch:evidence:2026-10-22:sepolia-resolution-check
    title: Local check — the resolution saved on 2026-10-20 against the current payload; the same 63 calls with the roles in another order; Safe owners and modules match
  - id: s28
    resource: urn:clutch:evidence:2026-10-22:sepolia-publisher-regressions
    title: Publisher regression tests — invalid success responses, body-read timeouts and separate attempts for each API URL and workspace
  - id: s29
    resource: urn:clutch:evidence:2026-10-22:zodiac-quota-reply
    title: Reply relayed by the stand owner — quotas are not enforced immediately and tests may exceed the displayed limits
  - id: s30
    resource: urn:clutch:evidence:2026-10-22:sepolia-constellation-deployed
    title: Owner publication from dacf262, Deployed and Nothing to deploy in Zodiac, original Nor conditions and zero RPC differences at block 11970750
  - id: s31
    resource: /research/sepolia-constellation-ui-2026-10-22.md
    title: UI registration review — SDK 2.10.0, all workspace metadata and the duplicate-key permission conflicts
  - id: s32
    resource: urn:clutch:evidence:2026-10-23:sepolia-role-key-migration
    title: Owner publication HTTP 200; two canonical successful migration receipts; zero policy differences, unchanged allowances and Safe configuration at block 11976825
  - id: s33
    resource: urn:clutch:evidence:2026-10-23:sepolia-workspace-after-migration
    title: Zodiac UI check — Deploy refuses a Safe already registered in Sepolia Basic Test; Remove vault affects only workspace records
  - id: s34
    resource: urn:clutch:evidence:2026-10-23:sepolia-workspace-registration
    title: Three old vault records removed after four saved policy bindings were detached; new Constellation Deployed with Nothing to deploy, three Vaults and seven Policies
  - id: s35
    resource: /specs/sepolia-test-plan.md
    title: Current-stand fork cases and public transaction sequences
  - id: s36
    resource: urn:clutch:evidence:2026-10-25:sepolia-safe-config-drift
    title: Safe configuration drift reproduced on a pinned fork, verifier corrected and 44 regression cases passed
---

# Sepolia stand deployment

Keep RPC credentials, keystores and run records local.
Publish the code and documentation on `testnet/sepolia`.
Production follow-ups are in [Differences from production](#differences-from-production).

## 1. RPC and signer

- [x] RPC returns chain `11155111` [s8].
- [x] Encrypted keystore: `clutch-sepolia`; permissions: `0600` [s8].
- [x] Local `.env` contains `SEPOLIA_RPC`, `SEPOLIA_ACCOUNT` and `SEPOLIA_SENDER` [s8].
- [x] Sender matches the keystore creation output: `0x4CAE8fd384bbe8dec68CdFbC2CbE4b398902E03c` [s8].
- [x] Agreed configuration: Committee and Emergency: separate 1/1 Safes with this sender as owner. The sender also controls test Voting [s9].

Do not put the keystore password or private key in `.env` [s7].

## 2. Local rehearsal

```sh
just --justfile sepolia.just check
just --justfile sepolia.just preflight
just --justfile sepolia.just rehearse
```

`rehearse` starts a disposable Anvil fork on `127.0.0.1:8547`, deploys the stand, compiles and applies its policy, funds test balances, then runs the drills.
It stops Anvil after the run. It does not sign or send public transactions.
Its receipts stay under `cache/sepolia/rehearsal/broadcast/`.
The commands use Amsterdam execution rules [s10].

- [x] Pin 13 dependency addresses and runtime hashes in `policy/constellation/sepolia/network.json`, read at block `11954838` [s11].
- [x] CoW quote probe: WETH → test USDC, HTTP `200`. Request and response: `cache/sepolia/quote-{request,response}.json` [s4].
- [x] Local deployment, policy application and funding: 39 + 126 + 4 transactions, all receipts have status `1` [s11].
- [x] CoW presign/unsign and two-part TWAP signature/cancellation probes pass [s11].
- [x] Both First-loss redemption paths, burn timing, objection and Voting cancellation pass; all 7 fork tests pass [s11].
- [x] Record local gas use: `90,936,081` across deployment, application and funding [s11].

Before signing, run `preflight` again.
Use its fee-history estimate and the rehearsal gas units for the fee estimate.
Preflight reads ten blocks and uses the median 50th-percentile tip plus twice the next base fee.
The public deployment used `55,854,156` gas and cost `55,854,155,943,826,071 wei` [s13].
Local fork fees do not estimate the public fee.

A quote does not prove order acceptance or settlement [s4].
Results and logs go to `cache/sepolia/rehearsal/`.

## 3. Create the Safes

- [x] Fund the public sender. RPC returned `1.55 Sepolia ETH` (`1550000000000000000 wei`) at block `11955105`; sender nonce is `0` [s12].

Proposed fixture values: Asset → Orders budgets of 1 test WETH and 1,000 test USDC per 30 days; mock objection window of 60 seconds; objection threshold of 1 test VOTE.
The script mints 1,000 test VOTE and 100 of each test share to the sender.
These values configure this stand.
Order limits remain 90 days for the operator and 1 day for recovery [s2].

For a new stand, run after step 2 passes and the public sender has funds:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just deploy
```

Enter the keystore password in the terminal. The script creates all five Safes; no manual Safe creation is needed [s1][s2][s3].

| Safe | Version | Owner | Configuration |
|---|---|---|---|
| Committee | 1.3.0 | Sender, 1/1 | Operator, First-loss and burn-motion proposer |
| Emergency | 1.5.0 | Sender, 1/1 | Emergency roles on Asset and Orders |
| Asset | 1.5.0 | Test Voting | Operator and safety modifiers |
| Orders | 1.5.0 | Test Voting | Orders modifier, CoW fallback handler and domain verifier |
| First-loss | 1.5.0 | Test Voting | First-loss modifier |

The script also creates a separate test Agent, mock Easy Track, its executor, two share tokens, redemption queues and a typed burn factory.
The sender controls the test governance contracts. This setup does not test signer independence [s9].

- [x] Public deployment: `39/39` receipts have status `1`, blocks `11955109–11955147`; no Safe execution failed [s13].
- [x] Confirm the 21 deployed addresses in `cache/sepolia/manifest.json` have code; compare direct CREATE receipts and Safe/module factory events [s13].
- [x] Read back Safe owners, thresholds, versions, modules and guards; each modifier's owner/avatar/target; CoW verifier and relayer approvals; First-loss queues, factory and test balances. All match the deployment configuration [s13].

Check the public deployment without sending transactions:

```sh
just --justfile sepolia.just verify-deployment
```

`verify-deployment` checks canonical receipts and the initial configuration at the final deployment block.
The earlier readback passed 415 checks at block `11955151` [s13].
A deployment check does not prove that the policy was applied or the stand was funded.

- [x] Verify the 12 stand contracts on Etherscan. All 12 have exact source matches, including both internal claim tokens. The five Safe proxies and four Roles proxies have recognized source [s14].

`deploy` and `resume-deploy` verify the sources on Etherscan through forge `--verify`. Set `ETHERSCAN_API_KEY` in the git-ignored `.env`.

After an interrupted deployment, inspect `broadcast/DeploySepolia.s.sol/11155111/`, then resume:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just resume-deploy
```

Do not start a second deployment from an existing manifest.
New manifests call the simulation height `simulationBlock`.
The existing manifest uses `deployBlock: 11955106`; the public receipts span blocks `11955109–11955147` [s13].

## 4. Apply permissions

The first run stopped after an RPC DNS failure.
Recovery confirmed 101 canonical receipts and restored the missing transaction at nonce `139` [s15].
The saved run now contains all 126 transaction hashes and 126 successful receipts.
The current RPC policy comparison found zero differences at block `11956623` [s18].
If a later run stops with transactions left, continue its recorded sequence:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just resume-apply
```

The artifact `cache/sepolia/policy.json` contains 63 configuration calls.
The resume command sends the transactions left in the recorded run.
Recovery checks and the backup path are in `cache/sepolia/apply-interruption-verification.json` [s15].
A fresh application resets budgets and restores the configured permissions.

- [ ] Verify all application receipts against canonical RPC receipts before funding. The saved receipt statuses alone do not cover this check.
- [x] Read back role membership, allowances, enabled modules and each modifier's owner/avatar/target. The comparison found zero policy differences [s18].
- [x] Save the policy snapshot and block hash in `cache/sepolia/constellation/diff.json` [s18].

### Prepare the existing stand as a Constellation

From the repository root, with `SEPOLIA_RPC` in the local `.env`:

```sh
just --justfile sepolia.just constellation <workspace-uuid>
just --justfile sepolia.just constellation-diff
just --justfile sepolia.just constellation-inspect
```

`constellation` reads the current policy through RPC and writes a local SDK payload.
It binds the three existing vault Safes and four Roles modifiers by address.
Committee and Emergency remain literal member addresses.
The role keys are `asset-operator`, `orders-operator`, `asset-emergency`, `orders-emergency`, `governance`, `first-loss` and `first-loss-burn` on their modifiers.
The payload declares no deployment nonce or Safe configuration override [s18].

| File | Content |
|---|---|
| `policy/constellation/sepolia/entrypoint.ts` | Named SDK nodes, built from the prepared local context |
| `cache/sepolia/constellation/payload.json` | Local SDK capture with legacy governance targets and original condition trees |
| `cache/sepolia/constellation/context.json` | Manifest, workspace and observed allowance values |
| `cache/sepolia/constellation/diff.json` | Pinned RPC snapshot, differences and coverage limits |

The serializer preserves all permission conditions and recompiles to the same 63 configuration calls, using the observed allowance balances and timestamps.
The RPC comparison checked 82 events from modifier creation, current wiring, membership, modules, allowance configuration, default roles and unwrap adapters.
It found zero differences at block `11956623`, hash `0x3fe11ff42613589ec2419d8a1da99d7536926647df8caa8fa1612876b1f446d7` [s18].

Re-run `constellation` to refresh the payload before a future publication.
`constellation-diff` refreshes the comparison only.
These commands use RPC read methods and local files.
They do not use the Zodiac API, publish a workspace draft or send transactions.
An RPC failure leaves the previous payload, context and diff intact.
Each successful write replaces its file through a temporary file and rename.
Check the command's exit status and the report's block before using a saved result [s25].
The comparison now checks the five Safe owner sets and thresholds and requires both guard slots to be zero at the report block. The local fork reproduces the earlier owner/guard false matches and verifies their detection after correction. These expectations follow the reduced Sepolia profile. Safe versions, singleton and fallback slots, target behavior and execution success remain outside this comparison [s36].

The stand owner published `Clutch Sepolia` under an explicit exception for `review/tamtamchik`.
The workspace shows three existing Safes, four Roles modifiers and seven roles.
That draft rewrote five governance conditions from `Nor` to `And` with `Or(LessThan, GreaterThan)` pairs.
The UI marked `operator_modifier` as modified.
Evidence: `cache/sepolia/constellation/published-state.json` and `cache/sepolia/constellation/published-overview.png` [s21].

The stand owner then started the deployment in Zodiac.
The package contained five zero-value governance `scopeFunction` calls.
The decoded conditions matched the condition-replacement draft after sorting AND/OR branches.
The RPC check found five differences at block `11956949`.
The Asset Safe owner is the test Voting contract; its owner is the stand controller.
A read-only simulation through Voting succeeds at block `11956962` [s22].

The deployment is cancelled as of 2026-10-22.
Both proposals remain in `Outstanding`; cancellation did not remove them [s23].

The local policy now keeps the original `Nor` conditions.
The exported payload uses legacy `targets` and empty `annotations` for governance.
Local readback reconstructs permissions and checks the same 63 configuration calls [s24].
The pinned SDK's generic `push` does not emit this legacy format [s24].
Production hosted commands keep the repository-owner workflow from clean merged `main` [s7].
ADR 015 proposes a separate route for the Sepolia workspace. EM decides it in OD-132 and OD-133 [s26].

### Publish the declaration to the Sepolia workspace

Run these commands only after EM's decisions on OD-132 and OD-133 [s26].
Commit and push `testnet/sepolia` first.
In the local `.env`, set `SEPOLIA_ZODIAC_API_KEY` and `SEPOLIA_ZODIAC_WORKSPACE`, the workspace of the prepared context.
Set `SEPOLIA_ZODIAC_API_URL` only for another API origin; it must use https.

```sh
just --justfile sepolia.just constellation <workspace-uuid>
CLUTCH_SEPOLIA_PUSH=1 just --justfile sepolia.just constellation-resolve
CLUTCH_SEPOLIA_PUSH=1 just --justfile sepolia.just constellation-publish
```

Both hosted commands refuse CI, another branch, local changes, an unpushed commit, a missing key and another workspace.
Each command compares the chain with the policy again and checks that the payload carries the current allowances.
It then calls resolve and compares the resolved specification with the payload.
The comparison covers the accounts, the Safe owners and modules, the members, the conditions, the allowances and the modifier wiring.
The resolver may list roles and targets in another order.
`constellation-publish` calls apply only after a matching resolution, and only once for each API URL, workspace and payload hash.
Success requires a complete HTTP exchange and a JSON result with nonempty `id` and `url` strings.
An invalid result or a body-read timeout fails and retains the attempt record.
The same payload can be published to another API URL or workspace [s28].
Each response is saved with its status and body under `cache/sepolia/constellation/hosted/`. The key is not saved.
After an unclear result, inspect the workspace before any retry.
The resolution saved on 2026-10-20 in the earlier workspace passes this comparison for the current payload [s27].

After the publication, check the saved draft.
The governance role keeps `Nor`, no node is marked as modified and the hosted diff is empty.
Do not press Deploy or Apply in the Zodiac app (OD-134) [s26].

- [x] Publish the existing-state declaration and check it in the workspace. On 2026-10-22, Zodiac marks it `Deployed`; the deployment page says `Nothing to deploy`. The three Safe addresses, four modifiers and seven role keys match the prepared declaration. The original governance `Nor` conditions remain. The RPC comparison found zero differences across 82 events at block `11970750` [s30].

- [x] Prepare all three `vault: true` flags and seven policy labels locally with SDK 2.10.0. Findings and the remaining policy-key conflict are in [the UI registration note](../research/sepolia-constellation-ui-2026-10-22.md) [s31].
- [x] Migrate the four role keys to `asset-operator`, `orders-operator`, `asset-emergency` and `orders-emergency` through test Voting. Both owner transactions succeeded at blocks `11976805` and `11976806`. The comparison at block `11976825` found zero policy differences, unchanged allowance storage and unchanged Safe configuration apart from the expected nonce increments. The decision is in ADR 015; the history is in [the migration note](../research/sepolia-role-key-migration-2026-10-22.md) [s26][s32].
- [x] Confirm three Vaults and seven Policies with the new key mapping in the Zodiac workspace. Registration completed on 2026-10-23 through Constellation deployment `b3a13747-db82-40d3-a1bd-07c9873503a3`, whose page shows `Nothing to deploy`. No wallet was connected and no on-chain transaction was sent for this registration [s34]. On 2026-10-23, Deploy stops because Asset Safe is already a vault in `Sepolia Basic Test`, where policies still use it. That workspace contains all three stand vaults. Zodiac permits a Safe to be a vault in only one workspace. This was the initial registration blocker [s33].

On the owner's explicit instruction, detach the saved vault bindings from the old `operator`, `first-loss`, `first-loss-burn` and `orders-operator` policies before removing the three old vault records. The first removal attempt failed with `Vault is still in use`; saving the detached bindings released that dependency. No old policy's `Apply changes` was used. The new Constellation then completed registration with no on-chain calls, and all three Vaults and seven Policies show `Deployed` [s34].

The new workspace's Outstanding list also shows an older Asset proposal, `a7001419-4a97-46ef-b151-69fb4d3843cc`, with five calls and an age of two days. It was not signed, sent or cancelled during registration [s34].

The governance view shows `Unsupported Condition` for `Nor`, but displays its original opcode `3` tree in both columns.
The saved resolve response matches the prepared payload.
Evidence: `cache/sepolia/constellation/deployed-check-2026-10-22/` [s30].

The captured workspace usage page on 2026-10-20 showed six policies against a limit of three.
The screenshot does not establish the cause of the earlier `governance` error [s19].
On 2026-10-22, the stand owner relayed the provider's reply: limits are not enforced immediately and tests may exceed them.
Continue the current stand tests above the displayed quotas.
Record an actual save or publication error for the provider to investigate [s29].

### Inspect the UI

- [Asset Safe](https://app.safe.global/settings/modules?safe=sep:0x464f188165BCbE8f7FB3776C10E7B185963922ae): Safe UI loads version 1.5.0, the test Voting owner and both Roles modules [s16].
- [Operator permissions](https://roles.gnosisguild.org/sep:0x6b3db3a3b4d9cb4bd697256e9fb1f1d19992dac3/roles/operator): Zodiac Roles loads the two token targets, transfer functions and the Orders receiver [s16].

The Roles viewer displays budget conditions as `Unsupported Condition` for operator `28` (`WithinAllowance`).
Use RPC allowance reads and the fork drill results to check budgets; the viewer does not decode them [s11][s16].
Screenshot: `cache/sepolia/roles-ui-operator.png`.
The imported policy in the Zodiac workspace decodes the USDC transfer's Orders recipient and `WithinAllowance` condition.
It displays the allowance key, without the remaining budget amount in that view.
Screenshot: `cache/sepolia/zodiac-imported-operator.png` [s17].

- [x] Name all 36 stand and dependency addresses in the Zodiac Address Book. Check each saved name, address and Sepolia chain assignment. Local evidence: `cache/sepolia/address-book-verification.json` and `cache/sepolia/zodiac-address-book.png` [s20].
- [ ] Connect the Committee signer in a browser wallet and test an allowed call through the role.
- [ ] Confirm the execution UI displays the budget conditions before approving it for budget reviews.

## 5. Fund the stand

The sell asset is Sepolia WETH (`0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`, 18 decimals).
The buy asset is Circle test USDC (`0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`, 6 decimals).
Review these proposed test amounts, then run:

```sh
SEPOLIA_FUND_WETH_WEI=20000000000000000 \
SEPOLIA_FUND_SHARES_WEI=10000000000000000000 \
CLUTCH_SEPOLIA=1 just --justfile sepolia.just fund
```

The script wraps 0.02 Sepolia ETH and transfers the WETH to Asset.
It transfers 10 of each test share to First-loss [s3].
Keep enough Sepolia ETH on the sender for subsequent transactions.

- [ ] Confirm Asset WETH and First-loss share balances from RPC.

After an interrupted funding run, inspect its receipts, then resume:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just resume-fund
```

Do not rerun `fund` to recover a partial run: it can wrap and transfer the amounts again.

## 6. CoW drills

Use the [Sepolia test plan](sepolia-test-plan.md) for the current-stand fork command,
case matrix and transaction sequences. Recorded outcomes and findings are in the
[test results](../research/sepolia-test-results.md). Fork results do not close the public drills below [s35].

- [ ] Committee funds Orders from Asset within the budget [s2].
- [ ] Request a fresh quote from the Orders address; presign the exact typed order through its Roles modifier.
- [ ] Submit market and limit orders to the Sepolia API; record their UIDs and settlement transactions [s4].
- [ ] Test limit-order cancellation and verify its presignature is zero.
- [ ] Create a two-part TWAP. Submit each part with its EIP-1271 signature; record both settlements [s2][s5].
- [ ] Check proceeds reach Asset. Confirm an unlisted token or receiver, excessive duration and budget excess are refused.
- [ ] Confirm the operator cannot presign from Asset or approve a spender from Asset.
- [ ] Cancel a TWAP and confirm its next part cannot execute.

## 7. First-loss drills

- [ ] Redeem each test share through the Committee role; settle the fixture queue as controller; claim only to Agent [s3].
- [ ] Confirm direct burn, transfer and approve are refused.
- [ ] Create a burn motion from Committee; confirm early enactment fails and enactment after 60 seconds succeeds.
- [ ] Object to a fresh motion with test VOTE; confirm enactment fails.
- [ ] Cancel another pending motion through test Voting; confirm it cannot enact.

These queues use synthetic 1:1 settlement. They test the permission path, not Earn prices, liquidity or oracle reports.
Lido's Sepolia deployment is deprecated [s6].

## 8. Stop and close the run

- [ ] Emergency disables the Asset operator modifier and cancels outstanding Orders [s1][s2].
- [ ] Complete recovery to Agent, then zero Orders approvals. Cancel pending burn motions through test Voting before a restart [s3].
- [ ] Confirm the Asset safety module still works and Emergency cannot restore authority. Restart through test Voting; confirm canceled orders and motions stay invalid [s1].
- [ ] Sweep remaining test assets to Agent and disable the stand's modifiers.
- [ ] Save receipts, order UIDs, balances and failed-action results under `cache/sepolia/`.

## Differences from production

The stand differs from production in the ways below. Check each one before a production deployment.

| Stand configuration | Check for the production deployment |
|---|---|
| One controller owns both 1/1 Committee and Emergency Safes. | Use the accepted production owners and thresholds. Test each signer's execution path. This stand does not prove signer independence [s9]. |
| Voting, Agent, Easy Track and its executor are test contracts controlled by the sender. | Bind the production contracts and test the ownership, governance and motion paths on a mainnet fork [s1][s9]. |
| First-loss uses test shares and queues with synthetic 1:1 settlement. | Test the real shares and redemption paths, including prices, liquidity and oracle reports. The synthetic drills cover permissions [s1][s11]. |
| Budgets, motion timing and objection settings use test fixtures. | Use the accepted production configuration and repeat the allowed and denied action tests [s2]. |

- [ ] Rehearse configuration and interrupted-run recovery on the target network. Include a transaction mined before its receipt reaches the saved run. Confirm canonical receipts and final state before funding [s15].
- [ ] Repeat the dependency-code and execution-rule checks for the target network. Preserve the exact compiler inputs and verify every deployed instance [s10][s14].
