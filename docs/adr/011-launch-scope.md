---
type: Decision
title: "ADR 011: Launch scope"
description: The launch assets and venues, the later onboarding of Lido Lend, and the integrations outside the launch.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-13T06:47:18Z
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
---

# ADR 011: Launch scope

## Context

- The mandate caps each of USDC, USDT, USDS and DAI as a share of stablecoins [s6].
- Sky converts DAI and USDS one to one in either direction, without an admin or a fee, to a receiver that the caller names. Sky can upgrade USDS; DAI is not upgradeable. The Agent holds 4,673,791.03 DAI [s5].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. The launch list is ETH, WETH, stETH, wstETH, earnETH, earnUSD, USDC, USDT, USDS, sUSDS, CoW access, and Lido Lend access, which is compatibility with Morpho Blue (decision log, 2026-09-22; OD-91).
2. The launch list includes DAI (decision log, 2026-09-22).
3. The vault launches without Lido Lend, but with a tested motion that onboards an ERC-4626 lender vault. Lido Lend must be ready on the day it deploys, through a motion (decision log, 2026-09-22; OD-102, OD-132, OD-134).
4. Replaced by decision 11 (OD-43).
5. Replaced by ADR 014 decision 3 (OD-106).
6. Replaced by decision 12 (OD-46).
7. DAI earns through Sky's DAI–USDS converter. The operator may convert DAI to USDS and back, one to one, with the receiver pinned to the Asset Safe (OD-22).
8. The DAI and USDS approvals to the converter have a fixed ceiling of one mandate size, as the stETH approval to the wstETH contract does, and a motion changes it by writing the approval's permission again (OD-22, OD-89, OD-134).
9. DAI stays off the operator's order lists, and recovery can sell DAI into USDC or USDT (OD-22, OD-43).
10. Stated by [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28.
11. Stated by [ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 17 and 20.
12. Stated by [ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 22 and 41.
13. Lido Lend is a separate deployment that is compatible with Morpho Blue, not markets on Morpho Blue's own contract. The vault lends through Lido Lend's lender vault, an ERC-4626 token, with the receiver and the owner pinned to the Asset Safe. It uses neither the lender vault's fallback exit nor its settlement, so no collateral enters the Asset Safe, and USDY cannot enter. A position returns only the asset that it lent: WETH and USDC, and USDT if a market lends it. The lender vault's address enters with the universal factory's onboarding motion, and that motion also adds its emergency exit ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13) (OD-49, OD-102, OD-132, OD-133).
14. Stated by [ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 13, 22 and 27.
15. LDO is off the launch list. It is on neither the operator's order lists nor the recovery sell list (OD-91).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

| Asset or venue | Role in the vault | Notes |
|---|---|---|
| ETH, WETH | held; wrap and unwrap; ETH staked through `submit`; WETH bought and sold in CoW orders by the operator, and sold by recovery ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 13 and 22) | — |
| stETH, wstETH | held; wrap and unwrap; sold through CoW orders | — |
| USDC, USDT | held | — |
| DAI | held; converted to USDS and back through Sky's converter, one to one | recovery sells it (decision 9) |
| USDS | held; receives converted DAI | — |
| sUSDS | savings position | an ERC-4626 position of the launch policy; the operator redeems it, and recovery can sell it in a CoW order |
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem; the DAO's first-loss shares sit in the first-loss Safe ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 19); insurance at launch ([ADR 014](/adr/014-funding-by-top-up-motions.md) decision 4) |
| Orders account | CoW market, limit and TWAP orders for the operator; recovery orders into USDC or USDT for the emergency role | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Lido Lend | lending, after launch | one motion of the universal factory that onboards Lido Lend's lender vault, an ERC-4626 vault, once Lido Lend's own contracts exist (decision 13); a position returns only WETH, USDC or USDT; in the protocol cap until it matures ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28); insurance at launch ([ADR 014](/adr/014-funding-by-top-up-motions.md) decision 4) |

A top-up motion brings stETH, DAI, USDC, USDT or sUSDS. ETH, WETH, wstETH and USDS come from these inside the vault: by staking, wrapping and Sky's converter ([ADR 014](/adr/014-funding-by-top-up-motions.md) decision 3), because Aragon Voting pays any token through Finance.

Out of the launch scope: sDAI, Aave and every other third-party lending market; Lido's withdrawal queue, and router swaps on Uniswap and 1inch ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 27 and 20); and LDO (decision 15).

## Options considered

- **Wait for Lido Lend:** not chosen (decision 3). A motion onboards it later.
- **Lend through Lido Lend's core, or through both surfaces:** not chosen (decision 13).
- **The lender vault's fallback exit or its settlement:** not chosen (decision 13). Each can pay the market's collateral, and USDY, the stablecoin market's collateral, cannot enter the Asset Safe.
- **Aave v3 or sDAI:** not chosen. EM's launch list leaves them out.
- **Swap DAI for USDS in CoW orders:** not chosen. Each swap pays a stablecoin-pair margin; Sky's converter is one to one, without a fee [s5].
- **Leave DAI idle:** not chosen (decision 7). It earns nothing.

## Consequences

- The policy authorizes asynchronous vault deposits; their settlement is untested.
- A position in Lido Lend has no exit while its market has no free liquidity: a withdrawal fails then (decision 13). The emergency role can still send the lender vault's shares to the Aragon Agent, which claims later ([threat model](/specs/threat-model.md)).
- DAI earns only after its conversion into USDS, which Sky can upgrade [s5]. The operator can keep each stablecoin within its cap through the DAI–USDS conversion and CoW sales of USDS.

## Confirmation

- INV-008 and INV-015 in the [invariants](/specs/invariants.md); INV-003 for the converter's receiver.
- Each protocol of the launch policy on the Asset Safe has an onboarding motion, built from the committed policy and enacted through the live Easy Track: Lido staking, WETH, Sky, earnUSD and earnETH (`test_launch_onboarding_of_lido_staking`, `test_launch_onboarding_of_weth`, `test_launch_onboarding_of_sky`, `test_launch_onboarding_of_earn_usd`, `test_launch_onboarding_of_earn_eth`). Only the emergency role's staking of ETH comes from a vote.
- One motion onboards an ERC-4626 lending vault with the writes of decision 13, and the operator lends and the emergency role exits (`test_uf_motion_onboards_an_erc4626_lending_vault`). The test uses a deployed ERC-4626 vault as a stand-in. Owed: the same test against Lido Lend's lender vault, once it is deployed on mainnet.

## Reversal conditions

- Lido Lend's lender vault ships with an interface that is not ERC-4626, or that the Roles conditions cannot pin to the Asset Safe.
- A market of Lido Lend stays without free liquidity for longer than the mandate's emergency window.
- The mandate changes the asset list.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
