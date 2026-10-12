#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Negative tests for the checks of build_onboarding.py (OD-37).

Run:
  uv run --with pyyaml python scripts/test_build_onboarding.py

Each content case changes one item of the committed content in memory and checks
that the build refuses it with the expected message. The pin cases do the same with
the committed pins: a changed item, a changed source, a new item and a removed item
each need a review and a new pin. The page cases render the committed content and
check that the page loads nothing from outside itself, escapes the text it is given,
shows no fork-test stand-in address and gives no element a widget role without its
script.
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


def _first_change(c):
    return next(ch for b in c["mandate"]["blocks"] for ch in b.get("changes", []))


def _first_ask(c, verdict=None):
    return next(ask for sec in c["rfp"]["sections"] for ask in sec.get("items", []) if verdict in (None, ask["verdict"]))


def _spare_node(c):
    node = copy.deepcopy(c["map"]["nodes"][0])
    node["id"] = "spare"
    c["map"]["nodes"].append(node)


def _spare_edge(c):
    edge = copy.deepcopy(c["map"]["edges"][0])
    edge["id"] = "spare-edge"
    c["map"]["edges"].append(edge)


def _coverage(group, name, reason=None, drop=False):
    def change(c):
        excluded = c["coverage"].setdefault(group, {}) or {}
        c["coverage"][group] = excluded
        if drop:
            excluded.pop(name)
        else:
            excluded[name] = reason
    return change


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
    ("a duplicate mandate block", lambda c: c["mandate"]["blocks"].append(copy.deepcopy(c["mandate"]["blocks"][0])), "duplicate id"),
    ("a mandate block without sources", lambda c: c["mandate"]["blocks"][0].update(sources=[]), "no sources"),
    ("a mandate change without sources", lambda c: _first_change(c).update(sources=[]), "no sources"),
    ("a mandate change in an unknown state", lambda c: _first_change(c).update(state="done"), "bad state done"),
    ("a control line on an unknown layer", lambda c: c["mandate"]["blocks"][0]["kept"].append("Onchain: a typo."), "unknown layer Onchain"),
    ("a percentage from the mandate draft", lambda c: c["mandate"]["blocks"][0].update(says="Up to 99 % each."), "must not appear"),
    ("a dollar figure from the mandate draft", lambda c: _first_change(c).update(why="It frees $1."), "must not appear"),
    ("a constellation change of an unknown kind", lambda c: c["constellation"]["changes"][0].update(kind="moved"), "bad kind moved"),
    ("an unknown source in the constellation", lambda c: c["constellation"]["changes"][0]["sources"].append("OD-99"), "unknown open decision OD-99"),
    ("a planned part without sources", lambda c: c["constellation"]["planned"][0].update(sources=[]), "no sources"),
    ("an ask that the research note does not hold", lambda c: _first_ask(c).update(asked="An ask that the request never made."),
     "the ask is not in docs/research/request-for-solution-2026-10-07.md"),
    ("an ask with an unknown verdict", lambda c: _first_ask(c).update(verdict="done"), "bad verdict done"),
    ("a changed ask without a reason", lambda c: _first_ask(c, "changed").pop("why"), "a change needs a why"),
    ("an ask without sources", lambda c: _first_ask(c).update(sources=[]), "no sources"),
    ("an addition without sources", lambda c: c["rfp"]["sections"][0]["added"][0].update(sources=[]), "no sources"),
    ("a duplicate RFP part", lambda c: c["rfp"]["sections"].append(copy.deepcopy(c["rfp"]["sections"][0])), "duplicate id"),
    ("a missing research note", lambda c: c["rfp"].update(note="docs/research/no-such-note.md"), "missing note docs/research/no-such-note.md"),
    ("a banner without the draft disclaimer", lambda c: c["meta"].update(banner="A finished design."), "must keep the draft disclaimer 'hypothetical draft'"),
    ("a banner that drops 'nothing is ratified'", lambda c: c["meta"].update(banner="**Hypothetical draft.** Approved."), "must keep the draft disclaimer 'nothing is ratified'"),
    ("a footer without the draft disclaimer", lambda c: c["meta"].update(footer="How this page is made."), "meta footer: must keep the draft disclaimer"),
    ("a whole ADR as a source", _source("ADR-007"), "ADR-007 names no decision or heading"),
    ("a reference to one decision of an ADR", _source("ADR-007#d27"), None),
    ("a reference to a section of an ADR", _source("ADR-007#consequences"), None),
    ("a reference to a decision that the ADR lacks", _source("ADR-007#d999"), "ADR-007 has no decision 999"),
    ("a reference to a heading that the ADR lacks", _source("ADR-007#no-such-heading"), "ADR-007 has no heading #no-such-heading"),
    ("an assumption without an id", lambda c: c["assumptions"][0].pop("id"), "assumption 1: needs an id"),
    ("two assumptions with one id", lambda c: c["assumptions"][1].update(id=c["assumptions"][0]["id"]), "duplicate id"),
    ("a question without an id", lambda c: c["quiz"][0].update(id="Not A Slug"), "quiz 1: needs an id"),
    ("a box that no flow step or scene lights", _spare_node, "lights the box spare"),
    ("an arrow that no flow step or scene walks", _spare_edge, "walks the arrow spare-edge"),
    ("an ADR that is neither cited nor excluded", _coverage("adrs", "ADR-012", drop=True), "ADR-012 is not cited and not excluded"),
    ("an invariant that is neither cited nor excluded", _coverage("invariants", "INV-007", drop=True), "INV-007 is not cited and not excluded"),
    ("a cited ADR that is also excluded", _coverage("adrs", "ADR-005", "A reason."), "ADR-005 is cited and also excluded"),
    ("an exclusion without a reason", _coverage("adrs", "ADR-012", ""), "the exclusion of ADR-012 needs a reason"),
    ("an exclusion of something that does not exist", _coverage("runbooks", "runbook:No such runbook", "A reason."), "the excluded runbook:No such runbook does not exist"),
]


def _repinned_source(pins):
    """The pins with one source hash changed, as if the source had changed since the review."""
    key = next(k for k, v in pins.items() if v["sources"])
    ref = next(iter(pins[key]["sources"]))
    pins[key]["sources"][ref] = "0" * 16
    return f"pin {key}: the source {ref} changed"


PIN_CASES = [
    ("the committed pins match the content and the sources", lambda c, p: None, None),
    ("a changed item needs a new pin", lambda c, p: c["actors"][0].update(what="A changed text."), f"pin actor:{{a0}}: its content changed"),
    ("a changed source needs a new pin", lambda c, p: _repinned_source(p), "the source"),
    ("a new item has no pin yet", lambda c, p: c["glossary"].append({"term": "Spare term", "plain": "A spare term.", "sources": ["ADR-005#d6"]}),
     "pin term:spare-term: it has no pin yet"),
    ("an item that is gone leaves a pin that must go", lambda c, p: p.update({"actor:gone": {"content": "0", "sources": {}}}),
     "pin actor:gone: the item no longer exists"),
    ("a new source of an item needs a new pin", lambda c, p: c["actors"][0]["sources"].append("OD-01"), "it cites a new source OD-01"),
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

    pins = b.read_pins()
    for name, change, expected in PIN_CASES:
        c = copy.deepcopy(content)
        p = copy.deepcopy(pins)
        result = change(c, p)
        expected = expected.replace("{a0}", content["actors"][0]["id"]) if expected else expected
        if isinstance(result, str):
            expected = result
        try:
            b.check(c, facts, p)
        except b.BuildError as exc:
            report(expected is not None and expected in str(exc), name, str(exc))
        else:
            report(expected is None, name, "accepted")

    where = {
        "decision": b.locate("ADR-007#d27", facts),
        "section": b.locate("ADR-007#proposed-direction", facts),
        "row": b.locate("OD-57", facts),
        "test": b.locate("test:test_D3_withdrawal_queue_is_out_of_scope", facts),
        "lip": b.locate("lip:part-8", facts),
    }
    texts = {k: b.extract((ROOT / w["path"]).read_text(encoding="utf-8"), w) for k, w in where.items()}
    report(texts["decision"].startswith("27. ") and "Decision 27 replaces" in texts["decision"] and "\n28. " not in texts["decision"],
           "a decision reference pins that decision and the notes that name it", texts["decision"][:80])
    report(texts["section"].startswith("## Proposed direction") and "## Options considered" not in texts["section"],
           "a heading reference pins that section alone", texts["section"][:80])

    # A later decision that replaces an earlier one leaves the earlier text as it was, so the
    # earlier decision's pin also covers every block of the Decision section that names it.
    adr = "## Decision\n\n1. Budgets retune.\n2. Budgets stay.\n   - Set once.\n\nDecision 2 replaces decision 1.\n\n" \
          "3. Monitoring pages ([ADR 010](/adr/010-x.md) decision 1).\n\n## Proposed direction\n\n- Not pinned.\n"
    report(b.decision_text(adr, "ADR-099", "1") == "1. Budgets retune.\n\nDecision 2 replaces decision 1.",
           "a decision's pin covers the note that replaces it, and not another ADR's decision 1", repr(b.decision_text(adr, "ADR-099", "1")))
    report(b.decision_text(adr, "ADR-099", "2") == "2. Budgets stay.\n   - Set once.\n\nDecision 2 replaces decision 1.",
           "a decision's pin keeps its indented lines", repr(b.decision_text(adr, "ADR-099", "2")))
    report(b._named_decisions("Decisions 17 to 20 replace decisions 1, 3, 6 to 12 and 14; decision 15's count", "ADR-007")
           == {str(n) for n in [1, 3, 6, 7, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20]}, "lists and ranges of decisions are read")
    adr9 = (ROOT / facts["adrs"]["ADR-009"]["path"]).read_text(encoding="utf-8")
    report("Decision 31 replaces decision 5" in b.decision_text(adr9, "ADR-009", "5"), "ADR 009's decision 5 pins the note that replaces it")
    report(texts["row"].startswith("| OD-57 |"), "an OD reference pins its row", texts["row"][:80])
    report(texts["test"].startswith("function test_D3_withdrawal_queue_is_out_of_scope(") and texts["test"].endswith("}"),
           "a test reference pins the test function", texts["test"][-80:])
    report(texts["lip"].startswith("#### Part 8"), "a LIP reference pins its part", texts["lip"][:80])
    report(b.digest(b.normalize("a  b\n c")) == b.digest(b.normalize("a b c")), "a re-wrapped source keeps its pin")

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

    widget = re.findall(r'role="(?:tab|tablist|tabpanel|button)"|aria-controls=|tabindex="0"', page)
    report(not widget, "the page gives no element a widget role without its script", str(widget[:5]))

    chips = re.findall(r'class="src"[^>]*>([^<]+)<', b.source_links(["ADR-007#d27", "OD-57", "ADR-007#d18", "ADR-007#consequences"], refs | {
        r: b.resolve(r, facts) for r in ("ADR-007#d27", "ADR-007#d18", "OD-57", "ADR-007#consequences")}))
    report(chips == ["ADR 007, decisions 18 and 27", "OD-57", "ADR 007: Consequences"], "the decisions of one ADR share a chip", str(chips))

    total = len(CONTENT_CASES) + len(PIN_CASES) + 10 + 6 + 2
    print(f"{total - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
