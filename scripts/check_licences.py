#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check the licence line of every source file (ADR 001, decision 9; ADR 012).

Run:
  uv run python scripts/check_licences.py            # check
  uv run python scripts/check_licences.py --lock     # rewrite policy/constellation/provenance.lock

The rule of ADR 001: a source file under src/, script/, scripts/, test/ or policy/
carries `SPDX-License-Identifier: AGPL-3.0-or-later`. Two exceptions:

- A file derived from the policy provider's constellation keeps LGPL-3.0-only (OD-34).
  If it is unchanged, it carries no SPDX line and its git blob hash must match the
  lock. If it changed, it carries `SPDX-License-Identifier: LGPL-3.0-only`.
- A file derived from Easy Track keeps GPL-3.0. None exists yet; a human adds its path
  to EASY_TRACK_DERIVED in a reviewed pull request.

This replaces the grep command that ADR 001 gives for a manual check.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCOPE = ("src/", "script/", "scripts/", "test/", "policy/")
SUFFIXES = (".sol", ".py", ".ts")
PROVIDER = "policy/constellation/"
LOCK = ROOT / PROVIDER / "provenance.lock"
EASY_TRACK_DERIVED: tuple[str, ...] = ()
SPDX = re.compile(r"SPDX-License-Identifier:\s*([A-Za-z0-9.+-]+)")
HEADER_LINES = 10


def blob(data: bytes) -> str:
    """The git blob hash of a file's bytes, as `git hash-object` computes it."""
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def sources() -> list[str]:
    done = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                          cwd=ROOT, check=True, stdout=subprocess.PIPE)
    paths = {item.decode() for item in done.stdout.split(b"\0") if item}
    return sorted(p for p in paths if p.startswith(SCOPE) and p.endswith(SUFFIXES) and "node_modules/" not in p)


def licence(path: Path) -> str | None:
    head = path.read_text(encoding="utf-8").splitlines()[:HEADER_LINES]
    for line in head:
        if match := SPDX.search(line):
            return match.group(1)
    return None


def read_lock() -> tuple[dict[str, str], set[str]]:
    verbatim: dict[str, str] = {}
    derived: set[str] = set()
    for line in LOCK.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split()
        if parts[0] == "verbatim" and len(parts) == 3:
            verbatim[PROVIDER + parts[2]] = parts[1]
        elif parts[0] == "derived" and len(parts) == 2:
            derived.add(PROVIDER + parts[1])
        else:
            raise ValueError(f"provenance.lock: cannot read {line!r}")
    return verbatim, derived


def problems() -> list[str]:
    verbatim, derived = read_lock()
    out = []
    for rel in sources():
        path = ROOT / rel
        found = licence(path)
        if found == "AGPL-3.0-or-later":
            continue
        if found == "LGPL-3.0-only":
            if rel not in derived and rel not in verbatim:
                out.append(f"{rel}: LGPL-3.0-only is only for files derived from the provider's constellation; a new file uses AGPL-3.0-or-later")
            continue
        if found and found.startswith("GPL-3.0"):
            if rel not in EASY_TRACK_DERIVED:
                out.append(f"{rel}: GPL-3.0 is only for files derived from Easy Track; a human lists them in EASY_TRACK_DERIVED")
            continue
        if found:
            out.append(f"{rel}: licence {found} is not allowed (ADR 001)")
            continue
        if rel in verbatim:
            if blob(path.read_bytes()) != verbatim[rel]:
                out.append(f"{rel}: a changed provider file needs `SPDX-License-Identifier: LGPL-3.0-only` and a notice (OD-34)")
            continue
        out.append(f"{rel}: no SPDX line; add `SPDX-License-Identifier: AGPL-3.0-or-later` (ADR 001)")
    for rel in sorted(set(verbatim) | derived):
        if not (ROOT / rel).is_file():
            out.append(f"provenance.lock lists {rel}, which does not exist")
    return out


def write_lock() -> None:
    _, derived = read_lock() if LOCK.is_file() else ({}, set())
    rows = []
    for rel in sources():
        if not rel.startswith(PROVIDER):
            continue
        found = licence(ROOT / rel)
        name = rel[len(PROVIDER):]
        if found is None:
            rows.append(f"verbatim {blob((ROOT / rel).read_bytes())} {name}")
        elif found == "LGPL-3.0-only":
            rows.append(f"derived {name}")
    header = [
        "# Files that come from the policy provider's constellation at 02ea37d (PROVENANCE.md).",
        "# verbatim <git blob hash> <path>: unchanged, so the file carries no SPDX line.",
        "# derived <path>: changed, so it carries SPDX-License-Identifier: LGPL-3.0-only and a notice (OD-34).",
        "# scripts/check_licences.py checks this list. Only a human adds an entry.",
    ]
    LOCK.write_text("\n".join(header + sorted(rows, key=lambda r: r.split()[-1])) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    if "--lock" in argv:
        write_lock()
        print(f"wrote {LOCK.relative_to(ROOT)}")
        return 0
    found = problems()
    for problem in found:
        print(problem)
    if found:
        return 1
    print(f"Every source file carries an allowed licence ({len(sources())} files).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
