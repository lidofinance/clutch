---
type: Decision
title: "ADR 012: Contributing with many agents"
description: Contribution, human verification, decision interviews, CI, generated files and guide source pins.
tags: [agents, contributors, process, security, ci]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T21:39:40Z
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
  - id: s7
    resource: /registers/decision-log.md
    title: Decision log — EM's request for a triage of the onboarding guide's tests, and EM's answer, 2026-10-12
  - id: s8
    resource: /research/guide-invariants-2026-10-12.md
    title: Research note — the guide's defects in print and without its script, the churn of whole-ADR pins, and the drift that the decision-level references found
  - id: s9
    resource: /registers/decision-log.md
    title: Decision log — EM's instructions after PR #38, 2026-10-14: the Emergency Brakes multisig in the guide, and the generated registers

---

# ADR 012: Contributing with many agents

## Context

- EM wants more contributors using their own agents without conflicting merges [s1].
- The initial single-operator repository allowed one agent author. Changes repeatedly touched shared files, two with top insertions. Mainnet and hosted-app scripts sat beside safe commands; restricted terms were excluded by convention [s2].
- [ADR 003](/adr/003-agent-operating-model.md) holds agent rules and deferred GitHub identity as OD-23 (decision 12) [s3]. [ADR 002](/adr/002-decision-and-review-process.md) defines acceptance and verification [s4].

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

Since OD-95, the repository is public ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md) decision 10).

EM decided on 2026-10-12 [s7]:

11. The onboarding guide gets every check that the agent's triage of 2026-10-12 proposed, in one pull request, with no part deferred [s8]. The browser tests check every presentation state and the page without its script. Each item of the guide is pinned to the text of its sources, and a reference names a decision or a section of an ADR, not the whole ADR. Every ADR, invariant, LIP part and runbook is cited by the guide or excluded with a reason. CI attaches the built page to each pull request, reports the pin changes, checks the workflows, and checks the guide's outside links each week.

EM decided on 2026-10-14, closing OD-81 and OD-82 [s9]:

12. The diagrams, in the guide and in the LIP draft, carry no node for the Emergency Brakes multisig. The guide states two facts about it: it can pause Easy Track, and two of the emergency Safe's five signers come from it.
13. The closed decisions live in `docs/registers/closed-decisions.yaml`, each with its question, date, decision-log headings, ADR decisions and the earlier ODs that it replaces or refines. `validate_docs.py --write-status` generates the register's closed index with each OD's state, the ADR index from each record's description, and each proposed ADR's open decisions; `--check-status` fails on a stale block. The validator fails on an unknown heading, decision or OD in the data, on a replacement of a later OD and on a skipped OD number, and the guide's build refuses a source that names a replaced OD, and an item whose text names an OD that its sources do not cite.

## Proposed direction

EM requested implementation of steps needing no further decision [s1]. The proposals below are agent-drafted.

- **Safe defaults (step 1).** The `Justfile` never loads `mainnet.just`. Mainnet recipes require `CLUTCH_MAINNET=1`, no CI or `PRIVATE_KEY`, confirmation and Foundry-keystore signing with a password prompt. Dry-run scripts take a command-line signer. Hosted-app scripts first require an owner-team member's `CLUTCH_OWNER_PUSH=1` on clean `main` and refuse CI [s5].
- **Identity (step 2).** Only listed agents can record a human's verification on that human's explicit instruction (ADR 003, decision 14). Teams have a separate `config/actors.yaml` list; agents cannot record team verification.
- **Verification (decision 7).** `just verify <page> <human>` runs `scripts/verify_page.py`, recording time, body hash and required `ref`/`--review`. Agents cannot be verifiers. Hashing excludes frontmatter: `generated.at` or source-metadata edits preserve the lock; body edits break it.
- **Commands (step 3).** Use `just setup`, `just check`, `just regen`, `just log` and `just test-fork`. Without just, run `uvx --from rust-just==1.58.0 just <recipe>`. `AGENTS.md`, the README and `CONTRIBUTING.md` use this interface.
- **Redaction (step 5).** `scripts/check_redaction.py` scans tracked/new files. Salted hashes in `config/redaction.yaml` identify restricted vendor names, revealing addresses and figures from the unapproved mandate. It also rejects private keys, keyed RPC URLs and API tokens. Findings show file, line and kind, never values.
- **Log (step 6).** Add one fragment in `docs/log.d/` per change. `scripts/build_log.py` generates `docs/log.md`; CI rejects stale output.
- **Merge queue (step 7).** Workflows run on `merge_group`. An admin enables the queue or requires up-to-date branches.
- **Generated files (step 8).** `.gitattributes` marks log, status register and guide. Resolve conflicts by taking either side and running `just regen`. Policy artifacts stay unmarked because reviewers must inspect their diffs.
- **IDs (step 9).** Take the next number from `main`. The validator rejects duplicate OD/ADR/INV IDs and incomplete open-decision rows.
- **Pull requests (step 11).** One decision or feature per pull request. The template asks for agent identity, human checks, commands run and restricted-data confirmation.
- **Procedures (step 12).** CONTRIBUTING holds the workflow. `decision-interview`, `record-decision`, `guide-update` and `research-note` join `adr-draft`.
- **GitHub Pages (decision 10).** `.github/workflows/pages.yml` runs for page changes on `main` or manually. It checks freshness and disclaimer, then deploys `index.html` and a `robots.txt` that asks crawlers to stay away. HTML also uses `noindex`. Only the deploy job writes Pages; pull requests never deploy. Missing banner/footer disclaimers fail the build.
- **Guide checks (decision 11)** follow the research evidence [s8]:
  - `matrix` runs axe-core in twelve states and rejects text matching its background. `static` rejects controls that look interactive but do nothing without JavaScript. Each first catches a planted defect. `ONBOARDING_PAGE` selects another HTML copy.
  - Dark styles apply only to screens. Only JavaScript adds widget roles to tabs, panels and map boxes.
  - `docs/onboarding/pins.json` hashes item content and source text. `ADR-NNN#dN` pins a decision and blocks naming it, including replacements; `ADR-NNN#<heading>` pins a section. Whole ADRs are refused; map layout is unpinned. Stale pins fail with the repair command. Review `just stale` before `just repin <item>`.
  - `docs/onboarding/content/coverage.yaml` excludes ADR 012, INV-007 and INV-020 with reasons. Unused map boxes or arrows fail the build.
  - The `docs` workflow retains HTML for 14 days, reports pin changes through `scripts/pin_report.py` and lists stale items when the build check fails. The `workflows` job uses zizmor 1.30.1. The `links` workflow runs `scripts/check_links.py` on Mondays and manually. `just check` runs `actionlint` and zizmor offline.
- **CI gaps (step 13).** `scripts/check_licences.py` replaces ADR 001's grep: AGPL-3.0-or-later for source, LGPL-3.0-only for changed provider files, and blob hashes in `policy/constellation/provenance.lock` for unchanged ones. `scripts/check_invariants.py` rejects missing named tests and Draft invariants without tests. Fork tests remain local until phase 2 (decision 8).

## Options considered

- List each agent manually: EM rejected under step 2 because contributors would need protected-file edits.
- Separate agent GitHub accounts (OD-23): EM rejected under step 15; agents own none.
- Risk-based CODEOWNERS: EM deferred under step 4, "don't edit codeowners yet".
- Resolve collisions without a queue: EM rejected under step 7 because two green pull requests can produce a failing `main`.
- Free-text decisions: EM rejected under step 14 because questions need options and recommendations.
- Per-reviewer IDs or no new IDs (OD-50 B/C): EM rejected because team IDs avoid names while pull requests identify approvers.
- Git-history checks or prose-only rules (OD-51 B/C): EM rejected because hashes detect edits without history.
- Keyed fork tests on pull requests (OD-52 B): EM rejected because submitted code could read the key. Merge-queue tests wait for phase 2.
- Restrict RFP figures (OD-53 A): EM rejected because they were sent to the provider and README labels figures as drafts.

## Consequences

- Unlisted agents can author pages; reviewers see `generated.by` and the human commit author.
- The queue increases merge time to keep `main` green.
- EM remains the decision bottleneck; batched interviews reduce interruptions.
- Hashed redaction lists deter casual discovery, not guessing.
- Any verified-body edit, including a typo, requires re-verification.
- Until phase 2, broken fork tests need not make CI red. The template asks authors to run `just test-fork`.
- Local anvil rehearsals may use one public test `PRIVATE_KEY` for one command. `mainnet.just` refuses it.
- Contributors need uv, bun, Foundry, git and an archive RPC for fork tests.
- The guide is readable by anyone with its URL, and its source links work for every reader, because the repository is public (OD-95).

## Confirmation

- `scripts/test_validate_docs.py` permits any agent author and rejects unlisted human authors/verifiers and agent verifiers. It checks unique OD/INV/ADR IDs, complete decision rows, team verification through pull requests and refusal of team acceptance. Verifications from 2026-10-07 need hashes; later edits fail.
- `scripts/test_checks.py` covers log fragments/builds, restricted content, secrets, licences and invariants.
- `bun test compiler` checks owner-guard refusal without confirmation, in CI, outside `main` and with local changes.
- The 2026-10-07 anvil-keystore rehearsal covered deploy, apply, fund, teardown and refusals [s2].
- On 2026-10-07, `scripts/test_build_onboarding.py` rejected missing disclaimers; the browser tests checked disclaimer and `noindex`. actionlint 1.7.12 found no workflow issues. HTTP-served HTML made no outside requests or console messages.
- On 2026-10-12, decision-11 validation passed 85 build cases and 193 browser checks. Cases included coverage, map rules, whole-ADR refusal, six pin cases, replacement-note pinning and shared ADR chips. On `5c7e68b`, `matrix`/`static` caught the research note's four defects [s8]. Pin-report tests passed ten cases; planted pin-report and builder defects each failed a test. actionlint 1.7.12 and zizmor 1.30.1 found no issues.

## Reversal conditions

- A contributor's agent leaks a restricted term or a secret past the check.
- The merge queue blocks routine work for more than a day.
- An agent writes a human's entry that the human did not instruct.
- Reviewers pin guide items again without reading the source changes, or most pull requests flag most items.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

An admin still turns on the merge queue, or requires branches to be up to date, in the branch rule on `main`.
