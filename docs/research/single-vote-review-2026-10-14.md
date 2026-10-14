---
type: Research Note
title: One Aragon vote to launch, Easy Track afterwards, 2026-10-14
description: The evidence behind OD-68 to OD-72 — whether Clutch launches with one Aragon vote and then runs without another in non-emergency operation; how one vote carries Voting items and Agent items; the five places where routine operation still needs a vote; the votes that stay by design; and who holds Easy Track's admin role, read on chain.
tags: [governance, easy-track, enabling-vote, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-14
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-14T16:47:06Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions to OD-67, 2026-10-13
  - id: s2
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — the accounts, the roles, the switch and the restart
  - id: s3
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — the factories, the templates, and removals by the emergency Safe
  - id: s4
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the orders account, its lists, its relayer approvals and its one modifier
  - id: s5
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — the registries, the payment permission, the shared token list and the first-loss Safe
  - id: s6
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — budget keys, the events that change them, and the Lido Lend key
  - id: s7
    resource: "https://github.com/lidofinance/clutch/blob/73b804b73cc862f99b2e917afe9127d6e724d056/policy/constellation/constellation/roles/governance/permissions.ts#L33-L67"
    title: Clutch policy at 73b804b — the governance role sets only the budget keys compiled into the policy
  - id: s8
    resource: "https://github.com/lidofinance/clutch/blob/73b804b73cc862f99b2e917afe9127d6e724d056/policy/constellation/constellation/allowances/index.ts#L7-L8"
    title: Clutch policy at 73b804b — one budget key per protocol spender
  - id: s9
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/payouts/multi-token/AllowedRecipientsBuilder.sol#L101-L190"
    title: Easy Track AllowedRecipientsBuilder at 3183d1f — the builder sets the limit at deployment and leaves the role with the admin alone
  - id: s10
    resource: /runbooks/index.md
    title: Runbook list — the switch, the restart and the funding limit
  - id: s11
    resource: /specs/lip-draft.md
    title: LIP draft — the template catalogue and the budget factory
  - id: s12
    resource: "https://github.com/lidofinance/clutch/blob/73b804b73cc862f99b2e917afe9127d6e724d056/script/DeployDryRun.s.sol#L79-L108"
    title: Clutch dry-run deployment at 73b804b — the Safe is created with the Agent as only owner, and the owner enables the modifiers
  - id: s13
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea"
    title: Easy Track — its role holders, read at block 26192012 with the commands below
---

# One Aragon vote to launch, Easy Track afterwards

On 2026-10-14 EM asked whether Clutch needs only one Aragon vote to launch, and whether everything else in non-emergency operation runs through Easy Track. The review read every passage that names a vote, then checked each mechanism in the policy source, the deployment script and on chain. Two further passes, one independent and one that re-derived each claim, reached the same answer.

## The answer

- **Launch: one Aragon vote, by design.** No page listed what the vote holds. [The enabling vote](/specs/enabling-vote.md) now does.
- **After launch: not yet.** Routine operation still needs an Aragon vote in five places. OD-68 to OD-72 track them.

## How one vote carries two kinds of item

- Aragon Voting holds Easy Track's admin role, and the Aragon Agent does not [s13]. Registering a factory is therefore a Voting item.
- The Aragon Agent is the only owner of the Asset Safe, the orders account and the first-loss Safe. The owner enables their modifiers and applies their policies [s12][s2]. These are Agent items, which pass Dual Governance.
- One vote carries both kinds. The Voting items run when the vote executes. The Agent items run after the Dual Governance timelock.
- Easy Track's standard builder sets each registry's limit and period when it deploys the registry, and then gives that role up. The registry's admin keeps it, and the Easy Track executor never gets it [s9]. So the launch limits need no vote, and every later change does.

## Five places where routine operation still needs a vote

1. **The orders account (OD-68).** It has no governance role, and the order signer's permission is a delegatecall, which no motion may write [s4][s3]. A new token, a change of the lists or of an order bound, and a permission granted again after a revoke all need a vote.
2. **Budget keys (OD-69).** There is one key per protocol spender [s8]. The governance role sets only the keys compiled into the policy [s7]. A spender that the enabling vote did not know, such as a replaced Earn deposit queue, needs a vote. ADR 009 already says this for the Lido Lend key [s6].
3. **Removals (OD-70).** Every removal is the emergency Safe's revoke of a whole target or function [s3]. Removing one spender also takes away the operator's permission to approve any other spender of that token. Staking, the DAI–USDS converter, the fixed-ceiling approvals and the transfers into the orders account have no template, so only a vote grants them again [s3].
4. **The TM Floor Value and the stETH limit (OD-71).** Only the registry's admin, the Aragon Agent, changes a limit [s5][s9], and the fixed approval ceilings are compiled into the policy. A new TM Floor Value is therefore a vote. ADR 008 re-pins the stETH limit "by vote when needed" [s5].
5. **New shapes and rewards (OD-72).** A shape outside the five templates needs a factory registered by vote [s3][s11]. The design has no path to claim rewards, and a reward token also needs the orders lists.

## Votes by design

These change who holds power, or the DAO's own bounds [s2][s3][s5][s11]:

- role membership;
- replacing a Safe, a modifier or a factory;
- delegatecall for the operator;
- another module on the Asset Safe, or a change of its Safe version;
- the shared payment permission and the shared token list;
- ending or changing the first-loss terms.

## After an emergency

- The restart after the switch is a vote (OD-59) [s1][s2]. The switch also revokes the operator on the orders account [s10], so the same vote must grant those permissions again, with any relayer approval that the emergency role set to zero [s4].
- An Easy Track unpause is a vote.

## Defects found, and fixed with this note

- The restart runbook and ADR 005's restart missed the orders account.
- Stale text: ADR 005 gave the orders account a governance role; ADR 011 said that no role reaches the first-loss Safe; INV-023 named two modifiers on the orders account; the roadmap and the parameters register named only the `first-loss` role; the guide's summaries of the vote left out the shared token list.
- No page said how a template adds a spender to a token's `approve` without dropping the others, although a write replaces the whole tree [s3]. ADR 006 now states the requirement.

## How to reproduce

Set `ETH_RPC_URL` in your shell. Never write the URL into a file.

```bash
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea
VOTING=0x2e59A20f205bB85a89C53f1936454680651E618e
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c
ADMIN=0x0000000000000000000000000000000000000000000000000000000000000000
cast call $ET 'hasRole(bytes32,address)(bool)' $ADMIN $VOTING --block 26192012   # true
cast call $ET 'hasRole(bytes32,address)(bool)' $ADMIN $AGENT --block 26192012    # false
cast call $ET 'evmScriptExecutor()(address)' --block 26192012                    # 0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977
```
