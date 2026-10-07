#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Negative tests for validate_docs.py: recorded verifications (ADR 003, OD-31), authors and
verifiers, and the register IDs (ADR 012).

Run:
  uv run --with pyyaml==6.0.2 python scripts/test_validate_docs.py

Each case copies docs/, config/ and AGENTS.md to a temporary directory, changes one file,
and checks what the validator reports.
"""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

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


ADR = "docs/adr/011-launch-scope.md"
OPEN_ROW = "\n## Closed"


def _edited(validator, edits: list[tuple[str, Any]]) -> list[str]:
    """Every error after applying (path, change) edits to a fresh copy, as `path: message`."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        _copy(root)
        for rel, change in edits:
            path = root / rel
            if callable(change):
                path.write_text(change(path.read_text(encoding="utf-8")), encoding="utf-8")
            else:
                shutil.copy(root / change, path)
        return [f"{i.path}: {i.message}" for i in validator.validate(root) if not i.warning]


def _author(actor: str):
    return lambda text: text.replace("  by: claude-code/opus-5.5\n  at:", f"  by: {actor}\n  at:", 1)


def _verified(actor: str):
    return lambda text: text.replace("verified: []", f"verified:\n  - by: {actor}\n    at: 2026-10-07T07:00:00Z", 1)


PR = "https://github.com/lidofinance/clutch/pull/1"


def _entry(actor: str, at: str, digest: str | None = None, ref: str | None = None, recorded_by: str | None = None) -> str:
    lines = [f"  - by: {actor}", f"    at: {at}"]
    if recorded_by:
        lines.append(f"    recorded_by: {recorded_by}")
    if ref:
        lines.append(f"    ref: {ref}")
    if digest:
        lines.append(f"    sha256: {digest}")
    return "\n".join(lines)


def _with_entry(validator, actor: str, at: str, ref: str | None = None, recorded_by: str | None = None,
                hashed: bool = True, edit_body: bool = False):
    """Add one verification to a page, with the hash of its body, and optionally edit the body after."""
    def change(text: str) -> str:
        digest = validator.body_hash(text) if hashed else None
        text = text.replace("verified: []", "verified:\n" + _entry(actor, at, digest, ref, recorded_by), 1)
        return text + "\nA later edit.\n" if edit_body else text
    return change


def _accepted_by(actor: str):
    return lambda text: text.replace("decision: proposed", f"decision: accepted\naccepted_by: {actor}", 1)


def _first_inv_row(text: str) -> str:
    return next(line for line in text.splitlines() if line.startswith("| INV-"))


EDIT_CASES = [
    ("any agent may author a page", [(ADR, _author("codex/gpt-5"))], None),
    ("an unlisted human may not author a page", [(ADR, _author("human:stranger"))], "is not in config/actors.yaml"),
    ("an agent never verifies", [(ADR, _verified("codex/gpt-5"))], "must name a human"),
    ("an unlisted human cannot verify", [(ADR, _verified("human:stranger"))], "is not in config/actors.yaml"),
    ("an OD ID is used once", [("docs/registers/open-decisions.md", lambda t: t.replace(
        OPEN_ROW, "\n| OD-01 | A copy | [ADR 012](/adr/012-contributing-with-many-agents.md) | A | EM |\n" + OPEN_ROW, 1))],
     "OD-01 appears in more than one row"),
    ("an open decision needs a recommendation", [("docs/registers/open-decisions.md", lambda t: t.replace(
        OPEN_ROW, "\n| OD-98 | A question? | [ADR 012](/adr/012-contributing-with-many-agents.md) |  | EM |\n" + OPEN_ROW, 1))],
     "OD-98: an open decision needs"),
    ("an invariant ID is used once", [("docs/specs/invariants.md", lambda t: t + "\n" + _first_inv_row(t) + "\n")],
     "appears in more than one row"),
    ("an ADR number is used once", [("docs/adr/011-a-copy.md", ADR)], "ADR 011 is taken by"),
]


def _lock_cases(validator) -> list[tuple[str, list[tuple[str, Any]], str | None]]:
    """Cases for team verifications (OD-50) and the body hash (OD-51)."""
    return [
        ("a team verifies with its pull request", [(ADR, _with_entry(validator, "human:defi-tech", "2026-10-07T07:00:00Z", ref=PR))], None),
        ("a team's verification needs its pull request", [(ADR, _with_entry(validator, "human:defi-tech", "2026-10-07T07:00:00Z"))],
         "the link to the pull request that a member approved"),
        ("a team's ref must be a pull request", [(ADR, _with_entry(validator, "human:defi-tech", "2026-10-07T07:00:00Z", ref="https://example.org/x"))],
         "the link to the pull request that a member approved"),
        ("an agent never records a team's verification", [(ADR, _with_entry(
            validator, "human:defi-tech", "2026-10-07T07:00:00Z", ref=PR, recorded_by="claude-code/opus-5.5"))],
         "an agent never records a body's or a team's verification"),
        ("a team never accepts an ADR", [(ADR, lambda t: _accepted_by("human:defi-tech")(
            _with_entry(validator, "human:defi-tech", "2026-10-07T07:00:00Z", ref=PR)(t)))],
         "only EM or the committee accepts an ADR"),
        ("a new verification records the body's hash", [(ADR, _with_entry(validator, "human:em", "2026-10-07T07:00:00Z", hashed=False))],
         "needs `sha256`, the hash of the page's body"),
        ("a verification before 2026-10-07 needs no hash", [(ADR, _with_entry(validator, "human:em", "2026-10-06T23:00:00Z", hashed=False))], None),
        ("an edit after a verification fails", [(ADR, _with_entry(validator, "human:em", "2026-10-07T07:00:00Z", edit_body=True))],
         "the body changed after the latest verification"),
    ]


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
         "an agent never records a body's or a team's verification"),
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

    baseline = set(_edited(validator, []))  # the copy lacks files outside docs/, which some links reach
    edit_cases = EDIT_CASES + _lock_cases(validator)
    for name, edits, expected in edit_cases:
        errors = [e for e in _edited(validator, edits) if e not in baseline]
        ok = not errors if expected is None else any(expected in message for message in errors)
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f"\n      got: {errors[:3]}"))

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        _copy(root)
        register = validator.render_status(root)
        row = next((line for line in register.splitlines() if PAGE.removeprefix("docs/") in line), "")
        ok = "human:em (recorded)" in row
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  the status register marks a recorded entry")

    print(f"{len(cases) + len(edit_cases) + 1 - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
