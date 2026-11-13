---
type: Decision
title: "ADR 014: Funding by top-up motions"
description: Two top-up factories fund the vault by Easy Track motion within a limit for three months, the first top-up included; insurance for earnETH, earnUSD and Lido Lend comes from the Asset Safe; only emergency, recovery and the operator's pinned return pay the Aragon Agent.
tags: [funding, finance, insurance, governance]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-13T07:44:55Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on funding, insurance at launch and the flows back to the treasury, 2026-11-05 to 2026-11-13
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Finance payments by Aragon Voting, and the executor's payment permission
  - id: s3
    resource: /research/funding-registries-2026-10-02.md
    title: Research note — how a funding registry counts, its calendar periods, and Lido's registry factories
  - id: s4
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — seeding and top-ups through Easy Track; outside the repository until the mandate is published
---

# ADR 014: Funding by top-up motions

## Context

- Aragon Voting holds Finance's payment permission without parameters. A payment that Voting sends as a call succeeds in any token, from the Aragon Agent, and no Dual Governance proposal is on the path [s2].
- The Easy Track executor's payment permission limits the token and the amount of each payment, and allows no USDS [s2].
- The mandate's draft text funds the vault through Easy Track: a seed, then top-ups [s4].
- A funding registry holds a limit for a period of 1, 2, 3, 6 or 12 calendar months. A top-up factory checks a motion against what is left at its creation, and the motion spends it at its enactment. Around a period's end, two full limits can pass within about 72 hours. A motion may name one recipient more than once, and each entry is one payment [s3].
- Lido's two registry factories take the registry's admin from their caller; the standard builders name the Aragon Agent [s3].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Replaced by decisions 13 and 18 (OD-140, OD-146).
2. Replaced by decision 14 (OD-142).
3. Replaced by decisions 15 and 18 (OD-141, OD-146).
4. Insurance is built in at launch, for Lido Earn and for Lido Lend (OD-107).
5. For Lido Earn, only earnETH and earnUSD are covered (OD-107).
6. A fund for Lido Lend has a fixed payout address, which the Lend team names and which is outside Lido Lend's contracts. The form of burnable shares has no use while Lido Lend has no share token that a holder can burn (OD-107, OD-131).
7. Insurance money comes from the Asset Safe by motion (OD-107).
8. Funds go back to the treasury rarely. Only emergency and recovery send them (OD-108).
9. Funds return to the Aragon Agent by an operator transfer pinned to the Agent, or by the emergency Safe's transfer. Neither needs a motion, and neither needs a vote. The operator's transfer is a recovery path, and monitoring alerts on every transfer to the Agent (agent's reading) (OD-108).
10. Redemption and fund-exit proceeds go to the Asset Safe, not to the Agent (OD-108).
11. The transfer of insurance money from the Asset Safe to the first-loss Safe spends a budget key (OD-129).
12. One motion of the universal factory deposits insurance money from the first-loss Safe into Lido Earn (OD-130).
13. Funding can be regular. Top-up factories of Lido's existing kind, in new instances, pay the Asset Safe from the treasury by Easy Track motion (OD-140).
14. The enabling vote registers the top-up factories and pays nothing. The first top-up, one million dollars, comes by top-up motions after the vote is enacted (OD-142).
15. There are two top-up factories: one for stETH, and one for the DAO's stablecoin list, which holds DAI, USDC, USDT and sUSDS (OD-141).
16. A registry's period is three months. Its limit for a period is the figure that EM gave as indicative; the figure is restricted until the mandate is published [s4] (OD-143).
17. The gates of the reports and the readings hold a top-up motion ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 21, 36, 41 and 48) (OD-144).
18. Top-up motions are the only funding path of the design. Aragon Voting holds Finance's payment permission, so nothing prevents the DAO from paying the vault by a vote, out of order (OD-146).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Above a limit.** Top-up motions are the only funding path (decision 18). A funding above a registry's limit for a period needs an Aragon vote that changes the limit, which Aragon Voting does as the registry's admin. USDS is on no top-up list: the vault gets it as DAI, which the operator converts through Sky's converter ([ADR 011](/adr/011-launch-scope.md) decision 7).
- **The first top-up (decision 14).** The enabling vote pays nothing. After it is enacted, anyone sends the Safe batches ([ADR 005](/adr/005-account-graph-and-roles.md) decision 32). Then the committee's Safe creates the motions of the first top-up, one for each factory that it uses, and anyone enacts them after the objection window. The first top-up is the launch cap ([ADR 010](/adr/010-pre-execution-screening.md) decision 20).
- **Top-up motions (decisions 13 to 17).** Two registries list the Asset Safe as their only recipient: one for stETH, and one for the tokens of the DAO's stablecoin list. Each holds a limit for a period of three months. A top-up factory, with the committee's Safe as its trusted caller, creates a motion of one or more payments from Finance to the Asset Safe; after the objection window, anyone enacts it, and the registry counts the amount. The Easy Track executor's payment permission caps one payment at 1,000 stETH or 2,000,000 units of a listed stablecoin [s2], and one motion carries several payments. A registry counts each token in 18 decimals, so the stablecoin registry counts a stablecoin at par, and the stETH registry counts stETH: its limit in stETH comes from the attested computation, at a pinned price. EM's indicative figure is for both registries together: each registry's limit is at most that figure, and monitoring alerts when a period's top-ups together pass it (agent's reading). Aragon Voting is each registry's admin, so a change of a limit, a period or a recipient is a vote without Dual Governance; Lido's standard builders name the Aragon Agent, so the deployment calls Lido's registry factories directly. The deployer adds the Asset Safe and sets each limit, then gives up its roles, and a check before the vote proves every role.
- **Above the launch cap.** [ADR 010](/adr/010-pre-execution-screening.md) decisions 21 and 22 set the conditions of a top-up motion that takes the vault above the launch cap.
- **Before the guard.** The March 2026 terms ([ADR 008](/adr/008-funding-through-existing-payments.md) context) let the Earn team instruct a redemption at any time, so a redemption still runs. If its proceeds take the vault above the first top-up, the committee's Safe returns the excess to the Aragon Agent with its pinned transfer.
- **Insurance by motion** ([ADR 013](/adr/013-one-easy-track-factory.md)):
  - Lido Earn (decision 12): the factory's `insurance` role on the first-loss modifier approves a deposit queue for the exact amount and deposits it with no referral: USDC into earnUSD, or wstETH into earnETH. The queue credits the depositor, which is the first-loss Safe, and anyone can call the queue's claim for it. The new shares follow the first-loss rules: the burn and the redemption of [ADR 008](/adr/008-funding-through-existing-payments.md) decisions 23 and 21. The role holds no transfer, no call of a share token and no cancel of a request.
  - A fund with a fixed payout address (decision 6). The motion that creates it gives the factory's `insurance` role a transfer of the token that is pinned to the payout address, and it sets the cap as a budget key that never refills. The factory's `insurance-governance` role on the first-loss modifier makes these writes, only under the `insurance` key, and it refuses the vault's accounts and the two Earn share tokens. The cap's key is the derived key of the token and the payout address. A payout is a motion of one transfer, and the modifier holds it to the pinned address and within what is left of the cap (INV-039). One token carries one fund at a time, because a write replaces the token's whole transfer permission. No contract of Lido Lend turns a payment into a gain for its lenders, so the address is outside Lido Lend ([research note](/research/lido-lend-insurance-2026-11-12.md)).
  - The exit of a fund ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 28): the committee's `first-loss` role sends insurance money back by a transfer pinned to the Asset Safe, in each token that can become insurance money.
  - Money for a fund (decisions 7 and 11): a transfer pinned to the first-loss Safe, through the universal factory's `insurance-funding` role on the operator modifier. The amount spends the derived key of the token and the first-loss Safe ([ADR 013](/adr/013-one-easy-track-factory.md) decision 9). The key starts empty. A budget write sets it, in the same motion or in an earlier one, and the 30-day floor of the refill period applies.
  - The checklist of [ADR 008](/adr/008-funding-through-existing-payments.md) decision 29 goes into the motion's forum post.
- **The operator's return.** A `transfer` to the Aragon Agent, of any amount, on the Asset Safe and on the orders account, for each listed token. On the Asset Safe, the return and the funding transfer to the orders account are two branches of one `transfer` tree per token, because a write replaces the whole tree. The motion that adds a token adds its return too.
- **Owed mandate text.** The [enabling vote](/specs/enabling-vote.md) lists it, under funding and under legacy and insurance.

## Options considered

- **A vote for each funding:** chosen first as the only funding (OD-106), then kept beside the top-ups (OD-140), then removed (decision 18). The committee expects regular top-ups, each would cost an Aragon vote, and a second funding path adds parts.
- **The top-up factories registered by a later vote, after the screening guard is set:** not chosen (decision 14). It keeps the launch cap on chain, and it puts the first top-up into a vote.
- **Registries that start with limits that sum to the launch cap, and a vote after the guard that raises them:** not chosen (OD-145). It keeps the cap on chain and costs a vote.
- **A third registry for sUSDS, or USDS on the list:** not needed (decision 15). The DAO's stablecoin list holds sUSDS, and USDS needs a vote that changes the list and the executor's payment permission.
- **Top-up registries from Lido's standard builders:** not chosen. A builder names the Aragon Agent as the registry's admin, so each change of a limit would pass Dual Governance.
- **Funding tokens fixed at launch, with a vote for a new one:** not chosen (decision 3). Voting pays any token.
- **A first payment inside the enabling vote:** chosen first (OD-106), then replaced (decision 14). The vote now pays nothing, and the first funding is a top-up.
- **Insurance money by an Aragon vote straight to the first-loss Safe:** not chosen (decision 7).
- **Insurance money without a budget key:** not chosen (decision 11). A budget key makes each amount a stated budget that monitoring reads, and the transfer fails above it.
- **A Lido Lend fund of burnable shares:** not possible today (decision 6). Lido Lend's core has no share token, and its lender vault has no burn that a holder can call.
- **A loss cover inside Lido Lend, or no Lend fund and a payout by vote:** not chosen (decision 6).
- **An Earn fund of plain tokens that pays a pinned address:** not chosen (decision 12). The deposit uses the burn and the redemption that the first-loss shares have.
- **Redemption proceeds to the Aragon Agent:** not chosen (decision 10).
- **A return to the Agent by motion, or only by the emergency Safe or a vote:** not chosen (decision 9).

## Consequences

- A top-up costs one motion and its objection window of 72 hours, and no vote.
- A funding above a registry's limit for a period needs an Aragon vote that changes the limit. USDS is on no top-up list: it reaches the vault as DAI, through Sky's converter.
- Aragon Voting holds Finance's payment permission, so the DAO can still pay any address by a vote. Clutch has no such flow, no gate for it and no alert on it other than the alert on every Finance payment to a vault Safe.
- The top-up path adds a registry and a factory for each kind of token. It changes neither Easy Track's payment permission nor its token list.
- The committee's Safe can pull up to a registry's limit in each period without a vote. The objection window, the limit and the gates on a top-up motion are the controls.
- Before the screening guard is set, nothing on chain keeps a top-up under the launch cap: the registries' limits are above it. A rule, an alert and the objection hold the cap ([ADR 010](/adr/010-pre-execution-screening.md) decision 21; OD-145). A change of a limit, a period or a recipient stays an Aragon vote.
- A registry counts token units, so a limit in stETH is no limit in dollars.
- Around the end of a period, two full limits can pass within about 72 hours: one motion enacted before the end, and one created in the last 72 hours and enacted after it [s3].
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
- A later top-up in another token arrives by its own motion, and DAI becomes USDS through Sky's converter (`test_03_ramp_up`).
- The enabling vote registers both top-up factories, each with its registry's `updateSpentAmount` and Finance's `newImmediatePayment` as its only calls, and pays nothing; the first top-up then comes by two top-up motions (`test_topup_the_enabling_vote_registers_the_factories_and_the_first_top_up_is_two_motions`, `test_02_enabling_vote_end_to_end`).
- Top-up motions (decisions 13 to 16), on a fork against the live Easy Track and Finance (`test/TopUps.t.sol`); both limits are stand-ins: one motion pays stETH to the Asset Safe (`test_topup_steth_motion_pays_the_asset_safe`); only the committee's Safe creates one, and only the Asset Safe receives (`test_topup_only_the_committee_creates_and_only_the_asset_safe_receives`); the registry's limit holds for a period, and the next period has it again (`test_topup_registry_limit_holds_for_a_period`); a payment above the executor's ceiling fails at enactment, and one motion carries three payments (`test_topup_one_motion_carries_several_payments`); the stablecoin factory pays DAI, USDC, USDT and sUSDS, counts each at par in one limit, and refuses USDS and stETH (`test_topup_stablecoins_from_the_dao_list`); only Aragon Voting changes a limit or a recipient (`test_topup_only_voting_changes_a_limit_or_a_recipient`). Owed: the alerts on a top-up motion that breaks a gate, the headroom or the launch cap, which Lido's monitoring runs; the production limits.
- The operator's return (decision 9): on the Asset Safe, each order token goes to the Aragon Agent in any amount, spends no budget and reaches no other receiver (`test_operator_returns_each_order_token_to_the_agent`, `test_operator_return_spends_no_budget`). A token outside the order lists has no return (`test_operator_return_only_for_order_tokens`). On the orders account, the operator returns a token to the Asset Safe or the Agent (`test_orders_operator_returns_tokens_to_the_asset_safe_or_the_agent`). A token that a motion adds gets its return in the same motion (`test_factory_orders_token_motion`).
- A first-loss redemption's claim pays only the Asset Safe (decision 10; `test_first_loss_claim_pays_only_the_asset_safe`). The claim of a settled request is not tested: a fork cannot settle a request.
- Insurance money (decision 11): without a budget, and above it, the move fails at enactment; one motion sets the budget and moves the money (`test_uf_insurance_money_goes_to_the_first_loss_safe`, `test_insurance_funding_pays_only_the_first_loss_safe`).
- The insurance deposit (decision 12): one motion sets the budget, moves USDC to the first-loss Safe and deposits it into earnUSD's queue, which records the request for the first-loss Safe and keeps no approval (`test_insurance_deposit_by_motion`); the same for wstETH and earnETH (`test_insurance_deposit_into_earn_eth`); the refusals (`test_insurance_deposit_refusals`, `test_insurance_role_holds_only_its_calls`). The claim of the shares after a report is not tested: a fork cannot make the report.
- A fund (decision 6): its creation pins the payout address and sets a cap that never refills; payouts go only to that address, only in the fund's token and only within the cap, also after 40 days (`test_fund_create_and_payout_by_motion`, `test_fund_payout_refusals`, `test_fund_create_refusals`). The governance role writes nothing but a fund (`test_insurance_governance_writes_only_a_fund`). The exit pays only the Asset Safe (`test_fund_exit_pays_only_the_asset_safe`). The tests use a stand-in payout address.
- Owed: the Lend team's answer on the payout address, and how that address pays the lenders.

## Reversal conditions

- The committee stops regular funding, so the registries and the top-up factories have no use.
- A top-up motion enacts against a gate without an objection.
- A top-up needs a token that Finance cannot pay.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
