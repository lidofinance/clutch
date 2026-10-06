---
type: Decision
title: "ADR 006: Governance through Easy Track factories"
description: Easy Track factories are the only new contracts, and they only expand; the committee's dedicated operator Safe is their trusted caller; each factory builds a permission tree from a template fixed at audit time, so a motion carries parameters, never a tree; every removal is the emergency Safe's immediate revoke.
tags: [governance, easy-track, factories, templates]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T13:05:14Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on factories, trusted caller, disclosure and templates, 2026-09-22, on the operator Safe, 2026-10-02, and on removals, 2026-10-05
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Easy Track settings, global duration, hash check, script format
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — governance, the toggle factory and the template factories
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

- Easy Track has one global objection period of 72 hours and an objection threshold of 0.5 percent of LDO [s2].
- A motion takes its duration from that global setting when it is created. No factory can shorten it [s2]. The setting itself can never be below 48 hours [s8].
- At enactment, Easy Track calls the factory again and requires the rebuilt script to match the stored hash [s2].
- A permission write replaces the stored tree for a role, target and selector [s3]. If a motion could submit a tree, every motion would need an on-chain proof that the new tree is narrower.

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

## Proposed direction

The rest of this section is agent-drafted from the design [s3]. EM has not accepted it as text.

- Each factory owns one template. A motion carries typed parameters only, such as a target, an asset and a budget key. The factory builds the tree.
- Every factory's trusted caller is the operator Safe. Easy Track fixes the trusted caller at deployment [s7].
- Every factory hard-codes the `operator` role key and refuses the Asset Safe and its modules as a target.
- The kit's role-toggle factory [s4] left the design (decision 8) and the kit on 2026-10-05. The budget factory and the template factories are not built.
- The modifier constrains the governance role again, so a factory bug cannot reach administration. The governance role cannot change membership, cannot touch the emergency role, cannot grant the operator the Asset Safe or one of its modules as a target (decision 10), cannot set an allowance outside the operator's budget keys, and cannot set a refill period below 30 days [s6]. A factory bug can still grant the operator a call on an ordinary target, such as a token transfer; the template and the objection window are the controls for that.
- A queued onboarding motion stops by an objection, by the Easy Track pause, or by the operator Safe cancelling its own motion. Once it is enacted, the emergency Safe can revoke the new permission at once.
- Every removal is an emergency action. The emergency role holds `revokeTarget` and `revokeFunction`, pinned to the `operator` key, and acts at once. Every operator permission lives under that key, so the revoke reaches all of them.

## Options considered

- The DAO pre-scopes one role key per strategy by vote, and motions toggle them. Not chosen by EM: every new protocol would need a vote.
- Motions submit condition trees. Not chosen: the narrowing proof is a tree comparison that no one should solve under an objection window.
- A bespoke controller contract for the allowlist, stale motions and ceilings. Removed: Easy Track's rebuild at enactment covers stale motions, and the modifier expresses the ceilings natively.
- Easy Track authority over the Agent. Not chosen: every motion could then run any script as the Agent.
- Removal templates through Easy Track, with the emergency revoke for urgent cases. Not chosen by EM: a removal only narrows, so a 72-hour window protects nothing.
- A shorter global window, or a second Easy Track for removals. Not possible: Easy Track refuses any window below 48 hours [s8].
- DAO-scoped role keys, with an unassign-only power for the emergency role. Not chosen by EM: it adds an emergency permission on an administrative function, for a model that EM had already rejected.

## Consequences

- The audit question becomes "can this template ever emit something unsafe". Each template must pin every receiver, owner and beneficiary field, bound every value-moving amount, never emit an administrative selector, and produce a script in the production format.
- A motion can point the operator at a contract that no one has audited. The template bounds how the vault interacts with it, so the loss ceiling is the attached budget. The controls are the objection window, the disclosure and monitoring. The LIP must say so plainly.
- Replacing the operator Safe means redeploying every factory with the new trusted caller and registering each one again by DAO vote [s7].
- The committee proposes its own expansions. The objection window, the disclosure rule and the Emergency Brakes pause are the counterweights.
- Routine removals happen at two of seven, without screening and without notice in advance. The forum post follows the removal. Monitoring pages a revoke-only emergency action at a lower severity than a transfer or a swap.
- A removed strategy comes back only through an onboarding motion or a DAO vote.
- The kit's toggle factory and its tests [s4][s5] are removed from the kit. INV-007 retires.

## Confirmation

- INV-004, INV-005, INV-006 and INV-018 in the [invariants](/specs/invariants.md).
- Kit tests for the governance-role guards [s6]. The factory-path tests ran on the retired toggle factory, so the template factories need their own.
- For decision 10, a fork test replays the probe that found the gap and shows each step refused, and another refuses every module that the Asset Safe enables on chain. The compiler's own tests refuse a policy without the guard and a manifest that misses a module.
- Each template factory, when built, needs its own tests for the four audit properties above.

## Reversal conditions

- A template that can emit an unsafe permission.
- A motion that enacts against the disclosure rule without an objection.

## Open questions

None open. OD-38 was decided on 2026-10-06.
