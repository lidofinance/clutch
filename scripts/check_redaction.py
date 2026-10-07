#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Refuse restricted terms and secrets in the repository's text files (ADR 012).

Run:
  uv run --with pyyaml==6.0.2 python scripts/check_redaction.py                    # check
  uv run --with pyyaml==6.0.2 python scripts/check_redaction.py --hash KIND "TERM" # an entry

Restricted terms are the screening vendor's identity, the addresses that reveal it, and
figures from the unapproved mandate (ADR 001, SECURITY.md). config/redaction.yaml holds
only salted SHA-256 hashes, so it does not name what it blocks. A hash hides a term from
a casual reader, not from someone who guesses it. Three kinds:

  word     the term inside the line's letters and digits, in any case, so a hyphen,
           a space or a longer word around it does not hide it
  address  a 20-byte hex address
  figure   a percentage or a dollar amount, after normalization ("12 %" -> "12%",
           "$1.50M" -> "$1.5m")

Secrets are private keys, RPC URLs that carry a key, and API tokens. A finding names the
file, the line and the kind, never the value. The check reads every tracked file and
every new file that git does not ignore.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONFIG = "config/redaction.yaml"
SALT = "clutch-redaction"
SKIP_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".ico", ".woff", ".woff2", ".zip", ".gz", ".lockb"}

WORD = re.compile(r"[a-z0-9]+")
ADDRESS = re.compile(r"0x[0-9a-fA-F]{40}(?![0-9a-fA-F])")
PERCENT = re.compile(r"(?<![\w.])(\d+(?:\.\d+)?)\s?%")
DOLLARS = re.compile(r"\$\s?(\d[\d,]*(?:\.\d+)?)\s?(k|m|mm|b|bn|million|billion)?\b", re.IGNORECASE)
UNITS = {"k": "k", "m": "m", "mm": "m", "million": "m", "b": "b", "bn": "b", "billion": "b"}

SECRETS = (
    ("private key", re.compile(r"(?i)\b(private[_-]?key|executor[_-]?key|mnemonic|seed[_-]?phrase)\b\s*[:=]\s*[\"']?(0x)?[0-9a-fA-F]{64}\b")),
    ("PEM private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----")),
    ("RPC URL with a key", re.compile(
        r"https?://[^\s\"'<>]*(?:alchemy\.com/v2/|infura\.io/v3/|quiknode\.pro/|ankr\.com/[a-z_]+/|"
        r"[?&](?:dkey|apikey|api_key|key|token)=)[A-Za-z0-9_-]{16,}")),
    ("API key assignment", re.compile(
        r"(?i)\b[A-Z0-9_]*(?:API[_-]?KEY|SECRET|TOKEN|PASSWORD)\b\s*[:=]\s*[\"']?(?!\$\{)[A-Za-z0-9_\-/+]{24,}")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b")),
)


def digest(kind: str, value: str) -> str:
    return hashlib.sha256(f"{SALT}:{kind}:{value}".encode("utf-8")).hexdigest()


def _number(text: str) -> str:
    value = float(text.replace(",", ""))
    return f"{value:g}"


def normalize(kind: str, term: str) -> str:
    """The form that the check hashes, for a term given with --hash."""
    term = term.strip()
    if kind == "word":
        return "".join(WORD.findall(term.lower()))
    if kind == "address":
        return term.lower()
    if kind == "figure":
        if match := PERCENT.fullmatch(term):
            return f"{_number(match.group(1))}%"
        if match := DOLLARS.fullmatch(term):
            return f"${_number(match.group(1))}{UNITS.get((match.group(2) or '').lower(), '')}"
        raise ValueError(f"not a percentage or a dollar amount: {term!r}")
    raise ValueError(f"unknown kind {kind!r}; use word, address or figure")


def load(root: Path = ROOT) -> dict[str, object]:
    data = yaml.safe_load((root / CONFIG).read_text(encoding="utf-8")) or {}
    words: dict[int, set[str]] = {}
    for entry in data.get("word") or []:
        words.setdefault(int(entry["length"]), set()).add(str(entry["sha256"]))
    return {
        "word": words,
        "address": {str(e["sha256"]) for e in data.get("address") or []},
        "figure": {str(e["sha256"]) for e in data.get("figure") or []},
    }


def scan_text(text: str, denylist: dict[str, object]) -> list[tuple[int, str]]:
    """Every finding in one text as (line number, kind)."""
    found: list[tuple[int, str]] = []
    words: dict[int, set[str]] = denylist["word"]  # type: ignore[assignment]
    for number, line in enumerate(text.splitlines(), 1):
        squashed = "".join(WORD.findall(line.lower()))  # also finds a term split by a hyphen or a space
        if any(digest("word", squashed[i:i + length]) in hashes
               for length, hashes in words.items() for i in range(len(squashed) - length + 1)):
            found.append((number, "restricted word"))
        if any(digest("address", a.lower()) in denylist["address"] for a in ADDRESS.findall(line)):
            found.append((number, "restricted address"))
        figures = [f"{_number(m.group(1))}%" for m in PERCENT.finditer(line)]
        figures += [f"${_number(m.group(1))}{UNITS.get((m.group(2) or '').lower(), '')}" for m in DOLLARS.finditer(line)]
        if any(digest("figure", f) in denylist["figure"] for f in figures):
            found.append((number, "restricted figure"))
        for kind, pattern in SECRETS:
            if pattern.search(line):
                found.append((number, kind))
    return found


def files(root: Path = ROOT) -> list[str]:
    done = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                          cwd=root, check=True, stdout=subprocess.PIPE)
    return sorted({item.decode() for item in done.stdout.split(b"\0") if item})


def main(argv: list[str]) -> int:
    if argv[:1] == ["--hash"]:
        if len(argv) != 3:
            print("usage: check_redaction.py --hash word|address|figure TERM", file=sys.stderr)
            return 2
        kind, term = argv[1], argv[2]
        value = normalize(kind, term)
        entry = {"sha256": digest(kind, value)}
        if kind == "word":
            entry = {"length": len(value), **entry}
        print(yaml.safe_dump({kind: [entry]}, sort_keys=False).strip())
        return 0
    denylist = load()
    problems = []
    for rel in files():
        path = ROOT / rel
        if path.suffix.lower() in SKIP_SUFFIXES or not path.is_file() or rel == CONFIG:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        problems += [f"{rel}:{line}: {kind}" for line, kind in scan_text(text, denylist)]
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} finding(s). Remove the term or the secret; see SECURITY.md and ADR 012.", file=sys.stderr)
        return 1
    print("No restricted term and no secret found.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
