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
  at: 2026-11-11T04:43:51Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on funding by tranche votes, insurance at launch and the flows back to the treasury, 2026-11-05
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Finance payments by Aragon Voting, the executor's payment permission, and the flows to the Aragon Agent
  - id: s4
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — seeding and top-ups through Easy Track; outside the repository until the mandate is published
  - id: s6
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — the first-loss terms of March 2026
---

# ADR 014: Funding by tranche votes

## Context

- Aragon Voting holds Finance's payment permission without parameters. A payment that Voting sends as a call succeeds in any token, from the Aragon Agent, and no Dual Governance proposal is on the path [s2].
- The Easy Track executor's payment permission limits the token and the amount of each payment, and allows no USDS [s2].
- The mandate's draft text funds the vault through Easy Track: a seed, then top-ups [s4].
- The first-loss Safe holds the DAO's first-loss shares in earnETH and earnUSD ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 19). Under the March 2026 terms, the Earn team instructs a burn after a confirmed loss, and a redemption on a confirmed material risk [s6].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Funding is not regular. Each funding is an Aragon vote that moves a tranche from the treasury to the vault. EM's sequence is indicative: one million dollars first, then larger tranches (OD-106).
2. The first tranche goes inside the enabling vote (OD-106).
3. The exact token list does not matter: each tranche vote names its tokens (OD-106).
4. Insurance is built in at launch, for Lido Earn and for Lido Lend (OD-107).
5. For Lido Earn, only earnETH and earnUSD are covered (OD-107).
6. A fund for Lido Lend takes one of the two forms of OD-66: burnable shares, or a fixed payout address (OD-107).
7. Insurance money comes from the Asset Safe by motion (OD-107).
8. Funds go back to the treasury rarely. Only emergency and recovery send them (OD-108).
9. Funds return to the Aragon Agent by an operator transfer pinned to the Agent, or by the emergency Safe's transfer. Neither needs a motion, and neither needs a vote. The operator's transfer is a recovery path, and monitoring alerts on every transfer to the Agent (agent's reading) (OD-108).
10. Redemption and fund-exit proceeds go to the Asset Safe, not to the Agent (OD-108).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **A tranche vote.** One `newImmediatePayment` per token, from Finance to the Asset Safe, with the forum post as the reference. The post states the funded value, the headroom under the mandate size and the vault's share of the DAO's non-LDO treasury. The proposer does not start a tranche vote while the monthly report is late, while level-5 prices cover more than the set share of the vault, or while the two readings differ by more than the band, and monitoring alerts on a tranche vote that starts then ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 21, 36 and 41).
- **The first tranche.** It is an item of the enabling vote and runs when the vote executes. The Safe batches run after the vote ([ADR 005](/adr/005-account-graph-and-roles.md) decision 32), so the tokens wait in the Asset Safe, which only Aragon Voting controls, until the operator's permissions apply. It is the launch cap ([ADR 010](/adr/010-pre-execution-screening.md) decisions 20 and 21).
- **The second tranche.** The screening guard goes on the committee's Safe, with its bypass mode off, before its vote starts, and the Zodiac UI requests the vendor's approval from that moment. Its vote is the only way above the launch cap ([ADR 010](/adr/010-pre-execution-screening.md) decisions 22 and 25).
- **Before the guard.** The March 2026 terms let the Earn team instruct a redemption at any time, so a redemption still runs. If its proceeds take the vault above the first tranche, the committee's Safe returns the excess to the Aragon Agent with its pinned transfer. Monitoring alerts on a redemption before the guard is set, and on an excess that stays.
- **Insurance shapes in the factory** ([ADR 013](/adr/013-one-easy-track-factory.md)):
  - Lido Earn: a deposit into earnETH or earnUSD with the first-loss Safe as the receiver; a burn by motion ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23); and a redemption request and claim by the `first-loss` role, paid to the Asset Safe.
  - Lido Lend, burnable shares: a deposit with the first-loss Safe as the receiver, and a burn by motion. ERC-4626 defines no burn by the holder, so this form fits only a Lend share token that has one.
  - Lido Lend, fixed payout address: the motion that creates the fund pins the payout address and the fund's cap. A payout motion pays at most the remaining cap, to that address only.
  - Money for a fund: a motion moves tokens from the Asset Safe to the first-loss Safe, pinned to it, through the universal factory's `insurance-funding` role on the operator modifier ([ADR 013](/adr/013-one-easy-track-factory.md) decision 18).
  - The checklist of [ADR 008](/adr/008-funding-through-existing-payments.md) decision 29 becomes the shape's fields: the product, the share token or the payout address, the cap, the loss trigger with its independent confirming party, the incident-update deadline and the end of the terms.
- **The operator's return.** A `transfer` to the Aragon Agent, of any amount, on the Asset Safe and on the orders account, for each listed token. On the Asset Safe, the return and the funding transfer to the orders account are two branches of one `transfer` tree per token, because a write replaces the whole tree of a role, target and selector. The motion that adds a token adds its return too.
- **Owed mandate text.** Funding by tranche votes replaces the draft's seed and top-ups through Easy Track [s4]. Redemption and fund-exit proceeds stay in the vault.

## Options considered

- **Funding registries and top-up motions through Easy Track:** not chosen (decision 1). Funding is not regular, and the registries, their factories and the change to the executor's payment permission add parts.
- **Funding tokens fixed at launch, with a vote for a new one:** not chosen (decision 3). Voting pays any token.
- **The first tranche as its own vote after the enabling vote:** not chosen (decision 2). It costs a vote.
- **Insurance money by tranche votes straight to the first-loss Safe:** not chosen (decision 7).
- **Redemption proceeds to the Aragon Agent:** not chosen (decision 10).
- **A return to the Agent by motion, or only by the emergency Safe or a vote:** not chosen (decision 9).

## Consequences

- A tranche costs one Aragon vote of about five days, without Dual Governance. Funding is rare, so these votes are rare.
- The launch has no funding registry, no top-up factory and no change to Easy Track's payment permission or token list.
- The launch cap holds by the first tranche's size, not by procedure.
- The operator can return any vault token to the Agent at any time. That is a risk to the vault's liveness, not a loss.
- A payout from a fund with a fixed payout address is the one flow, besides the returns to the Agent, that leaves the vault. A motion pins its address and its cap when it creates the fund.
- The first-loss Safe holds insurance for three products, so a defect in its modifier reaches all of them.

## Confirmation

- The Finance checks of the research note at block 26350608 [s2].
- The enabling vote pays the first tranche to the Asset Safe before the batches (`test_02_enabling_vote_end_to_end`), and a later tranche in another token arrives by its own vote (`test_03_ramp_up`).
- Insurance money moves from the Asset Safe to the first-loss Safe by a motion of the universal factory (`test_uf_insurance_money_goes_to_the_first_loss_safe`).
- On the orders account, one pinned tree lets the operator return a listed token to the Asset Safe or the Aragon Agent ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 44); the tests cover the return to the Asset Safe. On the Asset Safe, `test_orders_funding_from_the_asset_safe` still asserts that the operator cannot pay the Agent.
- Owed: each insurance shape; a redemption paid to the Asset Safe through the first-loss modifier; the operator's return to the Agent on the Asset Safe; a test of the return to the Agent from the orders account.
- INV-037 to INV-039 in the [invariants](/specs/invariants.md).

## Reversal conditions

- Funding becomes regular, so a motion path for top-ups would remove votes.
- A tranche needs a token that Finance cannot pay.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
