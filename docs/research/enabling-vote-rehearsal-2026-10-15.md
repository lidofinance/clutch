---
type: Research Note
title: The enabling vote rehearsed on a mainnet fork, 2026-10-15
description: The enabling vote built and run end to end on forks of blocks 26196400 (2026-10-15) and 26249900 (2026-10-22) with the live Aragon Voting, ACL, Finance, Easy Track and its executor — why the policy cannot travel inside the vote under EIP-7825, the vote that fits, nine more findings, what works with the live contracts, the ramp-up after the vote and what makes it hard; the evidence behind OD-92 to OD-94.
tags: [governance, enabling-vote, easy-track, ramp-up, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-22
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-22T18:44:46Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/clutch/blob/main/test/EnablingVoteRehearsal.t.sol"
    title: The rehearsal — test/EnablingVoteRehearsal.t.sol and test/rehearsal/, run on 2026-10-15 on a fork of block 26196400, and again on 2026-10-22 on a fork of block 26249900
  - id: s2
    resource: /specs/enabling-vote.md
    title: The enabling vote — the specified items, deployments and checks
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
  - id: s11
    resource: "https://etherscan.io/address/0x334D6eDc13F63728b39e6A6D04A7Bbd5D6A9B9FF#code"
    title: Easy Track's AllowedRecipientsBuilder — `admin` is fixed at construction and holds every registry role it grants; admin() of both live builders is the Aragon Agent at block 26196400
  - id: s12
    resource: "https://etherscan.io/address/0x4AC40c34f8992bb1e5E856A448792158022551ca#readContract"
    title: The shared stablecoin token list — Voting holds the admin role and not the add-token role, read at block 26196400
  - id: s13
    resource: "https://etherscan.io/address/0x9f3b9198911054B122fDb865f8A5Ac516201c339#code"
    title: Aragon ACL implementation — `grantPermissionP` sets the params without a check of the existing permission
  - id: s14
    resource: "https://etherscan.io/address/0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb#events"
    title: ACL events — SetPermissionParams for the executor's CREATE_PAYMENTS_ROLE on Finance on 2022-02-18, 2022-12-09, 2024-01-26 and 2025-12-20
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
  - id: s20
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the registries, the period boundary, the seed and the first-loss roles
  - id: s21
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — budget events, the budget factory and the top-up window
  - id: s22
    resource: /research/dai-usds-conversion-2026-10-05.md
    title: DAI and the DAI–USDS converter, 2026-10-05 — the Agent holds no USDS
  - id: s23
    resource: /research/legacy-investments-2026-10-05.md
    title: Legacy investments, 2026-10-05 — the Growth Committee Safe and the first-loss shares
  - id: s24
    resource: "https://github.com/lidofinance/clutch/blob/main/ROADMAP.md"
    title: Roadmap — the gates of the build and of the enabling vote
  - id: s25
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — the launch cap and the conditions of its lift
  - id: s26
    resource: /adr/011-launch-scope.md
    title: ADR 011 — what each launch asset does
  - id: s27
    resource: "https://etherscan.io/address/0x29e23b1ef0c9fffac8330f9abacebddd827e4b5c#code"
    title: The Easy Track factory AllowConsolidationPair
  - id: s28
    resource: "https://etherscan.io/address/0x2e59A20f205bB85a89C53f1936454680651E618e#readProxyContract"
    title: Aragon Voting — voteTime 432000 and objectionPhaseTime 172800, read at block 26196400
  - id: s29
    resource: /registers/parameters.md
    title: Parameters — the orders budget keys and the spare budget keys
---

# The enabling vote rehearsed on a mainnet fork, 2026-10-15

On 2026-10-15 EM asked for three things: build the enabling vote and run it end to end on a mainnet fork, find the issues that the design has not found yet, and make a ramp-up plan that names every obstacle. An agent wrote the rehearsal and ran it on 2026-10-15 [s1]. This note records what ran, what it found and the plan.

## Answer

- The vote that the spec describes cannot start. Aragon Voting stores the whole script when a vote starts [s5]. With the Safe batches inside, that transaction needs 37,606,772 gas. Since 2025-12-03, EIP-7825 caps a transaction on mainnet at 16,777,216 gas [s3][s4][s1].
- A vote that fits has 10 items. Voting approves the hash of each Safe batch, and anyone executes the batches after the vote [s8][s9]. The vote starts with 1,620,020 gas and executes with 1,369,025 gas. The largest batch uses 6,304,514 gas and 60,292 bytes [s1].
- The specified deployment and vote have two more defects. The standard registry builders make the Aragon Agent the admin, not Voting [s11]. Voting cannot add USDS to the shared token list until it takes the add-token role [s12][s1].
- The four USDS items fund nothing at launch, because the Agent holds no USDS [s22][s1]. A vote without them has 6 items, and the vault still gets USDS: a DAI top-up, Sky's converter and Sky savings ran after that vote [s1].
- The payment rewrite changes only USDS. The live ACL gave the same answer to 100 of 108 questions before and after the vote, and the 8 changes are USDS payments [s1]. But the rewrite overwrites a permission that every committee's top-ups use, and four earlier votes rewrote it [s13][s14].
- Easy Track's limit of 20 open motions is shared by every committee. On 2026-09-09, 18 motions were open, 16 of them for validator consolidations [s15][s16][s27].
- The rest works with the live contracts: the factory registrations, the top-ups, a budget motion through the governance role, the switch, the orders account's CoW setup, Earn deposits from the new Safe, a first-loss burn through the executor's role and a first-loss redemption request [s1].
- The seed can arrive 8 days after the vote starts, at the earliest [s28][s15]. Then the cap of OD-55 holds the vault until the lift. Each registry pays at most one mandate size a month, as a backstop, and after the seed a top-up needs the mandate's published eligibility conditions (OD-89) [s20][s25]. "What makes ramping up hard" lists every obstacle found.
- OD-92 to OD-94 ask EM to decide the vote's method, the USDS items and the answer to the motion limit.

## What ran

The rehearsal first ran on 2026-10-15 on a fork of block 26196400. It ran again on 2026-10-22 on a fork of block 26249900, after OD-89 to OD-91 [s1]. This note reports the second run. These live contracts take part: Aragon Voting, the LDO token manager, the ACL, Aragon Finance with the Agent's balances, Easy Track and its script executor, the shared stablecoin token list, the registry factories, the committee's Safe, the Growth Committee's Safe, CoW's contracts and the Lido Earn queues. These contracts are new: the four Clutch Safes on Safe v1.5.0, the four Roles modifiers, the two funding registries, the two top-up factories and a stand-in budget factory. The Safes and modifiers are deterministic proxies, so the policy compiles before they exist.

| Test | What it shows |
|---|---|
| `test_00` | The policy's manifest matches the deterministic addresses. |
| `test_01` | A vote with the Safe batches inside cannot start. |
| `test_02` | The vote that fits, end to end, and the state after it, with the registries' roles. |
| `test_03` | The first weeks: the first-loss move, the seed, top-ups, a budget motion, the switch. |
| `test_04` | Earn deposits from the new Asset Safe. |
| `test_05` | A first-loss burn by the executor's role, and a redemption request by the committee's role. |
| `test_06` | The payment rewrite changes only USDS. |
| `test_07` | USDS reaches the vault after a vote without the USDS items. |

All eight tests passed in both runs, and the rest of the fork suite still passed. Foundry does not apply EIP-7825. So the rehearsal sends each governance transaction with the cap less its intrinsic gas, after it cools every account that the transaction touches. The gas that this note reports is the execution gas plus the standard intrinsic gas of the calldata.

Figures marked `STANDIN` in the tests are test values. The policy is the repository's current constellation, compiled for the fork: 97 calls, 3 budget keys, and the operator, governance and emergency roles. The budget factory is a stand-in that bounds nothing. The orders and first-loss policies are not built, so the vote only enables their modifiers and assigns their roles.

The second run differs from the first only where OD-91 changed the design. LDO left the launch list, so the policy lost LDO's target and its `transfer` to the Agent, and the orders account lost LDO's relayer approval [s1].

| Measure | 2026-10-15, block 26196400 | 2026-10-22, block 26249900 |
|---|---|---|
| Tests passed | 8 of 8 | 8 of 8 |
| Policy calls | 99 | 97 |
| Batch 1: calls, gas, bytes | 101; 6,391,128; 61,124 | 99; 6,304,514; 60,292 |
| Batch 2: calls, gas, bytes | 12; 514,515; 2,692 | 11; 472,489; 2,532 |
| Start the vote, 10 items: gas | 1,620,008 | 1,620,020 |
| Start a vote with the batches inside: gas, bytes | 38,203,119; 67,268 | 37,606,772; 66,276 |
| The Agent's USDS | 0 | 0 |
| Params of the shared payment permission | 22 | 22 |
| Open Easy Track motions at the fork block | not recorded | 1 |

## The vote that fits

| # | Target | Call | Note |
|---|---|---|---|
| 1 | Easy Track | `addEVMScriptFactory`: the stablecoin top-up factory | permissions: the registry's `updateSpentAmount`, Finance's `newImmediatePayment` |
| 2 | Easy Track | `addEVMScriptFactory`: the stETH top-up factory | the same two permissions |
| 3 | Easy Track | `addEVMScriptFactory`: the budget factory | permission: the operator modifier's `execTransactionWithRole`; a stand-in |
| 4 | ACL | `grantPermissionP`: the executor's payment permission, 25 params | adds USDS, at most 2,000,000 per payment (OD-11, OD-24) |
| 5 | Token list | `grantRole`: the add-token role to Voting | finding 3 |
| 6 | Token list | `addToken(USDS)` | |
| 7 | Token list | `renounceRole`: Voting gives the add-token role up | finding 3 |
| 8 | Asset Safe | `approveHash`: batch 1 | 2 `enableModule` calls and the 97 policy calls |
| 9 | Orders account | `approveHash`: batch 2 | CoW's fallback handler, ComposableCoW as domain verifier, the modifier, 2 roles, 6 relayer approvals |
| 10 | First-loss Safe | `approveHash`: batch 3 | the modifier and its 2 roles |

| Transaction | Gas | Bytes |
|---|---|---|
| Start the vote, 10 items | 1,620,020 | 2,212 |
| Execute the vote, 10 items | 1,369,025 | — |
| Start the vote, 6 items without USDS | 757,151 | 996 |
| Execute the vote, 6 items without USDS | 541,652 | — |
| Batch 1, Asset Safe, 99 calls | 6,304,514 | 60,292 |
| Batch 2, orders account, 11 calls | 472,489 | 2,532 |
| Batch 3, first-loss Safe, 3 calls | 213,401 | 1,348 |
| Start a vote with the batches inside | 37,606,772 | 66,276 |

The cap is 16,777,216 gas per transaction [s3]. The txpools of geth and reth refuse a transaction above 131,072 bytes [s6][s7]. The rehearsal measured all 10 items [s1].

## Findings

### 1. The policy cannot travel inside the vote

- Aragon Voting copies the script into storage in `_newVote` and runs it in `_executeVote` [s5]. The cost of the copy grows with the script.
- With the three batches as direct `execTransaction` items, the script is 66,012 bytes. The transaction that starts the vote is 66,276 bytes, which the txpool accepts [s6][s7], and it needs 37,606,772 gas, which no block can include [s3][s1].
- So the spec's "Aragon Voting runs every item itself" cannot hold for the policy [s2].
- The vote that fits approves one hash for each batch. Safe v1.5.0 accepts an owner's approved hash as the owner's signature [s8][s9]. After the vote executes, anyone sends each batch with that signature. Each batch hash includes the Safe's nonce, so the batches of one Safe run in order.
- Batch 1 uses 38% of the gas cap and 46% of the size limit with 97 policy calls [s1]. The launch policy is larger: it adds every budget key with its ceiling, the Lido Lend key, the spare keys, one orders key for each listed token and the exit-governance role [s2][s29]. The batch builder must split by gas and by size. The rehearsal's builder starts a new batch at 12,000,000 gas of measured calls.

### 2. The standard builders cannot make Voting the registries' admin

- An AllowedRecipientsBuilder fixes its `admin` at construction. Each registry that it deploys has that admin as `DEFAULT_ADMIN_ROLE` holder and as a holder of every other role [s11]. On both live builders, the admin is the Aragon Agent [s11].
- The spec says that the standard builder deploys the registries "with Aragon Voting as their admin" [s2]. That is not possible. With the Agent as admin, a limit change is an Agent action, so it passes Dual Governance, which OD-73 avoids [s2].
- The rehearsal calls the same registry factories directly, with Voting as admin [s1]. The deployer holds the add-recipient and set-limit roles for one transaction: it adds the Asset Safe, sets the limit and gives both roles up. The builder asserts the role layout on chain, and this path does not. So `test_02` checks every role after the vote [s1].
- Another path gives the deployer no role: Voting adds the Asset Safe and sets the limit in the vote, with two more items for each registry.

### 3. Voting cannot add USDS to the shared token list in one item

- Voting holds the list's admin role, and the admin role administers the add-token role. Voting, the Agent and the executor do not hold the add-token role [s12].
- A single `addToken` item reverts, and the whole vote reverts with it at execution. The rehearsal found this when the vote failed [s1].
- The fix is three items: Voting takes the role, adds USDS and gives the role up [s1].

### 4. The USDS items fund nothing at launch

- The Agent holds no USDS at blocks 26196400 and 26249900, as on 2026-10-05 [s22][s1]. A USDS top-up can pay only after the treasury holds USDS.
- DAI is on the shared token list and in the payment permission already, and the operator converts DAI to USDS one to one (OD-22). After a 6-item vote without the USDS items, a DAI top-up, the conversion and a deposit into Sky savings ran [s1].
- The four USDS items include the overwrite of a shared permission (finding 5). OD-93 asks whether to keep them.

### 5. The payment rewrite overwrites a shared permission

- Every Easy Track top-up factory of every committee pays through one permission: the executor's `CREATE_PAYMENTS_ROLE` on Aragon Finance. Voting manages it. `grantPermissionP` replaces its params and does not check what was there [s13].
- The rehearsal builds the new params from the live ones at the fork block: 22 params that end in "deny". It replaces the end with one more branch, USDS at most 2,000,000 per payment, then "deny": 25 params [s1].
- `test_06` asks the live ACL 108 questions before and after the vote: 9 tokens, each at 12 amounts around every ceiling. Only the 8 USDS answers at or below 2,000,000 change [s1].
- Four votes rewrote these params before: on 2022-02-18, 2022-12-09, 2024-01-26 and 2025-12-20 [s14]. If another vote rewrites them after the Clutch vote is built, the vote that executes last drops the other's change without an error. `test_06` must run again at a recent block before the vote starts and before it executes.

### 6. Easy Track's limit of open motions is shared, and it was nearly full

- At most 20 motions can be open at once. At the limit, `createMotion` reverts with `MOTIONS_LIMIT_REACHED`. The code allows at most 24, and only the admin role, which Voting holds, changes the limit [s15].
- A motion stays open until someone enacts, cancels or rejects it, so a motion that waits for enactment also holds a slot [s15].
- Up to block 26196400, Easy Track has had 1,202 motions [s16]:
  - In the last 365 days, 30 factories created 329 motions.
  - The peak was 18 open motions on 2026-09-09. 16 of them came from the AllowConsolidationPair factory [s16][s27].
  - September 2026 had the most new motions of any month: 63.
  - In the last 365 days, 10 or more motions were open 6.7% of the time, and 15 or more were open 2.9% of the time.
  - The open count reached the limit 7 times in 2022 and 2023, when the limit was 12. The limit became 20 on 2023-05-26.
- In days 1 to 10 of a month, the time-weighted mean was 2.79 open motions with a peak of 18. In the other days, it was 3.43 with a peak of 17 [s16]. So the top-up window of ADR 009 does not avoid the busy times [s21].
- At block 26249900, 1 motion was open [s1]. The history above was not fetched again.
- Clutch adds motions: the seed, top-ups, a budget motion after each event, onboarding and removal motions, and burn motions [s21][s20]. The stand-in sets one key per motion [s1]. If the real budget factory does the same, a change of K keys at the lift holds K slots for 72 hours. OD-94 asks how to handle the limit.

### 7. A budget factory must build the same script at creation and at enactment

- Easy Track builds the script again at enactment and requires the same hash [s15]. So a factory cannot write the current time, or read state that can change during the 72 hours.
- The stand-in passes a timestamp of 0 to `setAllowance`, and the modifier stored the enactment time [s1]. So a budget motion starts the key's refill period again at enactment.

### 8. The vote shows hashes, not the policy

- Each batch shows on the vote as `approveHash` with a 32-byte hash. Tokenholders cannot read the policy from the vote.
- So the batches must be published with the vote, with one command that computes each hash again from the batch, the Safe and its nonce. The roadmap requires one-command verification of every permission change [s24].

### 9. A batch that cannot run blocks its Safe until another vote

- A batch with `safeTxGas` and `gasPrice` of zero reverts in full when a call in it fails, so the Safe's nonce does not change and the batch can run again [s10].
- A batch that can never run blocks the later batches of the same Safe, and only a new vote can approve a replacement.
- Most calls in the batches change only the new Safes and the modifiers. The other calls are token approvals and CoW's fallback handler, so few changes elsewhere on the chain can stop a batch. A paused or upgraded token is one such change. The rehearsal before execution is the check.

### 10. Earn deposits: one open request per queue, and limits that others set

- A Safe has at most one pending deposit request in each queue. A second deposit reverts until an oracle report makes the first one claimable [s18].
- At block 26196400, neither Earn vault had a vault limit: the limit is the largest int256 [s19]. The depositor check admitted the new Safe [s18][s1], and the deposits passed again at block 26249900. The holders of the vaults' roles can set a limit or a depositor list.
- `redeem` locks the caller's shares, and `claim` pays the caller's requests to any receiver [s17]. So the first-loss role can pin the receiver of a redemption to the Agent, as ADR 008 requires [s20]. The rehearsal requested a redemption but did not claim it, because a claim needs an oracle report.

## What works with the live contracts

- Voting registers the three factories, and the top-ups pay through the live Easy Track and Finance: USDC, stETH and DAI, and USDS after the vote once the fork gives the Agent some USDS [s1].
- A budget motion runs through the live executor and the governance role [s1].
- The emergency Safe disables the operator modifier, and the next operator call fails with `GS104` [s1].
- The orders account takes CoW's fallback handler and ComposableCoW as the verifier of CoW's settlement domain on Safe v1.5.0, and the relayer approvals [s1]. The roadmap's gate for the vote phase asks a fork rehearsal to show this [s24].
- The Growth Committee's Safe moves both first-loss share balances by plain transfer. The executor burns earnETH shares through the `first-loss-burn` role. The committee's Safe requests an earnUSD redemption through the `first-loss` role [s1].
- The new Asset Safe deposits USDC into earnUSD and wstETH into earnETH [s1].

## The ramp-up

### Terms

- **F**: the mandate size, a ceiling (OD-89). Its figure comes from the attested computation and is not in this repository [s20].
- **C**: the launch cap of one million dollars, until the lift (OD-54, OD-55) [s25].
- **FL**: the value of the first-loss shares at the Earn oracle price [s20].
- **D**: the day the vote starts.

### Plan

| Step | Earliest | Who acts | What happens | Bound or gate |
|---|---|---|---|---|
| 0. Prepare | before D | Clutch contributors, auditors, DAO | Build and audit every factory and policy that the vote names. Deploy the accounts, modifiers, registries and factories. Compile the mainnet policy, then build, publish and hash the batches. Hold the Snapshots for the mandate and the fifth emergency signer. Rehearse at a recent block. | The vote names fixed addresses and hashes, so all of them must exist first (findings 1, 2 and 8). |
| 1. Vote | D to D+5 | an LDO holder starts it; tokenholders vote | 3 days of main phase, then 2 days of objection phase [s28]. | Rehearse again before execution (finding 5). |
| 2. Enable | D+5 | anyone | Execute the vote, then the three batches in nonce order. Check the deployed state against the artifacts. | A batch that cannot run blocks its Safe (finding 9). |
| 3. First-loss move | D+5 | the Growth Committee's Safe, five of nine [s23] | Transfer both share balances to the first-loss Safe. | Another body's quorum. |
| 4. Seed | D+8 | the committee's Safe creates; anyone enacts | A seed motion on each registry that the seed uses, 72 hours each [s15]. The seed is at most F less FL, and at most C [s20]. | A free motion slot (finding 6). No USDS in the treasury (finding 4). |
| 5. Capped operation | D+8 to the lift | the committee's Safe as operator | Deposits within the budget keys. Top-ups only under the mandate's published eligibility conditions; each registry at most F a month as a backstop; the vault at most C [s20][s21]. | Budgets change only after an event (OD-56). One open request per Earn queue (finding 10). No swaps without the orders policy. |
| 6. Lift | when its gates close | the committee | The guard on the committee's Safe, the vendor's terms and Lido's review of the guard's change, then the forum post [s25]. Budget motions for the keys that need more room [s21]. | Outside Clutch's control. The budget motions hold motion slots (finding 6). |
| 7. Steady state | after the lift | the committee | Replenishments within the headroom under F and the treasury share, under the mandate's published conditions (OD-89). | The registries allow F per registry a month, and two F within about 72 hours around a month boundary, so F holds by procedure [s20]. |

### What makes ramping up hard

1. **The vote cannot be built as written.** Findings 1 to 3 stop the vote, and nothing after it can start. OD-92 asks how the vote applies the batches and deploys the registries.
2. **Everything that the vote names must exist before it starts.** The vote names factory addresses and batch hashes. The budget factory, the template and removal factories, the first-loss burn factory, the orders policy and the first-loss policy are not built yet [s24]. A factory or policy that misses the vote needs another vote. This rehearsal used a stand-in budget factory and enabled the orders and first-loss modifiers with no policy.
3. **The cap and its lift are outside Clutch's control.** The vault stays at most C until the guard is on the committee's Safe, the vendor's terms are in place and Lido has reviewed the guard's change [s25].
4. **The shared motion limit.** A seed, a top-up, a budget motion or a burn cannot start while 20 motions are open (finding 6). OD-94 asks how to handle it.
5. **The funding pace.** Each registry pays at most F a calendar month as a backstop, and each top-up waits 72 hours [s20]. After the seed, a top-up also needs the mandate's published eligibility conditions (OD-89). The seed is at most F less FL, and at most C [s20].
6. **The budget pace.** A key changes only after an event, by a 72-hour motion (OD-56) [s21]. An approval spends its key, and the key refills over 30 days [s21].
7. **No swaps without the orders policy.** USDT has no yield venue at launch; it is held until an order swaps it [s26]. So a seed in USDT stays idle. If the orders policy misses the vote, the orders account has no operator permissions, and a token for orders needs a vote (OD-78) [s2].
8. **USDS.** The USDS items fund nothing until the treasury holds USDS (finding 4). OD-93 asks whether to keep them.
9. **Outside parties.** The Growth Committee moves the first-loss shares [s23]. The holders of the Earn vaults' roles can set a vault limit or a depositor list, and Earn's oracle reports decide when a deposit or a redemption completes [s18][s19].
10. **The shared payment permission.** Another vote that rewrites it in the same weeks can lose its change, or Clutch's (finding 5).
11. **Hashes on the vote.** Tokenholders must check the published batches against the hashes (finding 8).

## Decisions this note opens

- **OD-92.** Q1: how the vote applies the Safe batches under the gas cap. Q2: how the registries get Voting as admin.
- **OD-93.** Whether the vote keeps the four USDS items.
- **OD-94.** How Clutch handles Easy Track's shared limit of 20 open motions.

The open-decision register has the options and the agent's recommendations.

## Limits of this rehearsal

- The policy is the repository's dry-run constellation, not the launch policy. It has no spare keys, no Lido Lend key, no orders keys and no exit-governance role.
- The budget factory is a stand-in. The template, removal and first-loss burn factories are not built. The `test_05` probe gave the first-loss modifier two permissions through the owner path, not through a policy.
- The figures are test values, not production figures. The emergency Safe's signers are test addresses.
- The proposer's LDO came from the Agent on the fork, and that one voter passed the vote.
- No Earn oracle report ran, so no deposit or redemption was claimed.
- The second run read the open motions at its fork block only. The history of finding 6 is from the first run.
- The screening guard is not part of the launch and did not run.

## How to reproduce

Set `RPC` to an archive Ethereum RPC in your shell. Never write the URL into a file. Then:

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
EX=0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977    # its script executor
ACL=0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb
FIN=0xB9E5CBB9CA5b0d659238807E84D0176930753d86   # Aragon Finance
TL=0x4AC40c34f8992bb1e5E856A448792158022551ca    # the shared stablecoin token list
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c

cast call $V 'voteTime()(uint64)' --block $B                 # 432000
cast call $V 'objectionPhaseTime()(uint64)' --block $B       # 172800
cast call $ET 'motionDuration()(uint256)' --block $B         # 259200
cast call $ET 'motionsCountLimit()(uint256)' --block $B      # 20
cast call $ET 'MAX_MOTIONS_LIMIT()(uint256)' --block $B      # 24
cast call $ET 'hasRole(bytes32,address)(bool)' $Z $V --block $B   # true

# finding 2: the builders' admin is the Agent
cast call 0x334D6eDc13F63728b39e6A6D04A7Bbd5D6A9B9FF 'admin()(address)' --block $B
cast call 0x958e0D946D014F377421a53AB5f9180d4485e63B 'admin()(address)' --block $B

# finding 3: Voting is the list's admin, without the add-token role
ADD=$(cast keccak ADD_TOKEN_TO_ALLOWED_LIST_ROLE)
cast call $TL 'hasRole(bytes32,address)(bool)' $Z $V --block $B     # true
cast call $TL 'hasRole(bytes32,address)(bool)' $ADD $V --block $B   # false
cast call $TL 'getRoleAdmin(bytes32)(bytes32)' $ADD --block $B      # the admin role

# findings 4 and 5: the Agent's USDS, and the executor's payment permission
cast call 0xdC035D45d973E3EC169d2276DDab16f1e407384F 'balanceOf(address)(uint256)' $AGENT --block $B   # 0
PAY=$(cast keccak CREATE_PAYMENTS_ROLE)
cast call $ACL 'getPermissionParamsLength(address,address,bytes32)(uint256)' $EX $FIN $PAY --block $B   # 22
cast call $ACL 'getPermissionManager(address,bytes32)(address)' $FIN $PAY --block $B                    # Voting

# finding 10: the Earn vault limits, (balance, limit)
cast call 0x7b1e06C46d4510277FC37a37bBeF65F3794fdDE4 'vaultState()((int256,int256))' --block $B   # earnUSD
cast call 0xa2a4C4ecE27229aF51c546844AB752824Ccb557e 'vaultState()((int256,int256))' --block $B   # earnETH
```

The history of finding 5: the ACL's `SetPermissionParams(address,address,bytes32,bytes32)` logs with the executor as topic 1 and Finance as topic 2, up to block 26196400. There are four, each in an `executeVote` transaction to Aragon Voting [s14]:

- `0xe80098eeccd65c2d811f76ac010eac1dc78dd80669712cc157cd307323e8e9cc` (2022-02-18)
- `0x46d937a9bb533feaf3b7936d230822eecc65d7ff4f6e38a4e17d3ca59cdf0799` (2022-12-09)
- `0x3ac00633d92351d7f34e25854b14a9c88cdb1cc6b776aa7bb1046eff4b4da48d` (2024-01-26)
- `0x2f4168b4006bfbbc0f1e6130a8b667d2590896c699e6f3b020b9d37df8327c44` (2025-12-20)

The counts of finding 6: fetch every Easy Track log up to block 26196400 with these first topics, through Etherscan's `getLogs` [s16]:

| Event | Topic 0 |
|---|---|
| `MotionCreated(uint256,address,address,bytes,bytes)` | `0x2775db1f1f2dd97c60ba2903b3ca235c9cecb3cb47a9cb464f86578b9877f4a4` |
| `MotionEnacted(uint256)` | `0xd4fbbd7bf63590ce72807eb770b83aaf2f3a7958a4b2093fd9ab89b276096942` |
| `MotionCanceled(uint256)` | `0x801fcb98a9fa2e695209772f0a24f3f7ac36f6568659ae2e0cd7763fb73f2862` |
| `MotionRejected(uint256)` | `0x6a4120e111f0bfb3586b7dc9317f9ae5441ce866d1ad9d221ce6d76431f84426` |
| `MotionsCountLimitChanged(uint256)` | `0x5e368703b7ab35fe9ef4dbc482cd414476841204c7484b8e834d0d3ac4ed8672` |

Sort the logs by block and log index. The open count goes up by one at each `MotionCreated`, and down by one at each `MotionEnacted`, `MotionCanceled` or `MotionRejected`. On 2026-10-15 the query returned 1,202 created, 1,197 enacted, 5 canceled and none rejected; the motion IDs run from 1 to 1,202 without a gap.
