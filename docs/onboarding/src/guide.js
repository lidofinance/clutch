// SPDX-License-Identifier: AGPL-3.0-or-later
// Progressive enhancement for the onboarding guide. The page reads in full
// without this script; the script adds the map highlights, the step player,
// tabs, tooltips, the detail and theme switches, and the self-check. It makes
// no network request and stores nothing.
(() => {
  "use strict";
  const root = document.documentElement;
  root.classList.add("js");
  const $ = (sel, from = document) => from.querySelector(sel);
  const $$ = (sel, from = document) => Array.from(from.querySelectorAll(sel));
  const words = (s) => (s || "").split(" ").filter(Boolean);
  const map = $("#map");

  // --- switches -----------------------------------------------------------
  const press = (buttons, chosen) => buttons.forEach((b) => b.setAttribute("aria-pressed", String(b === chosen)));
  const themeButtons = $$("[data-theme-set]");
  themeButtons.forEach((b) => b.addEventListener("click", () => {
    root.dataset.theme = b.dataset.themeSet;
    press(themeButtons, b);
  }));
  const lensButtons = $$("[data-lens]");
  lensButtons.forEach((b) => b.addEventListener("click", () => {
    const tech = b.dataset.lens === "tech";
    document.body.classList.toggle("lens-tech", tech);
    document.body.classList.toggle("lens-plain", !tech);
    press(lensButtons, b);
  }));

  // --- map highlight --------------------------------------------------------
  function highlight(nodes, edges) {
    const n = new Set(nodes);
    const e = new Set(edges);
    map.classList.toggle("focusing", n.size + e.size > 0);
    $$(".node", map).forEach((g) => g.classList.toggle("hl", n.has(g.dataset.node)));
    $$(".edge", map).forEach((g) => g.classList.toggle("hl", e.has(g.dataset.edge)));
  }
  const edgesOf = (id) => $$(".edge", map).filter((g) => g.dataset.from === id || g.dataset.to === id).map((g) => g.dataset.edge);

  // --- tabs -------------------------------------------------------------------
  const tabs = $$(".tab");
  const panelIds = tabs.map((t) => t.getAttribute("aria-controls"));
  function showTab(id) {
    tabs.forEach((t) => {
      const on = t.getAttribute("aria-controls") === id;
      t.setAttribute("aria-selected", String(on));
      t.tabIndex = on ? 0 : -1;
    });
    $$(".tabpanel").forEach((p) => { p.hidden = p.id !== id; });
  }
  tabs.forEach((t, i) => {
    t.addEventListener("click", (ev) => {
      ev.preventDefault();
      showTab(panelIds[i]);
      history.replaceState(null, "", "#" + panelIds[i]);
    });
    t.addEventListener("keydown", (ev) => {
      const step = ev.key === "ArrowRight" ? 1 : ev.key === "ArrowLeft" ? -1 : 0;
      if (!step) return;
      ev.preventDefault();
      const next = tabs[(i + step + tabs.length) % tabs.length];
      next.focus();
      next.click();
    });
  });
  function reveal(hash) {
    const target = hash && document.getElementById(hash);
    if (!target) return false;
    const panel = target.closest(".tabpanel");
    if (panel) showTab(panel.id);
    target.scrollIntoView({ block: "start" });
    return true;
  }
  // The skip link also moves focus, so the next Tab starts in the content.
  $(".skip").addEventListener("click", (ev) => {
    ev.preventDefault();
    $("#main").focus({ preventScroll: true });
    $("#main").scrollIntoView({ block: "start" });
  });
  showTab(panelIds[0]);
  reveal(location.hash.slice(1));
  window.addEventListener("hashchange", () => reveal(location.hash.slice(1)));

  // --- the step player in the side panel -------------------------------------
  const player = $(".player");
  const resting = $(".panel-default");
  let seq = [];
  let at = 0;
  function cleanCopy(el, skip) {
    const box = document.createElement("div");
    Array.from(el.children).forEach((child) => {
      if (skip && child.matches(skip)) return;
      box.appendChild(child.cloneNode(true));
    });
    $$("[id]", box).forEach((x) => x.removeAttribute("id"));
    $$("button", box).forEach((x) => x.remove());
    return box;
  }
  function draw() {
    const s = seq[at];
    $("#player-kicker").textContent = s.kicker;
    $("#player-title").textContent = s.title;
    $("#player-body").replaceChildren(s.body.cloneNode(true));
    $("#player-count").textContent = seq.length > 1 ? `${at + 1} of ${seq.length}` : "";
    $("#prev").disabled = at === 0;
    $("#next").disabled = at === seq.length - 1;
    highlight(s.nodes, s.edges);
  }
  // Shows a sequence in the panel. `fromMap` keeps the map where it is and
  // brings the panel into view; `byKeyboard` moves focus to the panel title.
  function play(items, { fromMap = false, byKeyboard = false } = {}) {
    seq = items;
    at = 0;
    player.hidden = false;
    resting.hidden = true;
    draw();
    const panel = $("#panel").getBoundingClientRect();
    const stage = $(".stage").getBoundingClientRect();
    if (fromMap) {
      if (panel.top > window.innerHeight || panel.bottom < 0) $("#panel").scrollIntoView({ block: "nearest" });
    } else if (stage.top < 0 || stage.top > window.innerHeight * 0.5) {
      $(".stage").scrollIntoView({ block: "start" });
    }
    if (byKeyboard) $("#player-title").focus();
  }
  function stop() {
    const hadFocus = player.contains(document.activeElement);
    player.hidden = true;
    resting.hidden = false;
    highlight([], []);
    if (hadFocus) $("#start-tour").focus();
  }
  $("#prev").addEventListener("click", () => { if (at > 0) { at -= 1; draw(); } });
  $("#next").addEventListener("click", () => { if (at < seq.length - 1) { at += 1; draw(); } });
  $("#player-close").addEventListener("click", stop);
  document.addEventListener("keydown", (ev) => {
    if (player.hidden || ev.target.closest("input, textarea, [role=tab]")) return;
    if (ev.key === "ArrowRight") $("#next").click();
    if (ev.key === "ArrowLeft") $("#prev").click();
    if (ev.key === "Escape") stop();
  });

  $("#start-tour").addEventListener("click", (ev) => {
    play($$(".scene").map((scene) => ({
      kicker: $(".kicker", scene).textContent,
      title: $("h3", scene).textContent,
      body: cleanCopy(scene, ".kicker, h3"),
      nodes: words(scene.dataset.nodes),
      edges: words(scene.dataset.edges),
    })), { byKeyboard: ev.detail === 0 });
  });
  // A "Play" chip, also inside the panel's copy of a scene, starts its flow.
  document.addEventListener("click", (ev) => {
    const chip = ev.target.closest("[data-play]");
    const button = chip && $(`#flow-${chip.dataset.play} .play`);
    if (!button) return;
    ev.preventDefault();
    button.click();
  });
  $$(".play").forEach((button) => button.addEventListener("click", (ev) => {
    const flow = button.closest(".flow");
    const title = $("h4", flow).textContent;
    const steps = $$(".step", flow);
    play(steps.map((step, i) => ({
      kicker: `Step ${i + 1} of ${steps.length}`,
      title,
      body: cleanCopy(step),
      nodes: words(step.dataset.nodes),
      edges: words(step.dataset.edges),
    })), { byKeyboard: ev.detail === 0 });
  }));
  function openNode(id, byKeyboard) {
    const group = document.getElementById("group-" + id);
    if (!group) return;
    const heading = $("h3", group).cloneNode(true);
    const tag = $(".tag", heading);
    if (tag) tag.remove();
    play([{
      kicker: tag ? `On the map · ${tag.textContent}` : "On the map",
      title: heading.textContent.trim(),
      body: cleanCopy(group, "h3"),
      nodes: [id],
      edges: edgesOf(id),
    }], { fromMap: true, byKeyboard });
  }
  $$(".node", map).forEach((g) => {
    g.addEventListener("click", () => openNode(g.dataset.node, false));
    g.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); openNode(g.dataset.node, true); }
    });
  });

  // --- tooltips: they repeat what the page already says ------------------------
  const tip = $("#tip");
  function place(x, y) {
    const pad = 14;
    const w = tip.offsetWidth;
    const h = tip.offsetHeight;
    tip.style.left = Math.min(x + pad, window.innerWidth - w - 8) + "px";
    tip.style.top = (y + pad + h > window.innerHeight ? y - h - pad : y + pad) + "px";
  }
  function show(text, x, y) {
    if (!text) return;
    tip.textContent = text;
    tip.hidden = false;
    place(x, y);
  }
  const hide = () => { tip.hidden = true; };
  const tipFor = (el) => {
    if (el.dataset.tip) return el.dataset.tip;
    const def = document.querySelector(`#term-${el.dataset.term} .gdef`);
    return def ? def.textContent : "";
  };
  // Delegated, so that the copies of the page in the panel get tooltips too.
  const tipped = (target) => (target instanceof Element ? target.closest("[data-tip], .term") : null);
  // A touch has no hover: a tooltip would only cover the panel it opens.
  document.addEventListener("pointerover", (ev) => {
    const el = tipped(ev.target);
    if (el && ev.pointerType !== "touch" && !el.contains(ev.relatedTarget)) show(tipFor(el), ev.clientX, ev.clientY);
  });
  document.addEventListener("pointerout", (ev) => {
    const el = tipped(ev.target);
    if (el && !el.contains(ev.relatedTarget)) hide();
  });
  document.addEventListener("pointermove", (ev) => { if (!tip.hidden) place(ev.clientX, ev.clientY); });
  // Keyboard focus only: a tap or a click also focuses a box.
  document.addEventListener("focusin", (ev) => {
    const el = tipped(ev.target);
    if (!el || !el.matches(":focus-visible")) return;
    const r = el.getBoundingClientRect();
    show(tipFor(el), r.left + r.width / 2, r.bottom);
  });
  document.addEventListener("focusout", (ev) => { if (tipped(ev.target)) hide(); });
  document.addEventListener("click", (ev) => {
    const term = ev.target.closest(".term");
    if (term && !term.closest("#tab-glossary")) {
      ev.preventDefault();
      reveal("term-" + term.dataset.term);
      hide();
    }
  });

  // --- print: every collapsed section opens, and closes again afterwards -----------
  let closedForPrint = [];
  window.addEventListener("beforeprint", () => {
    closedForPrint = $$("details:not([open])");
    closedForPrint.forEach((d) => { d.open = true; });
  });
  window.addEventListener("afterprint", () => {
    closedForPrint.forEach((d) => { d.open = false; });
    closedForPrint = [];
  });

  // --- self-check -----------------------------------------------------------------
  const questions = $$("fieldset.q");
  function score() {
    const answered = questions.filter((q) => $("input:checked", q));
    const right = questions.filter((q) => q.classList.contains("right"));
    $(".score").textContent = answered.length ? `${right.length} of ${questions.length} right so far.` : "";
  }
  questions.forEach((q) => q.addEventListener("change", () => {
    const picked = Number($("input:checked", q).value);
    const ok = picked === Number(q.dataset.answer);
    q.classList.toggle("right", ok);
    q.classList.toggle("wrong", !ok);
    $("details", q).open = true;
    score();
  }));
})();
