---
type: Research Note
title: The repository and many contributors with agents, 2026-10-07
description: The evidence behind ADR 012 — how often changes touch the same files, who the validator let author and verify, what CI ran, the unsafe defaults for an agent, the fifteen steps that EM answered by number, and the keystore rehearsal of the mainnet recipes.
tags: [contributors, agents, process, ci, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-07
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-07T07:49:32Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's question about more contributors and agents, and EM's answers by number, 2026-10-07
  - id: s2
    resource: /adr/003-agent-operating-model.md
    title: ADR 003 — the agent operating model, the protected files and OD-23
  - id: s3
    resource: /adr/001-repository-scope-visibility-licence-name.md
    title: ADR 001 — the licence check that a CI check replaces
  - id: s4
    resource: /adr/004-specifications-and-policy-as-data.md
    title: ADR 004 — the hosted Zodiac app is outside the path; its key stays with the repository-owner team
  - id: s5
    resource: /specs/specification-policy.md
    title: Specification policy — invariants map to named tests, and the guide is a fresh build
---

# The repository and many contributors with agents, 2026-10-07

## Answer

- EM asked how to open the repository to more contributors who run their own agents, and how to keep their work calm [s1].
- Three things broke first. A second agent could not pass the validator. Most changes edited the same few files. And some defaults were safe for one careful operator but not for a stranger's agent.
- The agent listed fifteen steps, and EM answered them by number on 2026-10-07 [s1]. ADR 012 records the decisions, and this note keeps the list.

## Measurements

The repository was read at commit `13b521c` of the branch `decisions/2026-10-06-tmc-meeting`, with the uncommitted RFP tab on top.

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
- `config/actors.yaml` listed one agent and three humans. The validator refused any other id in `generated.by` and in `verified`. Agents may change that file only on an explicit human request [s2].
- `AGENTS.md` and the README told users to run `python3 scripts/validate_docs.py`, which needs a system PyYAML; CI installs a pinned PyYAML in a virtual environment. No command set up the tools or ran everything that CI runs.
- CI ran the docs bundle, the guide's build and browser tests, and the policy artifact. It ran no Solidity test, because the fork suite needs an archive RPC. It had no secret scan and no licence check. ADR 001 gave a grep command for the licence check, to be replaced by a CI check later [s3]. The specification policy asks for an invariant-to-test check once it exists [s5].
- `Justfile` loaded `.env`, which held `PRIVATE_KEY`, and listed the mainnet `--broadcast` recipes `dry-run`, `fund` and `teardown` next to `test-fork`.
- `policy/constellation/package.json` had `push`, `pull`, `pull-org`, `pull-contracts` and a `prepush` hook. They call the hosted Zodiac app with its API key. The rule that only the repository-owner team runs them was in ADR 004 and the provenance file, not in `AGENTS.md` [s4].
- Restricted terms stayed out by convention and by manual scans. The decision log quotes one of the request for solution's allocation figures twice, in EM's words.
- `CODEOWNERS` gives every path to one team, and `/.github/` to the workflow reviewers. The branch rule on `main` could not be read from here, because the GitHub CLI was not signed in.

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
