---
type: Decision
title: "ADR 001: Repository scope, visibility, licence and name"
description: Repository scope, publication rules, licences, name and token-symbol restriction.
tags: [repository, licence, visibility, naming]
status: draft
review_status: human-reviewed
decision: accepted
accepted_by: human:em
generated:
  by: claude-code/opus-5.5
  at: 2026-10-19T22:29:31Z
verified:
  - by: human:em
    at: 2026-10-05T20:27:31Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-05--adr-001-to-adr-004-accepted
  - by: human:em
    at: 2026-10-06T08:16:51Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-06--adr-001-and-adr-004-verified-again
  - by: human:em
    at: 2026-10-20T18:46:48Z
    recorded_by: claude-code/opus-5.5
    ref: /registers/decision-log.md#2026-10-20--adr-001-to-adr-004-verified-again-and-yt-registered
    sha256: 01803ac13d0dd11559df48adc5d0509bd03120cc310c588f6d83373243e852fd
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's setup answers of 2026-09-30, the vendor's announcement, 2026-10-02, and the constellation's licence, 2026-10-06
  - id: s2
    resource: "https://www.gnu.org/licenses/gpl-3.0.html"
    title: GNU General Public License, version 3, section 13
  - id: s3
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/TrustedCaller.sol#L2"
    title: Easy Track TrustedCaller at 3183d1f — SPDX-License-Identifier GPL-3.0
  - id: s4
    resource: "https://www.gnu.org/licenses/agpl-3.0.html"
    title: GNU Affero General Public License, version 3, section 13
  - id: s5
    resource: "https://phantom.com/tokens/ethereum/0xd09185df1d4b966ac559fa72ce5e6adf5dc5ffe3"
    title: Clutch The Bald Eagle (CLUTCH), a token on Ethereum
  - id: s6
    resource: "https://web3.bitget.com/en/swap/sol/93tQHLgbK4J8dzv3xictW46JqfKCjKcoe69Q9nrtpump"
    title: Clutch Protocol (CLUTCH), a token on Solana
  - id: s7
    resource: "https://research.lido.fi/t/lido-labs-goose-3-lido-s-next-chapter/10927"
    title: GOOSE — the Guided Open Objective Setting Exercise
  - id: s8
    resource: "https://research.lido.fi/t/nest-network-economic-support-tokenomics/10648"
    title: NEST — Network Economic Support Tokenomics
  - id: s9
    resource: "https://www.gnu.org/licenses/lgpl-3.0.html"
    title: GNU Lesser General Public License, version 3 — the GNU GPL, version 3, with added permissions
---

# ADR 001: Repository scope, visibility, licence and name

## Context

- Decisions, specifications, policy, code, tests and deployment records need one consistent source.
- The factories will reuse Easy Track's audited GPL-3.0 base contracts [s3].
- The dry-run kit has six commits whose messages explain the corrections.
- The design names an unannounced screening vendor.

## Decision

EM decided these points on 2026-09-30 [s1]:

1. **Scope.** One repository holds the product documents, ADRs, specifications including the LIP, the Easy Track factories, the permission policy, deployment scripts and records, runbooks and the dry-run kit.
2. **Boundary.** The CTO knowledge base keeps its assessment of the system and the diligence evidence, restricted. This repository is the system of record for the system. The knowledge base is the record of judgement about it.
3. **Kit migration.** The kit enters with its six commits. Its history must pass the same publication test as its files.
4. **Visibility.** The repository is private now and public no later than deployment. Nothing enters it that could not be published at deployment. The screening vendor's identity and any unannounced counterparty terms stay out until they are announced.
5. **Licence.** AGPL-3.0-or-later. Files derived from Easy Track's base contracts keep GPL-3.0 [s3]. GPL-3.0 section 13 permits combining them with AGPL-3.0 code [s2].
6. **Name.** Clutch. A clutch is the set of eggs brooded together in one nest. The name continues the bird names of Lido governance: GOOSE [s7], EGG, NEST [s8] and Gaggle.
7. **No token.** Clutch must never become a token symbol. CLUTCH is already the symbol of unrelated tokens, for example on Ethereum [s5] and on Solana [s6].

EM decided on 2026-10-02, closing OD-07 [s1]:

8. **The vendor's name.** The redaction of the screening vendor's identity ends when the mandate is posted on the forum, after the vendor agrees in writing to be named for this use. Commercial terms never enter the repository.

EM decided on 2026-10-06, closing OD-34 [s1]:

9. **The constellation's licence.** Files derived from the policy provider's Zodiac constellation keep LGPL-3.0-only. A derived file gets `SPDX-License-Identifier: LGPL-3.0-only` when it changes. New files use AGPL-3.0-or-later, the policy compiler among them. LGPL-3.0 is GPL-3.0 with added permissions [s9], so the reasoning of decision 5 applies.

## Options considered

- Separate documentation and code repositories: rejected because specifications and tests must change in the same commit.
- Import without history: rejected because commit messages explain the corrections.
- GPL-3.0 throughout: rejected because AGPL-3.0-or-later matches Gaggle. GPL-3.0 section 13 permits Easy Track-derived files to keep their licence [s2].
- Roost, aerie or active-treasury: EM chose Clutch.
- Rewrite the policy port under AGPL-3.0-or-later and delete the copy: EM rejected this because a rewrite that follows the copy can still count as derived.

## Consequences

- The publication test covers files and commit messages.
- Source files use `SPDX-License-Identifier: AGPL-3.0-or-later`. Easy Track-derived files keep `GPL-3.0`; constellation-derived files keep `LGPL-3.0-only` (decision 9).
- The LGPL text in `policy/constellation/LICENSE` must accompany derived files. The licence reading in decision 9 is not a legal review.
- The kit's history names the policy provider. Its proposal repository is public, so the history passes the publication test.
- AGPL-3.0 section 13 requires source access for users of a modified version over a network [s4]. Public source and explorer verification at deployment are the planned response.
- The decision log redacts the screening vendor's name and mandate size. The name enters when the mandate is posted, under decision 8.

## Confirmation

- The visibility setting of `lidofinance/clutch` on GitHub.
- `grep -rL --include='*.sol' --include='*.py' --include='*.ts' --exclude-dir=node_modules "SPDX-License-Identifier: AGPL-3.0-or-later" src script scripts test policy` lists only files derived from Easy Track or from the provider's constellation. A CI check replaces this command once the factories exist.

## Reversal conditions

- A legal review requires a different licence or an earlier publication.
- A naming conflict appears.

## Open questions

None.
