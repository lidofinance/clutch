---
type: Decision
title: "ADR 008: Funding through the existing payment path"
description: The vault is seeded and topped up through Aragon Finance and two dedicated allowed-recipients registries, one for stablecoins and one for stETH, each with a one-month period and a limit of one TM Floor Value; the objection is the control and the registry is the backstop; the shared payment ACL stays unchanged.
tags: [funding, finance, easy-track, acl]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-10-02T14:07:21Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the payment ceilings and DAI, 2026-09-22, and on OD-06, 2026-10-02
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
---

# ADR 008: Funding through the existing payment path

## Context

Facts from the chain reads were read at block 26092572 [s2]. Facts about the registries were read at block 26105012 [s4].

- Aragon Finance pays out of the Aragon Agent [s2].
- The Easy Track executor holds the payment permission on Finance with 22 ACL parameters. They bind argument 0, the token, and argument 2, the amount. Argument 1, the receiver, is not constrained [s2].
- The per-payment ceilings are stETH 1,000, ETH 1,000, DAI 2,000,000, USDC 2,000,000, USDT 2,000,000, sUSDS 2,000,000 and LDO 5,000,000. Every other token is denied. USDS is not in the chain [s2].
- Aragon Voting manages the permission. A change rewrites the whole parameter array by vote [s2].
- Finance token budgets are off for USDC, DAI and stETH, so Finance adds no second cap [s2].
- A registry's period is 1, 2, 3, 6 or 12 calendar months, and it starts on the 1st at 00:00 UTC. The limit is checked when a motion starts and again when it is enacted. Around a period boundary, two full limits can be paid within about 72 hours [s4].
- A registry counts token units after scaling decimals, so 1 stETH counts as 1 USDC. One limit cannot hold stablecoins and stETH to a dollar figure [s4].
- Only a registry's admin, the Aragon Agent, sets its limit and its period. A change is a DAO vote [s4].
- No live registry uses a one-month period. Five use three months, four use six months and three use twelve months. The committee's Safe is already the trusted caller of two of them [s4].
- The standard top-up factory writes a fixed payment reference. A motion cannot carry a report's identifier in it [s4].
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

## Proposed direction

The rest of this section is agent-drafted [s3]. EM has not accepted it as text.

- **The shared ACL stays unchanged.** The same permission serves every Easy Track payment setup, so a change would raise the ceiling for all of them (OD-11).
- **Several payments in one motion.** A motion repeats the Asset Safe as recipient, one payment per ceiling. The ceilings are per call, not per motion [s4].
- **Two registries from the standard builder.** Each has the Asset Safe as its only recipient and the Aragon Agent as admin. As on the committee's registries, the Easy Track executor gets no role to add recipients [s4].
- **Two top-up factories.** The stablecoin factory uses a token list for the vault alone (OD-11). The stETH factory is the single-token version. The operator Safe is the trusted caller of both, as of every factory ([ADR 006](/adr/006-governance-through-easy-track-factories.md)). The DAO registers them by vote.
- **The figures.** The stablecoin limit is the TM Floor Value at par. The stETH limit is the floor divided by the pinned price. An attested computation produces both, and they enter this repository when the mandate is approved.
- **The seed.** The same registries carry the seed. It is at most one floor, less the legacy investments (OD-21).
- **The report.** The factory fixes the payment reference, so a top-up's report identifier goes in the forum post that the mandate requires before each top-up. Where to anchor it on chain is part of OD-14.
- **Seeding assets.** Seed in USDC, USDT, DAI or stETH. The vault acquires USDS inside itself. The Agent holds less than 8 ETH, so ETH needs no top-up path (OD-11) [s4].

## Options considered

- Raise the shared ceilings by vote. Not recommended: it widens a grant that other setups share, and the whole array must be rewritten.
- A new payment permission for the vault alone. Not recommended: it adds an ACL grant where configuration is enough.
- Fund by DAO vote only. Not recommended: every top-up would then carry the vote and the Dual Governance delay, and the mandate puts seeding and top-ups on Easy Track [s5].
- A period of three months. Not chosen by EM: a refill that the mandate allows in one month could wait for the next quarter.
- A stETH limit at a stress price. Not chosen: it buys refill speed that the mandate does not require, with capacity beyond one floor.
- One floor split between the two registries. Not chosen: neither asset could then carry a full refill, which the mandate permits.
- One registry with one dollar limit, through a token registry that counts stETH at a DAO-pinned rate. Not chosen by EM: it needs a new contract. A live rate would block enactment, because Easy Track rebuilds the script and checks its hash [s4].

## Consequences

- Without an objection, the operator Safe can pull one floor per registry each month, and two per registry within about 72 hours around a month boundary. The mandate's limit on size is a procedure, not code. The LIP must say so.
- After an ETH fall, a refill in stETH alone reaches less than the floor in one month. The rest follows the next month or in stablecoins. After an ETH rise, the stETH limit is worth more than a floor.
- The operator Safe creates every top-up motion, so each one passes the screening guard and the 72-hour objection window.
- The registry cannot enforce the mandate's rule that, after an objection, the manager needs a Snapshot vote to pull more funds. The controls are monitoring, a further objection, and a DAO vote that sets the limit to zero.
- A change of a limit or the period is a DAO vote.
- A per-payment ceiling is not a per-motion ceiling. The registry limit is the backstop that matters.
- USDS cannot enter through this path.
- The receiver is bound one layer above the ACL, in the registry and the factory. Both layers are needed.

## Confirmation

- INV-017 in the [invariants](/specs/invariants.md).
- Fork tests owed: a top-up motion pays the Asset Safe and fails for any other recipient; the limit holds at motion start and at enactment; a motion created in the last 72 hours of a month counts against the next month; a stETH motion with several payments, each under the per-payment ceiling; only the operator Safe can create a motion.

## Reversal conditions

- The mandate requires seeding in USDS.
- The mandate moves the top-up away from a monthly cycle.
- Top-ups above the shortfall or outside the cycle happen. That would argue for one dollar limit on chain.

## Open questions

- OD-11: confirm that the shared ACL parameters stay unchanged, the vault's token list and the seeding assets.
- OD-21: who holds the legacy investments, and how they move into the vault.
- OD-07: whether the screening vendor's policy can check a dollar limit per top-up motion.
- OD-14: where to anchor a report's identifier on chain.
