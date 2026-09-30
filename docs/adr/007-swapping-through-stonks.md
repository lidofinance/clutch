---
type: Decision
title: "ADR 007: Swapping through Stonks 2.0"
description: Every swap, routine or emergency, goes through fresh Stonks 2.0 instances managed by the Aragon Agent; the receiver fixed in each instance separates rebalancing from recovery; USDC is the hub and USDT the second recovery destination.
tags: [swaps, stonks, cow, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the swap engine, recovery pairs, instances and manager, 2026-09-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Stonks instances, receivers, managers and parameters
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/ReviewProbe.t.sol#L211"
    title: Kit test at 370e20a — an order pre-signature is opaque to the modifier
  - id: s4
    resource: /specs/lip-draft.md
    title: LIP draft — swapping and the instance matrix
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md"
    title: Kit harness README at 370e20a — the policy still grants order pre-signing
---

# ADR 007: Swapping through Stonks 2.0

## Context

- A CoW order pre-signature carries only an order identifier and a flag. The sell token, the buy token, the amounts and the receiver are inside a hash that the modifier cannot read [s3].
- A Stonks 2.0 instance has an immutable `RECEIVER`. The two live instances settle to different receivers [s2].
- Stonks 2.0 exposes `estimateTradeOutput`, which prices the order from an oracle, and `recoverERC20`, `recoverEther` and `recoverERC721`, so an unfilled order does not strand assets [s2].
- Order duration, margin and price tolerance are fixed per instance. A live volatile pair uses 1800 seconds, 110 and 550 basis points. A live stablecoin pair uses 1800 seconds, 30 and 150 basis points [s2].
- The earlier treasury instances have no receiver getter, and the committee's Safe is their manager [s2].

## Decision

EM decided on 2026-09-22 [s1]:

1. Stonks 2.0 is the default swap engine for the vault. The emergency swap must work through CoW, and Stonks 2.0 gives it oracle protection.
2. Recovery covers stablecoin-to-stablecoin swaps too. The missing recovery pairs are added.
3. No existing instance is reused.
4. The rebalancing set is stETH, wstETH, USDC, USDT, USDS and LDO.
5. The Aragon Agent manages every instance.
6. Recovery has a second destination, USDT, and it is mandatory.

## Proposed direction

The rest of this section is agent-drafted [s4]. EM has not accepted it as text.

- Two families of instances, all deployed fresh from the Stonks factory:

| Family | Used by | `RECEIVER` | Effect |
|---|---|---|---|
| Rebalancing | `operator` | Asset Safe | proceeds return to the vault, so the operator can trade but cannot move value out |
| Recovery | `emergency` | Aragon Agent | proceeds go to the DAO treasury |

- A swap takes two steps. First the role calls `transfer` on the asset, with the recipient pinned to an approved instance. Then anyone calls `placeOrder`, and the instance builds an order whose minimum output comes from its oracle.
- The operator needs no order pre-signing permission, and no role needs a standing approval to the CoW relayer.
- Topology: USDC is the hub. Rebalancing routes through USDC. Recovery sells each asset directly into USDC, and the volatile assets also into USDT, so a USDC depeg does not strand recovery.
- Direct pairs can be added later by motion where a route through the hub costs too much.

## Options considered

- Direct order pre-signing by the operator. Not chosen: neither price nor destination can be constrained [s3].
- A router swap with the destination in calldata. Not chosen: it pins the destination, but the vault would still hold a standing router approval.
- A full mesh of instances. Not chosen: every instance is an address to deploy, pin in a permission and monitor, and most pairs would be idle.
- Reusing the existing treasury instances. Not chosen by EM: their receiver is fixed to the Agent, their manager is the committee, and vault flows would mix with ordinary DAO swaps.

## Consequences

- The destination of proceeds is structural. No condition has to express it.
- Swaps are queued, not instant. An order runs for its duration against an oracle floor. The emergency service level is time to initiate, not time to fill.
- Assets sit in the instance between the transfer and the settlement. This is a short custody excursion out of the Asset Safe, and the LIP must say so.
- Recovering assets out of an instance is a DAO action, because the Agent is the manager. The committee cannot recover out of an instance it just sold into.
- The kit still grants the operator direct order pre-signing [s5]. The policy migration in [ADR 004](/adr/004-specifications-and-policy-as-data.md) removes it.

## Confirmation

- INV-013 and INV-014 in the [invariants](/specs/invariants.md). Neither has a test yet.

## Reversal conditions

- An instance that cannot price a pair in the list.
- Fill rates under stress that break the six-hour time to initiate.

## Open questions

- OD-05: order duration, margin and price tolerance by pair class.
- OD-18: whether the Stonks price source covers every pair in the instance list.
- The exact instance list is a phase 1 deliverable.
