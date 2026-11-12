---
type: Decision
title: "ADR 009: Budgets, exposure caps, reporting and monitoring"
description: Budgets, exposure caps, pricing, reports, the two readings, monitoring and the duty to remediate.
tags: [budgets, caps, reporting, monitoring, mandate]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T07:27:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on detective enforcement, budgets, caps, prices, reports, the two readings and monitoring, 2026-09-22 to 2026-11-10
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L782"
    title: Kit test at 7a8c661 — budget consumption at the approval, exhaustion and refill
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L226"
    title: Kit test at 7a8c661 — per-key allowance ceilings and the refill-period floor, with native conditions
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L262"
    title: Kit test at 7a8c661 — an approval spends its spender's key or stays below a fixed ceiling; an unlimited approval is refused
  - id: s12
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the committee rebalances within two working days after each snapshot; outside the repository until the mandate is published
  - id: s13
    resource: "https://research.lido.fi/t/10868/3"
    title: Lido forum — TMC-6 operational rules, 2025-11-17; sUSDS and tokenized money market funds at most 15 percent of the whole treasury, and a two-month runway floor
---

# ADR 009: Budgets, exposure caps, reporting and monitoring

## Context

- A permission bounds calls. It cannot see portfolio values or ratios.
- Each budget key is a consumable allowance in a token's units. Only successful calls consume it, and elapsed periods refill it up to its maximum [s3]. Native Roles conditions can enforce per-key ceilings and a period floor [s4].
- Value data is asynchronous, and prices drift with volatility and market stress whatever the cadence. More on-chain work adds little to the caps, which rest mostly on off-chain monitoring and the screening guard (EM, 2026-10-09) [s1].
- TMC-6 caps sUSDS and tokenized money market funds at 15 percent of the whole treasury, checked quarterly, and keeps a two-month stablecoin runway floor across the DAO's and the foundations' wallets [s13].
- Easy Track shares a limit of 20 open motions among all committees. On 2026-09-09, 18 motions were open ([research note](/research/enabling-vote-rehearsal-2026-10-15.md)).

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Accept detective enforcement with reporting. Reports rely on data published to immutable storage (decision log, 2026-09-22).
2. Reports go to IPFS. DataBus is not used, at least for now (decision log, 2026-09-22).
3. Budgets derive from the mandate, by an attested computation that actually runs (decision log, 2026-09-22).
4. The whole vault may sit in Lido products that are not new (decision log, 2026-09-22; OD-41).
5. Replaced by decision 31 (OD-56).
6. The committee owns the remediation of a ratio breach. If a breach gets worse, the escalation is the switch: the operator modifier is disabled (decisions 24 and 34) (decision log, 2026-09-22; OD-29).
7. Detectors run in the Lido on-chain monitoring and in the screening vendor's service (decision log, 2026-09-22).
8. Paging and escalation run through the general Lido incident process (decision log, 2026-09-22).
9. The yield-bearing cap is measured against the top-4 stablecoins plus the yield-bearing stablecoins that the vault holds directly. Own-product and protocol positions are outside the base (OD-03).
10. The mandate's illustrative balance renames its "USD-denominated" heading, so that it does not read as the cap's base (OD-03).
11. The budget is computed again on the literal base (OD-03).
12. Replaced by decision 28 (OD-41).
13. An operator approval to a protocol spender spends the budget of the key that the spender serves. An approval of zero is always allowed and spends nothing. Deposit calls spend no budget (OD-08).
14. The stETH approval to the wstETH contract has no budget key. Its fixed ceiling is one mandate size in stETH, and a motion changes it as [ADR 013](/adr/013-one-easy-track-factory.md) decision 13 allows (OD-08, OD-89, OD-105).
15. A budget motion cannot set a refill period below 30 days (OD-08).
16. Replaced by decision 28 (OD-41).
17. The `@lidofinance/defi-tech` team writes the specification of the vault's detectors in the Lido on-chain monitoring and makes the important updates to them. The `@lidofinance/lido-valset-vroom` team reviews them, runs the platform, and maintains the engine and the bot (OD-13).
18. The committee configures the vault's rules in the screening vendor's service. The defi-tech team supports it (OD-13).
19. The committee publishes a monthly report within seven calendar days after month-end, a post before each tranche vote, and an incident report within 72 hours. The defi-tech team builds and maintains a report generator in this repository. It reads the chain at a pinned block and the pricing source, so anyone can re-run it. The committee reviews and publishes each report (OD-14, OD-106, OD-122).
20. Replaced by decision 35 (OD-62).
21. While the monthly report is late, the proposer of a tranche vote does not start it, and monitoring alerts on a tranche vote that starts. Monitoring flags a missing report on day 8 after month-end. The committee explains the delay on the forum (OD-14, OD-106, OD-122).
22. A report's IPFS identifier is anchored only in its forum post. There is no on-chain anchor (OD-14).
23. The Snapshot text states the late-report rule of decision 21, and the LIP states the price waterfall of decisions 35 to 37 (OD-14, OD-62, OD-90).
24. The switch has a fixed trigger: a published cap breach that is still there after the committee's rebalancing window of two working days [s12], and that is larger at the next fortnightly snapshot. On the trigger, the emergency Safe disables the operator modifier (decision 34). A DAO vote can also do it (OD-29, OD-58).
25. Monitoring publishes the cap reading of each fortnightly snapshot. It runs the report generator at the snapshot's pinned block and publishes the cap ratios to IPFS. A breach in that reading is the published cap breach of decision 24, and the alert that pages the emergency Safe links the reading (OD-32, OD-58).
26. Every mandate rule gets a control on each layer that can carry it: the on-chain policy, screening before execution, monitoring with alerts, and display in the Zodiac UI. A [control matrix](/specs/control-matrix.md) maps each rule to its controls, owners and status. The screening vendor's rules are a written list in this repository (OD-39).
27. Replaced by decision 46 (OD-110).
28. A new Lido product counts against the protocol and counterparty cap until it matures. The mandate states the criteria for maturity. A budget motion and a forum post unlock the product, so the objection window is the unlock's timelock. Lido Lend is a new product; earnETH and earnUSD are not (OD-41).
29. A written requirement list goes to the policy provider. If the provider declines, Lido builds the display of its own reading (OD-44, OD-84).
30. Stated by [ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 11 and [ADR 010](/adr/010-pre-execution-screening.md) decision 19.
31. Budgets have no routine retune. Each key is set once, by the enabling vote or by the motion that onboards its spender. A budget motion changes a key only after an event (OD-56).
32. The yield-bearing key gets a fixed monthly budget, not the headroom of its cap (OD-56).
33. The caps are detective: the published fortnightly reading and the trigger of decision 24 (OD-56).
34. The emergency Safe disables the operator modifier through the emergency role's switch, for a defect in the permission layer or on the fixed trigger of decision 24 ([ADR 005](/adr/005-account-graph-and-roles.md) decision 25). The trigger is a duty, not a limit: the emergency role may act at any time. The alert of decision 25 pages the emergency Safe (OD-58).
35. Prices follow a written waterfall. Level 1 is Coingecko's closing price at the Snapshot Date. Level 2 is a second aggregator's price, when Coingecko's price is missing, more than 24 hours old, or outside a set band around the second aggregator's price. Level 3 is a Chainlink feed, or the time-weighted price of the deepest on-chain pool at the snapshot block. Level 4 is the asset's on-chain rate into an underlying that has a price. Level 4 is always the cross-check for a wrapper, such as wstETH, sUSDS or an Earn share. Level 5 is the committee's estimate, with its method in the report. An Earn share drops to level 5 while its curator freezes the vault (OD-62).
36. No asset is unpriced. Every price carries its level and its source. The post before a tranche vote names every price below level 2. While level 5 covers more than a set share of the vault, the proposer of a tranche vote does not start it, and monitoring alerts on a tranche vote that starts. The report records each level-5 input, so that anyone can re-run the report (OD-62, OD-106, OD-122).
37. The committee's written valuation policy sets the band of level 2 and the level-5 share of decision 36 (OD-62).
38. Replaced by decision 40 (OD-84).
39. Replaced by ADR 013 decision 9 (OD-102).
40. Two readings watch the vault: Lido's, from the report generator and monitoring, and the policy provider's own, in the Zodiac UI. Neither reads the other's data. Each reading checks the other (OD-84).
41. Both readings count. A cap breach in either published reading is a published cap breach for the trigger of decision 24. While the two readings differ by more than a band, on the vault's value or on a cap ratio, the proposer of a tranche vote does not start it, and monitoring alerts on a tranche vote that starts. The committee's valuation policy sets the band, as it sets the bands of decision 37 (OD-84, OD-106, OD-122).
42. The policy provider publishes its reports to IPFS with a pin-only key of a separate Lido pinning project, which Lido can revoke. The key is an admin setting of Lido's account in the Zodiac UI. The forum post that cites a reading links both reports (OD-85).
43. The Zodiac UI's signing flow refuses an operator transaction that would breach a cap at its post-transaction state by the provider's reading, and it shows each cap's headroom. It never refuses an emergency, recovery or DAO transaction. The gate is in the interface only: a signer can still execute through another Safe interface (OD-86, OD-110).
44. This repository holds the mandate's rules as data: the rubrics, the assets by address, each cap with its base, the product tiers, the vault's three Safes and the launch cap. Figures enter when the mandate is approved. Both readings use these rules. After the Snapshot vote, motion or vote that changes a rule, `@lidofinance/defi-tech` sends the new version to the provider, as it pushes the policy ([ADR 004](/adr/004-specifications-and-policy-as-data.md) decision 16). A change made in the Zodiac UI is drift, and an alert follows (OD-87, OD-110).
45. Monitoring warns when few of Easy Track's open-motion slots are free. The universal factory can set several keys in one motion (OD-94, OD-102).
46. The vault keeps no liquidity buffer (OD-110).
47. Each monthly report shows the TMC-6 ratio for the whole treasury: sUSDS and tokenized money market funds over the DAO's total treasury, the vault's sUSDS included (OD-111).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **Caps.** The mandate describes measurement, publication and remediation, not transaction reverts. Where the screening vendor can enforce a rule, it refuses an operator transaction that breaches it; emergency activity and price changes still need detective controls.
- **Prices.** Same-denomination caps use balances. Liquid-staking and yield-bearing caps need on-chain rates; cross-class caps need market oracles.
- **Budget shape.** The monthly flow equals each key's stock cap. Unbudgeted exits allow defensive exits and re-entry without a tighter flow limit. Lido-product keys allow the whole mandate per month (decision 4). This is a weak amount control, which the LIP must disclose.
- **Budget events.** Each budget motion's forum post names its event: a new mandate size; the onboarding of a spender with its key; a product's maturity and unlock (decision 28); or the setting of the guard ([ADR 010](/adr/010-pre-execution-screening.md) decision 22). A price change is not an event. A new mandate size changes no funding limit ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 1); a ceiling follows it by motion ([ADR 013](/adr/013-one-easy-track-factory.md) decision 13).
- **New Lido products.** The unlock motion raises Lido Lend's key to the own-product bound, and its forum post names the criteria that the product meets (decision 28). earnETH and earnUSD have own-product keys from the start.
- **The provider's reading.** The requirement list asks the Zodiac UI for its own reading of the vault's three Safes as one whole, with the mandate's rubrics: the first-loss Safe as a rubric outside the caps and the launch cap, and the orders account in the value. It shows the value per account, asset and protocol; each cap against its limit, with headroom; the launch cap until the guard is set; the budget left per key; open orders with their age and limit; pending motions with their deadlines; and the guard's state. It takes a reading at each Snapshot Date and fortnightly snapshot and publishes it (decision 42). Its alerts go to a Lido Slack channel by webhook and do not page; Lido's own monitoring pages (decision 8). It also meets decisions 43 and 44 and [ADR 010](/adr/010-pre-execution-screening.md) decision 25.
- **The rule data.** One file carries the rules of decision 44, with the mandate size and the treasury share ([ADR 008](/adr/008-funding-through-existing-payments.md) decisions 32 and 33). A check in CI validates it.
- **Attestation.** The computation ran on 2026-09-22 with pinned inputs and an independent attester, and again on 2026-10-02 with the literal base. Decision 32 needs a fixed yield-bearing figure after the mandate's approval, and no holdings snapshot. The results stay outside this repository until then, because the inputs include unapproved terms.
- **Approvals.** Each spender branch uses its own key. On the Asset Safe, approve only the deposit amount in the same transaction, so no approval stands. The orders account's approvals to CoW's vault relayer stand ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 41 and 46).
- **Budgets in the factory.** The universal factory bounds a key's `balance`, `maxRefill` and `refill` by its token's ceiling, and its `period` below by 30 days. Every key of a token shares that token's ceiling.
- **Reports.** The IPFS payloads hold balances, positions, exposures, the numerators and denominators of the ratios, and each price's level, source and timestamp. A tranche vote's payment reference can name the report, but no contract checks it.
- **Size and treasury share.** Each fortnightly reading and each post before a tranche vote state the vault's funded value against the mandate size, and the vault's share of the DAO's non-LDO treasury ([ADR 008](/adr/008-funding-through-existing-payments.md) decisions 32 and 33).

The phase-1 detector specification gives each detector an ID, a watched state, a severity and an execution environment. A pull request here that changes a watched permission links the matching detector change. It starts with:

- Drift against the compiled artifact ([ADR 004](/adr/004-specifications-and-policy-as-data.md)); the approval inventory; budget burn and every budget motion.
- Owner, threshold, module, guard and singleton changes on the new Safes; singleton changes are critical ([ADR 010](/adr/010-pre-execution-screening.md) decision 18).
- The motion lifecycle, free Easy Track motion slots (decision 45), funding and return flags, and emergency actions. Revoke-only actions page below transfers or swaps.
- The screening guard's detection, extended to the new instance on the committee's Safe ([ADR 010](/adr/010-pre-execution-screening.md) decisions 12 and 24).
- Open orders, idle tokens of the orders account, market-relative fills and the watch-tower's posting; fallback-handler or domain-verifier changes are critical ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- First-loss balance, owner, module and singleton changes; every burn motion and every action of the `first-loss` role ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- A new product's exposure against the protocol cap until its unlock (decision 28); the rule changes that the vendor reports ([ADR 010](/adr/010-pre-execution-screening.md) decision 19).
- A monthly report missing on day 8; the fortnightly cap readings on IPFS (decision 25), which page the emergency Safe on decision 24's trigger.
- The two published readings compared at each snapshot; a tranche vote that starts while a gate of decisions 21, 36 or 41 holds; a breach in the provider's reading, counted for decision 24's trigger.
- A change of the mandate's rules made in the Zodiac UI (decision 44).

## Options considered

- **A custom preventive-cap adapter:** not chosen. `staticcall` cannot keep a ledger, and a pre-state check can admit a transaction that breaks a cap.
- **A DataBus anchor for reports:** deferred (decision 2). The anchor would be off Ethereum.
- **Budget figures set by hand:** not chosen (decision 3).
- **Routine retunes, fortnightly or monthly:** not chosen (decision 31). About 26 motions a year, each with a committee signature, a forum disclosure and an objection window, would change most keys only slightly.
- **Fixed approval ceilings with budgets metered at the deposit:** not chosen (decision 13). Repeated approvals let a spender pull funds without a budgeted deposit.
- **Approval ceilings of one deposit:** not chosen. They add token figures and do not stop repeated approvals.
- **Only a DAO vote stops a breach that gets worse:** not chosen (OD-29). A vote is slower than the fixed trigger's response time.
- **Cap readings that the committee publishes:** not chosen (OD-32). The party in breach could delay its own stop.
- **Triggers from the monthly report only:** not chosen (OD-32). A stop could wait about six weeks.
- **A 14-day refill floor:** not chosen. Conditions cannot compare the refill with the period, so the monthly refill would double.
- **Uncap a new product after a fixed time:** not chosen (decision 28). The maturity criteria, not a date, unlock it.
- **Third-party valuations alone:** not chosen (OD-44). Caps, tranche votes and reports need a reproduction at a pinned block.
- **Leave an unpriced asset out of the ratios:** not chosen (decisions 35 and 36). Prices must stay available, and a source can be wrong as well as missing.
- **Price sources that the committee chooses without a ranking:** not chosen. Reports need a checkable rule.
- **Lido's reading as the record and the provider's as a check only:** not chosen (OD-84; decision 41).
- **The provider pins on its own account, and Lido pins the same identifier:** not chosen (OD-85).
- **A warning at signing with a typed confirmation:** not chosen (OD-86).
- **A cap check on chain by the provider:** not possible. The committee's Safe has one guard slot, which the screening guard takes (OD-83), and the only new contracts are the universal factory and its companions ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 1).
- **Separate rule sets for the two readings:** not chosen (OD-87). One rule set makes the cross-check test data and prices, and review catches a rule error once (decision 44).
- **Controls without a matrix:** not chosen (OD-39). Rules without a control could stay invisible.
- **Raise Easy Track's open-motion limit to its maximum of 24:** not chosen (OD-94). Every committee shares the setting.

## Consequences

- Reports have no on-chain anchor (decision 22). Their immutability rests on content addressing and the citing forum post: an informational control, not an Ethereum guarantee.
- Detective controls need human action. The mandate must name the responsible roles.
- The singleton alert must ship before deployment (OD-17).
- The committee must align the vendor's rules with the positions.
- An approval consumes its key's room even if its deposit later fails or is cancelled; the refill restores it.
- Token-unit budgets drift from ratio caps with prices (decision 31). A key can allow more than its cap's headroom after a price rise, or less after a fall.
- Under the literal base, yield-bearing room exists only next to directly held stablecoins. The illustrative allocation has none, and so no yield-bearing position. A fixed budget can allow deposits beyond the ratio's headroom (decision 32).
- The committee can enlarge the base before a test by holding more stablecoins. Deposit-time checks and the published history limit this but do not prevent it.
- sUSDS counts against the yield-bearing cap of the literal base as soon as it arrives.
- Lido Lend's key starts with a ceiling, and a motion raises it at most twofold in 15 days (OD-105), so the uncapped budget can take several motions.
- Screening makes the vendor part of each checked rule's trust base. Written rules and controlled relaxations are needed ([ADR 010](/adr/010-pre-execution-screening.md) decision 19).
- The generator needs a second aggregator, Chainlink and pool prices at a pinned block, and the recorded level-5 inputs. Lower-level prices can still be wrong (decision 36).
- Without the provider's reading, Lido's governs alone (decisions 29 and 41).
- A wrong price in one reading can stop the operator (decision 41). The two working days and the larger breach at the next fortnightly snapshot bound that risk (decision 24). A wrong price also delays funding while the readings differ by more than the band.
- The redundancy is full for balances and positions, which two indexers read. It is partial for prices: a wrapper can rest on the same upstream rate in both readings.
- One rule set serves both readings, so an error in the rules affects both. Review of the rule data in this repository must catch it (decision 44).

## Confirmation

- INV-008, INV-011 and INV-012 in the [invariants](/specs/invariants.md); INV-036 for the ceilings.
- Kit test: approvals bounded by a key or a ceiling, and an unlimited approval refused [s5].

## Reversal conditions

- A breach that detection misses, or that remediation does not close within the mandate's window.
- A report that cannot be reproduced from its published data.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

The committee's valuation policy owes the band of level 2, the level-5 share (decision 37) and the band between the two readings (decision 41). Owed: the screening vendor's answer on which rules it can check before execution, and the policy provider's answer on the requirement list. The rule data of decision 44 is owed with the report generator.
