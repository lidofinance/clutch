# Provenance of this directory

This directory started as a copy of the policy provider's Zodiac constellation for Lido Active Treasury Management. An agent copied it on 2026-10-06 at EM's request ([decision log](../../docs/registers/decision-log.md)). Since the port of 2026-10-06, it is the source of the Clutch permission policy ([ADR 004](../../docs/adr/004-specifications-and-policy-as-data.md), decisions 12 to 15). The provider's roles, holders, protocols and budgets are gone.

## Source

- Repository: https://github.com/gnosisguild/lido-atm-constellation (public).
- Commit: `02ea37d44efb324a7be395726618d5e76da490bc` (2026-08-27), the head of `main` on 2026-10-06.
- Copy command: `git archive 02ea37d44efb324a7be395726618d5e76da490bc zodiac.config.ts constellation .lib abis package.json bun.lock tsconfig.json LICENSE .gitignore .editorconfig .prettierignore | tar -x -C policy/constellation`

## Licence

The copied files are LGPL-3.0-only, as the upstream `LICENSE` and `package.json` state. They keep that licence under decision 9 of [ADR 001](../../docs/adr/001-repository-scope-visibility-licence-name.md) (OD-34): a derived file gets `SPDX-License-Identifier: LGPL-3.0-only` and a modification notice when it changes. New files use `AGPL-3.0-or-later`. JSON files cannot carry a header; `package.json` and `bun.lock` are derived, and `manifests/` and `artifacts/` are new.

`provenance.lock` lists every file that comes from upstream: an unchanged file with its git blob hash, a changed file by path. `scripts/check_licences.py` checks every source file against it in CI ([ADR 012](../../docs/adr/012-contributing-with-many-agents.md)).

## Not copied

| Path | Reason |
|---|---|
| `README.md` | The provider's proposal text, not configuration. The [research note](../../docs/research/zodiac-constellation-2026-10-06.md) cites it at the same commit. |
| `CLAUDE.md` | Agent instructions for the upstream repository. A nested `CLAUDE.md` loads as instructions for agents that work in this directory, and fetched content is untrusted input (`AGENTS.md`). |
| `docs/` | One screenshot. |
| `.vscode/` | Editor settings. |

## Layout

| Path | Content |
|---|---|
| `constellation/` | The policy: the two modifiers, the four roles, the budgets and the fixed values |
| `compiler/` | Clutch's compiler and its tests (ADR 004, decision 13) |
| `manifests/` | Deployment addresses. `fork-25946643.json` is the fork fixture's deployment, not mainnet |
| `artifacts/` | The compiled artifact for each manifest, committed (ADR 004, decision 14) |
| `.lib/` | The provider's helpers for `inspect` and `push` |

## Build

```sh
cd policy/constellation
bun install --frozen-lockfile                                   # bun 1.3.0, exact versions
bun compiler/compile.ts --manifest manifests/fork-25946643.json  # write the artifact
bun compiler/compile.ts --manifest manifests/fork-25946643.json --check
bun test compiler
CLUTCH_MANIFEST=manifests/fork-25946643.json bun .lib/scripts/inspect.ts
```

`bun push` and `bun pull-org` call the hosted app and need `ZODIAC_API_KEY`. Only a member of the repository-owner team runs them, from the merged `main`, with the key in a local `.env` that git ignores ([ADR 004](../../docs/adr/004-specifications-and-policy-as-data.md) decision 16). CI and agents do not run them. Never commit `.env` or `.zodiac/`.

## Changes from upstream

The import commit is byte-identical to the upstream files at the commit above. Later changes, all on 2026-10-06:

| Files | Change |
|---|---|
| `.lib/constellation.ts` | The empty codegen stub gains `accounts: {}`, so `inspect` runs offline; SPDX line and notice |
| `constellation/addresses.ts`, `nodes.ts`, `index.ts`, `allowances/index.ts`, `roles/index.ts` | Rewritten: the launch-scope contracts and a deployment manifest; two Roles modifiers bound by address and no Safe node; one budget key per protocol spender with dry-run stand-ins; four roles. SPDX line and notice in each |
| `constellation/roles/operator/*.ts`, `constellation/roles/emergency/*.ts` | Rewritten to the operator and emergency roles of ADR 005, with explicit function signatures. SPDX line and notice in each changed file; the two `index.ts` files are unchanged |
| `zodiac.config.ts`, `tsconfig.json` | No contracts for the `allow` kit; `compiler/` is type-checked. SPDX line and notice |
| `package.json`, `bun.lock` | Exact versions, the same as the lockfile resolved, plus `ethers` and `zodiac-roles-sdk` as direct dependencies; compile, check and test scripts; every script that calls the hosted app runs `compiler/owner-guard.ts` first (ADR 012). The lockfile changes only in the placement of type packages |
| `abis/` | Deleted: Clutch writes signatures and needs no ABI files |
| `constellation/lib.ts`, `constellation/parameters.ts`, `constellation/roles/governance/`, `constellation/roles/technical/`, `compiler/`, `manifests/`, `artifacts/` | New |

Unchanged from upstream: the other `.lib/` files, `LICENSE`, `.gitignore`, `.editorconfig` and `.prettierignore`.
