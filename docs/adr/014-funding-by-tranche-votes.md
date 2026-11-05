---
type: Decision
title: "ADR 014: Funding by tranche votes"
description: Aragon Voting funds the vault in rare tranches through Finance, the first inside the enabling vote; insurance for earnETH, earnUSD and Lido Lend comes from the Asset Safe; only emergency, recovery and the operator's pinned return pay the Aragon Agent.
tags: [funding, finance, insurance, governance]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-11-05T19:22:54Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on funding by tranche votes, insurance at launch and the flows back to the treasury, 2026-11-05
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Finance payments by Aragon Voting, the executor's payment permission, and the flows to the Aragon Agent
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the funding registries, the top-up motions, the USDS items, the first-loss Safe and the insurance funds
  - id: s4
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — seeding and top-ups through Easy Track; outside the repository until the mandate is published
  - id: s5
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch without the guard under a cap of one million dollars, and the lift of the cap
  - id: s6
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — the first-loss terms of March 2026
---

# ADR 014: Funding by tranche votes

## Context

- Aragon Voting holds Finance's payment permission without parameters. A payment that Voting sends as a call succeeds in any token, from the Aragon Agent, and no Dual Governance proposal is on the path [s2].
- The Easy Track executor's payment permission limits the token and the amount of each payment, and allows no USDS [s2][s3].
- ADR 008 funded the vault through two Easy Track funding registries and top-up motions, and the enabling vote carried four USDS items for them [s3].
- ADR 010 lets the vault launch without the screening guard under a cap of one million dollars, which a forum post lifts once the guard is set on the committee's Safe [s5].
- The mandate's draft text funds the vault through Easy Track: a seed, then top-ups [s4].
- The first-loss Safe holds the DAO's first-loss shares in earnETH and earnUSD. Under the March 2026 terms, the Earn team instructs a burn after a confirmed loss, and a redemption on a confirmed material risk [s3][s6].
- Before this ADR, the first-loss redemption and the exit from an insurance fund paid the Aragon Agent. Insurance funds were not built at launch [s3].

## Decision

EM decided on 2026-11-05, closing OD-106 [s1]:

1. Funding is not regular. Each funding is an Aragon vote that moves a tranche from the treasury to the vault. EM's sequence is indicative: one million dollars first, then larger tranches.
2. The first tranche goes inside the enabling vote.
3. The exact token list does not matter: each tranche vote names its tokens.

EM decided on 2026-11-05, closing OD-107 [s1]:

4. Insurance is built in at launch, for Lido Earn and for Lido Lend.
5. For Lido Earn, only earnETH and earnUSD are covered.
6. A fund for Lido Lend takes one of the two forms of OD-66: burnable shares, or a fixed payout address.
7. Insurance money comes from the Asset Safe by motion.

EM decided on 2026-11-05, closing OD-108 [s1]:

8. Funds go back to the treasury rarely. Only emergency and recovery send them.
9. Funds return to the Aragon Agent by an operator transfer pinned to the Agent, or by the emergency Safe's transfer. Neither needs a motion, and neither needs a vote.
10. Redemption and fund-exit proceeds go to the Asset Safe, not to the Agent.

Aragon Voting pays each tranche through Finance as its own vote item, in any token and without Dual Governance [s2]. Decisions 1 to 3 therefore remove the funding registries, the top-up factories and the four USDS items of the enabling vote. They replace [ADR 008](/adr/008-funding-through-existing-payments.md) decisions 1, 3 to 12, 24, 35 and 36, the registries of decision 20, and the funding assets of [ADR 011](/adr/011-launch-scope.md) decision 5. ADR 008 decisions 32 to 34 stand: the mandate size is a ceiling, each tranche counts at its value when it is funded, and the vault never holds more than the mandate's share of the DAO's non-LDO treasury. Decision 37 stands for the funded value. The first tranche is the launch cap of [ADR 010](/adr/010-pre-execution-screening.md) decision 20, so the cap holds by the tranche's size; a first-loss redemption before the guard is the one exception, and the committee returns its excess (proposed direction).

Decisions 4 to 7 replace ADR 008 decision 31. ADR 008 decisions 25, 26 and 29 stand: one Snapshot sets the framework, a motion creates each fund and pays out from it, and each fund fills in the checklist. Decision 30's third registry stays replaced, because insurance money comes from the Asset Safe.

Decision 10 replaces the Aragon Agent as the payee in ADR 008 decisions 21, 23 and 28, and in [ADR 005](/adr/005-account-graph-and-roles.md) decision 27. The agent reads decision 9's operator transfer as a recovery path: monitoring alerts on every transfer to the Agent.

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **A tranche vote.** One `newImmediatePayment` per token, from Finance to the Asset Safe, with the forum post as the reference. The post states the funded value, the headroom under the mandate size and the vault's share of the DAO's non-LDO treasury. The rules that held back a top-up now hold back a tranche vote: no tranche vote starts while the monthly report is late, while level-5 prices cover more than the set share of the vault, or while the two readings differ by more than the band ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 21, 36 and 41).
- **The first tranche.** It is an item of the enabling vote and runs when the vote executes. The Safe batches run after the vote ([ADR 005](/adr/005-account-graph-and-roles.md) decision 32), so the tokens wait in the Asset Safe, which only Aragon Voting controls, until the operator's permissions apply.
- **The second tranche.** Its vote lifts the launch cap of ADR 010 decision 22. It starts only after the screening guard is set on the committee's Safe with its bypass mode off, and the check of ADR 010 decision 8 runs until it executes.
- **Before the guard.** The March 2026 terms let the Earn team instruct a redemption at any time, so a redemption still runs. If its proceeds take the vault above the first tranche, the committee's Safe returns the excess to the Aragon Agent with its pinned transfer. Monitoring alerts on a redemption before the guard is set, and on an excess that stays.
- **Insurance shapes in the factory** ([ADR 013](/adr/013-one-easy-track-factory.md)):
  - Lido Earn: a deposit into earnETH or earnUSD with the first-loss Safe as the receiver; a burn by motion (ADR 008 decision 23); and a redemption request and claim by the `first-loss` role, paid to the Asset Safe.
  - Lido Lend, burnable shares: a deposit with the first-loss Safe as the receiver, and a burn by motion. ERC-4626 defines no burn by the holder, so this form fits only a Lend share token that has one.
  - Lido Lend, fixed payout address: the motion that creates the fund pins the payout address and the fund's cap. A payout motion pays at most the remaining cap, to that address only.
  - Money for a fund: a motion moves tokens from the Asset Safe to the first-loss Safe, pinned to it, through the Easy Track executor's `insurance-funding` role on the operator modifier.
  - The checklist of ADR 008 decision 29 becomes the shape's fields: the product, the share token or the payout address, the cap, the loss trigger with its independent confirming party, the incident-update deadline and the end of the terms.
- **The operator's return.** A `transfer` to the Aragon Agent, of any amount, on the Asset Safe and on the orders account, for each listed token. The motion that adds a token adds its return too.
- **Owed mandate text.** Funding by tranche votes replaces the draft's seed and top-ups through Easy Track [s4]. Redemption and fund-exit proceeds stay in the vault.

## Options considered

- Keep the funding registries and the top-up motions of ADR 008: replaced. Funding is not regular, and the registries, the factories and the USDS items add parts.
- A dormant third registry for insurance funds: moot, because insurance money comes from the Asset Safe.
- Funding tokens fixed at launch, with a vote for a new one: not chosen. Voting pays any token.
- The first tranche as its own vote after the enabling vote: not chosen. It costs a vote.
- Insurance money by tranche votes straight to the first-loss Safe: not chosen.
- Proceeds to the Aragon Agent: replaced by decision 10.
- A return to the Agent by motion, or only by the emergency Safe or a vote: not chosen (decision 9).

## Consequences

- A tranche costs one Aragon vote of about five days, without Dual Governance. Funding is rare, so these votes are rare.
- The launch has no funding registry, no top-up factory and no change to Easy Track's payment permission or token list.
- The launch cap holds by the first tranche's size, not by procedure.
- The operator can return any vault token to the Agent at any time. That is a risk to the vault's liveness, not a loss.
- A payout from a fund with a fixed payout address is the one flow, besides the returns to the Agent, that leaves the vault. A motion pins its address and its cap when it creates the fund.
- The first-loss Safe holds insurance for three products, so a defect in its modifier reaches all of them.

## Confirmation

- The Finance checks of the research note at block 26350608 [s2].
- Fork tests, when built: the enabling vote with the first tranche; a tranche vote; each insurance shape; a redemption paid to the Asset Safe; the operator's return to the Agent.
- INV-037 to INV-039 in the [invariants](/specs/invariants.md); INV-037 replaces INV-017.

## Reversal conditions

- Funding becomes regular, so a motion path for top-ups would remove votes.
- A tranche needs a token that Finance cannot pay.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
