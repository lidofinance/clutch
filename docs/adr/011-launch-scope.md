---
type: Decision
title: "ADR 011: Launch scope"
description: The launch assets and venues; Lido Lend is onboarded by motion through a Morpho Blue template that ships at launch with end-to-end tests, and stays in the protocol cap until it matures; swaps are CoW orders from the orders account; DAI earns through Sky's DAI–USDS converter; sDAI, third-party lending markets, and router swaps on Uniswap and 1inch are out at launch.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-09T06:40:00Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the launch assets, DAI and Lido Lend, 2026-09-22, and on WETH and DAI, 2026-10-05
  - id: s2
    resource: /specs/lip-draft.md
    title: LIP draft — launch asset and action matrix
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/README.md"
    title: Kit harness README at 7a8c661 — the policy follows the launch scope; what the kit still lacks
  - id: s4
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — USDS is not in the payment ACL chain
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

- Lido Lend is expected in October 2026 and is compatible with Morpho Blue [s1].
- USDS cannot be paid out through the existing payment path [s4]. EM decided on 2026-10-05 that a DAO vote adds it (decision 5).
- Since 2026-10-05 the kit's policy follows this scope [s3].
- The mandate names four main stablecoins: USDC, USDT, USDS and DAI. It caps the vault's holding of any one of them at a share of its stablecoins, and it requires a stablecoin buffer of one month of baseline spend [s6].
- Sky's DAI–USDS converter turns DAI into USDS one to one, and back. It has no admin and no fee, and it pays a receiver that the caller names. USDS is an upgradeable proxy under Sky governance; DAI is not. The Agent holds 4,673,791.03 DAI [s5].

## Decision

EM decided on 2026-09-22 [s1]:

1. The launch list: "ETH, WETH, stETH, wstETH, EarnETH, EarnUSD, USDC, USDT, USDS, sUSDS, CowSwap access, Lido Lend access (which is basically Morpho Blue compat), LDO".
2. Add DAI.
3. Launch without Lido Lend, but with the Morpho Blue template and end-to-end tests for it. Lido Lend must be ready on the day it deploys, through an Easy Track motion.
4. CoW access runs through Stonks 2.0, the default swap engine ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).

EM decided on 2026-10-05, closing OD-11 [s1]:

5. The funding assets are USDC, USDT, DAI, USDS, sUSDS and stETH. ETH is not one ([ADR 008](/adr/008-funding-through-existing-payments.md)).

EM decided on 2026-10-05, closing OD-20 [s1]:

6. WETH is supported through stETH: it is unwrapped and staked to sell, and bought back through Lido's withdrawal queue. Only stETH, LDO, USDC, USDT, USDS and DAI are swapped ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).

EM decided on 2026-10-05, closing OD-22 [s1]:

7. DAI earns through Sky's DAI–USDS converter. The operator may convert DAI to USDS and back, one to one, with the receiver pinned to the Asset Safe.
8. The DAI and USDS approvals to the converter carry a fixed ceiling of one TM Floor Value, as the stETH approval to the wstETH contract does ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
9. DAI stays out of the Stonks rebalancing set. Recovery keeps its DAI→USDC instance.

EM decided on 2026-10-06, closing OD-41 and OD-43 [s1]:

10. Lido Lend stays in the protocol cap until it matures, and a motion unlocks it ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28). earnETH and earnUSD are not new products.
11. Every swap is a CoW order placed from the orders account. Uniswap and 1inch wait until the screening vendor can bound a swap's minimum output ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). This replaces decision 4. Decision 6 stands for WETH; its list of swapped tokens gives way to the order lists of ADR 007. Decision 9 stands for the operator's order lists: DAI stays out of them, and recovery can still sell DAI into USDC or USDT.

EM decided on 2026-10-06, closing OD-46 [s1]:

12. WETH joins the operator's order lists ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 22). The route of decision 6 through stETH stays available, but it is no longer the only one. A later token needs a DAO vote.

EM stated on 2026-10-06, closing OD-49 [s1]:

13. Lido Lend is a separate deployment that is compatible with Morpho Blue, not markets on Morpho Blue's own contract. Its address enters with the onboarding motion, and that motion also adds its emergency exit ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13).

EM decided on 2026-10-08 [s1]:

14. Lido's withdrawal queue leaves the launch scope. WETH is bought and sold in CoW orders, and ETH is staked through `submit` ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 27). The other assets of the launch list stay: ETH staking, WETH, DAI with Sky's converter, and LDO.

Decision 14 replaces the withdrawal-queue route of decision 6.

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

| Asset or venue | Role in the vault | Notes |
|---|---|---|
| ETH, WETH | held; wrap and unwrap; WETH bought and sold in CoW orders by the operator, and sold by recovery; staking stays available; no withdrawal queue (decision 14) | not a funding asset |
| stETH, wstETH | held; wrap and unwrap; sold through CoW orders | stETH can seed the vault |
| USDC, USDT | held | can seed the vault |
| DAI | held; converted to USDS and back through Sky's converter, one to one | can seed the vault; recovery sells it into USDC or USDT (OD-26) |
| USDS | held; receives converted DAI | can fund the vault once a DAO vote adds it to the payment permission |
| sUSDS | savings position | tokenized-vault template; can also fund the vault; the operator redeems it, and recovery can sell it in a CoW order |
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem; the DAO's first-loss shares go from the Growth Committee to the first-loss Safe, which no role can reach (OD-21, OD-28, OD-42) |
| LDO | held | on the operator's order lists |
| Orders account | CoW market, limit, TWAP and stop-loss orders for the operator; recovery orders into USDC or USDT for the emergency role | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Lido Lend | lending, after launch | one motion through the Morpho Blue template once Lido Lend's own contract exists, which also adds its emergency exit (OD-49); the protocol cap applies until it matures and a budget motion unlocks it (OD-41) |

Out of the launch scope: sDAI, Aave and every other third-party lending market, Lido's withdrawal queue (decision 14), and router swaps on Uniswap and 1inch until the screening vendor can bound their output (OD-43).

## Options considered

- Wait for Lido Lend before launch. Not chosen by EM: it arrives later by motion.
- Keep Aave v3 and sDAI from the original proposal. Not chosen: they are not in EM's list.
- DAI in the Stonks rebalancing set. Not chosen by EM: every conversion would pay the stablecoin-pair margin.
- DAI idle as part of the liquidity buffer. Not chosen by EM: DAI would earn nothing, and a share above the mandate's per-stablecoin cap could only be fixed by recovery or a vote.

## Consequences

- The Morpho Blue template ships before the market it will point at exists. Its acceptance needs end-to-end tests against the deployed Morpho Blue contract on a fork.
- The kit's policy no longer grants Aave v3, sDAI or order pre-signing, and a fork test refuses them [s8].
- Asynchronous vault deposits are authorised at the policy layer in the kit. Their settlement is not tested.
- DAI earns only after conversion. Converted value is exposed to USDS, which Sky governance can upgrade [s5].
- The operator can keep each stablecoin under the mandate's per-stablecoin cap, by converting between DAI and USDS and by selling USDS through CoW orders.
- The converter is one more target in the operator's policy. Its approvals are bounded like the stETH approval to wstETH.

## Confirmation

- INV-015 in the [invariants](/specs/invariants.md). Kit tests refuse every out-of-scope venue [s8].
- The end-to-end test of the Morpho Blue template. It does not exist yet.
- Kit test: a conversion pays the Asset Safe in both directions; a conversion with any other receiver is refused; an approval to the converter at or above the ceiling is refused [s7]. The ceiling in the kit is a dry-run stand-in for one TM Floor Value.

## Reversal conditions

- Lido Lend ships with an interface that the Morpho Blue template cannot express.
- The mandate changes the asset list.

## Open questions

None open. OD-22 was decided on 2026-10-05, OD-04 on 2026-10-02, and OD-41, OD-43, OD-46 and OD-49 on 2026-10-06 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), [ADR 007](/adr/007-swapping-through-an-orders-account.md)).
