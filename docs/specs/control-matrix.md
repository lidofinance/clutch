---
type: Specification
title: Control matrix
description: Every mandate rule that this repository records, with its control on each layer that can carry it — the on-chain policy, screening before execution, monitoring with alerts, and display in the Zodiac UI — its owner and its status; and the written list of the screening vendor's rules, with their change control.
tags: [controls, mandate, monitoring, screening, specs]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-09T06:40:00Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on OD-39 to OD-45, 2026-10-06
  - id: s2
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — layered controls, the buffer, the cap tier of new products, the detectors and the Zodiac UI's display
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
---

# Control matrix

Every mandate rule gets a control on each layer that can carry it (OD-39) [s1][s2]:

- **On chain:** the permission policy refuses the transaction.
- **Before execution:** the screening vendor refuses an operator transaction. The emergency path and the DAO path are never screened [s4].
- **Detection:** monitoring finds a breach and alerts the person who must act.
- **Display:** the Zodiac UI shows the state and warns before signing (OD-44). Lido's readings are the canonical figures [s2].

Figures stay out of this page. They come from the attested computation once the mandate is approved. "Built" means built and tested on a fork; nothing is deployed.

## The matrix

| Rule | On chain | Before execution | Detection | Display | Owner | Status |
|---|---|---|---|---|---|---|
| The DAO keeps custody | The Aragon Agent is the only owner of the Asset Safe, the orders account and the first-loss Safe (INV-001, INV-021, INV-023) [s5][s8] | — | Owner, module and singleton alerts on every new Safe | Account graph | The DAO; `@lidofinance/defi-tech` specifies the alerts | Built for the Asset Safe; the other accounts specified |
| Only approved protocols and actions | Default deny; a new target only through a template motion with a 72-hour objection window, or a DAO vote (INV-004, INV-005) [s6] | Every operator transaction and every new motion | Drift against the committed policy artifact | The policy and its difference from the chain | The committee proposes; LDO holders can object; the emergency Safe revokes | Built; templates and drift detector specified |
| Every receiver is the vault | Receivers, owners and beneficiaries pinned (INV-003, INV-022) | Every operator transaction | Drift | — | `@lidofinance/defi-tech` | Built for positions; orders specified |
| No borrowing and no leverage | No borrow function in any role's permissions; INV-015 keeps the operator inside the launch scope | — | Drift | — | `@lidofinance/defi-tech` | Built; no test names borrowing |
| Spending per protocol spender is bounded | Budget keys per spender, and fixed ceilings (INV-008, INV-011, INV-012) [s2] | — | Budget burn; every budget motion, whose forum post names its event (OD-56) | Budget left per key | The committee files a budget motion after an event; no routine retune | Built with dry-run figures |
| Exposure caps | None: the policy cannot see value | Requested: refuse an operator transaction that breaches a cap at its post-transaction state | Fortnightly cap reading on IPFS; the Emergency Brakes multisig stops the operator when a breach gets worse (OD-29, OD-32) | Each cap against its limit, with warnings | The committee rebalances; the Emergency Brakes multisig acts on the trigger | Specified; screening requested |
| A new Lido product stays in the protocol cap until it matures (OD-41) | The product's budget key; the unlock is a budget motion with a forum post | — | The product's exposure against the protocol cap until the unlock | The product's tier | The committee proposes the unlock; LDO holders can object | Specified |
| Liquidity buffer of at least one month of baseline spend (OD-40) | None | Requested: refuse an operator transaction that takes the buffer below its floor | Continuous detector with an early-warning margin; a line in every report | The buffer against its floor | The committee restores it | Specified; screening requested |
| The first-loss shares stay untouched (OD-42) | In the first-loss Safe, which has no module (INV-021) [s7] | — | Any change of its balance, owners, modules or singleton | A separate sub-allocation | The DAO | Specified |
| Swaps pay the vault and stay inside the mandate (OD-43) | Orders only from the orders account, receivers and stop-loss oracles pinned; an order lives at most 30 days, a recovery order 1 day (INV-013, INV-014, INV-022, INV-023, INV-024) [s3] | Requested: refuse an operator order whose limit price lies too far below a market price, and a stop-loss expiry more than 30 days ahead. Recovery orders are never screened | Each fill against a market price; open orders, with an alert on any order older than 30 days; tokens left in the orders account; the watch-tower's posting; a high-severity page on every emergency swap; an alert on a recovery order whose limit sits far below a market price | Open orders | The committee; the emergency Safe cancels and sweeps | Specified; no price bound on chain: CoW's competition and EBBO rule hold fills to the on-chain market (OD-48) |
| Router swaps on Uniswap and 1inch only with an output bound (OD-43) | No permission at launch | Required before any router is added: a check of the minimum output against a market price | — | — | EM, once the vendor answers | Waits for the vendor |
| Funding only to the vault, within monthly limits | Two registries that pay only the Asset Safe (INV-017) [s7] | The creation of every top-up motion, once the launch cap lifts | Out-of-cycle top-ups, top-ups above the posted shortfall, a top-up after an objected one | Pending motions | The committee; LDO holders can object | Specified |
| Until the guard is live, the vault stays under a cap of one million dollars (OD-54, OD-55) | None: the registries allow more | None until the lift | A top-up motion whose enactment would take the vault above the cap, while its objection window is open; the vault's value above the cap at each fortnightly reading | The vault's value against the cap | The committee; LDO holders can object; the committee's forum post lifts the cap once the guard is set with its bypass mode off | Decided by EM on 2026-10-09; monitoring owed |
| No top-up while the monthly report is late | None | — | A missing report flagged on day 8 | Report status | The committee | Specified |
| Structural increases of exposure wait for a timelock (OD-45) | Motions with a 72-hour objection window, or DAO votes with the Dual Governance delay [s6] | The creation of every motion | Motion lifecycle | Pending motions and their deadlines | LDO holders; the Emergency Brakes multisig can pause Easy Track | Built on a mock Easy Track; specified |
| A relaxation of a screening rule is controlled (OD-45) | — | The written list below; the vendor's own delay, if it has one | A rule change, where the vendor reports one | — | The committee and `@lidofinance/defi-tech`; the Emergency Brakes multisig gets notice | Specified |
| A motion adds only exits to the emergency role (OD-49) | The exit-governance role writes only under the `emergency` key, with no delegatecall, no allowance and no administrative target (INV-025) | The creation of every motion | Drift on the safety policy | — | `@lidofinance/defi-tech` writes the templates; LDO holders can object | Specified |
| No delegatecall by motion, and no vault account as a motion's target | The governance role's guards (OD-36, OD-38) | — | Drift | — | `@lidofinance/defi-tech` | Built for the Asset Safe, and the compiler refuses a policy without the guard; the orders account specified |
| An emergency action starts within six hours | The emergency and technical roles (INV-002, INV-009) | Never screened | Paging through the general Lido incident process | — | The emergency Safe; the Emergency Brakes multisig | Built for the listed positions; a position that a motion onboards gets its emergency exit from that motion (OD-49), specified; runbooks and drills owed |
| Signers stay in step across three Safes | — | — | Owner-change alerts | Signer sets | The committee | Specified; runbook owed |
| Reports can be reproduced | — | — | The report generator at a pinned block | Lido's readings | `@lidofinance/defi-tech` builds the generator; the committee publishes | Specified |

The owner is who acts when the rule is at risk. `@lidofinance/defi-tech` writes the detector specification, and `@lidofinance/lido-valset-vroom` runs the monitoring platform (OD-13).

## The screening vendor's rules

These are the vault's rules in the vendor's service. A requested rule becomes decided only when the vendor confirms that it can check it before execution [s4].

| Rule | Applies to | State |
|---|---|---|
| Every operator Safe transaction needs the vendor's single-use approval; the guard fails closed | The operator Safe | Decided; applies from the lift of the launch cap (OD-54) |
| No standing approvals on the guard, except its two built-in timelock approvals | The guard | Decided; the vendor's written acceptance is owed |
| Refuse every delegatecall from the operator Safe except to MultiSendCallOnly v1.5.0 | The operator Safe | Requested |
| A dollar limit per top-up motion | Top-up motions | Requested |
| Refuse a transaction that takes the liquidity buffer below its floor | Operator transactions | Requested |
| Refuse a transaction that breaches a cap at its post-transaction state | Operator transactions | Requested |
| Refuse an order whose limit price, or a router swap whose minimum output, lies too far below a market price | Orders and router swaps | Requested |
| Refuse a stop-loss order whose expiry is more than 30 days ahead (OD-47) | Operator orders | Requested |
| Depegs, protocol compromise and counterparty anomalies | Monitoring | Decided that the vendor runs detectors ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 7); this list is proposed |

A relaxation of a rule changes this list in a reviewed pull request. The Emergency Brakes multisig and the forum get a notice, and the vendor's own delay applies if it has one (OD-45) [s1].
