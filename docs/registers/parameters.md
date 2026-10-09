---
type: Register
title: Parameters
description: Every Clutch parameter with its value where one exists, its source and its decision state; no value is final until its ADR is accepted.
tags: [parameters]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-09T06:40:00Z
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

"EM decision" means EM's own words [s1]. "Read" means an on-chain value at block 26092572 [s2]. "Proposed" means an agent proposal. "Open" points to the open item that decides it. Agents never set a parameter ([ADR 003](/adr/003-agent-operating-model.md)).

| Parameter | Value | State | Closes in |
|---|---|---|---|
| Operator | the operator Safe, a new Safe with the committee's signers | EM decision of 2026-10-02 [s1] | [ADR 005](/adr/005-account-graph-and-roles.md) |
| Operator Safe threshold | four of seven | EM decision of 2026-10-02 [s1] | ADR 005 |
| Safe version of the Asset Safe, the operator Safe and the emergency Safe | v1.5.0 | EM decisions of 2026-10-02 and 2026-10-05: the compatibility check met the condition; EM reported the vendor's confirmation of v1.5.0 support, which closed the gate; the due diligence found no blocker (OD-17) [s1][s3] | ADR 005 |
| Asset Safe fallback handler | none; a protocol that needs one comes back to EM | EM decision of 2026-10-05 [s1] | ADR 005 |
| How the Aragon Agent authorizes an Asset Safe transaction | `approveHash`, or the Agent sends the transaction itself; never a contract signature | EM decision of 2026-10-05 [s1] | ADR 005 |
| Emergency Safe | threshold two; owner set equal to the committee's | EM decision [s1] | ADR 005 |
| Technical role holder | the Emergency Brakes Safe, three of five | EM decision [s1]; quorum read [s2] | ADR 005 |
| Easy Track objection period | 72 hours, 259,200 seconds, global | Read [s2] | — |
| Easy Track objection threshold | 0.5 percent of LDO, 50 basis points | Read [s2] | — |
| Trusted caller of every factory | the operator Safe | EM decision of 2026-10-02 [s1] | [ADR 006](/adr/006-governance-through-easy-track-factories.md) |
| Swap venue | CoW orders from the orders account: market, limit, TWAP and stop-loss; no Stonks 2.0 instance | EM decision of 2026-10-06 (OD-43) [s1], replacing Stonks 2.0 (decided 2026-09-22, OD-05, OD-20) | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Orders account | a Safe owned by the Aragon Agent at one of one, with CoW's fallback handler and one modifier of its own, carrying the operator, emergency and technical roles and no governance role | EM decisions of 2026-10-06 (OD-43) and 2026-10-09 (OD-57) [s1] | ADR 007, [ADR 005](/adr/005-account-graph-and-roles.md) |
| Order receivers | the Asset Safe for the operator's orders; the Aragon Agent for the emergency role's orders | EM decision of 2026-10-06 (OD-43) [s1] | ADR 007 |
| Router swaps (Uniswap, 1inch) | none at launch; only after the screening vendor can bound a swap's minimum output | EM decision of 2026-10-06 (OD-43) [s1] | ADR 007 |
| Orders budgets | one budget key per listed token on transfers into the orders account; figures not in this repository | EM decision of 2026-10-06 (OD-43): budgets [s1]; one key per token is the agent's proposal; figures by attested computation | ADR 007, [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Exit-governance role | on the safety modifier, held by the Easy Track script executor; writes only the emergency role's exits, from the onboarding templates | EM decision of 2026-10-06 (OD-49) [s1] | ADR 006, ADR 005 |
| Lido Lend contract | a separate Morpho-Blue-compatible deployment; its address and its emergency exit enter with the onboarding motion | EM statement of 2026-10-06 (OD-49) [s1] | ADR 011 |
| Recovery order price | no on-chain floor; CoW's competition and EBBO rule hold a fill to the on-chain market; a high-severity page on every emergency swap and an alert on a limit far below a market price | EM decision of 2026-10-06 (OD-48) [s1] | ADR 007 |
| Maximum order life | 30 days for the operator's market and limit orders, through the order signer's `validDuration`; a TWAP order starts at its creation with at most 30 daily or 4 weekly parts; a stop-loss expiry at most 30 days ahead, by a requested screening rule; 1 day for a recovery order | EM decision of 2026-10-06 (OD-47) [s1] | ADR 007 |
| Order lists and relayer approvals | a DAO vote sets the lists, and adds a token with its relayer approval, emergency transfer and recovery orders; no motion adds a token, and no role can raise an approval on the orders account | EM decision of 2026-10-06 (OD-46) [s1]; the approval rule is the agent's proposal | ADR 006, ADR 007 |
| DAI–USDS conversion | Sky's DaiUsds `0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A`; the operator converts both ways, one to one; the receiver is pinned to the Asset Safe; DAI stays out of the operator's order tokens | EM decision of 2026-10-05 [s1]; read [s6] | [ADR 011](/adr/011-launch-scope.md) |
| Operator's order tokens | stETH, wstETH, WETH, USDC, USDT, USDS, LDO; DAI and sUSDS stay out | EM decisions of 2026-09-22, 2026-10-05 and 2026-10-06 (the rebalancing set, OD-22, OD-46) [s1] | ADR 007, [ADR 011](/adr/011-launch-scope.md) |
| Recovery buy tokens | USDC, or USDT as the second destination | EM decisions of 2026-09-22, 2026-10-05 and 2026-10-06 (OD-26, OD-43) [s1]; the sell list is an agent proposal in ADR 007 | ADR 007 |
| Per-payment ceilings of the shared ACL | stETH 1,000; ETH 1,000; DAI 2,000,000; USDC 2,000,000; USDT 2,000,000; sUSDS 2,000,000; LDO 5,000,000 | Read [s2]; EM decision of 2026-10-05 [s1]: a DAO vote adds USDS and keeps the other entries | [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Ceiling per USDS payment | 2,000,000 | EM decision of 2026-10-05 [s1] | ADR 008 |
| Funding registries | two: stablecoins and stETH; the Asset Safe is the only recipient of each | EM decision of 2026-10-02 [s1] | ADR 008 |
| Funding period | one calendar month | EM decision of 2026-10-02 [s1] | ADR 008 |
| Launch cap without the guard | one million dollars on the Asset Safe and the orders account, at the report's price rule; the first-loss Safe is outside; held by procedure; a forum post lifts it once the guard is set on the operator Safe with its bypass mode off | EM decisions of 2026-10-08 and 2026-10-09 (OD-54, OD-55) [s1] | [ADR 010](/adr/010-pre-execution-screening.md), ADR 008 |
| Funding limit per period | one TM Floor Value in each registry; stablecoins at par; stETH at the Coingecko price pinned when the enabling vote is prepared; the figures are not in this repository | EM decision of 2026-10-02 [s1]; figures by attested computation, entering when the mandate is approved | ADR 008 |
| Stablecoin token list of the funding registry | the shared stablecoin token list, with USDS added: DAI, USDT, USDC, sUSDS, USDS | EM decision of 2026-10-05 [s1] | ADR 008 |
| Funding assets | USDC, USDT, DAI, USDS, sUSDS, stETH; not ETH | EM decision of 2026-10-05 [s1] | ADR 008 |
| First-loss Safe | a Safe owned by the Aragon Agent at one of one, with no module, guard or fallback handler; it holds only the first-loss shares | EM decision of 2026-10-06 (OD-42) [s1] | ADR 008, [ADR 005](/adr/005-account-graph-and-roles.md) |
| Legacy Earn first-loss shares | the earnETH and earnUSD shares that the Growth Committee Safe `0xf6F0732c1e9971497342C295141566E6F1A31e96` holds, 1,362.84 and 1,998,416.46 at block 26126791; transferred to the dedicated first-loss Safe after the enabling vote (OD-42) | EM decisions of 2026-10-05 and 2026-10-06 [s1]; read [s5] | ADR 008 |
| First-loss burn | a DAO vote only; the first-loss Safe calls `burn` on the share token | EM decisions of 2026-10-05 and 2026-10-06 (OD-42) [s1] | ADR 008 |
| Redemption of the first-loss shares | no role can reach the first-loss Safe; a burn or a redemption is a DAO vote | EM decisions of 2026-10-05 (OD-21, OD-28) and 2026-10-06 (OD-42) [s1] | ADR 008 |
| Twyne | not counted against the seed until its holder and form are shown on chain or in a signed record | EM decision of 2026-10-05 [s1] | ADR 008 |
| Budget per key | not in this repository; the yield-bearing key gets a fixed monthly figure like the other keys (OD-56) | Computed by attested computation on 2026-09-22 and again on 2026-10-02 with the literal yield-bearing base; enters when the mandate is approved | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Cap tier of a new Lido product | the protocol and counterparty cap until the product matures; the mandate states the criteria; a budget motion with a forum post unlocks it; Lido Lend is new, earnETH and earnUSD are not | EM decision of 2026-10-06 (OD-41) [s1], replacing the three-month rule of 2026-10-02 and 2026-10-05 (OD-04, OD-12) | ADR 009 |
| Yield-bearing cap base | the top-4 stablecoins plus the yield-bearing stablecoins held directly; own-product and protocol positions excluded | EM decision of 2026-10-02 [s1] | ADR 009 |
| Budget retune cadence | none: a key is set once and changes by motion only after an event | EM decision of 2026-10-09 (OD-56) [s1], replacing the fortnightly retune of 2026-09-22 | ADR 009 |
| Budget events | a new TM Floor Value; a spender onboarded by motion; a new Lido product's unlock; the lift of the launch cap; a price move is not an event | agent proposal in ADR 009, following EM's reason of 2026-10-09 (OD-56) | ADR 009 |
| Budget refill-period floor | 30 days | EM decision of 2026-10-02 [s1] | ADR 009 |
| Escalation of a worsening cap breach | the Emergency Brakes multisig disables the operator modifier through the technical role when a published cap breach is still there after the committee's rebalancing window of two working days and is larger at the next fortnightly snapshot; monitoring publishes each fortnightly cap reading to IPFS, from the report generator at the snapshot's pinned block; a DAO vote can also do it | EM decisions of 2026-10-05 and 2026-10-06 (OD-29, OD-32) [s1] | ADR 009 |
| Liquidity buffer | at least one month of baseline spend, in stablecoins held directly and sUSDS; a continuous detector, a report line, a screening rule if the vendor can check it, a display in the Zodiac UI; the committee restores it within the mandate's window; the figure is not in this repository | EM decision of 2026-10-06 (OD-40) [s1]; figure by attested computation | ADR 009 |
| Approval bound | an approval to a protocol spender spends the budget of the key it serves; zero is free; deposits no longer spend budget; the stETH approval to the wstETH contract has a fixed ceiling of one TM Floor Value in stETH; the DAI and USDS approvals to Sky's DAI–USDS converter have the same fixed ceiling; no approval to Lido's withdrawal queue | EM decisions of 2026-10-02, 2026-10-05 and 2026-10-08 (OD-08, OD-22; the withdrawal queue left the design) [s1] | ADR 007, ADR 009, ADR 011 |
| Report storage | IPFS; no DataBus | EM decision [s1] | ADR 009 |
| Report anchor | the report's forum post only; no on-chain anchor | EM decision of 2026-10-05 [s1] | ADR 009 |
| Price source and staleness limit | Coingecko close at the Snapshot Date; a price older than 24 hours counts as missing | EM decision of 2026-10-05 [s1] | ADR 009 |
| Late-report flag | day 8 after month-end; no top-up motion while the report is late | EM decision of 2026-10-05 [s1] | ADR 009 |
| Screening guard | the screening vendor's existing transaction guard, one instance on the operator Safe, of the build that the Lido multisigs run | EM decisions of 2026-10-02 [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Screening rules | a written list in the [control matrix](/specs/control-matrix.md); a relaxation gets a notice to the Emergency Brakes multisig and the forum, and the vendor's own delay if it has one | EM decisions of 2026-10-06 (OD-39, OD-45) [s1]; the change by reviewed pull request is the agent's proposal | [ADR 010](/adr/010-pre-execution-screening.md) |
| Guard removal and bypass timelocks | 10 days each, fixed in the chosen build | EM decision of 2026-10-02 [s1]; a constant in the vendor's code | ADR 010 |
| Delegatecall target of the operator Safe | only Safe's MultiSendCallOnly v1.5.0, `0xA83c336B20401Af773B6219BA5027174338D1836`; a request to the vendor, not a gate | EM decision of 2026-10-05 [s1]; address and code hash [s3] | ADR 010 |
| Standing approvals on the guard | none, except the guard's two built-in timelock approvals | EM decision of 2026-10-02 [s1] | ADR 010 |
| Screening failure mode | fail closed on the operator | EM decision [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Flagging authority | the screening vendor, alone | EM decision [s1] | ADR 010 |
| Emergency time to initiate | at most six hours | Mandate ceiling; a hard gate [s1] | [ROADMAP](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) |
