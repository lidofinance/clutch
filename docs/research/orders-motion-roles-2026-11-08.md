---
type: Research Note
title: The orders account's motion roles and the exit-governance role on a fork, 2026-11-08
description: "The orders modifier's governance and approvals roles (ADR 007, decisions 41 and 44) and the safety modifier's exit-governance role (ADR 006, decision 13; ADR 007, decision 45), each held by the universal factory: what a motion may write, the compiler's new rules, and the fork tests, up to the writes of a motion that adds a token, run by hand."
tags: [swaps, cow, orders, emergency, policy, governance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-08
stale_after: 2027-02-28T00:00:00Z
superseded_by:
  ref: /research/raw-factory-prototype-2026-11-12.md
  note: "In part: since OD-134, the motion carries the signer and TWAP trees, and no shape of the factory builds them. The roles, their pins and the sorting rule stand."
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:38:25Z
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

This work builds the orders modifier's governance and approvals roles (ADR 007, decision 41) [s1], which the research note of 2026-11-07 left unbuilt [s2], and the exit-governance role that ADR 006 decision 13 put on the safety modifier [s8]. It extends the compiler, and tests the three roles on the fork of block 26249900 that the enabling vote sets up. The universal factory holds the three roles ([ADR 013](/adr/013-one-easy-track-factory.md) decision 18). EM accepted the pinned design and asked for the exit-governance role on 2026-11-08 (ADR 007, decisions 44 and 45) [s10]. Nothing is deployed.

## What was built

- **The orders modifier's governance role** [s3]. INV-040 and ADR 007 decisions 41 and 44 state what it writes. A grant's pinned tree must equal, byte for byte, the tree that the role's own permission compiles to. `allowFunction` restores only the operator's two functions without conditions: the cancel of a signer order, by delegatecall, and the removal of a TWAP order. The role holds no membership setter, no `allowTarget`, no revoke and no `setAllowance`, and it cannot write under its own key.
- **The approvals role** [s3]. It approves CoW's vault relayer, for any amount, for the eight tokens that an order sells. A motion can so raise an approval that the emergency role set to zero.
- **The exit-governance role** [s3]. On the safety modifier, it writes the emergency role's exit for a target that a motion names, and nothing else. INV-025 lists the exits. They do not include the exit of a market compatible with Morpho Blue: a withdrawal paid to the Asset Safe from the Asset Safe's own position. The Lido Lend shape must add it, with its tree pinned whole.
- **The compiler** [s5]. A grant's condition can be an Or of branches. In each branch the administered target must refuse every vault account with Nor, or be pinned to an account outside them, such as the order signer. Three rules apply to every grant. It pins the role key, never to its own role's key, and only to the keys that its modifier lets a motion write: the operator's on the operator modifier, the emergency role's on the safety modifier, and the operator's, the emergency role's and the approvals role's on the orders modifier. If its execution options could carry delegatecall, it must be on the orders modifier, for the order signer, with `signOrder` only by `scopeFunction` and `unsignOrder` either way. A signer order without a condition is refused, because it would pay anyone.
- **One source per tree.** Each pinned tree comes from one builder, which both the role that holds the permission and the role that writes it use. The two cannot drift apart.

## What the guards pin, and what they leave to the factory

The pins keep INV-008, INV-002 and INV-025 against any motion, not only in the compiled policy [s7]. The signer and TWAP trees cannot be pinned, because they carry the token lists. For them the guard pins the key, the target, the function and the execution options, and the universal factory's shape must build the tree itself (ADR 013) [s9]. As on the operator modifier, the deny-list of vault accounts is necessary and not sufficient.

Roles deletes a function without conditions when the emergency role revokes it, and `allowFunction` brings it back by motion. A revoked target comes back by `scopeTarget`, and a revoked signer order, TWAP order or transfer comes back when a motion writes its tree again.

## The form of a tree with a new token

The SDK sorts each token list, an Or of EqualTo leaves, by value. Adding a token therefore inserts one leaf in its sorted place in each list. The two TWAP shapes keep their order, because they first differ in their part counts, before any token. A compiler test checks this rule against the SDK on the operator's signer and TWAP trees and on the recovery tree, for a token that sorts first, one in the middle and one last [s6]. A factory that writes the trees by this rule keeps the compiler's form, so the trees on chain can be compared with a compile.

## The fork tests

Each test runs on the vault that the enabling vote sets up. Each motion role's member makes the role's calls, as an enacted motion would [s4][s11].

| What INV-040, INV-025 and decisions 41, 44 and 45 ask for | Test | Result |
|---|---|---|
| Orders governance writes only under its keys, never on a vault account, and no membership or administration | `test_orders_governance_writes_only_its_keys_and_targets` | Scoping a target under the operator, emergency and approvals keys passes. The role's own key, another key, the orders account, the orders modifier, the Asset Safe and both of its modifiers are refused. So are `assignRoles`, `setDefaultRole`, `allowTarget`, both revokes, `setAllowance`, and the role for any other member. |
| Delegatecall only for the order signer | `test_orders_governance_grants_delegatecall_only_for_the_signer` | The policy's own signer, TWAP and transfer trees can be written again, and the operator's two cancels restored. Refused: delegatecall to ComposableCoW, Both for the signer, `unsignOrder` by `scopeFunction`, a signer order under the approvals key, Send, `signOrder` without a condition, a restore for the emergency role, and any other function without conditions. |
| Transfers and approvals on the orders account pinned whole | `test_orders_governance_pins_transfers_and_approvals` | The return, the sweep and the zeroing can be written for a new token. Refused: another receiver, `transferFrom`, any approval for the operator, a non-zero approval for the emergency role, the zeroing under the approvals key, and TWAP orders for the emergency role, on another target or for another function. |
| Restores after an emergency revoke, with no DAO vote | `test_orders_governance_restores_what_the_emergency_role_revoked` | After the emergency role revokes the order signer as a target, `scopeTarget` brings signing back. After it revokes `unsignOrder`, `allowFunction` brings the cancel back. After it revokes `signOrder`, the tree written again brings it back. |
| The approvals role approves only CoW's vault relayer | `test_orders_approvals_role_approves_only_the_relayer` | The approvals role raises USDT's approval after the emergency role zeroes it. Another spender, a transfer, a delegatecall, a token outside the lists and another member are refused. For a new token, governance writes the relayer approval; another spender, an extra condition, Send, another function and a permission without conditions are refused. |
| Exit-governance writes only exits | `test_exit_governance_writes_only_exits` | Each of the five pinned exits and the four exits without conditions can be written for a new target. Refused: the operator's, the restart role's, the governance role's and its own key; another receiver, a non-zero approval, a claim paid to another account, one exit's tree for another exit, `transferFrom` and `deposit`; Send and delegatecall; a transfer, an approval or a deposit without conditions; every vault account as a target; membership, administration and any other member. |
| A new token's exit on the Asset Safe (decision 45) | `test_exit_governance_gives_a_new_token_its_exit` | Before the exit, the emergency role cannot move the token out of the Asset Safe. After it, the emergency role sends the token to the Agent and to the orders account, and a transfer or approval to another account is refused. |
| An onboarded vault's exit | `test_exit_governance_exits_an_erc4626_position` | For a stand-in ERC-4626 position, the emergency role cannot redeem before the exit. After it, it redeems and withdraws to the Asset Safe from the Asset Safe's own shares, and a redeem or withdrawal paid to or taken from another account is refused. The stand-in is Spark's savings DAI; no decision lists it. |
| A motion adds a token, end to end | `test_orders_motion_adds_a_token` | The motion's writes, run by hand, add a stand-in token to the operator's signer and TWAP lists on both sides and to the recovery orders' sell side, with its relayer approval, the emergency role's zeroing and sweep, the operator's return and the token's exit on the Asset Safe. An operator order that sells it settles and pays the Asset Safe. The emergency role then moves the token from the Asset Safe to the orders account, and a recovery order that sells it settles and pays the Agent. Recovery still buys only USDC or USDT, and the operator's orders still pay only the Asset Safe. The stand-in is WBTC; no decision lists it. |

## Checks

- 23 mutants of the orders modifier's two roles and 13 of the exit-governance role, each of which weakens one rule, are each refused by the compiler (9) or fail at least one fork test (27). The mutants ran from local scripts, not in the repository.
- The compiler's tests cover the three roles against the compiled artifacts, the compiler's refusal of each kind of weakened grant, the keys of each modifier, and the form of a tree with a new token [s6].

## Measures

| Measure | Value |
|---|---|
| The rehearsal's policy | 209 calls: 135 on the Asset Safe's modifiers and 74 on the orders modifier |
| The Asset Safe's batch | 137 calls, 11,268,619 gas, 110,148 bytes |
| The orders account's batch | 85 calls, 8,070,716 gas, 85,188 bytes |
| A vote that would carry the policy itself | 197,732 bytes and 117,885,603 gas: above both the transaction pool's limit of 131,072 bytes and EIP-7825's cap |
| The universal factory | 12,845 bytes of EIP-170's 24,576, unchanged |

Every batch fits one transaction under EIP-7825's cap of 16,777,216 gas and the transaction pool's limit. The Asset Safe's batch uses 84 percent of that limit. The batch builder splits a Safe's calls by gas alone, so it needs a split by size as well.
