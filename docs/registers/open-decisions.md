---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's inputs
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30
---

# Open decisions

EM decides every item until the Treasury Management Committee takes over as acceptor. An item that constrains the operator also needs a verification from the Emergency Brakes multisig when its ADR is accepted ([ADR 002](/adr/002-decision-and-review-process.md)) [s1]. An agent recommendation is a recommendation, not a decision. Items OD-01 to OD-06 were raised in the design interview on 2026-09-22 and not answered before the repository work started [s1].

| ID | Question | Closes in | Agent recommendation | Decides |
|---|---|---|---|---|
| OD-01 | Where does the screening hook live? Route A is a module guard on the Asset Safe: it needs Safe v1.5.0 and screens the operator and governance. Route B is a transaction guard on a dedicated operator Safe: it works from Safe v1.3.0 and screens the operator only. | [ADR 010](/adr/010-pre-execution-screening.md) | Route B, and keep the two-modifier split either way | EM; constrains the operator |
| OD-02 | If route B, does the Asset Safe stay on v1.5.0 or move to v1.4.1? | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 010](/adr/010-pre-execution-screening.md) | None yet. v1.5.0 keeps the module-guard option and matches the harness. v1.4.1 avoids being the first v1.5.0 in the Lido estate | EM; constrains the operator |
| OD-03 | What share of US-dollar assets is the denominator of the yield-bearing cap? The mandate does not fix it. The computation of 2026-09-22 used the split in the mandate's illustrative balance. | Mandate text; [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Fix the share in the mandate text, not in a script | EM with the committee |
| OD-04 | Does Lido Lend count against the per-protocol cap, or is it an uncapped own product? The computation took the capped reading. | Mandate text; [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), [ADR 011](/adr/011-launch-scope.md) | Settle it in the mandate text. The capped reading is the conservative one | EM with the committee |
| OD-05 | Order duration, margin and price tolerance for each swap instance, by pair class. | [ADR 007](/adr/007-swapping-through-stonks.md), [parameters](/registers/parameters.md) | Copy the live split: 1800 s, 110 bp and 550 bp for volatile pairs; 1800 s, 30 bp and 150 bp for stablecoin pairs [s2] | EM; constrains the operator |
| OD-06 | The period and the limit of the funding registry. | [ADR 008](/adr/008-funding-through-existing-payments.md) | Match the period to the mandate's monthly top-up rule. Size the limit by attested computation. An existing registry uses a six-month period [s2] | EM; constrains the operator |
| OD-07 | The screening vendor's guard: does it exist, who writes it, who audits it, and may the vault launch before it exists? EM: "They must write it even they don't have it yet; we can add it later." | [ADR 010](/adr/010-pre-execution-screening.md) | Settle it directly with the vendor. Launch with the guard slot empty only if EM confirms that reading of "add it later", because on-chain blocking is a hard requirement | EM |
| OD-08 | The approval ceiling per token and the budget refill-period floor. | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | A ceiling of one deposit, not one month of deposits, and a 30-day floor. Values by attested computation | EM; constrains the operator |
| OD-09 | How does an immediate removal work? EM asked that the removal templates skip the objection window. Easy Track sets one global duration when a motion is created [s2]. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Immediate de-scoping stays an emergency-role action. Easy Track removal stays the routine path. Do not change the global duration or run a second Easy Track | EM; constrains the operator |
| OD-10 | Which team owns the repository in CODEOWNERS? | `.github/CODEOWNERS` | Set it before the first external contributor joins | EM |
| OD-11 | Do the shared payment ACL parameters stay unchanged, with seeding only in USDC, USDT, DAI, stETH or ETH? | [ADR 008](/adr/008-funding-through-existing-payments.md) | Yes. Every Easy Track payment setup shares the permission, and a change rewrites all 22 entries by vote [s2] | EM; constrains the operator |
| OD-12 | Confirm two recorded readings of setup answers: the vision answer, and the answer about the acceptor that left the rest of the review process unchanged. | [Decision log](/registers/decision-log.md), [ADR 002](/adr/002-decision-and-review-process.md) | Confirm both | EM |
| OD-13 | Who writes and maintains the vault's detectors in each monitoring estate? | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | The committee specifies the rules. The team that runs each estate implements them | EM |
| OD-14 | Reporting operations: who publishes, on what schedule, what happens when a price is stale or missing, and who answers for a late report? | Mandate text; [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Name all four in the mandate | EM with the committee |
| OD-15 | How do the committee and the Emergency Brakes multisig record a verification of a page? | [ADR 002](/adr/002-decision-and-review-process.md) | A member commits the `verified` entry through a reviewed pull request, and the entry links the body's decision record | EM |
| OD-16 | The policy data format and the compiler toolchain. | [ADR 004](/adr/004-specifications-and-policy-as-data.md) | Decide in the phase 1 specification | EM |
| OD-17 | Incident-history diligence on Safe v1.5.0. EM asked for "a dd about audits and incident history". The audits are recorded; the incident history is not. | [ADR 010](/adr/010-pre-execution-screening.md) | Record it before ADR 010 is accepted | Evidence owed; EM decides |
| OD-18 | Does the Stonks price source cover every pair in the instance list? | [ADR 007](/adr/007-swapping-through-stonks.md) | Check each pair on a fork before the instance list is final | Evidence owed; EM decides |
