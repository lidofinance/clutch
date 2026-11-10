---
type: Research Note
title: The orders account's motion roles and the exit-governance role on a fork, 2026-11-08
description: "The orders modifier's governance and approvals roles (ADR 007, decisions 41 and 44) and the safety modifier's exit-governance role (ADR 006, decision 13; ADR 007, decision 45), each held by the Easy Track executor: what a motion may write, the compiler's new rules, and the fork tests, up to the writes of a motion that adds a token, run by hand."
tags: [swaps, cow, orders, emergency, policy, governance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-08
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-11-08T10:58:07Z
verified: []
sources:
  - id: s1
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — decision 41, the orders modifier's governance and approvals roles; decisions 44 and 45 of 2026-11-08
  - id: s2
    resource: /research/orders-account-fork-tests-2026-11-07.md
    title: The orders account's policy on a fork, 2026-11-07 — the operator and emergency roles, and what was left unbuilt
  - id: s3
    resource: "https://github.com/lidofinance/clutch/tree/7d7f539c2cc1ae90ef4d1ffb6a3533a44a1e3637/policy/constellation/constellation"
    title: The constellation at 7d7f539 — the orders modifier's governance and approvals roles, the exit-governance role, and the shared trees
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/7d7f539c2cc1ae90ef4d1ffb6a3533a44a1e3637/test/OrdersAccount.t.sol"
    title: The orders account's fork tests at 7d7f539
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/7d7f539c2cc1ae90ef4d1ffb6a3533a44a1e3637/policy/constellation/compiler/compile.ts"
    title: The policy compiler at 7d7f539 — grants with branches, the keys of each modifier and the delegatecall rule for grants
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/7d7f539c2cc1ae90ef4d1ffb6a3533a44a1e3637/policy/constellation/compiler/compile.test.ts"
    title: The compiler's tests at 7d7f539 — the three roles, the refused grants and the form of a tree with a new token
  - id: s7
    resource: /specs/invariants.md
    title: Invariants — INV-002, INV-004, INV-008, INV-025 and INV-040
  - id: s8
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — decision 13, the exit-governance role on the safety modifier (OD-49)
  - id: s9
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — the universal factory, its address book, its shapes and the exits they write
  - id: s10
    resource: /registers/decision-log.md
    title: The decision log — OD-101 of 2026-11-05, no Aragon vote after launch; EM's decisions of 2026-11-08
  - id: s11
    resource: "https://github.com/lidofinance/clutch/blob/7d7f539c2cc1ae90ef4d1ffb6a3533a44a1e3637/test/ExitGovernance.t.sol"
    title: The exit-governance role's fork tests at 7d7f539
---

# The orders account's motion roles and the exit-governance role on a fork, 2026-11-08

Decision 41 of ADR 007 gives the orders modifier a governance role and an approvals role, both held by the Easy Track executor. A motion adds a token to the order lists, on the sell side and the buy side, with its relayer approval, its emergency transfer and its recovery orders, and the governance role grants delegatecall only to the order signer [s1]. The research note of 2026-11-07 built the orders account's operator and emergency roles and left these two roles unbuilt [s2]. This work builds them, and the exit-governance role that ADR 006 decision 13 put on the safety modifier [s8], extends the compiler, and tests the three roles on the fork of block 26249900 that the enabling vote sets up. EM accepted the pinned design and asked for the exit-governance role on 2026-11-08 (ADR 007, decisions 44 and 45) [s10]. Nothing is deployed, and the universal factory does not yet write through any of the three roles.

## What was built

- **The orders modifier's governance role** [s3]. It scopes a target under the `operator`, `emergency` or `approvals` key, and it writes five kinds of function permission:
  - signer orders, for the operator and the emergency role: `signOrder` on the order signer, by delegatecall, the one delegatecall that a motion may grant;
  - TWAP orders, for the operator: `createWithContext` on ComposableCoW;
  - the return of a token to the Asset Safe or the Aragon Agent, for the operator and the emergency role;
  - the emergency role's zeroing of CoW's vault relayer's approval;
  - under the approvals key, the relayer approval.

  The last three trees do not depend on the token, so each is pinned whole: a grant's tree must equal, byte for byte, the tree that the role's own permission compiles to. `allowFunction` restores only the operator's two functions without conditions: the cancel of a signer order, by delegatecall, and the removal of a TWAP order. Every grant refuses the vault's accounts as the administered target, as on the operator modifier (OD-38). The role holds no membership setter, no `allowTarget`, no revoke and no `setAllowance`, and it cannot write under its own key.
- **The approvals role** [s3]. It approves CoW's vault relayer, for any amount, for the eight tokens that an order sells. A motion can so raise an approval that the emergency role set to zero.
- **The exit-governance role** [s3]. On the safety modifier, it writes the emergency role's exit for a target that a motion names, and nothing else. Its exits are the emergency role's own kinds, each tree pinned whole: a transfer to the Aragon Agent, or to the Agent or the orders account for a token that a recovery order sells; an approval set to zero, for any spender; an ERC-4626 redeem or withdrawal from the Asset Safe's own shares, paid to the Asset Safe; and a queue's claim, paid to the Asset Safe. Without conditions it writes only the exits that act for the calling Safe alone: cancelling a pending deposit, a redeem queue's redeem, and unwrapping a wrapper or WETH. It writes under the `emergency` key only, as plain calls, and it refuses the vault's accounts as targets, so it cannot reach the switch.
- **The compiler** [s5]. A grant's condition can now be an Or of branches. In each branch the administered target must refuse every vault account with Nor, or be pinned to an account outside them, such as the order signer. Three new rules apply to every grant. It pins the role key, never to its own role's key, and only to the keys that its modifier lets a motion write: the operator's on the operator modifier, the emergency role's on the safety modifier, and the operator's, the emergency role's and the approvals role's on the orders modifier. If its execution options could carry delegatecall, it must be on the orders modifier, for the order signer, with `signOrder` only by `scopeFunction` and `unsignOrder` either way. A signer order without a condition is refused, because it would pay anyone.
- **One source per tree.** Each pinned tree comes from one builder, which both the role that holds the permission and the role that writes it use: the orders account's return, zeroing and relayer approval, and the emergency role's exits on the Asset Safe. The two cannot drift apart.

## Why the governance role writes under the approvals key

INV-040, as first drafted, let the governance role write only under the `operator` and `emergency` keys [s7]. Decision 41 needs more. A token that a motion adds needs its own relayer approval, and the approvals role can approve only a token for which it holds a permission. A Roles permission names its target, so no permission covers a token that is not known yet. The governance role therefore writes the approvals role's permission for the new token, and the pin limits that write to the relayer approval itself. The approvals role's own invariant, that it approves only CoW's vault relayer, then holds against any motion. EM accepted this amendment of INV-040 on 2026-11-08 (ADR 007, decision 44).

## What the guards pin, and what they leave to the factory

The pins keep three invariants against any motion, not only in the compiled policy. Only the approvals role raises an approval on the orders account, and the emergency role only sets one to zero (INV-008). A transfer out of the orders account goes only to the Asset Safe or the Agent, and the emergency role's transfers out of the Asset Safe go only to the Agent or the orders account (INV-002). An exit that a motion writes is one of the emergency role's own kinds (INV-025) [s7]. The orders account's signer and TWAP trees cannot be pinned, because they carry the token lists, which change with each token. For them the guard pins the key, the target, the function and the execution options, and the universal factory's shape must build the tree itself, with its receiver, life and token lists (ADR 013) [s9]. Which target gets which exit is also the shape's choice. As on the operator modifier, the deny-list of vault accounts is necessary and not sufficient.

`allowFunction` on the orders modifier is there because the emergency role can revoke the operator's cancels one by one. Roles then deletes a function without conditions, and without the grant only a DAO vote could bring it back. EM decided on 2026-11-05 that no administrative action needs an Aragon vote after launch (OD-101) [s10]. A revoked target comes back by `scopeTarget`, and a revoked signer order, TWAP order or transfer comes back when a motion writes its tree again.

## Why the exit-governance role is built now

An operator order pays the Asset Safe, so a token that a motion adds to the order lists can arrive there. The emergency role on the safety modifier can move only the tokens that its permissions name, and before this work no motion could add one: the safety modifier had no motion role. Such a token could have left the Asset Safe only by DAO vote. The exit-governance role closes the gap, and the motion that adds a token also writes the token's exit on the Asset Safe: a transfer to the Agent or to the orders account, where a recovery order sells it (ADR 007, decision 45). The exit is the same kind of transfer that the emergency role holds for every launch token that recovery sells (decision 19).

## The form of a tree with a new token

The SDK sorts each token list, an Or of EqualTo leaves, by value. Adding a token therefore inserts one leaf in its sorted place in each list. The two TWAP shapes keep their order, because they first differ in their part counts, before any token. A compiler test checks this rule against the SDK on the operator's signer and TWAP trees and on the recovery tree, for a token that sorts first, one in the middle and one last [s6]. A factory that writes the trees by this rule keeps the compiler's form, so the trees on chain can be compared with a compile.

## The fork tests

Each test runs on the vault that the enabling vote sets up. Easy Track's executor makes each motion role's calls, as an enacted motion would [s4][s11].

| What INV-040, INV-025 and decisions 41, 44 and 45 ask for | Test | Result |
|---|---|---|
| Orders governance writes only under its keys, never on a vault account, and no membership or administration | `test_orders_governance_writes_only_its_keys_and_targets` | Scoping a target under the operator, emergency and approvals keys passes. The role's own key, another key, the orders account, the orders modifier, the Asset Safe and both of its modifiers are refused. So are `assignRoles`, `setDefaultRole`, `allowTarget`, both revokes, `setAllowance`, and the role for any member but the executor. |
| Delegatecall only for the order signer | `test_orders_governance_grants_delegatecall_only_for_the_signer` | The policy's own signer, TWAP and transfer trees can be written again, and the operator's two cancels restored. Refused: delegatecall to ComposableCoW, Both for the signer, `unsignOrder` by `scopeFunction`, a signer order under the approvals key, Send, `signOrder` without a condition, a restore for the emergency role, and any other function without conditions. |
| Transfers and approvals on the orders account pinned whole | `test_orders_governance_pins_transfers_and_approvals` | The return, the sweep and the zeroing can be written for a new token. Refused: another receiver, `transferFrom`, any approval for the operator, a non-zero approval for the emergency role, the zeroing under the approvals key, and TWAP orders for the emergency role, on another target or for another function. |
| Restores after an emergency revoke, with no DAO vote | `test_orders_governance_restores_what_the_emergency_role_revoked` | After the emergency role revokes the order signer as a target, `scopeTarget` brings signing back. After it revokes `unsignOrder`, `allowFunction` brings the cancel back. After it revokes `signOrder`, the tree written again brings it back. |
| The approvals role approves only CoW's vault relayer | `test_orders_approvals_role_approves_only_the_relayer` | The executor raises USDT's approval after the emergency role zeroes it. Another spender, a transfer, a delegatecall, a token outside the lists and another member are refused. For a new token, governance writes the relayer approval; another spender, an extra condition, Send, another function and a permission without conditions are refused. |
| Exit-governance writes only exits | `test_exit_governance_writes_only_exits` | Each of the five pinned exits and the four exits without conditions can be written for a new target. Refused: the operator's, the restart role's, the governance role's and its own key; another receiver, a non-zero approval, a claim paid to another account, one exit's tree for another exit, `transferFrom` and `deposit`; Send and delegatecall; a transfer, an approval or a deposit without conditions; every vault account as a target; membership, administration and any member but the executor. |
| A new token's exit on the Asset Safe (decision 45) | `test_exit_governance_gives_a_new_token_its_exit` | Before the exit, the emergency role cannot move the token out of the Asset Safe. After it, the emergency role sends the token to the Agent and to the orders account, and a transfer or approval to another account is refused. |
| An onboarded vault's exit | `test_exit_governance_exits_an_erc4626_position` | For a stand-in ERC-4626 position, the emergency role cannot redeem before the exit. After it, it redeems and withdraws to the Asset Safe from the Asset Safe's own shares, and a redeem or withdrawal paid to or taken from another account is refused. The stand-in is Spark's savings DAI; no decision lists it. |
| A motion adds a token, end to end | `test_orders_motion_adds_a_token` | The motion's writes, run by hand, add a stand-in token to the operator's signer and TWAP lists on both sides and to the recovery orders' sell side, with its relayer approval, the emergency role's zeroing and sweep, the operator's return and the token's exit on the Asset Safe. An operator order that sells it settles and pays the Asset Safe. The emergency role then moves the token from the Asset Safe to the orders account, and a recovery order that sells it settles and pays the Agent. Recovery still buys only USDC or USDT, and the operator's orders still pay only the Asset Safe. The stand-in is WBTC; no decision lists it. |

## Checks

- The fork suite passes 93 tests: the kit's 53, and at block 26249900 the rehearsal's 6, the factory's 18, the orders account's 13 and the exit-governance role's 3.
- 23 mutants of the orders modifier's two roles and 13 of the exit-governance role, each of which weakens one rule, are each refused by the compiler (9) or fail at least one fork test (27). The mutants ran from local scripts, not in the repository.
- The compiler passes 51 tests, 17 of them new: the three roles against the compiled artifacts, the compiler's refusal of each kind of weakened grant, the keys of each modifier, and the form of a tree with a new token.

## Measures

| Measure | Value |
|---|---|
| The rehearsal's policy | 209 calls: 135 on the Asset Safe's modifiers and 74 on the orders modifier |
| The Asset Safe's batch | 137 calls, 11,268,619 gas, 110,148 bytes |
| The orders account's batch | 85 calls, 8,070,716 gas, 85,188 bytes |
| A vote that would carry the policy itself | 197,732 bytes and 117,885,603 gas: above both the transaction pool's limit of 131,072 bytes and EIP-7825's cap |
| The universal factory | 12,845 bytes of EIP-170's 24,576, unchanged |

Every batch still fits one transaction under EIP-7825's cap of 16,777,216 gas and the transaction pool's limit. The Asset Safe's batch uses 84 percent of that limit, and the batch builder splits a Safe's calls by gas alone, so the next shapes need a split by size as well.

## Open for the next slice

- **The factory's shape for an orders token.** It writes on three modifiers: on the orders modifier, through the governance and approvals roles; on the operator modifier, the operator's transfer of the token into the orders account under a key derived for it, through the existing governance role; and on the safety modifier, the token's exit, through the exit-governance role. It must build the signer and TWAP trees from the token lists, by the rule above. Whether that fits in the factory's 11,731 free bytes is a measure for the build; a stateless builder contract that the factory calls is the fallback.
- **The batch builder.** A split by size, before the Asset Safe's batch reaches the transaction pool's limit.
- **A lending market's exit.** If Lido Lend's position is a market compatible with Morpho Blue rather than an ERC-4626 vault, its exit, a withdrawal paid to the Asset Safe from the Asset Safe's own position, is not yet among the exit-governance role's kinds. The Lido Lend shape adds it, with its tree pinned whole, before the enabling vote.

## Not tested, and not built

- The universal factory's shape that writes a token motion, the onboarding shapes that write exits, and their runs through Easy Track. The writes here run by hand.
- The orders account's restore through the factory. The restores here run by hand.
- The order book's acceptance of zero app data and the watch-tower's posting of TWAP parts, as on 2026-11-07.
