---
type: Research Note
title: The universal factory's prototype on a fork, 2026-11-05
description: "The prototype that ADR 013 asks for before any fallback to option B: the core of the universal Easy Track factory, the restart and insurance-funding roles, and the rebuilt enabling-vote rehearsal, tested against the live Easy Track; and the measures for the choice between options A and B."
tags: [governance, easy-track, factory, prototype, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-05
stale_after: 2027-02-28T00:00:00Z
superseded_by:
  ref: /research/raw-factory-prototype-2026-11-12.md
  note: "In part: since OD-134, the factory takes raw writes, so the shapes, the versions for each scope, the ceilings and the introductions of this note are gone. The address book, the counter, the restart role and the rehearsal stand."
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-12T13:38:25Z
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

The prototype built the core of the universal factory, the restart and insurance-funding roles, and step 1 of the rehearsal's rebuild [s1][s5]. ADR 013 asks for its measures before any fallback to option B. Everything runs against the live Aragon Voting, Easy Track, executor and Finance on a fork of block 26249900. Nothing is deployed.

## What was built

- **The factory** [s2]. It answers Easy Track's `createEVMScript`, at creation and again at enactment. A motion carries the counter it saw and up to 16 operations: the operator's approval list of one token, the revoke of one operator function, one budget key, one ceiling, the restart, or insurance money from the Asset Safe to the first-loss Safe.
- **The shape of an approval list.** The factory writes the tree in the canonical form of the roles SDK, so it writes what the policy compiler writes; a test compares the two for every launch list [s3].
- **Versions.** A scope's version is the hash of its content as last written: the approval list, a budget's figures, or a ceiling's value. A motion states the current content, so the version check and the narrowing check are one step.
- **The policy** [s4]. It adds `restart` on the safety modifier (INV-035) and `insurance-funding` on the operator modifier (INV-039). The governance role's guard on `setAllowance` accepts a launch key or a key that starts with "k:". The policy grew from 97 to 117 calls.
- **The rehearsal, step 1** [s5]. The registries, the top-up factories, the stand-in budget factory and the USDS items left the harness, and tests 6 and 7 retired with them. The vote registers the factory with its address book and pays the first tranche through Finance. Test 3 runs a later tranche vote, a budget motion, a ceiling motion, the switch and a restart motion.

## Checks

- Eight mutants of the factory, each with one check removed, each fail at least one of the factory's tests: the version check of an approval list, the version store, the counter check at creation, the shape's checks, the twofold limit, the 15 days, the budget ceiling and the vault-account check. With the counter check removed at creation, the check at enactment still stops the stale motion.
- The compiler's five new tests cover the restart rule and its pin, the derived-key guard and the insurance-funding receiver.

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

Every motion is far under EIP-7825's cap of 16,777,216 gas. The contract has 417 lines of code, and its checks and operations take 186 of them.

## Decision 15, built on 2026-11-06

EM decided that the motion that introduces a token sets the token's ceilings (OD-113) [s8]. The prototype builds it [s9][s10]:

- **The introduction.** One operation writes a token's first approval list and sets both of its ceilings, the budget ceiling and the approval ceiling. A budget for the token later in the same motion stays under the new budget ceiling; a budget before the introduction sees no ceiling and fails.
- **Once, and by no other means.** A token whose list a motion empties stays introduced. An approval list for a token that was never introduced is refused, and so is a ceiling operation on a ceiling that was never set. A ceiling that a motion lowers to zero cannot rise again.
- **The enabling vote's seeds.** A class of ceiling that the enabling vote does not seed for a launch token stays unset, so the vote seeds both classes for every launch token, with zero where no entry uses the class.

Checks: seven new mutants, one for each new check, each fail a test, and the eight earlier mutants still do.

Measures: the factory grows to 12,667 bytes, 52 percent of EIP-170's limit. A motion that introduces a token with one budget takes 322,302 gas at creation and 682,545 at enactment. The other motions of the table above changed by less than 2 percent, except a ceiling motion's enactment, which fell from 73,903 to 58,126 gas: the slot that keeps the time of the last raise also holds the ceiling's flag, so the raise writes no empty slot.

## The restore of a revoked target, built on 2026-11-06

The emergency role can revoke a whole operator target, and motions bring back what it revoked (OD-104, OD-114). The prototype adds a restore [s11][s12]:

- **What it writes.** The restore calls `scopeTarget` under the operator key, through the governance role, and writes nothing else. A target is never one of the vault's own accounts.
- **What comes back.** Roles keeps a target's function permissions when the target is revoked. The fork test shows it with the deployed Roles mastercopy: after the emergency role revoked USDC as a target, a restore motion brought back the operator's approval to the Earn deposit queue as the enabling vote wrote it, with no list written again and the list's version unchanged; a spender outside the stored list stayed refused. So a restore brings back what was stored, each permission written earlier by the enabling vote or by a motion, and nothing new. A target with nothing stored gives the operator nothing.
- **No narrowing by mistake.** The policy gives the operator no whole-target clearance, so `scopeTarget` never narrows such a clearance.
- **A stop wins.** A restore motion that was open before a stop fails on the raised counter, as every motion does.
- **Limits.** The restore acts on the operator modifier only; the orders account's restore comes with its roles. A function that the emergency role revoked alone is deleted from Roles: an approval list comes back by a motion that writes the list again, and any other function needs its protocol's shape.

Checks: two new mutants, a restore of a vault account and a restore that scopes nothing, each fail the new test.

Measures: the factory grows to 12,845 bytes, 52 percent of EIP-170's limit. A restore motion takes 230,280 gas at creation and 103,441 at enactment.
