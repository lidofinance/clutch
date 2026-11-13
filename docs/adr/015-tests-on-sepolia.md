---
type: Decision
title: "ADR 015: Tests on Sepolia"
description: Sepolia test permissions and the proposed role-key migration, with the same key scheme planned for mainnet.
tags: [sepolia, testing, zodiac, deployment, process]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/sonnet-5.5
  at: 2026-11-12T12:27:25Z
verified: []
sources:
  - id: s1
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the Zodiac workspace, local verification of hosted transactions and the owner workflow, decisions 10, 11 and 16
  - id: s2
    resource: "https://github.com/lidofinance/clutch/blob/60bdcd8107f3c2caa3f23da208bcb93d2443e3d1/policy/constellation/compiler/owner-guard.ts#L10-L19"
    title: Owner guard at 60bdcd8 — refusal without confirmation, in CI, outside main and with local changes
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/60bdcd8107f3c2caa3f23da208bcb93d2443e3d1/AGENTS.md#L40-L41"
    title: AGENTS.md at 60bdcd8 — agents never use the Zodiac API key and never deploy
  - id: s4
    resource: /specs/sepolia-stand-plan.md
    title: Sepolia stand plan — accounts, the single controller, the drills, the earlier workspace and the open checks
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/5d3633858a00b309cf8087fcd40a93a94068cb18/sepolia.just#L16-L20"
    title: sepolia.just at 5d36338 — the guard of public Sepolia transactions
  - id: s6
    resource: urn:clutch:evidence:2026-10-20:sepolia-published-constellation
    title: Published Clutch Sepolia draft — three existing Safes, four Roles modifiers and seven roles, under an explicit exception for a review branch
  - id: s7
    resource: urn:clutch:evidence:2026-10-20:sepolia-legacy-targets-resolve
    title: Hosted resolve — permissions with Nor returns 400; legacy targets with empty annotations returns 200
  - id: s8
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/index.mjs"
    title: Zodiac SDK 2.1.2 — push sends each role as permissions
  - id: s9
    resource: urn:clutch:evidence:2026-10-22:sepolia-publication-review
    title: Local review — retired publication helper, preserved snapshots and zero RPC policy differences at block 11969893
  - id: s10
    resource: urn:clutch:evidence:2026-10-22:sepolia-pending-review
    title: Zodiac readback — cancelled deployment and two proposals remaining in Outstanding
  - id: s11
    resource: urn:clutch:evidence:2026-10-20:zodiac-workspace-plan-limits
    title: Workspace usage screenshot — six policies against a limit of three; three vaults against a limit of three
  - id: s12
    resource: urn:clutch:evidence:2026-10-22:sepolia-new-workspace
    title: New Sepolia workspace — the constellation list is empty before publication
  - id: s13
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/api-C49DoaPC.mjs"
    title: Zodiac SDK 2.1.2 API client — accounts, users, constellation resolve and apply, and the ZODIAC_API_URL override
  - id: s14
    resource: urn:clutch:evidence:2026-10-20:zodiac-address-book
    title: Address Book — 36 saved names, addresses and Sepolia chain assignments checked against the local manifest and dependencies
  - id: s15
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — EM accepts ADRs in the interim; an accepted ADR authorises nothing on chain
  - id: s16
    resource: /registers/decision-log.md
    title: Decision log — YT registration and EM's decisions on the Sepolia migration, OD-149, OD-150 and OD-152
  - id: s17
    resource: "https://github.com/lidofinance/clutch/pull/44"
    title: Pull request #44 — the Sepolia stand and deployment workflow, open
  - id: s18
    resource: urn:clutch:evidence:2026-10-22:sepolia-resolution-check
    title: Local check — the resolution saved on 2026-10-20 against the current payload; the same 63 calls with the roles in another order; Safe owners and modules match
  - id: s19
    resource: urn:clutch:evidence:2026-10-22:sepolia-publisher-regressions
    title: Publisher regression tests — invalid success responses, body-read timeouts and separate attempts for each API URL and workspace
  - id: s20
    resource: urn:clutch:evidence:2026-10-22:zodiac-quota-reply
    title: Reply relayed by the stand owner — quotas are not enforced immediately and tests may exceed the displayed limits
  - id: s21
    resource: urn:clutch:evidence:2026-10-22:sepolia-constellation-deployed
    title: Owner publication from dacf262, Deployed and Nothing to deploy in Zodiac, original Nor conditions and zero RPC differences at block 11970750
  - id: s22
    resource: /research/sepolia-constellation-ui-2026-10-22.md
    title: Workspace registration review — SDK upgrade, metadata flags and conflicts under the original keys
  - id: s23
    resource: "https://docs.zodiac.eco/developers/roles/role-keys"
    title: Zodiac role keys — policy identity, migration to another key and execution clients
  - id: s24
    resource: /specs/invariants.md
    title: Invariants — governance scope, emergency stop and the literal operator and emergency keys
  - id: s25
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — fixed role keys in governance, emergency revocation and exit templates
  - id: s26
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account ownership, emergency powers and restart by the DAO
  - id: s27
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — Orders operator and recovery permissions, without an Orders governance role
  - id: s28
    resource: "https://github.com/lidofinance/clutch/blob/dacf2625ba23865e190f6c9013f6b375c3c787b8/policy/constellation/compiler/compile.ts#L165-L172"
    title: Compiler — STOP_ONLY identifies the emergency role by its literal key
  - id: s29
    resource: /research/sepolia-role-key-migration-2026-10-22.md
    title: Prepared migration — explicit deletions, two Safe batches and verified fork state
  - id: s30
    resource: urn:clutch:evidence:2026-10-23:sepolia-role-key-migration
    title: Owner publication HTTP 200; two canonical successful migration receipts; zero policy differences, unchanged allowances and Safe configuration at block 11976825
  - id: s31
    resource: urn:clutch:evidence:2026-10-23:sepolia-workspace-registration
    title: Three old vault records removed after four saved policy bindings were detached; new Constellation Deployed with Nothing to deploy, three Vaults and seven Policies
---

# ADR 015: Tests on Sepolia

## Context

- ADR 004 sets the Zodiac rules for the production policy. The repository-owner team owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main` (decision 16). No transaction that the hosted app builds is signed unless Clutch's compiler produces the same calls from the same commit (decision 11) [s1].
- The owner guard enforces decision 16. It refuses a hosted call without `CLUTCH_OWNER_PUSH=1`, in CI, outside `main` and with local changes [s2].
- Agents never use the Zodiac API key and never deploy [s3].
- A Sepolia test stand exists on the `testnet/sepolia` branch. Pull request #44 carries it and is not merged [s17].
- The stand has three vault Safes, four Roles modifiers and seven roles. One controller owns the 1/1 Committee and Emergency Safes and controls the test governance contracts. The stand plan lists the funding, the CoW and First-loss drills and the stop of the run as open steps [s4].
- `sepolia.just` keeps public Sepolia transactions for a human. Its guard requires `CLUTCH_SEPOLIA=1` and refuses CI and a raw private key. Foundry asks for the keystore password [s5].
- On 2026-10-20, the stand owner published a draft to an earlier workspace under an explicit exception for a review branch [s6]. The owner guard did not run [s4].
- The hosted API refused the five governance `Nor` conditions in the SDK's `permissions` format with HTTP 400. In the earlier workspace, the resolver accepted the same roles in the legacy `targets` format with HTTP 200 [s7].
- The SDK's `push` sends each role as `permissions` [s8]. The repository has no supported route for the legacy payload. A local publication helper was retired on 2026-10-22, before any hosted call [s9].
- The stand owner started a deployment in the earlier workspace and cancelled it. Its two proposals stayed in `Outstanding` [s4][s10].
- The earlier workspace showed six policies against a limit of three, and three vaults against a limit of three [s11].
- On 2026-10-22, the stand owner relayed a reply from the provider. It says the limits are not enforced immediately and tests may exceed them [s20].
- On 2026-10-22, a new workspace for the stand listed no constellations [s12]. The prepared payload binds the existing accounts. At block 11969893, the RPC comparison found zero policy differences [s9].
- The SDK's API client has endpoints for accounts, users, and constellation resolve and apply. It has no address-book endpoint [s13]. The stand's 36 address-book entries were made in the Zodiac app and checked on 2026-10-20 [s14].
- EM accepts an ADR in the interim, and the committee permanently. An accepted ADR authorises nothing on chain (ADR 002, decision 7) [s15].
- YT is a decision proposer and page verifier. ADR acceptance stays with EM and the committee [s16].
- Zodiac identifies a policy by its key within a workspace and chain. The Asset and Orders grants differ under both shared keys, `operator` and `emergency`; changing their display labels does not separate the policies [s22][s23].
- Roles has no rename operation. Moving to another key creates a role under that key and removes the old role. Execution clients must then use the new key [s23].
- The current design pins `operator` in governance and emergency revocation. INV-018 requires that literal key, and INV-025 pins exit governance to `emergency`. The compiler also identifies the Asset emergency role by its key [s24][s25][s28].

## Decision

EM decided on 2026-10-22, closing OD-149, OD-150 and OD-152 [s16]:

1. Use four account-specific role keys for Sepolia and mainnet: `asset-operator`, `orders-operator`, `asset-emergency` and `orders-emergency`. Migrate only the existing Sepolia stand after package review and fork tests. Complete the mainnet design updates before its initial deployment (OD-152 B).
2. The stand owner executes a locally compiled package through test Voting under the review conditions below. The owner must authorise the exact calls before signing (OD-149 C).
3. The stand owner may send public transactions on the existing Sepolia stand through `sepolia.just` and its guards, with the keystore. A second stand needs a new decision (OD-150 A).

OD-147, OD-148 and OD-151 remain open. These choices do not record acceptance or verification of the whole ADR [s16].

## Proposed direction

The implementation conditions below are drafted for review. The three decisions above are recorded; OD-147, OD-148 and OD-151 remain proposals.

The rows below describe permissions for the Sepolia workspace and chain 11155111. OD-149, OD-150 and OD-152 are decided; the other rows wait for EM's decision. The role-key decision also defines work for the mainnet design. It authorises no mainnet transaction, and ADR 004's production publication rules stay in force [s1][s15].

| Permission | Who acts | Conditions | Decision |
|---|---|---|---|
| Work from `testnet/sepolia` instead of the merged `main`: hosted calls to the Sepolia workspace and public Sepolia transactions | The stand owner | The commit is on GitHub. The working tree has no local changes. | OD-147 |
| Hold an API key for the Sepolia workspace in a git-ignored `.env` | The stand owner | Nobody commits the key. No agent and no CI job uses it. If the provider can limit a key to one workspace, the key reaches only the Sepolia workspace. | OD-147 |
| Run hosted calls through a Sepolia guard, separate from the owner guard | The stand owner | The guard requires `CLUTCH_SEPOLIA_PUSH=1` and the branch `testnet/sepolia`. It refuses CI, local changes, and a workspace that differs from the prepared context. The owner guard stays as it is. | OD-147 |
| Publish the existing-state declaration to the Sepolia workspace as a draft | The stand owner | A committed script checks the payload hash and a fresh RPC comparison. It calls resolve and compares the resolved specification with the payload: accounts, owners, members and `Nor` conditions. It calls apply once for each API URL, workspace and payload hash, records the attempt exclusively and saves each status and body. Success requires a complete HTTP exchange and a JSON result with nonempty `id` and `url` strings. It uses the same API address as the SDK. | OD-148 |
| Execute the locally compiled migration package | The stand owner | Review the exact calls and execute them through test Voting. This route does not authorise a package built by Zodiac. | OD-149 C |
| Send public Sepolia transactions on the existing stand: funding, the CoW and First-loss drills, recovery and the stop of the run | The stand owner, with the keystore | Only through the `sepolia.just` recipes and their guards. A second stand needs a new decision. | OD-150 A |
| Import the three existing Safes as vaults and enter the address-book entries in the Sepolia workspace | The stand owner | No role or permission is edited in the Zodiac app. The entries come from the checked address list. | OD-151 |
| Remove the earlier workspace's draft aliases and cancelled proposals | The stand owner | Only where the app permits it. Nothing is executed. | OD-151 |
| Migrate the four role keys on the existing Sepolia stand | The stand owner, through test Voting | OD-152 B and OD-149 C permit the migration. A reviewed package passes the checks below. The owner authorises its exact calls before signing. No new Safe or modifier is deployed. | OD-152 B; OD-149 C |
| Prepare payloads, run read-only RPC comparisons, and write code, tests and documents | Agents | No change: agents never use the key, call the hosted app, sign or send [s3]. | None |

### Role keys for Sepolia and mainnet

OD-152 B sets the following keys for both networks. The migration package targets only the existing Sepolia addresses [s4]. Mainnet must use the new keys in its initial policy after the design and implementation updates below are accepted and verified.

| Safe | Roles modifier | Current key | Proposed key |
|---|---|---|---|
| Asset | Operator | `operator` | `asset-operator` |
| Orders | Orders | `operator` | `orders-operator` |
| Asset | Safety | `emergency` | `asset-emergency` |
| Orders | Orders | `emergency` | `orders-emergency` |

The keys `governance`, `first-loss` and `first-loss-burn` stay as they are. Each renamed role keeps its members, targets, selectors, conditions and execution options, except for references to the migrated keys. The Asset governance role writes only `asset-operator`. Asset and Orders emergency revokes target `asset-operator` and `orders-operator` on their respective modifiers. Orders gains no governance role [s25][s27].

### Sepolia migration conditions

1. Read the existing state at a pinned block. Record the old roles, members, default roles, allowances and Safe/module configuration. Compile the complete desired state and a separate migration package. The package must remove the old roles as well as create the new ones; setup calls alone do not prove removal.
2. Use the owner path through test Voting. Prefer one atomic batch. If the route needs several transactions, review each intermediate state before execution. A new operator role must have a working emergency revoke before a member can use it. The sequence must preserve the Asset switch and Orders emergency recovery.
3. Preserve action permissions and allowance keys, including `orders_weth` and `orders_usdc`. Do not reset allowance balances, refill settings or stored timestamps. Change no owner, threshold, module wiring, asset address or role holder. Update key references in governance, revokes and any configured default role.
4. Remove memberships and executable target grants under the old keys on all four affected role instances. Update execution scripts and monitoring to the new keys. A stored function tree under a revoked target does not by itself mean that the old role can execute it.
5. Compare the reviewed package with any calls that Zodiac builds. Keep the original `Nor` conditions. Stop if the live state differs from the reviewed snapshot. After execution, save receipts and compare the chain with the new declaration.
6. If a migration fails, inspect its receipts and current state before preparing recovery. Recovery must not restore a permission revoked after the snapshot. A new package needs review and human authorisation [s15][s26].

The prepared implementation uses two atomic account batches through the existing MultiSendCallOnly 1.5.0, with its runtime pinned. Asset migrates first, Orders second. Each batch configures the new roles, enables the same holders, removes old memberships and clears old function slots and targets. Asset also updates governance. Between batches, each account keeps its operator and emergency control under its active key scheme. The publisher declares the old keys as `null` and omits allowances [s29].

### Mainnet design dependencies

OD-152 B requires these updates before mainnet deployment. The present rules remain in force until their amendments and implementation are complete [s24][s25].

| Area | Required update |
|---|---|
| ADR 005, ADR 006 and ADR 007 | Record the four keys and replace literal-key requirements. Preserve account ownership, separate emergency powers, DAO restart and the absence of Orders governance [s25][s26][s27]. |
| Governance, factories and exit templates | Pin grants and removals to `asset-operator`; pin exit governance to `asset-emergency`. Keep membership setters, delegatecall expansion and administrative targets outside governance [s25]. |
| Invariants | Replace INV-018's single-key rule with the account-to-key mapping. Update INV-025 and INV-027's key references. Preserve INV-004's governance restrictions and INV-009's emergency stop; map the revised rules to named tests [s24]. |
| Compiler and policy | Recognise the new emergency key in stop-only checks, including `STOP_ONLY`. Test that renaming cannot bypass those checks. Update manifests, declarations and generated artifacts together [s28]. |
| Execution and operations | Update role arguments, any default roles, factory bindings, monitoring, runbooks and UI labels. Rehearse the initial mainnet policy and enabling-vote path with the new keys on a mainnet fork [s24][s26]. |

Sepolia fixtures and a single controller do not prove the mainnet governance, signer or asset configuration [s4]. Any mainnet role already deployed before these updates would need a separate migration review and governance package.

## Options considered

- **Keep ADR 004 decision 16 for Sepolia.** Pull request #44 merges first, and the owner team pushes from `main`. Each change to the Sepolia tooling then waits for a merge before a test.
- **A one-time exception for each publication, recorded in the decision log.** This repeats the route of 2026-10-20, where no guard ran [s4].
- **A standing exception for any branch.** Reviewers then cannot see the code that ran.
- **The SDK's `push` alone.** The API refuses the governance `Nor` conditions in that format [s7].
- **Replace `Nor` with `And` and `Or` conditions in the policy.** The stand plan records five on-chain differences for that change [s4].
- **Agents publish.** AGENTS.md forbids it [s3].
- **Keep the shared keys.** Not chosen in OD-152. The current policy model blocks the two pairs of different grants from appearing as separate policies [s22][s23].
- **Use four account-specific keys on both networks.** Chosen in OD-152 B. Migrate the existing Sepolia roles and update the mainnet design before its initial deployment.
- **Change Sepolia alone.** Not chosen in OD-152. This separates the test and production key schemes and leaves the mainnet policy conflict unresolved.

## Consequences

- The production rule of ADR 004 does not change. A second guard exists for Sepolia, and both guards need tests.
- Hosted acceptance in the Sepolia workspace is evidence for Sepolia only. It does not show that the production workspace accepts the production policy.
- Code runs from a branch that is not merged. Reviewers see it in pull request #44, but nobody has approved it [s17].
- A key that reaches every workspace of the account also reaches the production workspace. The key condition of OD-147 decides this risk.
- The stand keeps one controller. It does not test signer independence [s4].
- The provider permits tests above the displayed quotas. Record an actual save or publication error for the provider to investigate [s20].
- A role-key migration changes on-chain role identity and execution arguments. It needs permission migration and tests even when the permitted actions stay the same [s23].

## Confirmation

- `policy/constellation/sepolia/publish-constellation.test.ts` covers the Sepolia guard. The guard refuses a run without `CLUTCH_SEPOLIA_PUSH=1`, in CI, on another branch, with local changes, with an unpushed commit, without the key, with another workspace and with an API address that does not use https.
- The same file covers the publication script with a mock `fetch`. The script stops for a stale payload, another manifest, and a resolution that differs in a condition, a member, an allowance, an account, a Safe owner or the annotations. It accepts a resolution that lists the roles in another order. It saves an HTTP error, a body that is not JSON and a timeout.
- An HTTP 200 with an incomplete or invalid result fails. A timeout while reading its body also fails. Each failure retains the attempt record and blocks a retry to the same API URL and workspace. The same payload can be published to another API URL or workspace. Concurrent runs for the same API URL, workspace and payload send one apply [s19].
- The resolution that the hosted app returned on 2026-10-20, in the earlier workspace, passes the comparison for the current payload. A rewrite of one `Nor` in that resolution fails it [s18].
- The local SDK is now 2.10.0, with API types 1.13.0. All three Safes carry `vault: true`; all seven roles carry policy labels. The publication CLI refuses the different grants under the shared `operator` and `emergency` keys before a hosted request. The payload keeps all original keys and the same configuration calls. This metadata update has not been published [s22].
- On 2026-10-22, the stand owner ran the publisher from commit `dacf262`. The saved resolve and apply responses have HTTP status `200`; the resolved specification matches the payload. Zodiac shows the three existing Safes, four modifiers and seven roles as `Deployed`, with `Nothing to deploy`. The governance view retains the original `Nor` trees, although it labels them `Unsupported Condition`. The RPC comparison found zero policy differences at block `11970750`. The stand plan records the command and evidence [s21].

EM chose the migration in OD-152 B. The prepared package passed nine tests on the existing stand's pinned fork, including the state between batches. Two local Anvil transactions left zero RPC differences, with unchanged allowance storage and Safe configuration. The source snapshot is block `11971984` [s29]. The stand owner then executed both batches at blocks `11976805` and `11976806`. The comparison at block `11976825` found zero policy differences [s30]. The workspace shows three Vaults and seven Policies [s31]. Its acceptance checks are:

- Fork tests execute allowed calls under each new key and refuse calls under each old key. They cover governance key pins, Asset switch, Orders revoke/recovery and the intermediate states of any split batch. They also refuse added members, extra grants, non-zero emergency approvals and emergency restoration.
- State comparisons preserve the allowance storage, members, Safe/module configuration and conditions specified above. The reviewed package contains no deployment or allowance-reset calls. Any Zodiac execution package must contain the same calls.
- After authorised execution, receipts succeed and a fresh RPC comparison finds zero differences against the migrated declaration. Tests update INV-018, INV-025 and INV-027 without weakening INV-004 or INV-009 [s24].
- After a separately authorised Constellation publication, reloading the workspace shows three Vaults and all seven intended Policies with the new keys. Resolve alone cannot prove that the app saved this metadata [s22].

## Reversal conditions

- The Sepolia key or the Sepolia guard reaches the production workspace.
- A hosted call runs from a commit that is not on GitHub.
- The hosted app changes a condition or an account in a saved draft.
- The provider enforces a quota that blocks a save or publication [s20].
- A new role bypasses a compiler restriction, or governance or emergency powers differ from the reviewed mapping.
- An old key still executes, a transition loses emergency control, or the migration resets allowance state.
- The hosted app still refuses the separate policies under the four new keys.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-147](/registers/open-decisions.md): May the stand owner make hosted calls to the Sepolia workspace and send public Sepolia transactions from `testnet/sepolia`? A: no; ADR 004 decision 16 stays, so pull request #44 merges first and the owner team pushes from `main`. B: yes, from a commit that is on GitHub with no local changes, through a Sepolia guard separate from the owner guard, with an API key for the Sepolia workspace in a git-ignored `.env`. C: a one-time exception for each publication, recorded in the decision log.
- [OD-148](/registers/open-decisions.md): How does the existing-state payload reach the Sepolia workspace? A: the SDK's `push`. B: a committed script behind the Sepolia guard: it checks the payload hash and a fresh RPC comparison, calls resolve, compares the resolved specification with the payload, calls apply once and saves each status and body. C: a manual API call.
- [OD-151](/registers/open-decisions.md): Which records may the stand owner make by hand in the Zodiac app? A: none. B: vault imports of the three existing Safes, the checked address-book entries, and removal of the earlier workspace's draft aliases and cancelled proposals; no role or permission edits in the app. C: any record, policy drafts included.

<!-- end of generated block -->
