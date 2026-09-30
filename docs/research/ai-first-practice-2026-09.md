---
type: Research Note
title: AI-first repository practice, September 2026
description: The evidence behind Clutch's decision process and agent operating model, from Lido's own repositories and from public practice in September 2026.
tags: [ai-first, agents, repository, okf, security]
status: stable
review_status: slop
valid_as_of: 2026-09-30
stale_after: 2027-03-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/lidofinance/lido-lend-markets/blob/bdf9e5047525c5b6f7489385fd494d53242db9a3/AGENTS.md"
    title: lido-lend-markets AGENTS.md at bdf9e50 (private repository; patterns only)
  - id: s2
    resource: "https://github.com/lidofinance/lido-lend-markets/blob/bdf9e5047525c5b6f7489385fd494d53242db9a3/docs/product/DOCUMENT_STATUS.md"
    title: lido-lend-markets document-status register at bdf9e50
  - id: s3
    resource: "https://github.com/lidofinance/lido-lend-markets/blob/bdf9e5047525c5b6f7489385fd494d53242db9a3/docs/specs/README.md"
    title: lido-lend-markets specification layers at bdf9e50
  - id: s4
    resource: "https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/ad30107c31c06aec8a7d5636e0d1058118604e6f/SPEC.md"
    title: Open Knowledge Format specification, version 0.2, at ad30107
  - id: s5
    resource: "https://arxiv.org/abs/2602.11988"
    title: Evaluating AGENTS.md, ETH Zurich, arXiv 2602.11988, 2026-02-12
  - id: s6
    resource: "https://usewire.io/blog/agents-md-466-projects-context-engineering/"
    title: What 466 AGENTS.md files teach about context engineering, an MSR 2026 study summary
  - id: s7
    resource: "https://www.cybedefend.com/en/blog/instruction-file-injection-agents-md-claude-md"
    title: Instruction file injection through AGENTS.md and CLAUDE.md
  - id: s8
    resource: "https://arxiv.org/abs/2609.29454"
    title: Agent skills for smart contract auditing, arXiv 2609.29454, 2026-09-24
  - id: s9
    resource: "https://www.linuxfoundation.org/press/agentic-ai-foundation-adds-43-new-members-as-enterprise-and-government-adoption-of-open-agent-standards-accelerates"
    title: Linux Foundation — the Agentic AI Foundation and its open agent standards
  - id: s10
    resource: "https://atlan.com/know/ai-agent/ai-agent-skills/what-are-agent-skills/"
    title: Agent Skills — format and adoption
  - id: s11
    resource: "https://www.augmentcode.com/guides/software-factory-metrics"
    title: Software factory metrics, citing LinearB and CircleCI figures (secondary source)
  - id: s12
    resource: "https://arxiv.org/pdf/2606.06752"
    title: Bloomberg's Pomona, arXiv 2606.06752
  - id: s13
    resource: "https://levelop.dev/blog/spec-driven-development-tools-compared"
    title: Spec Kit, Kiro and OpenSpec compared
  - id: s14
    resource: "https://uvik.net/spec-driven-development-benchmark/"
    title: Uvik spec-driven development benchmark (discarded, see below)
---

# AI-first repository practice, September 2026

An agent collected this evidence on 2026-09-30 for the setup interview. The lido-lend-markets repository is private, so this page records its patterns, not its content.

## Lido's own template

- lido-lend-markets keeps `AGENTS.md` as the single source of truth and `CLAUDE.md` as a one-line pointer to it. It adds stubs for other tools only when those tools are used [s1].
- Every agent-drafted document carries a review status: `slop`, `human-skimmed`, `human-reviewed` or `finalized`. A substantial rewrite resets it to `slop` [s1][s2].
- The status is self-declared prose. It carries no actor and no time, and the status register is kept by hand [s2]. OKF frontmatter and a validator fix each of these.
- Specifications have two layers. Hand-written pages carry what code cannot say. An API reference is generated from NatSpec and never edited by hand [s3].
- Tests derive from requirements, never from the implementation. Behaviour and its specification change in the same commit [s1].

## Open Knowledge Format

OKF 0.2 is the current version. It makes provenance, trust and freshness first-class frontmatter, and it allows producer-defined keys [s4]. It does not define a format for decisions or specifications, so it can wrap the lend-markets conventions. Its canonical repository is `GoogleCloudPlatform/open-knowledge-format` [s4].

## Evidence on agent instruction files

- AGENTS.md is the cross-tool standard, under the Linux Foundation's Agentic AI Foundation [s9]. Claude Code needs a `CLAUDE.md` that points to it.
- Across benchmark and real repositories, context files did not generally improve task success and raised inference cost by 20 to 23 percent. Files written by a model reduced success in 5 of 8 settings. Developer-written files gained 2.4 percent, which was not significant. Repository overviews did not help; specific rules were followed well [s5].
- In a study of 466 projects, half of the instruction files never changed after their first commit. A blank or copied file was worse than none [s6].
- Instruction files are attack surface. A February 2026 campaign exploited GitHub Actions workflows and replaced repositories' `CLAUDE.md` files. Injection also arrives through pull-request text, issues, configuration files, file names and invisible Unicode [s7].

## Skills and specifications

- Agent Skills are a cross-tool format for procedures: a `SKILL.md` with a name and a description, loaded on demand [s10].
- On 83 smart-contract audit skills, skills raised one model's detection score by 22.8 percent. Model choice mattered more than skill design, and skills that failed to trigger were the main weakness [s8].
- Spec-driven tools are popular, and their success figures are vendor claims [s13]. One benchmark states a run date after its own publication date, so its results are discarded [s14]. The practice of writing the specification first and deriving tests from it holds up; the frameworks are not yet proven.

## Review is the bottleneck

- In a dataset of 8.1 million pull requests, 79 percent of agent-opened pull requests merged in the top decile of organisations, against 92 percent of human-only ones [s11].
- Feature-branch throughput rose 59 percent year on year while median main-branch success fell to 70.8 percent [s11].
- At Bloomberg, small agentic pull requests were accepted at 82.1 percent [s12].

## What this means for Clutch

- Keep `AGENTS.md` short, rules only, with exact commands. The architecture belongs in `docs/`, which agents read on demand.
- Check instruction files for freshness in CI: broken paths and commands that no longer exist.
- Protect instruction files, workflows and skills with CODEOWNERS and required human review.
- Optimise for how fast a reviewer can verify a change, not for how fast an agent can write it. This is the North Star Metric in the [product brief](/product/brief.md).
- Write skill descriptions so that they trigger, and test them.
