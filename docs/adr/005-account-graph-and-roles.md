---
type: Decision
title: "ADR 005: Account graph and roles"
description: A Safe owned only by Aragon Voting holds the assets; two Roles modifiers split the operator and governance roles from the emergency role; the committee's own Safe holds the operator role; the emergency Safe, three of five with two committee members, two Emergency Brakes members and one member of neither body, holds the emergency role and its switch; the Emergency Brakes multisig touches no funds and keeps only the Easy Track pause; no emergency body resumes what it stopped; a Voting-owned orders account with one modifier of its own places every CoW order, and a Voting-owned first-loss Safe holds the first-loss shares, which burn only by Easy Track motion and redeem to the Agent through one narrow role of the committee's Safe; the Asset Safe, the committee's Safe and the emergency Safe run Safe v1.5.0, and the Asset Safe has no fallback handler.
tags: [architecture, roles, safe, zodiac, emergency]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-14T21:55:03Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers of 2026-09-22, and later decisions to OD-80 on 2026-10-14
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
  - id: s13
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — emergency powers, the Easy Track restart and Lido's pause-or-disable rule
---

# ADR 005: Account graph and roles

## Context

- The Easy Track executor holds neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Aragon Agent. The Dual Governance admin executor holds both [s2].
- The committee's Safe runs v1.3.0 with a quorum of four of seven. The Emergency Brakes Safe runs v1.3.0 with a quorum of three of five, and it holds the Easy Track pause but not the unpause [s2].
- The Roles mastercopy is locked, with owner `0x…01` [s2]. It keeps its own storage from slot 0, so a Safe-style proxy in front of it bricks the instance. It must be deployed as an EIP-1167 minimal proxy through the Zodiac module proxy factory [s3].
- A module guard receives the calling module, not the role key. One modifier therefore cannot let a guard block the operator without also blocking recovery [s3]. The screening route chosen in [ADR 010](/adr/010-pre-execution-screening.md) puts no guard on the Asset Safe. The split stays because recovery must survive the switch.
- Safe v1.5.0 was released on 2025-07-03 and audited twice, by Certora with formal verification and by Ackee with fuzzing. No advisory and no paid bounty concerns it. Its record of holding value is short: 57 Safes were created on it through Safe's factory before March 2026, and Safe{Wallet} made it the version of new Safes on 2026-09-22 [s7].
- On a type-1 signature, the Safe accepts an owner that sent the transaction or approved its hash [s8]. The kit executes the Asset Safe's transactions this way [s9], and it sets up the Asset Safe without a fallback handler [s10].
- The mandate draft promises a dual-access emergency exit. The DAO, and an emergency committee independent of the Treasury Management Committee, can each return every asset to the treasury within six hours [s12].
- On 2026-10-12 a member of the committee sent feedback on the design. It asked that the Emergency Brakes multisig may exit positions and send assets home, that the emergency Safe goes, and that the multisig may unpause Easy Track [s13].
- Lido's tokenholder update of May 2026 states the rule for multisigs with protocol roles: they only pause or disable contracts, and never resume or change them. The CircuitBreaker Committee follows it [s13].

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

EM decided on 2026-10-06, closing OD-42 and OD-43 [s1]:

19. The DAO's first-loss Earn shares sit in a dedicated first-loss Safe, owned by the Aragon Agent at one of one, with no modules. No role can reach them ([ADR 008](/adr/008-funding-through-existing-payments.md)).
20. A dedicated orders account places every swap as a CoW order. It is a Safe owned by the Aragon Agent, with CoW's fallback handler and its own modifiers ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).

EM decided on 2026-10-09, closing OD-57 [s1]:

21. The orders account carries one modifier, with the operator, emergency and technical roles and no governance role. The Asset Safe keeps its two modifiers (decision 6).
22. On the orders account, the technical role stops the operator by removing the operator Safe's membership of the operator role, with every argument pinned.

Decisions 21 and 22 narrow decision 6 to the Asset Safe, and decision 18's switch on the orders account becomes the membership removal.

EM decided on 2026-10-13, after the committee's feedback, closing OD-58 and OD-59 [s1]:

23. The Emergency Brakes multisig touches no funds. It holds no role on any modifier. In Clutch it keeps only the global Easy Track pause of decision 4.
24. The emergency Safe has five signers and a threshold of three: two members of the committee, two members of the Emergency Brakes multisig, and a fifth signer. The fifth signer is a member of neither the committee nor the Emergency Brakes multisig. The committee appoints two seats, the Emergency Brakes multisig appoints two, and a DAO Snapshot appoints the fifth. A signer who leaves their body also leaves the seat.
25. The emergency role holds the switch: it disables the operator modifier, with the module argument pinned. The technical role goes. On the orders account, the emergency role's revoke stops the operator, and the membership removal goes.
26. No emergency body resumes what it stopped. The emergency Safe and the Emergency Brakes multisig get no power to unpause Easy Track, to enable a module, to grant a permission again or to raise an approval. The DAO restarts after each stop.

Decision 24 replaces decisions 1, 5, 16 and 17, and the quorum and the signers of decision 2. Decision 25 replaces decisions 3 and 22, moves decision 18's switch to the emergency role, and removes the technical role from decision 21. Financial risk stays the common case (decision 2), and the engineering organisation still watches technical risk (decision 3). Both page the emergency Safe.

EM decided on 2026-10-13, closing OD-60 [s1]:

27. The first-loss Safe gets one modifier, with one `first-loss` role that the operator Safe holds. The role burns the DAO's first-loss shares, and redeems them with the proceeds pinned to the Aragon Agent ([ADR 008](/adr/008-funding-through-existing-payments.md) decisions 21 and 22). This replaces "with no modules" and "No role can reach them" in decision 19.

Decision 27's burn runs only as an Easy Track motion since OD-67 ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23). The operator Safe's role keeps the redemption to the Aragon Agent.

OD-68 gave the orders modifier a governance role ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 31), and OD-78 took it away again ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 38), so decision 21's "no governance role" stands.

EM decided on 2026-10-14, closing OD-73 [s1]:

28. Aragon Voting, not the Aragon Agent, is the only owner of the Asset Safe, the orders account and the first-loss Safe, and the admin of the vault's funding registries. Recovered assets still go to the Aragon Agent.

Decision 28 replaces the Aragon Agent as owner in decisions 14, 19 and 20, in [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 17 and in [ADR 008](/adr/008-funding-through-existing-payments.md) decision 19. A DAO action on the vault is then a direct Voting item, without Dual Governance. Aragon Voting authorizes a Safe transaction as decision 14 asked of the Agent: by `approveHash` or by sending it itself.

EM decided on 2026-10-14, in the interview on OD-68, closing OD-75 [s1]:

29. A motion may restore a permission to exactly its launch version, without delegatecall, on the operator modifier and on the orders modifier, and may raise a CoW relayer approval ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 34). The DAO restarts the rest by vote: the operator modifier after the switch, the order signer's delegatecall permission, a funding limit that a vote set to zero, an Easy Track unpause and a repair of the safety modifier.

Decision 29 narrows decision 26's "The DAO restarts after each stop": a motion also restores the launch versions. No emergency body resumes what it stopped.

EM decided on 2026-10-14, after a count of the launch, closing OD-78 [s1]:

30. No restore template ships with the launch, and the orders modifier has no approvals role. The DAO restarts by vote after each stop (decision 26): the same vote grants again what the emergency role revoked, on the Asset Safe and on the orders account, and sets again any relayer approval that the emergency role set to zero.

Decision 30 replaces decision 29.

EM decided on 2026-10-14, closing OD-80 [s1]:

31. The committee's own Safe holds the operator role and the first-loss role, and it is the trusted caller of every Clutch factory. Clutch deploys no operator Safe. The committee's Safe runs Safe v1.3.0 at 4 of 7.

Decision 31 replaces the dedicated operator Safe of decisions 7 and 8, and its Safe version in decisions 10 and 12. Decision 9's threshold, 4 of 7, is already the threshold of the committee's Safe. The committee's Safe takes the operator Safe's place in decision 27 and in every later text.

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **Asset Safe.** A new Safe owned one-of-one by Aragon Voting (decision 28). It holds the assets, apart from the first-loss shares and the tokens in transit in the orders account. No guard and no fallback handler are set on it. It runs Safe v1.5.0. Aragon Voting approves the hash of each transaction, or sends the transaction itself, so the Safe checks a type-1 signature (decisions 14 and 28).
- **Committee's Safe.** The Treasury Management Committee's existing Safe, at 4 of 7 on Safe v1.3.0 (decision 31). It holds the operator role and is the trusted caller of every factory. It also holds the first-loss role, which redeems first-loss shares to the Aragon Agent, and it creates every first-loss burn motion (decision 27; [ADR 008](/adr/008-funding-through-existing-payments.md) decision 23). Where the screening guard goes when the launch cap lifts is OD-83 ([ADR 010](/adr/010-pre-execution-screening.md)).
- **Emergency Safe.** A new Safe with five signers and a threshold of three: two committee members, two Emergency Brakes members and one member of neither body (decision 24). It holds no assets and has no guard. It holds the emergency role on the safety modifier and on the orders modifier, the switch included (decision 25). It runs Safe v1.5.0. Exactly two of its owners are owners of the committee's Safe, exactly two are owners of the Emergency Brakes Safe, and one is an owner of neither. One person can hold several addresses, so the fifth signer also states in writing that they belong to neither body. An owner change is a critical alert, and a DAO vote can replace the role's holder.
- **Operator modifier.** A minimal proxy of the Roles mastercopy. Owner, avatar and target are the Asset Safe. It carries the `operator` and `governance` roles.
- **Safety modifier.** A second minimal proxy with the same settings. It carries the `emergency` role, and the exit-governance role through which a motion adds an emergency exit ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13).
- The Asset Safe owns both modifiers. A role's call executes as the Safe, so a narrowly scoped role can administer a modifier without any authority over the Agent. This is how the emergency role revokes the operator.
- **Orders account.** A new Safe owned one-of-one by Aragon Voting, with CoW's fallback handler. It holds only tokens in transit between a transfer and a fill. It runs Safe v1.5.0 if a fork test shows that CoW's fallback handler works on it; that is not checked yet. It has one modifier, the orders modifier, with the `operator` and `emergency` roles and no `governance` role (decisions 21 and 25). No motion writes there: a DAO vote adds a token and grants the order signer's delegatecall ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). The emergency role stops the operator there by revoking its targets and functions on the orders modifier (decision 25).
- **First-loss Safe.** A new Safe owned one-of-one by Aragon Voting, with no guard and no fallback handler, on Safe v1.5.0 like the Asset Safe. It holds only the DAO's first-loss Earn shares. It has one modifier, the first-loss modifier, whose owner, avatar and target is the first-loss Safe. It has two roles. The committee's Safe holds `first-loss`, which redeems the shares to the Aragon Agent (decision 27). The Easy Track executor holds `first-loss-burn`, which burns them only as an enacted motion ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23). Both act on the Earn team's written instruction ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 22).
- **Restart.** After the switch, a Voting item enables the operator modifier again (decision 28). The switch also freezes each queued motion that writes through the operator modifier, and the restart re-arms it, because a motion does not expire. So the same vote first cancels the queued motions, through Voting's cancel role. After an Easy Track pause, a Voting item unpauses Easy Track (decision 26). The restart after the switch also grants again the operator's permissions on the orders account, which the switch revoked, and any relayer approval that the emergency role set to zero: no motion writes on the orders account, and no emergency body restarts what it stopped (decision 30).
- Easy Track never receives authority over the Agent.

| Role | Holder | Modifier | May do | May not do |
|---|---|---|---|---|
| DAO | Aragon Voting, by vote (decision 28) | owner path | everything: own the Safe, replace the policy, change membership | — |
| `operator` | committee's Safe, the committee's signers, four of seven (decision 31), screened once the launch cap lifts if OD-83 puts the guard there ([ADR 010](/adr/010-pre-execution-screening.md) decision 22) | operator | open, adjust and close positions in approved protocols within budgets; approve approved spenders, each approval spending its spender's budget key or staying below a fixed ceiling ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); stake ETH ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); convert DAI to USDS and back through Sky's converter, pinned to the Asset Safe ([ADR 011](/adr/011-launch-scope.md)); fund the orders account under budgets, and from it place CoW orders that pay the Asset Safe ([ADR 007](/adr/007-swapping-through-an-orders-account.md)) | move assets out, except into the orders account; borrow; administer a modifier or a Safe; change its own permissions |
| `governance` | Easy Track executor | operator | write operator permissions from a fixed template, for a target named in a motion; set operator budgets within ceilings | submit a condition tree; grant or remove any role; touch the emergency role; target the modifier's avatar or any of its modules (OD-38); grant delegatecall (OD-36) |
| `emergency` | emergency Safe, three of five: two committee members, two Emergency Brakes members and one member of neither body | safety, orders | zero approvals; exit positions to the Safe; unwrap wstETH and WETH, stake ETH and redeem sUSDS; send assets to the orders account or to the Agent; revoke the operator's targets and functions on the operator modifier and on the orders modifier, which is how every removal happens and how the operator stops on the orders account; disable the operator modifier, with the module argument pinned (decision 25); on the orders account, cancel orders, set a relayer approval to zero, send tokens to the Agent or the Asset Safe, and place orders that buy USDC or USDT and pay the Agent | add a permission; enter a protocol except by staking ETH; borrow; reach the first-loss Safe ([ADR 008](/adr/008-funding-through-existing-payments.md)); change the recovery destination; disable the safety modifier or the orders modifier; restore what it stopped: enable a module, grant a permission again or raise an approval (decision 26) |
| exit governance | Easy Track executor | safety | write an emergency exit for a target that an onboarding motion names: redeem, withdraw, claim and cancel pinned to the Asset Safe, a transfer pinned to the Agent, an approval set to zero (OD-49) | write anything but an exit; grant delegatecall; touch membership or the switch; set an allowance; target the Asset Safe or a module of it |
| `first-loss` | committee's Safe, the committee's signers, four of seven (decision 31), screened once the launch cap lifts if OD-83 puts the guard there | first-loss | request and claim the redemption of the DAO's earnETH and earnUSD shares, with the proceeds pinned to the Aragon Agent; on the Earn team's written instruction (decision 27; [ADR 008](/adr/008-funding-through-existing-payments.md)) | burn, transfer or approve the shares; pay anyone but the Agent; reach the Asset Safe or the orders account |
| `first-loss-burn` | Easy Track executor | first-loss | burn the DAO's earnETH and earnUSD shares, only as an enacted motion that the committee's Safe created ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23) | anything else |

The Emergency Brakes multisig holds no role in this table. It keeps the global Easy Track pause (decisions 4 and 23).

## Options considered

- The Emergency Brakes multisig as the emergency role. Not chosen by EM: financial response needs the people who watch the portfolio daily.
- A transfer permission to the Agent for the technical role, so that a body independent of the committee can return assets within six hours, as the mandate draft describes [s12]. Not chosen by EM (OD-30): it gives the Emergency Brakes multisig a power over assets.
- A separate technical committee for the switch. Not chosen: two members of the Emergency Brakes multisig, which has technical members, sit on the emergency Safe (decisions 24 and 25).
- The Emergency Brakes multisig exits positions and sends assets home, as the committee's feedback of 2026-10-12 asked [s13]. Not chosen by EM: technical emergency brakes must not touch funds.
- No emergency Safe: the committee's Safe holds the emergency role, as the same feedback asked [s13]. Not chosen by EM: the committee would act alone in an emergency, and the mandate's independent exit would not hold.
- The emergency Safe as the committee's signers at two of seven, with the switch at the Emergency Brakes multisig, the design until 2026-10-13. Replaced by EM (decisions 23 to 25).
- The Emergency Brakes multisig may unpause Easy Track, or cancel any motion, so that it can restart after its own pause [s13]. Not chosen by EM: no new powers, and no emergency body resumes (decision 26).
- The first-loss Safe with no modules, so that every burn or redemption is a DAO vote, the design until 2026-10-13. Replaced by EM (decision 27): the vote is slower than the first-loss terms that the mandate takes over.
- One modifier for all roles. Not chosen: a guard could not tell recovery from the operator, and disabling the module would remove recovery too.
- One modifier on each account, the Asset Safe included (OD-57 A). Not chosen by EM. On the Asset Safe the motion writers, the governance and exit-governance roles, would share a contract with the emergency and technical roles, kept apart only by the role-key pins, and the technical switch would depend on the modifier's own membership check.
- Two modifiers on the orders account, as on the Asset Safe (OD-57 C), the design until 2026-10-09. Replaced by EM: no motion writes on the orders account, so the split protected nothing there.
- The Agent as owner of the modifiers. Not chosen: the emergency role could then not revoke the operator without Agent authority.

## Consequences

- The committee's Safe, with the committee's seven signers, holds the operator role (decision 31). The emergency Safe carries two of them and two members of the Emergency Brakes multisig. A rotation that touches a seat also updates the emergency Safe (decision 24). The committee's Safe also holds the first-loss role (decision 27). A compromise of its quorum can redeem the first-loss shares to the Aragon Agent, and can propose a burn, which LDO holders see for 72 hours.
- Every quorum of the emergency Safe needs a signer from outside the committee and a signer from outside the Emergency Brakes multisig. The committee cannot act alone in an emergency, and two stolen committee keys reach nothing.
- A quorum without the committee can return assets within hours: the two Emergency Brakes members and the fifth signer. So the mandate's emergency committee, independent of the committee, three of five, with dual access, holds as drafted [s12]. That quorum has no spare signer, and the fifth signer is pivotal for it. The mandate text and the LIP owe no statement that the fast exit is not independent.
- Every emergency action needs a signer from outside the committee. No response-time data exists for such a mixed group, so a timed drill runs before launch.
- A Safe manages its own owners, so any three signers can change the composition. The seat rule, the owner-change alert and the DAO's power to replace the role's holder are the controls.
- Recovery orders, which have no on-chain price floor (OD-48), can be placed without a committee member.
- The compensating controls are one-way emergency powers, transfers pinned to the Agent or to the orders account, whose recovery orders pay the Agent, and the DAO's power to replace the whole policy. A recovery order has no on-chain price floor; CoW's rules hold its fill to the on-chain market, and paging and a limit alert watch it (OD-48).
- The governance role refuses every module of the Asset Safe as an administered target, so a DAO vote that enables another module on the Asset Safe must also apply a policy compiled with that module in the manifest (OD-38, [ADR 006](/adr/006-governance-through-easy-track-factories.md)). [s1] The orders account has no governance role (decision 21; [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 38), and the Asset Safe's governance role refuses the orders account and its modifier as targets.
- Four new Safes now: the Asset Safe, the emergency Safe, the orders account and the first-loss Safe. Aragon Voting owns three of them, and signers own the emergency Safe. Owner, module and singleton alerts cover all four and the committee's Safe (decision 31).
- The orders account carries the fallback handler and the contract-signature path that the Asset Safe avoids. Its exposure is what enters it: the operator's transfers spend budgets, and the emergency role's do not ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- Two narrow roles reach the first-loss shares. A burn needs an enacted motion, and the first-loss role of the committee's Safe redeems them only to the Agent. Neither can move them anywhere else, so their protection does not rest on a written rule ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- Disabling the operator modifier leaves the safety modifier working, so recovery survives the switch [s4].
- The orders account has no switch at the Safe: disabling its only modifier would also stop recovery there. The emergency role's revoke stops the operator there, one target or function at a time (decision 25). The orders account holds only tokens in transit, and a DAO vote can still disable its modifier.
- The safety policy pins the operator modifier's address. Replacing the operator modifier therefore needs a DAO vote that rewrites the safety policy in the same action. EM accepted this as a documented procedure on 2026-09-22 [s1].
- The switch also freezes each queued motion that writes through the operator modifier, and the restart re-arms it, because a motion does not expire. The DAO's restart cancels the queued motions first. A freeze of every Easy Track motion, top-ups and exit writes included, needs the Emergency Brakes multisig's pause. The general Lido incident process pages it.
- Every restart is a DAO vote: a direct Voting item of about five days, for the operator modifier and for an Easy Track unpause (decisions 26 and 28). So the runbook revokes first, and uses the switch only for a defect in the permission layer, for the cap-breach trigger ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 24), or when the committee is compromised or silent.
- No DAO-path action on the vault carries the Dual Governance delay, because Aragon Voting owns the vault's Safes (decision 28). Recovered assets still go to the Aragon Agent.
- The Asset Safe and the emergency Safe run Safe v1.5.0, and so do the first-loss Safe and, if its fork test passes, the orders account. The committee's Safe runs Safe v1.3.0 (decision 31). Safe v1.5.0 has a short record of holding value [s7]. The LIP says so.
- The vault's main Safe paths are ones that Certora formally verified on v1.5.0: transaction execution, `approveHash` and module execution [s7]. The contract-signature path and the fallback handler, where v1.5.0 changed most and where the next release changes again, stay unused on the Asset Safe. The orders account uses them, and holds only tokens in transit.
- Without a fallback handler, the Asset Safe refuses ERC-721 and ERC-1155 safe transfers, and it cannot sign a message by EIP-1271. A protocol that needs either comes back to EM (decision 15). The vault no longer uses Lido's withdrawal queue, whose requests are ERC-721 tokens ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 27).
- A later change of the Asset Safe's Safe version needs a DAO vote with a delegatecall to Safe's migration contract.

## Confirmation

- The probe `test/SingleModifierProbe.t.sol`, on the Asset Safe of the harness as a stand-in for the orders modifier: on one modifier, the pinned membership removal stops the operator, recovery keeps working, the switch cannot be repointed or widened, and the operator cannot restore itself (6 tests, 2026-10-08). Decision 25 replaced the membership removal; the probe's emergency revoke on its own modifier is the stop that stays. The orders account's own test is owed with the orders account.
- Kit tests of 2026-10-13: the emergency role holds the switch, pinned to the operator modifier, and cannot enable a module again (`test_D4_the_switch_is_the_emergency_role_s_and_pinned`); the switch freezes a queued motion until the owner path enables the modifier again (`test_D4_the_switch_freezes_queued_motions_until_the_dao_restarts`); the compiler refuses a grant or a budget for the emergency role, and every approval of the emergency role is zero (`policy/constellation/compiler/compile.test.ts`).

- INV-001, INV-002, INV-003, INV-004, INV-009, INV-019, INV-021, INV-022, INV-023, INV-026 and INV-027 in the [invariants](/specs/invariants.md).
- Kit tests: before 2026-10-13, the technical role was the only one that could disable a module, and only the operator modifier [s4]; the emergency flow returns assets to the Agent and nowhere else [s5]; the operator cannot widen or reach administration [s6]; the Asset Safe has the Agent as its only owner, the pinned singleton, and no fallback handler or guard [s11].
- Fork test owed for decision 28: Aragon Voting, as the only owner, runs an owner action on each of the three Safes through its own call script, by `approveHash` or by sending the transaction itself.

## Reversal conditions

- A signer compromise that reaches the emergency quorum.
- The fifth seat stays empty, or the mixed group misses the drill's time to initiate.
- An audit finding that a role can reach an owner-only surface.
- A Safe release or advisory that touches the Safe paths the vault uses, found by the check before the enabling vote ([ADR 010](/adr/010-pre-execution-screening.md)).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-65](/registers/open-decisions.md): Who holds the emergency Safe's fifth seat? The fifth signer is a member of neither the committee nor the Emergency Brakes multisig (OD-58), and a DAO Snapshot appoints them.

<!-- end of generated block -->

The orders account's fallback handler on Safe v1.5.0 needs a fork test before it is relied on ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). On OD-65, EM said on 2026-10-13 that a member of the Tech team may hold the fifth seat, tentatively; a Snapshot appoints the signer before the emergency Safe is deployed.
