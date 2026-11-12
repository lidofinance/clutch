---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T19:10:44Z
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
| OD-139 | Which form does the emergency role's zeroing of an approval take in the launch policy? Today the policy lists the operator's spenders for each approved token. The exit-governance role writes a zeroing only for any spender (INV-025). So a new spender that enters through the policy's source changes the emergency role's tree of every approved token, no motion can write those trees, and the change needs a DAO vote. (A) The launch policy uses the form for any spender, for each approved token. The policy then has one form, and a new spender of an approved token needs no write for the emergency role. (B) The policy keeps the list. A motion that adds a spender then replaces the token's tree with the form for any spender, by hand in the motion, and the policy's source needs both forms. | [ADR 005](/adr/005-account-graph-and-roles.md) | A. A zeroing only takes authority away, whatever the spender, so the wider form gives the emergency role no new power over funds. It removes a vote after launch (OD-101), and the launch policy and the motions share one form. The cost is one changed tree for each of five tokens in the enabling vote's policy | EM |
