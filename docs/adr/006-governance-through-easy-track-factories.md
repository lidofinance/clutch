---
type: Decision
title: "ADR 006: Governance through Easy Track factories"
description: Fixed Easy Track templates for permission changes, emergency exits and routine removals.
tags: [governance, easy-track, factories, templates]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T21:39:40Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on factories, trusted caller, disclosure and templates, 2026-09-22, on the operator Safe, 2026-10-02, on removals, 2026-10-05, on the scope of decision 7, 2026-10-13, on the committee's Safe as trusted caller, 2026-10-14, and on re-grants by motion, 2026-10-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Easy Track settings, global duration, hash check, script format
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — governance and the template factories
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/gov/RoleToggleEVMScriptFactory.sol"
    title: Kit role-toggle factory at 370e20a, retired by OD-09
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/FactoryOnly.t.sol#L77"
    title: Kit test at 370e20a — withdrawing a key from the retired toggle factory kills a queued motion
  - id: s7
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/TrustedCaller.sol#L13"
    title: Easy Track TrustedCaller — the trusted caller is set once at deployment and cannot change
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
- A write replaces the role/target/selector tree [s3]. Motion-supplied trees would require on-chain proof that each replacement is narrower.

## Decision

EM decided on 2026-09-22 [s1]:

1. Easy Track factories are the only new contracts: "I am okay with building necessary ET factories, that's the only allowed new contracts".
2. The DAO does not approve each new protocol by vote. An Easy Track factory onboards it.
3. The Treasury Management Committee is the trusted caller of the factories. On 2026-10-02 EM set the committee's dedicated operator Safe as that trusted caller, so every motion is created through the screening guard ([ADR 010](/adr/010-pre-execution-screening.md)).
4. The minimum for every motion is a forum disclosure, alerting set up for the new target, and runbook discipline. The final stops are an objection or the Easy Track pause by the Emergency Brakes multisig.
5. The template catalogue is accepted: wrap and unwrap, tokenized vault, asynchronous queue vault, spender approval, swap instance approval, Morpho Blue, and two removal templates.
6. EM also asked that the removal templates skip the objection window. Easy Track cannot do this for any motion: the window is never shorter than 48 hours [s8].

EM decided on 2026-10-05, closing OD-09 [s1]:

7. The two removal templates are dropped. Every removal is the emergency Safe's immediate revoke, posted on the forum afterwards. Easy Track only expands.
8. No DAO-scoped role keys. The role-toggle factory and the governance role's `assignRoles` permission leave the design. Every operator permission lives under the `operator` role key.

EM decided on 2026-10-06, closing OD-36 [s1]:

9. A motion cannot grant the operator delegatecall. The governance role's `allowFunction` and `scopeFunction` permissions take only the execution options None or Send. A delegatecall from the Asset Safe runs foreign code in the Safe's own storage, so delegatecall for the operator needs a DAO vote.

EM decided on 2026-10-06, closing OD-38 [s1]:

10. A motion cannot give the operator the Asset Safe or any module of the Asset Safe as a target. The governance role refuses each of them as the administered target, the safety modifier included. The deployment manifest lists every module that the Asset Safe enables. The compiler refuses a policy that lets a role reach the Asset Safe or one of its modules beyond a fixed set of calls, a grant that does not refuse every one of them, and a manifest that misses a compiled modifier. A DAO vote that enables another module on the Asset Safe also lists it in the manifest and applies the policy compiled again.

EM decided on 2026-10-06, closing OD-41 and OD-45 [s1]:

11. Easy Track motions are the timelock for every structural increase of exposure in the policy: a new target and a higher budget each wait for the objection window. The unlock of a matured Lido product is a budget motion with a forum post ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 28 and 30).

EM decided on 2026-10-06, closing OD-46 [s1]:

12. A DAO vote adds a token to the orders account's lists, with its relayer approval, its emergency transfer and its recovery orders. No template adds one: the order signer's permission is a delegatecall, and decision 9 keeps no exception. The swap-instance template leaves the catalogue, so five templates remain ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).

EM decided on 2026-10-06, closing OD-49 [s1]:

13. A motion that onboards a protocol also adds its emergency exit. A new role on the safety modifier, the exit-governance role, held by the Easy Track script executor, writes exits for the emergency role through the same templates ([ADR 005](/adr/005-account-graph-and-roles.md)).

EM confirmed on 2026-10-13 [s1] that decision 7's "Easy Track only expands" is a rule for permissions. The first-loss burn motion writes no permission, so it does not break decision 7 ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23).

EM decided on 2026-10-14, closing OD-70 and OD-72 [s1]:

14. Routine removals run as motions of a removal template, which waits for the objection window. The emergency Safe's immediate revoke stays for emergencies.
15. Before the enabling vote, the template catalogue is checked against the protocols that the mandate allows. A claim template, with the receiver pinned to the Asset Safe, ships only if a launch protocol pays rewards.

Decision 14 replaces decision 7 for routine removals: a removal template returns, so Easy Track no longer only expands. An emergency removal stays the emergency Safe's revoke. Decision 14 also replaces [ADR 005](/adr/005-account-graph-and-roles.md) decision 11 for routine removals.

EM decided on 2026-10-14, closing OD-77 [s1]:

16. A restore writes the launch version of a permission, whatever changed since: it drops a branch that a later motion added, and it brings back a branch that a routine removal took away. The committee's forum disclosure of a restore motion shows the difference from the current permission, and the objection window is the control.

EM decided on 2026-10-14, after a count of the launch, closing OD-78 [s1]:

17. No restore template ships with the launch ([ADR 005](/adr/005-account-graph-and-roles.md) decision 30). A revoked permission comes back through an onboarding motion, if a template covers it, or by DAO vote.

Decision 17 replaces decision 16.

EM decided on 2026-10-14, in the 80/20 pass after OD-78, closing OD-79 [s1]:

18. The catalogue check of decision 15 also drops each onboarding template whose shape no protocol in the committee's named pipeline needs. A later vote registers such a template with its first protocol.

Since OD-80, the committee's own Safe is the trusted caller of decision 3 ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31). Until the launch cap lifts, the guard does not screen motion creation ([ADR 010](/adr/010-pre-execution-screening.md) decisions 20 to 22 and 24).

EM decided on 2026-10-22, closing OD-97 [s1]:

19. A motion may bring back a single permission that the emergency role revoked, with the 72-hour objection window. A restart after the switch stays a vote.

Decision 19 confirms the motion path of decision 17 for a single permission, and narrows the vote of [ADR 005](/adr/005-account-graph-and-roles.md) decision 30 to a restart after the switch.

## Proposed direction

The rest of this section is agent-drafted from the design [s3]. EM has not accepted it as text.

- Each factory owns one template and builds the permission tree. A motion carries only typed parameters, such as target, asset and budget key.
- Adding a branch to any function with existing branches, such as an `approve` spender, requires the complete tree: a write replaces the slot. How a factory reads the existing branches is owed design work. The spender-approval template (OD-69) and the removal template (decision 14) need it.
- Every factory fixes the committee's Safe as trusted caller at deployment [s7]. Permission factories pin `operator` and refuse the Asset Safe, orders account and their modules as targets.
- The first-loss burn factory writes no permission. Its motion burns an amount of pinned earnETH or earnUSD shares through `first-loss-burn` on the first-loss modifier ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 23). This is the only Clutch motion that moves value away from the DAO.
- The role-toggle factory left the design and kit on 2026-10-05 (decision 8) [s4]. Budget and template factories remain unbuilt.
- Modifier conditions independently prevent governance from changing membership or emergency powers, granting administrative targets, using foreign budget keys or setting refill periods below 30 days [s6]. Refused targets include both accounts and their modules (decision 10). A factory bug can still grant calls on ordinary targets, such as token transfers. Templates and objections control that risk.
- An objection, Easy Track pause or committee cancellation stops a queued onboarding motion. The emergency switch freezes its operator-modifier write; restart would re-arm it because motions never expire. The restart vote must cancel it first ([ADR 005](/adr/005-account-graph-and-roles.md), decisions 25 and 26). After enactment, emergency can revoke the new permission immediately.
- **Exit-governance** writes only `emergency`, through `scopeTarget`, `scopeFunction` and `allowFunction`, with None or Send (decision 9). It refuses the Asset Safe and all its modules, including safety (decision 10). It has no `assignRoles`, switch access or allowances.
- **Exit templates.** Each onboarding template also builds its target's emergency exit: redeem, withdraw, claim and cancel with receiver and owner pinned to the Asset Safe; receipt-token transfer pinned to the Agent; and zero spender approval. They add no entry, deposit or non-zero approval. The modifier cannot identify an exit tree, so code, tests and audit must enforce this.
- **Routine removal** writes the complete function tree without the removed branch and adds nothing (decision 14). Emergency uses immediate `revokeTarget` or `revokeFunction`, pinned to `operator`. All operator permissions use that key; revokes on the operator and orders modifiers cover them.

## Options considered

- Grant existing emergency exits in the enabling vote, then wait for DAO votes for later exits: EM rejected this under OD-49. Lido Lend's contract does not exist before the vote, leaving it without a first-day exit.
- Onboard value-holding protocols only by vote, with exits: EM rejected this because Lido Lend must join by motion on its first day ([ADR 011](/adr/011-launch-scope.md), decision 3).
- Pre-scope a role per strategy and toggle by motion: EM rejected this because each new protocol would need a vote.
- Accept motion-supplied trees: rejected because each needs a narrowing proof during the objection window.
- Add a controller for allowlists, stale motions and ceilings: removed because enactment rebuilds handle staleness and native modifier conditions express ceilings.
- Give Easy Track Agent authority: rejected because motions could run arbitrary Agent scripts.
- Removal-template motions with emergency revocation: EM rejected the 72-hour wait for a narrowing change, then adopted routine removal motions in decision 14.
- Shorten the global window or create another Easy Track for removals: windows below 48 hours are refused [s8].
- DAO-scoped keys with emergency unassignment: EM rejected because they add an administrative emergency permission to an already rejected model.

## Consequences

- The unscreened emergency path gains its first motion writer. A flaw in an exit template can widen the emergency role. Only objection, Easy Track pause or a DAO vote stops such a write. Audit must cover each exit template; drift detection must cover safety policy.
- Onboarding adds an emergency exit at enactment. Its safety-modifier permission survives the operator switch.
- Each template must pin receivers, owners and beneficiaries, bound value-moving amounts, exclude administrative selectors and emit the production script format.
- A motion can select an unaudited contract. Templates limit interactions and loss to the attached budget; objection, disclosure and monitoring provide the controls. The LIP must state this risk.
- Replacing the committee's Safe requires new factories with the new trusted caller and DAO registration [s7].
- The committee proposes its own expansions. Disclosure, objection and Emergency Brakes pause constrain them, as do the emergency Safe's revoke and switch, which the committee cannot use alone.
- Routine removals wait for objection and, after the cap lifts, screening at creation. Emergency removals require three-of-five, without screening or advance notice, followed by a forum post. Revoke-only paging is less severe than transfer or swap paging.
- Reinstatement needs onboarding or a vote. Routine removal deletes only its branch (decision 14). After emergency revocation, permissions without a template, such as staking or fixed-ceiling approval, require a vote (decision 17).
- The toggle factory and its tests are removed [s4][s5]. INV-007 retires.

## Confirmation

- INV-004, INV-005, INV-006 and INV-018 in the [invariants](/specs/invariants.md).
- Kit tests for the governance-role guards [s6]. The factory-path tests ran on the retired toggle factory, so the template factories need their own.
- `test_D4_the_switch_freezes_queued_motions_until_the_dao_restarts` (2026-10-13): with the operator modifier disabled, a queued motion's enactment fails while exits work, and the same motion enacts after the owner path enables the modifier again.
- For decision 10, a fork test replays the probe that found the gap and shows each step refused, and another refuses every module that the Asset Safe enables on chain. The compiler's own tests refuse a policy without the guard and a manifest that misses a module.
- Each template factory, when built, needs its own tests for the four audit properties above.

## Reversal conditions

- A template that can emit an unsafe permission.
- A motion that enacts against the disclosure rule without an objection.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
