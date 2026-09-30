---
type: Decision
title: "ADR 009: Budgets, exposure caps, reporting and monitoring"
description: Exposure caps are detective controls with reports on IPFS; budgets derive from the mandate by attested computation and retune every two weeks; detectors run in two monitoring estates; the committee owns ratio-breach remediation.
tags: [budgets, caps, reporting, monitoring, mandate]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on detective enforcement, budgets, reporting and monitoring, 2026-09-22
  - id: s2
    resource: /specs/lip-draft.md
    title: LIP draft — budgets, reporting and detective controls
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/Drills.t.sol#L650"
    title: Kit test at 370e20a — budget consumption, exhaustion and refill
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/NoNewContract.t.sol#L82"
    title: Kit test at 370e20a — allowance ceilings and the refill-period floor
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L307"
    title: Kit test at 370e20a — an unlimited approval is refused
---

# ADR 009: Budgets, exposure caps, reporting and monitoring

## Context

- The permission layer cannot see valuation. It can bound a call, not a portfolio ratio [s2].
- A budget is a consumable allowance per key. A call consumes it only on success, and it refills per elapsed period up to a maximum [s3].
- A budget counts token units, so assets with different decimals need different keys [s2].

## Decision

EM decided on 2026-09-22 [s1]:

1. Accept detective enforcement with reporting. Reports rely on data published to immutable storage.
2. Reports go to IPFS. DataBus is not used, at least for now.
3. Budgets derive from the mandate, by an attested computation that actually runs.
4. The whole vault may sit in Lido products.
5. Budgets retune every two weeks.
6. The committee owns ratio-breach remediation. If a breach gets worse, the escalation is a pause of the whole module.
7. Detectors run in the Lido on-chain monitoring and in the screening vendor's service.
8. Paging and escalation run through the general Lido incident process.

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

- **Caps are detective.** The mandate must say that exposure caps are enforced by measurement, publication and remediation, not by reverting a transaction.
- **Which caps need prices.** A cap within one denomination needs balances only. A cap on a liquid staking token or on a yield-bearing asset needs on-chain rates. A cap across classes needs a market oracle.
- **Budget shape.** Monthly flow equals the stock cap for each key. Exits are unbudgeted, so a tighter flow would throttle re-entry after a defensive exit. Keys for Lido products have no ratio to bound, because the whole vault may sit in them. They bound only the amount that can move in one month, which is the whole mandate. That is a weak control, and the LIP must say so.
- **Budget figures.** The attested computation ran on 2026-09-22 with an independent attester and pinned inputs. Its inputs include unapproved mandate terms, so its results enter this repository only after the mandate is approved.
- **Approvals.** An operator approval is either zero or below a per-token ceiling. The proposed ceiling is one deposit, not one month of deposits (OD-08).
- **Refill floor.** A motion cannot set a refill period below a floor. The proposed floor is 30 days (OD-08).
- **Reports.** The payload is on IPFS and holds balances, positions, exposures, each ratio with its numerator and denominator, and the price source with its timestamp. Where a report justifies a top-up, its content identifier goes in the payment's `reference` field, which lands in an Ethereum event.
- **Monitoring.** The Lido on-chain monitoring carries policy drift, the approval inventory, budget burn, module and owner changes on both Safes, and motion events. The screening vendor carries depegs, protocol compromise and counterparty anomalies. Findings route into the existing notification and incident channels.

## Options considered

- Preventive caps through a custom condition adapter. Not chosen: the adapter is a static call, so it cannot keep a ledger, and a check of the current state admits a transaction that breaches the cap right after the check.
- DataBus as the report anchor. Not chosen by EM for now. It is not on Ethereum, so the anchor would sit on another chain.
- Budgets entered by hand. Not chosen: a financial figure comes only from an attested computation.

## Consequences

- A periodic report that is not tied to a funding motion has no on-chain anchor. Its immutability rests on content addressing and the forum post that cites it. That is enough for an informational control. It is not an Ethereum guarantee.
- Every detective control ends at a person. The mandate must name them.
- Budgets drift with price, because caps are ratios and budgets are token units. The two-week retune absorbs the drift.

## Confirmation

- INV-008, INV-011 and INV-012 in the [invariants](/specs/invariants.md).
- Kit tests: budget consumption and refill [s3]; ceilings and the refill floor [s4]; refused unlimited approval [s5].

## Reversal conditions

- A breach that detection misses, or that remediation does not close within the mandate's window.
- A report that cannot be reproduced from its published data.

## Open questions

- OD-03 and OD-04: the two mandate ambiguities that move the budget figures.
- OD-08: approval ceilings and the refill floor.
- OD-13: who writes the detectors.
- OD-14: who publishes reports, on what schedule, what happens on a stale price, and who answers for a late report.
