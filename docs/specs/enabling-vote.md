---
type: Specification
title: The enabling vote
description: Prerequisites and the mandate's owed text, direct Aragon Voting items without Dual Governance, the first tranche, post-vote actions, the few changes that still need a vote, and the full rehearsal still owed.
tags: [governance, enabling-vote, deployment, specs]
status: draft
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T12:19:12Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions, 2026-09-22 to 2026-11-10
  - id: s2
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the accounts, the roles and their holders
  - id: s4
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the orders account, its lists, its roles and its relayer approvals
  - id: s5
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the first-loss Safe, the insurance funds and the mandate size
  - id: s6
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — the budget keys and their ceilings
  - id: s7
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch without the guard, and the guard before the second tranche's vote
  - id: s8
    resource: /research/easy-track-first-2026-11-05.md
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's admin role and the Aragon Agent's roles, read on chain on 2026-10-14
  - id: s9
    resource: /research/enabling-vote-rehearsal-2026-10-15.md
    title: The enabling vote rehearsed on a mainnet fork, 2026-10-15 and 2026-10-22 — the vote of approved hashes under EIP-7825
  - id: s10
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — the universal factory, its address book and versions, and the votes that remain after launch
  - id: s11
    resource: /adr/014-funding-by-tranche-votes.md
    title: ADR 014 — funding by tranche votes, insurance at launch and the flows back to the treasury
  - id: s12
    resource: /research/easy-track-first-2026-11-05.md
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's roles, Finance payments by Aragon Voting, and the committee's principles on new members
---

# The enabling vote

Clutch launches with one Aragon vote, the enabling vote [s8]. After it, no administrative action needs an Aragon vote. Only funding tranches and a few break-glass and Lido-wide actions stay votes (OD-101, OD-125) [s10].

Aragon Voting stores the whole script when a vote starts. With the Safe batches inside, that transaction would need more gas than EIP-7825 lets one transaction use, so the vote approves the hash of each batch instead (OD-92) [s9].

## Before the vote

- **Snapshots.** The mandate, with its figures and the owed text below. The emergency Safe's fifth signer (OD-58, OD-65) [s1].
- **Figures.** An attested computation sets every budget, every ceiling, and the first tranche's tokens and amounts [s6][s10][s11].
- **Decisions.** Every OD is decided except OD-65, which closes at the fifth signer's Snapshot [s1].
- **Deployments.** They need no authority. Clutch's script creates the Asset Safe, the orders account and the first-loss Safe with Aragon Voting as their only owner, and the emergency Safe with its signers, all on Safe v1.5.0 (OD-17, OD-126). It deploys the four Roles modifiers as minimal proxies through the Zodiac module proxy factory, and the universal factory with the committee's Safe as its trusted caller. The factory's constructor seeds the versions and the ceilings of the launch policy (OD-80, OD-102) [s2][s10].
- **Checks.** The fork tests of the order signer and of CoW's fallback handler on Safe v1.5.0 behind a Roles modifier, which pass at block 26249900, run again at a recent block ([research note](/research/orders-account-fork-tests-2026-11-07.md)) [s4]. The external audit of the universal factory and the order signer (OD-96). The check of Safe's releases, advisories and bug-bounty records [s7]. The policy compiled for mainnet from the reviewed constellation. The factory's shapes against the mandate's protocols and the committee's named pipeline. The Safe batches, published with one command that computes each hash again. The full rehearsal below, at a recent block [s9][s10].

## The mandate's owed text

The mandate's Snapshot text owes these items (OD-90) [s1]:

- **Products and caps.** Exposure to mature Lido products is unbounded. A new Lido product, Lido Lend first, stays in the protocol cap until it meets the maturity criteria and a motion unlocks it; earnETH and earnUSD are not new (OD-41). The illustrative balance renames its "USD-denominated" heading (OD-03).
- **Funding.** Tranche votes replace the draft's seed and top-ups through Easy Track. Each tranche is an Aragon vote that names its tokens, sUSDS included. The first tranche, one million dollars, is the launch cap, and the second tranche's vote starts only after the screening guard is set (OD-106, OD-121).
- **Size.** The mandate size and the treasury share, with the share's base, the time of its test, the remedy for a breach that no vault transaction causes, and the eligibility conditions of a replenishment (OD-89).
- **Reporting.** The late-report rule (OD-14), and each report's TMC-6 ratio for the whole treasury (OD-111). The vault keeps no liquidity buffer, because TMC-6's runway floor already applies to the whole treasury (OD-110).
- **Legacy and insurance.** The mandate takes over the first-loss terms of the March 2026 Earn allocation: the first-loss Safe holds the shares, and the committee executes the terms on the Earn team's written instruction, every burn as a motion and an exit through one narrow role whose proceeds stay in the vault (OD-21, OD-42, OD-60, OD-67, OD-108). Insurance covers earnETH, earnUSD and Lido Lend at launch, with the money from the Asset Safe by motion (OD-107).
- **The committee.** A change of the committee's members needs no token-holder vote each time. The committee's principles of 2023 ask token holders to approve each new member, so the text states the new rule (OD-109) [s12].
- **Swaps and assets.** CoW's market, limit and TWAP orders through the orders account are the only venue, nothing on chain bounds their price, and Uniswap and 1inch wait for a screening check of the output (OD-43, OD-79, OD-103). The asset list names ETH, WETH and Sky's DAI–USDS converter ([ADR 011](/adr/011-launch-scope.md)).
- **Custody.** Aragon Voting owns the vault's Safes, so no vault action passes Dual Governance (OD-73).

The forum post carries the emergency section and the controls: the emergency Safe is three of five, with two committee members, two Emergency Brakes members and a fifth signer who is a member of neither body (OD-58); the emergency swap goes into USDC, or into USDT as the second destination (OD-26); and the [control matrix](/specs/control-matrix.md) says how each rule is kept (OD-39). The LIP alone states the price waterfall (OD-62).

## The vote

Aragon Voting runs the Easy Track and payment items itself. It holds Easy Track's admin role and Finance's payment permission, which has no parameters [s12]. For the vault's Safes, which it owns (OD-73), it approves the hash of each Safe batch, and anyone executes the batches after the vote (OD-92) [s9]. No item passes Dual Governance, because none needs the Aragon Agent to act [s1][s12].

### Easy Track

- Register the universal factory in Easy Track. Its permissions are its address book: one call, the factory's own `applyMotion` (OD-102, OD-118) [s10]. It is the only Clutch factory.

### The first tranche

- One `newImmediatePayment` from Finance to the Asset Safe for each token, for one million dollars in total, with the forum post as the reference (OD-106). This tranche is the launch cap of [ADR 010](/adr/010-pre-execution-screening.md) decision 20 [s7][s11].

### The vault's Safes

Each Safe's changes form one or more batches. The vote approves the hash of each batch on its Safe, and anyone sends the batch after the vote with that approval as Voting's signature (OD-92). The batches of one Safe run in nonce order [s9].

- **The Asset Safe.** Enable the operator modifier and the safety modifier, and apply the compiled policy on both: every permission, and every budget key of the launch tokens with its ceiling. A spender that joins later gets its key with its motion (ADR 013 decision 9). The operator's permissions include a transfer of each listed token to the Aragon Agent (OD-108). Grant `operator` to the committee's Safe; `governance` and `insurance-funding` on the operator modifier, and `exit-governance` and `restart` on the safety modifier, to the universal factory; and `emergency`, with the switch, to the emergency Safe [s2][s6][s10][s11].
- **The orders account.** Set CoW's fallback handler, and ComposableCoW as the verifier of CoW's settlement domain. Enable the orders modifier and apply its policy: the operator's orders on the launch lists and its transfers back to the Asset Safe or the Aragon Agent, and the emergency role's recovery orders, transfers and cancels. Grant `operator` to the committee's Safe, `emergency` to the emergency Safe, and the governance and approvals roles to the universal factory (OD-103, OD-118). Approve CoW's vault relayer for every listed token, the recovery tokens included [s4].
- **The first-loss Safe.** Enable the first-loss modifier and apply its policy. Grant `first-loss` to the committee's Safe, and `first-loss-burn` and the insurance roles to the universal factory (OD-107, OD-118) [s5][s11].

### Order

The vote's items run when it executes, about five days after it starts: the factory's registration and the first tranche. The tranche waits in the Asset Safe, which only Aragon Voting controls until the batches run. Then anyone sends the Safe batches, in each Safe's nonce order. The committee's Safe creates motions only after the batches ran. Monitoring warns when few of Easy Track's shared open-motion slots are free (OD-94) [s9].

## After the vote, without another vote

- Anyone sends the Safe batches that the vote approved (OD-92) [s9].
- The Growth Committee's Safe moves the first-loss shares to the first-loss Safe [s5].
- Lido Lend joins by an onboarding motion of the universal factory, and an insurance fund for it by another motion (OD-102, OD-107) [s10][s11].
- The owners of the committee's Safe set the screening guard on it before the second tranche's vote starts, and the Zodiac UI requests the vendor's approval from that moment (OD-83, OD-121) [s7].
- Each Safe's own owners rotate its signers. A change of the committee's members needs no Snapshot each time (OD-109). A Snapshot fills the fifth seat of the emergency Safe [s2].

## What still needs a vote after launch

[ADR 013](/adr/013-one-easy-track-factory.md) decision 4 lists the actions that stay Aragon votes: each tranche after the first, the replacement of a role holder, an owner action on a vault Safe, a new or changed factory, and an Easy Track unpause (OD-101, OD-125) [s10]. Each is a direct Voting item of about five days, without Dual Governance, because Aragon Voting owns the vault's Safes and pays through Finance (OD-73) [s1][s12]. Motions of the universal factory cover the rest. The emergency Safe and the committee's Safe return funds to the Aragon Agent without a motion (OD-108) [s11].

## The full rehearsal

The fork suite rehearses the vote with the universal factory's prototype, the first tranche and a later tranche ([research note](/research/universal-factory-prototype-2026-11-05.md)). Before the vote starts, the full vote is rehearsed at a recent block [s9][s10][s11]:

1. **Policy still owed.** The shapes of the launch protocols, with the ERC-4626 shape, through which Lido Lend's lender vault joins (OD-132, OD-133).
2. **Deployment.** The script deploys the three Safes, the emergency Safe, the four modifiers and the factory.
3. **The vote.** The factory's registration, the first tranche, and one approved hash for each Safe batch. The batch builder keeps each batch under the gas and size limits that the rehearsal set.
4. **The run.** The vote's gas when it starts and when it executes; each batch's gas against EIP-7825 and its size against the transaction pool's limit; the first tranche in the Asset Safe. Then the first motions against the live Easy Track: an onboarding shape; a budget; a ceiling; a token for the orders account, on both sides; an insurance fund, created and given money from the Asset Safe, and a payout to its pinned address; a first-loss redemption paid to the Asset Safe, and the return of an excess above the cap; the operator's return to the Aragon Agent; and the switch, the counter, a restart motion and the restore of the orders account. The run reads Easy Track's free motion slots at the block.
5. **Chain checks.** INV-032, the factory's registration, and INV-037, no Easy Track registry that lists a vault Safe; and the holders of Easy Track's admin, cancel and unpause roles, from the role events [s12].
6. **Records.** A research note records the run, and the invariants name the new tests.
