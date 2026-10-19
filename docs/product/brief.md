---
type: Product Brief
title: Clutch product brief
description: System purpose, goals, verification gates, readers and users.
tags: [product, vision, goals, nsm]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T20:31:21Z
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

The Treasury Management Committee puts a bounded part of the DAO treasury to work in approved protocols [s2].
Aragon Voting is the sole owner of the Asset Safe. Recovered assets go to the Aragon Agent (OD-73) [s2].
A default-deny policy limits the committee's actions. An emergency Safe can return assets to the Agent.
Easy Track motions change permissions only through templates fixed at audit time [s2].

## The problem

The system must combine three properties [s2]:

1. The DAO keeps custody.
2. Permissions limit authority before execution.
3. Routine changes avoid a full DAO vote and stay within the authority that the DAO approved.

No existing Lido component provides all three [s2].

## Vision

EM accepted this vision on 2026-09-30 and confirmed it on 2026-10-05 [s1]:

One repository specifies, builds, verifies, deploys and governs the Active Treasury system.
Every permission that can move DAO funds traces to an approved decision and a passing test.

## Goals

EM accepted these goals on 2026-09-30 [s1].

| Goal | Required result |
|---|---|
| Audit-ready | An auditor can reconstruct intent from specifications and ADRs. Each invariant maps to a test. The generated API reference matches the code. |
| Governance-ready | Delegates can read each on-chain action's specification and reproduce its check. The LIP agrees with the specifications. An immutable per-run artifact records deployed addresses and parameters. |
| Agent-operable, human-certified | Agents draft and test. Humans review and finalize. The validator enforces verification rules. Human-written instruction files stay short and current; CI checks them. |
| Operable | Signers can follow runbooks without code. Each emergency or technical step gives the exact transaction and has a fork drill. Alerts map to steps, and steps map to permissions. |

The general Lido incident process owns paging and escalation. This repository supplies the vault-specific steps and transactions [s1].

## North Star Metric

Measure the time for a reviewer who did not write a permission change to verify it end to end [s1].
One command reproduces the permission diff, runs the affected tests and checks traceability.
Time starts with the procedure and ends with the verdict; it excludes the review queue.
Review is the bottleneck when agents write most code. Each Easy Track permission change needs that review [s3][s1].

## Hard gates

Each gate must hold at 100 percent [s1]:

- **Traceability:** each permission traces to a specification clause, ADR, test and deployed artifact.
- **One-command verification:** one command verifies a permission change.
- **Six hours:** a fork drill proves that each emergency action starts within the mandate's six-hour ceiling.

## Submetrics

Track these measures [s1]:

- Open decisions and pages per review status.
- Invariants without tests and instruction-file freshness failures in CI.
- Time from ADR acceptance to merged code.
- Time to initiate each emergency action in a drill.
- Alerts without runbook steps and steps without permissions.

## Readers

Prioritize readers by the cost of a misreading. If their needs conflict, the higher-ranked reader takes priority [s1]:

1. **Signers:** operator and emergency runbooks. A misread during a depeg can lose funds in minutes.
2. **Auditors and reviewers:** missed defects can cause later losses.
3. **DAO voters and delegates:** the LIP supports the final human check.
4. **Coding agents:** human review must catch their errors.

## Users of the system

The system's users are the Lido DAO, which owns the assets and governs the policy, and the committee, which operates the vault [s1].
