---
type: Research Note
title: The onboarding guide's tests and pins, 2026-10-12
description: ADR 012 evidence on presentation defects, source-pin scope, pin churn and guide drift.
tags: [onboarding, testing, accessibility, provenance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-12
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:50:32Z
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

- A review of another Lido onboarding guide found two defect classes that this guide shared: text with the colour of its own background in print, and widget roles on the page without its script [s1].
- On this guide at `main` 5c7e68b, 3 of 12 presentation states failed axe-core, and the page without its script had 48 elements that looked interactive and did nothing.
- Two browser layers check these properties in every state. Each layer first proves that it catches a planted defect [s3].
- On the ADR changes of 2026-10-09, whole-ADR pins would have flagged 192 of 252 items. References to decisions and sections flag 159.
- EM asked for all of it in one pull request, with no part deferred [s2][s4].

## The two defect classes

- **The dark palette in print.** The text stayed light on a white print background, so it printed with the colour of its background. axe-core reports a contrast of 1:1 as "incomplete", not as a violation, so a check of violations alone misses it [s1]. The fix: print always uses the light palette.
- **Widget roles without the script.** The page gave tabs and panels their roles in its HTML. Without the script, a reader heard a tab list that did nothing [s1]. The fix: the roles come from the script.

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

With the same command and no `ONBOARDING_PAGE`, all 16 checks of the two layers pass, and the whole browser suite passes 193 of 193.

## Pins and their churn

- On `main` at 5c7e68b, 303 source lists of the guide cited a whole ADR, 414 times. ADR 005 had 89 of these citations, ADR 009 75 and ADR 007 50.
- A whole-ADR pin follows the ADR's Decision section, so each new decision would flag most items that cite the ADR.
- After the change, the guide held 932 references to single decisions, and 239 to sections, mostly the Proposed direction (183) and the Context (50). The build refuses a whole ADR.
- Measured on the ADR changes from 878377a to 5c7e68b, which changed the Decision sections of six ADRs: whole-ADR pins would have flagged 192 of 252 items, the new references flag 159, and the decision references alone flag 80. Most of the rest cite a Proposed direction, which that change also rewrote.
- The mapping dropped six references that supported nothing in their item, and added four that were missing.
