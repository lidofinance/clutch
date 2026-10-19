---
type: Decision
title: "ADR 009: Budgets, exposure caps, reporting and monitoring"
description: Budgets, exposure caps, pricing, reports, monitoring and responsibility for remediation.
tags: [budgets, caps, reporting, monitoring, mandate]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T20:52:38Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on detective enforcement, budgets, reporting and monitoring, 2026-09-22, and later decisions
  - id: s2
    resource: /specs/lip-draft.md
    title: LIP draft — budgets, reporting and detective controls
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L782"
    title: Kit test at 7a8c661 — budget consumption at the approval, exhaustion and refill
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L226"
    title: Kit test at 7a8c661 — per-key allowance ceilings and the refill-period floor, with native conditions
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L262"
    title: Kit test at 7a8c661 — an approval spends its spender's key or stays below a fixed ceiling; an unlimited approval is refused
  - id: s6
    resource: /research/funding-registries-2026-10-02.md
    title: Easy Track funding registries, 2026-10-02 — the top-up factory writes a fixed payment reference
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/Policy.sol#L328-L377"
    title: Kit policy at 370e20a — an approval is zero or below a fixed cap, and spends no budget
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/Policy.sol#L474-L489"
    title: Kit policy at 370e20a — the deposit call spends the budget
  - id: s9
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/Policy.sol#L688-L705"
    title: Kit policy at 370e20a — the governance permission on budgets pins the key and bounds nothing else
  - id: s10
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/src/policy/Policy.sol#L259-L280"
    title: Kit policy at 7a8c661 — each approval branch spends its spender's budget key, or has a fixed ceiling
  - id: s11
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/src/policy/Policy.sol#L524-L547"
    title: Kit policy at 7a8c661 — the governance permission on budgets pins the key and a 30-day period floor
  - id: s12
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the committee rebalances within two working days after each snapshot; outside the repository until the mandate is published
---

# ADR 009: Budgets, exposure caps, reporting and monitoring

## Context

- Permissions bound calls, but cannot see portfolio valuations or ratios [s2].
- Each budget key is a consumable allowance. Successful calls consume it; elapsed periods refill it up to its maximum [s3]. Different token decimals require separate keys [s2].
- Before OD-08, deposits spent budgets while approvals had fixed ceilings [s7][s8]. Spenders could pull approved funds without a deposit, outside that budget.
- Governance formerly pinned only the budget key [s9]. Native conditions can also enforce per-key ceilings and a period floor [s4].

## Decision

EM decided on 2026-09-22 [s1]:

1. Accept detective enforcement with reporting. Reports rely on data published to immutable storage.
2. Reports go to IPFS. DataBus is not used, at least for now.
3. Budgets derive from the mandate, by an attested computation that actually runs.
4. The whole vault may sit in Lido products.
5. Budgets retune every two weeks.
6. The committee owns ratio-breach remediation. If a breach gets worse, the escalation is a pause of the whole module.
7. Detectors run in the Lido on-chain monitoring and in the screening vendor's service.
8. Paging and escalation run through the general Lido incident process.

EM decided on 2026-10-02, closing OD-03 [s1]:

9. The yield-bearing cap is measured against the top-4 stablecoins plus the yield-bearing stablecoins that the vault holds directly. Own-product and protocol positions are outside the base.
10. The mandate's illustrative balance renames its "USD-denominated" heading, so that it does not read as the cap's base.
11. The budget is computed again on the literal base.

EM decided on 2026-10-02, closing OD-04 [s1]:

12. Lido Lend counts against the protocol cap for its first three months. After that it is a Lido own product with no cap per product.

EM decided on 2026-10-02, closing OD-08 [s1]:

13. An operator approval to a protocol spender spends the budget of the key that the spender serves. An approval of zero is always allowed and spends nothing. Deposit calls no longer spend budget.
14. The stETH approval to the wstETH contract has no budget key. It keeps a fixed ceiling of one TM Floor Value in stETH, the figure that OD-06 computes.
15. A budget motion cannot set a refill period below 30 days.

EM confirmed on 2026-10-05, closing OD-12 [s1]:

16. Lido Lend's three capped months count from Lido Lend's mainnet launch.

EM decided on 2026-10-05, closing OD-13 [s1]:

17. The `@lidofinance/defi-tech` team writes the specification of the vault's detectors in the Lido on-chain monitoring and makes the important updates to them. The `@lidofinance/lido-valset-vroom` team reviews them, runs the platform, and maintains the engine and the bot.
18. The committee configures the vault's rules in the screening vendor's service. The defi-tech team supports it.

EM decided on 2026-10-05, closing OD-14 [s1]:

19. The mandate's publisher and schedule stand: the committee publishes a monthly report within seven calendar days after month-end, a post before each top-up, and an incident report within 72 hours. The defi-tech team builds and maintains a report generator in this repository. It reads the chain at a pinned block and the pricing source, so anyone can re-run it. The committee reviews and publishes each report.
20. Prices come from Coingecko's closing price at the Snapshot Date. A price that is missing or more than 24 hours old is replaced by the asset's on-chain rate into an underlying that has a price. An asset with neither is listed as unpriced with its balance, left out of every ratio and of the vault value, and named in the report. An old price is never carried over silently. No top-up rests on a snapshot with an unpriced asset.
21. While the monthly report is late, no top-up motion starts. Monitoring flags a missing report on day 8 after month-end. The committee explains the delay on the forum.
22. A report's IPFS identifier is anchored only in its forum post. There is no on-chain anchor.
23. The mandate text states the price rule of decision 20 and the late-report rule of decision 21.

EM confirmed on 2026-10-05, closing OD-29 [s1]:

24. "A pause of the whole module" in decision 6 means disabling the operator modifier. The Emergency Brakes multisig does it through its technical role, on a fixed trigger: a published cap breach that is still there after the committee's rebalancing window of two working days [s12], and that is larger at the next fortnightly snapshot. A DAO vote can also do it.

EM decided on 2026-10-06, closing OD-32 [s1]:

25. Monitoring publishes the cap reading of each fortnightly snapshot. It runs the report generator at the snapshot's pinned block and publishes the cap ratios to IPFS. A breach in that reading is the published cap breach of decision 24, and the alert that pages the Emergency Brakes multisig links the reading.

EM decided on 2026-10-06, closing OD-39, OD-40, OD-41, OD-44 and OD-45 [s1]:

26. Every mandate rule gets a control on each layer that can carry it: the on-chain policy, screening before execution, monitoring with alerts, and display in the Zodiac UI. A [control matrix](/specs/control-matrix.md) maps each rule to its controls, owners and status. The screening vendor's rules are a written list in this repository.
27. The liquidity buffer of at least one month of baseline spend gets a continuous detector, a line in every report, a screening rule if the vendor can check it before execution, and a display in the Zodiac UI. The committee restores the buffer within the mandate's window. Its figure comes from the attested computation.
28. A new Lido product counts against the protocol and counterparty cap until it matures. The mandate states the criteria for maturity. A budget motion and a forum post unlock the product, so the objection window is the unlock's timelock. Lido Lend is a new product; earnETH and earnUSD are not. This replaces decisions 12 and 16, and decision 4 now covers only products that are not new.
29. The Zodiac UI shows Lido's own readings as the canonical figures, a live value labelled as indicative, and warnings before signing. A written requirement list goes to the policy provider. If the provider declines, Lido builds the display from the same readings.
30. Easy Track motions are the timelock for every structural increase of exposure in the policy. The unlock of a matured product is a motion (decision 28). A relaxation of the screening vendor's rules is a change under control ([ADR 010](/adr/010-pre-execution-screening.md) decision 19).

EM decided on 2026-10-09, closing OD-56 [s1]:

31. Budgets have no routine retune. Each key is set once, by the enabling vote or by the motion that onboards its spender. A budget motion changes a key only after an event.
32. The yield-bearing key gets a fixed monthly budget instead of the headroom of its cap.
33. The caps stay detective: the published fortnightly reading and the trigger of decision 24.

Decision 31 replaces decision 5. The fortnightly snapshot stays for the cap reading of decision 25 only.

EM decided on 2026-10-13, after the committee's feedback, closing OD-58 [s1]:

34. The emergency Safe disables the operator modifier through the emergency role's switch, for a defect in the permission layer or on the fixed trigger of decision 24 ([ADR 005](/adr/005-account-graph-and-roles.md) decision 25). The alert of decision 25 pages the emergency Safe.

Decision 34 replaces the Emergency Brakes multisig and its technical role in decisions 24 and 25. The emergency role can revoke every operator permission at any time, so the trigger no longer limits when it acts. The trigger stays a duty: when it is met, the emergency Safe switches the operator off.

EM decided on 2026-10-13, closing OD-62 [s1]:

35. Prices follow a written waterfall. Level 1 is Coingecko's closing price at the Snapshot Date. Level 2 is a second aggregator's price, when Coingecko's price is missing, more than 24 hours old, or outside a set band around the second aggregator's price. Level 3 is a Chainlink feed, or the time-weighted price of the deepest on-chain pool at the snapshot block. Level 4 is the asset's on-chain rate into an underlying that has a price. Level 4 is always the cross-check for a wrapper, such as wstETH, sUSDS or an Earn share. Level 5 is the committee's estimate, with its method in the report. An Earn share drops to level 5 while its curator freezes the vault.
36. No asset is unpriced. Every price carries its level and its source. A top-up post names every price below level 2. A top-up waits while level 5 covers more than a set share of the vault. The report records each level-5 input, so that anyone can re-run the report.
37. The committee's written valuation policy sets the band of level 2 and the level-5 share of decision 36.
38. The requirement list to the policy provider also asks for monitoring in the Zodiac UI: Lido's alerts shown there, next to Lido's readings. Lido's readings and alerts stay canonical. If the provider declines, Lido builds both.

Decisions 35 to 37 replace decision 20 and refine OD-14. Decision 23 now covers them: the mandate text states the waterfall. Decision 38 extends decision 29.

EM gave the reason on 2026-10-09 [s1]: the caps rest mostly on off-chain monitoring and the screening guard, because value data is asynchronous. More on-chain work adds little value, because prices drift with volatility and market stress whatever the cadence.

EM decided on 2026-10-14, closing OD-69 [s1]:

39. The enabling vote holds spare budget keys for each token, with ceilings, so that a motion can budget a spender that the vote did not know.

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

- **Caps.** The mandate must describe measurement, publication and remediation rather than transaction reverts. Where the screening vendor can enforce a rule, it refuses breaching operator transactions. Emergency activity and price changes still need detective controls.
- **Liquidity buffer.** Count directly held Asset Safe stablecoins and immediately redeemable sUSDS; exclude Earn shares and orders-account tokens. Monitoring checks continuously and warns above the floor; reports and Zodiac display the buffer. Attested computation supplies one month of baseline spend.
- **Prices.** Same-denomination caps use balances. Liquid-staking and yield-bearing caps need on-chain rates; cross-class caps need market oracles.
- **Budget shape.** Monthly flow equals each key's stock cap. Unbudgeted exits permit defensive exits and re-entry without a tighter flow constraint. Lido-product keys permit the whole mandate per month because the whole vault may use them. This is a weak amount control, which the LIP must disclose.
- **Budget function (decision 31).** A key limits monthly approval to one spender, independently of prices or exposure ratios. Published readings measure caps (decisions 25 and 33); screening can check them after the launch cap lifts, and the committee remediates breaches.
- **Spare keys.** The enabling vote includes two per launch token, with attested ceilings (decision 39). Onboarding takes and sets a spare key. Two is the agent's proposed count.
- **Budget events.** Each motion's forum post names its event: a new TM Floor Value; onboarding a spender and setting its key; product maturity/unlock (decision 28); or launch-cap lift ([ADR 010](/adr/010-pre-execution-screening.md), decision 22). Price changes are not events under decision 31. Floor changes also require DAO votes for funding limits and fixed approval ceilings ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 24).
- **Yield-bearing keys.** Use an attested fixed monthly figure (decision 32). Cap headroom no longer sets it, so no holdings snapshot is required.
- **New Lido products.** Lido Lend remains protocol-capped until maturity and a budget motion raises its key to the own-product bound. The forum post identifies satisfied criteria (decision 28). earnETH and earnUSD are own-product keys from the start.
- **Zodiac display.** Request account/asset/protocol value, with first-loss as a sub-allocation; buffer and cap limits with warnings; remaining budgets; open-order age and limits; motion deadlines; guard state; pre-signing breach warnings; and Lido alerts with their state (decision 38). Canonical figures come from Lido's report generator and monitoring. Third-party live values are indicative and must not feed caps, top-ups or reports.
- **Attestation.** The computation ran on 2026-09-22 with pinned inputs and an independent attester, then again on 2026-10-02 with the literal base. Decision 32 requires a fixed yield-bearing figure after mandate approval. Results stay outside this repository until approval because inputs include unapproved terms.
- **Approvals.** Each spender branch uses its own key; two spenders use two keys. On the Asset Safe, approve only the deposit amount in the same transaction, leaving no standing approval. Orders-account CoW approvals stand, are set by vote and cannot be raised by roles ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). Converter approvals for DAI/USDS use the stETH-to-wstETH fixed ceiling (decision 14; [ADR 011](/adr/011-launch-scope.md)). No withdrawal-queue approval is allowed (ADR 007, decision 27).
- **Budget factory.** One branch per key bounds `balance`, `maxRefill` and `refill` by its ceiling and `period` below by 30 days. A kit test demonstrates native conditions [s4].
- **Reports.** IPFS payloads contain balances, positions, exposures, ratio numerators/denominators, and each price's level, source and timestamp (decision 36). Monthly reports list all open orders ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 29) and first-loss as a sub-allocation ([ADR 008](/adr/008-funding-through-existing-payments.md)). Report identifiers go in forum posts: fixed top-up payment references [s6] provide no on-chain anchor (decision 22).
- **Monitoring responsibilities.** Lido monitors policy drift, approvals, budget burn, Safe changes and motions. The screening vendor covers depegs, protocol compromise and counterparty anomalies. Findings use existing notification and incident channels.
- **Funding alerts.** Flag top-ups outside days 1–10 except the seed, monthly totals above the posted shortfall, and motions after an objected top-up ([ADR 008](/adr/008-funding-through-existing-payments.md)). Flag every budget motion and check its stated event.

The phase-1 detector specification gives each detector an ID, watched state, severity and execution environment. Permission changes must link their corresponding detector changes. It starts with:

- Drift against the compiled artifact ([ADR 004](/adr/004-specifications-and-policy-as-data.md)); approval inventory; budget burn and every budget motion.
- Owner, threshold, module, guard and singleton changes on new Safes; singleton changes are critical ([ADR 010](/adr/010-pre-execution-screening.md)).
- Motion lifecycle, funding flags and emergency actions. Revoke-only actions page below transfers or swaps.
- Screening-guard detection extended to Safe v1.5.0 and the new instance.
- Open orders, idle orders-account tokens, market-relative fills and watch-tower posting; fallback-handler or domain-verifier changes are critical ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- First-loss balance, owner, module and singleton changes; every burn motion and first-loss-role action ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- Buffer versus floor (decision 27); new-product exposure versus protocol cap until unlock (decision 28); vendor-reported rule changes (decision 30).
- Monthly reports missing on day 8; fortnightly IPFS cap readings (decision 25), paging emergency on decision 24's trigger (decision 34).

## Options considered

- Custom preventive-cap adapter: rejected because `staticcall` cannot maintain a ledger, and a pre-state check can admit a cap-breaking transaction.
- DataBus report anchor: EM deferred it because the anchor would be off Ethereum.
- Manual budget figures: rejected because figures require attested computation.
- Fortnightly retunes (OD-56 A): replaced on 2026-10-09; roughly 26 annual motions changed most keys only slightly.
- Monthly retunes only for capped keys (OD-56 B): rejected.
- Fixed token approval ceilings with deposit-metered budgets: rejected because repeated approvals let spenders pull without budgeted deposits.
- One-deposit approval ceilings: rejected because they add token figures without stopping repeated approvals.
- DAO-only stops for worsening breaches: rejected under OD-29 because votes and Dual Governance delay exceed fixed-trigger response times.
- Committee-published cap readings: rejected under OD-32 because the party in breach could delay its own stop.
- Monthly-report-only triggers: rejected under OD-32 because a stop could wait about six weeks.
- A 14-day refill floor: rejected because conditions cannot compare refill and period, doubling monthly refill.
- Uncap Lido Lend after three calendar months (OD-04, OD-12): replaced by maturity criteria for all new Lido products (OD-41).
- Buffer checks only in periodic readings: rejected under OD-40 because intervening breaches would be missed.
- Third-party operating valuations: rejected under OD-44 because caps, top-ups and reports require pinned-block reproduction.
- Omit unpriced assets: replaced on 2026-10-13 (decisions 35 and 36). Prices must remain available, and sources can be wrong as well as missing.
- Unranked committee-chosen price sources: rejected because reports need a checkable rule.
- Zodiac as canonical figures/alerts source: rejected under OD-44 and decision 38; it displays Lido's outputs.
- Controls without a matrix: rejected under OD-39 because uncontrolled rules could remain invisible.

## Consequences

- Reports, including top-up reports, have no on-chain anchor (decision 22). Fixed payment references [s6] leave immutability to content addressing and the citing forum post: an informational control, not an Ethereum guarantee.
- Detective controls require human action. The mandate must name the responsible people.
- Defi-tech writes detectors; monitoring reviews them. The singleton alert must ship before deployment (OD-17). The guard detector already supports the committee's v1.3.0 Safe (OD-80).
- The committee must align vendor rules with positions. Each onboarding target needs alerts before enactment ([ADR 006](/adr/006-governance-through-easy-track-factories.md)).
- Per-key approvals cannot exceed a period's budget regardless of spender behaviour. Only budget motions add room. Approval consumes room even if its deposit later fails or is cancelled; refill restores it.
- A large approval still exposes funds up to budget. Same-transaction deposits and emergency zeroing constrain that exposure.
- Parallel motions can repeatedly reset a balance to its ceiling. Only the event rule and objection window limit frequency, so monitoring flags every motion.
- Since 2026-10-05, the kit meters spender-key approvals [s10] and enforces a 30-day period floor [s11]. Ceilings await attested figures; current budgets and fixed ceilings are stand-ins.
- Token-unit budgets drift from ratio caps with prices. No routine retune follows prices (decision 31). Published readings and, after lift, screening detect excess; a budget can become either too large or too small.
- Removing routine retunes avoids about 26 annual motions, each requiring committee signature, forum disclosure and objection. Remaining budget motions therefore receive individual alerts.
- The literal yield-bearing base includes directly held stablecoins. The illustrative allocation has none and therefore no yield-bearing position. A fixed budget can permit deposits beyond ratio headroom (decision 32); published readings detect this and the committee remediates.
- The committee can enlarge the base before a test by holding more stablecoins. Deposit-time checks and published history constrain this but do not prevent it.
- At deployment, Lido Lend's key needs a ceiling high enough for the eventual uncapped budget. Before unlock, its onboarding allowance and fortnightly check enforce the cap (decision 28). Governance can set only compiled keys; the enabling vote therefore includes token spare keys (decision 39).
- Unlock requires mandate-defined maturity criteria and a motion, not a date. The committee cannot loosen criteria alone; holders can object.
- Screening makes the vendor part of each checked rule's trust base. Written rules and controlled relaxations are required (decision 30).

The mandate text owes twelve changes:

- State new-product treatment in the own-product limit and protocol cap: Lido Lend remains capped until maturity and motion unlock. earnETH/earnUSD are not new (decision 28).
- Rename the illustrative balance's "USD-denominated" heading.
- Permit sUSDS funding, added on 2026-10-05 ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- State the price waterfall and late-report rule (decisions 23 and 35–37).
- Carry over March 2026 Earn first-loss terms, with the committee as executor and separate custody accessible only by burn motion or narrow redemption role (OD-21, OD-42, OD-60, OD-67; [ADR 008](/adr/008-funding-through-existing-payments.md)).
- Describe the independent emergency Safe: three-of-five, with two committee members, two Emergency Brakes members and one member of neither (OD-58; [ADR 005](/adr/005-account-graph-and-roles.md)).
- Limit emergency swap destinations to USDC, with USDT second (OD-26; [ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- State buffer detection, reporting, supported screening, display and the committee's restoration window (decision 27).
- Name CoW market, limit and TWAP orders, disclose no on-chain price bound, and defer Uniswap/1inch until minimum-output screening (OD-43).
- Reference the control matrix for each rule (decision 26).
- Name Voting as owner and the Agent as recovery destination ([ADR 005](/adr/005-account-graph-and-roles.md), decision 28).

Further requirements:

- Emergency must act on decision 34's fixed worsening-breach trigger; monitoring must page it without discretionary judgment.
- Monitoring publishes fortnightly readings independently of the committee; anyone can reproduce them at the same block (decision 25).
- Include all assets in vault value. Lower-level prices can still be wrong: top-up posts name prices below level 2, and top-ups wait if level 5 covers too much value (decision 36).
- The generator needs a second aggregator, pinned-block Chainlink/pool prices and recorded level-5 inputs.
- Zodiac display depends on the policy provider; canonical readings and alerts remain Lido's. Lido builds them if the provider declines (decisions 29 and 38).
- Late reports stop top-ups. sUSDS funding immediately counts against the literal-base yield-bearing cap.

## Confirmation

- INV-008, INV-011 and INV-012 in the [invariants](/specs/invariants.md).
- Kit tests: budget consumption at the approval and refill [s3]; per-key ceilings and the refill floor [s4]; approvals bounded by key or ceiling, and an unlimited approval refused [s5].

## Reversal conditions

- A breach that detection misses, or that remediation does not close within the mandate's window.
- A report that cannot be reproduced from its published data.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

The committee's valuation policy owes the band of level 2 and the level-5 share (decision 37). Owed: the screening vendor's answer on which rules it can check before execution, and the policy provider's answer on the requirement list.
