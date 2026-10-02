---
type: Decision
title: "ADR 007: Swapping through Stonks 2.0"
description: Every swap, routine or emergency, goes through fresh Stonks 2.0 instances from the standard factory; the operator Safe manages the rebalancing instances and the emergency Safe the recovery instances; the receiver separates the two families; the live parameters are copied by pair class; recovered tokens go to the treasury.
tags: [swaps, stonks, cow, emergency, rebalancing]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T13:35:00Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the swap engine, recovery pairs and instances, 2026-09-22, and on OD-05, 2026-10-02
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
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md"
    title: Kit harness README at 370e20a — the policy still grants order pre-signing
---

# ADR 007: Swapping through Stonks 2.0

## Context

- A CoW order pre-signature carries only an order identifier and a flag. The sell token, the buy token, the amounts and the receiver are inside a hash that the modifier cannot read [s3].
- A Stonks 2.0 instance has a fixed receiver for its proceeds [s2].
- Only an instance's admin or manager can place an order. Recovered tokens always go to the instance's fixed recovery address [s2].
- Every instance from the standard factory has Aragon Voting as admin and the Aragon Agent as recovery address [s2].
- An order's minimum output is the oracle quote less the margin; a manager can raise it, never lower it. An order is valid only while the oracle stays inside two bands around its price, the maximum improvement above and the price tolerance below [s2].
- The live instances use 1800 seconds, 110 and 550 basis points for a volatile pair, and 1800 seconds, 30 and 150 for a stablecoin pair. The Stonks 2.0 instances also set a maximum improvement of 1000 basis points and allow partial fills [s2].
- The deployed price stack prices only stETH and LDO today [s2].

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

## Proposed direction

The rest of this section is agent-drafted [s4]. EM has not accepted it as text.

| Family | Used by | Manager | Receiver | Recovered tokens go to |
|---|---|---|---|---|
| Rebalancing | `operator` | operator Safe | Asset Safe | Aragon Agent |
| Recovery | `emergency` | emergency Safe | Aragon Agent | Aragon Agent |

- **A swap.** The role transfers the asset to an approved instance, with the recipient pinned in the permission. The instance's manager then places the order. The proceeds settle to the receiver.
- **An unfilled order.** When it expires, anyone can return the unsold tokens to the instance, and the manager places a new order. This is the normal path. Recovering tokens out of an instance is the exception, for an instance that is retired or stuck.
- **The managers act outside the modifier.** The operator Safe calls its instances directly, so the screening guard checks each order. The emergency Safe calls its instances directly and is never screened.
- **Topology.** USDC is the hub. Rebalancing routes through USDC. Recovery sells each asset directly into USDC, and the volatile assets also into USDT, so a USDC depeg does not strand recovery. Direct pairs can be added later by motion.
- **Pricing before launch.** The vault's pairs need a new converter instance with the vault's token lists, and oracle-router feeds for wstETH, WETH, USDC, USDT, DAI and USDS. That is DAO configuration, and the instance list depends on it.

## Options considered

- **Direct order pre-signing by the operator.** Not chosen: neither price nor destination can be constrained [s3].
- **A router swap with the destination in calldata.** Not chosen: it pins the destination, but the vault would still hold a standing router approval.
- **A full mesh of instances.** Not chosen: every instance is an address to deploy, pin and monitor.
- **Reusing the existing treasury instances.** Not chosen by EM: their receiver is the treasury, and vault flows would mix with ordinary DAO swaps.
- **The Aragon Agent as manager.** Replaced by EM on 2026-10-02: every swap, emergency ones included, would have needed a DAO vote.
- **Rebalancing instances deployed outside the factory, recovering to the Asset Safe.** Not chosen by EM. It would keep recovered tokens in the vault with no new contract, at the cost of off-factory provenance.

## Consequences

- The destination of proceeds is structural. No condition has to express it.
- The operator can move vault assets to the treasury through a rebalancing instance, by transferring tokens in and recovering them out. Both ends belong to the DAO, so this is harmless, and invariant INV-002 says so.
- A recovery from a rebalancing instance makes the vault smaller. Getting the tokens back needs a top-up motion under the mandate's top-up rule, and that rule may refuse it.
- The emergency Safe cannot act on a rebalancing instance. It can stop new transfers into one, and a live order ends within its 30 minutes.
- Changing a manager needs a DAO vote, because Aragon Voting is the admin.
- Each instance's values are fixed. A wrong rebalancing value is fixed by a new instance and one motion. A wrong recovery value needs a DAO vote, because the safety policy pins the recovery instances.
- Swaps are queued, not instant. The emergency service level is time to initiate, not time to fill.
- Assets sit in an instance between the transfer and the settlement, a short custody excursion out of the Asset Safe. The LIP must say so.
- The kit still grants the operator direct order pre-signing [s5]. The policy migration in [ADR 004](/adr/004-specifications-and-policy-as-data.md) removes it.

## Confirmation

- INV-002, INV-013 and INV-014 in the [invariants](/specs/invariants.md).
- Fork tests owed: each manager places, re-places and recovers orders; a non-manager cannot; recovered tokens arrive at the treasury; an expired order's tokens return to the instance.

## Reversal conditions

- An instance cannot price a pair in the list.
- Fill rates under stress break the six-hour time to initiate.
- Recoveries from rebalancing instances become frequent enough that the treasury round trip shrinks the vault.

## Open questions

- The pricing configuration before launch: a new converter instance and router feeds. This is DAO configuration.
- The exact instance list is a phase 1 deliverable.
