---
type: Decision
title: "ADR 010: Pre-execution screening"
description: A suspicious operator transaction is blocked on chain before it executes, by the screening vendor's existing transaction guard on a dedicated operator Safe that is also the trusted caller of every factory; it fails closed, and recovery never passes through vendor code.
tags: [screening, guard, safe, security]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T11:52:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on on-chain blocking and the guard, 2026-09-22, and on the route, 2026-10-02
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
---

# ADR 010: Pre-execution screening

## Context

- A transaction guard sits on a Safe's own `execTransaction`. It receives the signatures and the sender, and it runs after the signature check and before execution [s5][s6]. Safe v1.3.0, v1.4.1 and v1.5.0 all have it [s2].
- A module guard exists only from Safe v1.5.0. The Safe calls it for every enabled module, the safety modifier included [s3]. With a module guard on the Asset Safe, recovery would pass only because the guard's own code lets the safety modifier through. In the kit, that is one line of mock code [s9].
- The screening vendor already has a transaction guard. It is deployed for other Lido multisigs and enforcing on one of them, and an external firm audited it in late 2025 [s7].
  - It is not a module guard, and Safe v1.5.0 refuses to set it as one [s4][s7].
  - In practice the vendor's key approves each exact transaction on chain, once, before it executes. A transaction without an approval reverts [s7].
  - The owners can remove the guard only through a fixed 10-day timelock that the vendor cannot block [s7].
- Easy Track's trusted caller is immutable [s8].

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

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Operator Safe.** A new Safe with the committee's signers. It holds no assets and has no modules, ever. It holds the operator role on the operator modifier, and it is the trusted caller of every factory. It runs Safe v1.5.0 with a threshold of 4 of 7.
- **Guard.** One instance of the vendor's guard, set on the operator Safe with `setGuard`. Enforcement must be on before the operator role is granted.
- **What it screens.** Every transaction of the operator Safe: every operator action and the creation of every motion. Motion enactment is not screened, but Easy Track's hash check fixes a motion's content at creation.
- **What it never touches.** The emergency Safe, the Emergency Brakes multisig and the DAO path act through the safety modifier or the owner path, and no guard is set on the Asset Safe. Recovery is therefore unscreened by construction.
- **Removal.** Only the operator Safe's owners can remove the guard, through the 10-day timelock. A vendor outage therefore stops the operator for at most ten days, and a hostile removal stays visible for ten days.
- **Monitoring.** Alert on: the start of the guard's removal timelock or its bypass timelock; the bypass mode turning on; any approval that is not bound to one transaction; any new approver key; any added policy contract; and any module enabled or guard changed on the operator Safe. Every operator transaction calls the same modifier function, so one reusable approval of that function would approve all vault activity. The vendor agreement must exclude such approvals.
- **Tooling.** Add the new instance to the estate's existing bytecode-verification and state-check configurations for this guard.

## Options considered

- **Route A: a module guard on the Asset Safe.** Rejected. Recovery would depend on vendor code, and only a DAO vote could remove a failed guard. The vendor's existing guard cannot be set as a module guard, so route A would need new vendor code and a new audit.
- **Option 3: a dedicated operator Safe, with the committee's Safe kept as trusted caller.** Not chosen. It pins fewer addresses, but motions would not be screened.
- **Option 5: the guard on the committee's existing Safe.** Not chosen. It is the smallest deployment, but every committee transaction, including duties outside the vault, would need the vendor's approval.
- **A guard written by Lido.** Rejected: it would be a new contract other than a factory.
- **Detection and response only, or advisory screening in the signing flow.** Rejected: EM made on-chain blocking a hard requirement.

## Consequences

- Three Safes share the committee's signers: the committee's Safe, the operator Safe and the emergency Safe. Every signer rotation must update all three.
- The operator Safe's address is pinned in several places. It is the immutable trusted caller of every factory [s8], the member that the toggle factory administers, a value in the governance role's conditions, and the operator role's holder. Replacing it needs a DAO vote that re-registers every factory. A vendor fault does not force a replacement, because the owners can remove the guard after ten days.
- Fail closed: a vendor outage stops operator activity and new motions. Recovery is unaffected.
- The guard is the one component that can stop operator activity and motion creation, and Lido does not write it. This narrows provider independence on purpose. The structural mitigations are that recovery never passes through it, the owners can remove it after ten days, and the technical role can disable the operator modifier.
- The deployed guard includes two changes made after its audit's fix review: an early return for callers other than the guarded Safe, and the 10-day timelocks. The assurance phase must review both [s7].
- Both new Safes run v1.5.0, the first in the Lido estate as far as the six Lido Safes checked show. The guard has no production history on v1.5.0; the fork check is the evidence [s10].
- The kit still tests the rejected route A, with a mock module guard on the Asset Safe. The harness must move to a transaction guard on a mock operator Safe, preferably the vendor's deployed bytecode on a fork.

## Confirmation

- INV-010 in the [invariants](/specs/invariants.md). It has no test for this route yet.
- Fork tests against the vendor's guard bytecode passed on 2026-10-02 on v1.3.0, v1.4.1 and v1.5.0: approved, unapproved and replayed transactions, in-band approvals, the 10-day removal path, and the path from the operator Safe through the Roles modifier [s10]. The tests identify the vendor, so they are restricted. They move into the harness when the vendor is announced.
- The estate's state checks on the new guard instance and on the operator Safe: no modules, and the Safe is not its own approver.

## Reversal conditions

- The vendor cannot or will not run a guard instance for the operator Safe.
- The review of the post-audit changes finds a defect.
- Approval latency makes routine operation impractical.

## Open questions

- OD-07: the vendor agreement, its announcement, the review of the post-audit changes, and the vendor's confirmation that its approval service supports v1.5.0 Safes.
- OD-17: the incident-history check on Safe v1.5.0, which both new Safes now use.
