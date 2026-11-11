---
type: Decision
title: "ADR 007: Swapping through an orders account"
description: CoW orders of the operator and of recovery from the orders account, with its permissions, token lists, order life, price controls and restore.
tags: [swaps, cow, orders, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-11-11T04:32:12Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on swaps, recovery and the orders account, 2026-09-22 to 2026-11-10
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L211"
    title: Kit test at 370e20a — an order pre-signature is opaque to the modifier
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L875"
    title: Kit test at 7a8c661 — the operator cannot pre-sign an order or approve the CoW relayer from the Asset Safe
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
28. The orders account carries one modifier, with the operator and emergency roles and the universal factory's governance and approvals roles, as [ADR 005](/adr/005-account-graph-and-roles.md) decision 21 states (OD-57, OD-58, OD-103, OD-118).
29. Every operator order lives at most 90 days: a market or limit order through the order signer's `validDuration`, and a TWAP order through its parts and their spacing. Each monthly report lists every open order, with its limit, its age and the idle balance behind it (OD-61, OD-79).
30. The emergency role's revoke stops the operator on the orders account, as [ADR 005](/adr/005-account-graph-and-roles.md) decision 25 states (OD-58).
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
46. One motion restores the orders account after an emergency stop. The motion states the current lists, and the factory checks them against their version. For the operator, the motion writes again the two targets, the order trees, the two cancels and, for each operator token, the transfer back to the Asset Safe or the Aragon Agent. Through the approvals role, it raises again the relayer approval of each recovery token that it names. It writes no version, and no other operation in the same motion may change the lists (OD-119).

## Proposed direction

The rest of this section is agent-drafted [s11]. EM has not accepted it as text.

- **Orders account.** A Safe v1.5.0 that Voting owns one of one ([ADR 005](/adr/005-account-graph-and-roles.md) decisions 13 and 28). It uses `ExtensibleFallbackHandler`, with ComposableCoW as the verifier of CoW's settlement domain. The enabling vote configures its one modifier, with the account as owner, avatar and target (decision 28).
- **Operator funding.** On the Asset Safe, each listed token's transfer is pinned to the orders account and spends that token's orders budget, from the attested computation.
- **Operator orders.**
  - Delegatecall the order signer with listed tokens, the Asset Safe as receiver, plain ERC-20 balances, zero app data (decision 42), no signed fee (decision 43) and at most 90 days' life (decision 29). The signer refuses a `validTo` beyond `validDuration`; `unsignOrder` cancels.
  - Use only ComposableCoW's TWAP handler, with listed tokens, the Asset Safe as receiver and zero app data. `createWithContext`, a start of zero and CoW's current-timestamp value factory make the creation the start. Permit at most 90 parts at most a day apart, or at most 12 parts at most 7 days apart, ending within 90 days (decision 29). `remove` cancels.
  - Transfer any listed token back to the Asset Safe, or to the Aragon Agent by a transfer pinned to it ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 9).
- **Emergency actions.** From the Asset Safe, transfer any asset to the orders account or the Agent. On the orders account, cancel any order, revoke operator targets and functions, zero CoW relayer approvals, and transfer listed tokens to the Aragon Agent or the Asset Safe. Signer recovery orders buy USDC or USDT, pay the Agent and last at most 1 day (decision 25).
- **Stop and restore.** Revoke `operator` targets and functions on the orders modifier (decision 30). Every operator permission there uses the `operator` key, so the revokes reach all of them. A revoke does not cancel resting orders; cancel them too, because fills never consult the policy. The restore motion brings the operator back after its objection window (decision 46).
- **Re-affirmation.** At 30 days, alert the committee to confirm or cancel each open order. Monthly reports list its limit, age, distance to market and idle balance (decision 29). Neither control acts on chain. Removing a token or tightening a bound also needs the cancellation of the affected orders.
- **Relayer approvals.** The enabling vote has the orders account approve CoW's vault relayer for the maximum amount of every token that an order sells. Only the approvals role raises an approval of the orders account, and only for the relayer, so a revoke of the operator leaves recovery settlement working. A token motion approves its new token (decision 41), and the restore motion raises again an approval that the emergency role set to zero (decision 46). Until then, a zero approval stops every order in that token; the transfer to the Agent stays available.
- **Governance.** The governance role writes the factory's two orders operations ([ADR 013](/adr/013-one-easy-track-factory.md) decision 18): the token motion (decisions 41, 44 and 45) and the restore (decision 46). It refuses the vault's accounts as targets. The Asset Safe's governance refuses the orders account and its modifier (OD-38).
- **Tokens.** Recovery sells stETH, wstETH, WETH, USDC, USDT, DAI, USDS and sUSDS: every launch asset of the Asset Safe except ETH, which is staked first, and Earn shares, which leave through their redeem queues. Recovery buys USDC, with USDT second (decision 5). The enabling vote sets both lists, and motions extend them (decision 41).
- **Routers.** None at launch. Uniswap and 1inch routes from the orders account, paying the Asset Safe, wait for the screening vendor's confirmation of a market-relative minimum-output check (decision 20).
- **Price controls.** The controls are the order terms, CoW's competition and EBBO, the screening of the operator once the guard is set, the funding budgets and fill monitoring (decision 26). Nothing on chain bounds the price. Emergency orders have neither screening nor budgets; paging and limit alerts cover them.
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

- The orders account holds assets between transfer and fill, through fallback and contract-signature paths that the Asset Safe avoids. Operator funding is budgeted; emergency funding is not, so the exposure in an incident can approach the vault's holdings. Fallback-handler and domain-verifier changes are critical alerts. The LIP must disclose the custody in transit.
- If the watch-tower stops, conditional orders wait and no funds move.
- Operator transactions come from the committee's Safe, so the screening guard checks them once it is set, before the second tranche's vote starts ([ADR 010](/adr/010-pre-execution-screening.md) decision 22). Three emergency signers, possibly without a committee member, choose unscreened recovery limits without an oracle floor ([ADR 005](/adr/005-account-graph-and-roles.md) decision 24). CoW's rules for the on-chain market, high-severity swap paging and low-limit alerts are the controls (decision 26).
- Decision 19's "always" applies to the tokens that the safety policy lists. Each onboarding motion adds its token's emergency transfer to the Agent (OD-49), and a token motion adds its recovery orders (decision 41).
- Operator proceeds pay the Asset Safe; recovery pays the Agent.
- A recovery order names its own limit, so it can fill in a depeg at a price that the emergency signers accept. The service level measures initiation, not fill time.
- No price feed or shared router sits in the swap path, so no outside setting is an untimelocked lever on the vault (OD-45).
- Recovery sells wstETH, WETH and sUSDS directly. Unstaking goes through CoW orders only (decision 27).
- New tokens join by motion, on the sell side and the buy side (decision 41). The launch lists cover the mandate's assets, so additions should be rare.
- Resting orders stay authorized for up to 90 days, whatever the price or context. The 30-day alert and the monthly report prompt a confirmation. Their tokens sit idle in the orders account.
- The orders account and its modifier reuse deployed code. The enabling vote grants the order signer's delegatecall for the launch tokens, and each token motion writes it again with the new token (decision 41).
- Without the withdrawal queue, neither an operator error nor a captured quorum can create uncancellable stETH requests [s9].
- The mandate draft lets the emergency path swap into any of the four main stablecoins [s10]. The Snapshot text names CoW orders through the orders account as the only venue and states that nothing on chain bounds their price (OD-90). The forum post names USDC, then USDT, as the recovery destinations and carries the control matrix.

## Confirmation

- INV-002, INV-008, INV-013, INV-014, INV-022, INV-023, INV-024 and INV-040 in the [invariants](/specs/invariants.md).
- Kit tests: no Asset Safe pre-signing or relayer approval [s5]; staking with the Safe as owner [s7]; both roles refused the withdrawal queue (`test_D3_withdrawal_queue_is_out_of_scope`); a WETH unwrap pays the Safe [s8].
- Fork tests on the enabling vote's vault, each order settled through CoW's settlement contract ([research note](/research/orders-account-fork-tests-2026-11-07.md)):
  - The signer's delegatecall from Safe v1.5.0 through Roles, with the receiver pinned (`test_orders_signer_order_settles_to_the_asset_safe`, `test_orders_signer_refusals`).
  - TWAP from Safe v1.5.0 with CoW's handler, the receiver conditions inside ComposableCoW's encoded data, and the refusal of other receivers (`test_orders_twap_part_settles_through_the_fallback_handler`, `test_orders_twap_refusals`).
  - The life limits of decisions 25 and 29, and the refusal of a TWAP outside both allowed shapes (the refusal tests).
  - The emergency cancel, sweep and recovery settlement with the vote's relayer approval (`test_orders_emergency_cancels_sweeps_and_recovers`), and the emergency revoke with recovery still working (`test_orders_emergency_revocation_keeps_recovery`).
- Fork tests of the orders roles ([research note](/research/orders-motion-roles-2026-11-08.md)):
  - The governance role's keys and targets, its one delegatecall, its pinned trees and its restores (`test_orders_governance_writes_only_its_keys_and_targets`, `test_orders_governance_grants_delegatecall_only_for_the_signer`, `test_orders_governance_pins_transfers_and_approvals`, `test_orders_governance_restores_what_the_emergency_role_revoked`).
  - The approvals role, which raises a zero approval for the relayer only (`test_orders_approvals_role_approves_only_the_relayer`).
  - The exit-governance role, which writes only the emergency role's exits, and a new token's exit on the Asset Safe (`test_exit_governance_writes_only_exits`, `test_exit_governance_gives_a_new_token_its_exit`).
  - A token motion's writes, run by hand; orders in the token then settle, and so does a recovery order after the emergency role moved the token from the Asset Safe (`test_orders_motion_adds_a_token`).
- Fork tests of the universal factory's orders operations through the live Easy Track ([research note](/research/orders-token-motions-2026-11-08.md)): the trees in the compiler's form; one motion that adds a token, in 7,789,536 gas under EIP-7825's cap with cold accounts, after which orders in the token settle; the checks; and versions that keep two token motions apart (`test_factory_orders_trees_match_the_compiler`, `test_factory_orders_token_motion`, `test_factory_orders_token_refusals`, `test_factory_orders_tokens_one_after_another`). One motion restores the orders account after an emergency stop, in 7,102,619 gas, and an order then settles; the restore refuses stale lists, a token outside recovery's list, an unsorted approval list and a token operation in the same motion (`test_factory_orders_restore_after_an_emergency_stop`, `test_factory_orders_restore_refusals`).
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
