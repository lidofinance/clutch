# Contributing to Clutch

[AGENTS.md](AGENTS.md) holds the rules and takes precedence over this workflow.
[ADR 012](docs/adr/012-contributing-with-many-agents.md) records the decisions behind it.

## Who does what

EM accepts decisions in the interim. The Treasury Management Committee is the permanent acceptor.
No other body verifies an ADR before acceptance (OD-63).

Humans decide, review, verify and merge. Agents draft text, code and tests.
Any agent may author a page. Only humans and teams listed in `config/actors.yaml` can verify pages.
Agents own no GitHub accounts. They use the contributor's account; the contributor opens and answers for the pull request.
Each commit carries the agent's `Co-Authored-By` trailer. Pages name their agent authors in `generated.by`.

## Set up once

1. Install uv, bun 1.3.0, Foundry and git.
2. Run `just setup` to install dependencies and headless Chromium, then build the contracts.
3. For fork tests, set `RPC=<archive mainnet RPC>` in the git-ignored `.env`.
4. Run `just doctor` to check tool versions.

`just` is optional. Use `uvx --from rust-just==1.58.0 just <recipe>` instead.
Never commit a key or an RPC URL that contains one.

## Make a change

1. Create one worktree per task from current `main`:

   ```sh
   git worktree add ../clutch-<topic> -b <kind>/<date>-<topic> origin/main
   ```

   Use `decisions`, `docs`, `policy`, `fix` or `research` as the kind.
   Do not run bare `git stash`: worktrees share the stash.
2. Keep one decision or feature per pull request.
3. Allocate new OD, ADR and INV numbers from `main` when you open the pull request.
   If another pull request takes a number first, the validator fails; take the next one.
4. Add a log fragment with `just log Update "What changed, in one line."`.
5. Run `just regen`, then `just check`. Commit generated files with their source changes.
6. If you changed `src/`, `script/`, `test/` or `policy/`, run `just test-fork` too.
   CI does not run the fork suite until phase 2 (OD-52).
7. Open a pull request with the template. A human merges through the merge queue, which repeats the checks on the merged result.

## Verify a page

Only listed humans and teams verify pages. Agents cannot verify them.

Run `just verify <page> <your id>` to record the time and body hash.
Add `--review human-reviewed` to set the review status.
A team member adds `--ref <approved pull request>`; a committee member adds `--ref <committee decision record>`.

A later body edit fails the check until the page is verified again (OD-51).
Team verification raises review status; only EM or the committee accepts an ADR (OD-50).

## Generated files

Do not edit these files by hand:

- `docs/log.md`
- `docs/registers/document-status.md`
- `docs/adr/index.md`
- The generated blocks: the closed index of `docs/registers/open-decisions.md`, and the open questions of each proposed ADR
- `docs/onboarding/clutch-onboarding.html`
- Policy artifacts in `policy/constellation/artifacts/`

After a merge conflict, take either version, run `just regen` and commit the result.
Reviewers must approve the policy artifact's diff (ADR 004, decision 14).

## Change the onboarding guide

For guide content, source pins, coverage and browser tests, follow [guide maintenance](docs/onboarding/guide.md).
Text lives in `docs/onboarding/content/`. Cite an ADR decision or heading, such as `ADR-007#d27`; whole-ADR citations fail.
After a source change, review affected guide items before `just repin <item>`.
For a `pins.json` conflict, take `main`'s version and use `just stale` to repeat that review.
The [guide-update procedure](skills/guide-update/SKILL.md) gives the steps.

## Decisions

Add a complete row to the [open-decisions register](docs/registers/open-decisions.md):
question, options, closing page, recommendation and decider. The validator rejects incomplete rows.
To close a decision, remove its row, add its entry to `docs/registers/closed-decisions.yaml` and run `just regen`. The validator writes the closed index.

EM triages open decisions and decides in batched interviews, with one decisions branch at a time.
The decision log quotes the interview exactly. Do not reconstruct a quote from memory or another source.

## Restricted material and secrets

The repository is public, so every file and commit message must be suitable for publication now (ADR 001, OD-95).
EM supplies restricted material outside the repository. Paraphrase it and cite a `urn:clutch:restricted:` source.
Call the unannounced screening vendor "the screening vendor". Do not include figures from the unapproved mandate.

`scripts/check_redaction.py` rejects restricted terms and secrets in tracked and new files through a hash-only list.
Remove a rejected term. Only a human changes the list.
Never commit keys, seeds, tokens, keystore passwords or RPC URLs with keys.

## Mainnet and the hosted app

`mainnet.just` broadcasts real transactions. Agents must not run it.
A human sets `CLUTCH_MAINNET=1` and runs `just --justfile mainnet.just <recipe>`, then signs with a Foundry keystore after a password prompt and confirms.
Keep only the keystore name and address in `.env`; never store its password or private key there.

Only a repository-owner team member can run package scripts that call the hosted Zodiac app.
They require a clean `main` and `CLUTCH_OWNER_PUSH=1` (ADR 004, decision 16).
