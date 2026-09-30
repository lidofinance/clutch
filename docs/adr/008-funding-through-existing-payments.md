---
type: Decision
title: "ADR 008: Funding through the existing payment path"
description: The vault is seeded and topped up through Aragon Finance and a dedicated allowed-recipients registry; the shared payment ACL stays unchanged, so seeding uses USDC, USDT, DAI, stETH or ETH.
tags: [funding, finance, easy-track, acl]
status: draft
review_status: slop
decision: proposed
constrains_operator: true
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on the payment ceilings and DAI, 2026-09-22
  - id: s2
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads, 2026-09-30 — Finance, the payment ACL chain, budgets and an existing top-up factory
  - id: s3
    resource: /specs/lip-draft.md
    title: LIP draft — funding
---

# ADR 008: Funding through the existing payment path

## Context

All facts below were read at block 26092572 [s2].

- Aragon Finance pays out of the Aragon Agent.
- The Easy Track executor holds the payment permission on Finance with 22 ACL parameters. They bind argument 0, the token, and argument 2, the amount. Argument 1, the receiver, is not constrained.
- The per-payment ceilings are stETH 1,000, ETH 1,000, DAI 2,000,000, USDC 2,000,000, USDT 2,000,000, sUSDS 2,000,000 and LDO 5,000,000. Every other token is denied. USDS is not in the chain.
- Aragon Voting manages the permission. A change rewrites the whole parameter array by vote.
- Finance token budgets are off for USDC, DAI and stETH, so Finance adds no second cap.
- An existing top-up factory already has the committee's Safe as its trusted caller. Its registry limits spending per period.

## Decision

EM decided on 2026-09-22 [s1]:

1. Investigate the payment ceilings and what must change to reach the mandate size.
2. Add DAI to the launch set, which also lets DAI seed the vault.

## Proposed direction

The rest of this section is an agent recommendation [s3]. EM has not accepted it (open item OD-11).

- Do not change the shared ACL parameters. The same permission serves every Easy Track payment setup, so a change would raise the ceiling for all of them.
- Seed and top up through several payments inside one motion. The ceilings are per call, not per motion.
- Let a dedicated `AllowedRecipientsRegistry` carry the real limit. Its only recipient is the Asset Safe. Its period limit follows the mandate's top-up rule.
- Add a token registry for the launch assets, and a `TopUpAllowedRecipients` factory with the committee's Safe as trusted caller, registered by DAO vote.
- Seed in USDC, USDT, DAI, stETH or ETH. The vault acquires USDS inside itself.
- Where a report justifies a top-up, put its IPFS content identifier in the payment's `reference` field ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)).

## Options considered

- Raise the shared ceilings by vote. Not recommended: it widens a grant that other setups share, and the whole array must be rewritten.
- A new payment permission for the vault alone. Not recommended: it adds an ACL grant where configuration is enough.
- Fund by DAO vote only. Not recommended: every top-up would then carry the vote and the Dual Governance delay.

## Consequences

- A per-payment ceiling is not a per-motion ceiling. The registry period limit is the control that matters, and it must be sized on purpose (OD-06).
- USDS cannot enter through this path.
- The receiver is bound one layer above the ACL, in the registry and the factory. Both layers are needed.

## Confirmation

- None yet. A fork test of a top-up motion that pays the Asset Safe, and fails for any other recipient, is owed.

## Reversal conditions

- The mandate requires seeding in USDS.
- The registry period cannot express the mandate's top-up rule.

## Open questions

- OD-06: the registry period and limit.
- OD-11: confirm that the shared ACL parameters stay unchanged.
