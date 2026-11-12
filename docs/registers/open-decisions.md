---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T14:54:04Z
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
| OD-136 | Who runs the check of a motion, and what follows a failure? The factory checks no write's content (OD-134), and `just motion-check` fails a motion that does not equal a merged policy change. Options: (A) monitoring runs the check on every motion of the factory at its creation, against the two commits that the forum post names, and a failure pages the emergency Safe, which raises the counter; (B) the check is advisory, and a reviewer runs it by hand in the 72 hours; (C) as A, and the screening vendor also refuses the creation of a motion that fails the check, once the guard is set. | [ADR 013](/adr/013-one-easy-track-factory.md) | A. A hand check can be skipped, and an unchecked motion is the widest risk of the raw factory. C adds the vendor to the trust base of every motion and needs the vendor's word on what it can check | EM |
