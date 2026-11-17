---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-17T20:53:17Z
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
| OD-157 | Does the operator's order signing get the price bound for like-for-like orders? The [research](/research/order-price-bound-2026-11-17.md) shows that a custom condition holds an order to par inside one class of tokens, dollar stablecoins or ETH and its Lido tokens, and that an order of two classes stays free. A: no; the order's limit, CoW's solver competition, screening, the orders budgets and the orders detector stay the controls. B: yes, as a guard against slips: after an audit, a motion writes the condition on the order signer's tree and on the TWAP tree, with a tolerance that the committee names. C: B, and research on a bound for orders of two classes without a feed: a corridor as policy data, or a budget on what the operator signs. | [ADR 007](/adr/007-swapping-through-an-orders-account.md) | A. The bound does not stop a hostile signing quorum, which signs an order of two classes; the orders budgets already bound that loss. Against a slip, screening does the same once the guard is set, and the launch cap bounds the time before. B adds a contract to audit and a call in the signing path, and its tolerance decides whether the operator can sell a token that left par, as stETH did in June 2022 and USDC in March 2023. | EM |
