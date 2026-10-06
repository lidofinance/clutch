---
type: Decision
title: "ADR 002: Decision and review process"
description: EM accepts decisions in the interim and the Treasury Management Committee permanently; the Emergency Brakes multisig also verifies every ADR that constrains the operator; pages carry OKF 0.2 trust fields and a review ladder that an edit resets.
tags: [process, review, okf, trust]
status: draft
review_status: human-reviewed
decision: accepted
accepted_by: human:em
constrains_operator: false
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T06:22:07Z
verified:
  - by: human:em
    at: 2026-10-05T20:27:31Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted
  - by: human:em
    at: 2026-10-06T06:23:50Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-06--adr-002-and-adr-003-verified-again
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the acceptor and on Emergency Brakes verification, 2026-09-30, and the confirmed reading, 2026-10-05, and on recorded verifications, 2026-10-06
  - id: s2
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice — the lend-markets review ladder and OKF 0.2
  - id: s3
    resource: "https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/ad30107c31c06aec8a7d5636e0d1058118604e6f/SPEC.md"
    title: Open Knowledge Format 0.2 — trust fields and trust tiers
  - id: s4
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — committee Safes and their quorums
---

# ADR 002: Decision and review process

## Context

- Agents draft most text in this repository. A reader must see what a human has checked.
- lido-lend-markets marks every agent-drafted document with a review status from `slop` to `finalized`, and resets it after a substantial rewrite [s2].
- OKF 0.2 records who generated a page, who verified it, and its sources [s3].
- The Treasury Management Committee operates the vault. The emergency Safe carries the committee's own signers. Without an outside verifier, the committee would approve its own limits.
- The Emergency Brakes multisig is a separate Safe with a quorum of three of five. At block 26092572 it shares no owner address with the committee's Safe [s4]. It holds the technical role in [ADR 005](/adr/005-account-graph-and-roles.md).

## Decision

EM decided on 2026-09-30 [s1]:

1. EM accepts ADRs in the interim. The Treasury Management Committee is the permanent acceptor.
2. An ADR that constrains the committee also needs a verification from the Emergency Brakes multisig before it is accepted. The constraining class covers any ADR that changes the operator's permissions, the emergency powers, the technical role or module disabling, the funding path, or budget and approval ceilings.

The answer about the acceptor did not object to the rest of the positioned process, so the rest is read as accepted [s1]. EM confirmed this reading on 2026-10-05, closing OD-12 [s1]:

3. `docs/` is an OKF 0.2 bundle. Every page carries `generated`, `verified`, `sources`, `status` and `review_status` [s3].
4. `review_status` uses the ladder `slop`, `human-skimmed`, `human-reviewed`, `finalized` [s2]. Agents set only `slop`.
5. A review status above `slop` needs a human verification at or after `generated.at`. An edit that changes the content bumps `generated.at`, so it resets the page to `slop`.
6. ADRs use one global sequence. An ADR moves from `proposed` to `accepted`, `rejected` or `superseded`. `accepted` needs `accepted_by`, a human actor, and that actor's verification after the last edit.
7. An accepted ADR is an engineering decision. It authorises nothing on chain.
8. Decisions made before the repository existed enter as `proposed` ADRs, and EM accepts each text separately.
9. A runbook needs a fork drill record, and a permission-policy change needs the output of the verification procedure, before either rises above `slop`.

EM decided on 2026-10-05, closing OD-15 [s1]:

10. A verification by the committee or by the Emergency Brakes multisig is committed by a member of that body through a reviewed pull request. The entry carries `ref`, an https or urn link to the body's decision record, such as a forum post or minutes.

EM decided on 2026-10-06, closing OD-31 [s1]:

11. Point 4 has one exception. On a human's explicit written instruction, an agent may record that human's own acceptance and verification. The entry names the agent in `recorded_by` and links, in `ref`, the decision-log heading that quotes the instruction. An agent never records a body's verification ([ADR 003](/adr/003-agent-operating-model.md) decision 14).

An agent drafted this record. It stays `proposed` until EM accepts the text.

## How the validator enforces it

`scripts/validate_docs.py` enforces points 2 to 6 and the runbook half of point 9:

- Every ADR declares `constrains_operator: true` or `false`.
- An accepted ADR with `constrains_operator: true` needs a `human:emergency-brakes` verification at or after `generated.at`, in addition to its acceptor's.
- A Runbook names the `permission` it exercises. Above `slop`, it needs a `drill` record with `at`, `network`, `block`, `time_to_initiate_seconds` and `result: pass`, and the time to initiate must not exceed six hours.
- A verification by `human:tmc` or `human:emergency-brakes` needs `ref`, an https or urn link to the body's decision record. Without it, the entry does not count (point 10).
- A verification with `recorded_by` must name an agent and must link, in `ref`, a heading of the decision log. The validator refuses it on a body's actor. The status register marks it `(recorded)` (point 11).

The validator does not yet check the verification-procedure output for a policy change. That check arrives with the procedure in phase 2 of the [roadmap](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md).

## Options considered

- The committee accepts alone. Not chosen: the constrained party would approve its own limits.
- A body's quorum signature: each body signs a Safe message over the page, and a script checks it on chain. Not chosen by EM: every verification would need a signing round.
- The whole DAO accepts every ADR. Not chosen: an ADR authorises nothing on chain, and on-chain changes already need a vote or a motion.
- OKF fields without a review ladder. Not chosen: there is then no review depth between unverified and reviewed.

## Consequences

- Every agent edit to a reviewed page is visible, because the page drops back to `slop`.
- EM accepts a decision with one explicit edit, not in conversation.
- The committee re-ratifies what EM accepted in the interim.
- Known gap: the validator cannot see an edit that leaves `generated.at` unchanged. A CI step that compares each changed page with the base branch closes it. The step is planned for phase 1.
- Known gap: the validator cannot tell who wrote a `human:` entry. Human review of the pull request is the control. CODEOWNERS and the branch rule on `main` enforce it (OD-10, decided 2026-10-05). For the two bodies, the `ref` link makes each entry checkable against the body's own record (point 10). The entry is still a member's claim, not a proof. An entry that an agent records on instruction says so in `recorded_by` (point 11); an entry that does not say so still depends on that review.

## Confirmation

- The validator rejects a review status above `slop` without a current human verification, an accepted ADR without its acceptor's verification, and an accepted constraining ADR without the Emergency Brakes verification.
- The `docs` CI workflow runs the validator and the register check.

## Reversal conditions

- The committee adopts a different process when it takes over as acceptor.
- The review load proves too high for the pace of the work.

## Open questions

None open. OD-12 and OD-15 were decided on 2026-10-05.
