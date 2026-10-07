---
type: Research Note
title: The request for solution against the decided design, 2026-10-07
description: What the request for solution that Lido contributors sent to the policy provider asked, part by part, paraphrased; the onboarding guide's RFP tab maps each ask to the decided design.
tags: [rfp, policy-provider, requirements, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-07
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-07T08:02:59Z
verified: []
sources:
  - id: s1
    resource: "urn:clutch:restricted:request-for-solution"
    title: "Request for solution \"Active Treasury Management\", sent to the policy provider; the copy that EM supplied on 2026-10-07; outside the repository"
  - id: s2
    resource: /registers/decision-log.md
    title: Decision log — EM's request for an analysis of the RFP in the onboarding guide, 2026-10-07
  - id: s3
    resource: /onboarding/guide.md
    title: Onboarding guide — the RFP tab, which maps each ask to the decided design
---

# The request for solution against the decided design, 2026-10-07

## Answer

- Lido contributors sent the policy provider a request for solution (RFP) [s1][s2]. It describes the accounts and how Easy Track changes the operator's permissions. It then sets requirements for assets and permissions, ownership and governance, emergency response, monitoring and transaction blocking, net asset value, and independence from the provider.
- It asks the provider what works today, what needs work and what is not compatible. It asks a different architecture to show how it keeps four properties: DAO ownership, default-deny permissions, rapid risk reduction and walk-away operation [s1].
- The onboarding guide's RFP tab maps each ask below to the decided design, and gives the reason for each difference [s3].

## The source

- EM named the RFP on 2026-10-07 as the one shared with the policy provider, and supplied the copy that this note reads [s2]. The RFP itself stays outside the repository [s1].
- This note paraphrases the RFP and does not repeat its target allocation figures. EM decided on 2026-10-07 that they are not restricted (OD-53): they are targets, not decided values, and the README marks every figure in the repository as a draft [s2].
- The guide's build fails when its RFP tab shows an ask that the next section does not hold word for word.

## What the RFP asked

Each item paraphrases one ask of the RFP [s1].

### Accounts

- An Asset Safe holds the assets and the positions. The Aragon Agent is its only owner, and the DAO cannot lose that ownership because a provider service is unavailable.
- An Operator Safe at 4 of 7 makes routine transactions through a restricted role. It cannot change its own permissions, block their removal, borrow, or use an asset or a function that a motion or the DAO did not approve.
- An Emergency Safe at 3 of 5, which the RFP links to the Emergency Brakes multisig, revokes approvals, exits approved positions and returns assets to the fixed DAO treasury address.
- Neither Safe can block the removal of its own authority, and the Operator Safe cannot block a DAO recovery action.

### Governance and Easy Track

- Easy Track manages the operator allowlist: it adds or removes an asset, a protocol target or a function selector, and changes a parameter constraint inside an allowed function.
- Lido contributors design, build, audit, deploy and maintain the Easy Track helper contracts. The provider confirms that its access control exposes the administration functions and works safely with this path.
- The Aragon Agent stays the only owner of the Asset Safe. Easy Track gets no ownership and no unrestricted execution, and it executes only the permission changes that the Operator Safe proposes in motions.
- A direct DAO path can make every change that Easy Track can make.
- The complete initial configuration is in place before ownership passes to the DAO, so no separate setup-only vote is needed.

### Permission-change paths

- Adding or widening a permission and removing one are separate actions. A removal cannot add or widen, and an expansion cannot make an arbitrary call.
- An expansion waits through a three-day objection period.
- A standard removal goes through an Easy Track removal motion, with the same three-day objection period.
- For an urgent risk, the emergency authority blocks or revokes within hours, and a durable change follows later.

### Assets and permissions

- A launch set of stETH, wstETH, LDO, USDC, USDT, DAI, sDAI, USDS, sUSDS, earnUSD and earnETH, with a note of the assets or actions that need custom policy work.
- Unapproved actions are denied by default. On-chain rules restrict the target contracts, the functions, the transferred value and the relevant parameters.
- Allocation limits per protocol, per yield-asset class and per liquid staking provider other than Lido, where this is technically possible.
- The answer explains which limits hold before execution and which depend on reporting and remediation.
- The Operator Safe cannot add a target, a function, an asset or a wider parameter range without the governance process.
- The permission detail separates protocol targets, function selectors, asset parameters and other policy parameters.

### Emergency response

- Liquid positions can be recovered within about six hours.
- The emergency role revokes token approvals and exits approved positions.
- Recovered assets go only to the fixed DAO treasury address.
- The Operator Safe cannot veto an emergency action.
- The emergency role cannot add permissions, enter a new protocol, borrow, create leverage or change the recovery destination.
- In an incident, new operator transactions stop first. The emergency signers check the event, revoke approvals, exit positions or start queued withdrawals, and return what is liquid to the treasury. The DAO disables a role or a module if needed, and an incident report follows.

### Monitoring and transaction blocking

- Monitoring covers transactions, assets, protocols and permission changes.
- Alerts reach the operator, the emergency signers and DAO operations, with the supported signals and the expected alert times.
- Each operator transaction is simulated and checked before execution, and the answer names the service that checks it.
- The answer explains what happens when the monitoring or blocking service is unavailable. On-chain permissions stay the final enforcement layer, and losing monitoring never widens them.

### Net asset value

- The NAV shows the total in USD, the valuation time and the freshness of the data, by asset, protocol, strategy and position. The answer says whether NAV is the provider's product, a partner's or custom work.
- The launch design permits no debt, but the NAV still detects and shows any unexpected liability.

### Provider independence

- The on-chain system keeps working without the provider's hosted app, API, extension, indexer, relayer or cloud service.
- An authorized account can send a valid transaction through another Safe-compatible frontend, or as raw transaction data.
- Permission removal, module disablement, emergency recovery and DAO ownership actions stay available through an outage, a suspension, a billing dispute or a contract termination.

### What to send back

- The answer says what works today, what needs work, and what is not compatible. A different architecture shows how it keeps DAO ownership, default-deny permissions, rapid risk reduction and walk-away operation.
