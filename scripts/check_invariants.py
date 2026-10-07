#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check that the invariants name tests that exist (specification policy; ADR 012).

Run:
  uv run python scripts/check_invariants.py

Each row of docs/specs/invariants.md names its state and its kit tests. A test name is
a backticked `test_...` word. The check fails when:

- a named test is not a function in a test/*.t.sol file, so a renamed or deleted test
  cannot leave an invariant pointing at nothing; or
- an invariant in state "Draft" names no test.

"Pending" and "Retired" invariants may name no test. The specification policy also asks
CI to fail when an invariant has no test at all; that stricter rule waits for the end of
phase 2, when every pending invariant is built (ROADMAP).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "docs" / "specs" / "invariants.md"
ROW = re.compile(r"^\|\s*(INV-\d{3})\s*\|(.*)\|\s*$")
TEST_NAME = re.compile(r"`(test_\w+)`")
TEST_FUNCTION = re.compile(r"function\s+(test_\w+)\s*\(")


def tests() -> set[str]:
    names: set[str] = set()
    for path in (ROOT / "test").rglob("*.t.sol"):
        names.update(TEST_FUNCTION.findall(path.read_text(encoding="utf-8")))
    return names


def problems() -> list[str]:
    known = tests()
    out = []
    for line in TABLE.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if not match:
            continue
        ident = match.group(1)
        cells = [c.strip() for c in match.group(2).split("|")]
        if len(cells) < 4:
            out.append(f"{ident}: the row needs the invariant, its ADR, its state and its tests")
            continue
        state, tests_cell = cells[-2], cells[-1]
        named = TEST_NAME.findall(tests_cell)
        for name in named:
            if name not in known:
                out.append(f"{ident}: names `{name}`, which no test/*.t.sol file defines")
        if state.startswith("Draft") and not named:
            out.append(f"{ident}: a Draft invariant names no test")
    return out


def main() -> int:
    found = problems()
    for problem in found:
        print(problem)
    if found:
        return 1
    print("Every invariant names only tests that exist, and every Draft invariant names one.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
