---
type: Research Note
title: Recovery into USDT and the withdrawal-queue approval, 2026-10-05
description: The evidence behind OD-26 and OD-27 — how USDS and DAI carry USDC risk through Sky's peg stability module, the recovery topology before the decision, and who can upgrade Lido's withdrawal queue, how much one request takes, and whether a request can be cancelled.
tags: [recovery, usdt, withdrawal-queue, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-05
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:58:30Z
verified: []
sources:
  - id: s1
    resource: "https://etherscan.io/address/0xf6e72Db5454dd049d0788e411b06CfAF16853042#readContract"
    title: Sky's USDC peg stability module — its gem and its pocket, read at block 26128295
  - id: s2
    resource: "https://etherscan.io/address/0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341"
    title: The peg stability module's pocket — its USDC balance, read at block 26128295
  - id: s3
    resource: "https://www.coindesk.com/markets/2023/03/11/dai-depegs-as-stablecoin-rout-plagues-crypto"
    title: CoinDesk, 2023-03-11 — DAI hits an all-time low of 88 cents as USDC loses its peg; DAI's collateral includes USDC
  - id: s4
    resource: /adr/007-swapping-through-stonks.md
    title: ADR 007 — the recovery topology before OD-26, and the recovery instances pinned by the safety policy
  - id: s5
    resource: "https://etherscan.io/address/0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1#readProxyContract"
    title: Lido withdrawal queue — proxy admin, implementation, request limits and bunker mode, read at block 26128295
  - id: s6
    resource: "https://etherscan.io/address/0xE42C659Dc09109566720EA8b2De186c2Be7D94D9#code"
    title: Lido WithdrawalQueueERC721 implementation, verified source — 23 state-changing functions, none of which cancels a request
  - id: s7
    resource: "https://etherscan.io/block/26128295"
    title: Ethereum block 26128295, used for every chain read on this page
---

# Recovery into USDT and the withdrawal-queue approval, 2026-10-05

An agent ran every chain read on this page on 2026-10-05. The reads use Ethereum mainnet block 26128295, hash `0x08a472b1b87fab25173d5e2101050989c068ee6a128b80e0cd98170639d4bf74`, time 2026-10-05T19:35:23Z [s7].

## USDS and DAI carry USDC risk

- Sky's USDC peg stability module is `0xf6e72Db5454dd049d0788e411b06CfAF16853042`. Its gem is USDC [s1].
- Its pocket, `0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341`, holds 4,290,965,112.39 USDC at the block [s1][s2].
- On 2023-03-11, when USDC lost its peg, DAI fell to an all-time low of 88 cents. The report names USDC among DAI's collateral [s3].

## The recovery topology before OD-26

- Recovery had seven instances: stETH, LDO, USDT, USDS and DAI into USDC, and stETH and LDO into USDT [s4].
- In a USDC depeg, recovery had no swap for USDC, and it could swap USDS and DAI only into USDC [s4].
- The safety policy pins the recovery instances, so a later addition needs a DAO vote [s4].

## The withdrawal queue

- The queue is `0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1`. Its proxy admin is the Aragon Agent, so only a DAO vote can upgrade it. Its implementation is `0xE42C659Dc09109566720EA8b2De186c2Be7D94D9` [s5].
- One request takes at least 100 wei and at most 1,000 stETH [s5].
- The implementation has 23 state-changing functions. None of them cancels a request [s6].
- Bunker mode was off at the block [s5].

## How to reproduce

Set `ETH_RPC_URL` in your shell. `cast` reads it from the environment. Never write the URL into a file.

```sh
B=26128295
P=0xf6e72Db5454dd049d0788e411b06CfAF16853042
cast call $P 'gem()(address)' --block $B
cast call $P 'pocket()(address)' --block $B
cast call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 'balanceOf(address)(uint256)' 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341 --block $B   # 6 decimals
WQ=0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1
cast call $WQ 'proxy__getAdmin()(address)' --block $B
cast call $WQ 'proxy__getImplementation()(address)' --block $B
cast call $WQ 'MAX_STETH_WITHDRAWAL_AMOUNT()(uint256)' --block $B
cast call $WQ 'MIN_STETH_WITHDRAWAL_AMOUNT()(uint256)' --block $B
cast call $WQ 'isBunkerModeActive()(bool)' --block $B
```

The function list comes from the implementation's verified ABI, through the Etherscan `getabi` endpoint.

## Limits

- Every read describes its block. The peg stability module's balance changes daily.
- The CoinDesk report is a press source, not a price record.
- This page records evidence. EM's decisions are in the [decision log](/registers/decision-log.md).
