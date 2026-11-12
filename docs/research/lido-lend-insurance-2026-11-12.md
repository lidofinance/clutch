---
type: Research Note
title: Lido Lend's contracts and an insurance fund for them, 2026-11-12
description: "What the public Lido Lend repositories show for OD-131: the core has no share token, the lender vault has no holder's burn, bad debt is shared among suppliers at liquidation, and no function pays lenders back; so neither form of a Lido Lend fund has a Lend-side entry point today."
tags: [insurance, lido-lend, first-loss, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-12
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T11:07:54Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/lend/blob/4d55f1dd98a0f7712543965c66e03c963a004263/README.md#L3-L14"
    title: Lido Lend core at 4d55f1d — a fork of Morpho Blue, and the four changes of the fork
  - id: s2
    resource: "https://github.com/lidofinance/lend/blob/4d55f1dd98a0f7712543965c66e03c963a004263/src/LidoLend.sol#L203-L616"
    title: Lido Lend core at 4d55f1d — supply, withdraw, repay, settle and liquidate, with the bad-debt accounting of a liquidation
  - id: s3
    resource: "https://github.com/lidofinance/lend/blob/4d55f1dd98a0f7712543965c66e03c963a004263/FORK_NOTES.md"
    title: Lido Lend core at 4d55f1d — the fork point, the kept ABI and the proxy
  - id: s4
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/src/LidoLendERC4626.sol#L138-L146"
    title: Lido Lend Markets at 23416c4 — the lender vault counts only the supply that it made itself
  - id: s5
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/src/LidoLendERC4626.sol#L220-L290"
    title: Lido Lend Markets at 23416c4 — the lender vault's targeted settlement and fallback exit
  - id: s6
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/docs/specs/lender-settlement.md#L3-L53"
    title: Lido Lend Markets at 23416c4 — settlement pays collateral, and it stops while the riskiest borrower has bad debt
  - id: s7
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/docs/specs/market-controller.md#L17-L37"
    title: Lido Lend Markets at 23416c4 — the controller's hooks; a lender's supply meets only the supply cap and the pause
  - id: s8
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/docs/specs/markets/eth-steth.md#L9-L39"
    title: Lido Lend Markets at 23416c4 — the WETH market with wstETH collateral, with no liquidity backstop
  - id: s9
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/docs/specs/markets/stables-usdy.md#L11-L12"
    title: Lido Lend Markets at 23416c4 — the stablecoin market with USDY collateral
  - id: s10
    resource: "https://github.com/lidofinance/lend-markets/tree/23416c43c4038ea3c00a13d6203949c8f88905cc/deployed"
    title: Lido Lend Markets at 23416c4 — the deployment records, which hold one testnet run
  - id: s11
    resource: "https://github.com/lidofinance/lend-markets/blob/23416c43c4038ea3c00a13d6203949c8f88905cc/docs/specs/roles.md#L45"
    title: Lido Lend Markets at 23416c4 — the Aragon Agent is the first admin of every proxy
  - id: s12
    resource: /adr/014-funding-by-tranche-votes.md
    title: ADR 014 — insurance at launch for Lido Earn and Lido Lend, and the two forms of a Lido Lend fund
  - id: s13
    resource: /registers/decision-log.md
    title: Decision log — EM's request of 2026-11-12 to investigate Lido Lend for OD-131
---

# Lido Lend's contracts and an insurance fund for them, 2026-11-12

EM asked the agent to investigate the two public Lido Lend repositories for OD-131 [s13]. The agent read both at the commits that the sources pin. It ran no code of either repository.

## Answer

Neither form of a Lido Lend fund of [ADR 014](/adr/014-funding-by-tranche-votes.md) decision 6 has an entry point in Lido Lend today [s12].

- **Burnable shares.** The core keeps a lender's supply as a number in its own storage, as Morpho Blue does. It has no share token [s1][s2]. The lender vault is an ERC-4626 token, and it has no burn that a holder can call [s5].
- **A fixed payout address.** No function of the core adds loan assets to a market without new supply shares [s2]. A transfer to the lender vault, and a supply to the core in the vault's name, do not change the vault's share price [s4]. So no Lend contract turns a payment into a gain for lenders.

## What the repositories show

1. **The core is a fork of Morpho Blue.** It keeps the market, position and action shapes. It adds owner-only market creation, a controller's hooks, `settle` and a proxy [s1][s3].
2. **A lender has two surfaces.** The core's `supply` and `withdraw` keep their Morpho Blue signatures [s3]. The lender vault wraps one market as an ERC-4626 token [s5].
3. **A lender's supply meets two limits:** the market's supply cap, and the controller's pause [s7]. The agent found no list of allowed lenders.
4. **Bad debt is shared.** A liquidation that leaves bad debt takes that amount off the market's total supply, so every supplier of the market loses in proportion [s2].
5. **Settlement is not a loss cover.** It cancels a borrower's debt against a lender's own supply and pays that lender collateral of the same oracle value. It stops while the riskiest borrower has bad debt [s6].
6. **The lender vault's exits can pay collateral.** Its fallback exit pays loan assets from free liquidity first, and collateral when it must settle [s5][s6]. The collateral is wstETH in the WETH market and USDY in the stablecoin market [s8][s9].
7. **No mainnet deployment is recorded.** The deployment records hold one testnet run [s10].
8. **The contracts can change.** The core and each vault run behind proxies, and the Aragon Agent is their first admin [s11].

## What this means for OD-131

- The share form does not fit Lido Lend as it is. The assumption of the agent's first recommendation, a share token with a holder's `burn(uint256)`, is false.
- Two payments could cover a loss with the functions that exist. Each has a limit.
  - A `repay` in a borrower's name, before a liquidation writes the debt off, lowers the loss of every lender of that market [s2]. A motion waits 72 hours, and a liquidation does not wait. A fund's creating motion also cannot pin a borrower.
  - A payment to an address outside Lido Lend, which then pays the lenders. This fits the payout form: the creating motion pins the address and the cap. The address and its rules are not in either repository.
- A loss cover inside Lido Lend needs a change of Lido Lend: a function that adds loan assets to a market's supply without new shares. The Lend team decides that.

## A second finding, for the onboarding shape

[ADR 011](/adr/011-launch-scope.md) decision 13 plans the Morpho Blue shape for Lido Lend, which uses the core's `supply` and `withdraw`. That shape fits the core [s3]. The core's `withdraw` fails when the market has no free liquidity. The lender vault's fallback exit still works then, and it can pay collateral [s5][s6]. In the WETH market the collateral is wstETH, which is on the launch list. In the stablecoin market it is USDY, which is not [s9]. OD-132 holds the choice of the surface.

## Limits of this note

- The agent read the two repositories at one commit each. Both can change, and the deployed contracts can differ from them.
- The agent did not read the interest-rate model's repository, and it ran no test of either repository.
- The agent did not ask the Lend team. The questions for it are in OD-131 and OD-132.
