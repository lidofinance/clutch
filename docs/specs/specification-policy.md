---
type: Policy
title: Specification policy
description: Rules for invariants and their tests, behaviour scenarios, runbooks and the policy artifact.
tags: [specs, invariants, testing, runbooks, policy]
status: draft
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:24:01Z
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
  - id: s5
    resource: /adr/012-contributing-with-many-agents.md
    title: ADR 012 — the invariant check in CI, the generated files rebuilt instead of merged, and the guide on GitHub Pages
---

# Specification policy

This policy applies [ADR 004](/adr/004-specifications-and-policy-as-data.md), which sets the three layers: conceptual specifications written by hand, an API reference generated from NatSpec, and the LIP [s1].

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

A runbook can rise above `slop` only with a passing fork `drill` record: the time, network, block and time to initiate, which must be at most six hours. The validator enforces this [s3].

## The permission policy

Each role, target and selector needs one complete tree: a write replaces its slot.
CI rejects an artifact that differs from a fresh compile, and reviewers approve the artifact [s1].
A change after launch is a motion of the universal factory ([ADR 013](/adr/013-one-easy-track-factory.md)); local tooling verifies its writes before signing.
A round-trip check compares the modifier's conditions on a fork with the artifact.
Behaviour tests check each role's allowed and refused actions independently of the encoding.
A policy change can rise above `slop` only with verification output [s3].

## Keeping specifications true

- Derive tests from specifications, never from implementation. Recompute expected values independently [s1][s2].
- Update affected specifications and invariants in the same commit as a behaviour change [s1].
- Specifications reference code; code does not reference specifications. A contract's comments cite no ADR, open decision, invariant, specification or test, and `scripts/check_licences.py` refuses one (OD-123).
