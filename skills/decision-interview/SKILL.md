---
name: decision-interview
description: Open a Clutch open decision (OD) and run EM's interview on it. Use when a design or process question needs EM's decision, when EM asks for "an interview", or when an open row in docs/registers/open-decisions.md is ready to decide.
license: AGPL-3.0-or-later
---

# Run a Clutch decision interview

1. Read `docs/registers/open-decisions.md`, the ADR that the question belongs to and the latest decision-log entries. Reuse an open OD if it already holds the question.
2. To open a new OD, take the next number on `main`. Add one complete row to the open table: the question with its options, the page that closes it, your recommendation with its reason, and who decides. The validator refuses an incomplete row (ADR 012).
3. Check every fact that an option rests on before you write it: read the code, the chain or the source, and record new reads in a research note with their exact commands. Never present an option that the repository's rules forbid.
4. Ask EM in one message, numbered Q1, Q2 and so on. For each question give the options as A, B, C with their main consequence, your recommendation, and what changes in the repository for each answer. Ask only what EM must decide; propose the rest.
5. Wait for EM's answer. Never assume one.
6. Record the answer with the `record-decision` skill. Then look for the next decision that the answer opens, and say so.
7. Keep one decisions branch open at a time. Batch the questions that are ready instead of asking them one by one.
