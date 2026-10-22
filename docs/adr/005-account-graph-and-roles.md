---
type: Decision
title: "ADR 005: Account graph and roles"
description: Account ownership, operator and emergency roles, recovery powers and first-loss access.
tags: [architecture, roles, safe, zodiac, emergency]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T20:15:25Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers of 2026-09-22, later decisions to OD-80 on 2026-10-14, and OD-92 on 2026-10-22
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

- The Easy Track executor has neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Aragon Agent; the Dual Governance admin executor holds both [s2].
- The committee's Safe runs v1.3.0 at four-of-seven. The Emergency Brakes Safe runs v1.3.0 at three-of-five and can pause Easy Track, but cannot unpause it [s2].
- The locked Roles mastercopy has owner `0x…01` and uses storage from slot 0 [s2]. A Safe-style proxy would brick it. Use an EIP-1167 minimal proxy from the Zodiac module proxy factory [s3].
- A module guard sees the calling module, not its role key [s3]. One modifier cannot separate operator screening from recovery. [ADR 010](/adr/010-pre-execution-screening.md) puts no guard on the Asset Safe. The split stays because recovery must survive the switch.
- Safe v1.5.0 was released on 2025-07-03. Certora audited it with formal verification; Ackee audited it with fuzzing. No advisory or paid bounty concerns it [s7]. Its value-holding history is short: the factory created 57 such Safes before March 2026. Safe{Wallet} adopted it for new Safes on 2026-09-22 [s7].
- Type-1 signatures accept an owner that sends the transaction or approves its hash [s8]. The kit executes Asset Safe transactions this way [s9] and sets up that Safe without a fallback handler [s10].
- The mandate draft promises dual access. The DAO and an emergency committee independent of the Treasury Management Committee can each return every asset to the treasury within six hours [s12].
- Feedback from one committee member on 2026-10-12 requested removal of the emergency Safe and Emergency Brakes powers to exit positions, return assets and unpause Easy Track [s13].
- Lido's May 2026 tokenholder update limits protocol-role multisigs to pause or disable powers, with no resume or change powers. The CircuitBreaker Committee follows this rule [s13].

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

Decisions 21 and 22 narrow decision 6 to the Asset Safe, and decision 18's switch on the orders account becomes the membership removal. Decision 21 also replaces "its own modifiers" in decision 20 with one modifier.

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

Since OD-70, a routine removal runs as a motion of the removal template ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 14). Decision 11's revoke stays for emergencies.

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

EM decided on 2026-10-22, closing OD-92 Q1 [s1]:

32. The enabling vote applies the Safe batches by approved hash. Aragon Voting approves the hash of each batch, and anyone executes the batches after the vote.

Decision 32 applies the `approveHash` of decision 28 to the enabling vote. The vote cannot carry the batches as its own items: Aragon Voting stores its script when a vote starts, and that transaction would need more gas than EIP-7825 lets one transaction use ([research note](/research/enabling-vote-rehearsal-2026-10-15.md)).

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **Asset Safe.** A new Safe v1.5.0, owned one-of-one by Aragon Voting, without a guard or fallback handler. It holds assets except first-loss shares and orders-account tokens in transit. Voting sends each transaction or approves its hash for a type-1 signature (decisions 14 and 28).
- **Committee's Safe.** The existing TMC Safe, four-of-seven on v1.3.0 (decision 31). It holds `operator` and is every factory's trusted caller. Its `first-loss` role redeems to the Agent (decision 27); it creates every first-loss burn motion ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 23). Screening starts when the launch cap lifts ([ADR 010](/adr/010-pre-execution-screening.md), decision 24).
- **Emergency Safe.** A new Safe v1.5.0 at three-of-five, without assets or a guard. It holds `emergency` on the safety and orders modifiers, including the switch (decision 25). Exactly two owners belong to the committee's Safe, two to Emergency Brakes and one to neither (decision 24). Because one person can use several addresses, the fifth signer must also confirm their independence in writing. Owner changes trigger critical alerts; a DAO vote can replace the role holder.
- **Operator modifier.** A Roles minimal proxy with the Asset Safe as owner, avatar and target; it carries `operator` and `governance`.
- **Safety modifier.** A second proxy with the same settings. It carries `emergency` and exit-governance, which adds emergency exits by motion ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 13).
- The Asset Safe owns both modifiers. A narrowly scoped role can administer a modifier as the Safe without a vote. This enables emergency revocation.
- **Orders account.** A new Voting-owned Safe, one-of-one, with CoW's fallback handler. It holds tokens only between transfer and fill. Its single modifier carries `operator` and `emergency`, with no `governance` role (decisions 21 and 25). Tokens and the order signer's delegatecall require DAO votes ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). Emergency stops the operator by revoking targets and functions (decision 25).
- **First-loss Safe.** A new Voting-owned Safe v1.5.0, one-of-one, without a guard or fallback handler. It holds only first-loss Earn shares and owns its modifier as owner, avatar and target. The committee's `first-loss` role redeems to the Agent (decision 27). The executor's `first-loss-burn` role burns only by enacted motion ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 23). Both require the Earn team's written instruction (ADR 008, decision 22).
- **Restart.** A Voting item restores the operator modifier (decision 28). First, the same vote uses Voting's cancel role to cancel queued motions that write through the operator modifier: the switch freezes them, but they never expire and restart would re-arm them. The vote also restores revoked orders-account permissions and any zeroed relayer approval (decision 30). An Easy Track unpause is also a Voting item (decision 26). No motion writes on the orders account, and no emergency body restores authority.
- Easy Track receives no Agent authority.

| Role | Holder | Modifier | May do | May not do |
|---|---|---|---|---|
| DAO | Aragon Voting, by vote (decision 28) | owner path | everything: own the Safe, replace the policy, change membership | — |
| `operator` | committee's Safe, the committee's signers, four of seven (decision 31), screened once the launch cap lifts ([ADR 010](/adr/010-pre-execution-screening.md) decisions 22 and 24) | operator | open, adjust and close positions in approved protocols within budgets; approve approved spenders, each approval spending its spender's budget key or staying below a fixed ceiling ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); stake ETH ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); convert DAI to USDS and back through Sky's converter, pinned to the Asset Safe ([ADR 011](/adr/011-launch-scope.md)); fund the orders account under budgets, and from it place CoW orders that pay the Asset Safe ([ADR 007](/adr/007-swapping-through-an-orders-account.md)) | move assets out, except into the orders account; borrow; administer a modifier or a Safe; change its own permissions |
| `governance` | Easy Track executor | operator | write operator permissions from a fixed template, for a target named in a motion; set operator budgets within ceilings | submit a condition tree; grant or remove any role; touch the emergency role; target the modifier's avatar or any of its modules (OD-38); grant delegatecall (OD-36) |
| `emergency` | emergency Safe, three of five: two committee members, two Emergency Brakes members and one member of neither body | safety, orders | zero approvals; exit positions to the Safe; unwrap wstETH and WETH, stake ETH and redeem sUSDS; send assets to the orders account or to the Agent; revoke the operator's targets and functions on the operator modifier and on the orders modifier, which is how every emergency removal happens and how the operator stops on the orders account; disable the operator modifier, with the module argument pinned (decision 25); on the orders account, cancel orders, set a relayer approval to zero, send tokens to the Agent or the Asset Safe, and place orders that buy USDC or USDT and pay the Agent | add a permission; enter a protocol except by staking ETH; borrow; reach the first-loss Safe ([ADR 008](/adr/008-funding-through-existing-payments.md)); change the recovery destination; disable the safety modifier or the orders modifier; restore what it stopped: enable a module, grant a permission again or raise an approval (decision 26) |
| exit governance | Easy Track executor | safety | write an emergency exit for a target that an onboarding motion names: redeem, withdraw, claim and cancel pinned to the Asset Safe, a transfer pinned to the Agent, an approval set to zero (OD-49) | write anything but an exit; grant delegatecall; touch membership or the switch; set an allowance; target the Asset Safe or a module of it |
| `first-loss` | committee's Safe, the committee's signers, four of seven (decision 31), screened once the launch cap lifts ([ADR 010](/adr/010-pre-execution-screening.md) decision 24) | first-loss | request and claim the redemption of the DAO's earnETH and earnUSD shares, with the proceeds pinned to the Aragon Agent; on the Earn team's written instruction (decision 27; [ADR 008](/adr/008-funding-through-existing-payments.md)) | burn, transfer or approve the shares; pay anyone but the Agent; reach the Asset Safe or the orders account |
| `first-loss-burn` | Easy Track executor | first-loss | burn the DAO's earnETH and earnUSD shares, only as an enacted motion that the committee's Safe created ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23) | anything else |

The Emergency Brakes multisig holds no role in this table. It keeps the global Easy Track pause (decisions 4 and 23).

- **The enabling vote's batches (decision 32).** Publish each batch with the vote, with one command that computes its hash again from the batch, the Safe and the Safe's nonce. The batches of one Safe run in nonce order. The builder starts a new batch below 12,000,000 gas and below 128 KiB. Rehearse the vote and the batches at a recent block before the vote starts and again before it executes.

## Options considered

- **Emergency Brakes as emergency role:** EM rejected this because financial response needs daily portfolio knowledge.
- **Technical-role transfers to the Agent:** EM rejected this under OD-30. They would provide the mandate's independent six-hour exit [s12], but give Emergency Brakes power over assets.
- **Separate technical committee for the switch:** rejected because Emergency Brakes has technical members and holds two seats on the emergency Safe (decisions 24 and 25).
- **Emergency Brakes exits and returns assets:** requested in the 2026-10-12 feedback [s13]; EM rejected technical brakes with fund access.
- **Committee Safe as emergency role, without a separate Safe:** requested in the same feedback [s13]; EM rejected this because the committee could act alone, defeating the independent exit.
- **Two-of-seven committee emergency Safe, with the switch at Emergency Brakes:** EM replaced this on 2026-10-13 (decisions 23–25).
- **Emergency Brakes unpause or motion cancellation:** EM rejected because emergency bodies receive no new powers and cannot resume (decision 26) [s13].
- **First-loss Safe without modules:** EM replaced this on 2026-10-13 (decision 27). DAO votes for each burn or redemption would exceed the inherited terms' timing.
- **One modifier for all roles:** rejected because a guard could not separate recovery, and disabling it would stop recovery.
- **One modifier per account, including the Asset Safe (OD-57 A):** EM rejected this. Governance and exit-governance would share a contract with emergency and technical roles, separated only by role-key pins. The switch would depend on that modifier's membership check.
- **Two orders modifiers (OD-57 C):** EM replaced this on 2026-10-09. No motion writes there, so the split added no protection.
- **Agent ownership of modifiers:** rejected because emergency revocation would need a DAO vote.

- One vote for each Safe batch: EM chose approved hashes in one vote instead (OD-92).

## Consequences

- Voters see the batches as hashes. The batches and the command that computes each hash must be published with the vote (decision 32). A batch that can never run blocks its Safe until another vote approves a replacement.
- The committee's Safe holds `operator` (decision 31) and `first-loss` (decision 27). A compromised quorum can redeem first-loss shares only to the Agent, or propose a burn with 72 hours for objection. Rotations affecting either body's emergency seat must update the emergency Safe (decision 24).
- Each emergency quorum includes someone outside the committee and someone outside Emergency Brakes. The committee cannot act alone; two compromised committee keys reach no emergency power.
- The two Emergency Brakes members and fifth signer can return assets within hours without the committee, satisfying the mandate's independent three-of-five exit [s12]. This quorum has no spare signer; the fifth signer is pivotal. The LIP and mandate need no disclaimer that the fast exit lacks independence.
- No response-time data exists for the mixed group. A timed drill is required before launch.
- Any three emergency signers can change the Safe's owners. Controls are the seat rule, owner-change alerts and DAO replacement of the role holder.
- A non-committee emergency quorum can place recovery orders without an on-chain price floor (OD-48).
- Compensating controls for emergency powers are one-way permissions, transfers pinned to the Agent or the orders account, and DAO policy replacement. Recovery orders pay the Agent; CoW market-fill rules, paging and limit alerts cover their price risk (OD-48).
- Governance refuses the Asset Safe's modules as targets. A vote adding a module must apply policy compiled with it in the manifest (OD-38, [ADR 006](/adr/006-governance-through-easy-track-factories.md)) [s1]. The orders account has no governance role, and Asset Safe governance refuses it and its modifier (decision 21; [ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 38).
- Four new Safes are required: Asset, emergency, orders and first-loss. Voting owns three; signers own the emergency Safe. Owner, module and singleton alerts cover all four plus the committee's Safe (decision 31).
- The orders account uses fallback and contract-signature paths avoided by the Asset Safe. Its exposure is what enters it: operator transfers spend budgets; emergency transfers do not ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- Disabling the operator modifier leaves safety and recovery working [s4]. The orders account's single modifier cannot provide the same switch without stopping recovery. Emergency revokes its operator targets or functions individually (decision 25); the DAO can still disable it.
- Replacing the pinned operator modifier requires a DAO vote that rewrites safety policy in the same action. EM accepted this procedure on 2026-09-22 [s1].
- The switch freezes queued operator-modifier writes; restart cancels them first. To freeze all Easy Track motions, including top-ups and exit writes, the Lido incident process pages Emergency Brakes for its global pause.
- Each restart requires a direct Voting item of about five days (decisions 26 and 28). The runbook revokes first and uses the switch only for permission-layer defects, the cap-breach trigger ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 24), or a compromised or silent committee.
- Voting ownership removes Dual Governance delay from vault actions (decision 28). Recovery still pays the Agent.
- Asset, emergency and first-loss Safes use v1.5.0; the orders account does so if its fork test passes. The committee keeps v1.3.0 (decision 31). The LIP must disclose v1.5.0's short value-holding history [s7].
- Certora verified transaction execution, `approveHash` and module execution on v1.5.0 [s7]. The Asset Safe avoids contract signatures and fallback handling, where this version and the next release change most. The orders account uses these paths for tokens in transit.
- Without a fallback handler, the Asset Safe refuses ERC-721/ERC-1155 safe transfers and EIP-1271 signing. Protocols needing these return to EM (decision 15). Lido's ERC-721 withdrawal queue is outside scope ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 27).
- An Asset Safe version change requires a DAO vote with a delegatecall to Safe's migration contract.

## Confirmation

- The probe `test/SingleModifierProbe.t.sol`, on the Asset Safe of the harness as a stand-in for the orders modifier: on one modifier, the pinned membership removal stops the operator, recovery keeps working, the switch cannot be repointed or widened, and the operator cannot restore itself (6 tests, 2026-10-08). Decision 25 replaced the membership removal; the probe's emergency revoke on its own modifier is the stop that stays. The orders account's own test is owed with the orders account.
- Kit tests of 2026-10-13: the emergency role holds the switch, pinned to the operator modifier, and cannot enable a module again (`test_D4_the_switch_is_the_emergency_role_s_and_pinned`); the switch freezes a queued motion until the owner path enables the modifier again (`test_D4_the_switch_freezes_queued_motions_until_the_dao_restarts`); the compiler refuses a grant or a budget for the emergency role, and every approval of the emergency role is zero (`policy/constellation/compiler/compile.test.ts`).

- INV-001, INV-002, INV-003, INV-004, INV-009, INV-019, INV-021, INV-022, INV-023, INV-026 and INV-027 in the [invariants](/specs/invariants.md).
- Kit tests: before 2026-10-13, the technical role was the only one that could disable a module, and only the operator modifier [s4]; the emergency flow returns assets to the Agent and nowhere else [s5]; the operator cannot widen or reach administration [s6]; the Asset Safe has the pinned singleton and no fallback handler or guard [s11]. The kit's owner check still names the Agent; it must name Aragon Voting (decision 28).
- The enabling-vote rehearsal checked decision 28: Aragon Voting approved a batch hash on each of the three Safes, and the batches ran (decision 32; [research note](/research/enabling-vote-rehearsal-2026-10-15.md)).

## Reversal conditions

- A signer compromise that reaches the emergency quorum.
- The fifth seat stays empty, or the mixed group misses the drill's time to initiate.
- An audit finding that a role can reach an owner-only surface.
- A Safe release or advisory that touches the Safe paths the vault uses, found by the check before the enabling vote ([ADR 010](/adr/010-pre-execution-screening.md)).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-65](/registers/open-decisions.md): Who holds the emergency Safe's fifth seat? The fifth signer is a member of neither the committee nor the Emergency Brakes multisig (OD-58), and a DAO Snapshot appoints them.

<!-- end of generated block -->

On OD-65, EM said on 2026-10-13 that a member of the Tech team may hold the fifth seat, tentatively; a Snapshot appoints the signer before the emergency Safe is deployed.
