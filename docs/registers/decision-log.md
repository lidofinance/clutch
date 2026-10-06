---
type: Register
title: Decision log
description: EM's inputs and decisions for Clutch, quoted exactly and dated; the source of record for every claim that EM decided something.
tags: [decisions, provenance]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T13:05:14Z
verified: []
sources:
  - id: s1
    resource: "urn:clutch:interview:2026-09-22"
    title: EM's design interview on 2026-09-22; the transcript is not in the repository
  - id: s2
    resource: "urn:clutch:interview:2026-09-30"
    title: EM's repository-setup interview on 2026-09-30; the transcript is not in the repository
  - id: s3
    resource: "urn:clutch:interview:2026-10-02"
    title: EM's decision interview on 2026-10-02; the transcript is not in the repository
  - id: s4
    resource: "urn:clutch:interview:2026-10-05"
    title: EM's decision interview, continued on 2026-10-05; the transcript is not in the repository
  - id: s5
    resource: "urn:clutch:interview:2026-10-06"
    title: EM's decision interview, continued on 2026-10-06; the transcript is not in the repository
---

# Decision log

Entries quote EM exactly, including typos. An agent copied them from the interview transcripts. EM should confirm each entry by verifying this page. Newest first. Times are UTC.

Square brackets mark a redaction. Redactions keep the screening vendor's identity, the addresses that reveal it, and the unapproved mandate size out of the repository ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)).

Most answers are numbered. The numbers refer to the questions that the agent asked in the interview, and each "Recorded as" line names the question.

## 2026-10-06 — OD-38: the governance role refuses every module of the Asset Safe

> OD-38: B, push

Recorded as: OD-38 is closed with option B. The governance role refuses, as the administered target, the Asset Safe and every module that the Asset Safe enables, the safety modifier included. The deployment manifest lists those modules. The compiler refuses a policy that lets a role reach the Asset Safe or one of its modules beyond a fixed set of calls, a grant that does not refuse every one of them, and a manifest that misses a compiled modifier. A DAO vote that enables another module on the Asset Safe also lists it in the manifest and applies the policy compiled again ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 10, [ADR 005](/adr/005-account-graph-and-roles.md)). The agent found the gap on 2026-10-06 while it wrote the onboarding guide. A fork probe granted the operator `scopeTarget` and `allowFunction` on the safety modifier through the governance role. The operator then gave its own Safe a new role on the safety modifier and moved USDC out of the Asset Safe through it. A regression test replays the probe. "push" is EM's instruction to push the branch. [s5]

## 2026-10-06 — OD-37: the onboarding guide

> now we need to make a huge effort on education and onboarding
>
> let's build an interactive html page which contains:
> - all actors
> - all flows
> - highlights key assumptions
> - highlights how deployment happens, how it's operated, how it handles emergencies, how it handles reporting, etc.
> - everything must be visual and easy to onboard tech and non-tech folks
> - highlight what we use from the existing code, platforms (e.g. Zodiac) and what we introduce and why
>
> we need to maintain it within repo as a durable artifact
>
> do a deep research and run an interview with me before implementing

After the research, the agent asked eight questions. EM answered:

> Q1: A
> Q2: A
> Q3: A
> Q4: A
> Q5: A
> Q6: A
> Q7: A
> Q8: A

Recorded as: OD-37 is closed with option A on every question. (1) The page is for internal readers first: the committee's signers, the Emergency Brakes multisig, Lido engineers, and the product, legal and operations teams. It is written to the publication standard, so it can go public with the repository at deployment. (2) After the guide, a reader can name who can move the vault's funds and who can stop them, walk any emergency to its first action with its time, tell what is reused from audited code and what is new and why, and find the source of any claim. An optional self-check of about eight questions follows, and nothing is tracked. (3) One page, with a guided tour and an explorer on the same system map. (4) Twelve groups on the map with 47 drill-down actor cards, the research's count; a status on every element, Implemented, Specified or Open; existing mainnet addresses only, "to be deployed" for new contracts, and never a fork-test address; thresholds and time windows, but no financial figure, with dry-run stand-ins labelled as such; the screening vendor redacted; a panel of what is open and owed, and a roadmap tracker. (5) Flows play as steps that highlight the actors and arrows on the map. (6) The page is generated from data files that cite IDs, with the repository's facts read at build time. CI fails when the committed page differs from a fresh build or when a cited ID or path does not exist, and a pull request that changes a decision, a role or a flow updates the page. Option A included the CI check, so this answer is EM's request for the new steps under `.github/`. (7) A Python build run with uv, plain JavaScript and inline SVG, under `docs/onboarding/`, with a new page type, Guide, in the validator. Readers open the file locally until deployment. EM did not say whether the organisation has private GitHub Pages, so the page stays a local file. (8) `@lidofinance/defi-tech` owns the guide and agents regenerate it. EM accepts the first version. The committee and the Emergency Brakes multisig review the sections that describe their duties ([onboarding guide](/onboarding/guide.md), [specification policy](/specs/specification-policy.md)). [s5]

## 2026-10-06 — OD-36: no delegatecall through governance, and the policy CI job

> - OD-36: A
> - add a new job for CI (decision 14)
> - push then

Recorded as: OD-36 is closed with option A. The governance role's `allowFunction` and `scopeFunction` permissions take only the execution options None or Send, so a motion cannot grant the operator delegatecall; a regression test refuses such a grant, and delegatecall for the operator needs a DAO vote ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 9). ADR 005's roles table adds the limit before the Emergency Brakes multisig verifies it. The second line is EM's explicit request for a new CI job under `.github/`: it fails when the committed policy artifact differs from a fresh compile ([ADR 004](/adr/004-specifications-and-policy-as-data.md) decision 14). [s5]

## 2026-10-06 — ADR 001 and ADR 004 verified again

> - record my re-verification of ADR 001 and ADR 004
> - push

Recorded as: EM verifies ADR 001 and ADR 004 again after the OD-33, OD-34 and OD-35 amendments, so both stay accepted. At this instruction, the agent recorded EM's two `verified` entries under the OD-31 rule: each names the agent in `recorded_by` and links this heading in `ref`. The verification is EM's. [s5]

## 2026-10-06 — OD-34 and OD-35: the constellation's licence and the Zodiac workspace

> OD-34: A
> OD-35: A

Recorded as: both as the agent recommended. (OD-34) Files derived from the policy provider's constellation keep LGPL-3.0-only and get `SPDX-License-Identifier: LGPL-3.0-only` when they change. New files use AGPL-3.0-or-later. The licence check of [ADR 001](/adr/001-repository-scope-visibility-licence-name.md) covers `policy/`. Option A included the change to `AGENTS.md`, so the agent made it at this request. (OD-35) The repository-owner team, `@lidofinance/defi-tech`, owns the Lido Zodiac workspace and its API key. A member of that team pushes from the merged `main`, with the key in a local `.env` that git ignores. The committee and the Emergency Brakes multisig can view the workspace, and CI holds no key ([ADR 004](/adr/004-specifications-and-policy-as-data.md)). Both ADRs changed, so EM verifies ADR 001 and ADR 004 again. [s5]

## 2026-10-06 — OD-33: the constellation as the policy source

> Q1: We want to work under Zodiac UI, so it's closer to B I believe, though it always a good idea to have local tooling to replicate/verify everything
> Q2: A
> Q3: A
> Q4: B
> Q5: A

Recorded as: OD-33 is closed. (Q1) The team works in the Zodiac UI, and local tooling replicates and verifies everything that the UI produces. The agent reads this as two rules: no transaction that the hosted app builds is signed, or enters a vote or a motion, unless Clutch's compiler produces the same calls from the same commit; and the policy changes only in the repository. (Q2) The constellation in TypeScript replaces the YAML file, and Clutch's own TypeScript compiler on the roles SDK replaces the Python compiler. It runs offline from a frozen lockfile and refuses entries that only the hosted app can compile. (Q3) The artifact is committed, CI fails when it differs from a fresh compile, reviewers approve it, and the enabling vote, the Easy Track templates and the drift detector consume it. (Q4) The Solidity builders go now: the port deletes them and rebuilds the fork tests on the artifact, with no equality gate. (Q5) [ADR 004](/adr/004-specifications-and-policy-as-data.md) is amended in place, and EM verifies it again. OD-35 asks who owns the Zodiac workspace and its API key. [s5]

## 2026-10-06 — OD-33 asked

> run an interview on OD-33

Recorded as: the agent asked five questions: what "backbone" means, what replaces decisions 8 and 9 of ADR 004, what reviewers approve and the vote consumes, when the Solidity builders go, and how to record the change. [s5]

## 2026-10-06 — the Zodiac constellation as the backbone asked

> now let's get back to https://github.com/gnosisguild/lido-atm-constellation and analyze whether the same config still works or it needs to be materially improved; if so, do a local copy of the cfg and store it within the repo; basically we want to use zodiac constellation as the project backbone; highlight whether we can do it or not and what's missing

Recorded as: the agent copied the configuration to `policy/constellation/` and wrote the [constellation note](/research/zodiac-constellation-2026-10-06.md). The constellation as the source of the policy would replace decisions 8 and 9 of ADR 004, which EM accepted, so it is OD-33. The copied files are LGPL-3.0-only, which ADR 001 does not allow, so they are OD-34. No decision is recorded yet. [s5]

## 2026-10-06 — OD-32: the fortnightly cap reading

> 1, push

Recorded as: OD-32 is closed with option 1. Monitoring runs the report generator at the pinned block of each fortnightly snapshot and publishes the cap ratios to IPFS. A breach in that reading is the published cap breach of the OD-29 trigger, and the alert that pages the Emergency Brakes multisig links the reading. The committee in breach does not publish its own breach ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s5]

## 2026-10-06 — OD-32 asked

> do a and b

Recorded as: the agent froze the text of ADR 005 to ADR 011 for the verification by the Emergency Brakes multisig, and wrote the multisig's brief. The read found that the OD-29 trigger needs a published cap breach at a fortnightly snapshot, but only monthly reports are published. [s5]

## 2026-10-06 — ADR 002 and ADR 003 verified again

> record my re-verification of ADR 002 and ADR 003; check tests, commit and push

Recorded as: EM verifies ADR 002 and ADR 003 again after the OD-31 edit, so both stay accepted. At this instruction, the agent recorded EM's two `verified` entries under the OD-31 rule: each names the agent in `recorded_by` and links this heading in `ref`. The verification is EM's. [s5]

## 2026-10-06 — OD-31: recording a human's own verification

> C, edit AGENTS.md

Recorded as: OD-31 is closed with option C. `AGENTS.md`, [ADR 002](/adr/002-decision-and-review-process.md) and [ADR 003](/adr/003-agent-operating-model.md) gain one exception: on a human's explicit written instruction, an agent may record that human's own acceptance and verification. The entry names the agent in `recorded_by` and links, in `ref`, the decision-log heading that quotes the instruction. The commit message says that the agent made the edit. The validator checks both fields and refuses them on a body's actor, and the status register marks such an entry `(recorded)`. The four entries of 2026-10-05 in ADR 001 to ADR 004 gain `recorded_by` and `ref`. EM's answer is also the explicit request that ADR 003 decision 7 needs before an agent edits `AGENTS.md`. [s5]

## 2026-10-06 — OD-31 asked

> tell me more about 'Clutch's AGENTS.md has no exception yet for human: entries written at your explicit instruction. That file is yours to edit.', what should I do exactly, give some examples?

Recorded as: the agent set out three options. A keeps the rule, and EM types each acceptance. B writes down a narrow exception. C adds to B a `recorded_by` field that the validator checks. [s5]

## 2026-10-05 — ADR 001 to ADR 004 accepted

> I merged, commit and push human entries for ADR 001-004

Recorded as: EM accepts ADR 001 to ADR 004, as OD-25 planned. At EM's instruction, the agent wrote EM's acceptance fields and EM's `verified` entries in the four records. The acceptance and the verification are EM's; the agent only made the edit. `AGENTS.md` forbids an agent to write a `human:` entry, so this edit is the exception that EM asked for. [s4]

## 2026-10-05 — OD-25 to OD-30: acceptance round 1 and the emergency exit

> Q1: 1
> Q2: B
> Q3: A
> Q4: A
> Q5: A
> Q6: A

Recorded as: all six as the agent recommended. (Q1, OD-25) The agent adds `scripts` to the licence check of [ADR 001](/adr/001-repository-scope-visibility-licence-name.md). After that change merges, EM accepts ADR 001 to ADR 004 in one edit. Decision 6 of [ADR 003](/adr/003-agent-operating-model.md) covers production parameters; the kit's dry-run budgets and fixed ceilings are test values. (Q2, OD-26) Recovery also sells USDC, USDS and DAI into USDT, because USDS and DAI carry USDC risk. Recovery then has ten instances, and the mandate text owes a change: the emergency swap goes into USDC, or into USDT as the second destination ([ADR 007](/adr/007-swapping-through-stonks.md)). (Q3, OD-27) The stETH approval to Lido's withdrawal queue has a fixed ceiling of one TM Floor Value in stETH and no budget key ([ADR 007](/adr/007-swapping-through-stonks.md)). (Q4, OD-28) The no-redeem rule for the first-loss Earn shares binds the emergency role too. In an emergency, it sends them to the Aragon Agent, and a burn or a redemption of them is a DAO vote ([ADR 008](/adr/008-funding-through-existing-payments.md)). (Q5, OD-29) "A pause of the whole module" means disabling the operator modifier. The Emergency Brakes multisig does it through the technical role on a fixed trigger: a published cap breach that is still there after the committee's rebalancing window of two working days, and that is larger at the next fortnightly snapshot. A DAO vote can also do it ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). (Q6, OD-30) The emergency Safe stays a subset of the committee's signers. The mandate draft promises an exit that is independent of the committee, so the mandate text owes a change, and the LIP states that the fast exit is not independent of the committee ([ADR 005](/adr/005-account-graph-and-roles.md)). The evidence for Q2 and Q3 is in the [recovery note](/research/recovery-and-withdrawal-queue-2026-10-05.md). [s4]

## 2026-10-05 — the open items asked

> run an interview on the open things

Recorded as: the agent asked the five questions of the acceptance round again, with its positions, and added a sixth question on the mandate's emergency exit. [s4]

## 2026-10-05 — acceptance round 1 asked

> run an interview cycle for clutch

Recorded as: the agent read every ADR and asked five questions before acceptance. [s4]

## 2026-10-05 — OD-22: DAI

> Q1. 1

Recorded as: OD-22 is closed. DAI earns through Sky's DAI–USDS converter. The operator may convert DAI to USDS and back, one to one, with the receiver pinned to the Asset Safe. The DAI and USDS approvals to the converter carry a fixed ceiling of one TM Floor Value, as the stETH approval to the wstETH contract does. DAI stays out of the Stonks rebalancing set, and recovery keeps its DAI→USDC instance. The evidence is in the [DAI note](/research/dai-usds-conversion-2026-10-05.md) ([ADR 011](/adr/011-launch-scope.md)). [s4]

## 2026-10-05 — OD-22 asked

> continue interview with the next pending decision

[s4]

## 2026-10-05 — OD-21: the legacy investments

> Q1: B
> Q2: 1

Recorded as: OD-21 is closed. (Q1) The legacy Earn positions are the DAO's first-loss shares in EarnETH and EarnUSD, approved by Snapshot in March 2026 and held by a Growth Committee Safe. After the enabling vote, the Growth Committee transfers them to the Asset Safe. The Treasury Management mandate takes over the first-loss terms of that allocation. Each first-loss burn is a DAO vote. A written rule forbids the operator from redeeming the first-loss shares. The agent had recommended that the shares stay with the Growth Committee and only count toward the vault (A). (Q2) A Twyne position reduces the seed only when its holder and form are shown on chain or in a signed record; no Lido address checked holds one. The evidence is in the [legacy investments note](/research/legacy-investments-2026-10-05.md) ([ADR 008](/adr/008-funding-through-existing-payments.md)). [s4]

## 2026-10-05 — OD-21 asked

> continue interview with the next pending decision

[s4]

## 2026-10-05 — OD-20: swap pricing

> Q1: 1.
> Q2: A, but support WETH too
> Q3: 1.

The router cannot price WETH, so the agent asked how to support it (Q2b):

> Q2b: 1.

Recorded as: OD-20 is closed. (Q1) The committee's Safe, as the manager of the shared Stonks 2.0 oracle router, adds USDC, USDT, DAI and USDS once the instance list is final. Each is quoted in USD, with a maximum price age equal to Chainlink's heartbeat for its feed. Lido deploys one USD-anchored converter for the vault through the deployed converter factory. The enabling vote starts only if every vault token is configured on the router and in sync. (Q2) The swap instances cover only the tokens that the router can price: stETH, LDO, USDC, USDT, USDS and DAI. wstETH is unwrapped and sUSDS is redeemed before a sale. EM added WETH. (Q2b) WETH goes through stETH: to sell it, the vault unwraps it, stakes the ETH through Lido's `submit` and sells the stETH; to buy it, the vault unstakes stETH through Lido's withdrawal queue and wraps the ETH. The operator and the emergency role may stake ETH, the operator may request and claim withdrawals pinned to the Asset Safe, and the emergency role may unwrap WETH. (Q3) The committee's Safe re-syncs a feed after Chainlink replaces it. Monitoring alerts when a vault token's feed is out of sync, and a runbook covers the re-sync. If a feed is broken during an emergency, the emergency Safe sends assets to the Aragon Agent instead of swapping. The evidence is in the [pricing note](/research/stonks-pricing-2026-10-05.md) ([ADR 007](/adr/007-swapping-through-stonks.md)). [s4]

## 2026-10-05 — OD-20 asked

> continue interview for the next pending decision, why it's not OD-18 or OD-19 btw, but OD-20?

[s4]

## 2026-10-05 — OD-17: Safe v1.5.0 after the due diligence

> Q1: 1. Keep v1.5.0; [the screening vendor] confirmed they support this version, consider it resolved.
> Q2: A
> Q3: 1.

Recorded as: OD-17 is closed. (Q1) The Asset Safe and the operator Safe keep Safe v1.5.0. EM reported that the screening vendor confirmed its support for v1.5.0 and closed that gate, so the operator Safe's v1.4.1 fallback no longer applies. The confirmation itself is outside this repository. (Q2) EM accepted the five conditions of Block A: (a) the Aragon Agent authorizes Asset Safe transactions only by `approveHash` or by sending them itself, never by a contract signature; (b) the Asset Safe has no fallback handler, and a protocol that needs one comes back to EM; (c) before the enabling vote, Safe's releases, the advisory databases and Safe's bug-bounty records are checked again, and a change that touches transaction execution, `approveHash`, module execution, the guard or owner management comes back to EM; (d) the LIP states the short record of v1.5.0 and has a failure-mode row for a defect in Safe or Roles code; (e) the vendor is asked to refuse every delegatecall from the operator Safe except to Safe's MultiSendCallOnly v1.5.0, as a request and not a gate, and monitoring alerts on any change of the singleton of the three new Safes. (Q3) The emergency Safe also uses Safe v1.5.0. The evidence is in the [due-diligence note](/research/safe-v150-due-diligence-2026-10-05.md) ([ADR 005](/adr/005-account-graph-and-roles.md), [ADR 010](/adr/010-pre-execution-screening.md)). [s4]

## 2026-10-05 — OD-17 asked

> do a deep research and run an interview on OD-17 if needed

[s4]

## 2026-10-05 — OD-16: the policy data format and the compiler

> Q1: YAML with a strict schema.
> Q2: Python, emitting one JSON artifact

Recorded as: OD-16 is closed. The policy data file is YAML with a strict schema: quoted addresses and amounts, no anchors or aliases, and a JSON Schema checked in CI. A Python compiler run with uv emits one JSON artifact with the ordered modifier calls, the expected condition trees and the allowances. The Foundry tests, the enabling vote script and the policy-drift detector consume it, and the round-trip check rebuilds the trees from the modifier's events on a fork ([ADR 004](/adr/004-specifications-and-policy-as-data.md)). [s4]

## 2026-10-05 — OD-16 asked

> run an interview on OD-16

[s4]

## 2026-10-05 — OD-15: how a body records a verification

> Q1: A

Recorded as: OD-15 is closed with Block A. A member of the committee or of the Emergency Brakes multisig commits that body's verification through a reviewed pull request. The entry carries `ref`, a link to the body's decision record, such as a forum post or minutes, and the validator refuses a body verification without it. The agent had recommended a quorum signature by each body's Safe; EM chose the member's entry ([ADR 002](/adr/002-decision-and-review-process.md)). [s4]

## 2026-10-05 — OD-15 asked

> run an interview on OD-15

[s4]

## 2026-10-05 — OD-14: the mandate text

> accept your mandate recommendation; push

Recorded as: the mandate text states the price rule and the late-report rule of OD-14. The mandate text now owes five changes ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s4]

## 2026-10-05 — OD-14: reporting operations and the anchor

> Q1:  1.
> Q2:  1. 
> Q3:  1.
> Q4:  B

Recorded as: OD-14 is closed. (Q1) The mandate's publisher and schedule stand. The defi-tech team builds and maintains a report generator in this repository, which reads the chain at a pinned block and the pricing source, so anyone can re-run it. The committee reviews and publishes each report. (Q2) Coingecko's closing price at the Snapshot Date is used. A price that is missing or more than 24 hours old is replaced by the asset's on-chain rate into an underlying that has a price. An asset with neither is listed as unpriced, left out of every ratio and the vault value, and named in the report. An old price is never carried over silently, and no top-up rests on a snapshot with an unpriced asset. (Q3) While the monthly report is late, no top-up motion starts. Monitoring flags a missing report on day 8, and the committee explains the delay on the forum. (Q4) Block B: a report's IPFS identifier is anchored only in its forum post. There is no on-chain anchor ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s4]

## 2026-10-05 — OD-14 asked

> run interview on OD-14

[s4]

## 2026-10-05 — OD-13: who writes and maintains the detectors

> Q1: it's like A-ish: defi-tech writes specs and make important updates though vroom team is responsible for the review, platform and maintenance of the engine and bot
> Q2: 1

Recorded as: OD-13 is closed. (Q1) The `@lidofinance/defi-tech` team writes the specification of the vault's detectors in the Lido on-chain monitoring and makes the important updates to them. The vroom team, read as `@lidofinance/lido-valset-vroom`, the code owner of the monitoring repository, reviews them, runs the platform, and maintains the engine and the bot. (Q2) The committee configures the vault's rules in the screening vendor's service, and the defi-tech team supports it ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s4]

## 2026-10-05 — OD-13 asked

> run an interview on OD-13

[s4]

## 2026-10-05 — OD-12: four recorded readings

> 1. confirm
> 2. confirm
> 3. confirm
> 4. let's do as you suggested: we know the name, no need to make it even more explicit

Recorded as: OD-12 is closed. (1) The vision reading is confirmed: EM accepted the positioned vision ([product brief](/product/brief.md)). (2) The acceptor reading is confirmed: the answer changed only the acceptor, and points 3 to 9 of [ADR 002](/adr/002-decision-and-review-process.md) are accepted as positioned. (3) Lido Lend's three capped months count from Lido Lend's mainnet launch ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). (4) The Lido-side party to the vendor agreement is the party that already holds the vendor's arrangement for the four guarded Lido multisigs. The repository does not name it ([ADR 010](/adr/010-pre-execution-screening.md)). [s4]

## 2026-10-05 — OD-12 asked

> run an interview on OD-12

[s4]

## 2026-10-05 — OD-24: the USDS ceiling

> 1. OD-24: 2,000,000

Recorded as: OD-24 is closed. The rewritten payment permission allows at most 2,000,000 USDS per payment, the same as DAI, USDC, USDT and sUSDS ([ADR 008](/adr/008-funding-through-existing-payments.md)). [s4]

## 2026-10-05 — OD-11: the payment permission, the token list and ETH

> Q1. 2
> Q2. 2 (add USDS and sUSDS)
> Q3. 1

Recorded as: OD-11 is closed. (Q1) A DAO vote rewrites the shared payment permission of the Easy Track executor to add USDS. The other entries stay as they are. The ceiling per USDS payment is still to be set (OD-24). (Q2) The stablecoin registry uses the shared stablecoin token list, with USDS added. The list then allows DAI, USDT, USDC, sUSDS and USDS. (Q3) ETH is not a funding asset; stETH covers the mandate's "(st)ETH". The agent had recommended keeping the permission unchanged and a token list for the vault alone. Two consequences are recorded in [ADR 008](/adr/008-funding-through-existing-payments.md): every stablecoin setup that shares the list can then pay USDS too; and funding in sUSDS goes beyond the mandate's funding rule, which names stETH and the top-four stablecoins, so the mandate text owes a change. [s4]

## 2026-10-05 — OD-11 asked

> run an interview on OD-11

[s4]

## 2026-10-05 — OD-10: code owners and the branch rule

> Q1:
> We must use:
> - https://github.com/orgs/lidofinance/teams/defi-tech as owning group
> - review-gh-workflows owns GitHub CI
> - no new team is needed
>
> Q2:
> - agree on branch rule
> - agree on at least a single approval by non-creator of PR
> - later

Recorded as: OD-10 is closed. The `@lidofinance/defi-tech` team owns the repository, and `@lidofinance/review-gh-workflows` owns `/.github/`. No new team is created. A branch rule on `main` requires a pull request and a code-owner review, allows no direct pushes, and dismisses approvals when new commits arrive. Every merge needs at least one approval from someone other than the pull request's creator. The agent's own GitHub identity comes later; OD-23 tracks it ([ADR 003](/adr/003-agent-operating-model.md)). [s4]

## 2026-10-05 — OD-10 asked

> run interview on OD-10

[s4]

## 2026-10-05 — OD-09 Q2: DAO-scoped role keys

> Q2: 3

Recorded as: OD-09 is closed. The design uses no DAO-scoped role keys. The role-toggle factory and the governance role's `assignRoles` permission leave the design. Every operator permission lives under the `operator` role key, so the emergency role's revoke reaches all of it, and no new emergency permission is needed. The agent recommended this option as the one that fits the answer to Q1 ([ADR 006](/adr/006-governance-through-easy-track-factories.md)). [s4]

## 2026-10-05 — OD-09 Q1: the removal path

> 1. Q1: B
>
> What makes the most of sense for Q2 given this Q1 answer?

Recorded as: Block B. The two removal templates are dropped. Every removal is the emergency Safe's immediate revoke, posted on the forum afterwards. Easy Track cannot give any motion a window below 48 hours, so no factory could meet the request of 2026-09-22. EM then asked which Q2 option fits this answer. [s4]

## 2026-10-02 — OD-09 asked

> run OD-09 interview

[s3]

## 2026-10-02 — OD-08: approvals and the refill-period floor

> Q1. 1. B
> Q2. 1. 30 days

Recorded as: OD-08 is closed. (Q1) Block B: an operator approval to a protocol spender spends the budget of the key that the spender serves. An approval of zero is always allowed and spends nothing. Deposit calls no longer spend budget. The stETH approval to the wstETH contract has no budget key and keeps a fixed ceiling of one TM Floor Value in stETH, the figure of OD-06. No new figure and no new contract. EM chose this over a fixed ceiling sized to the budget, and over a smaller fixed ceiling of one deposit, which the agent had recommended before it found that a spender can pull an approval without any deposit call. (Q2) A budget motion cannot set a refill period below 30 days ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s3]

## 2026-10-02 — OD-08 asked

> run interview on OD-08

[s3]

## 2026-10-02 — OD-07: the screening vendor's guard

> Q1. 1.
> Q2. A
> Q3. 1.
> Q4. 1, [the screening vendor]

Recorded as: OD-07 is closed. (Q1) The DAO vote grants the operator role and registers the factories only after the guard is set on the operator Safe with its bypass mode off. This is checked when the vote starts and watched until it executes. The agreement forbids standing approvals on this guard, of the nonce-free and the function-call kinds. The guard's two built-in timelock approvals stay. (Q2) Block A: the guard instance uses the build that the four Lido instances run, with 10-day timelocks. Lido reviews the one change made after the guard's audit. The vendor is asked to merge it into its main branch, correct its documentation and add it to its audit report. (Q3) The vendor's written confirmation that its approval service supports Safe v1.5.0 is a gate before deployment. Without it, the operator Safe uses Safe v1.4.1. Lido's monitoring for this guard adds v1.5.0 and the new instance. A dollar limit per top-up motion is a request to the vendor, not a gate. (Q4) The redaction of the vendor's identity ends when the mandate is posted on the forum, after the vendor agrees in writing to be named for this use. Commercial terms never enter the repository. Asked who signs the agreement, EM named the vendor. The agent reads this as the counterparty; the Lido-side party is still to be named, and OD-12 asks EM to confirm ([ADR 010](/adr/010-pre-execution-screening.md), [ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). [s3]

## 2026-10-02 — OD-07 asked

> run interview on OD-07

[s3]

## 2026-10-02 — OD-06 Q2: the limit

> A

Recorded as: OD-06 is closed with Block A of the Q2 challenge game. Two registries carry the funding, one for stablecoins and one for stETH, each with a limit of one TM Floor Value per month. Stablecoins count at par. The stETH limit is the floor at the Coingecko price pinned when the enabling vote is prepared, set by attested computation. The objection is the control, and the registry is the backstop. The LIP states both gaps: the registry can delay a permitted stETH refill after an ETH fall, and it allows more than one floor a month. Monitoring flags out-of-cycle top-ups, a month's top-ups above the posted shortfall, and a top-up after an objected one. The screening policy carries a dollar rule per motion if the vendor supports it. The DAO re-pins the stETH limit by vote when needed. EM chose this over Block B, one dollar limit on chain through a new token registry ([ADR 008](/adr/008-funding-through-existing-payments.md)). [s3]

## 2026-10-02 — OD-06 Q1: the period

> 1. One month
>
> For Q2 run a challenge game, use srawman vs steelman, read mandate accurately, suggest what's recommended

Recorded as: the registry period is one calendar month ([ADR 008](/adr/008-funding-through-existing-payments.md)). EM asked for a challenge game on Q2 before answering it. [s3]

## 2026-10-02 — OD-06 asked

> continue with OD-06 interview

[s3]

## 2026-10-02 — OD-05 Q3: where recovered rebalancing tokens go

> 1.

Recorded as: option 1 of the Q3 walkthrough. Instances come from the standard factory, whose recovery address is the treasury. Tokens recovered from a rebalancing instance therefore go to the treasury, not back to the vault. The agent had recommended deploying rebalancing instances outside the factory, so that they recover to the Asset Safe; EM chose the factory ([ADR 007](/adr/007-swapping-through-stonks.md)). [s3]

## 2026-10-02 — OD-05 Q1 and Q2: instance managers and parameters

> - Q1: 1
> - Q2: 1
>
> walk me through Q3 more with examples and considerations, compare with how it worked before for stonks, etc.

Recorded as: (Q1) the committee Safes manage the instances. The operator Safe manages the rebalancing instances, and the emergency Safe manages the recovery instances. This replaces the 2026-09-22 choice of the Aragon Agent as manager. (Q2) The parameters copy the live values by pair class, for both families. EM asked for a deeper walkthrough of Q3 before answering it. [s3]

## 2026-10-02 — OD-05 asked

> interview me about OD-05

[s3]

## 2026-10-02 — OD-04: Lido Lend and the protocol cap

> 3. Capped first three months as 25% protocol cap, uncapped then as Lido product

Recorded as: OD-04 is closed. Lido Lend counts against the protocol cap for its first three months. After that it is a Lido own product with no cap per product ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), [ADR 011](/adr/011-launch-scope.md)). The agent reads "first three months" as three calendar months from Lido Lend's mainnet launch, not from the vault's first deposit. Open item OD-12 asks EM to confirm this reading. [s3]

## 2026-10-02 — OD-03: the base of the yield-bearing cap

> 1. Literal (Block A)

Recorded as: OD-03 is closed with the literal reading. The yield-bearing cap is measured against the top-4 stablecoins plus the yield-bearing stablecoins that the vault holds directly. Own-product and protocol positions are outside the base. The option also carried two actions: the mandate's illustrative balance renames its "USD-denominated" heading, so that it does not read as the cap's base; and the budget is computed again on the literal base ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s3]

## 2026-10-02 — OD-02 and OD-19: the two new Safes

> OD-02: 3. let it be v1.5.0 both BUT only if [the screening vendor] guard is compat with v1.5.0, check it deeply
> OD-19: 1. 4 of 7

Recorded as: OD-02 is closed with a condition. Both new Safes, the Asset Safe and the operator Safe, use Safe v1.5.0 if the screening vendor's guard is compatible with v1.5.0. The agent's check on 2026-10-02 found it compatible, so the condition holds ([research note](/research/safe-v150-guard-compatibility-2026-10-02.md)). OD-19 is closed: the operator Safe's threshold is 4 of 7. [s3]

## 2026-10-02 — OD-01: the screening route

> I pick 'Option 1: dedicated operator Safe with its own guard, also the trusted caller.'

Recorded as: OD-01 is closed. The screening hook is a transaction guard on a dedicated operator Safe. The operator Safe carries the committee's signers, holds the operator role, and is the trusted caller of every factory. The guard is the screening vendor's existing transaction guard ([ADR 010](/adr/010-pre-execution-screening.md), [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 006](/adr/006-governance-through-easy-track-factories.md)). The operator Safe's threshold and Safe version are still open (OD-19, OD-02). [s3]

## 2026-10-02 — the vendor's existing guard

> if we need [the screening vendor] here and existing blocks they have, e.g. attached one to [the address of an existing guard on a Lido multisig], what option would win?

Recorded as: an input to OD-01. The screening vendor's existing guard must be usable as is. [s3]

## 2026-10-02 — criteria for OD-01

> what option has the least code, what option has the least deployed surface, what option has the least audit surface, what option has the lowest overhead and drift sensitivity?

Recorded as: the criteria EM applied to OD-01: least code, least deployed surface, least audit surface, and lowest overhead and drift sensitivity. [s3]

## 2026-10-02 — the request

> interview me about decisions, start with OD-01

[s3]

## 2026-09-30 — specifications and the permission policy

> 1. Accept as positioned: data file, compiler, round-trip check.
>
> I created https://github.com/lidofinance/clutch

Recorded as: the permission policy is a data file that a script compiles into modifier calls. A round-trip check reads the applied conditions back from the chain. The rest of the positioned specification model is accepted ([ADR 004](/adr/004-specifications-and-policy-as-data.md)). EM created the remote repository. [s2]

## 2026-09-30 — Emergency Brakes verification and the AGENTS.md cap

> 1. Emergency Brakes co-verifies ADRs that constrain TMC
> 2. Accept, with the 60-line cap enforced by the validator.

Recorded as: an ADR that constrains the Treasury Management Committee needs a verification from the Emergency Brakes multisig before it is accepted ([ADR 002](/adr/002-decision-and-review-process.md)). The agent operating model is accepted as positioned, and the validator caps `AGENTS.md` at 60 lines ([ADR 003](/adr/003-agent-operating-model.md)). [s2]

## 2026-09-30 — name and acceptor

> 1. the name will be 'Clutch'
> 2. we will have me EM as interim approver and TMC as the real one

Recorded as: the name is Clutch ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). EM accepts decisions in the interim. The Treasury Management Committee is the permanent acceptor ([ADR 002](/adr/002-decision-and-review-process.md)). The answer changed only the acceptor, so the rest of the positioned review process is read as accepted. Open item OD-12 asks EM to confirm this reading. [s2]

## 2026-09-30 — scope, kit migration, visibility and licence

> 1. Accept all four as positioned.

Recorded as: one repository holds the whole system. The dry-run kit enters with its history. The repository is private now and public no later than deployment. The licence is AGPL-3.0-or-later, and files derived from Easy Track keep GPL-3.0 ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). [s2]

## 2026-09-30 — readers

> Option 2 works.

Recorded as: the readers are ranked by the cost of a misreading: signers, then auditors and reviewers, then DAO voters and delegates, then coding agents. The brief also names the system's users: the DAO and the Treasury Management Committee ([product brief](/product/brief.md)). [s2]

## 2026-09-30 — North Star Metric

> option 2 works

Recorded as: the North Star Metric is the time for a reviewer who did not write a permission change to verify it end to end, measured as a timed verification procedure. Traceability, one-command verification and the six-hour time to initiate are hard gates at 100 percent ([product brief](/product/brief.md)). [s2]

## 2026-09-30 — goals

> option 2 works the best

Recorded as: the goals are Audit-ready, Governance-ready, Agent-operable and human-certified, and a fourth goal, Operable ([product brief](/product/brief.md)). [s2]

## 2026-09-30 — vision

> I chose A, your position is sound

Recorded as: the positioned vision is accepted ([product brief](/product/brief.md)). The answer is read as the first offered answer, "accept the position". It is not read as the option labelled "Contrast A", because the two are opposites and the answer calls the position sound. Open item OD-12 asks EM to confirm this reading. [s2]

## 2026-09-30 — the request

> let's start an ai-first repo for this development
>
> I want to have:
> - README
> - LICENSE
> - ROADMAP
> - ADRs
> - Specs
>
> Learn from https://github.com/lidofinance/lido-lend-markets and probably Open Knowledge Format (v0.2 or newer)
> Investigate how AI-first repos done in 2026 September, find success stories and strong signals
>
> Interview me what should be decided to set this repo properly up

[s2]

## 2026-09-22 13:39 — guard, budgets and the Safe version

> 1. Run the attested computation
> 2. They must write it even they don't have it yet; we can add it later. Investigate whether it's already built. 
> 3. Confirm
> 4. Acceptable
> 5. Acceptable, but do a dd about audits and incident history
> 6. Fine both, prefer less complexity
> 7. Accept and document

Recorded as, by question: (1) budget figures: run the attested computation now; (2) the guard contract: the screening vendor writes it; (3) guard failure: fail closed on the operator; (4) the screening vendor may flag a transaction alone; (5) the first Safe v1.5.0 in the Lido estate is acceptable, after diligence on its audits and incident history; (6) either modifier may carry the governance role, and less complexity is preferred; (7) replacing the operator modifier is a documented DAO procedure. See [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) and [ADR 010](/adr/010-pre-execution-screening.md). The reading of "we can add it later" is open item OD-07. [s1]

## 2026-09-22 12:56 — on-chain blocking

> 1. On-chain blocking is a hard requirement. Update Safe and other stuff down to scripts, docs and tests
> 2. Yes

Recorded as: (1) blocking a suspicious transaction on chain, before it executes, is a hard requirement ([ADR 010](/adr/010-pre-execution-screening.md)); (2) the policy splits across two modifiers ([ADR 005](/adr/005-account-graph-and-roles.md)). [s1]

## 2026-09-22 12:49 — budgets, recovery destination and monitoring

> 1. 
>
> It's fine to sit in Lido only
> Retune cadence fortnighly is okayish
>
> 2. Second recovery destination is mandatory, USDT is good enough
>
> 3. Assume [the screening vendor] integration added that can block execution of sus transactions
> Operator committee own ratio-breach remediation; if it gets worse, there can be a pause of the whole module
> detectors both in Lido on-chain monitoring and in [the screening vendor]

Recorded as, by question: (1) budget sizing: the whole vault may sit in Lido products, and budgets retune every two weeks ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (2) swap topology: recovery has a mandatory second destination, USDT ([ADR 007](/adr/007-swapping-through-stonks.md)); (3) monitoring: screening can block suspicious transactions ([ADR 010](/adr/010-pre-execution-screening.md)), the committee owns ratio-breach remediation, a pause of the whole module is the escalation, and detectors run in both monitoring estates ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s1]

## 2026-09-22 12:32 — eight open items

> 1. Derive from mandate
> 2. Launch without it but with Morpho Blue template, having e2e tests for it
> 3. Add DAI
> 4 and 9. We need stablecoin to stablecoin recovery too, yeah; add missing recovery pairs. Don't reuse existing instances; Rebalancing needed is stETH, wstETH, USDC, USDT, USDS, LDO
> 5. IPFS, Don't use databus at least yet
> 6. set is fine, removal templates should skip objection window
> 7. It's solved via general incident response process built in Lido
> 10. Agent it must be

Recorded as, by question: (1) budgets and approval ceilings derive from the mandate ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (2) Lido Lend is not in the launch, and the Morpho Blue template ships with end-to-end tests ([ADR 011](/adr/011-launch-scope.md)); (3) DAI joins the launch set ([ADR 011](/adr/011-launch-scope.md)); (4 and 9) the swap instance matrix: stablecoin-to-stablecoin recovery, the missing recovery pairs, no reuse of existing instances, and the rebalancing set ([ADR 007](/adr/007-swapping-through-stonks.md)); (5) reports go to IPFS, not DataBus ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (6) the template catalogue is accepted, and removal should skip the objection window, which Easy Track cannot do per factory (open item OD-09); (7) paging runs through the general Lido incident process ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (10) the Aragon Agent manages every swap instance ([ADR 007](/adr/007-swapping-through-stonks.md)). [s1]

## 2026-09-22 12:16 — technical role

> assign disableModule to technical emergency brakes, I do agree now

Recorded as: the Emergency Brakes multisig holds a technical role that can disable the operator's permission module and nothing else ([ADR 005](/adr/005-account-graph-and-roles.md)). [s1]

## 2026-09-22 12:11 — swap engine, Lido Lend and the emergency model

> 1) I want swap engine for ATM by-default to be stonks 2.0
> 2) Lido Lend will appear in October, we can add it a bit later, but need to be zero-day ready so that can be done via an ET motion
> 3) I am thinking about emergency in the following way:
>    - emergency has financial risks and there are most of them: depegs, dependency failure, curator misbehavior, etc. so that we want to have TMC with lower quorum to swap/exit/claim
>    - technical risks requiring pause of the whole module might have connected with Emergency Brakes, but it's overkill given ET is pausable itself and it's fine; the risks are monitored by the tech team including immunefi submissions, and Emergency Brakes indeed have tech folks inside

Recorded as: (1) Stonks 2.0 is the default swap engine ([ADR 007](/adr/007-swapping-through-stonks.md)); (2) Lido Lend is onboarded by an Easy Track motion and must be ready on the day it deploys ([ADR 011](/adr/011-launch-scope.md)); (3) financial emergencies go to the committee's signers at a lower quorum, and the engineering organisation watches technical risk ([ADR 005](/adr/005-account-graph-and-roles.md)). [s1]

## 2026-09-22 11:39 — seven open questions

> 1. It's a manual duty in the runbook, the same we do with HashConsensus or some of the DG committees
> 2. Operator (TMC) is the trusted caller
> 3. Minimum is forum disclosure for every motion, alerting setup, and runbook discipline; ultimate stop is objection or whole ET pause by emergency brakes
> 4. Accept detective enforcement with reporting, must rely on data published to immutable database, preferably IPFS or even on-chain through DataBus though not sure about the latter yet — would it fit or not
> 5. Emergency swap must work via cowswop, can think about using stonks 2.0 for that because it has decent oracle protection built-in
> 6. ETH, WETH, stETH, wstETH, EarnETH, EarnUSD, USDC, USDT, USDS, sUSDS, CowSwap access, Lido Lend access (which is basically Morpho Blue compat), LDO
> 7. It does not; it holds ET global pause and it's fine

Recorded as, by question: (1) signer-set drift: keeping the emergency Safe's signers equal to the committee's is a manual runbook duty ([ADR 005](/adr/005-account-graph-and-roles.md)); (2) the committee is the trusted caller of the onboarding factories ([ADR 006](/adr/006-governance-through-easy-track-factories.md)); (3) the minimum per motion is forum disclosure, alerting and runbook discipline, and the stops are an objection or the Easy Track pause ([ADR 006](/adr/006-governance-through-easy-track-factories.md)); (4) exposure caps are enforced by detection and reporting on immutable storage ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (5) the emergency swap runs through CoW, with Stonks 2.0 as the candidate ([ADR 007](/adr/007-swapping-through-stonks.md)); (6) the launch assets and venues ([ADR 011](/adr/011-launch-scope.md)); (7) the Emergency Brakes multisig keeps only the Easy Track pause. EM changed (7) at 12:16 and gave it the technical role. [s1]

## 2026-09-22 11:24 — four changes

> changes:
>
> 1) Emergency role is not Emergency Brakes inside, but a subset of TMC (same participants. quorum of 2 folks)
> 2) I don't like the idea DAO approves new protocols, let it be just another Easy Track factory or the one that we already have but broader; 
> 3) Better investigate Finance cap limits we set before via granular Aragon permissions, what we must do with them to scale up to [the mandate size]
> 4) disableModule must be within emergency scope
>
> Update the spec and interview me about other open questions

Recorded as: (1) the emergency role is a Safe with the committee's signers and a threshold of two ([ADR 005](/adr/005-account-graph-and-roles.md)); (2) Easy Track factories onboard new protocols, not a DAO vote ([ADR 006](/adr/006-governance-through-easy-track-factories.md)); (3) an investigation of the payment ceilings ([ADR 008](/adr/008-funding-through-existing-payments.md)); (4) module disabling in the emergency scope, which EM moved to the technical role at 12:16. [s1]

## 2026-09-22 10:50 — new contracts

> I am okay with building necessary ET factories, that's the only allowed new contracts
>
> Update your judgement

Recorded as: Easy Track factories are the only new contracts ([ADR 006](/adr/006-governance-through-easy-track-factories.md)). [s1]

## 2026-09-22 10:43 — the question behind it

> Can we have a solution without newly developed contracts? What we will lose then? We also can discover ready to use audited solutions from Open Zeppelin or other audited libs and frameworks

[s1]
