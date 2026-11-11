---
type: Decision
title: "ADR 012: Contributing with many agents"
description: Contribution, human verification, decision interviews, CI, generated files, guide source pins, and pages that show the current design only.
tags: [agents, contributors, process, security, ci]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T07:42:18Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on contributors and their agents (2026-10-07), the guide's checks (2026-10-12), the generated registers (2026-10-14), and decisions on build branches, the activity log and current-design pages (2026-11-10)
  - id: s2
    resource: /research/contributor-readiness-2026-10-07.md
    title: Research note — file churn, the actor list, CI coverage, unsafe defaults, the fifteen steps and the keystore rehearsal
  - id: s3
    resource: /adr/003-agent-operating-model.md
    title: ADR 003 — the agent operating model
  - id: s4
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — who accepts and who verifies
  - id: s5
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the hosted Zodiac app is outside the path, and the repository-owner team holds its key
  - id: s8
    resource: /research/guide-invariants-2026-10-12.md
    title: Research note — the guide's defects in print and without its script, and the churn of whole-ADR pins
---

# ADR 012: Contributing with many agents

## Context

- EM wants more contributors, each with their own agent, without conflicting merges [s1].
- Many contributors edit shared files; mainnet and hosted-app scripts sit beside safe commands; restricted terms need a check, not a convention [s2].
- [ADR 003](/adr/003-agent-operating-model.md) holds the agent rules [s3]. [ADR 002](/adr/002-decision-and-review-process.md) defines acceptance and verification [s4].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Any agent may author a page: `generated.by` accepts any agent id of the form `<runner>/<model>`. Only the humans and teams that `config/actors.yaml` lists verify a page (decision log, 2026-10-07; OD-50).
2. `CODEOWNERS` does not change for now (decision log, 2026-10-07).
3. A change lands on `main` through a merge queue, or, without one, only when its branch is up to date with `main`. The checks run on the merged result (decision log, 2026-10-07).
4. An agent opens a decision only as a complete row of the open-decision register: the question with its options, the page that closes it, its recommendation and who decides. EM triages the open decisions and decides them in batched interviews. One decisions branch is open at a time, and a decision may also be recorded on the build branch that raised it (decision log, 2026-10-07; OD-124).
5. Agents own no GitHub accounts. An agent's work lands through the account of the human who runs it. Each commit carries a `Co-Authored-By` trailer for the agent, and each page names the agent in `generated.by` (decision log, 2026-10-07; OD-23).
6. A team verifies through a member, with `ref` to the pull request that the member approved. `human:defi-tech` is the first team. A team's verification raises a page's review status and never accepts an ADR: only EM or the committee accepts one (OD-50).
7. Each verification records `sha256`, the hash of the page's body. `just verify` writes the entry. The validator fails when the body differs from the hash of the latest verification, until a human verifies the page again. Verifications before 2026-10-07 carry no hash (OD-51).
8. The fork suite stays out of CI until phase 2 of the roadmap. Then it runs in the merge queue and on pushes to `main`, with the archive RPC key as a repository secret, never on a pull request (OD-52).
9. The request for solution's allocation figures are not restricted. The README opens with a disclosure: everything in the repository is a draft and not ratified, and every number is speculative (OD-53).
10. A CI workflow publishes the onboarding guide on GitHub Pages from `main`. The page says that it is a hypothetical draft: nothing is deployed or ratified, every number can change, and it is not advice (decision log, 2026-10-07; OD-95).
11. The onboarding guide carries every check of the triage of 2026-10-12 [s8]. The browser tests check every presentation state and the page without its script. Each item is pinned to the text of its sources, and a reference names a decision or a section of an ADR, not the whole ADR. Every ADR, invariant, LIP part and runbook is cited by the guide or excluded with a reason. CI attaches the built page to each pull request, reports the pin changes, checks the workflows, and checks the guide's outside links each week (decision log, 2026-10-12).
12. The diagrams, in the guide and in the LIP draft, carry no node for the Emergency Brakes multisig. The guide states two facts about it: it can pause Easy Track, and two of the emergency Safe's five signers come from it (OD-81).
13. The closed decisions live in `docs/registers/closed-decisions.yaml`, each with its question, date, decision-log headings, ADR decisions and the earlier ODs that it replaces or refines; the open-decision register lists open items only. `validate_docs.py --write-status` generates the ADR index and each proposed ADR's open decisions, and `--check-status` fails on a stale block. The validator fails on an unknown heading, decision or OD in the data, on a replacement of a later OD and on a skipped OD number; the guide's build refuses a source that names a replaced OD, and an item whose text names an OD that its sources do not cite. There is no activity log: git and the decision log keep the history (OD-82, OD-127).
14. Pages other than the decision log show the current design only. An ADR keeps every decision number. A replaced decision becomes one line, "Replaced by …" or "Lapsed …", with the OD that ended it, and the guide may not cite that line. An amended decision carries its current text with the ODs that shaped it. A page states no history of earlier designs: the decision log, the closed register and git keep it (OD-128).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

`CONTRIBUTING.md` holds the workflow and the commands, `AGENTS.md` the agent rules, and [guide maintenance](/onboarding/guide.md) the guide's build, pins and tests. The bullets add only what those pages do not state.

- **One owner per fact.** A page states a fact once, where it belongs, and other pages point to it: a decision in its ADR; EM's words and the history in the decision log; a property and its tests in the invariants; a value in the parameters; a control in the control matrix; a failure in the threat model; the vote's content in the enabling-vote specification; the workflow in `CONTRIBUTING.md`; evidence in a research note. A decision that another decision states in full becomes one line, "Stated by …", and the guide may not cite that line.
- **Safe defaults.** The `Justfile` never loads `mainnet.just`. The mainnet recipes refuse CI and a `PRIVATE_KEY`. The hosted-app scripts, which only the owner team runs [s5], refuse CI.
- **Identity and verification.** Only listed agents record a human's verification ([ADR 003](/adr/003-agent-operating-model.md) decision 14). `just verify <page> <human>` runs `scripts/verify_page.py`; the hash covers the body, not the front matter.
- **Redaction.** `scripts/check_redaction.py` compares files with salted hashes in `config/redaction.yaml`, and rejects private keys, keyed RPC URLs and API tokens. A finding shows the file, line and kind, never the value.
- **Merge queue.** Workflows run on `merge_group`. An admin turns the queue on, or requires up-to-date branches, in the branch rule on `main`.
- **Generated files.** `.gitattributes` marks the status register and the guide. Policy artifacts stay unmarked, because reviewers read their diffs.
- **Pull requests.** The template asks for the agent, the human checks, the commands run and the restricted-data confirmation.
- **GitHub Pages.** `.github/workflows/pages.yml` checks the page's freshness and its disclaimer, and deploys it with `noindex` and a `robots.txt` that asks crawlers to stay away. Only the deploy job writes Pages; pull requests never deploy.
- **Guide checks** [s8]. Guide maintenance describes the `matrix` and `static` browser groups, `docs/onboarding/pins.json` and `docs/onboarding/content/coverage.yaml`. Dark styles apply only to screens. The `docs` workflow reports pin changes through `scripts/pin_report.py`; actionlint and zizmor 1.30.1 check the workflows; `scripts/check_links.py` checks the outside links.

## Options considered

- Each agent listed by hand: not chosen. Contributors would need protected-file edits.
- Agent GitHub accounts: not chosen (decision 5).
- Risk-based CODEOWNERS: deferred (decision 2).
- Merges without a queue or up-to-date branches: not chosen. Two green pull requests can produce a failing `main`.
- Free-text decisions: not chosen. A question needs its options and a recommendation.
- Per-reviewer IDs: not chosen. Team IDs avoid names, and the pull request names the approver.
- Verification rules in prose only: not chosen. A hash detects an edit without the history.
- Keyed fork tests on pull requests: not chosen. Submitted code could read the key.
- Restricted request-for-solution figures: not chosen. They went to the provider, and the README labels every figure as a draft.
- An activity log beside git and the decision log: not chosen (decision 13). It restated both.
- Pages that keep replaced decisions in full: not chosen (decision 14). Readers met each earlier design as if it held.

## Consequences

- The queue increases merge time to keep `main` green.
- EM remains the decision bottleneck; batched interviews reduce interruptions.
- Hashed redaction lists deter casual discovery, not guessing.
- Until phase 2, broken fork tests need not make CI red.
- Local anvil rehearsals may use one public test `PRIVATE_KEY` for one command.
- The guide's source links work for every reader, because the repository is public (OD-95).
- A change of design rewrites the decision in place, so the pins of the guide items that cite it go stale and need a review (decision 14).

## Confirmation

- `scripts/test_validate_docs.py` permits any agent author and refuses unlisted human authors and verifiers and agent verifiers. It checks unique OD, INV and ADR IDs, complete decision rows, team verification through pull requests and the refusal of team acceptance, and that a verification since 2026-10-07 carries the hash that a later edit breaks.
- `scripts/test_checks.py` covers restricted content, secrets, licence lines, contract comments and invariants.
- `bun test compiler` checks the owner guard's refusals: without a confirmation, in CI, outside `main` and with local changes.
- `scripts/test_build_onboarding.py` and the browser tests cover the disclaimers, `noindex`, coverage, the map rules, the refusal of whole-ADR and stub citations, the pins and the presentation states; actionlint and zizmor find no issue in the workflows.
- The anvil-keystore rehearsal of the dry run covered deploy, apply, fund, teardown and the refusals [s2].

## Reversal conditions

- A contributor's agent leaks a restricted term or a secret past the check.
- The merge queue blocks routine work for more than a day.
- An agent writes a human's entry that the human did not instruct.
- Reviewers pin guide items again without reading the source changes, or most pull requests flag most items.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
