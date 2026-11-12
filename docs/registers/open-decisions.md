---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T11:10:32Z
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
| OD-131 | Which Lido Lend fund does the factory carry (OD-107)? Lido Lend has no entry point for either form today: its core has no share token, its lender vault has no burn that a holder can call, and no function adds loan assets to a market without new supply shares ([research note](/research/lido-lend-insurance-2026-11-12.md)). Options: (A) build the payout form only: the motion that creates the fund pins the token, the payout address and the cap, which is a budget key that does not refill; the payout address is one that the Lend team names, outside Lido Lend's contracts, and it pays the lenders; (B) ask the Lend team for a loss cover in Lido Lend, a function that adds loan assets to a market's supply without new shares, and build the fund against it when it exists, which needs a changed factory and a vote if it comes after the audit; (C) no Lend fund in the factory: insurance money for Lido Lend waits in the first-loss Safe as plain tokens, and Aragon Voting pays it out by vote after a loss. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A, with one question to the Lend team before the build: which address receives a payout and how it pays the lenders. The payout form is the only one that fits Lido Lend as it is, and a test with a stand-in address covers it. The share form of ADR 014 decision 6 has no use until Lido Lend has a share token with a holder's burn | EM |
| OD-132 | Which Lido Lend surface does the vault lend through? The core's `supply` and `withdraw` keep their Morpho Blue signatures, and the planned Morpho Blue shape fits them; a withdrawal fails while the market has no free liquidity. The lender vault is an ERC-4626 token whose fallback exit still works then, and it can pay collateral: wstETH in the WETH market, and USDY, which is not on the launch list, in the stablecoin market ([research note](/research/lido-lend-insurance-2026-11-12.md)). Options: (A) the lender vault, through the factory's ERC-4626 shape with the fallback exit added, receiver and owner pinned to the Asset Safe; (B) the core, through the Morpho Blue shape, with no exit while a market has no free liquidity; (C) both shapes in the factory, and the onboarding motion chooses. | [ADR 011](/adr/011-launch-scope.md) | A for the WETH market, whose collateral is a launch token. For the stablecoin market, decide first whether USDY may enter the Asset Safe through an exit. The agent has not asked the Lend team which surface it intends for a DAO lender | EM |
