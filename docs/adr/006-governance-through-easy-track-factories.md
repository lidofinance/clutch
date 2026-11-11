---
type: Decision
title: "ADR 006: Governance through Easy Track factories"
description: The governance role's guards, protocols onboarded by motion with their emergency exits, disclosure duties, removals and restores; ADR 013 holds the universal factory.
tags: [governance, easy-track, factories]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T06:58:05Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on onboarding by motion, the trusted caller, disclosure, removals, delegatecall, administrative targets, exits and restores, 2026-09-22 to 2026-11-10
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Easy Track settings, global duration, hash check, script format
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L176"
    title: Kit tests at 7a8c661 — the governance role cannot change membership, touch the emergency role, grant an administrative target, raise a foreign allowance key or shorten a refill period
  - id: s8
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/MotionSettings.sol#L36"
    title: Easy Track MotionSettings at 3183d1f — the minimum motion duration is 48 hours, and setMotionDuration refuses less (L93)
---

# ADR 006: Governance through Easy Track factories

## Context

- Easy Track's global objection window is 72 hours; holders of 0.5 percent of LDO can reject a motion [s2].
- Each motion uses the global window at creation. Factories cannot shorten it [s2], and the global setting cannot fall below 48 hours [s8].
- At enactment, Easy Track rebuilds the factory's script and checks its stored hash [s2].
- A write replaces the whole tree of a role, target and selector.

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. The only new contracts are the universal factory and its thin companion contracts; CoW's order signer counts as new code with them (decision log, 2026-09-22; OD-96, OD-102, OD-117).
2. The DAO does not approve each new protocol by vote. A motion of the universal factory onboards it (decision log, 2026-09-22; OD-102).
3. Stated by [ADR 005](/adr/005-account-graph-and-roles.md) decision 31 and [ADR 010](/adr/010-pre-execution-screening.md) decision 24 (decision log, 2026-09-22; OD-01).
4. The minimum for every motion is a forum disclosure, alerting set up for the new target, and runbook discipline. The final stops are an objection, the Easy Track pause by the Emergency Brakes multisig, and a raise of the factory's counter (decision log, 2026-09-22; OD-102).
5. Replaced by ADR 013 decision 5 (OD-102).
6. Lapsed (OD-09): Easy Track never shortens a motion's window below 48 hours.
7. An emergency removal is the emergency Safe's immediate revoke, posted on the forum afterwards (OD-09, OD-70).
8. No DAO-scoped role keys, and no `assignRoles` for the governance role. Every operator permission lives under the `operator` role key (OD-09).
9. A motion grants no delegatecall, with one exception: the order signer's, on the orders account ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 41). On the Asset Safe, the governance role's `allowFunction` and `scopeFunction` take only the execution options None or Send, because a delegatecall from the Asset Safe runs foreign code in the Safe's own storage (OD-36, OD-103).
10. A motion cannot give the operator the Asset Safe or any of its modules as a target. The governance role refuses each of them as the administered target, the safety modifier included. The deployment manifest lists every module that the Asset Safe enables. The compiler refuses a policy that lets a role reach the Asset Safe or one of its modules beyond a fixed set of calls, a grant that does not refuse every one of them, and a manifest that misses a compiled modifier. A DAO vote that enables another module on the Asset Safe also lists it in the manifest and applies the policy compiled again (OD-38).
11. Easy Track motions are the timelock for every structural increase of exposure in the policy: a new target and a higher budget each wait for the objection window. The unlock of a matured Lido product is a budget motion with a forum post ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28) (OD-41, OD-45).
12. Replaced by ADR 007 decision 41 (OD-103).
13. A motion that onboards a protocol also adds its emergency exit, from the same shape, through the exit-governance role on the safety modifier, which the universal factory holds ([ADR 013](/adr/013-one-easy-track-factory.md) decisions 7 and 18) (OD-49, OD-102, OD-118).
14. A routine removal is a narrowing motion of the universal factory, which waits for the objection window ([ADR 013](/adr/013-one-easy-track-factory.md) decision 7) (OD-70, OD-102).
15. Replaced by ADR 013 decision 5 (OD-102).
16. Replaced by decision 19 (OD-97).
17. Replaced by decision 19 (OD-97, OD-102).
18. Replaced by ADR 013 decision 5 (OD-102).
19. Stated by [ADR 013](/adr/013-one-easy-track-factory.md) decisions 12 and 16 and [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 46 (OD-97).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **The guards.** Modifier conditions keep the governance role from changing membership or emergency powers, granting administrative targets, using foreign budget keys or setting refill periods below 30 days [s6] (INV-004, INV-012). A factory bug can still grant calls on ordinary targets, such as token transfers; the shapes and objections control that risk.
- **Exit governance** writes through `scopeTarget`, `scopeFunction` and `allowFunction` (OD-49), within the limits of INV-025.
- **Exits from the shapes.** An exit adds no entry, deposit or non-zero approval. Which target gets which exit is the shape's choice, which the code, the tests and the audit check.

## Options considered

- Grant the emergency exits in the enabling vote, and later exits by DAO vote: not chosen. Lido Lend's contract does not exist before the vote, so it would have no first-day exit (OD-49).
- Onboard value-holding protocols only by vote: not chosen. Lido Lend joins by motion ([ADR 011](/adr/011-launch-scope.md) decision 13).
- Pre-scope a role per strategy and toggle it by motion: not chosen. Each new protocol would need a vote.
- Motion-supplied condition trees: not chosen. Each would need a narrowing proof during the objection window; the factory builds each tree from typed entries instead ([ADR 013](/adr/013-one-easy-track-factory.md) decision 7).
- Easy Track authority over the Agent: not chosen. Motions could run arbitrary Agent scripts.
- A shorter global window, or a second Easy Track for removals: not possible. Easy Track refuses a window below 48 hours [s8].
- DAO-scoped keys with emergency unassignment: not chosen. They add an administrative emergency permission.

## Consequences

- The unscreened emergency path has a motion writer: a flaw in an exit shape can widen the emergency role ([threat model](/specs/threat-model.md)).
- An exit that onboarding adds is a safety-modifier permission, so it survives the operator switch.
- A motion can select an unaudited contract ([threat model](/specs/threat-model.md)). The LIP states this risk.
- The committee proposes its own expansions. Disclosure, objection and the Emergency Brakes pause constrain them, as do the emergency Safe's revoke and switch, which the committee cannot use alone.
- A routine removal waits for the objection window and, once the guard is set, for screening at creation. An emergency removal has neither screening nor advance notice.

## Confirmation

- INV-004, INV-005, INV-006, INV-018, INV-025 and INV-029 in the [invariants](/specs/invariants.md).
- For decision 10, the compiler's tests refuse a policy without the guard and a manifest that misses a module.

## Reversal conditions

- The reversal conditions of [ADR 013](/adr/013-one-easy-track-factory.md): a shape that can emit an unsafe permission, or a motion that enacts against the disclosure rule without an objection.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
