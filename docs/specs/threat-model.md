---
type: Specification
title: Threat model
description: The vault's failure modes, each with its trigger, its mitigation and its detection.
tags: [specs, security, threat-model]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-11T04:57:34Z
verified: []
sources:
  - id: s1
    resource: /adr/index.md
    title: Decision records — the decisions that each mitigation rests on
  - id: s2
    resource: /research/operator-safe-review-2026-10-15.md
    title: The committee's Safe as the operator, reviewed again on 2026-10-15 — its other duties under the guard
---

# Threat model

Each row names a failure, what triggers it, what limits it and what detects it. The ADRs hold the decisions that the mitigations rest on [s1]. The [invariants](/specs/invariants.md) hold the properties that the tests check, and the [control matrix](/specs/control-matrix.md) holds the mandate's rules with their controls.

## Failure modes

| Failure | Trigger | Mitigation | Detection |
| --- | --- | --- | --- |
| Modifier bricked at deployment | Roles proxy deployed through a Safe proxy rather than a minimal proxy | Mandatory use of the Zodiac ModuleProxyFactory; deployment rehearsal on a fork | Deployment self-test before any funding |
| Role key mismatch | Deployment tooling and the factory derive role keys differently | Pin the derivation and assert it at deployment | Deployment self-test |
| Operator key compromise | Signer compromise | Default deny; no transfer except into the orders account or, pinned, to the Aragon Agent; receivers pinned to the avatar; budgets; approvals bounded by each spender's budget | Policy-drift and approval monitoring; budget burn-rate alerts; an alert on every transfer to the Agent |
| Emergency key compromise | Signer compromise | Emergency cannot add permissions, enter protocols beyond staking ETH, or change the recovery destination. It can choose a bad limit for a recovery order: nothing on chain bounds the price, and CoW's EBBO rule bounds it in practice (OD-48). It can raise the factory's counter, which makes every open motion fail but moves no funds | Any emergency action pages the DAO; a revoke-only action pages at a lower severity than a transfer or a swap; an alert on a recovery limit far below a market price; an alert on a raise of the counter |
| Defect in Safe or Roles code | A bug in the Safe v1.5.0 singleton or in the Roles mastercopy | The vault's main Safe paths are ones that Certora formally verified, and the Asset Safe uses no fallback handler and no contract signature, while the orders account, which does, holds only tokens in transit; Safe's releases and advisories are checked again before the enabling vote; the emergency role's switch can disable the operator modifier; the DAO can replace the policy or move the assets by vote | Safe's advisories and releases; the engineering organisation's watch on technical risk, including bug-bounty submissions; alerts on singleton, module and owner changes |
| Falsified signing interface | A signer's device or wallet interface shows one transaction and has another signed, as at Bybit in 2025 | Once the guard is set, each transaction of the committee's Safe needs the vendor's approval (OD-83); the vendor is asked to refuse delegatecalls except to MultiSendCallOnly; the operator's permissions bound what a signing quorum can do; the emergency role's powers only reduce exposure, though a recovery order has no price floor (OD-48) | Alerts on owner, guard, module and singleton changes of the new Safes |
| Queued motion restores a revoked permission | An expansion motion enacts after an incident | The emergency Safe raises the factory's counter, so every queued Clutch motion fails at enactment (OD-102); the Easy Track pause, held by the Emergency Brakes multisig, freezes every motion; the committee's Safe can cancel its own motion; after enactment, the emergency Safe revokes the permission again at once | Motion monitoring, with an alert on a failed enactment; the incident runbook pages the emergency Safe and, for a pause, the Emergency Brakes multisig |
| Stale motion overwrites a newer change | Two motions write one scope, in either order | The versions: the motion that enacts second fails at enactment, and its creator or Aragon Voting cancels it (OD-100, OD-102) | Alert on a failed enactment; a warning when few Easy Track motion slots are free (OD-94) |
| Operator modifier disabled while positions are open | The emergency Safe switches the operator off during a defect | The safety modifier keeps working, so the emergency role can still exit and return assets | Module-enabled monitoring on the Safe, alert on any change |
| Emergency Safe unreachable during a permission-layer defect | Signer availability: every quorum needs signers from two bodies | The DAO path can replace the policy outright; the Easy Track pause still freezes every motion | Escalation clock in the runbook; the timed drill |
| Captured committee restarts the operator | A restart motion after a stop | The 72-hour objection window; the counter fails the motion after any new stop; the emergency Safe can stop the operator again (OD-104) | Alert on every restart motion |
| Onboarding motion points at a malicious contract | A motion survives its objection window | The shape pins receivers and bounds amounts, so loss is capped by the attached budget rather than the balance | Published diligence per motion; position and budget monitoring |
| A shape emits more than it should | A flaw in a shape of the universal factory | The shapes' tests and the external audit; the objection window; the Easy Track pause; the counter; the emergency Safe's revoke; a vote replaces the factory | Every motion decoded from `MotionCreated`; drift detection on the policies |
| An exit shape grants more than an exit | A flaw in an onboarding shape's exit part | The shape's tests and audit; the objection window; the Easy Track pause; a DAO vote replaces the safety policy | Drift detection on the safety policy |
| The factory's checks prove too complex | The audit cannot establish that a shape never emits an unsafe permission | Fallback to raw writes that may also widen, with the objection window as the only bound on where funds go ([ADR 013](/adr/013-one-easy-track-factory.md) decision 11) | The audit's report |
| A motion exceeds a chain limit | The factory or its companion exceeds EIP-170's 24,576 bytes, or a motion needs more gas than EIP-7825's cap of 16,777,216 | A shape in a thin companion contract (OD-117); a motion's script of one call (OD-118); at most 16 operations in one motion | The fork tests' size and gas measures before each change of the factory |
| Signer sets drift apart | A seat holder leaves the committee or the Emergency Brakes multisig and keeps the emergency seat | Operational reconciliation duty and the seat rule; no on-chain enforcement | Owner-set monitoring on the Safes; an alert on every change of the owners or the threshold of the committee's Safe (OD-109) |
| Budget drains too fast | A motion sets a very short refill period | `GreaterThan` floor of 30 days on `period` | Budget monitoring |
| Budget reset by repeated motions | Budget motions, each of which resets a balance | The ceiling of each key; the versions, so two open motions on one key cannot both enact; the event rule; the objection window | Every budget motion, whose forum post must name its event |
| Ceiling raised with its budget | A captured committee raises a ceiling to make room for a larger budget | A raise of at most twice the ceiling, at most once in 15 days for that ceiling (OD-105); the objection window | Alert on every ceiling motion |
| Tranche above the headroom | A tranche vote would take the funded value above the mandate size, or the vault above the treasury share | Each tranche is an Aragon vote of about five days; its forum post states the funded value, the headroom and the treasury share; the second tranche waits for the screening guard; the emergency Safe or the committee's Safe can return funds to the Agent | An alert on a tranche vote whose execution would take the vault above the size or the share, while the vote is open; the fortnightly readings |
| Funds returned to the Agent without need | A compromised or mistaken committee sends vault tokens to the Agent | Only the Agent can receive them, so the vault loses liveness, not funds; a tranche vote funds it again (OD-108) | Alert on every transfer to the Agent |
| Spender pulls without a deposit | A protocol spender is upgraded to steal, or an approval stands too long | Each approval spends its key's budget, so approvals per period cannot exceed it; approvals in the same transaction as the deposit; the emergency role zeroes approvals and can revoke the approve permission | Approval inventory and budget burn monitoring |
| Exit impossible when it matters | Protocol illiquidity or asynchronous settlement | Receipt-token transfer to the Agent; claim later. A position that a motion onboarded gets its emergency exit from that motion (OD-49) | Position inventory monitoring |
| First-loss shares or insurance funds misused | A burn, a payout or a redemption without an instruction | A burn or a payout needs an enacted motion, so LDO holders can block it for 72 hours (OD-67, OD-107); a payout goes only to the address that the creating motion pinned, within the fund's cap; the first-loss role of the committee's Safe can only redeem to the Asset Safe, and it cannot transfer, approve or burn (OD-60, OD-108); before the guard is set, the committee returns any excess above the launch cap to the Aragon Agent; the Earn team's written instruction and the forum post come first | Alert on every action of the first-loss role, on every motion on the first-loss modifier, on a redemption request before the guard is set, and on any change of the first-loss Safe's balance, owners, modules or singleton |
| An order fills far below the market | An order with a poor limit, or a solver that fills at the limit while the market is better | The order's own limit; CoW's solver competition; screening of operator orders once the guard is set; the orders budgets | Alert on each fill below a market price, and on open orders and tokens left in the orders account |
| CoW's watch-tower stops | Conditional orders are not posted to the order book | The orders wait and no funds move; the committee can cancel them and place ordinary orders | Alert when a conditional order's part is not posted on time |
| Screening vendor outage | The vendor's key stops approving | Fail closed: operator activity, new motions and the committee's other duties stop; recovery is unaffected, and the Emergency Brakes multisig keeps its pause of the LDO buyback executor; the owners can remove the guard after ten days (OD-83) [s2] | Approval-latency and vendor-heartbeat monitoring |
| Cap breach gets worse | The committee does not rebalance within its window | The emergency Safe disables the operator modifier on the fixed trigger; the safety modifier keeps working, so recovery stays available | Lido's and the policy provider's fortnightly cap readings on IPFS; the alert pages the emergency Safe when the trigger is met in either |
| Monitoring unavailable | Service outage | On-chain permissions are the enforcement layer and do not widen when monitoring stops | Heartbeat on the monitor itself |
