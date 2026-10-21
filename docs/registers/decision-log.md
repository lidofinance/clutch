---
type: Register
title: Decision log
description: EM's inputs and decisions for Clutch, quoted exactly and dated; the source of record for every claim that EM decided something.
tags: [decisions, provenance]
status: stable
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-21T15:57:51Z
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
  - id: s6
    resource: "urn:clutch:interview:2026-10-07"
    title: EM's requests of 2026-10-07; the transcript is not in the repository
  - id: s7
    resource: "urn:clutch:interview:2026-10-08"
    title: EM's request for simplification options and EM's answers, 2026-10-08; the transcript is not in the repository
  - id: s8
    resource: "urn:clutch:interview:2026-10-09"
    title: EM's answers to OD-54 to OD-57, 2026-10-09; the transcript is not in the repository
  - id: s9
    resource: "urn:clutch:interview:2026-10-12"
    title: EM's request for a triage of the onboarding guide's tests, and EM's answer, 2026-10-12; the transcript is not in the repository
  - id: s10
    resource: "urn:clutch:interview:2026-10-13"
    title: EM's request to triage the committee's feedback, EM's answers to cards 1 to 5, EM's answers on ADR 002, the first-loss holder and OD-64, EM's verification of ADR 004, and EM's answers on OD-65 to OD-67, 2026-10-13; the transcript is not in the repository
  - id: s11
    resource: "urn:clutch:restricted:cfo-followup-2026-10-13"
    title: The CFO's follow-up questions and EM's answers in the committee's channel, 2026-10-13; outside the repository
  - id: s12
    resource: "urn:clutch:interview:2026-10-14"
    title: EM's question on one Aragon vote, and EM's answers on OD-66 and OD-68 to OD-83, 2026-10-14; the transcript is not in the repository
  - id: s13
    resource: "urn:clutch:interview:2026-10-15"
    title: EM's question on the operator Safe and EM's answer, 2026-10-15; the transcript is not in the repository
  - id: s14
    resource: "urn:clutch:interview:2026-10-20"
    title: EM's correction of the record of OD-44 and OD-62, EM's answers on the two readings, EM's verification of ADR 001 to ADR 004, and EM's answer on the YT registration, 2026-10-20; the transcript is not in the repository
  - id: s15
    resource: "urn:clutch:interview:2026-10-21"
    title: EM's request to update pull request #42, 2026-10-21; the transcript is not in the repository
---

# Decision log

Entries quote EM exactly, including typos. An agent copied them from the interview transcripts. EM should confirm each entry by verifying this page. Newest first. Times are UTC.

Square brackets mark a redaction. Redactions keep the screening vendor's identity, the addresses that reveal it, the unapproved mandate size, a price level that EM gave as an example, a local file path, a person's name, and the name and link of another, private repository out of the repository ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)).

Most answers are numbered. The numbers refer to the questions that the agent asked in the interview, and each "Recorded as" line names the question.

## 2026-10-21 — AGENTS.md names YT

After pull request #41 merged, EM asked:

> I merged #41, now update my https://github.com/lidofinance/clutch/pull/42 to fix inconsistencies and open things

Recorded as:

- EM's request is the explicit request that `AGENTS.md` needs before an agent edits it ([ADR 003](/adr/003-agent-operating-model.md)). The agent changed one rule to match the registration of `human:yt` of 2026-10-20: the only names used are EM and YT, the two people that `config/actors.yaml` lists. [s15]

## 2026-10-20 — ADR 001 to ADR 004 verified again, and YT registered

Pull request #41 shortened the explanations of ADR 001 to ADR 004, which EM had accepted, and registered `human:yt` in `config/actors.yaml`. The agent asked EM to verify the four ADRs again and to decide on the registration. EM answered:

> I verify ADR 001-004, I allow YT registration; do a push

Recorded as:

- EM verifies ADR 001 to ADR 004 again after the edits of pull request #41, so they stay accepted. At this instruction, the agent recorded EM's `verified` entries under the OD-31 rule: each names the agent in `recorded_by`, links this heading in `ref`, and carries the hash of the page's body. The verifications are EM's.
- EM allows the registration of `human:yt` as a decision proposer and page verifier. ADR acceptance stays with EM and the committee ([ADR 002](/adr/002-decision-and-review-process.md)). EM's answer is the explicit request that `config/actors.yaml` needs ([ADR 003](/adr/003-agent-operating-model.md)). [s14]

## 2026-10-20 — OD-84 to OD-88: two readings, the provider's reports and its checks

EM wrote, on the record that the Zodiac UI shows Lido's readings and alerts:

> I didn't want to feed their tools with our data, I meant that they have their version, and we have ours so that it's a cross-check and redundancy is justified

EM's answer of 2026-10-13 to the first question on OD-62 was "keep OD-44, still add more demand from Zodiac UI to have display and monitoring there". The agent recorded it as Lido's alerts shown in the Zodiac UI, next to Lido's readings ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 38). EM's words above say that this was not meant.

The agent asked five questions: which reading governs when the two readings differ (Q1); how the policy provider's reports reach IPFS (Q2); what the Zodiac UI does at signing (Q3); where the provider gets the mandate's rules (Q4); and what the screening vendor's integration still lacks (Q5). EM answered:

> Q1: B
> Q2: A, can be an admin setting for our account
> Q3: A
> Q4: A
> Q5: A

Recorded as, by question:

- (Q1, OD-84) Two readings watch the vault: Lido's, from the report generator and monitoring, and the policy provider's own, in the Zodiac UI. Neither reads the other's data. Both count: a cap breach in either published reading is a published cap breach for the switch's trigger, and no top-up motion starts while the two readings differ by more than a band. The committee's valuation policy sets the band. This replaces OD-44 in part and the first answer of OD-62 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decisions 40 and 41).
- (Q2, OD-85) The policy provider publishes its reports to IPFS with a pin-only key of a separate Lido pinning project, which Lido can revoke. The key is an admin setting of Lido's account in the Zodiac UI. The forum post links both reports ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 42).
- (Q3, OD-86) The Zodiac UI's signing flow refuses an operator transaction that would breach a cap, or take the liquidity buffer below its floor, at its post-transaction state by the provider's reading. It never refuses an emergency, recovery or DAO transaction. The gate is in the interface only. This replaces the warnings before signing of OD-44 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 43).
- (Q4, OD-87) This repository holds the mandate's rules as data, and both readings use them. `@lidofinance/defi-tech` sends each version to the provider after the Snapshot vote, motion or vote that changes a rule. A change made in the Zodiac UI is drift ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 44).
- (Q5, OD-88) From the lift of the launch cap, the Zodiac UI's signing flow sends each transaction of the committee's Safe that it builds to the screening vendor for its approval, and shows the approval state. Lido's monitoring alerts when such a transaction waits for the approval longer than a set time ([ADR 010](/adr/010-pre-execution-screening.md), decisions 25 and 26).
- Without a question, the agent also recorded three points of the requirement list, and EM did not object: the Zodiac UI shows the vault's three Safes as one whole, with the mandate's rubrics, the first-loss Safe outside the caps and the launch cap, and the orders account outside the liquidity buffer; its alerts go to a Lido Slack channel by webhook and do not page; and the mandate's rules reach the provider only as OD-87 says. [s14]

## 2026-10-15 — OD-80 and OD-83 kept after a review of the operator Safe

EM wrote:

> I woke up today and not sure whether it's good to have TMC safe re-used directly or previous design with a new operator safe (with the same composition) was better, can you do a corridor test, strawman vs steelman, research previous practice and find out what is more justified on the scale of future proof vs design simplicity and maintenability

The agent's review advised against a return to a new Safe with the same seven signers. It offered two contrast blocks: A, the recorded design, and B, an operator Safe owned 1 of 1 by the committee's Safe, with the guard on it only. EM answered:

> let it be A still, I don't like to have a nested interim safe

Recorded as:

- OD-80 and OD-83 stand. The committee's Safe holds the operator role and the first-loss role, it is the trusted caller of every Clutch factory, and from the lift it carries the screening guard ([ADR 010](/adr/010-pre-execution-screening.md), decision 24). The owned operator Safe goes to ADR 010's options as not chosen. ADR 010 and the LIP draft now name the other duties of the committee's Safe that the guard screens. The evidence is in a [research note](/research/operator-safe-review-2026-10-15.md). [s13]

## 2026-10-14 — OD-83: the screening guard on the committee's Safe

EM answered OD-83:

> OD-83: A

Recorded as:

- (OD-83) When the launch cap lifts, the screening guard is set on the committee's Safe. It screens every transaction of that Safe, the committee's other duties included, and a vendor outage stops them too ([ADR 010](/adr/010-pre-execution-screening.md), decision 24). This is the option that EM did not choose on 2026-10-02 (Option 5), now that the committee's Safe holds the operator role (OD-80). [s12]

## 2026-10-14 — OD-80 to OD-82: the committee's Safe as the operator, the Emergency Brakes multisig in the guide, and generated registers

After PR #38 merged, EM wrote:

> now let's prepare the next one:
> - let's get rid of extra msig for operator safe and just re-use the existing TMC multisig
> - emergency brakes not exactly needed on visual schemes and we may just mention that:
>   - they can pause ET
>   - two folks in Emergency Safes are from that msig
>   - and that's it!
>
> Also:
> - do C2
> - do C3
> - the new build checks as needed

Recorded as:

- (OD-80) The committee's own Safe, the Treasury Management Committee's Safe at 4 of 7 on Safe v1.3.0, holds the operator role and the first-loss role, and it is the trusted caller of every Clutch factory. Clutch deploys no operator Safe ([ADR 005](/adr/005-account-graph-and-roles.md), decision 31). Where the screening guard goes when the launch cap lifts follows from it and is open as OD-83.
- (OD-81) The diagrams, in the guide and in the LIP draft, carry no node for the Emergency Brakes multisig. The guide states two facts about it: it can pause Easy Track, and two of the emergency Safe's signers come from it ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 12).
- (OD-82) C2 and C3 of the agent's consolidation review, with the checks that they need: the closed decisions move into a data file, and the validator generates the register's closed index with each OD's state, the ADR index and each proposed ADR's open decisions; the guide's build refuses a source that names a replaced OD, and an item whose text names an OD that it does not cite ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 13). [s12]

## 2026-10-14 — OD-79: the 80/20 pass after OD-78

The agent ran the 80/20 pass that EM asked for with OD-78 and offered O1 to O5, and O2b. EM answered:

> O1: Let first-loss Earn shares to be on a separate "first loss Safe" still, but under operator Safe management; by default burn should not be allowed unless ET motion passes
> O2: Agree on no stop-loss orders
> O2b: Still need TWAP
> O3: keep
> O4: agree
> O5: keep as you suggested

Recorded as:

- (OD-79, O1) The first-loss shares stay in the separate first-loss Safe. The operator Safe manages them through its `first-loss` role, and a burn runs only as an Easy Track motion. This is the design of OD-60 and OD-67, so nothing changes ([ADR 008](/adr/008-funding-through-existing-payments.md), decisions 21 to 23).
- (OD-79, O2 and O2b) The launch has no stop-loss orders; TWAP orders stay ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 39).
- (OD-79, O3) The budget factory stays.
- (OD-79, O4) The catalogue check keeps only the onboarding templates whose shape a protocol in the committee's named pipeline needs. A later vote registers another template with its first protocol ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 18).
- (OD-79, O5) The removal template stays. [s12]

## 2026-10-14 — OD-78: a smaller launch

EM asked how many Safes, actors, new Easy Track factories and launch vote items the design has, and said:

> now I feel that complexity is large

The agent counted them and listed three items as optional at launch: insurance funds; the token template, with the orders modifier's governance and approvals roles; and the restore template. EM answered:

> I want cut, remove optional at launch; also run 80/20 pass even after that

Recorded as:

- (OD-78) Insurance funds do not ship with the launch: no fund roles, no fund templates, and no third funding registry or top-up factory. A later vote adds them; OD-66's framework, checklist, motions and exit describe them for that vote ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 31).
- (OD-78) The token template does not ship, and the orders modifier has no governance role and no approvals role. A DAO vote adds a token to the orders account, for every order type, with its relayer approval, and sets again an approval that the emergency role set to zero ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 38).
- (OD-78) The restore template does not ship. The DAO restarts by vote after each stop, as OD-59 decided ([ADR 005](/adr/005-account-graph-and-roles.md), decision 30; [ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 17).
- The 80/20 pass on the smaller design follows; EM decides its options separately. [s12]

## 2026-10-14 — OD-76 and OD-77: launch stop-loss feeds, and the restore's launch version

After the interview, the agent reported three effects of OD-74 and OD-75, and asked for two picks: which launch tokens get stop-loss orders, because Chainlink's Feed Registry has no USD feed for wstETH, WETH or LDO; and whether a restore keeps writing the launch version. EM answered:

> 1. (a)
> 2. noted
> 3. keep it

Recorded as:

- (OD-76, point 1) (a): at launch, stop-loss orders cover only the tokens whose proxies pass the registry check before the vote: stETH, USDC, USDT and USDS, and WETH through the registry's ETH/USD feed. wstETH and LDO get TWAP orders only ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 37).
- (point 2) noted: the switch does not freeze a motion that writes only on the orders modifier. No change ([ADR 005](/adr/005-account-graph-and-roles.md), proposed direction, "Restart").
- (OD-77, point 3) "keep it": a restore writes the launch version, whatever changed since. The restore motion's forum disclosure shows the difference from the current permission, and the objection window is the control ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 16). [s12]

## 2026-10-14 — OD-74 and OD-75: the interview on OD-68

EM asked for an interview on OD-68. The agent asked four cards on tokens that a motion adds to the orders account, and, at EM's request, reviewed every restart that needs a DAO vote. EM answered card by card:

> 1. Enough

> Card 1: A
> Card 2: B works, because the DAO restarts CAN be "ET motion restarts"
>
> Read other places where you believe that DAO restart must be a DAO vote and reconsider it to be an ET motion wherever it doesn't hurt trust model too much

> R1: vote
> R2: motion
> R3a: motion
> R3b: vote, I am afraid of delegatecalls
> R4: motion
> R5: vote
> R6: vote
> R7: vote

> 3: B

> A

Recorded as:

- (OD-74, card 1) a token that a motion adds gets TWAP orders, and stop-loss orders only with feeds checked against Chainlink's Feed Registry; market, limit and recovery orders stay a vote. "Card 1: A": a stop-loss permission pins a Chainlink proxy, which the factory checks against the registry at creation and at enactment; the launch tokens pin proxies too ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decisions 32 and 33).
- (OD-74, card 2) B: the Easy Track executor holds an approvals role that raises CoW's relayer approval for any listed token by motion, also after the emergency role set it to zero ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 34).
- (OD-75, card 2b) a motion restores a permission to exactly its launch version, without delegatecall, on the operator modifier (R2) and on the orders modifier (R3a), and raises a relayer approval (R4). The operator modifier's restart after the switch (R1), the order signer's delegatecall permission (R3b), a funding limit that a vote set to zero (R5), an Easy Track unpause (R6) and a repair of the safety modifier (R7) stay votes ([ADR 005](/adr/005-account-graph-and-roles.md), decision 29).
- (OD-74, card 3) B: a token that a motion adds also gets an emergency recovery TWAP, with no delegatecall, that sells it for USDC or USDT, pays the Aragon Agent and ends within 1 day ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 35).
- (OD-74, card 4) "A": the token template ships with the launch, with fork tests and the phase-3 audit ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 36). [s12]

## 2026-10-14 — OD-73: Aragon Voting owns the vault's Safes; OD-66 closed

The agent explained OD-73 and the two open points of OD-66, and asked EM to confirm its reading of OD-66 point 1. EM answered:

> OD-73: A confirmed
> OD-66:
> p. 2: A
> p. 5: A
> 1. Snapshot that sets a standing framework, then a motion per fund.
> OD-68: interview me

Recorded as:

- (OD-73) A: Aragon Voting, not the Aragon Agent, is the only owner of the Asset Safe, the orders account and the first-loss Safe, and the admin of the vault's funding registries. Recovered assets still go to the Aragon Agent. A DAO action on the vault is a direct Voting item, without Dual Governance ([ADR 005](/adr/005-account-graph-and-roles.md), decision 28).
- (OD-66, point 1) one Snapshot sets a standing framework for insurance funds, then each new fund needs one Easy Track motion. This corrects the agent's earlier reading, a Snapshot for each fund ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 25).
- (OD-66, point 2) A: the framework fixes a checklist that every fund fills in. The option named each fund's Snapshot; with one standing framework, each fund's motion and its forum post fill it in ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 29).
- (OD-66, point 5) A: a third funding registry and top-up factory pay only the first-loss Safe, within a limit, and ship with the launch ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 30). OD-66 closes.
- (OD-68) EM asked for an interview. Decision 31 of [ADR 007](/adr/007-swapping-through-an-orders-account.md) stands until the interview changes it. [s12]

## 2026-10-14 — OD-68 to OD-72 decided, OD-66 in part, OD-73 opened

The agent reviewed whether Clutch launches with one Aragon vote and then runs on Easy Track alone. It asked EM to decide OD-68 to OD-72 and the open parts of OD-66, and it proposed OD-73: whether Aragon Voting, not the Aragon Agent, owns the vault's Safes, so that no Clutch action passes Dual Governance. EM answered:

> OD-73: A
> OD-66:
> 1. Snapshot + motion
> 2. Didn't get what should be decided?
> 3. Decided
> 4. Ship with launch
> 5. Didn't get what should be decided?
> 6. Confirmed
>
> OD-68: C
> OD-69: A
> OD-70: B
> OD-71: A
> OD-72: rec
> OD-73: what it is about?

Recorded as:

- (OD-68) C: the orders modifier gets a governance role, held by the Easy Track executor, without delegatecall, and a motion adds a token for ComposableCoW's TWAP and stop-loss orders. A token for market, limit and recovery orders still needs a DAO vote ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 31).
- (OD-69) A: the enabling vote holds spare budget keys for each token, with ceilings ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 39).
- (OD-70) B: routine removals run as motions of a removal template, which waits for the objection window, and the emergency Safe's revoke stays for emergencies. This replaces part of OD-09 ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 14).
- (OD-71) A: a new TM Floor Value is a mandate change, so its DAO vote is by design, and a shortfall in stETH is topped up in stablecoins, so a re-pin is optional ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 24).
- (OD-72) "rec", the recommendation: before the vote, the template catalogue is checked against the protocols that the mandate allows, and a claim template, with the receiver pinned to the Asset Safe, ships only if a launch protocol pays rewards ([ADR 006](/adr/006-governance-through-easy-track-factories.md), decision 15).
- (OD-66, points 1, 3, 4 and 6) a new fund is approved by a Snapshot and then one Easy Track motion; the agent reads this as one Snapshot for each fund, which EM should confirm. Payouts run as Easy Track motions. The fund roles and factories ship with the launch. An exit from a fund stays with the operator Safe's direct role, paid to the Aragon Agent ([ADR 008](/adr/008-funding-through-existing-payments.md), decisions 25 to 28). Points 2 and 5 stay open, because EM asked what is to be decided there.
- (OD-73) not recorded as a decision: EM answered "A" and also asked what OD-73 is about. It stays open until EM confirms. [s12]

## 2026-10-13 — OD-67: three readings confirmed

The agent asked EM to check three points of the OD-67 record. First, its reading of "keep ET motion": only the burn moves to motions, and the exit to the Aragon Agent stays a direct role. Second, its reading of [ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 7, "Easy Track only expands", as a rule for permissions. Third, its proposals: the burn factory's shape, an amount and one of two pinned share tokens, and the advice to pause the Earn vault until a burn enacts. EM answered:

> 1. confirm
> 2. confirm
> 3. good

Recorded as: the first two readings are EM's. A motion that changes no permission, such as the first-loss burn, does not break decision 7 ([ADR 006](/adr/006-governance-through-easy-track-factories.md), the note after decision 13). EM agrees with the proposals of the third point; they stay in the agent-drafted text of [ADR 006](/adr/006-governance-through-easy-track-factories.md), [ADR 008](/adr/008-funding-through-existing-payments.md) and the LIP draft. [s10]

## 2026-10-13 — OD-67: no first-loss burn without the objection window

The agent asked whether Earn's first-loss burn also runs as an Easy Track motion, if burns for other products do. EM answered:

> I don't like direct burn without objection window, so keep ET motion

Recorded as: (OD-67) every first-loss burn runs as an Easy Track motion, Earn's included. The operator Safe creates the motion, and after the 72-hour objection window the Easy Track executor burns the shares through a `first-loss-burn` role on the first-loss modifier. The operator Safe's `first-loss` role keeps the redemption and the claim, paid to the Aragon Agent, as OD-60 decided. This replaces the direct burn of OD-60 ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 23). [s10]

## 2026-10-13 — OD-65 and OD-66 opened: the fifth signer and insurance funds

After the changes, the CFO asked two follow-up questions in the committee's channel: whether the emergency Safe's fifth signer can come from the Tech team, and whether the vault can manage more "insurance funds", for other products too. EM answered there [s11]:

> yup, tentatively tho

> Yeah, should have, will model it further

The agent proposed two open decisions, two templates for a new fund (burnable shares, and a fixed payout address), and one Easy Track motion to onboard each fund ([research note](/research/cfo-feedback-2026-10-13.md#follow-up-insurance-funds-for-other-products)). EM answered:

> add OD-65 and OD-66;
> I agree on two templates: burnable shares and a fixed payout address;
> may we execute these under ET motion? I would do so
>
> take this into account and report back

Recorded as:

- (OD-65) Open. EM's tentative answer: the fifth signer may come from the Tech team, if they are a member of neither the committee nor the Emergency Brakes multisig ([ADR 005](/adr/005-account-graph-and-roles.md), decision 24).
- (OD-66) Open, with two points from EM. A new insurance fund uses one of two templates: burnable shares, or a fixed payout address. EM prefers that the burns and the payouts run as Easy Track motions. The agent reads "these" as the burns and the payouts, not only the onboarding of a fund, and states the consequences in the OD-66 row. No ADR decision changes until OD-66 closes. [s10]

## 2026-10-13 — ADR 004 verified again

> record my re-verification of ADR 004; push

Recorded as: EM verifies ADR 004 again after the OD-64 edit, which adds decision 17: the Emergency Brakes multisig does not get access to view the Lido Zodiac workspace. ADR 004 stays accepted. At this instruction, the agent recorded EM's `verified` entry under the OD-31 rule: it names the agent in `recorded_by`, links this heading in `ref`, and carries the hash of the page's body. The verification is EM's. EM also asked the agent to push the branch. [s10]

## 2026-10-13 — ADR 002 verified again, the first-loss holder and OD-64

After the decisions of the day, the agent asked three things. It asked EM to verify ADR 002 again after its OD-63 edit. It asked which Safe "TMC Safe" means for the first-loss role. It also asked whether the Emergency Brakes multisig keeps two things: a notice of a relaxed screening rule ([ADR 010](/adr/010-pre-execution-screening.md), decision 19), and a view of the Lido Zodiac workspace ([ADR 004](/adr/004-specifications-and-policy-as-data.md), decision 16). EM answered:

> - record my re-verification of ADR 002
> - TMC Safe means operator safe
> - drop both

Recorded as:

- EM verifies ADR 002 again after the OD-63 edit, so it stays accepted. At this instruction, the agent recorded EM's `verified` entry under the OD-31 rule: it names the agent in `recorded_by`, links this heading in `ref`, and carries the hash of the page's body. The verification is EM's.
- (OD-60) The operator Safe holds the `first-loss` role, not the committee's own Safe. This replaces the agent's earlier reading ([ADR 008](/adr/008-funding-through-existing-payments.md), decision 21; [ADR 005](/adr/005-account-graph-and-roles.md), decision 27).
- (OD-64) The Emergency Brakes multisig loses both. A relaxation of a screening rule gets a notice on the forum only ([ADR 010](/adr/010-pre-execution-screening.md), decision 23), and the multisig no longer gets a view of the Lido Zodiac workspace. ADR 004 is accepted, so its text changed when EM verified it again, the same day (see the entry above). [s10]

## 2026-10-13 — OD-62: prices and the Zodiac UI; the protected files

The agent's fifth card asked whether Lido's readings stay canonical in the Zodiac UI (Q1), whether a written price waterfall replaces "unpriced" (Q2), and whether the committee's valuation policy sets the waterfall's band and the share of the vault that the last level may price (Q3). EM answered:

> Q1: keep OD-44, still add more demand from Zodiac UI to have display and monitoring there
> Q2: M
> Q3: it should
>
> also, go ahead on editing two protected files from card 1

Recorded as:

- (Q1) OD-44 stays: Lido's readings and alerts are canonical, and the Zodiac UI displays them. The requirement list to the policy provider grows: the UI should carry the monitoring too, with Lido's alerts shown there. If the provider declines, Lido builds both ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 38).
- (Q2, OD-62) A five-level price waterfall replaces "unpriced": Coingecko's close; a second aggregator; a Chainlink feed or the deepest pool's time-weighted price; the on-chain rate into a priced underlying; the committee's estimate, with its method. Every price carries its level and its source. A top-up post names every price below level 2, and a top-up waits while level 5 covers more than a set share of the vault ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decisions 35 and 36).
- (Q3) The committee's written valuation policy sets the band of level 2 and the level-5 share. No figure is set yet ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 37).
- EM's go-ahead is the explicit request that `config/actors.yaml` and `AGENTS.md` need before an agent edits them (ADR 003). The agent removed `human:emergency-brakes` from the actors and rewrote the `AGENTS.md` rule on `constrains_operator` (OD-63). [s10]

## 2026-10-13 — OD-61: the order life

The agent's fourth card proposed 90 days for limit orders and stop-loss expiries, with TWAP shapes scaled to 90 days and every open order in the monthly report. EM answered:

> M, TWAP and stop-loss orders follow the same bound as limit orders

Recorded as: every operator order lives at most 90 days: market and limit orders through the order signer's `validDuration`, TWAP orders through their parts and spacing, and stop-loss orders through the requested screening rule. Each monthly report lists every open order with its limit, its age and the idle balance behind it. A recovery order still lives at most 1 day. This replaces the 30-day bounds of OD-47 ([ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 29). [s10]

## 2026-10-13 — OD-60: the first-loss role

The agent's third card proposed one modifier on the first-loss Safe, with a narrow first-loss role: burn the DAO's own shares, and redeem them with the proceeds pinned to the Aragon Agent. EM answered:

> M, role is hold by TMC Safe

Recorded as: the first-loss Safe stays owned by the Aragon Agent at one of one, and gets one modifier with one `first-loss` role that the operator Safe holds. The role burns the DAO's earnETH and earnUSD shares, and requests and claims their redemption with the proceeds pinned to the Agent. It cannot transfer or approve them. The committee executes the first-loss terms of the March 2026 Earn allocation in place of the Growth Committee, on the Earn team's written instruction. The same day, EM said that "TMC Safe" means the operator Safe, so the operator Safe holds the role (see the entry above). This replaces the DAO vote of OD-42 for a burn or a redemption ([ADR 008](/adr/008-funding-through-existing-payments.md), decisions 21 and 22; [ADR 005](/adr/005-account-graph-and-roles.md), decision 27). [s10]

## 2026-10-13 — OD-59: no resume by an emergency body

The agent's second card asked who restarts Easy Track after a pause: the DAO, as now (A); the Emergency Brakes multisig with the unpause and cancel roles (B); or the multisig with the cancel role only (the middle). After card 1, the agent added that the emergency Safe's switch also freezes the queued motions that write through the operator modifier, and that re-enabling the modifier re-arms them. EM answered:

> Card 2: strongly A; now new powers, no resume under emergency bodies

Recorded as: A. The agent reads "now new powers" as "no new powers". No emergency body, neither the emergency Safe nor the Emergency Brakes multisig, holds a power to resume: no unpause, no re-enabled module, no permission granted again, no raised approval. The DAO restarts after either stop: a Voting item unpauses Easy Track, and an Agent item through Dual Governance enables the operator modifier again, after the same vote cancels the queued motions. The policy already met this rule; the compiler now refuses a policy that breaks it ([ADR 005](/adr/005-account-graph-and-roles.md), decision 26). [s10]

## 2026-10-13 — OD-58 and OD-63: the emergency Safe and the switch

The agent's first card asked who holds the emergency powers. It set out the current design, the committee's design, in which the Emergency Brakes multisig exits and the emergency Safe goes, and two middles. EM answered:

> On the card 1:
>
> 1. I strongly believe technical emergency brakes must not touch funds.
> 2. Let's remove technical role of Emergency Brakes: "Hold the technical role: disable the operator modifier for a defect in the permission layer, or on the fixed cap-breach trigger. On the orders account, it removes the operator Safe from the operator role instead (OD-57)."
> 3. Let's compose Emergency Safe 3/5 where 2 folks from TMC, 2 folks from Emergency Brakes, and 1 independent guy, and assign this responsibility "Hold the technical role: disable the operator modifier for a defect in the permission layer, or on the fixed cap-breach trigger. On the orders account, it removes the operator Safe from the operator role instead (OD-57)"
> 4. I.e., Emergency Brakes in this setup can only pause ET
> 5. Take into account all of this and figure out what this all brings and what things can be simplified automatically if any under this new trust model (I mean we can have logical (quasi-)tautology somewhere)

The agent analysed the quorums and listed what the model simplifies. It asked whether the switch merges into the emergency role and the orders account's membership removal goes (Q1), how the seats are appointed (Q2), and whether the Emergency Brakes multisig still verifies the records that constrain the operator (Q3). EM answered:

> - Q1: yes
> - Q2: directionally agree, let's just have a strict requirement that 5th signed is not within TMC and Emergency Brakes
> - Q3: It shouldn't

Recorded as:

- (1, 4, OD-58) The Emergency Brakes multisig touches no funds and holds no role in the vault. It keeps only the global Easy Track pause ([ADR 005](/adr/005-account-graph-and-roles.md), decision 23).
- (3, Q2) The emergency Safe has five signers at three of five: two committee members, two Emergency Brakes members, and a fifth signer who is a member of neither body. The agent reads "5th signed" as "fifth signer". The committee and the Emergency Brakes multisig appoint two seats each, and a DAO Snapshot appoints the fifth. A signer who leaves their body leaves the seat ([ADR 005](/adr/005-account-graph-and-roles.md), decision 24).
- (2, 3, Q1) The switch moves to the emergency role, and the technical role goes. On the orders account, the emergency role's revoke stops the operator, and the membership removal of OD-57 goes. The emergency Safe switches off on the cap-breach trigger ([ADR 005](/adr/005-account-graph-and-roles.md), decision 25; [ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 30; [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 34).
- (5) The simplifications are in the [research note](/research/cfo-feedback-2026-10-13.md). The mandate's independent emergency committee now holds as drafted, so the mandate and the LIP owe no statement that the fast exit is not independent. This replaces OD-30.
- (Q3, OD-63) The Emergency Brakes multisig no longer verifies the records that constrain the operator, and nothing replaces it. The `constrains_operator` field, its validator rule and `human:emergency-brakes` go, and the verification-requests register retires. ADR 002 is accepted, so its text changed when EM verified it again, the same day (see the entry above). [s10]

## 2026-10-13 — the committee's feedback asked

> we got a feedback from CFO ([a name]) who is also sitting within TMC, see [a local file]
> let's try to triage and address this points one by one, meticulous interview is needed;
> Before we start this interview, do a deep research to prepare the background: learn the current state of the art, learn the landscape, current market conditions, incidents track, recent treasury management news, general crypto sentiment, protocols launched and sun set, crypto 2026 reports and so on and so forth.

Recorded as: the agent researched first: emergency powers in other treasuries and councils, the 2026 incidents, the market and Lido's own records. It then prepared five cards for the six points ([research note](/research/cfo-feedback-2026-10-13.md)). [s10]

## 2026-10-12 — the onboarding guide's invariant checks, source pins and coverage

> learn what we did recently in [another, private Lido repository and its pull request]
> pay attention to Copilot findings and how we addressed them; triage if the same test suite and approach should be apploed for clutch onboarding guide

The agent read the other guide's review and its fixes, and probed this guide ([research note](/research/guide-invariants-2026-10-12.md)). It proposed three tiers. Now: the browser checks that find live defects, and the fixes. Cheap guards: the map rule, a weekly link check, the page as an artifact of each pull request, and a check of the workflows. Later, with EM's decision: pins of each item to its sources, with references to single decisions, and a coverage rule. EM answered:

> do a PR to clutch without deferring 'Later' items

Recorded as: one pull request carries all three tiers ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 11).

- The browser tests check accessibility in twelve presentation states and check the page without its script. The dark palette applies only on screens, and only the script gives an element a widget role.
- Each item of the guide is pinned to the text of its sources. A reference names a decision or a section of an ADR, never the whole ADR. Every ADR, invariant, LIP part and runbook is cited or excluded with a reason, and every box and arrow of the map is used.
- CI attaches the built page to each pull request, reports its pin changes, checks the workflows with zizmor, and checks the guide's outside links every week.
- The mapping of the guide's references to decisions found nine places that were behind OD-54 and OD-57. The same pull request fixes them. [s9]

## 2026-10-09 — OD-56's reason, and OD-57: one modifier on the orders account

> Q3: on Q3 I believe we will mostly rely on the off-chain monitoring and guard, because this data is still asynchronous in its nature, so that having excessive work on-chain adds a little value imo as you mentioned price drifts happen and happen regardless our own cadence due to volatility and market stress
> Q4: B

Recorded as:

- (Q3, OD-56) EM confirmed option C and gave the reason: the caps rest mostly on off-chain monitoring and the screening guard, because value data is asynchronous. More on-chain work adds little value, because prices drift with volatility and market stress whatever the cadence. Following this reason, the agent dropped "a price move outside a band" from its proposed list of budget events, so budgets do not follow prices at all ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decisions 31 to 33).
- (Q4, OD-57) The orders account carries one modifier, with the operator, emergency and technical roles and no governance role. The Asset Safe keeps its two modifiers. On the orders account, the technical role stops the operator by removing the operator Safe's membership of the operator role, with every argument pinned ([ADR 005](/adr/005-account-graph-and-roles.md), decision 21; [ADR 007](/adr/007-swapping-through-an-orders-account.md), decision 28). [s8]

## 2026-10-09 — OD-54 to OD-56: the capped launch, its figure and the budgets

> Q1: C
> Q2: A
> Q3: C, but please explain in a more detailed but digestable way what is about
>
> On Q4 please outline all options better, what you assume to be a 'vote' and etc; I feel that I am confused now

Recorded as:

- (Q1, OD-54) The launch without the screening guard stays under its cap by procedure. The funding registries keep the limits of [ADR 008](/adr/008-funding-through-existing-payments.md). Until the cap lifts, the committee requests a top-up only while the vault stays at or below the cap. Monitoring alerts above the cap, and LDO holders can object to a top-up motion that would cross it. A forum post lifts the cap once the guard is set on the operator Safe with its bypass mode off. The enabling vote no longer waits for the guard ([ADR 010](/adr/010-pre-execution-screening.md), decisions 20 to 22; ADR 008, decision 20).
- (Q2, OD-55) The cap is one million dollars, on the Asset Safe and the orders account. The first-loss Safe stays outside it ([ADR 010](/adr/010-pre-execution-screening.md), decision 20).
- (Q3, OD-56) Budgets have no routine retune. Each key is set once and changes by motion only after an event. The yield-bearing key gets a fixed monthly budget. The caps stay detective. This replaces the fortnightly retune ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decisions 31 to 33). EM asked for a fuller explanation, which the agent gave in its reply of 2026-10-09.
- (Q4, OD-57) Not answered. EM asked for a clearer outline of the options and of what "vote" means. OD-57 stays open, with a clearer question.
- (F of 2026-10-08) The withdrawal queue is now out of [ADR 007](/adr/007-swapping-through-an-orders-account.md) (decision 27), [ADR 011](/adr/011-launch-scope.md) (decision 14) and the policy. [s8]

## 2026-10-08 — simplification options; OD-54 to OD-57 opened

> say I want to achieve 80% of result with 20% of complexity and effort in clutch; what can be a list of options to drop or simplify things? research it hard and deep, validate every claim you made against Lido approaches and established trust models

The agent answered with eleven options, A to K, each checked against Lido practice, the ENS endowment and Aave's Finance Steward ([research note](/research/simplification-2026-10-08.md)). EM answered:

> - A is not an option, we must not do it basically it's a lot of ops burden — omnibus votes are heavy to run, coordinate, gather quorum and repeat especially out of order when needed
> - B option sounds possible but still undesirable
> - E option — I want to talk a bit more
> - F option — we can cut withdrawal queue; others should stay IMO
> - G options is a bit too weak to cut — we won't get rid of the on-chain code but we will lose UX a lot
> - C option — let's test it and research
> - H option — possible, but saves is too low
>
> - B2: agree to not consider, too scary
> - D: agree to not consider, weak escape hatch without it
> - J: we can launch without guard but under a cap of ~$1-3M only
> - K: too early
>
> incorporate this input, update the reasoning, and run a batched interview afterwards

Recorded as:

- (A) Not taken. The template factories, the exit-governance role and the budget factory stay. A DAO vote for every change costs too much in operations: an omnibus vote is heavy to run and coordinate, needs a quorum, and is hard to repeat out of order ([ADR 006](/adr/006-governance-through-easy-track-factories.md)).
- (B) Not taken for now. TWAP and stop-loss orders stay ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- (B2, D) Not considered. The orders account stays, and the emergency role keeps its recovery orders, the escape hatch ([ADR 007](/adr/007-swapping-through-an-orders-account.md)).
- (C) The agent tested one modifier per account on a fork and opened OD-57 ([research note](/research/simplification-2026-10-08.md)).
- (E) Opened as OD-56, for discussion ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- (F) The withdrawal queue leaves the design: the operator's withdrawal requests and claims, its stETH approval to the queue, and the emergency role's claim. ETH staking, WETH, DAI with Sky's converter, and LDO stay. The records and the policy change follow with the answers to OD-54 to OD-57 ([ADR 007](/adr/007-swapping-through-an-orders-account.md), [ADR 011](/adr/011-launch-scope.md)).
- (G) Not taken. The display requirements and the requested vendor rules stay: the on-chain code stays either way, and the display carries the user experience ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- (H) Not taken. Safe v1.5.0 stays, because the saving is too small ([ADR 005](/adr/005-account-graph-and-roles.md), [ADR 010](/adr/010-pre-execution-screening.md)).
- (J) A launch without the screening guard is acceptable under a cap of about one to three million dollars. Opened as OD-54, how the cap holds and lifts, and OD-55, its figure ([ADR 010](/adr/010-pre-execution-screening.md)).
- (K) Not taken: too early. [s7]

## 2026-10-07 — the onboarding guide on GitHub Pages

> I want to host our onboarding html on GitHub pages from this repo CI workflow, implement it and tell what should I do from my side; we don't need to be super private here, just preserve disclaimers that this is a hypothetical draft, etc etc

Recorded as: a CI workflow publishes the onboarding guide on GitHub Pages from `main` ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 10). This replaces "internal first" of OD-37, and "it goes public with the repository at deployment", for the guide's page alone. The repository itself stays private until deployment ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). The page says, in its banner and its footer, that it is a hypothetical draft: nothing is deployed or ratified, every number can change, and it is not advice. The build refuses a banner or a footer without that disclaimer. [s6]

## 2026-10-07 — OD-50 to OD-53: reviewers, verification locks, the fork suite and the request's figures

> Q1: A
> Q2: A
> Q3: C, will be A later, make a mark in roadmap for it
> Q4: B, just make a proper disclosure in the readme of the repo that everything is draft and not ratified, so numbers and everything is speculative

Recorded as:

- (Q1, OD-50) A team verifies through a member, with `ref` to the pull request that the member approved. `human:defi-tech` is the first team in `config/actors.yaml`. A team's verification raises a page's review status and never accepts an ADR; only EM or the committee accepts one ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 6).
- (Q2, OD-51) Each verification from 2026-10-07 on records `sha256`, the hash of the page's body, and `just verify` writes it. The validator fails when the body differs from the hash of the latest verification, until a human verifies the page again (decision 7).
- (Q3, OD-52) The fork suite stays out of CI for now. Phase 2 of the roadmap moves it into the merge queue and onto pushes to `main`, with the archive RPC key as a repository secret, never on a pull request (decision 8).
- (Q4, OD-53) The request for solution's allocation figures are not restricted, and the two quotes in this log stay. The README now opens with a disclosure: everything in the repository is a draft and not ratified, and every number is speculative. The guide's banner says the same. The guide's build no longer refuses a figure in the RFP tab (decision 9). [s6]

## 2026-10-07 — many contributors and their agents

> Now analyze the repo from the prospects that I want more contributors to come and run their agents to contribute; what should we do to streamline entry and avoid hectic things from happening?

The agent answered with fifteen steps. The [research note](/research/contributor-readiness-2026-10-07.md) keeps the list, and EM's numbers refer to it.

> 2. agree
> 4. don't edit codeowners yet
> 7. agree
> 14. agree
> 15. agents don't own github accounts
>
> Implement everything that you can and pen OD-50 if needed from this input and run an interview, again if needed

Recorded as:

- (2) Any agent may author a page: `generated.by` accepts any agent id. Only the humans that `config/actors.yaml` lists verify a page. Which human reviewer ids join the list is OD-50 ([ADR 012](/adr/012-contributing-with-many-agents.md), decision 1).
- (4) `CODEOWNERS` does not change for now (decision 2).
- (7) Changes land through a merge queue, or with branches that are up to date with `main`, so the checks run on the merged result (decision 3).
- (14) An agent opens a decision only as a complete row of the open-decision register. EM triages and decides in batched interviews, one decisions branch at a time (decision 4).
- (15, OD-23) Agents own no GitHub accounts. An agent's work lands through the account of the human who runs it. OD-23 is closed, and ADR 012 decision 5 replaces ADR 003 decision 12 when EM accepts ADR 012.
- The agent reads "Implement everything that you can" as the steps that need no further decision: 1, 3, 5, 6, 8, 9, 11 and 12, the parts of 2 and 13 that are decided, and the rules of 7 and 14. It reads "pen" as "open". It opened OD-50 to OD-53 for the rest: the human reviewer ids, a content lock for verifications, the fork suite in CI, and the request for solution's figures. [s6]

## 2026-10-07 — the RFP in the onboarding guide

> now I want our onboarding doc also to include analysis against RFP we shared with Zodiac inbox/Active Treasury Management — 1pager.md, similar way we made an explicit highlight of mandate and its changes, and constellation cfg with its changes
>
> update the onboarding doc, fix tests if needed

Recorded as: the onboarding guide gets an RFP tab ([onboarding guide](/onboarding/guide.md)). The agent reads "RFP we shared with Zodiac" as the request for solution in the file that EM named, which Lido contributors sent to the policy provider. A research note records what the request asked, paraphrased and without its allocation figures, and cites the request as held outside the repository ([research note](/research/request-for-solution-2026-10-07.md), [ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). The tab gives each ask its answer in the decided design, marks it as asked, changed or not answered yet, gives the reason for each change, and lists what Clutch adds that the request did not ask for. [s6]

## 2026-10-06 — the mandate and the constellation in the onboarding guide

> let's add two new items for onboarding:
> - the mandate visual blocks with texts and explainers, also visually highlight what we changed in this repo and why
> - the constellation config represented visually (maybe a bit high-level to not burden the doc), also visually highlight what we changed in this repo and why
> - also I am not sure if 'Plain / Technical' toggle works at all
> - also I see this console error: 'clutch-onboarding.html:1 Unsafe attempt to load URL file:///[local path]/clutch/docs/onboarding/clutch-onboarding.html from frame with URL file:///[local path]/clutch/docs/onboarding/clutch-onboarding.html. 'file:' URLs are treated as unique security origins'

Recorded as: the onboarding guide gets a Mandate tab and a Constellation tab ([onboarding guide](/onboarding/guide.md)). The agent reads "the mandate visual blocks" as one card for each part of the mandate draft: what the draft says, how Clutch keeps the rule, and each change that Clutch made, with its reason and its state: mandate text owed, design choice or proposed. The draft is not public, so a card paraphrases only what this repository records about it and shows no figure from it ([ADR 001](/adr/001-repository-scope-visibility-licence-name.md)). The agent reads "a bit high-level" as the modifiers and roles of the committed artifact with their holders and counts, each role's exact targets only in the Technical view, and a table of the changes from the policy provider's constellation. The doubt about the detail switch and the console error are reports of defects, which the agent checks and fixes where it finds a cause. [s5]

## 2026-10-06 — OD-49: emergency exits for positions that a motion onboards

> run OD-49 interview

The agent asked two questions. Q1: how does the emergency role exit a position that a motion onboarded, given that the governance role cannot touch the emergency role? A: the enabling vote grants every emergency exit whose contract exists by then, and for anything onboarded later the operator exits until a DAO vote adds the emergency exit; B: an exit-only template role on the safety modifier, so the motion that onboards a protocol also adds its emergency exit; C: onboard any protocol that holds value by DAO vote. The agent recommended A. Q2, an input: will Lido Lend's markets live on Morpho Blue's own contract? A: yes; B: no, a separate deployment; C: not known yet. EM answered:

> Q1: B
> Q2: B

Recorded as:

- (1, OD-49) A motion that onboards a protocol also adds its emergency exit. A new role on the safety modifier, the exit-governance role, held by the Easy Track script executor, writes exits for the emergency role through the same templates. It cannot write anything but an exit shape, grant delegatecall, touch the technical role or membership, set an allowance, or target the Asset Safe or a module of it ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13, [ADR 005](/adr/005-account-graph-and-roles.md)).
- (2, OD-49) Lido Lend is a separate deployment that is compatible with Morpho Blue, not markets on Morpho Blue's own contract. Its address enters with the onboarding motion, and that motion also adds its emergency exit ([ADR 011](/adr/011-launch-scope.md) decision 13).

## 2026-10-06 — OD-48: the price risk of recovery orders

> run an interview on OD-48

The agent asked one question: how is the price risk of recovery orders handled, given that no guard screens them? A: an on-chain floor through ComposableCoW's GoodAfterTime order type and a Chainlink price checker; B: no on-chain floor, relying on CoW's competition and EBBO rule, with paging on every emergency swap and an alert on a recovery order whose limit sits far below a market price; C: B plus a daily budget on the emergency role's transfers into the orders account. EM answered:

> Q1: B

Recorded as:

- (1, OD-48) Recovery orders have no on-chain price floor. CoW's solver competition and its EBBO rule hold a fill to at least the on-chain market, and a solver that breaks the rule must refund the user or lose its bond. Every emergency swap pages at high severity, and monitoring alerts on a recovery order whose limit sits far below a market price. The GoodAfterTime floor stays a research item ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 26, [research note](/research/cow-orders-account-2026-10-06.md)).

## 2026-10-06 — OD-47: the maximum order life

> do OD-47 interview

The agent asked three questions. Q1: how long can the operator's market and limit orders live? A: 14 days; B: 30 days; C: 90 days. Q2: how are TWAP and stop-loss orders bounded? A: a TWAP order starts at its creation and ends within 30 days, a screening rule refuses a stop-loss expiry more than 30 days ahead, and monitoring alerts on any open order older than 30 days; B: monitoring and cancelling only. Q3: how long can a recovery order live? A: 1 day; B: as long as the operator's orders. EM answered:

> Q1: B
> Q2: A
> Q3: A

Recorded as:

- (1, OD-47) The operator's market and limit orders live at most 30 days. The policy pins the order signer's `validDuration` to at most 30 days ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 23).
- (2, OD-47) A TWAP order starts at its creation and has at most 30 parts at most a day apart, or at most 4 parts at most 7 days apart, so it ends within 30 days. A stop-loss order's expiry is at most 30 days ahead, through a screening rule requested from the vendor, because no condition can compare the expiry with the current time. Monitoring alerts on any open order older than 30 days, and the emergency Safe can cancel it (decision 24).
- (3, OD-47) A recovery order lives at most 1 day. The policy pins the order signer's `validDuration` for the emergency role to at most 1 day (decision 25).

## 2026-10-06 — OD-46: how a new token joins the orders account's lists

> run an interview on the next pending decision

The agent asked two questions. Q1: how does a token join the lists, given that the order signer's permission is a delegatecall and a motion cannot write one (OD-36)? A: a DAO vote; B: a narrow exception to OD-36 for the order signer; C: no token pins. Q2: which tokens start on the operator's lists? A: the set of 2026-09-22; B: that set plus WETH; C: B plus sUSDS. EM answered:

> Q1: A
> Q2: B

Recorded as:

- (1, OD-46) A DAO vote adds a token to the orders account's lists, for the operator and for recovery. The same vote adds the token's approval of CoW's vault relayer, its emergency transfer and its recovery orders. The swap-instance template leaves the catalogue, and five templates remain. OD-36 keeps no exception ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 12, [ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 21).
- (2, OD-46) The operator's lists start with stETH, wstETH, WETH, USDC, USDT, USDS and LDO. DAI and sUSDS stay off. The operator trades WETH in CoW orders, and staking and Lido's withdrawal queue stay available ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 22, [ADR 011](/adr/011-launch-scope.md) decision 12).

## 2026-10-06 — OD-39 to OD-45: the committee's meeting on controls, buffer, product tiers, first-loss, swaps, NAV and timelocks

> we had a meeting today with TMC members, key points:
> - we want to maintain liquidity buffer for >= 1 month of baseline monthly spend; not enforceable on-chain, but can be covered with monitoring and alerting, should be visible in Zodiac UI ideally
> - agreed that new Lido products like Lido Lend stay within the risk tier of "Protocol / counterparty cap, 25% of total assets" till maturation happens and "no limit" unlocks
> - in general what's not enforceable on-chain should be covered with internal monitoring and alerts, [the screening vendor]'s guard that we added, zodiac UI to display and warn
> - we need to mark first-loss funds somehow, maybe even suballocation or?
> - swaps are too limited now: folks want to have DCA and long-standing limit orders (like sell if ETH breaks [a price level]), on top of that they wanted to have 1inch and uniswap available; so probably stonks 2.0 is not the right fit or it can be primary day-to-day path and other things as backup? but is it worth having stonks 2.0 then? bc it's pretty complex and verbose deployment-wise
> - we will insist on having NAV data in Zodiac UI (at the very least they can integrated Debank API)
> - structural risk exposure increase changes must be timelocked (i.e., changing whitelist), which works pretty well with ET factories I guess, but check
>
> Digest all of this and suggest what we must update and why, scan the whole set of decisions made, APRs and repo contents, don't rush

The agent asked seven questions. EM answered:

> Q1: A
> Q2: A
> Q3: A, earnETH and earnUSD are not new
> Q4: A
> Q5: A
> Q6: A
> Q7: A

Recorded as, by question:

- (1, OD-39) Every mandate rule gets a control on each layer that can carry it: the on-chain policy, screening before execution, monitoring with alerts, and display in the Zodiac UI. A control matrix in the specifications maps each rule to its controls, owners and status. The screening vendor's rules become a written list in this repository ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 26).
- (2, OD-40) The liquidity buffer of at least one month of baseline spend gets a continuous detector, a line in every report, a screening rule if the vendor can check it before execution, and a display in the Zodiac UI. The committee restores it within the mandate's window. Its figure comes from the attested computation ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 27).
- (3, OD-41) A new Lido product, Lido Lend first, counts against the protocol and counterparty cap until it matures. The mandate states the criteria for maturity. A budget motion and a forum post unlock it, so the objection window is its timelock. earnETH and earnUSD are not new. This replaces the three-month rule of OD-04 and OD-12 ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 28).
- (4, OD-42) The DAO's first-loss Earn shares go to a dedicated first-loss Safe, owned by the Aragon Agent at one of one, with no modules. No role can reach them. This replaces the destination of OD-21, and the no-redeem rule becomes structural ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 19, [ADR 005](/adr/005-account-graph-and-roles.md)).
- (5, OD-43) A dedicated orders account replaces the Stonks 2.0 instances for both roles. It is a Safe owned by the Aragon Agent, with CoW's fallback handler and its own modifiers. The operator funds it by pinned transfers under budgets, and places CoW market, limit, TWAP and stop-loss orders whose proceeds go to the Asset Safe. The emergency role places orders whose proceeds go to the Aragon Agent, and can always send assets to the Agent. The launch uses CoW only. Uniswap and 1inch come only if the screening vendor can bound a swap's minimum output before execution ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 17, [research note](/research/cow-orders-account-2026-10-06.md)).
- (6, OD-44) A written requirement list goes to the policy provider: the Zodiac UI shows Lido's own readings as the canonical figures, a live value labelled as indicative, and warnings before signing. If the provider declines, Lido builds the display from the same readings ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 29).
- (7, OD-45) Easy Track motions are the timelock for every structural increase of exposure. A relaxation of the screening vendor's rules gets change control: the written list, a notice to the Emergency Brakes multisig and the forum, and the vendor's own delay if it has one. The unlock of a matured product is a motion ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 30, [ADR 010](/adr/010-pre-execution-screening.md) decision 19).

Square brackets mark two redactions: the screening vendor's name, and the example price level of a stop-loss order, which the repository does not publish. [s5]

## 2026-10-06 — browser tests for the onboarding guide

> now add autotests the onboarding guide, including checks that every interactive element works as intended, feel free to use playwrite; update the guide itself wherever and whenever needed

Recorded as: the onboarding guide gets automated browser tests, `scripts/test_onboarding_page.py`, that drive every control of the page in headless Chromium with Playwright, and the agent fixes the guide where the tests find a defect. The agent reads "autotests" as tests that run automatically, so this is EM's request for a new job in the docs CI workflow under `.github/` that runs them on every pull request ([onboarding guide](/onboarding/guide.md)). [s5]

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

Recorded as: all six as the agent recommended. (Q1, OD-25) The agent adds `scripts` to the licence check of [ADR 001](/adr/001-repository-scope-visibility-licence-name.md). After that change merges, EM accepts ADR 001 to ADR 004 in one edit. Decision 6 of [ADR 003](/adr/003-agent-operating-model.md) covers production parameters; the kit's dry-run budgets and fixed ceilings are test values. (Q2, OD-26) Recovery also sells USDC, USDS and DAI into USDT, because USDS and DAI carry USDC risk. Recovery then has ten instances, and the mandate text owes a change: the emergency swap goes into USDC, or into USDT as the second destination ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). (Q3, OD-27) The stETH approval to Lido's withdrawal queue has a fixed ceiling of one TM Floor Value in stETH and no budget key ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). (Q4, OD-28) The no-redeem rule for the first-loss Earn shares binds the emergency role too. In an emergency, it sends them to the Aragon Agent, and a burn or a redemption of them is a DAO vote ([ADR 008](/adr/008-funding-through-existing-payments.md)). (Q5, OD-29) "A pause of the whole module" means disabling the operator modifier. The Emergency Brakes multisig does it through the technical role on a fixed trigger: a published cap breach that is still there after the committee's rebalancing window of two working days, and that is larger at the next fortnightly snapshot. A DAO vote can also do it ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). (Q6, OD-30) The emergency Safe stays a subset of the committee's signers. The mandate draft promises an exit that is independent of the committee, so the mandate text owes a change, and the LIP states that the fast exit is not independent of the committee ([ADR 005](/adr/005-account-graph-and-roles.md)). The evidence for Q2 and Q3 is in the [recovery note](/research/recovery-and-withdrawal-queue-2026-10-05.md). [s4]

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

Recorded as: OD-20 is closed. (Q1) The committee's Safe, as the manager of the shared Stonks 2.0 oracle router, adds USDC, USDT, DAI and USDS once the instance list is final. Each is quoted in USD, with a maximum price age equal to Chainlink's heartbeat for its feed. Lido deploys one USD-anchored converter for the vault through the deployed converter factory. The enabling vote starts only if every vault token is configured on the router and in sync. (Q2) The swap instances cover only the tokens that the router can price: stETH, LDO, USDC, USDT, USDS and DAI. wstETH is unwrapped and sUSDS is redeemed before a sale. EM added WETH. (Q2b) WETH goes through stETH: to sell it, the vault unwraps it, stakes the ETH through Lido's `submit` and sells the stETH; to buy it, the vault unstakes stETH through Lido's withdrawal queue and wraps the ETH. The operator and the emergency role may stake ETH, the operator may request and claim withdrawals pinned to the Asset Safe, and the emergency role may unwrap WETH. (Q3) The committee's Safe re-syncs a feed after Chainlink replaces it. Monitoring alerts when a vault token's feed is out of sync, and a runbook covers the re-sync. If a feed is broken during an emergency, the emergency Safe sends assets to the Aragon Agent instead of swapping. The evidence is in the [pricing note](/research/stonks-pricing-2026-10-05.md) ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). [s4]

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

Recorded as: option 1 of the Q3 walkthrough. Instances come from the standard factory, whose recovery address is the treasury. Tokens recovered from a rebalancing instance therefore go to the treasury, not back to the vault. The agent had recommended deploying rebalancing instances outside the factory, so that they recover to the Asset Safe; EM chose the factory ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). [s3]

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

Recorded as, by question: (1) budget sizing: the whole vault may sit in Lido products, and budgets retune every two weeks ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (2) swap topology: recovery has a mandatory second destination, USDT ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); (3) monitoring: screening can block suspicious transactions ([ADR 010](/adr/010-pre-execution-screening.md)), the committee owns ratio-breach remediation, a pause of the whole module is the escalation, and detectors run in both monitoring estates ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). [s1]

## 2026-09-22 12:32 — eight open items

> 1. Derive from mandate
> 2. Launch without it but with Morpho Blue template, having e2e tests for it
> 3. Add DAI
> 4 and 9. We need stablecoin to stablecoin recovery too, yeah; add missing recovery pairs. Don't reuse existing instances; Rebalancing needed is stETH, wstETH, USDC, USDT, USDS, LDO
> 5. IPFS, Don't use databus at least yet
> 6. set is fine, removal templates should skip objection window
> 7. It's solved via general incident response process built in Lido
> 10. Agent it must be

Recorded as, by question: (1) budgets and approval ceilings derive from the mandate ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (2) Lido Lend is not in the launch, and the Morpho Blue template ships with end-to-end tests ([ADR 011](/adr/011-launch-scope.md)); (3) DAI joins the launch set ([ADR 011](/adr/011-launch-scope.md)); (4 and 9) the swap instance matrix: stablecoin-to-stablecoin recovery, the missing recovery pairs, no reuse of existing instances, and the rebalancing set ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); (5) reports go to IPFS, not DataBus ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (6) the template catalogue is accepted, and removal should skip the objection window, which Easy Track cannot do per factory (open item OD-09); (7) paging runs through the general Lido incident process ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (10) the Aragon Agent manages every swap instance ([ADR 007](/adr/007-swapping-through-an-orders-account.md)). [s1]

## 2026-09-22 12:16 — technical role

> assign disableModule to technical emergency brakes, I do agree now

Recorded as: the Emergency Brakes multisig holds a technical role that can disable the operator's permission module and nothing else ([ADR 005](/adr/005-account-graph-and-roles.md)). [s1]

## 2026-09-22 12:11 — swap engine, Lido Lend and the emergency model

> 1) I want swap engine for ATM by-default to be stonks 2.0
> 2) Lido Lend will appear in October, we can add it a bit later, but need to be zero-day ready so that can be done via an ET motion
> 3) I am thinking about emergency in the following way:
>    - emergency has financial risks and there are most of them: depegs, dependency failure, curator misbehavior, etc. so that we want to have TMC with lower quorum to swap/exit/claim
>    - technical risks requiring pause of the whole module might have connected with Emergency Brakes, but it's overkill given ET is pausable itself and it's fine; the risks are monitored by the tech team including immunefi submissions, and Emergency Brakes indeed have tech folks inside

Recorded as: (1) Stonks 2.0 is the default swap engine ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); (2) Lido Lend is onboarded by an Easy Track motion and must be ready on the day it deploys ([ADR 011](/adr/011-launch-scope.md)); (3) financial emergencies go to the committee's signers at a lower quorum, and the engineering organisation watches technical risk ([ADR 005](/adr/005-account-graph-and-roles.md)). [s1]

## 2026-09-22 11:39 — seven open questions

> 1. It's a manual duty in the runbook, the same we do with HashConsensus or some of the DG committees
> 2. Operator (TMC) is the trusted caller
> 3. Minimum is forum disclosure for every motion, alerting setup, and runbook discipline; ultimate stop is objection or whole ET pause by emergency brakes
> 4. Accept detective enforcement with reporting, must rely on data published to immutable database, preferably IPFS or even on-chain through DataBus though not sure about the latter yet — would it fit or not
> 5. Emergency swap must work via cowswop, can think about using stonks 2.0 for that because it has decent oracle protection built-in
> 6. ETH, WETH, stETH, wstETH, EarnETH, EarnUSD, USDC, USDT, USDS, sUSDS, CowSwap access, Lido Lend access (which is basically Morpho Blue compat), LDO
> 7. It does not; it holds ET global pause and it's fine

Recorded as, by question: (1) signer-set drift: keeping the emergency Safe's signers equal to the committee's is a manual runbook duty ([ADR 005](/adr/005-account-graph-and-roles.md)); (2) the committee is the trusted caller of the onboarding factories ([ADR 006](/adr/006-governance-through-easy-track-factories.md)); (3) the minimum per motion is forum disclosure, alerting and runbook discipline, and the stops are an objection or the Easy Track pause ([ADR 006](/adr/006-governance-through-easy-track-factories.md)); (4) exposure caps are enforced by detection and reporting on immutable storage ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)); (5) the emergency swap runs through CoW, with Stonks 2.0 as the candidate ([ADR 007](/adr/007-swapping-through-an-orders-account.md)); (6) the launch assets and venues ([ADR 011](/adr/011-launch-scope.md)); (7) the Emergency Brakes multisig keeps only the Easy Track pause. EM changed (7) at 12:16 and gave it the technical role. [s1]

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
