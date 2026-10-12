#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""The pin changes of a pull request, as Markdown for the job summary (ADR 012, decision 11).

Run:
  python3 scripts/pin_report.py --base origin/main >> "$GITHUB_STEP_SUMMARY"

It compares docs/onboarding/pins.json at the base with the working tree. The build
check already fails when an item is not pinned again after a change. This report
shows the reviewer what each new pin means. The first list matters most: an item
whose source changed while its text stayed the same. The author says that the old
text is still true; the reviewer reads the source change and confirms it.

The report never fails the job. It needs only the Python standard library.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
PINS = "docs/onboarding/pins.json"


def compare(base: dict[str, Any], head: dict[str, Any]) -> dict[str, list[tuple[str, list[str]]]]:
    """Each changed pin by kind, with the sources that changed or came in."""
    out: dict[str, list[tuple[str, list[str]]]] = {"kept": [], "changed": [], "new": [], "removed": []}
    for key in sorted(head):
        old, now = base.get(key), head[key]
        if old is None:
            out["new"].append((key, sorted(now["sources"])))
            continue
        moved = sorted(r for r, h in now["sources"].items() if old["sources"].get(r) != h)
        moved += sorted(f"no longer {r}" for r in old["sources"] if r not in now["sources"])
        if old["content"] != now["content"]:
            out["changed"].append((key, moved))
        elif moved:
            out["kept"].append((key, moved))
    out["removed"] = [(key, []) for key in sorted(base) if key not in head]
    return out


def markdown(result: dict[str, list[tuple[str, list[str]]]], base: str) -> str:
    total = sum(len(v) for v in result.values())
    lines = ["## Onboarding guide: pin review", ""]
    if not total:
        return "\n".join(lines + [f"No pin changed against `{base}`.", ""])
    lines.append(f"{total} pins changed against `{base}`.")
    titles = {
        "kept": ("Text kept after a source change", "Read each source change, then confirm that the text of the item is still true."),
        "changed": ("Text changed", "Read the new text next to its sources."),
        "new": ("New items", "Read each new item next to its sources."),
        "removed": ("Removed items", "Confirm that the guide does not need them."),
    }
    for kind, (title, ask) in titles.items():
        if not result[kind]:
            continue
        lines += ["", f"### {title} ({len(result[kind])})", "", ask, ""]
        for key, refs in result[kind]:
            lines.append(f"- `{key}`" + (": " + ", ".join(f"`{r}`" for r in refs) if refs else ""))
    lines.append("")
    return "\n".join(lines)


def read(ref: str | None) -> dict[str, Any] | None:
    if ref is None:
        text = (ROOT / PINS).read_text(encoding="utf-8")
    else:
        done = subprocess.run(["git", "-C", str(ROOT), "show", f"{ref}:{PINS}"], capture_output=True, text=True)
        if done.returncode:
            return None
        text = done.stdout
    return json.loads(text).get("items", {})


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base", required=True, help="the git ref to compare with, for example origin/main")
    args = parser.parse_args(argv)
    base = read(args.base)
    if base is None:
        print(f"## Onboarding guide: pin review\n\n`{args.base}` has no {PINS}. Every item is new; read the whole guide.\n")
        return 0
    print(markdown(compare(base, read(None)), args.base))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
