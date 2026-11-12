---
type: Research Note
title: The enabling vote rehearsed on a mainnet fork, 2026-10-15
description: The enabling vote built and run end to end on forks of blocks 26196400 (2026-10-15) and 26249900 (2026-10-22) with the live Aragon Voting, ACL, Finance, Easy Track and its executor — why the policy cannot travel inside the vote under EIP-7825, the vote of approved hashes, Easy Track's shared motion limit and what works with the live contracts; the evidence behind OD-92 and OD-94.
tags: [governance, enabling-vote, easy-track, ramp-up, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-22
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:50:32Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/clutch/blob/f0a0dede114033162082cc57b0b523974389a1ab/test/EnablingVoteRehearsal.t.sol"
    title: The rehearsal at f0a0ded — test/EnablingVoteRehearsal.t.sol and test/rehearsal/, run on 2026-10-15 on a fork of block 26196400, and again on 2026-10-22 on a fork of block 26249900
  - id: s3
    resource: "https://eips.ethereum.org/EIPS/eip-7825"
    title: EIP-7825 (Final) — a protocol cap of 16,777,216 (2^24) gas per transaction
  - id: s4
    resource: "https://blog.ethereum.org/2025/11/06/fusaka-mainnet-announcement"
    title: Ethereum Foundation — Fusaka activates on mainnet at epoch 411392, 2025-12-03 21:49:11 UTC, with EIP-7825
  - id: s5
    resource: "https://etherscan.io/address/0xf165148978Fa3cE74d76043f833463c340CFB704#code"
    title: Aragon Voting implementation — `_newVote` stores the script (contracts/Voting.sol line 574) and `_executeVote` runs it in one call (line 635)
  - id: s6
    resource: "https://github.com/ethereum/go-ethereum/blob/87e144d2374b638e9565235e06d602a54ff033b3/core/txpool/legacypool/legacypool.go#L46-L56"
    title: go-ethereum — the txpool refuses a transaction above 128 KiB
  - id: s7
    resource: "https://github.com/paradigmxyz/reth/blob/c10d16f9b7556e1e3e05f3114c240e45a0109dd6/crates/transaction-pool/src/validate/constants.rs#L7-L12"
    title: reth — the txpool's default maximum transaction input is 128 KiB
  - id: s8
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L380-L384"
    title: Safe v1.5.0 — `approveHash` records an owner's approval of a transaction hash
  - id: s9
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L323-L328"
    title: Safe v1.5.0 — a type-1 signature is valid when the owner approved the hash
  - id: s10
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L182-L190"
    title: Safe v1.5.0 — with safeTxGas and gasPrice zero, a failed call reverts the whole transaction
  - id: s15
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea#code"
    title: Easy Track — the open-motion limit, its maximum of 24, the admin role that sets it, and the script hash checked at enactment
  - id: s16
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea#events"
    title: Easy Track events to block 26196400 — every motion created, enacted, canceled or rejected, and the two limit changes
  - id: s17
    resource: "https://etherscan.io/address/0x000000000c139266ba06170ed1deaca6d11903c1#code"
    title: Lido Earn RedeemQueue implementation — `redeem` locks the caller's shares; `claim` pays the caller's requests to any receiver
  - id: s18
    resource: "https://etherscan.io/address/0x00000006da9f179bfe250dd1c51cd2d3581930c8#code"
    title: Lido Earn DepositQueue implementation — the depositor check and one pending request per account
  - id: s19
    resource: "https://etherscan.io/address/0x0000000714cf2851bac1ae2f41871862e9d216fd#code"
    title: Lido Earn RiskManager implementation — the vault limit that a deposit request must stay under
  - id: s27
    resource: "https://etherscan.io/address/0x29e23b1ef0c9fffac8330f9abacebddd827e4b5c#code"
    title: The Easy Track factory AllowConsolidationPair
  - id: s28
    resource: "https://etherscan.io/address/0x2e59A20f205bB85a89C53f1936454680651E618e#readProxyContract"
    title: Aragon Voting — voteTime 432000 and objectionPhaseTime 172800, read at block 26196400
---

# The enabling vote rehearsed on a mainnet fork, 2026-10-15

On 2026-10-15 EM asked for the enabling vote built and run end to end on a mainnet fork. An agent wrote the rehearsal and ran it on 2026-10-15, and again on 2026-10-22 [s1]. This note records what ran and what it measured. The rehearsed vote also carried funding registries, top-up factories and USDS items; OD-106 removed them from the design, and this note keeps only the evidence that stands without them.

## Answer

- A vote with the Safe batches inside cannot start. Aragon Voting stores the whole script when a vote starts [s5], and that transaction needs 37,606,772 gas. Since 2025-12-03, EIP-7825 caps a transaction on mainnet at 16,777,216 gas [s3][s4][s1].
- A vote of approved hashes fits: Voting approves the hash of each Safe batch, and anyone executes the batches after the vote [s8][s9].
- Easy Track's limit of 20 open motions is shared by every committee. On 2026-09-09, 18 motions were open [s15][s16].

## What ran

The rehearsal first ran on 2026-10-15 on a fork of block 26196400. It ran again on 2026-10-22 on a fork of block 26249900, after OD-89 to OD-91 [s1]. This note reports the second run. These live contracts take part: Aragon Voting, the LDO token manager, the ACL, Aragon Finance with the Agent's balances, Easy Track and its script executor, the committee's Safe, the Growth Committee's Safe, CoW's contracts and the Lido Earn queues. The four Clutch Safes on Safe v1.5.0 and the four Roles modifiers are new. They are deterministic proxies, so the policy compiles before they exist.

| Test | What it shows |
|---|---|
| `test_00` | The policy's manifest matches the deterministic addresses. |
| `test_01` | A vote with the Safe batches inside cannot start. |
| `test_02` | The vote that fits, end to end, and the state after it. |
| `test_03` | The first weeks: the first-loss move, a budget motion, the switch. |
| `test_04` | Earn deposits from the new Asset Safe. |
| `test_05` | A first-loss burn, and a redemption request by the committee's role. |

These tests, and `test_06` and `test_07` on the removed payment and USDS items, passed in both runs: 8 of 8 [s1]. Foundry does not apply EIP-7825. So the rehearsal sends each governance transaction with the cap less its intrinsic gas, after it cools every account that the transaction touches. The gas that this note reports is the execution gas plus the standard intrinsic gas of the calldata.

The policy is the repository's constellation of that date, compiled for the fork: 97 calls and 3 budget keys. The orders and first-loss policies were not built, so the vote only enabled their modifiers and assigned their roles. The first run's policy had 99 calls: OD-91 then took LDO off the launch list [s1]. At block 26249900, 1 Easy Track motion was open [s1].

## The vote that fits

The rehearsed vote had 10 items. Items 1 to 7 registered the top-up factories and the stand-in budget factory and added USDS to the payment paths; the current design has none of them (OD-102, OD-106). Items 8 to 10 approve the Safe batches:

| # | Target | Call | Note |
|---|---|---|---|
| 8 | Asset Safe | `approveHash`: batch 1 | 2 `enableModule` calls and the 97 policy calls |
| 9 | Orders account | `approveHash`: batch 2 | CoW's fallback handler, ComposableCoW as domain verifier, the modifier, 2 roles, 6 relayer approvals |
| 10 | First-loss Safe | `approveHash`: batch 3 | the modifier and its 2 roles |

| Transaction | Gas | Bytes |
|---|---|---|
| Start the vote, 10 items | 1,620,020 | 2,212 |
| Execute the vote, 10 items | 1,369,025 | — |
| Batch 1, Asset Safe, 99 calls | 6,304,514 | 60,292 |
| Batch 2, orders account, 11 calls | 472,489 | 2,532 |
| Batch 3, first-loss Safe, 3 calls | 213,401 | 1,348 |
| Start a vote with the batches inside | 37,606,772 | 66,276 |

The cap is 16,777,216 gas per transaction [s3]. The txpools of geth and reth refuse a transaction above 131,072 bytes [s6][s7]. A vote has 3 days of main phase, then 2 days of objection phase: `voteTime` is 432,000 seconds and `objectionPhaseTime` is 172,800 [s28].

## Findings

Findings 2 to 5 concerned the funding registries, the shared token list and the executor's payment permission, which OD-106 removed from the vote. [ADR 005](/adr/005-account-graph-and-roles.md) decision 32 and its proposed direction hold finding 8: the vote shows hashes, so the batches are published with it.

### 1. The policy cannot travel inside the vote

- Aragon Voting copies the script into storage in `_newVote` and runs it in `_executeVote` [s5]. The cost of the copy grows with the script.
- With the three batches as direct `execTransaction` items, the script is 66,012 bytes. The transaction that starts the vote is 66,276 bytes, which the txpool accepts [s6][s7], and it needs 37,606,772 gas, which no block can include [s3][s1].
- Safe v1.5.0 accepts an owner's approved hash as the owner's signature [s8][s9]. After the vote executes, anyone sends each batch with that signature. Each batch hash includes the Safe's nonce, so the batches of one Safe run in order.
- Batch 1 uses 38% of the gas cap and 46% of the size limit with 97 policy calls [s1]. The launch policy is larger, so the batch builder must split by gas and by size. The rehearsal's builder starts a new batch at 12,000,000 gas of measured calls.

### 6. Easy Track's limit of open motions is shared, and it was nearly full

- At most 20 motions can be open at once. At the limit, `createMotion` reverts with `MOTIONS_LIMIT_REACHED`. The code allows at most 24, and only the admin role, which Voting holds, changes the limit [s15].
- A motion stays open until someone enacts, cancels or rejects it, so a motion that waits for enactment also holds a slot [s15].
- Up to block 26196400, Easy Track has had 1,202 motions [s16]:
  - In the last 365 days, 30 factories created 329 motions. September 2026 had the most new motions of any month: 63.
  - The peak was 18 open motions on 2026-09-09. 16 of them came from the AllowConsolidationPair factory [s16][s27].
  - In the last 365 days, 10 or more motions were open 6.7% of the time, and 15 or more were open 2.9% of the time.
  - The open count reached the limit 7 times in 2022 and 2023, when the limit was 12. The limit became 20 on 2023-05-26.

### 7. A budget factory must build the same script at creation and at enactment

- Easy Track builds the script again at enactment and requires the same hash [s15]. So a factory cannot write the current time, or read state that can change during the 72 hours.
- The rehearsal's motion passed a timestamp of 0 to `setAllowance`, and the modifier stored the enactment time [s1]. So such a motion starts the key's refill period again at enactment.

### 9. A batch that cannot run blocks its Safe until another vote

- A batch with `safeTxGas` and `gasPrice` of zero reverts in full when a call in it fails, so the Safe's nonce does not change and the batch can run again [s10].
- A batch that can never run blocks the later batches of the same Safe, and only a new vote can approve a replacement. A paused or upgraded token can stop a batch: the batches hold token approvals.

### 10. Earn deposits: one open request per queue, and limits that others set

- A Safe has at most one pending deposit request in each queue. A second deposit reverts until an oracle report makes the first one claimable [s18].
- At block 26196400, neither Earn vault had a vault limit: the limit is the largest int256 [s19]. The depositor check admitted the new Safe [s18][s1], and the deposits passed again at block 26249900. The holders of the vaults' roles can set a limit or a depositor list.
- `redeem` locks the caller's shares, and `claim` pays the caller's requests to any receiver [s17]. So the first-loss role's permission can pin the receiver of a redemption ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 21). The rehearsal requested a redemption but did not claim it, because a claim needs an oracle report.

## What works with the live contracts

- The emergency Safe disables the operator modifier, and the next operator call fails with `GS104` [s1].
- The orders account takes CoW's fallback handler and ComposableCoW as the verifier of CoW's settlement domain on Safe v1.5.0, and the relayer approvals [s1].
- The Growth Committee's Safe moves both first-loss share balances by plain transfer. The `first-loss-burn` role burns earnETH shares. The committee's Safe requests an earnUSD redemption through the `first-loss` role [s1].
- The new Asset Safe deposits USDC into earnUSD and wstETH into earnETH [s1].

## Limits of this rehearsal

- The policy is the repository's dry-run constellation, not the launch policy, and the figures are test values.
- The `test_05` probe gave the first-loss modifier two permissions through the owner path, not through a policy.
- The proposer's LDO came from the Agent on the fork, and that one voter passed the vote.
- No Earn oracle report ran, so no deposit or redemption was claimed.
- The history of finding 6 is from the first run and was not fetched again.

## How to reproduce

Check out commit `f0a0ded` [s1], and set `RPC` to an archive Ethereum RPC in your shell. Never write the URL into a file. Then:

```sh
forge test --match-contract EnablingVoteRehearsal -vv
cd policy/constellation && bun compiler/compile.ts --manifest manifests/rehearsal-26249900.json --check
```

The lines that start with `REHEARSAL` are the measurements in this note. `REHEARSAL_WRITE_MANIFEST=true` makes `test_00` write `./rehearsal-manifest.json`; move it to `policy/constellation/manifests/` before you compile.

Chain reads at block 26196400, with `ETH_RPC_URL` set:

```sh
B=26196400
Z=0x0000000000000000000000000000000000000000000000000000000000000000
V=0x2e59A20f205bB85a89C53f1936454680651E618e     # Aragon Voting
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea    # Easy Track

cast call $V 'voteTime()(uint64)' --block $B                 # 432000
cast call $V 'objectionPhaseTime()(uint64)' --block $B       # 172800
cast call $ET 'motionDuration()(uint256)' --block $B         # 259200
cast call $ET 'motionsCountLimit()(uint256)' --block $B      # 20
cast call $ET 'MAX_MOTIONS_LIMIT()(uint256)' --block $B      # 24
cast call $ET 'hasRole(bytes32,address)(bool)' $Z $V --block $B   # true

# finding 10: the Earn vault limits, (balance, limit)
cast call 0x7b1e06C46d4510277FC37a37bBeF65F3794fdDE4 'vaultState()((int256,int256))' --block $B   # earnUSD
cast call 0xa2a4C4ecE27229aF51c546844AB752824Ccb557e 'vaultState()((int256,int256))' --block $B   # earnETH
```

The counts of finding 6: fetch every Easy Track log up to block 26196400 with these first topics, through Etherscan's `getLogs` [s16]:

| Event | Topic 0 |
|---|---|
| `MotionCreated(uint256,address,address,bytes,bytes)` | `0x2775db1f1f2dd97c60ba2903b3ca235c9cecb3cb47a9cb464f86578b9877f4a4` |
| `MotionEnacted(uint256)` | `0xd4fbbd7bf63590ce72807eb770b83aaf2f3a7958a4b2093fd9ab89b276096942` |
| `MotionCanceled(uint256)` | `0x801fcb98a9fa2e695209772f0a24f3f7ac36f6568659ae2e0cd7763fb73f2862` |
| `MotionRejected(uint256)` | `0x6a4120e111f0bfb3586b7dc9317f9ae5441ce866d1ad9d221ce6d76431f84426` |
| `MotionsCountLimitChanged(uint256)` | `0x5e368703b7ab35fe9ef4dbc482cd414476841204c7484b8e834d0d3ac4ed8672` |

Sort the logs by block and log index. The open count goes up by one at each `MotionCreated`, and down by one at each `MotionEnacted`, `MotionCanceled` or `MotionRejected`. On 2026-10-15 the query returned 1,202 created, 1,197 enacted, 5 canceled and none rejected; the motion IDs run from 1 to 1,202 without a gap.
