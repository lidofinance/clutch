---
type: Research Note
title: Sepolia deployment findings
description: Observed errors, applied corrections and open items before a production deployment.
tags: [sepolia, deployment, testing]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-22T19:20:48Z
verified: []
sources:
  - id: s1
    resource: urn:clutch:evidence:2026-10-20:sepolia-fork-rehearsal
    title: Local rehearsal — build failures, corrected scripts, receipts and seven fork drills
  - id: s2
    resource: urn:clutch:evidence:2026-10-20:sepolia-public-deployment
    title: Public deployment — canonical receipts, gas use and configuration readback
  - id: s3
    resource: urn:clutch:evidence:2026-10-20:sepolia-explorer-verification
    title: Etherscan — 12 exact source matches, submission records and frozen compiler inputs
  - id: s4
    resource: https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement
    title: Ethereum Foundation — Sepolia Amsterdam activation and gas repricing
  - id: s5
    resource: urn:clutch:evidence:2026-10-20:sepolia-deployment-review
    title: Local review — recorded deployment inputs, deployed Roles ABI and recovery checks
  - id: s6
    resource: urn:clutch:evidence:2026-10-20:sepolia-policy-interruption
    title: Interrupted apply — terminal DNS failure, canonical receipts, sender nonce and recovered transaction
  - id: s7
    resource: urn:clutch:evidence:2026-10-20:sepolia-safe-roles-ui
    title: Browser evidence — Safe account and module views; unsupported WithinAllowance rendering in Zodiac Roles
  - id: s8
    resource: urn:clutch:evidence:2026-10-20:sepolia-zodiac-workspace-import
    title: Zodiac workspace — three imported vaults, policy readback, server errors and duplicate role keys
  - id: s9
    resource: https://docs.zodiac.eco/developers/roles/role-keys
    title: Zodiac — unique policy keys and role migration after import
  - id: s10
    resource: /specs/sepolia-stand-plan.md
    title: Sepolia stand — agreed fixtures, controller authority and outstanding public drills
  - id: s11
    resource: urn:clutch:evidence:2026-10-20:sepolia-document-checks
    title: Local documentation checks — ten existing ADR verification errors during regeneration
  - id: s12
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-snapshot
    title: Local Constellation — SDK condition serialization, captured initialization event, preserved allowances and zero RPC policy differences
  - id: s13
    resource: urn:clutch:evidence:2026-10-20:zodiac-workspace-plan-limits
    title: Workspace usage screenshot — policy and vault limits, saved at cache/sepolia/zodiac-plan-limits.png
  - id: s14
    resource: urn:clutch:evidence:2026-10-20:zodiac-policy-address-labels
    title: Fresh operator policy view — Address Book labels resolve for targets and the Orders recipient; External members still shows the Committee address
  - id: s15
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-push
    title: Hosted Constellation push — 400 validation response, roles SDK integrity check of both condition forms and the allowance key correction
  - id: s16
    resource: urn:clutch:evidence:2026-10-20:nor-replacement-checks
    title: Nor replacement — compiler and Sepolia tests, fork suite with 52 passes, integrity check of 34 payload permissions and five RPC differences
  - id: s17
    resource: urn:clutch:evidence:2026-10-20:sepolia-published-constellation
    title: Published Clutch Sepolia draft — three existing Safes, four Roles modifiers, seven roles and a governance condition difference in the UI
  - id: s18
    resource: urn:clutch:evidence:2026-10-20:sepolia-legacy-targets-resolve
    title: Hosted resolve — permissions with Nor returns 400; legacy targets with empty annotations preserves Nor and returns 200
  - id: s19
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-deployment-started
    title: Deployment started — five pending governance calls, RPC differences at block 11956949 and successful read-only Voting execution simulation at block 11956962
  - id: s20
    resource: urn:clutch:evidence:2026-10-22:sepolia-pending-review
    title: Zodiac readback — cancelled deployment, two remaining proposals, server error and operator-route refusal
  - id: s21
    resource: urn:clutch:evidence:2026-10-22:sepolia-legacy-export-regression
    title: Local export regression — original Nor conditions, six governance scopes and 63 configuration calls
  - id: s22
    resource: urn:clutch:evidence:2026-10-22:sepolia-publication-review
    title: Local review — retired unpublished helper, snapshot-retention regression tests and archived RPC evidence
  - id: s23
    resource: urn:clutch:evidence:2026-10-22:sepolia-publisher-regressions
    title: Publisher regression tests — invalid success responses, body-read timeouts and separate attempts for each API URL and workspace
  - id: s24
    resource: urn:clutch:evidence:2026-10-22:zodiac-quota-reply
    title: Reply relayed by the stand owner — quotas are not enforced immediately and tests may exceed the displayed limits
  - id: s25
    resource: urn:clutch:evidence:2026-10-22:sepolia-constellation-deployed
    title: Owner publication from dacf262, Deployed and Nothing to deploy in Zodiac, original Nor conditions and zero RPC differences at block 11970750
  - id: s26
    resource: /research/sepolia-constellation-ui-2026-10-22.md
    title: UI registration review — SDK 2.10.0, all workspace metadata and two incompatible policy groups
---

# Sepolia deployment findings

The public deployment completed with 39 successful transactions at blocks `11955109–11955147`.
The readback at block `11955151` passed 415 checks [s2].
Use [the deployment plan](sepolia-stand-plan.md) for the next actions.

## Constellation check on 2026-10-22

The stand owner published the existing-state declaration from commit `dacf262` to workspace `25091c1a-4f37-48b1-8d35-f287550481a8`.
The saved resolve and apply responses have HTTP status `200`; the resolution matches the payload.
[Clutch Sepolia](https://app.zodiac.eco/workspace/25091c1a-4f37-48b1-8d35-f287550481a8/constellations/c0cc7061-5e89-4024-bf1b-2a3531f2f311) shows `Deployed`.
Its deployment page says `Nothing to deploy` and `All updates have been applied onchain` [s25].

The read-only command `just --justfile sepolia.just constellation-diff` checked 82 events at block `11970750` and found zero policy differences.
The prepared payload matches the current state.
This check did not inspect a new transaction receipt; the empty deployment does not establish new on-chain execution.
Evidence: `cache/sepolia/constellation/deployed-check-2026-10-22/` [s25].

The governance view still shows `Unsupported Condition` for `Nor`.
Both columns display the original opcode `3` tree with the nine protected addresses.
Use the resolved specification and RPC comparison to check those conditions [s25].

The same workspace shows `No vaults yet` under Vaults and `No policies defined` under Policies.
The Constellation graph contains the accounts and roles, but those two lists remain empty.
The earlier completion check covered the Constellation and RPC state; it missed these lists.
The declaration omitted `vault: true` on the Safes and `policy` on the roles.
SDK 2.1.2 also dropped policy labels.
The local dependencies now use SDK 2.10.0 and API types 1.13.0.
The correction adds all three vault flags and seven policy labels without changing the original keys.
Preparation records both policy conflicts and returns status `1`; the publication CLI refuses them before a hosted request.
Promoting all seven roles still conflicts with Zodiac's rule that one policy key has the same grants on each modifier: `operator` and `emergency` differ between Asset and Orders.
The research note records the source reads, the offline reproduction and the remaining provider requirement [s26].
Evidence: `vaults-empty.*` and `policies-empty.*` in the same evidence directory [s25].

## Issues found during preparation

| Issue | Correction | Reason |
|---|---|---|
| Cancun estimates did not match Sepolia's Amsterdam gas rules. | Pass `--hardfork amsterdam` to the Sepolia scripts and local fork. | Use the network's execution rules when estimating gas [s1][s4]. |
| Foundry could not read or write the new Sepolia inputs and artifacts. | Grant read access to the Sepolia network directory and read/write access to `cache/sepolia/`. | Run the scripts without broad filesystem access [s1]. |
| The deployment script exceeded the compiler's Yul stack limit. | Keep stand addresses in one struct and split account creation from fixture creation. | Compile the deployment without changing its account graph [s1]. |
| The manifest writer used the wrong serialization API shape. | Write the address object, then add the dependency object with `writeJson`. | Produce valid JSON that the policy compiler can read [s1]. |
| The initial CoW call did not match the four-argument `createWithContext` ABI. | Add the dispatch argument to the interface, policy and TWAP drill. | Use the deployed contract's selector and argument layout [s1]. |
| Rehearsal broadcasts shared the public broadcast directory. | Set `FOUNDRY_BROADCAST` to `cache/sepolia/rehearsal/broadcast/`. | Keep local receipts out of public recovery records [s1]. |
| Local mining stalled pending script transactions. | Use mixed mining with a one-second interval during broadcasts. | Mine transactions when the immediate mining trigger stalls [s1]. |
| Interval mining caused RPC read failures during the parallel drill suite. | Switch Anvil to automining before the tests. | Keep the local head fixed between test transactions [s1]. |

## Gaps found in the deployment review

| Gap | Correction | Reason |
|---|---|---|
| The local fee was used to size public funding. The public deployment used the same gas but paid a higher gas price. | Combine measured gas units with the current fee-history estimate in `preflight`. | Deployment used `55,854,156` gas and paid `55,854,155,943,826,071 wei`. Local fees depend on the fork's mining conditions [s1][s2]. |
| The RPC returned `eth_gasPrice: 21 wei` and `eth_maxPriorityFeePerGas: 7 wei`, while recent included tips were about `1 gwei`. | Read ten blocks with `eth_feeHistory`; use the median 50th-percentile tip plus twice the next base fee. | Estimate fees from recent included transactions instead of the low RPC suggestions [s5]. |
| `deployBlock` named the simulation height as if it were a mined deployment block. | Name it `simulationBlock` in new manifests; derive the mined range from canonical receipts. | The existing value is `11955106`; the first mined receipt is at `11955109` [s2]. |
| Receipt and state checks existed only as cached one-off tools. | Add `verify-deployment` with receipt checks and initial-state reads at the final deployment block. | A manifest and successful simulation do not prove a completed public deployment [s2][s5]. |
| A fresh policy run resets budgets and restores permissions; repeated funding transfers the amounts again. | Refuse an existing broadcast on `apply` and `fund`; provide guarded `resume-deploy`, `resume-apply` and `resume-fund`. | Recover the recorded run without generating a second transaction sequence [s5]. |
| The drill runner could accept a green suite with missing tests. | Require the exact seven drill names, seven passes and no skips. | A successful Forge exit alone does not prove the required paths ran [s1][s5]. |
| `IRoles.getModulesPaginated` used an integer cursor and return value. | Use `getModulesPaginated(address,uint256) returns (address[],address)`. | Match the deployed Roles ABI; the integer argument changes the selector [s5]. |
| The 12 stand contracts had no explorer source verification. | Freeze the deployed compiler inputs, submit them and check 12 exact source matches. Keep separate status and submission commands. | Source publication needs the exact deployed sources, settings and constructor arguments [s3]. |
| Etherscan recognized the two claim tokens through `SimilarMatch`; the first submission tool skipped them. | Submit their own frozen constructor arguments and check `SimilarMatch` is empty. | Recognized source alone does not confirm an exact verification for that instance [s3]. |
| A completed source verification could leave its saved GUID marked as pending. | Update the saved result when the source check confirms an exact match. | Keep the local status consistent with Etherscan [s3]. |
| Editing `IRoles.sol` changes source metadata for later builds. | Keep the original eight source files in `cache/sepolia/deployed-source-snapshot.tar.gz`; retain the frozen explorer inputs. | Verify the existing deployment with its original inputs [s3][s5]. |
| The RPC connection failed after 100 saved apply receipts. A further transaction was mined without its hash reaching the saved run. | Match its sender, nonce, destination, value and input against the recorded plan. Check canonical receipts, back up the file and restore the missing hash and receipt. Continue with `resume-apply`. | Recovery confirmed 101 successful receipts, no Safe failure and 25 transactions remaining at that point. Restarting `apply` would reset permissions and budgets [s6]. |
| The legacy Roles viewer renders `WithinAllowance` as `Unsupported Condition` (operator `28`). | The imported policy in the Zodiac workspace decodes this condition and displays its allowance key. Check budget amounts through RPC and the fork drills. | The condition view does not show the remaining budget. Screenshots: `cache/sepolia/roles-ui-operator.png` and `cache/sepolia/zodiac-imported-operator.png` [s1][s7][s8]. |
| Address Book labels do not appear in the operator policy's `External members` field. | Check label support for this field with the UI provider. A fresh Actions view already shows the USDC, WETH and Orders recipient labels. | The saved Committee entry has the correct address and Sepolia chain. The cause of the raw member rendering is unconfirmed. Evidence: `cache/sepolia/zodiac-policy-address-labels.json` and `cache/sepolia/zodiac-policy-address-labels.png` [s14]. |
| Starting a Constellation deployment did not execute its transaction. | Check the deployment page and RPC before marking the step complete. The page still offers Deploy; all five governance differences remain at block `11956949`. | The package contains five zero-value `scopeFunction` calls. Their condition trees match the local policy after sorting AND/OR branches. The Asset Safe owner is the test Voting contract. A read-only simulation through its controller and `execute` path succeeds. Evidence: `cache/sepolia/constellation/pending-deployment-check.json` and `cache/sepolia/constellation/pending-owner-simulation.json` [s19]. |
| Importing all three Asset roles into the Zodiac workspace returned `Unexpected Server Error`. A separate `operator` import succeeded; `governance` still failed. | Import supported roles separately and check the saved list after each failure. Keep the governance import open. | A failed import does not prove that no records were saved. Screenshots: `cache/sepolia/zodiac-policy-import-error.png` and `cache/sepolia/zodiac-governance-import-error.png` [s8]. |
| Asset and Orders both use the keys `operator` and `emergency`. Zodiac permits one policy per key per chain in a workspace. | Import Orders `operator` as `orders-operator` and Asset `emergency` as `asset-emergency`, as drafts only under the stand owner's instruction. Add a migration warning to both descriptions. Do not apply them. | The next deployment would move the original role to the new key. Screenshots: `cache/sepolia/zodiac-orders-operator-draft.png` and `cache/sepolia/zodiac-asset-emergency-draft.png` [s8][s9]. |
| Manual workspace imports did not test the Constellation publication path. | Prepare a local Constellation with the existing addresses and original role keys. The stand owner later published a draft under an explicit exception for the review branch. | The saved draft contains three Safes, four modifiers and seven roles. Its governance condition encoding differs from the chain; publication does not apply that change [s12][s17]. |
| SDK 2.1.2 dropped callback-valued conditions when serializing raw Clutch permission entries to JSON. | Materialize each permission with `coercePermission`, capture the real SDK payload locally and recompile the serialized entries. | Recipient and budget conditions must survive serialization. SDK 2.10.0 settles these conditions itself; the regression checks their serialized recipient and allowance. The prepared payload preserves the policy's 63 configuration calls with observed allowance values [s12][s26]. |
| The hosted API refused the Constellation push with `400 The constellation is not valid`. It refused five governance scopes containing `Nor` opcode `3` in the `permissions` format. | Keep the original policy. The local Sepolia export describes governance through legacy `targets` and empty `annotations`; readback reconstructs its permissions before checking all configuration calls [s18][s21]. | Replacing `Nor` with `And` of `Or(LessThan, GreaterThan)` pairs passed the SDK check but introduced five on-chain differences [s15][s16]. That shared-policy draft is outside this change. |
| The permissions parser's refusal of `Nor` does not cover all API formats. | Test the documented legacy role representation with `targets` and `annotations: []`. The resolver returned `200` with the original `Nor` trees. | This result proves resolver acceptance of that representation. It does not prove publication or a zero transaction diff. Responses: `cache/sepolia/constellation/hosted-resolve.json` and `cache/sepolia/constellation/hosted-resolve-targets.json` [s18]. |
| The pinned SDK's generic `push` emits roles through `permissions` only. | Use the adapted local payload for provider review; confirm the publication workflow before publishing it. | Named SDK nodes still use the SDK's format. The local adapter does not change the hosted CLI or its owner guard [s18][s21]. |
| Cancelling the prepared deployment left both proposals in `Outstanding`. The Constellation signing page returned `Unexpected Server Error`; the separate five-call proposal selected an operator route and returned `TargetAddressNotAllowed`. | Check cancellation and proposal status separately. Review an owner-authorized route before signing any future governance update. | On 2026-10-22 the deployment showed `Deployment cancelled`, while both proposals remained after a reload. No Delete/Dismiss action was found in the inspected pages. Evidence: `cache/sepolia/pending-review-2026-10-22/` [s20]. |
| The SDK serializer did not add `key` to the allowance entries. The API refused `orders_weth` and `orders_usdc` with a key format error. | Add the record key to each allowance entry in `createNodes`. The compiler accepts a `key` that equals the allowance name. | The API schema requires `key` in each allowance entry [s15]. |
| The stand owner ran `.lib/scripts/push.ts` directly from a review branch. The owner guard did not run. | Use the owner workflow from the merged `main` for the next publication. | The guard refused `bun run push` on a review branch with local changes. ADR 004, decision 16, requires the owner workflow [s15]. |
| An unpublished local helper checked an exception flag without the owner guard. It accepted any resolve HTTP 200, lacked freshness checks, recorded attempts non-atomically and lost non-JSON responses. | Retire the helper before use. Review the publication route under the owner workflow, the resolved specification, API destination, current RPC state and saved hosted draft before any execution. | The helper made no hosted calls. Removing it does not establish a supported publication path for the legacy payload [s22]. |
| The tracked publisher returned success for HTTP 200 with an invalid body or a timeout while reading it. | Require a complete HTTP exchange and a JSON result with nonempty `id` and `url` strings. Retain the attempt record on failure. | An HTTP status alone does not confirm publication. Regression tests reproduce the original false success and now reject it [s23]. |
| A saved attempt blocked the same payload in another workspace or API. | Include the API URL, workspace and payload hash in the exclusive attempt key. | Repeated and concurrent requests to the same destination remain blocked. Another destination has its own attempt record [s23]. |
| Preparation deleted the previous snapshot before reading RPC. A network failure removed the saved diff; a fresh preparation also removed its payload and context. | Preserve existing files until new values are ready. Write each replacement to a temporary file and rename it. | Both CLI modes now retain the previous three files on an RPC failure. Preserve review evidence under block-specific filenames [s22]. |
| The SDK ABI declares `Initialized(uint8)`, but the deployed proxy emits `Initialized(uint64)`. | Add the captured `uint64` signature to the read-only decoder. | The original event decoder stopped on the real initialization log. This correction changes the decoder [s12]. |
| Fresh-apply allowance values use an initial balance and timestamp zero. | Preserve the stored balance and timestamp from the pinned RPC snapshot in the existing-account Constellation. | Publishing an existing-state declaration must not prepare a budget reset [s12]. |
| The workspace reports six policies against a limit of three, and three vaults against a limit of three [s13]. | Continue the current stand tests above the displayed quotas. Record an actual save or publication error for the provider to investigate. | On 2026-10-22, the stand owner relayed the provider's reply: quotas are not enforced immediately and tests may exceed them [s24]. Their connection to the earlier `governance` import failure is unproven. |
| `forge --help` printed an inherited explorer API key. | Run help with `env -u ETHERSCAN_API_KEY forge … --help`. | Keep the API key out of terminal output [s5]. |

The explorer package contains seven compiler inputs for 12 contracts, with eight source files.
It preserves the inputs from before the source fixes.
Keep it for this deployment.
For a future deployment, `explorer-prepare` creates a fresh package before source edits.
It refuses an existing package or a current build that differs from the recorded deployment input.
`explorer-check` checks the frozen package without network access.
`explorer-status` reads the explorer.
`SEPOLIA_PUBLISH_SOURCES=1 just --justfile sepolia.just explorer-submit` publishes the sources.
All 12 contracts now have exact source matches. Results: `cache/sepolia/etherscan-verification/status.json` [s3].

## Open items before production deployment

- [ ] Diagnose the `governance` import failure. The hosted push refused the same role's `Nor` scopes; check whether the import failure has the same cause. Confirm the saved policy matches the role's members, targets and conditions read from RPC [s8][s15].
- [ ] Reconcile workspace keys with the deployment configuration. The two draft aliases remain unapplied. Check the final diff for unintended role removal or migration [s8][s9].
- [x] Prepare and check the local existing-account Constellation. The RPC comparison found zero differences across four modifiers and seven roles at block `11956623` [s12].
- [x] Confirm that the stand owner's published Constellation is visible in the workspace. The draft contains all seven roles on the existing accounts [s17].
- [x] Review publication of the existing-state payload with original `Nor` conditions. The new workspace shows `Deployed` and `Nothing to deploy`; the saved resolution matches the payload, and the RPC comparison found zero differences at block `11970750` [s25].
- [ ] Show allowance amounts and remaining budgets in the operational UI. Compare them with RPC values at the same block. The imported condition view currently shows the allowance key [s7][s8].
- [ ] Rehearse configuration and interrupted-run recovery on the target network. Include a transaction mined before its receipt reaches the saved run. Confirm canonical receipts and final state before funding [s5][s6].
- [ ] Repeat dependency-code and execution-rule checks for the target network. Preserve the exact compiler inputs and verify every deployed instance [s1][s3][s5].
- [ ] Check ADR verification before production. Earlier body edits caused ten verification errors; any future body edit needs renewed human verification [s11].

## Stand differences to resolve

| Stand configuration | Check for the production deployment |
|---|---|
| One controller owns both 1/1 Committee and Emergency Safes. | Use the accepted production owners and thresholds. Test each signer's execution path; this stand does not prove signer independence [s10]. |
| Voting, Agent, Easy Track and its executor are test contracts controlled by the sender. | Bind the production contracts and test the ownership, governance and motion paths on a mainnet fork [s1][s10]. |
| First-loss uses test shares and queues with synthetic 1:1 settlement. | Test the real shares and redemption paths, including prices, liquidity and oracle reports. The synthetic drills cover permissions [s1][s10]. |
| Budgets, motion timing and objection settings use test fixtures. | Use the accepted production configuration and repeat the allowed and denied action tests [s10]. |

## Checks still required

- Check all 126 application receipts against RPC before funding. The saved run contains 126 successful receipts, and the current policy comparison passes [s12].
- Fund the public stand and check its balances. The completed fork rehearsal does not cover these public transactions [s1][s2].
- Submit CoW orders and record settlements. The quote probe and fork signatures do not prove solver acceptance or settlement [s1].

Policy application uses 126 transactions for 63 configuration calls.
The current scripts keep that sequence; no batching change forms part of these fixes [s1].
The First-loss queues use synthetic 1:1 settlement, so their drills cover the permission path [s1].
