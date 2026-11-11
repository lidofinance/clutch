---
type: Decision
title: "ADR 011: Launch scope"
description: The launch assets and venues, the later onboarding of Lido Lend, and the integrations outside the launch.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-11-11T04:42:44Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the launch assets, DAI, WETH, LDO and Lido Lend, 2026-09-22 to 2026-11-05
  - id: s5
    resource: /research/dai-usds-conversion-2026-10-05.md
    title: DAI and the DAI–USDS converter, 2026-10-05 — the treasury's stablecoins, the converter, and the two tokens
  - id: s6
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — the four main stablecoins, the per-stablecoin cap and the liquidity buffer; outside the repository until the mandate is published
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L553"
    title: Kit test at 7a8c661 — DAI to USDS and back pays the Asset Safe, any other receiver is refused, and the converter approvals have a fixed ceiling
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/Drills.t.sol#L875"
    title: Kit test at 7a8c661 — the operator cannot reach Aave, sDAI or the CoW settlement
---

# ADR 011: Launch scope

## Context

- Lido Lend is a lending product that is compatible with Morpho Blue [s1].
- The mandate caps each of USDC, USDT, USDS and DAI as a share of stablecoins [s6].
- Sky converts DAI and USDS one to one in either direction, without an admin or a fee, to a receiver that the caller names. Sky can upgrade USDS; DAI is not upgradeable. The Agent holds 4,673,791.03 DAI [s5].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. The launch list is ETH, WETH, stETH, wstETH, earnETH, earnUSD, USDC, USDT, USDS, sUSDS, CoW access, and Lido Lend access, which is compatibility with Morpho Blue (decision log, 2026-09-22; OD-91).
2. The launch list includes DAI (decision log, 2026-09-22).
3. The vault launches without Lido Lend, but with the universal factory's Morpho Blue shape and end-to-end tests for it. Lido Lend must be ready on the day it deploys, through a motion (decision log, 2026-09-22; OD-102).
4. Replaced by decision 11 (OD-43).
5. Replaced by ADR 014 decision 3 (OD-106).
6. Replaced by decision 12 (OD-46).
7. DAI earns through Sky's DAI–USDS converter. The operator may convert DAI to USDS and back, one to one, with the receiver pinned to the Asset Safe (OD-22).
8. The DAI and USDS approvals to the converter have a fixed ceiling of one mandate size, as the stETH approval to the wstETH contract does, and a motion changes it as [ADR 013](/adr/013-one-easy-track-factory.md) decision 13 allows (OD-22, OD-89, OD-105).
9. DAI stays off the operator's order lists, and recovery can sell DAI into USDC or USDT (OD-22, OD-43).
10. Lido Lend stays in the protocol cap until it matures, and a motion unlocks it ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28). earnETH and earnUSD are not new products (OD-41).
11. Every swap is a CoW order placed from the orders account. Uniswap and 1inch wait until the screening vendor can bound a swap's minimum output ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 20) (OD-43).
12. WETH is on the operator's order lists ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 22). A later token joins the lists by motion ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 41) (OD-46, OD-103).
13. Lido Lend is a separate deployment that is compatible with Morpho Blue, not markets on Morpho Blue's own contract. Its address enters with the universal factory's onboarding motion, and that motion also adds its emergency exit ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13) (OD-49, OD-102).
14. Lido's withdrawal queue is outside the launch scope. WETH is bought and sold in CoW orders, and ETH is staked through `submit` ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 27) (decision log, 2026-10-08).
15. LDO is off the launch list. It is on neither the operator's order lists nor the recovery sell list (OD-91).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

| Asset or venue | Role in the vault | Notes |
|---|---|---|
| ETH, WETH | held; wrap and unwrap; ETH staked through `submit`; WETH bought and sold in CoW orders by the operator, and sold by recovery (decision 14) | can come in a tranche vote ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 3) |
| stETH, wstETH | held; wrap and unwrap; sold through CoW orders | can come in a tranche vote |
| USDC, USDT | held | can come in a tranche vote |
| DAI | held; converted to USDS and back through Sky's converter, one to one | can come in a tranche vote; recovery sells it into USDC or USDT (decision 9) |
| USDS | held; receives converted DAI | can come in a tranche vote, because Aragon Voting pays any token through Finance |
| sUSDS | savings position | the universal factory's tokenized-vault shape; can come in a tranche vote; the operator redeems it, and recovery can sell it in a CoW order |
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem; the DAO's first-loss shares sit in the first-loss Safe, where a burn runs only by a motion of the universal factory and the role of the committee's Safe redeems them to the Asset Safe ([ADR 008](/adr/008-funding-through-existing-payments.md) decisions 21 and 23); insurance for both vaults is built in at launch ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 4) |
| Orders account | CoW market, limit and TWAP orders for the operator; recovery orders into USDC or USDT for the emergency role | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Lido Lend | lending, after launch | one motion through the universal factory's Morpho Blue shape, once Lido Lend's own contract exists, which also adds its emergency exit (decision 13); the protocol cap applies until it matures and a budget motion unlocks it (decision 10); its insurance is built in at launch ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 4) |

Out of the launch scope: sDAI, Aave and every other third-party lending market, Lido's withdrawal queue (decision 14), LDO (decision 15), and router swaps on Uniswap and 1inch until the screening vendor can bound their output (decision 11).

## Options considered

- **Wait for Lido Lend:** not chosen (decision 3). A motion onboards it later.
- **Aave v3 or sDAI:** not chosen. EM's launch list leaves them out.
- **Swap DAI for USDS in CoW orders:** not chosen. Each swap pays a stablecoin-pair margin; Sky's converter is one to one, without a fee [s5].
- **Leave DAI idle:** not chosen (decision 7). It earns nothing.

## Consequences

- The universal factory's Morpho Blue shape ships before its target market exists. Its acceptance needs end-to-end fork tests against the deployed Morpho Blue.
- The policy grants no Aave v3, no sDAI and no order pre-signing on the Asset Safe; tests refuse them [s8].
- The policy authorizes asynchronous vault deposits; their settlement is untested.
- DAI earns only after its conversion into USDS, which Sky can upgrade [s5]. The operator can keep each stablecoin within its cap through the DAI–USDS conversion and CoW sales of USDS.
- The converter adds a policy target with fixed-ceiling approvals, like the stETH approval to the wstETH contract.

## Confirmation

- INV-015 in the [invariants](/specs/invariants.md); tests refuse every venue outside the scope [s8].
- Converter tests pay the Asset Safe in both directions, refuse other receivers and refuse approvals at or above the ceiling [s7]. The kit's ceiling stands in for one mandate size.
- Owed: the universal factory's Morpho Blue shape and its end-to-end test.

## Reversal conditions

- Lido Lend ships with an interface that the universal factory's Morpho Blue shape cannot express.
- The mandate changes the asset list.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
