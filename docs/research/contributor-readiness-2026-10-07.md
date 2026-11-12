---
type: Research Note
title: The repository and many contributors with agents, 2026-10-07
description: ADR 012 evidence on shared-file changes, actors, CI, agent defaults and the keystore rehearsal.
tags: [contributors, agents, process, ci, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-07
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:50:32Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's question about more contributors and agents, and EM's answers by number, 2026-10-07
  - id: s2
    resource: /adr/003-agent-operating-model.md
    title: ADR 003 — the agent operating model, the protected files and OD-23
  - id: s4
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the hosted Zodiac app is outside the path; its key stays with the repository-owner team
---

# The repository and many contributors with agents, 2026-10-07

## Answer

- EM asked how to open the repository to more contributors who run their own agents [s1].
- The agent listed fifteen steps, and EM answered them by number on 2026-10-07 [s1]. ADR 012 records the decisions.

## Measurements

The repository was read at commit `13b521c` of the branch `decisions/2026-10-06-tmc-meeting`.

- History: 75 commits, 28 of them merges. A non-merge commit touched a median of 13 files and at most 52.
  - Command: `git log --no-merges --name-only --format='' | sort | uniq -c | sort -rn`
- The files that most non-merge commits touched, out of 47:

| File | Commits |
|---|---|
| `docs/log.md` | 33 |
| `docs/registers/document-status.md` (generated) | 32 |
| `docs/registers/decision-log.md` | 30 |
| `docs/registers/open-decisions.md` | 28 |
| `docs/specs/lip-draft.md` | 25 |
| `docs/specs/invariants.md` | 18 |
| `docs/registers/parameters.md` | 17 |

- `docs/log.md` and the decision log put new entries at the top, so two parallel pull requests always conflict on the same lines.
- `config/actors.yaml` listed one agent and three humans. The validator refused any other id in `generated.by` and in `verified` [s2].
- No command set up the tools or ran everything that CI runs. CI ran no Solidity test, no secret scan and no licence check.
- `Justfile` loaded `.env`, which held `PRIVATE_KEY`, and listed the mainnet `--broadcast` recipes `dry-run`, `fund` and `teardown` next to `test-fork`.
- The `push` and `pull` scripts of `policy/constellation/package.json` call the hosted Zodiac app with its API key. The rule that only the repository-owner team runs them was in ADR 004, not in `AGENTS.md` [s4].
- Restricted terms stayed out by convention and by manual scans.

## The fifteen steps

EM's numbers refer to this list [s1].

1. Safe defaults: the mainnet recipes in their own file, behind a flag and a prompt; keystore signing; a guard on the hosted-app scripts; both rules in `AGENTS.md`.
2. Contributor identity: any agent id may author a page, only listed humans verify, and human reviewer ids join the list by role.
3. One command each to set up, to run every CI check, and to rebuild every generated file.
4. `CODEOWNERS` by risk, and a check of the branch rule.
5. A check for restricted terms and secrets in CI, with a list that holds only hashes.
6. One file per log entry, so that the log is built and never edited.
7. A merge queue, or branches that must be up to date, so that the checks run on the merged result.
8. Generated files marked as generated, and rebuilt instead of merged.
9. ID reservation, and a validator check for an ID that is used twice.
10. A content hash in each verification, so that an edit to a verified page fails until it is verified again.
11. A pull-request template and a scope rule.
12. Skills for the recurring procedures, and `CONTRIBUTING.md`.
13. The fork suite, the licence check and the invariant-to-test check in CI.
14. Decision intake: an agent opens a decision only with its options and a recommendation; EM triages; batched interviews; one decisions branch at a time.
15. The agents' own GitHub accounts, OD-23 [s2].

## The keystore rehearsal

The mainnet recipes were rehearsed on 2026-10-07 on a local anvil fork of mainnet at block 26139102, signed with a throwaway Foundry keystore that held anvil's first public test key.

- `CLUTCH_MAINNET=1 just --yes --justfile mainnet.just dry-run` deployed the dry run. The Asset Safe's only owner was the mock Agent, and both modules were enabled. The policy compiled against the written manifest, and the apply step ran 105 calls.
- `fund`, with the funder's balance set to 0.05 ETH, completed its legs. With anvil's default balance of 10,000 ETH, a swap leg failed its slippage bound instead, because the script expects a 0.05 ETH funder.
- `teardown` disabled both modules and swept the funds back to the signer.
- Without `CLUTCH_MAINNET=1`, with `PRIVATE_KEY` set, or with `CI` set, the recipes refused to run.
- The funding script writes `bootstrap-manifest.json` with a trailing comma, which is not valid JSON. This predates ADR 012.
