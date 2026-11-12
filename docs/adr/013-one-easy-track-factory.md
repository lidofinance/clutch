---
type: Decision
title: "ADR 013: One Easy Track factory; Aragon votes after launch only for tranches and break-glass actions"
description: One universal Easy Track factory carries every Clutch motion as a list of raw writes, holds the motion roles and makes each motion's writes in one call; after the enabling vote, Aragon votes remain only for funding tranches, role holders and break-glass actions.
tags: [governance, easy-track, factory, raw-writes]
status: draft
review_status: slop
decision: proposed
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T19:10:44Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM on versions, the vote-free design, the factory, the restart, a motion's one call, the votes that remain, raw writes, the policy version, the check of a motion, the pending motion and removals, 2026-11-01 to 2026-11-12
  - id: s2
    resource: /research/easy-track-first-2026-11-05.md
    title: Research note — Easy Track's script permissions, enactment, cancel and pause; Roles storage; Merkle-root engines; the two-modifier alternative
  - id: s3
    resource: /research/raw-factory-prototype-2026-11-12.md
    title: Research note — the typed factory's size, gas and checks, and the raw factory's measures, 2026-11-12
---

# ADR 013: One Easy Track factory; Aragon votes after launch only for tranches and break-glass actions

## Context

- Easy Track lets a factory's scripts call only the addresses and functions registered with that factory. Aragon Voting holds the admin role that registers or removes a factory [s2].
- A factory's checks run at creation and again at enactment, because Easy Track rebuilds the script then ([ADR 006](/adr/006-governance-through-easy-track-factories.md) context) [s2].
- Motions have no order. Two motions that write the same function can both pass their checks, and the later enactment wins [s2].
- The Roles modifier keeps its trees in internal storage, so no contract can read them [s2].
- Easy Track's executor copies a script into memory three times for each call that the script makes, so a script's gas grows with its size times its calls. EIP-7825 caps a transaction at 16,777,216 gas ([research note](/research/orders-token-motions-2026-11-08.md)).

## Decision

EM decided each decision below; its ODs lead to EM's words in the [decision log](/registers/decision-log.md) [s1].

1. Clutch uses no Merkle-root policy. The Roles modifiers keep their permission trees (OD-100).
2. Easy Track motions carry versions, so that two motions cannot overwrite each other's changes (OD-100).
3. After the enabling vote, no administrative action needs an Aragon vote. An Easy Track motion is the most that an action needs. Removing complexity is the aim: fewer moving parts is the best outcome (OD-101).
4. These actions stay Aragon votes: each funding tranche ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 1); the replacement of a role holder, such as the committee's Safe in the operator role; an owner action on a vault Safe, such as a module, the Safe version or the owners; a new or changed factory; a removal on the safety modifier or on the orders modifier, whose motion roles hold no revoke; and the unpause of Easy Track, which only Aragon Voting can do (OD-101, OD-125, OD-138).
5. One universal Easy Track factory carries every Clutch motion (OD-102).
6. The factory's Easy Track registration is its address book: one call, the factory's own `applyMotion`. Nothing else is callable (OD-102, OD-118).
7. Replaced by decision 11 (OD-134).
8. The factory cannot be upgraded. A motion grants no delegatecall but the order signer's, and the guards against administrative targets and selectors stay ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 9 and 10) (OD-102, OD-103).
9. A motion sets the budget of a new spender under a derived key: `k:`, then the spender, then the token's first ten bytes. The governance role's policy accepts only the launch keys and the keys that start with `k:`, so the policy holds no spare keys (OD-102, OD-134).
10. The factory keeps one policy version and one counter. A motion that writes on one of the four modifiers states the policy version. The factory checks it at creation and again at enactment, so the motion fails if another such motion was enacted in between, and the enactment raises the version. A motion that only acts, such as a burn, a payout or a restart, states the counter alone. The emergency Safe can raise the counter, which makes every open motion fail (OD-100, OD-102, OD-118, OD-135).
11. A motion is a list of raw writes, which may also widen a permission. Each write names one of the four modifiers, a role, a target and the call's data, and the factory makes it as that role through that modifier. The factory builds no permission, checks no write's content and keeps no ceiling. The policy of each motion role on its modifier is the bound on what a write can do, and the objection window is the only bound on where funds go (OD-102, OD-134).
12. A motion, and no emergency body ([ADR 005](/adr/005-account-graph-and-roles.md) decision 26), restarts the operator after the emergency switch. A restart role on the safety modifier, held by the universal factory, may only enable the operator modifier on the Asset Safe (OD-104, OD-118).
13. Lapsed (OD-134): the factory keeps no ceiling.
14. The policy chains no second Roles modifier whose bounds only a vote changes. The policy of each motion role and the objection window give the bound (OD-112, OD-134).
15. Lapsed (OD-134): the factory keeps no ceiling, so no motion introduces a token.
16. A motion created after an emergency revoke may enact, and so bring the revoked permission back after its objection window. The policy version counts only the factory's own motions, not the emergency role's revokes; the counter fails the motions that were open when the emergency Safe raised it (OD-114).
17. Lapsed (OD-134): the factory has no shape, so it needs no companion contract.
18. The universal factory holds the motion roles. A motion's script makes one call, the factory's `applyMotion`. That call checks the motion again and makes its writes in order, all in the enactment's one transaction. A write that its modifier refuses fails the whole motion (OD-118).
19. The repository holds the pending motion: the pull request that changes the policy commits the motion's file and its base policy, and CI checks that the motion turns the base policy into the committed artifact. Monitoring checks every open motion of the factory: its calldata is the pending motion's, and the chain holds the base policy. A failure pages the emergency Safe, which raises the counter (OD-136, OD-137).

## Proposed direction

The rest of this section is agent-drafted. EM has not accepted it as text.

- **A motion's calldata.** It holds the counter and the policy version that the motion read, and the list of writes, at most 64. `decodeEVMScriptCallData` returns them as they are, so a reviewer reads the writes from the motion itself. A failed enactment reverts as a whole; the motion stays open until the committee's Safe or Aragon Voting cancels it [s2].
- **The factory's checks.** The creator is the committee's Safe. The counter is current. The motion has at least one write and at most 64. Each write names one of the four modifiers. If a write's target is one of the four modifiers, the policy version is current. The factory checks nothing else.
- **Roles.** The factory holds one role per kind of write: `governance` and `insurance-funding` on the operator modifier, `exit-governance` and `restart` on the safety modifier, the governance and approvals roles on the orders modifier, and `first-loss-burn` with the insurance roles on the first-loss modifier ([ADR 014](/adr/014-funding-by-tranche-votes.md)). Each role's policy holds the guards that stay ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decisions 8 to 10; INV-004, INV-021, INV-025, INV-035, INV-039, INV-040).
- **Motions at launch.** The table lists the motions that the fork suite builds from raw writes. It is no limit: a motion can carry any write that its role's policy accepts, so a new protocol needs no changed factory. Each permission tree arrives in the motion, and the policy's source in this repository is where it comes from (the `motion` command below).

| Motion | Writes | Fork test |
|---|---|---|
| Budget | the governance role's `setAllowance` for one key, with a period of at least 30 days | `test_03_ramp_up`, `test_factory_budget_motion_sets_a_launch_orders_budget` |
| Protocol onboarding | the operator's permissions for the target, the budget of each new spender under its derived key, and the emergency exits through the `exit-governance` role, with the zeroing of each new approval ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 13) | `test_uf_motion_onboards_an_erc4626_lending_vault`; `test_replay_the_example_motion` for a motion that the `motion` command built |
| A launch protocol | the same writes for a protocol of the launch policy, from the policy without it: Lido staking in 5 writes, WETH in 3, Sky in 15, earnUSD in 17 and earnETH in 17. A new protocol of the same form joins by the same writes, and a launch protocol that a DAO vote removed comes back by them | `test_launch_onboarding_of_lido_staking`, `test_launch_onboarding_of_weth`, `test_launch_onboarding_of_sky`, `test_launch_onboarding_of_earn_usd`, `test_launch_onboarding_of_earn_eth` |
| Lido Lend's lender vault | the onboarding of an ERC-4626 vault: the asset's `approve` to the vault under a derived key; `deposit`, `redeem` and `withdraw` with receiver and owner pinned to the avatar; the emergency role's `redeem`; no fallback exit and no settlement ([ADR 011](/adr/011-launch-scope.md) decision 13). Its address arrives with the motion (OD-49) | `test_uf_motion_onboards_an_erc4626_lending_vault`, against a deployed ERC-4626 vault as a stand-in |
| Orders account token | the token on both sides of signer and TWAP orders and in what recovery orders sell; its relayer approval; the emergency role's zeroing and transfer; the operator's transfer into the orders account under a derived key, with its return; that budget; and the token's exit on the Asset Safe ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decisions 41, 44 and 45) | `test_factory_orders_token_motion` |
| Orders account token retirement | the operator's signer and TWAP order trees, written again without the token; the token's transfer on the Asset Safe, written again with the Aragon Agent as the only receiver; and the token's orders budget set to zero. No revoke: the token keeps its return, its relayer approval, its recovery orders and its exit ([ADR 007](/adr/007-swapping-through-an-orders-account.md)) | `test_factory_orders_token_retirement` |
| Orders account restore | the operator's permissions on the orders account, written again, and the named relayer approvals ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 46) | `test_factory_orders_restore_after_an_emergency_stop` |
| Removal | a revoke of a target or a function, or a permission written again without the removed entries ([ADR 006](/adr/006-governance-through-easy-track-factories.md) decision 14) | `test_D1_change_type_2_target` and `test_D1_change_type_3_selector`, on the kit's mock Easy Track |
| Restore | `scopeTarget` for a target that the emergency role revoked; the function permissions that the modifier stored under it work again (decision 16) | `test_uf_restore_motion_brings_back_a_revoked_target` |
| Restart | `enableModule` for the operator modifier, through the `restart` role (decision 12) | `test_uf_restart_motion_after_the_switch` |
| Insurance money | a transfer from the Asset Safe to the first-loss Safe, which spends the key derived for the token and the first-loss Safe ([ADR 014](/adr/014-funding-by-tranche-votes.md) decisions 7 and 11) | `test_uf_insurance_money_goes_to_the_first_loss_safe` |
| Insurance deposit | the first-loss Safe's approval of an Earn deposit queue for the exact amount, and its deposit, through the `insurance` role ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 12) | `test_insurance_deposit_by_motion` |
| First-loss burn | `burn` through the `first-loss-burn` role ([ADR 008](/adr/008-funding-through-existing-payments.md) decision 23) | `test_first_loss_burn_by_motion` |
| Fund with a payout address | the `insurance` role's transfer of the token, pinned to the payout address, and the cap as a budget key that never refills, through the `insurance-governance` role ([ADR 014](/adr/014-funding-by-tranche-votes.md) decision 6) | `test_fund_create_and_payout_by_motion` |
| Fund payout | a transfer from the first-loss Safe to the fund's payout address, within what is left of the cap | `test_fund_create_and_payout_by_motion` |

- **The counter.** The emergency Safe raises it with every switch. Aragon Voting can raise it too.
- **The policy version.** It orders the motions that write permissions or budgets: of two such motions that are open together, the one that enacts second fails, and the committee creates it again. This is coarser than a version for each scope, and such motions are rare. An action, such as a burn or a payout, never waits for another motion.
- **The `motion` command.** `just motion <base> <head>` takes a policy change between two commits and reads the policy artifact that each commit holds. It builds the writes that turn the first policy into the second: the budgets, then the removals and the additions of each role. It takes the counter and the policy version from the factory or from its flags. It writes the motion's calldata, the list of its writes in words and a draft of the forum post. It refuses a change that no motion role can write, such as a membership, a removal on the safety modifier, or a write that the motion role's own policy refuses: that change needs a DAO vote. `just motion-replay` enacts the motion through the live Easy Track on a fork, on the rehearsal's vault with the first policy. The Zodiac UI does not know the factory's format, so it is not the planner.
- **The launch protocols' motions.** `just launch-motions` prints, for each protocol of the launch policy on the Asset Safe, the motion that onboards it and the parts that no motion can write. It builds each motion with the `motion` command's planner, from the committed policy without the protocol, and runs the check on it. The fork suite enacts the committed motions (`policy/constellation/artifacts/launch-onboarding-rehearsal-26249900.json`).
- **The check of a motion.** `just motion-check <base> <head> <calldata>` runs a motion's writes on a model of the Roles modifier, from the first policy, and fails unless the outcome is the second policy. It evaluates the motion role's condition tree on each write of a modifier on itself, as the modifier does: the role key, the target, the execution options, a budget's key and refill period, and a tree that the policy pins whole. It fails a write that the role's policy refuses. It also fails on an action that the motion's author did not declare, and on a second commit that is not merged. It shares no comparison code with the `motion` command, which runs it on its own output. A revoked target keeps its functions in the modifier's storage, so the check fails a removal that revokes the target alone.
- **Limits of the two commands.** Both take the chain's policy to be the first artifact. They do not read the modifiers, so they do not see a revoke of the emergency role. The round-trip check closes that gap: `just round-trip-check <base> --rpc --from-block N` rebuilds each modifier's state from its events and fails if the chain does not hold the first policy ([ADR 004](/adr/004-specifications-and-policy-as-data.md) decision 13; INV-016). Run it before a motion is built or checked. The check says nothing about a declared action, such as a burn or a relayer approval: neither whether its modifier accepts it, nor what it does. The check does not test that a submitted tree is well-formed, and the modifier refuses a malformed tree. The fork suite closes both gaps for the rehearsal's network: it replays the repository's pending motion on the vault with the base policy, so CI refuses a pending motion that would fail at its enactment. That replay runs on the rehearsal's vault until a vault is deployed.
- **The pending motion.** A policy change after launch is one pull request: the constellation, the compiled artifact, and `pending/<network>/` with the motion's file and its base policy, which `just motion-pending <base>` writes. The compiler's tests check the pending motion in CI. After the merge, the committee's Safe creates the motion with the file's calldata. After the enactment, `just motion-settle` checks that Easy Track enacted a motion with exactly the file's calldata, and that the chain holds the committed artifact. It then moves the file to `enacted/<network>/<motion id>.json`, the repository's record of enacted motions, and removes the base policy. A pull request commits both. One motion is pending for a network at a time. The file's calldata holds the counter and the policy version, so a raise of either needs the pending motion built again.
- **The two detectors.** `just watch` is both, on the logs of the modifiers and of Easy Track. The drift detector compares the chain with the policy that the repository says it holds: the pending motion's base policy until Easy Track enacts a motion with exactly the pending calldata, and the committed artifact otherwise. The chain's state alone does not show that the pending motion enacted: another motion can make the same permission writes and one more action, such as a burn, which no modifier's state holds. The motion detector fails every open motion of the factory that is not the pending motion, and every open motion while the chain does not hold the base policy. It reports every enacted motion of the factory that is neither the pending motion nor in the repository's record, and that alert stays until a pull request records the motion. The chain is the anchor: a base policy that the chain does not hold fails, whatever the file says. The command exits with 1 on an alert and prints the result as JSON with `--json`. Lido's monitoring runs it on a clone of `main` and pages the emergency Safe through the general Lido incident process; this repository holds no schedule and sends no page.
- **Other alerts.** Monitoring also alerts on a failed enactment, a raise of the counter, a restart motion, a budget set to more than twice its last value, and few free motion slots ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) decision 45).
- **Trusted caller.** The factory's constructor fixes the committee's Safe as its trusted caller ([ADR 005](/adr/005-account-graph-and-roles.md) decision 31), so a new committee Safe needs a new factory (decision 4).

## Options considered

- Merkle-root policies, as in Veda's and Mellow's vaults: not chosen (decision 1). The Roles modifier has no root and no proof channel, so a root engine would replace the modifiers with new code [s2].
- One write of the whole policy per motion: not chosen. It approaches EIP-7825's gas cap as the policy grows [s2].
- Writes without a version: not chosen. Two motions on one scope undo each other [s2].
- A version for each scope: not chosen (decision 10). The factory would read each write's role, target and function, and two open permission motions are rare (OD-135).
- Typed shapes, where the factory builds each permission and a raw write only narrows: built first, then replaced (decision 11). The typed factory took 20,121 bytes with a companion contract of 12,524 bytes in 1,253 lines of source, and each new protocol form needed a changed factory and a vote [s3].
- Raw writes with budget ceilings in the factory: not chosen (decision 11). A ceiling does not change the worst case, because a motion can grant a permission that spends no budget [s3].
- A catalogue of template factories: not chosen. It needs up to nine factories and more votes.
- Two chained Roles modifiers, an outer one with bounds that only a vote changes: not chosen (decision 14). It adds a modifier and a second policy, and each change of a bound becomes a vote [s2].
- Restart by vote: not chosen (decision 12). It is the vote after launch that decision 3 avoids.
- A motion that approves the hash of its writes, with a helper that holds the roles and makes the writes in a second transaction: not chosen (decision 18). Each motion would need a second transaction, an expiry for an unapplied approval, and its checks again at execution.

## Consequences

- The objection window is the bound on where funds go. A motion that nobody objects to can give the operator a permission with no receiver pin and no budget, or set any budget [s3].
- A captured committee, with no objection, can therefore move the vault's funds, not only lose up to its budgets in each period. The disclosure rule, the decoded motion, the comparison of its trees with the policy's source, and the 72 hours are the defence ([threat model](/specs/threat-model.md)).
- The guards in each motion role's policy stay: no membership, no administrative target, no delegatecall but the order signer's, no refill period below 30 days, exits only for the emergency role, and no transfer of the first-loss shares. The compiler checks them.
- The factory is small: the external audit covers it and CoW's order signer ([ADR 007](/adr/007-swapping-through-an-orders-account.md) decision 40). The permission trees of each motion are not audited code; they come from the policy's source, which the compiler's tests and the fork tests check.
- A new protocol form needs no changed factory and no vote: its motion carries its permissions.
- Easy Track's executor, which every Easy Track factory of the DAO shares, holds no Clutch role. Another factory reaches the vault only if Aragon Voting registers it for `applyMotion`, which runs the counter and policy-version checks again, though not the trusted-caller check.
- A vote that replaces the factory deploys the new factory, registers it, and moves every motion role to it. The new factory starts its counter and its policy version at zero, and the old factory's open motions end with its removal from Easy Track.
- A failed check costs every open motion: the emergency Safe raises the counter, and the committee creates each motion again with a new objection window. A wrong failure has the same cost, so the detector's inputs, the pending files on `main` and the chain's logs, must be right (decision 19).
- A policy change that is merged without its pending motion makes the drift detector alert, because the chain does not hold the committed artifact. A change that needs a DAO vote has no pending motion, so the alert stands until the vote enacts.
- A removal of an emergency exit, or of a token's own targets on the orders account, needs a DAO vote (decision 4). A motion can still take a token out of the order lists, because it writes the order trees again without the token. The token keeps its return and its relayer approval, and its orders budget keeps its key, at zero: the governance role's own policy lists the launch keys, and no motion writes that policy.
- No motion writes two parts of the launch policy. The first is the emergency role's zeroing of an approval in the launch form, which lists the operator's spenders: the exit-governance role writes a zeroing only for any spender. So a new spender that enters through the policy's source changes the emergency role's tree of every approved token, and that change needs a DAO vote (OD-139). The second is the emergency role's staking of ETH, which carries ETH: the exit-governance role grants plain calls only.
- The repository keeps the record of enacted motions. An enacted motion without a record stays an alert until a pull request records it, so the record is a reviewed act.
- A motion's script shows only its one call. The forum post and monitoring take the writes from the motion's calldata.

## Confirmation

- The `motion` command and its check: the compiler's tests in `policy/constellation/compiler/motion.test.ts`, and `test_replay_the_example_motion`, which enacts a motion that the command built, of 11 writes, through the live Easy Track in 2,657,268 gas; the operator then lends within the new budget, and the emergency role exits and sets the new approval to zero. The check's evaluation of a role's conditions agrees with the deployed modifiers on 65 writes of the motion roles, 19 accepted and 46 refused (`test_guard_cases_for_the_motion_check`, `just round-trip`); one more case holds the limit of a malformed tree. The fork suite replays the repository's pending motion whenever it holds one (`test_replay_a_motion_file`). Twelve mutants of the two commands, and ten of the evaluation, each fail a test.
- The round-trip check (INV-016): after the example motion enacts on the fork, the state that the check rebuilds from the modifiers' events equals the motion's head policy (`test_roundtrip_events_after_the_example_motion`, `just round-trip`). After an emergency revoke, the check reports the revoke and nothing else. After a fund's creation, with a cap that never refills, the deployed modifier stores the largest value for a maximum refill of zero and the block's time for a timestamp of zero, and the check rebuilds the fund's policy from the events (`test_roundtrip_events_after_a_fund_is_created`). The check fails on logs that do not hold a modifier's setup, so a range of blocks that starts after the deployment does not pass.
- The two detectors (decision 19): on the fork's real logs of the modifiers and of the live Easy Track, they pass the pending motion while it is open, skip a cancelled motion, alert on an open motion that the repository does not hold, alert on the pending motion after an emergency revoke, ask for the record of the pending motion after its enactment, alert on an enacted motion without a record, and refuse to settle when another motion enacted the pending motion's writes and one more action (`test_watch_events_with_the_example_motion_open`, `test_watch_events_with_a_widening_motion_open`, `test_watch_events_with_the_example_motion_open_after_a_revoke`, `test_watch_events_after_another_motion_enacts_the_pending_writes`, `just round-trip`). Eighteen mutants of the detectors each fail a compiler test.
- INV-032 to INV-035 in the [invariants](/specs/invariants.md). The factory's fork tests run against the live Easy Track, in `test/UniversalFactory.t.sol`, `test/OrdersAccount.t.sol` and `test/FirstLoss.t.sol`.
- The factory is 3,371 bytes, under EIP-170's 24,576. One motion that adds a token to the orders account makes 16 writes and enacts in 7,790,415 gas (`test_factory_orders_token_motion`). One that restores the orders account makes 9 writes in 3,622,403 gas (`test_factory_orders_restore_after_an_emergency_stop`). One that onboards an ERC-4626 lending vault makes 10 writes in 2,553,752 gas (`test_uf_motion_onboards_an_erc4626_lending_vault`). One that takes a token out of the order lists makes 4 writes in 3,323,942 gas (`test_factory_orders_token_retirement`). All are under EIP-7825's cap.
- The launch protocols' motions: after the owner of the modifiers takes a protocol out, its motion enacts through the live Easy Track, the operator uses the protocol within the policy, and the emergency role exits. Lido staking takes 667,618 gas, WETH 322,367, Sky 3,129,306, earnUSD 2,444,337 and earnETH 2,440,961 (`test/LaunchOnboarding.t.sol`). After each motion, and after the retirement, the round-trip check finds the motion's head policy on chain (`just round-trip`). The retirement's policy equals a compile of the constellation with the token in the retired list; the agent compared the two once, at this change. Nineteen mutants of the builder each fail a compiler test.

## Reversal conditions

- A motion whose writes do not fit one transaction under EIP-7825's cap, even as one call.
- A motion that enacts against the disclosure rule without an objection.
- A motion that widens a permission and that no reviewer compared with the policy's source before its window ended.
- Two open permission motions that block each other often enough to slow the committee: a version for each scope (OD-135, option B).

## Open questions

<!-- generated by scripts/validate_docs.py --write-status; edit the sources, not this block -->

No open decision closes in this record.

<!-- end of generated block -->
