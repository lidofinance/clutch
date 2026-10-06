#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Negative tests for the checks of build_onboarding.py (OD-37).

Run:
  uv run --with pyyaml python scripts/test_build_onboarding.py

Each content case changes one item of the committed content in memory and checks
that the build refuses it with the expected message. The page cases render the
committed content and check that the page loads nothing from outside itself, escapes
the text it is given, and shows no fork-test stand-in address.
"""

from __future__ import annotations

import copy
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load_builder():
    spec = importlib.util.spec_from_file_location("build_onboarding", ROOT / "scripts" / "build_onboarding.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["build_onboarding"] = module
    spec.loader.exec_module(module)
    return module


def _source(ref: str):
    return lambda c: c["actors"][0]["sources"].append(ref)


CONTENT_CASES = [
    ("the committed content passes", lambda c: None, None),
    ("an unknown ADR", _source("ADR-999"), "unknown ADR ADR-999"),
    ("an unknown open decision", _source("OD-99"), "unknown open decision OD-99"),
    ("an unknown invariant", _source("INV-999"), "unknown invariant INV-999"),
    ("an unknown test", _source("test:test_no_such_test"), "unknown test test_no_such_test"),
    ("an unknown runbook", _source("runbook:No such runbook"), "unknown runbook 'No such runbook'"),
    ("an unknown LIP part", _source("lip:part-99"), "unknown LIP part 99"),
    ("a missing file", _source("doc:docs/no-such-page.md"), "missing file docs/no-such-page.md"),
    ("a missing heading", _source("doc:ROADMAP.md#no-such-heading"), "missing heading #no-such-heading"),
    ("an unrecognised reference", _source("see the forum"), "unrecognised reference"),
    ("a card without sources", lambda c: c["actors"][0].update(sources=[]), "no sources"),
    ("a glossary link without a term", lambda c: c["actors"][0].update(what="See [[no such term]]."), "[[no such term]] is not a term"),
    ("an address that the repository does not record", lambda c: c["actors"][0].update(address="0x" + "12" * 20), "is not recorded"),
    ("an actor on an unknown node", lambda c: c["actors"][0].update(node="nowhere"), "unknown node nowhere"),
    ("a bad actor label", lambda c: c["actors"][0].update(label="done"), "bad label done"),
    ("a role that the artifact does not have", lambda c: c["actors"][0].update(role="admin"), "no role admin in the policy artifact"),
    ("a duplicate actor", lambda c: c["actors"].append(copy.deepcopy(c["actors"][0])), "duplicate id"),
    ("a flow step on an unknown node", lambda c: c["flows"]["flows"][0]["steps"][0]["nodes"].append("nowhere"), "unknown node nowhere"),
    ("a flow step on an unknown edge", lambda c: c["flows"]["flows"][0]["steps"][0].setdefault("edges", []).append("no-edge"), "unknown edge no-edge"),
    ("a bad flow label", lambda c: c["flows"]["flows"][0].update(label="done"), "bad label done"),
    ("a flow in an unknown group", lambda c: c["flows"]["flows"][0].update(group="nowhere"), "unknown group"),
    ("a tour scene with an unknown flow", lambda c: c["tour"][0].setdefault("flows", []).append("no-flow"), "unknown flow no-flow"),
    ("a map edge to an unknown node", lambda c: c["map"]["edges"][0].update(to="nowhere"), "bad endpoint or kind"),
    ("a quiz answer out of range", lambda c: c["quiz"][0].update(answer=9), "answer out of range"),
    ("a reuse row in an unknown column", lambda c: c["reuse"][0].update(column="other"), "bad column"),
    ("an unknown watched-by reference", lambda c: c["assumptions"][0].setdefault("watched_by", []).append("INV-999"), "unknown invariant INV-999"),
]


def main() -> int:
    b = _load_builder()
    content = b.load()
    facts = b.facts()
    failures = 0

    def report(ok: bool, name: str, detail: str = "") -> None:
        nonlocal failures
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f"\n      got: {detail}"))

    for name, change, expected in CONTENT_CASES:
        c = copy.deepcopy(content)
        change(c)
        try:
            b.check(c, facts)
        except b.BuildError as exc:
            report(expected is not None and expected in str(exc), name, str(exc))
        else:
            report(expected is None, name, "accepted")

    try:
        b.parse_yaml("check: one\ncheck: two\n")
    except b.BuildError as exc:
        report("the key 'check' appears twice" in str(exc), "a repeated key in a content file", str(exc))
    else:
        report(False, "a repeated key in a content file", "accepted")

    refs = b.check(content, facts)
    page = b.render(content, facts, refs)

    external = [m for m in re.findall(r'(?:src|href)="(https?:[^"]*)"', page) if not m.startswith(b.REPO_URL)]
    loaders = re.findall(r"<(?:script|img|iframe|link|object|embed)\b[^>]*\b(?:src|href)=", page) + re.findall(r"@import|url\(\s*['\"]?https?:", page)
    report(not external and not loaders, "the page loads nothing from outside itself", f"{external[:3]} {loaders[:3]}")
    report("default-src 'none'" in page, "the page carries its content security policy")

    c = copy.deepcopy(content)
    c["actors"][0]["what"] = "<script>alert(1)</script> & <b>"
    escaped = b.render(c, facts, refs)
    report("<script>alert(1)" not in escaped and "&lt;script&gt;alert(1)" in escaped, "the page escapes the text it is given")

    report(not b.stand_in_leaks(page), "the committed content shows no fork-test stand-in address", str(b.stand_in_leaks(page)))
    stand_in = sorted(b.fork_only_addresses())[0]
    f = copy.deepcopy(facts)
    f["policy"][0]["members"] = [stand_in]
    report(b.stand_in_leaks(b.render(content, f, refs)) == [stand_in], "a stand-in address from the artifact is caught")

    total = len(CONTENT_CASES) + 6
    print(f"{total - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
