---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T23:13:05Z
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
| OD-145 | How does the launch cap of one million dollars hold before the screening guard is set? The top-up factories exist from the enabling vote (OD-142), and a registry's limit for a period is far above the cap (OD-143). (A) By a rule: the committee's Safe creates no top-up motion that takes the vault above the cap, monitoring alerts on one, and LDO holders object within 72 hours. (B) On chain: the registries start with limits that sum to the cap, and one Aragon vote after the guard is set raises them to the limits of OD-143. | [ADR 010](/adr/010-pre-execution-screening.md) | B. ADR 010 decision 20 makes on-chain blocking a hard requirement above the cap, and under A only an objection of LDO holders stops a top-up above it. B keeps the cap on chain for one vote, once; it is the vote that the earlier design already had after the guard. A stands until EM decides | EM |
