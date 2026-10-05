---
type: Decision
title: "ADR 004: Specifications and the permission policy as data"
description: Hand-written conceptual specs, a generated API reference, invariants mapped to tests, the LIP as an external layer, runbooks as their own class, and a permission policy kept as a strict YAML data file that a Python compiler turns into one JSON artifact, which a round-trip check compares with the trees rebuilt from the modifier's events.
tags: [specs, policy, invariants, testing, runbooks]
status: draft
review_status: slop
decision: proposed
constrains_operator: false
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on specifications and the policy, 2026-09-30, and on the format and compiler, 2026-10-05
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
---

# ADR 004: Specifications and the permission policy as data

## Context

- Today the policy is hand-written Solidity that builds each condition tree [s3].
- A write to a role, target and selector replaces the stored tree. It does not merge into it. A regression test in the kit guards this [s4].
- Since 2026-10-05 the kit's policy follows the launch scope and the approval rule. It has no swap instances and no factories, and it is still Solidity [s5].
- Tests read off the implementation inherit its bugs. lido-lend-markets derives tests from requirements and keeps specs in two layers [s2].
- The Roles modifier emits every applied condition tree in its `ScopeFunction` event [s6]. The last write per role, target and selector wins, and revoke events clear entries, so the live policy can be rebuilt from events without decoding storage. This is not yet checked against the deployed mastercopy's event ABI.
- The repository already runs Foundry for the fork tests and Python with uv for the docs validator. Lido's DAO vote scripts are Python [s7].

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

An agent drafted this record. It stays `proposed` until EM accepts the text.

## Options considered

- Solidity builders as the source of truth. Not chosen: the encoding and the intent live in one place, and nothing independent checks the encoding.
- The original proposal's TypeScript format. Not chosen: it adds a toolchain, and the kit never applied it.
- A data file without a round-trip check. Not chosen: a compiler bug would then reach the chain unseen.
- TOML or JSON for the data file. Not chosen by EM: TOML handles nested condition trees badly, and JSON has no comments for reviewers.
- A Foundry script as the compiler. Not chosen by EM: it keeps one language, but Solidity is clumsy for data transformation.

## Consequences

- The compiler must emit one complete tree per role, target and selector, because a write replaces the slot [s4].
- The round-trip check must use the deployed mastercopy's enum values and its `Allowance` field order: `refill`, `maxRefill`, `period`, `balance`, `timestamp`.
- Until the migration, the Solidity builders stay, and [test/README.md](https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/test/README.md) marks where they diverge from the design [s5].
- The policy path crosses two languages: Python compiles and Solidity tests. The round-trip check compares the chain with the data file, independent of both.
- The policy-drift detector ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) compares the live chain with the same artifact, so one file states what the policy must be.
- Before the round-trip check is relied on, its event decoding must be checked against the deployed mastercopy.
- The schema and the artifact format are phase 1 work; the compiler and the round-trip check are phase 2.

## Confirmation

- INV-016: the round-trip check passes on a fork.
- The invariant-to-test check in CI, once it exists.

## Reversal conditions

- The round-trip check cannot read some condition back from the modifier.
- The compiler proves harder to verify than the builders it replaces.

## Open questions

None open. OD-16 was decided on 2026-10-05.
