---
type: Decision
title: "ADR 004: Specifications and the permission policy as data"
description: Hand-written conceptual specs, a generated API reference, invariants mapped to tests, the LIP as an external layer, runbooks as their own class, and a permission policy written as a Zodiac constellation that Clutch's own compiler turns into one committed JSON artifact; the team works in the Zodiac UI, local tooling verifies everything the UI produces, and a round-trip check compares the chain with the artifact.
tags: [specs, policy, invariants, testing, runbooks]
status: draft
review_status: human-reviewed
decision: accepted
accepted_by: human:em
constrains_operator: false
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T08:12:59Z
verified:
  - by: human:em
    at: 2026-10-05T20:27:31Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted
  - by: human:em
    at: 2026-10-06T08:16:51Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-06--adr-001-and-adr-004-verified-again
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on specifications and the policy, 2026-09-30, on the format and compiler, 2026-10-05, and on the Zodiac constellation, 2026-10-06
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

- Today the policy is hand-written Solidity that builds each condition tree [s3].
- A write to a role, target and selector replaces the stored tree. It does not merge into it. A regression test in the kit guards this [s4].
- Since 2026-10-05 the kit's policy follows the launch scope and the approval rule. It has no swap instances and no factories, and it is still Solidity [s5].
- Tests read off the implementation inherit its bugs. lido-lend-markets derives tests from requirements and keeps specs in two layers [s2].
- The Roles modifier emits every applied condition tree in its `ScopeFunction` event [s6]. The last write per role, target and selector wins, and revoke events clear entries, so the live policy can be rebuilt from events without decoding storage. The event signatures are in the deployed mastercopy's code [s8]. A decode of real events is not yet checked.
- The repository already runs Foundry for the fork tests and Python with uv for the docs validator. Lido's DAO vote scripts are Python [s7].
- On 2026-10-06, EM asked to use the Zodiac constellation as the project backbone [s1]. The policy provider's constellation still builds after a one-line fix. The roles SDK compiles the kit's condition shapes to the same flat arrays, and its ABI matches the deployed mastercopy [s8].
- The hosted Zodiac app compiles some entries on its server and needs an API key. It has no hand-off to an Aragon vote or an Easy Track motion [s8].

## Decision

EM accepted the positioned model on 2026-09-30 [s1]:

1. **Conceptual specifications** are written by hand. They hold what code cannot say: the architecture, the roles matrix, the permission model, the invariants and the threat model.
2. **The API reference** is generated from NatSpec. Nobody edits it by hand.
3. **Invariants** have IDs `INV-NNN`. Each maps to a named test, and CI fails on an invariant without a test.
4. **Behaviour** is written as WHEN/THEN scenarios. Tests derive from the specifications, never from the implementation. A behaviour change updates its specification in the same commit.
5. **The LIP** is a third, external layer. It summarises and cites the conceptual specifications and must never contradict them.
6. **Runbooks** are a separate class under `docs/runbooks/`. There is one per emergency or technical action. Each maps to a permission and carries a drill record.
7. **The permission policy is a data file.** A script compiles it into modifier calls. A round-trip check reads the applied conditions back from the modifier on a fork and compares them with the data file, so the chain checks the compiler. Behaviour tests assert what each role can and cannot do, independent of the encoding.

Rejected: keeping the Solidity builders as the source of truth, and adopting the TypeScript policy format of the original proposal [s1].

EM decided on 2026-10-05, closing OD-16 [s1]:

8. The policy data file is YAML with a strict schema. Addresses and amounts are quoted strings, YAML anchors and aliases are not allowed, and CI checks the file against a JSON Schema.
9. The compiler is a Python program run with uv and pinned dependencies. It emits one JSON artifact: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances. The Foundry tests, the enabling vote script and the policy-drift detector all consume that artifact. The round-trip check rebuilds the trees from the modifier's events on a fork and compares them with the artifact.

EM decided on 2026-10-06, closing OD-33 [s1]:

10. Clutch works in the Zodiac UI. The team pushes the constellation to a Lido Zodiac workspace. The UI shows the account graph and the policy, the difference from the chain, and the transactions that a change needs.
11. Local tooling replicates and verifies everything that the UI produces. No transaction that the hosted app builds is signed, or enters a vote or a motion, unless Clutch's compiler produces the same calls from the same commit. The policy changes only in the repository; a change made in the UI is drift.
12. The policy source is the Zodiac constellation, written in TypeScript under `policy/`. It replaces the YAML file of decision 8. Decision 7 still applies through decision 14: the compiled artifact is the policy's data.
13. Clutch's own compiler, written in TypeScript on the Zodiac roles SDK, replaces the Python compiler of decision 9. It runs offline from a frozen lockfile with pinned versions, and it emits the artifact of decision 9. It refuses an entry that only the hosted app can compile, such as an action or a DeFi Kit preset, because local tooling cannot verify it.
14. The artifact is committed. A policy pull request carries the TypeScript change and the recompiled artifact, and CI fails when they differ. Reviewers approve the artifact. The enabling vote, the Easy Track templates and the drift detector consume the committed artifact.
15. The Solidity builders go now. The port to the constellation deletes them and rebuilds the fork tests on the artifact. The port does not have to reproduce the builders' trees.

Not chosen on 2026-10-06: the hosted app as an optional viewer only, the hosted app without local verification, a Python compiler that reads a JSON export of the constellation, review of the TypeScript only, and a gate that keeps the Solidity builders until the compiled trees equal theirs.

EM decided on 2026-10-06, closing OD-35 [s1]:

16. The team that owns the repository, `@lidofinance/defi-tech`, owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main`, with the key in a local `.env` that git ignores. The committee and the Emergency Brakes multisig get access to view the workspace. CI holds no key.

An agent drafted this record. It stays `proposed` until EM accepts the text.

## Options considered

- Solidity builders as the source of truth. Not chosen: the encoding and the intent live in one place, and nothing independent checks the encoding.
- The original proposal's TypeScript format. Not chosen on 2026-09-30: it adds a toolchain, and the kit never applied it. Chosen on 2026-10-06 (decision 12): EM wants to work in the Zodiac UI, and the roles SDK compiles the kit's condition shapes to the same arrays [s8].
- YAML and a Python compiler (decisions 8 and 9). Replaced on 2026-10-06: the UI works on the constellation, and two encoders of one format would have to agree.
- The hosted app from authoring to the chain. Not chosen: it compiles some entries on its server, so the repository would not hold the whole policy, and it has no hand-off to a vote or a motion [s8].
- A Python compiler that reads a JSON export of the constellation. Not chosen: it re-implements the SDK's flattening, and the round-trip check, not a second language, gives the independence.
- Keep the Solidity builders until the compiled trees equal theirs. Not chosen by EM: the port rebuilds the tests on the artifact.
- A data file without a round-trip check. Not chosen: a compiler bug would then reach the chain unseen.
- TOML or JSON for the data file. Not chosen by EM: TOML handles nested condition trees badly, and JSON has no comments for reviewers.
- A Foundry script as the compiler. Not chosen by EM: it keeps one language, but Solidity is clumsy for data transformation.

## Consequences

- The compiler must emit one complete tree per role, target and selector, because a write replaces the slot [s4].
- The round-trip check must use the deployed mastercopy's enum values and its `Allowance` field order: `refill`, `maxRefill`, `period`, `balance`, `timestamp`.
- The port deletes the Solidity builders (decision 15). Until it lands, [test/README.md](https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md) marks where they diverge from the design [s5].
- The policy path crosses two languages: TypeScript compiles and Solidity tests. The round-trip check compares the chain with the committed artifact, independent of both.
- The compile step runs the npm dependency tree of the SDK. CI compiles offline from the frozen lockfile, and the vote consumes only the reviewed artifact (decision 14).
- The hand-off to an Aragon vote or an Easy Track motion is Clutch code that reads the committed artifact. The hosted app has none [s8].
- The UI's difference from the chain is a view. The drift detector of ADR 009 stays the source of alerts.
- Clutch needs a Lido Zodiac workspace and an API key, which the repository-owner team holds (decision 16). The key never enters the repository, CI or a vote, and agents do not use it.
- Use of the hosted app can need a plan from the policy provider. Its terms stay out of the repository until they are announced.
- If the committee executes operator transactions through the UI, the screening guard of [ADR 010](/adr/010-pre-execution-screening.md) still checks each Safe transaction. A fork drill must show that before launch.
- Files derived from the provider's constellation keep LGPL-3.0-only ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md) decision 9).
- The policy-drift detector ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) compares the live chain with the same artifact, so one file states what the policy must be.
- The event signatures of the roles SDK match the deployed mastercopy [s8]. Before the round-trip check is relied on, a decode of real events must still be checked.
- The port, the compiler and the artifact format start at once (decision 15). The round-trip check is phase 2 work.

## Confirmation

- INV-016: the round-trip check passes on a fork.
- The invariant-to-test check in CI, once it exists.

## Reversal conditions

- The round-trip check cannot read some condition back from the modifier.
- The compiler proves harder to verify than the builders it replaces.
- Local tooling cannot reproduce a transaction that the UI builds.
- The roles SDK stops supporting the deployed mastercopy's encoding.
- A change of the provider's plan or licence blocks local compilation or verification.

## Open questions

None open. OD-16 was decided on 2026-10-05. OD-33 and OD-35 were decided on 2026-10-06.
