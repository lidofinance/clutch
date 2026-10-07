<!-- One decision or one feature per pull request (ADR 012). Keep every section. -->

## What and why

<!-- What changes, and the decision, open decision or request behind it (ADR, OD, decision-log heading). -->

## Agent

<!-- The agent in `generated.by`, or "none". Agents own no GitHub accounts: a human opens this pull request and answers for it (ADR 012). -->

## What a human must check

<!-- The claims, figures or permissions that need a human eye, with the page and the source. -->

## Checks

- [ ] `just regen` ran, and the generated files are committed
- [ ] `just check` passes (paste the last line of each check, or name the one that cannot run here)
- [ ] `just test-fork` passes, or the change does not touch `src/`, `script/`, `test/` or `policy/`
- [ ] A log fragment in `docs/log.d/` describes the change (`just log KIND "TEXT"`)
- [ ] No restricted term, figure or secret: the screening vendor stays "the screening vendor", and no figure comes from the unapproved mandate
