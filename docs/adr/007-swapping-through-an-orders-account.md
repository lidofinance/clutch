---
type: Decision
title: "ADR 007: Swapping through an orders account"
description: Every swap, routine or emergency, is a CoW order placed from a dedicated orders account — a Safe owned by the Aragon Agent, with CoW's fallback handler and its own two modifiers; the operator funds it under budgets and places market, limit, TWAP and stop-loss orders that pay the Asset Safe; the emergency role places recovery orders that pay the Aragon Agent into USDC or USDT, or sends assets to the Agent; the launch uses CoW only; Stonks 2.0 is no longer used; staking and the withdrawal queue stay, and the withdrawal-queue approval keeps its fixed ceiling.
tags: [swaps, cow, orders, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T21:22:14Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the swap engine, recovery pairs and instances, 2026-09-22, on OD-05, 2026-10-02, on OD-20, OD-26 and OD-27, 2026-10-05, and on OD-43, 2026-10-06
  - id: s2
    resource: /research/stonks-instances-2026-10-02.md
    title: Stonks 2.0 instances — roles, order life, factory, funding precedent and price coverage
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L211"
    title: Kit test at 370e20a — an order pre-signature is opaque to the modifier
  - id: s4
    resource: /specs/lip-draft.md
    title: LIP draft — swapping through the orders account
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L875"
    title: Kit test at 7a8c661 — the operator cannot pre-sign an order or approve the CoW relayer from the Asset Safe
  - id: s6
    resource: /research/stonks-pricing-2026-10-05.md
    title: Stonks 2.0 pricing, 2026-10-05 — the converter, the shared router, Chainlink's registry, feed replacements, and the WETH route
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L582"
    title: Kit test at 7a8c661 — staking, a withdrawal-queue round trip with the Asset Safe as owner, and a wrap into WETH
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L699"
    title: Kit test at 7a8c661 — the emergency role unwraps WETH into the Asset Safe through WETH's 2,300-gas transfer, stakes the ETH and sends the stETH to the Agent
  - id: s9
    resource: /research/recovery-and-withdrawal-queue-2026-10-05.md
    title: Recovery into USDT and the withdrawal-queue approval, 2026-10-05 — USDC risk in USDS and DAI, the recovery topology, and the withdrawal queue's upgrader, limits and missing cancel
  - id: s10
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the emergency path may swap any asset into any of the four main stablecoins; outside the repository until the mandate is published
  - id: s11
    resource: /research/cow-orders-account-2026-10-06.md
    title: CoW orders from a dedicated orders account, 2026-10-06 — the order signer, ComposableCoW, the fallback-handler requirement, the watch-tower, router swaps and the hosted app
---

# ADR 007: Swapping through an orders account

## Context

- A CoW order pre-signature carries only an order identifier and a flag. The sell token, the buy token, the amounts and the receiver are inside a hash that the modifier cannot read [s3].
- The deployed CoW order signer computes that identifier on chain from a typed order. It runs only by delegatecall, so the calling Safe owns the order. It bounds the order's life and fee, and leaves the receiver and the amounts to its caller, so a permission must pin them [s11].
- CoW's conditional orders, TWAP and stop-loss among them, need the owning Safe to use CoW's fallback handler and to name ComposableCoW as the verifier of CoW's settlement domain. A watch-tower posts them to CoW's order book [s11].
- The order signer, TWAP and stop-loss orders carry no price check on chain. The roles modifier can compare a parameter only with fixed values, and a check in the modifier would need new contract code. ComposableCoW's GoodAfterTime order type can check a price checker's expected output when the order is validated; it is not checked for the vault [s11].
- Zodiac's own kit covers CoW, covers Uniswap v3 only for liquidity, and does not cover 1inch. A router swap with an unchecked minimum output loses value to front-running [s11].
- A Stonks 2.0 instance bounds the price on chain and pays a fixed receiver [s2]. The design until 2026-10-06 used eight rebalancing and ten recovery instances, a converter, four feeds on a router shared with the NEST buyback, and Chainlink's Feed Registry, which cannot price wstETH, WETH or sUSDS [s6]. In a real depeg, a recovery order may not fill inside its band [s9].
- USDS and DAI carry USDC risk. DAI fell to 88 cents when USDC lost its peg in March 2023 [s9].
- Only a DAO vote can upgrade Lido's withdrawal queue. A request cannot be cancelled [s9].
- The mandate draft lets the emergency path swap any asset into any of the four main stablecoins [s10].
- On 2026-10-06 the Treasury Management Committee asked for dollar-cost averaging, standing limit orders, stop-loss orders, and access to 1inch and Uniswap [s1].

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

EM decided on 2026-10-05, closing OD-26 and OD-27 [s1]:

15. Recovery also sells USDC, USDS and DAI into USDT, so every stablecoin that carries USDC risk can leave USDC. Recovery then has ten instances.
16. The stETH approval to Lido's withdrawal queue has no budget key. It keeps a fixed ceiling of one TM Floor Value in stETH, as the approval to the wstETH contract does.

EM decided on 2026-10-06, closing OD-43 [s1]:

17. A dedicated orders account replaces the Stonks 2.0 instances, for the operator and for the emergency role. It is a Safe owned by the Aragon Agent, with CoW's fallback handler and its own modifiers.
18. The operator funds the orders account by transfers pinned to it, under budgets. From it the operator places CoW market, limit, TWAP and stop-loss orders whose proceeds go to the Asset Safe.
19. The emergency role places orders whose proceeds go to the Aragon Agent, and can always send assets to the Agent.
20. The launch uses CoW only. Uniswap and 1inch come only if the screening vendor can bound a swap's minimum output before execution.

Decisions 17 to 20 replace decisions 1, 3, 6 to 12 and 14. The emergency swap still works through CoW (decision 1). Decisions 2, 4, 5, 13 and 16 stand. Decision 15 stands for the tokens that recovery sells into USDT; the instance count no longer applies.

EM decided on 2026-10-06, closing OD-46 [s1]:

21. A DAO vote adds a token to the lists, for the operator and for recovery, with its relayer approval, its emergency transfer and its recovery orders in the same vote. No motion can add one, because the order signer's permission is a delegatecall (OD-36).
22. The operator's lists start with stETH, wstETH, WETH, USDC, USDT, USDS and LDO. DAI and sUSDS stay off.

Decision 22 adds WETH to decision 4's set. The operator trades WETH in CoW orders, so decision 13's route through stETH is no longer the only one; staking and the withdrawal queue stay available.

EM decided on 2026-10-06, closing OD-47 [s1]:

23. The operator's market and limit orders live at most 30 days. The policy pins the order signer's `validDuration` to at most 30 days.
24. A TWAP order starts at its creation and has at most 30 parts at most a day apart, or at most 4 parts at most 7 days apart, so it ends within 30 days. A stop-loss order's expiry is at most 30 days ahead, through a screening rule requested from the vendor, because no condition can compare the expiry with the current time. Monitoring alerts on any open order older than 30 days, and the emergency Safe can cancel it.
25. A recovery order lives at most 1 day. The policy pins the order signer's `validDuration` for the emergency role to at most 1 day.

EM decided on 2026-10-06, closing OD-48 [s1]:

26. Recovery orders have no on-chain price floor. CoW's solver competition and its EBBO rule hold a fill to at least the on-chain market, and a solver that breaks the rule must refund the user or lose its bond. Every emergency swap pages at high severity, and monitoring alerts on a recovery order whose limit sits far below a market price. A floor through GoodAfterTime stays a research item [s11].

## Proposed direction

The rest of this section is agent-drafted [s4][s11]. EM has not accepted it as text.

- **The orders account.** A new Safe, owned by the Aragon Agent at one of one. Its fallback handler is CoW's `ExtensibleFallbackHandler`, and ComposableCoW verifies CoW's settlement domain for it. It has two modifiers, as the Asset Safe has: the orders operator modifier, with the `operator` and `governance` roles, and the orders safety modifier, with the `emergency` and `technical` roles. Each modifier's owner, avatar and target is the orders account. The enabling vote sets it up.
- **Operator, on the Asset Safe.** A transfer of a listed token to the orders account, pinned to it, spends that token's orders budget. The budgets are figures from the attested computation.
- **Operator, on the orders account.**
  - A delegatecall to the order signer: sell and buy tokens from the lists, the Asset Safe as receiver, an order life of at most 30 days (decision 23), and a fee bound. `unsignOrder` cancels.
  - ComposableCoW orders: TWAP and stop-loss handlers only, the Asset Safe as receiver, tokens from the lists, and a stop-loss's oracles pinned to Chainlink feeds. A TWAP order is created with `createWithContext`, a start of zero and CoW's current-timestamp value factory, so it starts at its creation, and its parts and spacing take one of decision 24's two shapes. `remove` cancels.
  - A transfer of any token back to the Asset Safe.
- **Emergency role.**
  - On the Asset Safe: a transfer of any asset to the orders account, or to the Aragon Agent.
  - On the orders account: cancel any order, revoke the operator's targets and functions, set an approval of CoW's vault relayer to zero, send any listed token to the Aragon Agent or the Asset Safe, and place orders through the order signer that buy USDC or USDT, pay the Aragon Agent and live at most 1 day (decision 25).
- **Technical role.** It can disable the orders operator modifier, with the module argument pinned. The orders safety modifier keeps working.
- **Relayer approvals.** The enabling vote has the orders account approve CoW's vault relayer for the maximum amount of every token on the lists, the recovery tokens included. No role can raise an approval on the orders account, so a recovery order settles even when the operator is revoked. If the emergency role sets an approval to zero, every order in that token stops, recovery orders included, until a DAO vote sets it again; sending the token to the Agent stays open.
- **Governance role.** It cannot add a token to the lists (decision 21). It refuses the orders account and its modules as targets, as on the Asset Safe (OD-38).
- **Tokens.** The operator's lists start with decision 22's set. Recovery sells every token of the launch list except ETH, which is staked first, and the Earn shares, which leave through their redeem queues. It buys USDC, or USDT as the second destination. The enabling vote sets both lists.
- **Routers.** None at launch. If the screening vendor confirms a check of a swap's minimum output against a market price, routes to Uniswap and 1inch from the orders account follow, with the Asset Safe as recipient.
- **Price protection.** An order's own terms, CoW's solver competition, the screening of every operator transaction, the budgets on the operator's transfers into the orders account, and monitoring of each fill against a market price. Nothing on chain bounds the price, but CoW's competition and EBBO rule hold a fill to the on-chain market (decision 26). The emergency role's orders have neither screening nor a budget, so paging and the limit alert cover them.
- **Monitoring.** Open orders and conditional orders, with an alert on any order older than 30 days; a recovery order whose limit sits far below a market price; tokens left in the orders account; each fill against a market price; the account's owner, threshold, modules, fallback handler and domain verifier, with a change as critical; relayer approvals; and whether the watch-tower posts the conditional orders.

## Options considered

- **Stonks 2.0 instances for both roles**, the design until 2026-10-06. Replaced by EM (OD-43): no limit, TWAP or stop-loss orders; eighteen instances, a converter, four feeds and a shared router to deploy, configure and watch; and a band that can stop a recovery order in a real depeg.
- **Stonks for market swaps and recovery, and the orders account for the other orders.** Not chosen by EM: it keeps both sets of components.
- **Orders owned by the Asset Safe.** Not chosen: conditional orders need a fallback handler on their owner, which decision 15 of [ADR 005](/adr/005-account-graph-and-roles.md) excludes for the Asset Safe, and market orders would need a delegatecall from the Asset Safe.
- **Uniswap and 1inch at launch.** Not chosen by EM: the modifier cannot bound a swap's minimum output, so they wait for a screening check of it.
- **A custom price check in the modifier.** Not chosen: it is new contract code ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 1).
- **Direct order pre-signing by the operator.** Not chosen: a pre-signature hides the order's terms [s3]. The order signer reads them from a typed order.
- **The withdrawal-queue approval under a budget key.** Not chosen by EM: it needs a new figure from the attested computation. Only the DAO can upgrade the queue, and a claim pays the Asset Safe [s9].

## Consequences

- No price bound exists on chain. The LIP and the mandate must say so plainly, and name the controls that take its place.
- The orders account uses the fallback handler and the contract-signature path that the Asset Safe avoids. Its exposure is what enters it. The budgets bound the operator's transfers into it; the emergency role's transfers have no budget, so in an incident it can hold much of the vault. A change of its fallback handler or domain verifier is a critical alert.
- Assets sit in the orders account between the transfer and the fill. The LIP must say so.
- Conditional orders depend on CoW's watch-tower. If it stops, the orders wait and no funds move.
- Every operator transaction on the orders account comes from the operator Safe, so the screening guard checks it. The emergency role's orders are not screened, as before, and now no oracle bounds their price: two emergency signers choose the limit. CoW's rules hold the fill to the on-chain market, every emergency swap pages at high severity, and monitoring alerts on a limit far below a market price (decision 26).
- Decision 19's "always" holds for the tokens that the safety policy lists. A token that a motion onboards gets its emergency transfer to the Agent from that motion (OD-49); a recovery order for it still needs a DAO vote (decision 21).
- Proceeds go straight to their receiver: the Asset Safe for the operator, the Aragon Agent for recovery. No recovered token goes to the treasury by accident.
- A recovery order names its own limit, so it can fill in a depeg at a price that the emergency signers accept. The service level stays the time to initiate, not the time to fill.
- The vault no longer depends on Chainlink's Feed Registry, the shared Stonks router, or the committee's Safe as the router's manager. The router's settings stop being an untimelocked lever on the vault (OD-45).
- Recovery can sell wstETH, WETH and sUSDS directly. The operator buys and sells WETH in CoW orders in minutes, where the withdrawal queue takes days and a request cannot be cancelled. Staking and the withdrawal queue stay for unstaking.
- A new token waits for a DAO vote. The launch lists cover the mandate's assets, so this should be rare.
- The new components are one Safe and two modifiers, all instances of existing code. The delegatecall to the order signer comes from the enabling vote, because a motion cannot grant one (OD-36).
- The order signer has no audit that this repository found. It is 40 lines long, and Lido reviews it in phase 3.
- A fixed ceiling bounds each approval to the withdrawal queue, not each month. An operator error or a captured quorum can put all stETH into requests. A request cannot be cancelled, so that stETH stays illiquid until finalization: days, and longer in bunker mode. The emergency role can claim a request only after finalization [s9].
- The mandate text owes changes: the venues and order types, the absence of an on-chain price bound, and the emergency swap into USDC or USDT [s10] ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).

## Confirmation

- INV-002, INV-008, INV-013, INV-014, INV-022, INV-023 and INV-024 in the [invariants](/specs/invariants.md).
- Kit tests that stand: the operator cannot pre-sign an order or approve the CoW relayer from the Asset Safe [s5]; staking and a withdrawal-queue round trip work with the Asset Safe as owner [s7]; WETH's unwrap pays the Asset Safe [s8].
- Fork tests owed: the order signer by delegatecall from a Safe v1.5.0 through a roles modifier, with the receiver pinned; a TWAP and a stop-loss order from a Safe v1.5.0 with CoW's fallback handler; the conditions that pin the receiver and the oracles inside ComposableCoW's encoded order data; a refusal of every other receiver; the life bounds of decisions 23 to 25, including a refusal of a TWAP order outside both shapes; the emergency role's cancel, sweep and recovery order, settled with the relayer approval that the vote sets; and the technical role's switch on the orders account.

## Reversal conditions

- A fork test shows that CoW's fallback handler or the order signer does not work with a Safe v1.5.0 behind a roles modifier.
- Fills under stress break the six-hour time to initiate.
- Monitoring shows fills below a market price beyond the mandate's tolerance.
- CoW's watch-tower proves unreliable for the conditional orders that the committee depends on.
- The screening guard cannot check the operator's transactions on the orders account.
- CoW's EBBO rule fails to repay a loss, or recovery orders fill far below the on-chain market. The GoodAfterTime floor of the research note then comes back (decision 26).

## Open questions


OD-43, OD-46, OD-47, OD-48 and OD-49 were decided on 2026-10-06. Owed: the fork tests above, the screening vendor's answer on output checks, and the orders budgets from the attested computation.
