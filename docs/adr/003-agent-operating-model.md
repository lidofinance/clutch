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
  by: claude-code/opus-5.5
  at: 2026-10-19T22:29:31Z
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

EM accepted the positioned model on 2026-09-30, with the line cap enforced by the validator [s1]:

1. `AGENTS.md` is the single source of truth for agents. It holds rules only, at most 60 lines, and the validator fails the build above the cap. The map lives in `docs/index.md`.
2. `CLAUDE.md` is a symlink to `AGENTS.md`. Other tool files are added only when a tool is used.
3. An agent drafts the first `AGENTS.md`. EM prunes it by hand.
4. Repeatable procedures are Agent Skills under `skills/`. The ADR-drafting skill is shared with Gaggle. Three skills are specific to Clutch: the permission-change verification procedure, the fork drill runner and a policy diff.
5. Agents may branch, draft, write code and tests, and open pull requests.
6. Agents never merge, never touch `deployed/` and never mark a page reviewed. Agents never change budgets, approval ceilings, swap instance settings, funding limits, factory allowlists or role membership.
7. The licence, the security policy, `AGENTS.md`, the actor list and the CI files change only on an explicit human request. CODEOWNERS with required human review covers `AGENTS.md`, `skills/`, the CI files and the permission policy.
8. The fork tests need an archive RPC. Keys never enter the repository or its logs.

Rejected: the cap of about 100 lines that Gaggle uses. It is too generous against the evidence [s2].

EM decided on 2026-10-05, closing OD-10 [s1]:

9. The `@lidofinance/defi-tech` team owns the repository. `@lidofinance/review-gh-workflows` owns `/.github/`. No new team is created.
10. A branch rule on `main` requires a pull request and a code-owner review, allows no direct pushes, and dismisses approvals when new commits arrive.
11. Every merge needs at least one approval from someone other than the pull request's creator.
12. The agent's own GitHub identity comes later (OD-23).

EM confirmed on 2026-10-05, closing OD-25 [s1]:

13. Decision 6 covers production parameters. The kit's dry-run budgets and fixed ceilings are test values, not parameters.

EM decided on 2026-10-06, closing OD-31 [s1]:

14. Decision 6 has one exception. On a human's explicit written instruction, an agent may record that human's own acceptance and verification. The decision log quotes the instruction, the entry names the agent in `recorded_by` and links the quote in `ref`, and the commit message says that the agent made the edit. An agent never records a body's verification ([ADR 002](/adr/002-decision-and-review-process.md) point 10).

## Options considered

- A long `AGENTS.md` with an architecture tour, as in lido-lend-markets: rejected because overviews did not help agents [s2].
- No cap: rejected because instruction files grow and become stale [s2].

## Consequences

- Agents read `docs/` on demand.
- Humans choose parameters. Agents can draft options but never pick one.
- The human-written instruction-file goal remains unmet until EM prunes the initial agent draft.
- A freshness check is owed; it must fail on broken paths and obsolete commands. Until it exists, that goal remains unmet.
- Of the four planned skills, only `skills/adr-draft/` exists. The three Clutch-specific skills arrive with their tools in phase 2.
- Until an agent has its own GitHub identity, it uses the creator's git identity. Another owning-team member must approve; the creator's approval does not count.
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

- OD-23: when the agent gets its own GitHub identity.
