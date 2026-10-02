---
type: Research Note
title: Safe v1.5.0 and the screening guard, 2026-10-02
description: The check behind OD-02 — the Safe v1.5.0 source on the transaction-guard path, the provenance and support facts read on 2026-10-02, and a pointer to the restricted fork test of the screening vendor's guard on v1.3.0, v1.4.1 and v1.5.0.
tags: [safe, guard, screening, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-02
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T11:52:27Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L115-L168"
    title: Safe v1.5.0 execTransaction — the nonce is incremented and the signatures are checked before the guard is called
  - id: s2
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L62"
    title: Safe v1.5.0 SAFE_TX_TYPEHASH
  - id: s3
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L294"
    title: Safe v1.5.0 checkNSignatures — signatures shorter than the threshold revert (GS020); longer ones are accepted
  - id: s4
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/base/GuardManager.sol#L71-L73"
    title: Safe v1.5.0 setGuard — refuses a guard without the transaction-guard interface (GS300)
  - id: s5
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/interfaces/IGuardManager.sol#L10"
    title: Safe v1.5.0 ChangedGuard event, guard address indexed
  - id: s6
    resource: "https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/base/GuardManager.sol#L39"
    title: Safe v1.4.1 ChangedGuard event, guard address indexed
  - id: s7
    resource: "https://github.com/safe-global/safe-deployments/blob/7b1fb6d615ab2d2999550ec9166554b180e813e5/src/assets/v1.5.0/safe_migration.json"
    title: Safe deployment record — SafeMigration v1.5.0, canonical address and code hash
  - id: s8
    resource: "https://api.safe.global/tx-service/eth/api/v1/about/singletons/"
    title: Safe Transaction Service for Ethereum — indexed singletons, fetched 2026-10-02
  - id: s9
    resource: "https://etherscan.io/block/26104388"
    title: Ethereum block 26104388, used for the chain reads on this page
  - id: s10
    resource: "urn:clutch:restricted:screening-guard-2026-10-02"
    title: Restricted fork test of the screening vendor's guard and its results; held outside the repository until the vendor is announced
---

# Safe v1.5.0 and the screening guard, 2026-10-02

EM chose Safe v1.5.0 for both new Safes on 2026-10-02, on one condition: the screening vendor's guard must be compatible with v1.5.0. This page records the check. An agent ran every step on 2026-10-02.

## What the guard needs from the Safe

The guard rebuilds the Safe transaction hash itself. It uses the Safe's domain separator, which it reads once at construction, and the Safe's nonce minus one, which it reads during the check [s10]. It reads nothing else from the Safe.

## What Safe v1.5.0 does

- `execTransaction` computes the transaction hash with `nonce++`, checks the owners' signatures, and only then calls the guard. The guard receives the full signatures and the sender [s1]. So the nonce minus one is the nonce of the transaction under check, exactly as in v1.3.0 and v1.4.1.
- The transaction typehash is the one that v1.3.0 and v1.4.1 use [s2].
- A signature string longer than the threshold needs is accepted [s3]. The guard's in-band approval rides in those extra bytes.
- `setGuard` accepts only a contract that reports the transaction-guard interface [s4]. The guard reports it [s10].
- The `ChangedGuard` event indexes the guard address in v1.5.0 [s5], as it does in v1.4.1 [s6]. Monitoring rules written for the v1.4.1 Safe that runs the guard today therefore apply unchanged.

## Fork test of the vendor's guard

The fork test deploys the guard from the exact creation bytecode of a deployed instance. It then checks that the redeployed runtime code equals the deployed code, except for the three values that depend on the guard's own address [s10]. It runs one suite against fresh v1.3.0, v1.4.1 and v1.5.0 Safes, each with seven owners and a threshold of four. The suite checks these points:

1. The Safe accepts the guard.
2. The guard starts in a bypass mode and enforces once the vendor turns enforcement on.
3. An unapproved transaction reverts.
4. A single-use approval lets exactly one transaction through. The same call at the next nonce reverts.
5. An approval appended to the owners' signatures works. A signature from any other key reverts.
6. Delegatecalls and module enabling need an approval.
7. The vendor's key cannot relax or remove the guard.
8. The owners cannot remove the guard at once. They can start the 10-day timelock without the vendor and remove the guard after it.

A fifth test runs the vault's real path on v1.5.0: operator Safe with the guard, then the Roles modifier, then the Asset Safe. Without an approval the operator cannot act. With one, the call runs as the Asset Safe.

Result: 5 of 5 tests passed at block 26104388 [s9][s10]. Three deliberate defects each made the v1.5.0 suite fail as expected: a wrong approval hash, a guard that was never attached, and a removal at exactly ten days.

## Support and provenance, read on 2026-10-02

- Safe's Transaction Service for Ethereum indexes the v1.5.0 singleton `0xFf51A5898e281Db6DfC7855790607438dF2ca44b` [s8].
- The official SafeMigration v1.5.0 contract at `0x6439e7ABD8Bb915A5263094784C5CF561c4172AC` has code whose hash matches its deployment record [s7][s9].
- All seven owners of the committee's Safe are externally owned accounts [s9]. The v1.5.0 change to contract-signature validation therefore does not affect them.

## Limits

- The guard has no production history on v1.5.0. Its one enforcing instance runs on v1.4.1 [s10].
- The vendor's approval service runs off chain. Its support for v1.5.0 Safes is not tested here, and the vendor must confirm it (OD-07).
- The incident-history check on Safe v1.5.0 is still owed (OD-17).
