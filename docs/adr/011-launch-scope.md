---
type: Decision
title: "ADR 011: Launch scope"
description: The launch assets and venues; Lido Lend is onboarded by motion through a Morpho Blue template that ships at launch with end-to-end tests; DAI earns through Sky's DAI–USDS converter; sDAI and third-party lending markets are out.
tags: [scope, assets, launch, lido-lend]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
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
4. CoW access runs through Stonks 2.0, the default swap engine ([ADR 007](/adr/007-swapping-through-stonks.md)).

EM decided on 2026-10-05, closing OD-11 [s1]:

5. The funding assets are USDC, USDT, DAI, USDS, sUSDS and stETH. ETH is not one ([ADR 008](/adr/008-funding-through-existing-payments.md)).

EM decided on 2026-10-05, closing OD-20 [s1]:

6. WETH is supported through stETH: it is unwrapped and staked to sell, and bought back through Lido's withdrawal queue. Only stETH, LDO, USDC, USDT, USDS and DAI are swapped ([ADR 007](/adr/007-swapping-through-stonks.md)).

EM decided on 2026-10-05, closing OD-22 [s1]:

7. DAI earns through Sky's DAI–USDS converter. The operator may convert DAI to USDS and back, one to one, with the receiver pinned to the Asset Safe.
8. The DAI and USDS approvals to the converter carry a fixed ceiling of one TM Floor Value, as the stETH approval to the wstETH contract does ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
9. DAI stays out of the Stonks rebalancing set. Recovery keeps its DAI→USDC instance.

## Proposed direction

The rest of this section is agent-drafted [s2]. EM has not accepted it as text.

| Asset or venue | Role in the vault | Notes |
|---|---|---|
| ETH, WETH | held; wrap and unwrap; staked to stETH before a sale, and bought back through Lido's withdrawal queue | not a funding asset; no swap instance |
| stETH, wstETH | held; wrap and unwrap | stETH can seed the vault; wstETH is unwrapped before a sale |
| USDC, USDT | held | can seed the vault |
| DAI | held; converted to USDS and back through Sky's converter, one to one | can seed the vault; recovery sells it into USDC |
| USDS | held; receives converted DAI | can fund the vault once a DAO vote adds it to the payment permission |
| sUSDS | savings position | tokenized-vault template; can also fund the vault; redeemed before a sale |
| earnETH, earnUSD | vault positions | asynchronous deposit and redeem; the DAO's first-loss shares arrive from the Growth Committee, and the operator never redeems them (OD-21) |
| LDO | held | in the rebalancing set |
| Stonks 2.0 instances | rebalancing and recovery | [ADR 007](/adr/007-swapping-through-stonks.md) |
| Lido Lend | lending, after launch | one motion through the Morpho Blue template once the market exists; the protocol cap applies for its first three months, then none as a Lido own product (OD-04, decided 2026-10-02) |

Out of the launch scope: sDAI, Aave and every other third-party lending market.

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
- The operator can keep each stablecoin under the mandate's per-stablecoin cap, by converting between DAI and USDS and by rebalancing USDS through Stonks.
- The converter is one more target in the operator's policy. Its approvals are bounded like the stETH approval to wstETH.

## Confirmation

- INV-015 in the [invariants](/specs/invariants.md). Kit tests refuse every out-of-scope venue [s8].
- The end-to-end test of the Morpho Blue template. It does not exist yet.
- Kit test: a conversion pays the Asset Safe in both directions; a conversion with any other receiver is refused; an approval to the converter at or above the ceiling is refused [s7]. The ceiling in the kit is a dry-run stand-in for one TM Floor Value.

## Reversal conditions

- Lido Lend ships with an interface that the Morpho Blue template cannot express.
- The mandate changes the asset list.

## Open questions

None open. OD-22 was decided on 2026-10-05, and OD-04 on 2026-10-02 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
