---
type: Research Note
title: Legacy investments, 2026-10-05
description: The evidence behind OD-21 — the DAO's first-loss shares in EarnETH and EarnUSD, the Growth Committee Safe that holds them, how they arrived and were once burned, whether they can move, and the search for the Twyne position.
tags: [funding, earn, first-loss, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-05
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T16:07:52Z
verified: []
sources:
  - id: s1
    resource: "https://research.lido.fi/t/lido-earn-competing-on-trust-5m-treasury-allocation/11228"
    title: "Lido Earn: Competing on Trust — $5m Treasury Allocation; the Growth Committee executes, its execution address holds the shares, and the first-loss burn rule"
  - id: s2
    resource: "https://snapshot.org/#/s:lido-snapshot.eth/proposal/0xd32eab4ce41e2754d8a51fdf89bd9f4eb43ecbeb7b60d0e93ce84bc3e4d4c8a3"
    title: Snapshot vote on the Lido Earn treasury allocation, closed 2026-03-09
  - id: s3
    resource: "https://blog.lido.fi/lido-poolside-recap-tokenholder-update-may-2026/"
    title: Lido tokenholder update, May 2026 — the DAO approved the burn of EarnETH shares valued at 144 ETH after the Kelp incident
  - id: s4
    resource: "https://etherscan.io/address/0xf6F0732c1e9971497342C295141566E6F1A31e96"
    title: The Growth Committee Safe that holds the DAO's Earn shares — owners, threshold, modules, guard and token history, read at block 26126791
  - id: s5
    resource: "https://etherscan.io/tx/0x2f9d886f6687a8e6c4904bdbf9581ebb78bf47595651ccd767088bec91db3e07"
    title: The LOL committee's Safe sends the earnUSD shares to the holder, 2026-04-01
  - id: s6
    resource: "https://etherscan.io/tx/0x5abd3ccf5790c21fdb4fe07c91ca29238ec189b382de7b7561032c8e5c9a2978"
    title: The LOL committee's Safe sends the earnETH shares to the holder, 2026-06-25
  - id: s7
    resource: "https://etherscan.io/tx/0xdfca0390d39299ec88e6be26f5254d873b9a1098f71591c42f357412d60e71c7"
    title: The LOL committee's Safe burns 143.98 earnETH shares, 2026-05-15
  - id: s8
    resource: "https://etherscan.io/address/0x48c4929630099b217136b64089E8543dB0E5163a#readContract"
    title: The LOL committee's stETH top-up registry — its two allowed recipients, read at block 26126791
  - id: s9
    resource: "https://etherscan.io/address/0x000000000c79d2b5cd58ae545afc83030233d7b6#code"
    title: Lido Earn BurnableTokenizedShareManager implementation — the transfer checks, the flags and the holder-side burn
  - id: s10
    resource: "https://etherscan.io/address/0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4#readContract"
    title: earnETH share manager — balances, flags and account settings, read at block 26126791
  - id: s11
    resource: "https://etherscan.io/address/0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981#readContract"
    title: earnUSD share manager — balances, flags and account settings, read at block 26126791
  - id: s12
    resource: "https://twyne.gitbook.io/twyne/resources/on-chain-addresses"
    title: Twyne on-chain addresses — its Ethereum credit vaults, read 2026-10-05
  - id: s13
    resource: "https://research.lido.fi/t/twyne-lido-alliance-proposal/9901"
    title: Twyne Lido Alliance proposal — the token contribution to the Lido Alliance
  - id: s14
    resource: "https://etherscan.io/block/26126791"
    title: Ethereum block 26126791, used for every chain read on this page
  - id: s15
    resource: "https://github.com/lidofinance/docs/blob/fa199bc5e33e4e47d0a6232abec241f1cac69eba/docs/multisigs/committees.md"
    title: Lido multisig documentation at fa199bc — the LOL committee Safe and the Growth Committee
  - id: s16
    resource: /research/funding-registries-2026-10-02.md
    title: Easy Track funding registries, 2026-10-02 — the twelve top-up registries
---

# Legacy investments, 2026-10-05

An agent ran every chain read on this page on 2026-10-05. The reads use Ethereum mainnet block 26126791, hash `0xf95a2f933213511dea670c8d1e2bd86535b0050d80a60a0bc929eb8faa8db0b0`, time 2026-10-05T14:33:59Z [s14].

## The Earn positions

- **What they are.** They are the DAO's first-loss allocation to Lido Earn. A Snapshot vote that closed on 2026-03-09 approved $3M in wstETH for EarnETH and $2M in USDC for EarnUSD [s1][s2].
- **Who acts on them.** The Growth Committee executes deposits, withdrawals and conversions, and a Growth Committee address holds the shares. After a loss of 1% or more is flagged, the committee burns up to all of the DAO's shares in that vault. The DAO may change or end this arrangement at any time. The DAO's positions leave only through standard redemption [s1].
- **The holder today.** Safe `0xf6F0732c1e9971497342C295141566E6F1A31e96` holds 1,362.835894090579470546 earnETH shares and 1,998,416.461042983403493685 earnUSD shares [s4][s10][s11]. It is a Safe v1.4.1 with nine owners and a threshold of five, and it has no modules and no guard [s4].
- **Its place in the Growth Committee.** It is the second allowed recipient of the LOL committee's stETH top-up registry. The LOL committee's Safe is the registry's trusted caller and its first recipient [s8][s15]. The holder also keeps stETH that the committee uses for other work [s4].
- **How the shares arrived.** The LOL committee's Safe sent the earnUSD shares on 2026-04-01 and the earnETH shares on 2026-06-25 [s5][s6].
- **The first-loss burn.** On 2026-05-15 the LOL committee's Safe burned 143.98 earnETH shares, after the Kelp incident [s3][s7].
- **Other addresses.** The Aragon Agent, the committee's Safe, the LOL committee's Safe and the Rewards Share committee's Safe hold no shares of either vault. Neither do the six other committee Safes that receive Easy Track top-ups directly [s10][s11][s16].

## Can the shares move

- Both share tokens are ERC-20 tokens. At the block, neither has a mint, burn or transfer pause, a deposit or transfer whitelist, or a lockup, and the holder is not blacklisted [s9][s10][s11]. A transfer from the holder to the Asset Safe therefore works today.
- The vaults' administrators can add a pause, a whitelist, a lockup or a blacklist later [s9].
- A burn acts on the caller's own shares, or on shares that the caller may spend. The holder therefore executes a first-loss burn [s9].

## Twyne

- Twyne's credit vaults on Ethereum take wrapped ETH and wstETH positions from Euler and Aave. None of them takes USDC [s12].
- The Lido Alliance thread records Twyne giving the Lido Alliance 10% of its token supply, with a one-year cliff and two years of vesting. It records no payment from Lido [s13].
- At the block, none of the Aragon Agent, the committee's Safe, the Growth Committee holder, the LOL committee's Safe and the two Lido Alliance Safes holds a Twyne vault token. The token histories of the Growth Committee holder, the LOL committee's Safe and the Alliance operations Safe show no Twyne token [s12][s14].
- The holder and the form of the Twyne position are not known.

## How to reproduce

Set `ETH_RPC_URL` in your shell. `cast` reads it from the environment. Never write the URL into a file.

```sh
B=26126791
G=0xf6F0732c1e9971497342C295141566E6F1A31e96
EETH=0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4
EUSD=0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981
cast call $EETH 'sharesOf(address)(uint256)' $G --block $B
cast call $EUSD 'sharesOf(address)(uint256)' $G --block $B
cast call $EETH 'flags()((bool,bool,bool,bool,bool,uint32))' --block $B
cast call $EETH 'accounts(address)' $G --block $B
cast call $G 'getOwners()(address[])' --block $B
cast call $G 'getThreshold()(uint256)' --block $B
cast call 0x48c4929630099b217136b64089E8543dB0E5163a 'getAllowedRecipients()(address[])' --block $B
cast call <Twyne vault> 'balanceOf(address)(uint256)' <address> --block $B
```

## Limits

- Every read describes its block.
- The Twyne search covers the addresses named above. It does not prove that no Lido address holds a Twyne position.
- This page records evidence. EM's decision is in the [decision log](/registers/decision-log.md).
