---
type: Research Note
title: "Treasury Management Vault: Threat Model (Draft)"
description: 'A copy of the Notion page "Treasury Management Vault: Threat Model (Draft)", last edited there on 2026-11-12.'
tags: [notion, security, incident-response]
status: draft
review_status: slop
valid_as_of: 2026-11-12
generated:
  by: claude-code/opus-5.5
  at: 2026-11-17T12:00:00Z
verified: []
sources:
  - id: s1
    resource: "https://app.notion.com/p/401bf633d0c981df9101ef4909acf673"
    title: The Notion page, last edited on 2026-11-12
---

# Treasury Management Vault: Threat Model (Draft)

> Source: https://app.notion.com/p/401bf633d0c981df9101ef4909acf673 [s1]
> Last edited in Notion: 2026-11-12

**Version:** 0.2 — proposed
**Status:** Draft for Engineering, Finance and SecOps review
**Scope:** Funding, trading, integrations, legacy first-loss commitments, emergency response and recovery.

## 1. Working design and trust boundaries

The working design assumes DAO-owned Safes, restricted TMC permissions, CoW-only launch trading and a separate 3-of-5 emergency Safe. Emergency authority is limited to defensive actions.

The main trust boundaries are:

| Boundary | Required validation | Owner |
| --- | --- | --- |
| DAO governance → permissions and funding | Who can change limits, modules, destinations and administrative authority? | **YT**, reviewed by **EM** |
| Routine operators → Asset Safe and orders account | What can operators transfer, approve or sign—including economically harmful but technically permitted actions? | **YT**, economic review by **the treasury lead** |
| Emergency signers → containment and exits | What can emergency authority do, and could those powers themselves be abused? | **YT + the security lead** |
| Vault → underlying protocols and providers | Which external administrators, liquidity sources and services can affect assets or execution? | **YT + the treasury lead** |
| Monitoring → responders and signers | Who receives, acknowledges and acts on alerts? What happens when they are unavailable? | **The security lead; the execution coordinator, with the deputy coordinator as deputy** |

Before funding, attach the actual address/permission map, component versions, upgrade authorities and approved asset/strategy list. These design assumptions are not evidence of implementation.

## 2. Security objectives

The vault should:

- Prevent unauthorized transfers and privilege escalation.
- Limit economic damage possible **within** approved permissions.
- Preserve usable emergency access without creating unrestricted emergency authority.
- Maintain accurate exposure, valuation, liquidity and funding records.
- Make material actions attributable, independently checked and recoverable where possible.

A valid transaction is not necessarily economically safe.

## 3. Likelihood and impact

### Rating method

**Likelihood:** Low = unlikely under the assessed operating conditions; Medium = credible; High = expected or readily repeatable.

**Impact:** Low = limited disruption without material loss; Medium = significant operational disruption or bounded loss; High = material loss, inaccessible assets, loss of control or prolonged inability to contain exposure.

| Likelihood ↓ / Impact → | Low | Medium | High |
| --- | --- | --- | --- |
| **Low** | Low | Low | Medium |
| **Medium** | Low | Medium | High |
| **High** | Medium | High | High |

**Initial ratings below use Medium likelihood as an explicit planning baseline because implementation and operating evidence have not yet been assessed.** They are not measured probabilities. Impact assumes the scenario succeeds; residual risk must be assessed separately after controls are tested.

### Threat register

| Threat / scenario | Likelihood | Impact | Priority | Required controls and evidence | Owner |
| --- | --- | --- | --- | --- | --- |
| **Contract or permission failure:** compromised operators bypass restrictions or exploit permitted actions. | Medium | High | High | Reviewed permissions and upgrade paths; positive/negative tests; quantify maximum damage without privilege escalation. | **YT; EM review** |
| **Signer or interface compromise:** misleading transaction data or stolen signing access causes harmful execution. | Medium | High | High | Hardware signing, independent transaction verification, signer-dependency review and tested rotation. | **The security lead + YT** |
| **Unsafe or outstanding CoW orders:** adverse terms or settlement continues after a stop. | Medium | High | High | Economic limits; partial-fill and cancellation tests; document precisely what remains executable after each containment action. | **YT + the treasury lead** |
| **Underlying protocol or asset failure:** exploit, depeg, freeze or queued redemption traps funds. | Medium | High | High | Shared-exposure analysis, realistic exit routes and stressed-liquidity assessment; distinguish immediately recoverable from still-exposed assets. | **The treasury lead + YT** |
| **Accounting or funding failure:** stale valuation, double counting or omitted commitments conceals limit breaches. | Medium | High | High | Reconcile Safes, orders and pending redemptions; define valuation sources and cap perimeter; restrict funding when required data is unreliable. | **The treasury lead** |
| **Emergency failure or abuse:** unavailable quorum, ineffective revocation or misuse of defensive powers. | Medium | High | High | Test every emergency path and destination restriction; rehearse unavailable signers and compromised tooling; assess emergency-quorum compromise. | **YT + the security lead; the execution coordinator/the deputy coordinator coordinate** |
| **Governance or legacy first-loss error:** unauthorized expansion, invalid instructions or duplicate burns. | Medium | High | High | Mandate-to-permission mapping, authenticated instructions, independent payload review and applicable governance/objection periods. | **The treasury lead + YT** |
| **Monitoring or provider failure:** alerts are missed or common dependencies disable detection and response. | Medium | Medium\* | Medium\* | End-to-end paging tests, acknowledgement escalation, service-health checks and independently usable fallbacks. | **The security lead + YT; the execution coordinator/the deputy coordinator coordinate** |
| **Legal or recovery impediment:** unclear authority or asset restrictions delay recovery. | Medium | High | High | Confirm escalation authority, preserve evidence and obtain applicable Legal review. | **The treasury lead, with Legal and the security lead** |

\*Escalate impact to **High** where an outage prevents timely containment of exposed assets.

## 4. Exposure and assumptions

- **Funding cap:** The proposed US\$1m perimeter covers the Asset Safe and orders account. Document treatment of pending settlements and redemptions. Separately held legacy first-loss assets mean this is **not necessarily total treasury exposure**.
- **Liquidity:** The existing treasury-wide runway floor remains the working assumption; eligibility of particular vault assets toward that floor requires confirmation by **the treasury lead**.
- **Shared dependencies:** Separate Safes or signers do not establish independence. **The security lead and YT** assess shared devices, interfaces, RPCs, preparation tooling and communications.
- **Response:** **The execution coordinator** coordinates execution; **the deputy coordinator** is deputy; **the treasury lead** owns treasury assessment. Paging access and coverage require testing.
- **Timing and authority:** The six-hour target concerns initiating defensive actions, not completed redemption. Existing signing thresholds and governance requirements remain applicable.

## 5. Evidence and acceptance

Track each control as **Proposed → Implemented → Tested**, with an owner and evidence link. Distinguish onchain enforcement, operational checks and monitoring.

Before funding:

- **YT / EM:** reviewed architecture, permissions and execution-path tests.
- **The treasury lead:** validated exposure, valuation, funding and liquidity rules.
- **The security lead:** security review and tested escalation.
- **The execution coordinator / the deputy coordinator:** emergency execution rehearsal and confirmed signer coverage.

Reassess likelihood, impact and residual risk using that evidence. Unresolved risks require an accountable owner, operating restriction and acceptance by the appropriately authorized body. Technical and financial readiness assessments do not independently authorize restart.

Update this model when permissions, integrations, funding limits, signer arrangements or emergency powers change.

**References:** [Appendix D: Threat & Failure-Mode Summary](https://app.notion.com/p/318bf633d0c980869408d8986f105394); [Incident Response Policy](https://app.notion.com/p/26c9c9a59f15494997e39827da9b2192).

**Companion document:** [Treasury Management Vault: Incident Response Playbook (Draft)](incident-response-playbook.md)
