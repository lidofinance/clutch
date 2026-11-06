---
type: Decision
title: "ADR 013: One Easy Track factory, and no Aragon votes after launch"
description: One universal Easy Track factory with versioned writes replaces the template catalogue; after the enabling vote, Aragon votes remain only for funding tranches and break-glass actions.
tags: [governance, easy-track, factory, versioning]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-11-06T04:19:05Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on Merkle roots and versioning, 2026-11-01, on the vote-free design, the factory, the orders, the restart, the ceilings and the two-modifier alternative, 2026-11-05, and on a new token's ceilings and motions after a revoke, 2026-11-06
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Easy Track's script permissions, enactment, cancel and pause; Roles storage; Merkle-root engines; the two-modifier alternative
  - id: s3
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — the template catalogue, the trusted caller and the guards of the governance role
  - id: s4
    resource: /research/single-vote-review-2026-10-14.md
    title: One Aragon vote to launch, Easy Track afterwards, 2026-10-14 — the actions that still needed a vote
  - id: s5
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the committed artifact feeds the vote, the Easy Track motions and the drift detector
  - id: s6
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/TrustedCaller.sol#L13"
    title: Easy Track TrustedCaller — a factory's trusted caller is set once at deployment and cannot change
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/278dc1e01a8a1e441027d9b19e2c0e977a05142e/docs/specs/enabling-vote.md#what-still-needs-a-vote-after-launch"
    title: The enabling-vote spec before this ADR, at 278dc1e — the table of what still needed a vote after launch
---

# ADR 013: One Easy Track factory, and no Aragon votes after launch

## Context

- Easy Track lets a factory's scripts call only the addresses and functions registered with that factory. Aragon Voting holds the admin role that registers or removes a factory [s2].
- At enactment, Easy Track builds the script through the factory again and checks the hash stored at creation. A factory's checks therefore run at creation and again at enactment [s2].
- Motions have no order. Two motions that write the same function can both pass their checks, and the later enactment wins [s2].
- A write sets the whole tree of a role, target and selector. The Roles modifier keeps its trees in internal storage, so no contract can read them [s2][s3].
- One write of the whole policy per motion does not scale: the Asset Safe's launch batch of 99 calls already takes about 6.3 million gas, and EIP-7825 caps a transaction at about 16.8 million [s2].
- Before this ADR, the catalogue of ADR 006 planned up to nine Clutch factories, and six kinds of action still needed an Aragon vote after launch [s3][s4][s7].

## Decision

EM decided on 2026-11-01, closing OD-100 [s1]:

1. Clutch uses no Merkle-root policy. The Roles modifiers keep their permission trees.
2. Easy Track motions carry versions, so that two motions cannot overwrite each other's changes.

EM decided on 2026-11-05, closing OD-101 [s1]:

3. After the enabling vote, no administrative action needs an Aragon vote. An Easy Track motion is the most that an action needs. Removing complexity is the aim: fewer moving parts is the best outcome.
4. Two kinds of action stay Aragon votes: each funding tranche ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 1), and the replacement of a role holder, such as the committee's Safe in the operator role.

The agent reads decision 3 to keep three more Aragon votes, for break-glass and Lido-wide actions: an owner action on a vault Safe (a module, the Safe version or the owners), a new or changed factory, and the unpause of Easy Track, which only Aragon Voting can do [s2].

EM decided on 2026-11-05, choosing option A, closing OD-102 [s1]:

5. One universal Easy Track factory carries every Clutch motion. It replaces the template catalogue, the budget factory and the first-loss burn factory.
6. The factory's Easy Track registration is its address book: the role call of each of the vault's four modifiers, and the factory's own commit. Nothing else is callable.
7. The factory widens a permission only through typed shapes. Each shape pins receivers, owners and beneficiaries to the vault, draws a budget key and writes the emergency exit. A raw write only narrows: a revoke, or a complete list that removes entries.
8. The factory cannot be upgraded, and a motion grants no delegatecall, with one exception: the order signer's, on the orders account ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 41). The guards against administrative targets and selectors stay ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 9 and 10).
9. Each shape derives a budget key for a new spender, so the policy holds no spare keys.
10. The factory keeps a version for each scope that a motion writes. It checks the versions at creation and again at enactment, and the script's last call commits the new versions. The emergency Safe can raise one counter that makes every open motion fail.
11. If the checks of decision 7 prove too tough and complex, the factory falls back to option B: raw writes that may also widen, with the objection window as the only bound on where funds go.

Decisions 5 to 10 are option A as the agent proposed it, and EM chose it. Before a switch to option B, the agent reports the prototype's numbers: the factory's size against the 24,576-byte limit of EIP-170, the gas per motion and the complexity of the checks.

EM decided on 2026-11-05, choosing option A, closing OD-104 [s1]:

12. A motion restarts the operator after the emergency switch. A restart role on the safety modifier, held by the Easy Track executor, may only enable the operator modifier on the Asset Safe. No emergency body resumes what it stopped.

EM decided on 2026-11-05, closing OD-105 [s1]:

13. A motion changes a ceiling. It may lower a ceiling at any time. It may raise one to at most twice its value, at most once in 15 days for that ceiling.

EM accepted the agent's limit on raises and wrote "Would consider doubling once per 15 days"; the agent reads that as the period. A ceiling that one motion could set to any value would bound nothing, because the same motion could raise the ceiling and the budget together.

EM decided on 2026-11-05, choosing option A, closing OD-112 [s1]:

14. The policy chains no second Roles modifier whose bounds only a vote changes. The factory's shapes give the bound.

EM decided on 2026-11-06, closing OD-113 and OD-114 [s1]:

15. The motion that introduces a token sets the token's ceilings, in the same motion. Decision 13 applies after that. The enabling vote sets the ceilings of the launch tokens.
16. A motion created after an emergency revoke may enact, and so bring the revoked permission back after its objection window. The factory's versions record only the factory's own writes, not the emergency role's revokes; the counter fails the motions that were open when the emergency Safe raised it.

EM wrote "ceiling should be set together with token intro"; the agent reads the introduction as the motion that first writes a permission for the token. EM confirmed on 2026-11-06 that a token's introduction counts as its ceilings' first raise, so the next raise waits 15 days [s1].

Decisions 5 to 7 replace the template catalogue of [ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 5, 14, 15, 17 and 18: a routine removal is the factory's narrowing write, a revoked permission comes back through a shape, and a shape that the factory lacks needs a changed factory, which is a vote. Decision 12 replaces the vote for a restart in ADR 006 decision 19 and in [ADR 005](/adr/005-account-graph-and-roles.md) decisions 26 and 30. Decision 9 replaces the spare keys of [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 39. Decision 13 replaces the fixed ceilings of ADR 009 decision 14 and [ADR 011](/adr/011-launch-scope.md) decision 8: each is now a ceiling under decision 13.

The accepted [ADR 004](/adr/004-specifications-and-policy-as-data.md) decision 14 says that the Easy Track templates consume the committed artifact [s5]. Since this ADR, that means the factory's motions: each motion is built from a merged commit of the policy.

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Scopes and versions.** A scope is one modifier's role, target and selector, one allowance key, or one ceiling. Its version is the hash of its current content, as the factory last wrote it. The enabling vote seeds the versions of the launch policy from the committed artifact. A motion names the version that it expects for each scope it writes, and the counter it saw. The factory refuses the motion at creation, and Easy Track's rebuild refuses it at enactment, if a version or the counter changed. The script's last call, the factory's `commit`, stores the new versions. A failed enactment reverts as a whole, so it leaves no partial write; the motion stays open until the committee's Safe or Aragon Voting cancels it [s2].
- **Narrowing.** A raw write names the scope's current content, which must match its version, and writes a subset of it, or revokes the target or the function.
- **Address book.** The registration lists `execTransactionWithRole` on the operator, safety, orders and first-loss modifiers, and the factory's `commit`. The Easy Track executor holds one role per kind of write: `governance` and `insurance-funding` on the operator modifier, `exit-governance` and `restart` on the safety modifier, the governance and approvals roles on the orders modifier, and `first-loss-burn` with the insurance roles on the first-loss modifier ([ADR 014](/adr/014-funding-by-tranche-votes.md)).
- **Shapes at launch.** An ERC-20 approval list; an ERC-4626 vault; an asynchronous queue vault; a market compatible with Morpho Blue, for Lido Lend; a wrapper; Sky's DAI–USDS converter; the orders account's token lists, with the order signer, ComposableCoW's TWAP, the relayer approval, the emergency transfer and the recovery orders; budgets, with a refill period of at least 30 days; ceilings (decision 13); the first-loss burn; the insurance funds of ADR 014; the restart; and a claim, if a launch protocol pays rewards. Each onboarding shape also writes its target's exit for the emergency role through `exit-governance`.
- **The counter.** Aragon Voting can raise it too, as the owner. The emergency Safe raises it with every switch, so a motion queued before a stop fails at enactment.
- **Ceilings.** The factory keeps each ceiling with the time of its last raise. Ceilings are per shape class and per token, so a new protocol uses an existing ceiling.
- **The `motion` command.** It takes a change of the policy from a merged commit, reads the versions and the counter on chain, builds the motion's calldata, runs the motion against the live Easy Track on a fork, prints the permission difference from the modifiers' events and drafts the forum post. The Zodiac UI does not know the factory's format or its versions, so it is not the planner.
- **Monitoring.** It decodes every motion of the factory from `MotionCreated`, and alerts on a failed enactment, a raise of the counter, a ceiling motion, a restart motion and few free motion slots ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 45).
- **Trusted caller.** The committee's Safe is the factory's trusted caller ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31). Easy Track sets it once [s6], so a new committee Safe needs a new factory, which is a vote (decision 4).

## Options considered

- Merkle-root policies, as in Veda's and Mellow's vaults: EM rejected them on 2026-11-01. The Roles modifier has no root and no proof channel, so a root engine would replace the modifiers with new code [s2].
- One write of the whole policy per motion: rejected, because it approaches EIP-7825's gas cap as the policy grows [s2].
- Scope writes without versions: rejected, because two motions on one scope undo each other [s2].
- Option B, raw writes in both directions: kept as the fallback of decision 11.
- Option C, keeping the catalogue: not chosen. It needs up to nine factories and more votes.
- Two chained Roles modifiers, an outer one with bounds that only a vote changes: not adopted (decision 14). It adds a modifier and a second policy, and each change of a bound becomes a vote [s2].
- Restart by vote: not chosen (decision 12).
- Ceilings fixed at deployment: replaced by decision 13.
- Orders through ComposableCoW's TWAP only, without the order signer: not chosen ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 41).

## Consequences

- The factory becomes the most critical contract, and its shapes are the bound. It is new code, with the order signer (OD-96), and the external audit covers both.
- A captured committee, with no objection, can onboard a bad protocol and lose up to its budgets in each period, as before. A ceiling rises at most twofold in 15 days.
- A captured committee could restart the operator after a stop. The motion is visible for 72 hours, the counter fails it after any new stop, and the emergency Safe can stop the operator again.
- A stale motion fails at enactment and holds one of Easy Track's 20 shared motion slots until it is cancelled.
- A token's first ceilings are as high as the motion that introduces the token sets them, so the objection window is their only bound (decision 15). Decision 13's limit applies from then on.
- A launch token counts as introduced once the enabling vote seeds one of its ceilings, so a class of ceiling that the vote does not seed for it stays unset: no motion sets it. The enabling vote therefore seeds both classes for every launch token, with zero where no entry uses the class.
- A motion created after an emergency revoke can bring the permission back after its 72 hours, unless LDO holders object or the emergency Safe raises the counter again (decision 16, OD-97).
- Every Clutch motion uses one factory and one calldata format, so monitoring decodes one format.
- After launch, Aragon votes are for funding tranches and break-glass actions only.

## Confirmation

- A fork prototype of the factory, with tests against the live Easy Track: a conflict on one scope in both orders; disjoint scopes in any order; the counter failing a stale motion; a cancel; the restart; and every refusal, which covers delegatecall other than the order signer's, a protected target, an administrative selector, a raw widening, a ceiling above its limit, a second raise within 15 days and a call outside the address book.
- The factory's size against EIP-170 and the gas per motion, reported before decision 11 applies.
- On 2026-11-05 a prototype of the factory's core passed 15 tests against the live Easy Track on a fork, and eight mutants of its checks each failed a test. It is 11,553 bytes, 47 percent of EIP-170's limit, and its largest measured motion enacts in about 3.8 million gas ([research note](/research/universal-factory-prototype-2026-11-05.md)).
- On 2026-11-06 the prototype built decision 15: one operation writes a token's first approval list and sets both of its ceilings; a token is introduced once; an approval list for a token that was never introduced, and a ceiling operation on a ceiling that was never set, are refused. It counts the introduction as each ceiling's first raise ([research note](/research/universal-factory-prototype-2026-11-05.md#decision-15-built-on-2026-11-06)).
- INV-032 to INV-036 in the [invariants](/specs/invariants.md).

## Reversal conditions

- The factory does not fit EIP-170, or its checks prove too complex to review: decision 11.
- A shape that can emit an unsafe permission.
- A motion that enacts against the disclosure rule without an objection.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
