---
type: Decision
title: "ADR 010: Pre-execution screening"
description: A screening guard must be able to block a suspicious operator transaction on chain before it executes; it fails closed, the vendor may flag alone, recovery is never screened, and the route for the hook is still open.
tags: [screening, guard, safe, security]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on on-chain blocking and the guard, 2026-09-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — guard hooks per Safe version, the committee Safe, Safe v1.5.0 provenance and audits
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — pre-execution screening and the two routes
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/Drills.t.sol#L778"
    title: Kit tests at 370e20a — the guard blocks a flagged operator transaction, never blocks recovery, and the DAO can remove it
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/script/DeployDryRun.s.sol#L55"
    title: Kit deploy script at 370e20a — preflight asserts the Safe v1.5.0 runtime codehash
---

# ADR 010: Pre-execution screening

## Context

- Only Safe v1.5.0 has a module-path guard setter. v1.4.1 and v1.3.0 guard only the owner path. The Roles mastercopy has no guard hook at all [s2].
- The Safe v1.5.0 singleton's runtime code matches the published deployment record. The release has audit reports by Ackee and Certora [s2]. The kit's deploy script asserts the codehash at preflight [s5].
- The committee's Safe runs v1.3.0, has an owner-path guard setter, and has no guard set [s2].
- A module guard sees the calling module but not the role key [s3].

## Decision

EM decided on 2026-09-22 [s1]:

1. The screening vendor's integration can block the execution of suspicious transactions.
2. On-chain blocking is a hard requirement. The Safe, the scripts, the documents and the tests change to meet it.
3. The screening vendor writes the guard, even if it does not have one yet.
4. The guard fails closed.
5. The screening vendor may flag a transaction without a Lido co-signature.
6. Being the first Safe v1.5.0 in the Lido estate is acceptable, after diligence on its audits and incident history.
7. Either modifier may carry the governance role. Less complexity is preferred.
8. Replacing the operator modifier is a documented procedure.

## Proposed direction

The kit implements route A below [s3][s4]. The choice of route is open (OD-01).

| | Route A: module guard on the Asset Safe | Route B: transaction guard on a dedicated operator Safe |
|---|---|---|
| Hook | `setModuleGuard`, at the asset boundary | `setGuard`, at the caller boundary |
| Safe version | v1.5.0 | v1.3.0 or later |
| Screens | the operator and governance | the operator only |
| Guarded Safe | the Safe that holds the assets | a caller that holds nothing |
| Extra deployment | none | a dedicated operator Safe with the committee's signers |

- In route A, the guard recognises the safety modifier by address and never screens it. Recovery therefore works even when the identical call is flagged [s4].
- The DAO can detach a failed guard through the owner path [s4].
- Governance stays on the operator modifier, the simpler structure. An onboarding motion is where a hostile target would enter, so screening it is wanted.
- The agent recommendation of 2026-09-22 is route B, with the two-modifier split kept for its own sake. The screening vendor's public material points to enforcement in the signing flow, not to an on-chain module guard. This is not proof, and it must be settled with the vendor (OD-07).

## Options considered

- Detect and respond only. Not chosen: EM made on-chain blocking a hard requirement.
- Advisory blocking in the signing flow. Not chosen: signers can proceed without the advice.
- A guard written by Lido. Not chosen: it would be a new contract other than a factory.

## Consequences

- The guard is the one component that can halt operator activity, and Lido does not write it. It brings its own audit, liveness risk and upgrade path. This narrows provider independence on purpose.
- The structural mitigations are that recovery is never screened, the DAO can detach the guard, and the technical role can disable the operator modifier.
- Fail closed means a vendor outage freezes the operator. In route A it also delays policy changes, because governance sits on the screened modifier.
- The vault would be the first Safe v1.5.0 in the Lido estate in route A.

## Confirmation

- INV-010 in the [invariants](/specs/invariants.md).
- Kit tests with a mock guard [s4]. The vendor's guard needs its own tests and audit.

## Reversal conditions

- The vendor cannot supply a guard for the chosen route.
- The guard's liveness record makes fail-closed unacceptable.

## Open questions

- OD-01: route A or route B.
- OD-02: the Asset Safe version if route B.
- OD-07: the vendor's guard: existence, author, audit, and whether the vault may launch before it exists. EM said "we can add it later".
- OD-17: the incident-history diligence on Safe v1.5.0. The audits are recorded; the incident history is not.
