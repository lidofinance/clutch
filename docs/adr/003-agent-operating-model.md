---
type: Decision
title: "ADR 003: Agent operating model"
description: Agent rules, instruction-file limits, skills, protected files and human review requirements.
tags: [agents, process, security]
status: draft
review_status: human-reviewed
decision: accepted
accepted_by: human:em
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:57:30Z
verified:
  - by: human:em
    at: 2026-10-05T20:27:31Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted
  - by: human:em
    at: 2026-10-06T06:23:50Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-06--adr-002-and-adr-003-verified-again
  - by: human:em
    at: 2026-10-20T18:46:48Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-20--adr-001-to-adr-004-verified-again-and-yt-registered
    sha256: cc807121e2ac9a378d6cce9cfbaa1c9fb347e9c3d0d2f4d021d13a9fecb901be
  - by: human:em
    at: 2026-10-22T21:59:49Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-22--adr-001-adr-003-and-adr-004-verified-again
    sha256: f6e1f8b3d0ce27dc614564333c6a0868092cad631ae173c65e08576531e80c8e
  - by: human:em
    at: 2026-11-11T05:49:57Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-11-11--adr-001-to-adr-004-verified-again
    sha256: e092343930158cba60bd02192cf82ba208c000f1f22f4c5c7802be2c9ab95b10
  - by: human:em
    at: 2026-11-11T20:36:04Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-11-11--adr-001-to-adr-004-verified-after-the-occam-pass-and-a-second-recording-agent
    sha256: 3e3d0d6472c8b3d2ebd21d7cff6246d0a0efcaf8bae551a447c2891fa4423a65
  - by: human:em
    at: 2026-11-12T14:08:31Z
    recorded_by: claude-code/mythos-5.2
    ref: /registers/decision-log.md#2026-11-12--adr-003-and-adr-004-verified-after-the-switch-to-raw-writes
    sha256: 11585c3c0e341d0e3f2ed8331ba57575dc16bcad8174529c2250be062d5645a4
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the agent operating model, 2026-09-30, and on code owners and the reading of decision 6, 2026-10-05, and on recorded verifications, 2026-10-06
  - id: s2
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice — evidence on instruction files, skills and attacks
---

# ADR 003: Agent operating model

## Context

- Context files generally did not improve agent success and increased inference cost. Agent-written files reduced success in most settings; overviews did not help. Agents followed specific non-standard rules well [s2].
- Half the instruction files in one study never changed after their first commit [s2].
- Instruction files and CI are attack surfaces. A February 2026 campaign rewrote repositories' `CLAUDE.md` files through GitHub Actions [s2].
- Agent Skills provide portable procedures; failure to trigger is their main weakness [s2].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. `AGENTS.md` is the single source of truth for agents. It holds rules only, at most 60 lines, and the validator fails the build above the cap. The map lives in `docs/index.md` (decision log, 2026-09-30).
2. `CLAUDE.md` is a symlink to `AGENTS.md`. Other tool files are added only when a tool is used (decision log, 2026-09-30).
3. An agent drafts the first `AGENTS.md`. EM prunes it by hand (decision log, 2026-09-30).
4. Repeatable procedures are Agent Skills under `skills/`. The ADR-drafting skill is shared with Gaggle. Three skills are specific to Clutch: the permission-change verification procedure, the fork drill runner and a policy diff (decision log, 2026-09-30).
5. Agents may branch, draft, write code and tests, and open pull requests (decision log, 2026-09-30).
6. Agents never merge, never touch `deployed/` and never mark a page reviewed. Agents never change budgets, ceilings, the orders account's token lists, tranche amounts or role membership (OD-43, OD-106).
7. The licence, the security policy, `AGENTS.md`, the actor list and the CI files change only on an explicit human request. CODEOWNERS with required human review covers `AGENTS.md`, `skills/`, the CI files and the permission policy (decision log, 2026-09-30).
8. The fork tests need an archive RPC. Keys never enter the repository or its logs (decision log, 2026-09-30).
9. The `@lidofinance/defi-tech` team owns the repository. `@lidofinance/review-gh-workflows` owns `/.github/`. No new team is created (OD-10).
10. A branch rule on `main` requires a pull request and a code-owner review, allows no direct pushes, and dismisses approvals when new commits arrive (OD-10).
11. Every merge needs at least one approval from someone other than the pull request's creator (OD-10).
12. Replaced by ADR 012 decision 5 (decision log, 2026-10-07).
13. Decision 6 covers production parameters. The kit's dry-run budgets and fixed ceilings are test values, not parameters (OD-25).
14. Decision 6 has one exception. On a human's explicit written instruction, an agent may record that human's own acceptance and verification. The decision log quotes the instruction, the entry names the agent in `recorded_by` and links the quote in `ref`, and the commit message says that the agent made the edit. An agent never records a body's verification ([ADR 002](/adr/002-decision-and-review-process.md) decision 10) (OD-31).

## Options considered

- A long `AGENTS.md` with an architecture tour, as in lido-lend-markets: rejected because overviews did not help agents [s2].
- No cap: rejected because instruction files grow and become stale [s2].
- A cap of about 100 lines, as Gaggle uses: rejected. It is too generous against the evidence [s2].

## Consequences

- Agents read `docs/` on demand.
- Humans choose parameters. Agents can draft options but never pick one.
- The human-written instruction-file goal remains unmet until EM prunes the initial agent draft.
- A freshness check is owed; it must fail on broken paths and obsolete commands. Until it exists, that goal remains unmet.
- The procedures live in `skills/`: `adr-draft`, `decision-interview`, `record-decision`, `guide-update` and `research-note`.
- An agent owns no GitHub account: its work lands through the account of the human who runs it (OD-23, [ADR 012](/adr/012-contributing-with-many-agents.md) decision 5). Another owning-team member must approve; the creator's approval does not count.
- The rules bind only while both owner teams have write access and the branch rule is active. The agent's environment cannot check either.
- A `human:` entry alone no longer proves human authorship. `recorded_by` and the quoted instruction identify agent-recorded entries (decision 14); the register marks them `(recorded)`.

## Confirmation

- The validator fails when `AGENTS.md` exceeds 60 lines or is missing.
- The validator refuses a recorded verification without an agent in `recorded_by`, without a `ref` to a decision-log heading, or on a body's actor.
- `.github/CODEOWNERS` names the owners: `@lidofinance/defi-tech` for everything and `@lidofinance/review-gh-workflows` for `/.github/`. It binds once the branch rule on `main` is on.

## Reversal conditions

- Evidence that a longer instruction file improves agent results in this repository.
- A tool that cannot follow a symlinked `CLAUDE.md`.

## Open questions

None.
