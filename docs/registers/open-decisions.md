---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T21:45:08Z
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
| OD-129 | Does insurance money need a bound on its amount? The `insurance-funding` role transfers any amount of a listed token from the Asset Safe to the first-loss Safe, and the universal factory refuses only an amount of zero. Options: (A) a budget key for each token on that transfer, within the token's budget ceiling, so that a budget motion sets how much insurance money can move in a period; (B) a ceiling of its own class for each token in the factory; (C) no bound, with the objection window as the only control. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A. It uses the budgets and ceilings that the factory already has, and it adds no code to the factory. Without a bound, two motions that nobody objects to can move any amount to the first-loss Safe and then burn it | EM |
| OD-130 | Which operation gives Lido Earn its insurance at launch (OD-107)? Insurance money reaches the first-loss Safe as plain tokens, and the burn and the `first-loss` redemption act on Earn shares. No operation turns the money into shares. Options: (A) one factory operation that deposits a token from the first-loss Safe into earnETH or earnUSD, with an approval of the exact amount, through an insurance role on the first-loss modifier; the new shares then follow the first-loss rules, a burn by motion and a redemption to the Asset Safe; (B) no deposit: an Earn fund holds plain tokens and pays a pinned payout address within a cap. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A. It adds one operation and uses the burn and the redemption that are built and tested | EM |
| OD-131 | How does the factory carry the two forms of a Lido Lend fund before Lido Lend exists (OD-107)? A shape that the factory lacks needs a changed factory and a vote ([ADR 013](/adr/013-one-easy-track-factory.md) decision 4). Options: (A) build both forms now: the payout form, whose creating motion pins the payout address and holds the cap as a budget key that does not refill, tested with a stand-in address; and the share form, as a motion that adds a share token with a holder's `burn(uint256)` to the burn role; (B) build the payout form only, and add the share form with a changed factory when Lido Lend's share token exists; (C) leave both forms to a changed factory. | [ADR 014](/adr/014-funding-by-tranche-votes.md) | A, with one stated assumption: Lido Lend's share token has a holder's `burn(uint256)`. If it does not, the share form does not fit, and the payout form remains | EM |
