---
type: Policy
title: Specification policy
description: Rules for specification layers, invariant tests, runbooks, policy artifacts and the generated guide.
tags: [specs, invariants, testing, runbooks, policy]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T20:31:21Z
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
  - id: s4
    resource: /registers/decision-log.md
    title: Decision log — EM on the onboarding guide (OD-37) and its browser tests, 2026-10-06
  - id: s5
    resource: /adr/012-contributing-with-many-agents.md
    title: ADR 012 — the invariant check in CI, the generated files rebuilt instead of merged, and the guide on GitHub Pages
---

# Specification policy

This policy applies [ADR 004](/adr/004-specifications-and-policy-as-data.md) [s1].

## Three layers

| Layer | Content and maintenance |
|---|---|
| Conceptual specifications | Hand-written architecture, roles, permissions, invariants and threat model. Reviewers read these before code [s1][s2]. |
| API reference | Generated from NatSpec once the factories exist. Behaviour changes update NatSpec and regenerate the reference. Do not edit it by hand [s1]. |
| LIP | Summary for delegates, with links to the conceptual specifications. If they disagree, fix the LIP in the same commit [s1]. |

## Invariants

- Give each invariant a unique `INV-NNN` ID. Never reuse an ID.
- State one testable property and name its ADR. Mark it pending if it depends on an open decision.
- Map each invariant to a named test. CI rejects a missing test or a Draft invariant without one [s5].
- Pending invariants can wait for tests until the end of phase 2. Then CI must reject any invariant without a test [s1].

## Behaviour scenarios

Write scenarios as "WHEN a condition, THEN an expected result". Map each to a scenario test or fork test [s1].

## Runbooks

Give each emergency or technical action a runbook under `docs/runbooks/`, with `type: Runbook` [s1].
Name its `permission` and give the exact transaction for each step.

A runbook can rise above `slop` only with a passing fork `drill` record [s3].
Record the date, network, block and time to initiate. The validator requires that time to be at most six hours [s3].

## The permission policy

Write the policy as a Zodiac constellation in TypeScript.
Clutch's compiler produces one committed artifact with modifier calls, expected trees and allowances [s1].
Each role, target and selector needs one complete tree: a write replaces its slot.

CI rejects an artifact that differs from a fresh compile. Reviewers approve the artifact.
The team uses the Zodiac UI; local tooling must verify its output before signing.
A round-trip check compares the modifier's conditions on a fork with the artifact.
Behaviour tests check each role's allowed and refused actions independently of the encoding.
A policy change can rise above `slop` only with verification output [s3].

## Keeping specifications true

- Derive tests from specifications, never from implementation. Recompute expected values independently [s1][s2].
- Update affected specifications and invariants in the same commit as a behaviour change [s1].
- Specifications reference code. Contract NatSpec must not reference specifications, ADRs or tests.

## The onboarding guide

The [guide](/onboarding/guide.md) is generated from `docs/onboarding/content/` and repository sources [s4].
A change to a decision, role, permission, flow or runbook must update the guide in the same pull request.
Commit the rebuilt page. CI rejects stale output and unresolved references [s4].

Browser tests exercise every control on each pull request [s4].
CI publishes the page from `main` after it checks freshness and the draft disclaimer [s5].
