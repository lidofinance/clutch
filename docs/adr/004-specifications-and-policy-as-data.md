---
type: Decision
title: "ADR 004: Specifications and the permission policy as data"
description: Specification layers, invariant tests, policy compilation, committed artifacts, local verification and the Zodiac workspace.
tags: [specs, policy, invariants, testing, runbooks]
status: draft
review_status: human-reviewed
decision: accepted
accepted_by: human:em
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-13T06:47:18Z
verified:
  - by: human:em
    at: 2026-10-05T20:27:31Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted
  - by: human:em
    at: 2026-10-06T08:16:51Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-06--adr-001-and-adr-004-verified-again
  - by: human:em
    at: 2026-10-13T09:11:53Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-13--adr-004-verified-again
    sha256: 889927fc006912dd3a4ea63794b9fb280a36f2255b634d4f1c51717a8f96fcd9
  - by: human:em
    at: 2026-10-20T18:46:48Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-20--adr-001-to-adr-004-verified-again-and-yt-registered
    sha256: 74b99987b2dc29b343e59ba7b447fe67d89d5bfba7f20e4dc6761e72854f4862
  - by: human:em
    at: 2026-10-22T21:59:49Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-22--adr-001-adr-003-and-adr-004-verified-again
    sha256: c3d2212eb1878d512ab0c21d754fc1ef40af44d9abe6a2dc4f574be8255b6fe4
  - by: human:em
    at: 2026-11-11T05:49:58Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-11-11--adr-001-to-adr-004-verified-again
    sha256: b3bdb7b4fe47803eb501ee333ff207b4025b0df173bc941e5cd1ee4beb790136
  - by: human:em
    at: 2026-11-11T20:36:05Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-11-11--adr-001-to-adr-004-verified-after-the-occam-pass-and-a-second-recording-agent
    sha256: 7f79aab20c346fa82ed45cb735290adb04226cf4af39f17c19442bd63fb9dc08
  - by: human:em
    at: 2026-11-12T14:08:31Z
    recorded_by: claude-code/mythos-5.2
    ref: /registers/decision-log.md#2026-11-12--adr-003-and-adr-004-verified-after-the-switch-to-raw-writes
    sha256: a74f433a134f032bc6ad54836936f07b6a831cc4efac62bb2d1339e742128423
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on specifications and the policy, 2026-09-30, on the format and compiler, 2026-10-05, on the Zodiac constellation, 2026-10-06, and on the workspace's viewers, 2026-10-13
  - id: s2
    resource: /research/ai-first-practice-2026-09.md
    title: AI-first repository practice — lend-markets specification layers
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/src/policy/FullPolicy.sol"
    title: Kit policy builders at 7a8c661 — the current Solidity source of the policy
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/ReviewProbe.t.sol#L141"
    title: Kit test at 7a8c661 — every spender of a token sits in one approve scope, because a later write to the same role, target and selector replaces the earlier tree
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7a8c6613602a0078807298b1cebb513af2d74bd5/test/README.md"
    title: Kit harness README at 7a8c661 — what the policy follows, and what the kit still lacks
  - id: s6
    resource: "https://github.com/gnosisguild/zodiac-modifier-roles/blob/820e5bc975d1817bdd4bc4a95226f553f7b67b68/packages/evm/contracts/PermissionBuilder.sol#L36-L42"
    title: Zodiac Roles v2 PermissionBuilder at 820e5bc — ScopeFunction emits the full condition array
  - id: s7
    resource: "https://github.com/lidofinance/scripts/blob/d02f8786f138583c521d6406fdbf1b2180a131a8/pyproject.toml#L13"
    title: Lido DAO vote scripts at d02f878 — Python with eth-brownie
  - id: s8
    resource: /research/zodiac-constellation-2026-10-06.md
    title: Research note — the policy provider's constellation, the hosted path, the compile probe, the SDK's ABI against the mastercopy, and the differences from the design
---

# ADR 004: Specifications and the permission policy as data

## Context

- The kit at `7a8c661` builds condition trees in Solidity [s3]. Since 2026-10-05 it follows the launch scope and approval rule, without swap instances or factories [s5].
- A write replaces the role/target/selector tree. A kit regression test checks this [s4].
- Implementation-derived tests inherit implementation bugs. lido-lend-markets derives tests from requirements and uses two specification layers [s2].
- `ScopeFunction` emits the applied tree [s6]. The last write per role, target and selector wins, and revokes clear entries, so events can reconstruct the policy without storage decoding. The event signatures are in the deployed mastercopy's code [s8]; real-event decoding remains untested.
- The repository uses Foundry for fork tests and Python with uv for document validation. Lido's DAO vote scripts use Python [s7].
- On 2026-10-06, EM requested Zodiac constellation as the project backbone [s1]. The provider's copy builds after a one-line fix. Its roles SDK produces the kit's flat condition arrays, and its ABI matches the deployed mastercopy [s8].
- The hosted Zodiac app compiles some entries server-side and needs an API key. It has no Aragon vote or Easy Track hand-off [s8].

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. **Conceptual specifications** are written by hand. They hold what code cannot say: the architecture, the roles matrix, the permission model, the invariants and the threat model (decision log, 2026-09-30).
2. **The API reference** is generated from NatSpec. Nobody edits it by hand (decision log, 2026-09-30).
3. **Invariants** have IDs `INV-NNN`. Each maps to a named test, and CI fails on a Draft invariant without one (decision log, 2026-09-30).
4. **Behaviour** is written as WHEN/THEN scenarios. Tests derive from the specifications, never from the implementation. A behaviour change updates its specification in the same commit (decision log, 2026-09-30).
5. **The LIP** is a third, external layer. It summarises and cites the conceptual specifications and must never contradict them (decision log, 2026-09-30).
6. **Runbooks** are a separate class under `docs/runbooks/`. There is one per emergency or technical action. Each maps to a permission and carries a drill record (decision log, 2026-09-30).
7. **The permission policy is a data file.** A script compiles it into modifier calls. A round-trip check reads the applied conditions back from the modifier on a fork and compares them with the data file, so the chain checks the compiler. Behaviour tests assert what each role can and cannot do, independent of the encoding (decision log, 2026-09-30).
8. Replaced by decision 12 (OD-33).
9. Replaced by decision 13 (OD-33).
10. Clutch works in the Zodiac UI. The team pushes the constellation to a Lido Zodiac workspace. The UI shows the account graph and the policy, the difference from the chain, and the transactions that a change needs (OD-33).
11. Local tooling replicates and verifies everything that the UI produces. No transaction that the hosted app builds is signed, or enters a vote or a motion, unless Clutch's compiler produces the same calls from the same commit. The policy changes only in the repository; a change made in the UI is drift (OD-33).
12. The policy source is the Zodiac constellation, written in TypeScript under `policy/`. Decision 7 applies through decision 14: the compiled artifact is the policy's data (OD-33).
13. Clutch's own compiler is written in TypeScript on the Zodiac roles SDK. It runs offline from a frozen lockfile with pinned versions. It emits one JSON artifact: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances. The round-trip check rebuilds the trees from the modifier's events on a fork and compares them with the artifact. The compiler refuses an entry that only the hosted app can compile, such as an action or a DeFi Kit preset, because local tooling cannot verify it (OD-16, OD-33).
14. The artifact is committed. A policy pull request carries the TypeScript change and the recompiled artifact, and CI fails when they differ. Reviewers approve the artifact. The enabling vote, the motions' permission trees and the drift detector consume the committed artifact (OD-33).
15. The Solidity builders go now. The port to the constellation deletes them and rebuilds the fork tests on the artifact. The port does not have to reproduce the builders' trees (OD-33).
16. The team that owns the repository, `@lidofinance/defi-tech`, owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main`, with the key in a local `.env` that git ignores. The committee gets access to view the workspace. CI holds no key (OD-35, OD-64).
17. The Emergency Brakes multisig gets no access to view the workspace (OD-64).

## Options considered

- Solidity builders as the source: rejected because intent and encoding would have no independent check.
- A YAML policy file with a Python compiler: not chosen. The UI uses constellation, and two encoders would need to agree.
- The hosted app as an optional viewer only, the hosted app without local verification, or review of the TypeScript only: not chosen (decisions 10, 11 and 14).
- Hosted authoring through execution: rejected because server-side compilation leaves part of the policy outside the repository, with no vote or motion hand-off [s8].
- Python over a constellation JSON export: rejected because it duplicates SDK flattening. The round-trip check provides independence.
- Keep Solidity builders until tree parity: EM rejected this; the port rebuilds tests around the artifact.
- No round-trip check: rejected because compiler defects could reach the chain unseen.
- TOML or JSON: EM rejected TOML's handling of nested trees and JSON's lack of comments.
- A Foundry compiler script: EM rejected Solidity's limitations for data transformation, despite the single-language benefit.

## Consequences

- The compiler must emit a complete tree for each role, target and selector: writes replace slots [s4].
- The round-trip check must use the mastercopy's enum values and `Allowance` order: `refill`, `maxRefill`, `period`, `balance`, `timestamp`.
- TypeScript compiles; Solidity tests. The round-trip check compares chain state with the artifact independently of both.
- Compilation runs the SDK's npm dependencies. CI compiles offline from the frozen lockfile; the vote consumes only the reviewed artifact (decision 14).
- Clutch must build the vote and motion hand-off around that artifact; the hosted app provides none [s8].
- The UI's chain diff is a view. ADR 009's detector remains the source of drift alerts against the same artifact.
- Clutch needs a Lido Zodiac workspace and API key, held by the repository-owner team (decision 16). The key stays outside the repository, CI and votes. Agents must not use it.
- The hosted app may require a provider plan. Unannounced terms stay outside the repository.
- Once ADR 010's screening guard is set, it checks each transaction of the committee's Safe, those that the UI builds included (OD-83, OD-88). A fork drill before a top-up above the launch cap must prove this.
- Constellation-derived files keep LGPL-3.0-only ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md), decision 9).
- SDK event signatures match the mastercopy [s8]. Verify real-event decoding before relying on the round-trip check.
- The port, the compiler and the artifact format exist (decision 15). The round-trip check comes in phase 2.

## Confirmation

- INV-016: the round-trip check passes on a fork.
- `scripts/check_invariants.py` in CI: every named test exists, and every Draft invariant names one.

## Reversal conditions

- The round-trip check cannot read some condition back from the modifier.
- The compiler proves harder to verify than the builders it replaces.
- Local tooling cannot reproduce a transaction that the UI builds.
- The roles SDK stops supporting the deployed mastercopy's encoding.
- A change of the provider's plan or licence blocks local compilation or verification.

## Open questions

None.
