---
type: Research Note
title: The orders account's policy on a fork, 2026-11-07
description: "The orders modifier's operator and emergency roles, the Asset Safe's transfers to the orders account, and the fork tests that ADR 007 owed: CoW's order signer by delegatecall and TWAP orders through ComposableCoW, from a Safe v1.5.0 behind a Roles modifier, settled through CoW's settlement contract."
tags: [swaps, cow, orders, policy, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-07
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-11-08T10:32:34Z
verified: []
sources:
  - id: s1
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the orders account, its roles, the order signer, TWAP orders, recovery orders and the fork tests owed
  - id: s2
    resource: /research/cow-orders-account-2026-10-06.md
    title: CoW orders from a dedicated orders account, 2026-10-06 — the contracts, their addresses and what was not tested
  - id: s3
    resource: "https://github.com/lidofinance/clutch/tree/d590723c1c19162eb797a4f0569eb3ab36882a3a/policy/constellation/constellation"
    title: The constellation at d590723 — the orders roles, the CoW module and the funding transfers
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/d590723c1c19162eb797a4f0569eb3ab36882a3a/test/OrdersAccount.t.sol"
    title: The orders account's fork tests at d590723
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/d590723c1c19162eb797a4f0569eb3ab36882a3a/policy/constellation/compiler/compile.ts"
    title: The policy compiler at d590723 — the delegatecall rule and the orders account's protection
  - id: s6
    resource: "https://eth.blockscout.com/address/0x23dA9AdE38E4477b23770DeD512fD37b12381FAB?tab=contract"
    title: CowswapOrderSigner, verified source on Blockscout — signOrder's expiry and fee checks, read on 2026-11-07
  - id: s7
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/ComposableCoW.sol#L222-L274"
    title: ComposableCoW at c043595 — getTradeableOrderWithSignature and the signature for a Safe with CoW's fallback handler
  - id: s8
    resource: "https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/types/twap/libraries/TWAPOrder.sol"
    title: ComposableCoW TWAP at c043595 — the order data, its validation and the parts it builds
  - id: s9
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/governance/fees/partner-fee.md?plain=1#L8-L22"
    title: CoW's partner fee at 3df4739 — defined in an order's app data, at most 100 basis points of volume
  - id: s10
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/cow-protocol/concepts/order-types/cow-hooks.mdx?plain=1#L7-L9"
    title: CoW Hooks at 3df4739 — arbitrary calls attached to an order, run before and after the swap
  - id: s11
    resource: "https://github.com/cowprotocol/services/blob/65e032591c37daef3400b2c39a94c79d77f32bb9/crates/shared/src/order_validation.rs#L962-L969"
    title: CoW's order book at 65e0325 — an order with a non-zero signed fee is refused, because fees moved into the limit price
  - id: s12
    resource: "https://github.com/cowprotocol/services/blob/65e032591c37daef3400b2c39a94c79d77f32bb9/crates/orderbook/openapi.yml#L1043-L1050"
    title: CoW's order book API at 65e0325 — set an order's fee amount to zero when creating it
  - id: s13
    resource: "https://github.com/cowprotocol/docs/blob/3df4739e8c23f36ed3c5186b605bc5db3f39dee4/docs/governance/fees/fees.md?plain=1#L17-L65"
    title: CoW's fees at 3df4739 — the surplus, quote improvement and volume fees, charged inside an order's execution
---

# The orders account's policy on a fork, 2026-11-07

ADR 007 put every swap of the vault on a separate orders account and listed the fork tests that it owed before the design is relied on [s1]. The research note of 2026-10-06 ran no fork test and left open whether CoW's fallback handler works on Safe v1.5.0 [s2]. This work builds the orders account's policy and runs those tests on a fork of block 26249900, on the vault that the enabling vote sets up. Nothing is deployed.

## What was built

- **The orders modifier's roles** [s3]. The operator, held by the committee's Safe, signs market and limit orders through CoW's order signer by delegatecall, and creates TWAP orders through ComposableCoW. Both pay the Asset Safe and trade only the order tokens: stETH, wstETH, WETH, USDC, USDT and USDS. The operator cancels its orders and sends an order token back to the Asset Safe or to the Aragon Agent. The emergency role, held by the emergency Safe, places recovery orders through the order signer that buy USDC or USDT and pay the Aragon Agent, cancels any order, revokes the operator's targets and functions with the role key pinned, sets a relayer approval to zero, and sends any token to the Agent or the Asset Safe.
- **What each order pins.** A signer order pins both tokens, the receiver, plain ERC-20 balances, zero app data, a `validDuration` of at most 90 days for the operator and 1 day for the emergency role, a signed fee of zero and a fee bound of zero. The signer itself refuses an order that expires beyond `validDuration` [s6]. A TWAP order pins CoW's TWAP handler, both tokens, the receiver, a start of zero, zero app data, CoW's current-timestamp factory, and one of two shapes: at most 90 parts at most a day apart, or at most 12 parts at most 7 days apart [s8].
- **Zero app data and a zero fee.** An order's app data can carry a partner fee of up to 100 basis points of its volume, which CoW pays to the partner that the app data names [s9], and hooks, which are arbitrary calls run with the swap [s10]. Zero app data carries neither. CoW takes its fee from an order's surplus, so the policy signs none; the signer alone would let the fee reach 1 wei [s6], so the policy also pins the order's fee field to zero. EM accepted zero app data on 2026-11-07 (OD-115), and the fee field after the research below (OD-116).
- **The Asset Safe's side.** The operator funds the orders account by a transfer of an order token pinned to it, which spends that token's orders budget: six new budget keys, with stand-in figures. The emergency role may send any asset that a recovery order sells, DAI and sUSDS among them, to the orders account as well as to the Agent.
- **The compiler** [s5]. It refuses any delegatecall except the orders account's call of the order signer's `signOrder` and `unsignOrder`, and it protects the orders account and its modifier as it protects the Asset Safe: no role calls the orders account itself, and the emergency role only removes authority on the orders modifier. On its first run the check found that the governance role's guard on the operator modifier refused the Asset Safe and its modules, but not the orders account or its modifier, as targets. The Asset Safe owns neither, so a grant there could reach no administration, but the guard now refuses both.
- **The enabling vote.** The orders account's batch carries its policy from the compiled artifact, and the relayer approvals now cover DAI and sUSDS, which recovery sells.
- **A manifest with every pinned address.** The constellation now refuses a manifest that misses an address that a permission pins. Before, a missing address did not fail: the helpers leave an undefined parameter open, so a transfer pinned to it would have paid any address. The mainnet dry run's manifest has lacked the first-loss Safe since 2026-11-05, so a dry-run compile would have left the insurance-funding transfer open. The dry run now names keyless stand-ins for the first-loss Safe and the orders account. Agents never run the dry run.

## The fork tests

Each order settles through CoW's deployed settlement contract. The test adds itself as a solver through the allow-list's manager, and the settlement pays the buy side from its own balance, at the order's limit price [s4].

| ADR 007 asked for | Test | Result |
|---|---|---|
| The signer by delegatecall from Safe v1.5.0 through Roles, with the receiver pinned | `test_orders_signer_order_settles_to_the_asset_safe`, `test_orders_signer_refusals` | The orders account pre-signs; the order settles with the vote's relayer approval and pays the Asset Safe. Another receiver, the owner as receiver, an unlisted token, non-zero app data, Balancer balances, a fee bound, a fee of 1 wei, and a delegatecall to anything but the signer are refused. |
| TWAP from Safe v1.5.0 with CoW's handler, the receiver pinned inside the encoded data | `test_orders_twap_part_settles_through_the_fallback_handler`, `test_orders_twap_refusals` | The first part settles through the Safe's EIP-1271 check, which CoW's fallback handler answers with ComposableCoW, and pays the Asset Safe. So CoW's fallback handler works on Safe v1.5.0 [s7]. Another receiver, an unlisted token, another handler, another factory, a later start, non-zero app data and `create` without a context are refused. |
| The life limits of decisions 25 and 29, and TWAP outside both shapes | the refusal tests and `test_orders_emergency_cancels_sweeps_and_recovers` | 90 days pass for the operator and 90 days and one second fail; one day and one second fail for a recovery order. 90 parts a day apart and 12 parts 7 days apart pass; 91 parts, 13 parts, and a second more of spacing in either shape fail. |
| Emergency cancel, sweep and recovery settlement with the vote's relayer approval | `test_orders_emergency_cancels_sweeps_and_recovers` | The emergency Safe cancels a signer order and a TWAP order, sweeps a token to the Agent, zeroes a relayer approval and cannot raise one, and its DAI recovery order settles and pays the Agent. A recovery order that pays the Asset Safe, buys USDS or lives longer than a day is refused. |
| Emergency revocation on the orders modifier, with recovery still available | `test_orders_emergency_revocation_keeps_recovery` | After the revoke, the operator's signer and TWAP orders are refused, and a USDS recovery order still settles and pays the Agent. |

`test_orders_funding_from_the_asset_safe` adds the Asset Safe's side: the operator funds the orders account within its orders budget and nowhere else, and the emergency role may fund it too.

## Checks

- The fork suite passes 84 tests: the kit's 53, and at block 26249900 the rehearsal's 6, the factory's 18 and the orders account's 7.
- Eleven mutants of the orders policy, each weakening one condition, each fail at least one test: any receiver, any app data, any life, any fee bound and a 1-wei fee for signer orders; any number of parts, any receiver and any start for TWAP orders; USDS as a recovery buy token; funding with no budget; and the emergency revoke with any key.
- The compiler passes 32 tests, eight of them new: the delegatecall rule, the orders account's protection, the receivers and lives in the compiled artifact, and the extended guard.

## Measures

| Measure | Value |
|---|---|
| The rehearsal's policy | 182 calls: 130 on the Asset Safe's modifiers and 52 on the orders modifier |
| The orders account's batch | 63 calls, 5,233,852 gas |
| The Asset Safe's batch | 132 calls, 8,944,744 gas |
| A vote that would carry the policy itself | 139,876 bytes and 82,347,800 gas: above both the transaction pool's limit of 131,072 bytes and EIP-7825's cap |

Every batch fits one transaction under EIP-7825's cap of 16,777,216 gas. Before the orders policy, a vote that carried the policy failed only on gas; it now fails on its size too, which leaves the vote's approved hashes (OD-92) as the only way.

## The signed fee (OD-116)

EM asked whether a signed fee of zero is the right bound, or whether a smarter one exists. After this research, EM chose the agent's recommendation on 2026-11-07: no signed fee, with the order's own fee field pinned to zero (ADR 007, decision 43). Both roles' signer permissions now pin the field, and a recovery or operator order with a fee of 1 wei is refused.

- **What the signer checks.** `signOrder` refuses an order whose fee exceeds the sell amount times the fee bound in basis points, plus 1 wei [s6]. With a bound of zero, the fee can be 0 or 1 wei.
- **CoW's order book refuses a signed fee.** An order with a non-zero fee fails validation, with the reason in the code: an order used to pay for its execution with a fee that it signed, and fees have since moved into the limit price and the slippage tolerance [s11]. The API says to set the fee to zero when creating an order [s12]. So an order with a fee never reaches the solvers through the order book.
- **Where CoW charges fees now.** Inside the execution, never as a separate transfer: 50 percent of an out-of-market limit order's surplus, or of a market order's improvement on its quote, at most 0.98 percent of the volume; and a volume fee of 2 basis points, or 0.3 for correlated assets such as stablecoins. A partner fee would come on top, and zero app data excludes it [s13]. The vault receives at least the order's limit, so the limit bounds every fee.
- **The options.**
  - A bound above zero buys nothing, because no such order reaches the order book. It also opens a path: a pre-signed order moves its fee into CoW's settlement contract, and only a solver that broke CoW's rules could then take it.
  - A bound of zero alone: the fee can be 1 wei.
  - A bound of zero, and the order's own fee field pinned to zero. The policy then states the order book's rule exactly, at the cost of one more condition in each signer permission. The agent recommended this, and EM chose it.
- **What "smarter" can mean.** No on-chain rule can bound a fee better than the limit does, because the modifier compares a parameter only with fixed values (OD-48). The smarter control is the limit itself: the committee's order tool sets it from a fresh quote with a capped slippage, the screening guard checks it once the launch cap lifts, and monitoring compares each fill with the market. A standing limit order shares its surplus with CoW, at most 0.98 percent of the volume; that is a cost of resting orders, not of the signed fee.

## Not tested, and not built

- The order book's acceptance of an order with zero app data and of a TWAP part with zero app data, and the watch-tower's posting of TWAP parts. Neither runs on a fork.
- The universal factory's shape that adds a token to the lists with its relayer approval, emergency transfer and recovery orders (ADR 007 decision 41; INV-040). The orders modifier's governance and approvals roles, and the restore of what the emergency role revoked there, were built on 2026-11-08 ([research note](/research/orders-motion-roles-2026-11-08.md)).
- The orders budgets' figures, which come from the attested computation.
