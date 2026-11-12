---
type: Research Note
title: The universal factory with raw writes, a prototype, 2026-11-12
description: "The report that ADR 013 decision 11 asks for before the switch to raw writes, and the prototype that EM's choice of 2026-11-12 led to: the typed factory's size and gas, the raw factory's size and gas, what one raw motion can onboard, and what the factory no longer checks."
tags: [factory, easy-track, governance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-12
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:00:25Z
verified: []
sources:
  - id: s1
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — decision 11, the fallback to raw writes and the report before it
  - id: s2
    resource: /registers/decision-log.md
    title: Decision log — EM's request for a wider factory and EM's choice of raw writes, 2026-11-12
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/5b7dd199adfdd68f4d81fbd6f8ffefd26f8beb9e/src/factory/RawFactory.sol#L19-L156"
    title: The raw factory's prototype at 5b7dd19
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/5b7dd199adfdd68f4d81fbd6f8ffefd26f8beb9e/test/RawFactory.t.sol#L92-L295"
    title: The raw factory's fork tests at 5b7dd19, through the live Easy Track
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/5b7dd199adfdd68f4d81fbd6f8ffefd26f8beb9e/src/factory/UniversalFactory.sol"
    title: The typed factory at 5b7dd19, which the prototype stands beside
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/5b7dd199adfdd68f4d81fbd6f8ffefd26f8beb9e/src/factory/OrdersShape.sol"
    title: The typed factory's orders shape at 5b7dd19
---

# The universal factory with raw writes, a prototype, 2026-11-12

EM asked for a factory that accepts wider calldata, and then chose raw writes [s2]. [ADR 013](/adr/013-one-easy-track-factory.md) decision 11 asks for a report before that switch [s1]. This note is the report, with the prototype's measures. The prototype stands beside the typed factory. It deletes nothing.

## The typed factory, measured

- **Size.** The factory is 20,121 bytes and its orders shape 12,524: 32,645 bytes and 1,253 lines of new code, for 14 operations [s5][s6].
- **Where the size is.** About 140 of the factory's 500 function lines are the motion's core: the script, the one call, the versions and the counter. The rest, and the whole orders shape, builds and checks permissions.
- **Gas.** A budget motion enacts in 220,544 gas, and the heaviest motion, a token for the orders account, in 7,893,034. Gas is not the reason for the switch.
- **Complexity.** Every shape exists twice: in the policy compiler and in Solidity. Tests hold the two equal. Each new kind of protocol needs new Solidity, an audit and, after launch, an Aragon vote.

## The raw factory, measured

| Measure | Typed | Raw |
|---|---|---|
| Runtime bytes | 20,121, plus 12,524 for the orders shape | 3,337 |
| Source lines | 1,253 | 156 |
| A budget motion, enactment gas | 220,544 | 218,792 |
| Sixteen budgets in one motion, enactment gas | 2,908,197 | 2,376,661 |
| A new ERC-4626 vault in one motion | not built; needs a shape | 9 writes, 2,124,133 gas |

All gas figures are enactments through the live Easy Track on a fork of block 26249900 [s4].

## What the prototype does

- A motion is a list of raw writes. Each write names one of the vault's four modifiers, a role, a target and the call's data. The factory makes each as that role, as a plain call without value [s3].
- The factory builds no permission and reads no content. Each modifier's own policy decides what a role may write.
- It keeps three gates: only the committee's Safe creates a motion, only Easy Track's executor applies one, and a motion names only the four modifiers [s3].
- It keeps two numbers. The counter fails every open motion when the emergency Safe or Aragon Voting raises it. The policy version rises with each enacted motion that writes on a modifier itself, and such a motion fails if the version moved after its creation [s3].
- A motion that only acts, such as a burn, a payout or a restart, states the counter alone. An unrelated permission motion does not fail it [s4].

## What the tests show

1. One motion onboards an ERC-4626 lending vault that the launch policy does not know, with no code for its kind: the operator's approval under a budget key, its deposit, redeem and withdraw with the receiver and the owner pinned to the Asset Safe, and the emergency role's exits. The operator then lends within the budget and no further, and the emergency role exits [s4]. The vault is a WETH vault on Morpho Blue. It stands in for the lender vault of Lido Lend's WETH market.
2. The modifiers' guards still bind a raw motion. A grant on a vault account, a grant with delegatecall, a budget with a refill period below 30 days and a write under the governance role's own key each fail the whole motion [s4].
3. A raw motion can do what a typed shape refused. One write gives the operator a transfer of WETH to any address, with no budget, and the operator then sends all of it to a stranger [s4]. Only an objection in the 72 hours stops such a motion.
4. Of two permission motions created at the same policy version, the second to enact fails [s4].
5. A restart, insurance money with its budget and a first-loss burn run as raw writes [s4].

Six mutants of the prototype each fail one of the nine tests.

## What the factory no longer checks

- That a widened permission pins its receivers to the vault.
- That an approval spends a budget key or stays below a cap.
- Budget ceilings, approval caps, the raise rule and a token's introduction.
- That an onboarding writes its emergency exit. The motion's author adds the exit, and reviewers check it.
- That one fund exists for each token, and that a payout names its fund's terms.

The policy's own guards stay: no vault account as an administered target, no delegatecall except the order signer's, writes only under the allowed role keys, budget keys only in the launch or the derived form, the 30-day floor on a refill period, and the emergency exits and the orders account's fixed permissions pinned whole.

## What the switch will change

The switch replaces the typed factory with the raw one, and it is not in this change.

- **Code.** The typed factory and its orders shape go. The fork tests of the typed operations become tests of raw motions, or go where they test a check that no longer exists.
- **Tooling.** The `motion` command builds a motion's writes from a merged policy change, and a second command checks that a motion's writes equal that change. These two commands carry what the typed checks carried.
- **Pages.** ADR 013 decisions 7, 9, 10, 13 and 15, the ceilings of ADR 009 and ADR 011, INV-033, INV-034 and INV-036, the threat model, the LIP draft and the guide.
- **Monitoring.** An alert on a budget that a motion raises more than twofold can replace the ceiling as a detective control.

## Limits of this note

- The prototype's roles come from each modifier's owner in the tests, not from the enabling vote. The switch moves them into the vote.
- The size and the gas are the prototype's. The switch can change them.
- No audit has read the prototype.
