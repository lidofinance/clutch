---
type: Register
title: Parameters
description: Every Clutch parameter with its value where one exists, its source and its decision state; no value is final until its ADR is accepted.
tags: [parameters]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T11:33:11Z
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
| Operator | the operator Safe, a new Safe with the committee's signers | EM decision of 2026-10-02 [s1] | [ADR 005](/adr/005-account-graph-and-roles.md) |
| Operator Safe threshold | four of seven | EM decision of 2026-10-02 [s1] | ADR 005 |
| Safe version of the Asset Safe and the operator Safe | v1.5.0; the operator Safe uses v1.4.1 if the vendor does not confirm v1.5.0 support in writing | EM decisions of 2026-10-02: a condition that the compatibility check met, and the vendor's confirmation as a gate [s1] | ADR 005 |
| Emergency Safe | threshold two; owner set equal to the committee's | EM decision [s1] | ADR 005 |
| Technical role holder | the Emergency Brakes Safe, three of five | EM decision [s1]; quorum read [s2] | ADR 005 |
| Easy Track objection period | 72 hours, 259,200 seconds, global | Read [s2] | — |
| Easy Track objection threshold | 0.5 percent of LDO, 50 basis points | Read [s2] | — |
| Trusted caller of every factory | the operator Safe | EM decision of 2026-10-02 [s1] | [ADR 006](/adr/006-governance-through-easy-track-factories.md) |
| Swap engine | Stonks 2.0, fresh instances only | EM decision [s1] | [ADR 007](/adr/007-swapping-through-stonks.md) |
| Swap instance manager | the operator Safe for rebalancing instances; the emergency Safe for recovery instances | EM decision of 2026-10-02 [s1], replacing the Aragon Agent of 2026-09-22 | ADR 007 |
| Swap instance origin | the standard Stonks 2.0 factory; admin Aragon Voting; recovered tokens go to the Aragon Agent | EM decision of 2026-10-02 [s1] | ADR 007 |
| Rebalancing set | stETH, wstETH, USDC, USDT, USDS, LDO | EM decision [s1] | ADR 007 |
| Recovery destinations | USDC as the hub; USDT as the mandatory second destination | EM decision on USDT [s1]; the hub is the agent topology that EM's answer built on | ADR 007 |
| Order duration, margin, price tolerance | volatile to stable: 1800 s, 110 bp, 550 bp; stable to stable: 1800 s, 30 bp, 150 bp; both families | EM decision of 2026-10-02 [s1], copying the live instances | ADR 007 |
| Maximum improvement and partial fills | 1000 bp; partial fills on; every instance | EM decision of 2026-10-02 [s1], copying the live Stonks 2.0 instances | ADR 007 |
| Per-payment ceilings of the shared ACL | stETH 1,000; ETH 1,000; DAI 2,000,000; USDC 2,000,000; USDT 2,000,000; sUSDS 2,000,000; LDO 5,000,000 | Read [s2]; EM decision of 2026-10-05 [s1]: a DAO vote adds USDS and keeps the other entries | [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Ceiling per USDS payment | 2,000,000 | EM decision of 2026-10-05 [s1] | ADR 008 |
| Funding registries | two: stablecoins and stETH; the Asset Safe is the only recipient of each | EM decision of 2026-10-02 [s1] | ADR 008 |
| Funding period | one calendar month | EM decision of 2026-10-02 [s1] | ADR 008 |
| Funding limit per period | one TM Floor Value in each registry; stablecoins at par; stETH at the Coingecko price pinned when the enabling vote is prepared; the figures are not in this repository | EM decision of 2026-10-02 [s1]; figures by attested computation, entering when the mandate is approved | ADR 008 |
| Stablecoin token list of the funding registry | the shared stablecoin token list, with USDS added: DAI, USDT, USDC, sUSDS, USDS | EM decision of 2026-10-05 [s1] | ADR 008 |
| Funding assets | USDC, USDT, DAI, USDS, sUSDS, stETH; not ETH | EM decision of 2026-10-05 [s1] | ADR 008 |
| Budget per key | not in this repository | Computed by attested computation on 2026-09-22 and again on 2026-10-02 with the literal yield-bearing base; enters when the mandate is approved | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Lido Lend cap | the protocol cap for three calendar months from Lido Lend's mainnet launch, then none, as a Lido own product | EM decision of 2026-10-02 [s1]; the start was confirmed on 2026-10-05 (OD-12) | ADR 009 |
| Yield-bearing cap base | the top-4 stablecoins plus the yield-bearing stablecoins held directly; own-product and protocol positions excluded | EM decision of 2026-10-02 [s1] | ADR 009 |
| Budget retune cadence | every two weeks | EM decision [s1] | ADR 009 |
| Budget refill-period floor | 30 days | EM decision of 2026-10-02 [s1] | ADR 009 |
| Approval bound | an approval to a protocol spender spends the budget of the key it serves; zero is free; deposits no longer spend budget; the stETH approval to the wstETH contract has a fixed ceiling of one TM Floor Value in stETH | EM decision of 2026-10-02 [s1] | ADR 009 |
| Report storage | IPFS; no DataBus | EM decision [s1] | ADR 009 |
| Screening guard | the screening vendor's existing transaction guard, one instance on the operator Safe, of the build that the Lido multisigs run | EM decisions of 2026-10-02 [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Guard removal and bypass timelocks | 10 days each, fixed in the chosen build | EM decision of 2026-10-02 [s1]; a constant in the vendor's code | ADR 010 |
| Standing approvals on the guard | none, except the guard's two built-in timelock approvals | EM decision of 2026-10-02 [s1] | ADR 010 |
| Screening failure mode | fail closed on the operator | EM decision [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Flagging authority | the screening vendor, alone | EM decision [s1] | ADR 010 |
| Emergency time to initiate | at most six hours | Mandate ceiling; a hard gate [s1] | [ROADMAP](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) |
