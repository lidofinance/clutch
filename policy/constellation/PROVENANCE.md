# Provenance of this directory

This directory is a copy of the policy provider's Zodiac constellation for Lido Active Treasury Management. An agent copied it on 2026-10-06 at EM's request ([decision log](../../docs/registers/decision-log.md)). Since OD-33 of 2026-10-06, the Clutch policy source grows from it ([ADR 004](../../docs/adr/004-specifications-and-policy-as-data.md)). Until the port lands, its content is the provider's proposal, not the Clutch policy.

## Source

- Repository: https://github.com/gnosisguild/lido-atm-constellation (public).
- Commit: `02ea37d44efb324a7be395726618d5e76da490bc` (2026-08-27), the head of `main` on 2026-10-06.
- Copy command: `git archive 02ea37d44efb324a7be395726618d5e76da490bc zodiac.config.ts constellation .lib abis package.json bun.lock tsconfig.json LICENSE .gitignore .editorconfig .prettierignore | tar -x -C policy/constellation`

## Licence

The files are LGPL-3.0-only, as the upstream `LICENSE` and `package.json` state. They keep that licence under decision 9 of [ADR 001](../../docs/adr/001-repository-scope-visibility-licence-name.md) (OD-34): a derived file gets `SPDX-License-Identifier: LGPL-3.0-only` when it changes, and new files use `AGPL-3.0-or-later`.

## Not copied

| Path | Reason |
|---|---|
| `README.md` | The provider's proposal text, not configuration. The [research note](../../docs/research/zodiac-constellation-2026-10-06.md) cites it at the same commit. |
| `CLAUDE.md` | Agent instructions for the upstream repository. A nested `CLAUDE.md` loads as instructions for agents that work in this directory, and fetched content is untrusted input (`AGENTS.md`). |
| `docs/` | One screenshot. |
| `.vscode/` | Editor settings. |

## What does not apply to Clutch

- The roles, the role holders, the protocols and the module power predate the Clutch design and contradict it. The [research note](../../docs/research/zodiac-constellation-2026-10-06.md) lists each difference.
- The budget figures in `constellation/allowances/index.ts` are the provider's placeholders. They are not Clutch figures. Production budgets come from the attested computation and are not in this repository.
- `zodiac.config.ts` names the Safe v1.4.1 singleton. Clutch uses Safe v1.5.0 ([ADR 005](../../docs/adr/005-account-graph-and-roles.md)).

## Build

```sh
cd policy/constellation
bun install --frozen-lockfile    # bun 1.3.0, as package.json pins
bun .lib/scripts/inspect.ts      # prints the nodes as push() would send them
```

At commit `02ea37d`, `inspect` fails without the `.zodiac/` codegen, which `bun pull-org` writes from the hosted app with an API key. The empty stub in `.lib/constellation.ts` has no `accounts` key, and `@zodiaceco/sdk` 2.1.2 and 2.4.1 read `codegen.accounts`. The change below fixes this, so `inspect` runs offline.

`bun push` and `bun pull-org` call the hosted app and need `ZODIAC_API_KEY`. Only a member of the repository-owner team runs them, from the merged `main`, with the key in a local `.env` that git ignores ([ADR 004](../../docs/adr/004-specifications-and-policy-as-data.md) decision 16). CI and agents do not run them. Never commit `.env` or `.zodiac/`.

## Changes from upstream

The import commit is byte-identical to the upstream files at the commit above. Later changes:

| Date | File | Change |
|---|---|---|
| 2026-10-06 | `.lib/constellation.ts` | The empty codegen stub gains `accounts: {}`, with a notice in the file. Without it, `inspect` stops with `TypeError: undefined is not an object (evaluating 'codegen.accounts[opts.workspace]')`. |
| 2026-10-06 | `.lib/constellation.ts` | `SPDX-License-Identifier: LGPL-3.0-only` on the first line, because the file changed (OD-34). |
