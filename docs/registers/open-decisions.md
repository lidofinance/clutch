---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T22:48:34Z
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
| OD-141 | Which tokens get a top-up factory? Each factory pays one registry's recipients, and a registry counts every token in 18 decimals, so stETH and stablecoins need two registries. (A) Two: one for stETH, and one for the DAO's stablecoin list as it is, which holds DAI, USDC, USDT and sUSDS. (B) stETH only; stablecoins come by tranche vote. (C) A, and USDS too, which needs a vote that adds USDS to the token list and rewrites the executor's payment permission. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A. The committee named stETH and stablecoins that earn nothing. The stablecoin list needs no change, so A adds two registries, two factories and no other part. USDS reaches the vault by a tranche vote, or as DAI through Sky's converter | EM |
| OD-142 | Which vote registers the top-up factories? Until the screening guard is set, the vault's funding stops at the launch cap of one million dollars (OD-54, OD-55), and the second tranche's vote starts only after the guard is set (OD-121). (A) The second funding vote registers them, after the guard is set. Before it, no top-up path exists, so the cap holds on chain. (B) The enabling vote registers them. A written rule keeps the committee from a top-up above the cap, monitoring alerts on one, and the objection is the control. | [ADR 010](/adr/010-pre-execution-screening.md) | A. The cap then holds by construction and not by a rule, and A costs no vote: the second funding vote exists in either case | EM |
| OD-143 | What are the period and the limit of each registry? A period is 1, 2, 3, 6 or 12 calendar months, and a period's end lets two full limits pass within about 72 hours. A limit counts token units, not dollars. (A) Three months, and a limit that the attested computation sets from what the committee expects to pull in one period, never above one mandate size. (B) One month, as OD-06 once set, with the same rule for the limit. (C) Twelve months, with one mandate size as the limit. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A. The committee expects a top-up about every three to four months, so a period of three months matches one top-up, and a limit near one top-up bounds what a captured committee can pull before a vote lowers it. The mandate size stays the ceiling on the vault's value (OD-89) | EM, with the figures from the attested computation |
| OD-144 | Which gates hold a top-up motion? The proposer starts no tranche vote while the monthly report is late, while the committee's estimate prices more than the set share, or while the two readings differ (OD-122). (A) The same gates hold a top-up motion: the committee's Safe creates none while a gate holds; the motion's forum post states the funded value, the headroom under the mandate size and the treasury share; monitoring alerts on a top-up motion that breaks a gate or the headroom, and on one after an objected one; LDO holders object. (B) A top-up motion has no gates of its own: the registry's limit and the objection are the controls. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | A. A top-up moves the same funds as a tranche with 72 hours in place of a vote, so it must not have weaker conditions | EM |
