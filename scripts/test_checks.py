#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Tests of the repository checks of ADR 012: the log build, the redaction and secret
check, the licence check and the invariant check.

Run:
  uv run --with pyyaml==6.0.2 python scripts/test_checks.py

Every case builds its own input. Test values that look like a secret are assembled at run
time, so this file itself passes the redaction check.
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


LOG = _load("build_log")
VERIFY = _load("verify_page")
RED = _load("check_redaction")
LIC = _load("check_licences")
INV = _load("check_invariants")


def _denylist(words=(), addresses=(), figures=()):
    """A denylist built from neutral test terms, in the shape that check_redaction.load returns."""
    by_length: dict[int, set[str]] = {}
    for word in words:
        value = RED.normalize("word", word)
        by_length.setdefault(len(value), set()).add(RED.digest("word", value))
    return {
        "word": by_length,
        "address": {RED.digest("address", RED.normalize("address", a)) for a in addresses},
        "figure": {RED.digest("figure", RED.normalize("figure", f)) for f in figures},
    }


def _kinds(text: str, denylist) -> list[str]:
    return [kind for _, kind in RED.scan_text(text, denylist)]


def _fragments(files: dict[str, str]):
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for name, body in files.items():
            (folder / name).write_text(body, encoding="utf-8")
        LOG.FRAGMENTS = folder
        try:
            return LOG.fragments(), None
        except LOG.LogError as exc:
            return None, str(exc)


def _invariants(table: str, known: set[str]) -> list[str]:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "invariants.md"
        path.write_text(table, encoding="utf-8")
        INV.TABLE = path
        INV.tests = lambda: known
        return INV.problems()


PAGE = "---\ntype: Decision\nreview_status: slop\n{verified}\nsources: []\n---\n# Body\n"
ZEBRA = _denylist(words=["zebracorn"], addresses=["0x" + "ab" * 20], figures=["42%", "$7.5M"])
KEY = "0x" + "c0ffee" * 10 + "abcd"
ROW = "| INV-901 | A property. | [ADR 001](/adr/001.md) | {state} | {tests} |"

CASES = [
    # The log.
    ("a fragment builds its entry", lambda: _fragments({"2026-10-07T101010Z-one.yaml": "date: 2026-10-07\nkind: Update\ntext: One line.\n"})[0][0][1]["text"] == "One line."),
    ("a fragment name needs its time", lambda: "the name must be" in _fragments({"2026-10-07-one.yaml": "date: 2026-10-07\nkind: Update\ntext: x\n"})[1]),
    ("a fragment's date matches its name", lambda: "differs from the date in the name" in _fragments({"2026-10-07T101010Z-one.yaml": "date: 2026-10-06\nkind: Update\ntext: x\n"})[1]),
    ("a fragment's kind is known", lambda: "`kind` must be one of" in _fragments({"2026-10-07T101010Z-one.yaml": "date: 2026-10-07\nkind: Gossip\ntext: x\n"})[1]),
    ("a fragment holds one line", lambda: "one non-empty line" in _fragments({"2026-10-07T101010Z-one.yaml": "date: 2026-10-07\nkind: Update\ntext: |\n  a\n  b\n"})[1]),
    ("the log lists the newest date and entry first", lambda: LOG.render([
        ("2026-10-06T000001Z-a.yaml", {"date": "2026-10-06", "kind": "Update", "text": "old"}),
        ("2026-10-07T000001Z-b.yaml", {"date": "2026-10-07", "kind": "Update", "text": "early"}),
        ("2026-10-07T120000Z-c.yaml", {"date": "2026-10-07", "kind": "Decision", "text": "late"}),
    ]) == "# Log\n\n## 2026-10-07\n\n* **Decision**: late\n* **Update**: early\n\n## 2026-10-06\n\n* **Update**: old\n"),
    # Restricted terms.
    ("a restricted word is found in any case", lambda: _kinds("Ask ZebraCorn about it.", ZEBRA) == ["restricted word"]),
    ("a restricted word is found inside a longer word", lambda: _kinds("deploy zebracornGuard", ZEBRA) == ["restricted word"]),
    ("a restricted word is found across a hyphen", lambda: _kinds("zebra-corn", ZEBRA) == ["restricted word"]),
    ("an ordinary word passes", lambda: _kinds("A zebra and a unicorn.", ZEBRA) == []),
    ("a restricted address is found in any case", lambda: _kinds("at 0x" + "AB" * 20 + " today", ZEBRA) == ["restricted address"]),
    ("a restricted percentage is found with a space", lambda: _kinds("a cap of 42 % each", ZEBRA) == ["restricted figure"]),
    ("a restricted amount is found in another notation", lambda: _kinds("about $7.50 million", ZEBRA) == ["restricted figure"]),
    ("another figure passes", lambda: _kinds("a cap of 41% and $7.5k", ZEBRA) == []),
    # Secrets.
    ("a private key assignment is a secret", lambda: _kinds("PRIVATE" + "_KEY=" + KEY, ZEBRA) == ["private key"]),
    ("a placeholder key passes", lambda: _kinds("PRIVATE" + "_KEY=0x...", ZEBRA) == []),
    ("a bare hash passes", lambda: _kinds("codehash " + KEY, ZEBRA) == []),
    ("an RPC URL with a key is a secret", lambda: _kinds("RPC=https://lb.drpc.org/ogrpc?network=ethereum&dk" + "ey=" + "A1b2C3d4E5f6G7h8I9j0", ZEBRA) == ["RPC URL with a key"]),
    ("an RPC URL without a key passes", lambda: _kinds("RPC=https://your-archive-mainnet-rpc", ZEBRA) == []),
    ("a GitHub token is a secret", lambda: _kinds("token gh" + "p_" + "a" * 36, ZEBRA) == ["GitHub token"]),
    ("a CI secret reference passes", lambda: _kinds("RPC_TOKEN: ${{ secrets.FORK_RPC }}", ZEBRA) == []),
    ("a PEM private key is a secret", lambda: _kinds("-----BEGIN " + "PRIVATE KEY-----", ZEBRA) == ["PEM private key"]),
    # Licences.
    ("the blob hash equals git's", lambda: LIC.blob(b"hello\n") == "ce013625030ba8dba906f756967f9e9ca394464a"),
    ("an SPDX line is read from the header", lambda: _spdx("// SPDX-License-Identifier: LGPL-3.0-only\npragma x;\n") == "LGPL-3.0-only"),
    ("a file without an SPDX line has none", lambda: _spdx("pragma x;\n") is None),
    # Invariants.
    ("a Draft invariant with an existing test passes", lambda: _invariants(ROW.format(state="Draft", tests="`test_a`"), {"test_a"}) == []),
    ("a missing test fails", lambda: any("which no test/*.t.sol file defines" in p for p in _invariants(ROW.format(state="Draft", tests="`test_gone`"), {"test_a"}))),
    ("a Draft invariant without a test fails", lambda: any("names no test" in p for p in _invariants(ROW.format(state="Draft", tests="None yet"), set()))),
    ("a Pending invariant may wait for its test", lambda: _invariants(ROW.format(state="Pending: not built", tests="None yet"), set()) == []),
    # The verification helper.
    ("a first verification replaces the empty list", lambda: VERIFY.add_entry(PAGE.format(verified="verified: []"), ["by: human:em", "at: T", "sha256: h"])
     == PAGE.format(verified="verified:\n  - by: human:em\n    at: T\n    sha256: h")),
    ("a later verification goes after the earlier ones", lambda: VERIFY.add_entry(PAGE.format(verified="verified:\n  - by: human:em\n    at: T1"), ["by: human:tmc", "at: T2"])
     == PAGE.format(verified="verified:\n  - by: human:em\n    at: T1\n  - by: human:tmc\n    at: T2")),
    ("the helper can set the review status", lambda: "review_status: human-reviewed" in VERIFY.add_entry(PAGE.format(verified="verified: []"), ["by: human:em", "at: T"], "human-reviewed")),
    ("the helper keeps the body as it was", lambda: VERIFY.add_entry(PAGE.format(verified="verified: []"), ["by: human:em", "at: T"]).endswith("\n---\n# Body\n")),
]


def _spdx(text: str):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "x.sol"
        path.write_text(text, encoding="utf-8")
        return LIC.licence(path)


def main() -> int:
    failures = 0
    for name, case in CASES:
        try:
            ok = bool(case())
        except Exception as exc:  # a crash is a failure, with its reason
            ok = False
            name = f"{name} ({type(exc).__name__}: {exc})"
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}")
    print(f"{len(CASES) - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
