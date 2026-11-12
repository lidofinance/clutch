---
type: Decision
title: "ADR 010: Pre-execution screening"
description: Transaction screening on the committee's Safe, the vendor's controls, outage behaviour, the launch cap, and the guard before any funding above the cap.
tags: [screening, guard, safe, security]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T23:13:05Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on on-chain blocking, the guard, its Safe, the launch cap, rule relaxations and the approval in the Zodiac UI, 2026-09-22 to 2026-11-10
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — guard hooks per Safe version, the committee Safe, Safe v1.5.0 provenance and audits
  - id: s3
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/base/ModuleManager.sol#L94-L108"
    title: Safe v1.5.0 ModuleManager — the module guard is called for every enabled module
  - id: s4
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/base/ModuleManager.sol#L258-L260"
    title: Safe v1.5.0 setModuleGuard — refuses a guard without the module-guard interface (GS301)
  - id: s5
    resource: "https://github.com/safe-global/safe-smart-account/blob/186a21a74b327f17fc41217a927dea7064f74604/contracts/base/GuardManager.sol#L7-L19"
    title: Safe v1.3.0 transaction guard — receives the signatures and the sender
  - id: s6
    resource: "https://github.com/safe-global/safe-smart-account/blob/186a21a74b327f17fc41217a927dea7064f74604/contracts/GnosisSafe.sol#L145-L150"
    title: Safe v1.3.0 execTransaction — checks the signatures, then calls the guard before it executes
  - id: s7
    resource: "urn:clutch:restricted:screening-guard-2026-10-02"
    title: Restricted evidence on the screening vendor's existing guard — source, audit, deployments and approval history, read at block 26104293; held outside the repository until the vendor is announced
  - id: s8
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/TrustedCaller.sol#L13"
    title: Easy Track TrustedCaller — the trusted caller is immutable
  - id: s9
    resource: "https://github.com/lidofinance/clutch/blob/3f75056a6b5cf163a7c287680a7c915d5769bb42/src/mocks/MockModuleGuard.sol#L39"
    title: Kit mock module guard — the safety-modifier exemption is one line of guard code
  - id: s10
    resource: /research/safe-v150-guard-compatibility-2026-10-02.md
    title: Safe v1.5.0 and the screening guard — the compatibility check of 2026-10-02
  - id: s11
    resource: "urn:clutch:restricted:screening-guard-build-2026-10-02"
    title: Restricted evidence on the guard's audit pin, its deployed build, its approval kinds and Lido's detector for it, checked 2026-10-02; held outside the repository until the vendor is announced
  - id: s12
    resource: /research/safe-v150-due-diligence-2026-10-05.md
    title: Safe v1.5.0 due diligence, 2026-10-05 — audits, advisories, use and value on mainnet, incidents, and MultiSendCallOnly v1.5.0
  - id: s13
    resource: /research/operator-safe-review-2026-10-15.md
    title: The committee's Safe as the operator, reviewed again on 2026-10-15 — its other duties, Lido's practice and the alternatives
---

# ADR 010: Pre-execution screening

## Context

- A transaction guard checks the Safe's `execTransaction` after the signatures and before the execution, and it receives the signatures and the sender [s5][s6]. Safe v1.3.0, v1.4.1 and v1.5.0 support it [s2].
- Module guards begin in v1.5.0 and see every enabled module, the safety modifier included [s3]. Recovery would then depend on guard code that admits the safety modifier; the kit models this with one line [s9].
- The screening vendor's existing transaction guard is deployed on other Lido multisigs and enforces on one. An external firm audited it in late 2025 [s7].
  - It cannot serve as a module guard; v1.5.0 refuses that assignment [s4][s7].
  - In practice, the vendor's key approves each exact transaction once on chain. An unapproved transaction reverts [s7].
  - The owners remove it only through a fixed 10-day timelock that the vendor cannot block [s7].
  - After the audit's pinned fix review, the deployed build adds one change: both timelocks rise from 1 day to 10 days. The change is on a vendor branch, not `main`, and the documentation still says 1 day [s11].
  - An approval hash can authorize one transaction once, one call at any nonce, or one function on one target with any arguments. Only the first is specific to a transaction [s11].
  - Lido's detector supports v1.3.0 and v1.4.1 only. It watches standing approvals, both timelocks, bypass, policy contracts, keepers, and the owner, guard and module changes of the guarded Safe [s11].
- Easy Track fixes a factory's trusted caller at deployment [s8].
- The due diligence found no Safe-contract defect behind its listed losses. Bybit's signed delegatecall of 2025 replaced a Safe's implementation; the Safe emits no event for that change [s12].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. The screening vendor's integration can block the execution of suspicious transactions (decision log, 2026-09-22).
2. Stated by decision 20 (decision log, 2026-09-22).
3. The screening vendor writes the guard, even if it does not have one yet (decision log, 2026-09-22).
4. The guard fails closed (decision log, 2026-09-22).
5. The screening vendor may flag a transaction without a Lido co-signature (decision log, 2026-09-22).
6. Either modifier may carry the governance role. Less complexity is preferred (decision log, 2026-09-22).
7. Replacing the operator modifier is a documented procedure (decision log, 2026-09-22).
8. Replaced by decision 22 (OD-54).
9. The agreement forbids standing approvals on this guard, of the nonce-free and the function-call kinds. The guard's two built-in timelock approvals stay (OD-07).
10. The guard instance uses the build that the four Lido instances run, with 10-day timelocks. Lido reviews the one change made after the guard's audit. The vendor is asked to merge it into its main branch, correct its documentation and add it to its audit report (OD-07).
11. Lapsed (OD-80): the committee's Safe runs Safe v1.3.0.
12. Lido's monitoring for this guard adds the new instance on the committee's Safe (OD-07, OD-80, OD-106).
13. Stated by [ADR 001](/adr/001-repository-scope-visibility-licence-name.md) decision 8 (OD-07).
14. The Lido-side party to the vendor agreement is the party that already holds the vendor's arrangement for the four guarded Lido multisigs. This repository does not name it (OD-12).
15. Lapsed (OD-80): the committee's Safe runs Safe v1.3.0.
16. Before the enabling vote, Safe's releases, the advisory databases and Safe's bug-bounty records are checked again. A change that touches transaction execution, `approveHash`, module execution, the guard or owner management comes back to EM (OD-17).
17. The vendor is asked to refuse every delegatecall from the committee's Safe except to Safe's MultiSendCallOnly v1.3.0. This is a request, not a gate (OD-17, OD-80).
18. Lido's monitoring alerts on any change of the singleton of the Asset Safe, the committee's Safe and the emergency Safe (OD-17, OD-80).
19. The screening vendor's rules for the vault are a written list in this repository, in the [control matrix](/specs/control-matrix.md). A relaxation of a rule is a change under control: the forum gets a notice (decision 23), and the vendor's own delay applies if it has one ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 26) (OD-39, OD-45, OD-64).
20. The vault may launch without the screening guard, under a cap of one million dollars on the Asset Safe and the orders account. The launch tranche is the cap. Above the cap, on-chain blocking is a hard requirement (OD-54, OD-55, OD-106, OD-142).
21. Until the guard is set, the committee's Safe creates no top-up motion that takes the vault above the cap. Monitoring alerts on such a motion, and when the vault's value goes above the cap before the guard is set (OD-54, OD-142; the rule is the agent's reading, and OD-145 asks whether the cap holds on chain).
22. The guard goes on the committee's Safe, with its bypass mode off, before a funding above the cap starts: a top-up motion or a tranche vote. The guard is checked when that motion or vote starts and watched until it is enacted (OD-54, OD-83, OD-121, OD-142).
23. A relaxation of a screening rule gets a notice on the forum only (OD-64).
24. The guard is set on the committee's Safe (decision 22). It screens every transaction of that Safe, the committee's other duties included, and a vendor outage stops them too (OD-83, OD-121).
25. From the moment the guard is set, the Zodiac UI's signing flow sends each transaction of the committee's Safe that it builds to the screening vendor for its single-use approval, and shows the approval state (OD-88, OD-121).
26. Lido's monitoring alerts when a transaction of the committee's Safe waits for the vendor's approval longer than a set time. The detector specification, which `@lidofinance/defi-tech` writes (OD-13), sets the time (OD-88).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Guard setup.** The owners add decision 10's build with `setGuard`, in one transaction; the factory does not change. The vendor disables bypass. Turning bypass on again needs the vendor's approval and a 10-day timelock [s11].
- **Screened actions.** Every transaction of the committee's Safe (decision 24): Asset Safe and orders activity, first-loss actions ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 21), motion creation and the duties outside the vault. Enactment is unscreened; Easy Track's hash check fixes a motion's content at creation.
- **Unscreened paths.** The emergency role and the DAO act without the guard: none sits on the Asset Safe, so recovery never depends on guard code.
- **No modules.** The guarded committee's Safe must have none: v1.3.0 has no module guard, so a module's execution would bypass screening [s2].
- **Removal.** An outage stops the operator for at most the ten days of the removal timelock; a hostile removal stays visible throughout it.
- **Monitoring.** The existing v1.3.0 detector takes the new instance (decision 12) [s11]. One standing approval of the shared modifier's execution function would approve all vault activity; the agreement forbids it (decision 9).
- **Late approvals.** The alert of decision 26 compares the pending transactions of the committee's Safe with the vendor's approvals. It measures the latency of the reversal conditions.
- **Delegatecalls.** Batching needs only the MultiSendCallOnly v1.3.0 of the committee's Safe (decision 17). One approved stray delegatecall could replace the implementation and remove the guard.
- **Tooling.** Add the instance to the existing bytecode-verification and state-check configurations.

**Capped launch (decisions 20 to 22):**

- Until the guard is set, the permissions, four-of-seven signing, monitoring, the emergency revoke and the switch protect the funds within the cap.
- The cap counts the value of the Asset Safe and the orders account at the report's price rule ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 35 and 36). It leaves out the first-loss Safe, which those roles cannot reach.
- The cap limits treasury funding. An excess from a price move needs reporting, not action.
- Before a funding above the launch cap starts, set decision 10's guard, turn bypass off, put decision 9's agreement in place and start the monitoring of decision 12. Check the address, the bypass and the absence of standing approvals; the vote's forum post links the check (decision 22).

## Options considered

- **A module guard on the Asset Safe:** not chosen. Recovery would depend on vendor code that only a DAO vote can remove, and the role needs new vendor code and an audit.
- **A dedicated operator Safe:** not chosen (OD-80, OD-83). The trusted caller is fixed, so a new operator Safe needs a new factory, and motions created from the committee's Safe would escape screening.
- **A permanent cap without a guard:** not chosen (OD-83).
- **A one-of-one operator Safe that the committee's Safe owns:** not chosen. EM: "I don't like to have a nested interim safe" [s1]. It would confine screening to vault activity, but it adds a Safe and a nested execution for each action [s13].
- **A guard that Lido writes:** not chosen. It is new code beyond the universal factory ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 1).
- **Detection or advisory screening only:** not chosen (decision 20).
- **A three-million-dollar cap, or a figure that the mandate sets:** not chosen (OD-55).

## Consequences

- The trusted caller is immutable [s8], so a replacement of the committee's Safe needs a DAO vote that registers a new universal factory. The guard's removal after ten days avoids a replacement for a vendor fault.
- The committee's duties outside the vault that screening covers (decision 24) are Stonks orders and top-ups, the Stonks 2.0 price router, and the LDO buyback's manager and emergency duties [s13].
- Lido does not write the guard, which can stop operator activity and motion creation. This narrows provider independence on purpose. Recovery's independence, the ten-day removal and the emergency switch limit this dependency (OD-58).
- The harness needs transaction-guard coverage on a stand-in for the committee's Safe, preferably with the vendor's deployed bytecode.

## Confirmation

- INV-010 and INV-019 in the [invariants](/specs/invariants.md).
- Fork tests against the vendor's guard bytecode pass on v1.3.0, v1.4.1 and v1.5.0, the 10-day removal path and the path from the operator role's Safe through the Roles modifier included [s10]. The tests identify the vendor, so they are restricted. They move into the harness when the vendor is announced.
- The estate's state checks on the new guard instance and on the committee's Safe: no modules, and the Safe is not its own approver.

## Reversal conditions

- The vendor cannot or will not run a guard instance for the committee's Safe.
- The review of the post-audit change finds a defect.
- The vendor does not accept the exclusion of standing approvals.
- The approval latency makes routine operation impractical.
- The vendor withdraws its support for Safe v1.3.0, the version of the committee's Safe.
- The committee's duties outside the vault cannot work under screening.
- The check before the enabling vote finds a Safe change on the vault's paths (decision 16).
- The vault stays above the cap before the guard is set, after a first-loss redemption, without a return of the excess.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-145](/registers/open-decisions.md): How does the launch cap of one million dollars hold before the screening guard is set? The top-up factories exist from the enabling vote (OD-142), and a registry's limit for a period is far above the cap (OD-143). (A) By a rule: the committee's Safe creates no top-up motion that takes the vault above the cap, monitoring alerts on one, and LDO holders object within 72 hours. (B) On chain: the registries start with limits that sum to the cap, and one Aragon vote after the guard is set raises them to the limits of OD-143.

<!-- end of generated block -->

Owed: the vendor's answers on the requested rules and on rule-change records and delays, before a funding above the launch cap.
