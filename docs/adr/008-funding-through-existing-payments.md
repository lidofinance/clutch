---
type: Decision
title: "ADR 008: Funding through the existing payment path"
description: The vault is seeded and topped up through Aragon Finance and two dedicated allowed-recipients registries, one for stablecoins and one for stETH, each with a one-month period and a limit of one TM Floor Value; the objection is the control and the registry is the backstop; a DAO vote adds USDS to the shared payment permission and to the shared stablecoin token list; ETH is not a funding asset; the DAO's first-loss Earn shares move in from the Growth Committee and reduce the seed.
tags: [funding, finance, easy-track, acl]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T19:30:52Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the payment ceilings and DAI, 2026-09-22, on OD-06, 2026-10-02, and on the funding assets and the legacy investments, 2026-10-05
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
---

# ADR 008: Funding through the existing payment path

## Context

Facts from the chain reads were read at block 26092572 [s2]. Facts about the registries were read at block 26105012 [s4].

- Aragon Finance pays out of the Aragon Agent [s2].
- The Easy Track executor holds the payment permission on Finance with 22 ACL parameters. They bind argument 0, the token, and argument 2, the amount. Argument 1, the receiver, is not constrained [s2].
- The per-payment ceilings are stETH 1,000, ETH 1,000, DAI 2,000,000, USDC 2,000,000, USDT 2,000,000, sUSDS 2,000,000 and LDO 5,000,000. Every other token is denied. USDS is not in the chain [s2]. The chain was unchanged at block 26125804, when the Agent held no USDS and some sUSDS [s4].
- The shared stablecoin token list allows DAI, USDT, USDC and sUSDS, and Aragon Voting administers it [s4].
- Aragon Voting manages the permission. A change rewrites the whole parameter array by vote [s2].
- Finance token budgets are off for USDC, DAI and stETH, so Finance adds no second cap [s2].
- A registry's period is 1, 2, 3, 6 or 12 calendar months, and it starts on the 1st at 00:00 UTC. The limit is checked when a motion starts and again when it is enacted. Around a period boundary, two full limits can be paid within about 72 hours [s4].
- A registry counts token units after scaling decimals, so 1 stETH counts as 1 USDC. One limit cannot hold stablecoins and stETH to a dollar figure [s4].
- Only a registry's admin, the Aragon Agent, sets its limit and its period. A change is a DAO vote [s4].
- No live registry uses a one-month period. Five use three months, four use six months and three use twelve months. The committee's Safe is already the trusted caller of two of them [s4].
- The standard top-up factory writes a fixed payment reference. A motion cannot carry a report's identifier in it [s4].
- The legacy Earn positions are the DAO's first-loss allocation to Lido Earn, approved by Snapshot in March 2026. A Growth Committee Safe holds 1,362.84 earnETH and 1,998,416.46 earnUSD shares. The shares transfer freely today, and their holder executes a burn. No Lido address checked holds a Twyne position [s6].
- The mandate's funding rules [s5]. A motion seeds the vault in stETH or stablecoins, up to the TM Floor Value. The legacy investments carry over into the vault and reduce the seed. After each month-end snapshot, a top-up may refill the vault to the floor within ten calendar days. Under the runway protection, that top-up may be paid in stETH, up to the floor. A non-stablecoin balance is valued at the motion, at the Coingecko price. The objection is the control of a top-up.

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

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **The shared permission gains USDS.** The vote rewrites the whole parameter array as one unit. The seven existing entries stay, and USDS joins with a ceiling of 2,000,000 per payment (decision 12). A fork test of the new array is owed before the vote.
- **Several payments in one motion.** A motion repeats the Asset Safe as recipient, one payment per ceiling. The ceilings are per call, not per motion [s4].
- **Two registries from the standard builder.** Each has the Asset Safe as its only recipient and the Aragon Agent as admin. As on the committee's registries, the Easy Track executor gets no role to add recipients [s4].
- **Two top-up factories.** The stablecoin factory uses the shared stablecoin token list, after the vote adds USDS to it. The stETH factory is the single-token version. The operator Safe is the trusted caller of both, as of every factory ([ADR 006](/adr/006-governance-through-easy-track-factories.md)). The DAO registers them by vote.
- **The figures.** The stablecoin limit is the TM Floor Value at par. The stETH limit is the floor divided by the pinned price. An attested computation produces both, and they enter this repository when the mandate is approved.
- **The seed.** The same registries carry the seed. It is at most one floor, less the value of the first-loss shares that arrive from the Growth Committee, set by attested computation at the Earn oracle price. Twyne counts only when shown (decision 17). The seed motion follows the share transfer.
- **The first-loss shares.** The Asset Safe receives them by plain transfer and needs no permission for it. A burn is a DAO vote that has the Asset Safe call `burn` on the share token. The first-loss amount is the shares received, less any burn. In an emergency, the emergency role sends them to the Agent instead of redeeming them, and the Agent can still burn them by vote. Monitoring alerts when the Asset Safe's earnETH or earnUSD balance falls below the first-loss amount ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- **The report.** The factory fixes the payment reference, so a top-up's report identifier goes in the forum post that the mandate requires before each top-up. There is no on-chain anchor. No top-up motion starts while the monthly report is late or the snapshot has an unpriced asset ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).
- **Funding assets.** USDC, USDT, DAI, USDS, sUSDS and stETH. ETH is not a funding asset: the Agent holds less than 8 ETH [s4].

## Options considered

- Raise the shared ceilings by vote. Not chosen by EM: the vote adds USDS and keeps the other ceilings (OD-11). Raising them widens a grant that other setups share.
- A new payment permission for the vault alone. Not chosen by EM: the vote rewrites the shared permission instead (OD-11). A separate grant adds an ACL entry where configuration is enough.
- Fund by DAO vote only. Not chosen by EM: the funding runs through two Easy Track registries (OD-06). Every top-up would otherwise carry the vote and the Dual Governance delay, and the mandate puts seeding and top-ups on Easy Track [s5].
- A period of three months. Not chosen by EM: a refill that the mandate allows in one month could wait for the next quarter.
- A stETH limit at a stress price. Not chosen: it buys refill speed that the mandate does not require, with capacity beyond one floor.
- One floor split between the two registries. Not chosen: neither asset could then carry a full refill, which the mandate permits.
- One registry with one dollar limit, through a token registry that counts stETH at a DAO-pinned rate. Not chosen by EM: it needs a new contract. A live rate would block enactment, because Easy Track rebuilds the script and checks its hash [s4].
- Keep the shared permission unchanged. Not chosen by EM: USDS could then never fund the vault.
- A token list for the vault alone, with USDC, USDT and DAI. Not chosen by EM: EM added USDS and sUSDS to the funding assets and kept the shared list.
- ETH as a funding asset, with a third registry and factory. Not chosen: the Agent holds less than 8 ETH.
- The first-loss shares stay with the Growth Committee and only count toward the vault. Not chosen by EM. The agent had recommended it, because it keeps the first-loss terms as approved and needs no written rule.
- The Growth Committee redeems the shares, and the seed is funded in full. Not chosen: it ends the first-loss protection that the DAO approved.
- Twyne counts against the seed now, as the mandate states. Not chosen by EM: no holder or form has been shown.

## Consequences

- Without an objection, the operator Safe can pull one floor per registry each month, and two per registry within about 72 hours around a month boundary. The mandate's limit on size is a procedure, not code. The LIP must say so.
- After an ETH fall, a refill in stETH alone reaches less than the floor in one month. The rest follows the next month or in stablecoins. After an ETH rise, the stETH limit is worth more than a floor.
- The operator Safe creates every top-up motion, so each one passes the screening guard and the 72-hour objection window.
- The registry cannot enforce the mandate's rule that, after an objection, the manager needs a Snapshot vote to pull more funds. The controls are monitoring, a further objection, and a DAO vote that sets the limit to zero.
- A change of a limit or the period is a DAO vote.
- A per-payment ceiling is not a per-motion ceiling. The registry limit is the backstop that matters.
- USDS can fund the vault once the vote rewrites the permission.
- The rewrite is DAO-wide. Every Easy Track payment setup shares the permission, and every stablecoin setup that shares the token list can then pay USDS too. The vote must say so.
- Aragon Voting administers the shared token list, so a change made for another setup also changes the vault's funding assets.
- sUSDS is a yield-bearing stablecoin. A top-up in sUSDS counts at once against its yield-bearing cap ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)). The registry counts it at par, although one sUSDS is worth more than one dollar, so the limit admits slightly more value in sUSDS.
- The mandate limits funding to stETH and the top-four stablecoins, and sUSDS is not one of them. The mandate text owes a change.
- The receiver is bound one layer above the ACL, in the registry and the factory. Both layers are needed.
- The vault holds first-loss capital. Its earnETH and earnUSD shares can then mean two things: the first-loss amount, and any shares the operator buys. The chain cannot tell them apart, so the no-redeem rule is procedural, and monitoring is its only check.
- Each first-loss burn waits for a DAO vote and the Dual Governance timelock, so it comes later than a burn by the Growth Committee would.
- A burn lowers the vault's value, and the next monthly top-up refills the vault to the floor from the treasury.
- The move needs the Earn vaults to keep share transfers open until it happens. Their administrators can restrict transfers [s6].
- Until a Twyne holder is shown, Twyne does not reduce the seed, so the seed can be larger than the mandate's figure.

## Confirmation

- INV-017 in the [invariants](/specs/invariants.md).
- Fork tests owed: the first-loss shares transfer from the Growth Committee Safe to the Asset Safe, and a DAO-vote path burns them from the Asset Safe; a top-up motion pays the Asset Safe and fails for any other recipient; the limit holds at motion start and at enactment; a motion created in the last 72 hours of a month counts against the next month; a stETH motion with several payments, each under the per-payment ceiling; only the operator Safe can create a motion.

## Reversal conditions

- The DAO declines to widen USDS payments for every stablecoin setup, so the vote that rewrites the permission fails.
- The mandate moves the top-up away from a monthly cycle.
- Top-ups above the shortfall or outside the cycle happen. That would argue for one dollar limit on chain.
- The Earn vaults block share transfers before the move.
- The first-loss terms end. The shares then become ordinary vault positions.

## Open questions

- Twyne: who holds the position, and in what form. The mandate's drafters owe the evidence (decision 17).
