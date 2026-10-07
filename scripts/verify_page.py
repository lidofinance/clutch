#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Record a human's verification of a page, with the hash of its body (ADR 012, OD-51).

Run:
  just verify docs/adr/012-contributing-with-many-agents.md human:em
  just verify docs/runbooks/x.md human:defi-tech --ref https://github.com/lidofinance/clutch/pull/42
  uv run --with pyyaml==6.0.2 python scripts/verify_page.py PAGE --by ACTOR [--ref REF]
      [--recorded-by AGENT] [--review STATUS]

The entry records `sha256`, the hash of the page's body. The validator fails when the
body changes after the latest verification, until a human verifies the page again.

Only humans verify. A human runs this for their own entry. A team member adds `--ref`,
the link to the pull request that they approve (OD-50); a member of a body adds `--ref`,
the link to the body's decision record (ADR 002). An agent runs it only on a human's
explicit written instruction, for that human's own entry, with `--recorded-by` and
`--ref` to the decision-log heading that quotes the instruction (ADR 003, OD-31).
`--review` also sets the page's review status.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REVIEWS = ("human-skimmed", "human-reviewed", "finalized")


def _validator():
    spec = importlib.util.spec_from_file_location("validate_docs", ROOT / "scripts" / "validate_docs.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["validate_docs"] = module
    spec.loader.exec_module(module)
    return module


def add_entry(text: str, entry: list[str], review: str | None = None) -> str:
    """The page with the entry appended to `verified`, and the frontmatter otherwise unchanged."""
    match = re.match(r"\A---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        raise ValueError("the page has no frontmatter")
    lines = match.group(1).split("\n")
    start = next((i for i, line in enumerate(lines) if re.match(r"verified:\s*(\[\])?\s*$", line)), None)
    if start is None:
        raise ValueError("the frontmatter has no `verified` key")
    block = ["  - " + entry[0]] + ["    " + item for item in entry[1:]]
    if lines[start].strip() == "verified: []":
        lines[start:start + 1] = ["verified:"] + block
    else:
        end = start + 1
        while end < len(lines) and (lines[end].startswith("  ") or not lines[end].strip()):
            end += 1
        lines[end:end] = block
    if review:
        index = next((i for i, line in enumerate(lines) if line.startswith("review_status:")), None)
        if index is None:
            raise ValueError("the frontmatter has no `review_status` key")
        lines[index] = f"review_status: {review}"
    return "---\n" + "\n".join(lines) + "\n---\n" + text[match.end():]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("page", help="the page, such as docs/adr/012-contributing-with-many-agents.md")
    parser.add_argument("--by", required=True, help="the human actor, such as human:em")
    parser.add_argument("--ref", help="a pull request (team), a decision record (body) or a decision-log heading (recorded)")
    parser.add_argument("--recorded-by", help="the agent that records a human's verification on instruction")
    parser.add_argument("--review", choices=REVIEWS, help="also set the page's review status")
    args = parser.parse_args(argv)

    if not args.by.startswith("human:"):
        print("Refused: only a human verifies a page (ADR 003). Agents never verify.", file=sys.stderr)
        return 1
    path = (ROOT / args.page) if not Path(args.page).is_absolute() else Path(args.page)
    text = path.read_text(encoding="utf-8")
    validator = _validator()
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    entry = [f"by: {args.by}", f"at: {now}"]
    if args.recorded_by:
        entry.append(f"recorded_by: {args.recorded_by}")
    if args.ref:
        entry.append(f"ref: {args.ref}")
    entry.append(f"sha256: {validator.body_hash(text)}")
    try:
        path.write_text(add_entry(text, entry, args.review), encoding="utf-8")
    except ValueError as exc:
        print(f"{args.page}: {exc}", file=sys.stderr)
        return 1
    print(f"recorded {args.by}'s verification of {args.page} at {now}. Run `just regen`, then `just check-docs`.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
