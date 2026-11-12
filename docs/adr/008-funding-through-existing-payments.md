---
type: Decision
title: "ADR 008: First-loss shares, insurance funds and the mandate size"
description: The DAO's first-loss Earn shares in their own Safe, their burn by motion and their redemption to the Asset Safe, the framework for insurance funds, and the mandate size as a ceiling.
tags: [first-loss, insurance, mandate, funding]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:38:25Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the first-loss shares, insurance funds and the mandate size, 2026-09-22 to 2026-11-10
  - id: s6
    resource: /research/legacy-investments-2026-10-05.md
    title: Legacy investments, 2026-10-05 — the first-loss Earn shares, their Growth Committee holder, transferability, and the Twyne search
  - id: s7
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — the first-loss terms of March 2026, the Kelp burn, and the time that a DAO vote takes
---

# ADR 008: First-loss shares, insurance funds and the mandate size

## Context

- The March 2026 Snapshot approved the DAO's first-loss Earn allocation. A Growth Committee Safe holds 1,362.84 earnETH and 1,998,416.46 earnUSD shares. At the read, the shares transfer freely and the holder can burn them. The checked Lido addresses hold no Twyne position [s6].
- The March 2026 terms let the Earn team instruct the executing committee to burn up to all of the DAO's shares in that vault after a curator-confirmed loss of at least 1%. On a confirmed material risk, the Earn team may instruct a normal redemption. Neither action needs a vote. An incident update is due within seven days, and the DAO can change or end the authorization at any time [s7].
- Kelp's loss of April 2026 was below 1%. A Snapshot allowed a one-time exception, which ran on 2026-05-15 as one `burn` call [s7].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Lapsed (OD-106): tranche votes do not use Easy Track's payment permission.
2. Stated by [ADR 011](/adr/011-launch-scope.md) decision 2.
3. Lapsed (OD-106): the vault has no funding registry.
4. Replaced by ADR 014 decision 1 (OD-106).
5. Replaced by ADR 014 decision 1 (OD-106).
6. Lapsed (OD-106): the vault has no top-up motion.
7. Lapsed (OD-106): the vault has no top-up motion.
8. Lapsed (OD-106): the vault has no funding registry.
9. Lapsed (OD-106): the vault leaves Easy Track's payment permission unchanged.
10. Lapsed (OD-106): the vault has no funding registry.
11. Replaced by ADR 014 decision 3 (OD-106).
12. Lapsed (OD-106): the vault leaves Easy Track's payment permission unchanged.
13. After the enabling vote, the Growth Committee transfers the DAO's first-loss shares in earnETH and earnUSD from its Safe to the first-loss Safe (OD-21, OD-42).
14. The Treasury Management mandate takes over the first-loss terms of the March 2026 Earn allocation (OD-21).
15. Replaced by decision 23 (OD-67).
16. Lapsed (OD-42): the operator role cannot reach the first-loss Safe.
17. A Twyne position counts in the funded value only when its holder and form are shown on chain or in a signed record (OD-21, OD-106).
18. Lapsed (OD-42): the emergency role cannot reach the first-loss Safe.
19. The first-loss shares sit in a dedicated first-loss Safe, not in the Asset Safe. Aragon Voting owns it one of one, and the first-loss modifier is its only module (OD-42, OD-60, OD-73).
20. Replaced by ADR 010 decisions 20 and 22 (OD-106, OD-121).
21. The first-loss modifier gives the committee's Safe one `first-loss` role. The role may request and claim the redemption of the DAO's own earnETH and earnUSD shares, with the proceeds pinned to the Asset Safe. It may not transfer, approve or burn the shares (OD-60, OD-67, OD-80, OD-108).
22. The committee executes the first-loss terms of the March 2026 Earn allocation, in place of the Growth Committee, on the Earn team's written instruction (OD-60).
23. No first-loss burn runs without the objection window. A burn runs only as a motion of the universal factory: the committee's Safe creates it, and after the window the factory burns the shares through the `first-loss-burn` role on the first-loss modifier (OD-67, OD-80, OD-102, OD-118).
24. Lapsed (OD-106): the vault has no funding registry or stETH limit.
25. One Snapshot sets a standing framework for insurance funds. Then each new fund needs one motion (OD-66).
26. Payouts from an insurance fund run as motions (OD-66).
27. Replaced by ADR 014 decision 4 (OD-107).
28. The committee's Safe exits an insurance fund through its direct role, with the proceeds paid to the Asset Safe (OD-66, OD-80, OD-108).
29. The framework fixes a checklist that every fund fills in, in its motion and its forum post: the product, and its share token or payout address; the motion's writes; the fund's cap; the loss trigger and a confirming party independent of the product team; the incident-update deadline; and the end of the terms (OD-66, OD-102).
30. Replaced by ADR 014 decision 7 (OD-107).
31. Replaced by ADR 014 decision 4 (OD-107).
32. The mandate size follows the mandate's draft text. The vault holds up to the mandate size in assets. Each funding counts in US dollars at its value when it is funded. The legacy positions that move into the vault count too (OD-89).
33. The vault never holds more than the mandate's share of the DAO's non-LDO treasury (OD-89).
34. More funding than the mandate size needs a separate DAO approval. A further funding or a replenishment uses an approved governance path only when the mandate's published eligibility conditions are met, and after the required disclosure (OD-89).
35. Lapsed (OD-106): the vault has no funding registry.
36. Lapsed (OD-106): the vault leaves Easy Track's payment permission unchanged.
37. The funded value counts the first-loss shares at the report's price rule ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decisions 35 and 36) (OD-98, OD-106).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **First-loss custody.** A Safe v1.5.0 ([ADR 005](/adr/005-account-graph-and-roles.md) decision 13). Plain transfers bring the first-loss shares (decision 13), and a motion brings insurance money ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 7).
- **First-loss burn.** The motion names an amount and the earnETH or earnUSD share (decision 23; [ADR 013](/adr/013-one-easy-track-factory.md#proposed-direction)).
- **First-loss exit.** The committee's `first-loss` role calls `redeem` and `claim` on the Earn vault's queue (decision 21).
- **Instructions and reporting.** Publish the Earn team's instruction and the curator's confirmation with the motion (decision 22). Below the terms, get a Snapshot exception first, as for Kelp. The first-loss amount is the received shares less the burns; reports show it as a sub-allocation. The [threat model](/specs/threat-model.md) lists the alerts.
- **Insurance funds.** Each fund fills in the checklist of decision 29. [ADR 014](/adr/014-funding-by-tranche-votes.md) decisions 5 and 6 state what a fund covers.

## Options considered

- **Leave the first-loss shares with the Growth Committee:** not chosen. The mandate takes over the terms (decision 14), and the shares would stay without a written rule.
- **Hold the first-loss shares in the Asset Safe:** not chosen (OD-42). They would look like purchased shares, and only monitoring would keep them apart.
- **The Growth Committee redeems the first-loss shares and funds the vault in full:** not chosen. It ends the approved protection.
- **A DAO vote for every burn or redemption:** not chosen. A vote takes longer than the terms' timing [s7].
- **A first-loss Safe that the committee owns:** not chosen. The committee would take full custody.
- **An emergency redemption of the first-loss shares:** not chosen. An exit before a flagged loss would front-run the protected depositors.
- **Count a Twyne position now, as the mandate states:** not chosen. Its holder and form are not shown (decision 17).

## Consequences

- Only an enacted burn or a redemption to the Asset Safe reaches the first-loss shares (decisions 21 and 23), so no written rule needs a check.
- The capital still absorbs losses first; a curator's freeze can delay a redemption [s7].
- A burn by motion comes later than a Growth Committee burn would: the March 2026 terms allowed urgent burns before notice, and public motions remove that option [s7]. The public notice lets depositors time an entry or an exit, so the vault should pause deposits and redemptions until the burn, as after Kelp.
- Burns move value to other depositors, so each burn motion pages monitoring. The [threat model](/specs/threat-model.md) covers a captured committee quorum.
- Burns reduce the vault's value, and no funding refills it by right (decision 34).
- The move depends on the Earn administrators keeping share transfers open until it happens; they can restrict transfers [s6].
- The treasury share can break without a vault transaction, through the treasury's own spending or a price move. Until the mandate states the remedy, monitoring can report the breach, but no rule defines the response.

## Confirmation

- INV-021 and INV-037 in the [invariants](/specs/invariants.md); INV-039 for insurance money.
- The enabling-vote rehearsal moved both first-loss share balances from the Growth Committee's Safe by plain transfer ([research note](/research/enabling-vote-rehearsal-2026-10-15.md)).
- The first-loss modifier's policy holds the `first-loss` and `first-loss-burn` roles, and the enabling vote's first-loss batch applies it. On a fork with the live Earn vaults, a burn motion burns the first-loss Safe's shares after the objection window (`test_first_loss_burn_by_motion`), nothing burns outside a motion (`test_first_loss_burn_needs_a_motion`), the committee's role requests a redemption and cannot move the shares (`test_first_loss_role_requests_a_redemption`, `test_first_loss_role_cannot_move_the_shares`), and no other role reaches the shares (`test_other_roles_do_not_reach_the_first_loss_shares`).
- The compiler refuses a first-loss role that transfers or approves the shares, and any role that calls the first-loss Safe or its modifier (`policy/constellation/compiler/compile.test.ts`).
- The exit of a fund pays only the Asset Safe (decision 28; `test_fund_exit_pays_only_the_asset_safe`). [ADR 014](/adr/014-funding-by-tranche-votes.md) holds the confirmation of insurance money, of the Earn deposit and of a fund with a payout address.

## Reversal conditions

- The Earn vaults block share transfers before the move.
- The first-loss terms end. A DAO vote then moves the shares to the Asset Safe as ordinary positions.
- The DAO changes or ends the first-loss authorization. A DAO vote then changes or removes the two first-loss roles and the burn role.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

- Twyne: who holds the position, and in what form. The mandate's drafters owe the evidence (decision 17).
- The treasury share's base and test time, the remedy for a breach that no vault transaction causes, and the eligibility conditions of a replenishment. The mandate's drafters owe them (decisions 33 and 34).
