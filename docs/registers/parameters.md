---
type: Register
title: Parameters
description: Every Clutch parameter with its value where one exists, its source and its decision state; no value is final until its ADR is accepted.
tags: [parameters]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T20:29:40Z
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

"EM decision" means EM's own words [s1]. "Read" means an on-chain value at block 26092572 [s2]; a row that cites another research note uses that note's block. "Proposed" means an agent proposal. "Open" points to the open item that decides it. Agents never set a parameter ([ADR 003](/adr/003-agent-operating-model.md)).

| Parameter | Value | State | Closes in |
|---|---|---|---|
| Operator | the committee's own Safe, at 4 of 7 on Safe v1.3.0 | EM decisions of 2026-10-02 and 2026-10-14 (OD-80) [s1] | [ADR 005](/adr/005-account-graph-and-roles.md) |
| Committee's Safe threshold | four of seven, its existing threshold | EM decisions of 2026-10-02 and 2026-10-14 (OD-80) [s1] | ADR 005 |
| Safe version of the Asset Safe and the emergency Safe | v1.5.0; the committee's Safe stays on v1.3.0 (OD-80) | EM decisions of 2026-10-02 and 2026-10-05: the compatibility check met the condition; EM reported the vendor's confirmation of v1.5.0 support, which closed the gate; the due diligence found no blocker (OD-17) [s1][s3] | ADR 005 |
| Asset Safe fallback handler | none; a protocol that needs one comes back to EM | EM decision of 2026-10-05 [s1] | ADR 005 |
| How Aragon Voting authorizes an Asset Safe transaction | `approveHash`, or Aragon Voting sends the transaction itself; never a contract signature; in the enabling vote, Voting approves the hash of each Safe batch, and anyone executes the batches after the vote | EM decisions of 2026-10-05, 2026-10-14 (OD-73) and 2026-10-22 (OD-92) [s1] | ADR 005 |
| Emergency Safe | three of five: two committee members, two Emergency Brakes members and a fifth signer who is a member of neither body; the committee and the Emergency Brakes multisig appoint two seats each, and a DAO Snapshot appoints the fifth | EM decision of 2026-10-13 (OD-58) [s1], replacing threshold two with the committee's owners (OD-30) | ADR 005 |
| Switch holder | the emergency Safe, through the emergency role; the module argument is pinned to the operator modifier; the technical role is gone | EM decision of 2026-10-13 (OD-58) [s1] | ADR 005 |
| Emergency Brakes multisig in the vault | no role; it keeps only the global Easy Track pause | EM decision of 2026-10-13 (OD-58) [s1] | ADR 005 |
| Restart after a stop | the DAO only: Voting items unpause Easy Track, or enable the operator modifier again and grant again the operator's permissions on the orders account and any relayer approval set to zero, after the same vote cancels the queued motions | EM decisions of 2026-10-13 (OD-59) and 2026-10-14 (OD-73, OD-78) [s1]; the cancel step is the agent's proposal | ADR 005 |
| Easy Track objection period | 72 hours, 259,200 seconds, global | Read [s2] | — |
| Easy Track objection threshold | 0.5 percent of LDO, 50 basis points | Read [s2] | — |
| Trusted caller of every factory | the committee's Safe | EM decisions of 2026-10-02 (OD-01) and 2026-10-14 (OD-80) [s1] | [ADR 006](/adr/006-governance-through-easy-track-factories.md) |
| Swap venue | CoW orders from the orders account: market, limit and TWAP, and no stop-loss at launch (OD-79); no Stonks 2.0 instance | EM decision of 2026-10-06 (OD-43) [s1], replacing Stonks 2.0 (decided 2026-09-22, OD-05, OD-20) | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Orders account | a Safe owned by Aragon Voting at one of one, with CoW's fallback handler and one modifier of its own, carrying the operator and emergency roles and no governance role | EM decisions of 2026-10-06 (OD-43), 2026-10-09 (OD-57), 2026-10-13 (OD-58) and 2026-10-14 (OD-73, OD-78) [s1] | ADR 007, [ADR 005](/adr/005-account-graph-and-roles.md) |
| Order receivers | the Asset Safe for the operator's orders; the Aragon Agent for the emergency role's orders | EM decision of 2026-10-06 (OD-43) [s1] | ADR 007 |
| Router swaps (Uniswap, 1inch) | none at launch; only after the screening vendor can bound a swap's minimum output | EM decision of 2026-10-06 (OD-43) [s1] | ADR 007 |
| Orders budgets | one budget key per listed token on transfers into the orders account; figures not in this repository | EM decision of 2026-10-06 (OD-43): budgets [s1]; one key per token is the agent's proposal; figures by attested computation | ADR 007, [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Exit-governance role | on the safety modifier, held by the Easy Track script executor; writes only the emergency role's exits, from the onboarding templates | EM decision of 2026-10-06 (OD-49) [s1] | ADR 006, ADR 005 |
| Lido Lend contract | a separate Morpho-Blue-compatible deployment; its address and its emergency exit enter with the onboarding motion | EM statement of 2026-10-06 (OD-49) [s1] | ADR 011 |
| Recovery order price | no on-chain floor; CoW's competition and EBBO rule hold a fill to the on-chain market; a high-severity page on every emergency swap and an alert on a limit far below a market price | EM decision of 2026-10-06 (OD-48) [s1] | ADR 007 |
| Maximum order life | 90 days for every operator order: market and limit orders through the order signer's `validDuration`; a TWAP order starts at its creation with at most 90 daily or 12 weekly parts; 1 day for a recovery order; an alert at 30 days asks the committee to confirm or cancel | EM decisions of 2026-10-06 (OD-47) and 2026-10-13 (OD-61) [s1]; the part counts and the 30-day request are the agent's proposal | ADR 007 |
| Order lists and relayer approvals | a DAO vote sets the lists, and adds a token with its relayer approval, emergency transfer and recovery orders; no motion adds a token, and no role can raise an approval on the orders account | EM decisions of 2026-10-06 (OD-46) and 2026-10-14 (OD-78) [s1]; the approval rule is the agent's proposal | ADR 006, ADR 007 |
| Spare budget keys | spare keys for each token, with ceilings, in the enabling vote; two for each token on the launch lists is the agent's proposal | EM decision of 2026-10-14 (OD-69) [s1] | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| DAI–USDS conversion | Sky's DaiUsds `0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A`; the operator converts both ways, one to one; the receiver is pinned to the Asset Safe; DAI stays out of the operator's order tokens | EM decision of 2026-10-05 [s1]; read [s6] | [ADR 011](/adr/011-launch-scope.md) |
| Operator's order tokens | stETH, wstETH, WETH, USDC, USDT, USDS; DAI and sUSDS stay out; LDO left the launch list | EM decisions of 2026-09-22, 2026-10-05, 2026-10-06 and 2026-10-22 (the rebalancing set, OD-22, OD-46, OD-91) [s1] | ADR 007, [ADR 011](/adr/011-launch-scope.md) |
| Recovery buy tokens | USDC, or USDT as the second destination | EM decisions of 2026-09-22, 2026-10-05 and 2026-10-06 (OD-26, OD-43) [s1]; the sell list is an agent proposal in ADR 007 | ADR 007 |
| Per-payment ceilings of the shared ACL | stETH 1,000; ETH 1,000; DAI 2,000,000; USDC 2,000,000; USDT 2,000,000; sUSDS 2,000,000; LDO 5,000,000 | Read [s2]; EM decision of 2026-10-05 [s1]: a DAO vote adds USDS and keeps the other entries | [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Ceiling per USDS payment | 2,000,000 | EM decision of 2026-10-05 [s1] | ADR 008 |
| Funding registries | two: stablecoins and stETH; the Asset Safe is the only recipient of each | EM decision of 2026-10-02 [s1] | ADR 008 |
| Funding period | one calendar month | EM decision of 2026-10-02 [s1] | ADR 008 |
| Launch cap without the guard | one million dollars on the Asset Safe and the orders account, at the report's price rule; the first-loss Safe is outside; held by procedure; a forum post lifts it once the guard is set on the committee's Safe with its bypass mode off | EM decisions of 2026-10-08, 2026-10-09 (OD-54, OD-55) and 2026-10-14 (OD-83) [s1] | [ADR 010](/adr/010-pre-execution-screening.md), ADR 008 |
| Funding limit per period | one mandate size in each registry, as a backstop; stablecoins at par; stETH at the Coingecko price pinned when the enabling vote is prepared; the figures are not in this repository; a new mandate size is a DAO vote by design, and a re-pin of the stETH limit is optional (OD-71) | EM decisions of 2026-10-02 and 2026-10-21 (OD-89) [s1]; figures by attested computation, entering when the mandate is approved | ADR 008 |
| Mandate size | a ceiling: the vault holds up to it in assets; each funding counts in US dollars at its value when funded, and the legacy positions count too; more funding needs a separate DAO approval; a replenishment needs the mandate's published eligibility conditions and its disclosure; the figure is not in this repository | EM decision of 2026-10-21 (OD-89) [s1], replacing the floor of mandate draft v0.1 | ADR 008 |
| Treasury share | the vault never holds more than the mandate's share of the DAO's non-LDO treasury; the figure is not in this repository | EM decision of 2026-10-21 (OD-89) [s1]; open: the mandate owes the share's base, the time of its test and the remedy for a breach that no vault transaction causes | ADR 008 |
| Funded value | the first-loss shares at their value on the day of the transfer, plus each top-up at its value on the day of its enactment, by the report's price rule; each top-up's forum post states it, with the headroom under the mandate size | Proposed, following OD-89 | ADR 008, [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Registry admin | Aragon Voting, for each of the vault's two funding registries; it sets a limit and a period; the registry factories deploy both registries with Voting as admin, the deployer adds the Asset Safe and sets each limit, then gives up its roles, and a check before the vote proves every role | EM decisions of 2026-10-14 (OD-73) and 2026-10-22 (OD-92) [s1] | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 008](/adr/008-funding-through-existing-payments.md) |
| Stablecoin token list of the funding registry | the shared stablecoin token list, with USDS added: DAI, USDT, USDC, sUSDS, USDS; the enabling vote adds USDS: Voting takes the list's add-token role, adds USDS and gives the role up | EM decisions of 2026-10-05 and 2026-10-22 (OD-93) [s1] | ADR 008 |
| Easy Track motion slots | Easy Track's limit of 20 open motions stays as it is; every committee shares it; monitoring warns when few slots are free; the budget factory can set several keys in one motion; the warning threshold is not set | EM decision of 2026-10-22 (OD-94) [s1]; the detector specification sets the threshold | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Funding assets | USDC, USDT, DAI, USDS, sUSDS, stETH; not ETH | EM decision of 2026-10-05 [s1] | ADR 008 |
| First-loss Safe | a Safe owned by Aragon Voting at one of one, with no guard or fallback handler, and one modifier with two roles: `first-loss` for the committee's Safe and `first-loss-burn` for the Easy Track executor; it holds only the first-loss shares | EM decisions of 2026-10-06 (OD-42), 2026-10-13 (OD-60, OD-67) and 2026-10-14 (OD-73) [s1] | ADR 008, [ADR 005](/adr/005-account-graph-and-roles.md) |
| First-loss role holder | the committee's Safe, four of seven: the redemption and the claim, paid to the Aragon Agent; the guard screens each action once the launch cap lifts (OD-83) | EM decisions of 2026-10-13 (OD-60): "role is hold by TMC Safe" and "TMC Safe means operator safe"; the burn moved to motions (OD-67); and of 2026-10-14 (OD-80): the committee's Safe holds the operator role and the first-loss role [s1] | ADR 008, ADR 005 |
| Legacy Earn first-loss shares | the earnETH and earnUSD shares that the Growth Committee Safe `0xf6F0732c1e9971497342C295141566E6F1A31e96` holds, 1,362.84 and 1,998,416.46 at block 26126791; transferred to the dedicated first-loss Safe after the enabling vote (OD-42) | EM decisions of 2026-10-05 and 2026-10-06 [s1]; read [s5] | ADR 008 |
| First-loss burn | an Easy Track motion that the committee's Safe creates on the first-loss burn factory; after the 72-hour objection window, the Easy Track executor burns through the `first-loss-burn` role; on the Earn team's written instruction under the March 2026 terms; below the terms, after a Snapshot exception | EM decisions of 2026-10-13 (OD-60, OD-67) [s1], replacing the DAO vote of OD-42; the Snapshot step is the agent's proposal | ADR 008 |
| Redemption of the first-loss shares | the `first-loss` role requests and claims the redemption, with the proceeds pinned to the Aragon Agent; it cannot transfer or approve the shares | EM decision of 2026-10-13 (OD-60) [s1], replacing the DAO vote of OD-42 | ADR 008 |
| Twyne | not counted against the seed until its holder and form are shown on chain or in a signed record | EM decision of 2026-10-05 [s1] | ADR 008 |
| Budget per key | not in this repository; the yield-bearing key gets a fixed monthly figure like the other keys (OD-56) | Computed by attested computation on 2026-09-22 and again on 2026-10-02 with the literal yield-bearing base; enters when the mandate is approved | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) |
| Cap tier of a new Lido product | the protocol and counterparty cap until the product matures; the mandate states the criteria; a budget motion with a forum post unlocks it; Lido Lend is new, earnETH and earnUSD are not | EM decision of 2026-10-06 (OD-41) [s1], replacing the three-month rule of 2026-10-02 and 2026-10-05 (OD-04, OD-12) | ADR 009 |
| Yield-bearing cap base | the top-4 stablecoins plus the yield-bearing stablecoins held directly; own-product and protocol positions excluded | EM decision of 2026-10-02 [s1] | ADR 009 |
| Budget retune cadence | none: a key is set once and changes by motion only after an event | EM decision of 2026-10-09 (OD-56) [s1], replacing the fortnightly retune of 2026-09-22 | ADR 009 |
| Budget events | a new mandate size; a spender onboarded by motion; a new Lido product's unlock; the lift of the launch cap; a price move is not an event | agent proposal in ADR 009, following EM's reason of 2026-10-09 (OD-56) | ADR 009 |
| Budget refill-period floor | 30 days | EM decision of 2026-10-02 [s1] | ADR 009 |
| Escalation of a worsening cap breach | the emergency Safe disables the operator modifier through the emergency role's switch when a published cap breach is still there after the committee's rebalancing window of two working days and is larger at the next fortnightly snapshot; the trigger is a duty, not a limit; monitoring publishes each fortnightly cap reading to IPFS, from the report generator at the snapshot's pinned block; a breach in the policy provider's published reading counts too; a DAO vote can also do it | EM decisions of 2026-10-05, 2026-10-06, 2026-10-13 and 2026-10-20 (OD-29, OD-32, OD-58, OD-84) [s1] | ADR 009 |
| Liquidity buffer | at least one month of baseline spend, in stablecoins held directly and sUSDS; a continuous detector, a report line, a screening rule if the vendor can check it, a display in the Zodiac UI; the committee restores it within the mandate's window; the figure is not in this repository | EM decision of 2026-10-06 (OD-40) [s1]; figure by attested computation | ADR 009 |
| Approval bound | an approval to a protocol spender spends the budget of the key it serves; zero is free; deposits no longer spend budget; the stETH approval to the wstETH contract has a fixed ceiling of one mandate size in stETH; the DAI and USDS approvals to Sky's DAI–USDS converter have the same fixed ceiling; no approval to Lido's withdrawal queue | EM decisions of 2026-10-02, 2026-10-05 and 2026-10-08 (OD-08, OD-22; the withdrawal queue left the design) [s1] | ADR 007, ADR 009, ADR 011 |
| Report storage | IPFS; no DataBus; the policy provider's report goes there too, with a pin-only key of a separate Lido pinning project that Lido can revoke, set as an admin setting of Lido's account in the Zodiac UI | EM decisions [s1], the second report of 2026-10-20 (OD-85) | ADR 009 |
| Report anchor | the forum post, which links Lido's report and the provider's; no on-chain anchor | EM decisions of 2026-10-05 and 2026-10-20 (OD-85) [s1] | ADR 009 |
| Price source and staleness limit | a five-level waterfall: Coingecko's close at the Snapshot Date; a second aggregator; a Chainlink feed or the deepest pool's time-weighted price; the on-chain rate into a priced underlying; the committee's estimate; a price older than 24 hours counts as missing; no asset is unpriced | EM decisions of 2026-10-05 and 2026-10-13 (OD-14, OD-62) [s1] | ADR 009 |
| Price band of level 2 | not set; the committee's valuation policy sets it | EM decision of 2026-10-13 (OD-62) [s1] | ADR 009 |
| Level-5 share that holds a top-up | not set; the committee's valuation policy sets it | EM decision of 2026-10-13 (OD-62) [s1] | ADR 009 |
| Zodiac UI | the policy provider's own reading of the three Safes as one whole, with the mandate's rubrics; independent of Lido's reading, and both count (OD-84); refuses an operator transaction that breaches a cap or the buffer's floor, in its interface only (OD-86); uses the mandate's rules from this repository, and a change made in the UI is drift (OD-87); from the lift, requests the screening vendor's approval and shows its state (OD-88); alerts to a Lido Slack channel by webhook, without paging; Lido builds the display of its own reading if the provider declines | EM decisions of 2026-10-06 (OD-44), 2026-10-13 (OD-62) and 2026-10-20 (OD-84 to OD-88) [s1]; the Slack channel was recorded without a question, and EM did not object | ADR 009, [ADR 010](/adr/010-pre-execution-screening.md) |
| Band between the two readings | not set; the committee's valuation policy sets it; a top-up waits while the readings differ by more | EM decision of 2026-10-20 (OD-84) [s1] | ADR 009 |
| Mandate rules as data | in this repository: rubrics, assets by address, caps with their bases, product tiers, the three Safes, the buffer's base, the launch cap, the mandate size and the treasury share; figures when the mandate is approved; sent to the policy provider after each governance act that changes a rule | EM decision of 2026-10-20 (OD-87) [s1] | ADR 009 |
| Wait for the screening vendor's approval before an alert | not set; the detector specification sets it | EM decision of 2026-10-20 (OD-88) [s1] | ADR 010 |
| Late-report flag | day 8 after month-end; no top-up motion while the report is late | EM decision of 2026-10-05 [s1] | ADR 009 |
| Screening guard | the screening vendor's existing transaction guard, one instance, of the build that the Lido multisigs run, on the committee's Safe from the lift of the launch cap | EM decisions of 2026-10-02 and 2026-10-14 (OD-83) [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Screening rules | a written list in the [control matrix](/specs/control-matrix.md); a relaxation gets a notice on the forum, and the vendor's own delay if it has one | EM decisions of 2026-10-06 (OD-39, OD-45) and 2026-10-13 (OD-64) [s1]; the change by reviewed pull request is the agent's proposal | [ADR 010](/adr/010-pre-execution-screening.md) |
| Guard removal and bypass timelocks | 10 days each, fixed in the chosen build | EM decision of 2026-10-02 [s1]; a constant in the vendor's code | ADR 010 |
| Delegatecall target of the committee's Safe | only Safe's MultiSendCallOnly of its version, v1.3.0, pinned before the lift; a request to the vendor, not a gate | EM decisions of 2026-10-05 and 2026-10-14 (OD-80) [s1] | ADR 010 |
| Standing approvals on the guard | none, except the guard's two built-in timelock approvals | EM decision of 2026-10-02 [s1] | ADR 010 |
| Screening failure mode | fail closed on the operator | EM decision [s1] | [ADR 010](/adr/010-pre-execution-screening.md) |
| Flagging authority | the screening vendor, alone | EM decision [s1] | ADR 010 |
| Emergency time to initiate | at most six hours | Mandate ceiling; a hard gate [s1] | [ROADMAP](https://github.com/lidofinance/clutch/blob/main/ROADMAP.md) |
