---
type: Decision
title: "ADR 013: One Easy Track factory, and no Aragon votes after launch"
description: One universal Easy Track factory carries every Clutch motion, with versioned writes, holds the motion roles and makes each motion's writes in one call; after the enabling vote, Aragon votes remain only for funding tranches, role holders and break-glass actions.
tags: [governance, easy-track, factory, versioning]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-11-11T04:57:10Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on versions, the vote-free design, the factory, the restart, the ceilings, a new token's ceilings, the companion contract, a motion's one call and the votes that remain, 2026-11-01 to 2026-11-10
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Easy Track's script permissions, enactment, cancel and pause; Roles storage; Merkle-root engines; the two-modifier alternative
---

# ADR 013: One Easy Track factory, and no Aragon votes after launch

## Context

- Easy Track lets a factory's scripts call only the addresses and functions registered with that factory. Aragon Voting holds the admin role that registers or removes a factory [s2].
- At enactment, Easy Track builds the script through the factory again and checks the hash stored at creation. A factory's checks therefore run at creation and again at enactment [s2].
- Motions have no order. Two motions that write the same function can both pass their checks, and the later enactment wins [s2].
- A write sets the whole tree of a role, target and selector. The Roles modifier keeps its trees in internal storage, so no contract can read them [s2].
- Easy Track's executor copies a script into memory three times for each call that the script makes, so the gas of a script grows with its size times its calls. EIP-7825 caps a transaction at 16,777,216 gas ([research note](/research/orders-token-motions-2026-11-08.md)).

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Clutch uses no Merkle-root policy. The Roles modifiers keep their permission trees (OD-100).
2. Easy Track motions carry versions, so that two motions cannot overwrite each other's changes (OD-100).
3. After the enabling vote, no administrative action needs an Aragon vote. An Easy Track motion is the most that an action needs. Removing complexity is the aim: fewer moving parts is the best outcome (OD-101).
4. These actions stay Aragon votes: each funding tranche ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 1); the replacement of a role holder, such as the committee's Safe in the operator role; an owner action on a vault Safe, such as a module, the Safe version or the owners; a new or changed factory; and the unpause of Easy Track, which only Aragon Voting can do (OD-101, OD-125).
5. One universal Easy Track factory carries every Clutch motion (OD-102).
6. The factory's Easy Track registration is its address book: one call, the factory's own `applyMotion`. Nothing else is callable (OD-102, OD-118).
7. The factory widens a permission only through typed shapes. Each shape pins receivers, owners and beneficiaries to the vault, draws a budget key and writes the emergency exit. A raw write only narrows: a revoke, or a complete list that removes entries (OD-102).
8. The factory cannot be upgraded, and a motion grants no delegatecall, with one exception: the order signer's, on the orders account ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 41). The guards against administrative targets and selectors stay ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 9 and 10) (OD-102, OD-103).
9. Each shape derives a budget key for a new spender, so the policy holds no spare keys (OD-102).
10. The factory keeps a version for each scope that a motion writes. It checks the versions at creation and again at enactment, and the motion's one call stores the new versions. The emergency Safe can raise one counter that makes every open motion fail (OD-100, OD-102, OD-118).
11. If the checks of decision 7 prove too tough and complex to review, the factory falls back to raw writes that may also widen, with the objection window as the only bound on where funds go. Before such a switch, the agent reports the factory's size, its gas per motion and the complexity of its checks (OD-102).
12. A motion restarts the operator after the emergency switch. A restart role on the safety modifier, held by the universal factory, may only enable the operator modifier on the Asset Safe. No emergency body resumes what it stopped (OD-104, OD-118).
13. A motion changes a ceiling. It may lower a ceiling at any time. It may raise one to at most twice its value, at most once in 15 days for that ceiling (OD-105).
14. The policy chains no second Roles modifier whose bounds only a vote changes. The factory's shapes give the bound (OD-112).
15. The motion that first writes a permission for a token introduces the token and sets its ceilings; the launch tokens' ceilings come with the launch policy. A ceiling's seed and an introduction each count as its first raise, so its next raise waits 15 days. Decision 13 applies after that (OD-113, OD-120).
16. A motion created after an emergency revoke may enact, and so bring the revoked permission back after its objection window. The factory's versions record only the factory's own writes, not the emergency role's revokes; the counter fails the motions that were open when the emergency Safe raised it (OD-114).
17. The universal factory may carry a shape in a thin companion contract. The factory creates the companion in its own constructor and only reads from it. The companion holds no state, makes no call and cannot be upgraded, and Easy Track registers the factory alone. The orders shape is the first such companion (OD-117).
18. The universal factory holds the motion roles. A motion's script makes one call, the factory's `applyMotion`. That call checks the motion again, stores its versions and makes its writes, all in the enactment's one transaction (OD-118).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Scopes and versions.** A scope is one modifier's role, target and selector, one allowance key, one ceiling, or the orders account's lists. Its version is the hash of its current content, as the factory last wrote it. The factory's constructor seeds the versions and the ceilings of the launch policy, which the enabling vote applies. A motion names the version that it expects for each scope it writes, and the counter it saw; the factory refuses it, at creation and at enactment, if a version or the counter changed. A failed enactment reverts as a whole and leaves no partial write; the motion stays open until the committee's Safe or Aragon Voting cancels it [s2].
- **Narrowing.** A raw write names the scope's current content, which must match its version, and writes a subset of it, or revokes the target or the function.
- **Roles.** The factory holds one role per kind of write: `governance` and `insurance-funding` on the operator modifier, `exit-governance` and `restart` on the safety modifier, the governance and approvals roles on the orders modifier, and `first-loss-burn` with the insurance roles on the first-loss modifier ([ADR 014](/adr/014-funding-by-tranche-votes.md)). Easy Track's executor holds none.
- **Shapes at launch.** The agent proposes the list below; a shape that the factory lacks needs a changed factory, which is a vote (decision 4). Each onboarding shape also writes its target's exit for the emergency role through `exit-governance`. No shape covers a third-party lending pool such as Aave, which is outside the launch scope. The prototype builds the approval list, the introduction, budgets, ceilings, the revoke, the target restore, the restart, insurance money, the orders token and the orders restore.

| Shape | Motion fields | Writes |
|---|---|---|
| ERC-20 approval list | token; the current and the next list | the token's complete `approve` list, each new spender's amount spending a key derived for it; zero spends nothing |
| Introduction | token; its first list; its budget and approval ceilings | the token's first approval list and both of its ceilings, which count as their first raise (decision 15) |
| Wrapper | wrapper, underlying | `wrap` and `unwrap`, or `deposit` and `withdraw` on WETH; the output returns to the avatar |
| ERC-4626 vault | vault, asset | the asset's `approve` to the vault, spending a key derived for the vault; `deposit` with receiver `EqualToAvatar`; `redeem` and `withdraw` with receiver and owner `EqualToAvatar` |
| Asynchronous queue vault | vault, asset | the asset's `approve` to the queue, spending a key derived for the queue; the asynchronous deposit request with any owner pinned to the avatar; the redeem request, cancel and claim with receiver and owner pinned to the avatar |
| Market compatible with Morpho Blue | contract, market parameters | the loan token's `approve` to that contract, spending a key derived for it; `supply` with `onBehalf` pinned to the avatar; `withdraw` with `onBehalf` and `receiver` pinned to the avatar. Lido Lend's address arrives with the motion (OD-49); end-to-end tests against the deployed Morpho Blue prove the shape before Lido Lend exists |
| Sky's DAI–USDS converter | none | the conversions in both directions, with the receiver pinned to the avatar, and the DAI and USDS approvals to the converter below their ceiling (OD-22) |
| Orders account token | token; its budget and approval ceilings; the current lists | the operator's transfer into the orders account under a key derived for the token; the token on both sides of signer and TWAP orders and in what recovery orders sell; its relayer approval; the emergency role's zeroing and transfer; the operator's return; and the token's exit on the Asset Safe ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 41, 44 and 45) |
| Orders account restore | the current lists; the tokens whose relayer approval it raises | the operator's targets, order trees, cancels and returns for the current lists, and the named relayer approvals ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 46) |
| Budget | token, spender, balance, maximum refill, refill, period, expected version | `setAllowance` within the token's budget ceiling, with a period of at least 30 days |
| Ceiling | key, expected value, new value | a lower ceiling at any time, or a raise to at most twice the ceiling, at most once in 15 days (decision 13) |
| Revoke | target, selector, expected version | the revoke of one operator function: a raw write that only narrows (decision 7) |
| Target restore | target | the function permissions stored under a revoked target, as they were last written (decision 16) |
| Restart | none | `enableModule` for the operator modifier, through the `restart` role (decision 12) |
| Insurance money | token, amount | a transfer from the Asset Safe to the first-loss Safe ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 7) |
| First-loss burn | share token, amount | `burn` through the `first-loss-burn` role ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23) |
| Insurance fund | the framework's checklist | the fund's permissions, its deposit, its burn and its payout ([ADR 014](/adr/014-funding-by-tranche-votes.md) decisions 4 to 7) |
| Claim | protocol, reward contract | the protocol's reward claim with the receiver pinned to the avatar; only if a launch protocol pays rewards (OD-72) |
- **The counter.** The emergency Safe raises it with every switch, so a motion queued before a stop fails at enactment. Aragon Voting can raise it too.
- **Ceilings.** The factory keeps each ceiling with the time of its last raise. A ceiling belongs to a class, budget or approval cap, and to a token; every budget key of a token shares the token's budget ceiling.
- **The `motion` command.** It takes a change of the policy from a merged commit, reads the versions and the counter on chain, builds the motion's calldata, runs the motion against the live Easy Track on a fork, prints the writes that the factory's `writesOf` returns and the permission difference from the modifiers' events, and drafts the forum post. The Zodiac UI does not know the factory's format or its versions, so it is not the planner.
- **Monitoring.** It decodes every motion of the factory from `MotionCreated`, and alerts on a failed enactment, a raise of the counter, a ceiling motion, a restart motion and few free motion slots ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 45).
- **Trusted caller.** The committee's Safe is the factory's trusted caller ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31). The factory's constructor fixes it, so a new committee Safe needs a new factory, which is a vote (decision 4).

## Options considered

- Merkle-root policies, as in Veda's and Mellow's vaults: not chosen (decision 1). The Roles modifier has no root and no proof channel, so a root engine would replace the modifiers with new code [s2].
- One write of the whole policy per motion: not chosen. It approaches EIP-7825's gas cap as the policy grows [s2].
- Scope writes without versions: not chosen. Two motions on one scope undo each other [s2].
- Raw writes in both directions: the fallback of decision 11.
- A catalogue of template factories: not chosen. It needs up to nine factories and more votes.
- Two chained Roles modifiers, an outer one with bounds that only a vote changes: not chosen (decision 14). It adds a modifier and a second policy, and each change of a bound becomes a vote [s2].
- Restart by vote: not chosen (decision 12). It is the vote after launch that decision 3 avoids.
- A motion that approves the hash of its writes, with a helper that holds the roles and makes the writes in a second transaction: not chosen (decision 18). Each motion would need a second transaction, an expiry for an approval that nobody applies, and its checks again at execution.

## Consequences

- The factory becomes the most critical contract, and its shapes are the bound. It is new code, with its companion and CoW's order signer (OD-96), and the external audit covers all three.
- A captured committee, with no objection, can onboard a bad protocol and lose up to its budgets in each period. A ceiling rises at most twofold in 15 days.
- A captured committee could restart the operator after a stop. The motion is visible for 72 hours, the counter fails it after any new stop, and the emergency Safe can stop the operator again.
- A stale motion fails at enactment and holds one of Easy Track's 20 shared motion slots until it is cancelled.
- A token's first ceilings are as high as the motion that introduces the token sets them, so the objection window is their only bound (decision 15). Decision 13's limit applies from then on.
- A launch token counts as introduced once one of its ceilings is seeded, so a class of ceiling that the seed does not set for it stays unset, and no motion sets it. The seed therefore sets both classes for every launch token, with zero where no entry uses the class.
- A motion created after an emergency revoke can bring the permission back after its 72 hours, unless LDO holders object or the emergency Safe raises the counter again (decision 16).
- Every Clutch motion uses one factory and one calldata format, so monitoring decodes one format.
- Easy Track's executor, which every Easy Track factory of the DAO shares, holds no Clutch role. Another factory reaches the vault only if Aragon Voting registers it for the factory's `applyMotion`, and that call runs the factory's shape, version and counter checks again, though not its trusted-caller check.
- A vote that replaces the factory deploys the new factory seeded with the current versions and ceilings, registers it, and moves every motion role to it; the ceilings' raise clocks start again from the new seed.
- A motion's script shows one call. The factory's `writesOf` returns the writes that a motion makes if it is enacted now, for the forum post and for monitoring.

## Confirmation

- The factory's fork tests against the live Easy Track, in `test/UniversalFactory.t.sol` and `test/OrdersAccount.t.sol`: a conflict on one scope in both orders; disjoint scopes; the counter; a cancel; the restart; introductions with their ceilings; a ceiling's raise limit, with the seed as the first raise; the restore of a revoked target; insurance money; the orders token and the orders restore; the one-call registration, the roles that the factory holds, and a refused write that fails the whole motion; and every refusal, which covers delegatecall other than the order signer's, a protected target, an administrative selector, a raw widening, a ceiling above its limit, a second raise within 15 days and a call outside the address book.
- The factory is 17,295 bytes and its orders shape 12,524, under EIP-170's 24,576. One motion that adds a token enacts in 7,789,536 gas (`test_factory_orders_token_motion`), and one that restores the orders account in 7,102,619 (`test_factory_orders_restore_after_an_emergency_stop`), both under EIP-7825's cap.
- INV-032 to INV-036 in the [invariants](/specs/invariants.md).

## Reversal conditions

- A shape that fits neither the factory nor a companion contract, or checks too complex to review: decision 11.
- A motion whose writes do not fit one transaction under EIP-7825's cap, even as one call.
- A shape that can emit an unsafe permission.
- A motion that enacts against the disclosure rule without an objection.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
