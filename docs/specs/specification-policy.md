---
type: Policy
title: Specification policy
description: How Clutch specifications are written and kept true — three layers, invariant IDs that map to tests, when-then scenarios, runbooks with drill records, the policy data file with a round-trip check, and the same-commit rule.
tags: [specs, invariants, testing, runbooks, policy]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T08:05:00Z
verified: []
sources:
  - id: s1
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — specifications and the permission policy as data
  - id: s2
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice — lend-markets specification layers
  - id: s3
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — the runbook and policy-change gates
---

# Specification policy

This policy applies [ADR 004](/adr/004-specifications-and-policy-as-data.md) [s1].

## Three layers

- **Conceptual specifications** are written by hand. They hold the architecture, the roles matrix, the permission model, the invariants and the threat model: what a reviewer needs before reading code [s1][s2].
- **The API reference** is generated from NatSpec once the factories exist. Nobody edits it by hand. A change to a function's behaviour changes its NatSpec, and the reference is regenerated [s1].
- **The LIP** is the external layer for delegates. It summarises and cites the conceptual specifications. It must never contradict them. When the two disagree, the conceptual specification wins and the LIP is fixed in the same commit [s1].

## Invariants

- Each invariant has an ID `INV-NNN`. An ID is never reused.
- Each invariant states one property that a test can check.
- Each invariant maps to at least one named test. CI fails when an invariant has no test, once the check exists [s1].
- Each invariant names the ADR that sets it. An invariant that depends on an open decision is marked "pending".

## Behaviour scenarios

Behaviour is written as "WHEN a condition, THEN an expected result". A scenario maps to a scenario test or a fork test [s1].

## Runbooks

- Each emergency or technical action has one runbook under `docs/runbooks/`, with `type: Runbook` [s1].
- A runbook names the `permission` it exercises and gives the exact transaction for each step.
- A runbook rises above `slop` only with a `drill` record: when, on which network and block, the time to initiate, and a passing result. The time to initiate must not exceed six hours. The validator enforces this [s3].

## The permission policy

- The policy is written as a Zodiac constellation in TypeScript. Clutch's compiler turns it into one committed artifact: the modifier calls, the expected trees and the allowances [s1].
- The compiler emits one complete tree per role, target and selector, because a write replaces the slot.
- CI fails when the committed artifact differs from a fresh compile. Reviewers approve the artifact.
- The team works in the Zodiac UI. Local tooling verifies everything that the UI produces before anything is signed.
- A round-trip check reads the applied conditions back from the modifier on a fork and compares them with the committed artifact.
- Behaviour tests assert what each role can and cannot do, independent of the encoding.
- A policy change rises above `slop` only with the output of the verification procedure [s3].

## Keeping specifications true

- Tests derive from the specifications, never from the implementation. Expected values are recomputed independently [s1][s2].
- A pull request that changes behaviour changes the affected specification and invariants in the same commit [s1].
- Specifications reference the code. Contract NatSpec never references specifications, ADRs or tests.
