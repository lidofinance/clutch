#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Build the onboarding guide: docs/onboarding/clutch-onboarding.html.

Run:
  uv run --with pyyaml python scripts/build_onboarding.py           # write the page
  uv run --with pyyaml python scripts/build_onboarding.py --check   # fail if the page is stale

The guide's text lives in docs/onboarding/content/*.yaml. Facts that the
repository already states are read at build time: ADR titles and states, open
decisions, invariants, runbooks, the LIP's status labels, the roadmap, the
review state of every page, and the roles and permissions of the compiled
policy artifact. Every reference in the content must resolve, or the build
fails. The output is one self-contained HTML file with no external requests.
The content renders without JavaScript; the script only adds interaction.
"""

from __future__ import annotations

import argparse
import html
import importlib.util
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
GUIDE = ROOT / "docs" / "onboarding"
CONTENT = GUIDE / "content"
SRC = GUIDE / "src"
OUT = GUIDE / "clutch-onboarding.html"
ARTIFACT = ROOT / "policy" / "constellation" / "artifacts" / "fork-25946643.json"
REPO_URL = "https://github.com/lidofinance/clutch/blob/main/"

DOMAINS = {"gov", "ops", "vault", "ext"}
KINDS = {"body", "multisig", "contract", "service", "external"}
STATUSES = {
    "existing": "Exists today",
    "instance": "New instance of existing code",
    "new": "New code",
    "mixed": "Existing and new parts",
}
LABELS = {
    "built": ("Built and tested on a fork", "✓"),
    "specified": ("Specified, not built", "◐"),
    "open": ("Open", "○"),
    "existing": ("Existing on mainnet", "●"),
    "planned": ("Planned", "◌"),
}
EDGE_KINDS = {"owns", "role", "executes", "screens", "governs", "funds", "recovers", "safety", "watches", "signers", "reports"}


class BuildError(Exception):
    pass


def _validator():
    spec = importlib.util.spec_from_file_location("validate_docs", ROOT / "scripts" / "validate_docs.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["validate_docs"] = module  # dataclasses need the module registered
    spec.loader.exec_module(module)
    return module


V = _validator()


# --------------------------------------------------------------------------
# Repository facts
# --------------------------------------------------------------------------

def _rows(text: str, first_cell: str) -> list[list[str]]:
    """Table rows whose first cell matches the regex `first_cell`."""
    out = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and re.fullmatch(first_cell, cells[0]):
            out.append(cells)
    return out


def _plain(md: str) -> str:
    """Markdown cell text without links, emphasis or code ticks."""
    md = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", md)
    return md.replace("**", "").replace("`", "").strip()


def facts() -> dict[str, Any]:
    docs = ROOT / "docs"
    adrs = {}
    for path in sorted((docs / "adr").glob("[0-9][0-9][0-9]-*.md")):
        meta, _ = V._frontmatter(path.read_text(encoding="utf-8"))
        number = path.name[:3]
        title = re.sub(r"\AADR \d{3}:\s*", "", str(meta.get("title", "")))
        adrs[f"ADR-{number}"] = {
            "title": title,
            "decision": meta.get("decision", ""),
            "review": meta.get("review_status", ""),
            "path": path.relative_to(ROOT).as_posix(),
        }

    od_text = (docs / "registers" / "open-decisions.md").read_text(encoding="utf-8")
    open_part, _, closed_part = od_text.partition("## Closed")
    ods = {}
    for cells in _rows(open_part, r"OD-\d{2}"):
        ods[cells[0]] = {"question": _plain(cells[1]), "state": "open"}
    for cells in _rows(closed_part, r"OD-\d{2}"):
        ods[cells[0]] = {"question": _plain(cells[1]), "state": "closed", "closed": cells[2]}

    inv_text = (docs / "specs" / "invariants.md").read_text(encoding="utf-8")
    invariants = {}
    for cells in _rows(inv_text, r"INV-\d{3}"):
        invariants[cells[0]] = {"text": _plain(cells[1]), "status": _plain(cells[3]), "tests": _plain(cells[4])}

    rb_text = (docs / "runbooks" / "index.md").read_text(encoding="utf-8")
    runbooks = {}
    for cells in _rows(rb_text, r"[A-Z][^|]*"):
        if cells[0] in ("Runbook",) or len(cells) < 5:
            continue
        runbooks[cells[0]] = {"holder": _plain(cells[1]), "written": cells[3], "drilled": cells[4]}

    lip_path = docs / "specs" / "lip-draft.md"
    lip = {}
    for line in lip_path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"#### Part (\d+): (.+?) \*\*\[(.+?)\]\*\*\s*$", line)
        if match:
            slug = re.sub(r"[^\w\- ]", "", line.lstrip("#").strip().lower()).replace(" ", "-")
            lip[match.group(1)] = {"title": match.group(2), "label": match.group(3), "anchor": slug}

    roadmap = []
    for cells in _rows((ROOT / "ROADMAP.md").read_text(encoding="utf-8"), r"\d\. .+"):
        roadmap.append({"phase": cells[0], "job": _plain(cells[1]), "gate": _plain(cells[2])})

    reviews: Counter[str] = Counter()
    for path in V._concepts(docs):
        meta, _ = V._frontmatter(path.read_text(encoding="utf-8"))
        if meta:
            reviews[str(meta.get("review_status", ""))] += 1

    tests: dict[str, str] = {}
    for path in sorted((ROOT / "test").rglob("*.t.sol")):
        for name in re.findall(r"function (test_\w+)\s*\(", path.read_text(encoding="utf-8")):
            tests[name] = path.relative_to(ROOT).as_posix()

    return {
        "adrs": adrs,
        "ods": ods,
        "invariants": invariants,
        "runbooks": runbooks,
        "lip": lip,
        "roadmap": roadmap,
        "reviews": dict(sorted(reviews.items())),
        "tests": dict(sorted(tests.items())),
        "policy": policy(),
    }


def recorded_addresses(folders: tuple[str, ...] = ("docs", "policy/constellation/constellation", "script")) -> set[str]:
    """Every address in the given folders, in lower case. The guide itself does not count."""
    found: set[str] = set()
    for folder in folders:
        for path in (ROOT / folder).rglob("*"):
            if path.is_file() and path.suffix in (".md", ".ts", ".sol", ".json") and GUIDE not in path.parents:
                found.update(a.lower() for a in re.findall(r"0x[0-9a-fA-F]{40}", path.read_text(encoding="utf-8")))
    return found


def policy() -> list[dict[str, Any]]:
    """Each role of the compiled artifact: its modifier, members and permitted calls."""
    artifact = json.loads(ARTIFACT.read_text(encoding="utf-8"))
    roles = []
    for modifier in artifact["modifiers"]:
        for role in modifier["roles"]:
            targets = []
            for target in role["targets"]:
                calls = [f["signature"] or f["selector"] for f in target["functions"]]
                targets.append({"name": target["name"] or target["address"], "calls": calls})
            roles.append({
                "role": role["name"],
                "modifier": modifier["ref"].replace("_", " "),
                "members": [m["name"] or m["address"] for m in role["members"]],
                "targets": targets,
                "keys": [k["name"] for k in modifier.get("allowances", [])],
            })
    return roles


# --------------------------------------------------------------------------
# References
# --------------------------------------------------------------------------

def resolve(ref: str, f: dict[str, Any]) -> dict[str, str]:
    """A source reference as a label and a link. Raises BuildError if it does not resolve."""
    if re.fullmatch(r"ADR-\d{3}", ref):
        if ref not in f["adrs"]:
            raise BuildError(f"unknown ADR {ref}")
        return {"label": ref.replace("-", " "), "href": REPO_URL + f["adrs"][ref]["path"], "title": f["adrs"][ref]["title"]}
    if re.fullmatch(r"OD-\d{2}", ref):
        if ref not in f["ods"]:
            raise BuildError(f"unknown open decision {ref}")
        return {"label": ref, "href": REPO_URL + "docs/registers/open-decisions.md", "title": f["ods"][ref]["question"]}
    if re.fullmatch(r"INV-\d{3}", ref):
        if ref not in f["invariants"]:
            raise BuildError(f"unknown invariant {ref}")
        return {"label": ref, "href": REPO_URL + "docs/specs/invariants.md", "title": f["invariants"][ref]["text"]}
    if ref.startswith("test:"):
        name = ref[5:]
        if name not in f["tests"]:
            raise BuildError(f"unknown test {name}")
        return {"label": name, "href": REPO_URL + f["tests"][name], "title": f"Test {name} in {f['tests'][name]}"}
    if ref.startswith("runbook:"):
        name = ref[8:]
        if name not in f["runbooks"]:
            raise BuildError(f"unknown runbook {name!r}")
        return {"label": f"Runbook: {name}", "href": REPO_URL + "docs/runbooks/index.md", "title": f"Runbook: {name}"}
    if ref.startswith("lip:part-"):
        part = ref[9:]
        if part not in f["lip"]:
            raise BuildError(f"unknown LIP part {part}")
        anchor = f["lip"][part]["anchor"]
        return {"label": f"LIP part {part}", "href": REPO_URL + "docs/specs/lip-draft.md#" + anchor, "title": f["lip"][part]["title"]}
    if ref.startswith("doc:"):
        path, _, anchor = ref[4:].partition("#")
        target = ROOT / path
        if not target.is_file():
            raise BuildError(f"missing file {path}")
        if anchor and anchor not in V._heading_slugs(str(target)):
            raise BuildError(f"missing heading #{anchor} in {path}")
        parts = path.split("/")
        label = parts[-2] if parts[-1] == "index.md" and len(parts) > 1 else parts[-1].removesuffix(".md")
        return {"label": label, "href": REPO_URL + path + (f"#{anchor}" if anchor else ""), "title": path}
    raise BuildError(f"unrecognised reference {ref!r}")


# --------------------------------------------------------------------------
# Content
# --------------------------------------------------------------------------

class _StrictLoader(yaml.SafeLoader):
    """A safe loader that refuses a repeated key, which plain YAML drops silently."""


def _mapping(loader: _StrictLoader, node: yaml.MappingNode, deep: bool = False) -> dict[Any, Any]:
    seen = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in seen:
            raise BuildError(f"line {key_node.start_mark.line + 1}: the key {key!r} appears twice")
        seen.add(key)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)


_StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _mapping)


def parse_yaml(text: str) -> Any:
    return yaml.load(text, Loader=_StrictLoader)


def load() -> dict[str, Any]:
    content = {}
    for name in ("meta", "map", "actors", "flows", "assumptions", "reuse", "glossary", "tour", "quiz"):
        path = CONTENT / f"{name}.yaml"
        try:
            content[name] = parse_yaml(path.read_text(encoding="utf-8"))
        except BuildError as exc:
            raise BuildError(f"{path.relative_to(ROOT)}: {exc}") from None
    return content


def check(c: dict[str, Any], f: dict[str, Any]) -> dict[str, dict[str, str]]:
    """Cross-checks the content and resolves every reference. Returns the reference table."""
    errors: list[str] = []
    refs: dict[str, dict[str, str]] = {}

    def sources(where: str, items: Any) -> None:
        if not items:
            errors.append(f"{where}: no sources")
            return
        for ref in items:
            try:
                refs[ref] = resolve(ref, f)
            except BuildError as exc:
                errors.append(f"{where}: {exc}")

    nodes = {n["id"]: n for n in c["map"]["nodes"]}
    edges = {e["id"]: e for e in c["map"]["edges"]}
    for n in c["map"]["nodes"]:
        if n["domain"] not in DOMAINS or n["kind"] not in KINDS or n["status"] not in STATUSES:
            errors.append(f"node {n['id']}: bad domain, kind or status")
    for e in c["map"]["edges"]:
        if e["from"] not in nodes or e["to"] not in nodes or e["kind"] not in EDGE_KINDS:
            errors.append(f"edge {e['id']}: bad endpoint or kind")
    if len(nodes) != len(c["map"]["nodes"]) or len(edges) != len(c["map"]["edges"]):
        errors.append("map: duplicate ids")

    roles = {p["role"] for p in f["policy"]}
    actor_ids = set()
    for a in c["actors"]:
        if a["id"] in actor_ids:
            errors.append(f"actor {a['id']}: duplicate id")
        actor_ids.add(a["id"])
        if a["node"] not in nodes:
            errors.append(f"actor {a['id']}: unknown node {a['node']}")
        if a["status"] not in STATUSES:
            errors.append(f"actor {a['id']}: bad status {a['status']}")
        if a.get("label") and a["label"] not in LABELS:
            errors.append(f"actor {a['id']}: bad label {a['label']}")
        if a.get("role") and a["role"] not in roles:
            errors.append(f"actor {a['id']}: no role {a['role']} in the policy artifact")
        sources(f"actor {a['id']}", a.get("sources"))

    flow_ids = set()
    for fl in c["flows"]["flows"]:
        flow_ids.add(fl["id"])
        if fl["group"] not in {g["id"] for g in c["flows"]["groups"]}:
            errors.append(f"flow {fl['id']}: unknown group")
        if fl["label"] not in LABELS:
            errors.append(f"flow {fl['id']}: bad label {fl['label']}")
        for i, step in enumerate(fl["steps"], 1):
            for n in step.get("nodes", []):
                if n not in nodes:
                    errors.append(f"flow {fl['id']} step {i}: unknown node {n}")
            for e in step.get("edges", []):
                if e not in edges:
                    errors.append(f"flow {fl['id']} step {i}: unknown edge {e}")
        sources(f"flow {fl['id']}", fl.get("sources"))

    for i, a in enumerate(c["assumptions"], 1):
        sources(f"assumption {i}", a.get("sources"))
        for ref in a.get("watched_by", []):
            try:
                refs[ref] = resolve(ref, f)
            except BuildError as exc:
                errors.append(f"assumption {i} watched_by: {exc}")
    for r in c["reuse"]:
        if r["column"] not in {"reused", "instance", "new"}:
            errors.append(f"reuse {r['name']}: bad column")
        sources(f"reuse {r['name']}", r.get("sources"))

    terms = {t["term"].lower() for t in c["glossary"]}
    for t in c["glossary"]:
        sources(f"term {t['term']}", t.get("sources"))
    for s in c["tour"]:
        for n in s.get("nodes", []):
            if n not in nodes:
                errors.append(f"tour {s['title']}: unknown node {n}")
        for e in s.get("edges", []):
            if e not in edges:
                errors.append(f"tour {s['title']}: unknown edge {e}")
        for fl in s.get("flows", []):
            if fl not in flow_ids:
                errors.append(f"tour {s['title']}: unknown flow {fl}")
        sources(f"tour {s['title']}", s.get("sources"))
    for q in c["quiz"]:
        if not 0 <= q["answer"] < len(q["options"]):
            errors.append(f"quiz {q['question']}: answer out of range")
        sources(f"quiz {q['question'][:30]}", q.get("sources"))

    # Every [[term]] in the text must be a glossary term.
    blob = json.dumps(c, ensure_ascii=False)
    for term in re.findall(r"\[\[([^\]]+)\]\]", blob):
        if term.split("|")[0].lower() not in terms:
            errors.append(f"glossary: [[{term}]] is not a term")

    # The guide shows only addresses that the repository already records.
    known = recorded_addresses()
    for address in sorted(set(re.findall(r"0x[0-9a-fA-F]{40}", blob))):
        if address.lower() not in known:
            errors.append(f"address {address} is not recorded in docs/, policy/ or script/")

    if errors:
        raise BuildError("\n".join(sorted(set(errors))))
    return refs


# --------------------------------------------------------------------------
# Rendering helpers
# --------------------------------------------------------------------------

def esc(text: Any) -> str:
    return html.escape(str(text), quote=True)


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def fmt(text: str) -> str:
    """Escapes text, then renders **bold**, `code` and [[term]] or [[term|shown text]]."""
    out = esc(text)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"`(.+?)`", r"<code>\1</code>", out)

    def term(match: re.Match[str]) -> str:
        name, _, shown = match.group(1).partition("|")
        return f'<a class="term" href="#term-{slug(name)}" data-term="{slug(name)}">{shown or name}</a>'

    return re.sub(r"\[\[([^\]]+)\]\]", term, out)


def paras(text: str) -> str:
    return "".join(f"<p>{fmt(p.strip())}</p>" for p in str(text).split("\n\n") if p.strip())


def source_links(items: list[str], refs: dict[str, dict[str, str]]) -> str:
    links = []
    for ref in items or []:
        r = refs[ref]
        links.append(f'<a class="src" href="{esc(r["href"])}" title="{esc(r["title"])}">{esc(r["label"])}</a>')
    return f'<p class="sources"><span>Sources</span> {" ".join(links)}</p>' if links else ""


def badge(label: str) -> str:
    text, icon = LABELS[label]
    return f'<span class="badge st-{label}"><span aria-hidden="true">{icon}</span> {esc(text)}</span>'


def alert(text: str) -> str:
    """A known defect or risk, shown with an icon and a label, never by colour alone."""
    return f'<p class="alert" role="note"><span class="alert-label"><span aria-hidden="true">⚠</span> Open issue</span> {fmt(text)}</p>'


def status_tag(status: str) -> str:
    return f'<span class="tag tag-{status}">{esc(STATUSES[status])}</span>'


# --------------------------------------------------------------------------
# The system map
# --------------------------------------------------------------------------

def _clip(cx: float, cy: float, tx: float, ty: float, w: float, h: float) -> tuple[float, float]:
    """The point where the ray from a rectangle's centre toward (tx, ty) leaves it."""
    dx, dy = tx - cx, ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    sx = (w / 2) / abs(dx) if dx else float("inf")
    sy = (h / 2) / abs(dy) if dy else float("inf")
    s = min(sx, sy)
    return cx + dx * s, cy + dy * s


GLYPHS = {
    "body": '<path d="M2 14h16M3 12h14M4 6v6M8 6v6M12 6v6M16 6v6M2 6h16L10 1z"/>',
    "multisig": '<circle cx="6" cy="5" r="3"/><circle cx="14" cy="5" r="3"/><path d="M1 15c0-4 2-6 5-6s5 2 5 6M9 15c0-4 2-6 5-6s5 2 5 6"/>',
    "contract": '<path d="M10 1l8 4v8l-8 4-8-4V5z M2 5l8 4 8-4 M10 9v8"/>',
    "service": '<path d="M5 14h10a4 4 0 0 0 0-8 5 5 0 0 0-9.5-1A4 4 0 0 0 5 14z"/>',
    "external": '<circle cx="10" cy="8" r="7"/><path d="M3 8h14M10 1c3 3 3 11 0 14M10 1c-3 3-3 11 0 14"/>',
}


def render_map(m: dict[str, Any]) -> str:
    nodes = {n["id"]: n for n in m["nodes"]}
    w, h = m["width"], m["height"]
    parts = [
        f'<svg id="map" class="map" viewBox="0 0 {w} {h}" role="group" aria-labelledby="map-title map-desc">',
        '<title id="map-title">System map</title>',
        f'<desc id="map-desc">{esc(m["description"])}</desc>',
        '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
        '<path d="M0 0L10 5L0 10z" class="arrowhead"/></marker></defs>',
        '<g class="edges">',
    ]
    for e in m["edges"]:
        a, b = nodes[e["from"]], nodes[e["to"]]
        ox, oy = e.get("offset", [0, 0])
        ax, ay = a["x"] + a["w"] / 2 + ox, a["y"] + a["h"] / 2 + oy
        bx, by = b["x"] + b["w"] / 2 + ox, b["y"] + b["h"] / 2 + oy
        via = [tuple(p) for p in e.get("via", [])]
        first = via[0] if via else (bx, by)
        last = via[-1] if via else (ax, ay)
        start = _clip(ax, ay, first[0], first[1], a["w"], a["h"])
        end = _clip(bx, by, last[0], last[1], b["w"], b["h"])
        points = [start, *via, end]
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points)
        mid = len(points) // 2
        (px, py), (qx, qy) = points[mid - 1], points[mid]
        lx, ly = e.get("label_at", [(px + qx) / 2, (py + qy) / 2 - 4])
        start_marker = ' marker-start="url(#arrow)"' if e.get("both") else ""
        label = f'<text x="{lx:.1f}" y="{ly:.1f}" text-anchor="middle">{esc(e["short"])}</text>' if e.get("short") else ""
        parts.append(
            f'<g class="edge ek-{e["kind"]}" id="edge-{e["id"]}" data-edge="{e["id"]}" data-from="{e["from"]}" data-to="{e["to"]}" '
            f'data-tip="{esc(e["label"])}">'
            f'<path d="{d}" marker-end="url(#arrow)"{start_marker}/><path class="hit" d="{d}"/>{label}</g>'
        )
    parts.append("</g><g class=\"nodes\">")
    for n in m["nodes"]:
        x, y, nw, nh = n["x"], n["y"], n["w"], n["h"]
        lines = n["label"].split("\n")
        tip = f'{n["label"].replace(chr(10), " ")}: {n["summary"]}'
        parts.append(
            f'<g class="node dom-{n["domain"]} kind-{n["kind"]} ns-{n["status"]}" id="node-{n["id"]}" data-node="{n["id"]}" '
            f'tabindex="0" role="button" aria-label="{esc(tip)}" data-tip="{esc(tip)}">'
            f'<rect x="{x}" y="{y}" width="{nw}" height="{nh}" rx="{10 if n["kind"] in ("multisig", "body") else 4}"/>'
            f'<g class="glyph" transform="translate({x + 9},{y + 8})" aria-hidden="true">{GLYPHS[n["kind"]]}</g>'
        )
        tag = {"existing": "EXISTS", "new": "NEW", "instance": "NEW INSTANCE", "mixed": "PARTLY NEW"}[n["status"]]
        parts.append(f'<text class="nt" x="{x + 34}" y="{y + 22}">{tag}</text>')
        top = y + 50
        for i, line in enumerate(lines):
            parts.append(f'<text class="nl" x="{x + nw / 2:.1f}" y="{top + i * 21:.1f}" text-anchor="middle">{esc(line)}</text>')
        if n.get("sub"):
            parts.append(f'<text class="ns" x="{x + nw / 2:.1f}" y="{top + len(lines) * 21 - 1:.1f}" text-anchor="middle">{esc(n["sub"])}</text>')
        parts.append("</g>")
    parts.append("</g></svg>")
    return "".join(parts)


# --------------------------------------------------------------------------
# Sections
# --------------------------------------------------------------------------

def section_outcomes(c: dict[str, Any]) -> str:
    items = "".join(f"<li>{fmt(o)}</li>" for o in c["meta"]["outcomes"])
    return f'<section class="outcomes" aria-label="What you will learn"><h2>After this guide you can</h2><ol>{items}</ol></section>'


def section_tour(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    scenes = []
    for i, s in enumerate(c["tour"], 1):
        flows = "".join(f'<a class="chip" href="#flow-{f}" data-play="{f}">Play: {esc(next(fl["title"] for fl in c["flows"]["flows"] if fl["id"] == f))}</a>' for f in s.get("flows", []))
        tech = f'<div class="tech">{paras(s["tech"])}</div>' if s.get("tech") else ""
        chips = f'<p class="chips">{flows}</p>' if flows else ""
        scenes.append(
            f'<article class="scene" id="scene-{i}" data-nodes="{" ".join(s.get("nodes", []))}" data-edges="{" ".join(s.get("edges", []))}">'
            f'<p class="kicker">Scene {i} of {len(c["tour"])}</p><h3>{esc(s["title"])}</h3>{paras(s["text"])}'
            f'{alert(s["alert"]) if s.get("alert") else ""}{tech}{chips}{source_links(s.get("sources"), refs)}</article>'
        )
    return f'<section id="tour" class="tour" aria-label="Guided tour"><h2>Guided tour</h2>{"".join(scenes)}</section>'


def _pills(a: dict[str, Any]) -> str:
    """The status tag and the build badge; an existing element shows only its badge."""
    if a.get("label") == "existing":
        return badge("existing")
    return status_tag(a["status"]) + (badge(a["label"]) if a.get("label") else "")


def section_actors(c: dict[str, Any], f: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    policy = {p["role"]: p for p in f["policy"]}
    jump = "".join(
        f'<a class="chip dom-{n["domain"]}" href="#group-{n["id"]}"><span class="swatch" aria-hidden="true"></span>'
        f'{esc(n["label"].replace(chr(10), " "))} <span class="count">{sum(a["node"] == n["id"] for a in c["actors"])}</span></a>'
        for n in c["map"]["nodes"]
    )
    groups = [f'<nav class="jump chips" aria-label="Actor groups">{jump}</nav>']
    for n in c["map"]["nodes"]:
        cards = []
        for a in (a for a in c["actors"] if a["node"] == n["id"]):
            can = "".join(f"<li>{fmt(x)}</li>" for x in a.get("can", []))
            cannot = "".join(f"<li>{fmt(x)}</li>" for x in a.get("cannot", []))
            numbers = " · ".join(esc(x) for x in a.get("numbers", []))
            numbers = f'<p class="numbers"><span>Numbers</span> {numbers}</p>' if numbers else ""
            cols = (
                f'<div class="cols"><div><h5>Can</h5><ul>{can}</ul></div><div><h5>Cannot</h5><ul>{cannot}</ul></div></div>'
                if can or cannot else ""
            )
            address = ""
            if a.get("address"):
                shown = f'<code>{esc(a["address"])}</code>' if re.fullmatch(r"0x[0-9a-fA-F]{40}", a["address"]) else esc(a["address"])
                address = f'<p class="addr"><span>Address</span> {shown}</p>'
            elif a.get("addresses"):
                rows = "".join(f"<li>{esc(x['name'])} <code>{esc(x['address'])}</code></li>" for x in a["addresses"])
                address = f'<div class="addr"><span>Addresses</span><ul>{rows}</ul></div>'
            perms = ""
            if a.get("role") in policy:
                p = policy[a["role"]]
                rows = "".join(
                    f'<tr><th scope="row">{esc(t["name"])}</th><td>{"<br>".join(f"<code>{esc(x)}</code>" for x in t["calls"])}</td></tr>'
                    for t in p["targets"]
                )
                keys = (
                    f'<p>Budget keys on this modifier: {", ".join(f"<code>{esc(k)}</code>" for k in p["keys"])}. '
                    f'The amounts are dry-run values and are not shown.</p>'
                    if p["keys"] and a["role"] == "operator" else ""
                )
                perms = (
                    f'<details class="tech perms"><summary>Exact permissions in the compiled policy ({len(p["targets"])} targets)</summary>{keys}'
                    f'<p>Held by: {esc(", ".join(p["members"]))}. On the {esc(p["modifier"])}. Read at build time from the committed fork-test artifact. '
                    f'Its holders are stand-ins, and its budgets and ceilings are dry-run values, not mainnet figures.</p>'
                    f'<table><thead><tr><th>Target</th><th>Calls</th></tr></thead><tbody>{rows}</tbody></table></details>'
                )
            cards.append(
                f'<article class="card actor" id="actor-{a["id"]}" data-node="{n["id"]}">'
                f'<header><h4>{esc(a["name"])}</h4>{_pills(a)}</header>'
                f'<p class="what">{fmt(a["what"])}</p>'
                f'{alert(a["alert"]) if a.get("alert") else ""}'
                f'<p class="ctl"><span>Controlled by</span> {fmt(a["controlled_by"])}</p>'
                f'{cols}{numbers}{address}{perms}'
                f'{source_links(a.get("sources"), refs)}</article>'
            )
        groups.append(
            f'<section class="group dom-{n["domain"]}" id="group-{n["id"]}" data-node="{n["id"]}">'
            f'<h3><span class="swatch" aria-hidden="true"></span>{esc(n["label"].replace(chr(10), " "))} {status_tag(n["status"])}</h3>'
            f'<p class="lead">{fmt(n["summary"])}</p>{"".join(cards)}</section>'
        )
    return "".join(groups)


def section_flows(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    rows = []
    for g in c["flows"]["groups"]:
        chips = "".join(
            f'<a class="chip" href="#flow-{fl["id"]}"><span aria-hidden="true">{LABELS[fl["label"]][1]}</span> {esc(fl["title"])}</a>'
            for fl in c["flows"]["flows"] if fl["group"] == g["id"]
        )
        rows.append(f'<div><p class="gname">{esc(g["title"])}</p><p class="chips">{chips}</p></div>')
    legend = " ".join(f'<span aria-hidden="true">{icon}</span> {esc(text)}' for k, (text, icon) in LABELS.items() if k != "existing")
    out = [f'<nav class="jump findex" aria-label="All flows">{"".join(rows)}<p class="lead">{legend}</p></nav>']
    for g in c["flows"]["groups"]:
        flows = [fl for fl in c["flows"]["flows"] if fl["group"] == g["id"]]
        items = []
        for fl in flows:
            steps = []
            for i, s in enumerate(fl["steps"], 1):
                meta = []
                if s.get("who"):
                    meta.append(f'<span class="who">{fmt(s["who"])}</span>')
                if s.get("time"):
                    meta.append(f'<span class="time">⏱ {esc(s["time"])}</span>')
                check = f'<p class="check"><span>Check</span> {fmt(s["check"])}</p>' if s.get("check") else ""
                check += alert(s["alert"]) if s.get("alert") else ""
                tech = f'<div class="tech">{paras(s["tech"])}</div>' if s.get("tech") else ""
                steps.append(
                    f'<li class="step" data-nodes="{" ".join(s.get("nodes", []))}" data-edges="{" ".join(s.get("edges", []))}">'
                    f'<p class="smeta">{"".join(meta)}</p>{paras(s["text"])}{check}{tech}</li>'
                )
            escapes = "".join(f"<li>{fmt(x)}</li>" for x in fl.get("escapes", []))
            if escapes:
                escapes = f'<div class="escapes"><h5>If this goes wrong</h5><ul>{escapes}</ul></div>'
            when = f' <span>Time</span> {esc(fl["time"])}' if fl.get("time") else ""
            items.append(
                f'<article class="flow card" id="flow-{fl["id"]}">'
                f'<header><h4>{esc(fl["title"])}</h4>{badge(fl["label"])}</header>'
                f'<p class="lead">{fmt(fl["summary"])}</p>'
                f'<p class="meta"><span>Trigger</span> {fmt(fl["trigger"])}{when}</p>'
                f'<button class="play" type="button" data-flow="{fl["id"]}">Play on the map</button>'
                f'<ol class="steps">{"".join(steps)}</ol>{escapes}'
                f'{source_links(fl.get("sources"), refs)}</article>'
            )
        out.append(f'<section class="fgroup" id="fgroup-{g["id"]}"><h3>{esc(g["title"])}</h3><p class="lead">{fmt(g["summary"])}</p>{"".join(items)}</section>')
    return "".join(out)


def section_assumptions(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    rows = []
    for i, a in enumerate(c["assumptions"], 1):
        watched = a.get("watched_by", [])
        note = " " + fmt(a["watch_note"]) if a.get("watch_note") else ""
        watch = (
            " ".join(f'<a class="src" href="{esc(refs[r]["href"])}" title="{esc(refs[r]["title"])}">{esc(refs[r]["label"])}</a>' for r in watched)
            if watched else '<span class="badge st-open"><span aria-hidden="true">○</span> Not checked yet</span>'
        )
        rows.append(
            f'<article class="card assumption" id="assumption-{i}"><header><h3><span class="rank">{i}</span> {fmt(a["assumption"])}</h3>'
            f'<span class="tag tag-{a["kind"]}">{esc(a["kind"].capitalize())}</span></header>'
            f'{alert(a["alert"]) if a.get("alert") else ""}'
            f'<div class="cols"><div><h4 class="sub">Why it matters</h4>{paras(a["why"])}</div><div><h4 class="sub">If it is false</h4>{paras(a["breaks"])}</div></div>'
            f'<p class="watch"><span>Watched by</span> {watch}{note}</p>'
            f'{source_links(a.get("sources"), refs)}</article>'
        )
    return "".join(rows)


def section_reuse(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    cols = {"reused": [], "instance": [], "new": []}
    for r in c["reuse"]:
        owner = f'<p class="owner"><span>Owner</span> {fmt(r["owner"])}</p>' if r.get("owner") else ""
        cols[r["column"]].append(
            f'<article class="card reuse" id="reuse-{slug(r["name"])}"><h4>{esc(r["name"])}</h4>'
            f'<p>{fmt(r["what"])}</p><p class="why"><span>Why</span> {fmt(r["why"])}</p>'
            f'{owner}'
            f'{source_links(r.get("sources"), refs)}</article>'
        )
    heads = c["meta"]["reuse_columns"]
    return "".join(
        f'<section class="rcol rcol-{k}"><h3>{esc(heads[k]["title"])} <span class="count">{len(v)}</span></h3>'
        f'<p class="lead">{fmt(heads[k]["text"])}</p>{"".join(v)}</section>'
        for k, v in cols.items()
    )


def section_glossary(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    items = []
    for t in sorted(c["glossary"], key=lambda t: t["term"].lower()):
        tech = f'<div class="tech">{paras(t["tech"])}</div>' if t.get("tech") else ""
        items.append(
            f'<div class="gterm" id="term-{slug(t["term"])}"><dt>{esc(t["term"])}</dt>'
            f'<dd><p class="gdef">{fmt(t["plain"])}</p>{tech}'
            f'{source_links(t.get("sources"), refs)}</dd></div>'
        )
    return f'<dl class="glossary">{"".join(items)}</dl>'


def section_status(c: dict[str, Any], f: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    lip = "".join(
        f'<tr><th scope="row"><a href="{esc(REPO_URL + "docs/specs/lip-draft.md#" + p["anchor"])}">Part {k}: {esc(p["title"])}</a></th><td>{_lip_badge(p["label"])}</td></tr>'
        for k, p in f["lip"].items()
    )
    written = sum(r["written"].lower().startswith("yes") for r in f["runbooks"].values())
    drilled = sum(r["drilled"].lower().startswith("yes") for r in f["runbooks"].values())
    adr = "".join(
        f'<tr><th scope="row"><a href="{esc(REPO_URL + a["path"])}">{esc(k.replace("-", " "))}</a> {esc(a["title"])}</th><td>{esc(a["decision"])}</td><td>{esc(a["review"])}</td></tr>'
        for k, a in f["adrs"].items()
    )
    rb = "".join(
        f'<tr><th scope="row">{esc(k)}</th><td>{esc(r["holder"])}</td><td>{esc(r["written"])}</td><td>{esc(r["drilled"])}</td></tr>'
        for k, r in f["runbooks"].items()
    )
    open_ods = [k for k, o in f["ods"].items() if o["state"] == "open"]
    ods = "".join(f'<li><strong>{esc(k)}</strong> {esc(f["ods"][k]["question"])}</li>' for k in open_ods) or "<li>None.</li>"
    phases = "".join(
        f'<li class="{"now" if p["phase"].startswith(c["meta"]["current_phase"]) else ""}"><strong>{esc(p["phase"])}</strong>'
        f'<span>{esc(p["job"])}</span><span class="gate">Gate: {esc(p["gate"])}</span></li>'
        for p in f["roadmap"]
    )
    reviews = ", ".join(f"{v} {esc(k)}" for k, v in f["reviews"].items())
    owed = "".join(f"<li>{fmt(x)}</li>" for x in c["meta"]["owed"])
    return (
        f'<div class="statusgrid"><section><h3>Roadmap</h3><p class="lead">{fmt(c["meta"]["phase_note"])}</p><ol class="phases">{phases}</ol></section>'
        f'<section><h3>What is still owed</h3><ul>{owed}</ul><h4>Open decisions</h4><ul>{ods}</ul>'
        f'<p class="lead">Pages by review state: {reviews}.</p></section></div>'
        f'<section><h3>The LIP, part by part</h3><p class="lead">In the LIP, Implemented means built and tested on a fork. Nothing is deployed.</p><table><thead><tr><th>Part</th><th>Status</th></tr></thead><tbody>{lip}</tbody></table></section>'
        f'<section><h3>Decision records</h3><table><thead><tr><th>ADR</th><th>Decision</th><th>Review</th></tr></thead><tbody>{adr}</tbody></table></section>'
        f'<section><h3>Runbooks</h3><p class="lead">{len(f["runbooks"])} listed. {written} written. {drilled} drilled on a fork.</p><table><thead><tr><th>Runbook</th><th>Holder</th><th>Written</th><th>Drilled</th></tr></thead><tbody>{rb}</tbody></table></section>'
    )


def _lip_badge(label: str) -> str:
    """The LIP's own status words, with the icon of the matching guide label."""
    key = "built" if label.startswith("Implemented") else "open" if label.startswith("Open") else "specified"
    return f'<span class="badge st-{key}"><span aria-hidden="true">{LABELS[key][1]}</span> {esc(label)}</span>'


def section_quiz(c: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    items = []
    for i, q in enumerate(c["quiz"], 1):
        opts = "".join(
            f'<li><label><input type="radio" name="q{i}" value="{j}"> {fmt(o)}</label></li>' for j, o in enumerate(q["options"])
        )
        items.append(
            f'<fieldset class="q" data-answer="{q["answer"]}"><legend>{i}. {fmt(q["question"])}</legend><ul>{opts}</ul>'
            f'<details class="answer"><summary>Show the answer</summary><p><strong>{fmt(q["options"][q["answer"]])}</strong></p>'
            f'{paras(q["why"])}{source_links(q.get("sources"), refs)}</details></fieldset>'
        )
    return f'<p class="lead">{fmt(c["meta"]["quiz_note"])}</p>{"".join(items)}<p class="score" aria-live="polite"></p>'


def map_list(m: dict[str, Any]) -> str:
    """The map's boxes and arrows as two tables, for readers who cannot use the drawing."""
    nodes = {n["id"]: n for n in m["nodes"]}

    def name(node_id: str) -> str:
        return nodes[node_id]["label"].replace(chr(10), " ")

    boxes = "".join(
        f'<tr><th scope="row">{esc(name(n["id"]))}</th><td>{esc(STATUSES[n["status"]])}</td><td>{fmt(n["summary"])}</td></tr>'
        for n in m["nodes"]
    )
    arrows = "".join(
        f'<tr id="arrow-{e["id"]}"><th scope="row">{esc(name(e["from"]))}</th><td>{esc(name(e["to"]))}</td><td>{fmt(e["label"])}</td></tr>'
        for e in m["edges"]
    )
    return (
        f'<details class="maplist"><summary>The map as a list</summary>'
        f'<table><caption>Boxes</caption><thead><tr><th scope="col">Box</th><th scope="col">Status</th><th scope="col">What it is</th></tr></thead><tbody>{boxes}</tbody></table>'
        f'<table><caption>Arrows</caption><thead><tr><th scope="col">From</th><th scope="col">To</th><th scope="col">What it means</th></tr></thead><tbody>{arrows}</tbody></table>'
        f'</details>'
    )


def legend(c: dict[str, Any]) -> str:
    dom = "".join(f'<li><span class="sw dom-{k}" aria-hidden="true"></span>{esc(v)}</li>' for k, v in c["meta"]["legend"]["domains"].items())
    st = "".join(f'<li><span class="sw ns-{k}" aria-hidden="true"></span>{esc(v)}</li>' for k, v in c["meta"]["legend"]["statuses"].items())
    ek = "".join(f'<li><span class="ln ek-{k}" aria-hidden="true"></span>{esc(v)}</li>' for k, v in c["meta"]["legend"]["edges"].items())
    kinds = "".join(
        f'<li><svg class="kg" viewBox="0 0 20 18" aria-hidden="true">{GLYPHS[k]}</svg>{esc(v)}</li>' for k, v in c["meta"]["legend"]["kinds"].items()
    )
    return f'<div class="legend" aria-label="Legend"><ul>{dom}</ul><ul>{st}</ul><ul>{kinds}</ul><ul>{ek}</ul></div>'


def render(c: dict[str, Any], f: dict[str, Any], refs: dict[str, dict[str, str]]) -> str:
    css = (SRC / "guide.css").read_text(encoding="utf-8")
    js = (SRC / "guide.js").read_text(encoding="utf-8")
    m = c["meta"]
    tabs = [
        ("actors", "Actors", section_actors(c, f, refs)),
        ("flows", "Flows", section_flows(c, refs)),
        ("reuse", "Built or reused", section_reuse(c, refs)),
        ("assumptions", "Assumptions", section_assumptions(c, refs)),
        ("status", "Status", section_status(c, f, refs)),
        ("glossary", "Glossary", section_glossary(c, refs)),
        ("selfcheck", "Self-check", section_quiz(c, refs)),
    ]
    tablist = "".join(
        f'<a class="tab" role="tab" href="#tab-{k}" id="tablink-{k}" aria-controls="tab-{k}">{esc(t)}</a>' for k, t, _ in tabs
    )
    panels = "".join(
        f'<section class="tabpanel" role="tabpanel" id="tab-{k}" aria-labelledby="tablink-{k}"><h2>{esc(t)}</h2>'
        f'<p class="intro">{fmt(m["tab_intros"][k])}</p>{body}</section>'
        for k, t, body in tabs
    )
    return f"""<!doctype html>
<html lang="en" data-theme="auto">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'">
<meta name="generator" content="scripts/build_onboarding.py">
<script>document.documentElement.classList.add("js")</script>
<title>{esc(m["title"])}</title>
<style>
{css}
</style>
</head>
<body class="lens-plain">
<a class="skip" href="#main">Skip to the content</a>
<header class="top">
<div class="brand"><h1>{esc(m["title"])}</h1><p class="subtitle">{fmt(m["subtitle"])}</p></div>
<div class="controls">
<div class="seg" role="group" aria-label="Detail"><button type="button" data-lens="plain" aria-pressed="true">Plain</button><button type="button" data-lens="tech" aria-pressed="false">Technical</button></div>
<div class="seg" role="group" aria-label="Theme"><button type="button" data-theme-set="auto" aria-pressed="true">Auto</button><button type="button" data-theme-set="light" aria-pressed="false">Light</button><button type="button" data-theme-set="dark" aria-pressed="false">Dark</button></div>
</div>
<p class="banner" role="note">{fmt(m["banner"])}</p>
</header>
<main id="main" tabindex="-1">
{section_outcomes(c)}
<section class="stage" aria-label="System map and walkthrough">
<figure class="mapcard">
<figcaption><h2>The system on one page</h2><p>{fmt(m["map_caption"])}</p></figcaption>
<div class="mapwrap">{render_map(c["map"])}</div>
{legend(c)}
{map_list(c["map"])}
</figure>
<aside class="panel" id="panel" aria-live="polite">
<div class="player" hidden>
<p class="kicker" id="player-kicker"></p>
<h3 id="player-title" tabindex="-1"></h3>
<div id="player-body"></div>
<div class="pnav"><button type="button" id="prev">← Back</button><span id="player-count"></span><button type="button" id="next">Next →</button></div>
<button type="button" id="player-close" class="linklike">Close</button>
</div>
<div class="panel-default">{fmt(m["panel_default"])}<p><button type="button" id="start-tour" class="primary">Start the guided tour</button></p></div>
</aside>
</section>
{section_tour(c, refs)}
<section class="explore" aria-label="Explore">
<nav class="tabs" role="tablist" aria-label="Sections">{tablist}</nav>
{panels}
</section>
</main>
<footer class="foot">{paras(m["footer"])}</footer>
<div id="tip" role="tooltip" hidden></div>
<script>
{js}
</script>
</body>
</html>
"""


def fork_only_addresses() -> set[str]:
    """The fork fixture's stand-in addresses: in the artifact's manifest, but in no document."""
    manifest = json.loads(ARTIFACT.read_text(encoding="utf-8"))["manifest"]
    stand_ins = {v.lower() for v in manifest.values() if isinstance(v, str) and re.fullmatch(r"0x[0-9a-fA-F]{40}", v)}
    return stand_ins - recorded_addresses(("docs",))


def stand_in_leaks(page: str) -> list[str]:
    """Fork-test stand-in addresses that a rendered page shows."""
    return sorted(a for a in fork_only_addresses() if a in page.lower())


def build() -> str:
    c = load()
    f = facts()
    refs = check(c, f)
    page = render(c, f, refs)
    if leaks := stand_in_leaks(page):
        raise BuildError("the page shows fork-test stand-in addresses: " + ", ".join(leaks))
    return page


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the committed page differs from a fresh build")
    args = parser.parse_args()
    try:
        page = build()
    except BuildError as exc:
        print(f"onboarding guide: build failed\n{exc}", file=sys.stderr)
        return 1
    if args.check:
        committed = OUT.read_text(encoding="utf-8") if OUT.is_file() else ""
        if committed != page:
            print(f"{OUT.relative_to(ROOT)} is stale. Run: uv run --with pyyaml python scripts/build_onboarding.py", file=sys.stderr)
            return 1
        print(f"{OUT.relative_to(ROOT)} matches a fresh build.")
        return 0
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(page) // 1024} KiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
