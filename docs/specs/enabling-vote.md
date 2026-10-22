---
type: Specification
title: The enabling vote
description: Prerequisites, direct Aragon Voting items without Dual Governance, post-vote actions and later changes that still require a vote.
tags: [governance, enabling-vote, deployment, specs]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T20:25:16Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions to OD-94, 2026-10-22
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
  - id: s9
    resource: /research/enabling-vote-rehearsal-2026-10-15.md
    title: The enabling vote rehearsed on a mainnet fork, 2026-10-15 and 2026-10-22 — why this vote cannot start as written, and the vote that fits
---

# The enabling vote

Clutch launches with one Aragon vote, the enabling vote [s8].

A fork rehearsal on 2026-10-15, run again on 2026-10-22, found that this vote cannot start as written [s9]. Aragon Voting stores the whole script when a vote starts, and with the Safe batches inside, that transaction needs more gas than EIP-7825 lets one transaction use. The rehearsal also found that the standard builder cannot make Voting a registry's admin, and that Voting must take the token list's add-token role before it adds USDS. EM decided the changes on 2026-10-22 (OD-92, OD-93), and this page follows them.

## Before the vote

- **Snapshots.** The mandate, with its figures. The emergency Safe's fifth signer (OD-58, OD-65) [s1].
- **Figures.** An attested computation sets every budget and its key's ceiling, the orders budgets, the funding limits, the fixed approval ceilings and the stETH limit at the pinned price [s5][s6].
- **Decisions.** Every OD is decided except OD-65, which closes at the fifth signer's Snapshot [s1].
- **Deployments.** They need no authority. Clutch's script creates the Asset Safe, the orders account and the first-loss Safe with Aragon Voting as only owner, and the emergency Safe with its signers, on Safe v1.5.0; the orders account runs it only if its fork test passes. It deploys the four Roles modifiers as minimal proxies through the Zodiac module proxy factory, and the Easy Track factories with the committee's Safe as their trusted caller (OD-80). The registry factories deploy the two funding registries with Aragon Voting as their admin (OD-73). The deployer adds the Asset Safe and sets each limit and period, then gives up its roles (OD-92) [s2][s3][s5][s8][s9].
- **Checks.** The fork tests of the order signer and of CoW's fallback handler on Safe v1.5.0 behind a Roles modifier [s4]. The external audit. The check of Safe's releases, advisories and bug-bounty records [s7]. The policy compiled for mainnet from the reviewed constellation. The template catalogue against the mandate's protocols and the committee's named pipeline (OD-72, OD-79). The check of every role of both registries (OD-92). The Safe batches, published with one command that computes each hash again. A rehearsal of the vote and the batches at a recent block, with the before-and-after check of the shared payment permission, before the vote starts and again before it executes (OD-92, OD-93) [s9].

## The vote

Aragon Voting runs the Easy Track, payment and token-list items itself: it holds Easy Track's admin role, and manages the payment permission and the shared token list [s8][s5]. For the vault's Safes, which it owns (OD-73), it approves the hash of each Safe batch, and anyone executes the batches after the vote (OD-92) [s9]. No item passes Dual Governance, because none needs the Aragon Agent to act [s1].

### Easy Track and payments

- Register every Clutch factory in Easy Track: the onboarding templates that the catalogue check keeps, at most five (OD-79), the removal template, a claim template if the catalogue check finds a launch protocol that pays rewards, the budget factory, the first-loss burn factory and the two top-up factories (OD-78) [s3][s4][s5].
- Rewrite the shared payment permission of the Easy Track executor to add USDS, with a ceiling of 2,000,000 per payment (OD-11, OD-24) [s5].
- Add USDS to the shared stablecoin token list: Voting takes the list's add-token role, adds USDS and gives the role up (OD-93) [s5][s9].

### The vault's Safes

Each Safe's changes form one or more batches. The vote approves the hash of each batch on its Safe, and anyone sends the batch after the vote with that approval as Voting's signature (OD-92). The batches of one Safe run in nonce order [s9].


- **The Asset Safe.** Enable the operator modifier and the safety modifier, and apply the compiled policy on both: every permission, and every budget key with its ceiling, the Lido Lend key and the spare keys of each token included (OD-69). Grant `operator` to the committee's Safe, `governance` and `exit-governance` to the Easy Track executor, and `emergency`, with the switch, to the emergency Safe [s2][s3][s6].
- **The orders account.** Set CoW's fallback handler, and ComposableCoW as the verifier of CoW's settlement domain. Enable the orders modifier and apply its policy: the operator's orders on the launch lists, and the emergency role's recovery orders, transfers and cancels. Grant `operator` to the committee's Safe and `emergency` to the emergency Safe; the orders modifier has no governance role (OD-78). Approve CoW's vault relayer for every listed token, the recovery tokens included [s4].
- **The first-loss Safe.** Enable the first-loss modifier and apply its policy. Grant `first-loss` to the committee's Safe and `first-loss-burn` to the Easy Track executor [s5].

### Order

The vote's items run when it executes, about five days after it starts. Then anyone sends the Safe batches, in each Safe's nonce order. The committee's Safe creates motions only after the batches ran. Monitoring warns when few of Easy Track's shared open-motion slots are free, and the budget factory can set several keys in one motion (OD-94) [s9].

## After the vote, without another vote

- Anyone sends the Safe batches that the vote approved (OD-92) [s9].
- The Growth Committee's Safe moves the first-loss shares to the first-loss Safe [s5].
- The committee's Safe creates the seed motion [s5].
- Lido Lend joins by one onboarding motion, because its key is already in the policy [s6].
- The owners of the committee's Safe set the screening guard on it (OD-83), and a forum post lifts the launch cap (OD-54, OD-55) [s7].
- Each Safe's own owners rotate its signers. A Snapshot fills the fifth seat of the emergency Safe [s2].

## What still needs a vote after launch

| Kind | What | Where |
|---|---|---|
| Still a vote | A token for the orders account, for any order type, with its relayer approval | OD-78 [s4] |
| By design | A new mandate size, and a re-pin of the stETH limit if wanted | [s5] |
| By design | An onboarding template that the launch did not register, with its first protocol, and a claim template that did not ship | OD-72, OD-79 [s3] |
| By design | Role membership; replacing a Safe, a modifier or a factory; delegatecall for the operator; another module or a Safe version change; the shared payment permission or token list; ending the first-loss terms | [s2][s3][s5] |
| Later, by vote | Insurance funds for other products: the fund roles and templates, and a third funding registry and top-up factory | OD-78 [s5] |
| After an emergency | Every restart: the operator modifier, with the operator's permissions on the orders account and any relayer approval set to zero; a funding limit that a vote set to zero; an Easy Track unpause; a repair of the safety modifier | OD-59, OD-78 [s2][s3] |
| How | Each vote above is a direct Voting item of about five days, without Dual Governance, because Aragon Voting owns the vault's Safes | OD-73 [s1] |

Motions cover the rest, since EM's decisions of 2026-10-14 (OD-69, OD-70, OD-72): a budget for a new spender from a spare key, a routine removal, and a reward claim through the claim template, if it shipped [s1]. The review behind this table is in the research note [s8].
