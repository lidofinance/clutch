---
type: Decision
title: "ADR 007: Swapping through an orders account"
description: CoW operator and recovery orders, their account, permissions, price controls and limits.
tags: [swaps, cow, orders, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T18:22:59Z
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

- A CoW pre-signature exposes only an order identifier and flag. Tokens, amounts and receiver are hidden in a hash the modifier cannot read [s3].
- The deployed signer computes that hash from a typed order. It runs only by delegatecall, so the calling Safe owns the order. It bounds life and fee; permissions must pin receiver and amounts [s11].
- Conditional orders, including TWAP and stop-loss, need CoW's fallback handler and ComposableCoW as settlement-domain verifier. A watch-tower posts them to the order book [s11].
- The signer, TWAP and stop-loss have no on-chain price check. Roles compares parameters with fixed values; a price check would need new code. GoodAfterTime can check a price checker's expected output at validation, but this is untested for Clutch [s11].
- Zodiac's kit covers CoW, Uniswap v3 only for liquidity, and no 1inch. Unchecked router minimum output exposes swaps to front-running [s11].
- Before 2026-10-06, the design used eight Stonks rebalancing and ten recovery instances, a converter, four feeds and the NEST-shared router [s6]. Stonks pins receivers and price bands [s2]. Chainlink's registry cannot price wstETH, WETH or sUSDS [s6]; depegs can prevent recovery within a band [s9].
- USDS and DAI carry USDC risk. DAI fell to 88 cents during USDC's March 2023 depeg [s9].
- Only a DAO vote can upgrade Lido's withdrawal queue; requests cannot be cancelled [s9].
- The mandate draft permits the emergency path to swap any asset into any of its four main stablecoins [s10].
- On 2026-10-06, the committee requested dollar-cost averaging, standing limits, stop-loss orders, 1inch and Uniswap [s1].

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

Decision 22 adds WETH to decision 4's set. The operator trades WETH in CoW orders, so decision 13's route through stETH is no longer the only one. Staking stays available; the withdrawal queue left the design on 2026-10-08 (decision 27).

EM decided on 2026-10-06, closing OD-47 [s1]:

23. The operator's market and limit orders live at most 30 days. The policy pins the order signer's `validDuration` to at most 30 days.
24. A TWAP order starts at its creation and has at most 30 parts at most a day apart, or at most 4 parts at most 7 days apart, so it ends within 30 days. A stop-loss order's expiry is at most 30 days ahead, through a screening rule requested from the vendor, because no condition can compare the expiry with the current time. Monitoring alerts on any open order older than 30 days, and the emergency Safe can cancel it.
25. A recovery order lives at most 1 day. The policy pins the order signer's `validDuration` for the emergency role to at most 1 day.

EM decided on 2026-10-06, closing OD-48 [s1]:

26. Recovery orders have no on-chain price floor. CoW's solver competition and its EBBO rule hold a fill to at least the on-chain market, and a solver that breaks the rule must refund the user or lose its bond. Every emergency swap pages at high severity, and monitoring alerts on a recovery order whose limit sits far below a market price. A floor through GoodAfterTime stays a research item [s11].

EM decided on 2026-10-08 [s1]:

27. The withdrawal queue leaves the design. The operator neither requests nor claims Lido withdrawals and holds no stETH approval to the queue. The emergency role does not claim.

Decision 27 replaces the withdrawal-queue route of decision 13 and decision 16. Staking through `submit` stays, and WETH is bought in CoW orders (decision 22).

EM decided on 2026-10-09, closing OD-57 [s1]:

28. The orders account carries one modifier, with the operator, emergency and technical roles and no governance role. The technical role stops the operator there by removing the operator Safe's membership of the operator role, with every argument pinned ([ADR 005](/adr/005-account-graph-and-roles.md) decisions 21 and 22).

EM decided on 2026-10-13, after the committee's feedback, closing OD-61 [s1]:

29. Every operator order lives at most 90 days: a market or limit order through the order signer's `validDuration`, a TWAP order through its parts and their spacing, and a stop-loss order through the screening rule of decision 24. Each monthly report lists every open order, with its limit, its age and the idle balance behind it.

Decision 29 replaces the 30-day bounds of decisions 23 and 24. The 30-day alert of decision 24 stays, as a request to confirm or cancel the order. Decision 25 stands: a recovery order lives at most 1 day.

EM decided on 2026-10-13, closing OD-58 [s1]:

30. The orders modifier carries the operator and emergency roles and no governance role. The technical role goes, and the emergency role's revoke stops the operator on the orders account ([ADR 005](/adr/005-account-graph-and-roles.md) decision 25). This replaces the technical role and the membership removal of decision 28.

EM decided on 2026-10-14, closing OD-68 [s1]:

31. The orders modifier gets a governance role, held by the Easy Track executor, without delegatecall. A motion adds a token for ComposableCoW's TWAP and stop-loss orders, which are plain calls.

Decision 31 replaces "no governance role" in decisions 28 and 30, and, for TWAP and stop-loss orders, the DAO vote of decision 21. A token for market, limit and recovery orders still needs a DAO vote (decision 21), because their permission is a delegatecall (OD-36). A fork test comes before decision 31 is relied on.

Since OD-73, Aragon Voting owns the orders account ([ADR 005](/adr/005-account-graph-and-roles.md) decision 28).

EM decided on 2026-10-14, in an interview on OD-68, closing OD-74 [s1]:

32. A token that a motion adds gets TWAP orders, and stop-loss orders only with feeds checked against Chainlink's Feed Registry. Market, limit and recovery orders through the order signer stay a DAO vote.
33. A stop-loss permission pins a Chainlink proxy. The factory accepts a proxy only if its aggregator equals the Feed Registry's feed for the token in USD, at creation and again at enactment. The launch tokens pin proxies too.
34. The Easy Track executor holds an approvals role on the orders modifier. Through it, a motion raises the approval of CoW's vault relayer for any listed token, also after the emergency role set the approval to zero.
35. A token that a motion adds also gets an emergency recovery TWAP, with no delegatecall: it sells the token for USDC or USDT, pays the Aragon Agent and ends within 1 day.
36. The token template ships with the launch. The enabling vote registers it; fork tests come before decision 31 is relied on, and the phase-3 audit covers it.

Decisions 32 to 36 refine decision 31. Decision 34 replaces "no role can raise an approval on the orders account" and the DAO vote that set a zeroed approval again.

EM decided on 2026-10-14, closing OD-76 [s1]:

37. At launch, stop-loss orders cover only stETH, WETH, USDC, USDT and USDS. Before the vote, each of their proxies passes decision 33's check, with the registry's ETH/USD feed for WETH. The registry has no USD feed for wstETH or LDO [s6], so they get TWAP orders only.

EM decided on 2026-10-14, after a count of the launch, closing OD-78 [s1]:

38. The token template does not ship with the launch, and the orders modifier has no governance role and no approvals role. A DAO vote adds a token to the lists, for every order type, with its relayer approval (decision 21), and sets again an approval that the emergency role set to zero.

Decision 38 replaces decisions 31, 32 and 34 to 36. Decision 33 stands for the proxies that the launch tokens pin, without a factory, and decision 37 stands.

EM decided on 2026-10-14, in the 80/20 pass after OD-78, closing OD-79 [s1]:

39. The launch has no stop-loss orders. The orders policy allows no StopLoss handler and pins no oracle, and the vendor gets no request for a stop-loss expiry rule. TWAP orders stay.

Decision 39 replaces the stop-loss parts of decisions 18, 24 and 29, and decisions 33 and 37.

Since OD-91, LDO is out of the launch list, so it leaves the rebalancing set of decision 4 and the operator's lists of decision 22 ([ADR 011](/adr/011-launch-scope.md), decision 15).

Since OD-89, the TM Floor Value of decision 16 means one mandate size ([ADR 008](/adr/008-funding-through-existing-payments.md), decisions 32 to 34).

## Proposed direction

The rest of this section is agent-drafted [s4][s11]. EM has not accepted it as text.

- **Orders account.** A new Safe owned one-of-one by Voting ([ADR 005](/adr/005-account-graph-and-roles.md), decision 28). It uses `ExtensibleFallbackHandler` and ComposableCoW for CoW's settlement domain. The enabling vote configures its single modifier, with the account as owner, avatar and target, and `operator` and `emergency` roles only (decisions 28 and 30).
- **Operator funding.** On the Asset Safe, each listed-token transfer is pinned to the orders account and spends that token's orders budget, from the attested computation.
- **Operator orders.**
  - Delegatecall the order signer with listed tokens, the Asset Safe as receiver, a fee bound and at most 90 days' life (decision 29). The signer refuses `validTo` beyond `validDuration`; `unsignOrder` cancels.
  - Use only ComposableCoW's TWAP handler, with listed tokens and the Asset Safe as receiver; no stop-loss (decision 39). `createWithContext`, start zero and CoW's current-timestamp value factory make creation the start. Permit at most 90 parts at most a day apart, or at most 12 parts at most 7 days apart, ending within 90 days (decision 29). `remove` cancels.
  - Transfer any token back to the Asset Safe.
- **Emergency actions.** From the Asset Safe, transfer any asset to orders or the Agent. On orders, cancel any order, revoke operator targets/functions, zero CoW relayer approvals, and transfer listed tokens to the Aragon Agent or the Asset Safe. Signer recovery orders buy USDC or USDT, pay the Agent and last at most 1 day (decision 25).
- **Stop.** Revoke `operator` targets and functions on the orders modifier (decision 30). Every operator permission there uses the `operator` key, so revocation reaches all of them. Revocation does not cancel resting orders; cancel them too, because fills never consult the policy. A 2026-10-08 fork probe demonstrated emergency revocation on a stand-in modifier.
- **Re-affirmation.** At 30 days, alert the committee to confirm or cancel each open order. Monthly reports list its limit, age, distance to market and idle balance (decision 29). Neither control acts on chain. Removing a token or tightening a bound also requires cancellation of affected orders.
- **Relayer approvals.** The enabling vote has the orders account approve CoW's vault relayer for the maximum amount of all listed tokens, including recovery tokens. No role can raise an orders-account approval, so operator revocation leaves recovery settlement available. Zeroing an approval stops all orders in that token until a DAO vote restores it; transfer to the Agent remains available.
- **Governance.** The orders account has no `governance` role (decisions 28 and 38). Tokens require DAO votes (decision 21), as does the signer's delegatecall (OD-36). Asset Safe governance refuses the orders account and its modifier (OD-38).
- **Tokens.** Operator lists start with decision 22. Recovery sells the launch list except ETH, which is staked first, and Earn shares, which use redeem queues. Recovery buys USDC, with USDT second. The enabling vote sets both lists.
- **Routers.** None at launch. Uniswap and 1inch routes from the orders account, paying the Asset Safe, wait for the screening vendor's confirmation of a market-relative minimum-output check.
- **Price controls.** Controls are order terms, CoW competition and EBBO, operator screening, funding budgets and fill monitoring (decision 26). Nothing on chain bounds the price; CoW competition and EBBO hold a fill to the on-chain market. Emergency orders have neither screening nor budgets; paging and limit alerts cover them.
- **Monitoring.** Watch open and conditional orders, 30-day confirmations, low recovery limits, idle tokens and each fill against market. Owner, threshold, module, fallback-handler and domain-verifier changes are critical. Watch relayer approvals and posting by the watch-tower.

## Options considered

- **Stonks for both roles:** EM replaced this on 2026-10-06 (OD-43). It lacks limit, TWAP and stop-loss orders, needs eighteen instances plus converter, four feeds and the shared router, and can block recovery in a depeg.
- **Stonks plus an orders account:** EM rejected because it retains both component sets.
- **Asset Safe as order owner:** rejected because conditional orders require its forbidden fallback handler ([ADR 005](/adr/005-account-graph-and-roles.md), decision 15). Market orders would require Asset Safe delegatecall.
- **Uniswap/1inch at launch:** EM rejected pending screening of minimum output, which Roles cannot bound against market.
- **Custom modifier price check:** rejected as new non-factory code ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 1).
- **Direct pre-signing:** rejected because it hides order terms [s3]. The typed-order signer exposes them.
- **Budgeted withdrawal-queue approval:** EM rejected because it needs another attested figure. Only the DAO upgrades the queue, and claims pay the Asset Safe [s9].
- **Keep unstaking at par through the queue:** EM replaced this on 2026-10-08 (decision 27). CoW already buys WETH; queue requests cannot be cancelled.
- **30-day life with monthly renewal:** EM replaced this on 2026-10-13 after the committee requested longer-lived limits (decision 29).
- **One-year life:** EM rejected. CoW's book permits it, but pre-signed orders have no CoW maximum, and resting orders outlive their original context. Clutch needs its own bound.

## Consequences

- The LIP and mandate must disclose the absent on-chain price bound and the replacement controls.
- The orders account holds assets between transfer and fill, through fallback and contract-signature paths avoided by the Asset Safe. Operator funding is budgeted; emergency funding is not, so incident exposure can approach the vault's holdings. Fallback-handler and domain-verifier changes are critical alerts. The LIP must disclose custody in transit.
- If the watch-tower stops, conditional orders wait and no funds move.
- Operator transactions come from the committee's Safe, so the screening guard checks them. Three emergency signers, possibly without a committee member, choose unscreened recovery limits without an oracle floor ([ADR 005](/adr/005-account-graph-and-roles.md), decision 24). CoW's rules for the on-chain market, high-severity swap paging and low-limit alerts are the controls (decision 26).
- Decision 19's "always" applies to safety-listed tokens. Each onboarding motion adds its token's emergency transfer to the Agent (OD-49); recovery orders for new tokens still need a vote (decision 21).
- Operator proceeds pay the Asset Safe; recovery pays the Agent. These destinations are explicit.
- A recovery order names its own limit, so it can fill in a depeg at a price the emergency signers accept. The service level measures initiation, not fill time.
- Chainlink's Feed Registry, the shared Stonks router and its committee manager no longer affect the vault (OD-45). Router settings no longer provide an untimelocked lever on the vault.
- Recovery sells wstETH, WETH and sUSDS directly. Operator WETH swaps can complete in minutes. Staking remains; unstaking uses CoW only (decision 27).
- New tokens require DAO votes. The launch lists cover mandate assets, so additions should be rare.
- Resting orders remain authorized for up to 90 days despite changes in price or context. The 30-day alert and monthly report prompt confirmation. Their backing tokens remain idle in orders.
- The new Safe and modifier reuse existing code (decision 28). The enabling vote grants the signer's delegatecall; a motion cannot (OD-36).
- This repository found no audit of the 40-line order signer. Lido reviews it in phase 3.
- Without the withdrawal queue, neither operator error nor a captured quorum can create uncancellable stETH requests [s9]. Large unstaking trades at CoW market prices rather than queue par (decision 27).
- The mandate must update venues, order types, the missing on-chain price bound and USDC/USDT recovery [s10] ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).

## Confirmation

- INV-002, INV-008, INV-013, INV-014, INV-022, INV-023 and INV-024 in the [invariants](/specs/invariants.md).
- Existing kit coverage: no Asset Safe pre-signing or relayer approval [s5]; staking with the Safe as owner [s7]; both roles refused the withdrawal queue (`test_D3_withdrawal_queue_is_out_of_scope`); WETH unwrap pays the Safe [s8].
- Fork tests still owed:
  - Signer delegatecall from Safe v1.5.0 through Roles, with receiver pinning.
  - TWAP from Safe v1.5.0 with CoW's handler; receiver conditions inside ComposableCoW's encoded data; refusal of other receivers.
  - Life limits of decisions 25 and 29, including refusal of TWAP outside both allowed shapes.
  - Emergency cancel, sweep and recovery settlement with the vote's relayer approval.
  - Emergency revocation on the orders modifier, with recovery still available (decision 30).

## Reversal conditions

- A fork test shows that CoW's fallback handler or the order signer does not work with a Safe v1.5.0 behind a roles modifier.
- Fills under stress break the six-hour time to initiate.
- Monitoring shows fills below a market price beyond the mandate's tolerance.
- CoW's watch-tower proves unreliable for the conditional orders that the committee depends on.
- The screening guard cannot check the operator's transactions on the orders account.
- CoW's EBBO rule fails to repay a loss, or recovery orders fill far below the on-chain market. The GoodAfterTime floor of the research note then comes back (decision 26).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

Owed: the fork tests above, the screening vendor's answer on output checks, and the orders budgets from the attested computation.
