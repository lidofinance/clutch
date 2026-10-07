---
type: Decision
title: "ADR 012: Contributing with many agents"
description: Many contributors may run their own agents here — any agent may author a page, and only listed humans and teams verify, with a hash that locks the page's body; agents own no GitHub accounts; changes land through a merge queue; decisions enter as complete open-decision rows and are decided in batched interviews; safe defaults, one command for setup, checks and generated files, and checks for restricted terms, licences, invariants and IDs.
tags: [agents, contributors, process, security, ci]
status: draft
review_status: slop
decision: proposed
constrains_operator: false
generated:
  by: claude-code/opus-5.5
  at: 2026-10-07T08:22:39Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's answers on more contributors and their agents, 2026-10-07
  - id: s2
    resource: /research/contributor-readiness-2026-10-07.md
    title: Research note — file churn, the actor list, CI coverage, unsafe defaults, the fifteen steps and the keystore rehearsal
  - id: s3
    resource: /adr/003-agent-operating-model.md
    title: ADR 003 — the agent operating model; decision 12 deferred the agent's own GitHub identity as OD-23
  - id: s4
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — who accepts and who verifies
  - id: s5
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the hosted Zodiac app is outside the path, and the repository-owner team holds its key
  - id: s6
    resource: /registers/open-decisions.md
    title: Open decisions — OD-23, and OD-50 to OD-53 from this record
---

# ADR 012: Contributing with many agents

## Context

- EM wants more contributors to run their own agents in this repository, without hectic merges [s1].
- The repository was built for one operator. The validator let one agent author pages. Most changes edited the same shared files, and two of them insert at the top. Mainnet recipes and hosted-app scripts sat next to safe ones, and restricted terms stayed out by convention [s2].
- ADR 003 holds the agent rules. Its decision 12 deferred the agent's own GitHub identity as OD-23 [s3]. ADR 002 sets who accepts and who verifies [s4].

## Decision

EM decided on 2026-10-07 [s1]. The numbers refer to the fifteen steps of the research note [s2].

1. (Step 2) Any agent may author a page: `generated.by` accepts any agent id of the form `<runner>/<model>`. Only the humans that `config/actors.yaml` lists verify a page. Human reviewer ids join the list by role; which ones is OD-50.
2. (Step 4) `CODEOWNERS` does not change for now.
3. (Step 7) A change lands on `main` through a merge queue, or, without one, only when its branch is up to date with `main`. The checks run on the merged result.
4. (Step 14) An agent opens a decision only as a complete row of the open-decision register: the question with its options, the page that closes it, its recommendation and who decides. EM triages the open decisions and decides them in batched interviews. One decisions branch is open at a time.
5. (Step 15) Agents own no GitHub accounts. An agent's work lands through the account of the human who runs it. Each commit carries a `Co-Authored-By` trailer for the agent, and each page names the agent in `generated.by`. This closes OD-23, and it replaces ADR 003 decision 12 when EM accepts this record.

EM decided on 2026-10-07, closing OD-50 to OD-53 [s1]:

6. (OD-50) A team verifies through a member, with `ref` to the pull request that the member approved. `human:defi-tech` is the first team. A team's verification raises a page's review status and never accepts an ADR: only EM or the committee accepts one.
7. (OD-51) Each verification from 2026-10-07 on records `sha256`, the hash of the page's body. `just verify` writes the entry. The validator fails when the body differs from the hash of the latest verification, until a human verifies the page again. Earlier verifications stay as they are.
8. (OD-52) The fork suite stays out of CI for now. Phase 2 of the roadmap moves it into the merge queue and onto pushes to `main`, with the archive RPC key as a repository secret, never on a pull request.
9. (OD-53) The request for solution's allocation figures are not restricted. The README opens with a disclosure: everything in the repository is a draft and not ratified, and every number is speculative.

EM decided on 2026-10-07 [s1]:

10. A CI workflow publishes the onboarding guide on GitHub Pages from `main`. The page says that it is a hypothetical draft: nothing is deployed or ratified, every number can change, and it is not advice. This replaces "internal first" of OD-37 for the guide's page alone. The repository stays private until deployment (ADR 001).

An agent drafted this record. It stays `proposed` until EM accepts the text.

## Proposed direction

EM asked the agent to implement every step that needs no further decision [s1]. The rest of this section is agent-drafted.

- **Safe defaults (step 1).** `mainnet.just` holds the mainnet recipes, and the `Justfile` never loads it. A recipe runs only with `CLUTCH_MAINNET=1`, outside CI, without `PRIVATE_KEY`, after a prompt, and it signs with a Foundry keystore, which asks for its password. The dry-run scripts take their signer from the command line. The package scripts that call the hosted app run an owner guard first: they refuse unless a member of the repository-owner team sets `CLUTCH_OWNER_PUSH=1` on a clean `main`, and they refuse in CI [s5].
- **Identity (step 2).** Only agents that `config/actors.yaml` lists may record a human's verification on that human's instruction (ADR 003, decision 14). The rule is unchanged, because writing a human's entry is the sensitive path. Teams are a separate list in `config/actors.yaml`; an agent never records a team's verification.
- **Verification (decision 7).** `scripts/verify_page.py`, through `just verify <page> <human>`, writes a verification with the time, the body's hash and, where needed, `ref` and `--review`. It refuses an agent as the verifier. The body is the page after its frontmatter, so a bump of `generated.at` or a new source keeps the lock, and any edit to the text breaks it.
- **Commands (step 3).** `just setup`, `just check`, `just regen`, `just log` and `just test-fork`. Without just installed, `uvx --from rust-just==1.58.0 just <recipe>` runs any recipe. `AGENTS.md`, the README and `CONTRIBUTING.md` use these commands.
- **Restricted terms and secrets (step 5).** `scripts/check_redaction.py` reads every tracked and new file. It refuses the screening vendor's identity, the addresses that reveal it and figures from the unapproved mandate, through a list of salted hashes in `config/redaction.yaml`, and it refuses private keys, RPC URLs with a key and API tokens. A finding names the file, the line and the kind, never the value.
- **The log from fragments (step 6).** Each change adds one file to `docs/log.d/`, and `scripts/build_log.py` builds `docs/log.md`. CI fails when the log is not a fresh build.
- **Merge queue (step 7).** The workflows also run on `merge_group`. An admin turns the merge queue on in the branch rule, or requires branches to be up to date.
- **Generated files (step 8).** `.gitattributes` marks the log, the status register and the guide as generated. On a conflict, a contributor takes either side and runs `just regen`. The policy artifact is not marked, because reviewers approve its diff.
- **IDs (step 9).** The validator refuses an OD, ADR or INV number that is used twice, and an open decision with an empty cell. A contributor takes the next number from `main`.
- **Pull requests (step 11).** A pull-request template asks for the agent, what a human must check, the commands that ran and a restricted-data statement. One decision or one feature goes in each pull request.
- **Procedures (step 12).** `CONTRIBUTING.md` holds the workflow. Four skills join `adr-draft`: `decision-interview`, `record-decision`, `guide-update` and `research-note`.
- **The guide on GitHub Pages (decision 10).** `.github/workflows/pages.yml` runs on a push to `main` that changes the page, or by hand. It checks that the committed page is a fresh build and still carries its disclaimer, then deploys the page as `index.html`, with a `robots.txt` that asks crawlers to stay away. The page also carries a `noindex` tag. Only the deploy job may write to Pages; a pull request never deploys. The build refuses a banner or a footer that drops the disclaimer.
- **CI gaps (step 13).** `scripts/check_licences.py` replaces ADR 001's grep command: every source file carries AGPL-3.0-or-later, a changed provider file carries LGPL-3.0-only, and an unchanged provider file matches its blob hash in `policy/constellation/provenance.lock`. `scripts/check_invariants.py` fails when an invariant names a test that does not exist, or when a Draft invariant names none. The fork suite stays a local check until phase 2 (decision 8).

## Options considered

- Keep one listed agent and add each new one by hand. Not chosen by EM (step 2): every new contributor would wait for a change to a protected file.
- Give each agent its own GitHub account (OD-23). Not chosen by EM (step 15): agents own no accounts.
- `CODEOWNERS` by risk: decisions to EM, policy and contracts to policy reviewers. Deferred by EM (step 4): "don't edit codeowners yet".
- Fix collisions after they happen, without a merge queue. Not chosen by EM (step 7): two green pull requests can still turn `main` red.
- Let any contributor open a decision as free text. Not chosen by EM (step 14): EM would receive questions without options or a recommendation.
- One verifier id per reviewer, or no new ids (OD-50 B and C). Not chosen by EM: a team id names no person, and its pull request shows who approved.
- A content check from the git history, or the rule as text only (OD-51 B and C). Not chosen by EM: the hash needs no history and catches every edit.
- The fork suite on every pull request, with the key (OD-52 B). Not chosen by EM: a pull request's code could read the key. The merge-queue option waits for phase 2.
- The request for solution's figures as restricted terms (OD-53 A). Not chosen by EM: they went to the policy provider, and the README marks every figure as a draft.

## Consequences

- An unknown agent's page passes the validator. The reviewer sees the agent in `generated.by` and the human in the commit.
- Merges take longer in a queue, and `main` stays green.
- EM remains the bottleneck for decisions, by design. Batched interviews reduce the interruptions.
- The redaction list hides its terms from a casual reader, not from someone who guesses them.
- A verified page cannot change silently. A typo fix on it needs a new verification.
- Until phase 2, a pull request can break the fork suite without a red check. The template asks its author to run `just test-fork`.
- A local rehearsal on an anvil fork may still set `PRIVATE_KEY` to one of anvil's public keys, for one command. `mainnet.just` refuses to run while it is set.
- A contributor needs uv, bun, Foundry and git, and an archive RPC for the fork suite.

- Anyone with the address can read the guide. Its source links point into the private repository, so a reader without access gets an error page there.

## Confirmation

- `scripts/test_validate_docs.py`: any agent may author; an unlisted human cannot author or verify; an agent never verifies; an OD, an INV and an ADR number are each used once; an open decision needs every cell; a team verifies only with its pull request and never accepts an ADR; a verification from 2026-10-07 on needs the body's hash, and an edit after it fails.
- `scripts/test_checks.py`: the log build and its fragments, restricted words, addresses and figures, secrets, licences and invariants.
- `bun test compiler`: the owner guard refuses without the owner's confirmation, in CI, outside `main` and with local changes.
- The keystore rehearsal of `mainnet.just` on an anvil fork, 2026-10-07: deploy, apply, fund and teardown, and the refusals [s2].

## Reversal conditions

- A contributor's agent leaks a restricted term or a secret past the check.
- The merge queue blocks routine work for more than a day.
- An agent writes a human's entry that the human did not instruct.

- `scripts/test_build_onboarding.py`: a banner or a footer without the draft disclaimer fails the build. The browser tests check the disclaimer and the `noindex` tag. `actionlint` 1.7.12 finds nothing in the workflows, and the page works when served over HTTP, with no outside request and no console message (2026-10-07).

## Open questions

None. EM closed OD-50 to OD-53 on 2026-10-07 [s6]. An admin still turns on the merge queue, or requires branches to be up to date, in the branch rule on `main`.
