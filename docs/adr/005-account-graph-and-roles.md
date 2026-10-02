---
type: Decision
title: "ADR 005: Account graph and roles"
description: A Safe owned only by the Aragon Agent holds the assets; two Roles modifiers split the operator and governance roles from the emergency and technical roles; a dedicated operator Safe with the committee's signers holds the operator role; the emergency Safe carries the same signers at a quorum of two; the Emergency Brakes multisig can disable the operator modifier and nothing else.
tags: [architecture, roles, safe, zodiac, emergency]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T14:28:58Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers of 2026-09-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Agent authority, committee Safes, Roles mastercopy
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — account graph, roles and deployment constraints
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/Drills.t.sol#L611"
    title: Kit test at 370e20a — module disabling is technical-only, pinned, and leaves recovery working
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/Drills.t.sol#L562"
    title: Kit test at 370e20a — emergency flow, with transfers pinned to the Agent
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/Drills.t.sol#L677"
    title: Kit test at 370e20a — adversarial operator
---

# ADR 005: Account graph and roles

## Context

- The Easy Track executor holds neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Aragon Agent. The Dual Governance admin executor holds both [s2].
- The committee's Safe runs v1.3.0 with a quorum of four of seven. The Emergency Brakes Safe runs v1.3.0 with a quorum of three of five, and it holds the Easy Track pause but not the unpause [s2].
- The Roles mastercopy is locked, with owner `0x…01` [s2]. It keeps its own storage from slot 0, so a Safe-style proxy in front of it bricks the instance. It must be deployed as an EIP-1167 minimal proxy through the Zodiac module proxy factory [s3].
- A module guard receives the calling module, not the role key. One modifier therefore cannot let a guard block the operator without also blocking recovery [s3]. The screening route chosen in [ADR 010](/adr/010-pre-execution-screening.md) puts no guard on the Asset Safe. The split stays because recovery must survive the technical role's switch.

## Decision

EM decided on 2026-09-22 [s1]:

1. The emergency role is a subset of the Treasury Management Committee: the same participants, with a quorum of two.
2. Financial risk, such as depegs, dependency failure and curator misbehaviour, is the common case. The committee's signers at the lower quorum answer it, and they can swap, exit and claim.
3. Module disabling belongs to the Emergency Brakes multisig, as a technical role. The engineering organisation watches technical risk, including bug-bounty submissions.
4. The Emergency Brakes multisig keeps the global Easy Track pause.
5. Keeping the emergency Safe's signers equal to the committee's is a manual runbook duty, as for HashConsensus and some Dual Governance committees.
6. The policy splits across two modifiers.

EM decided on 2026-10-02 [s1]:

7. A dedicated operator Safe with its own screening guard holds the operator role, and it is also the trusted caller of every factory ([ADR 010](/adr/010-pre-execution-screening.md)).
8. Both new Safes, the Asset Safe and the operator Safe, use Safe v1.5.0, on the condition that the screening vendor's guard is compatible with it. The check of 2026-10-02 found it compatible ([research note](/research/safe-v150-guard-compatibility-2026-10-02.md)).
9. The operator Safe's threshold is 4 of 7.

EM decided on 2026-10-02, closing OD-07 [s1]:

10. The screening vendor confirms in writing that its approval service supports Safe v1.5.0. Without that confirmation, the operator Safe uses Safe v1.4.1 ([ADR 010](/adr/010-pre-execution-screening.md)).

## Proposed direction

The rest of this section is the design that the kit implements [s3]. EM has not accepted it as text.

- **Asset Safe.** A new Safe owned one-of-one by the Aragon Agent. It holds every asset. No guard is set on it. It runs Safe v1.5.0.
- **Operator Safe.** A new Safe with the committee's signers. It holds no assets and has no modules. It carries the screening guard, holds the operator role and is the trusted caller of every factory. It runs Safe v1.5.0, or v1.4.1 if the vendor does not confirm v1.5.0 support, with a threshold of 4 of 7.
- **Operator modifier.** A minimal proxy of the Roles mastercopy. Owner, avatar and target are the Asset Safe. It carries the `operator` and `governance` roles.
- **Safety modifier.** A second minimal proxy with the same settings. It carries the `emergency` and `technical` roles.
- The Asset Safe owns both modifiers. A role's call executes as the Safe, so a narrowly scoped role can administer a modifier without any authority over the Agent. This is how the emergency role revokes the operator.
- Easy Track never receives authority over the Agent.

| Role | Holder | Modifier | May do | May not do |
|---|---|---|---|---|
| DAO | Aragon Agent, by vote through Dual Governance | owner path | everything: own the Safe, replace the policy, change membership | — |
| `operator` | operator Safe, the committee's signers, four of seven, screened ([ADR 010](/adr/010-pre-execution-screening.md)) | operator | open, adjust and close positions in approved protocols within budgets; approve approved spenders up to a cap; as manager of the rebalancing swap instances, place orders and recover unsold tokens to the Aragon Agent ([ADR 007](/adr/007-swapping-through-stonks.md)) | move assets out, except into a rebalancing instance; borrow; administer a modifier or the Safe; change its own permissions |
| `governance` | Easy Track executor | operator | toggle pre-scoped operator role keys; set operator budgets within ceilings | author a permission; name a target; grant a role to another address; touch the emergency role |
| `emergency` | emergency Safe, two signatures, the committee's signers | safety | zero approvals; exit positions to the Safe; send assets to recovery swap instances or to the Agent; revoke the operator's targets and functions; as manager of the recovery swap instances, place orders and recover tokens to the Aragon Agent | add a permission; enter a protocol; borrow; change the recovery destination; disable a module |
| `technical` | Emergency Brakes Safe, three of five | safety | disable the operator modifier; the module argument is pinned | anything else, including disabling the safety modifier |

## Options considered

- The Emergency Brakes multisig as the emergency role. Not chosen by EM: financial response needs the people who watch the portfolio daily.
- A separate technical committee. Not chosen: the Emergency Brakes multisig already holds the Easy Track pause and has technical members.
- One modifier for all roles. Not chosen: a guard could not tell recovery from the operator, and disabling the module would remove recovery too.
- The Agent as owner of the modifiers. Not chosen: the emergency role could then not revoke the operator without Agent authority.

## Consequences

- Three Safes share the committee's signers: the committee's Safe, the operator Safe and the emergency Safe. Every rotation must update all three. EM's decision makes this a manual runbook duty.
- The operator and the emergency role do not fail independently. They are the same people at different quorums. The guarantee that the operator cannot block an emergency action rests on role scoping alone.
- The compensating controls are one-way emergency powers, transfers pinned to the Agent or to recovery instances, and the DAO's power to replace the whole policy.
- Disabling the operator modifier leaves the safety modifier working, so recovery survives the technical switch [s4].
- The safety policy pins the operator modifier's address. Replacing the operator modifier therefore needs a DAO vote that rewrites the safety policy in the same action. EM accepted this as a documented procedure on 2026-09-22 [s1].
- Freezing queued motions needs the Emergency Brakes multisig, a different body. The general Lido incident process pages it.
- Every DAO-path action carries the Dual Governance delay.

## Confirmation

- INV-002, INV-003, INV-004 and INV-009 in the [invariants](/specs/invariants.md).
- Kit tests: the technical role is the only one that can disable a module, and only the operator modifier [s4]; the emergency flow returns assets to the Agent and nowhere else [s5]; the operator cannot widen or reach administration [s6].

## Reversal conditions

- A signer compromise that reaches the emergency quorum.
- An audit finding that a role can reach an owner-only surface.

## Open questions

- OD-17: the incident-history check on Safe v1.5.0, which both new Safes now use.
