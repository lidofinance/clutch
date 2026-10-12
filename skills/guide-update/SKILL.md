---
name: guide-update
description: Change the Clutch onboarding guide (docs/onboarding/clutch-onboarding.html) — its content, tabs, style or script — and keep its build and browser tests green. Use when a decision, role, permission, flow or runbook changes, or when EM asks for a change to the guide.
license: AGPL-3.0-or-later
---

# Update the Clutch onboarding guide

1. Change the text in `docs/onboarding/content/*.yaml`, the style and script in `docs/onboarding/src/`, and the builder in `scripts/build_onboarding.py`. Never edit the HTML file.
2. Every claim carries `sources` that resolve: an ADR decision (`ADR-007#d27`) or ADR section (`ADR-007#proposed-direction`), an OD, an invariant, a test, a runbook, a LIP part or a file with an anchor. Cite the decisions that the claim rests on, never a whole ADR. `uv run --with pyyaml python scripts/build_onboarding.py --list-sources` lists them. Check each claim against its source before you write it.
3. Keep restricted content out: no figure from the unapproved mandate or the request for solution, no vendor name, no stand-in address. The build refuses some of these.
4. Build: `just regen`. Then run `just check-docs` and `just check-browser`.
5. If the build reports a stale pin, run `just stale`. Read each stale item next to the change of its sources, and fix the item if the change makes it wrong. Then run `just repin <item>` for each item that you reviewed, and commit `docs/onboarding/pins.json` with the change. Never pin an item that you did not read against its source change. Name in the pull request each item that you pinned again while its text stayed the same.
6. A new ADR, invariant, LIP part or runbook needs a citation in the guide, or an entry with a reason in `docs/onboarding/content/coverage.yaml`. A new box or arrow on the map needs a flow step or a tour scene that lights it.
7. A new control gets its own browser test in `scripts/test_onboarding_page.py`. A new build check gets a negative case in `scripts/test_build_onboarding.py`. Break the page on purpose once to see the new test fail, then restore it. To test a broken copy of the page, set `ONBOARDING_PAGE` to its path.
8. Look at the result: screenshot the changed tab in the light and the dark theme, in Plain and in Technical, in print and at phone width.
9. Update `docs/onboarding/guide.md` when the guide gains a tab, a control or a check. Add a log fragment with `just log Update "..."`.
