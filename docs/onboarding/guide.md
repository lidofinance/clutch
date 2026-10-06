---
type: Guide
title: Onboarding guide
description: One interactive page that explains Clutch to signers, engineers, reviewers and other teams — a system map with a guided tour, actor cards, flows that play on the map, the mandate block by block, the constellation, assumptions, what is reused and what is new, status, a glossary and a self-check — generated from the repository and checked by CI.
tags: [onboarding, guide, education]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T22:32:10Z
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
  - id: s5
    resource: /registers/decision-log.md
    title: Decision log — EM's request for the mandate and constellation tabs, the detail switch and the console error, 2026-10-06
  - id: s6
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — the eleven changes that the mandate text owes, and the control on each layer
  - id: s7
    resource: /research/zodiac-constellation-2026-10-06.md
    title: Research note — the policy provider's constellation and its differences from the decided design
---

# Onboarding guide

The onboarding guide is one interactive page that explains Clutch to everyone who needs the picture: signers, engineers, reviewers, delegates and other teams [s1]. It is the file [clutch-onboarding.html](clutch-onboarding.html).

## Open the guide

- Get the file from the repository and open it in a browser. GitHub shows an HTML file as source code, so it does not show the page [s1].
- The page is one self-contained file. It makes no network request and stores nothing, so it works offline.
- The page is written to the publication standard. It goes public with the repository at deployment, not before [s1][s3].

## What it holds

- A map of the system. A guided tour of ten scenes plays on the map for readers who are new to it.
- Nine tabs: the actors, the flows, the mandate, the constellation, what Clutch reuses and what it adds, the assumptions, the status, a glossary and an optional self-check of nine questions. Each flow can play on the map step by step.
- The Mandate tab shows each block of the mandate draft as a card: what the draft says, how Clutch keeps the rule on each layer, and what Clutch changed and why. A badge and a coloured border mark each change as mandate text owed, a design choice or proposed [s5][s6]. The draft is not public, so the tab paraphrases only what the repository records about it, and the build refuses a currency sign or a percentage in it [s3].
- The Constellation tab draws the built policy from the committed artifact: the Asset Safe, its two modifiers and their roles, with each role's holder and its count of targets and calls [s4]. It lists the parts that are specified but not built, and a table of what Clutch changed from the policy provider's constellation, each change with its kind and its reason [s5][s7].
- Each element shows its status: whether it exists today, is built and tested on a fork, is specified, is open or is planned. Each claim links to its source in the repository.
- A Plain and a Technical detail level, and a light and a dark theme. Technical adds contract addresses, exact permissions, function signatures and implementation notes, in the tabs and in every scene of the tour [s5]. The map is also a list of its boxes and arrows, so no tooltip holds the only copy of a fact. The page reads in full without JavaScript, works on a phone, and prints with every section open.
- It leaves out the names of people, any unannounced counterparty, every financial figure and the fork tests' stand-in addresses. The screening vendor stays "[the screening vendor]".

## How it is built

- The text lives in `docs/onboarding/content/`, the style and the script in `docs/onboarding/src/`. The script `scripts/build_onboarding.py` writes the page [s2].
- The build reads the facts that the repository already states: the titles and states of the decision records, the open decisions, the invariants, the runbooks, the status labels of the LIP, the roadmap, the review state of every page, and the roles and permissions of the committed policy artifact [s4].
- The build fails when a reference to a decision, an invariant, a test, a runbook, a LIP part, a file or a heading does not resolve. It also fails when a content file repeats a key, when a glossary link has no term, when an address is not already recorded in `docs/`, in the constellation or in `script/`, or when a fork-test stand-in address reaches the page. It fails when a mandate change has an unknown state, a control line names an unknown layer, a constellation change has an unknown kind, or the mandate content holds a currency sign or a percentage.
- CI fails when the committed page differs from a fresh build [s2].

```sh
uv run --with pyyaml python scripts/build_onboarding.py           # write the page
uv run --with pyyaml python scripts/build_onboarding.py --check   # fail if the page is stale
uv run --with pyyaml python scripts/test_build_onboarding.py      # test the build's checks
```

## How it is tested

- `scripts/test_build_onboarding.py` tests the build's checks: each one refuses a broken input with its own message.
- `scripts/test_onboarding_page.py` drives the committed page in headless Chromium with Playwright. It takes what to expect from the content and the repository, so a changed scene, flow, box or question changes its test with it [s1].
- The browser tests cover every control: the theme switch, the detail switch in every tab and in the panel, the tabs and their arrow keys, links to any part of the page, the guided tour and its keys, each flow's steps and the boxes and arrows that each step lights, the tour's Play chips, every box on the map by mouse, keyboard and touch, the tooltips, the glossary links, the jump lists, the permission tables, the mandate's counts and changes, the constellation's graph against the artifact and its table of changes, the self-check and its score, and the skip link.
- They also check the page without JavaScript, in print, on a phone-sized screen and with reduced motion; that no two boxes or arrow labels on the map overlap; that axe-core finds no accessibility violation in any tab, in either theme, with the player open or closed; and that the page makes no network request and logs no error.
- CI runs both test scripts on every pull request.

```sh
uv run --with playwright==1.63.0 python -m playwright install --only-shell chromium   # once
uv run --with pyyaml==6.0.2 --with playwright==1.63.0 --with axe-playwright-python==0.1.8 \
    python scripts/test_onboarding_page.py [group ...]                               # the browser tests
```

## Rules

- A pull request that changes a decision, a role, a permission, a flow or a runbook updates the guide's content and commits the rebuilt page in the same pull request [s2].
- A change to the page's script or style keeps the browser tests passing, and a new control gets its own test in the same pull request.
- Nobody edits the HTML file by hand. Agents regenerate it from the content files.
- `@lidofinance/defi-tech` owns the guide. EM accepts the first version. The Treasury Management Committee reviews the sections on operation, funding and reporting. The Emergency Brakes multisig reviews the sections on its duties [s1].
