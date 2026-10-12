---
type: Guide
title: Onboarding guide
description: One interactive page that explains Clutch to signers, engineers, reviewers and other teams — a system map with a guided tour, actor cards, flows that play on the map, the mandate block by block, the constellation, the request for solution ask by ask, assumptions, what is reused and what is new, status, a glossary and a self-check — generated from the repository and checked by CI.
tags: [onboarding, guide, education]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-12T07:50:11Z
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
  - id: s8
    resource: /registers/decision-log.md
    title: Decision log — EM's request for an analysis of the RFP in the guide, 2026-10-07
  - id: s9
    resource: /research/request-for-solution-2026-10-07.md
    title: Research note — what the request for solution asked
  - id: s10
    resource: /adr/012-contributing-with-many-agents.md
    title: ADR 012 — decision 10, the guide on GitHub Pages with its draft disclaimer
  - id: s11
    resource: /adr/012-contributing-with-many-agents.md
    title: ADR 012 — decision 11, the guide's invariant checks, source pins and coverage
  - id: s12
    resource: /research/guide-invariants-2026-10-12.md
    title: Research note — the guide's defects in print and without its script, and the churn of whole-ADR pins
---

# Onboarding guide

The onboarding guide is one interactive page that explains Clutch to everyone who needs the picture: signers, engineers, reviewers, delegates and other teams [s1]. It is the file [clutch-onboarding.html](clutch-onboarding.html).

## Open the guide

- Open the published page on GitHub Pages, at the address in the repository's Pages settings: `https://lidofinance.github.io/clutch/` for a public site. A CI workflow publishes it from `main` [s10].
- Or get the file from the repository and open it in a browser. GitHub shows an HTML file as source code, so it does not show the page [s1].
- The page is one self-contained file. It makes no network request and stores nothing, so it works offline.
- The page is written to the publication standard. EM decided on 2026-10-07 to publish it ahead of the repository, which stays private until deployment [s3][s10]. Its banner and footer say that it is a hypothetical draft: nothing is deployed or ratified, every number can change, and it is not advice. The build refuses a page without that disclaimer, and the page asks search engines not to index it.

## What it holds

- A map of the system. A guided tour of ten scenes plays on the map for readers who are new to it.
- Ten tabs: the actors, the flows, the mandate, the constellation, the RFP, what Clutch reuses and what it adds, the assumptions, the status, a glossary and an optional self-check of nine questions. Each flow can play on the map step by step.
- The Mandate tab shows each block of the mandate draft as a card: what the draft says, how Clutch keeps the rule on each layer, and what Clutch changed and why. A badge and a coloured border mark each change as mandate text owed, a design choice or proposed [s5][s6]. The draft is not public, so the tab paraphrases only what the repository records about it, and the build refuses a currency sign or a percentage in it [s3].
- The Constellation tab draws the built policy from the committed artifact: the Asset Safe, its two modifiers and their roles, with each role's holder and its count of targets and calls [s4]. It lists the parts that are specified but not built, and a table of what Clutch changed from the policy provider's constellation, each change with its kind and its reason [s5][s7].
- The RFP tab takes the request for solution that Lido contributors sent to the policy provider, part by part. Each ask shows how Clutch answers it, marked as asked, changed or not answered yet, with the reason for each change, and each part lists what Clutch added. A research note records the asks [s8][s9].
- Each element shows its status: whether it exists today, is built and tested on a fork, is specified, is open or is planned. Each claim links to its source in the repository.
- A Plain and a Technical detail level, and a light and a dark theme. Technical adds contract addresses, exact permissions, function signatures and implementation notes, in the tabs and in every scene of the tour [s5]. The map is also a list of its boxes and arrows, so no tooltip holds the only copy of a fact. The page reads in full without JavaScript, works on a phone, where the tabs keep one row that scrolls sideways, and prints with every section open.
- It leaves out the names of people, any unannounced counterparty, every financial figure and the fork tests' stand-in addresses. The screening vendor stays "[the screening vendor]".

## How it is built

- The text lives in `docs/onboarding/content/`, the style and the script in `docs/onboarding/src/`. The script `scripts/build_onboarding.py` writes the page [s2].
- The build reads the facts that the repository already states: the titles and states of the decision records, the open decisions, the invariants, the runbooks, the status labels of the LIP, the roadmap, the review state of every page, and the roles and permissions of the committed policy artifact [s4].
- The build fails when a reference to a decision, an invariant, a test, a runbook, a LIP part, a file or a heading does not resolve, or when a reference names a whole ADR instead of a decision or a heading of it [s11]. It also fails when a content file repeats a key, when a glossary link has no term, when an address is not already recorded in `docs/`, in the constellation or in `script/`, or when a fork-test stand-in address reaches the page. It fails when a mandate change has an unknown state, a control line names an unknown layer, a constellation change has an unknown kind, or the mandate content holds a currency sign or a percentage. It fails when an RFP ask is not in the research note word for word, an ask has an unknown verdict, or a changed ask has no reason.
- Every ADR, invariant, LIP part and runbook is cited by the guide, or `content/coverage.yaml` excludes it with a reason. Every box of the map is lit, and every arrow is walked, by some flow step or tour scene [s11].
- CI fails when the committed page differs from a fresh build [s2].

```sh
just regen          # write the page, with the other generated files
just check-docs     # among other checks: fail if the page is stale, and test the build's checks
```

## Pins

- Each item of the guide, such as an actor card, a flow, a scene, an assumption or an RFP part, is pinned in `pins.json`. The pin holds the hash of the item's content and the hash of the text that each of its sources pins [s11].
- A reference pins only what the claim rests on. `ADR-007#d27` pins decision 27, with every other block of the Decision section that names it, so a later decision that replaces decision 27 changes the pin. `ADR-007#proposed-direction` pins that section. An OD, an invariant or a runbook pins its table row, a test pins its function, a LIP part pins its section, and a file reference pins its section or the whole file [s11][s12].
- The build fails when an item or one of its sources differs from its pin. Then:
  1. Run `just stale`. It lists each stale item, with the change of each source since the pins were last committed.
  2. Read the item next to the change. Fix the item if the change makes it wrong.
  3. Run `just repin <item>`, and commit `pins.json` with the change.
- On a pull request, the job summary lists the pins that changed. Items whose source changed while their text stayed the same come first: the author says that the text is still true, and the reviewer checks it.

```sh
just stale                       # each stale item, with the source changes
just repin actor:operator-safe   # pin an item again, after the review
uv run --with pyyaml python scripts/build_onboarding.py --list-sources   # every decision and heading that content can cite
```

## How it is tested

- `scripts/test_build_onboarding.py` tests the build's checks: each one refuses a broken input with its own message.
- `scripts/test_onboarding_page.py` drives the committed page in headless Chromium with Playwright. It takes what to expect from the content and the repository, so a changed scene, flow, box or question changes its test with it [s1].
- The browser tests cover every control: the theme switch, the detail switch in every tab and in the panel, the tabs and their arrow keys, links to any part of the page, the guided tour and its keys, each flow's steps and the boxes and arrows that each step lights, the tour's Play chips, every box on the map by mouse, keyboard and touch, the tooltips, the glossary links, the jump lists, the permission tables, the mandate's counts and changes, the constellation's graph against the artifact and its table of changes, the RFP's counts, parts, asks, reasons and additions, the self-check and its score, and the skip link.
- They also check the page without JavaScript, in print, on a phone-sized screen and with reduced motion; that no two boxes or arrow labels on the map overlap; that axe-core finds no accessibility violation in any tab, in either theme, with the player open or closed; and that the page makes no network request and logs no error.
- Two groups check invariants in every state, not examples in one [s11][s12]:
  - `matrix` runs axe-core on the whole content in twelve states. A state is screen or print, a light or a dark system colour scheme, and the page with its script, in the Auto theme or the theme that differs from the system, or without its script, in Auto. It also fails on text that has the colour of its own background, which axe-core reports only as "incomplete".
  - `static` reads the page without its script. Nothing may look interactive and do nothing: no visible element may carry a widget role, a tab stop that is not a native control, a pressed, selected, expanded or controls state, or a link without a target. The script adds the tab and button roles.
  - Each of the two first proves that it catches a planted defect.
- Set `ONBOARDING_PAGE` to test another copy of the page, for example one with a planted defect, and `ONBOARDING_CHROMIUM` to use another Chromium.
- CI runs both test scripts on every pull request. It attaches the built page to the pull request for 14 days, and writes the pin changes into the job summary. A scheduled job checks the page's outside links every Monday [s11].

```sh
just setup          # once: installs the headless Chromium, among other tools
just check-browser  # the browser tests
uv run --with pyyaml==6.0.2 --with playwright==1.63.0 --with axe-playwright-python==0.1.8 \
    python scripts/test_onboarding_page.py [group ...]   # only the named groups
```

## Rules

- A pull request that changes a decision, a role, a permission, a flow or a runbook updates the guide's content and commits the rebuilt page in the same pull request [s2].
- A change to the page's script or style keeps the browser tests passing, and a new control gets its own test in the same pull request.
- Nobody edits the HTML file by hand. Agents regenerate it from the content files.
- `@lidofinance/defi-tech` owns the guide. EM accepts the first version. The Treasury Management Committee reviews the sections on operation, funding and reporting. The Emergency Brakes multisig reviews the sections on its duties [s1].
