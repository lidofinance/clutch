---
type: Register
title: Parameters
description: Every Clutch value that someone can set or read, with its source and its decision state; no value is final until its ADR is accepted.
tags: [parameters]
status: draft
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-13T07:06:18Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's inputs
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30
  - id: s3
    resource: /research/safe-v150-due-diligence-2026-10-05.md
    title: Safe v1.5.0 due diligence, 2026-10-05
  - id: s5
    resource: /research/legacy-investments-2026-10-05.md
    title: Legacy investments, 2026-10-05
  - id: s6
    resource: /research/dai-usds-conversion-2026-10-05.md
    title: DAI and the DAI–USDS converter, 2026-10-05
---

# Parameters

A row holds a value that someone can set or read. A decision without a value lives in its ADR.
"EM" means EM's decision, named by its OD; the [decision log](/registers/decision-log.md) holds EM's words and their dates [s1]. "Read" means an on-chain value at block 26092572 [s2]; a row that cites another research note uses that note's block. "Proposed" means an agent proposal. Agents never set a parameter ([ADR 003](/adr/003-agent-operating-model.md)).

| Parameter | Value | State | Closes in |
|---|---|---|---|
| Operator | the committee's own Safe, at 4 of 7 on Safe v1.3.0 | EM (OD-80) [s1] | [ADR 005](/adr/005-account-graph-and-roles.md) |
| Safe version of the vault's Safes | v1.5.0 for the Asset Safe, the emergency Safe, the orders account and the first-loss Safe; v1.3.0 for the committee's Safe | EM (OD-17, OD-80, OD-126) [s1]; the due diligence found no blocker [s3] | ADR 005 |
| Asset Safe fallback handler | none | EM (OD-17) [s1] | ADR 005 |
| Emergency Safe | three of five: two committee members, two Emergency Brakes members and a fifth signer who is a member of neither body | EM (OD-58) [s1] | ADR 005 |
| Easy Track objection period | 72 hours, 259,200 seconds, global | Read [s2] | — |
| Easy Track objection threshold | 0.5 percent of LDO, 50 basis points | Read [s2] | — |
| Easy Track motion slots | 20 open motions, shared by every committee; the warning threshold is not set | EM (OD-94, OD-102) [s1]; the detector specification sets the threshold | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Universal factory limits | at most 64 writes in one motion | Proposed: the factory's constant | [ADR 013](/adr/013-one-easy-track-factory.md) |
| Budget keys for new spenders | set by the motion for each new spender: `k:`, then the spender, then the token's first ten bytes; the governance role's policy accepts a launch key or a key that starts with `k:`; a launch key is its label as `bytes32`; the policy holds no spare keys | EM (OD-102, OD-134) [s1]; the key form is the prototype's | ADR 013, ADR 009 |
| Budget per key | not in this repository | Computed by attested computation on 2026-09-22 and again on 2026-10-02 with the literal yield-bearing base; enters when the mandate is approved (OD-56) | ADR 009 |
| Orders budgets | one budget key per listed token on transfers into the orders account; figures not in this repository | EM (OD-43) [s1]: budgets; one key per token is the agent's proposal; figures by attested computation | [ADR 007](/adr/007-swapping-through-an-orders-account.md), ADR 009 |
| Budget refill-period floor | 30 days | EM (OD-08) [s1] | ADR 009 |
| Approval bound | the stETH approval to the wstETH contract, and the DAI and USDS approvals to Sky's DAI–USDS converter, have fixed ceilings of one mandate size, which a motion changes by writing the approval's permission again; every other approval spends its spender's budget key | EM (OD-08, OD-22, OD-89, OD-134) [s1] | ADR 007, ADR 009, [ADR 011](/adr/011-launch-scope.md), ADR 013 |
| DAI–USDS conversion | Sky's DaiUsds `0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A`, one to one in both directions | EM (OD-22) [s1]; read [s6] | ADR 011 |
| Operator's order tokens | stETH, wstETH, WETH, USDC, USDT, USDS | EM (OD-22, OD-46, OD-91) [s1] | ADR 007, ADR 011 |
| Recovery buy tokens | USDC, or USDT as the second destination | EM (OD-26, OD-43) [s1]; the sell list is an agent proposal in ADR 007 | ADR 007 |
| Maximum order life | 90 days for every operator order: market and limit orders through the order signer's `validDuration`; a TWAP order starts at its creation with at most 90 daily or 12 weekly parts; 1 day for a recovery order; an alert at 30 days asks the committee to confirm or cancel | EM (OD-47, OD-61) [s1]; the part counts and the 30-day request are the agent's proposal | ADR 007 |
| Launch cap without the guard | one million dollars on the Asset Safe and the orders account, at the report's price rule; the first-loss Safe is outside | EM (OD-54, OD-55, OD-83, OD-106, OD-121) [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Mandate size | not in this repository; each funding counts in US dollars at its value when funded, and the legacy positions count too | EM (OD-89) [s1] | [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Treasury share | not in this repository | EM (OD-89) [s1]; open: the mandate owes the share's base, the time of its test and the remedy for a breach that no vault transaction causes | ADR 008 |
| Funded value | the first-loss shares at their value on the day of the transfer, plus each top-up at its value on the day it is paid, by the report's price rule | Proposed, following OD-89, OD-98 and OD-106 | ADR 008, ADR 009 |
| Legacy Earn first-loss shares | the earnETH and earnUSD shares that the Growth Committee Safe `0xf6F0732c1e9971497342C295141566E6F1A31e96` holds, 1,362.84 and 1,998,416.46 at block 26126791 | EM (OD-21, OD-42) [s1]; read [s5] | ADR 008 |
| Escalation of a worsening cap breach | a published cap breach that is still there after the committee's rebalancing window of two working days and is larger at the next fortnightly snapshot | EM (OD-29, OD-32, OD-58, OD-84) [s1] | ADR 009 |
| Price source and staleness limit | the five-level waterfall of ADR 009 decision 35; a price older than 24 hours counts as missing | EM (OD-14, OD-62) [s1] | ADR 009 |
| Price band of level 2 | not set; the committee's valuation policy sets it | EM (OD-62) [s1] | ADR 009 |
| Level-5 share that holds a top-up motion | not set; the committee's valuation policy sets it | EM (OD-62, OD-122, OD-144) [s1] | ADR 009 |
| Top-up tokens | stETH through one factory; DAI, USDC, USDT and sUSDS through the factory of the DAO's stablecoin list | EM (OD-141) [s1] | [ADR 014](/adr/014-funding-by-top-up-motions.md) |
| Top-up registries' period | three calendar months | EM (OD-143) [s1] | ADR 014 |
| Top-up registries' limit for a period | EM's indicative figure, restricted until the mandate is published, for both registries together; the stETH registry's limit in stETH and the production figures come from the attested computation | EM (OD-143) [s1]; the split between the registries is the agent's reading | ADR 014 |
| The Easy Track executor's ceiling on one payment | 1,000 stETH; 2,000,000 of DAI, USDC, USDT or sUSDS; one motion carries several payments | Read on chain, unchanged by Clutch | ADR 014 |
| First top-up | one million dollars, by top-up motions after the enabling vote | EM (OD-106, OD-142) [s1]; the tokens and amounts come from the attested computation | ADR 014, ADR 010 |
| Band between the two readings | not set; the committee's valuation policy sets it | EM (OD-84, OD-122) [s1] | ADR 009 |
| Late-report flag | day 8 after month-end | EM (OD-14, OD-122) [s1] | ADR 009 |
| Wait for the screening vendor's approval before an alert | not set; the detector specification sets it | EM (OD-88) [s1] | ADR 010 |
| Guard removal and bypass timelocks | 10 days each, fixed in the chosen build | EM (OD-07) [s1]; a constant in the vendor's code | ADR 010 |
| Delegatecall target of the committee's Safe | only Safe's MultiSendCallOnly of its version, v1.3.0; a request to the vendor, not a gate | EM (OD-17, OD-80) [s1] | ADR 010 |
| Standing approvals on the guard | none, except the guard's two built-in timelock approvals | EM (OD-07) [s1] | ADR 010 |
| Emergency time to initiate | at most six hours | Mandate ceiling; a hard gate [s1] | [ROADMAP](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) |
