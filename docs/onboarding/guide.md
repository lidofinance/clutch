---
type: Guide
title: Onboarding guide
description: One interactive page that explains Clutch to signers, engineers, reviewers and other teams — a system map with a guided tour, actor cards, flows that play on the map, assumptions, what is reused and what is new, status, a glossary and a self-check — generated from the repository and checked by CI.
tags: [onboarding, guide, education]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T13:05:14Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's request for the onboarding guide and the answers to the interview, 2026-10-06 (OD-37)
  - id: s2
    resource: /specs/specification-policy.md
    title: Specification policy — the onboarding guide is generated, and a change updates it in the same pull request
  - id: s3
    resource: /adr/001-repository-scope-visibility-licence-name.md
    title: ADR 001 — the repository is private until deployment, and nothing enters it that could not be published then
  - id: s4
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the committed policy artifact that the guide reads
---

# Onboarding guide

The onboarding guide is one interactive page that explains Clutch to everyone who needs the picture: signers, engineers, reviewers, delegates and other teams [s1]. It is the file [clutch-onboarding.html](clutch-onboarding.html).

## Open the guide

- Get the file from the repository and open it in a browser. GitHub shows an HTML file as source code, so it does not show the page [s1].
- The page is one self-contained file. It makes no network request and stores nothing, so it works offline.
- The page is written to the publication standard. It goes public with the repository at deployment, not before [s1][s3].

## What it holds

- A map of the system. A guided tour of ten scenes plays on the map for readers who are new to it.
- Seven tabs: the actors, the flows, what Clutch reuses and what it adds, the assumptions, the status, a glossary and an optional self-check of eight questions. Each flow can play on the map step by step.
- Each element shows its status: whether it exists today, is built and tested on a fork, is specified, is open or is planned. Each claim links to its source in the repository.
- A Plain and a Technical detail level, and a light and a dark theme. The page reads in full without JavaScript, and it prints.
- It leaves out the names of people, any unannounced counterparty, every financial figure and the fork tests' stand-in addresses. The screening vendor stays "[the screening vendor]".

## How it is built

- The text lives in `docs/onboarding/content/`, the style and the script in `docs/onboarding/src/`. The script `scripts/build_onboarding.py` writes the page [s2].
- The build reads the facts that the repository already states: the titles and states of the decision records, the open decisions, the invariants, the runbooks, the status labels of the LIP, the roadmap, the review state of every page, and the roles and permissions of the committed policy artifact [s4].
- The build fails when a reference to a decision, an invariant, a test, a runbook, a LIP part, a file or a heading does not resolve. It also fails when a content file repeats a key, when a glossary link has no term, when an address is not already recorded in `docs/`, in the constellation or in `script/`, or when a fork-test stand-in address reaches the page.
- CI fails when the committed page differs from a fresh build [s2].

```sh
uv run --with pyyaml python scripts/build_onboarding.py           # write the page
uv run --with pyyaml python scripts/build_onboarding.py --check   # fail if the page is stale
uv run --with pyyaml python scripts/test_build_onboarding.py      # test the build's checks
```

## Rules

- A pull request that changes a decision, a role, a permission, a flow or a runbook updates the guide's content and commits the rebuilt page in the same pull request [s2].
- Nobody edits the HTML file by hand. Agents regenerate it from the content files.
- `@lidofinance/defi-tech` owns the guide. EM accepts the first version. The Treasury Management Committee reviews the sections on operation, funding and reporting. The Emergency Brakes multisig reviews the sections on its duties [s1].
