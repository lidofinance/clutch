---
type: Specification
title: The enabling vote
description: What Clutch's one Aragon vote must hold — the items that Aragon Voting executes and the items that the Aragon Agent executes through Dual Governance — what must be done before it, what follows without a vote, and what still needs a vote after it.
tags: [governance, enabling-vote, deployment, specs]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-14T16:47:06Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions to OD-67, 2026-10-13
  - id: s2
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the accounts, the roles and their holders
  - id: s3
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — the factories, their trusted caller and the exit-governance role
  - id: s4
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the orders account, its lists and its relayer approvals
  - id: s5
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the payment permission, the token list, the registries and the first-loss Safe
  - id: s6
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — the budget keys and their ceilings
  - id: s7
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch without the guard, and the checks before the vote
  - id: s8
    resource: /research/single-vote-review-2026-10-14.md
    title: One Aragon vote to launch, Easy Track afterwards, 2026-10-14 — the review, and Easy Track's admin role read on chain
---

# The enabling vote

Clutch launches with one Aragon vote, the enabling vote. This page lists what the vote holds, what comes before it and what follows it without a vote. The agent drafted it from the decisions [s8]. EM has not accepted it as text.

## Before the vote

- **Snapshots.** The mandate, with its figures. The emergency Safe's fifth signer (OD-58, OD-65) [s1].
- **Figures.** An attested computation sets every budget and its key's ceiling, the orders budgets, the funding limits, the fixed approval ceilings and the stETH limit at the pinned price [s5][s6].
- **Decisions.** OD-66 closes, because its roles and factories ship in this vote. OD-68 to OD-72 close, because each one changes what the vote holds [s1].
- **Deployments.** They need no authority. Clutch's script creates the Asset Safe, the orders account and the first-loss Safe with the Aragon Agent as only owner, and the operator Safe and the emergency Safe with their signers, on Safe v1.5.0; the orders account runs it only if its fork test passes. It deploys the four Roles modifiers as minimal proxies through the Zodiac module proxy factory, and the Easy Track factories with the operator Safe as their trusted caller. Easy Track's standard builder deploys the two funding registries and sets each limit and period [s2][s3][s5][s8].
- **Checks.** The fork tests of the order signer and of CoW's fallback handler on Safe v1.5.0 behind a Roles modifier [s4]. The external audit. The check of Safe's releases, advisories and bug-bounty records [s7]. The policy compiled for mainnet from the reviewed constellation.

## The vote

### Items that Aragon Voting executes

Aragon Voting holds Easy Track's admin role and administers the shared token list [s8][s5].

- Register every Clutch factory in Easy Track: the five template factories, the budget factory, the first-loss burn factory and the two top-up factories [s3][s5].
- Rewrite the shared payment permission of the Easy Track executor to add USDS, with a ceiling of 2,000,000 per payment (OD-11, OD-24) [s5].
- Add USDS to the shared stablecoin token list [s5].

### Items that the Aragon Agent executes, through Dual Governance

- **The Asset Safe.** Enable the operator modifier and the safety modifier, and apply the compiled policy on both: every permission, and every budget key with its ceiling, the Lido Lend key included. Grant `operator` to the operator Safe, `governance` and `exit-governance` to the Easy Track executor, and `emergency`, with the switch, to the emergency Safe [s2][s3][s6].
- **The orders account.** Set CoW's fallback handler, and ComposableCoW as the verifier of CoW's settlement domain. Enable the orders modifier and apply its policy: the operator's orders on the launch lists, and the emergency role's recovery orders, transfers and cancels. Grant `operator` to the operator Safe and `emergency` to the emergency Safe. Approve CoW's vault relayer for every listed token, the recovery tokens included [s4].
- **The first-loss Safe.** Enable the first-loss modifier and apply its policy. Grant `first-loss` to the operator Safe and `first-loss-burn` to the Easy Track executor [s5].
- **OD-66.** If OD-66 closes as recommended: the roles and the factories for new insurance funds [s1].

### Order

The Voting items run when the vote executes. The Agent items run after the Dual Governance timelock. A motion that needs one of the new roles reverts at enactment until then, so the operator Safe creates motions only after the Agent items have run.

## After the vote, without another vote

- The Growth Committee's Safe moves the first-loss shares to the first-loss Safe [s5].
- The operator Safe creates the seed motion [s5].
- Lido Lend joins by one onboarding motion, because its key is already in the policy [s6].
- The operator Safe's owners set the screening guard, and a forum post lifts the launch cap (OD-54, OD-55) [s7].
- Each Safe's own owners rotate its signers. A Snapshot fills the fifth seat of the emergency Safe [s2].

## What still needs a vote after launch

| Kind | What | Where |
|---|---|---|
| Open | A new token, or any other change, on the orders account | OD-68 |
| Open | A budget key for a spender that the vote did not know | OD-69 |
| Open | Granting again what a routine removal took | OD-70 |
| Open | A new TM Floor Value, and a re-pinned stETH limit | OD-71 |
| Open | A shape outside the five templates, and reward claims | OD-72 |
| By design | Role membership; replacing a Safe, a modifier or a factory; delegatecall for the operator; another module or a Safe version change; the shared payment permission or token list; ending the first-loss terms | [s2][s3][s5] |
| After an emergency | The restart, which also grants the orders account's permissions and relayer approvals again; an Easy Track unpause | OD-59 [s2] |

The review behind this table is in the research note [s8].
