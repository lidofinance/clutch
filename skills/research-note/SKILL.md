---
name: research-note
description: Write a dated Clutch research note in docs/research/ that records evidence — chain reads, code reads, external sources or a restricted input — so that ADRs and the guide can cite it. Use before a decision rests on a fact that the repository does not yet record.
license: AGPL-3.0-or-later
---

# Write a Clutch research note

1. Name the file `docs/research/<topic>-<YYYY-MM-DD>.md`. Copy the frontmatter of a recent note: `type: Research Note`, `review_status: slop`, `valid_as_of`, `stale_after`, `generated` with the time from `date -u`, `verified: []` and `sources`.
2. Start with "## Answer": the findings in a few bullets, each with its `[sN]` marker.
3. Record every chain read with the block and the exact command, and every code read with a commit permalink. Report what ran, and say so when a check could not run.
4. Cite restricted input with a `urn:clutch:restricted:<name>` source and paraphrase it. Never copy a vendor name, a restricted address or an unapproved figure; `just check-docs` refuses them.
5. Add the note to `docs/research/index.md`, then run `just regen` and `just check-docs`.
