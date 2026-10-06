---
type: Research Note
title: Stonks 2.0 pricing, 2026-10-05
description: The evidence behind OD-20 — how a Stonks 2.0 instance gets its price, who can configure the shared oracle router, which vault tokens Chainlink's Feed Registry covers, how often Chainlink replaced the vault's feeds, and the Lido staking and withdrawal-queue checks behind the WETH route.
tags: [stonks, pricing, oracle, chainlink, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-05
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T14:39:55Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/AmountConverter.sol#L65-L121"
    title: Stonks AmountConverter at 0669c4a — the router, the anchor and the token lists are fixed in the constructor; no admin
  - id: s2
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/routers/OracleRouter.sol#L137-L265"
    title: Stonks OracleRouter at 0669c4a — what the admin or the manager can set, turn on or off, and re-sync
  - id: s3
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/routers/OracleRouter.sol#L663-L691"
    title: Stonks OracleRouter at 0669c4a — a token's aggregator comes from Chainlink's Feed Registry, and a token without a registry feed is refused
  - id: s4
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/routers/OracleRouter.sol#L551-L597"
    title: Stonks OracleRouter at 0669c4a — a price read is refused when the registry's aggregator differs from the stored one
  - id: s5
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/Ownable.sol#L15-L51"
    title: Stonks Ownable at 0669c4a — the admin is fixed at deployment, and the admin or the manager passes onlyAdminOrManager
  - id: s6
    resource: "https://github.com/lidofinance/stonks/blob/0669c4a50660912785e18861d9ef8108a86a3552/contracts/factories/AmountConverterFactory.sol#L54-L75"
    title: Stonks AmountConverterFactory at 0669c4a — anyone deploys a converter with any token lists on the factory's router
  - id: s7
    resource: "https://github.com/lidofinance/audits/blob/dd83a42ac001f5774e3de81a0435a1397a1a22fd/Ackee%20Blockchain%20Stonks%202%20Audit%20Report%2012-25.pdf"
    title: Ackee audit of Stonks 2.0 — every contract in scope, the fix review at 0669c4a, and the deployment verification of the router, the converter factory and the converters
  - id: s8
    resource: "https://etherscan.io/address/0x79ef3a538200Fe4981D67E7e886bfb36D4Cb5a31#readContract"
    title: Stonks 2.0 oracle router — admin, manager, token settings and sync state, read at block 26126631
  - id: s9
    resource: "https://etherscan.io/address/0xD96223670BF73cB191a9F0b526653B7eC99dcf45#events"
    title: Stonks 2.0 converter factory — the three converters it deployed and their token lists
  - id: s10
    resource: "https://etherscan.io/address/0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf#readContract"
    title: Chainlink Feed Registry — feeds per token, and the FeedConfirmed events from block 23,500,000
  - id: s11
    resource: "https://reference-data-directory.vercel.app/feeds-mainnet.json"
    title: Chainlink's published list of Ethereum feeds — heartbeats and deviation thresholds, read 2026-10-05
  - id: s12
    resource: "https://etherscan.io/tx/0xd34730fe6f821e3f05eff51f1606276e10eaf40c5854e2d2793a1cd1373d8aee"
    title: Execution of vote 204, 2026-08-10 — Aragon Voting makes the committee's Safe the router's manager
  - id: s13
    resource: "https://etherscan.io/tx/0x318f630aa537a4383567baf83814139faa58ae9795e2860a8c803a05bea7efe3"
    title: The committee's Safe configures the ETH/USD bridge, stETH and LDO on the router, 2026-08-13
  - id: s14
    resource: "https://etherscan.io/block/26126631"
    title: Ethereum block 26126631, used for every chain read on this page
  - id: s15
    resource: "https://etherscan.io/address/0xe42c659dc09109566720ea8b2de186c2be7d94d9#code"
    title: Lido WithdrawalQueueERC721 implementation — a request is created without the owner's receiver hook, and a claim pays ETH with a plain call
  - id: s16
    resource: "https://etherscan.io/address/0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84#readContract"
    title: Lido stETH — staking state and the current stake limit, read at block 26126631
  - id: s17
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/FullPolicy.sol#L69-L70"
    title: Kit policy at 370e20a — the operator wraps and unwraps wstETH
  - id: s18
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/FullPolicy.sol#L219-L221"
    title: Kit policy at 370e20a — the emergency role redeems sUSDS and unwraps wstETH
---

# Stonks 2.0 pricing, 2026-10-05

An agent read the Stonks source at the audited commit `0669c4a` and ran every chain read on this page on 2026-10-05. The reads use Ethereum mainnet block 26126631, hash `0x1364e09dc56800192a827d3ca13f3e569936fba3d2785278ce9cd718730119d4`, time 2026-10-05T14:01:59Z [s14].

## How an instance gets a price

- A Stonks 2.0 instance asks its converter for the expected output of an order. The converter asks the oracle router for the prices of the two tokens. The router reads Chainlink's Feed Registry [s1][s3].
- **The converter.** Its router, its anchor (ETH or USD) and its lists of tokens to sell and to buy are set when it is deployed. It has no admin [s1]. The deployed converter factory lets anyone deploy a converter with any lists, on the factory's fixed router [s6][s9].
- **The existing converters.** The factory deployed three on 2026-01-29. All three cover only stETH and LDO [s9].
- **The router.** One router serves every Stonks 2.0 instance, the NEST buyback included. Its admin, Aragon Voting, is fixed at deployment. The admin appoints a manager [s5][s8].
- **What the admin and the manager can do.** They add a token, set the maximum age of its price, turn it on or off, and re-sync it [s2][s5]. Neither of them can choose a feed: the router takes the aggregator from Chainlink's Feed Registry, and it refuses a token that the registry does not list [s3].
- **Re-sync.** If Chainlink replaces the aggregator in its registry, the router refuses that token's price until the admin or the manager re-syncs it [s2][s4].
- **Audit.** Ackee audited every Stonks contract in December 2025 and reviewed the fixes at `0669c4a`. It then verified the deployed router, the converter factory and the converters against that commit [s7]. The converter, the router, the ownership contract and the factory have no later change on the main branch [s1][s3][s5][s6].

## The router today

- Vote 204, executed on 2026-08-10, made the committee's Safe the router's manager [s12].
- On 2026-08-13 the committee's Safe set the ETH/USD bridge with a maximum age of 3,600 seconds, and stETH and LDO, both quoted in ETH with a maximum age of 86,400 seconds [s13]. These ages equal the heartbeats of the Chainlink feeds behind them [s11].
- At the block, stETH, LDO and the bridge are in sync, and no other token is configured [s8].

## Which vault tokens Chainlink's registry covers

| Token | USD feed in the registry | ETH feed in the registry | Heartbeat of the USD feed |
|---|---|---|---|
| stETH | yes | yes, configured | 3,600 s |
| LDO | no | yes, configured | — |
| USDC | yes | yes | 82,800 s |
| USDT | yes | yes | 86,400 s |
| DAI | yes | yes | 3,600 s |
| USDS | yes | no | 82,800 s |
| wstETH | no | no | — |
| WETH | no | no | — |
| sUSDS | no | no | — |

- The registry's aggregators for USDC, USDT, DAI, USDS and ETH/USD are the current aggregators of Chainlink's published feeds [s10][s11].
- Chainlink publishes a calculated wstETH/USD feed on Ethereum, `0x164b276057258d81941e97B0a900D4C7B358bCe0`, but its registry has no wstETH entry. Chainlink publishes no Ethereum price feed for WETH or sUSDS [s10][s11].
- The router can therefore price USDC, USDT, DAI and USDS once they are added. It cannot price wstETH, WETH or sUSDS, whoever configures it, unless Chainlink adds them to its registry [s3][s10].

## How often Chainlink replaced the vault's feeds

- From block 23,500,000 (2025-10-07) to the block, the registry confirmed 40 feed changes. For the vault's tokens, it replaced only the USDC and USDT aggregators, each twice: on 2026-09-16 and on 2026-09-21 [s10].
- With a token configured, each replacement stops that token's pricing until a re-sync [s4]. USDC is the vault's hub ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).

## The WETH route

- Lido staking was open at the block, with a current stake limit of 150,000 stETH [s16].
- The withdrawal queue was not paused. It creates a request for its owner without calling the owner's receiver hook, so a Safe without a fallback handler can own a request. It pays a claim with a plain call that forwards all remaining gas [s15].
- WETH pays out ETH with a transfer that forwards only 2,300 gas. A fork test must show that the Asset Safe accepts it.

## The kit

- The operator wraps and unwraps wstETH [s17]. The emergency role redeems sUSDS and unwraps wstETH [s18].

## How to reproduce

Set `ETH_RPC_URL` in your shell. `cast` reads it from the environment. Never write the URL into a file. Some RPCs limit log ranges; the Etherscan logs API serves the same events.

```sh
B=26126631
R=0x79ef3a538200Fe4981D67E7e886bfb36D4Cb5a31          # oracle router
FR=0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf         # Chainlink Feed Registry
USD=0x0000000000000000000000000000000000000348
ETH=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
cast call $R 'ADMIN()(address)' --block $B
cast call $R 'manager()(address)' --block $B
cast call $R 'tokenConfig(address)((uint128,uint128,address,uint32,uint8),uint32,uint8,uint8,bool)' <token> --block $B
cast call $R 'isFeedInSync(address)(bool)' <token> --block $B
cast call $FR 'getFeed(address,address)(address)' <token> $USD --block $B   # reverts if the registry has no feed
cast call $FR 'getFeed(address,address)(address)' <token> $ETH --block $B
cast call <Chainlink proxy> 'aggregator()(address)' --block $B
cast logs --address $FR "$(cast keccak 'FeedConfirmed(address,address,address,address,uint16,address)')" --from-block 23500000 --to-block $B
cast logs --address 0xD96223670BF73cB191a9F0b526653B7eC99dcf45 "$(cast keccak 'AmountConverterDeployed(address,address,address[],address[],bool)')" --from-block 0 --to-block $B
cast call 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84 'isStakingPaused()(bool)' --block $B
cast call 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84 'getCurrentStakeLimit()(uint256)' --block $B
cast call 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1 'isPaused()(bool)' --block $B
```

## Limits

- Every read describes its block. The manager or Aragon Voting can change the router's settings at any time.
- The heartbeats come from Chainlink's published feed list, read on 2026-10-05.
- The source review covers the functions named above. It is not an audit.
- This page records evidence. EM's decision is in the [decision log](/registers/decision-log.md).
