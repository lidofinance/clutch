#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Validate the docs/ bundle against OKF 0.2 and the Clutch profile.

Run:
  python3 scripts/validate_docs.py                  # validate; errors exit 1
  python3 scripts/validate_docs.py --write-status   # regenerate the document-status register, then validate
  python3 scripts/validate_docs.py --check-status   # validate and fail if the register is out of date

Adapted from the Gaggle validator (lidofinance/gaggle), which adapts the ctokb validator.
Errors block a merge. Warnings do not.

Profile rules on top of OKF 0.2:
- Every concept carries `review_status`: slop | human-skimmed | human-reviewed | finalized.
- A review status above `slop` needs a `human:` verification at or after `generated.at`.
  An edit that bumps `generated.at` therefore forces the page back to `slop`.
- A Decision carries `decision`: proposed | accepted | superseded | rejected.
  `accepted` needs `accepted_by` (a human actor), that actor's verification at or after
  `generated.at`, and a review status of human-reviewed or finalized.
- No `generated.at` or `verified[].at` lies in the future beyond a small clock skew.
- Every inline [sN] marker matches a `sources` id.
- Humans and processes come from config/actors.yaml. Any agent id may author a page in
  `generated.by` (ADR 012). Only listed humans verify, and only listed agents record a
  human's verification.

Clutch rules on top of the Gaggle profile:
- AGENTS.md holds at most 60 lines (ADR 003).
- Every Runbook names the `permission` it exercises. A Runbook above `slop` needs a
  passing `drill` record, and the drill's time to initiate must not exceed six hours,
  the mandate's ceiling (ADR 002, ROADMAP standing gates).
- A verification by a body, `human:tmc`, carries `ref`: an https or urn link to the
  body's decision record (ADR 002, OD-15).
- An agent records a human's own verification only on that human's written instruction
  (ADR 003, OD-31). The entry names the agent in `recorded_by`, and its `ref` links the
  decision-log heading that quotes the instruction. An agent never records a body's
  verification.
- A team, such as `human:defi-tech`, verifies with `ref`: the link to the pull request that
  a member approved. A team never accepts an ADR; only EM or the committee does (OD-50).
- A verification from 2026-10-07 on records `sha256`, the hash of the page's body. The
  check fails when the body differs from the hash of the latest verification, until a
  human verifies the page again with `just verify` (OD-51).
- An ID in the open-decision register, the invariants or the ADR numbers is used once
  and never reused. An open decision names its question, the page that closes it, an
  agent recommendation and who decides (ADR 012).
- A closed decision lives in docs/registers/closed-decisions.yaml with its question, date,
  decision-log headings, ADR decisions and the earlier ODs that it replaces or refines.
  Every heading, decision and OD that it names exists; it replaces only earlier ODs; and
  every OD number up to the highest is open or closed. `--write-status` generates the
  register's closed index, each OD's state, the ADR index and each proposed ADR's open
  decisions; `--check-status` fails when one is stale (ADR 012, OD-82).
"""

from __future__ import annotations

import argparse
import functools
import hashlib
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import yaml

OKF_VERSION = "0.2"
RESERVED = {"index.md", "log.md"}
FRONTMATTER = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.DOTALL)
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)")
CITATION_MARKER = re.compile(r"\[(s\d+)\](?!\()")
LEGACY_CITATIONS = re.compile(r"^#+\s+Citations\s*$", re.MULTILINE)
ACTOR = re.compile(r"\A(human:[a-z0-9-]+|process:[a-z0-9-]+|[a-z0-9._-]+/[a-z0-9._-]+)\Z")

FORBIDDEN_TRACKED = ("notes/", "private/", ".env")
ALLOWED_TRACKED = {".env.example"}  # a template with placeholders, as in .gitignore
STATUSES = {"draft", "stable", "deprecated"}
REVIEW_STATUSES = ("slop", "human-skimmed", "human-reviewed", "finalized")
DECISIONS = {"proposed", "accepted", "superseded", "rejected"}
TYPES = {
    "Attested Computation", "Decision", "Guide", "Policy", "Product Brief", "Register",
    "Research Note", "Runbook", "Specification",
}
AGENTS_MAX_LINES = 60
BODY_ACTORS = ("human:tmc",)
ACCEPTORS = ("human:em", "human:tmc")  # ADR 002: EM in the interim, the committee permanently
# A team's verification links the pull request that a member approved (ADR 012, OD-50).
PR_REF = re.compile(r"\Ahttps://github\.com/lidofinance/clutch/pull/\d+\Z")
# Verifications from this date on record the hash of the page's body (ADR 012, OD-51).
BODY_LOCK_FROM = datetime(2026, 10, 7)
SHA256 = re.compile(r"\A[0-9a-f]{64}\Z")
BODY_REF = re.compile(r"\A(https://\S+|urn:\S+)\Z")
# A verification that an agent recorded links the decision-log heading that quotes the
# human's instruction (ADR 003, OD-31).
INSTRUCTION_REF = re.compile(r"\A/registers/decision-log\.md#([\w-]+)\Z")
SIX_HOURS = 6 * 60 * 60
DRILL_FIELDS = ("at", "network", "block", "time_to_initiate_seconds", "result")
REGISTER_REL = "registers/document-status.md"
CLOCK_SKEW_SECONDS = 600  # a timestamp later than now plus this skew is rejected
REGISTER_ACTOR = "process:status-register"


@dataclass(frozen=True)
class Issue:
    path: str
    message: str
    warning: bool = False

    def __str__(self) -> str:
        return f"{'warn ' if self.warning else 'error'}  {self.path}: {self.message}"


def _frontmatter(text: str) -> tuple[dict[str, Any] | None, str | None]:
    match = FRONTMATTER.match(text)
    if not match:
        return None, None
    try:
        parsed = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        return None, str(exc).replace("\n", " ")
    return (parsed if isinstance(parsed, dict) else None), None


def _as_dt(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        dt = value
    elif isinstance(value, date):
        return datetime(value.year, value.month, value.day)
    elif isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
        except ValueError:
            return None
    else:
        return None
    return dt.astimezone(timezone.utc).replace(tzinfo=None) if dt.tzinfo else dt


def _in_future(dt: datetime) -> bool:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    return (dt - now).total_seconds() > CLOCK_SKEW_SECONDS


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _allowed_actors(root: Path) -> set[str]:
    config = root / "config" / "actors.yaml"
    if not config.is_file():
        return set()
    data = yaml.safe_load(config.read_text(encoding="utf-8")) or {}
    return {str(a) for key in ("humans", "teams", "processes", "agents") for a in (data.get(key) or [])}


@functools.lru_cache(maxsize=8)
def _teams(root: Path) -> frozenset[str]:
    config = root / "config" / "actors.yaml"
    if not config.is_file():
        return frozenset()
    data = yaml.safe_load(config.read_text(encoding="utf-8")) or {}
    return frozenset(str(a) for a in (data.get("teams") or []))


def body_hash(text: str) -> str:
    """The SHA-256 of a page's body: everything after the frontmatter, with LF line ends."""
    match = FRONTMATTER.match(text)
    body = text[match.end():] if match else text
    return hashlib.sha256(body.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def _check_actor(actor: Any, allowed: set[str], where: str, out: list[str]) -> None:
    text = str(actor)
    if not ACTOR.match(text):
        out.append(f"{where} is not a valid OKF actor id: {text!r}")
    elif allowed and text not in allowed:
        out.append(f"{where} {text!r} is not in config/actors.yaml")


def _check_author(actor: Any, allowed: set[str], out: list[str]) -> None:
    """Any agent may author a page; a human or a process must be listed (ADR 012)."""
    text = str(actor)
    if not ACTOR.match(text):
        out.append(f"generated.by is not a valid OKF actor id: {text!r}")
    elif text.startswith(("human:", "process:")):
        _check_actor(text, allowed, "generated.by", out)


@functools.lru_cache(maxsize=8)
def _heading_slugs(path: str) -> frozenset[str]:
    """GitHub-style anchors of the headings in a Markdown file, outside code fences."""
    slugs: set[str] = set()
    seen: dict[str, int] = {}
    fenced = False
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        match = None if fenced else re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not match:
            continue
        base = re.sub(r"[^\w\- ]", "", match.group(1).strip().lower()).replace(" ", "-")
        count = seen.get(base, 0)
        seen[base] = count + 1
        slugs.add(base if count == 0 else f"{base}-{count}")
    return frozenset(slugs)


def _instruction_ref_ok(ref: str, docs: Path) -> bool:
    match = INSTRUCTION_REF.match(ref)
    log = docs / "registers" / "decision-log.md"
    return bool(match) and log.is_file() and match.group(1) in _heading_slugs(str(log))


def _verifications(meta: dict[str, Any]) -> list[dict[str, Any]]:
    verified = meta.get("verified", [])
    if isinstance(verified, dict):  # OKF 0.2 section 5.2: a bare mapping is a one-element list
        return [verified]
    return verified if isinstance(verified, list) else []


def _check_concept(meta: dict[str, Any], text: str, allowed: set[str], docs: Path) -> list[str]:
    out: list[str] = []

    kind = str(meta.get("type", "")).strip()
    if not kind:
        out.append("no non-empty `type` (OKF 0.2 section 11)")
    elif kind not in TYPES:
        out.append(f"WARN unknown type {kind!r}; extend the vocabulary deliberately")

    if "timestamp" in meta:
        out.append("legacy 0.1 `timestamp`; use `generated: {by, at}` (OKF 0.2 section 13.1)")
    if LEGACY_CITATIONS.search(text):
        out.append("legacy 0.1 `# Citations` section; move provenance to `sources`")

    if (status := meta.get("status")) and str(status) not in STATUSES:
        out.append(f"invalid status {status!r}; one of {sorted(STATUSES)} (OKF 0.2 section 5.4)")

    review = str(meta.get("review_status", "")).strip()
    if not review:
        out.append("no `review_status`; agent-drafted pages start as `slop`")
    elif review not in REVIEW_STATUSES:
        out.append(f"invalid review_status {review!r}; one of {list(REVIEW_STATUSES)}")

    generated = meta.get("generated")
    generated_at = None
    if not isinstance(generated, dict) or not generated.get("by") or not generated.get("at"):
        out.append("`generated` must be a mapping with `by` and `at` (OKF 0.2 section 5.2)")
    else:
        _check_author(generated["by"], allowed, out)
        generated_at = _as_dt(generated["at"])
        if generated_at is None:
            out.append(f"generated.at is not an ISO 8601 datetime: {generated['at']!r}")
        elif _in_future(generated_at):
            out.append(f"generated.at is in the future: {_iso(generated_at)}")

    raw_verified = meta.get("verified", [])
    if raw_verified not in (None, []) and not isinstance(raw_verified, (list, dict)):
        out.append("`verified` must be a list of {by, at} events (OKF 0.2 section 5.2)")
    human_checks: dict[str, datetime] = {}
    latest: tuple[datetime, str, str | None] | None = None  # the newest verification: when, who, its body hash
    teams = _teams(docs.parent)
    for index, event in enumerate(_verifications(meta)):
        where = f"verified[{index}]"
        if not isinstance(event, dict) or not event.get("by") or not event.get("at"):
            out.append(f"{where} must be a mapping with `by` and `at`")
            continue
        if not str(event["by"]).startswith("human:"):
            out.append(f"{where}.by must name a human: agents never verify (ADR 003)")
        else:
            _check_actor(event["by"], allowed, f"{where}.by", out)
        event_at = _as_dt(event["at"])
        if event_at is None:
            out.append(f"{where}.at is not an ISO 8601 datetime: {event['at']!r}")
            continue
        if _in_future(event_at):
            out.append(f"{where}.at is in the future: {_iso(event_at)}; a future-dated verification would survive later edits")
            continue
        actor = str(event["by"])
        if event.get("recorded_by") is not None:
            recorder = str(event["recorded_by"])
            if not actor.startswith("human:"):
                out.append(f"{where}: `recorded_by` applies only to a human's verification")
                continue
            if actor in BODY_ACTORS or actor in teams:
                out.append(f"{where}: an agent never records a body's or a team's verification; a member records it (ADR 002, OD-15, OD-50)")
                continue
            if recorder.startswith(("human:", "process:")):
                out.append(f"{where}.recorded_by must name an agent, not {recorder!r}")
                continue
            _check_actor(recorder, allowed, f"{where}.recorded_by", out)
            if not _instruction_ref_ok(str(event.get("ref", "")).strip(), docs):
                out.append(
                    f"{where} recorded by {recorder} needs `ref`, a link to the decision-log heading "
                    "that quotes the human's instruction (ADR 003)"
                )
                continue
        if actor in BODY_ACTORS and not BODY_REF.match(str(event.get("ref", "")).strip()):
            out.append(f"{where} by {actor} needs `ref`, an https or urn link to the body's decision record (ADR 002)")
            continue
        if actor in teams and not PR_REF.match(str(event.get("ref", "")).strip()):
            out.append(f"{where} by {actor} needs `ref`, the link to the pull request that a member approved (ADR 012, OD-50)")
            continue
        digest = event.get("sha256")
        if digest is None and event_at >= BODY_LOCK_FROM:
            out.append(f"{where} needs `sha256`, the hash of the page's body; write the entry with `just verify` (ADR 012, OD-51)")
            continue
        if digest is not None and not SHA256.match(str(digest)):
            out.append(f"{where}.sha256 must be 64 lowercase hex characters")
            continue
        if latest is None or event_at >= latest[0]:
            latest = (event_at, actor, None if digest is None else str(digest))
        if actor.startswith("human:"):
            human_checks[actor] = max(event_at, human_checks.get(actor, event_at))

    if latest is not None and latest[2] is not None and latest[2] != body_hash(text):
        out.append(
            f"the body changed after the latest verification, by {latest[1]} at {_iso(latest[0])}; "
            "a human verifies the page again with `just verify` (ADR 012, OD-51)"
        )

    current_humans = {
        actor for actor, at in human_checks.items() if generated_at is None or at >= generated_at
    }
    if review and review != "slop" and not current_humans:
        out.append(
            f"review_status {review!r} needs a human verification at or after generated.at; "
            "the content changed after review, so reset it to `slop` or re-verify"
        )

    if kind == "Decision":
        decision = str(meta.get("decision", "")).strip()
        if decision not in DECISIONS:
            out.append(f"a Decision needs `decision`: one of {sorted(DECISIONS)}")
        elif decision == "accepted":
            acceptor = str(meta.get("accepted_by", "")).strip()
            if not acceptor.startswith("human:"):
                out.append("an accepted Decision needs `accepted_by`, a human actor")
            elif acceptor not in ACCEPTORS:
                out.append(f"accepted_by {acceptor!r}: only EM or the committee accepts an ADR (ADR 002); a team never does (OD-50)")
            else:
                _check_actor(acceptor, allowed, "accepted_by", out)
                if acceptor not in current_humans:
                    out.append(f"accepted_by {acceptor!r} has no verification at or after generated.at")
            if review not in ("human-reviewed", "finalized"):
                out.append("an accepted Decision needs review_status human-reviewed or finalized")
        elif decision == "superseded":
            target = str(meta.get("superseded_by", "")).strip()
            if not target:
                out.append("a superseded Decision needs `superseded_by`")
            elif not (docs / target.lstrip("/")).exists():
                out.append(f"superseded_by points to a missing page: {target}")

    if kind == "Runbook":
        if not str(meta.get("permission", "")).strip():
            out.append("a Runbook must name the `permission` it exercises")
        if review and review != "slop":
            drill = meta.get("drill")
            if not isinstance(drill, dict) or any(f not in drill for f in DRILL_FIELDS):
                out.append(f"a Runbook above `slop` needs a `drill` record with {list(DRILL_FIELDS)}")
            else:
                if str(drill.get("result")).strip() != "pass":
                    out.append("a Runbook above `slop` needs a drill with `result: pass`")
                seconds = drill.get("time_to_initiate_seconds")
                if not isinstance(seconds, (int, float)) or seconds < 0:
                    out.append("drill.time_to_initiate_seconds must be a non-negative number")
                elif seconds > SIX_HOURS:
                    out.append(f"drill time to initiate {seconds}s exceeds the six-hour ceiling ({SIX_HOURS}s)")

    for field in ("valid_as_of", "stale_after"):
        if field in meta and _as_dt(meta[field]) is None:
            out.append(f"{field} is not a date or datetime: {meta[field]!r}")
    if "stale_after" in meta and (stale := _as_dt(meta["stale_after"])):
        if stale <= datetime.now(timezone.utc).replace(tzinfo=None):
            out.append(f"WARN stale since {stale.date().isoformat()}; refresh or deprecate")

    ids: set[str] = set()
    sources = meta.get("sources", [])
    if sources and not isinstance(sources, list):
        out.append("`sources` must be a list of entries (OKF 0.2 section 5.1)")
        sources = []
    for index, entry in enumerate(sources or []):
        if not isinstance(entry, dict):
            out.append(f"sources[{index}] must be a mapping (OKF 0.2 section 5.1)")
            continue
        if source_id := entry.get("id"):
            if str(source_id) in ids:
                out.append(f"duplicate source id {str(source_id)!r}")
            ids.add(str(source_id))
        if not str(entry.get("resource", "")).strip():
            out.append(f"sources[{index}] needs a non-empty `resource` (OKF 0.2 section 5.1)")

    cited = set(CITATION_MARKER.findall(text))
    for marker in sorted(cited - ids):
        out.append(f"inline [{marker}] has no matching entry in `sources`")
    for unused in sorted(ids - cited):
        out.append(f"WARN source {unused!r} is declared but never cited inline")

    return out


def _check_links(path: Path, docs: Path, text: str) -> list[str]:
    out: list[str] = []
    for target in MARKDOWN_LINK.findall(text):
        if "://" in target or target.startswith(("mailto:", "#")):
            continue
        clean = target.split("#", 1)[0]
        if not clean:
            continue
        base = docs if clean.startswith("/") else path.parent
        candidate = (base / clean.lstrip("/")).resolve()
        if candidate.is_dir():
            candidate = candidate / "index.md"
        if not candidate.exists():
            out.append(f"broken link: {target}")
    return out


def _tracked(root: Path) -> list[str] | None:
    try:
        done = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=root, check=True, stdout=subprocess.PIPE,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return [item.decode() for item in done.stdout.split(b"\0") if item]


OD_REGISTER = "docs/registers/open-decisions.md"
ID_REGISTERS = (
    (OD_REGISTER, re.compile(r"^\|\s*(OD-\d+)\s*\|", re.MULTILINE)),
    ("docs/specs/invariants.md", re.compile(r"^\|\s*(INV-\d+)\s*\|", re.MULTILINE)),
)


def _check_registers(root: Path) -> list[Issue]:
    """IDs are used once and never reused; an open decision is complete (ADR 012)."""
    issues: list[Issue] = []
    for rel, pattern in ID_REGISTERS:
        path = root / rel
        if not path.is_file():
            continue
        ids = pattern.findall(path.read_text(encoding="utf-8"))
        for ident in sorted({i for i in ids if ids.count(i) > 1}):
            issues.append(Issue(rel, f"{ident} appears in more than one row; an ID is used once and never reused (ADR 012)"))
    numbers: dict[str, list[str]] = {}
    for path in sorted((root / "docs" / "adr").glob("[0-9][0-9][0-9]-*.md")):
        numbers.setdefault(path.name[:3], []).append(path.name)
    for number, names in sorted(numbers.items()):
        if len(names) > 1:
            issues.append(Issue("docs/adr", f"ADR {number} is taken by {', '.join(names)}; a number is used once (ADR 012)"))
    register = root / OD_REGISTER
    if register.is_file():
        open_part = register.read_text(encoding="utf-8").split("\n## Closed", 1)[0]
        for line in open_part.splitlines():
            if re.match(r"^\|\s*OD-\d+\s*\|", line):
                cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
                if len(cells) < 5 or not all(cells[:5]):
                    issues.append(Issue(OD_REGISTER, f"{cells[0]}: an open decision needs a question, the page that closes it, "
                                        "an agent recommendation and who decides (ADR 012)"))
    return issues


def _concepts(docs: Path) -> list[Path]:
    return sorted(p for p in docs.rglob("*.md") if p.name not in RESERVED)


def render_status(root: Path) -> str:
    """Render the document-status register from the frontmatter of every other concept."""
    docs = root / "docs"
    rows: list[tuple[str, str, str, str, str, str]] = []
    newest: datetime | None = None
    for path in _concepts(docs):
        rel = path.relative_to(docs).as_posix()
        if rel == REGISTER_REL:
            continue
        meta, _ = _frontmatter(path.read_text(encoding="utf-8"))
        meta = meta or {}
        generated = meta.get("generated") if isinstance(meta.get("generated"), dict) else {}
        at = _as_dt(generated.get("at")) if generated else None
        if at and (newest is None or at > newest):
            newest = at
        humans = sorted({
            str(e.get("by")) + (" (recorded)" if e.get("recorded_by") is not None else "")
            for e in _verifications(meta)
            if isinstance(e, dict) and str(e.get("by", "")).startswith("human:")
        })
        rows.append((
            f"[{rel}](/{rel})",
            str(meta.get("type", "?")),
            str(meta.get("review_status", "?")),
            str(meta.get("decision", "")) if meta.get("type") == "Decision" else "",
            at.date().isoformat() if at else "?",
            ", ".join(humans) if humans else "none",
        ))
    stamp = _iso(newest) if newest else "1970-01-01T00:00:00Z"
    lines = [
        "---",
        "type: Register",
        "title: Document status",
        "description: Generated table of every concept in the bundle with its review status, decision state and human verifiers.",
        "status: stable",
        "review_status: slop",
        "generated:",
        f"  by: {REGISTER_ACTOR}",
        f"  at: {stamp}",
        "verified: []",
        "---",
        "",
        "# Document status",
        "",
        "Generated by `python3 scripts/validate_docs.py --write-status`. Do not edit it by hand. CI fails when it is out of date.",
        "",
        "Review statuses: `slop` means drafted by an agent and not checked by a human. `human-skimmed` means a quick human pass. `human-reviewed` means a substantive human pass. `finalized` means accepted as final for the current stage. None of them means audit, legal review or governance approval.",
        "",
        "A verifier marked `(recorded)` did not type the entry: an agent recorded it on that human's written instruction, and the entry's `ref` links the decision-log heading that quotes it (ADR 003).",
        "",
        "| Page | Type | Review status | Decision | Last change | Verified by |",
        "|---|---|---|---|---|---|",
    ]
    lines += [f"| {' | '.join(row)} |" for row in rows]
    return "\n".join(lines) + "\n"


def validate(root: Path) -> list[Issue]:
    docs = root / "docs"
    if not docs.is_dir():
        return [Issue("docs", "OKF bundle is missing")]

    issues: list[Issue] = []
    allowed = _allowed_actors(root)
    if not allowed:
        issues.append(Issue("config/actors.yaml", "no actor allowlist found", warning=True))

    for path in sorted(docs.rglob("*.md")):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        meta, parse_error = _frontmatter(text)

        if parse_error:
            issues.append(Issue(rel, f"frontmatter is not valid YAML: {parse_error}"))
        elif path.name in RESERVED:
            if path == docs / "index.md":
                if meta is None or str(meta.get("okf_version")) != OKF_VERSION:
                    issues.append(Issue(rel, f'root index must declare okf_version: "{OKF_VERSION}"'))
            elif meta is not None:
                issues.append(Issue(rel, "reserved index and log files carry no frontmatter (OKF 0.2 sections 8, 9)"))
        elif meta is None:
            issues.append(Issue(rel, "concept has no parseable YAML frontmatter (OKF 0.2 section 11)"))
        else:
            for message in _check_concept(meta, text, allowed, docs):
                warning = message.startswith("WARN ")
                issues.append(Issue(rel, message.removeprefix("WARN "), warning=warning))

        issues.extend(Issue(rel, message) for message in _check_links(path, docs, text))

    issues.extend(_check_registers(root))
    issues.extend(_check_closed(root))

    agents = root / "AGENTS.md"
    if agents.is_file():
        lines = len(agents.read_text(encoding="utf-8").splitlines())
        if lines > AGENTS_MAX_LINES:
            issues.append(Issue("AGENTS.md", f"{lines} lines exceeds the cap of {AGENTS_MAX_LINES} (ADR 003); move detail to docs/"))
    else:
        issues.append(Issue("AGENTS.md", "missing; it is the source of truth for agents (ADR 003)"))

    if (tracked := _tracked(root)) is None:
        issues.append(Issue(".git", "could not inspect repository paths", warning=True))
    else:
        for item in tracked:
            if item.startswith(FORBIDDEN_TRACKED) and item not in ALLOWED_TRACKED:
                issues.append(Issue(item, "an ignored local path must never be committed (SECURITY.md)"))

    return issues


# --------------------------------------------------------------------------
# Generated blocks (ADR 012, OD-82): the register's closed index, the ADR index and the
# open decisions of each proposed ADR. `--write-status` writes them; `--check-status` fails
# when one is stale. Accepted ADRs are left alone, because an edit would break their
# recorded verification.
# --------------------------------------------------------------------------

CLOSED_REL = "docs/registers/closed-decisions.yaml"
ADR_INDEX_REL = "docs/adr/index.md"
LOG_REL = "docs/registers/decision-log.md"
OD_ID = re.compile(r"\AOD-(\d{2})\Z")
ADR_REF = re.compile(r"\AADR-(\d{3})(?:#d(\d+))?\Z")
GENERATED_START = "<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->"
GENERATED_END = "<!-- end of generated block -->"
SEE_LABELS = {"research": "research note", "specs": "specification", "registers": "register", "runbooks": "runbooks", "product": "product brief"}


def _slug(title: str) -> str:
    return re.sub(r"[^\w\- ]", "", title.strip().lower()).replace(" ", "-")


def _log_anchors(root: Path) -> dict[str, str]:
    """Each decision-log heading with its GitHub anchor; a repeated heading gets -1, -2."""
    path = root / LOG_REL
    out: dict[str, str] = {}
    seen: dict[str, int] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"## (.+?)\s*$", line)
        if match:
            base = _slug(match.group(1))
            count = seen.get(base, 0)
            seen[base] = count + 1
            out.setdefault(match.group(1), base if count == 0 else f"{base}-{count}")
    return out


def _adr_files(root: Path) -> dict[str, Path]:
    return {p.name[:3]: p for p in sorted((root / "docs" / "adr").glob("[0-9][0-9][0-9]-*.md"))}


def _adr_decision_numbers(path: Path) -> set[int]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^## Decision\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return {int(n) for n in re.findall(r"^(\d+)\. ", match.group(1), re.M)} if match else set()


def load_closed(root: Path) -> list[dict[str, Any]]:
    """The closed decisions, as written in the data file. Empty when the file is missing."""
    path = root / CLOSED_REL
    if not path.is_file():
        return []
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or []
    return data if isinstance(data, list) else []


def _od_number(od: str) -> int:
    match = OD_ID.match(str(od))
    return int(match.group(1)) if match else 0


def _relations(entry: dict[str, Any]) -> list[tuple[str, str]]:
    """An entry's links to earlier ODs as (od, kind), kind being full, part or refines."""
    out = []
    for item in entry.get("replaces") or []:
        if isinstance(item, dict):
            out.append((str(item.get("od")), "part" if item.get("part") else "full"))
    out += [(str(od), "refines") for od in entry.get("refines") or []]
    return out


def od_states(entries: list[dict[str, Any]]) -> dict[str, dict[str, list[str]]]:
    """For each closed OD, the ODs in force that replace it, replace it in part or refine it.
    A link from an OD that a later one replaced in full no longer counts: OD-78 replaced
    OD-75, so OD-75's refinement of OD-59 lapses and OD-59 stands as decided."""
    state = {str(e.get("id")): {"replaced_by": [], "in_part_by": [], "refined_by": []} for e in entries}
    dead: set[str] = set()
    for entry in sorted(entries, key=lambda e: _od_number(e.get("id")), reverse=True):
        od = str(entry.get("id"))
        if od in dead:
            continue
        for target, kind in _relations(entry):
            if target not in state:
                continue
            key = {"full": "replaced_by", "part": "in_part_by", "refines": "refined_by"}[kind]
            state[target][key].append(od)
            if kind == "full":
                dead.add(target)
    for value in state.values():
        for key in value:
            value[key].sort(key=_od_number)
    return state


def _join(items: list[str]) -> str:
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1]


def _number_text(numbers: list[int]) -> str:
    """32, 33, 34 and 36 as '32 to 34 and 36'."""
    runs: list[list[int]] = []
    for n in sorted(set(numbers)):
        if runs and n == runs[-1][-1] + 1:
            runs[-1].append(n)
        else:
            runs.append([n])
    parts = [str(r[0]) if len(r) == 1 else (f"{r[0]} and {r[1]}" if len(r) == 2 else f"{r[0]} to {r[-1]}") for r in runs]
    return _join(parts)


def _adr_refs_text(refs: list[str], files: dict[str, Path]) -> list[str]:
    grouped: dict[str, list[int]] = {}
    for ref in refs:
        match = ADR_REF.match(str(ref))
        if match:
            grouped.setdefault(match.group(1), [])
            if match.group(2):
                grouped[match.group(1)].append(int(match.group(2)))
    out = []
    for adr, numbers in grouped.items():
        name = files[adr].name if adr in files else f"{adr}.md"
        link = f"[ADR {adr}](/adr/{name}#decision)"
        if numbers:
            word = "decision" if len(set(numbers)) == 1 else "decisions"
            link += f", {word} {_number_text(numbers)}"
        out.append(link)
    return out


def _state_text(od: str, entry: dict[str, Any], states: dict[str, dict[str, list[str]]]) -> str:
    own = states.get(od, {"replaced_by": [], "in_part_by": [], "refined_by": []})
    if own["replaced_by"]:
        text = f"Replaced by {_join(own['replaced_by'])}"
        if own["in_part_by"]:
            text += f", and in part by {_join(own['in_part_by'])}"
    else:
        text = "In force"
        tails = []
        if own["in_part_by"]:
            tails.append(f"replaced in part by {_join(own['in_part_by'])}")
        if own["refined_by"]:
            tails.append(f"refined by {_join(own['refined_by'])}")
        if tails:
            text += "; " + "; ".join(tails)
    full = [t for t, kind in _relations(entry) if kind == "full"]
    part = [t for t, kind in _relations(entry) if kind == "part"]
    refines = [t for t, kind in _relations(entry) if kind == "refines"]
    forward = []
    if full:
        forward.append(f"replaces {_join(full)}")
    if part:
        forward.append(f"replaces in part {_join(part)}")
    if refines:
        forward.append(f"refines {_join(refines)}")
    text += "."
    if forward:
        text += " It " + "; it ".join(forward) + "."
    if entry.get("note"):
        text += " " + " ".join(str(entry["note"]).split())
    return text


def render_closed_index(root: Path) -> str:
    """The closed part of the register: one row per closed OD, newest decision state included."""
    entries = load_closed(root)
    states = od_states(entries)
    anchors = _log_anchors(root)
    files = _adr_files(root)
    lines = [
        "## Closed",
        "",
        GENERATED_START,
        "",
        f"Generated from [{Path(CLOSED_REL).name}]({Path(CLOSED_REL).name}). EM's words are in the "
        "[decision log](decision-log.md); each decision's text is in its ADR. The state counts only the "
        "ODs in force: an OD that a later one replaced no longer replaces or refines anything.",
        "",
        "| ID | Question | Closed | Record | State |",
        "|---|---|---|---|---|",
    ]
    for entry in sorted(entries, key=lambda e: _od_number(e.get("id"))):
        od = str(entry.get("id"))
        record = []
        for heading in entry.get("log") or []:
            label = re.sub(r"\A\d{4}-\d{2}-\d{2} — ", "", str(heading))
            record.append(f"[{label}](decision-log.md#{anchors.get(str(heading), _slug(str(heading)))})")
        record += _adr_refs_text([str(r) for r in entry.get("adr") or []], files)
        record += [f"[{SEE_LABELS.get(str(p).strip('/').split('/')[0], 'page')}]({p})" for p in entry.get("see") or []]
        question = " ".join(str(entry.get("question", "")).split())
        lines.append(f"| {od} | {question} | {entry.get('closed')} | {'; '.join(record)} | {_state_text(od, entry, states)} |")
    lines += ["", GENERATED_END]
    return "\n".join(lines) + "\n"


def _open_rows(root: Path) -> list[list[str]]:
    path = root / OD_REGISTER
    if not path.is_file():
        return []
    open_part = path.read_text(encoding="utf-8").split("\n## Closed", 1)[0]
    return [[c.strip() for c in line.strip().strip("|").split("|")]
            for line in open_part.splitlines() if re.match(r"^\|\s*OD-\d+\s*\|", line)]


def render_adr_open_block(root: Path, adr: str) -> str:
    """The open decisions that close in an ADR, from the register's open table."""
    items = []
    for cells in _open_rows(root):
        if len(cells) > 2 and re.search(rf"/adr/{adr}-", cells[2]):
            items.append(f"- [{cells[0]}](/registers/open-decisions.md): {' '.join(cells[1].split())}")
    body = "\n".join(items) if items else "No open decision closes in this record."
    return f"{GENERATED_START}\n\n{body}\n\n{GENERATED_END}"


def _with_open_block(text: str, block: str) -> str:
    """The ADR text with its open-decisions block replaced, or inserted under the heading."""
    if GENERATED_START in text and GENERATED_END in text:
        start = text.index(GENERATED_START)
        end = text.index(GENERATED_END, start) + len(GENERATED_END)
        return text[:start] + block + text[end:]
    heading = "\n## Open questions\n"
    if heading not in text:
        return text
    head, tail = text.split(heading, 1)
    return head + heading + "\n" + block + "\n" + ("\n" + tail.lstrip("\n") if tail.strip() else "")


def render_adr_index(root: Path) -> str:
    """The ADR index with each entry rewritten from its record's title and description."""
    path = root / ADR_INDEX_REL
    text = path.read_text(encoding="utf-8")
    files = _adr_files(root)
    out = []
    for line in text.splitlines():
        match = re.match(r"\* \[ADR (\d{3}):", line)
        if match and match.group(1) in files:
            meta, _ = _frontmatter(files[match.group(1)].read_text(encoding="utf-8"))
            meta = meta or {}
            description = " ".join(str(meta.get("description", "")).split())
            out.append(f"* [{meta.get('title', '')}]({files[match.group(1)].name}) - {description}")
        else:
            out.append(line)
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


def generated_files(root: Path) -> dict[Path, str]:
    """Every file that carries a generated block, with the text that it should hold."""
    out: dict[Path, str] = {}
    register = root / OD_REGISTER
    if register.is_file() and (root / CLOSED_REL).is_file():
        head = register.read_text(encoding="utf-8").split("\n## Closed", 1)[0].rstrip("\n")
        out[register] = head + "\n\n" + render_closed_index(root)
    if (root / ADR_INDEX_REL).is_file():
        out[root / ADR_INDEX_REL] = render_adr_index(root)
    for number, path in _adr_files(root).items():
        text = path.read_text(encoding="utf-8")
        meta, _ = _frontmatter(text)
        if (meta or {}).get("decision") == "accepted" or "\n## Open questions\n" not in text:
            continue
        out[path] = _with_open_block(text, render_adr_open_block(root, number))
    return out


def _check_closed(root: Path) -> list[Issue]:
    """The closed-decision data: known IDs, logs, records and links, and no gap in the numbers."""
    path = root / CLOSED_REL
    if not path.is_file():
        return []
    issues: list[Issue] = []
    try:
        entries = yaml.safe_load(path.read_text(encoding="utf-8")) or []
    except yaml.YAMLError as exc:
        return [Issue(CLOSED_REL, f"not valid YAML: {exc}")]
    if not isinstance(entries, list):
        return [Issue(CLOSED_REL, "must be a list of closed decisions")]
    anchors = _log_anchors(root)
    files = _adr_files(root)
    numbers = {a: _adr_decision_numbers(p) for a, p in files.items()}
    open_ids = {cells[0] for cells in _open_rows(root)}
    closed_ids: list[str] = []
    for entry in entries:
        od = str(entry.get("id", "")) if isinstance(entry, dict) else ""
        where = od or "an entry"
        if not OD_ID.match(od):
            issues.append(Issue(CLOSED_REL, f"{where}: `id` must be OD-NN"))
            continue
        closed_ids.append(od)
        if od in open_ids:
            issues.append(Issue(CLOSED_REL, f"{od} is both open and closed; remove its row from the open table"))
        if not str(entry.get("question", "")).strip():
            issues.append(Issue(CLOSED_REL, f"{od}: needs its question"))
        if not isinstance(entry.get("closed"), date):
            issues.append(Issue(CLOSED_REL, f"{od}: `closed` must be a date, YYYY-MM-DD"))
        logs = entry.get("log") or []
        if not logs and not entry.get("note"):
            issues.append(Issue(CLOSED_REL, f"{od}: needs the decision-log heading that records it, or a note on why none does"))
        for heading in logs:
            if str(heading) not in anchors:
                issues.append(Issue(CLOSED_REL, f"{od}: no decision-log heading {heading!r}"))
        for ref in entry.get("adr") or []:
            match = ADR_REF.match(str(ref))
            if not match or match.group(1) not in files:
                issues.append(Issue(CLOSED_REL, f"{od}: unknown ADR reference {ref!r}"))
            elif match.group(2) and int(match.group(2)) not in numbers[match.group(1)]:
                issues.append(Issue(CLOSED_REL, f"{od}: ADR {match.group(1)} has no decision {match.group(2)}"))
        for page in entry.get("see") or []:
            if not (root / "docs" / str(page).lstrip("/")).is_file():
                issues.append(Issue(CLOSED_REL, f"{od}: no page {page}"))
        for target, kind in _relations(entry):
            if not OD_ID.match(target):
                issues.append(Issue(CLOSED_REL, f"{od}: {target!r} is not an OD"))
            elif _od_number(target) >= _od_number(od):
                issues.append(Issue(CLOSED_REL, f"{od}: it can only {'refine' if kind == 'refines' else 'replace'} an earlier OD, not {target}"))
    known = set(closed_ids)
    for od in sorted({od for od in closed_ids if closed_ids.count(od) > 1}):
        issues.append(Issue(CLOSED_REL, f"{od} is listed more than once"))
    for entry in entries:
        if isinstance(entry, dict):
            for target, _ in _relations(entry):
                if OD_ID.match(target) and target not in known:
                    issues.append(Issue(CLOSED_REL, f"{entry.get('id')}: {target} is not a closed decision"))
    every = known | open_ids
    if every:
        top = max(_od_number(od) for od in every)
        for n in range(1, top + 1):
            if f"OD-{n:02d}" not in every:
                issues.append(Issue(CLOSED_REL, f"OD-{n:02d} is neither open nor closed; an OD number is never skipped"))
    return issues


def generated_issues(root: Path) -> list[Issue]:
    """A stale generated block, file by file."""
    out = []
    for path, wanted in generated_files(root).items():
        if path.read_text(encoding="utf-8") != wanted:
            out.append(Issue(path.relative_to(root).as_posix(), "a generated block is out of date; run --write-status and commit the result"))
    return out



def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write-status", action="store_true", help="regenerate the document-status register")
    mode.add_argument("--check-status", action="store_true", help="fail if the register is out of date")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    register = root / "docs" / REGISTER_REL
    if args.write_status:
        for path, text in generated_files(root).items():
            path.write_text(text, encoding="utf-8")
        register.write_text(render_status(root), encoding="utf-8")

    issues = validate(root)
    if args.check_status:
        current = register.read_text(encoding="utf-8") if register.exists() else ""
        if current != render_status(root):
            issues.append(Issue(f"docs/{REGISTER_REL}", "out of date; run --write-status and commit the result"))
        issues.extend(generated_issues(root))

    errors = [issue for issue in issues if not issue.warning]
    for issue in issues:
        print(issue, file=sys.stderr if not issue.warning else sys.stdout)
    concepts = len(_concepts(root / "docs"))
    print(f"\ndocs/: {concepts} concepts · {len(errors)} errors · {len(issues) - len(errors)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
