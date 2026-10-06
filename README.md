# Clutch

Clutch is the Lido Active Treasury system. The Treasury Management Committee operates a DAO-owned Safe through a default-deny permission policy. The DAO keeps custody. An emergency Safe can pull assets back to the Aragon Agent. Easy Track motions change the policy only inside templates that are fixed at audit time.

This repository is the single system of record: product documents, decisions, specifications, the permission policy, contracts, tests, scripts, runbooks and deployment records.

## Status

- Design and specification stage. Nothing is deployed.
- Private. The repository becomes public no later than deployment. Nothing enters it that could not be published at that point.
- Agents drafted the first version of every document. Each page stays `slop` until a human reviews it. The state of every page is in [docs/registers/document-status.md](docs/registers/document-status.md).
- EM accepts decisions in the interim. The Treasury Management Committee is the permanent acceptor. An ADR that constrains the committee also needs a verification from the Emergency Brakes multisig.

## Why "Clutch"

A clutch is the set of eggs brooded together in one nest. The name continues the bird names of Lido governance: GOOSE, EGG, NEST and Gaggle. CLUTCH is already a token symbol for several unrelated projects, so Clutch must never become a token symbol.

## Where to start

- [AGENTS.md](AGENTS.md) — the rules for agents and humans. `CLAUDE.md` is a symlink to it.
- [docs/index.md](docs/index.md) — the map, and the knowledge bundle in Open Knowledge Format 0.2.
- [docs/product/brief.md](docs/product/brief.md) — vision, goals, North Star Metric, readers and users.
- [docs/adr/](docs/adr/index.md) — decision records. What is still open is in [docs/registers/open-decisions.md](docs/registers/open-decisions.md).
- [docs/specs/](docs/specs/index.md) — the specification policy, the invariants and the LIP draft.
- [ROADMAP.md](ROADMAP.md) — phases and the gates between them.
- [test/README.md](test/README.md) — the dry-run harness on a pinned mainnet fork.

## How this repository works

- Agents draft most text and code. Humans decide, review and merge.
- Every page in `docs/` records its sources, who produced it, who verified it, and its review status.
- An accepted ADR is an engineering decision. It authorises nothing on chain. On-chain change still needs the vote, motion or signature that the system defines.
- CI validates the bundle and checks that the document-status register is current.

## Commands

```sh
python3 scripts/validate_docs.py                  # validate the docs bundle; errors exit 1
python3 scripts/validate_docs.py --write-status   # regenerate docs/registers/document-status.md
python3 scripts/validate_docs.py --check-status   # fail if the register is out of date
python3 scripts/test_validate_docs.py             # test the validator's recorded-verification rule
RPC=<archive mainnet RPC> forge test              # the fork suite
```

The validator needs Python 3.10 or later and PyYAML. Without a local PyYAML, run it through uv: `uv run --with pyyaml python scripts/validate_docs.py`.

## Licence

AGPL-3.0-or-later. Files derived from Easy Track keep GPL-3.0; GPL-3.0 section 13 permits combining them with AGPL-3.0 code.
