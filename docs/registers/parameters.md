---
type: Register
title: Parameters
description: Every Clutch parameter with its value where one exists, its source and its decision state; no value is final until its ADR is accepted.
tags: [parameters]
status: draft
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

# Parameters

"EM decision" means EM's own words [s1]. "Read" means an on-chain value at block 26092572 [s2]. "Proposed" means an agent proposal. "Open" points to the open item that decides it. Agents never set a parameter ([ADR 003](/adr/003-agent-operating-model.md)).

| Parameter | Value | State | Closes in |
|---|---|---|---|
| Operator | the committee's Safe, four of seven | Read [s2]; holder by EM decision [s1] | [ADR 005](/adr/005-account-graph-and-roles.md) |
| Emergency Safe | threshold two; owner set equal to the committee's | EM decision [s1] | ADR 005 |
| Technical role holder | the Emergency Brakes Safe, three of five | EM decision [s1]; quorum read [s2] | ADR 005 |
| Easy Track objection period | 72 hours, 259,200 seconds, global | Read [s2] | — |
| Easy Track objection threshold | 0.5 percent of LDO, 50 basis points | Read [s2] | — |
| Trusted caller of every factory | the committee's Safe | EM decision [s1] | [ADR 006](/adr/006-governance-through-easy-track-factories.md) |
| Swap engine | Stonks 2.0, fresh instances only | EM decision [s1] | [ADR 007](/adr/007-swapping-through-stonks.md) |
| Swap instance manager | the Aragon Agent | EM decision [s1] | ADR 007 |
| Rebalancing set | stETH, wstETH, USDC, USDT, USDS, LDO | EM decision [s1] | ADR 007 |
| Recovery destinations | USDC as the hub; USDT as the mandatory second destination | EM decision on USDT [s1]; the hub is the agent topology that EM's answer built on | ADR 007 |
| Order duration, margin, price tolerance | none yet | Open: OD-05 | ADR 007 |
| Per-payment ceilings of the shared ACL | stETH 1,000; ETH 1,000; DAI 2,000,000; USDC 2,000,000; USDT 2,000,000; sUSDS 2,000,000; LDO 5,000,000 | Read [s2]; kept unchanged by proposal, OD-11 | [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Funding registry period and limit | none yet | Open: OD-06 | ADR 008 |
| Budget per key | not in this repository | Computed by attested computation on 2026-09-22; enters when the mandate is approved | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Budget retune cadence | every two weeks | EM decision [s1] | ADR 009 |
| Budget refill-period floor | 30 days | Proposed; open: OD-08 | ADR 009 |
| Approval ceiling per token | one deposit | Proposed; open: OD-08 | ADR 009 |
| Report storage | IPFS; no DataBus | EM decision [s1] | ADR 009 |
| Screening failure mode | fail closed on the operator | EM decision [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Flagging authority | the screening vendor, alone | EM decision [s1] | ADR 010 |
| Emergency time to initiate | at most six hours | Mandate ceiling; a hard gate [s1] | [ROADMAP](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) |
