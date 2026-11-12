---
type: Specification
title: Control matrix
description: Mandate controls across policy, screening, monitoring and UI, with owners, status and the screening vendor's written rule list and change control.
tags: [controls, mandate, monitoring, screening, specs]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-12T19:10:44Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on OD-39 to OD-45, 2026-10-06, on OD-64, 2026-10-13, on OD-84 to OD-88, 2026-10-20, on OD-100 to OD-112, 2026-11-05, and on OD-119 to OD-128, 2026-11-10
  - id: s2
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — layered controls, the cap tier of new products, the detectors, the two readings, and the TMC-6 line
  - id: s3
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — swaps through the orders account, and the absence of an on-chain price bound
  - id: s4
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the screening guard, the rules requested from the vendor, and their change control
  - id: s5
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the accounts and the roles
  - id: s6
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — motions as the timelock, and the guards on the governance role
  - id: s7
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — funding, and the first-loss Safe
  - id: s8
    resource: /specs/invariants.md
    title: Invariants — the on-chain properties that the tests check
  - id: s9
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — the universal factory, its raw writes, its policy version and counter, and the restart by motion
  - id: s10
    resource: /adr/014-funding-by-tranche-votes.md
    title: ADR 014 — funding by tranche votes, insurance at launch, and the flows back to the treasury
---

# Control matrix

Every mandate rule gets a control on each layer that can carry it (OD-39) [s1][s2]:

- **On chain:** the permission policy refuses the transaction.
- **Before execution:** once the screening guard is set on the committee's Safe, before the second tranche's vote starts (OD-83, OD-121), the screening vendor refuses an operator transaction. The Zodiac UI's signing flow also refuses one that breaches a cap, in its own interface only (OD-86). The emergency path and the DAO path are never screened or refused [s2][s4].
- **Detection:** monitoring finds a breach and alerts the person who must act.
- **Display:** the Zodiac UI shows the policy provider's own reading of the vault, and Lido's report generator publishes Lido's. The two readings are independent, and both count (OD-84) [s2].

Figures stay out of this page. They come from the attested computation once the mandate is approved. "Built" means built and tested on a fork; nothing is deployed.

## The matrix

| Rule | On chain | Before execution | Detection | Display | Owner | Status |
|---|---|---|---|---|---|---|
| The DAO keeps custody | Aragon Voting is the only owner of the Asset Safe, the orders account and the first-loss Safe (OD-73). Only emergency and recovery paths, and the operator's transfer pinned to the Aragon Agent, send funds back; redemption and fund-exit proceeds pay the Asset Safe (OD-108; INV-001, INV-021, INV-023, INV-038) [s5][s8][s10] | — | Owner, module and singleton alerts on every new Safe; an alert on every transfer to the Aragon Agent | Account graph | The DAO; `@lidofinance/defi-tech` specifies the alerts | Built for the Asset Safe and the orders account; the first-loss modifier's policy and the operator's return on the Asset Safe are owed |
| Only approved protocols and actions | Default deny; a new target only by a motion of the universal factory, with a 72-hour objection window. The factory's address book is its Easy Track registration. A motion's raw writes can widen a permission within the guards of each motion role's policy, so the objection window is the bound (OD-102, OD-134; INV-004, INV-005, INV-032, INV-034) [s6][s9] | Every operator transaction and every new motion, once the guard is set | Drift against the committed policy artifact; the chain against the policy that the repository says it holds, and every open motion of the factory against the repository's pending motion; a failure pages the emergency Safe (OD-136, OD-137) | The policy and its difference from the chain | The committee proposes; LDO holders can object; the emergency Safe revokes | Built for the guards and the factory's prototype; the drift detector specified |
| Every receiver is the vault | Receivers, owners and beneficiaries pinned (INV-003, INV-022) | Every operator transaction, once the guard is set | Drift | — | `@lidofinance/defi-tech` | Built for positions and orders |
| No borrowing and no leverage | No borrow function in any role's permissions; INV-015 keeps the operator inside the launch scope | — | Drift | — | `@lidofinance/defi-tech` | Built; no test names borrowing |
| Spending per protocol spender is bounded | Budget keys per spender, which a motion sets with a refill period of at least 30 days; the objection window bounds the amount (OD-134; INV-008, INV-011, INV-012) [s2][s9] | — | Budget burn; every budget motion, whose forum post names its event (OD-56); a budget set to more than twice its last value | Budget left per key | The committee files a budget motion after an event; no routine retune | Built with dry-run figures |
| Exposure caps | None: the policy cannot see value | The Zodiac UI refuses an operator transaction that breaches a cap at its post-transaction state, in its interface only (OD-86). Requested from the screening vendor: the same refusal | Fortnightly cap readings on IPFS, Lido's and the provider's; a breach in either counts (OD-84); the emergency Safe's switch stops the operator when a breach gets worse (OD-29, OD-32, OD-58) | Each cap against its limit, with headroom | The committee rebalances; the emergency Safe switches off on the trigger | Specified; screening requested |
| A new Lido product stays in the protocol cap until it matures (OD-41) | The product's budget key; the unlock is a budget motion with a forum post | — | The product's exposure against the protocol cap until the unlock | The product's tier | The committee proposes the unlock; LDO holders can object | Specified |
| The first-loss shares move only under the March 2026 terms (OD-42, OD-60) | In the first-loss Safe: a burn needs an enacted motion of the universal factory, and the first-loss role of the committee's Safe only redeems to the Asset Safe (OD-108); no role can transfer or approve the shares (INV-021) [s7][s10] | The objection window of every burn motion; the screening guard on its actions once the guard is set (OD-83) | Every burn motion and every action of the first-loss role; a redemption before the guard is set, and any excess above the cap that stays; any change of the first-loss Safe's balance, owners, modules or singleton | A separate sub-allocation | The committee, on the Earn team's written instruction; the DAO changes or removes the role | Built and tested on a fork with the first-loss modifier's policy and the burn motion |
| Swaps pay the vault and stay inside the mandate (OD-43) | Orders only from the orders account, receivers pinned, no stop-loss orders (OD-79); an order lives at most 90 days, a recovery order 1 day (INV-013, INV-014, INV-022, INV-023, INV-024) [s3] | Requested: refuse an operator order whose limit price lies too far below a market price. Recovery orders are never screened | Each fill against a market price; open orders, with an alert at 30 days that asks the committee to confirm or cancel each one, and every open order in the monthly report (OD-61); tokens left in the orders account; the watch-tower's posting; a high-severity page on every emergency swap; an alert on a recovery order whose limit sits far below a market price | Open orders | The committee; the emergency Safe cancels and sweeps | Built and tested on a fork; no price bound on chain: CoW's competition and EBBO rule hold fills to the on-chain market (OD-48) |
| Router swaps on Uniswap and 1inch only with an output bound (OD-43) | No permission at launch | Required before any router is added: a check of the minimum output against a market price | — | — | EM, once the vendor answers | Waits for the vendor |
| Funding only by tranche votes, and only to the vault (OD-106) | Only Aragon Voting pays the vault, through Finance; no Easy Track registry lists a vault Safe, and the factory's address book has no payment call (INV-037) [s10] | — | Every Finance payment to a vault Safe, matched to an enacted vote | Funding history | The DAO votes; the committee's forum post prepares each tranche | Decided (OD-106); built in the rehearsal; the chain check of INV-037 is owed |
| The vault stays within the mandate size and the treasury share (OD-89) [s7] | None | — | A tranche vote whose execution would take the funded value above the mandate size, or the vault above the treasury share, while the vote is open; the treasury share at each fortnightly reading | The funded value against the mandate size, and the vault's treasury share | The DAO votes each tranche; the committee's forum post states the headroom; a new size is a mandate change | Decided by EM on 2026-10-21; monitoring owed; the mandate owes the share's base, the time of its test and the remedy |
| Until the guard is live, the vault stays under a cap of one million dollars (OD-54, OD-55) | The first tranche, inside the enabling vote, is the cap (OD-106) [s10] | None until the guard is set | The vault's value above the cap at each fortnightly reading; a first-loss redemption before the guard is set, until the committee returns the excess to the Aragon Agent | The vault's value against the cap | The second tranche's vote is the only way above the cap, and it starts only once the guard is set with its bypass mode off (OD-121) | Decided (OD-106, OD-121); monitoring owed |
| No tranche vote starts while the monthly report is late (OD-122) | None | — | A missing report flagged on day 8; an alert on a tranche vote that starts while the report is late | Report status | The vote's proposer; the committee publishes the report | Specified |
| Structural increases of exposure wait for a timelock (OD-45) | Motions with a 72-hour objection window, with a policy version that fails a stale motion (OD-100, OD-135; INV-033); funding by tranche votes, which run as direct Voting items (OD-73, OD-106) [s6][s9] | The creation of every motion, once the guard is set | Motion lifecycle; failed enactments; raises of the factory's counter; free Easy Track motion slots (OD-94) | Pending motions and their deadlines | LDO holders; the Emergency Brakes multisig can pause Easy Track; the emergency Safe's switch freezes the vault's queued motions and raises the counter | Built and tested against the live Easy Track on a fork |
| The enabling vote installs exactly the reviewed Safe batches (OD-92) | Aragon Voting approves each batch's hash, and a batch with another content does not run [s5] | One command computes each hash again from the published batch, the Safe and its nonce | A batch that fails, or that waits after the vote executes | The published batches and their hashes | `@lidofinance/defi-tech` | Decided by EM on 2026-10-22; the command and the publication are owed |
| A relaxation of a screening rule is controlled (OD-45) | — | The written list below; the vendor's own delay, if it has one | A rule change, where the vendor reports one | — | The committee and `@lidofinance/defi-tech`; the forum gets notice (OD-64) | Specified |
| A motion adds only exits to the emergency role (OD-49) | The exit-governance role writes only under the `emergency` key, only exit trees pinned whole, with no delegatecall, no allowance and no administrative target (INV-025) | The creation of every motion, once the guard is set | Drift on the safety policy | — | `@lidofinance/defi-tech` writes the policy's source, from which each motion's trees come; LDO holders can object | Built and tested on a fork for the orders token, for an ERC-4626 lending vault and for each launch protocol |
| No delegatecall by motion except the order signer's, and no vault account as a motion's target | The governance role's guards (OD-36, OD-38); on the orders modifier, delegatecall only to the order signer, for signing and unsigning (OD-103; INV-040) [s3][s9] | — | Drift | — | `@lidofinance/defi-tech` | Built for the Asset Safe and the orders modifier, the factory's orders operations included, and the compiler refuses a policy without either guard |
| An emergency action starts within six hours | The emergency role, with its switch (INV-002, INV-009) | Never screened | Paging through the general Lido incident process | — | The emergency Safe; the Emergency Brakes multisig for the Easy Track pause | Built for the listed positions; a position that a motion onboards gets its emergency exit from that motion (OD-49), specified; runbooks and drills owed |
| The emergency Safe keeps its seat rule (OD-58) | — | — | Owner-change alerts, critical on the emergency Safe (INV-026) | Signer sets | The committee and the Emergency Brakes multisig, for their seats | Specified; runbook owed |
| No emergency body restores what it stopped (OD-59) | The emergency role holds only calls that remove authority, and the compiler refuses a grant or a budget for it (INV-027). Only the universal factory's restart role enables the operator modifier again (OD-104; INV-035) [s9] | — | Drift; any change of Easy Track's roles; every restart motion | — | The committee restarts by motion, after the objection window | Built for the Asset Safe, the restart by motion included; the Easy Track roles are a chain check before the enabling vote |
| Every asset has a price, with its level and source (OD-62) | None | — | The report generator's five-level waterfall; a tranche vote's post names every price below level 2; a tranche vote waits while level 5 covers more than the set share | Lido's reading, with each price's level and source; the provider's reading, with its own sources (OD-84) | The committee's valuation policy sets the band and the level-5 share | Specified; the figures are not set |
| Reports can be reproduced | — | — | The report generator at a pinned block | Lido's reading; the provider's report, on IPFS next to it (OD-85) | `@lidofinance/defi-tech` builds the generator; the committee publishes | Specified |
| The two readings agree within a band (OD-84) | None | — | Both published readings compared at each snapshot; a tranche vote that starts while they differ by more than the band | Both readings and their difference | The committee explains a difference; `@lidofinance/defi-tech` specifies the comparison | Specified; the band is not set |
| sUSDS and tokenized money market funds stay within TMC-6's share of the whole treasury (OD-111) | None | — | The ratio for the whole treasury, the vault's sUSDS included, in each monthly report | The ratio against TMC-6's cap | The committee rebalances under TMC-6 | Decided by EM on 2026-11-05; the report line is owed |
| Both readings use this repository's rules (OD-87) | — | — | A change of the mandate's rules made in the Zodiac UI is drift | The rules' version | `@lidofinance/defi-tech` sends each version after the Snapshot vote, motion or vote that changes a rule | Specified; the rule data is owed |
| The screening vendor approves in time (OD-88) | The guard fails closed (INV-010) | From the moment the guard is set, the Zodiac UI requests the vendor's approval for each transaction of the committee's Safe that it builds | A transaction of the committee's Safe that waits for approval longer than the set time | The approval state | The committee; `@lidofinance/defi-tech` specifies the alert | Specified; applies from the moment the guard is set (OD-121) |

The owner is who acts when the rule is at risk. `@lidofinance/defi-tech` writes the detector specification, and `@lidofinance/lido-valset-vroom` runs the monitoring platform (OD-13).

## The screening vendor's rules

These are the vault's rules in the vendor's service. A requested rule becomes decided only when the vendor confirms that it can check it before execution [s4].

| Rule | Applies to | State |
|---|---|---|
| Every transaction of the committee's Safe needs the vendor's single-use approval; the guard fails closed | The committee's Safe, its duties outside the vault included (OD-83) | Decided; applies from the moment the guard is set, before the second tranche's vote starts (OD-121) |
| No standing approvals on the guard, except its two built-in timelock approvals | The guard | Decided; the vendor's written acceptance is owed |
| Refuse every delegatecall from the committee's Safe except to the MultiSendCallOnly of its version | The committee's Safe | Requested |
| Refuse a transaction that breaches a cap at its post-transaction state | Operator transactions | Requested |
| Refuse an order whose limit price, or a router swap whose minimum output, lies too far below a market price | Orders and router swaps | Requested |
| Depegs, protocol compromise and counterparty anomalies | Monitoring | Decided that the vendor runs detectors ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 7); this list is proposed |

A relaxation of a rule changes this list in a reviewed pull request (OD-45, OD-64) [s1].
