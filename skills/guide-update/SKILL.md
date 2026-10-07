---
name: guide-update
description: Change the Clutch onboarding guide (docs/onboarding/clutch-onboarding.html) — its content, tabs, style or script — and keep its build and browser tests green. Use when a decision, role, permission, flow or runbook changes, or when EM asks for a change to the guide.
license: AGPL-3.0-or-later
---

# Update the Clutch onboarding guide

1. Change the text in `docs/onboarding/content/*.yaml`, the style and script in `docs/onboarding/src/`, and the builder in `scripts/build_onboarding.py`. Never edit the HTML file.
2. Every claim carries `sources` that resolve: an ADR, an OD, an invariant, a test, a runbook, a LIP part or a file with an anchor. Check each claim against its source before you write it.
3. Keep restricted content out: no figure from the unapproved mandate or the request for solution, no vendor name, no stand-in address. The build refuses some of these.
4. Build: `just regen`. Then run `just check-docs` and `just check-browser`.
5. A new control gets its own browser test in `scripts/test_onboarding_page.py`. A new build check gets a negative case in `scripts/test_build_onboarding.py`. Break the page on purpose once to see the new test fail, then restore it.
6. Look at the result: screenshot the changed tab in the light and the dark theme, in Plain and in Technical, and at phone width.
7. Update `docs/onboarding/guide.md` when the guide gains a tab, a control or a check. Add a log fragment with `just log Update "..."`.
