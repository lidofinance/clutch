# Clutch

> **Draft. Nothing here is ratified.** Every decision record, specification, figure, parameter, address and permission in this repository is a working draft. The Lido DAO, the Treasury Management Committee and every other body have ratified none of it, and nothing here authorises an action on chain. Every number is speculative until the vote that sets it passes: budgets, caps, limits, thresholds, timings, and the figures quoted from the mandate draft and from the request for solution can all change. An `accepted` decision record is an engineering decision for this repository, not a ratification.

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
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to set up, make a change, open a pull request and raise a decision, with or without an agent.
- [docs/onboarding/clutch-onboarding.html](docs/onboarding/clutch-onboarding.html) — the interactive onboarding guide. CI publishes it on GitHub Pages from `main` (`https://lidofinance.github.io/clutch/` for a public site); it carries the same draft disclaimer as this README. Or download it and open it in a browser; GitHub shows it as source. How it is built: [docs/onboarding/guide.md](docs/onboarding/guide.md).
- [docs/index.md](docs/index.md) — the map, and the knowledge bundle in Open Knowledge Format 0.2.
- [docs/product/brief.md](docs/product/brief.md) — vision, goals, North Star Metric, readers and users.
- [docs/adr/](docs/adr/index.md) — decision records. What is still open is in [docs/registers/open-decisions.md](docs/registers/open-decisions.md).
- [docs/specs/](docs/specs/index.md) — the specification policy, the invariants, the control matrix and the LIP draft.
- [ROADMAP.md](ROADMAP.md) — phases and the gates between them.
- [test/README.md](test/README.md) — the dry-run harness on a pinned mainnet fork.
- [policy/constellation/](policy/constellation/PROVENANCE.md) — the permission policy as a Zodiac constellation, its compiler and the committed artifact.

## How this repository works

- Agents draft most text and code. Humans decide, review and merge. Any contributor's agent may author a page; only listed humans verify one. Agents own no GitHub accounts: the human who runs an agent opens its pull request ([ADR 012](docs/adr/012-contributing-with-many-agents.md)).
- Every page in `docs/` records its sources, who produced it, who verified it, and its review status.
- An accepted ADR is an engineering decision. It authorises nothing on chain. On-chain change still needs the vote, motion or signature that the system defines.
- CI validates the bundle and checks that the generated files are fresh builds: the document-status register, the log, the onboarding guide and the policy artifact. It checks every control of the guide in a browser, refuses restricted terms and secrets, checks every source file's licence and every invariant's tests, and runs again in the merge queue on the merged result.

## Commands

```sh
just setup                  # once: forge-std, the policy's packages, a headless Chromium, a build
just check                  # everything that CI runs, except the fork suite
just regen                  # rebuild the generated files: the policy artifact, the log, the status register, the guide
just log Update "TEXT"      # add the change's log entry as a fragment in docs/log.d/
just test-fork              # the fork suite on the pinned mainnet fork; needs RPC in .env
just --list                 # every recipe
```

Without just installed, `uvx --from rust-just==1.58.0 just <recipe>` runs any recipe. The recipes run each script through uv with pinned dependencies. The mainnet recipes of the dry-run kit are in `mainnet.just`, for humans only (see [CONTRIBUTING.md](CONTRIBUTING.md)).

## Licence

AGPL-3.0-or-later. Files derived from Easy Track keep GPL-3.0; GPL-3.0 section 13 permits combining them with AGPL-3.0 code.
