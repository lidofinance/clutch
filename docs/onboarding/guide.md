---
type: Guide
title: Onboarding guide
description: How to open, build, maintain and test the interactive guide.
tags: [onboarding, guide, education]
status: draft
review_status: slop
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:27:15Z
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
    title: ADR 001 — the repository is public, and nothing enters it that could not be published (decision 10)
  - id: s4
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the committed policy artifact that the guide reads
  - id: s5
    resource: /registers/decision-log.md
    title: Decision log — EM's request for the mandate and constellation tabs, the detail switch and the console error, 2026-10-06
  - id: s6
    resource: /specs/lip-draft.md
    title: LIP draft, open item 2 — the mandate text owed, sorted into the Snapshot text and the forum post (OD-90)
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

The [interactive guide](clutch-onboarding.html) explains Clutch to signers, engineers, reviewers, delegates and other teams [s1].

## Open the guide

Open `https://lidofinance.github.io/clutch/`, which CI publishes from `main` [s10]. Or download `clutch-onboarding.html` and open it in a browser; GitHub shows HTML as source [s1].

The file works offline, makes no network request and stores nothing. It works without JavaScript and prints with all sections open. A text list repeats the map's boxes and arrows, so tooltips contain no exclusive facts.
Its banner and footer identify a hypothetical draft: nothing is deployed or ratified, figures can change, and the page is not advice. The build requires this disclaimer, and the page asks search engines not to index it [s10].

## What it holds

The map has a ten-scene tour. Ten tabs cover actors, flows, mandate, constellation, RFP, reuse, assumptions, status, glossary and a nine-question self-check.
Flows play on the map step by step. Each claim links to its source and shows its status: existing, fork-tested, specified, open or planned.
Plain and Technical detail levels apply to tabs and tour scenes; Technical adds addresses, permissions, signatures and implementation notes [s5].

| Tab | Content |
|---|---|
| Mandate | Each block's rule, controls, changes and reasons. Badges distinguish Snapshot text owed, forum-post items, design choices and proposals [s5][s6]. The tab paraphrases only repository evidence about the private draft [s3]. |
| Constellation | Accounts, modifiers, roles, holders, target and call counts from the committed artifact [s4]. Specified but unbuilt parts and changes from the provider's constellation appear separately, with reasons [s7]. |
| RFP | Each original ask, its answer and verdict: asked, changed or unanswered. The research note records the asks [s8][s9]. |

The guide omits personal names, unannounced counterparties, figures from the mandate or the attested computation, and fork stand-in addresses. Its only dollar figure is the launch cap, which EM set (OD-55).
The screening vendor stays "[the screening vendor]".

## How it is built

Edit text in `docs/onboarding/content/`, and styles or scripts in `docs/onboarding/src/`. `scripts/build_onboarding.py` generates the HTML [s2]; never edit the HTML by hand.

The build reads ADR titles and states, open decisions, invariants, runbooks, LIP status labels, the roadmap, document review states and the policy artifact [s4].
It rejects these inputs [s11]:

- Unresolved decisions, invariants, tests, runbooks, LIP parts, files or headings; a reference to a whole ADR, or to a decision line that only names what replaced it or what states it.
- Duplicate content keys, or glossary links without terms.
- Addresses absent from `docs/`, the constellation and `script/`; fork stand-in addresses.
- Unknown mandate states, control layers or constellation change kinds; currency signs or percentages in mandate content.
- RFP asks that differ from the research note, unknown verdicts, or changed asks without reasons.
- An ADR, invariant, LIP part or runbook that the guide neither cites nor excludes with a reason in `content/coverage.yaml`.
- A map box that no flow step or tour scene lights, or an arrow that none walks.

CI rejects HTML that differs from a fresh build [s2].

## Pins

Each guide item has a pin in `pins.json`: hashes of its content and of the source text that it cites [s11].
Cite the evidence for the claim, in these forms [s11][s12]:

| Reference | Text pinned |
|---|---|
| `ADR-007#d27` | Decision 27 and the other Decision blocks that name it |
| `ADR-007#proposed-direction` | The named section |
| OD, invariant or runbook | Its register entry or table row |
| Test | Its function |
| LIP part | Its section |
| File | Its section or the whole file |

If an item or a source changes, the build fails until a reviewer reads the item beside the source change and pins it again. The [guide-update procedure](https://github.com/lidofinance/clutch/blob/main/skills/guide-update/SKILL.md) gives the steps.
For a `pins.json` merge conflict, take `main`'s version and review again.
The CI job summary on a pull request lists changed pins, with unchanged items whose sources changed first. The author confirms that these items remain true; the reviewer checks that claim.

```sh
just regen       # rebuild the guide and the other generated files
just stale       # list stale items with the change of each source
just repin actor:committee
uv run --with pyyaml python scripts/build_onboarding.py --list-sources
```

## How it is tested

`scripts/test_build_onboarding.py` checks that invalid inputs fail with the expected errors.
`scripts/test_onboarding_page.py` drives headless Chromium; its expected results come from the content and the repository [s1]. It covers every control, the layout in print and on phones, reduced motion, the page without JavaScript, network requests, console errors, and axe-core in each tab and both themes.

Two groups check presentation invariants, and each first proves that it catches a planted defect [s11][s12]:

- `matrix`: axe-core checks all content in twelve states. Each state combines screen or print, light or dark system colours, and one of three configurations: JavaScript in Auto, JavaScript in the opposite theme, or no JavaScript in Auto. It also rejects text with its background's colour.
- `static`: without JavaScript, visible elements cannot have widget roles, non-native tab stops, pressed, selected, expanded or controls states, or links without targets. JavaScript adds button and tab roles.

CI runs both scripts on each pull request, attaches the built page for 14 days and reports pin changes. A scheduled job checks external links each Monday [s11].

```sh
just check-docs     # freshness, references and build validation
just check-browser  # every browser group; `just setup` installs headless Chromium
```

Set `ONBOARDING_PAGE` to test another HTML copy, or `ONBOARDING_CHROMIUM` for another Chromium.

## Rules

Update the guide's content and commit the rebuilt HTML in the same pull request as a changed decision, role, permission, flow or runbook [s2].
Script and style changes must pass the browser tests. Add a test for each new control in the same pull request.

`@lidofinance/defi-tech` owns the guide. EM accepts its first version.
The committee reviews operation, funding and reporting. The Emergency Brakes multisig reviews its own duties [s1].
