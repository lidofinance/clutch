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
- Actors come from config/actors.yaml.

Clutch rules on top of the Gaggle profile:
- AGENTS.md holds at most 60 lines (ADR 003).
- Every Decision declares `constrains_operator` as true or false. An accepted Decision
  that constrains the operator also needs a `human:emergency-brakes` verification at or
  after `generated.at` (ADR 002).
- Every Runbook names the `permission` it exercises. A Runbook above `slop` needs a
  passing `drill` record, and the drill's time to initiate must not exceed six hours,
  the mandate's ceiling (ADR 002, ROADMAP standing gates).
- A verification by a body, `human:tmc` or `human:emergency-brakes`, carries `ref`: an
  https or urn link to the body's decision record (ADR 002, OD-15).
- An agent records a human's own verification only on that human's written instruction
  (ADR 003, OD-31). The entry names the agent in `recorded_by`, and its `ref` links the
  decision-log heading that quotes the instruction. An agent never records a body's
  verification.
"""

from __future__ import annotations

import argparse
import functools
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
CO_VERIFIER = "human:emergency-brakes"
BODY_ACTORS = ("human:tmc", "human:emergency-brakes")
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
    return {str(a) for key in ("humans", "processes", "agents") for a in (data.get(key) or [])}


def _check_actor(actor: Any, allowed: set[str], where: str, out: list[str]) -> None:
    text = str(actor)
    if not ACTOR.match(text):
        out.append(f"{where} is not a valid OKF actor id: {text!r}")
    elif allowed and text not in allowed:
        out.append(f"{where} {text!r} is not in config/actors.yaml")


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
        _check_actor(generated["by"], allowed, "generated.by", out)
        generated_at = _as_dt(generated["at"])
        if generated_at is None:
            out.append(f"generated.at is not an ISO 8601 datetime: {generated['at']!r}")
        elif _in_future(generated_at):
            out.append(f"generated.at is in the future: {_iso(generated_at)}")

    raw_verified = meta.get("verified", [])
    if raw_verified not in (None, []) and not isinstance(raw_verified, (list, dict)):
        out.append("`verified` must be a list of {by, at} events (OKF 0.2 section 5.2)")
    human_checks: dict[str, datetime] = {}
    for index, event in enumerate(_verifications(meta)):
        where = f"verified[{index}]"
        if not isinstance(event, dict) or not event.get("by") or not event.get("at"):
            out.append(f"{where} must be a mapping with `by` and `at`")
            continue
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
            if actor in BODY_ACTORS:
                out.append(f"{where}: an agent never records a body's verification; a member records it (ADR 002, OD-15)")
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
        if actor.startswith("human:"):
            human_checks[actor] = max(event_at, human_checks.get(actor, event_at))

    current_humans = {
        actor for actor, at in human_checks.items() if generated_at is None or at >= generated_at
    }
    if review and review != "slop" and not current_humans:
        out.append(
            f"review_status {review!r} needs a human verification at or after generated.at; "
            "the content changed after review, so reset it to `slop` or re-verify"
        )

    if kind == "Decision":
        constrains = meta.get("constrains_operator")
        if not isinstance(constrains, bool):
            out.append("a Decision must declare `constrains_operator: true` or `false`")
        decision = str(meta.get("decision", "")).strip()
        if decision not in DECISIONS:
            out.append(f"a Decision needs `decision`: one of {sorted(DECISIONS)}")
        elif decision == "accepted":
            acceptor = str(meta.get("accepted_by", "")).strip()
            if not acceptor.startswith("human:"):
                out.append("an accepted Decision needs `accepted_by`, a human actor")
            else:
                _check_actor(acceptor, allowed, "accepted_by", out)
                if acceptor not in current_humans:
                    out.append(f"accepted_by {acceptor!r} has no verification at or after generated.at")
            if review not in ("human-reviewed", "finalized"):
                out.append("an accepted Decision needs review_status human-reviewed or finalized")
            if constrains is True and CO_VERIFIER not in current_humans:
                out.append(
                    f"an accepted Decision that constrains the operator needs a {CO_VERIFIER} "
                    "verification at or after generated.at"
                )
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write-status", action="store_true", help="regenerate the document-status register")
    mode.add_argument("--check-status", action="store_true", help="fail if the register is out of date")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    register = root / "docs" / REGISTER_REL
    if args.write_status:
        register.write_text(render_status(root), encoding="utf-8")

    issues = validate(root)
    if args.check_status:
        current = register.read_text(encoding="utf-8") if register.exists() else ""
        if current != render_status(root):
            issues.append(Issue(f"docs/{REGISTER_REL}", "out of date; run --write-status and commit the result"))

    errors = [issue for issue in issues if not issue.warning]
    for issue in issues:
        print(issue, file=sys.stderr if not issue.warning else sys.stdout)
    concepts = len(_concepts(root / "docs"))
    print(f"\ndocs/: {concepts} concepts · {len(errors)} errors · {len(issues) - len(errors)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
