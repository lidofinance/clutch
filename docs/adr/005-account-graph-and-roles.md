---
type: Decision
title: "ADR 005: Account graph and roles"
description: A Safe owned only by the Aragon Agent holds the assets; two Roles modifiers split the operator and governance roles from the emergency and technical roles; a dedicated operator Safe with the committee's signers holds the operator role; the emergency Safe carries the same signers at a quorum of two; the Emergency Brakes multisig can disable the operator modifier and nothing else; the three new Safes run Safe v1.5.0, and the Asset Safe has no fallback handler.
tags: [architecture, roles, safe, zodiac, emergency]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:58:30Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers of 2026-09-22, and later decisions to OD-30 on 2026-10-05
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Agent authority, committee Safes, Roles mastercopy
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — account graph, roles and deployment constraints
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L740"
    title: Kit test at 7a8c661 — module disabling is technical-only, pinned, and leaves recovery working
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L669"
    title: Kit test at 7a8c661 — emergency flow, with transfers pinned to the Agent
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L807"
    title: Kit test at 7a8c661 — adversarial operator
  - id: s7
    resource: /research/safe-v150-due-diligence-2026-10-05.md
    title: Safe v1.5.0 due diligence, 2026-10-05 — audits, advisories, use and value on mainnet, incidents, and the Safe paths the vault uses
  - id: s8
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L323-L328"
    title: Safe v1.5.0 checkNSignatures — a type-1 signature passes if the owner sent the transaction or approved its hash
  - id: s9
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/SafeExec.sol#L18-L29"
    title: Kit SafeExec at 370e20a — the owner approves the hash, then the Safe executes on a type-1 signature
  - id: s10
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/script/DeployDryRun.s.sol#L73-L77"
    title: Kit deployment script at 370e20a — the Asset Safe is set up with no fallback handler
  - id: s11
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L898"
    title: Kit test at 7a8c661 — the Asset Safe's owner, threshold, singleton, and missing fallback handler and guards
  - id: s12
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the dual-access emergency exit and an emergency committee independent of the Treasury Management Committee; outside the repository until the mandate is published
---

# ADR 005: Account graph and roles

## Context

- The Easy Track executor holds neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Aragon Agent. The Dual Governance admin executor holds both [s2].
- The committee's Safe runs v1.3.0 with a quorum of four of seven. The Emergency Brakes Safe runs v1.3.0 with a quorum of three of five, and it holds the Easy Track pause but not the unpause [s2].
- The Roles mastercopy is locked, with owner `0x…01` [s2]. It keeps its own storage from slot 0, so a Safe-style proxy in front of it bricks the instance. It must be deployed as an EIP-1167 minimal proxy through the Zodiac module proxy factory [s3].
- A module guard receives the calling module, not the role key. One modifier therefore cannot let a guard block the operator without also blocking recovery [s3]. The screening route chosen in [ADR 010](/adr/010-pre-execution-screening.md) puts no guard on the Asset Safe. The split stays because recovery must survive the technical role's switch.
- Safe v1.5.0 was released on 2025-07-03 and audited twice, by Certora with formal verification and by Ackee with fuzzing. No advisory and no paid bounty concerns it. Its record of holding value is short: 57 Safes were created on it through Safe's factory before March 2026, and Safe{Wallet} made it the version of new Safes on 2026-09-22 [s7].
- On a type-1 signature, the Safe accepts an owner that sent the transaction or approved its hash [s8]. The kit executes the Asset Safe's transactions this way [s9], and it sets up the Asset Safe without a fallback handler [s10].
- The mandate draft promises a dual-access emergency exit. The DAO, and an emergency committee independent of the Treasury Management Committee, can each return every asset to the treasury within six hours [s12].

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

EM decided on 2026-10-05, closing OD-09 [s1]:

11. Every removal of an operator permission is the emergency Safe's immediate revoke. No DAO-scoped role keys exist, so the revoke reaches every operator permission ([ADR 006](/adr/006-governance-through-easy-track-factories.md)).

EM decided on 2026-10-05, closing OD-17 [s1]:

12. The Asset Safe and the operator Safe keep Safe v1.5.0 after the due diligence [s7]. EM reported that the screening vendor confirmed its support for v1.5.0. The gate of decision 10 is therefore met, and the v1.4.1 fallback no longer applies.
13. The emergency Safe also uses Safe v1.5.0.
14. The Aragon Agent authorizes Asset Safe transactions only by `approveHash` or by sending them itself. It never uses a contract signature.
15. The Asset Safe has no fallback handler. A protocol that needs one comes back to EM.

EM decided on 2026-10-05, closing OD-29 and OD-30 [s1]:

16. The emergency Safe stays a subset of the committee's signers. The mandate text changes to match: it describes the emergency Safe as the committee's signers at two of seven, the technical role of the Emergency Brakes multisig, and a DAO vote as the path that is independent of the committee.
17. The LIP states that the fast exit is not independent of the committee.
18. The technical role also disables the operator modifier when a cap breach gets worse, on the trigger of [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 24.

The other conditions of OD-17 are in [ADR 010](/adr/010-pre-execution-screening.md): the check before the enabling vote, the delegatecall request to the vendor and the singleton alert. The LIP states the short record of v1.5.0.

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **Asset Safe.** A new Safe owned one-of-one by the Aragon Agent. It holds every asset. No guard and no fallback handler are set on it. It runs Safe v1.5.0. The Agent approves the hash of each transaction, or sends the transaction itself, so the Safe checks a type-1 signature (decision 14).
- **Operator Safe.** A new Safe with the committee's signers. It holds no assets and has no modules. It carries the screening guard, holds the operator role and is the trusted caller of every factory. It runs Safe v1.5.0, with a threshold of 4 of 7.
- **Emergency Safe.** A new Safe with the committee's signers and a threshold of two. It holds no assets and has no guard. It holds the emergency role on the safety modifier. It runs Safe v1.5.0.
- **Operator modifier.** A minimal proxy of the Roles mastercopy. Owner, avatar and target are the Asset Safe. It carries the `operator` and `governance` roles.
- **Safety modifier.** A second minimal proxy with the same settings. It carries the `emergency` and `technical` roles.
- The Asset Safe owns both modifiers. A role's call executes as the Safe, so a narrowly scoped role can administer a modifier without any authority over the Agent. This is how the emergency role revokes the operator.
- Easy Track never receives authority over the Agent.

| Role | Holder | Modifier | May do | May not do |
|---|---|---|---|---|
| DAO | Aragon Agent, by vote through Dual Governance | owner path | everything: own the Safe, replace the policy, change membership | — |
| `operator` | operator Safe, the committee's signers, four of seven, screened ([ADR 010](/adr/010-pre-execution-screening.md)) | operator | open, adjust and close positions in approved protocols within budgets; approve approved spenders, each approval spending its spender's budget key or staying below a fixed ceiling ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); stake ETH, and request and claim Lido withdrawals pinned to the Asset Safe ([ADR 007](/adr/007-swapping-through-stonks.md)); convert DAI to USDS and back through Sky's converter, pinned to the Asset Safe ([ADR 011](/adr/011-launch-scope.md)); as manager of the rebalancing swap instances, place orders and recover unsold tokens to the Aragon Agent ([ADR 007](/adr/007-swapping-through-stonks.md)) | move assets out, except into a rebalancing instance; borrow; administer a modifier or the Safe; change its own permissions |
| `governance` | Easy Track executor | operator | write operator permissions from a fixed template, for a target named in a motion; set operator budgets within ceilings | submit a condition tree; grant or remove any role; touch the emergency role; target a modifier or the Safe |
| `emergency` | emergency Safe, two signatures, the committee's signers | safety | zero approvals; exit positions to the Safe; unwrap wstETH and WETH, stake ETH and redeem sUSDS, so that recovery can sell them; send assets to recovery swap instances or to the Agent; revoke the operator's targets and functions, which is how every removal happens; as manager of the recovery swap instances, place orders and recover tokens to the Aragon Agent | add a permission; enter a protocol except by staking ETH; borrow; redeem the first-loss Earn shares ([ADR 008](/adr/008-funding-through-existing-payments.md)); change the recovery destination; disable a module |
| `technical` | Emergency Brakes Safe, three of five | safety | disable the operator modifier, for a defect in the permission layer or for a cap breach that gets worse (decision 18); the module argument is pinned | anything else, including disabling the safety modifier |

## Options considered

- The Emergency Brakes multisig as the emergency role. Not chosen by EM: financial response needs the people who watch the portfolio daily.
- A transfer permission to the Agent for the technical role, so that a body independent of the committee can return assets within six hours, as the mandate draft describes [s12]. Not chosen by EM (OD-30): it gives the Emergency Brakes multisig a power over assets.
- A separate technical committee. Not chosen: the Emergency Brakes multisig already holds the Easy Track pause and has technical members.
- One modifier for all roles. Not chosen: a guard could not tell recovery from the operator, and disabling the module would remove recovery too.
- The Agent as owner of the modifiers. Not chosen: the emergency role could then not revoke the operator without Agent authority.

## Consequences

- Three Safes share the committee's signers: the committee's Safe, the operator Safe and the emergency Safe. Every rotation must update all three. EM's decision makes this a manual runbook duty.
- The operator and the emergency role do not fail independently. They are the same people at different quorums. The guarantee that the operator cannot block an emergency action rests on role scoping alone.
- No body independent of the committee can return assets within six hours. The Emergency Brakes multisig can only stop the operator, and a DAO vote takes days. The mandate text and the LIP say so (decisions 16 and 17).
- The compensating controls are one-way emergency powers, transfers pinned to the Agent or to recovery instances, and the DAO's power to replace the whole policy.
- Disabling the operator modifier leaves the safety modifier working, so recovery survives the technical switch [s4].
- The safety policy pins the operator modifier's address. Replacing the operator modifier therefore needs a DAO vote that rewrites the safety policy in the same action. EM accepted this as a documented procedure on 2026-09-22 [s1].
- Freezing queued motions needs the Emergency Brakes multisig, a different body. The general Lido incident process pages it.
- Every DAO-path action carries the Dual Governance delay.
- The three new Safes run Safe v1.5.0, which has a short record of holding value [s7]. The LIP says so.
- The vault's main Safe paths are ones that Certora formally verified on v1.5.0: transaction execution, `approveHash` and module execution [s7]. The contract-signature path and the fallback handler, where v1.5.0 changed most and where the next release changes again, stay unused.
- Without a fallback handler, the Asset Safe refuses ERC-721 and ERC-1155 safe transfers, and it cannot sign a message by EIP-1271. A protocol that needs either comes back to EM (decision 15).
- A later change of the Asset Safe's Safe version needs a DAO vote with a delegatecall to Safe's migration contract.

## Confirmation

- INV-001, INV-002, INV-003, INV-004, INV-009 and INV-019 in the [invariants](/specs/invariants.md).
- Kit tests: the technical role is the only one that can disable a module, and only the operator modifier [s4]; the emergency flow returns assets to the Agent and nowhere else [s5]; the operator cannot widen or reach administration [s6]; the Asset Safe has the Agent as its only owner, the pinned singleton, and no fallback handler or guard [s11].

## Reversal conditions

- A signer compromise that reaches the emergency quorum.
- An audit finding that a role can reach an owner-only surface.
- A Safe release or advisory that touches the Safe paths the vault uses, found by the check before the enabling vote ([ADR 010](/adr/010-pre-execution-screening.md)).

## Open questions

None open. OD-17 was decided on 2026-10-05.
