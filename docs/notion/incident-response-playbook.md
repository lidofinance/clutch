---
type: Research Note
title: "Treasury Management Vault: Incident Response Playbook (Draft)"
description: 'A copy of the Notion page "Treasury Management Vault: Incident Response Playbook (Draft)", last edited there on 2026-11-17.'
tags: [notion, security, incident-response]
status: draft
review_status: slop
valid_as_of: 2026-11-17
generated:
  by: claude-code/opus-5.5
  at: 2026-11-17T13:00:00Z
verified: []
sources:
  - id: s1
    resource: "https://app.notion.com/p/401bf633d0c9815981c0c671f42d36a9"
    title: The Notion page, last edited on 2026-11-17
---

# Treasury Management Vault: Incident Response Playbook (Draft)

> Source: https://app.notion.com/p/401bf633d0c9815981c0c671f42d36a9 [s1]
> Last edited in Notion: 2026-11-17

**Version:** 0.2
**Status:** Draft for EM and SecOps review
**Scope:** Suspected exploits, signer compromise, harmful orders, depegs, permission breaches and failures affecting safe vault operation.

This playbook supplements the existing [Incident Response Policy](https://app.notion.com/p/26c9c9a59f15494997e39827da9b2192). It uses the assumptions in the [Treasury Management Vault: Threat Model (Draft)](threat-model.md). Procedures and permissions require validation before operational use.

## 1. Detect and escalate

Anyone identifying a suspected incident should immediately notify SecOps [through the established incident process](https://app.notion.com/p/26c9c9a59f15494997e39827da9b2192?pvs=25) and alert the TMC and emergency signers.

## 2. Assess and contain

The Incident Lead coordinates assessment; authorized signers execute the approved defensive actions.

| Incident | Initial response |
| --- | --- |
| Contract exploit or permission breach | Stop affected execution, revoke relevant permissions and assess safe withdrawal paths. |
| Signer or interface compromise | Suspend use of the affected signing path, involve SecOps and initiate authorized revocation or rotation. |
| Harmful or unexpected CoW order | Identify outstanding orders. Cancel each one with `unsignOrder` on the order signer and `remove` on ComposableCoW. Where needed, set the vault relayer's approval to zero. Verify that no settlement remains possible. |
| Depeg, protocol distress or redemption failure | Stop new affected allocations; assess liquidity and initiate an orderly or emergency exit where appropriate. |
| Monitoring or screening outage | Verify exposure independently and apply the agreed outage policy. Escalate if safe execution cannot be established. |

**Emergency boundaries:** The 3-of-5 emergency Safe can revoke the operator's permissions, disable the operator modifier, zero approvals, exit positions, cancel orders, place recovery orders that buy USDC or USDT and pay the Aragon Agent, and return assets to the Agent. It can raise the universal factory's counter, so that no open motion enacts. It cannot add a permission, enter a protocol except by staking ETH, or restore what it stopped ([ADR 005](/adr/005-account-graph-and-roles.md)). The Emergency Brakes multisig can pause Easy Track. It cannot unpause it.

Initiate required defensive actions within the six-hour target, escalating immediately if blocked. Record submission, confirmation and outstanding settlement separately. Queued redemptions may take longer.

## 3. Verify containment and preserve evidence

- Verify the operator’s effective permissions and the status of outstanding orders, approvals and redemption requests.
- Reconcile affected balances across the Asset Safe, orders account and first-loss Safe.
- Preserve transaction data, configuration, alerts and the decision timeline.
- Coordinate suspected theft and recovery with SecOps and Legal under the existing escalation process.

Legacy first-loss burns follow their approved terms and Easy Track objection process. Emergency authority does not bypass those requirements.

## 4. Communicate and recover

Use the incident channels and communication roles established by SecOps. Publish the mandate-required forum report within **72 hours**, coordinating sensitive disclosures with SecOps and Legal.

The report should cover the incident, exposure, actions taken, known losses, pending withdrawals and next steps. Distinguish market movements, investment losses and first-loss utilization.

Recovery requires a documented cause assessment, reviewed remediation, reconciled balances and tested permissions. **A restart motion restarts the operator after a stop.** The universal factory's `restart` role enables the operator modifier after the 72-hour objection window, and restore motions bring back what the emergency role revoked. An Easy Track unpause needs an Aragon vote ([ADR 013](/adr/013-one-easy-track-factory.md) decision 12). A forum update alone does not authorize restart.

## 5. Readiness and follow-up

Before launch, confirm responder coverage and rehearse operator shutdown, order cancellation, permission revocation, redemption and DAO return, including unavailable signers and failed primary tooling.

The [runbook backlog](/runbooks/index.md) lists one runbook per emergency or technical action, with its permission. No runbook is written or drilled yet.

After an incident, complete the SecOps post-mortem process, assign remediation owners and update this playbook and the Threat Model.

**Assumptions:** DAO ownership; restricted TMC permissions; CoW-only launch trading; separately recorded legacy first-loss holdings; validated emergency paths; and the launch cap retained until screening and expansion conditions are met.

## 6. Incident response responsibilities

### 6.1 Response team

Material vault incidents require coordinated participation from **SecOps, Engineering and Finance/Ops**, under one Incident Lead.

| Role | Proposed owner | Responsibilities |
| --- | --- | --- |
| **Incident Lead / Security Lead** | **The security lead**, or a designated SecOps responder | Confirms severity, coordinates response, assigns tasks, manages evidence preservation and escalation, and ensures explicit handovers. |
| **Engineering Lead** | **YT** | Leads technical investigation; assesses contracts, permissions, orders and integrations; prepares containment transactions and arranges independent verification; confirms containment and remediation. |
| **Engineering escalation** | **The engineering escalation lead** | Resolves technical uncertainty, mobilizes engineering resources, and reviews material changes to permissions, execution paths and recovery plans. |
| **Finance / Treasury Lead** | **The treasury lead** | Assesses exposure, liquidity, valuation and potential losses; evaluates defensive actions’ economic consequences; confirms mandate constraints; owns financial reconciliation and treasury reporting; supports **the execution coordinator** or **the deputy coordinator** with execution/operations coordination. |
| **Execution Coordinator** | **The execution coordinator** | Mobilizes authorized signers, coordinates transaction preparation and review, tracks quorum and execution status, and follows outstanding orders, withdrawals and redemptions through to reconciliation. |
| **Deputy Execution Coordinator** | **The deputy coordinator** | Takes over when **the execution coordinator** is unavailable or hands over; supports signer coordination and execution tracking during incidents. |
| **Communications Lead** | **Nominated by the treasury lead** | Coordinates TMC and DAO updates, with technical facts verified by Engineering and sensitive disclosures reviewed by SecOps and Legal. |
| **Scribe** | **Assigned by the Incident Lead** | Maintains the incident timeline, decisions, approvals, transaction references, financial estimates and outstanding actions. Where practical, remains separate from active technical and execution roles. |

Assignments require confirmation by the named personnel. **The treasury lead** nominates Finance/Treasury cover; **YT** and **the engineering escalation lead** confirm Engineering cover; **the security lead** confirms SecOps cover.

### 6.2 Activation and availability

The detector follows the existing SecOps escalation process and obtains explicit acknowledgement from a responder.

For material vault incidents, the Incident Lead involves **YT**, **the treasury lead** and **the execution coordinator**, or their confirmed deputies, through the approved incident channel. **The deputy coordinator** takes over execution coordination if **the execution coordinator** does not acknowledge within the agreed escalation window or explicitly hands over.

Before operational use, confirm and test:

- **The execution coordinator**’s and **the deputy coordinator**’s access to the applicable paging system (currently OpsGenie).
- **The treasury lead**’s OpsGenie installation and tested emergency notifications; primary on-call rotation membership is not required for reachability. **An onboarding contact** checks onboarding with **the treasury lead** and coordinates with SecOps if needed.
- Coverage expectations, acknowledgement deadlines and deputy escalation.
- Direct paging and availability of Emergency Committee signers.
- Fallback contact routes if primary communications fail.

P1 participation and information sharing follow the parent SecOps policy. The vault-specific inclusion of Finance/Ops must be agreed with SecOps.

### 6.3 Assessment, containment and execution

Engineering and Finance assess the incident concurrently:

- **YT:** identifies the technical failure, what remains executable, and safe containment options.
- **The treasury lead:** identifies treasury exposure, liquidity needs, mandate constraints and the economic consequences of available actions.
- **The execution coordinator**, or **the deputy coordinator** as deputy: establishes signer availability and coordinates preparation, review, submission and confirmation.

The Incident Lead coordinates the response. **Only authorized signers execute actions under existing permissions and signing thresholds.** Coordination roles do not confer additional authority.

Emergency Committee activation should occur in parallel where warranted rather than wait for **the execution coordinator**, **the deputy coordinator** or **the treasury lead** to respond. Pre-authorized containment must not be delayed by a wider committee meeting; unavailable personnel trigger fallback escalation, not expanded permissions.

The six-hour target concerns **initiating defensive actions**, not guaranteeing completed settlement or redemption.

### 6.4 Reconciliation, reporting and recovery

- **YT:** verifies containment, outstanding permissions/orders and technical remediation.
- **The treasury lead:** owns reconciliation of balances, pending redemptions, exposure and losses, and confirms financial impact for incident closure.
- **The execution coordinator / the deputy coordinator:** track submitted, confirmed, failed and outstanding execution steps.
- **Communications Lead:** coordinates the draft’s required forum report within 72 hours.
- **Incident Lead:** coordinates the post-mortem and assigns remediation owners and deadlines.

Recovery requires documented technical and financial readiness assessments. Neither authorizes restart; a restart motion does.

### 6.5 Emergency committees

- **Technical/security emergencies:** SecOps and Engineering coordinate the response, involving existing emergency committees only within their approved mandates and deployed permissions. Contract upgrades follow the applicable DAO approval process.
- **Financial/vault emergencies:** A separate 3-of-5 emergency Safe acts. The committee appoints two signers, the Emergency Brakes multisig appoints two, and a DAO Snapshot appoints a fifth signer who is a member of neither ([ADR 005](/adr/005-account-graph-and-roles.md) decision 24). Its deployment and membership remain to be confirmed.

**YT** will confirm the responsible bodies and escalation paths before operational use.

### 6.6 Monitoring and automated alerting

Planned coverage: **internal monitoring** for technical events, including signer and state changes; **the screening vendor** for financial parameters, including token-price spikes and peg issues. High/Critical incidents are to page relevant responders through OpsGenie. **YT** will agree the precise monitoring responsibilities and paging setup with the screening vendor; implementation and testing remain to be confirmed.

### 6.7 Vendor emergency contacts

**YT** will confirm and record the emergency contact, channel and escalation route for:

- **The screening vendor:** an integration exists; confirm the applicable emergency contact and paging path.
- **Zodiac:** discuss requirements; whether direct paging or incident integration is needed remains open.
