---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-19T16:12:06Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's inputs

---

# Open decisions

The acceptor decides every item: EM until 2026-11-23, YT from that day, until the Treasury Management Committee takes over ([ADR 002](/adr/002-decision-and-review-process.md)) [s1]. An agent recommendation is a recommendation, not a decision. A closed item leaves this table: [closed-decisions.yaml](closed-decisions.yaml) records it, and the [decision log](decision-log.md) keeps the decider's words (OD-127).

| ID | Question | Closes in | Agent recommendation | Decides |
|---|---|---|---|---|
| OD-168 | What counts as the vault's volume for the guard's threshold, and who reads it? The mandate's text sets a threshold on the volume of a quarter and does not define it. A: the US-dollar value of the orders account's fills in a calendar quarter, read by the orders detector. B: every operator outflow of the Asset Safe in a calendar quarter: deposits, orders and transfers. C: the committee's definition in the mandate's numerical rules. | [ADR 010](/adr/010-pre-execution-screening.md) | A, unless the mandate's numerical rules define it. The fills are on chain, and the orders detector reads them already. Ask the committee whether the quarter is a calendar quarter or a rolling one | The acceptor |
