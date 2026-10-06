---
type: Register
title: Verification requests
description: What each record that constrains the operator asks the Emergency Brakes multisig to check, the duties those records give the multisig, and how a member records the multisig's verification.
tags: [verification, emergency-brakes, process]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T06:59:08Z
verified: []
sources:
  - id: s1
    resource: /adr/002-decision-and-review-process.md
    title: ADR 002 — the Emergency Brakes multisig verifies every record that constrains the operator; a member records a body's verification with `ref`; an edit resets a verification
  - id: s2
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the technical role, the Easy Track pause, the emergency Safe, and decisions 16 to 18
  - id: s3
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 decision 24 — the fixed trigger for a cap breach that gets worse
  - id: s4
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — the Easy Track pause as a final stop for a motion
  - id: s5
    resource: /registers/decision-log.md
    title: Decision log — EM on OD-15, OD-29, OD-30, OD-31 and OD-32
  - id: s6
    resource: /runbooks/index.md
    title: Runbooks — the two runbooks that the Emergency Brakes multisig holds
  - id: s7
    resource: /specs/lip-draft.md
    title: LIP draft, section 6.2 — the owner path restores the operator modifier by enabling it again
---

# Verification requests

## Why the multisig verifies

- A record that constrains the operator needs a verification from the Emergency Brakes multisig before EM accepts it [s1].
- ADR 005 to ADR 011 constrain the operator. On 2026-10-06 all seven are `proposed`, and their text is frozen for this request.
- A verification means that the multisig read the record, finds its constraints on the operator sound from the view of emergency response and technical risk, and accepts the duties that the record gives it. It is not an audit, a legal review or a governance approval.
- An edit to a record after the verification resets it. The multisig then verifies the new text again [s1].

## The duties that the records give the multisig

Read these first. A verification of ADR 005 and ADR 009 accepts them.

1. **Disable the operator modifier for a defect in the permission layer.** The technical role calls `disableModule` on the Asset Safe, for the operator modifier only: the module argument is pinned. The safety modifier keeps working, so the emergency Safe can still exit and return assets to the Aragon Agent. Only the Safe's owner, the Aragon Agent through a DAO vote, enables it again [s2][s7].
2. **Disable the operator modifier when a cap breach gets worse (OD-29).** The trigger is fixed: a published cap breach that is still there after the committee's rebalancing window of two working days, and that is larger at the next fortnightly snapshot. Monitoring publishes the cap reading of each fortnightly snapshot to IPFS, and its alert links that reading when it pages the multisig (OD-32). The multisig needs no financial judgment. A DAO vote can also disable the modifier [s3][s5].
3. **Pause Easy Track.** The multisig keeps the global Easy Track pause. It is the final stop for a motion that survives its objection window, and it freezes queued motions during an incident [s2][s4]. The pause stops every Easy Track motion of the DAO, not only the vault's, and the multisig cannot unpause: only the DAO resumes Easy Track [s2][s7].
4. **Be the independent stop, not the exit (OD-30).** The fast exit is the emergency Safe: the committee's signers at two of seven. No body that is independent of the committee can return assets within six hours. The multisig can only stop the operator, and the independent way to move assets is a DAO vote, which takes days [s2][s5].

The multisig gets no power over assets or permissions, and it cannot disable the safety modifier [s2]. It holds two runbooks: disable the operator modifier, and pause Easy Track [s6].

## What each record asks

| Record | What it requires of the operator | What it asks of the multisig | Read closely |
|---|---|---|---|
| [ADR 005](/adr/005-account-graph-and-roles.md): account graph and roles | The operator Safe, four of seven and screened, holds only the operator role. The emergency Safe, two of seven, holds the emergency role. Apart from positions that pay back to the Asset Safe, an asset leaves it only to the Aragon Agent or to a swap instance. | Duties 1, 2, 3 and 4 | The roles table, and decisions 16 to 18 |
| [ADR 006](/adr/006-governance-through-easy-track-factories.md): governance through Easy Track factories | The operator Safe creates every motion. A motion only expands the policy. Every removal is the emergency Safe's immediate revoke. | Duty 3 | Decision 4, and the consequence on queued motions |
| [ADR 007](/adr/007-swapping-through-stonks.md): swapping through Stonks 2.0 | Every swap goes through a pinned instance. The operator Safe manages the rebalancing instances. Recovery has ten instances. | None | The recovery set, and what happens when a price feed breaks |
| [ADR 008](/adr/008-funding-through-existing-payments.md): funding | Top-ups pay only the Asset Safe, within two monthly registry limits. Neither role redeems the first-loss Earn shares. | Duty 3 applies to top-up motions | The two gaps of the registries |
| [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md): budgets, caps, reporting and monitoring | Each approval spends its spender's budget or stays below a fixed ceiling. Caps are detective, and reports go to IPFS. | Duty 2 | Decision 24, and the monitoring list |
| [ADR 010](/adr/010-pre-execution-screening.md): pre-execution screening | Every operator Safe transaction needs the screening vendor's approval, and the guard fails closed. | None: the multisig and recovery are never screened | Failure behaviour |
| [ADR 011](/adr/011-launch-scope.md): launch scope | Only the launch assets and venues. No third-party lending market. | None | The asset table |

## How a member records the verification

1. The multisig decides, and records its decision in a forum post or in minutes [s1]. A private record can be cited with a `urn:` link.
2. A member opens a pull request that adds this entry to the `verified` list of each record that the multisig verifies:

   ```yaml
     - by: human:emergency-brakes
       at: 2026-10-20T12:00:00Z   # when the entry is made; later than the record's generated.at
       ref: https://example.org/record   # or urn:..., the multisig's decision record
   ```

3. The validator refuses the entry without `ref`. An agent never writes this entry [s1][s5].
4. EM accepts each record in the same pull request or right after it. The [document-status register](/registers/document-status.md) then shows both verifications.
