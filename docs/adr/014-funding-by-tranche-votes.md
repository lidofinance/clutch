---
type: Decision
title: "ADR 014: Funding by tranche votes"
description: Aragon Voting funds the vault in rare tranches through Finance, the first inside the enabling vote; insurance for earnETH, earnUSD and Lido Lend comes from the Asset Safe; only emergency, recovery and the operator's pinned return pay the Aragon Agent.
tags: [funding, finance, insurance, governance]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T11:10:32Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on funding by tranche votes, insurance at launch and the flows back to the treasury, 2026-11-05
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Finance payments by Aragon Voting, and the executor's payment permission
  - id: s4
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — seeding and top-ups through Easy Track; outside the repository until the mandate is published
---

# ADR 014: Funding by tranche votes

## Context

- Aragon Voting holds Finance's payment permission without parameters. A payment that Voting sends as a call succeeds in any token, from the Aragon Agent, and no Dual Governance proposal is on the path [s2].
- The Easy Track executor's payment permission limits the token and the amount of each payment, and allows no USDS [s2].
- The mandate's draft text funds the vault through Easy Track: a seed, then top-ups [s4].

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
11. The transfer of insurance money from the Asset Safe to the first-loss Safe spends a budget key (OD-129).
12. One operation of the universal factory deposits insurance money from the first-loss Safe into Lido Earn (OD-130).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **A tranche vote.** One `newImmediatePayment` per token, from Finance to the Asset Safe, with the forum post as the reference. The post states the funded value, the headroom under the mandate size and the vault's share of the DAO's non-LDO treasury. [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 21, 36 and 41 say when the proposer does not start it.
- **The first tranche.** It runs when the enabling vote executes. The Safe batches run after the vote ([ADR 005](/adr/005-account-graph-and-roles.md) decision 32), so the tokens wait in the Asset Safe, which only Aragon Voting controls, until the operator's permissions apply. It is the launch cap ([ADR 010](/adr/010-pre-execution-screening.md) decision 20).
- **The second tranche.** [ADR 010](/adr/010-pre-execution-screening.md) decisions 22 and 25 set its conditions.
- **Before the guard.** The March 2026 terms ([ADR 008](/adr/008-funding-through-existing-payments.md) context) let the Earn team instruct a redemption at any time, so a redemption still runs. If its proceeds take the vault above the first tranche, the committee's Safe returns the excess to the Aragon Agent with its pinned transfer.
- **Insurance shapes in the factory** ([ADR 013](/adr/013-one-easy-track-factory.md)):
  - Lido Earn (decision 12): the factory's `insurance` role on the first-loss modifier approves a deposit queue for the exact amount and deposits it with no referral: USDC into earnUSD, or wstETH into earnETH. The queue credits the depositor, which is the first-loss Safe, and anyone can call the queue's claim for it. The new shares follow the first-loss rules: the burn and the redemption of [ADR 008](/adr/008-funding-through-existing-payments.md) decisions 23 and 21. The role holds no transfer, no call of a share token and no cancel of a request.
  - Lido Lend, burnable shares: a deposit with the first-loss Safe as the receiver, and a burn by motion. Lido Lend's core has no share token, and its lender vault has no burn that a holder can call, so this form has no use today ([research note](/research/lido-lend-insurance-2026-11-12.md); OD-131).
  - Lido Lend, fixed payout address: the motion that creates the fund pins the payout address and the fund's cap, and a payout motion pays within both (INV-039). No contract of Lido Lend turns a payment into a gain for its lenders, so the address is outside Lido Lend (OD-131).
  - Money for a fund (decisions 7 and 11): a transfer pinned to the first-loss Safe, through the universal factory's `insurance-funding` role on the operator modifier. The amount spends the key that the factory derives for the token and the first-loss Safe ([ADR 013](/adr/013-one-easy-track-factory.md) decision 9). The key starts empty. A budget operation sets it within the token's budget ceiling, in the same motion or in an earlier one, and the 30-day floor of the refill period applies.
  - The checklist of [ADR 008](/adr/008-funding-through-existing-payments.md) decision 29 becomes the shape's fields.
- **The operator's return.** A `transfer` to the Aragon Agent, of any amount, on the Asset Safe and on the orders account, for each listed token. On the Asset Safe, the return and the funding transfer to the orders account are two branches of one `transfer` tree per token, because a write replaces the whole tree. The motion that adds a token adds its return too.
- **Owed mandate text.** The [enabling vote](/specs/enabling-vote.md) lists it, under funding and under legacy and insurance.

## Options considered

- **Funding registries and top-up motions through Easy Track:** not chosen (decision 1). Funding is not regular, and the registries, their factories and the change to the executor's payment permission add parts.
- **Funding tokens fixed at launch, with a vote for a new one:** not chosen (decision 3). Voting pays any token.
- **The first tranche as its own vote after the enabling vote:** not chosen (decision 2). It costs a vote.
- **Insurance money by tranche votes straight to the first-loss Safe:** not chosen (decision 7).
- **Insurance money without a bound, or with a ceiling of its own class in the factory:** not chosen (decision 11). Without a bound, two motions that nobody objects to could move any amount to the first-loss Safe and then burn it. A budget key uses the budgets and ceilings that the factory has.
- **An Earn fund of plain tokens that pays a pinned address:** not chosen (decision 12). The deposit uses the burn and the redemption that the first-loss shares have.
- **Redemption proceeds to the Aragon Agent:** not chosen (decision 10).
- **A return to the Agent by motion, or only by the emergency Safe or a vote:** not chosen (decision 9).

## Consequences

- A tranche costs one Aragon vote of about five days.
- The launch adds no funding contract and changes neither Easy Track's payment permission nor its token list.
- A payout from a fund with a fixed payout address is the one flow, besides the returns to the Agent, that leaves the vault.
- The first-loss Safe holds insurance for three products, so a defect in its modifier reaches all of them.
- Insurance money shares its token's budget ceiling with the operator's keys of that token. A token whose budget ceiling is zero carries no insurance money, because a motion cannot raise a ceiling from zero.
- A motion can set the insurance budget and move the money in one enactment, so the budget adds no second objection window. It bounds the amount to the token's budget ceiling.
- An insurance deposit waits in the Earn vault's queue until the vault's next report. No role cancels the request.
- A deposit of a token with another vault's queue, or of a token outside the policy, passes its creation and fails at its enactment.

## Confirmation

- INV-037 to INV-039 in the [invariants](/specs/invariants.md).
- The Finance checks of the research note at block 26350608 [s2].
- A later tranche in another token arrives by its own vote (`test_03_ramp_up`).
- The operator's return (decision 9): on the Asset Safe, each order token goes to the Aragon Agent in any amount, spends no budget and reaches no other receiver (`test_operator_returns_each_order_token_to_the_agent`, `test_operator_return_spends_no_budget`). A token outside the order lists has no return (`test_operator_return_only_for_order_tokens`). On the orders account, the operator returns a token to the Asset Safe or the Agent (`test_orders_operator_returns_tokens_to_the_asset_safe_or_the_agent`). A token that a motion adds gets its return in the same motion (`test_factory_orders_token_motion`).
- A first-loss redemption's claim pays only the Asset Safe (decision 10; `test_first_loss_claim_pays_only_the_asset_safe`). The claim of a settled request is not tested: a fork cannot settle a request.
- Insurance money (decision 11): without a budget, and above it, the move fails at enactment; one motion sets the budget and moves the money; a budget above the token's ceiling is refused at creation (`test_uf_insurance_money_goes_to_the_first_loss_safe`, `test_insurance_funding_pays_only_the_first_loss_safe`).
- The insurance deposit (decision 12): one motion sets the budget, moves USDC to the first-loss Safe and deposits it into earnUSD's queue, which records the request for the first-loss Safe and keeps no approval (`test_insurance_deposit_by_motion`); the same for wstETH and earnETH (`test_insurance_deposit_into_earn_eth`); the refusals (`test_insurance_deposit_refusals`, `test_insurance_role_holds_only_its_calls`). The claim of the shares after a report is not tested: a fork cannot make the report.
- Owed: a Lido Lend fund, with its creation, its payout and its exit (OD-131).

## Reversal conditions

- Funding becomes regular, so a motion path for top-ups would remove votes.
- A tranche needs a token that Finance cannot pay.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-131](/registers/open-decisions.md): Which Lido Lend fund does the factory carry (OD-107)? Lido Lend has no entry point for either form today: its core has no share token, its lender vault has no burn that a holder can call, and no function adds loan assets to a market without new supply shares ([research note](/research/lido-lend-insurance-2026-11-12.md)). Options: (A) build the payout form only: the motion that creates the fund pins the token, the payout address and the cap, which is a budget key that does not refill; the payout address is one that the Lend team names, outside Lido Lend's contracts, and it pays the lenders; (B) ask the Lend team for a loss cover in Lido Lend, a function that adds loan assets to a market's supply without new shares, and build the fund against it when it exists, which needs a changed factory and a vote if it comes after the audit; (C) no Lend fund in the factory: insurance money for Lido Lend waits in the first-loss Safe as plain tokens, and Aragon Voting pays it out by vote after a loss.

<!-- end of generated block -->
