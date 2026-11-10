---
type: Research Note
title: One Easy Track factory and funding by tranche votes, 2026-11-05
description: "OD-100 to OD-112 evidence: Easy Track's script permissions, cancel and pause; Roles storage; Merkle-root engines; the two-modifier alternative; Finance payments by Aragon Voting; and the flows to the Aragon Agent."
tags: [governance, easy-track, roles, funding, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-05
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-11-05T19:07:00Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's questions and answers of 2026-11-01 and 2026-11-05
  - id: s2
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EasyTrack.sol#L133-L250"
    title: Easy Track at 3183d1f — createMotion and enactMotion are paused with the contract; enactMotion rebuilds the script and checks its hash; cancelMotion is the creator's; cancelMotions and cancelAllMotions need CANCEL_ROLE
  - id: s3
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EVMScriptFactoriesRegistry.sol#L52-L116"
    title: Easy Track at 3183d1f — only DEFAULT_ADMIN_ROLE adds or removes a factory, and every script must pass the factory's permissions
  - id: s4
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/libraries/EVMScriptPermissions.sol#L40-L59"
    title: Easy Track at 3183d1f — canExecuteEVMScript accepts a script only if each call's address and selector are in the factory's permissions
  - id: s5
    resource: "https://etherscan.io/address/0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5#code"
    title: Roles mastercopy that Clutch uses, verified source — contracts/Core.sol L13-L14 (roles internal, allowances public), contracts/Roles.sol L103-L110 (a module call uses the caller's default role), contracts/adapters/Types.sol L29 (the custom condition's view check)
  - id: s6
    resource: "https://github.com/Se7en-Seas/boring-vault/blob/4538ccf7706290e38b739e939854897c0f81f6de/src/base/Roles/ManagerWithMerkleVerification.sol#L32-L98"
    title: Veda's BoringVault manager at 4538ccf — one Merkle root per strategist, set by an authorized caller; the leaf is built at L277
  - id: s7
    resource: "https://github.com/mellow-finance/flexible-vaults/blob/2af48a02506b2c4fc3c278dbd3f32c1b456153db/src/interfaces/permissions/IVerifier.sol#L53-L142"
    title: Mellow flexible-vaults at 2af48a0 — the verifier's one Merkle root and its setter, the four verification types and their leaf formats
  - id: s8
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — a write replaces the role, target and selector tree
  - id: s9
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Easy Track's settings, and the Emergency Brakes multisig's pause without unpause
  - id: s10
    resource: /research/enabling-vote-rehearsal-2026-10-15.md
    title: The enabling vote rehearsed on a mainnet fork — the policy batch's gas and size, and EIP-7825's limit per transaction
  - id: s11
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the executor's payment permission, its 22 parameters and its ceilings per payment
  - id: s12
    resource: "https://research.lido.fi/t/4279"
    title: Lido forum — Treasury Management Principles and the Treasury Management Committee, 2023-04-04
  - id: s13
    resource: "https://research.lido.fi/t/10868/3"
    title: Lido forum — TMC-6 operational rules, 2025-11-17; the Snapshot ended on 2025-12-01
---

# One Easy Track factory and funding by tranche votes, 2026-11-05

On 2026-11-01 EM asked three questions. Could a Merkle tree of allowed actions, as in Veda's and Mellow's vaults, let Easy Track manage everything? Is the Roles modifier compatible with it? And can a trusted caller cancel a pending motion? On 2026-11-05 EM set the aim that no administrative action after the enabling vote needs an Aragon vote [s1]. This note keeps the evidence behind OD-100 to OD-112. All chain reads are at block 26350608 unless a row says otherwise.

## Easy Track

- **A factory's scripts can call only what its registration allows.** At creation and again at enactment, Easy Track builds the script through the factory and requires that each call's address and selector are in the factory's permissions [s3][s4]. So the registration of a factory is its address book.
- **Only the admin registers a factory.** `addEVMScriptFactory` and `removeEVMScriptFactory` need `DEFAULT_ADMIN_ROLE` [s3]. Aragon Voting holds it; the Emergency Brakes multisig and the Aragon Agent do not.
- **Enactment rebuilds the script.** `enactMotion` asks the factory again and requires the hash stored at creation [s2]. A factory that checks state at creation therefore checks it again at enactment. If the check fails, the whole enactment reverts, the deletion of the motion included, so the motion stays open until it is cancelled.
- **Cancel.** `cancelMotion` is only for the motion's creator, at any time, and it works while Easy Track is paused, because it has no pause modifier. `cancelMotions` and `cancelAllMotions` need `CANCEL_ROLE` [s2]. Of the three addresses checked, only Aragon Voting holds `CANCEL_ROLE`.
- **Pause.** `createMotion` and `enactMotion` stop while Easy Track is paused [s2]. Aragon Voting holds `PAUSE_ROLE` and `UNPAUSE_ROLE`. The Emergency Brakes multisig holds `PAUSE_ROLE` only [s9].
- **No order between motions.** Each motion enacts after its own window. Two motions that write the same function both pass their checks if nothing changed when they were created, and the later enactment wins.
- **Monitoring can decode every motion.** `MotionCreated` carries the creator, the factory, the calldata and the script [s2].
- **Settings.** The objection window is 259,200 seconds, the threshold is 50 basis points, and at most 20 motions are open at once. Easy Track was not paused.

## The Roles modifier

- **The trees are private storage.** The Roles mastercopy keeps `roles` internal and `allowances` public [s5]. No contract can read a permission tree on chain, so a factory cannot compare a write with the current tree. A factory that versions writes must keep the versions itself.
- **A write replaces a tree.** A write sets the whole tree of a role, target and selector [s8]. Adding a branch means writing the complete list.
- **Modifiers can chain.** `execTransactionFromModule` checks the calling module's default role [s5]. One modifier can therefore be the module of another.
- **A custom condition is a view call.** Its `check` gets the call's fields and the condition's data, and nothing else [s5]. A Merkle proof cannot pass through it.

## Merkle-root engines

| | Veda | Mellow |
|---|---|---|
| Root | One per strategist, set by an authorized caller [s6] | One per verifier [s7] |
| Leaf | The packed hash of the decoder and sanitizer, the target, whether value is non-zero, the selector, and the address arguments that the decoder extracts [s6] | `(who, where, selector)` in the compact type, `(who, where, value, data)` in the extended type, or a custom verifier's data [s7] |
| Per protocol | A decoder and sanitizer contract | A leaf per call shape, or a custom verifier |

The Roles modifier has no root to set and no proof channel. A Merkle policy would replace the modifiers with a new engine, which is new code. EM dropped Merkle roots on 2026-11-01 [s1].

## Whole writes, scope writes and versions

- **A whole write per motion does not scale.** The rehearsal's largest batch, the Asset Safe's 99 calls, took 6,304,514 gas and 60,292 bytes [s10]. EIP-7825 caps a transaction at 16,777,216 gas, and the policy grows with every protocol.
- **A scope write is small, but it races.** A motion that writes one function's complete list stays small. Two such motions on one function, created before either enacts, undo each other's change.
- **Versions close the race.** If the factory keeps a version per scope, checks it at creation and at enactment, and the script's last call commits the new version, then the second motion fails at enactment. Its creator cancels it, or Voting does. One counter that the emergency Safe and Voting can raise makes every open motion fail, so a stale motion cannot undo a revoke.

## The two-modifier alternative

An alternative chained two Roles modifiers: an outer one, whose bounds only a vote changes, and an inner one that motions change. Chaining works, because a module call uses the default role [s5]. The alternative adds a modifier and a second policy to keep in sync, and each change of a bound needs a vote. EM did not adopt it; the factory's typed shapes give the bound instead (OD-112) [s1].

## Finance payments by Aragon Voting

| Check | Result |
|---|---|
| Voting's payment permission on Finance | `hasPermission` true, 0 parameters |
| The Easy Track executor's payment permission | `hasPermission` false without arguments, 22 parameters |
| The executor, with real arguments | 1 DAI allowed; 3,000,000 DAI refused |
| `newImmediatePayment(DAI, 0x…dEaD, 1 DAI)` sent from Voting, as a call | succeeds |
| The same, for more DAI than the Agent holds | `VAULT_TOKEN_TRANSFER_REVERTED` |
| The same, from any other address | `APP_AUTH_FAILED` |

- The executor's `false` without arguments is not a defect. The ACL fails a parameter that reads an argument when no argument is given, and the executor's permission limits the token and the amount [s11].
- Aragon Voting pays from the Aragon Agent through Finance itself, in any token, when its vote executes. No Dual Governance proposal is on that path. The reason "votes add Dual Governance delay to each payment" in ADR 008's options is therefore wrong for a Finance payment.

```sh
# B=26350608; RPC holds an archive endpoint and is never committed.
ACL=0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb FIN=0xB9E5CBB9CA5b0d659238807E84D0176930753d86
VOT=0x2e59A20f205bB85a89C53f1936454680651E618e EX=0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea EB=0x73b047fe6337183A454c5217241D780a932777bD
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F ROLE=$(cast keccak CREATE_PAYMENTS_ROLE)
TS=$(cast block $B -f timestamp)
cast call $ACL 'hasPermission(address,address,bytes32)(bool)' $VOT $FIN $ROLE --block $B         # true
cast call $ACL 'getPermissionParamsLength(address,address,bytes32)(uint256)' $VOT $FIN $ROLE --block $B   # 0
cast call $ACL 'getPermissionParamsLength(address,address,bytes32)(uint256)' $EX $FIN $ROLE --block $B    # 22
# [token, receiver, amount, max uint256, 1, block timestamp], as Finance passes them
cast call $ACL 'hasPermission(address,address,bytes32,uint256[])(bool)' $EX $FIN $ROLE "[$(cast to-dec $DAI),57005,1000000000000000000,$(cast max-uint),1,$TS]" --block $B   # true
cast call $FIN 'newImmediatePayment(address,address,uint256,string)' $DAI 0x000000000000000000000000000000000000dEaD 1000000000000000000 clutch-check --from $VOT --block $B   # 0x
for r in DEFAULT_ADMIN_ROLE PAUSE_ROLE UNPAUSE_ROLE CANCEL_ROLE; do
  cast call $ET 'hasRole(bytes32,address)(bool)' $(cast call $ET "$r()(bytes32)") $VOT --block $B   # true for each
done
cast call $ET 'hasRole(bytes32,address)(bool)' $(cast call $ET 'CANCEL_ROLE()(bytes32)') $EB --block $B   # false
```

## Flows to the Aragon Agent

| Flow | Who | Before OD-108 | After OD-108 |
|---|---|---|---|
| Emergency transfers from the Asset Safe and the orders account | the emergency Safe | the Agent | the Agent |
| Recovery orders (OD-48) | the emergency Safe | the Agent | the Agent |
| First-loss redemption and claim | the committee's Safe | the Agent (ADR 008 decisions 21 and 23) | the Asset Safe |
| Exit from an insurance fund | the committee's Safe | the Agent (ADR 008 decision 28; not built) | the Asset Safe |
| A return of vault funds | the committee's Safe | none | the Agent, by a transfer pinned to it |

Only emergency and recovery paths, and the operator's pinned return, now reach the Agent. Monitoring alerts on every transfer to it.

## Treasury rules that the committee's items touch

- **New committee members.** The 2023 principles let prospective members apply for an empty seat and "request approval of their inclusion into the Committee by token holders" [s12]. The committee's multisig is 4 of 7, and it "will not be authorized to function with fewer than 7 members" [s12]. A change of members without a Snapshot each time therefore needs text in the mandate's Snapshot (OD-109).
- **TMC-6.** sUSDS plus tokenized money market funds stay at or below 15 percent of the total treasury, checked quarterly. A stablecoin runway floor of two months applies across the DAO and the foundations' wallets [s13]. The vault's sUSDS counts in that cap, so each report shows the ratio for the whole treasury (OD-111). The vault keeps no buffer of its own (OD-110).
