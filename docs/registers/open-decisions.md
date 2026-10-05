---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T12:12:12Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's inputs
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30
  - id: s3
    resource: /research/funding-registries-2026-10-02.md
    title: Easy Track funding registries, 2026-10-02
---

# Open decisions

EM decides every item until the Treasury Management Committee takes over as acceptor. An item that constrains the operator also needs a verification from the Emergency Brakes multisig when its ADR is accepted ([ADR 002](/adr/002-decision-and-review-process.md)) [s1]. An agent recommendation is a recommendation, not a decision. Items OD-01 to OD-06 were raised in the design interview on 2026-09-22 and not answered before the repository work started [s1]. Closed items move to the table at the end.

| ID | Question | Closes in | Agent recommendation | Decides |
|---|---|---|---|---|
| OD-16 | The policy data format and the compiler toolchain. | [ADR 004](/adr/004-specifications-and-policy-as-data.md) | Decide in the phase 1 specification | EM |
| OD-17 | Incident-history check on Safe v1.5.0. EM asked for "a dd about audits and incident history". Both new Safes now use v1.5.0. The audits are recorded; the incident history is not. If the vendor does not confirm v1.5.0 support, the operator Safe uses v1.4.1, and this check covers the Asset Safe only. | [ADR 010](/adr/010-pre-execution-screening.md) | Record it before ADR 005 and ADR 010 are accepted | Evidence owed; EM decides |
| OD-20 | Who configures the swap pricing before launch, and when? The vault's pairs need a new converter instance with the vault's token lists, and oracle-router feeds for wstETH, WETH, USDC, USDT, DAI and USDS. | [ADR 007](/adr/007-swapping-through-stonks.md) | Put the converter and the feeds in the enabling vote. Verify every pair on a fork before the instance list is final | EM, then the DAO |
| OD-21 | How do the legacy investments that the mandate carries over move into the vault, and who holds them now? The mandate lists EarnETH, EarnUSD and Twyne, and they reduce the seed. The Agent and the committee's Safe hold no shares of the current earnETH and earnUSD vaults [s3]. | [ADR 008](/adr/008-funding-through-existing-payments.md) | Find the holder first. A position held for the DAO moves in the enabling vote, because the payment permission denies these tokens [s2]. Size the seed after the move | EM |
| OD-22 | Should DAI earn, or stay idle? DAI can seed the vault, but no operator permission moves it: it is not in the rebalancing set ([ADR 007](/adr/007-swapping-through-stonks.md)), sDAI is out of scope, and no DAI-to-USDS converter is in scope ([ADR 011](/adr/011-launch-scope.md)). Only recovery can move it. | [ADR 011](/adr/011-launch-scope.md) | If DAI should earn, add the DAI-to-USDS converter as a conversion: it needs no price and no swap instance. If DAI is the liquidity buffer, say so in ADR 011 | EM; constrains the operator |
| OD-23 | When does the agent get its own GitHub identity? Until it does, the agent pushes under the creator's git identity, and another member of the owning team must approve. | [ADR 003](/adr/003-agent-operating-model.md) | Deferred by EM on 2026-10-05: "later". Give it write access to branches only, so that EM can approve agent work as a code owner | EM |

## Closed

| ID | Question | Closed | Outcome |
|---|---|---|---|
| OD-01 | Where does the screening hook live? | 2026-10-02 | EM: "Option 1: dedicated operator Safe with its own guard, also the trusted caller." Recorded in [ADR 010](/adr/010-pre-execution-screening.md) [s1] |
| OD-02 | Which Safe version do the two new Safes use? | 2026-10-02 | EM: v1.5.0 for both, "only if [the screening vendor] guard is compat with v1.5.0". The check of 2026-10-02 found it compatible ([research note](/research/safe-v150-guard-compatibility-2026-10-02.md)) [s1] |
| OD-19 | The operator Safe's threshold | 2026-10-02 | EM: 4 of 7 [s1] |
| OD-03 | What is the base of the yield-bearing cap? | 2026-10-02 | EM: "Literal (Block A)": the top-4 stablecoins plus the yield-bearing stablecoins held directly. Own-product and protocol positions are outside the base ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) [s1] |
| OD-04 | Does Lido Lend count against the protocol cap? | 2026-10-02 | EM: capped for the first three months, then uncapped as a Lido product ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) [s1] |
| OD-05 | How are the swap instances configured? | 2026-10-02 | EM: the operator Safe and the emergency Safe manage their families; the live values are copied by pair class; instances come from the standard factory, so recovered tokens go to the treasury ([ADR 007](/adr/007-swapping-through-stonks.md)) [s1] |
| OD-18 | Does the Stonks price source cover every pair? | 2026-10-02 | Answered by evidence: no. The deployed stack prices only stETH and LDO. The configuration moved to OD-20 ([research note](/research/stonks-instances-2026-10-02.md)) |
| OD-06 | The period and the limit of the funding registry | 2026-10-02 | EM: "1. One month", then "A" after a challenge game: two registries, stablecoins and stETH, each with a limit of one TM Floor Value per month; stETH at a pinned Coingecko price; the objection is the control and the registry is the backstop ([ADR 008](/adr/008-funding-through-existing-payments.md)) [s1] |
| OD-07 | The screening vendor's guard: the agreement, the build, the confirmations and the announcement | 2026-10-02 | EM: "Q1. 1.", "Q2. A", "Q3. 1.", "Q4. 1, [the screening vendor]": the operator role only after the guard enforces; no standing approvals; the build that the Lido multisigs run, with 10-day timelocks; written v1.5.0 support as a gate, with v1.4.1 as the fallback; the redaction ends when the mandate is posted, with the vendor's consent ([ADR 010](/adr/010-pre-execution-screening.md)) [s1] |
| OD-08 | The approval ceiling per token and the budget refill-period floor | 2026-10-02 | EM: "Q1. 1. B" and "Q2. 1. 30 days": an approval to a protocol spender spends the budget of the key it serves, and deposits no longer do; the stETH approval to the wstETH contract keeps a fixed ceiling of one TM Floor Value in stETH; the refill-period floor is 30 days ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) [s1] |
| OD-09 | How does an immediate removal work? | 2026-10-05 | EM: "1. Q1: B" and "Q2: 3": the two removal templates are dropped, and every removal is the emergency Safe's immediate revoke, posted on the forum afterwards; no DAO-scoped role keys, so the toggle factory leaves the design and the revoke reaches every operator permission ([ADR 006](/adr/006-governance-through-easy-track-factories.md)) [s1] |
| OD-10 | Which team owns the repository in CODEOWNERS? | 2026-10-05 | EM: `@lidofinance/defi-tech` owns the repository and `@lidofinance/review-gh-workflows` owns GitHub CI, with no new team; a branch rule on `main` with code-owner review and at least one approval by someone other than the pull request's creator; the agent's own identity later, OD-23 ([ADR 003](/adr/003-agent-operating-model.md)) [s1] |
| OD-11 | Do the shared payment ACL parameters stay unchanged, which token list does the stablecoin registry use, and is ETH a funding asset? | 2026-10-05 | EM: "Q1. 2", "Q2. 2 (add USDS and sUSDS)", "Q3. 1": a DAO vote adds USDS to the shared payment permission; the stablecoin registry uses the shared token list with USDS added; ETH is not a funding asset ([ADR 008](/adr/008-funding-through-existing-payments.md)) [s1] |
| OD-24 | The ceiling per USDS payment in the rewritten payment permission | 2026-10-05 | EM: "1. OD-24: 2,000,000": the same as DAI, USDC, USDT and sUSDS ([ADR 008](/adr/008-funding-through-existing-payments.md)) [s1] |
| OD-12 | Confirm four recorded readings: the vision answer, the acceptor answer, the start of Lido Lend's capped months, and who signs the vendor agreement | 2026-10-05 | EM confirmed the first three. The Lido-side signer is the party that already holds the vendor's arrangement for the four guarded Lido multisigs, not named here ([ADR 002](/adr/002-decision-and-review-process.md), [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), [ADR 010](/adr/010-pre-execution-screening.md)) [s1] |
| OD-13 | Who writes and maintains the vault's detectors in each monitoring estate? | 2026-10-05 | EM: defi-tech writes the detector specification and makes the important updates; the vroom team (`@lidofinance/lido-valset-vroom`) reviews them, runs the platform and maintains the engine and the bot; the committee configures the vendor's rules, with defi-tech supporting ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) [s1] |
| OD-14 | Reporting operations: who publishes, on what schedule, what happens on a stale or missing price, who answers for a late report, and where a report's identifier is anchored | 2026-10-05 | EM: the mandate's publisher and schedule, with a re-runnable report generator built by defi-tech; Coingecko with an on-chain-rate fallback and no silent stale price; no top-up while a report is late; the identifier only in the forum post, with no on-chain anchor ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) [s1] |
| OD-15 | How do the committee and the Emergency Brakes multisig record a verification of a page? | 2026-10-05 | EM: "Q1: A": a member of the body commits the entry through a reviewed pull request, with `ref` linking the body's decision record; the validator refuses a body verification without it ([ADR 002](/adr/002-decision-and-review-process.md)) [s1] |
