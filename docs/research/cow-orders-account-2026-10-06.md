---
type: Research Note
title: CoW orders from a dedicated orders account, 2026-10-06
description: The evidence behind OD-43 and OD-48 — what the deployed CoW order signer and ComposableCoW enforce, what a Safe needs for TWAP and stop-loss orders, how CoW's rules hold a fill to the market, why GoodAfterTime's price check does not fit recovery orders yet, what Zodiac's own kit covers for CoW, Uniswap and 1inch, why the roles modifier cannot bound a price, and what the hosted Zodiac app shows today.
tags: [swaps, cow, composable-cow, orders, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-06
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T18:32:34Z
verified: []
sources:
  - id: s1
    resource: "https://kit.kpk.io/learn/protocols/cowswap/ethereum"
    title: kpk DeFi Kit, CoW Swap on Ethereum — the permissions that Zodiac's kit grants for market orders through the order signer and for TWAP orders through ComposableCoW, read on 2026-10-06
  - id: s2
    resource: "https://eth.blockscout.com/address/0x23dA9AdE38E4477b23770DeD512fD37b12381FAB?tab=contract"
    title: CowswapOrderSigner, verified source on Blockscout — delegatecall only, the expiry bound and the fee bound, read on 2026-10-06
  - id: s3
    resource: "https://github.com/cowprotocol/composable-cow/tree/c0435953ac8312a606d66c91554f2bb4d22ec686"
    title: ComposableCoW at c043595 — the README's Safe setup, handlers, audits and mainnet deployments
  - id: s4
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/types/StopLoss.sol#L47-L102"
    title: ComposableCoW StopLoss at c043595 — the order data, including the two oracles, and the strike check
  - id: s5
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/types/twap/libraries/TWAPOrder.sol#L31-L42"
    title: ComposableCoW TWAP at c043595 — the order data, including the receiver and the minimum per part
  - id: s6
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/ComposableCoW.sol#L113-L152"
    title: ComposableCoW at c043595 — create, createWithContext and remove
  - id: s7
    resource: "https://docs.cow.fi/cow-protocol/reference/contracts/periphery/composable-cow"
    title: CoW Protocol documentation, ComposableCoW — conditional orders need a watch-tower to reach the order book, read on 2026-10-06
  - id: s8
    resource: "https://kit.kpk.io/learn/protocols"
    title: kpk DeFi Kit protocol list — Uniswap v3 covers liquidity actions only, and 1inch is not covered, read on 2026-10-06
  - id: s9
    resource: "https://www.zodiac.eco/"
    title: Zodiac product page — the features of the hosted app, read on 2026-10-06
  - id: s10
    resource: /research/zodiac-constellation-2026-10-06.md
    title: The Zodiac constellation note — the provider's own swap entry, a CoW action with a TODO for bounds
  - id: s11
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the Stonks 2.0 design that OD-43 replaces, and its consequences under stress
  - id: s12
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/README.md?plain=1#L130-L181"
    title: ComposableCoW README at c043595 — handler compatibility with CoW's poller, mainnet deployments, and the scope of the audits
  - id: s13
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/types/GoodAfterTime.sol#L21-L90"
    title: ComposableCoW GoodAfterTime at c043595 — the optional price checker and its slippage bound
  - id: s14
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/cow-protocol/reference/core/auctions/competition_rules.md?plain=1#L16-L21"
    title: CoW competition rules at 3df4739 — the limit-price constraint, whitelisted solvers, and scores by the surplus for users
  - id: s15
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/cow-protocol/reference/core/auctions/competition_rules.md?plain=1#L81-L85"
    title: CoW competition rules at 3df4739 — penalties and slashing, and the EBBO rule that clearing prices match or beat the AMMs
  - id: s16
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/cow-protocol/reference/core/auctions/ebbo_specifics.md?plain=1#L15-L36"
    title: CoW EBBO violations at 3df4739 — the solver reimburses the user within 72 hours, or its bond is slashed
  - id: s17
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/cow-protocol/reference/core/auctions/bonding_pools.md?plain=1#L9"
    title: CoW bonding pools at 3df4739 — what a pool must hold to vouch for solvers
  - id: s18
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/governance/fees/fees.md?plain=1#L19-L44"
    title: CoW fees at 3df4739 — surplus and quote-improvement fees capped at 0.98% of volume, and the volume fee
  - id: s19
    resource: "https://github.com/charlesndalton/milkman/blob/f7719b59c349eb60eadaed734270a440c77345f8/DEPLOYMENTS.md?plain=1#L19-L21"
    title: Milkman deployments at f7719b5 — the mainnet Chainlink expected-out calculator
  - id: s20
    resource: "https://github.com/charlesndalton/milkman/blob/f7719b59c349eb60eadaed734270a440c77345f8/src/pricecheckers/ChainlinkExpectedOutCalculator.sol#L23-L74"
    title: Milkman ChainlinkExpectedOutCalculator at f7719b5 — it reads latestAnswer and does not check the answer's age
---

# CoW orders from a dedicated orders account, 2026-10-06

The Treasury Management Committee asked for dollar-cost averaging, standing limit orders, stop-loss orders, and access to 1inch and Uniswap. This note records the facts behind OD-43. It reads the deployed contracts and the public documentation. It ran no fork test.

## The CoW order signer

- The contract at `0x23dA9AdE38E4477b23770DeD512fD37b12381FAB` is the verified `CowswapOrderSigner`. It runs only by delegatecall, so the Safe that calls it owns the order. It derives the order identifier from the typed order and sets a pre-signature on CoW's settlement contract [s2].
- `signOrder(order, validDuration, feeAmountBP)` requires the order to expire before `block.timestamp + validDuration`, and its fee to stay within `feeAmountBP` of the sell amount. `unsignOrder(order)` withdraws the pre-signature [s2].
- The signer accepts any receiver, any amounts and any expiry within `validDuration`. A permission must pin the receiver, the tokens and `validDuration` itself [s2].
- Zodiac's kit grants exactly this delegatecall. It pins the sell token, the buy token, the receiver, as the avatar, and the fee bound. It leaves the amounts, the expiry, the order kind and partial fills open [s1]. The provider's own constellation for this vault used the same path, with a TODO for bounds [s10].
- No audit of the signer was found. It is 40 lines long.

## Conditional orders: TWAP and stop-loss

- ComposableCoW offers TWAP, StopLoss, GoodAfterTime, TradeAboveThreshold and PerpetualStableSwap orders. Ackee audited ComposableCoW and the `ExtensibleFallbackHandler`; Gnosis reviewed it in May and July 2023 and again in August 2024 [s3]. The README adds that several order types came after these reports and are outside their scope; whether the TWAP and StopLoss handlers are in scope is not checked [s12].
- A Safe that owns conditional orders must set its fallback handler to CoW's `ExtensibleFallbackHandler`, and must name ComposableCoW as the verifier for CoW's settlement domain. Every signature for that domain is then checked by ComposableCoW [s3][s1].
- A TWAP order's data names the sell and buy tokens, the receiver, the amount per part, the minimum to receive per part, the start, the number of parts and their spacing [s5]. Zodiac's kit pins the tokens and the receiver and leaves the rest open [s1]. A TWAP order with a start of zero takes its start from its creation; the README warns that creating it again with `createWithContext` can move the start [s12].
- A stop-loss order's data names the tokens, the amounts, the receiver, the expiry, a Chainlink-style oracle for each token, the strike and the maximum oracle age. The order becomes valid when the sell token's price in the buy token falls to the strike or below [s4]. The oracles are order data, so a permission must pin them to real feeds. A rise to a target price is an ordinary limit order instead.
- ComposableCoW's `create` and `createWithContext` store an order for the calling Safe, and `remove` deletes one [s6].
- Conditional orders reach CoW's order book only through a watch-tower that watches for new orders. CoW runs one [s7]. If it stops, the orders wait; no funds move.
- A GoodAfterTime order can carry a price checker: a contract that returns the expected output for the order's sell amount. The order is valid only if its buy amount reaches that output less a slippage bound in basis points, and the check runs when the order is validated [s13]. The handler is deployed at `0xdaf33924925e03c9cc3a10d434016d6cfad0add5`, with 4,041 bytes of code at block 26134502 and a verified `GoodAfterTime` source on Blockscout. CoW's README marks it not compatible with its poller, because it takes the buy amount from input that the poller does not pass [s12]. This is the only CoW path found that bounds a price on chain.
- The deployed Chainlink price checker for such orders is Milkman's expected-out calculator at `0xe23fc134382de3eAF871C249C90bf3Acb846C5ab` [s19]. Its source says that it does not care how old a feed's answer is: it reads `latestAnswer()` [s20]. The feeds that it reads are order data, so a policy would have to pin the checker, every feed and the slippage bound for each pair.

## CoW's rules on the fill price

- Only whitelisted solvers can submit a settlement, and no order executes if its limit price is violated. Each solution gets a score that is roughly the surplus it generates for users, and the best bids win [s14].
- CoW's EBBO rule requires uniform clearing prices in line with, or better than, what users would get from AMMs [s15]. After a violation, the solver must reimburse the user within 72 hours; if it does not, its bond is slashed by the amount of the refund [s16]. A bonding pool holds $500,000 in stablecoins and 1,500,000 COW [s17].
- The protocol takes 50% of an order's surplus or quote improvement, capped at 0.98% of its volume, plus a standard volume fee of 0.02% [s18].
- So the limit is the only bound on chain, but CoW's rules hold a fill to the on-chain market. What remains is a violation beyond what a bond repays, and thin on-chain liquidity in a crash, which a genuine recovery order meets too.

## Uniswap and 1inch

- Zodiac's kit covers Uniswap v3 for liquidity positions only, with no swap action, and it does not cover 1inch [s8].
- A router swap can pin its recipient and its tokens. Nothing in the roles modifier can bound its minimum output against a price: the deployed SDK's operators compare a parameter with fixed values only, and the `Custom` operator calls a checker contract that would be new code. A swap without a sound minimum output loses value to front-running.

## The hosted Zodiac app

- The product page describes roles and scopes, batched execution, simulation, and limits through permissions. It describes no balances, no portfolio value, no risk metrics, no alerts and no third-party data integration [s9]. A value display in the app is a request to the provider.

## The chain, read on 2026-10-06 at block 26134502

| Contract | Address | Code | Verified name |
|---|---|---|---|
| Order signer | `0x23dA9AdE38E4477b23770DeD512fD37b12381FAB` | 1,810 bytes | `CowswapOrderSigner` |
| ComposableCoW | `0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74` | 8,478 bytes | `ComposableCoW` |
| Fallback handler | `0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5` | 9,419 bytes | `ExtensibleFallbackHandler` |
| TWAP handler | `0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5` | 4,533 bytes | `TWAP` |
| StopLoss handler | `0x412c36e5011cd2517016d243a2dfb37f73a242e7` | 4,259 bytes | `StopLoss` |
| GoodAfterTime handler | `0xdaf33924925e03c9cc3a10d434016d6cfad0add5` | 4,041 bytes | `GoodAfterTime` |
| Milkman Chainlink calculator | `0xe23fc134382de3eAF871C249C90bf3Acb846C5ab` | 1,890 bytes | `ChainlinkExpectedOutCalculator` |

## What this means for the design

- The Asset Safe has no fallback handler, by decision 15 of ADR 005. It cannot own conditional orders unless that decision changes. A separate account can carry the fallback handler and hold only tokens in transit.
- Market and limit orders through the signer need no fallback handler, but they need a delegatecall from the owning Safe. A motion cannot grant a delegatecall (OD-36), so the enabling vote must.
- The order signer, TWAP and StopLoss paths do not bound the price on chain. A limit order's minimum is its limit, and CoW's solvers compete to fill above it. The bound is the order's own terms, the screening of each operator transaction, the budget on what enters the account, and monitoring of fill prices. GoodAfterTime with a price checker would add an on-chain floor, but it needs an order poster of Lido's own and a checker that ignores stale feeds. EM decided against a floor for now and relies on CoW's rules (OD-48).
- Stonks 2.0 bounds the price on chain, but its band can stop a recovery order from filling in a real depeg [s11].

## How to reproduce

```sh
for a in 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74 \
         0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5 \
         0x412c36e5011cd2517016d243a2dfb37f73a242e7 0xdaf33924925e03c9cc3a10d434016d6cfad0add5 \
         0xe23fc134382de3eAF871C249C90bf3Acb846C5ab; do
  cast codesize --rpc-url "$RPC" --block 26134502 "$a"
done
curl -s -A "Mozilla/5.0" -H "Referer: https://eth.blockscout.com/" \
  https://eth.blockscout.com/api/v2/smart-contracts/0x23dA9AdE38E4477b23770DeD512fD37b12381FAB | jq -r .name
curl -s -A "Mozilla/5.0" -H "Referer: https://eth.blockscout.com/" \
  https://eth.blockscout.com/api/v2/smart-contracts/0xdaf33924925e03c9cc3a10d434016d6cfad0add5 | jq -r .name
```

## Limits

- No fork test ran. Owed before the design is relied on: the signer called by delegatecall from a Safe v1.5.0 through a roles modifier, with the receiver pinned; a TWAP and a stop-loss order created by a Safe v1.5.0 with CoW's fallback handler; and the condition shapes that pin the receiver and the oracles inside ComposableCoW's encoded order data.
- CoW's fallback handler was built for earlier Safe versions. Its behaviour on Safe v1.5.0 is not checked.
- The signer's audit status is not established.
- Whether the screening vendor can check an order's limit price, or a router swap's minimum output, against a market price before execution is a question for the vendor.
- GoodAfterTime is not checked for the vault: its audit scope, how its orders reach the order book, the deployed price checkers, and which vault tokens they can price.
