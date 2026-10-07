#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Build docs/log.md from one fragment per entry in docs/log.d/ (ADR 012).

Run:
  uv run --with pyyaml==6.0.2 python scripts/build_log.py                   # write docs/log.md
  uv run --with pyyaml==6.0.2 python scripts/build_log.py --check           # fail if docs/log.md is stale
  uv run --with pyyaml==6.0.2 python scripts/build_log.py --new KIND TEXT   # add an entry dated now

Each change adds its own fragment, so two pull requests never edit the same lines
of the log. A fragment is a YAML file named `<date>T<HHMMSS>Z-<slug>.yaml`, with the
UTC time when it was written:

  date: 2026-10-07
  kind: Update
  text: One line of Markdown.

The log lists dates newest first, and the entries of one date newest first.
"""

from __future__ import annotations

import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
FRAGMENTS = ROOT / "docs" / "log.d"
LOG = ROOT / "docs" / "log.md"
KINDS = ("Decision", "Evidence", "Import", "Initialization", "Update")
NAME = re.compile(r"(\d{4}-\d{2}-\d{2})T\d{6}Z-[a-z0-9]+(?:-[a-z0-9]+)*\.yaml")


class LogError(Exception):
    pass


def fragments() -> list[tuple[str, dict[str, str]]]:
    """Every fragment as (file name, content), checked."""
    errors = []
    found = []
    for path in sorted(FRAGMENTS.glob("*")):
        match = NAME.fullmatch(path.name)
        if not match:
            errors.append(f"{path.name}: the name must be <date>T<HHMMSS>Z-<slug>.yaml")
            continue
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            errors.append(f"{path.name}: not valid YAML: {exc}")
            continue
        if not isinstance(data, dict) or set(data) != {"date", "kind", "text"}:
            errors.append(f"{path.name}: needs exactly `date`, `kind` and `text`")
            continue
        date, kind, text = str(data["date"]), str(data["kind"]), str(data["text"]).strip()
        if date != match.group(1):
            errors.append(f"{path.name}: `date` {date} differs from the date in the name")
        if kind not in KINDS:
            errors.append(f"{path.name}: `kind` must be one of {', '.join(KINDS)}")
        if not text or "\n" in text:
            errors.append(f"{path.name}: `text` must be one non-empty line")
        found.append((path.name, {"date": date, "kind": kind, "text": text}))
    if errors:
        raise LogError("\n".join(errors))
    return found


def render(items: list[tuple[str, dict[str, str]]]) -> str:
    by_date: dict[str, list[tuple[str, dict[str, str]]]] = {}
    for name, entry in items:
        by_date.setdefault(entry["date"], []).append((name, entry))
    sections = []
    for date in sorted(by_date, reverse=True):
        lines = [f"* **{e['kind']}**: {e['text']}" for _, e in sorted(by_date[date], reverse=True)]
        sections.append(f"## {date}\n\n" + "\n".join(lines) + "\n")
    return "# Log\n\n" + "\n".join(sections)


def new(kind: str, text: str, now: datetime | None = None) -> Path:
    """Write a fragment dated now (UTC), named after the first words of its text."""
    if kind not in KINDS:
        raise LogError(f"`kind` must be one of {', '.join(KINDS)}")
    text = " ".join(text.split())
    if not text:
        raise LogError("`text` must be one non-empty line")
    now = now or datetime.now(timezone.utc)
    plain = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text).lower()
    slug = "-".join(w for w in re.split(r"[^a-z0-9]+", plain) if w)[:48].strip("-") or "entry"
    slug = "-".join(slug.split("-")[:6])
    path = FRAGMENTS / f"{now:%Y-%m-%dT%H%M%S}Z-{slug}.yaml"
    if path.exists():
        raise LogError(f"{path.name} exists; wait a second and run again")
    data = {"date": f"{now:%Y-%m-%d}", "kind": kind, "text": text}
    path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=10**6), encoding="utf-8")
    return path


def main(argv: list[str]) -> int:
    if argv[:1] == ["--new"]:
        if len(argv) != 3:
            print("usage: build_log.py --new KIND TEXT", file=sys.stderr)
            return 2
        try:
            print(f"wrote docs/log.d/{new(argv[1], argv[2]).name}")
        except LogError as exc:
            print(exc, file=sys.stderr)
            return 1
        argv = []
    try:
        page = render(fragments())
    except LogError as exc:
        print(exc, file=sys.stderr)
        return 1
    if "--check" in argv:
        if LOG.read_text(encoding="utf-8") != page:
            print("docs/log.md differs from its fragments; run scripts/build_log.py", file=sys.stderr)
            return 1
        print("docs/log.md matches its fragments.")
        return 0
    LOG.write_text(page, encoding="utf-8")
    print(f"wrote docs/log.md ({len(page.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
