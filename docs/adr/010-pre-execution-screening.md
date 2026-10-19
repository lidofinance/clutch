---
type: Decision
title: "ADR 010: Pre-execution screening"
description: Transaction screening on the committee's Safe, vendor controls, outage behaviour and conditions for lifting the launch cap.
tags: [screening, guard, safe, security]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T22:33:22Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on on-chain blocking and the guard, 2026-09-22, on the route and the vendor's guard, 2026-10-02, on Safe v1.5.0, 2026-10-05, on the notice of a relaxed rule, 2026-10-13, and on the guard's Safe, 2026-10-14, kept on 2026-10-15
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

- A transaction guard checks the Safe's `execTransaction` after signatures and before execution, receiving signatures and sender [s5][s6]. Versions v1.3.0, v1.4.1 and v1.5.0 support it [s2].
- Module guards begin in v1.5.0 and see every enabled module, including safety [s3]. Recovery would depend on guard code admitting safety; the kit models this with one line [s9].
- The screening vendor's existing transaction guard is deployed on other Lido multisigs and enforcing on one. An external firm audited it in late 2025 [s7].
  - It cannot serve as a module guard; v1.5.0 refuses that assignment [s4][s7].
  - In practice, the vendor's key approves each exact transaction once on chain. Unapproved transactions revert [s7].
  - Owners remove it only through a fixed 10-day timelock that the vendor cannot block [s7].
  - After the audit's pinned fix review, the deployed build adds one change: both timelocks rise from 1 day to 10 days. This change is on a vendor branch, not `main`; documentation still says 1 day [s11].
  - Approval hashes can authorize one transaction once, one call at any nonce, or one function/target with any arguments. Only the first is transaction-specific [s11].
  - Lido's detector supports v1.3.0/v1.4.1 only. It watches standing approvals, both timelocks, bypass, policy contracts, keepers and guarded-Safe owner/guard/module changes [s11].
- Easy Track fixes trusted callers at deployment [s8].
- Due diligence found no v1.5.0 advisory or paid bounty and no Safe-contract defect behind its listed losses. Bybit's 2025 signed delegatecall replaced a Safe implementation; the Safe emits no event for that change [s12].

## Decision

EM decided on 2026-09-22 [s1]:

1. The screening vendor's integration can block the execution of suspicious transactions.
2. On-chain blocking is a hard requirement.
3. The screening vendor writes the guard, even if it does not have one yet.
4. The guard fails closed.
5. The screening vendor may flag a transaction without a Lido co-signature.
6. Either modifier may carry the governance role. Less complexity is preferred.
7. Replacing the operator modifier is a documented procedure.

EM decided on 2026-10-02, closing OD-01 [s1]: "Option 1: dedicated operator Safe with its own guard, also the trusted caller." EM chose it against four criteria: least code, least deployed surface, least audit surface, and lowest overhead and drift sensitivity. The guard is the screening vendor's existing transaction guard.

EM decided on 2026-10-02, closing OD-02 and OD-19 [s1]: both new Safes use Safe v1.5.0, on the condition that the vendor's guard is compatible with it, and the operator Safe's threshold is 4 of 7. The check of 2026-10-02 found the guard compatible with v1.5.0 [s10].

EM decided on 2026-10-02, closing OD-07 [s1]:

8. The DAO vote grants the operator role and registers the factories only after the guard is set on the operator Safe with its bypass mode off. This is checked when the vote starts and watched until it executes.
9. The agreement forbids standing approvals on this guard, of the nonce-free and the function-call kinds. The guard's two built-in timelock approvals stay.
10. The guard instance uses the build that the four Lido instances run, with 10-day timelocks. Lido reviews the one change made after the guard's audit. The vendor is asked to merge it into its main branch, correct its documentation and add it to its audit report.
11. The vendor's written confirmation that its approval service supports Safe v1.5.0 is a gate before deployment. Without it, the operator Safe uses Safe v1.4.1.
12. Lido's monitoring for this guard adds Safe v1.5.0 and the new instance. A dollar limit per top-up motion is a request to the vendor, not a gate.
13. The redaction of the vendor's identity ends when the mandate is posted on the forum, after the vendor agrees in writing to be named for this use. Commercial terms never enter this repository ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)).

EM confirmed on 2026-10-05, closing OD-12 [s1]:

14. The Lido-side party to the vendor agreement is the party that already holds the vendor's arrangement for the four guarded Lido multisigs. This repository does not name it.

EM decided on 2026-10-05, closing OD-17 [s1]:

15. The operator Safe runs Safe v1.5.0. EM reported that the vendor confirmed its support for v1.5.0. The gate of decision 11 is therefore met, and the v1.4.1 fallback no longer applies.
16. Before the enabling vote, Safe's releases, the advisory databases and Safe's bug-bounty records are checked again. A change that touches transaction execution, `approveHash`, module execution, the guard or owner management comes back to EM.
17. The vendor is asked to refuse every delegatecall from the operator Safe except to Safe's MultiSendCallOnly v1.5.0. This is a request, not a gate.
18. Lido's monitoring alerts on any change of the singleton of the Asset Safe, the operator Safe and the emergency Safe.

The other OD-17 decisions, on the Asset Safe and the emergency Safe, are in [ADR 005](/adr/005-account-graph-and-roles.md).

EM decided on 2026-10-06, closing OD-39 and OD-45 [s1]:

19. The screening vendor's rules for the vault are a written list in this repository, in the [control matrix](/specs/control-matrix.md). A relaxation of a rule is a change under control: the Emergency Brakes multisig and the forum get a notice, and the vendor's own delay applies if it has one ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 26 and 30).

EM decided on 2026-10-08 and 2026-10-09, closing OD-54 and OD-55 [s1]:

20. The vault may launch without the screening guard, under a cap of one million dollars on the Asset Safe and the orders account. Above the cap, on-chain blocking stays a hard requirement. This narrows decision 2.
21. The cap holds by procedure. The funding registries keep the limits of [ADR 008](/adr/008-funding-through-existing-payments.md). Until the cap lifts, the committee requests a top-up only while the vault stays at or below the cap. Monitoring alerts above the cap, and LDO holders can object to a top-up motion that would cross it.
22. A forum post lifts the cap once the guard is set on the operator Safe with its bypass mode off.

Decision 22 replaces decision 8: the enabling vote no longer waits for the guard, and the check of decision 8 applies to the lift. Decisions 9, 10 and 12 become conditions of the lift, not of the launch. Decision 18, the singleton alert, still applies from the launch.

EM decided on 2026-10-13, closing OD-64 [s1]:

23. A relaxation of a screening rule gets a notice on the forum only. The Emergency Brakes multisig no longer gets one. This replaces the notice to the Emergency Brakes multisig in decision 19.

Since OD-80, the committee's own Safe holds the operator role ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31), so decisions 8, 17, 18 and 22 name the committee's Safe where they name the operator Safe, and decision 17's batching library is the MultiSendCallOnly of Safe v1.3.0. Decisions 11 and 15, on Safe v1.5.0 for the operator, lapse, and so does decision 12's Safe v1.5.0 support: the committee's Safe runs v1.3.0, which Lido's detector supports [s11].

EM decided on 2026-10-14, closing OD-83 [s1]:

24. When the launch cap lifts, the guard is set on the committee's Safe. It screens every transaction of that Safe, the committee's other duties included, and a vendor outage stops them too.

Decision 24 takes Option 5, which was not chosen on 2026-10-02. The committee's Safe now holds the operator role (OD-80), so the guard of decisions 8, 10 and 22 is on it.

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Committee's Safe.** The existing four-of-seven v1.3.0 Safe holds `operator` and is every factory's trusted caller (OD-80). Its guard starts at cap lift (decision 24).
- **Guard setup.** Use the same build as Lido's guarded multisigs, set with `setGuard`. The vendor disables bypass. Re-enabling it needs vendor approval and a 10-day timelock [s11]. Only then can the cap lift (decision 22).
- **Screened actions.** Every committee Safe transaction: Asset Safe and orders activity, first-loss actions ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 21), motion creation and non-vault duties (decision 24). Enactment is unscreened; Easy Track's hash check fixes content at creation.
- **Unscreened paths.** Emergency and DAO use safety or owner authority. No guard sits on the Asset Safe, and Emergency Brakes has no vault role ([ADR 005](/adr/005-account-graph-and-roles.md), decision 23). Recovery never depends on guard code.
- **No modules.** The guarded committee Safe must have none: v1.3.0 lacks a module guard, so module execution would bypass screening [s2].
- **Removal.** Only committee Safe owners can remove the guard, after ten days. Outages stop operation for at most that delay; hostile removal remains visible throughout it.
- **Monitoring.** Add the new instance to the existing v1.3.0 detector (decision 12) [s11]. Watch both timelocks, bypass activation, standing approvals, keepers, added policy contracts and Safe module/guard/owner changes. One standing approval of the shared modifier execution function would approve all vault activity; the agreement forbids it (decision 9). Also alert critically on new Safes' singleton changes: delegatecall can replace implementations without Safe events (decision 18) [s12].
- **Delegatecalls.** Batching needs only the committee Safe's v1.3.0 MultiSendCallOnly. Ask the vendor to refuse other targets (decision 17); one approved stray delegatecall could replace the implementation and remove the guard.
- **Pre-vote check.** Repeat due-diligence advisory, release and bounty checks shortly before the enabling vote. Return changes on Clutch's Safe paths to EM (decision 16) [s12].
- **Tooling.** Add the instance to existing bytecode-verification and state-check configurations.
- **Rule changes.** Use reviewed pull requests, as for policy. Keep the vendor anonymous until announced.

**Capped launch (OD-54, OD-55):**

- The existing committee Safe remains unguarded until lift. The enabling vote grants `operator` and registers it as trusted caller. Owners add the guard later in one transaction; factories stay unchanged.
- Until then, permissions, four-of-seven signing, monitoring, emergency revocation and the switch protect funds within the cap.
- Count Asset Safe and orders value using [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 20. Exclude first-loss, which those roles cannot reach.
- The cap limits treasury funding. Price-driven excess requires reporting, not action.
- Alert during objection if a top-up would exceed the cap; report excess at each fortnightly reading.
- Before lift, set decision 10's guard, disable bypass, put decision 9's agreement in place and activate monitoring (decision 12). Check address, bypass and absent standing approvals. The committee's forum post links the check and lifts the cap.
- Vendor redaction ends only under decision 13.

**Requested screening rules (OD-39, OD-40, OD-43, OD-47):**

- Refuse operator transactions that breach the buffer floor or post-transaction cap.
- Refuse orders or router swaps whose limit/minimum output is too far below market.
- Mark each rule requested until the vendor confirms pre-execution support. Ask whether it records changes and can delay relaxations.

## Options considered

- **Route A, Asset Safe module guard:** rejected because recovery would depend on vendor code removable only by DAO vote. The existing guard cannot serve this role, requiring new vendor code and audit.
- **Option 3, dedicated operator with committee motion creation:** rejected because motions would escape screening despite fewer pinned addresses.
- **OD-83 B, new operator Safe at lift:** EM rejected because fixed trusted callers require redeploying all factories.
- **OD-83 C, cap without guard:** EM rejected.
- **Committee-owned one-of-one operator Safe (2026-10-15):** EM rejected it: "I don't like to have a nested interim safe" [s1]. It confines screening to vault activity, and one owner swap could move the operator role, but adds a Safe and nested execution for each action [s13].
- **Lido-written guard:** rejected as new non-factory code.
- **Detection or advisory screening only:** rejected because EM made on-chain blocking a hard requirement. EM permitted a capped unguarded launch on 2026-10-08 (decision 20).
- **Registry-enforced cap, lifted by vote (OD-54 A):** EM rejected. It would hold on chain at the cost of another DAO vote to lift it.
- **Second registry pair gated on guard installation (OD-54 B):** EM rejected because it adds a factory coupled to vendor code.
- **Three-million-dollar cap or mandate-set figure (OD-55 B/C):** EM rejected.

## Consequences

- Committee and emergency Safes share committee signers. Seat-affecting rotations update both.
- The committee Safe is the pinned operator and immutable factory caller [s8]. Replacement requires DAO re-registration of all factories. Guard removal after ten days avoids replacement for a vendor fault.
- The guard fails closed: outages stop operator activity and new motions, without affecting recovery.
- After lift, screening also covers Stonks orders/top-ups, the Stonks 2.0 price router, and LDO buyback manager/emergency duties (decision 24). Outages stop them for up to the removal delay. Emergency Brakes retains unscreened buyback-executor emergency authority [s13].
- No committee Safe module is allowed while guarded (INV-010).
- Before lift, operator actions and motion creation are unscreened. Above-cap top-ups breach procedure but do not revert; objection and monitoring are the controls.
- Guard setup and standing-approval terms gate cap lift, not launch.
- Lido does not write the guard, which can stop operator activity and motion creation. This deliberately narrows provider independence. Recovery independence, ten-day removal and the emergency switch, which disables the operator modifier, constrain this dependency (OD-58).
- Lido must review the post-audit 10-day timelock change; ask the vendor to merge and document it [s11]. It remains off `main`, with 1-day documentation. Earlier text wrongly counted the non-Safe-caller early return as another post-audit change; the fix-review commit already includes it [s11].
- v1.5.0 support rests on EM's 2026-10-05 report; the confirmation is outside this repository.
- If the vendor accepts the request, batching uses only MultiSendCallOnly; other delegatecalls fail screening.
- Naming requires mandate publication and written vendor consent. Restricted fork tests then enter the harness.
- Asset and emergency Safes use v1.5.0, the first among the six checked Lido Safes. The committee keeps v1.3.0: the guard passed Lido's fork tests on it [s10], and the detector supports it [s11].
- The mock module guard and route-A tests were removed on 2026-10-05. The harness has no screening test now. It needs transaction-guard coverage on a committee stand-in, preferably using deployed vendor bytecode.

## Confirmation

- INV-010 in the [invariants](/specs/invariants.md). It has no test for this route yet.
- Fork tests against the vendor's guard bytecode passed on 2026-10-02 on v1.3.0, v1.4.1 and v1.5.0: approved, unapproved and replayed transactions, in-band approvals, the 10-day removal path, and the path from the operator role's Safe through the Roles modifier [s10]. The tests identify the vendor, so they are restricted. They move into the harness when the vendor is announced.
- The estate's state checks on the new guard instance and on the committee's Safe: no modules, and the Safe is not its own approver.
- INV-019 in the [invariants](/specs/invariants.md): the Asset Safe and the emergency Safe run the pinned Safe v1.5.0 singleton, and the committee's Safe runs Safe v1.3.0.

## Reversal conditions

- The vendor cannot or will not run a guard instance for the committee's Safe.
- The review of the post-audit change finds a defect.
- The vendor does not accept the exclusion of standing approvals.
- Approval latency makes routine operation impractical.
- The vendor withdraws its support for Safe v1.3.0, the version of the committee's Safe.
- The committee's duties outside the vault cannot work under screening.
- The check before the enabling vote finds a Safe change on the vault's paths (decision 16).
- A top-up takes the vault above the cap before the lift (decision 21).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

Owed: the vendor's answers on the requested rules and on rule-change records and delays, before the lift.
