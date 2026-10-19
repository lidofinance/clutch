---
type: Decision
title: "ADR 002: Decision and review process"
description: ADR acceptance, human verification, review states and validator limits.
tags: [process, review, okf, trust]
status: draft
review_status: slop
decision: accepted
accepted_by: human:em
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T20:46:17Z
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
    at: 2026-10-13T09:03:50Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-13--adr-002-verified-again-the-first-loss-holder-and-od-64
    sha256: eb19c8a2f7b4ce5a182f4f5760a7d5e80459a801b201278d7cbdba684cb0c7e5
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the acceptor and on Emergency Brakes verification, 2026-09-30, and the confirmed reading, 2026-10-05, on recorded verifications, 2026-10-06, and on the end of the Emergency Brakes verification, 2026-10-13
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

- Readers must distinguish agent drafts from human-reviewed text.
- lido-lend-markets uses review states from `slop` to `finalized` and resets them after substantial rewrites [s2].
- OKF 0.2 records a page's author, verifiers and sources [s3].
- The committee operates the vault and supplies emergency signers. Without outside verification, it would approve its own limits.
- At block 26092572, the three-of-five Emergency Brakes Safe shared no owner address with the committee's Safe [s4]. It held ADR 005's technical role until 2026-10-13.
- On 2026-10-13, the emergency Safe became three-of-five: two committee members, two Emergency Brakes members and one member of neither body. The Emergency Brakes multisig lost all vault roles ([ADR 005](/adr/005-account-graph-and-roles.md), decisions 23 and 24).

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

EM decided on 2026-10-13, closing OD-63 [s1]:

12. The Emergency Brakes multisig no longer verifies an ADR before it is accepted, and nothing replaces it. This replaces decision 2. Decision 10 now covers the committee only.

## How the validator enforces it

`scripts/validate_docs.py` enforces decisions 3–6 and the runbook part of decision 9:

- A Runbook names its `permission`. Above `slop`, its `drill` needs `at`, `network`, `block`, `time_to_initiate_seconds` and `result: pass`. The time must not exceed six hours.
- A `human:tmc` verification needs an https or urn `ref` to the committee's decision record; otherwise it does not count (decision 10).
- A recorded verification names an agent in `recorded_by` and links a decision-log heading in `ref`. The validator rejects it for a body's actor. The status register marks it `(recorded)` (decision 11).

The validator does not yet check policy-verification output. That check arrives with the procedure in [roadmap](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) phase 2.

## Options considered

- Committee-only acceptance: rejected because the committee would approve its own limits.
- Quorum signatures over pages: EM rejected this because each verification would need a Safe signing round and an on-chain check.
- DAO acceptance of each ADR: rejected because ADRs authorize no on-chain action; votes and motions already govern those actions.
- OKF fields without review states: rejected because they would not distinguish review depth.
- Emergency Brakes verification of constraining ADRs: EM replaced this on 2026-10-13 (decision 12). The multisig has no vault role, and ADR acceptance authorizes no on-chain action.

## Consequences

- Agent edits reset reviewed pages to `slop`.
- EM accepts through an explicit edit. The committee re-ratifies interim acceptances.
- The validator cannot detect a body edit that leaves `generated.at` unchanged. A base-branch comparison is planned for phase 1.
- The validator cannot identify who wrote a `human:` entry. Pull request review, CODEOWNERS and the `main` branch rule provide that control (OD-10, 2026-10-05).
- A committee verification's `ref` makes the member's claim checkable against the decision record (decision 10). It is not proof of authorship.
- `recorded_by` identifies an entry made on instruction (decision 11). Entries without it still depend on human review.

## Confirmation

- The validator rejects a review status above `slop` without a current human verification, and an accepted ADR without its acceptor's verification.
- The `docs` CI workflow runs the validator and the register check.

## Reversal conditions

- The committee adopts a different process when it takes over as acceptor.
- The review load proves too high for the pace of the work.

## Open questions

None open. OD-12 and OD-15 were decided on 2026-10-05, and OD-63 on 2026-10-13.
