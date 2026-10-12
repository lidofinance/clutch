#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check every outside link of the published onboarding guide (ADR 012, decision 11).

Run:
  python3 scripts/check_links.py            # links into GitHub through its API; GITHUB_TOKEN is optional
  python3 scripts/check_links.py --local    # this repository's own links against the working tree

It reads the committed page, so it checks the links that readers click. A link into
a GitHub repository must name a file that exists on the linked branch, and its anchor
must be a heading of that file. The repository is public, so the API answers without
a token; a token only raises the rate limit. Any other link must answer with a status
below 400. The build check resolves the same links against the files of each pull
request; a scheduled job runs this script once a week for the published state.
"""

from __future__ import annotations

import argparse
import datetime
import html
import importlib.util
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "onboarding" / "clutch-onboarding.html"
BLOB = re.compile(r"^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/([^#?]+)(?:#(.*))?$")
AGENT = "clutch-onboarding-link-check"


class RateLimited(Exception):
    """GitHub's API refuses reads until the time in the exception."""


def _builder() -> Any:
    spec = importlib.util.spec_from_file_location("build_onboarding", ROOT / "scripts" / "build_onboarding.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["build_onboarding"] = module
    spec.loader.exec_module(module)
    return module


def links(page: str) -> list[str]:
    return sorted({html.unescape(u) for u in re.findall(r'(?:href|src)="(https?://[^"]+)"', page)})


class Checker:
    def __init__(self, token: str | None, local: bool) -> None:
        self.token = token
        self.local = local
        self.files: dict[str, str | None] = {}
        self.B = _builder()

    def _get(self, url: str, headers: dict[str, str]) -> tuple[int, str]:
        request = urllib.request.Request(url, headers={"User-Agent": AGENT, **headers})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            # A spent rate limit is no answer about the link: stop instead of failing every link.
            if url.startswith("https://api.github.com/") and exc.code in (403, 429) and exc.headers.get("x-ratelimit-remaining") == "0":
                raise RateLimited(exc.headers.get("x-ratelimit-reset", "")) from exc
            return exc.code, ""
        except (urllib.error.URLError, TimeoutError) as exc:
            return 0, str(exc)

    def file(self, url: str, owner: str, repo: str, ref: str, path: str) -> str | None:
        key = f"{owner}/{repo}@{ref}:{path}"
        if key not in self.files:
            if self.local and url.startswith(self.B.REPO_URL):
                local = ROOT / urllib.parse.unquote(path)
                self.files[key] = local.read_text(encoding="utf-8") if local.is_file() else None
            else:
                headers = {"Accept": "application/vnd.github.raw+json", "X-GitHub-Api-Version": "2022-11-28"}
                if self.token:
                    headers["Authorization"] = f"Bearer {self.token}"
                api = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={urllib.parse.quote(ref, safe='')}"
                status, body = self._get(api, headers)
                self.files[key] = body if status == 200 else None
        return self.files[key]

    def problem(self, url: str) -> str | None:
        """Why a link fails, or None when it resolves."""
        match = BLOB.match(url)
        if not match:
            status, detail = self._get(url, {})
            return None if 0 < status < 400 else f"answers {status or detail}"
        owner, repo, ref, path, anchor = match.groups()
        text = self.file(url, owner, repo, ref, path)
        if text is None:
            return f"{path} does not exist on {ref}, or the API refused the read"
        if anchor and path.endswith(".md"):
            slugs = {s["slug"] for s in self.B.parse_sections(text)}
            if urllib.parse.unquote(anchor) not in slugs:
                return f"{path} has no heading with the anchor #{anchor}"
        return None


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--page", type=Path, default=PAGE, help="the page to read (default: the committed guide)")
    parser.add_argument("--local", action="store_true", help="read this repository's links from the working tree, not the API")
    args = parser.parse_args(argv)
    page = args.page.read_text(encoding="utf-8")
    checker = Checker(os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"), args.local)
    found = links(page)
    try:
        failures = [(url, why) for url in found if (why := checker.problem(url))]
    except RateLimited as exc:
        reset = datetime.datetime.fromtimestamp(int(exc.args[0]), datetime.timezone.utc).strftime("%H:%M UTC") if str(exc.args[0]).isdigit() else "later"
        print(f"GitHub's API rate limit is spent until {reset}, so no link was judged. Set GITHUB_TOKEN, or run again then.")
        return 2
    for url, why in failures:
        print(f"FAIL  {url}\n      {why}")
    print(f"{len(found)} links to {len(checker.files)} files: " + (f"{len(failures)} fail" if failures else "all resolve"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
