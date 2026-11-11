---
name: record-decision
description: Record EM's answer to a Clutch open decision across the repository — the decision log, the open-decision register, the ADR, the invariants, the LIP, the onboarding guide and the log. Use right after EM answers an interview question or states a decision.
license: AGPL-3.0-or-later
---

# Record a Clutch decision

1. Add a decision-log entry at the top of `docs/registers/decision-log.md`. Quote EM's message exactly, typos included. Use square brackets only for the redactions that the page lists. Below the quote, write "Recorded as:" with one line per answer, each naming its OD and the page that now holds it.
2. Record as EM's decision only what the chosen option said. Everything you add goes to the ADR's "Proposed direction", marked as agent-drafted.
3. Remove the OD row from the open table of `docs/registers/open-decisions.md`. Add its entry to `docs/registers/closed-decisions.yaml`, with the date and the decision-log heading that holds EM's words. The register lists open items only (OD-127).
4. Update the ADR in place, so that it shows the current design only (OD-128): add the new decision with its OD; give an amended decision its current text and the ODs that shaped it; turn a replaced decision into one line, "N. Replaced by decision M (OD-nn)." or "N. Lapsed (OD-nn): reason."; and keep only the live options, consequences and open questions. Never renumber a decision. Never edit an accepted ADR: write a new ADR that amends it, and say which decision it replaces.
5. Update every page that the decision changes: invariants (a new `INV-NNN` from `main`, mapped to a named test), the LIP, the control matrix, the parameters, the runbooks, the roadmap and the guide's content in `docs/onboarding/content/`.
6. Run `just regen`, then `just check`. Fix every error before you stop.
7. Commit and push only when EM says so.
