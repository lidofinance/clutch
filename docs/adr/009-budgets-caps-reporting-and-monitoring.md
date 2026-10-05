---
type: Decision
title: "ADR 009: Budgets, exposure caps, reporting and monitoring"
description: Exposure caps are detective controls with reports on IPFS; budgets derive from the mandate by attested computation and retune every two weeks; detectors run in two monitoring estates; the committee owns ratio-breach remediation.
tags: [budgets, caps, reporting, monitoring, mandate]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:58:30Z
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

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

- **Caps are detective.** The mandate must say that exposure caps are enforced by measurement, publication and remediation, not by reverting a transaction.
- **Which caps need prices.** A cap within one denomination needs balances only. A cap on a liquid staking token or on a yield-bearing asset needs on-chain rates. A cap across classes needs a market oracle.
- **Budget shape.** Monthly flow equals the stock cap for each key. Exits are unbudgeted, so a tighter flow would throttle re-entry after a defensive exit. Keys for Lido products have no ratio to bound, because the whole vault may sit in them. They bound only the amount that can move in one month, which is the whole mandate. That is a weak control, and the LIP must say so.
- **Yield-bearing keys.** A yield-bearing key gets the headroom: the cap's share of the stablecoins plus yield-bearing stablecoins held directly, minus the current holding of that token, and never less than zero. Converting a stablecoin into a yield-bearing stablecoin leaves the base unchanged. The headroom depends on what the vault holds, so each fortnightly retune derives it from a holdings snapshot read at a pinned block. Without a snapshot, the key gets no budget.
- **Lido Lend key.** The protocol cap applies until three calendar months after Lido Lend goes live. From that date the key is bounded by the mandate size, like every own-product key. The months count from Lido Lend's mainnet launch (decision 16).
- **Budget figures.** The attested computation ran on 2026-09-22 with an independent attester and pinned inputs. It ran again on 2026-10-02 with the literal base. The yield-bearing key now gets no figure until the first retune after seeding, and the other keys are unchanged. The inputs include unapproved mandate terms, so the results enter this repository only after the mandate is approved.
- **Approvals.** Each approval branch names one spender and spends that spender's key, so a token approved to two spenders draws on two keys. The operator approves only what it deposits, in the same transaction, so no approval stands between transactions. The DAI and USDS approvals to Sky's DAI–USDS converter and the stETH approval to Lido's withdrawal queue carry the same fixed ceiling as the stETH approval to the wstETH contract (decision 14; [ADR 011](/adr/011-launch-scope.md); [ADR 007](/adr/007-swapping-through-stonks.md)).
- **The budget factory.** It builds one branch per key, so each key has its own ceiling on `balance`, `maxRefill` and `refill`, and every branch bounds `period` below by 30 days. The kit test shows one shared ceiling only [s4].
- **Reports.** The payload is on IPFS and holds balances, positions, exposures, each ratio with its numerator and denominator, and the price source with its timestamp. The standard top-up factory writes a fixed payment reference, so a top-up cannot carry the report's identifier in it [s6]. The identifier goes in the report's forum post, and there is no on-chain anchor (decision 22). Reports show the first-loss Earn shares apart from the vault's other Earn shares ([ADR 008](/adr/008-funding-through-existing-payments.md)).
- **Monitoring.** The Lido on-chain monitoring carries policy drift, the approval inventory, budget burn, module, owner and singleton changes on the three new Safes, and motion events. For funding it flags a top-up motion outside days 1 to 10 of a month, apart from the seed; a month's top-ups above the posted shortfall; and any top-up motion after an objected one ([ADR 008](/adr/008-funding-through-existing-payments.md)). For budgets it flags a second budget motion on the same key within 14 days. The screening vendor carries depegs, protocol compromise and counterparty anomalies. Findings route into the existing notification and incident channels.
- **The detector specification.** A monitoring specification in this repository lists each detector with an ID, what it watches, its severity and where it runs (phase 1). A pull request here that changes a watched permission links the matching detector change. The list starts from: policy drift against the compiled policy artifact ([ADR 004](/adr/004-specifications-and-policy-as-data.md)); the approval inventory; budget burn and repeated budget motions; owner, threshold, module, guard and singleton changes on the three new Safes, the singleton change as critical ([ADR 010](/adr/010-pre-execution-screening.md)); motion lifecycle; the funding flags; emergency actions, graded so that a revoke-only action pages lower than a transfer or a swap; the screening guard, extended to Safe v1.5.0 and the new instance; the Stonks price router, for a vault token out of sync, a new aggregator in Chainlink's registry for a vault token, and any change of the router's settings ([ADR 007](/adr/007-swapping-through-stonks.md)); the first-loss Earn shares, for an earnETH or earnUSD balance below the first-loss amount and any redeem request that would cross it ([ADR 008](/adr/008-funding-through-existing-payments.md)); and swap-instance orders and stranded balances; and a monthly report still missing on day 8.

## Options considered

- Preventive caps through a custom condition adapter. Not chosen: the adapter is a static call, so it cannot keep a ledger, and a check of the current state admits a transaction that breaches the cap right after the check.
- DataBus as the report anchor. Not chosen by EM for now. It is not on Ethereum, so the anchor would sit on another chain.
- Budgets entered by hand. Not chosen: a financial figure comes only from an attested computation.
- A fixed approval ceiling per token, sized to the key's budget ceiling, with deposits still spending the budget. Not chosen by EM: a spender could pull each new approval without a deposit, and the budget would never bound it.
- A smaller fixed ceiling of one deposit. Not chosen: it adds a figure per token and still lets repeated approvals feed a spender.
- Only a DAO vote pauses the operator for a cap breach that gets worse. Not chosen by EM (OD-29): a vote and its Dual Governance delay are slower than a fixed trigger.
- A refill-period floor of 14 days, to match the retune. Not chosen: the conditions cannot compare the refill with the period, so it would double the refill per month.

## Consequences

- No report has an on-chain anchor, a top-up's report included (decision 22). The top-up factory also fixes the payment reference [s6]. A report's immutability rests on content addressing and the forum post that cites it. That is enough for an informational control. It is not an Ethereum guarantee.
- Every detective control ends at a person. The mandate must name them.
- Each detector change involves two teams: defi-tech writes it and the monitoring team reviews it. The guard detector's Safe v1.5.0 support and the singleton alert of OD-17 must ship before the operator Safe is deployed.
- The committee keeps the vendor-side rules in step with the vault's positions, because every onboarding motion needs alerting for its new target before it is enacted ([ADR 006](/adr/006-governance-through-easy-track-factories.md)).
- Approvals per key per period cannot exceed the budget, whatever a spender does. Only a budget motion can add room.
- An approval spends budget even if its deposit then fails or is cancelled. The room on that key comes back at the next refill or retune.
- One large approval is still a standing exposure up to the budget. The same-transaction practice and the emergency role's power to zero approvals bound it.
- A budget motion can reset a key's balance to its ceiling. Only the fortnightly procedure and the objection window limit how often, because motions can run in parallel. Monitoring flags a second budget motion on a key within 14 days.
- Since 2026-10-05 the kit meters each approval on its spender's key [s10], and its governance permission bounds the period below by 30 days [s11]. The per-key ceilings wait for the attested figures. The kit's budgets and fixed ceilings are dry-run stand-ins.
- Budgets drift with price, because caps are ratios and budgets are token units. The two-week retune absorbs the drift.
- Under the literal base, a yield-bearing stablecoin has room only next to stablecoins that the vault holds directly. The illustrative allocation holds none, so it plans no yield-bearing position.
- The committee can enlarge the base before a test by holding more stablecoins. The test at deposit time and the published history limit this. They do not prevent it.
- The policy must hold the Lido Lend budget key, with a ceiling that allows the uncapped budget, from deployment. Otherwise the cap could not lift by motion alone. During the first three months, the allowance set by the onboarding motion and the fortnightly test hold the cap.
- The mandate text owes eight changes: the own-product limit and the protocol cap must state the three-month rule for Lido Lend; the illustrative balance renames its "USD-denominated" heading; the funding rules must allow sUSDS, which EM added on 2026-10-05 ([ADR 008](/adr/008-funding-through-existing-payments.md)); the reporting section states the price rule and the late-report rule (decision 23), so that tokenholders can hold the committee to them; the legacy section takes over the first-loss terms of the March 2026 Earn allocation, and neither the operator nor the emergency role redeems the first-loss shares (OD-21, OD-28, [ADR 008](/adr/008-funding-through-existing-payments.md)); the emergency section describes the emergency Safe as the committee's signers at two of seven, the technical role of the Emergency Brakes multisig, and a DAO vote as the path that is independent of the committee (OD-30, [ADR 005](/adr/005-account-graph-and-roles.md)); and the emergency swap goes into USDC, or into USDT as the second destination (OD-26, [ADR 007](/adr/007-swapping-through-stonks.md)).
- The Emergency Brakes multisig acts on a financial signal when a cap breach gets worse (decision 24). The trigger is fixed, so the multisig needs no financial judgment. Monitoring must page it when the trigger is met.
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

None open. OD-08, OD-12, OD-13 and OD-14 were decided on 2026-10-02 and 2026-10-05.
