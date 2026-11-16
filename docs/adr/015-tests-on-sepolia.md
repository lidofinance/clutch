---
type: Decision
title: "ADR 015: Tests on Sepolia"
description: Sepolia test permissions and the role-key migration, with the same key scheme planned for mainnet.
tags: [sepolia, testing, zodiac, deployment, process]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-16T20:11:16Z
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
    resource: /specs/sepolia-stand.md
    title: Sepolia stand — accounts, 14 roles, the single controller, recipes and open items
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/5d3633858a00b309cf8087fcd40a93a94068cb18/sepolia.just#L16-L20"
    title: sepolia.just at 5d36338 — the guard of public Sepolia transactions
  - id: s6
    resource: urn:clutch:evidence:2026-10-20:sepolia-published-constellation
    title: Published Clutch Sepolia draft — three existing Safes and four Roles modifiers, under an explicit exception for a review branch
  - id: s7
    resource: urn:clutch:evidence:2026-10-20:sepolia-legacy-targets-resolve
    title: Hosted resolve — permissions with Nor returns 400; legacy targets with empty annotations returns 200
  - id: s8
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/index.mjs"
    title: Zodiac SDK 2.1.2 — push sends each role as permissions
  - id: s9
    resource: urn:clutch:evidence:2026-10-20:sepolia-constellation-deployment-started
    title: Started Constellation deployment — five governance condition rewrites and five RPC differences at block 11956949
  - id: s10
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/api-C49DoaPC.mjs"
    title: Zodiac SDK 2.1.2 API client — accounts, users, constellation resolve and apply, and the ZODIAC_API_URL override
  - id: s11
    resource: urn:clutch:evidence:2026-10-20:zodiac-address-book
    title: Address Book — 36 saved names, addresses and Sepolia chain assignments checked against the local manifest and dependencies
  - id: s12
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — EM accepts ADRs in the interim; an accepted ADR authorises nothing on chain
  - id: s13
    resource: /registers/decision-log.md
    title: Decision log — YT registration, EM's decisions on OD-147 to OD-153, and the stand owner's choices
  - id: s14
    resource: "https://github.com/lidofinance/clutch/pull/44"
    title: Pull request #44 — the Sepolia stand and deployment workflow, open
  - id: s15
    resource: urn:clutch:evidence:2026-10-22:sepolia-resolution-check
    title: Local check — the resolution saved on 2026-10-20 against the payload; the same calls with the roles in another order; Safe owners and modules match
  - id: s16
    resource: urn:clutch:evidence:2026-10-22:sepolia-publisher-regressions
    title: Publisher regression tests — invalid success responses, body-read timeouts and separate attempts for each API URL and workspace
  - id: s17
    resource: "https://docs.zodiac.eco/developers/roles/role-keys"
    title: Zodiac role keys — policy identity, migration to another key and execution clients
  - id: s18
    resource: /specs/invariants.md
    title: Invariants — governance scope, emergency stop and the literal operator and emergency keys
  - id: s19
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — fixed role keys in governance, emergency revocation and exit templates
  - id: s20
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account ownership, emergency powers and restart by the DAO
  - id: s21
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — Orders operator and recovery permissions
  - id: s22
    resource: "https://github.com/lidofinance/clutch/blob/dacf2625ba23865e190f6c9013f6b375c3c787b8/policy/constellation/compiler/compile.ts#L165-L172"
    title: Compiler — STOP_ONLY identifies the emergency role by its literal key
  - id: s23
    resource: urn:clutch:evidence:2026-10-22:sepolia-role-key-migration-package
    title: Prepared migration — explicit deletions, two Safe batches and nine fork tests at block 11971984
  - id: s24
    resource: urn:clutch:evidence:2026-10-23:sepolia-role-key-migration
    title: Two canonical successful migration receipts; zero policy differences, unchanged allowances and Safe configuration at block 11976825
  - id: s25
    resource: /research/sepolia-test-results.md
    title: Sepolia test results — the publication of the 14 roles on 2026-11-16 and the public transactions
  - id: s26
    resource: urn:clutch:source:compiler-role-key-scheme
    title: policy/constellation/compiler/compile.ts — the `roleKeyScheme` branch of the stop-only check, the zeroing rule and the keys that a motion may write
---

# ADR 015: Tests on Sepolia

## Context

- ADR 004 sets the Zodiac rules for the production policy. The repository-owner team owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main` (decision 16). Nobody signs a transaction that the hosted app builds unless Clutch's compiler produces the same calls from the same commit (decision 11) [s1].
- The owner guard enforces decision 16. It refuses a hosted call without `CLUTCH_OWNER_PUSH=1`, in CI, outside `main` and with local changes [s2].
- Agents never use the Zodiac API key and never deploy [s3].
- A Sepolia test stand exists on the `testnet/sepolia` branch. Pull request #44 carries it and is not merged [s14].
- The stand has three vault Safes, four Roles modifiers and 14 roles. The universal factory holds the nine motion roles. The orders modifier's governance role has the key `orders-governance`; the decision log records why [s4][s13]. One controller owns the 1/1 Committee and Emergency Safes and controls the test governance contracts [s4].
- `sepolia.just` keeps public Sepolia transactions for a human. Its guard requires `CLUTCH_SEPOLIA=1` and refuses CI and a raw private key. Foundry asks for the keystore password [s5].
- The hosted API refuses the governance `Nor` conditions in the SDK's `permissions` format with HTTP 400. It accepts the same roles in the legacy `targets` format [s7].
- The SDK's `push` sends each role as `permissions` [s8]. The repository has no other supported route for the legacy payload.
- The SDK's API client has endpoints for accounts, users, and constellation resolve and apply. It has no address-book endpoint [s10]. The stand's 36 address-book entries were made in the Zodiac app [s11].
- EM accepts an ADR in the interim, and the Treasury Management Committee permanently. An accepted ADR authorises nothing on chain (ADR 002, decision 7) [s12].
- YT is a decision proposer and page verifier. ADR acceptance stays with EM and the committee [s13].
- Zodiac identifies a policy by its key within a workspace and chain. The Asset and Orders grants differed under the shared keys `operator` and `emergency`. A change of display label does not separate the policies [s17].
- Roles has no rename operation. A move to another key creates a role under that key and removes the old role. Execution clients must then use the new key [s17].
- The current design pins `operator` in governance and emergency revocation. INV-018 requires that literal key, and INV-025 pins exit governance to `emergency`. The compiler also identifies the Asset emergency role by its key [s18][s19][s22].

## Decision

EM decided on 2026-10-22, closing OD-149, OD-150 and OD-152 [s13]:

1. Use four account-specific role keys for Sepolia and mainnet: `asset-operator`, `orders-operator`, `asset-emergency` and `orders-emergency`. Migrate only the existing Sepolia stand after package review and fork tests. Complete the mainnet design updates before the initial mainnet deployment (OD-152 B).
2. The stand owner executes a locally compiled package through test Voting under the review conditions below. The stand owner must authorise the exact calls before signing (OD-149 C).
3. The stand owner may send public transactions on the existing Sepolia stand through `sepolia.just` and its guards, with the keystore. A second stand needs a new decision (OD-150 A).

EM decided on 2026-11-16, closing OD-147, OD-148, OD-151 and OD-153, and confirmed decision 1 for both networks [s13]:

4. The stand owner may make hosted calls to the Sepolia workspace and send public Sepolia transactions from `testnet/sepolia`, and from `main` once the stand is merged: from a commit that is on GitHub on the same branch, with no local changes, through a Sepolia guard that is separate from the owner guard, with an API key for the Sepolia workspace in a git-ignored `.env` (OD-147 B).
5. The existing-state payload reaches the Sepolia workspace through a committed script behind the Sepolia guard. The script checks the payload hash and a fresh RPC comparison, calls resolve, compares the resolved specification with the payload, calls apply once and saves each status and body (OD-148 B).
6. The stand owner may make these records by hand in the Zodiac app: the vault imports of the three existing Safes, the checked address-book entries, and the removal of the earlier workspace's draft aliases and cancelled proposals. The stand owner edits no role and no permission in the app (OD-151 B).
7. On mainnet the orders modifier's governance role takes the key `orders-governance`, as on the stand, in the same change that brings the four keys of decision 1 (OD-153 A).

These choices do not record acceptance or verification of the whole ADR [s13].

## Proposed direction

This section holds the conditions of each permission. Every row follows a decision above.

The rows below describe permissions for the Sepolia workspace and chain 11155111. The role-key decision also defines work for the mainnet design. It authorises no mainnet transaction. ADR 004's production publication rules stay in force [s1][s12].

| Permission | Who acts | Conditions | Decision |
|---|---|---|---|
| Work from `testnet/sepolia`, or from the merged `main`: hosted calls to the Sepolia workspace and public Sepolia transactions | The stand owner | The commit is on GitHub, on the branch that is checked out. The working tree has no local changes. | OD-147 B |
| Hold an API key for the Sepolia workspace in a git-ignored `.env` | The stand owner | Nobody commits the key. No agent and no CI job uses it. If the provider can limit a key to one workspace, the key reaches only the Sepolia workspace. | OD-147 B |
| Run hosted calls through a Sepolia guard, separate from the owner guard | The stand owner | The guard requires `CLUTCH_SEPOLIA_PUSH=1` and the branch `testnet/sepolia` or `main`. It refuses CI, local changes, and a workspace that differs from the prepared context. The owner guard stays as it is. | OD-147 B |
| Publish the existing-state declaration to the Sepolia workspace as a draft | The stand owner | A committed script checks the payload hash and a fresh RPC comparison. It calls resolve and compares the resolved specification with the payload: accounts, owners, members and `Nor` conditions. It calls apply once for each API URL, workspace and payload hash, records the attempt exclusively and saves each status and body. Success requires a complete HTTP exchange and a JSON result with nonempty `id` and `url` strings. It uses the same API address as the SDK. | OD-148 B |
| Execute the locally compiled migration package | The stand owner | The stand owner reviews the exact calls and executes them through test Voting. This route does not authorise a package built by Zodiac. | OD-149 C |
| Send public Sepolia transactions on the existing stand: funding, the CoW and First-loss drills, motions, recovery and the stop of the run | The stand owner, with the keystore | Only through the `sepolia.just` recipes and their guards. A second stand needs a new decision. | OD-150 A |
| Import the three existing Safes as vaults and enter the address-book entries in the Sepolia workspace | The stand owner | The stand owner edits no role or permission in the Zodiac app. The entries come from the checked address list. | OD-151 B |
| Remove the earlier workspace's draft aliases and cancelled proposals | The stand owner | Only where the app permits it. The stand owner executes nothing. | OD-151 B |
| Migrate the four role keys on the existing Sepolia stand | The stand owner, through test Voting | OD-152 B and OD-149 C permit the migration. A reviewed package passes the checks below. The stand owner authorises its exact calls before signing. The package deploys no new Safe or modifier. | OD-152 B; OD-149 C |
| Prepare payloads, run read-only RPC comparisons, and write code, tests and documents | Agents | No change: agents never use the key, call the hosted app, sign or send [s3]. | None |

### Role keys for Sepolia and mainnet

OD-152 B sets the following keys for both networks. The migration package targets only the existing Sepolia addresses [s4]. Mainnet must use the new keys in its initial policy after the design and implementation updates below are accepted and verified.

| Safe | Roles modifier | Old key | New key |
|---|---|---|---|
| Asset | Operator | `operator` | `asset-operator` |
| Orders | Orders | `operator` | `orders-operator` |
| Asset | Safety | `emergency` | `asset-emergency` |
| Orders | Orders | `emergency` | `orders-emergency` |
| Orders | Orders | `governance` | `orders-governance` (OD-153 A) |

The other keys stay as they are. Each renamed role keeps its members, targets, selectors, conditions and execution options, except for references to the migrated keys. The Asset governance role writes only `asset-operator`. The Asset emergency revoke targets `asset-operator`, and the Orders emergency revoke targets `orders-operator` [s19][s21]. The stand's orders modifier has had the key `orders-governance` for its governance role since 2026-11-16. The `main` branch keeps `governance` on both modifiers until the mainnet change [s13].

### Sepolia migration

The stand moved to the four account keys on 2026-10-23, through two test-Voting transactions. The chain matched the artifact after the move, and allowances and Safe configuration did not change. The old keys keep no member and only revoked targets [s23][s24][s25].

### Mainnet design dependencies

OD-152 B requires these updates before mainnet deployment. The current rules stay in force until their amendments and implementation are complete [s18][s19].

| Area | Required update |
|---|---|
| ADR 005, ADR 006 and ADR 007 | Record the four keys and replace literal-key requirements. Preserve account ownership, separate emergency powers and DAO restart [s19][s20][s21]. |
| The motion roles of the universal factory | The governance role on the operator modifier writes only under `asset-operator`. The exit-governance role writes only under `asset-emergency`. The governance role on the orders modifier writes only under `orders-operator`, `orders-emergency` and `approvals`; its own key becomes `orders-governance`. Keep membership setters, delegatecall expansion and administrative targets outside these roles [s19]. |
| Emergency powers | The Asset emergency role's revoke names `asset-operator`, and the Orders emergency role's revoke names `orders-operator` [s20][s21]. |
| Invariants | Replace INV-018's single-key rule with the account-to-key mapping. Update the key references of INV-025, INV-027 and INV-040. Preserve INV-004's governance restrictions and INV-009's emergency stop. Map the revised rules to named tests [s18]. |
| Compiler and policy | The shared compiler already takes the four keys for a manifest with `roleKeyScheme: account`: the stop-only check, the zeroing rule and the keys that a motion may write. Move the mainnet constellation, its manifests and the committed artifacts to that scheme together, and then remove the shared-key branch. The launch-onboarding file, the example motions and the motion, round-trip and detector commands read role names from the artifact or name them; update each [s22][s26]. |
| Execution and operations | Update the role arguments of the fork suite and the rehearsal, the runbooks, the onboarding guide and the monitoring. Rehearse the enabling vote and one motion of each motion role with the new keys on a mainnet fork [s18][s20]. |

Sepolia fixtures and a single controller do not prove the mainnet governance, signer or asset configuration [s4]. Any mainnet role that is deployed before these updates needs a separate migration review and governance package.

## Options considered

- **Keep ADR 004 decision 16 for Sepolia.** Not chosen in OD-147. Pull request #44 merges first, and the owner team pushes from `main`. Each change to the Sepolia tooling then waits for a merge before a test.
- **A one-time exception for each publication, recorded in the decision log.** Not chosen in OD-147. This repeats the route of 2026-10-20, where no guard ran [s6].
- **A standing exception for any branch.** Reviewers then cannot see the code that ran.
- **The SDK's `push` alone, or a manual API call.** Not chosen in OD-148. The API refuses the governance `Nor` conditions in the format that `push` sends [s7]. A manual call leaves no record that a reviewer can read.
- **No record by hand in the Zodiac app, or any record.** Not chosen in OD-151. The SDK has no address-book endpoint [s10], and a policy edit in the app is drift (ADR 004, decision 11) [s1].
- **Replace `Nor` with `And` and `Or` conditions in the policy.** That change gave five on-chain differences [s9].
- **Agents publish.** AGENTS.md forbids it [s3].
- **Keep the shared keys.** Not chosen in OD-152. The policy model blocks the two pairs of different grants from appearing as separate policies [s17].
- **Use four account-specific keys on both networks.** Chosen in OD-152 B. Migrate the existing Sepolia roles and update the mainnet design before its initial deployment.
- **Change Sepolia alone.** Not chosen in OD-152. This separates the test and production key schemes and leaves the mainnet policy conflict unresolved.
- **Keep `governance` on both modifiers on mainnet, or give both governance roles an account key.** Not chosen in OD-153. The first leaves a role that the hosted app does not show. The second renames a role that no conflict needs.

## Consequences

- The production rule of ADR 004 does not change. A second guard exists for Sepolia, and both guards need tests.
- The Sepolia guard accepts two branches, `testnet/sepolia` and `main`. Each answers to its own branch on GitHub, so a local `main` at a commit that is not merged fails.
- The hosted publications of 2026-10-22 and 2026-11-16 ran before OD-147 and OD-148 closed [s25].
- Until the mainnet design takes the four keys, `main` holds a decided key scheme that its policy does not use yet. The table of mainnet design dependencies lists the work.
- Hosted acceptance in the Sepolia workspace is evidence for Sepolia only. It does not show that the production workspace accepts the production policy.
- Code runs from a branch that is not merged. Reviewers can see it in pull request #44. Nobody has approved it [s14].
- A key that reaches every workspace of the account also reaches the production workspace. The key condition of OD-147 controls this risk.
- The stand keeps one controller. It does not test signer independence [s4].
- A role-key migration changes on-chain role identity and execution arguments. It needs permission migration and tests even when the permitted actions stay the same [s17].

## Confirmation

- `policy/constellation/sepolia/publish-constellation.test.ts` covers the Sepolia guard. The guard refuses a run without `CLUTCH_SEPOLIA_PUSH=1`, in CI, on a branch other than `testnet/sepolia` and `main`, with local changes, with an unpushed commit, without the key, with another workspace and with an API address that does not use https.
- The same file covers the publication script with a mock `fetch`. The script stops for a stale payload, another manifest, and a resolution that differs in a condition, a member, an allowance, an account, a Safe owner or the annotations. It accepts a resolution that lists the roles in another order. It saves an HTTP error, a body that is not JSON and a timeout.
- An HTTP 200 with an incomplete or invalid result fails. A timeout while reading its body also fails. Each failure keeps the attempt record and blocks a retry to the same API URL and workspace. The same payload can be published to another API URL or workspace. Concurrent runs for the same API URL, workspace and payload send one apply [s16].
- A resolution with one `Nor` rewritten fails the comparison [s15].
- The migration package passed nine tests on a pinned fork, including the state between its two batches [s23]. The stand owner executed both batches at blocks `11976805` and `11976806`. The comparison at block `11976825` found zero policy differences, with unchanged allowance storage and Safe configuration [s24].
- The stand owner published the 14 roles to the Sepolia workspace on 2026-11-16. The resolve and the apply matched the payload, the policy and the chain at block `12148661`. Zodiac then showed `Nothing to deploy` [s25].

The acceptance checks of the migration are:

- Fork tests execute allowed calls under each new key and refuse calls under each old key. They cover governance key pins, the Asset switch, the Orders revoke and recovery, and the intermediate states of any split batch. They also refuse added members, extra grants, non-zero emergency approvals and emergency restoration.
- State comparisons preserve the allowance storage, members, Safe/module configuration and conditions specified above. The reviewed package contains no deployment or allowance-reset calls. Any Zodiac execution package must contain the same calls.
- After authorised execution, receipts succeed and a fresh RPC comparison finds zero differences against the migrated declaration. Tests update INV-018, INV-025 and INV-027 without weakening INV-004 or INV-009 [s18].
- After a separately authorised publication, a reload of the workspace shows three Vaults and the 14 Policies with the new keys. Resolve alone cannot prove that the app saved this metadata [s25].

## Reversal conditions

- The Sepolia key or the Sepolia guard reaches the production workspace.
- A hosted call runs from a commit that is not on GitHub.
- The hosted app changes a condition or an account in a saved draft.
- The provider enforces a quota that blocks a save or publication.
- A new role bypasses a compiler restriction, or governance or emergency powers differ from the reviewed mapping.
- An old key still executes, a transition loses emergency control, or the migration resets allowance state.
- The hosted app refuses the separate policies under the four new keys.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
