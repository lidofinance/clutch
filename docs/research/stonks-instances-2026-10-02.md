---
type: Research Note
title: Stonks 2.0 instances, 2026-10-02
description: What the deployed Stonks 2.0 code lets each role do, how an order lives and ends, what the factory fixes, how the earlier instances were funded, and which tokens the deployed price stack can price — the evidence behind OD-05 and OD-18.
tags: [stonks, swaps, cow, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-02
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T13:35:00Z
verified: []
sources:
  - id: s1
    resource: "https://etherscan.io/address/0xb368586CB980895E51e1D82102E63b3F69d3F151#code"
    title: Stonks 2.0 instance, verified source — Stonks.sol, Order.sol, AssetRecoverer.sol, Ownable.sol
  - id: s2
    resource: "https://etherscan.io/address/0x632C0CCDca849eeD780FC685BBa9AbC3c7407Cb2#code"
    title: Stonks 2.0 factory, verified source
  - id: s3
    resource: "https://etherscan.io/address/0x70dA04C5D0f325F5AF1426dE6672BF2424B4593d#code"
    title: Stonks 2.0 amount converter, verified source and allowed-token lists
  - id: s4
    resource: "https://etherscan.io/address/0x79ef3a538200Fe4981D67E7e886bfb36D4Cb5a31#readContract"
    title: Oracle router used by the converter — per-token feed state
  - id: s5
    resource: "https://etherscan.io/block/26104584"
    title: Ethereum block 26104584, used for the role, parameter and pricing reads
  - id: s6
    resource: "https://etherscan.io/address/0x1a7cFA9EFB4D5BfFDE87B0FaEb1fC65d653868C0#readContract"
    title: The committee's stETH top-up registry — allowed recipients, read at block 26104917
  - id: s7
    resource: "https://etherscan.io/address/0xf4F6A03E3dbf0aA22083be80fDD340943d275Ea5#readContract"
    title: Stonks v1 stETH to USDC instance — manager and recovery address, read at block 26104917
---

# Stonks 2.0 instances, 2026-10-02

An agent read the verified source and ran every chain read on this page on 2026-10-02.

## Who can do what on an instance

The source sets three roles [s1].

- **Admin.** Fixed when the instance is deployed. Only the admin sets the manager and the emergency operator.
- **Manager.** Places orders, and recovers tokens from the instance. Recovered tokens always go to the instance's fixed recovery address, `AGENT`, and never to the caller. The admin can do the same.
- **Emergency operator.** Pauses order creation, pauses order signatures, or kills the instance. The admin and the manager can do this too.

Nobody else can place an order. Earlier text in this repository said that anyone can; that was wrong.

## How an order lives and ends

- At creation, the order's minimum output is the oracle quote less the margin, or the manager's own minimum if that is higher. A manager can make an order stricter, never cheaper [s1].
- The order lives for the instance's order duration [s1].
- While it lives, it stays valid only inside two bands around its price. The oracle may rise by at most the maximum improvement, and fall by at most the price tolerance [s1].
- An order may fill in part, if the instance allows partial fills [s1].
- After the order expires, anyone can return its unsold tokens to the instance. The manager, the admin or the emergency operator can also cancel a live order and return its tokens. The order cannot send its sell token anywhere else [s1].
- Bounds checked in the constructor: the duration lies between 1 minute and 1 day. The margin and the price tolerance are at most 1000 basis points. The maximum improvement is at most 1000 basis points, or off [s1].

## What the factory fixes

- Every instance from the factory gets Aragon Voting `0x2e59A20f205bB85a89C53f1936454680651E618e` as admin, and the Aragon Agent `0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c` as recovery address. Both are fixed [s2][s5].
- Anyone can deploy an instance through the factory, and names its manager, tokens, converter, parameters and receiver [s2].
- Changing a manager later therefore needs a DAO vote.

## The live instances

| Instance | Pair | Manager | Duration, margin, tolerance | Maximum improvement | Partial fills |
|---|---|---|---|---|---|
| Stonks 2.0 `0xb368…F151` | stETH to LDO | NEST buyback executor | 1800 s, 110 bp, 550 bp | 1000 bp | on |
| Stonks 2.0 `0x8c59…3042` | stETH to LDO | NEST buyback executor | 1800 s, 110 bp, 550 bp | 1000 bp | on |
| Stonks v1 `0xf4F6…5Ea5` | stETH to USDC | the committee's Safe | 1800 s, 110 bp, 550 bp | — | — |
| Stonks v1 `0x278f…A5C7` | USDC to USDT | the committee's Safe | 1800 s, 30 bp, 150 bp | — | — |

No emergency operator is set on either Stonks 2.0 instance [s5]. The Stonks v1 instances recover to the Aragon Agent and settle to it [s7].

## How the earlier instances were funded

The committee's stETH top-up registry lists the three Stonks v1 stETH instances and the NEST allocator as its allowed recipients [s6]. The treasury funds those instances by the committee's Easy Track motions. Their proceeds and their recovered tokens both return to the treasury, so for them "recover to the Agent" sends tokens back where they came from.

## What the deployed price stack can price

- The deployed converter allows only stETH as a sell token and only LDO as a buy token [s3][s5].
- The oracle router it reads reports feeds in sync for stETH and LDO only. For wstETH, WETH, USDC, USDT, DAI and USDS it has no feed, and a price request reverts [s4][s5].
- As a positive control, the router priced the stETH and LDO pair, and the live instance quoted it at the same block [s5].

## Limits

- Every read describes its block. Governance can add feeds and deploy converters.
- The source review covers the roles and order life above. It is not an audit.
