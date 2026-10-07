---
name: adr-draft
description: Draft a new decision record (ADR) in the Clutch repository, or revise a proposed one. Use when a design question needs a recorded decision, when EM or the Treasury Management Committee states a decision in conversation, or when an item in docs/registers/open-decisions.md is ready to be written up.
license: AGPL-3.0-or-later
---

# Draft a Clutch ADR

1. Read `docs/adr/index.md` and `docs/registers/open-decisions.md`. Reuse an existing ADR if the question is already open there. Otherwise take the next free number in the single global sequence.
2. Copy the frontmatter of an existing ADR. Set `type: Decision`, `status: draft`, `review_status: slop`, `decision: proposed`, `verified: []`, and `generated.by` to your own actor id from `config/actors.yaml`. Set `generated.at` to the current UTC time with second precision.
3. Set `constrains_operator`. It is `true` when the ADR changes the operator's permissions, the emergency powers, the technical role or module disabling, the funding path, or a budget or approval ceiling. Otherwise it is `false`. When in doubt, set `true`: the Emergency Brakes multisig must then verify the ADR before it is accepted.
4. Write these sections in this order: Context, Decision, Proposed direction (when part of the text is an agent proposal), Options considered, Consequences, Confirmation, Reversal conditions, Open questions.
   - Context states facts, each with an inline `[sN]` marker that matches a `sources` entry. Cite an on-chain fact only from a read that ran, with its block. Add new reads to a research note with their exact commands.
   - Decision says who decided and when. Quote EM exactly from `docs/registers/decision-log.md`. Mark every agent recommendation as a recommendation.
   - Options considered lists each option with its main consequence. Do not pad the list.
   - Confirmation names the invariant, test or check that shows the decision holds.
   - Reversal conditions name the evidence that would reopen the decision.
5. Never write a financial figure that no attested computation produced. Never set a parameter; list options for the acceptor instead.
6. Never set `decision: accepted` and never add a `human:` entry to `verified`. EM or the committee accepts an ADR by editing it.
7. Add or update the ADR's line in `docs/adr/index.md`, and the matching items in `docs/registers/open-decisions.md` and `docs/specs/invariants.md`.
8. Add a log fragment with `just log Decision "..."`. Run `just regen`, then `just check-docs`. Fix every error before you stop.
