---
type: Decision
title: "ADR 014: Funding by tranche votes"
description: Aragon Voting funds the vault in tranches through Finance, the first inside the enabling vote, and top-up factories pay it by motion; insurance for earnETH, earnUSD and Lido Lend comes from the Asset Safe; only emergency, recovery and the operator's pinned return pay the Aragon Agent.
tags: [funding, finance, insurance, governance]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T22:48:34Z
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

1. A tranche is an Aragon vote that moves funds from the treasury to the vault. EM's sequence is indicative: one million dollars first, then larger tranches. Decision 13 replaces "Funding is not regular" (OD-106, OD-140).
2. The first tranche goes inside the enabling vote (OD-106).
3. The exact token list does not matter: each tranche vote names its tokens (OD-106).
4. Insurance is built in at launch, for Lido Earn and for Lido Lend (OD-107).
5. For Lido Earn, only earnETH and earnUSD are covered (OD-107).
6. A fund for Lido Lend has a fixed payout address, which the Lend team names and which is outside Lido Lend's contracts. The form of burnable shares has no use while Lido Lend has no share token that a holder can burn (OD-107, OD-131).
7. Insurance money comes from the Asset Safe by motion (OD-107).
8. Funds go back to the treasury rarely. Only emergency and recovery send them (OD-108).
9. Funds return to the Aragon Agent by an operator transfer pinned to the Agent, or by the emergency Safe's transfer. Neither needs a motion, and neither needs a vote. The operator's transfer is a recovery path, and monitoring alerts on every transfer to the Agent (agent's reading) (OD-108).
10. Redemption and fund-exit proceeds go to the Asset Safe, not to the Agent (OD-108).
11. The transfer of insurance money from the Asset Safe to the first-loss Safe spends a budget key (OD-129).
12. One motion of the universal factory deposits insurance money from the first-loss Safe into Lido Earn (OD-130).
13. Funding can be regular. Top-up factories of Lido's existing kind, in new instances, pay the Asset Safe from the treasury by Easy Track motion, beside the tranche votes (OD-140).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **A tranche vote.** One `newImmediatePayment` per token, from Finance to the Asset Safe, with the forum post as the reference. The post states the funded value, the headroom under the mandate size and the vault's share of the DAO's non-LDO treasury. [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 21, 36 and 41 say when the proposer does not start it.
- **The first tranche.** It runs when the enabling vote executes. The Safe batches run after the vote ([ADR 005](/adr/005-account-graph-and-roles.md) decision 32), so the tokens wait in the Asset Safe, which only Aragon Voting controls, until the operator's permissions apply. It is the launch cap ([ADR 010](/adr/010-pre-execution-screening.md) decision 20).
- **Top-up motions (decision 13).** A registry lists the Asset Safe as its only recipient and holds a limit for a period. A top-up factory, with the committee's Safe as its trusted caller, creates a motion of one or more payments from Finance to the Asset Safe; after the objection window, anyone enacts it, and the registry counts the amount. Aragon Voting is each registry's admin, so a change of a limit, a period or a recipient is a vote without Dual Governance; Lido's standard builders name the Aragon Agent, so the deployment calls Lido's registry factories directly. The Easy Track executor's payment permission caps one payment at 1,000 stETH or 2,000,000 units of a listed stablecoin [s2], and one motion carries several payments. Still open: the tokens (OD-141), the vote that registers the factories (OD-142), the period and the limit (OD-143), and the gates on a top-up motion (OD-144).
- **The second tranche.** [ADR 010](/adr/010-pre-execution-screening.md) decisions 22 and 25 set its conditions.
- **Before the guard.** The March 2026 terms ([ADR 008](/adr/008-funding-through-existing-payments.md) context) let the Earn team instruct a redemption at any time, so a redemption still runs. If its proceeds take the vault above the first tranche, the committee's Safe returns the excess to the Aragon Agent with its pinned transfer.
- **Insurance by motion** ([ADR 013](/adr/013-one-easy-track-factory.md)):
  - Lido Earn (decision 12): the factory's `insurance` role on the first-loss modifier approves a deposit queue for the exact amount and deposits it with no referral: USDC into earnUSD, or wstETH into earnETH. The queue credits the depositor, which is the first-loss Safe, and anyone can call the queue's claim for it. The new shares follow the first-loss rules: the burn and the redemption of [ADR 008](/adr/008-funding-through-existing-payments.md) decisions 23 and 21. The role holds no transfer, no call of a share token and no cancel of a request.
  - A fund with a fixed payout address (decision 6). The motion that creates it gives the factory's `insurance` role a transfer of the token that is pinned to the payout address, and it sets the cap as a budget key that never refills. The factory's `insurance-governance` role on the first-loss modifier makes these writes, only under the `insurance` key, and it refuses the vault's accounts and the two Earn share tokens. The cap's key is the derived key of the token and the payout address. A payout is a motion of one transfer, and the modifier holds it to the pinned address and within what is left of the cap (INV-039). One token carries one fund at a time, because a write replaces the token's whole transfer permission. No contract of Lido Lend turns a payment into a gain for its lenders, so the address is outside Lido Lend ([research note](/research/lido-lend-insurance-2026-11-12.md)).
  - The exit of a fund ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 28): the committee's `first-loss` role sends insurance money back by a transfer pinned to the Asset Safe, in each token that can become insurance money.
  - Money for a fund (decisions 7 and 11): a transfer pinned to the first-loss Safe, through the universal factory's `insurance-funding` role on the operator modifier. The amount spends the derived key of the token and the first-loss Safe ([ADR 013](/adr/013-one-easy-track-factory.md) decision 9). The key starts empty. A budget write sets it, in the same motion or in an earlier one, and the 30-day floor of the refill period applies.
  - The checklist of [ADR 008](/adr/008-funding-through-existing-payments.md) decision 29 goes into the motion's forum post.
- **The operator's return.** A `transfer` to the Aragon Agent, of any amount, on the Asset Safe and on the orders account, for each listed token. On the Asset Safe, the return and the funding transfer to the orders account are two branches of one `transfer` tree per token, because a write replaces the whole tree. The motion that adds a token adds its return too.
- **Owed mandate text.** The [enabling vote](/specs/enabling-vote.md) lists it, under funding and under legacy and insurance.

## Options considered

- **Tranche votes only:** chosen first (OD-106), then replaced (decision 13). The committee expects regular top-ups, and each would cost an Aragon vote.
- **Top-up registries from Lido's standard builders:** not chosen. A builder names the Aragon Agent as the registry's admin, so each change of a limit would pass Dual Governance.
- **Funding tokens fixed at launch, with a vote for a new one:** not chosen (decision 3). Voting pays any token.
- **The first tranche as its own vote after the enabling vote:** not chosen (decision 2). It costs a vote.
- **Insurance money by tranche votes straight to the first-loss Safe:** not chosen (decision 7).
- **Insurance money without a budget key:** not chosen (decision 11). A budget key makes each amount a stated budget that monitoring reads, and the transfer fails above it.
- **A Lido Lend fund of burnable shares:** not possible today (decision 6). Lido Lend's core has no share token, and its lender vault has no burn that a holder can call.
- **A loss cover inside Lido Lend, or no Lend fund and a payout by vote:** not chosen (decision 6).
- **An Earn fund of plain tokens that pays a pinned address:** not chosen (decision 12). The deposit uses the burn and the redemption that the first-loss shares have.
- **Redemption proceeds to the Aragon Agent:** not chosen (decision 10).
- **A return to the Agent by motion, or only by the emergency Safe or a vote:** not chosen (decision 9).

## Consequences

- A tranche costs one Aragon vote of about five days. A top-up costs one motion and its objection window of 72 hours.
- The top-up path adds a registry and a factory for each kind of token. It changes neither Easy Track's payment permission nor its token list.
- The committee's Safe can pull up to a registry's limit in each period without a vote. The objection window, the limit and the gates on a top-up motion are the controls. A change of a limit, a period or a recipient stays an Aragon vote.
- A registry counts token units, so a limit in stETH is no limit in dollars.
- A payout from a fund with a fixed payout address is the one flow, besides the returns to the Agent, that leaves the vault.
- The first-loss Safe holds insurance for three products, so a defect in its modifier reaches all of them.
- A motion can set the insurance budget and move the money in one enactment, so the budget adds no second objection window and no bound of its own. The objection window bounds the amount ([ADR 013](/adr/013-one-easy-track-factory.md) decision 11).
- An insurance deposit waits in the Earn vault's queue until the vault's next report. No role cancels the request.
- A fund's payout address is outside Lido Lend, so what the lenders get rests on that address's own rules. The fund bounds the amount and the receiver, not the use.
- One fund exists for each token at a time. A motion that creates a second fund in a token replaces the first fund's payout address.
- A fund's money is not kept apart from other insurance money in the first-loss Safe. The cap bounds the payouts, and the committee's exit can return the money to the Asset Safe without a motion.
- A motion that the first-loss modifier's policy refuses, such as a deposit of a token with another vault's queue or a payout to another address, passes its creation and fails at its enactment.

## Confirmation

- INV-037 to INV-039 in the [invariants](/specs/invariants.md).
- The Finance checks of the research note at block 26350608 [s2].
- A later tranche in another token arrives by its own vote (`test_03_ramp_up`).
- Top-up motions (decision 13), as a probe on a fork against the live Easy Track and Finance, with stand-in limits (`test/TopUps.t.sol`): one motion pays stETH to the Asset Safe (`test_topup_steth_motion_pays_the_asset_safe`); only the committee's Safe creates one, and only the Asset Safe receives (`test_topup_only_the_committee_creates_and_only_the_asset_safe_receives`); the registry's limit holds for a period, and the next period has it again (`test_topup_registry_limit_holds_for_a_period`); a payment above the executor's ceiling fails at enactment, and one motion carries three payments (`test_topup_one_motion_carries_several_payments`); the stablecoin factory pays a token of the DAO's list and refuses USDS and stETH (`test_topup_stablecoins_from_the_dao_list`); only Aragon Voting changes a limit or a recipient (`test_topup_only_voting_changes_a_limit_or_a_recipient`). Owed: the registries in the enabling-vote rehearsal, once OD-141 to OD-144 close.
- The operator's return (decision 9): on the Asset Safe, each order token goes to the Aragon Agent in any amount, spends no budget and reaches no other receiver (`test_operator_returns_each_order_token_to_the_agent`, `test_operator_return_spends_no_budget`). A token outside the order lists has no return (`test_operator_return_only_for_order_tokens`). On the orders account, the operator returns a token to the Asset Safe or the Agent (`test_orders_operator_returns_tokens_to_the_asset_safe_or_the_agent`). A token that a motion adds gets its return in the same motion (`test_factory_orders_token_motion`).
- A first-loss redemption's claim pays only the Asset Safe (decision 10; `test_first_loss_claim_pays_only_the_asset_safe`). The claim of a settled request is not tested: a fork cannot settle a request.
- Insurance money (decision 11): without a budget, and above it, the move fails at enactment; one motion sets the budget and moves the money (`test_uf_insurance_money_goes_to_the_first_loss_safe`, `test_insurance_funding_pays_only_the_first_loss_safe`).
- The insurance deposit (decision 12): one motion sets the budget, moves USDC to the first-loss Safe and deposits it into earnUSD's queue, which records the request for the first-loss Safe and keeps no approval (`test_insurance_deposit_by_motion`); the same for wstETH and earnETH (`test_insurance_deposit_into_earn_eth`); the refusals (`test_insurance_deposit_refusals`, `test_insurance_role_holds_only_its_calls`). The claim of the shares after a report is not tested: a fork cannot make the report.
- A fund (decision 6): its creation pins the payout address and sets a cap that never refills; payouts go only to that address, only in the fund's token and only within the cap, also after 40 days (`test_fund_create_and_payout_by_motion`, `test_fund_payout_refusals`, `test_fund_create_refusals`). The governance role writes nothing but a fund (`test_insurance_governance_writes_only_a_fund`). The exit pays only the Asset Safe (`test_fund_exit_pays_only_the_asset_safe`). The tests use a stand-in payout address.
- Owed: the Lend team's answer on the payout address, and how that address pays the lenders.

## Reversal conditions

- The committee stops regular funding, so the registries and the top-up factories have no use.
- A top-up motion enacts against a gate without an objection.
- A tranche needs a token that Finance cannot pay.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-141](/registers/open-decisions.md): Which tokens get a top-up factory? Each factory pays one registry's recipients, and a registry counts every token in 18 decimals, so stETH and stablecoins need two registries. (A) Two: one for stETH, and one for the DAO's stablecoin list as it is, which holds DAI, USDC, USDT and sUSDS. (B) stETH only; stablecoins come by tranche vote. (C) A, and USDS too, which needs a vote that adds USDS to the token list and rewrites the executor's payment permission.
- [OD-143](/registers/open-decisions.md): What are the period and the limit of each registry? A period is 1, 2, 3, 6 or 12 calendar months, and a period's end lets two full limits pass within about 72 hours. A limit counts token units, not dollars. (A) Three months, and a limit that the attested computation sets from what the committee expects to pull in one period, never above one mandate size. (B) One month, as OD-06 once set, with the same rule for the limit. (C) Twelve months, with one mandate size as the limit.

<!-- end of generated block -->
