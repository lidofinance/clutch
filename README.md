# Clutch

> **Draft. Nothing here is ratified.** Documents, decisions, figures, parameters, addresses and permissions are working drafts. No Lido governance body has ratified them. Nothing here authorises an on-chain action. All figures can change until the vote that sets them passes, including budgets, caps, limits, thresholds, timings and figures from the mandate draft or request for solution. An `accepted` ADR is a repository engineering decision, not ratification.

Clutch is the Lido Active Treasury system. The Treasury Management Committee operates a DAO-owned Safe through a default-deny permission policy.
The DAO keeps custody. An emergency Safe can return assets to the Aragon Agent.
Easy Track motions change permissions only through templates fixed at audit time.

This repository holds the product documents, decisions, specifications, policy, contracts, tests, scripts, runbooks and deployment records.

## Status

- Design and specification stage. Nothing is deployed.
- Private; becomes public by deployment. Content must be suitable for publication then.
- Agents drafted each document's first version. Pages stay `slop` until human review; see [document status](docs/registers/document-status.md).
- EM accepts decisions in the interim. The Treasury Management Committee is the permanent acceptor.

## Start here

| You want to… | Read |
|---|---|
| Learn the system | [Interactive guide](docs/onboarding/clutch-onboarding.html), then [product brief](docs/product/brief.md) |
| Find a document | [Documentation map](docs/index.md) |
| Make a change | [Contributing](CONTRIBUTING.md) and [agent rules](AGENTS.md) |
| Understand a choice | [Decision records](docs/adr/index.md) and [open decisions](docs/registers/open-decisions.md) |
| Check requirements | [Specifications](docs/specs/index.md) |
| Understand policy and tests | [Policy layout](policy/constellation/PROVENANCE.md) and [fork harness](test/README.md) |
| Find the next phase | [Roadmap](ROADMAP.md) |

The guide is a self-contained HTML file. Download it and open it in a browser; GitHub shows its source.
CI also publishes it from `main` to GitHub Pages (`https://lidofinance.github.io/clutch/` for a public site).
See [guide maintenance](docs/onboarding/guide.md).

## Workflow

Agents draft and test. Humans decide, review and merge ([ADR 012](docs/adr/012-contributing-with-many-agents.md)).
Documents record sources, authors, verifications and review status.
An accepted ADR does not replace the vote, motion or signature required for an on-chain action.

CI checks document metadata, generated files, guide controls, restricted terms, secrets, licences and invariant-to-test links.
The merge queue repeats the checks on the merged result.

## Commands

```sh
just setup       # install dependencies and build contracts
just check       # CI checks, except the fork suite
just regen       # rebuild policy artifact, log, status register and guide
just test-fork   # pinned mainnet fork; needs an archive RPC in .env
just --list      # all recipes
```

Without `just`, use `uvx --from rust-just==1.58.0 just <recipe>`.
See [Contributing](CONTRIBUTING.md) for log entries and the human-only mainnet workflow.

## Name and licence

A clutch is a group of eggs in one nest. The name follows Lido's GOOSE, EGG, NEST and Gaggle names.
Clutch must not become a token symbol: unrelated projects already use CLUTCH.

AGPL-3.0-or-later. Easy Track-derived files keep GPL-3.0; section 13 permits their combination with AGPL-3.0 code.
