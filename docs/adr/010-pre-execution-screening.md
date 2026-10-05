---
type: Decision
title: "ADR 010: Pre-execution screening"
description: A suspicious operator transaction is blocked on chain before it executes, by the screening vendor's existing transaction guard on a dedicated operator Safe that is also the trusted caller of every factory; it fails closed, and recovery never passes through vendor code; the operator Safe runs Safe v1.5.0, which the vendor supports, and the vendor is asked to refuse delegatecalls except to Safe's batching library.
tags: [screening, guard, safe, security]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on on-chain blocking and the guard, 2026-09-22, on the route and the vendor's guard, 2026-10-02, and on Safe v1.5.0, 2026-10-05
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
---

# ADR 010: Pre-execution screening

## Context

- A transaction guard sits on a Safe's own `execTransaction`. It receives the signatures and the sender, and it runs after the signature check and before execution [s5][s6]. Safe v1.3.0, v1.4.1 and v1.5.0 all have it [s2].
- A module guard exists only from Safe v1.5.0. The Safe calls it for every enabled module, the safety modifier included [s3]. With a module guard on the Asset Safe, recovery would pass only because the guard's own code lets the safety modifier through. In the kit, that is one line of mock code [s9].
- The screening vendor already has a transaction guard. It is deployed for other Lido multisigs and enforcing on one of them, and an external firm audited it in late 2025 [s7].
  - It is not a module guard, and Safe v1.5.0 refuses to set it as one [s4][s7].
  - In practice the vendor's key approves each exact transaction on chain, once, before it executes. A transaction without an approval reverts [s7].
  - The owners can remove the guard only through a fixed 10-day timelock that the vendor cannot block [s7].
  - The audit report pins the commit of its fix review. The build that the Lido multisigs run adds one later change: both timelocks, from 1 day to 10 days. That change is on a branch of the vendor's repository, not on its main branch, and the vendor's documentation still says 1 day [s11].
  - The vendor's key can approve three kinds of hash: one exact transaction, once; one exact call, at any nonce; or one function on one target, with any arguments. Only the first is bound to one transaction [s11].
  - Lido's on-chain monitoring already has a detector for this guard. It alerts on standing approvals, the start of either timelock, the bypass mode, policy contracts, keeper changes, and owner, guard and module changes on the guarded Safe. It supports Safe v1.3.0 and v1.4.1 only [s11].
- Easy Track's trusted caller is immutable [s8].
- The due diligence on Safe v1.5.0 found no advisory and no paid bounty that concerns v1.5.0. No loss in its list of incidents at Safe accounts came from a defect in Safe's contracts. At Bybit in 2025, one signed delegatecall replaced a Safe's implementation. A Safe emits no event of its own for such a change [s12].

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

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Operator Safe.** A new Safe with the committee's signers. It holds no assets and has no modules, ever. It holds the operator role on the operator modifier, and it is the trusted caller of every factory. It runs Safe v1.5.0, with a threshold of 4 of 7.
- **Guard.** One instance of the vendor's guard, of the build that the Lido multisigs run, set on the operator Safe with `setGuard`. The vendor's key then turns the bypass mode off. The owners cannot turn it on again without the vendor's approval and the 10-day bypass timelock [s11]. Only then does the enabling vote grant the operator role (decision 8).
- **What it screens.** Every transaction of the operator Safe: every operator action and the creation of every motion. Motion enactment is not screened, but Easy Track's hash check fixes a motion's content at creation.
- **What it never touches.** The emergency Safe, the Emergency Brakes multisig and the DAO path act through the safety modifier or the owner path, and no guard is set on the Asset Safe. Recovery is therefore unscreened by construction.
- **Removal.** Only the operator Safe's owners can remove the guard, through the 10-day timelock. A vendor outage therefore stops the operator for at most ten days, and a hostile removal stays visible for ten days.
- **Monitoring.** Lido's existing detector for this guard carries the alerts the vault needs: the start of either timelock, the bypass mode turning on, a standing approval, a keeper change, an added policy contract, and module, guard or owner changes on the operator Safe [s11]. It must add Safe v1.5.0 and the new instance (decision 12). Every operator transaction calls the same modifier function, so one standing approval of that function would approve all vault activity. The agreement forbids such approvals (decision 9). Lido's monitoring also needs a critical alert on any change of the singleton of the three new Safes (decision 18), because a delegatecall can replace a Safe's implementation without any Safe event [s12].
- **Delegatecalls.** The operator Safe needs a delegatecall only to batch calls through Safe's MultiSendCallOnly v1.5.0 [s12]. The vendor is asked to refuse every other delegatecall (decision 17). One approved delegatecall to another target could replace the operator Safe's implementation and remove the guard.
- **The check before the vote.** The advisory, release and bug-bounty reads of the due-diligence note [s12] run again shortly before the enabling vote starts. A change on the vault's Safe paths goes to EM (decision 16).
- **Tooling.** Add the new instance to the estate's existing bytecode-verification and state-check configurations for this guard.

## Options considered

- **Route A: a module guard on the Asset Safe.** Rejected. Recovery would depend on vendor code, and only a DAO vote could remove a failed guard. The vendor's existing guard cannot be set as a module guard, so route A would need new vendor code and a new audit.
- **Option 3: a dedicated operator Safe, with the committee's Safe kept as trusted caller.** Not chosen. It pins fewer addresses, but motions would not be screened.
- **Option 5: the guard on the committee's existing Safe.** Not chosen. It is the smallest deployment, but every committee transaction, including duties outside the vault, would need the vendor's approval.
- **A guard written by Lido.** Rejected: it would be a new contract other than a factory.
- **Detection and response only, or advisory screening in the signing flow.** Rejected: EM made on-chain blocking a hard requirement.

## Consequences

- Three Safes share the committee's signers: the committee's Safe, the operator Safe and the emergency Safe. Every signer rotation must update all three.
- The operator Safe's address is pinned in several places. It is the immutable trusted caller of every factory [s8] and the operator role's holder. Replacing it needs a DAO vote that re-registers every factory. A vendor fault does not force a replacement, because the owners can remove the guard after ten days.
- Fail closed: a vendor outage stops operator activity and new motions. Recovery is unaffected.
- The guard is the one component that can stop operator activity and motion creation, and Lido does not write it. This narrows provider independence on purpose. The structural mitigations are that recovery never passes through it, the owners can remove it after ten days, and the technical role can disable the operator modifier.
- The build adds one change after the audit's fix review: the 10-day timelocks. It is not on the vendor's main branch, and the vendor's documentation still says 1 day. Lido reviews the change, and the vendor is asked to merge and document it [s11]. An earlier version of this record counted two such changes. The second, an early return for callers other than the guarded Safe, is the commit that the report's fix review pins [s11].
- The vendor's support for Safe v1.5.0 rests on EM's report of 2026-10-05. The confirmation itself is outside this repository.
- If the vendor accepts the delegatecall request, the operator Safe can batch only through MultiSendCallOnly. Any other delegatecall then fails at screening.
- The vendor's name enters this repository when the mandate is posted on the forum, with the vendor's written consent. The restricted fork tests then move into the harness.
- The three new Safes run v1.5.0, the first in the Lido estate as far as the six Lido Safes checked show. The guard has no production history on v1.5.0; the fork check is the evidence [s10].
- The kit's mock module guard and its tests of the rejected route A were removed on 2026-10-05. The harness has no screening test now. It needs a transaction guard on a mock operator Safe, preferably the vendor's deployed bytecode on a fork.

## Confirmation

- INV-010 in the [invariants](/specs/invariants.md). It has no test for this route yet.
- Fork tests against the vendor's guard bytecode passed on 2026-10-02 on v1.3.0, v1.4.1 and v1.5.0: approved, unapproved and replayed transactions, in-band approvals, the 10-day removal path, and the path from the operator Safe through the Roles modifier [s10]. The tests identify the vendor, so they are restricted. They move into the harness when the vendor is announced.
- The estate's state checks on the new guard instance and on the operator Safe: no modules, and the Safe is not its own approver.
- INV-019 in the [invariants](/specs/invariants.md): the three new Safes run the pinned Safe v1.5.0 singleton.

## Reversal conditions

- The vendor cannot or will not run a guard instance for the operator Safe.
- The review of the post-audit change finds a defect.
- The vendor does not accept the exclusion of standing approvals.
- Approval latency makes routine operation impractical.
- The vendor withdraws its support for Safe v1.5.0.
- The check before the enabling vote finds a Safe change on the vault's paths (decision 16).

## Open questions

None open. OD-17 was decided on 2026-10-05.
