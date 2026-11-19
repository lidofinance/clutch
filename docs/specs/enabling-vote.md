---
type: Specification
title: The enabling vote
description: Prerequisites and the mandate's owed text, direct Aragon Voting items without Dual Governance, the initial funding by the vote's payments, post-vote actions, the few changes that still need a vote, and the full rehearsal still owed.
tags: [governance, enabling-vote, deployment, specs]
status: draft
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-19T16:13:10Z
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
    title: ADR 009 — the budget keys and the fixed approval ceilings
  - id: s7
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch without the guard, and the guard at the volume threshold
  - id: s8
    resource: /research/easy-track-first-2026-11-05.md
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's admin role and the Aragon Agent's roles, read on chain on 2026-10-14
  - id: s9
    resource: /research/enabling-vote-rehearsal-2026-10-15.md
    title: The enabling vote rehearsed on a mainnet fork, 2026-10-15 and 2026-10-22 — the vote of approved hashes under EIP-7825
  - id: s10
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — the universal factory, its address book, its counter and policy version, and the votes that remain after launch
  - id: s11
    resource: /adr/014-funding-by-top-up-motions.md
    title: ADR 014 — the initial funding, top-up motions, insurance and the flows back to the treasury
  - id: s12
    resource: /research/easy-track-first-2026-11-05.md
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's roles, Finance payments by Aragon Voting, and the committee's principles on new members
  - id: s13
    resource: "urn:clutch:restricted:mandate-text-2026-11-19"
    title: The mandate's authorization text as of 2026-11-19; outside the repository until the mandate is published
---

# The enabling vote

Clutch launches with one Aragon vote, the enabling vote [s8]. After it, no administrative action needs an Aragon vote, and top-up motions carry the funding (OD-140). Only a few break-glass and Lido-wide actions stay votes, and a change of a top-up registry's limit is one of them (OD-101, OD-125, OD-146) [s10][s11].

Aragon Voting stores the whole script when a vote starts. With the Safe batches inside, that transaction would need more gas than EIP-7825 lets one transaction use, so the vote approves the hash of each batch instead (OD-92) [s9].

## Before the vote

- **Snapshots.** The mandate, with its figures and the owed text below. Its Snapshot sets the class of the emergency Safe's fifth signer, and the acceptor names the person before the vote (OD-58, OD-65) [s1][s2].
- **Figures.** An attested computation sets every budget, every fixed approval ceiling, each top-up registry's limit, and the initial funding's tokens and amounts [s6][s10][s11].
- **Decisions.** Every OD is decided [s1].
- **Deployments.** They need no authority. Clutch's script creates the Asset Safe, the orders account and the first-loss Safe with Aragon Voting as their only owner, and the emergency Safe with its signers, all on Safe v1.5.0 (OD-17, OD-126). It deploys the four Roles modifiers as minimal proxies through the Zodiac module proxy factory, and the universal factory with the committee's Safe as its trusted caller. Through Lido's deployed registry factories, it deploys the two funding registries, with Aragon Voting as their admin and the Asset Safe as their only recipient, and their two top-up factories, with the committee's Safe as trusted caller. It sets each registry's limit and its period of three months, and gives up its roles (OD-140 to OD-143). The factory's constructor fixes that caller, Easy Track's executor, the emergency Safe, Aragon Voting and the four modifiers; it holds no other state than its counter and its policy version (OD-80, OD-102, OD-135) [s2][s10].
- **Checks.** The fork tests of the order signer and of CoW's fallback handler on Safe v1.5.0 behind a Roles modifier, which pass at block 26249900, run again at a recent block ([research note](/research/orders-account-fork-tests-2026-11-07.md)) [s4]. The external audit of the universal factory and the order signer (OD-96). The check of Safe's releases, advisories and bug-bounty records [s7]. The policy compiled for mainnet from the reviewed constellation. The policy's source against the mandate's protocols and the committee's named pipeline. The Safe batches, published as a file with each batch's Safe, nonce and MultiSend data. `just batches-check <file>` computes each batch's hash again, as Safe v1.5.0 does, and fails unless the batches carry the compiled policy and the vault's setup, and nothing else. A reviewer compares each `approveHash` item of the vote with the hashes that the command prints. The full rehearsal below, at a recent block [s9][s10].

## The mandate's owed text

EM named the mandate's text of 2026-11-19 the source of truth, and the design follows it (OD-160 to OD-167) [s1][s13]. The text carries what the design needs on custody, the committee's members, the venue and the assets, the top-up channels, the first-loss terms, the reports and the votes that remain. It still owes these changes (OD-90):

- **Screening.** One rule for the guard: it is set when the vault's volume in a quarter passes the threshold. The go-live condition, the table of guardrails and the list of control layers must say the same. They must not say that screening holds a limit or an order's price before the guard is set (OD-160). The text defines the volume and its quarter (OD-168).
- **Monitoring.** Monitoring runs from go-live, and not from the volume threshold ([ADR 010](/adr/010-pre-execution-screening.md)).
- **Funding.** The enabling vote pays the initial funding from the treasury. The holder's signers move the Earn positions after the vote; the vote cannot. The text must not say that every funding is a top-up motion, and a test with real funds cannot come before the vote (OD-161).
- **Twyne.** It leaves the launch list and comes by a later onboarding motion (OD-162).
- **The fifth signer.** The sentence names the class: a Lido Labs engineering contributor who is a member of neither body (OD-65).
- **Reporting.** The runway reading needs the DAO's operating expenses, so not every line of a report can be rebuilt from on-chain data (OD-163).

The treasury share is Clutch's own rule, and the text needs none (OD-164).

The forum post carries the emergency section and the controls: the emergency Safe is three of five, with two committee members, two Emergency Brakes members and a fifth signer, a Lido Labs engineering contributor who is a member of neither body (OD-58, OD-65); the emergency swap goes into USDC, or into USDT as the second destination (OD-26); and the [control matrix](/specs/control-matrix.md) says how each rule is kept (OD-39). The LIP alone states the price waterfall (OD-62).

## The vote

Aragon Voting runs the Easy Track and payment items itself. It holds Easy Track's admin role and Finance's payment permission, which has no parameters [s12]. For the vault's Safes, which it owns (OD-73), it approves the hash of each Safe batch, and anyone executes the batches after the vote (OD-92) [s9]. No item passes Dual Governance, because none needs the Aragon Agent to act [s1][s12].

### Easy Track

- Register the universal factory in Easy Track. Its permissions are its address book: one call, the factory's own `applyMotion` (OD-102, OD-118) [s10]. It is the only factory of Clutch's own code.
- Register the two top-up factories, which are Lido's own code in new instances: one for stETH, and one for the DAO's stablecoin list, which holds DAI, USDC, USDT and sUSDS. Each may call its registry's `updateSpentAmount` and Finance's `newImmediatePayment`, and nothing else (OD-141, OD-142) [s11].

### The initial funding

- The vote pays the initial funding: one call of Finance's `newImmediatePayment` for each token, from the treasury to the Asset Safe, in the amounts of the attested computation. The payments pass no top-up registry and no objection window (OD-161) [s11][s12].
- The funds reach the Asset Safe before the Safe batches run. Until then the Safe has no module, and only Aragon Voting, its owner, can move them [s2].
- The vote does not move the Earn positions. The Growth Committee's Safe transfers them after the vote [s5].

### The vault's Safes

Each Safe's changes form one or more batches. The vote approves the hash of each batch on its Safe, and anyone sends the batch after the vote with that approval as Voting's signature (OD-92). The batches of one Safe run in nonce order [s9].

- **The Asset Safe.** Enable the operator modifier and the safety modifier, and apply the compiled policy on both: every permission, and every budget key of the launch tokens. A spender that joins later gets its key with its motion (ADR 013 decision 9). The operator's permissions include a transfer of each listed token to the Aragon Agent (OD-108). Grant `operator` to the committee's Safe; `governance` and `insurance-funding` on the operator modifier, and `exit-governance` and `restart` on the safety modifier, to the universal factory; and `emergency`, with the switch, to the emergency Safe [s2][s6][s10][s11].
- **The orders account.** Set CoW's fallback handler, and ComposableCoW as the verifier of CoW's settlement domain. Enable the orders modifier and apply its policy: the operator's orders on the launch lists and its transfers back to the Asset Safe or the Aragon Agent, and the emergency role's recovery orders, transfers and cancels. Grant `operator` to the committee's Safe, `emergency` to the emergency Safe, and the governance and approvals roles to the universal factory (OD-103, OD-118). Approve CoW's vault relayer for every listed token, the recovery tokens included [s4].
- **The first-loss Safe.** Enable the first-loss modifier and apply its policy. Grant `first-loss` to the committee's Safe, and `first-loss-burn` and the insurance roles to the universal factory (OD-107, OD-118) [s5][s11].

### Order

The vote's items run when it executes, about five days after it starts: the registration of the three factories, and the payments of the initial funding. Then anyone sends the Safe batches, in each Safe's nonce order. The committee's Safe creates motions only after the batches ran. Monitoring warns when few of Easy Track's shared open-motion slots are free (OD-94) [s9].

## After the vote, without another vote

- Anyone sends the Safe batches that the vote approved (OD-92) [s9].
- The committee's Safe creates a top-up motion when the vault needs more funding, within the gates of a top-up (OD-140, OD-144) [s11].
- The Growth Committee's Safe moves the first-loss shares to the first-loss Safe [s5].
- Lido Lend joins by an onboarding motion of the universal factory, and an insurance fund for it by another motion, after a Snapshot approves the insurance framework (OD-102, OD-107, OD-167) [s10][s11].
- The owners of the committee's Safe set the screening guard on it when the vault's volume passes the mandate's threshold, and the Zodiac UI requests the vendor's approval from that moment (OD-83, OD-121, OD-160) [s7].
- Each Safe's own owners rotate its signers. A change of the committee's members needs no Snapshot each time (OD-109). The acceptor names the fifth signer of the emergency Safe (OD-65) [s2].

## What still needs a vote after launch

[ADR 013](/adr/013-one-easy-track-factory.md) decision 4 lists the actions that stay Aragon votes: a change of a top-up registry's limit, period or recipients, the replacement of a role holder, an owner action on a vault Safe, a new or changed factory, and an Easy Track unpause (OD-101, OD-125) [s10]. Each is a direct Voting item of about five days, without Dual Governance, because Aragon Voting owns the vault's Safes and pays through Finance (OD-73) [s1][s12]. Motions of the universal factory cover the rest. The emergency Safe and the committee's Safe return funds to the Aragon Agent without a motion (OD-108) [s11].

## The full rehearsal

The fork suite rehearses the vote with the universal factory and the two top-up factories, the initial funding and a later top-up (`test/EnablingVoteRehearsal.t.sol`, `test/TopUps.t.sol`). Before the vote starts, the full vote is rehearsed at a recent block [s9][s10][s11]:

1. **Policy still owed.** The onboarding motion of Lido Lend's lender vault, against the deployed vault (OD-132, OD-133); the fork suite runs it against a stand-in.
2. **Deployment.** The script deploys the three Safes, the emergency Safe, the four modifiers and the factory.
3. **The vote.** The registration of the three factories, and one approved hash for each Safe batch. The batch builder keeps each batch under the gas and size limits that the rehearsal set.
4. **The run.** The vote's gas when it starts and when it executes; each batch's gas against EIP-7825 and its size against the transaction pool's limit. The initial funding in the Asset Safe after the vote. Then the first motions against the live Easy Track: a top-up; an onboarding; a budget; a token for the orders account, on both sides; an insurance fund, created and given money from the Asset Safe, and a payout to its pinned address; a first-loss redemption paid to the Asset Safe; the operator's return to the Aragon Agent; and the switch, the counter, a restart motion and the restore of the orders account. The run reads Easy Track's free motion slots at the block.
5. **Chain checks.** INV-032, the factory's registration, and INV-037, no Easy Track registry that lists a vault Safe; and the holders of Easy Track's admin, cancel and unpause roles, from the role events [s12].
6. **Records.** A research note records the run, and the invariants name the new tests.
