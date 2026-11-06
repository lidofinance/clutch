---
type: Research Note
title: The universal factory's prototype on a fork, 2026-11-05
description: "The prototype that ADR 013 asks for before any fallback to option B: the core of the universal Easy Track factory, the restart and insurance-funding roles, and the rebuilt enabling-vote rehearsal, tested against the live Easy Track; the measures for the choice between options A and B, and the questions that the prototype raised."
tags: [governance, easy-track, factory, prototype, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-05
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-11-06T04:31:16Z
verified: []
sources:
  - id: s1
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — the universal factory, its address book, shapes, versions, counter, restart and ceilings
  - id: s2
    resource: "https://github.com/lidofinance/clutch/blob/eeede8bf934ac9d6d7e8e4a9555b808662f0345a/src/factory/UniversalFactory.sol"
    title: The universal factory's prototype at eeede8b
  - id: s3
    resource: "https://github.com/lidofinance/clutch/blob/eeede8bf934ac9d6d7e8e4a9555b808662f0345a/test/UniversalFactory.t.sol"
    title: The prototype's tests against the live Easy Track, at eeede8b
  - id: s4
    resource: "https://github.com/lidofinance/clutch/tree/eeede8bf934ac9d6d7e8e4a9555b808662f0345a/policy/constellation/constellation/roles"
    title: The policy's roles at eeede8b — restart, insurance-funding, and the governance role's guard on derived keys
  - id: s5
    resource: /specs/enabling-vote.md
    title: The enabling-vote spec — the rehearsal's rebuild in two steps
  - id: s6
    resource: /research/easy-track-first-2026-11-05.md
    title: One Easy Track factory and funding by tranche votes, 2026-11-05 — Easy Track's script permissions, enactment and cancel; Roles storage
  - id: s7
    resource: /adr/014-funding-by-tranche-votes.md
    title: ADR 014 — the first tranche inside the enabling vote, and insurance money from the Asset Safe by motion
  - id: s8
    resource: /registers/decision-log.md
    title: Decision log — EM's decisions of 2026-11-06 on the prototype's first two questions (OD-113, OD-114), and EM's confirmation that an introduction counts as the first raise
  - id: s9
    resource: "https://github.com/lidofinance/clutch/blob/a4394fb3c8c3fa90435424e16495e0418260fd41/src/factory/UniversalFactory.sol"
    title: The universal factory's prototype at a4394fb, with the introduction of a token
  - id: s10
    resource: "https://github.com/lidofinance/clutch/blob/a4394fb3c8c3fa90435424e16495e0418260fd41/test/UniversalFactory.t.sol"
    title: The prototype's tests at a4394fb, with the two tests of a token's introduction
  - id: s11
    resource: "https://github.com/lidofinance/clutch/blob/72743fc74aa1f7f0d59cbfdb9dd4812df8469cc3/src/factory/UniversalFactory.sol"
    title: The universal factory's prototype at 72743fc, with the restore of a revoked target
  - id: s12
    resource: "https://github.com/lidofinance/clutch/blob/72743fc74aa1f7f0d59cbfdb9dd4812df8469cc3/test/UniversalFactory.t.sol"
    title: The prototype's tests at 72743fc, with the test of the restore
---

# The universal factory's prototype on a fork, 2026-11-05

The prototype built the core of the universal factory, the two new roles of the Easy Track executor, and step 1 of the rehearsal's rebuild [s1][s5]. ADR 013 asks for its measures before any fallback to option B. Everything runs against the live Aragon Voting, Easy Track, executor and Finance on a fork of block 26249900. Nothing is deployed.

## What was built

- **The factory** [s2]. It answers Easy Track's `createEVMScript`, at creation and again at enactment. A motion carries the counter it saw and up to 16 operations:
  - the operator's approval list of one token, which widens only through its shape and narrows by removal;
  - the revoke of one operator function;
  - one budget key, within its token's budget ceiling;
  - one ceiling: lowered at any time, or raised at most twofold, at most once in 15 days;
  - the restart;
  - insurance money from the Asset Safe to the first-loss Safe.
- **The shape of an approval list.** A new spender gets the key that the factory derives, "k:" then the spender then the token's first ten bytes, or a cap within the token's approval ceiling. The vault's own accounts are never a spender. The factory writes the tree in the canonical form of the roles SDK, so it writes what the policy compiler writes; a test compares the two for every launch list [s3].
- **Versions.** A scope's version is the hash of its content as last written: the approval list, a budget's figures, or a ceiling's value. A motion states the current content, so the version check and the narrowing check are one step. The script's last call, `commit`, stores the new versions; only the executor calls it, and it checks the counter again.
- **The policy** [s4]. The executor holds `restart` on the safety modifier, which may only enable the operator modifier on the Asset Safe, and `insurance-funding` on the operator modifier, which may only transfer to the first-loss Safe. The governance role's guard on `setAllowance` accepts a launch key or a key that starts with "k:". The compiler allows `enableModule` on the Asset Safe to the restart role alone, pinned to the operator modifier. The policy grew from 97 to 117 calls.
- **The rehearsal, step 1** [s5]. The registries, the top-up factories, the stand-in budget factory and the USDS items left the harness. The vote registers the factory with its address book and pays the first tranche through Finance. Test 3 runs a later tranche vote, a budget motion, a ceiling motion, the switch and a restart motion. Tests 6 and 7 retired with the items they tested.

## Checks

- The fork suite: 74 tests pass. The kit forks block 25946643 (53 tests); the rehearsal (6) and the factory (15) fork block 26249900.
- Eight mutants of the factory, each with one check removed, each fail at least one of the factory's tests: the version check of an approval list, the version store in `commit`, the counter check at creation, the shape's checks, the twofold limit, the 15 days, the budget ceiling and the vault-account check. With the counter check removed at creation, `commit`'s own check still stops the stale motion at enactment.
- The compiler: 24 tests pass, five of them new. They cover the restart rule and its pin, the derived-key guard and the insurance-funding receiver.
- `just check` passes.

## Measures for the choice between options A and B

| Measure | Value |
|---|---|
| Runtime size | 11,553 bytes, 47 percent of EIP-170's 24,576 |
| A motion that adds one spender: creation, enactment | 330,009 and 461,313 gas |
| A budget motion | 245,388 and 204,459 gas |
| A ceiling motion | 225,364 and 73,903 gas |
| Insurance money | 230,981 and 117,983 gas |
| An approval list of 32 spenders, the most one list may hold | 1,089,305 and 3,778,605 gas |
| 16 budgets in one motion | 846,409 and 3,217,395 gas |
| A restart motion | 227,563 and 113,651 gas |

Every motion is far under EIP-7825's cap of 16,777,216 gas. The contract has 417 lines of code, and its checks and operations take 186 of them. The agent recommends option A: it fits, and its checks stay simple to review. The size has to be measured again when the build phase adds the other shapes and their exits. If they push the factory near the limit, each shape can move into its own stateless contract that the factory calls with a view call, with no delegatecall.

## Questions that the prototype raised

1. **A new token has no ceiling.** Ceilings are per token, a zero ceiling cannot rise by motion, and so a token outside the launch list takes no budget and no cap. The options are a ceiling for every token of the mandate's asset list at deployment, a first ceiling by vote, or a first raise from zero up to a fixed figure. The agent recommended the first: it needs no new rule and no vote. EM decided on 2026-11-06 that the motion that introduces a token sets its ceilings, in the same motion (OD-113) [s8]. The prototype builds it since that day; see the next section.
2. **Versions do not see the emergency Safe.** The emergency role revokes directly on the modifier, so the factory's version of that scope does not change. The counter, which the emergency Safe raises with each stop, fails every motion that was open before. A motion created after a revoke may bring the permission back after its objection window, as OD-97 allows. EM accepted this on 2026-11-06 (OD-114) [s8].
3. **The seeds come from the policy.** The factory starts with the version of every list that the enabling vote writes. The prototype takes them from a copy of the launch lists and proves the copy against the compiled artifact. The build phase's tooling should compute them from the artifact itself.
4. **A failed enactment holds a motion slot.** Easy Track deletes the motion only when enactment succeeds, so a stale motion stays open until its creator or Aragon Voting cancels it [s6]. The tests cancel it, and monitoring should alert on it.

## Decision 15, built on 2026-11-06

EM decided that the motion that introduces a token sets the token's ceilings (OD-113) [s8]. The prototype builds it [s9][s10]:

- **The introduction.** One new operation writes a token's first approval list and sets both of its ceilings, the budget ceiling and the approval ceiling. The list fills the shape under the new approval ceiling. A budget for the token later in the same motion stays under the new budget ceiling; a budget before the introduction sees no ceiling and fails.
- **Once.** A token is introduced once. The enabling vote introduces the launch tokens by seeding their ceilings. A token whose list a motion empties stays introduced, so no motion can lower its ceilings to zero and introduce it again with higher ones.
- **No first ceiling by other means.** An approval list for a token that was never introduced is refused, and so is a ceiling operation on a ceiling that was never set. A ceiling that a motion lowers to zero cannot rise again.
- **Decision 13 after that.** The prototype counts the introduction as each ceiling's first raise, so the next raise waits 15 days. EM confirmed this reading on 2026-11-06 [s8].
- **The enabling vote's seeds.** A class of ceiling that the enabling vote does not seed for a launch token stays unset, because the token already counts as introduced. The vote therefore seeds both classes for every launch token, with zero where no entry uses the class.

Checks: the fork suite passes 76 tests, the factory's 17 among them. Seven new mutants, one for each new check, each fail a test, and the eight earlier mutants still do.

Measures: the factory grows to 12,667 bytes, 52 percent of EIP-170's limit. A motion that introduces a token with one budget takes 322,302 gas at creation and 682,545 at enactment. The other motions of the table above changed by less than 2 percent, except a ceiling motion's enactment, which fell from 73,903 to 58,126 gas: the slot that keeps the time of the last raise now also holds the ceiling's flag, so the raise no longer writes an empty slot.

## The restore of a revoked target, built on 2026-11-06

The emergency role can revoke a whole operator target, and motions bring back what it revoked (OD-104, OD-114). Until this date no operation could scope a target again, so a revoked target stayed off. The prototype adds a restore [s11][s12]:

- **What it writes.** The restore calls `scopeTarget` under the operator key, through the governance role, and writes nothing else. A target is never one of the vault's own accounts.
- **What comes back.** Roles keeps a target's function permissions when the target is revoked. The fork test shows it with the deployed Roles mastercopy: after the emergency role revoked USDC as a target, a restore motion brought back the operator's approval to the Earn deposit queue as the enabling vote wrote it, with no list written again and the list's version unchanged; a spender outside the stored list stayed refused. So a restore brings back what was stored, each permission written earlier by the enabling vote or by a motion, and nothing new. A target with nothing stored gives the operator nothing.
- **No narrowing by mistake.** The policy gives the operator no whole-target clearance, so `scopeTarget` never narrows such a clearance.
- **A stop wins.** A restore motion that was open before a stop fails on the raised counter, as every motion does.
- **Limits.** The restore acts on the operator modifier only; the orders account's restore comes with its roles. A function that the emergency role revoked alone is deleted from Roles: an approval list comes back by a motion that writes the list again, and any other function needs its protocol's shape, which the build phase adds.

Checks: the fork suite passes 77 tests, the factory's 18 among them. Two new mutants, a restore of a vault account and a restore that scopes nothing, each fail the new test.

Measures: the factory grows to 12,845 bytes, 52 percent of EIP-170's limit. A restore motion takes 230,280 gas at creation and 103,441 at enactment.

## Not built

The other shapes, each shape's emergency exit with the exit-governance role, the orders account's roles, the first-loss modifier's insurance roles, the payouts, the `motion` command and the monitoring. They are work of the build phase, and the full vote is step 2 of the rebuild [s5][s7].

The shapes that bring back a function that the emergency role revoked alone, other than an approval list, come with each protocol's shape (OD-104, OD-114).
