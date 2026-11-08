---
type: Specification
title: The enabling vote
description: Prerequisites, direct Aragon Voting items without Dual Governance, the first tranche, post-vote actions and the few changes that still need a vote.
tags: [governance, enabling-vote, deployment, specs]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-07T18:35:46Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions to OD-112, 2026-11-05
  - id: s2
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the accounts, the roles and their holders
  - id: s4
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the orders account, its lists, its roles and its relayer approvals
  - id: s5
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the first-loss Safe and the mandate size
  - id: s6
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — the budget keys and their ceilings
  - id: s7
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch without the guard, and the checks of the guard
  - id: s8
    resource: /research/single-vote-review-2026-10-14.md
    title: One Aragon vote to launch, Easy Track afterwards, 2026-10-14 — the review, and Easy Track's admin role read on chain
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
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's roles and Finance payments by Aragon Voting, read on chain
---

# The enabling vote

Clutch launches with one Aragon vote, the enabling vote [s8]. After it, no administrative action needs an Aragon vote. Only funding tranches and a few break-glass and Lido-wide actions stay votes (OD-101) [s10].

Aragon Voting stores the whole script when a vote starts. With the Safe batches inside, that transaction would need more gas than EIP-7825 lets one transaction use, so the vote approves the hash of each batch instead (OD-92) [s9].

## Before the vote

- **Snapshots.** The mandate, with its figures and its owed text: funding by tranche votes, changes of the committee's members without a Snapshot each time, insurance for earnETH, earnUSD and Lido Lend, and no liquidity buffer inside the vault ([LIP draft](/specs/lip-draft.md), open item 2). The emergency Safe's fifth signer (OD-58, OD-65) [s1].
- **Figures.** An attested computation sets every budget, every ceiling, and the first tranche's tokens and amounts [s6][s10][s11].
- **Decisions.** Every OD is decided except OD-65, which closes at the fifth signer's Snapshot [s1].
- **Deployments.** They need no authority. Clutch's script creates the Asset Safe, the orders account and the first-loss Safe with Aragon Voting as only owner, and the emergency Safe with its signers, on Safe v1.5.0; the orders account runs it only if its fork test passes. It deploys the four Roles modifiers as minimal proxies through the Zodiac module proxy factory, and the universal factory with the committee's Safe as its trusted caller (OD-80, OD-102) [s2][s10].
- **Checks.** The fork tests of the order signer and of CoW's fallback handler on Safe v1.5.0 behind a Roles modifier [s4], which passed on 2026-11-07 at block 26249900 and run again at a recent block ([research note](/research/orders-account-fork-tests-2026-11-07.md)). The external audit of the universal factory and the order signer (OD-96). The check of Safe's releases, advisories and bug-bounty records [s7]. The policy compiled for mainnet from the reviewed constellation. The factory's shapes against the mandate's protocols and the committee's named pipeline. The factory's versions, seeded from the compiled artifact. The Safe batches, published with one command that computes each hash again. A rehearsal of the vote and the batches at a recent block, with the first tranche [s9][s10].

## The vote

Aragon Voting runs the Easy Track and payment items itself. It holds Easy Track's admin role and Finance's payment permission, which has no parameters [s12]. For the vault's Safes, which it owns (OD-73), it approves the hash of each Safe batch, and anyone executes the batches after the vote (OD-92) [s9]. No item passes Dual Governance, because none needs the Aragon Agent to act [s1][s12].

### Easy Track

- Register the universal factory in Easy Track. Its permissions are its address book: `execTransactionWithRole` on the operator, safety, orders and first-loss modifiers, and the factory's own `commit` (OD-102) [s10]. It is the only Clutch factory.

### The first tranche

- One `newImmediatePayment` from Finance to the Asset Safe for each token, for one million dollars in total, with the forum post as the reference (OD-106). This tranche is the launch cap of [ADR 010](/adr/010-pre-execution-screening.md) decision 20 [s7][s11].

### The vault's Safes

Each Safe's changes form one or more batches. The vote approves the hash of each batch on its Safe, and anyone sends the batch after the vote with that approval as Voting's signature (OD-92). The batches of one Safe run in nonce order [s9].

- **The Asset Safe.** Enable the operator modifier and the safety modifier, and apply the compiled policy on both: every permission, and every budget key with its ceiling, the Lido Lend key included. The operator's permissions include a transfer of each listed token to the Aragon Agent (OD-108). Grant `operator` to the committee's Safe; `governance` and `insurance-funding` on the operator modifier, and `exit-governance` and `restart` on the safety modifier, to the Easy Track executor; and `emergency`, with the switch, to the emergency Safe [s2][s6][s10][s11].
- **The orders account.** Set CoW's fallback handler, and ComposableCoW as the verifier of CoW's settlement domain. Enable the orders modifier and apply its policy: the operator's orders on the launch lists and its transfers to the Aragon Agent, and the emergency role's recovery orders, transfers and cancels. Grant `operator` to the committee's Safe, `emergency` to the emergency Safe, and the governance and approvals roles to the Easy Track executor (OD-103). Approve CoW's vault relayer for every listed token, the recovery tokens included [s4].
- **The first-loss Safe.** Enable the first-loss modifier and apply its policy. Grant `first-loss` to the committee's Safe, and `first-loss-burn` and the insurance roles to the Easy Track executor (OD-107) [s5][s11].

### Order

The vote's items run when it executes, about five days after it starts: the factory's registration and the first tranche. The tranche waits in the Asset Safe, which only Aragon Voting controls until the batches run. Then anyone sends the Safe batches, in each Safe's nonce order. The committee's Safe creates motions only after the batches ran. Monitoring warns when few of Easy Track's shared open-motion slots are free (OD-94) [s9].

## After the vote, without another vote

- Anyone sends the Safe batches that the vote approved (OD-92) [s9].
- The Growth Committee's Safe moves the first-loss shares to the first-loss Safe [s5].
- Lido Lend joins by an onboarding motion of the universal factory, and an insurance fund for it by another motion (OD-102, OD-107) [s10][s11].
- The owners of the committee's Safe set the screening guard on it (OD-83). The second tranche's vote waits for the guard [s7][s11].
- Each Safe's own owners rotate its signers. A change of the committee's members needs no Snapshot each time (OD-109). A Snapshot fills the fifth seat of the emergency Safe [s2].

## What still needs a vote after launch

| Kind | What | Where |
|---|---|---|
| Funding | Each tranche after the first: one Finance payment per token to the Asset Safe. The second tranche lifts the launch cap and starts only after the screening guard is set | OD-106 [s11] |
| Break-glass | The replacement of a role holder, such as the committee's Safe in the operator role, with a new universal factory for the new trusted caller | OD-101 [s10] |
| Break-glass, as the agent reads OD-101 | A module, a Safe version or an owner change on a vault Safe; a new or changed factory, such as a shape that the factory lacks | OD-101 [s10] |
| Lido-wide | An Easy Track unpause, which only Aragon Voting can do | [s12] |
| How | Each vote above is a direct Voting item of about five days, without Dual Governance, because Aragon Voting owns the vault's Safes and pays through Finance | OD-73 [s1][s12] |

Motions of the universal factory cover the rest: onboarding and removal, budgets and ceilings, tokens on both sides of the orders account, the restart after a stop, the first-loss burn, and the creation, funding and payout of each insurance fund (OD-102 to OD-105, OD-107) [s10][s11]. The emergency Safe and the committee's Safe return funds to the Aragon Agent without a motion (OD-108) [s11].

## Rebuilding the rehearsal

The rehearsal of 2026-10-15 and 2026-10-22 built the vote of ADR 008: two funding registries, their top-up factories, a stand-in budget factory and the four USDS items [s9]. Since OD-102 and OD-106, that vote is not the vote on this page. The rebuild runs in two steps. Until a step replaces a test, the test stays as the evidence of the decisions that it served.

### Step 1: with the factory prototype

Done on 2026-11-05: the fork suite passes 74 tests, and the [research note](/research/universal-factory-prototype-2026-11-05.md) records the measures.

The fork prototype of the universal factory ([ADR 013](/adr/013-one-easy-track-factory.md), confirmation) rebuilds the Easy Track part of the vote [s10]:

1. **Harness.** `RehearsalBase` drops the funding registries, the top-up factories and the token-list interfaces. It deploys the prototype with the committee's Safe as its trusted caller, and builds its address book: `execTransactionWithRole` on the four modifiers and the factory's `commit`. The prototype replaces `BudgetFactoryStandIn`.
2. **Policy.** The constellation adds two roles of the Easy Track executor: `restart` on the safety modifier, pinned to `enableModule` with the operator modifier as its argument, and `insurance-funding` on the operator modifier, pinned to transfers to the first-loss Safe. The compiler's guard on protected targets allows exactly that one `enableModule` call. The rehearsal's manifest is compiled again, and reviewers approve the artifact's diff ([ADR 004](/adr/004-specifications-and-policy-as-data.md), decision 14).
3. **The vote.** One Easy Track item registers the factory with its address book, in place of the three factory items. The USDS items go. One `newImmediatePayment` from Finance for each token pays the first tranche, with stand-in amounts under the launch cap [s11].
4. **Tests.**
   - `test_02_enabling_vote_end_to_end` checks the factory's registration, and that the first tranche reaches the Asset Safe when the vote executes, before the batches run.
   - `test_03_ramp_up` replaces the seed and the top-ups with the first tranche and a later tranche vote in another token, such as USDS that the fork gives the Agent. Its budget motion runs through the prototype, with versions. A ceiling motion raises a ceiling twofold, and a second raise within 15 days fails.
   - `test_06_the_payment_rewrite_changes_only_usds` and `test_07_usds_reaches_the_vault_without_the_usds_items` retire, because they test items that no longer exist.
   - New tests run against the live Easy Track: a conflict on one scope, in both orders; disjoint scopes, in any order; the counter that fails a stale motion; a cancel; a restart motion after the switch; and each refusal of the factory.
   - `test_D4_the_switch_freezes_queued_motions_until_the_dao_restarts` becomes `test_D4_the_switch_freezes_queued_motions_until_a_restart_motion`, and the pages that cite it follow.
5. **Measures for EM.** The factory's size against the 24,576-byte limit of EIP-170, the gas per motion and the complexity of the checks, before decision 11 of ADR 013 can apply.

### Step 2: the full vote, before it starts

The full vote, rehearsed at a recent block [s9][s10][s11]:

1. **Policy.** The orders modifier's governance and approvals roles, with delegatecall only to the order signer; the first-loss modifier's `first-loss`, `first-loss-burn` and insurance roles; the operator's transfers to the Aragon Agent, on the Asset Safe and on the orders account; and the shapes of the launch protocols.
2. **Deployment.** The script deploys the three Safes, the emergency Safe, the four modifiers and the factory. The factory takes the versions of the launch policy from the committed artifact.
3. **The vote.** The factory's registration, the first tranche, and one approved hash for each Safe batch. The batch builder keeps each batch under the gas and size limits that the rehearsal set.
4. **The run.** The vote's gas when it starts and when it executes; each batch's gas against EIP-7825 and its size against the transaction pool's limit; the first tranche in the Asset Safe. Then the first motions against the live Easy Track: an onboarding shape; a budget; a ceiling; a token for the orders account, on both sides; an insurance fund, created and given money from the Asset Safe, and a payout to its pinned address; a first-loss redemption paid to the Asset Safe, and the return of an excess above the cap; the operator's return to the Aragon Agent; and the switch, the counter and a restart motion. The run reads Easy Track's free motion slots at the block.
5. **Chain checks.** INV-032, the factory's registration, and INV-037, no Easy Track registry that lists a vault Safe; and the holders of Easy Track's admin, cancel and unpause roles, from the role events [s12].
6. **Records.** A research note records the run. The checks of this page follow it, and the invariants name the new tests.
