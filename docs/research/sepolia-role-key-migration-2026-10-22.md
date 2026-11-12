---
type: Research Note
title: Sepolia role-key migration, 2026-10-22
description: Four role deletions, two Safe owner batches and verification against the existing Sepolia stand.
tags: [sepolia, zodiac, roles, migration, evidence]
status: draft
review_status: slop
valid_as_of: 2026-10-22
stale_after: 2026-10-29T00:00:00Z
generated:
  by: claude-code/sonnet-5.5
  at: 2026-11-12T12:27:25Z
verified: []
sources:
  - id: s1
    resource: /adr/015-tests-on-sepolia.md
    title: OD-137 proposal and acceptance checks
  - id: s2
    resource: "https://docs.zodiac.eco/developers/constellations"
    title: Constellation partial updates — omission preserves a role and null clears it
  - id: s3
    resource: "https://docs.zodiac.eco/developers/roles/role-keys"
    title: Role identity and migration to another key
  - id: s4
    resource: "https://github.com/safe-global/safe-deployments/blob/main/src/assets/v1.5.0/multi_send_call_only.json"
    title: Canonical MultiSendCallOnly 1.5.0 address and runtime hash on Sepolia
  - id: s5
    resource: urn:clutch:evidence:2026-10-22:sepolia-role-key-migration
    title: Prepared package, source RPC comparison, compiler regression and fork checks
  - id: s6
    resource: urn:clutch:evidence:2026-10-23:sepolia-role-key-migration
    title: Owner publication HTTP 200; two canonical successful migration receipts; zero policy differences, unchanged allowances and Safe configuration at block 11976825
---

# Sepolia role-key migration

## Answer

- The Constellation must declare the four old role instances as `null`. A renamed role alone leaves its predecessor untouched. The pinned SDK preserves these null declarations [s2][s3][s5].
- The prepared declaration has three vault flags, seven policy labels and no policy-key conflicts. It omits allowances. The local package preserves permissions and holders, changes the governance/revoke key references, and clears old memberships, functions and targets [s1][s5].
- At block `11971984`, the source profile had zero policy differences. Safe owners, nonces, modules, singleton/guard/fallback slots and allowance values were recorded in the package [s5].
- Two owner transactions contain the 87 configuration calls. Each Safe batch is atomic. A fork test checks the mixed state between the Asset and Orders batches [s5].
- Mainnet still uses its current keys. The Sepolia compiler now always uses the four account keys, and the mainnet design dependencies remain open in ADR 015 [s1][s5].

## Reads and preparation

A local preparation tool read the chain state and compiled the package. The repository no longer carries that tool.

The read-only transport permits chain headers, code, storage, logs, calls and transaction/receipt reads. It refuses write methods and suppresses RPC endpoint details on errors. The package is under `cache/sepolia/role-key-migration/`; no credentials or keystore data appear in it [s5].

The batch executor is the existing MultiSendCallOnly 1.5.0 at `0xA83c336B20401Af773B6219BA5027174338D1836`. Preparation checks its runtime against `0xcdbdcec38d2f1c7d961b0029ff8416b7e86e9974d6f0e9c9580c7d17fcfb6663`, published by Safe for Sepolia [s4][s5].

Payload SHA-256: `1c33e4b11883eb318d97b36ecb0d19ce2985646e7fddda494e70fe1dfa6a2494` [s5].

## Findings from the rehearsal

- The compiler identified a stop-only role by the literal name `emergency`. Renaming it bypassed that check. A regression failed before the fix and passes with `asset-emergency` and `orders-emergency` in the stop-only set [s5].
- A single `Voting.forward` CallsScript exceeded the transaction gas cap. Its byte-copy loop contributed to the cost. The replacement uses Voting's `execute` path and two Safe MultiSendCallOnly batches [s5].
- Nine pinned-fork tests pass. They cover new-role execution, old-key refusal, account isolation, governance pins, emergency revoke and switch, CoW signing/receiver limits, allowance preservation, the intermediate state, atomic rollback and dormant function-slot cleanup [s5].
- Local Anvil receipts report `6,109,955` gas for Asset and `5,694,166` for Orders. Both transactions succeed. The RPC comparison then finds zero differences at local block `11971986`; allowance storage and Safe configuration match the source snapshot, apart from one nonce increment per affected Safe [s5].
- The CoW signing test initially used `validTo == block.timestamp + validDuration`. The deployed signer rejected it as `Dishonest valid duration`. Using the existing stand's `validDuration - 1` fixture passes without a permission change [s5].
- The inherited five-second local RPC timeout was too short for a cold Anvil gas estimate. The migration runner uses a bounded sixty-second timeout and waits for receipts before verification [s5].
- The publisher's strict test type-check rejected assignment to read-only `Response.text`. The timeout fixture now defines its own response property; it preserves the same failure behaviour [s5].

## Limits

EM chose OD-137 B, OD-134 C and OD-135 A on 2026-10-22. The owner reviewed and authorised the exact package before signing; preparation and fork tests execute no public transaction [s1][s5]. The owner then executed both batches at blocks `11976805` and `11976806`. The comparison at block `11976825` found zero policy differences, unchanged allowance storage and unchanged Safe configuration apart from the expected nonce increments [s6].
