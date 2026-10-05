---
type: Research Note
title: DAI and the DAI–USDS converter, 2026-10-05
description: The evidence behind OD-22 — the treasury's stablecoin balances, Sky's DAI–USDS converter and what it lets a caller do, and how the DAI and USDS tokens differ in upgradeability.
tags: [dai, usds, conversion, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-05
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
verified: []
sources:
  - id: s1
    resource: "https://etherscan.io/address/0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A#code"
    title: Sky DaiUsds converter, verified source — immutable joins, no admin, no fee; daiToUsds and usdsToDai pay a receiver that the caller names
  - id: s2
    resource: "https://etherscan.io/address/0xdC035D45d973E3EC169d2276DDab16f1e407384F#code"
    title: USDS token — an ERC1967 proxy
  - id: s3
    resource: "https://etherscan.io/address/0x1923dfee706a8e78157416c29cbccfde7cdf4102#code"
    title: USDS implementation at the block, verified source — UUPS upgrades and wards; no freeze, blacklist or pause
  - id: s4
    resource: "https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F#code"
    title: DAI token, verified source — not a proxy
  - id: s5
    resource: "https://etherscan.io/address/0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c"
    title: Aragon Agent — stablecoin balances read at block 26127302
  - id: s6
    resource: "https://etherscan.io/block/26127302"
    title: Ethereum block 26127302, used for every chain read on this page
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/FullPolicy.sol"
    title: Kit policy at 370e20a — no permission on the DAI–USDS converter
---

# DAI and the DAI–USDS converter, 2026-10-05

An agent ran every chain read on this page on 2026-10-05. The reads use Ethereum mainnet block 26127302, hash `0x200efb8f8965a500dcaba0c4db8a5772c377c501bd56643096d071e01ff6b46a`, time 2026-10-05T16:16:23Z [s6].

## The treasury's stablecoins

At the block, the Aragon Agent holds 4,673,791.03 DAI, 9,606,793.69 USDC, 8,041,953.56 USDT, no USDS, 693,020.00 sUSDS and no sDAI [s5].

## The converter

- Sky's `DaiUsds` contract is at `0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A`. Its DAI and USDS addresses and its two joins are fixed at deployment. It has no admin and charges no fee [s1].
- `daiToUsds(usr, wad)` takes `wad` DAI from the caller and pays `wad` USDS to `usr`. `usdsToDai(usr, wad)` does the reverse. The caller first approves the converter to take the token [s1].
- The caller names the receiver, so a permission on the converter must pin `usr` to the Asset Safe.
- At 370e20a, the kit granted no permission on the converter [s7]. EM's decision added it.

## The two tokens

- USDS is an ERC1967 proxy. Its implementation at the block upgrades through UUPS under Sky's wards, and it has no freeze, blacklist or pause function [s2][s3].
- DAI is not a proxy [s4].

## How to reproduce

Set `ETH_RPC_URL` in your shell. `cast` reads it from the environment. Never write the URL into a file.

```sh
B=26127302
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c
cast call <token> 'balanceOf(address)(uint256)' $AGENT --block $B
C=0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A
cast call $C 'dai()(address)' --block $B
cast call $C 'usds()(address)' --block $B
cast storage 0xdC035D45d973E3EC169d2276DDab16f1e407384F 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --block $B   # USDS implementation
cast storage 0x6B175474E89094C44Da98b954EedeAC495271d0F 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --block $B   # zero: DAI is not a proxy
```

## Limits

- Every read describes its block. Sky governance can upgrade USDS.
- The source review covers the functions named above. It is not an audit.
- This page records evidence. EM's decision is in the [decision log](/registers/decision-log.md).
