---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-16T19:54:04Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's inputs

---

# Open decisions

EM decides every item until the Treasury Management Committee takes over as acceptor ([ADR 002](/adr/002-decision-and-review-process.md)) [s1]. An agent recommendation is a recommendation, not a decision. A closed item leaves this table: [closed-decisions.yaml](closed-decisions.yaml) records it, and the [decision log](decision-log.md) keeps EM's words (OD-127).

| ID | Question | Closes in | Agent recommendation | Decides |
|---|---|---|---|---|
| OD-65 | Who holds the emergency Safe's fifth seat? The fifth signer is a member of neither the committee nor the Emergency Brakes multisig (OD-58), and a DAO Snapshot appoints them. | [ADR 005](/adr/005-account-graph-and-roles.md) | EM said on 2026-10-13 "yup, tentatively tho" to a member of the Tech team. Accept that as a criterion, not a name: a Tech-team member on neither body, whose key and seed are generated apart from the Emergency Brakes members' setup, who signs a written statement of independence, keeps on-call duty and takes part in the timed drill. Review the seat at the first rotation, because the only quorum without the committee is then all from the engineering organisation | EM; a DAO Snapshot appoints the signer |
| OD-153 | Which key does the orders modifier's governance role take on mainnet? The stand's record says that the hosted Zodiac app keeps one policy for each role key in a workspace and chain, and that it refused the stand's roles while the operator modifier and the orders modifier both had a `governance` role with different grants. The stand renamed its orders role to `orders-governance` on 2026-11-16. `main` has `governance` on both modifiers. A: `orders-governance` on mainnet, as on the stand, in the same change that brings the four account keys of OD-152. B: keep `governance` on both modifiers, and publish only one of the two roles to the Lido workspace. C: `asset-governance` and `orders-governance`, so that each governance key names its account. | [ADR 005](/adr/005-account-graph-and-roles.md) | A. The stand ran this key through the hosted app and its tests, so mainnet takes a scheme that a public network has shown. B leaves a role that the app does not show, against ADR 004 decision 10. C renames a second role that no conflict needs, and INV-004 and the motion tooling name it. Confirm the hosted app's rule with the policy provider before the mainnet change. | EM |
