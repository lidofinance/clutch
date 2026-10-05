---
type: Decision
title: "ADR 007: Swapping through Stonks 2.0"
description: Every swap, routine or emergency, goes through fresh Stonks 2.0 instances from the standard factory; the operator Safe manages the rebalancing instances and the emergency Safe the recovery instances; the receiver separates the two families; the live parameters are copied by pair class; recovered tokens go to the treasury; the committee's Safe keeps the vault's feeds on the shared price router; only stETH, LDO and the four dollar stablecoins are swapped, and wstETH, sUSDS, WETH and ETH are converted first.
tags: [swaps, stonks, cow, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the swap engine, recovery pairs and instances, 2026-09-22, on OD-05, 2026-10-02, and on OD-20, 2026-10-05
  - id: s2
    resource: /research/stonks-instances-2026-10-02.md
    title: Stonks 2.0 instances — roles, order life, factory, funding precedent and price coverage
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L211"
    title: Kit test at 370e20a — an order pre-signature is opaque to the modifier
  - id: s4
    resource: /specs/lip-draft.md
    title: LIP draft — swapping and the instance matrix
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L875"
    title: Kit test at 7a8c661 — the operator cannot pre-sign an order or approve the CoW relayer
  - id: s6
    resource: /research/stonks-pricing-2026-10-05.md
    title: Stonks 2.0 pricing, 2026-10-05 — the converter, the shared router, Chainlink's registry, feed replacements, and the WETH route
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L582"
    title: Kit test at 7a8c661 — staking, a withdrawal-queue round trip with the Asset Safe as owner, and a wrap into WETH
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L699"
    title: Kit test at 7a8c661 — the emergency role unwraps WETH into the Asset Safe through WETH's 2,300-gas transfer, stakes the ETH and sends the stETH to the Agent
---

# ADR 007: Swapping through Stonks 2.0

## Context

- A CoW order pre-signature carries only an order identifier and a flag. The sell token, the buy token, the amounts and the receiver are inside a hash that the modifier cannot read [s3].
- A Stonks 2.0 instance has a fixed receiver for its proceeds [s2].
- Only an instance's admin or manager can place an order. Recovered tokens always go to the instance's fixed recovery address [s2].
- Every instance from the standard factory has Aragon Voting as admin and the Aragon Agent as recovery address [s2].
- An order's minimum output is the oracle quote less the margin; a manager can raise it, never lower it. An order is valid only while the oracle stays inside two bands around its price, the maximum improvement above and the price tolerance below [s2].
- The live instances use 1800 seconds, 110 and 550 basis points for a volatile pair, and 1800 seconds, 30 and 150 for a stablecoin pair. The Stonks 2.0 instances also set a maximum improvement of 1000 basis points and allow partial fills [s2].
- An instance prices through a converter and a shared oracle router. A converter's token lists are fixed when it is deployed, and anyone can deploy one through the converter factory. The existing converters cover only stETH and LDO [s6].
- Aragon Voting is the router's admin. Since vote 204, the committee's Safe is its manager. Either can add a token, set the maximum age of its price, turn it off, or re-sync it. Neither can choose the feed [s6].
- The router takes each feed from Chainlink's Feed Registry. The registry has USD feeds for USDC, USDT, DAI and USDS, and no entry for wstETH, WETH or sUSDS [s6].
- When Chainlink replaces a feed's aggregator, the router refuses that token until the admin or the manager re-syncs it. Chainlink replaced the USDC and USDT aggregators twice in September 2026 [s6].

## Decision

EM decided on 2026-09-22 [s1]:

1. Stonks 2.0 is the default swap engine for the vault. The emergency swap must work through CoW, and Stonks 2.0 gives it oracle protection.
2. Recovery covers stablecoin-to-stablecoin swaps too. The missing recovery pairs are added.
3. No existing instance is reused.
4. The rebalancing set is stETH, wstETH, USDC, USDT, USDS and LDO.
5. Recovery has a second destination, USDT, and it is mandatory.

EM decided on 2026-10-02, closing OD-05 [s1]:

6. The operator Safe manages the rebalancing instances. The emergency Safe manages the recovery instances. This replaces the 2026-09-22 choice of the Aragon Agent as manager of every instance, which would have made every swap a DAO vote.
7. The parameters copy the live values by pair class, for both families. Volatile to stable: 1800 seconds, 110 basis points margin, 550 basis points price tolerance. Stable to stable: 1800 seconds, 30 and 150. Every instance: a maximum improvement of 1000 basis points, and partial fills on.
8. Instances come from the standard factory. Tokens recovered from a rebalancing instance therefore go to the treasury, not back to the vault.

EM decided on 2026-10-05, closing OD-20 [s1]:

9. The committee's Safe, as the router's manager, adds USDC, USDT, DAI and USDS once the instance list is final. Each is quoted in USD, with a maximum price age equal to Chainlink's heartbeat for its feed.
10. Lido deploys one USD-anchored converter for the vault through the deployed converter factory.
11. The enabling vote starts only if every vault token is configured on the router and in sync.
12. The swap instances cover only stETH, LDO, USDC, USDT, USDS and DAI. wstETH is unwrapped and sUSDS is redeemed before a sale.
13. WETH is supported through stETH. To sell WETH, the vault unwraps it, stakes the ETH through Lido's `submit` and sells the stETH. To buy WETH, it unstakes stETH through Lido's withdrawal queue and wraps the ETH. The operator and the emergency role may stake ETH. The operator may request and claim withdrawals, pinned to the Asset Safe. The emergency role may unwrap WETH.
14. The committee's Safe re-syncs a feed after Chainlink replaces it. Monitoring alerts when a vault token's feed is out of sync, and a runbook covers the re-sync. If a feed is broken during an emergency, the emergency Safe sends assets to the Aragon Agent instead of swapping.

## Proposed direction

The rest of this section is agent-drafted [s4]. EM has not accepted it as text.

| Family | Used by | Manager | Receiver | Recovered tokens go to |
|---|---|---|---|---|
| Rebalancing | `operator` | operator Safe | Asset Safe | Aragon Agent |
| Recovery | `emergency` | emergency Safe | Aragon Agent | Aragon Agent |

- **A swap.** The role transfers the asset to an approved instance, with the recipient pinned in the permission. The instance's manager then places the order. The proceeds settle to the receiver.
- **An unfilled order.** When it expires, anyone can return the unsold tokens to the instance, and the manager places a new order. This is the normal path. Recovering tokens out of an instance is the exception, for an instance that is retired or stuck.
- **The managers act outside the modifier.** The operator Safe calls its instances directly, so the screening guard checks each order. The emergency Safe calls its instances directly and is never screened.
- **Topology.** USDC is the hub. Rebalancing routes through USDC. Recovery sells each swappable asset directly into USDC, and stETH and LDO also into USDT, so a USDC depeg does not strand recovery. That is about seven recovery and eight rebalancing instances. Direct pairs can be added later by motion.
- **Pricing.** One USD-anchored converter serves every vault instance, so the stablecoin pairs do not depend on the ETH/USD feed. Its lists follow the instance list: sell stETH, LDO, USDC, USDT, USDS and DAI; buy USDC, USDT, stETH, USDS and LDO. The router is shared with the NEST buyback, so a router setting changed for one changes it for the other.
- **Converted assets.** wstETH, sUSDS, WETH and ETH have no price on the router. The operator converts them before a rebalance. The emergency role converts them before a recovery swap, or sends them to the Agent. Lido's `submit` mints stETH to the caller, the Asset Safe, and its referral argument is pinned to zero. The withdrawal queue's owner and claim recipient are pinned to the Asset Safe. The stETH approval to the queue spends a budget key, as every approval does ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). Claiming a finalized request falls under the emergency role's exits.

## Options considered

- **Direct order pre-signing by the operator.** Not chosen: neither price nor destination can be constrained [s3].
- **A router swap with the destination in calldata.** Not chosen: it pins the destination, but the vault would still hold a standing router approval.
- **A full mesh of instances.** Not chosen: every instance is an address to deploy, pin and monitor.
- **Reusing the existing treasury instances.** Not chosen by EM: their receiver is the treasury, and vault flows would mix with ordinary DAO swaps.
- **The Aragon Agent as manager.** Replaced by EM on 2026-10-02: every swap, emergency ones included, would have needed a DAO vote.
- **Rebalancing instances deployed outside the factory, recovering to the Asset Safe.** Not chosen by EM. It would keep recovered tokens in the vault with no new contract, at the cost of off-factory provenance.
- **The enabling vote adds the feeds.** Not chosen by EM: the committee's Safe already manages the router and can change the feeds afterwards, so vote items would add little protection.
- **A new price source for wstETH.** Not chosen: it is new contract code.
- **WETH and ETH sent only to the Agent.** Not chosen by EM: EM wants WETH supported.
- **A request to Chainlink to add WETH to its registry.** Not chosen: it depends on Chainlink, with no timeline.
- **A second router for the vault, with the emergency Safe as manager.** Not chosen by EM: the emergency role would control the operator's price checks.

## Consequences

- The destination of proceeds is structural. No condition has to express it.
- The operator can move vault assets to the treasury through a rebalancing instance, by transferring tokens in and recovering them out. Both ends belong to the DAO, so this is harmless, and invariant INV-002 says so.
- A recovery from a rebalancing instance makes the vault smaller. Getting the tokens back needs a top-up motion under the mandate's top-up rule, and that rule may refuse it.
- The emergency Safe cannot act on a rebalancing instance. It can stop new transfers into one, and a live order ends within its 30 minutes.
- Changing a manager needs a DAO vote, because Aragon Voting is the admin.
- Each instance's values are fixed. A wrong rebalancing value is fixed by a new instance and one motion. A wrong recovery value needs a DAO vote, because the safety policy pins the recovery instances.
- Swaps are queued, not instant. The emergency service level is time to initiate, not time to fill.
- Assets sit in an instance between the transfer and the settlement, a short custody excursion out of the Asset Safe. The LIP must say so.
- Since 2026-10-05 the kit grants no order pre-signing and no CoW relayer approval, and a fork test refuses both [s5]. The kit deploys no instance, so it has no swap path yet.
- A wstETH sale takes two steps: unwrap, then sell stETH. Buying WETH takes days, because the withdrawal queue finalizes requests over days.
- Swap pricing depends on Chainlink's Feed Registry and on the committee's Safe to re-sync it. A replaced USDC feed stops every vault swap until the re-sync. Recovery can still send assets to the Agent, which needs no price.
- The committee's Safe can turn a vault token off on the router, or loosen its maximum price age. It cannot choose a feed. Monitoring alerts on every router change.
- Staking converts ETH to stETH one to one. The way back is the withdrawal queue, not a swap.

## Confirmation

- INV-002, INV-013, INV-014 and INV-020 in the [invariants](/specs/invariants.md).
- Kit tests: staking and a withdrawal-queue round trip work with the Asset Safe as owner [s7]; WETH's unwrap pays the Asset Safe, although WETH forwards only 2,300 gas [s8]. The oracle report that finalizes a request is simulated.
- Fork tests owed: each manager places, re-places and recovers orders; a non-manager cannot; recovered tokens arrive at the treasury; an expired order's tokens return to the instance; the converter prices every instance pair; an instance refuses a token that is turned off or out of sync.

## Reversal conditions

- An instance cannot price a pair in the list.
- Fill rates under stress break the six-hour time to initiate.
- Recoveries from rebalancing instances become frequent enough that the treasury round trip shrinks the vault.
- Chainlink deprecates its Feed Registry, or removes a vault token from it.
- Chainlink adds wstETH or WETH to its registry. Direct instances can then be added by motion.
- Feed replacements stop recovery swaps often enough to threaten the six-hour target.

## Open questions

- The exact instance list is a phase 1 deliverable.
