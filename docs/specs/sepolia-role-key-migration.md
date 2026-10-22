---
type: Guide
title: Sepolia role-key migration
description: Prepare, review, publish and execute the four-key migration on the existing Sepolia stand.
tags: [sepolia, zodiac, migration, roles]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-22T22:34:04Z
verified: []
sources:
  - id: s1
    resource: /adr/013-tests-on-sepolia.md
    title: ADR 013 — OD-100 proposal and migration acceptance checks
  - id: s2
    resource: /research/sepolia-role-key-migration-2026-10-22.md
    title: Migration package, account batches, fork checks and remaining public steps
  - id: s3
    resource: /specs/sepolia-stand-plan.md
    title: Existing Sepolia addresses, controller, workspace and owner workflow
---

# Sepolia role-key migration

Use the existing Safes and Roles modifiers on chain `11155111`. EM chose OD-100 B, OD-97 C and OD-98 A on 2026-10-22. The stand owner reviews the locally compiled package, authorises its exact calls and signs public transactions. Preparing or publishing a draft executes no migration [s1][s3].

| Safe | Modifier | Old key | New key |
|---|---|---|---|
| Asset | Operator | `operator` | `asset-operator` |
| Asset | Safety | `emergency` | `asset-emergency` |
| Orders | Orders | `operator` | `orders-operator` |
| Orders | Orders | `emergency` | `orders-emergency` |

The package keeps the existing holders and action permissions. Governance and emergency revokes use the new operator key for their account. `governance`, `first-loss`, `first-loss-burn` and allowance storage stay unchanged [s1][s2].

## 1. Prepare and rehearse

```sh
just --justfile sepolia.just migration-prepare 25091c1a-4f37-48b1-8d35-f287550481a8
just --justfile sepolia.just migration-rehearse
```

Preparation refuses policy drift, different owners, nonces, guards or fallback handlers, and an unexpected MultiSendCallOnly runtime. It saves the package and Constellation under `cache/sepolia/role-key-migration/`. Inspect `package.json`, `payload.json`, the payload SHA-256, `fork-tests.log`, `fork-verification.json` and `rehearsal.json` [s2].

The package contains 87 configuration calls in two atomic Safe batches. The Asset batch migrates both Asset roles and updates governance. The Orders batch migrates both Orders roles. Between batches, Asset uses the new keys and Orders uses the old keys; each retains its emergency revoke and recovery path [s2].

## 2. Publish the Constellation draft

The owner runs hosted commands from a clean, pushed `testnet/sepolia`, with the workspace key in the ignored `.env`. An agent needs an explicit exception to use that key. OD-95 and OD-96 remain open; hosted publication still needs its applicable authorisation. Public execution needs the owner's authorisation in ADR 013 [s1][s3].

```sh
CLUTCH_SEPOLIA_PUSH=1 just --justfile sepolia.just migration-resolve
CLUTCH_SEPOLIA_PUSH=1 just --justfile sepolia.just migration-publish
```

The script checks the source state again and compares the resolved target state. The declaration marks all three Safes as vaults and all seven roles as policies. It sets the four old role instances to `null`; omitting them would leave them active. It omits allowances so that Zodiac receives no allowance write [s2].

Inspect the saved draft in the Sepolia workspace. Check the three Safe addresses, the four renamed keys, the explicit old-role removals, the unchanged members and the original governance `Nor` conditions. Publication does not execute the two batches. If Zodiac builds an execution package, compare its decoded calls with the reviewed package before signing [s1][s2].

## 3. Execute the reviewed batches

After review of the draft and the owner's authorisation of the exact locally compiled package:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just migration-apply
```

Foundry asks for the existing keystore password. The controller sends two transactions to the existing test Voting contract. Each calls its Safe through the pinned MultiSendCallOnly. The command uses no API key and deploys no Safe or modifier [s2].

If the first transaction succeeds and the second fails, inspect the receipts and current state. The first account remains migrated. After review, resume the saved transaction list:

```sh
CLUTCH_SEPOLIA=1 just --justfile sepolia.just migration-resume
```

Keep the original package and broadcast record. Do not prepare a new migration or restore old grants to retry the second batch [s1][s2].

## 4. Verify and activate the local profile

Pass the Asset and Orders transaction hashes in that order:

```sh
just --justfile sepolia.just migration-verify '<asset-tx-hash>,<orders-tx-hash>'
```

Verification requires successful canonical receipts for the exact transactions, zero policy differences, unchanged allowance storage, unchanged Safe configuration and one nonce increment on each affected Safe. It writes `verification.json`. The local rehearsal writes a separate `fork-verification.json` with `localOnly: true` [s2].

Only after public verification succeeds, activate the saved target manifest:

```sh
cp cache/sepolia/role-key-migration/target-manifest.json cache/sepolia/manifest.json
just --justfile sepolia.just constellation 25091c1a-4f37-48b1-8d35-f287550481a8
```

Reload Zodiac. Confirm three Vaults and seven Policies with the new key mapping after the authorised deployment workflow completes. A resolved specification alone does not prove that the app saved these records [s1][s2].

## Mainnet

Use the same four keys in the initial mainnet policy after the ADR 013 design dependencies are complete. Update factory and exit-governance pins, invariants, execution clients, monitoring and runbooks together. These Sepolia commands authorise no mainnet action [s1].
