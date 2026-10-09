---
type: Decision
title: "ADR 009: Budgets, exposure caps, reporting and monitoring"
description: Every mandate rule gets a control on each layer that can carry it — on-chain policy, screening, monitoring, display — mapped in a control matrix; exposure caps and the liquidity buffer are detected, reported on IPFS, screened where the vendor can check them, and shown in the Zodiac UI from Lido's readings; a new Lido product stays in the protocol cap until it matures and a motion unlocks it; budgets derive from the mandate by attested computation, are set once, and change by motion only after an event; detectors run in two monitoring estates; the committee owns remediation.
tags: [budgets, caps, reporting, monitoring, mandate]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-09T06:40:00Z
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

- The permission layer cannot see valuation. It can bound a call, not a portfolio ratio [s2].
- A budget is a consumable allowance per key. A call consumes it only on success, and it refills per elapsed period up to a maximum [s3].
- A budget counts token units, so assets with different decimals need different keys [s2].
- Before OD-08, the kit capped each approval at a fixed amount and spent the budget at the deposit [s7][s8]. A spender can pull what it is approved for without any deposit call, so that budget did not bound what a spender takes.
- Before OD-08, the kit's governance permission on budgets pinned the key and passed every other value [s9]. Ceilings per key and a period floor can be expressed with native conditions [s4].

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

EM gave the reason on 2026-10-09 [s1]: the caps rest mostly on off-chain monitoring and the screening guard, because value data is asynchronous. More on-chain work adds little value, because prices drift with volatility and market stress whatever the cadence.

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

- **Caps are detective.** The mandate must say that exposure caps are enforced by measurement, publication and remediation, not by reverting a transaction. Where the screening vendor can check a rule before execution, it refuses an operator transaction that breaks the rule; the rule stays detective for the emergency path and for moves in price.
- **The liquidity buffer.** It counts the stablecoins that the Asset Safe holds directly, and sUSDS, which redeems at once. Earn shares and tokens in the orders account do not count. Monitoring checks it continuously and warns at a margin above the floor; every report shows it; the Zodiac UI shows it. Its figure, one month of baseline spend, comes from the attested computation.
- **Which caps need prices.** A cap within one denomination needs balances only. A cap on a liquid staking token or on a yield-bearing asset needs on-chain rates. A cap across classes needs a market oracle.
- **Budget shape.** Monthly flow equals the stock cap for each key. Exits are unbudgeted, so a tighter flow would throttle re-entry after a defensive exit. Keys for Lido products have no ratio to bound, because the whole vault may sit in them. They bound only the amount that can move in one month, which is the whole mandate. That is a weak control, and the LIP must say so.
- **What a budget does (decision 31).** A key is a speed limit: it bounds how much the operator can approve to one spender in a month. It does not track a cap or a price. The caps are measured and published (decisions 25 and 33), the screening guard can check a cap before execution once the launch cap lifts, and the committee remediates a breach.
- **Events.** A budget motion follows one of these events, and its forum post names it: a new TM Floor Value; a spender onboarded by motion, whose motion sets its key; a new Lido product's unlock at maturity (decision 28); or the lift of the capped launch ([ADR 010](/adr/010-pre-execution-screening.md) decision 22). A price move is not an event: budgets do not follow prices (EM's reason for decision 31).
- **Yield-bearing keys (decision 32).** The yield-bearing key gets a fixed monthly figure from the attested computation, like the other keys. The headroom rule, the cap's share less the current holding, no longer sets it, so the key needs no holdings snapshot.
- **New Lido products.** Lido Lend's key stays within the protocol cap from its onboarding until a budget motion unlocks it after it matures. The unlock motion raises the key to the bound of an own product, and its forum post states which criteria the product meets (decision 28). The earnETH and earnUSD keys are own-product keys from the start.
- **The Zodiac UI.** The requirement list for the policy provider: the value per account, asset and protocol, with the first-loss Safe as a sub-allocation; the buffer against its floor; each cap against its limit, with warnings; the budget left on each key; open orders; pending motions and their deadlines; the screening guard's state; and a warning before signing when a transaction would cross a limit. The canonical figures are Lido's published readings, from the report generator and monitoring. A live value, for example from a third-party portfolio service, is labelled as indicative and never feeds a cap, a top-up or a report.
- **Budget figures.** The attested computation ran on 2026-09-22 with an independent attester and pinned inputs. It ran again on 2026-10-02 with the literal base. After decision 32, the yield-bearing key needs a fixed figure, which the computation produces when the mandate is approved. The inputs include unapproved mandate terms, so the results enter this repository only after the mandate is approved.
- **Approvals.** Each approval branch names one spender and spends that spender's key, so a token approved to two spenders draws on two keys. On the Asset Safe, the operator approves only what it deposits, in the same transaction, so no approval stands between transactions. The orders account's approvals of CoW's vault relayer stand; a DAO vote sets them, and no role can raise one ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). The DAI and USDS approvals to Sky's DAI–USDS converter carry the same fixed ceiling as the stETH approval to the wstETH contract (decision 14; [ADR 011](/adr/011-launch-scope.md)). The vault does not approve Lido's withdrawal queue ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 27).
- **The budget factory.** It builds one branch per key, so each key has its own ceiling on `balance`, `maxRefill` and `refill`, and every branch bounds `period` below by 30 days. A kit test shows this shape with native conditions [s4].
- **Reports.** The payload is on IPFS and holds balances, positions, exposures, each ratio with its numerator and denominator, and the price source with its timestamp. The standard top-up factory writes a fixed payment reference, so a top-up cannot carry the report's identifier in it [s6]. The identifier goes in the report's forum post, and there is no on-chain anchor (decision 22). Reports show the first-loss Safe as a sub-allocation of the vault ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- **Monitoring.** The Lido on-chain monitoring carries policy drift, the approval inventory, budget burn, module, owner and singleton changes on the new Safes, and motion events. For funding it flags a top-up motion outside days 1 to 10 of a month, apart from the seed; a month's top-ups above the posted shortfall; and any top-up motion after an objected one ([ADR 008](/adr/008-funding-through-existing-payments.md)). For budgets it flags every budget motion, and checks that its forum post names an event. The screening vendor carries depegs, protocol compromise and counterparty anomalies. Findings route into the existing notification and incident channels.
- **The detector specification.** A monitoring specification in this repository lists each detector with an ID, what it watches, its severity and where it runs (phase 1). A pull request here that changes a watched permission links the matching detector change. The list starts from: policy drift against the compiled policy artifact ([ADR 004](/adr/004-specifications-and-policy-as-data.md)); the approval inventory; budget burn and every budget motion; owner, threshold, module, guard and singleton changes on the new Safes, the singleton change as critical ([ADR 010](/adr/010-pre-execution-screening.md)); motion lifecycle; the funding flags; emergency actions, graded so that a revoke-only action pages lower than a transfer or a swap; the screening guard, extended to Safe v1.5.0 and the new instance; the orders account, for open orders, tokens left in it, each fill against a market price, any change of its fallback handler or domain verifier as critical, and whether CoW's watch-tower posts its conditional orders ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); the first-loss Safe, for any change of its balance, owners, modules or singleton ([ADR 008](/adr/008-funding-through-existing-payments.md)); the liquidity buffer against its floor (decision 27); each new Lido product's exposure against the protocol cap until its unlock (decision 28); a change of the screening vendor's rules, where the vendor reports one (decision 30); a monthly report still missing on day 8; and the cap reading of each fortnightly snapshot, published to IPFS (decision 25), with an alert that pages the Emergency Brakes multisig when the trigger of decision 24 is met.

## Options considered

- Preventive caps through a custom condition adapter. Not chosen: the adapter is a static call, so it cannot keep a ledger, and a check of the current state admits a transaction that breaches the cap right after the check.
- DataBus as the report anchor. Not chosen by EM for now. It is not on Ethereum, so the anchor would sit on another chain.
- Budgets entered by hand. Not chosen: a financial figure comes only from an attested computation.
- Every key retuned every two weeks (OD-56 A), the design until 2026-10-09. Replaced by EM (OD-56): it needed about 26 budget motions a year, most of them on keys that a retune barely changes.
- Only the keys that a cap bounds retuned, once a month, at the monthly report's snapshot (OD-56 B). Not chosen by EM.
- A fixed approval ceiling per token, sized to the key's budget ceiling, with deposits still spending the budget. Not chosen by EM: a spender could pull each new approval without a deposit, and the budget would never bound it.
- A smaller fixed ceiling of one deposit. Not chosen: it adds a figure per token and still lets repeated approvals feed a spender.
- Only a DAO vote pauses the operator for a cap breach that gets worse. Not chosen by EM (OD-29): a vote and its Dual Governance delay are slower than a fixed trigger.
- The committee publishes the fortnightly cap reading. Not chosen by EM (OD-32): the party in breach would publish its own breach, and a late post would delay the stop.
- The trigger uses the monthly reports only. Not chosen by EM (OD-32): the stop could come about six weeks after the breach.
- A refill-period floor of 14 days, to match the retune. Not chosen: the conditions cannot compare the refill with the period, so it would double the refill per month.
- Lido Lend in the protocol cap for three calendar months from its launch, then uncapped (OD-04, OD-12). Replaced by EM (OD-41): maturity, not a date, unlocks a new product, and the rule covers every new Lido product.
- The buffer only in the periodic readings. Not chosen by EM (OD-40): a breach between two readings would go unseen.
- A third-party portfolio value as the operating figure. Not chosen by EM (OD-44): it cannot be reproduced at a pinned block, so it cannot carry a cap, a top-up or a report.
- Controls added rule by rule, without a matrix. Not chosen by EM (OD-39): a rule with no control would stay invisible.

## Consequences

- No report has an on-chain anchor, a top-up's report included (decision 22). The top-up factory also fixes the payment reference [s6]. A report's immutability rests on content addressing and the forum post that cites it. That is enough for an informational control. It is not an Ethereum guarantee.
- Every detective control ends at a person. The mandate must name them.
- Each detector change involves two teams: defi-tech writes it and the monitoring team reviews it. The guard detector's Safe v1.5.0 support and the singleton alert of OD-17 must ship before the operator Safe is deployed.
- The committee keeps the vendor-side rules in step with the vault's positions, because every onboarding motion needs alerting for its new target before it is enacted ([ADR 006](/adr/006-governance-through-easy-track-factories.md)).
- Approvals per key per period cannot exceed the budget, whatever a spender does. Only a budget motion can add room.
- An approval spends budget even if its deposit then fails or is cancelled. The room on that key comes back at the next refill.
- One large approval is still a standing exposure up to the budget. The same-transaction practice and the emergency role's power to zero approvals bound it.
- A budget motion can reset a key's balance to its ceiling. Only the event rule and the objection window limit how often, because motions can run in parallel. Monitoring flags every budget motion.
- Since 2026-10-05 the kit meters each approval on its spender's key [s10], and its governance permission bounds the period below by 30 days [s11]. The per-key ceilings wait for the attested figures. The kit's budgets and fixed ceilings are dry-run stand-ins.
- Budgets drift with price, because caps are ratios and budgets are token units. No routine retune absorbs the drift (decision 31). A key can allow more than its cap's room after a price rise, or less after a fall. The published reading and, once the launch cap lifts, the screening guard catch a breach; no budget motion follows the price.
- About 26 budget motions a year, each signed by the operator Safe, disclosed on the forum and open to objection, are no longer needed. A budget motion now stands out, so monitoring flags each one.
- Under the literal base, a yield-bearing stablecoin has room only next to stablecoins that the vault holds directly. The illustrative allocation holds none, so it plans no yield-bearing position. With a fixed yield-bearing budget (decision 32), the operator can deposit past the cap's room within a month; the published reading catches it, and the committee remediates.
- The committee can enlarge the base before a test by holding more stablecoins. The test at deposit time and the published history limit this. They do not prevent it.
- The policy must hold the Lido Lend budget key, with a ceiling that allows the uncapped budget, from deployment. Otherwise the cap could not lift by motion alone. Until the unlock motion, the allowance set by the onboarding motion and the fortnightly test hold the cap (decision 28).
- A new product's unlock waits for its criteria and a motion, not for a date. The criteria live in the mandate, so the committee cannot loosen them alone, and LDO holders can object to each unlock.
- Where screening checks a rule before execution, the screening vendor is part of the trust base for that rule. The vendor's rules therefore live as a written list here, and a relaxation of one is a change under control (decision 30).
- The display in the Zodiac UI depends on the policy provider. The canonical figures do not: they come from Lido's own readings, and Lido builds the display if the provider declines (decision 29).
- The mandate text owes eleven changes: the own-product limit and the protocol cap must state that a new Lido product, Lido Lend first, stays in the protocol cap until it meets the maturity criteria and a motion unlocks it, and that earnETH and earnUSD are not new (decision 28); the illustrative balance renames its "USD-denominated" heading; the funding rules must allow sUSDS, which EM added on 2026-10-05 ([ADR 008](/adr/008-funding-through-existing-payments.md)); the reporting section states the price rule and the late-report rule (decision 23), so that tokenholders can hold the committee to them; the legacy section takes over the first-loss terms of the March 2026 Earn allocation, and the first-loss shares sit in a dedicated first-loss Safe that no role can reach (OD-21, OD-28, OD-42, [ADR 008](/adr/008-funding-through-existing-payments.md)); the emergency section describes the emergency Safe as the committee's signers at two of seven, the technical role of the Emergency Brakes multisig, and a DAO vote as the path that is independent of the committee (OD-30, [ADR 005](/adr/005-account-graph-and-roles.md)); the emergency swap goes into USDC, or into USDT as the second destination (OD-26, [ADR 007](/adr/007-swapping-through-an-orders-account.md)); the liquidity buffer states its controls: the detector, the report line, screening where the vendor can check it, the display, and the committee's window to restore it (decision 27); the swap section names CoW's market, limit, TWAP and stop-loss orders through the orders account, says that nothing on chain bounds their price, and makes Uniswap and 1inch wait for a screening check of the output (OD-43); and the control section says how each rule is kept, by reference to the control matrix (decision 26).
- The Emergency Brakes multisig acts on a financial signal when a cap breach gets worse (decision 24). The trigger is fixed, so the multisig needs no financial judgment. Monitoring must page it when the trigger is met.
- The trigger does not depend on the committee that is in breach: monitoring computes and publishes the fortnightly reading, and anyone can run the report generator again at the same block (decision 25).
- Leaving an unpriced asset out understates the vault value, which could open a top-up that the vault does not need. Decision 20 forbids a top-up on such a snapshot.
- A late monthly report stops top-ups, so the vault cannot be refilled for long without reporting.
- A top-up in sUSDS counts at once against its yield-bearing cap under the literal base.

## Confirmation

- INV-008, INV-011 and INV-012 in the [invariants](/specs/invariants.md).
- Kit tests: budget consumption at the approval and refill [s3]; per-key ceilings and the refill floor [s4]; approvals bounded by key or ceiling, and an unlimited approval refused [s5].

## Reversal conditions

- A breach that detection misses, or that remediation does not close within the mandate's window.
- A report that cannot be reproduced from its published data.

## Open questions

None open. OD-08, OD-12, OD-13 and OD-14 were decided on 2026-10-02 and 2026-10-05, OD-39, OD-40, OD-41, OD-44 and OD-45 on 2026-10-06, and OD-56 on 2026-10-09. Owed: the screening vendor's answer on which rules it can check before execution, and the policy provider's answer on the requirement list.
