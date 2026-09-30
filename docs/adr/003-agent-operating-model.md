---
type: Decision
title: "ADR 003: Agent operating model"
description: AGENTS.md is the single source of truth, at most 60 lines of rules, capped by the validator; skills hold procedures; agents never merge, never touch deployed records and never set parameters.
tags: [agents, process, security]
status: draft
review_status: slop
decision: proposed
constrains_operator: false
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the agent operating model, 2026-09-30
  - id: s2
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice — evidence on instruction files, skills and attacks
---

# ADR 003: Agent operating model

## Context

- Context files did not generally improve agent success, and they raised inference cost. Agent-written context files reduced success in most settings. Repository overviews did not help. Specific non-standard rules were followed well [s2].
- Half of the instruction files in one study never changed after their first commit [s2].
- Instruction files and CI workflows are attack surface. A February 2026 campaign rewrote repositories' `CLAUDE.md` files through GitHub Actions [s2].
- Agent Skills are a portable format for procedures. A skill that fails to trigger is the main weakness [s2].

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

An agent drafted this record. It stays `proposed` until EM accepts the text.

## Options considered

- A long `AGENTS.md` with an architecture tour, as in lido-lend-markets. Not chosen: overviews do not help agents [s2].
- No cap. Not chosen: instruction files grow and go stale [s2].

## Consequences

- An agent reads `docs/` on demand instead of loading a long instruction file.
- Parameters stay a human decision. An agent can draft options, never pick one.
- The first `AGENTS.md` is agent-written until EM prunes it. The subgoal "human-written instruction files" is unmet until then.
- A freshness check for instruction files is owed: it must fail on a broken path or on a command that no longer exists. Until it exists, that subgoal is also unmet.
- Of the four skills, only `skills/adr-draft/` exists. The three Clutch-specific skills arrive with the tools they drive in phase 2.

## Confirmation

- The validator fails when `AGENTS.md` exceeds 60 lines or is missing.
- `.github/CODEOWNERS` lists the protected paths. It takes effect once the owning team is set (OD-10).

## Reversal conditions

- Evidence that a longer instruction file improves agent results in this repository.
- A tool that cannot follow a symlinked `CLAUDE.md`.

## Open questions

- OD-10: the owning team for CODEOWNERS.
