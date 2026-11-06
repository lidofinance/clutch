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
  at: 2026-11-06T00:20:54Z
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
    title: Decision log — EM's decisions of 2026-11-06 on the prototype's first two questions (OD-113, OD-114)
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

1. **A new token has no ceiling.** Ceilings are per token, a zero ceiling cannot rise by motion, and so a token outside the launch list takes no budget and no cap. The options are a ceiling for every token of the mandate's asset list at deployment, a first ceiling by vote, or a first raise from zero up to a fixed figure. The agent recommended the first: it needs no new rule and no vote. EM decided on 2026-11-06 that the motion that introduces a token sets its ceilings, in the same motion (OD-113) [s8]. The prototype does not build that yet: it refuses every raise from zero.
2. **Versions do not see the emergency Safe.** The emergency role revokes directly on the modifier, so the factory's version of that scope does not change. The counter, which the emergency Safe raises with each stop, fails every motion that was open before. A motion created after a revoke may bring the permission back after its objection window, as OD-97 allows. EM accepted this on 2026-11-06 (OD-114) [s8].
3. **The seeds come from the policy.** The factory starts with the version of every list that the enabling vote writes. The prototype takes them from a copy of the launch lists and proves the copy against the compiled artifact. The build phase's tooling should compute them from the artifact itself.
4. **A failed enactment holds a motion slot.** Easy Track deletes the motion only when enactment succeeds, so a stale motion stays open until its creator or Aragon Voting cancels it [s6]. The tests cancel it, and monitoring should alert on it.

## Not built

The other shapes, each shape's emergency exit with the exit-governance role, the orders account's roles, the first-loss modifier's insurance roles, the payouts, the `motion` command and the monitoring. They are work of the build phase, and the full vote is step 2 of the rebuild [s5][s7].
