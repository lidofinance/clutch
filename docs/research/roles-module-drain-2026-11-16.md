---
type: Research Note
title: A Safe drained through its Roles module on 2026-11-16, and the Clutch design
description: "What the drain transaction did, what the wallet's role policy pinned and what it left free, and how the Clutch policy compares: no router and no free route, and an order price that nothing on chain bounds."
tags: [security, roles, orders, incident, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-17
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-17T20:16:01Z
verified: []
sources:
  - id: s1
    resource: "https://etherscan.io/tx/0x6c7cce68b6373dd0e645e6667d46788f49da5a4afc286bc363a2bf34f0a8c9c5"
    title: The drain transaction, block 26427327, 2026-11-16 11:35:23 UTC
  - id: s2
    resource: "https://thedefiant.io/news/hacks/safe-wallet-drained-of-6-4-million-via-roles-module"
    title: Press report, 2026-11-16 — USDC and syrupUSDC left one wallet; an analyst traced the drain to a gap in its delegated trading permissions
  - id: s3
    resource: "https://cointelegraph.com/news/safe-wallet-reportedly-loses-millions-after-key-compromise"
    title: Press report, 2026-11-16 — a co-founder of the module's maker on the role member's key and on the wallet's own policy
  - id: s4
    resource: urn:clutch:evidence:2026-11-17:roles-drain-simulation
    title: Calls simulated one block before the drain, with the role member as the caller, and the calldata of the drain decoded
  - id: s5
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — CoW only, the order signer's pins, and no price bound on chain
  - id: s6
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the role holders, the free parameters and the unwrappers
  - id: s7
    resource: /specs/threat-model.md
    title: Threat model — an order that fills far below the market, and a permission with a free route
  - id: s8
    resource: /registers/decision-log.md
    title: Decision log — EM's request of 2026-11-17 and EM's choices for OD-154 to OD-156
---

# A Safe drained through its Roles module on 2026-11-16, and the Clutch design

EM asked the agent how the drain relates to the Clutch design, what Clutch should do, and how to harden it [s8]. The agent read the transaction and simulated calls on mainnet, read two press reports, and checked the committed policy of `main`. It did not read the modifier's whole event history, and it did not identify the wallet's owner.

## What happened

1. The wallet is a Safe with one module: a Roles modifier of the older version, whose role identifiers are numbers. A MultiSend contract is set on the modifier, so one role call can carry a batch [s1][s4].
2. An externally owned account that held a role made one call with five parts [s1][s4]:
   - a withdrawal of 4,387,188 USDC from an ERC-4626 vault to the Safe;
   - an approval of USDC to a swap aggregator's router, for the maximum;
   - a swap on that router from USDC to USDC, with a minimum output of 1, the Safe as the beneficiary, and an executor that the caller chose;
   - the same approval for syrupUSDC;
   - the same swap for 1,717,919 syrupUSDC.
3. The router sent the tokens to the executor, and the Safe received nothing back [s1].
4. A co-founder of the module's maker said that the module has no vulnerability, that the transaction came from the key of a long-standing role member, and that the key was most likely compromised. The wallet's own policy allowed the transaction [s3]. An analyst traced the drain to a gap in the wallet's delegated trading permissions [s2].

## What the policy pinned, and what it left free

The agent simulated calls of the role member one block before the drain [s4].

| Call | Result |
|---|---|
| A transfer of USDC to another address | Refused: the function is not allowed |
| An approval of USDC to another spender | Refused: the spender is not on the list |
| A vault withdrawal to another receiver | Refused: the receiver is pinned |
| A swap with another beneficiary | Refused: the beneficiary is pinned |
| A swap into another destination token | Refused: the token is not on the list |
| A swap with any executor and a minimum output of 1 | Allowed |

So the policy was not careless. It pinned the spender, the receiver and the destination token. It left free the address that receives the tokens to swap them, and the least amount that must come back.

## Clutch against the same pattern

The agent checked the committed artifact of the rehearsal at `72c7d67`, before the changes of OD-156 [s5][s6].

| The drained wallet | Clutch |
|---|---|
| A router whose caller chooses the executor | No router. Swaps go through CoW, and the signer of an order does not choose the solver |
| A free address that receives funds | None in a role that a Safe holds. Two parameters were free without need: the referral of the operator's Earn deposit, and the data of a TWAP order's creation |
| A role held by one key | The committee's Safe, the emergency Safe and the universal factory hold the roles |
| A batch through MultiSend | No modifier has a transaction unwrapper |
| The whole balance in one call | Tokens reach the orders account only within the budgets of 30 days |
| A free minimum output | The same: nothing on chain bounds the price of an operator's order |

On the last row: an order's fee and app data are zero, its receiver is the Asset Safe and both tokens are on the lists. Its amounts are free. A solver on CoW's list can fill a signed order at its limit; CoW's auction and its bond rules are not on chain. A loss needs a bad order from the committee's signing quorum and a solver that fills at the limit, and what sits in the orders account bounds it [s5][s7].

## What followed

EM chose, on 2026-11-17 [s8]:

- no price bound on chain for operator orders at launch, and research on a bound without an outside price feed (OD-154);
- stricter conditions for any later router (OD-155);
- four hardening steps (OD-156): a compiler rule against free route parameters, the two pins, the orders detector with its drill, and two invariants on the role holders and the unwrappers.

## Limits of this note

- The agent decoded one transaction and simulated ten calls. It did not rebuild the wallet's whole policy.
- The press reports give the maker's account of the key. Nobody has confirmed it.
- The comparison covers the launch policy. A later motion can write any permission; the compiler rule covers the policy changes that go through the repository.
