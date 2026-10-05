---
type: Decision
title: "ADR 011: Launch scope"
description: The launch assets and venues; Lido Lend is onboarded by motion through a Morpho Blue template that ships at launch with end-to-end tests; sDAI and third-party lending markets are out.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T14:39:55Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the launch assets, DAI and Lido Lend, 2026-09-22, and on WETH, 2026-10-05
  - id: s2
    resource: /specs/lip-draft.md
    title: LIP draft — launch asset and action matrix
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md"
    title: Kit harness README at 370e20a — the policy still grants Aave v3, sDAI and order pre-signing
  - id: s4
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — USDS is not in the payment ACL chain
---

# ADR 011: Launch scope

## Context

- Lido Lend is expected in October 2026 and is compatible with Morpho Blue [s1].
- USDS cannot be paid out through the existing payment path [s4]. EM decided on 2026-10-05 that a DAO vote adds it (decision 5).
- The kit's policy predates this scope [s3].

## Decision

EM decided on 2026-09-22 [s1]:

1. The launch list: "ETH, WETH, stETH, wstETH, EarnETH, EarnUSD, USDC, USDT, USDS, sUSDS, CowSwap access, Lido Lend access (which is basically Morpho Blue compat), LDO".
2. Add DAI.
3. Launch without Lido Lend, but with the Morpho Blue template and end-to-end tests for it. Lido Lend must be ready on the day it deploys, through an Easy Track motion.
4. CoW access runs through Stonks 2.0, the default swap engine ([ADR 007](/adr/007-swapping-through-stonks.md)).

EM decided on 2026-10-05, closing OD-11 [s1]:

5. The funding assets are USDC, USDT, DAI, USDS, sUSDS and stETH. ETH is not one ([ADR 008](/adr/008-funding-through-existing-payments.md)).

EM decided on 2026-10-05, closing OD-20 [s1]:

6. WETH is supported through stETH: it is unwrapped and staked to sell, and bought back through Lido's withdrawal queue. Only stETH, LDO, USDC, USDT, USDS and DAI are swapped ([ADR 007](/adr/007-swapping-through-stonks.md)).

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

| Asset or venue | Role in the vault | Notes |
|---|---|---|
| ETH, WETH | held; wrap and unwrap; staked to stETH before a sale, and bought back through Lido's withdrawal queue | not a funding asset; no swap instance |
| stETH, wstETH | held; wrap and unwrap | stETH can seed the vault; wstETH is unwrapped before a sale |
| USDC, USDT, DAI | held | can seed the vault |
| USDS | held | can fund the vault once a DAO vote adds it to the payment permission |
| sUSDS | savings position | tokenized-vault template; can also fund the vault; redeemed before a sale |
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem |
| LDO | held | in the rebalancing set |
| Stonks 2.0 instances | rebalancing and recovery | [ADR 007](/adr/007-swapping-through-stonks.md) |
| Lido Lend | lending, after launch | one motion through the Morpho Blue template once the market exists; the protocol cap applies for its first three months, then none as a Lido own product (OD-04, decided 2026-10-02) |

Out of the launch scope: sDAI, Aave and every other third-party lending market.

## Options considered

- Wait for Lido Lend before launch. Not chosen by EM: it arrives later by motion.
- Keep Aave v3 and sDAI from the original proposal. Not chosen: they are not in EM's list.

## Consequences

- The Morpho Blue template ships before the market it will point at exists. Its acceptance needs end-to-end tests against the deployed Morpho Blue contract on a fork.
- The kit still grants Aave v3 supply and withdraw, sDAI deposits and direct order pre-signing [s3]. The policy migration in [ADR 004](/adr/004-specifications-and-policy-as-data.md) removes them.
- Asynchronous vault deposits are authorised at the policy layer in the kit. Their settlement is not tested.

## Confirmation

- INV-015 in the [invariants](/specs/invariants.md). It has no test yet.
- The end-to-end test of the Morpho Blue template. It does not exist yet.

## Reversal conditions

- Lido Lend ships with an interface that the Morpho Blue template cannot express.
- The mandate changes the asset list.

## Open questions

- OD-22: whether DAI earns or stays idle. No operator permission moves DAI: it is not in the rebalancing set, sDAI is out of scope, and no DAI-to-USDS converter is in scope.

OD-04 was decided on 2026-10-02 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
