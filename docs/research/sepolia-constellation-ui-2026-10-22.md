---
type: Research Note
title: Sepolia Constellation UI registration, 2026-10-22
description: Missing workspace metadata, the pinned serializer and conflicting policy keys on the existing Sepolia stand.
tags: [sepolia, zodiac, constellation, evidence]
status: draft
review_status: slop
valid_as_of: 2026-10-22
stale_after: 2026-10-29T00:00:00Z
generated:
  by: codex/gpt-6
  at: 2026-10-22T19:20:48Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/zodiaceco/zodiac-sdk/blob/0157a6755d2331047acc3c6780440a7416c471bc/README.md#L349-L371"
    title: SDK 2.10.0 — vault and policy metadata, key identity and equal grants across modifiers
  - id: s2
    resource: "https://github.com/zodiaceco/zodiac-sdk/blob/0157a6755d2331047acc3c6780440a7416c471bc/CHANGELOG.md#L68-L73"
    title: SDK changelog — policy metadata added in 2.4.0
  - id: s3
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/index.mjs"
    title: Earlier SDK 2.1.2 — describeRoles serializes key, members and permissions only
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/dacf2625ba23865e190f6c9013f6b375c3c787b8/policy/constellation/sepolia/constellation.ts#L28-L46"
    title: Published Sepolia declaration — three existing Safes without vault flags and seven roles without policy labels
  - id: s5
    resource: "https://github.com/zodiaceco/zodiac-sdk/pull/70"
    title: Policy feature — API requires the same label, description, members and permissions for a policy key
  - id: s6
    resource: urn:clutch:evidence:2026-10-22:sepolia-ui-registration-review
    title: SDK upgrade, all ten workspace metadata fields, two policy conflicts and zero RPC differences at block 11971576
  - id: s7
    resource: "https://unpkg.com/@zodiaceco/api-types@1.13.0/dist/index.d.mts"
    title: Published API types — resolve returns on-chain Account shapes without vault or policy metadata
  - id: s8
    resource: /specs/sepolia-deployment-notes.md
    title: Saved workspace readback — Deployed Constellation with empty Vaults and Policies lists
---

# Sepolia Constellation UI registration

## Answer

- The published declaration omitted `vault: true` on all three Safes and `policy` on all seven roles. Constellation accounts do not appear in Vaults or Policies unless those fields mark them [s1][s4][s8].
- SDK 2.1.2 passes `vault`, but drops `policy` and `description` when it serializes roles. An offline capture reproduced both behaviours. Policy metadata first appeared in SDK 2.4.0 [s2][s3][s6].
- The local dependencies are now SDK 2.10.0 and API types 1.13.0. The three Safes carry `vault: true`, and all seven roles carry policy labels under their original keys. Removing those ten metadata fields makes the prepared payload equal to the published payload. No address, role key, permission or allowance changed [s6].
- Promoting all seven roles is blocked by Zodiac's documented policy model. One key identifies one policy, whose label, description, members and permissions must match across its modifiers. The stand has two keys with different permissions [s1][s5][s6].

## Conflicting policies

| Original key | Asset role | Orders role | Difference |
|---|---|---|---|
| `operator` | Token transfers to Orders, under allowances | CoW orders, TWAPs, cancellation and token returns to Asset | Same member; different permission sets [s6]. |
| `emergency` | Recovery transfers, operator revocation and module removal | Recovery CoW orders, cancellation, zero approvals and revocation | Same member; different permission sets [s6]. |

A different display label cannot create two policies under one key.
Splitting the same workspace into several Constellations does not change the policy's key identity.
Renaming keys or sharing a union of permissions would change the stand [s1][s5][s6].
The unique keys `governance`, `first-loss` and `first-loss-burn` have no duplicate-key conflict.
This review did not test their promotion against the hosted app [s6].

## Correction through Constellation

The local Safe declarations now carry the workspace metadata:

```ts
const asset = sep.safe["Clutch Sepolia — Asset"]
asset({ address: manifest.assetSafe, vault: true })
```

Orders and First-loss carry the same flag.
The payload check requires it and still refuses Safe configuration overrides [s6].

A policy-capable SDK describes an existing role without changing its key:

```ts
roles: {
  operator: { members, permissions, policy: "Clutch Sepolia — Operator" },
}
```

SDK 2.10.0 now retains the policy metadata and settles callback conditions.
The earlier callback-materialization workaround has been removed.
The preparation command records policy conflicts in `diff.json` and returns status `1` while they remain, even when the chain matches.
The publication CLI refuses those conflicts before credentials, RPC or a hosted request.
The upgrade alone does not resolve them [s1][s2][s6].

For all roles to appear with their current grants, Zodiac must support different grants per modifier under one policy key, or identify a displayed role by chain, modifier and key.
The provider must confirm a supported metadata-only registration route for that model.
That is a change to Zodiac's application model; no contract replacement or role-key migration is needed for it [s1][s5][s6].

## Checks and limits

- Offline SDK capture: `bun --no-env-file cache/sepolia/constellation/ui-registration-review-2026-10-22/probe.ts`. The capture replaces the API client and refuses network access [s6].
- Local preparation: `just --justfile sepolia.just constellation 25091c1a-4f37-48b1-8d35-f287550481a8`. At block `11971576`, the RPC comparison found zero policy differences across 82 events. The new payload recompiles to the same 63 configuration calls [s6].
- The vault and policy export regressions failed before the corrections. The current Sepolia and compiler suites pass 117 tests; the fork suite passes 52 and skips the public-Sepolia fixture. Both strict type checks pass. Bun 1.3.0, as pinned in CI, accepts the frozen lockfile. The mainnet-fork artifact changes only its SDK version; its 99 calls are unchanged [s6].
- The resolve endpoint returns on-chain accounts. Its response does not include `vault` or `policy`, so it cannot prove that the workspace registered them. Check the saved declaration and the actual Vaults and Policies lists after any later authorized publication [s7][s8].
- No hosted resolve, publication, Apply, deployment or GitHub push ran for this correction. Hosted metadata acceptance and registration remain unverified. The current server's exact refusal of the two policy conflicts was not exercised; the restriction comes from the provider's published model [s1][s5][s6].

Evidence is under `cache/sepolia/constellation/ui-registration-review-2026-10-22/`.
`report-before-sdk-update.json` preserves the earlier probe that lost policy metadata.
`prepared-payload.json` carries all ten metadata fields, and `prepared-diff.json` records both blocked policy groups.
It is not ready for publication [s6].
