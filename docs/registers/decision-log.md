---
type: Register
title: Decision log
description: EM's inputs and decisions for Clutch, quoted exactly and dated; the source of record for every claim that EM decided something.
tags: [decisions, provenance]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T14:28:58Z
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
---

# Decision log

Entries quote EM exactly, including typos. An agent copied them from the interview transcripts. EM should confirm each entry by verifying this page. Newest first. Times are UTC.

Square brackets mark a redaction. Redactions keep the screening vendor's identity, the addresses that reveal it, and the unapproved mandate size out of the repository ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)).

Most answers are numbered. The numbers refer to the questions that the agent asked in the interview, and each "Recorded as" line names the question.

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
