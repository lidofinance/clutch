#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Browser tests of the onboarding guide, docs/onboarding/clutch-onboarding.html (OD-37).

Run:
  uv run --with playwright==1.63.0 python -m playwright install --only-shell chromium   # once
  uv run --with pyyaml==6.0.2 --with playwright==1.63.0 --with axe-playwright-python==0.1.8 \\
      python scripts/test_onboarding_page.py [group ...]

The tests drive the committed page in headless Chromium. They take what to
expect from the guide's content and the repository, through the builder, so a
changed scene, flow, box or question changes its test with it. Each group below
exercises one kind of interactive element; name groups to run only those. The
page must make no network request and log no console error in any group.

Set ONBOARDING_CHROMIUM to a browser executable to use it instead of the one
that Playwright installed.
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys
from collections import Counter
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

from playwright.sync_api import Browser, Page, sync_playwright

ROOT = Path(__file__).resolve().parent.parent
URL = (ROOT / "docs" / "onboarding" / "clutch-onboarding.html").as_uri()
LIGHT_PAGE = "rgb(249, 249, 247)"  # --page in the light theme
DARK_PAGE = "rgb(13, 13, 13)"  # --page in the dark theme


def _builder():
    spec = importlib.util.spec_from_file_location("build_onboarding", ROOT / "scripts" / "build_onboarding.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["build_onboarding"] = module
    spec.loader.exec_module(module)
    return module


B = _builder()
CONTENT = B.load()
FACTS = B.facts()
NODES = {n["id"]: n for n in CONTENT["map"]["nodes"]}
EDGES = CONTENT["map"]["edges"]
FLOWS = CONTENT["flows"]["flows"]
TABS = ["tab-actors", "tab-flows", "tab-mandate", "tab-constellation", "tab-reuse", "tab-assumptions", "tab-status", "tab-glossary",
        "tab-selfcheck"]
BLOCKS = CONTENT["mandate"]["blocks"]
CHANGES = [ch for b in BLOCKS for ch in b.get("changes", [])]


def plain(text: str) -> str:
    """Content text as the page shows it: no markup, single spaces."""
    text = re.sub(r"\[\[([^\]|]+)(?:\|([^\]]*))?\]\]", lambda m: m.group(2) or m.group(1), str(text))
    return " ".join(text.replace("**", "").replace("`", "").split())


def label(node_id: str) -> str:
    return NODES[node_id]["label"].replace("\n", " ")


# --------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------

class Run:
    def __init__(self) -> None:
        self.passed = 0
        self.failed = 0
        self.problems: list[str] = []

    def check(self, ok: bool, name: str, detail: Any = "") -> bool:
        if ok:
            self.passed += 1
            print(f"PASS  {name}")
        else:
            self.failed += 1
            print(f"FAIL  {name}\n      got: {detail}")
        return ok


@contextmanager
def opened(browser: Browser, run: Run, group: str, *, fragment: str = "", **options: Any) -> Iterator[Page]:
    """A fresh page. Instant scrolls by default; one group checks the smooth default."""
    options.setdefault("viewport", {"width": 1440, "height": 1000})
    options.setdefault("reduced_motion", "reduce")
    context = browser.new_context(**options)
    context.set_default_timeout(5000)  # a control that never responds fails fast
    page = context.new_page()

    def console(message: Any) -> None:
        if message.type in ("error", "warning"):
            run.problems.append(f"{group}: console {message.type}: {message.text}")

    page.on("console", console)
    page.on("pageerror", lambda error: run.problems.append(f"{group}: page error: {error}"))
    page.on("request", lambda r: None if r.url.startswith(("file:", "data:")) else run.problems.append(f"{group}: request {r.url}"))
    page.goto(URL + fragment)
    try:
        yield page
    finally:
        context.close()


PLAYER = """() => ({
  open: !document.querySelector('.player').hidden,
  resting: !document.querySelector('.panel-default').hidden,
  kicker: document.getElementById('player-kicker').textContent,
  title: document.getElementById('player-title').textContent,
  count: document.getElementById('player-count').textContent,
  prev: document.getElementById('prev').disabled,
  next: document.getElementById('next').disabled,
  body: document.getElementById('player-body').innerText.split(/\\s+/).join(' '),
  nodes: [...document.querySelectorAll('#map .node.hl')].map((e) => e.dataset.node).sort(),
  edges: [...document.querySelectorAll('#map .edge.hl')].map((e) => e.dataset.edge).sort(),
  focusing: document.getElementById('map').classList.contains('focusing'),
})"""


def player(page: Page) -> dict[str, Any]:
    return page.evaluate(PLAYER)


def shown_panels(page: Page) -> list[str]:
    return page.eval_on_selector_all(".tabpanel", "ps => ps.filter((p) => !p.hidden).map((p) => p.id)")


def top_of(page: Page, selector: str) -> float:
    return page.eval_on_selector(selector, "e => e.getBoundingClientRect().top")


def in_view(page: Page, selector: str) -> bool:
    return page.eval_on_selector(selector, "e => { const r = e.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; }")


def reached(page: Page, selector: str) -> bool:
    """The target's top is in the window, as a link to it leaves it. An item at
    the very end of the page cannot scroll to the top, so the top half is too
    strict."""
    top = top_of(page, selector)
    return -2 <= top < page.evaluate("innerHeight") - 10


def tip(page: Page) -> tuple[bool, str]:
    shown, text = page.evaluate("() => { const t = document.getElementById('tip'); return [!t.hidden, t.textContent]; }")
    return shown, text


def active(page: Page) -> str:
    return page.evaluate("document.activeElement.id || document.activeElement.className || document.activeElement.tagName")


def pressed(page: Page, attribute: str) -> list[str]:
    return page.eval_on_selector_all(f"[{attribute}]", f"bs => bs.filter((b) => b.getAttribute('aria-pressed') === 'true').map((b) => b.getAttribute('{attribute}'))")


def background(page: Page) -> str:
    return page.evaluate("getComputedStyle(document.body).backgroundColor")


def displayed(page: Page, selector: str) -> list[bool]:
    """Whether each match is rendered: its own display is not enough when an ancestor is hidden."""
    return page.eval_on_selector_all(selector, "els => els.map((e) => e.getClientRects().length > 0)")


# --------------------------------------------------------------------------
# Groups
# --------------------------------------------------------------------------

def test_structure(browser: Browser, run: Run) -> None:
    with opened(browser, run, "structure") as page:
        ids = page.eval_on_selector_all("[id]", "els => els.map((e) => e.id)")
        counts = Counter(ids)
        run.check(not [i for i, n in counts.items() if n > 1], "every id is unique", [i for i, n in counts.items() if n > 1][:5])
        known = set(ids)
        links = page.eval_on_selector_all("a[href^='#']", "els => els.map((e) => e.getAttribute('href').slice(1))")
        run.check(all(link in known for link in links), "every link inside the page has a target", sorted({x for x in links if x not in known})[:5])
        refs = page.evaluate(
            "() => [...document.querySelectorAll('[aria-controls], [aria-labelledby]')]"
            ".flatMap((e) => `${e.getAttribute('aria-controls') || ''} ${e.getAttribute('aria-labelledby') || ''}`.split(' ').filter(Boolean))"
        )
        run.check(all(r in known for r in refs), "every ARIA reference has a target", [r for r in refs if r not in known][:5])
        terms = page.eval_on_selector_all(".term", "els => els.map((e) => e.dataset.term)")
        run.check(bool(terms) and all(f"term-{t}" in known for t in terms), f"every glossary link has its term ({len(terms)} links)",
                  sorted({t for t in terms if f"term-{t}" not in known}))
        unnamed = page.evaluate(
            "() => [...document.querySelectorAll('button, a[href], [role=button], [role=tab], input, summary')]"
            ".filter((e) => !((e.getAttribute('aria-label') || e.textContent || '').trim() || (e.labels && e.labels.length)))"
            ".map((e) => e.outerHTML.slice(0, 80))"
        )
        run.check(not unnamed, "every control has a name", unnamed[:3])

        boxes = page.eval_on_selector_all(
            "#map .node", "els => els.map((e) => [e.dataset.node, e.getAttribute('role'), e.getAttribute('tabindex'), e.getAttribute('aria-label')])")
        run.check(sorted(b[0] for b in boxes) == sorted(NODES) and all(b[1] == "button" and b[2] == "0" and b[3] for b in boxes),
                  f"every box on the map is a named button in the tab order ({len(NODES)})", boxes[:2])
        arrows = page.eval_on_selector_all("#map .edge", "els => els.map((e) => [e.dataset.edge, e.dataset.tip])")
        run.check(sorted(a[0] for a in arrows) == sorted(e["id"] for e in EDGES) and all(a[1] for a in arrows),
                  f"every arrow on the map carries its meaning ({len(EDGES)})")
        rows = {e["id"]: page.text_content(f"#arrow-{e['id']}") or "" for e in EDGES}  # the list is collapsed
        run.check(all(plain(e["label"]) in " ".join(rows[e["id"]].split()) for e in EDGES),
                  "the map list repeats every arrow's meaning, so no tooltip holds the only copy",
                  [e["id"] for e in EDGES if plain(e["label"]) not in " ".join(rows[e["id"]].split())][:3])

        counts_on_page = {
            "actor cards": (page.locator(".card.actor").count(), len(CONTENT["actors"])),
            "flows": (page.locator("article.flow").count(), len(FLOWS)),
            "tour scenes": (page.locator(".scene").count(), len(CONTENT["tour"])),
            "assumptions": (page.locator(".card.assumption").count(), len(CONTENT["assumptions"])),
            "reuse cards": (page.locator(".card.reuse").count(), len(CONTENT["reuse"])),
            "glossary terms": (page.locator(".gterm").count(), len(CONTENT["glossary"])),
            "questions": (page.locator("fieldset.q").count(), len(CONTENT["quiz"])),
            "mandate blocks": (page.locator(".card.mblock").count(), len(BLOCKS)),
            "mandate changes": (page.locator(".mchange").count(), len(CHANGES)),
            "roles in the constellation": (page.locator(".crole").count(), len(FACTS["policy"])),
            "specified parts": (page.locator(".card.cplan").count(), len(CONTENT["constellation"]["planned"])),
            "constellation changes": (page.locator("table.cdiff tbody tr").count(), len(CONTENT["constellation"]["changes"])),
        }
        run.check(all(a == b for a, b in counts_on_page.values()), "the page shows every item of the content", counts_on_page)

        hrefs = page.eval_on_selector_all("a[href^='http']", "els => els.map((e) => e.getAttribute('href'))")
        foreign = [h for h in hrefs if not h.startswith(B.REPO_URL)]
        missing = sorted({h for h in hrefs if h.startswith(B.REPO_URL) and not (ROOT / h[len(B.REPO_URL):].split("#")[0]).exists()})
        run.check(bool(hrefs) and not foreign and not missing, f"every source link points at a file in this repository ({len(hrefs)} links)",
                  (foreign[:2], missing[:2]))


def test_theme(browser: Browser, run: Run) -> None:
    for system, system_page in (("light", LIGHT_PAGE), ("dark", DARK_PAGE)):
        with opened(browser, run, "theme", color_scheme=system) as page:
            run.check(page.get_attribute("html", "data-theme") == "auto" and pressed(page, "data-theme-set") == ["auto"]
                      and background(page) == system_page, f"[{system} system] the page starts on Auto and follows the system", background(page))
            for choice, colour in (("light", LIGHT_PAGE), ("dark", DARK_PAGE), ("auto", system_page)):
                page.click(f"[data-theme-set={choice}]")
                state = (page.get_attribute("html", "data-theme"), pressed(page, "data-theme-set"), background(page))
                run.check(state == (choice, [choice], colour), f"[{system} system] the {choice} button sets the theme", state)


def test_lens(browser: Browser, run: Run) -> None:
    with opened(browser, run, "lens") as page:
        caption = " ".join(page.inner_text("#lens-note").split())
        run.check(page.get_attribute(".seg[aria-label=Detail]", "aria-describedby") == "lens-note" and caption == plain(CONTENT["meta"]["lens_note"]),
                  "the Detail switch says what Technical adds", caption)
        notes, shown = {}, []
        for tab in TABS:
            page.click(f".tab[aria-controls={tab}]")
            notes[tab] = page.locator(f"#{tab} .tech").count()
            if any(displayed(page, f"#{tab} .tech")):
                shown.append(tab)
        run.check(not shown and pressed(page, "data-lens") == ["plain"],
                  f"Plain hides every technical note in every tab ({sum(notes.values())} notes)", shown)
        bare = [t for t in ("tab-actors", "tab-flows", "tab-mandate", "tab-constellation") if not notes[t]]
        run.check(not bare, "the actors, flows, mandate and constellation tabs carry technical notes", notes)
        addresses = sum(bool(a.get("address") or a.get("addresses")) for a in CONTENT["actors"])
        run.check(page.locator("#tab-actors .addr.tech").count() == addresses and page.locator("#tab-actors .addr:not(.tech)").count() == 0,
                  f"every address is a technical note ({addresses} cards)")
        page.click("[data-lens=tech]")
        hidden = []
        for tab in TABS:
            page.click(f".tab[aria-controls={tab}]")
            if not all(displayed(page, f"#{tab} .tech")):
                hidden.append(tab)
        run.check(not hidden and pressed(page, "data-lens") == ["tech"] and page.evaluate("document.body.className") == "lens-tech",
                  "Technical shows every technical note in every tab", hidden)
        page.click("#tablink-flows")
        flow = next(f for f in FLOWS if f["steps"][0].get("tech"))
        page.click(f"#flow-{flow['id']} .play")
        run.check(all(displayed(page, "#player-body .tech")), f"the panel shows the technical note of {flow['id']} in Technical")
        page.click("[data-lens=plain]")
        run.check(not any(displayed(page, "#player-body .tech")) and not any(displayed(page, "#tab-flows .tech")),
                  "Plain hides the technical notes again, in the panel too")
        page.keyboard.press("Escape")

        scenes = CONTENT["tour"]
        page.click("[data-lens=tech]")
        page.click("#start-tour")
        wrong = []
        for i, scene in enumerate(scenes, 1):
            if scene.get("tech"):
                text = " ".join(" ".join(page.locator("#player-body .tech").all_inner_texts()).split())
                if not (all(displayed(page, "#player-body .tech")) and plain(scene["tech"])[:80] in text):
                    wrong.append((i, text[:60]))
            if i < len(scenes):
                page.click("#next")
        run.check(not wrong, f"Technical shows each scene's technical note in the panel ({sum(bool(s.get('tech')) for s in scenes)} notes)", wrong[:2])
        page.click("[data-lens=plain]")
        run.check(not any(displayed(page, "#player-body .tech")), "Plain hides the scene's technical note in the panel")


def test_tabs(browser: Browser, run: Run) -> None:
    with opened(browser, run, "tabs") as page:
        tabs = page.eval_on_selector_all(".tab", "els => els.map((e) => e.getAttribute('aria-controls'))")
        run.check(tabs == TABS, "the tabs are in their order", tabs)

        def state() -> tuple[list[str], list[str], list[str]]:
            selected = page.eval_on_selector_all(".tab[aria-selected=true]", "els => els.map((e) => e.getAttribute('aria-controls'))")
            focusable = page.eval_on_selector_all(".tab[tabindex='0']", "els => els.map((e) => e.getAttribute('aria-controls'))")
            return shown_panels(page), selected, focusable

        run.check(state() == ([TABS[0]], [TABS[0]], [TABS[0]]), "the first tab is selected when the page opens", state())
        for tab in TABS:
            page.click(f".tab[aria-controls={tab}]")
            ok = state() == ([tab], [tab], [tab]) and page.evaluate("location.hash") == f"#{tab}"
            run.check(ok, f"the {tab[4:]} tab shows its panel alone and names it in the address", state())
        page.focus(f".tab[aria-controls={TABS[0]}]")
        trail = []
        for _ in TABS:
            page.keyboard.press("ArrowRight")
            trail.append((state()[0][0], page.evaluate("document.activeElement.getAttribute('aria-controls')")))
        want = [(t, t) for t in TABS[1:] + TABS[:1]]
        run.check(trail == want, "ArrowRight moves the selection and the focus through every tab, and wraps", trail)
        page.keyboard.press("ArrowLeft")
        run.check(state()[0] == [TABS[-1]], "ArrowLeft from the first tab goes to the last", state())


def test_links(browser: Browser, run: Run) -> None:
    targets = {
        "tab-status": "tab-status",
        f"actor-{CONTENT['actors'][-1]['id']}": "tab-actors",
        f"flow-{FLOWS[-1]['id']}": "tab-flows",
        f"reuse-{B.slug(CONTENT['reuse'][-1]['name'])}": "tab-reuse",
        f"assumption-{len(CONTENT['assumptions'])}": "tab-assumptions",
        f"term-{B.slug(sorted(t['term'] for t in CONTENT['glossary'])[-1])}": "tab-glossary",
        f"scene-{len(CONTENT['tour'])}": None,
        f"mandate-{BLOCKS[-1]['id']}": "tab-mandate",
        f"cchange-{B.slug(CONTENT['constellation']['changes'][-1]['area'])}": "tab-constellation",
    }
    for target, tab in targets.items():
        with opened(browser, run, "links", fragment=f"#{target}") as page:
            panels = shown_panels(page)
            run.check((tab is None or panels == [tab]) and reached(page, f"#{target}"), f"a link to #{target} opens its tab and shows it", panels)
    with opened(browser, run, "links") as page:
        term = B.slug(CONTENT["glossary"][0]["term"])
        page.evaluate(f"location.hash = '#term-{term}'")
        page.wait_for_function("document.getElementById('tab-glossary').hidden === false")
        run.check(reached(page, f"#term-{term}"), "a changed address in the open page moves to its target")
    with opened(browser, run, "links", fragment="#no-such-element") as page:
        run.check(shown_panels(page) == [TABS[0]], "an unknown address leaves the page on its first tab")


def test_tour(browser: Browser, run: Run) -> None:
    scenes = CONTENT["tour"]
    n = len(scenes)
    with opened(browser, run, "tour") as page:
        page.click("#start-tour")
        p = player(page)
        run.check(p["open"] and not p["resting"], "Start the guided tour opens the player")
        wrong = []
        for i, scene in enumerate(scenes, 1):
            p = player(page)
            want = {
                "kicker": f"Scene {i} of {n}", "title": scene["title"], "count": f"{i} of {n}", "prev": i == 1, "next": i == n,
                "nodes": sorted(scene.get("nodes", [])), "edges": sorted(scene.get("edges", [])),
            }
            got = {k: p[k] for k in want}
            first = plain(scene["text"].split("\n\n")[0])[:80]
            if got != want or first not in p["body"]:
                wrong.append((i, {k: (got[k], want[k]) for k in want if got[k] != want[k]}, first in p["body"]))
            if i < n:
                page.click("#next")
        run.check(not wrong, f"every scene shows its text and lights exactly its boxes and arrows ({n} scenes)", wrong[:2])
        page.click("#prev")
        run.check(player(page)["count"] == f"{n - 1} of {n}", "Back moves one scene back")
        page.keyboard.press("ArrowLeft")
        page.keyboard.press("ArrowLeft")
        page.keyboard.press("ArrowRight")
        run.check(player(page)["count"] == f"{n - 2} of {n}", "the arrow keys move between scenes")
        page.keyboard.press("Escape")
        p = player(page)
        run.check(not p["open"] and p["resting"] and not p["focusing"] and not p["nodes"], "Escape closes the player and clears the map")
        page.click("#start-tour")
        page.click("#player-close")
        p = player(page)
        run.check(not p["open"] and not p["focusing"], "Close closes the player and clears the map")

        page.focus("#start-tour")
        page.keyboard.press("Enter")
        run.check(player(page)["open"] and active(page) == "player-title", "a keyboard start moves focus to the panel")
        page.keyboard.press("Escape")
        run.check(active(page) == "start-tour", "Escape returns focus to the start button")


def test_flows(browser: Browser, run: Run) -> None:
    with opened(browser, run, "flows") as page:
        page.click("#tablink-flows")
        for flow in FLOWS:
            page.click(f"#flow-{flow['id']} .play")
            n = len(flow["steps"])
            wrong = []
            for j, step in enumerate(flow["steps"], 1):
                p = player(page)
                want = {
                    "kicker": f"Step {j} of {n}", "title": flow["title"], "count": f"{j} of {n}", "prev": j == 1, "next": j == n,
                    "nodes": sorted(step.get("nodes", [])), "edges": sorted(step.get("edges", [])),
                }
                got = {k: p[k] for k in want}
                text = plain(step["text"])[:80]
                if got != want or text not in p["body"]:
                    wrong.append((j, {k: (got[k], want[k]) for k in want if got[k] != want[k]}, text in p["body"]))
                if j < n:
                    page.click("#next")
            run.check(not wrong, f"the {flow['id']} flow plays its {n} steps with their boxes and arrows", wrong[:2])
            page.keyboard.press("Escape")
        page.focus(f"#flow-{FLOWS[0]['id']} .play")
        page.keyboard.press("Enter")
        run.check(player(page)["title"] == FLOWS[0]["title"] and active(page) == "player-title", "a flow started from the keyboard moves focus to the panel")


def test_tour_chips(browser: Browser, run: Run) -> None:
    titles = {f["id"]: f["title"] for f in FLOWS}
    chips = [(i, f) for i, scene in enumerate(CONTENT["tour"], 1) for f in scene.get("flows", [])]
    with opened(browser, run, "tour chips") as page:
        wrong = []
        for i, flow in chips:
            page.click(f"#scene-{i} [data-play='{flow}']")
            p = player(page)
            if not (p["open"] and p["title"] == titles[flow] and p["kicker"].startswith("Step 1 of")):
                wrong.append((i, flow, p["title"]))
            page.keyboard.press("Escape")
        run.check(not wrong, f"every Play chip in the tour starts its flow ({len(chips)} chips)", wrong[:3])
        scene = next(i for i, s in enumerate(CONTENT["tour"], 1) if s.get("flows"))
        page.click("#start-tour")
        for _ in range(scene - 1):
            page.click("#next")
        flow = CONTENT["tour"][scene - 1]["flows"][0]
        page.click(f"#player-body [data-play='{flow}']")
        run.check(player(page)["title"] == titles[flow], "a Play chip inside the panel starts its flow")


def test_boxes(browser: Browser, run: Run) -> None:
    arrows = {n: sorted(e["id"] for e in EDGES if n in (e["from"], e["to"])) for n in NODES}
    cards = Counter(a["node"] for a in CONTENT["actors"])
    with opened(browser, run, "boxes") as page:
        wrong = []
        for node_id, node in NODES.items():
            page.click(f"#node-{node_id} rect")
            p = player(page)
            got = (p["title"], p["kicker"], p["nodes"], p["edges"], page.locator("#player-body .card").count(), p["count"])
            want = (label(node_id), f"On the map · {B.STATUSES[node['status']]}", [node_id], arrows[node_id], cards[node_id], "")
            if got != want:
                wrong.append((node_id, got, want))
        run.check(not wrong, f"every box opens its actors and lights its arrows ({len(NODES)} boxes)", wrong[:2])
        for key, name in (("Enter", "Enter"), (" ", "Space")):
            page.keyboard.press("Escape")
            page.focus("#node-brakes")
            page.keyboard.press(key)
            run.check(player(page)["title"] == label("brakes") and active(page) == "player-title", f"{name} on a focused box opens it and moves focus to the panel")


def test_tooltips(browser: Browser, run: Run) -> None:
    with opened(browser, run, "tooltips") as page:
        wrong = []
        for node_id, node in NODES.items():
            page.hover(f"#node-{node_id} rect")
            shown, text = tip(page)
            if not (shown and text == f"{label(node_id)}: {node['summary']}"):
                wrong.append((node_id, shown, text[:40]))
            page.mouse.move(1, 1)
            if tip(page)[0]:
                wrong.append((node_id, "stays"))
        run.check(not wrong, f"every box shows its tooltip and hides it when the pointer leaves ({len(NODES)})", wrong[:3])

        wrong = []
        for edge in EDGES:
            page.locator(f"#edge-{edge['id']}").scroll_into_view_if_needed()
            seen = []
            for share in (0.5, 0.4, 0.6, 0.3, 0.7):
                x, y = page.evaluate(
                    """([id, share]) => {
                      const p = document.querySelector(`#edge-${id} path.hit`);
                      const q = p.getPointAtLength(p.getTotalLength() * share);
                      const m = p.getScreenCTM();
                      return [q.x * m.a + q.y * m.c + m.e, q.x * m.b + q.y * m.d + m.f];
                    }""", [edge["id"], share])
                page.mouse.move(x, y)
                seen.append(tip(page))
                page.mouse.move(1, 1)
                if seen[-1] == (True, edge["label"]):
                    break
            if seen[-1] != (True, edge["label"]):
                wrong.append((edge["id"], seen[-1][1][:40]))
        run.check(not wrong, f"every arrow shows its meaning under the pointer ({len(EDGES)})", wrong[:3])

        definitions = {B.slug(t["term"]): plain(t["plain"]) for t in CONTENT["glossary"]}
        link = page.locator("#tab-actors a.term").first
        term = link.get_attribute("data-term")
        link.focus()
        shown, text = tip(page)
        run.check(shown and " ".join(text.split()) == definitions[term], "a focused glossary link shows its definition", text[:60])
        link.evaluate("e => e.blur()")
        run.check(not tip(page)[0], "the tooltip hides when the link loses focus")
        page.click("#start-tour")
        inner = page.locator("#player-body a.term").first
        term = inner.get_attribute("data-term")
        inner.hover()
        shown, text = tip(page)
        run.check(shown and " ".join(text.split()) == definitions[term], "a glossary link inside the panel shows its definition", text[:60])


def test_terms(browser: Browser, run: Run) -> None:
    with opened(browser, run, "glossary links") as page:
        link = page.locator("#tab-actors a.term").first
        term = link.get_attribute("data-term")
        link.click()
        run.check(shown_panels(page) == ["tab-glossary"] and reached(page, f"#term-{term}"),
                  "a glossary link in a card opens the glossary at its term", shown_panels(page))
        page.click("#tablink-actors")
        page.click("#start-tour")
        link = page.locator("#player-body a.term").first
        term = link.get_attribute("data-term")
        link.click()
        run.check(shown_panels(page) == ["tab-glossary"] and reached(page, f"#term-{term}"), "a glossary link inside the panel opens the glossary at its term")
        link = page.locator("#tab-glossary .gdef a.term").first
        term = link.get_attribute("data-term")
        link.click()
        run.check(page.evaluate("location.hash") == f"#term-{term}" and reached(page, f"#term-{term}"),
                  "a glossary link inside the glossary moves to its term")


def test_jumps(browser: Browser, run: Run) -> None:
    with opened(browser, run, "jump lists") as page:
        lists = (("tab-actors", len(NODES)), ("tab-flows", len(FLOWS)), ("tab-mandate", len(BLOCKS)))
        for tab, count in lists:
            selector = f"#{tab} nav.jump a"
            page.click(f"#tablink-{tab[4:]}")
            hrefs = page.eval_on_selector_all(selector, "els => els.map((e) => e.getAttribute('href'))")
            wrong = []
            for href in hrefs:
                page.evaluate("scrollTo(0, 0)")
                page.click(f"{selector}[href='{href}']")
                if not reached(page, href):
                    wrong.append(href)
            run.check(len(hrefs) == count and not wrong, f"every jump link in the {tab[4:]} tab reaches its target ({len(hrefs)})", wrong[:3])


def test_permissions(browser: Browser, run: Run) -> None:
    roles = {p["role"]: p for p in FACTS["policy"]}
    cards = [a for a in CONTENT["actors"] if a.get("role")]
    with opened(browser, run, "permissions") as page:
        run.check(not any(displayed(page, "details.perms")), "Plain hides the permission tables")
        page.click("[data-lens=tech]")
        wrong = []
        for actor in cards:
            box = page.locator(f"#actor-{actor['id']} details.perms")
            box.locator("summary").click()
            role = roles[actor["role"]]
            got = (box.evaluate("d => d.open"), box.locator("tbody tr").count(), all(m in box.inner_text() for m in role["members"]),
                   f'({B.count(len(role["targets"]), "target")})' in box.locator("summary").inner_text())
            if got != (True, len(role["targets"]), True, True):
                wrong.append((actor["id"], got))
        run.check(bool(cards) and not wrong, f"every role card opens the role's exact permissions from the artifact ({len(cards)} roles)", wrong)


def test_mandate(browser: Browser, run: Run) -> None:
    with opened(browser, run, "mandate", fragment="#tab-mandate") as page:
        stats = page.eval_on_selector_all(".mstats li", "els => els.map((e) => [e.className, e.querySelector('strong').textContent])")
        want = [[f"ms-{s}", str(sum(ch["state"] == s for ch in CHANGES))] for s in B.CHANGE_STATES]
        run.check(stats == want, "the counts by state add up the changes of every block", stats)
        chips = page.eval_on_selector_all("#tab-mandate nav.jump a", "els => els.map((e) => e.querySelector('.count')?.textContent || '')")
        run.check(chips == [str(len(b["changes"])) if b.get("changes") else "" for b in BLOCKS], "each block's link counts its changes", chips)
        wrong = []
        for b in BLOCKS:
            card = page.locator(f"#mandate-{b['id']}")
            got = {
                "says": plain(b["says"]) in " ".join(card.locator(".msays").inner_text().split()),
                "controls": card.locator(".mkept > ul > li").count(),
                "layers": card.locator(".mkept .layer").evaluate_all("els => els.map((e) => e.textContent)"),
                "states": card.locator(".mchange").evaluate_all("els => els.map((e) => [...e.classList].find((c) => c.startsWith('ms-')))"),
                "reasons": card.locator(".mchange .why").count(),
                "unchanged": card.locator(".munchanged").count(),
            }
            want = {
                "says": True,
                "controls": len(b["kept"]),
                "layers": [k.partition(": ")[0] for k in b["kept"] if k.partition(": ")[0] in B.LAYERS],
                "states": [f"ms-{ch['state']}" for ch in b.get("changes", [])],
                "reasons": len(b.get("changes", [])),
                "unchanged": 0 if b.get("changes") else 1,
            }
            if got != want:
                wrong.append((b["id"], {k: got[k] for k in want if got[k] != want[k]}))
        run.check(not wrong, f"every block shows the draft's text, each control with its layer, and each change with its state and "
                  f"reason ({len(BLOCKS)} blocks, {len(CHANGES)} changes)", wrong[:2])
        text = page.inner_text("#tab-mandate")
        run.check(not re.search(r"[$€£%]", text), "the mandate tab shows no currency sign and no percentage", re.findall(r".{0,20}[$€£%]", text)[:2])


def test_constellation(browser: Browser, run: Run) -> None:
    roles = FACTS["policy"]
    modifiers = list(dict.fromkeys(r["modifier"] for r in roles))
    k = CONTENT["constellation"]
    with opened(browser, run, "constellation", fragment="#tab-constellation") as page:
        graph = page.eval_on_selector_all(
            ".cmod", "ms => ms.map((m) => [m.querySelector('.cmodifier strong').textContent, [...m.querySelectorAll('.crole strong')].map((r) => r.textContent)])")
        want = [[m, [r["role"] for r in roles if r["modifier"] == m]] for m in modifiers]
        run.check(graph == want, f"the graph shows each modifier of the artifact with its roles ({len(modifiers)} modifiers, {len(roles)} roles)", graph)
        wrong = []
        for r in roles:
            text = " ".join(page.inner_text(f"#crole-{B.slug(r['modifier'])}-{B.slug(r['role'])}").split())
            calls = sum(len(t["calls"]) for t in r["targets"])
            if not (all(m in text for m in r["members"]) and f'{B.count(len(r["targets"]), "target")} · {B.count(calls, "call")}' in text):
                wrong.append((r["role"], text[:100]))
        run.check(not wrong, "every role box names its holder and counts its targets and calls from the artifact", wrong[:2])
        run.check(not any(displayed(page, "#tab-constellation details.tech")), "Plain hides each role's list of targets")
        page.click("[data-lens=tech]")
        wrong = []
        for r in roles:
            box = page.locator(f"#crole-{B.slug(r['modifier'])}-{B.slug(r['role'])} details.tech")
            box.locator("summary").click()
            names = box.locator("li").evaluate_all("els => els.map((e) => e.firstChild.textContent.trim())")
            if not (box.evaluate("d => d.open") and names == [t["name"] for t in r["targets"]]):
                wrong.append((r["role"], names[:3]))
        run.check(not wrong, "Technical opens each role's targets, as the artifact lists them", wrong[:2])
        plans = page.eval_on_selector_all(".cplan h4", "els => els.map((e) => e.textContent)")
        run.check(plans == [p["name"] for p in k["planned"]], f"the specified parts show apart from the built ones ({len(plans)})", plans)
        rows = page.eval_on_selector_all(
            "table.cdiff tbody tr",
            "rs => rs.map((r) => [r.id, r.querySelector('th').firstChild.textContent, [...r.querySelector('th .badge').classList].find((c) => c.startsWith('ck-'))])")
        want = [[f"cchange-{B.slug(ch['area'])}", ch["area"], f"ck-{ch['kind']}"] for ch in k["changes"]]
        run.check(rows == want, f"the change table shows every change with its kind ({len(want)} rows)", [r for r in rows if r not in want][:2])


def test_selfcheck(browser: Browser, run: Run) -> None:
    questions = CONTENT["quiz"]
    with opened(browser, run, "self-check", fragment="#tab-selfcheck") as page:
        run.check(page.inner_text(".score") == "", "the score is empty before any answer")
        wrong = []
        for i, q in enumerate(questions, 1):
            box = page.locator("fieldset.q").nth(i - 1)
            miss = (q["answer"] + 1) % len(q["options"])
            box.locator(f"input[value='{miss}']").check()
            after_miss = (box.get_attribute("class"), box.locator("details").evaluate("d => d.open"), page.inner_text(".score"))
            box.locator(f"input[value='{q['answer']}']").check()
            after_hit = box.get_attribute("class")
            answer = " ".join(box.locator("details strong").first.inner_text().split())
            score = page.inner_text(".score")
            if not ("wrong" in after_miss[0] and after_miss[1] and after_miss[2] == f"{i - 1} of {len(questions)} right so far."
                    and "right" in after_hit and "wrong" not in after_hit
                    and answer == plain(q["options"][q["answer"]]) and score == f"{i} of {len(questions)} right so far."):
                wrong.append((i, after_miss, after_hit, answer[:30], score))
        run.check(not wrong, f"every question marks a wrong and a right answer, shows why, and keeps the score ({len(questions)})", wrong[:2])
    with opened(browser, run, "self-check", fragment="#tab-selfcheck") as page:
        box = page.locator("fieldset.q").first
        box.locator("summary").click()
        run.check(box.locator("details").evaluate("d => d.open") and page.inner_text(".score") == "",
                  "Show the answer opens without answering and leaves the score alone")


def test_skip_link(browser: Browser, run: Run) -> None:
    with opened(browser, run, "skip link") as page:
        page.keyboard.press("Tab")
        box = page.locator(".skip").bounding_box()
        run.check(active(page) == "skip" and box is not None and box["x"] >= 0, "the first Tab shows the skip link", active(page))
        page.keyboard.press("Enter")
        run.check(active(page) == "main", "the skip link moves focus to the content", active(page))


def test_without_javascript(browser: Browser, run: Run) -> None:
    with opened(browser, run, "without JavaScript", java_script_enabled=False) as page:
        run.check(all(displayed(page, ".tabpanel")) and page.locator(".tabpanel").count() == len(TABS), "every section shows without JavaScript")
        run.check(all(displayed(page, ".tech")), "every technical note shows without JavaScript")
        run.check(not any(displayed(page, "#start-tour, .play, .controls, .panel")), "no control that needs JavaScript shows without it")
        run.check(all(displayed(page, ".scene")) and page.locator("#map").bounding_box()["width"] > 600, "the map and the tour show without JavaScript")


def test_print(browser: Browser, run: Run) -> None:
    with opened(browser, run, "print") as page:
        closed = page.locator("details:not([open])").count()
        page.evaluate("dispatchEvent(new Event('beforeprint'))")
        page.emulate_media(media="print")
        run.check(all(displayed(page, ".tabpanel")) and all(displayed(page, ".tech")), "print shows every section and every technical note")
        run.check(page.locator("details:not([open])").count() == 0 and closed > 0, f"print opens every collapsed section ({closed})")
        run.check(not any(displayed(page, ".controls, .panel, .tabs, .play")), "print leaves out the controls")
        page.evaluate("dispatchEvent(new Event('afterprint'))")
        page.emulate_media(media="screen")
        run.check(page.locator("details:not([open])").count() == closed and shown_panels(page) == [TABS[0]],
                  "after print the page returns to how it was")


def test_phone(browser: Browser, run: Run) -> None:
    phone = {"viewport": {"width": 390, "height": 844}, "is_mobile": True, "has_touch": True, "device_scale_factor": 2}
    with opened(browser, run, "phone", **phone) as page:
        overflow = page.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth")
        run.check(overflow <= 0, "the page does not scroll sideways on a phone", overflow)
        run.check(page.eval_on_selector(".mapwrap", "w => w.scrollWidth > w.clientWidth"), "the map scrolls sideways inside its frame")
        map_box = page.locator(".mapcard").bounding_box()
        panel_box = page.locator(".panel").bounding_box()
        run.check(panel_box["y"] >= map_box["y"] + map_box["height"] - 1, "the panel sits below the map on a phone")
        page.locator("#node-asset-safe").tap()
        run.check(player(page)["title"] == label("asset-safe") and in_view(page, "#player-title"), "a tapped box opens its actors in view")
        run.check(not tip(page)[0], "a tap shows no tooltip over the panel")
        wide = []
        for tab in TABS:
            page.click(f".tab[aria-controls={tab}]")
            if page.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth") > 0:
                wide.append(tab)
        run.check(not wide, "no tab makes the page scroll sideways on a phone", wide)
        page.click("#tablink-constellation")
        run.check(page.eval_on_selector(".tablewrap", "w => w.scrollWidth <= w.clientWidth"), "the table of changes stacks within a phone's width")


def test_motion(browser: Browser, run: Run) -> None:
    for preference, behaviour in (("no-preference", "smooth"), ("reduce", "auto")):
        with opened(browser, run, "motion", reduced_motion=preference) as page:
            got = page.evaluate("getComputedStyle(document.documentElement).scrollBehavior")
            run.check(got == behaviour, f"scrolling is {behaviour} when the reader asks for {preference}", got)


def test_map_layout(browser: Browser, run: Run) -> None:
    with opened(browser, run, "map layout") as page:
        shapes = page.evaluate(
            """() => {
              const box = (e) => { const b = e.getBBox(); return [b.x, b.y, b.x + b.width, b.y + b.height]; };
              return {
                view: (() => { const v = document.getElementById('map').viewBox.baseVal; return [v.x, v.y, v.width, v.height]; })(),
                boxes: [...document.querySelectorAll('#map .node')].map((g) => [g.dataset.node, box(g.querySelector('rect')),
                  [...g.querySelectorAll('text')].map(box)]),
                labels: [...document.querySelectorAll('#map .edge text')].map((t) => [t.parentNode.dataset.edge, box(t)]),
              };
            }""")

        def overlap(a: list[float], b: list[float], slack: float = 1.0) -> bool:
            return a[0] + slack < b[2] and b[0] + slack < a[2] and a[1] + slack < b[3] and b[1] + slack < a[3]

        boxes = shapes["boxes"]
        clashes = [(a[0], b[0]) for i, a in enumerate(boxes) for b in boxes[i + 1:] if overlap(a[1], b[1], 0)]
        run.check(not clashes, "no two boxes on the map overlap", clashes)
        spill = [b[0] for b in boxes if any(t[0] < b[1][0] - 1 or t[2] > b[1][2] + 1 or t[1] < b[1][1] - 1 or t[3] > b[1][3] + 1 for t in b[2])]
        run.check(not spill, "every box's text fits inside the box", spill)
        labels = shapes["labels"]
        on_boxes = [(lab[0], b[0]) for lab in labels for b in boxes if overlap(lab[1], b[1])]
        run.check(not on_boxes, "no arrow label covers a box", on_boxes)
        pairs = [(a[0], b[0]) for i, a in enumerate(labels) for b in labels[i + 1:] if overlap(a[1], b[1])]
        run.check(not pairs, "no two arrow labels overlap", pairs)
        view = shapes["view"]
        outside = [lab[0] for lab in labels if lab[1][0] < view[0] or lab[1][2] > view[0] + view[2] or lab[1][1] < view[1] or lab[1][3] > view[1] + view[3]]
        run.check(not outside, "every arrow label lies inside the map", outside)


def test_accessibility(browser: Browser, run: Run) -> None:
    from axe_playwright_python.sync_playwright import Axe

    axe = Axe()

    def scan(page: Page, where: str, context: Any = None, options: dict[str, Any] | None = None) -> None:
        violations = axe.run(page, context=context, options=options or {"resultTypes": ["violations"]}).response["violations"]
        summary = [(v["id"], v["impact"], len(v["nodes"]), v["nodes"][0]["target"]) for v in violations]
        run.check(not violations, f"axe finds no accessibility violation: {where}", summary[:3])

    for scheme in ("light", "dark"):
        with opened(browser, run, "accessibility", color_scheme=scheme) as page:
            scan(page, f"{scheme} theme, the page as it opens")
            page.click("[data-lens=tech]")
            page.evaluate("document.querySelectorAll('details').forEach((d) => { d.open = true; })")
            for tab in TABS:
                page.click(f".tab[aria-controls={tab}]")
                scan(page, f"{scheme} theme, Technical, the {tab[4:]} tab")
            page.click("#start-tour")
            scan(page, f"{scheme} theme, the player open, outside the map", context={"exclude": [["#map"]]})
            # While a step plays, the boxes it does not use are faded on purpose.
            # Their text stays readable in the panel, in the map list and when the
            # player closes, so only the contrast rule skips the faded map.
            scan(page, f"{scheme} theme, the player open, the faded map", context={"include": [["#map"]]},
                 options={"resultTypes": ["violations"], "rules": {"color-contrast": {"enabled": False}}})
            page.keyboard.press("Escape")
            scan(page, f"{scheme} theme, the player closed again")


GROUPS: dict[str, Callable[[Browser, Run], None]] = {
    "structure": test_structure,
    "theme": test_theme,
    "lens": test_lens,
    "tabs": test_tabs,
    "links": test_links,
    "tour": test_tour,
    "flows": test_flows,
    "chips": test_tour_chips,
    "boxes": test_boxes,
    "tooltips": test_tooltips,
    "terms": test_terms,
    "jumps": test_jumps,
    "permissions": test_permissions,
    "mandate": test_mandate,
    "constellation": test_constellation,
    "selfcheck": test_selfcheck,
    "skip": test_skip_link,
    "nojs": test_without_javascript,
    "print": test_print,
    "phone": test_phone,
    "motion": test_motion,
    "layout": test_map_layout,
    "a11y": test_accessibility,
}


def main(argv: list[str]) -> int:
    chosen = argv or list(GROUPS)
    unknown = [g for g in chosen if g not in GROUPS]
    if unknown:
        print(f"unknown group: {', '.join(unknown)}; choose from {', '.join(GROUPS)}", file=sys.stderr)
        return 2
    run = Run()
    with sync_playwright() as p:
        executable = os.environ.get("ONBOARDING_CHROMIUM")
        browser = p.chromium.launch(executable_path=executable) if executable else p.chromium.launch()
        try:
            for name in chosen:
                print(f"-- {name}")
                try:
                    GROUPS[name](browser, run)
                except Exception as exc:  # a broken control can stop a group; report it and go on
                    run.check(False, f"the {name} group runs to the end", f"{type(exc).__name__}: {str(exc).splitlines()[0][:200]}")
        finally:
            browser.close()
    run.check(not run.problems, "no network request and no console error in any group", run.problems[:5])
    print(f"{run.passed} passed, {run.failed} failed")
    return 1 if run.failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
