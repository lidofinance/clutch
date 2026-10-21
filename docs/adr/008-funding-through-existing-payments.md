---
type: Decision
title: "ADR 008: Funding through the existing payment path"
description: Funding through Finance and registries, first-loss shares and the procedural launch cap.
tags: [funding, finance, easy-track, acl]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/opus-5.5
  at: 2026-10-21T20:39:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the payment ceilings and DAI, 2026-09-22, on OD-06, 2026-10-02, on the funding assets, the legacy investments and the first-loss shares in an emergency, 2026-10-05, on the first-loss role and its burn, 2026-10-13, and on the mandate size, 2026-10-21
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Finance, the payment ACL chain, budgets and an existing top-up factory
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — funding
  - id: s4
    resource: /research/funding-registries-2026-10-02.md
    title: Easy Track funding registries, 2026-10-02 — how a registry counts, and the live registries
  - id: s5
    resource: "urn:clutch:restricted:mandate-draft-v0.1"
    title: Mandate draft v0.1 — seeding, the monthly top-up, the runway protection and the legacy investments; outside the repository until the mandate is published
  - id: s6
    resource: /research/legacy-investments-2026-10-05.md
    title: Legacy investments, 2026-10-05 — the first-loss Earn shares, their Growth Committee holder, transferability, and the Twyne search
  - id: s7
    resource: /research/cfo-feedback-2026-10-13.md
    title: The committee's feedback of 2026-10-12 — the first-loss terms of March 2026, the Kelp burn, and the time that a DAO vote takes
---

# ADR 008: Funding through the existing payment path

## Context

Chain reads use block 26092572 [s2]; registry reads use 26105012 [s4].

- Finance pays from the Aragon Agent [s2]. Easy Track's payment permission has 22 ACL parameters, constraining token argument 0 and amount argument 2, but not receiver argument 1 [s2].
- Per-payment ceilings: stETH 1,000; ETH 1,000; DAI, USDC, USDT and sUSDS 2,000,000 each; LDO 5,000,000. Other tokens, including USDS, are denied [s2]. At block 26125804 this was unchanged; the Agent held no USDS and some sUSDS [s4].
- Voting administers the shared DAI/USDT/USDC/sUSDS token list [s4] and the payment permission. A vote rewrites the whole parameter array [s2].
- Finance budgets are off for USDC, DAI and stETH, adding no second cap [s2].
- Registry periods are 1, 2, 3, 6 or 12 calendar months, starting on the 1st at 00:00 UTC. Limits apply at creation and enactment. A boundary permits two full limits within about 72 hours [s4].
- Registries scale decimals, so 1 stETH counts as 1 USDC. A shared limit cannot express a dollar cap for both [s4].
- Only the admin changes limits or periods, by DAO vote. Existing registries use the Agent as admin [s4].
- No live registry uses one month: five use three, four use six and three use twelve. The committee's Safe is trusted caller for two [s4].
- Top-up factories fix the payment reference; motions cannot include a report identifier [s4].
- The March 2026 Snapshot approved the DAO's first-loss Earn allocation. A Growth Committee Safe holds 1,362.84 earnETH and 1,998,416.46 earnUSD shares. At the read, shares transfer freely and the holder can burn them. Checked Lido addresses hold no Twyne position [s6].
- March 2026 terms let the Earn team instruct the executing committee to burn up to all of the DAO's shares in that vault after a curator-confirmed loss of at least 1%. On confirmed material risk, the Earn team may instruct normal redemption. Neither action needs a vote. An incident update is due within seven days; the DAO can change or end authorization at any time [s7].
- Kelp's April 2026 loss was below 1%. A Snapshot allowed a one-time exception, executed on 2026-05-15 as one `burn` call [s7].
- Agent actions through a DAO vote take about nine days through Dual Governance, plus an omnibus slot [s7].
- Mandate draft v0.1 set a floor, the TM Floor Value: a seed up to it, less the carried-over investments, and monthly top-ups back to it within ten calendar days. Its runway protection allowed stETH funding up to that floor. It valued stETH at the Coingecko price of each motion, and an objection controlled each top-up [s5]. On 2026-10-21 EM replaced the floor with the mandate size of the mandate's later draft text (decisions 32 to 34) [s1].

## Decision

EM decided on 2026-09-22 [s1]:

1. Investigate the payment ceilings and what must change to reach the mandate size.
2. Add DAI to the launch set, which also lets DAI seed the vault.

EM decided on 2026-10-02, closing OD-06 [s1]:

3. The registry period is one calendar month.
4. Two registries carry the funding, one for stablecoins and one for stETH. Each has a limit of one TM Floor Value per period. Stablecoins count at par. The stETH limit is the floor at the Coingecko price pinned when the enabling vote is prepared, set by attested computation.
5. The objection is the control, and the registry is the backstop. The LIP states the two gaps: the registry can delay a permitted stETH refill after an ETH fall, and it allows more than one floor a month.
6. Monitoring flags a top-up motion outside days 1 to 10 of a month, apart from the seed; a month's top-ups above the shortfall posted on the forum; and any top-up motion after an objected one.
7. The screening policy carries a dollar rule per top-up motion, if the screening vendor supports it (OD-07).
8. The DAO re-pins the stETH limit by vote when needed.

EM decided on 2026-10-05, closing OD-11 [s1]:

9. A DAO vote rewrites the shared payment permission of the Easy Track executor to add USDS. The other entries stay as they are.
10. The stablecoin registry uses the shared stablecoin token list, with USDS added. It then allows DAI, USDT, USDC, sUSDS and USDS.
11. ETH is not a funding asset. stETH covers the mandate's "(st)ETH".
12. The rewritten permission allows at most 2,000,000 USDS per payment, the same as DAI, USDC, USDT and sUSDS (OD-24).

EM decided on 2026-10-05, closing OD-21 [s1]:

13. After the enabling vote, the Growth Committee transfers the DAO's first-loss shares in EarnETH and EarnUSD from its Safe to the Asset Safe.
14. The Treasury Management mandate takes over the first-loss terms of the March 2026 Earn allocation.
15. Each first-loss burn is a DAO vote.
16. A written rule forbids the operator from redeeming the first-loss shares.
17. A Twyne position reduces the seed only when its holder and form are shown on chain or in a signed record.

EM decided on 2026-10-05, closing OD-28 [s1]:

18. The no-redeem rule binds the emergency role too. In an emergency, the emergency role sends the first-loss shares to the Aragon Agent. It never redeems below the first-loss amount. A burn or a redemption of the first-loss shares is a DAO vote.

EM decided on 2026-10-06, closing OD-42 [s1]:

19. The Growth Committee transfers the first-loss shares to a dedicated first-loss Safe, not to the Asset Safe. The first-loss Safe is owned by the Aragon Agent at one of one and has no modules, so no role can reach the shares. A burn or a redemption is a DAO vote that has the first-loss Safe act. This replaces the destination of decision 13. Decisions 14, 15 and 17 stand. Decisions 16 and 18 give way to the structure: no role can reach the shares, so no written rule is needed and the emergency role has nothing to send.

EM decided on 2026-10-08 and 2026-10-09, closing OD-54 and OD-55 [s1]:

20. Until the screening guard is live, the vault's funding stops at a cap of one million dollars on the Asset Safe and the orders account ([ADR 010](/adr/010-pre-execution-screening.md) decisions 20 to 22). The registries keep the period and the limits of decisions 3 and 4. The committee requests a top-up only while the vault stays at or below the cap. A forum post lifts the cap once the guard is set on the operator Safe with its bypass mode off.

EM decided on 2026-10-13, after the committee's feedback, closing OD-60 [s1]:

21. The first-loss Safe gets one Roles modifier, the first-loss modifier, with one `first-loss` role that the operator Safe holds. The role may burn the DAO's own earnETH and earnUSD shares, and request and claim their redemption with the proceeds pinned to the Aragon Agent. It may not transfer or approve the shares. The Aragon Agent stays the first-loss Safe's only owner.
22. The committee executes the first-loss terms of the March 2026 Earn allocation, in place of the Growth Committee, on the Earn team's written instruction.

Decisions 21 and 22 replace decision 15, the burn and the redemption by DAO vote in decisions 18 and 19, and "has no modules, so no role can reach the shares" in decision 19. Decision 14 stands, with the committee as the executor. The operator still cannot reach the shares, and the emergency role still has nothing to send, so decisions 16 and 18 stay given way.

EM decided on 2026-10-13, closing OD-67 [s1]:

23. No first-loss burn runs without the objection window. A burn runs only as an Easy Track motion: the operator Safe creates it, and after the window the Easy Track executor burns the shares through a `first-loss-burn` role on the first-loss modifier. The operator Safe's `first-loss` role keeps the redemption and the claim, paid to the Aragon Agent.

Decision 23 replaces the burn in decision 21. The redemption and the claim stay as decision 21 says.

EM decided on 2026-10-14, closing OD-71 and OD-66 [s1]:

24. A new TM Floor Value is a mandate change, so its DAO vote is by design. A shortfall in stETH is topped up in stablecoins, so a re-pin of the stETH limit is optional.
25. One Snapshot sets a standing framework for insurance funds. Then each new fund needs one Easy Track motion.
26. Payouts from an insurance fund run as Easy Track motions.
27. The roles and the factories for insurance funds ship with the launch.
28. An exit from an insurance fund stays with the operator Safe's direct role, with the proceeds paid to the Aragon Agent.
29. The framework fixes a checklist that every fund fills in, in its motion and its forum post: the product, and its share token or payout address; the template; the fund's cap; the loss trigger and a confirming party independent of the product team; the incident-update deadline; and the end of the terms.
30. A third funding registry and top-up factory pay only the first-loss Safe, within a limit, and ship with the launch.

Decision 24 makes the re-pin of decision 8 optional. Decisions 25 to 30 close OD-66; EM corrected the agent's first reading of decision 25 the same day. Since OD-73, Aragon Voting owns the first-loss Safe and administers the vault's funding registries ([ADR 005](/adr/005-account-graph-and-roles.md) decision 28).

EM decided on 2026-10-14, after a count of the launch, closing OD-78 [s1]:

31. Insurance funds do not ship with the launch: no fund roles on the first-loss modifier, no fund templates, and no third funding registry or top-up factory. A later vote adds them; decisions 25, 26, 28 and 29 describe them for that vote.

Decision 31 replaces decisions 27 and 30.

Since OD-80, the committee's own Safe holds the first-loss role of decisions 21 and 23 and creates the burn motions ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31).

EM decided on 2026-10-21, closing OD-89 [s1]:

32. The mandate size follows the mandate's draft text. The vault holds up to the mandate size in assets. Each funding counts in US dollars at its value when it is funded. The legacy positions that move into the vault count too.
33. The vault never holds more than the mandate's share of the DAO's non-LDO treasury.
34. More funding than the mandate size needs a separate DAO approval. A further funding or a replenishment uses an approved governance path only when the mandate's published eligibility conditions are met, and after the required disclosure.

Decisions 32 to 34 replace the floor of the context and of decisions 4 and 5, and the monthly refill behind decision 6: the mandate size is a ceiling, and no top-up refills the vault to it by right. Where an earlier decision of this ADR, ADR 007, ADR 009 or ADR 011 names one TM Floor Value, it now means one mandate size. Decision 24 stands for a new mandate size. Decisions 3, 4 and 7 stand as the registries' backstop. The proposed direction adapts the alerts of decision 6 to the headroom under the size; its alert on a top-up after an objected one stands.

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **USDS permission.** One vote rewrites the array, retaining seven entries and adding USDS at 2,000,000 per payment (decision 12). Fork-test the array before the vote.
- **Multiple payments.** A motion can repeat the Asset Safe as recipient, respecting each call's ceiling. Ceilings apply per call, not per motion [s4].
- **Registries.** Two standard-builder registries pay only the Asset Safe, with Voting as admin ([ADR 005](/adr/005-account-graph-and-roles.md), decision 28). As in the committee's registries, the executor cannot add recipients [s4].
- **Factories.** One uses the shared stablecoin list after USDS is added; one is stETH-only. Both fix the committee's Safe as trusted caller, as [ADR 006](/adr/006-governance-through-easy-track-factories.md) requires. The DAO registers them.
- **Limits.** Stablecoins use the mandate size at par; stETH uses the size divided by the pinned price. Attested computation produces both; they enter this repository when the mandate is approved. Each limit is a backstop: it allows more than the headroom under the size, so the size holds by procedure, objection and monitoring, as the launch cap does (decision 20).
- **Seed.** Use the same registries, up to the mandate size less the transferred first-loss shares at the attested Earn oracle valuation (decision 32). Count Twyne only when evidenced (decision 17). Transfer shares before the seed motion. Before lift, the seed also stays within the cap (decision 20).
- **Capped top-ups.** The forum post states snapshot value and cap headroom under [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 20. During objection, monitoring flags motions that would exceed the cap. First-loss is outside it.
- **Funded value.** Monitoring keeps the vault's funded value: the first-loss shares at their value on the day of the transfer, and each top-up at its value on the day of its enactment, by the report's price rule ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md), decision 35). Each top-up's forum post states the funded value, the headroom under the mandate size, and the vault's share of the DAO's non-LDO treasury.
- **Funding alerts.** Monitoring flags a top-up above the headroom that its forum post states; a top-up motion that would take the vault above the mandate size or the treasury share, while its objection window is open; a fortnightly reading above the treasury share; and any top-up motion after an objected one. The days 1 to 10 window of decision 6 ends with the monthly refill.
- **Treasury share.** The mandate owes three definitions: the base of the share, the time of its test, and the remedy for a breach that no vault transaction causes, such as the treasury's own spending or a price move (decision 33).
- **First-loss custody.** Plain transfers fund the first-loss Safe without a permission. That Safe is its modifier's owner, avatar and target.
- **First-loss burn.** The committee creates a motion naming an amount and pinned earnETH or earnUSD. After 72 hours without objection, the executor calls `burn` through `first-loss-burn` (decision 23). Burns always wait, including urgent ones.
- **First-loss exit.** The committee's `first-loss` role calls `redeem` and `claim` on the vault's queue, paying only the Agent (decision 21).
- **Instructions and reporting.** The Earn team's written instruction is required: curator-confirmed loss of at least 1% for burns, confirmed material risk for exits. Publish the instruction and curator confirmation with the motion; update the incident within seven days [s7]. Below the terms, obtain a Snapshot exception first, as for Kelp. First-loss equals received shares less burns; reports show it as a sub-allocation. Monitor balance, owner, module and singleton changes; page on every burn motion and first-loss-role action ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- **Top-up reports.** Put the report identifier in the required pre-top-up forum post; the fixed payment reference provides no on-chain anchor. No top-up motion starts with a late monthly report or unpriced snapshot asset ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- **Funding assets.** USDC, USDT, DAI, USDS, sUSDS and stETH. Exclude ETH; the Agent holds less than 8 ETH [s4].

## Options considered

- Raise shared ceilings: EM rejected this under OD-11; retain them and add USDS. Higher ceilings would widen other setups' grants.
- Add a vault-only payment permission: EM rejected under OD-11 because shared configuration avoids another ACL entry.
- Fund only by DAO vote: EM rejected under OD-06. The mandate uses Easy Track [s5]; votes add Dual Governance delay to each payment.
- Three-month periods: EM rejected because a permitted monthly refill could wait until the next quarter.
- Price stETH limits for stress: rejected because it adds capacity above one floor for speed the mandate does not require.
- Split one floor between registries: rejected because neither asset could provide a full permitted refill.
- One dollar registry with a DAO-pinned stETH rate: EM rejected as new contract code. A live rate would break enactment's rebuilt-script hash check [s4].
- Leave the shared permission unchanged: EM rejected because USDS could never fund the vault.
- Vault-only USDC/USDT/DAI list: rejected because EM added USDS and sUSDS and retained the shared list.
- ETH funding with a third registry/factory: rejected because the Agent holds less than 8 ETH.
- Leave first-loss shares with Growth: EM rejected the agent's recommendation, which preserved existing terms without a written rule.
- Hold first-loss in the Asset Safe with a written no-redeem rule: EM replaced this on 2026-10-06 (OD-42). Shares were indistinguishable from purchased shares, leaving only monitoring.
- Growth redeems first-loss and seeds in full: rejected because it ends approved protection.
- DAO votes for every burn/redemption: EM replaced on 2026-10-13 (decision 21). Roughly nine days through Dual Governance exceeds the inherited terms' timing [s7].
- Committee-owned first-loss Safe: EM rejected because the committee would take full custody.
- Emergency first-loss redemption: EM rejected because exit before a flagged loss would front-run protected depositors.
- Deduct Twyne now, as the mandate states: EM rejected because its holder and form remain unproved.
- Keep the floor of mandate draft v0.1: EM replaced it on 2026-10-21 (OD-89), because the mandate's draft text sets a ceiling.

## Consequences

- Without objection, the committee can draw one mandate size per registry per month, or two within about 72 hours across a boundary. The mandate size and the treasury share hold by procedure; the LIP must disclose this.
- After an ETH fall, the stETH limit is worth less than the mandate size; after a rise, it is worth more. The size counts each funding at its value when funded, so the limit stays a backstop.
- The one-month period was chosen for a monthly refill, which the mandate no longer has. It stays as the backstop's period until the mandate publishes the eligibility conditions of a replenishment.
- The treasury share can break without a vault transaction, through the treasury's own spending or a price move. Until the mandate states the remedy, monitoring can report the breach, but no rule defines the response.
- Every top-up uses the committee's Safe and the 72-hour objection window. After cap lift, the guard also screens it.
- Registries cannot require a Snapshot after an objected top-up. Monitoring, further objections and a DAO vote zeroing the limit provide the controls.
- Limit or period changes require DAO votes. Per-call ceilings do not limit whole motions; registry limits provide that backstop.
- Adding USDS changes the DAO-wide payment permission and every setup sharing the stablecoin list. The vote must disclose this. Voting's later list changes also change Clutch's funding assets.
- sUSDS funding immediately counts against the yield-bearing cap ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). Registries count it at par despite its value above one dollar, admitting slightly more value. The mandate must add sUSDS beyond its stETH/top-four stablecoin list.
- Before lift, registry limits exceed the cap. Procedure, objection and monitoring enforce it (decision 20). The mandate must state the capped phase, its scope and the lifting forum post.
- The ACL leaves the receiver open; the registry and factory bind it one layer above. Both layers are necessary.
- Separate first-loss custody distinguishes protected shares from ordinary Asset Safe positions. Only enacted burns or Agent-only redemptions can reach the first-loss Safe (decisions 21 and 23); the no-redeem rule needs no written check.
- On Earn instructions, the committee proposes burns or exits without a DAO vote. Capital still absorbs losses first; curator freezes can delay redemption [s7].
- Burns wait at least 72 hours, later than a Growth Committee burn would, and LDO holders can block them by objection. Public notice lets depositors time entry or exit. The vault should pause deposits and redemptions until burn, as after Kelp [s7]. March 2026 terms allowed urgent burns before notice; public motions remove that option [s7].
- A compromised committee quorum cannot burn immediately. It can propose a publicly visible 72-hour motion or redeem only to the Agent. Burns transfer value to other depositors, so each motion pages monitoring. Emergency cannot reach the first-loss Safe; the DAO can remove both roles.
- Burns reduce the vault's value. No top-up refills it by right: a replenishment needs the mandate's published eligibility conditions (decision 34).
- The move depends on Earn administrators keeping share transfers open until it happens; they can restrict transfers [s6].
- Without evidence of a Twyne holder, Twyne does not reduce the seed; the seed can exceed the mandate's figure.

## Confirmation

- INV-017 and INV-021 in the [invariants](/specs/invariants.md).
- Fork tests still owed:
  - Growth-to-first-loss share transfers.
  - Burns only through enacted `first-loss-burn` motions, with all other callers refused.
  - Committee `first-loss` redemption pays only the Agent and cannot transfer, approve or burn.
  - Asset Safe modifier roles cannot reach the first-loss Safe.
  - Top-ups pay only the Asset Safe; limits hold at creation and enactment.
  - Motions from a month's last 72 hours count against the next month.
  - Multi-payment stETH motions respect each per-payment ceiling.
  - Only the committee's Safe can create motions.

## Reversal conditions

- The DAO declines to widen USDS payments for every stablecoin setup, so the vote that rewrites the permission fails.
- The mandate's eligibility conditions call for a period other than one calendar month (decision 3).
- Top-ups above the headroom under the mandate size happen. That would argue for one dollar limit on chain.
- The Earn vaults block share transfers before the move.
- The first-loss terms end. A DAO vote then moves the shares to the Asset Safe as ordinary positions.
- The DAO changes or ends the first-loss authorisation. A DAO vote then changes or removes the two first-loss roles and the burn factory.
- A top-up takes the vault above the cap before the lift (decision 20).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->

- Twyne: who holds the position, and in what form. The mandate's drafters owe the evidence (decision 17).
- The treasury share's base and test time, the remedy for a breach that no vault transaction causes, and the eligibility conditions of a replenishment. The mandate's drafters owe them (decisions 33 and 34).
