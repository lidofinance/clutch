---
type: Decision
title: "ADR 005: Account graph and roles"
description: The vault's Safes and their owners, the modifiers and their roles, the emergency Safe and the switch, and who resumes what an emergency stopped.
tags: [architecture, roles, safe, zodiac, emergency]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T22:02:51Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers from 2026-09-22 to 2026-11-10
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Agent authority, committee Safes, Roles mastercopy
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
    resource: "https://github.com/lidofinance/clutch/blob/03efa77c724f7fdde791a902a138090c099add0d/test/Drills.t.sol#L794"
    title: Kit test at 03efa77 — the Asset Safe's owner, Aragon Voting's stand-in, its threshold, singleton, and missing fallback handler and guards
  - id: s12
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the dual-access emergency exit and an emergency committee independent of the Treasury Management Committee; outside the repository until the mandate is published
  - id: s13
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — emergency powers, the Easy Track restart and Lido's pause-or-disable rule
  - id: s14
    resource: "https://research.lido.fi/t/4279"
    title: Lido forum — Treasury Management Principles and the Treasury Management Committee, 2023-04-04; token holders approve each new member
---

# ADR 005: Account graph and roles

## Context

- The Easy Track executor has neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Aragon Agent; the Dual Governance admin executor holds both [s2].
- The committee's Safe runs v1.3.0 at four-of-seven. The Emergency Brakes Safe runs v1.3.0 at three-of-five and can pause Easy Track, but cannot unpause it [s2].
- The locked Roles mastercopy has owner `0x…01` and uses storage from slot 0 [s2]. A Safe-style proxy would brick it, so each modifier is an EIP-1167 minimal proxy from the Zodiac module proxy factory.
- A module guard sees the calling module, not its role key, so one modifier cannot separate operator screening from recovery. [ADR 010](/adr/010-pre-execution-screening.md) puts no guard on the Asset Safe.
- Safe v1.5.0 was released on 2025-07-03. Certora audited it with formal verification; Ackee audited it with fuzzing. No advisory or paid bounty concerns it [s7]. Its value-holding history is short: the factory created 57 such Safes before March 2026. Safe{Wallet} adopted it for new Safes on 2026-09-22 [s7].
- Type-1 signatures accept an owner that sends the transaction or approves its hash [s8]. The kit executes Asset Safe transactions this way [s9] and sets up that Safe without a fallback handler [s10].
- The mandate draft promises dual access. The DAO and an emergency committee independent of the Treasury Management Committee can each return every asset to the treasury within six hours [s12].
- Lido's May 2026 tokenholder update limits protocol-role multisigs to pause or disable powers, with no resume or change powers. The CircuitBreaker Committee follows this rule [s13].
- The committee's 2023 principles ask token holders to approve each new member [s14].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Replaced by decision 24 (OD-58).
2. Financial risk, such as depegs, dependency failure and curator misbehaviour, is the common case. The emergency Safe answers it, and it can swap, exit and claim (decision log, 2026-09-22; OD-58).
3. The engineering organisation watches technical risk, bug-bounty submissions included, and pages the emergency Safe, which holds the switch (decision log, 2026-09-22; OD-58).
4. Stated by decision 23.
5. Replaced by decision 24 (OD-58).
6. The Asset Safe's policy splits across two modifiers, the operator modifier and the safety modifier. The orders account and the first-loss Safe carry one modifier each (decision log, 2026-09-22; OD-57, OD-60).
7. Replaced by decision 31 (OD-80).
8. Replaced by decision 12 (OD-17).
9. Lapsed (OD-80): no operator Safe; the committee's Safe is 4 of 7.
10. Lapsed (OD-80): the guard goes on the committee's v1.3.0 Safe.
11. Stated by [ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 7, 8 and 14.
12. The Asset Safe uses Safe v1.5.0, after the due diligence [s7] (OD-02, OD-17).
13. The emergency Safe, the orders account and the first-loss Safe use Safe v1.5.0 too (OD-17, OD-126).
14. Aragon Voting authorizes an Asset Safe transaction only by `approveHash` or by sending it itself, never by a contract signature (OD-17, OD-73).
15. The Asset Safe has no fallback handler. A protocol that needs one comes back to EM (OD-17).
16. Replaced by decision 24 (OD-58).
17. Replaced by decision 24 (OD-58).
18. Stated by [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 24 and 34.
19. Stated by [ADR 008](/adr/008-funding-through-existing-payments.md) decision 19.
20. Stated by [ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 17 and 20.
21. The orders account's one modifier carries the operator and emergency roles and the universal factory's governance and approvals roles. One modifier suffices: the emergency role's revoke stops the operator there, and recovery keeps working (OD-57, OD-58, OD-103, OD-118).
22. Replaced by decision 25 (OD-58).
23. The Emergency Brakes multisig touches no funds and holds no role on any modifier. In Clutch it keeps only the global Easy Track pause (decision log, 2026-09-22; OD-58).
24. The emergency Safe has five signers and a threshold of three. The committee appoints two of its members, the Emergency Brakes multisig appoints two of its members, and a DAO Snapshot appoints a fifth signer who is a member of neither. A signer who leaves their body also leaves the seat (OD-58).
25. The emergency role holds the switch: it disables the operator modifier, with the module argument pinned. On the orders account, the emergency role's revoke stops the operator (OD-58).
26. No emergency body resumes what it stopped. The emergency Safe and the Emergency Brakes multisig get no power to unpause Easy Track, to enable a module, to grant a permission again or to raise an approval. Motions restart the operator and bring back what the emergency role revoked ([ADR 013](/adr/013-one-easy-track-factory.md) decisions 12 and 16; [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 46). An Easy Track unpause stays an Aragon vote (OD-59, OD-97, OD-104, OD-119).
27. Stated by [ADR 008](/adr/008-funding-through-existing-payments.md) decisions 21 and 23.
28. Aragon Voting, not the Aragon Agent, is the only owner of the Asset Safe, the orders account and the first-loss Safe, each at one of one. A DAO action on the vault is a direct Voting item, without Dual Governance. Recovered assets go to the Aragon Agent (OD-73, OD-106).
29. Replaced by decision 26 (OD-78, OD-104).
30. Replaced by decision 26 (OD-104).
31. The committee's own Safe holds the operator role and the first-loss role, and it is the universal factory's trusted caller. Clutch deploys no operator Safe. The committee's Safe runs Safe v1.3.0 at 4 of 7 (OD-80).
32. The enabling vote applies the Safe batches by approved hash: Aragon Voting approves each batch's hash, and anyone executes the batches after the vote. The vote cannot carry the batches as its own items: Aragon Voting stores its script when a vote starts, and that transaction would need more gas than EIP-7825 lets one transaction use ([research note](/research/enabling-vote-rehearsal-2026-10-15.md)) (OD-92).
33. A change of the committee's members needs no Snapshot each time. Monitoring alerts on every change of the owners or the threshold of the committee's Safe, and a runbook covers the change (OD-109).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Emergency Safe.** It holds no assets and has no guard. Because one person can use several addresses, the fifth signer also confirms their independence in writing. At every stop, the emergency Safe raises the universal factory's counter ([ADR 013](/adr/013-one-easy-track-factory.md) decision 10), and the creator of each motion queued before the stop cancels it.
- **Modifiers.** The operator modifier and the safety modifier are Roles minimal proxies, each with the Asset Safe as owner, avatar and target. The first-loss Safe is the owner, avatar and target of its modifier. A narrowly scoped role can administer a modifier as the Safe without a vote, which makes the emergency revoke possible.

| Role | Holder | Modifier | May do | May not do |
|---|---|---|---|---|
| DAO | Aragon Voting, by vote (decision 28) | owner path | everything: own the Safe, replace the policy, change membership | — |
| `operator` | committee's Safe, four of seven (decision 31), screened once the guard is set ([ADR 010](/adr/010-pre-execution-screening.md) decisions 22 and 24) | operator | open, adjust and close positions in approved protocols within budgets; approve approved spenders, each approval spending its spender's budget key or staying below its fixed ceiling ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 13 and 14); stake ETH ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); convert DAI to USDS and back through Sky's converter, pinned to the Asset Safe ([ADR 011](/adr/011-launch-scope.md)); fund the orders account under budgets, and from it place CoW orders that pay the Asset Safe ([ADR 007](/adr/007-swapping-through-an-orders-account.md)) | move assets out, except into the orders account or, by a transfer pinned to it, to the Aragon Agent ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 9; not built yet on the Asset Safe); borrow; administer a modifier or a Safe; change its own permissions |
| `governance` | universal factory | operator | write and revoke operator permissions for a target that a motion names; set an operator budget under a launch key or a derived key, with a refill period of at least 30 days; restore a revoked target ([ADR 013](/adr/013-one-easy-track-factory.md) decisions 9 and 11) | grant or remove any role; touch the emergency role; target the modifier's avatar or any of its modules (OD-38); grant delegatecall (OD-36) |
| `emergency` | emergency Safe, three of five (decision 24) | safety, orders | zero approvals; exit positions to the Safe; unwrap wstETH and WETH, stake ETH and redeem sUSDS; send assets to the orders account or to the Agent; revoke the operator's targets and functions on the operator modifier and on the orders modifier; disable the operator modifier, with the module argument pinned (decision 25); on the orders account, cancel orders, set a relayer approval to zero, send tokens to the Agent or the Asset Safe, and place orders that buy USDC or USDT and pay the Agent | add a permission; enter a protocol except by staking ETH; borrow; reach the first-loss Safe ([ADR 008](/adr/008-funding-through-existing-payments.md)); change the recovery destination; disable the safety modifier or the orders modifier; restore what it stopped (decision 26) |
| exit governance | universal factory | safety | write an emergency exit for a target that a motion names, each tree pinned whole: redeem, withdraw and claim paid to the Asset Safe; cancel, a redeem queue's redeem and unwrap; a transfer pinned to the Agent, or to the Agent or the orders account for a token that recovery sells; an approval set to zero (OD-49; [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 45) | write anything but an exit; write under any key but `emergency`; grant Send or delegatecall; touch membership or the switch; set an allowance; target the Asset Safe or a module of it |
| `first-loss` | committee's Safe, four of seven (decision 31), screened once the guard is set ([ADR 010](/adr/010-pre-execution-screening.md) decision 24) | first-loss | request and claim the redemption of the DAO's earnETH and earnUSD shares, with the proceeds pinned to the Asset Safe; on the Earn team's written instruction ([ADR 008](/adr/008-funding-through-existing-payments.md) decisions 21 and 22; [ADR 014](/adr/014-funding-by-tranche-votes.md) decision 10); send insurance money back to the Asset Safe ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 28) | burn, transfer or approve the shares; pay anyone but the Asset Safe; act on the Asset Safe or the orders account |
| `first-loss-burn` | universal factory | first-loss | burn the DAO's earnETH and earnUSD shares, only as an enacted motion that the committee's Safe created ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23) | anything else |
| `restart` | universal factory | safety | `enableModule` on the Asset Safe, with the operator modifier as its argument, only as an enacted motion ([ADR 013](/adr/013-one-easy-track-factory.md) decision 12) | anything else |
| `insurance-funding` | universal factory | operator | transfer a listed token from the Asset Safe to the first-loss Safe, within the budget key of that token, only as an enacted motion ([ADR 014](/adr/014-funding-by-tranche-votes.md) decisions 7 and 11) | pay anyone but the first-loss Safe |
| `insurance` | universal factory | first-loss | approve an Earn deposit queue for its token and deposit into earnETH or earnUSD, with the first-loss Safe as the depositor; pay a fund's payout address within the fund's cap; each only as an enacted motion ([ADR 014](/adr/014-funding-by-tranche-votes.md) decisions 6 and 12) | pay any other address; transfer or approve the first-loss shares |
| `insurance-governance` | universal factory | first-loss | create a fund: write the `insurance` role's transfer of the fund's token and set the fund's cap, which never refills, only as an enacted motion ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 6) | write under any key but `insurance`; write anything but a plain transfer; target a vault account or an Earn share token; grant or remove a role |
| orders `governance` and approvals | universal factory | orders | add a token to the orders account's lists, with delegatecall only to the order signer; restore the operator after an emergency stop; raise an approval of CoW's vault relayer ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 41 and 46) | any other delegatecall; touch membership or the emergency role's revoke |

- **The enabling vote's batches (decision 32).** Publish each batch with the vote. `just batches-check <file>` computes its hash again from the batch, the Safe and the Safe's nonce, and checks the batch's calls: the calls on the Safe's modifiers are the compiled policy's, in its order, and every other call is a setup call that the command knows. The batches of one Safe run in nonce order. The builder starts a new batch below 12,000,000 gas and below 128 KiB. Rehearse the vote and the batches at a recent block before the vote starts and again before it executes.

## Options considered

- **Emergency Brakes as the emergency role:** not chosen. Financial response needs daily portfolio knowledge.
- **A separate technical committee for the switch:** not chosen. Emergency Brakes has technical members and holds two seats on the emergency Safe (decisions 24 and 25).
- **Emergency Brakes exits and returns assets:** not chosen. Technical brakes get no fund access (decision 23) [s13].
- **The committee's Safe as the emergency role, without a separate Safe:** not chosen. The committee could act alone, which defeats the independent exit [s13].
- **Emergency Brakes unpause or motion cancellation:** not chosen. Emergency bodies get no new powers and cannot resume (decision 26) [s13].
- **One modifier for all roles on the Asset Safe:** not chosen. Disabling it would stop recovery.
- **One modifier per account, the Asset Safe included:** not chosen. Governance and exit governance would share a contract with the emergency role, separated only by role-key pins, and the switch would depend on that modifier's membership check.
- **Agent ownership of the modifiers:** not chosen. Emergency revocation would need a DAO vote.
- **One vote for each Safe batch:** not chosen (decision 32).

## Consequences

- Voters see the batches as hashes (decision 32). A batch that can never run blocks its Safe until another vote approves a replacement.
- Each emergency quorum includes someone outside the committee and someone outside Emergency Brakes. The committee cannot act alone; two compromised committee keys reach no emergency power.
- The two Emergency Brakes members and the fifth signer can return assets within hours without the committee, which meets the mandate's independent three-of-five exit [s12]. This quorum has no spare signer; the fifth signer is pivotal. It can place recovery orders without an on-chain price floor (OD-48).
- No response-time data exists for the mixed group. A timed drill is required before launch.
- Any three emergency signers can change the Safe's owners. The controls are the seat rule, owner-change alerts and the DAO's replacement of the role holder.
- Four new Safes are required: Asset, emergency, orders and first-loss.
- On the orders account, the emergency role revokes the operator's targets or functions one by one (decision 25), because disabling its single modifier would stop recovery. The DAO can still disable it.
- Replacing the pinned operator modifier is a DAO vote that rewrites the safety policy in the same action and replaces the universal factory, which holds the modifier's address ([ADR 013](/adr/013-one-easy-track-factory.md)) [s1].
- The switch freezes queued operator-modifier writes. To freeze all Easy Track motions, exit writes included, the Lido incident process pages Emergency Brakes for its global pause.
- Each restart waits for the 72-hour objection window ([ADR 013](/adr/013-one-easy-track-factory.md) decision 12). The runbook revokes first and uses the switch only for permission-layer defects, the cap-breach trigger ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 34), or a compromised or silent committee.
- The LIP must disclose v1.5.0's short value-holding history [s7].
- The Asset Safe avoids contract signatures and fallback handling, where v1.5.0 and the next release change most [s7].
- Without a fallback handler, the Asset Safe refuses ERC-721 and ERC-1155 safe transfers and EIP-1271 signing (decision 15).
- An Asset Safe version change is a DAO vote with a delegatecall to Safe's migration contract.

## Confirmation

- INV-001, INV-002, INV-003, INV-009, INV-019, INV-021, INV-023, INV-025, INV-026, INV-027 and INV-035 in the [invariants](/specs/invariants.md).
- The compiler's tests of INV-027 are in `policy/constellation/compiler/compile.test.ts`; `compile.test.ts` also checks that the universal factory holds every motion role and no other.
- The operator cannot widen or reach administration [s6]; the Asset Safe has no guard [s11].
- The enabling-vote rehearsal: Aragon Voting approved a batch hash on each of the three Safes, and the batches ran (decision 32; [research note](/research/enabling-vote-rehearsal-2026-10-15.md)).

## Reversal conditions

- A signer compromise that reaches the emergency quorum.
- The fifth seat stays empty, or the mixed group misses the drill's time to initiate.
- An audit finding that a role can reach an owner-only surface.
- A Safe release or advisory that touches the Safe paths the vault uses, found by the check before the enabling vote ([ADR 010](/adr/010-pre-execution-screening.md)).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

- [OD-65](/registers/open-decisions.md): Who holds the emergency Safe's fifth seat? The fifth signer is a member of neither the committee nor the Emergency Brakes multisig (OD-58), and a DAO Snapshot appoints them.
- [OD-139](/registers/open-decisions.md): Which form does the emergency role's zeroing of an approval take in the launch policy? Today the policy lists the operator's spenders for each approved token. The exit-governance role writes a zeroing only for any spender (INV-025). So a new spender that enters through the policy's source changes the emergency role's tree of every approved token, no motion can write those trees, and the change needs a DAO vote. (A) The launch policy uses the form for any spender, for each approved token. The policy then has one form, and a new spender of an approved token needs no write for the emergency role. (B) The policy keeps the list. A motion that adds a spender then replaces the token's tree with the form for any spender, by hand in the motion, and the policy's source needs both forms.

<!-- end of generated block -->
