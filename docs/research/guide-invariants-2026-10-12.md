---
type: Research Note
title: The onboarding guide's tests and pins, 2026-10-12
description: The evidence behind ADR 012 decision 11 — two defect classes that the review of another Lido guide found, probed on this guide's page; the churn of pins on whole ADRs; the move to decision-level references; and the drift that the move found.
tags: [onboarding, testing, accessibility, provenance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-12
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-12T07:53:08Z
verified: []
sources:
  - id: s1
    resource: "urn:clutch:restricted:guide-review-2026-10-12"
    title: The review of another Lido onboarding guide, the findings of an automated reviewer on it and their fixes, in a private repository; read on 2026-10-12; outside the repository
  - id: s2
    resource: /registers/decision-log.md
    title: Decision log — EM's request for a triage of the guide's tests, and EM's answer, 2026-10-12
  - id: s3
    resource: /onboarding/guide.md
    title: Onboarding guide — the build's checks, the pins and the browser tests
  - id: s4
    resource: /adr/012-contributing-with-many-agents.md
    title: ADR 012 — decision 11, the guide's invariant checks, source pins and coverage
---

# The onboarding guide's tests and pins, 2026-10-12

## Answer

- Another Lido onboarding guide was reviewed in October 2026. An automated reviewer found four defects in it. Two of the defect classes were also in this guide: text with the colour of its own background in print, and widget roles on the page without its script [s1].
- On this guide at `main` 5c7e68b, 3 of 12 presentation states failed axe-core, and the page without its script had 48 elements that looked interactive and did nothing. The page of this change passes in all 12 states and has no such element.
- Two browser layers now check these properties in every state, not examples in one state. Each layer first proves that it catches a planted defect [s3].
- Each item of the guide is now pinned to the text that its sources hold. A pin on a whole ADR follows its whole Decision section, so every new decision would flag every item that cites the ADR. The guide's references now name decisions and sections. On the ADR changes of 2026-10-09, whole-ADR pins would have flagged 192 of 252 items, and the new references flag 159.
- Mapping each reference to its decisions found nine places where the guide was behind the decisions of 2026-10-09. This change fixes them.
- EM asked for all of it in one pull request, with no part deferred [s2][s4].

## The two defect classes

The other guide's review found these defects, and its fixes are the model for this change [s1]:

- **The dark palette in print.** The page took its dark colours from the system or from the theme switch, also in print. Print set only a white page background. The text stayed light, so it printed with the colour of its background. axe-core reports a contrast of 1:1 as "incomplete", not as a violation, because hidden text can have that contrast on purpose. A check of violations alone therefore misses it.
- **Widget roles without the script.** The page gave tabs and panels their roles in its HTML. Without the script, a reader heard a tab list that did nothing. The roles now come from the script, and the tabs are plain links to their sections until it runs.

## The probe of this guide

Command, with the test script of this change:

```sh
git show 5c7e68b:docs/onboarding/clutch-onboarding.html > /tmp/clutch-guide-main.html
ONBOARDING_PAGE=/tmp/clutch-guide-main.html uv run --with pyyaml==6.0.2 --with playwright==1.63.0 \
    --with axe-playwright-python==0.1.8 python scripts/test_onboarding_page.py matrix static
```

Result on 2026-10-12: 12 passed, 4 failed.

- Three states failed: the dark theme in print on a light system, and Auto in print on a dark system, with the script and without it. In each, 215 elements failed axe-core's colour-contrast rule, and 210 elements, the page title among them, had the colour of their background.
- The page without its script had 48 findings: 17 map boxes with the role of a button, 10 tabs, 10 tab panels and their tab list, and 10 tabs that named the panel that they control.
- Both self-tests passed: the matrix layer caught planted white-on-white text, and the static layer caught a planted tab role.

The fixes:

- The dark palette applies only on screens. Print always uses the light palette.
- The page gives no element a widget role. The script makes the tabs a tab widget and each map box a button. Without the script, a map box is a labelled image.

With the same command and no `ONBOARDING_PAGE`, all 16 checks of the two layers pass, and the whole browser suite passes 193 of 193.

## Pins and their churn

- On `main` at 5c7e68b, 303 source lists of the guide cited a whole ADR, 414 times. ADR 005 had 89 of these citations, ADR 009 75 and ADR 007 50.
- A whole-ADR pin follows the ADR's Decision section. Each interview adds decisions, so each one would flag most items for a review that changes nothing. Reviewers would learn to pin again without reading.
- The guide now cites what each claim rests on: 932 references to single decisions, and 239 to sections, mostly the Proposed direction (183) and the Context (50). The build refuses a whole ADR.
- A later decision often replaces an earlier one and leaves the earlier text as it was, for example "Decision 31 replaces decision 5" in ADR 009. A decision's pin therefore also holds every other block of the Decision section that names it. A new decision that names no earlier decision flags nothing.
- Measured on the ADR changes from 878377a to 5c7e68b, which changed the Decision sections of six ADRs: whole-ADR pins would have flagged 192 of 252 items, the new references flag 159, and the decision references alone flag 80. Most of the rest cite a Proposed direction, which that change also rewrote. A finer pin, on one entry of a Proposed direction, is possible later; this change does not add it.
- The mapping dropped six references that supported nothing in their item, and added four that were missing.

## Drift that the mapping found

The guide was behind two decisions of 2026-10-09 in nine places. This change fixes them:

- OD-57, one modifier on the orders account: the Emergency Brakes multisig's card, the technical role's card, the cap-breach flow, a self-check answer, the reuse row of the modifiers and the glossary entry still described a second operator modifier there. On the orders account, the technical role removes the operator Safe from the operator role.
- OD-54, the capped launch: the top-up flow, the seed flow and the glossary's seed did not say that top-ups and the seed stay at or below the cap until it lifts. The vendor-outage flow also says now that it applies once the guard is set.

One more difference is not fixed here. The repository card says that the repository stays private until deployment, as ADR 001 decision 4 says, but GitHub's API reports the repository as public (checked 2026-10-12). Both texts need EM's record of the change.

## Also in this change

- A weekly job checks every outside link of the published page. Links into this repository must name a file that exists and a heading that exists.
- Each pull request gets the built page as an artifact, and a job summary of its pin changes. Items whose sources changed while their text stayed the same come first.
- `zizmor` checks the workflows for unsafe patterns.
