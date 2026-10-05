---
type: Research Note
title: Easy Track funding registries, 2026-10-02
description: How an Easy Track allowed-recipients registry counts its limit and its period, what the standard top-up factory writes, and which periods, limits and roles the twelve live top-up registries use — the evidence behind OD-06.
tags: [funding, easy-track, registry, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-02
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T11:23:52Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/LimitsChecker.sol#L118-L128"
    title: Easy Track LimitsChecker at 3183d1f — the check at motion start, with the full limit for a motion that ends after the period
  - id: s2
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/LimitsChecker.sol#L132-L168"
    title: Easy Track LimitsChecker at 3183d1f — the spend at enactment, the period reset and the revert above the limit
  - id: s3
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/LimitsChecker.sol#L288-L335"
    title: Easy Track LimitsChecker at 3183d1f — allowed periods and calendar period boundaries
  - id: s4
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/TopUpAllowedRecipients.sol#L77-L103"
    title: Easy Track TopUpAllowedRecipients at 3183d1f — the motion script, its first call and the fixed payment reference
  - id: s5
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/TopUpAllowedRecipients.sol#L124-L160"
    title: Easy Track TopUpAllowedRecipients at 3183d1f — recipient, token and limit checks of a motion
  - id: s6
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/AllowedTokensRegistry.sol#L100-L114"
    title: Easy Track AllowedTokensRegistry at 3183d1f — amounts scaled to 18 decimals
  - id: s7
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/AllowedRecipientsBuilder.sol#L169-L190"
    title: Easy Track AllowedRecipientsBuilder at 3183d1f — the role holders a new registry must have
  - id: s8
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EasyTrack.sol#L183-L184"
    title: Easy Track at 3183d1f — enactment rebuilds the script and requires the stored hash
  - id: s9
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/single-token/TopUpAllowedRecipientsSingleToken.sol#L73-L104"
    title: Easy Track TopUpAllowedRecipientsSingleToken at 3183d1f — the same fixed payment reference
  - id: s10
    resource: "https://etherscan.io/block/26105012"
    title: Ethereum block 26105012, used for every chain read on this page
  - id: s11
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea#readContract"
    title: Easy Track — the registered factories, the motion duration and the objection threshold
  - id: s12
    resource: "https://etherscan.io/block/26125804"
    title: Ethereum block 26125804, used for the re-read of 2026-10-05
  - id: s13
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/AllowedTokensRegistry.sol#L101"
    title: Easy Track AllowedTokensRegistry at 3183d1f — normalizeAmount refuses token 0
---

# Easy Track funding registries, 2026-10-02

An agent read the Easy Track source at `3183d1f` and ran every chain read on this page on 2026-10-02. The reads use Ethereum mainnet block 26105012, hash `0xf2ec35ab8858185d18527a8be6418ac088531032e3b11ca804c10e776b64735c`, time 2026-10-02T13:43:23Z [s10].

## How a registry counts

- **Period.** The period is 1, 2, 3, 6 or 12 calendar months. It starts on the 1st of a month at 00:00 UTC and is aligned to January, so a quarter starts in January, April, July or October [s3].
- **Check at motion start.** The factory checks the motion's total against what is left in the period. If the motion can only be enacted after the period ends, the check uses the full limit [s1][s5].
- **Spend at enactment.** The motion's first call spends the total. It starts a new period if the old one has ended, and it reverts above the limit [s2][s4].
- **Boundary.** So around each period boundary, two full limits can be paid within about 72 hours: one motion enacted before the boundary, and one created in its last 72 hours and enacted after it.
- **Units.** A token registry scales each amount to 18 decimals, and the registry adds the scaled amounts. 1 stETH counts the same as 1 USDC [s6]. One limit therefore cannot hold stablecoins and stETH to a dollar figure.
- **Repeated recipients.** A motion may name the same recipient more than once, and each entry is one Finance payment [s4][s5]. The per-payment ceilings of the payment ACL therefore do not cap a motion.
- **The token registry's interface.** The factory calls only `isTokenAllowed` and `normalizeAmount` on its token registry [s5].
- **Enactment rebuilds the script.** Easy Track rebuilds the script at enactment and requires the stored hash [s8]. The script carries the scaled total [s4], so a scale that changes during the objection window blocks enactment.
- **Who sets the limit.** The standard builder gives the role that sets the limit and the period to the registry's admin alone, and never to the Easy Track executor [s7].
- **Payment reference.** Both versions of the top-up factory write the same fixed reference, "Easy Track: top up recipient" [s4][s9]. A motion cannot put a report's identifier in that field.

## How to reproduce

Set `ETH_RPC_URL` to an Ethereum RPC in your shell. `cast` reads it from the environment. Never write the URL into a file, because it often contains a key.

```sh
B=26105012
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c
cast call $ET 'getEVMScriptFactories()(address[])' --block $B
cast call $FACTORY 'allowedRecipientsRegistry()(address)' --block $B   # each factory
cast call $FACTORY 'finance()(address)' --block $B                     # present on top-up factories only
cast call $FACTORY 'trustedCaller()(address)' --block $B
cast call $REG 'getLimitParameters()(uint256,uint256)' --block $B      # limit, months
cast call $REG 'hasRole(bytes32,address)(bool)' $(cast keccak SET_PARAMETERS_ROLE) $AGENT --block $B
```

## The live top-up registries

Easy Track lists 52 factories. Twelve are top-up factories, and each has its own registry [s11][s10]. Easy Track's motion duration is 259,200 seconds and its objection threshold is 50 basis points [s11].

| Registry | Token | Limit per period | Period, months | Trusted caller is the committee's Safe |
|---|---|---|---|---|
| `0x231Ac69A1A37649C6B06a71Ab32DdD92158C80b8` | LDO | 15,000,000 | 12 | no |
| `0x49d1363016aA899bba09ae972a1BF200dDf8C55F` | stETH | 150 | 12 | no |
| `0x97615f72c3428A393d65A84A3ea6BBD9ad6C0D74` | LDO | 1,000,000 | 3 | no |
| `0x48c4929630099b217136b64089E8543dB0E5163a` | stETH | 8,000 | 6 | no |
| `0x68267f3D310E9f0FF53a37c141c90B738E1133c2` | stablecoins | 18,000,000 | 3 | no |
| `0xdc7300622948a7AdaF339783F6991F9cdDD79776` | stETH | 3,000 | 12 | no |
| `0xDAdC4C36cD8F468A398C25d0D8aaf6A928B47Ab4` | stablecoins | 5,000,000 | 3 | no |
| `0xb0FE4D300334461523D9d61AaD90D0494e1Abb43` | stablecoins | 1,000,000 | 3 | no |
| `0x3B525F4c059F246Ca4aa995D21087204F30c9E2F` | stablecoins | 5,000,000 | 6 | no |
| `0x1a7cFA9EFB4D5BfFDE87B0FaEb1fC65d653868C0` | stETH | 12,000 | 6 | yes |
| `0x3f0534CCcFb952470775C516DC2eff8396B8A368` | stablecoins | 10,000,000 | 3 | yes |
| `0x8d8b35cA51e7808098afF4918C21Ce428c943F89` | stablecoins | 8,000,000 | 6 | no |

- **Periods in use.** Five registries use three months, four use six months and three use twelve months. None uses one or two months [s10].
- **Roles.** On all twelve, the Aragon Agent holds the role that sets the limit and the period, and Aragon Voting and the Easy Track executor do not. The executor holds the role that spends the limit. It can add recipients on four registries, and on none of the other eight, both of the committee's included [s10].
- **The shared stablecoin list.** All six stablecoin top-up factories use the token registry `0x4AC40c34f8992bb1e5E856A448792158022551ca`. It allows DAI, USDT, USDC and sUSDS. Aragon Voting holds its admin role [s10].
- **The committee's recipients.** The committee's two registries pay nine Stonks v1 instances, whose recovery address is the Aragon Agent, and the NEST allocator [s10].

## Other reads

- The Aragon Agent holds 7.877196199769308015 ETH: `cast balance $AGENT --block $B --ether` [s10].
- The Aragon Agent and the committee's Safe `0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647` hold no shares of the current earnETH and earnUSD vaults. On their share managers, `0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4` and `0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981`, `balanceOf` and `sharesOf` return zero for both accounts [s10]. Who holds the legacy positions that the mandate carries over is not known (OD-21).

## Re-read on 2026-10-05

At block 26125804, hash `0x1ecee04c146330422626ea6292efa592d5d1d35e864797dfc987b53fd3a2bf05` [s12]:

- The executor's payment permission on Finance still has 22 parameters, and Aragon Voting still manages it. They decode to the same chain: stETH at most 1,000, DAI 2,000,000, LDO 5,000,000, USDC 2,000,000, USDT 2,000,000, ETH 1,000 and sUSDS 2,000,000 per payment; every other token is refused. The commands are in the [chain-reads note](/research/chain-reads-2026-09-30.md).
- The Aragon Agent holds no USDS, and it holds 693,020 sUSDS: `cast call <token> 'balanceOf(address)(uint256)' $AGENT --block 26125804` [s12].
- The multi-token top-up factory cannot pay ETH, because the token registry refuses token 0 [s13]. The single-token factory takes any token, so an ETH factory is possible, but none of the twelve live registries pays ETH.

## Limits

- Every read describes its block. A vote can change any limit, period or role above.
- The source review covers the functions named above. It is not an audit.
