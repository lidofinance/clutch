---
type: Decision
title: "ADR 013: Tests on Sepolia"
description: What the stand owner may do to test Clutch on Sepolia, with public test transactions, the Zodiac test workspace, its key, its branch and its guards.
tags: [sepolia, testing, zodiac, deployment, process]
status: draft
review_status: slop
decision: proposed
generated:
  by: codex/gpt-6
  at: 2026-10-22T15:44:18Z
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
    resource: /specs/sepolia-deployment-notes.md
    title: Sepolia deployment findings — the push without the owner guard, the Nor refusal, the legacy role format and the cancelled deployment
  - id: s8
    resource: urn:clutch:evidence:2026-10-20:sepolia-legacy-targets-resolve
    title: Hosted resolve — permissions with Nor returns 400; legacy targets with empty annotations returns 200
  - id: s9
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/index.mjs"
    title: Zodiac SDK 2.1.2 — push sends each role as permissions
  - id: s10
    resource: urn:clutch:evidence:2026-10-22:sepolia-publication-review
    title: Local review — retired publication helper, preserved snapshots and zero RPC policy differences at block 11969893
  - id: s11
    resource: urn:clutch:evidence:2026-10-22:sepolia-pending-review
    title: Zodiac readback — cancelled deployment and two proposals remaining in Outstanding
  - id: s12
    resource: urn:clutch:evidence:2026-10-20:zodiac-workspace-plan-limits
    title: Workspace usage screenshot — six policies against a limit of three; three vaults against a limit of three
  - id: s13
    resource: urn:clutch:evidence:2026-10-22:sepolia-new-workspace
    title: New Sepolia workspace — the constellation list is empty before publication
  - id: s14
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/api-C49DoaPC.mjs"
    title: Zodiac SDK 2.1.2 API client — accounts, users, constellation resolve and apply, and the ZODIAC_API_URL override
  - id: s15
    resource: urn:clutch:evidence:2026-10-20:zodiac-address-book
    title: Address Book — 36 saved names, addresses and Sepolia chain assignments checked against the local manifest and dependencies
  - id: s16
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — EM accepts ADRs in the interim; an accepted ADR authorises nothing on chain
  - id: s17
    resource: /registers/decision-log.md
    title: Decision log — EM allows the registration of YT as a decision proposer and page verifier; acceptance stays with EM and the committee, 2026-10-20
  - id: s18
    resource: "https://github.com/lidofinance/clutch/pull/44"
    title: Pull request #44 — the Sepolia stand and deployment workflow, open
  - id: s19
    resource: urn:clutch:evidence:2026-10-22:sepolia-resolution-check
    title: Local check — the resolution saved on 2026-10-20 against the current payload; the same 63 calls with the roles in another order; Safe owners and modules match
  - id: s20
    resource: urn:clutch:evidence:2026-10-22:sepolia-publisher-regressions
    title: Publisher regression tests — invalid success responses, body-read timeouts and separate attempts for each API URL and workspace
  - id: s21
    resource: urn:clutch:evidence:2026-10-22:zodiac-quota-reply
    title: Reply relayed by the stand owner — quotas are not enforced immediately and tests may exceed the displayed limits
---

# ADR 013: Tests on Sepolia

## Context

- ADR 004 sets the Zodiac rules for the production policy. The repository-owner team owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main` (decision 16). No transaction that the hosted app builds is signed unless Clutch's compiler produces the same calls from the same commit (decision 11) [s1].
- The owner guard enforces decision 16. It refuses a hosted call without `CLUTCH_OWNER_PUSH=1`, in CI, outside `main` and with local changes [s2].
- Agents never use the Zodiac API key and never deploy [s3].
- A Sepolia test stand exists on the `testnet/sepolia` branch. Pull request #44 carries it and is not merged [s18].
- The stand has three vault Safes, four Roles modifiers and seven roles. One controller owns the 1/1 Committee and Emergency Safes and controls the test governance contracts. The stand plan lists the funding, the CoW and First-loss drills and the stop of the run as open steps [s4].
- `sepolia.just` keeps public Sepolia transactions for a human. Its guard requires `CLUTCH_SEPOLIA=1` and refuses CI and a raw private key. Foundry asks for the keystore password [s5].
- On 2026-10-20, the stand owner published a draft to an earlier workspace under an explicit exception for a review branch [s6]. The owner guard did not run [s7].
- The hosted API refused the five governance `Nor` conditions in the SDK's `permissions` format with HTTP 400. In the earlier workspace, the resolver accepted the same roles in the legacy `targets` format with HTTP 200 [s8].
- The SDK's `push` sends each role as `permissions` [s9]. The repository has no supported route for the legacy payload. A local publication helper was retired on 2026-10-22, before any hosted call [s10].
- The stand owner started a deployment in the earlier workspace and cancelled it. Its two proposals stayed in `Outstanding` [s7][s11].
- The earlier workspace showed six policies against a limit of three, and three vaults against a limit of three [s12].
- On 2026-10-22, the stand owner relayed a reply from the provider. It says the limits are not enforced immediately and tests may exceed them [s21].
- On 2026-10-22, a new workspace for the stand listed no constellations [s13]. The prepared payload binds the existing accounts. At block 11969893, the RPC comparison found zero policy differences [s10].
- The SDK's API client has endpoints for accounts, users, and constellation resolve and apply. It has no address-book endpoint [s14]. The stand's 36 address-book entries were made in the Zodiac app and checked on 2026-10-20 [s15].
- EM accepts an ADR in the interim, and the committee permanently. An accepted ADR authorises nothing on chain (ADR 002, decision 7) [s16].
- YT is a decision proposer and page verifier. ADR acceptance stays with EM and the committee [s17].

## Decision

No decision is recorded yet. YT proposes this record; an agent drafted it on 2026-10-22. OD-89 to OD-93 carry the questions, and EM decides them [s16][s17].

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it.

Tests on Sepolia are permitted under the rows below. Each row is a permission that the tests need, and each row waits for EM's decision. The rows apply only to the Sepolia workspace and to chain 11155111. ADR 004 does not change for the production workspace [s1].

| Permission | Who acts | Conditions | Decision |
|---|---|---|---|
| Work from `testnet/sepolia` instead of the merged `main`: hosted calls to the Sepolia workspace and public Sepolia transactions | The stand owner | The commit is on GitHub. The working tree has no local changes. | OD-89 |
| Hold an API key for the Sepolia workspace in a git-ignored `.env` | The stand owner | Nobody commits the key. No agent and no CI job uses it. If the provider can limit a key to one workspace, the key reaches only the Sepolia workspace. | OD-89 |
| Run hosted calls through a Sepolia guard, separate from the owner guard | The stand owner | The guard requires `CLUTCH_SEPOLIA_PUSH=1` and the branch `testnet/sepolia`. It refuses CI, local changes, and a workspace that differs from the prepared context. The owner guard stays as it is. | OD-89 |
| Publish the existing-state declaration to the Sepolia workspace as a draft | The stand owner | A committed script checks the payload hash and a fresh RPC comparison. It calls resolve and compares the resolved specification with the payload: accounts, owners, members and `Nor` conditions. It calls apply once for each API URL, workspace and payload hash, records the attempt exclusively and saves each status and body. Success requires a complete HTTP exchange and a JSON result with nonempty `id` and `url` strings. It uses the same API address as the SDK. | OD-90 |
| Execute a transaction that the Zodiac app builds for the stand (Deploy or Apply) | Nobody, until EM decides otherwise | If EM permits it: Clutch's compiler produces the same calls from the same commit, and the test Voting contract executes them. | OD-91 |
| Send public Sepolia transactions on the existing stand: funding, the CoW and First-loss drills, recovery and the stop of the run | The stand owner, with the keystore | Only through the `sepolia.just` recipes and their guards. A second stand needs a new decision. | OD-92 |
| Import the three existing Safes as vaults and enter the address-book entries in the Sepolia workspace | The stand owner | No role or permission is edited in the Zodiac app. The entries come from the checked address list. | OD-93 |
| Remove the earlier workspace's draft aliases and cancelled proposals | The stand owner | Only where the app permits it. Nothing is executed. | OD-93 |
| Prepare payloads, run read-only RPC comparisons, and write code, tests and documents | Agents | No change: agents never use the key, call the hosted app, sign or send [s3]. | None |

## Options considered

- **Keep ADR 004 decision 16 for Sepolia.** Pull request #44 merges first, and the owner team pushes from `main`. Each change to the Sepolia tooling then waits for a merge before a test.
- **A one-time exception for each publication, recorded in the decision log.** This repeats the route of 2026-10-20, where no guard ran [s7].
- **A standing exception for any branch.** Reviewers then cannot see the code that ran.
- **The SDK's `push` alone.** The API refuses the governance `Nor` conditions in that format [s8].
- **Replace `Nor` with `And` and `Or` conditions in the policy.** The deployment findings record five on-chain differences for that change [s7].
- **Agents publish.** AGENTS.md forbids it [s3].

## Consequences

- The production rule of ADR 004 does not change. A second guard exists for Sepolia, and both guards need tests.
- Hosted acceptance in the Sepolia workspace is evidence for Sepolia only. It does not show that the production workspace accepts the production policy.
- Code runs from a branch that is not merged. Reviewers see it in pull request #44, but nobody has approved it [s18].
- A key that reaches every workspace of the account also reaches the production workspace. The key condition of OD-89 decides this risk.
- The stand keeps one controller. It does not test signer independence [s4].
- The provider permits tests above the displayed quotas. Record an actual save or publication error for the provider to investigate [s21].

## Confirmation

- `policy/constellation/sepolia/publish-constellation.test.ts` covers the Sepolia guard. The guard refuses a run without `CLUTCH_SEPOLIA_PUSH=1`, in CI, on another branch, with local changes, with an unpushed commit, without the key, with another workspace and with an API address that does not use https.
- The same file covers the publication script with a mock `fetch`. The script stops for a stale payload, another manifest, and a resolution that differs in a condition, a member, an allowance, an account, a Safe owner or the annotations. It accepts a resolution that lists the roles in another order. It saves an HTTP error, a body that is not JSON and a timeout. Nobody has run the script against the hosted app.
- An HTTP 200 with an incomplete or invalid result fails. A timeout while reading its body also fails. Each failure retains the attempt record and blocks a retry to the same API URL and workspace. The same payload can be published to another API URL or workspace. Concurrent runs for the same API URL, workspace and payload send one apply [s20].
- The resolution that the hosted app returned on 2026-10-20, in the earlier workspace, passes the comparison for the current payload. A rewrite of one `Nor` in that resolution fails it [s19].
- After the publication: the saved draft shows the `Nor` conditions of the governance role, no modified node and an empty hosted diff. The stand owner records this as evidence.

## Reversal conditions

- The Sepolia key or the Sepolia guard reaches the production workspace.
- A hosted call runs from a commit that is not on GitHub.
- The hosted app changes a condition or an account in a saved draft.
- The provider enforces a quota that blocks a save or publication [s21].

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-89](/registers/open-decisions.md): May the stand owner make hosted calls to the Sepolia workspace and send public Sepolia transactions from `testnet/sepolia`? A: no; ADR 004 decision 16 stays, so pull request #44 merges first and the owner team pushes from `main`. B: yes, from a commit that is on GitHub with no local changes, through a Sepolia guard separate from the owner guard, with an API key for the Sepolia workspace in a git-ignored `.env`. C: a one-time exception for each publication, recorded in the decision log.
- [OD-90](/registers/open-decisions.md): How does the existing-state payload reach the Sepolia workspace? A: the SDK's `push`. B: a committed script behind the Sepolia guard: it checks the payload hash and a fresh RPC comparison, calls resolve, compares the resolved specification with the payload, calls apply once and saves each status and body. C: a manual API call.
- [OD-91](/registers/open-decisions.md): May the stand owner execute a transaction that the Zodiac app builds for the Sepolia stand, through Deploy or Apply? A: no, drafts only. B: yes, when Clutch's compiler produces the same calls from the same commit and the test Voting contract executes them. C: yes, without that check.
- [OD-92](/registers/open-decisions.md): May the stand owner send public Sepolia transactions on the existing stand from `testnet/sepolia`: funding, the CoW and First-loss drills, recovery and the stop of the run? A: yes, only through the `sepolia.just` recipes and their guards, with the keystore; a second stand needs a new decision. B: only after pull request #44 merges. C: no more public transactions.
- [OD-93](/registers/open-decisions.md): Which records may the stand owner make by hand in the Zodiac app? A: none. B: vault imports of the three existing Safes, the checked address-book entries, and removal of the earlier workspace's draft aliases and cancelled proposals; no role or permission edits in the app. C: any record, policy drafts included.

<!-- end of generated block -->
