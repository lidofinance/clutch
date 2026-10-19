---
type: Guide
title: Onboarding guide
description: How to open, build, maintain and test the interactive guide.
tags: [onboarding, guide, education]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T20:31:21Z
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

The [interactive guide](clutch-onboarding.html) explains Clutch to signers, engineers, reviewers, delegates and other teams [s1].

## Open the guide

Open the published address from the repository's Pages settings: `https://lidofinance.github.io/clutch/` for a public site.
CI publishes it from `main` [s10]. Or download `clutch-onboarding.html` and open it in a browser; GitHub shows HTML as source [s1].

The file works offline, makes no network request and stores nothing.
EM authorized publication ahead of the private repository on 2026-10-07 [s3][s10].
The banner and footer identify a hypothetical draft: nothing is deployed or ratified, figures can change, and the page is not advice.
The build requires this disclaimer. The page asks search engines not to index it.

## What it holds

The map has a ten-scene tour. Ten tabs cover actors, flows, mandate, constellation, RFP, reuse, assumptions, status, glossary and a nine-question self-check.
Flows play on the map step by step. Each claim links to its source and shows its status: existing, fork-tested, specified, open or planned.

| Tab | Content |
|---|---|
| Mandate | Each block's rule, controls, changes and reasons. Badges distinguish text owed, design choices and proposals [s5][s6]. The tab paraphrases only repository evidence about the private draft. The build rejects currency signs and percentages [s3]. |
| Constellation | Accounts, modifiers, roles, holders, target and call counts from the committed artifact [s4]. Specified but unbuilt parts and changes from the provider's constellation appear separately, with reasons [s5][s7]. |
| RFP | Each original ask, its answer and verdict: asked, changed or unanswered. Changed asks have reasons; each part lists additions. The research note records the asks [s8][s9]. |

Plain and Technical detail levels apply to tabs and tour scenes.
Technical adds addresses, permissions, signatures and implementation notes [s5]. Light and dark themes are available.
A text list repeats the map's boxes and arrows, so tooltips contain no exclusive facts.
The full page works without JavaScript and prints with all sections open. On phones, tabs scroll in one row.

The guide omits personal names, unannounced counterparties, financial figures and fork stand-in addresses.
The screening vendor stays "[the screening vendor]".

## How it is built

Edit text in `docs/onboarding/content/`, and styles or scripts in `docs/onboarding/src/`.
`scripts/build_onboarding.py` generates the HTML [s2]. Do not edit the HTML by hand.

The build reads ADR titles and states, open decisions, invariants, runbooks, LIP status labels, roadmap, document review states and the policy artifact [s4].
It rejects these inputs [s11]:

- Unresolved decisions, invariants, tests, runbooks, LIP parts, files or headings; references to a whole ADR.
- Duplicate content keys or glossary links without terms.
- Addresses absent from `docs/`, the constellation and `script/`; fork stand-in addresses.
- Unknown mandate states, control layers or constellation change kinds; currency signs or percentages in mandate content.
- RFP asks that differ from the research note, unknown verdicts or changed asks without reasons.

The guide must cite each ADR, invariant, LIP part and runbook, or exclude it with a reason in `content/coverage.yaml` [s11].
A flow or tour scene must light each map box and traverse each arrow [s11].
CI rejects HTML that differs from a fresh build [s2].

```sh
just regen       # rebuild the guide and other generated files
just check-docs  # check freshness, references and build validation
```

## Pins

Each guide item has a pin in `pins.json`: hashes of its content and cited source text [s11].
Pin the evidence for the claim, with these reference forms [s11][s12]:

| Reference | Text pinned |
|---|---|
| `ADR-007#d27` | Decision 27 and other Decision blocks that name it, including replacements |
| `ADR-007#proposed-direction` | The named section |
| OD, invariant or runbook | Its table row |
| Test | Its function |
| LIP part | Its section |
| File | Its section or the whole file |

If an item or source changes, the build fails. To resolve it:

1. Run `just stale` to see stale items and source diffs.
2. Read each item beside its source diff. Correct the text if required.
3. Run `just repin <item>` after review.
4. Commit `pins.json` with the change.

For a `pins.json` merge conflict, take `main`'s version and repeat these steps.
The pull request summary lists changed pins, with unchanged items whose sources changed first.
The author confirms that these items remain true; the reviewer checks that claim.

```sh
just stale
just repin actor:committee
uv run --with pyyaml python scripts/build_onboarding.py --list-sources
```

## How it is tested

`scripts/test_build_onboarding.py` checks that invalid inputs fail with the expected errors.
`scripts/test_onboarding_page.py` uses Playwright and headless Chromium. Expected results come from the content and repository [s1].

| Coverage | Checks |
|---|---|
| Controls and navigation | Theme and detail switches in tabs and panels; tabs and arrow keys; deep links; tour and keys; flow steps; lit boxes and arrows; tour Play chips; map boxes by mouse, keyboard and touch; tooltips; glossary and jump links; permission tables; mandate counts and changes; constellation graph and changes; RFP counts, asks, reasons and additions; quiz and score; skip link |
| Layout and runtime | Print, phones, reduced motion and no JavaScript; no box or arrow-label overlap; no network requests or console errors |
| Accessibility | axe-core in each tab and both themes, with the player open and closed |

Two groups check presentation invariants [s11][s12]:

- `matrix`: axe-core checks all content in twelve states across screen/print, system colours, Auto/opposite themes and JavaScript availability. It also rejects text with its background's colour, even if axe-core marks the result incomplete.
- `static`: without JavaScript, visible elements cannot have inactive widget roles, non-native tab stops, pressed/selected/expanded/controls states or links without targets. JavaScript adds button and tab roles.

Each group first proves that it catches a planted defect.
Set `ONBOARDING_PAGE` for another HTML copy, or `ONBOARDING_CHROMIUM` for another Chromium.

CI runs both scripts on each pull request, retains the built page for 14 days and reports pin changes.
A scheduled job checks external links each Monday [s11].

```sh
just setup          # install tools, including headless Chromium
just check-browser  # run all browser groups
uv run --with pyyaml==6.0.2 --with playwright==1.63.0 --with axe-playwright-python==0.1.8 \
    python scripts/test_onboarding_page.py [group ...]
```

## Rules

Update guide content and commit rebuilt HTML in the same pull request as a changed decision, role, permission, flow or runbook [s2].
Script and style changes must pass browser tests. Add a test for each new control in the same pull request.

`@lidofinance/defi-tech` owns the guide. EM accepts its first version.
The committee reviews operation, funding and reporting. The Emergency Brakes multisig reviews its own duties [s1].
