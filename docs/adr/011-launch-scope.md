---
type: Decision
title: "ADR 011: Launch scope"
description: Launch assets and venues, the later Lido Lend onboarding and excluded integrations.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T18:22:59Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the launch assets, DAI and Lido Lend, 2026-09-22, on WETH and DAI, 2026-10-05, and on LDO, 2026-10-22
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

- Lido Lend is expected in October 2026 with Morpho Blue compatibility [s1].
- Existing payments exclude USDS [s4]; EM chose its addition by vote on 2026-10-05 (decision 5).
- The kit follows this scope since 2026-10-05 [s3].
- The mandate caps each of USDC, USDT, USDS and DAI as a share of stablecoins, with one month of baseline spend as a stablecoin buffer [s6].
- Sky converts DAI/USDS one-to-one in either direction, without admin or fee, to a caller-named receiver. USDS is upgradeable by Sky; DAI is not. The Agent holds 4,673,791.03 DAI [s5].

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

EM decided on 2026-10-22, closing OD-91 [s1]:

15. LDO leaves the launch list. It is on neither the operator's order lists nor the recovery sell list.

Decision 15 replaces LDO in decisions 1 and 14, and in the operator's lists of [ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 4 and 22.

Since OD-89, the TM Floor Value of decision 8 means one mandate size ([ADR 008](/adr/008-funding-through-existing-payments.md), decisions 32 to 34).

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
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem; the DAO's first-loss shares go from the Growth Committee to the first-loss Safe, where a burn runs only by Easy Track motion and the narrow role of the committee's Safe redeems them to the Aragon Agent (OD-21, OD-28, OD-42, OD-60, OD-67) |
| Orders account | CoW market, limit and TWAP orders for the operator, and no stop-loss orders ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 39); recovery orders into USDC or USDT for the emergency role | [ADR 007](/adr/007-swapping-through-an-orders-account.md) |
| Lido Lend | lending, after launch | one motion through the Morpho Blue template once Lido Lend's own contract exists, which also adds its emergency exit (OD-49); the protocol cap applies until it matures and a budget motion unlocks it (OD-41) |

Out of the launch scope: sDAI, Aave and every other third-party lending market, Lido's withdrawal queue (decision 14), LDO (decision 15), and router swaps on Uniswap and 1inch until the screening vendor can bound their output (OD-43).

## Options considered

- Wait for Lido Lend: EM rejected; onboard it later by motion.
- Keep Aave v3/sDAI: rejected because EM's list excludes them.
- Rebalance DAI through Stonks: EM rejected because each conversion pays stablecoin-pair margin.
- Leave DAI idle in the buffer: EM rejected because it earns nothing, and excess above its cap could only be fixed by recovery or a vote.

## Consequences

- The Morpho Blue template ships before its target market exists. Acceptance requires end-to-end fork tests against deployed Morpho Blue.
- The kit's policy no longer grants Aave v3, sDAI or order pre-signing; fork tests refuse them [s8].
- The kit authorizes asynchronous vault deposits at the policy layer; settlement is untested.
- DAI earns only after conversion into upgradeable USDS [s5]. The operator can keep each stablecoin within its cap through DAI/USDS conversion and CoW sales of USDS.
- The converter adds a policy target with fixed-ceiling approvals, like stETH-to-wstETH.

## Confirmation

- INV-015 in the [invariants](/specs/invariants.md); tests refuse every out-of-scope venue [s8].
- The Morpho Blue template's end-to-end test remains unbuilt.
- Converter tests pay the Asset Safe in both directions, refuse other receivers and refuse approvals at or above the ceiling [s7]. The kit ceiling stands in for one mandate size.

## Reversal conditions

- Lido Lend ships with an interface that the Morpho Blue template cannot express.
- The mandate changes the asset list.

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
