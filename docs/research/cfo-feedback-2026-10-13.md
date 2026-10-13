---
type: Research Note
title: The committee's feedback of 2026-10-12
description: The evidence behind OD-58 to OD-67 — six points of feedback from the CFO, a member of the committee; Lido's pause-or-disable rule and its emergency bodies; how Easy Track pauses and restarts; the 2026 incidents that bear on emergency powers; the first-loss terms of March 2026; CoW's order life; prices under stress; the quorums of the new emergency Safe; what the new model simplifies; and a drill that shows the switch freezing a queued motion.
tags: [emergency, governance, easy-track, first-loss, orders, prices, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-13
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-13T17:07:39Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's request of 2026-10-13 and EM's answers to cards 1 to 5
  - id: s2
    resource: "urn:clutch:restricted:cfo-feedback-2026-10-12"
    title: The CFO's message to the committee, 2026-10-12; outside the repository
  - id: s3
    resource: "https://etherscan.io/block/26181761"
    title: Ethereum block 26181761, hash 0xb9cb066dd0b626080c48c779cca60b00b4e265d89aabef6607e2515a45fa8d16, 2026-10-13T06:25:23Z, used for every chain read on this page
  - id: s4
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea#code"
    title: Easy Track, verified source — createMotion and enactMotion are whenNotPaused; cancelMotions and cancelAllMotions need CANCEL_ROLE
  - id: s5
    resource: "https://research.lido.fi/t/emergency-brakes-multi-sig-upgrade/2608"
    title: Lido forum — the Emergency Brakes multisig, 2022-07-21; it pauses, and the DAO resumes
  - id: s6
    resource: "https://docs.lido.fi/multisigs/emergency-brakes"
    title: Lido docs — the Emergency Brakes multisigs and the CircuitBreaker committees, read 2026-10-13
  - id: s7
    resource: "https://blog.lido.fi/lido-poolside-recap-tokenholder-update-may-2026/"
    title: Lido tokenholder update, May 2026 — multisigs with protocol roles only pause or disable contracts
  - id: s8
    resource: "https://research.lido.fi/t/circuitbreaker-programmable-panic-layer/11400"
    title: Lido forum — CircuitBreaker, a bounded pause with a heartbeat (LIP-34)
  - id: s9
    resource: "https://github.com/lidofinance/core/blob/60bc9b77b036eec22b2ab8a3a1d49c6b6614c600/contracts/0.8.9/utils/PausableUntil.sol#L51-L52"
    title: Lido PausableUntil — a pause ends by itself when its resume time passes
  - id: s10
    resource: "https://research.lido.fi/t/lido-earn-competing-on-trust-5m-treasury-allocation/11228"
    title: Lido forum — the March 2026 Earn allocation and its first-loss terms
  - id: s11
    resource: "https://research.lido.fi/t/11579"
    title: Lido forum — the review of the Kelp incident, 2026-05-21
  - id: s12
    resource: "https://github.com/cowprotocol/services/blob/a6ae72eb6cd0798057d96ee8875aa92499e8b33e/crates/shared/src/order_validation.rs#L1130-L1133"
    title: CoW services at a6ae72e — no maximum validTo for pre-signed orders
  - id: s13
    resource: "https://github.com/cowprotocol/services/blob/a6ae72eb6cd0798057d96ee8875aa92499e8b33e/crates/configs/src/orderbook/order_validation.rs#L24-L29"
    title: CoW services at a6ae72e — the default maximum order validity of one year, and the default limit on open limit orders per owner
  - id: s14
    resource: /research/cow-orders-account-2026-10-06.md
    title: Research note — the CoW order signer and its validDuration check
  - id: s15
    resource: "https://research.lido.fi/t/security-bulletin-batched-immunefi-reported-weakness-disclosure-march-2026-funds-not-at-risk/11342"
    title: Lido forum — security bulletin of March 2026; a bridge pause and its restart by vote
  - id: s16
    resource: "https://www.chainalysis.com/blog/lessons-from-the-drift-hack/"
    title: Chainalysis — the Drift incident of 2026-04-01; council signers socially engineered into pre-signed transactions
  - id: s17
    resource: "https://www.halborn.com/blog/post/explained-the-resolv-hack-march-2026"
    title: Halborn — the Resolv incident of 2026-03-22
  - id: s18
    resource: "https://cointelegraph.com/news/how-a-2-85-price-error-triggered-27m-in-liquidations-on-aave"
    title: Cointelegraph — wstETH priced 2.85% low on Aave, 2026-03-10
  - id: s19
    resource: "https://api.safe.global/tx-service/eth/api/v1/safes/0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647/multisig-transactions/"
    title: Safe Transaction Service — the committee's Safe, 80 executed transactions from 2024-04-19 to 2026-09-14, read 2026-10-13
  - id: s20
    resource: "https://research.4pillars.io/en/research/reflections-on-the-resolv-protocol-exploit"
    title: Four Pillars — the Resolv exploit; a single report of the time that the pause's signatures took
  - id: s21
    resource: "urn:clutch:restricted:cfo-followup-2026-10-13"
    title: The CFO's follow-up questions and EM's answers in the committee's channel, 2026-10-13; outside the repository
  - id: s22
    resource: "https://github.com/mellow-finance/flexible-vaults/blob/735e085339a5ad6a637e742870a7e1c746554d95/src/managers/BurnableTokenizedShareManager.sol#L9-L15"
    title: Mellow flexible-vaults — the burnable share manager; `burn` burns the caller's own shares
  - id: s23
    resource: "https://github.com/mellow-finance/flexible-vaults/blob/f164438c2d0d5e5d78c52481e7716ee0d174c41b/src/managers/ShareManager.sol#L241"
    title: Mellow flexible-vaults — the plain share manager; `burn` is `onlyQueue`
  - id: s24
    resource: "https://github.com/Se7en-Seas/boring-vault/blob/4538ccf7706290e38b739e939854897c0f81f6de/src/base/BoringVault.sol#L94-L99"
    title: Veda BoringVault — `exit`, the only path to `_burn`, needs an authorised caller
  - id: s25
    resource: "https://github.com/morpho-org/morpho-blue/blob/8f89ede29ec9d2cfa9688aa670346226a3571f06/src/Morpho.sol#L390-L401"
    title: Morpho Blue — a liquidation that leaves bad debt lowers the market's total supply assets
---

# The committee's feedback of 2026-10-12

The CFO, a member of the committee, sent six points of feedback on the design on 2026-10-12 [s2]. EM asked for research first, and then for an interview, one point at a time [s1]. This note holds the research. The decisions are OD-58 to OD-63 [s1].

## The feedback

The CFO finds the architecture scalable for the committee's purposes. Some complexity comes from Easy Track and from the existing monitoring. Less complexity would need weaker mandate rules or more DAO votes, and the CFO proposes neither [s2]. The six points [s2]:

1. Give the Emergency Brakes multisig the right to withdraw funds from any protocol to the Asset Safe or the treasury, as a body that is independent of the committee.
2. Let the Emergency Brakes multisig unpause Easy Track.
3. Let the committee replace the Growth Committee for first-loss burns, without added friction.
4. Let limit orders live longer than 30 days.
5. Report and monitor through the Zodiac UI. A price must never be missing; find it in another source.
6. Remove the emergency Safe. The committee's Safe and the Emergency Brakes multisig handle emergencies.

## Lido's emergency bodies and their rule

- The Emergency Brakes multisig was set up in 2022 to pull one lever: pause. It "isn't meant to have the ability to unpause things"; the DAO resumes [s5].
- Every power that Lido's documentation lists for it pauses or disables something. None moves funds [s6].
- The Emergency Brakes Safe runs Safe v1.3.0 with a threshold of three of five [s3]. Command: `cast call 0x73b047fe6337183A454c5217241D780a932777bD "getThreshold()(uint256)" --block 26181761`.
- Lido's tokenholder update of May 2026 states the rule: multisigs with protocol roles "can only pause or disable contracts, not resume or change them". Pauses are time-limited, and a substantive change needs a full on-chain vote [s7].
- The CircuitBreaker follows the rule. A committee only pauses an assigned contract, for a bounded time: 21 days by default, within bounds of 5 to 60 days. It loses the power if it sends no heartbeat within 365 days by default [s8].
- Lido's answer to restart friction is a pause that ends by itself: `isPaused()` is `block.timestamp < resumeSince` [s9]. Easy Track's pause has no end time [s4].

## Easy Track: who pauses, who restarts

Read at block 26181761 [s3], with `cast call 0xF0211b7660680B49De1A7E9f25C65660F0a13Fea "hasRole(bytes32,address)(bool)" $(cast keccak <ROLE>) <holder> --block 26181761`:

| Holder | `PAUSE_ROLE` | `UNPAUSE_ROLE` | `CANCEL_ROLE` |
|---|---|---|---|
| Emergency Brakes multisig `0x73b047fe6337183A454c5217241D780a932777bD` | yes | no | no |
| Aragon Voting `0x2e59A20f205bB85a89C53f1936454680651E618e` | yes | yes | yes |
| Aragon Agent `0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c` | no | no | no |

- `paused()` is false, and the motion duration is 259,200 seconds [s3].
- A pause stops `createMotion` and `enactMotion` for every Easy Track motion of the DAO, not only the vault's. An objection and a creator's own cancel still work [s4].
- A motion does not expire. After an unpause, a queued motion whose window has ended can enact at once, unless someone cancels it first. Only a holder of `CANCEL_ROLE`, Aragon Voting, cancels another party's motion [s4].
- Aragon Voting holds the Easy Track roles itself, so a vote item that unpauses or cancels runs when the vote runs: five days. An item that has the Aragon Agent act also passes Dual Governance, about nine days.
- A restart takes long in practice. Bridge deposits that the Emergency Brakes multisig paused on 2026-03-03 came back with a vote and a Dual Governance proposal in mid-April, after the code fix [s15].

## 2026 incidents that bear on emergency powers

- Resolv, 2026-03-22: a key compromise with no mint cap [s17]. One report says that collecting four signatures for the pause took about an hour [s20].
- Drift, 2026-04-01: council signers were socially engineered into pre-signed transactions, under a governance with no timelock; about $285 million left [s16]. A low threshold did not fail here; the signers did.
- Kelp, 2026-04-18: the Lido Earn team learned of the exploit from an outside signal 78 minutes after it, and paused deposits after about three hours. The curator froze earnETH for 27 days, so no one could exit in that time [s11].
- Lesson for the vault: an emergency power is safest when its destinations are fixed and it cannot restore what it stopped. An exit can wait on a curator's freeze.

## The committee's signing speed

The committee's Safe executed 80 routine transactions from 2024-04-19 to 2026-09-14, without paging [s19]. Minutes from the first signature:

| Signature | median | under 1 hour | under 6 hours |
|---|---|---|---|
| 2nd | 8 | 64 of 80 | 70 of 80 |
| 4th | 16 | 45 of 80 | 60 of 80 |

No such data exists for a group that mixes members of different bodies. The first drill measures it.

## The first-loss terms

- After a loss of at least 1% that the curators confirm, the Earn team may instruct the executing committee to burn up to all of the DAO's shares in that vault. On a confirmed material risk, it may instruct a withdrawal through the vault's normal redemption. No vote is needed. An incident update is due within seven days, and the DAO may change or end the authorisation at any time. The burn decision must be documented in the incident update, but "execution may precede posting if time-sensitive" [s10].
- After the Kelp incident the loss stayed below 1%. A Snapshot approved a one-time exception, and the burn ran on 2026-05-15 as one `burn` call [s11].
- Lido's review says that the activation criteria and the roles of the curators and the DAO "will be formalized before the next incident" [s11].
- Under OD-42, every burn or redemption was a DAO vote through Dual Governance: about nine days, plus a slot in an omnibus vote. That is slower than the terms that the mandate takes over.

## Order life

- CoW's order book sets no maximum `validTo` for pre-signed orders, and a default of one year for other orders [s12][s13]. So the vault's bound is its own.
- The order signer refuses an order whose `validTo` lies beyond its `validDuration`, so the policy can pin the order life [s14].
- A resting order is a standing authorisation. It keeps acting after its context changes, and a fill does not consult the policy. A revoke does not cancel it.

## Prices under stress

- A single source can be wrong, not only missing. On 2026-03-10 an oracle priced wstETH 2.85% low on Aave for hours [s18].
- Fair-value practice names a principal market and a hierarchy of inputs: quoted prices, then observable inputs, then model inputs, under a written valuation policy.

## The new emergency Safe: quorums

Five seats: two committee members (C), two Emergency Brakes members (B) and one member of neither body (N). Three signatures act. Of the ten possible quorums:

- Each one has a signer from outside the committee and a signer from outside the Emergency Brakes multisig.
- Only {B, B, N} has no committee member. So a path that overrules the committee exists, and it needs both Emergency Brakes members and the fifth signer.
- Only {C, C, N} has no Emergency Brakes member.
- Two stolen committee keys reach nothing.

## What the model simplifies

- One role key, not two. The technical role had one permission, `disableModule` pinned to the operator modifier, and now has the same holder as the emergency role. It merges into `emergency` (OD-58).
- The orders account's membership removal (OD-57) is redundant. The same holder already revokes the operator's targets and functions there.
- The cap-breach trigger stops being a limit, because the emergency role can revoke everything at any time. It stays a duty.
- The mandate and the LIP no longer need to say that the fast exit is not independent of the committee.
- One emergency pager: the cap-breach trigger, a defect in the permission layer and a financial emergency all page the emergency Safe.
- The duty to keep the emergency Safe's owners equal to the committee's goes. A seat rule replaces it.
- The Emergency Brakes multisig's own mandate does not change, so it needs no Snapshot.

It does not simplify the two modifiers on the Asset Safe, because recovery must survive the switch, or the granular revoke, because every removal is a revoke.

## The switch freezes queued motions

The drill `test_D4_the_switch_freezes_queued_motions_until_the_dao_restarts` ran on the pinned fork on 2026-10-13 and passed. A motion that writes through the governance role is queued. The emergency role disables the operator modifier. After the objection window, the enactment reverts with the Safe's `GS104`, while the emergency role's transfer to the Agent still works. The owner path enables the modifier again, and the same motion then enacts. So a restart must cancel the queued motions first.

## Follow-up: insurance funds for other products

On 2026-10-13 the CFO asked whether the vault can manage more insurance funds, for other products too (OD-66) [s21]. A first-loss fund needs a way for the DAO's position to take a loss before other depositors. Each product's contracts decide that way.

| Product contracts | How a holder's position can take a loss | Template that fits |
|---|---|---|
| A Mellow vault with the burnable share manager, as Lido Earn uses | `burn(uint256)` burns the caller's own shares [s22] | burnable shares |
| A Mellow vault with the plain share manager | only a queue can burn shares [s23] | none, unless the product gives a payout address |
| A Veda vault | only an authorised caller can burn shares, through `exit` [s24] | none, unless the product gives a payout address |
| A Morpho Blue market, the base of Lido Lend | a liquidation that leaves bad debt lowers the market's supply assets, so every lender of that market takes the loss [s25] | none, unless the product gives a payout address, for example a reserve that covers bad debt |
| A product on another chain | its shares are on that chain | none: the first-loss Safe is on Ethereum |

So the burnable-shares template serves the Lido Earn family. Any other product needs a fixed payout address that its own design defines, or a new template. A new template needs a factory that the DAO registers by vote, once for each kind of product.

## Open after the decisions

- The fifth signer: who, on what terms, and the Snapshot that appoints them (OD-65).
- Insurance funds for products other than Lido Earn (OD-66).
- The committee's valuation policy: the band of level 2 and the level-5 share (OD-62).
- The policy provider's answer on display and monitoring in the Zodiac UI (OD-44, OD-62).
