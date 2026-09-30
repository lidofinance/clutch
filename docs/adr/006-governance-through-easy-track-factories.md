---
type: Decision
title: "ADR 006: Governance through Easy Track factories"
description: Easy Track factories are the only new contracts; the committee is their trusted caller; each factory builds a permission tree from a template fixed at audit time, so a motion carries parameters, never a tree.
tags: [governance, easy-track, factories, templates]
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
    title: Decision log — EM on factories, trusted caller, disclosure and templates, 2026-09-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Easy Track settings, global duration, hash check, script format
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — governance, the toggle factory and the template factories
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/gov/RoleToggleEVMScriptFactory.sol"
    title: Kit role-toggle factory at 370e20a
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/FactoryOnly.t.sol#L77"
    title: Kit test at 370e20a — withdrawing a key kills a queued motion
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L246"
    title: Kit tests at 370e20a — the governance role cannot change membership, touch the emergency role, grant an administrative target or raise a foreign allowance key
---

# ADR 006: Governance through Easy Track factories

## Context

- Easy Track has one global objection period of 72 hours and an objection threshold of 0.5 percent of LDO [s2].
- A motion takes its duration from that global setting when it is created. No factory can shorten it [s2].
- At enactment, Easy Track calls the factory again and requires the rebuilt script to match the stored hash [s2].
- A permission write replaces the stored tree for a role, target and selector [s3]. If a motion could submit a tree, every motion would need an on-chain proof that the new tree is narrower.

## Decision

EM decided on 2026-09-22 [s1]:

1. Easy Track factories are the only new contracts: "I am okay with building necessary ET factories, that's the only allowed new contracts".
2. The DAO does not approve each new protocol by vote. An Easy Track factory onboards it.
3. The Treasury Management Committee is the trusted caller of the factories.
4. The minimum for every motion is a forum disclosure, alerting set up for the new target, and runbook discipline. The final stops are an objection or the Easy Track pause by the Emergency Brakes multisig.
5. The template catalogue is accepted: wrap and unwrap, tokenized vault, asynchronous queue vault, spender approval, swap instance approval, Morpho Blue, and two removal templates.
6. EM also asked that the removal templates skip the objection window. Easy Track cannot do this per factory [s2]. Open item OD-09 holds the choice.

## Proposed direction

The rest of this section is agent-drafted from the design [s3]. EM has not accepted it as text.

- Each factory owns one template. A motion carries typed parameters only, such as a target, an asset and a budget key. The factory builds the tree.
- Every factory hard-codes the `operator` role key and refuses the modifiers and the Safe as a target.
- The role-toggle factory exists in the kit [s4]. The budget factory and the template factories are not built.
- The modifier constrains the governance role again, so a factory bug cannot widen anything. The governance role cannot change membership, cannot touch the emergency role, cannot grant the operator an administrative target, and cannot set an allowance outside the operator's budget keys [s6].
- Withdrawing a key from a factory's allowlist kills any queued motion for that key, because enactment rebuilds the script [s5].
- Immediate de-scoping is an emergency action. The emergency role holds `revokeTarget` and `revokeFunction`, pinned to the operator, and acts at once. Easy Track removal is the routine, reviewable path.

## Options considered

- The DAO pre-scopes one role key per strategy by vote, and motions toggle them. Not chosen by EM: every new protocol would need a vote.
- Motions submit condition trees. Not chosen: the narrowing proof is a tree comparison that no one should solve under an objection window.
- A bespoke controller contract for the allowlist, stale motions and ceilings. Removed: Easy Track's rebuild at enactment covers stale motions, and the modifier expresses the ceilings natively.
- Easy Track authority over the Agent. Not chosen: every motion could then run any script as the Agent.

## Consequences

- The audit question becomes "can this template ever emit something unsafe". Each template must pin every receiver, owner and beneficiary field, bound every value-moving amount, never emit an administrative selector, and produce a script in the production format.
- A motion can point the operator at a contract that no one has audited. The template bounds how the vault interacts with it, so the loss ceiling is the attached budget. The controls are the objection window, the disclosure and monitoring. The LIP must say so plainly.
- The committee proposes its own expansions. The objection window, the disclosure rule and the Emergency Brakes pause are the counterweights.

## Confirmation

- INV-004, INV-005, INV-006 and INV-007 in the [invariants](/specs/invariants.md).
- Kit tests for the factory path and the governance-role guards [s5][s6].
- Each template factory, when built, needs its own tests for the four audit properties above.

## Reversal conditions

- A template that can emit an unsafe permission.
- A motion that enacts against the disclosure rule without an objection.

## Open questions

- OD-09: the immediate-removal path.
