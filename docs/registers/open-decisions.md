---
type: Register
title: Open decisions
description: Every open item for Clutch, the page that closes it, the agent recommendation where one exists, and who decides.
tags: [decisions, open-questions]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T14:56:24Z
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
| OD-09 | How does an immediate removal work? EM asked that the removal templates skip the objection window. Easy Track sets one global duration when a motion is created [s2]. | [ADR 006](/adr/006-governance-through-easy-track-factories.md) | Immediate de-scoping stays an emergency-role action. Easy Track removal stays the routine path. Do not change the global duration or run a second Easy Track | EM; constrains the operator |
| OD-10 | Which team owns the repository in CODEOWNERS? | `.github/CODEOWNERS` | Set it before the first external contributor joins | EM |
| OD-11 | Do the shared payment ACL parameters stay unchanged, with seeding only in USDC, USDT, DAI, stETH or ETH? Which token list does the stablecoin registry use? The shared list also allows sUSDS, and Aragon Voting administers it for every stablecoin setup. The Agent holds less than 8 ETH [s3]. | [ADR 008](/adr/008-funding-through-existing-payments.md) | Yes. Every Easy Track payment setup shares the permission, and a change rewrites all 22 entries by vote [s2]. Give the vault its own token list of USDC, USDT and DAI. Drop ETH from the seeding assets | EM; constrains the operator |
| OD-12 | Confirm four recorded readings: the vision answer; the answer about the acceptor, which left the rest of the review process unchanged; the start of Lido Lend's three capped months, read as Lido Lend's mainnet launch; and who signs the vendor agreement. Asked who signs, EM named the vendor, which the agent reads as the counterparty, so the Lido-side party is still to name. | [Decision log](/registers/decision-log.md), [ADR 002](/adr/002-decision-and-review-process.md), [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Confirm all four, and name the Lido-side party to the vendor agreement | EM |
| OD-13 | Who writes and maintains the vault's detectors in each monitoring estate? Lido's existing detector for the screening guard must add Safe v1.5.0 and the new instance ([ADR 010](/adr/010-pre-execution-screening.md)). | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | The committee specifies the rules. The team that runs each estate implements them | EM |
| OD-14 | Reporting operations: who publishes, on what schedule, what happens when a price is stale or missing, and who answers for a late report? Where is a report's identifier anchored on chain, now that the standard top-up factory fixes the payment reference [s3]? | Mandate text; [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | Name the first four in the mandate. Until an on-chain anchor is chosen, the identifier goes in the forum post that precedes each top-up | EM with the committee |
| OD-15 | How do the committee and the Emergency Brakes multisig record a verification of a page? | [ADR 002](/adr/002-decision-and-review-process.md) | A member commits the `verified` entry through a reviewed pull request, and the entry links the body's decision record | EM |
| OD-16 | The policy data format and the compiler toolchain. | [ADR 004](/adr/004-specifications-and-policy-as-data.md) | Decide in the phase 1 specification | EM |
| OD-17 | Incident-history check on Safe v1.5.0. EM asked for "a dd about audits and incident history". Both new Safes now use v1.5.0. The audits are recorded; the incident history is not. If the vendor does not confirm v1.5.0 support, the operator Safe uses v1.4.1, and this check covers the Asset Safe only. | [ADR 010](/adr/010-pre-execution-screening.md) | Record it before ADR 005 and ADR 010 are accepted | Evidence owed; EM decides |
| OD-20 | Who configures the swap pricing before launch, and when? The vault's pairs need a new converter instance with the vault's token lists, and oracle-router feeds for wstETH, WETH, USDC, USDT, DAI and USDS. | [ADR 007](/adr/007-swapping-through-stonks.md) | Put the converter and the feeds in the enabling vote. Verify every pair on a fork before the instance list is final | EM, then the DAO |
| OD-21 | How do the legacy investments that the mandate carries over move into the vault, and who holds them now? The mandate lists EarnETH, EarnUSD and Twyne, and they reduce the seed. The Agent and the committee's Safe hold no shares of the current earnETH and earnUSD vaults [s3]. | [ADR 008](/adr/008-funding-through-existing-payments.md) | Find the holder first. A position held for the DAO moves in the enabling vote, because the payment permission denies these tokens [s2]. Size the seed after the move | EM |
| OD-22 | Should DAI earn, or stay idle? DAI can seed the vault, but no operator permission moves it: it is not in the rebalancing set ([ADR 007](/adr/007-swapping-through-stonks.md)), sDAI is out of scope, and no DAI-to-USDS converter is in scope ([ADR 011](/adr/011-launch-scope.md)). Only recovery can move it. | [ADR 011](/adr/011-launch-scope.md) | If DAI should earn, add the DAI-to-USDS converter as a conversion: it needs no price and no swap instance. If DAI is the liquidity buffer, say so in ADR 011 | EM; constrains the operator |

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
