---
type: Decision
title: "ADR 007: Swapping through an orders account"
description: CoW orders of the operator and of recovery from the orders account, with its permissions, token lists, order life, price controls and restore.
tags: [swaps, cow, orders, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:38:25Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on swaps, recovery and the orders account, 2026-09-22 to 2026-11-10
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L211"
    title: Kit test at 370e20a — an order pre-signature is opaque to the modifier
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L582"
    title: Kit test at 7a8c661 — staking, a withdrawal-queue round trip with the Asset Safe as owner, and a wrap into WETH
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L699"
    title: Kit test at 7a8c661 — the emergency role unwraps WETH into the Asset Safe through WETH's 2,300-gas transfer, stakes the ETH and sends the stETH to the Agent
  - id: s9
    resource: /research/recovery-and-withdrawal-queue-2026-10-05.md
    title: Recovery into USDT and the withdrawal-queue approval, 2026-10-05 — USDC risk in USDS and DAI, and the withdrawal queue's upgrader, limits and missing cancel
  - id: s10
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the emergency path may swap any asset into any of the four main stablecoins; outside the repository until the mandate is published
  - id: s11
    resource: /research/cow-orders-account-2026-10-06.md
    title: CoW orders from a dedicated orders account, 2026-10-06 — the order signer, ComposableCoW, the fallback-handler requirement, the watch-tower, router swaps and the hosted app
---

# ADR 007: Swapping through an orders account

## Context

- A CoW pre-signature exposes only an order identifier and a flag. Tokens, amounts and receiver hide in a hash that the modifier cannot read [s3].
- The deployed order signer computes that hash from a typed order. It runs only by delegatecall, so the calling Safe owns the order. It bounds life and fee; the permissions must pin receiver and amounts [s11].
- Conditional orders, TWAP included, need CoW's fallback handler and ComposableCoW as the verifier of the settlement domain. A watch-tower posts them to the order book [s11].
- The order signer and TWAP orders have no on-chain price check. Roles compares parameters with fixed values; a price check would need new code. GoodAfterTime can check a price checker's expected output at validation, but Clutch has not tested it [s11].
- Zodiac's kit covers CoW, Uniswap v3 only for liquidity, and no 1inch. An unchecked minimum output on a router exposes a swap to front-running [s11].
- USDS and DAI carry USDC risk. DAI fell to 88 cents during USDC's depeg of March 2023 [s9].
- Only a DAO vote can upgrade Lido's withdrawal queue, and its requests cannot be cancelled [s9].
- The mandate draft permits the emergency path to swap any asset into any of its four main stablecoins [s10].
- On 2026-10-06, the committee asked for dollar-cost averaging, standing limits, stop-loss orders, 1inch and Uniswap [s1].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Replaced by decision 17 (OD-43).
2. Recovery covers stablecoin-to-stablecoin swaps too (decision log, 2026-09-22).
3. Replaced by decision 17 (OD-43).
4. Replaced by decision 22 (OD-46).
5. Recovery has a second destination, USDT, and it is mandatory (decision log, 2026-09-22).
6. Replaced by decision 17 (OD-43).
7. Replaced by decision 17 (OD-43).
8. Replaced by decision 17 (OD-43).
9. Lapsed (OD-43): the orders account needs no router, converter or price feed.
10. Lapsed (OD-43): the orders account needs no router, converter or price feed.
11. Lapsed (OD-43): the orders account needs no router, converter or price feed.
12. Replaced by decision 17 (OD-43).
13. The operator and the emergency role may stake ETH through Lido's `submit` and unwrap WETH. The operator may also wrap ETH into WETH (OD-20).
14. Lapsed (OD-43): the orders account needs no router, converter or price feed.
15. Recovery also sells USDC, USDS and DAI into USDT, so every stablecoin that carries USDC risk can leave USDC (OD-26, OD-27).
16. Replaced by decision 27 (decision log, 2026-10-08).
17. A dedicated orders account carries the CoW orders of the operator and of the emergency role. It is a Safe that Aragon Voting owns one of one, with CoW's fallback handler and one modifier (OD-43, OD-57, OD-73).
18. The operator funds the orders account by transfers pinned to it, under budgets. From it, the operator places CoW market, limit and TWAP orders whose proceeds go to the Asset Safe (OD-43, OD-79).
19. The emergency role places orders whose proceeds go to the Aragon Agent, and can always send assets to the Agent (OD-43).
20. The launch uses CoW only. Uniswap and 1inch come only if the screening vendor can bound a swap's minimum output before execution (OD-43).
21. Replaced by decision 41 (OD-103).
22. The operator's lists start with stETH, wstETH, WETH, USDC, USDT and USDS. DAI and sUSDS stay off (OD-46, OD-91).
23. Replaced by decision 29 (OD-61).
24. A TWAP order starts at its creation. Monitoring alerts on any open order older than 30 days, as a request to confirm or cancel it, and the emergency Safe can cancel the order (OD-47, OD-61, OD-79).
25. A recovery order lives at most 1 day. The policy pins the order signer's `validDuration` for the emergency role to at most 1 day (OD-47).
26. Recovery orders have no on-chain price floor. CoW's solver competition and its EBBO rule hold a fill to at least the on-chain market, and a solver that breaks the rule must refund the user or lose its bond. Every emergency swap pages at high severity, and monitoring alerts on a recovery order whose limit sits far below a market price. A floor through GoodAfterTime stays a research item [s11] (OD-48).
27. The vault does not use Lido's withdrawal queue. The operator neither requests nor claims Lido withdrawals and holds no stETH approval to the queue. The emergency role does not claim (decision log, 2026-10-08).
28. Stated by [ADR 005](/adr/005-account-graph-and-roles.md) decision 21.
29. Every operator order lives at most 90 days: a market or limit order through the order signer's `validDuration`, and a TWAP order through its parts and their spacing. Each monthly report lists every open order, with its limit, its age and the idle balance behind it (OD-61, OD-79).
30. Stated by [ADR 005](/adr/005-account-graph-and-roles.md) decision 25.
31. Replaced by decision 41 (OD-78, OD-103).
32. Replaced by decision 41 (OD-78, OD-103).
33. Replaced by decision 39 (OD-79).
34. Replaced by decision 41 (OD-78, OD-103).
35. Replaced by decision 41 (OD-78, OD-103).
36. Replaced by decision 41 (OD-78, OD-103).
37. Replaced by decision 39 (OD-79).
38. Replaced by decision 41 (OD-103).
39. The launch has no stop-loss orders. The orders policy allows no StopLoss handler and pins no oracle, and the screening vendor gets no request for a stop-loss expiry rule (OD-79).
40. CoW's order signer is deployed code that Lido reuses and does not deploy. It has no known audit, so it counts as new code with the universal factory, and the external audit covers both (OD-96, OD-102).
41. The operator places market and limit orders through CoW's order signer. The universal factory holds the orders modifier's governance and approvals roles. One motion adds a token to the lists, on the sell side and on the buy side, with its relayer approval, its emergency transfer and its recovery orders. The governance role grants delegatecall only to the order signer, for signing and unsigning orders (OD-103, OD-118).
42. Every order of the orders account carries zero app data, so it carries no hooks and no partner fee (OD-115).
43. An order of the orders account signs no fee. The policy pins the order's own fee field to zero, and the order signer's fee bound stays zero. CoW's order book refuses a signed fee, and CoW charges its fees inside the execution, within the order's limit (OD-116).
44. The orders modifier's governance role writes, under the approvals key, only the relayer approval. It pins whole each tree that does not depend on the token: the return to the Asset Safe or the Aragon Agent, for the operator and the emergency role; the emergency role's zeroing of the relayer's approval; and the relayer approval. So no motion gives a role another receiver or spender, and only the approvals role raises an approval (OD-103).
45. The motion that adds a token to the order lists also writes the token's exit on the Asset Safe, through the exit-governance role: a transfer to the Aragon Agent, or to the orders account, where a recovery order sells it (OD-49).
46. One motion restores the orders account after an emergency stop. For the operator, the motion writes again the two targets, the order trees, the two cancels and, for each operator token, the transfer back to the Asset Safe or the Aragon Agent. Through the approvals role, it raises again the relayer approval of each recovery token that it names. The motion carries the order trees with the current lists, and the factory does not check them (OD-119, OD-134).

## Proposed direction

The rest of this section is agent-drafted [s11]. EM has not accepted it as text.

- **Orders account.** A Safe v1.5.0 ([ADR 005](/adr/005-account-graph-and-roles.md) decision 13) with `ExtensibleFallbackHandler`, and ComposableCoW as the verifier of CoW's settlement domain. The enabling vote configures its one modifier, with the account as owner, avatar and target ([ADR 005](/adr/005-account-graph-and-roles.md) decision 21).
- **Operator funding.** Each listed token's transfer to the orders account spends that token's orders budget (decision 18).
- **Operator orders.**
  - Delegatecall the order signer with listed tokens, the Asset Safe as receiver and plain ERC-20 balances (decisions 29, 42 and 43). The signer refuses a `validTo` beyond `validDuration`; `unsignOrder` cancels.
  - Use only ComposableCoW's TWAP handler, with the same tokens and receiver. `createWithContext`, a start of zero and CoW's current-timestamp value factory make the creation the start. Permit at most 90 parts at most a day apart, or at most 12 parts at most 7 days apart (decision 29). `remove` cancels.
  - Transfer any listed token back to the Asset Safe, or to the Aragon Agent ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 9).
- **Emergency actions.** The `emergency` row of the role table in [ADR 005](/adr/005-account-graph-and-roles.md#proposed-direction) lists them. Recovery orders are signer orders (decision 25).
- **Stop and restore.** The emergency role's revoke ([ADR 005](/adr/005-account-graph-and-roles.md) decision 25) reaches every operator permission (INV-018). A revoke does not cancel resting orders; cancel them too, because fills never consult the policy. Decision 46 restores the operator.
- **Re-affirmation.** The 30-day alert (decision 24) and the monthly report (decision 29), which also shows each order's distance to market, do not act on chain. Removing a token or tightening a bound also needs the cancellation of the affected orders.
- **Relayer approvals.** The enabling vote has the orders account approve CoW's vault relayer for the maximum amount of every token that an order sells. A zero approval stops every order in that token until a motion raises it again (decisions 44 and 46); the transfer to the Agent stays available.
- **Governance.** A motion writes through the orders modifier's governance and approvals roles ([ADR 013](/adr/013-one-easy-track-factory.md) decision 18): the token motion (decisions 41, 44 and 45) and the restore (decision 46). The governance role's policy leaves the content of an order tree, whose token lists change, to the motion ([ADR 013](/adr/013-one-easy-track-factory.md) decision 11). No governance role takes a vault account or its modifier as a target (OD-38; INV-004, INV-040).
- **Tokens.** Recovery sells stETH, wstETH, WETH, USDC, USDT, DAI, USDS and sUSDS: every launch asset of the Asset Safe except ETH, which is staked first, and Earn shares, which leave through their redeem queues. Recovery buys USDC, with USDT second (decision 5). The enabling vote sets both lists, and motions extend them (decision 41).
- **Routers.** None at launch (decision 20). A later Uniswap or 1inch route runs from the orders account, pays the Asset Safe and needs a market-relative minimum-output check.
- **Price controls.** Nothing on chain bounds the price. The [threat model](/specs/threat-model.md) lists the controls of operator orders. Emergency orders have neither screening nor budgets; decision 26 states their controls.
- **Monitoring.** Watch open and conditional orders, 30-day confirmations, low recovery limits, idle tokens and each fill against the market. Owner, threshold, module, fallback-handler and domain-verifier changes are critical. Watch the relayer approvals and the watch-tower's posting.

## Options considered

- **Stonks 2.0 instances:** not chosen (OD-43). They lack limit and TWAP orders, need an instance per pair, a converter, feeds and a shared router, and a depeg can block recovery.
- **The Asset Safe as order owner:** not chosen. Conditional orders need a fallback handler, which the Asset Safe must not have ([ADR 005](/adr/005-account-graph-and-roles.md) decision 15), and market orders would need its delegatecall.
- **Uniswap and 1inch at launch:** not chosen until screening can bound a swap's minimum output, which Roles cannot bound against the market (decision 20).
- **A price check in a custom modifier:** not chosen. It is new code beyond the universal factory ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 1).
- **Direct pre-signing:** not chosen. It hides the order's terms [s3]; the typed-order signer exposes them.
- **Unstaking through Lido's withdrawal queue:** not chosen (decision 27). Its requests cannot be cancelled, only a DAO vote upgrades it [s9], and CoW orders buy WETH.
- **A shorter or a longer order life:** not chosen (decision 29). A 30-day life forces the monthly renewals that the committee asked to avoid. A year lets resting orders outlive their context; pre-signed orders have no CoW maximum, so Clutch needs its own bound.

## Consequences

- The orders account holds assets between transfer and fill. Operator funding is budgeted; emergency funding is not, so the exposure in an incident can approach the vault's holdings. The LIP must disclose the custody in transit.
- Three emergency signers, possibly without a committee member, choose unscreened recovery limits without an oracle floor ([ADR 005](/adr/005-account-graph-and-roles.md) decision 24; decision 26).
- Decision 19's "always" applies to the tokens that the safety policy lists; motions add the others ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13; decisions 41 and 45).
- A recovery order names its own limit, so it can fill in a depeg at a price that the emergency signers accept. The service level measures initiation, not fill time.
- No price feed or shared router sits in the swap path, so no outside setting is an untimelocked lever on the vault (OD-45).
- The launch lists cover the mandate's assets, so token motions (decision 41) should be rare.
- Resting orders stay authorized for up to 90 days, whatever the price or context, and their tokens sit idle in the orders account.
- The enabling vote grants the order signer's delegatecall for the launch tokens, and each token motion writes it again with the new token (decision 41).
- Without the withdrawal queue, neither an operator error nor a captured quorum can create uncancellable stETH requests [s9].
- The Snapshot text and the forum post state the swap venue, the missing price bound and the recovery destinations ([enabling vote](/specs/enabling-vote.md)) (OD-90).

## Confirmation

- INV-002, INV-008, INV-013, INV-014, INV-022, INV-023, INV-024, INV-025 and INV-040 in the [invariants](/specs/invariants.md). INV-034 names the tests of the two orders motions.
- Kit tests: staking with the Safe as owner [s7]; a WETH unwrap pays the Safe [s8].
- Fork tests on the enabling vote's vault: signer and TWAP orders from Safe v1.5.0, each settled through CoW's settlement contract ([research note](/research/orders-account-fork-tests-2026-11-07.md)).
- Fork tests of the orders roles ([research note](/research/orders-motion-roles-2026-11-08.md)), and of the two orders motions through the live Easy Track (`test/OrdersAccount.t.sol`); their gas is in [ADR 013](/adr/013-one-easy-track-factory.md#confirmation).
- After a restore motion, an order settles. The restore refuses stale lists, a token outside recovery's list, an unsorted approval list and a token operation in the same motion.
- Still owed: the order book's acceptance of zero app data, the watch-tower's posting of TWAP parts, the screening vendor's answer on output checks, and the orders budgets from the attested computation.

## Reversal conditions

- A fork test shows that CoW's fallback handler or the order signer does not work with a Safe v1.5.0 behind a roles modifier.
- Fills under stress break the six-hour time to initiate.
- Monitoring shows fills below a market price beyond the mandate's tolerance.
- CoW's watch-tower proves unreliable for the conditional orders that the committee depends on.
- The screening guard cannot check the operator's transactions on the orders account.
- CoW's EBBO rule fails to repay a loss, or recovery orders fill far below the on-chain market. Then the GoodAfterTime floor of the research note is the next step (decision 26).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
