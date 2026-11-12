---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T12:05:15Z
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
| OD-133 | May USDY enter the Asset Safe through an exit from Lido Lend's stablecoin market? The lender vault's fallback exit can pay collateral (OD-132), and that market's collateral is USDY, which is not on the launch list ([research note](/research/lido-lend-insurance-2026-11-12.md)). Options: (A) build the lender-vault shape for the WETH market only, whose collateral, wstETH, is a launch token; the stablecoin market waits for this decision; (B) allow the exit: the motion that onboards the stablecoin market also introduces USDY, with its exit to the Aragon Agent and a recovery order that sells it; (C) lend to the stablecoin market through the core, which never pays collateral, and accept that a withdrawal fails while the market has no free liquidity. | [ADR 011](/adr/011-launch-scope.md) | A. The WETH market needs no new token. The agent has not checked whether the Asset Safe can hold and transfer USDY, and that check comes before B | EM |
