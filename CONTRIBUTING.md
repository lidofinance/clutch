# Contributing to Clutch

Many contributors work here, each with their own agents. This page is the workflow. [AGENTS.md](AGENTS.md) holds the rules, and it wins where the two differ. [ADR 012](docs/adr/012-contributing-with-many-agents.md) records the decisions behind this page.

## Who does what

- EM decides in the interim. The Treasury Management Committee is the permanent acceptor. The Emergency Brakes multisig verifies each ADR that constrains the operator ([ADR 002](docs/adr/002-decision-and-review-process.md)).
- Humans review, verify and merge. Agents draft text, code and tests.
- Agents own no GitHub accounts. The human who runs an agent opens its pull request and answers for it. Each commit carries a `Co-Authored-By` trailer for the agent, and each page names the agent in `generated.by`.
- Any agent may author a page. Only the humans that [config/actors.yaml](config/actors.yaml) lists verify a page.

## Set up once

1. Install uv, bun 1.3.0, Foundry and git. `just` is optional: `uvx --from rust-just==1.58.0 just <recipe>` runs any recipe.
2. Run `just setup`. It fetches forge-std, installs the policy's packages and a headless Chromium, and builds the contracts.
3. For the fork suite, put `RPC=<archive mainnet RPC>` in `.env`, which git ignores. Bring your own archive RPC. Never commit an RPC URL that carries a key.
4. Run `just doctor` to see the tool versions.

## Make a change

1. Use one worktree per task, from the current `main`: `git worktree add ../clutch-<topic> -b <kind>/<date>-<topic> origin/main`. The kinds are `decisions`, `docs`, `policy`, `fix` and `research`. Never run a bare `git stash`: the stash is shared by every worktree.
2. Keep to one decision or one feature per pull request. Commit the generated files with the change that caused them.
3. Take a new OD, ADR or INV number from `main` when you open the pull request. If another pull request takes the same number first, the validator fails, and you take the next number.
4. Add the log entry: `just log Update "What changed, in one line."`. Never edit `docs/log.md`.
5. Run `just regen`, then `just check`. Also run `just test-fork` when the change touches `src/`, `script/`, `test/` or `policy/`: CI does not run the fork suite until phase 2 (OD-52).
6. Open the pull request with the template. A human merges it through the merge queue, which runs the checks again on the merged result.

## Verify a page

- Only the humans and teams that `config/actors.yaml` lists verify a page. Agents never verify.
- Run `just verify <page> <your id>`. It writes your entry with the time and the hash of the page's body. Add `--review human-reviewed` to set the review status as well.
- A team member, such as one of `human:defi-tech`, adds `--ref <the pull request that you approve>`. A member of the committee or of the Emergency Brakes multisig adds `--ref <the body's decision record>`.
- Any later edit to the page's body fails the check until someone verifies the page again (OD-51).
- A team's verification raises a page's review status. Only EM or the committee accepts an ADR (OD-50).

## Generated files

- `docs/log.md`, `docs/registers/document-status.md` and `docs/onboarding/clutch-onboarding.html` come from scripts. Never edit them by hand. On a merge conflict, take either side, run `just regen` and commit the result.
- The policy artifact is generated too, but reviewers approve its diff ([ADR 004](docs/adr/004-specifications-and-policy-as-data.md), decision 14).

## Decisions

- A question that needs a decision becomes a row of [the open-decision register](docs/registers/open-decisions.md): the question with its options, the page that closes it, the agent's recommendation and who decides. The validator refuses an incomplete row.
- EM triages the open decisions and decides them in batched interviews. Only one decisions branch is open at a time, so two decisions never conflict.
- The decision log quotes EM exactly, from the interview that EM gave. Never write a quote from memory or from another source.

## Restricted material and secrets

- Nothing enters the repository that could not be published at deployment ([ADR 001](docs/adr/001-repository-scope-visibility-licence-name.md)). The screening vendor stays "the screening vendor", and no figure comes from the unapproved mandate.
- Restricted material reaches you from EM, outside the repository. Cite it with a `urn:clutch:restricted:` source, and paraphrase it.
- `scripts/check_redaction.py` refuses restricted terms and secrets in every file. Its list holds only hashes. If it refuses a line, remove the term. Only a human changes the list.
- Never commit a key, a seed, a token, a keystore password or an RPC URL with a key.

## Mainnet and the hosted app

- `mainnet.just` broadcasts real transactions. Agents never run it. A human runs a recipe with `CLUTCH_MAINNET=1 just --justfile mainnet.just <recipe>`, signs with a Foundry keystore after a password prompt, and confirms. `.env` holds the keystore's name and address, never a private key or a password.
- The package scripts that call the hosted Zodiac app refuse to run unless a member of the repository-owner team sets `CLUTCH_OWNER_PUSH=1` on a clean `main` ([ADR 004](docs/adr/004-specifications-and-policy-as-data.md), decision 16).
