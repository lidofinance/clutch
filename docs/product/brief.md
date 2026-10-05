---
type: Product Brief
title: Clutch product brief
description: What the Clutch repository is for — the system it records, the problem, the vision, four goals, the North Star Metric, three hard gates, the ranked readers and the system's users.
tags: [product, vision, goals, nsm]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T11:33:11Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's repository-setup answers of 2026-09-30, and the confirmed vision reading, 2026-10-05
  - id: s2
    resource: /specs/lip-draft.md
    title: LIP draft — Active Treasury Management Vault
  - id: s3
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice, September 2026 — review is the bottleneck
---

# Clutch product brief

## The system

- Clutch is the Lido Active Treasury system. The Treasury Management Committee puts a bounded part of the DAO treasury to work in approved protocols [s2].
- The DAO keeps custody. The Aragon Agent is the only owner of the Safe that holds the assets [s2].
- A default-deny permission policy decides what the committee can do. An emergency Safe can return the assets to the Agent [s2].
- Easy Track motions change the policy only inside templates that are fixed at audit time [s2].

## The problem

Three properties must hold together, and no existing Lido component gives all three [s2]:

1. Custody stays with the DAO.
2. Authority is bounded before execution, not after.
3. Routine changes do not need a full DAO vote, and they cannot widen authority past what the DAO approved.

## Vision

EM accepted this vision on 2026-09-30, and confirmed that reading of the answer on 2026-10-05 [s1]:

One repository from which the Active Treasury system is specified, built, verified, deployed and governed. Every permission that can move DAO funds traces back to an approved decision and forward to a passing test.

The repository is a decision-and-verification record that happens to compile. It is not a code repository with documents attached [s1].

## Goals

EM accepted four goals on 2026-09-30 [s1].

**Audit-ready.** An auditor can reconstruct intent from the specifications and ADRs without asking the team.

- Every invariant maps to a test.
- The generated API reference never drifts from the code.

**Governance-ready.** Every on-chain action has a specification that a delegate can read and a check that anyone can reproduce.

- The LIP and the internal specifications never contradict each other.
- Every deployed address and parameter is in an immutable per-run artifact.

**Agent-operable, human-certified.** Agents do most of the drafting and testing. Only a human moves a page to reviewed or finalized.

- A validator enforces the review ladder. An agent can never write a human verification.
- Instruction files stay short, human-written and current. CI checks them.

**Operable.** A signer can act correctly under pressure without reading code.

- Every emergency and technical action has a runbook step with the exact transaction, drilled on a fork.
- Every monitoring alert maps to a runbook step, and every runbook step maps to a permission.
- The general Lido incident process owns paging and escalation. This repository owns the vault-specific steps and transactions.

## North Star Metric

The time for a reviewer who did not write a permission change to verify it end to end [s1].

It is measured as a timed verification procedure. One command reproduces the permission diff, runs the affected tests and checks traceability. The clock runs from the start of the procedure to the reviewer's verdict. Time waiting in a review queue does not count [s1].

Why this metric: review, not generation, is now the bottleneck in repositories where agents write much of the code [s3]. This system changes through Easy Track motions, and someone must verify each one.

## Hard gates

Each gate must hold at 100 percent. They are gates, not metrics [s1].

1. **Traceability.** Every permission traces to a specification clause, an ADR, a test and a deployed artifact.
2. **One-command verification.** Every permission change is verifiable by one command.
3. **Six hours.** Every emergency action is initiated within the mandate's six-hour ceiling, proven in fork drills.

## Submetrics

These come from the same decision [s1]:

- Open decisions.
- Pages per review status.
- Invariants without a test.
- Instruction-file freshness failures in CI.
- Time from an accepted ADR to merged code.
- Drill time to initiate, per emergency action.
- Alerts without a runbook step.
- Runbook steps without a permission.

## Readers

The readers are ranked by the cost of a misreading. When needs conflict, the higher-ranked reader wins [s1].

1. **Signers**, operator and emergency, through the runbooks. A misread runbook during a depeg loses funds in minutes.
2. **Auditors and reviewers.** A missed issue loses funds later and less often.
3. **DAO voters and delegates**, through the LIP. The vote is the last human check.
4. **Coding agents.** The review gates exist to catch their misreadings. Structure serves them more than content does.

## Users of the system

The users of the system are not the readers of the repository [s1]:

- **The Lido DAO**, which owns the assets and governs the policy.
- **The Treasury Management Committee**, which operates the vault.
