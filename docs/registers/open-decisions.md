---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:38:25Z
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
| OD-136 | May the stand owner make hosted calls to the Sepolia workspace and send public Sepolia transactions from `testnet/sepolia`? A: no; ADR 004 decision 16 stays, so pull request #44 merges first and the owner team pushes from `main`. B: yes, from a commit that is on GitHub with no local changes, through a Sepolia guard separate from the owner guard, with an API key for the Sepolia workspace in a git-ignored `.env`. C: a one-time exception for each publication, recorded in the decision log. | [ADR 015](/adr/015-tests-on-sepolia.md) | B. Reviewers can see the code that runs, the guard keeps CI and local changes out, and the production rule does not change. Before the first call, confirm whether the provider can limit a key to one workspace. | EM |
| OD-137 | How does the existing-state payload reach the Sepolia workspace? A: the SDK's `push`. B: a committed script behind the Sepolia guard: it checks the payload hash and a fresh RPC comparison, calls resolve, compares the resolved specification with the payload, calls apply once and saves each status and body. C: a manual API call. | [ADR 015](/adr/015-tests-on-sepolia.md) | B. The API refused the governance `Nor` conditions in the format that `push` sends (A). A manual call leaves no reviewable record (C). | EM |
| OD-140 | Which records may the stand owner make by hand in the Zodiac app? A: none. B: vault imports of the three existing Safes, the checked address-book entries, and removal of the earlier workspace's draft aliases and cancelled proposals; no role or permission edits in the app. C: any record, policy drafts included. | [ADR 015](/adr/015-tests-on-sepolia.md) | B. The SDK has no address-book endpoint, and a policy edit in the app is drift (ADR 004 decision 11). | EM |
