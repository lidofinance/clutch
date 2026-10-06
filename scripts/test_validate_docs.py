#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Negative tests for the recorded-verification rule of validate_docs.py (ADR 003, OD-31).

Run:
  uv run --with pyyaml python scripts/test_validate_docs.py

Each case copies docs/, config/ and AGENTS.md to a temporary directory, changes the
verified entry of one accepted ADR, and checks what the validator reports for that page.
"""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = "docs/adr/004-specifications-and-policy-as-data.md"
ENTRY = (
    "verified:\n"
    "  - by: human:em\n"
    "    at: 2026-10-05T20:27:31Z\n"
    "    recorded_by: claude-code/opus-5.5\n"
    "    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted\n"
)


def _load_validator():
    spec = importlib.util.spec_from_file_location("validate_docs", ROOT / "scripts" / "validate_docs.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["validate_docs"] = module  # dataclasses need the module registered
    spec.loader.exec_module(module)
    return module


def _copy(target: Path) -> None:
    shutil.copytree(ROOT / "docs", target / "docs")
    shutil.copytree(ROOT / "config", target / "config")
    shutil.copy(ROOT / "AGENTS.md", target / "AGENTS.md")
    subprocess.run(["git", "init", "-q"], cwd=target, check=True)  # the validator inspects tracked paths


def _errors(validator, root: Path, entry: str) -> list[str]:
    page = root / PAGE
    text = (ROOT / PAGE).read_text(encoding="utf-8")
    assert ENTRY in text, f"{PAGE} no longer carries the expected recorded entry"
    page.write_text(text.replace(ENTRY, entry), encoding="utf-8")
    return [i.message for i in validator.validate(root) if i.path == PAGE and not i.warning]


def main() -> int:
    validator = _load_validator()
    cases = [
        ("a recorded entry with its instruction link counts", ENTRY, None),
        ("recorded_by without ref", ENTRY.replace(
            "    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted\n", ""),
         "needs `ref`, a link to the decision-log heading"),
        ("ref to a missing heading", ENTRY.replace("adr-001-to-adr-004-accepted", "no-such-heading"),
         "needs `ref`, a link to the decision-log heading"),
        ("ref outside the decision log", ENTRY.replace(
            "/registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted", "https://example.org/x"),
         "needs `ref`, a link to the decision-log heading"),
        ("recorded_by names a human", ENTRY.replace("recorded_by: claude-code/opus-5.5", "recorded_by: human:tmc"),
         "recorded_by must name an agent"),
        ("recorded_by names an unknown agent", ENTRY.replace("claude-code/opus-5.5", "rogue/agent"),
         "is not in config/actors.yaml"),
        ("an agent records a body's verification", ENTRY.replace("by: human:em", "by: human:emergency-brakes"),
         "an agent never records a body's verification"),
    ]
    failures = 0
    for name, entry, expected in cases:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _copy(root)
            errors = _errors(validator, root, entry)
        if expected is None:
            ok = not errors
        else:
            ok = any(expected in message for message in errors)
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f"\n      got: {errors}"))

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        _copy(root)
        register = validator.render_status(root)
        row = next((line for line in register.splitlines() if PAGE.removeprefix("docs/") in line), "")
        ok = "human:em (recorded)" in row
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  the status register marks a recorded entry")

    print(f"{len(cases) + 1 - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
