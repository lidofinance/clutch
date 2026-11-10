---
type: Research Note
title: A token for the orders account by motion, 2026-11-08
description: "The universal factory's operation that adds a token to the orders account in one motion (ADR 007, decisions 41, 44 and 45; ADR 013, decisions 17 and 18), and the fork tests through the live Easy Track: the companion contract that EIP-170's size limit needs, the executor's memory cost under EIP-7825's gas cap, and the factory that makes a motion's writes in one call."
tags: [swaps, orders, factory, easy-track, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-08
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-11-08T14:29:17Z
verified: []
sources:
  - id: s1
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — decisions 41, 44 and 45, a token for the orders account by motion
  - id: s2
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — one universal factory, typed shapes, versions, decision 11's report before a fallback, and decisions 17 and 18
  - id: s3
    resource: /research/orders-motion-roles-2026-11-08.md
    title: The orders account's motion roles and the exit-governance role on a fork, 2026-11-08
  - id: s4
    resource: "https://github.com/lidofinance/clutch/blob/c78603346d14b9b6588f17b214318f46540f0532/src/factory/UniversalFactory.sol"
    title: The universal factory at c786033 — the one call, `applyMotion`, and the orders token's operation
  - id: s5
    resource: "https://github.com/lidofinance/clutch/blob/c78603346d14b9b6588f17b214318f46540f0532/src/factory/OrdersShape.sol"
    title: The orders shape at c786033 — the companion contract that builds the orders writes
  - id: s6
    resource: "https://github.com/lidofinance/clutch/blob/c78603346d14b9b6588f17b214318f46540f0532/test/OrdersAccount.t.sol"
    title: The orders account's fork tests at c786033, the factory's orders motion among them
  - id: s7
    resource: "https://etherscan.io/address/0x5cEb19e1890f677c3676d5ecDF7c501eBA01A054#code"
    title: The CallsScript that Easy Track's script executor runs, verified on Etherscan — Aragon OS, Solidity 0.4.24
  - id: s8
    resource: "https://eips.ethereum.org/EIPS/eip-7825"
    title: EIP-7825 — a cap of 16,777,216 gas on one transaction
  - id: s9
    resource: "https://eips.ethereum.org/EIPS/eip-170"
    title: EIP-170 — a limit of 24,576 bytes on a contract's code
  - id: s10
    resource: "https://github.com/lidofinance/clutch/blob/c78603346d14b9b6588f17b214318f46540f0532/test/UniversalFactory.t.sol"
    title: The universal factory's fork tests at c786033 — the registration, the roles in the factory, a refused write, and the measures
  - id: s11
    resource: "https://github.com/lidofinance/clutch/blob/077d0455b57a91525756cfc2b9511989fa47e614/test/UniversalFactory.t.sol"
    title: The universal factory's fork tests on main at 077d045, before the one call — the measures that the comparison runs again
  - id: s12
    resource: /registers/decision-log.md
    title: Decision log — EM on the companion contract and on one motion for a token, 2026-11-08
---

# A token for the orders account by motion, 2026-11-08

Decision 41 of ADR 007 lets a motion add a token to the orders account's lists, with its relayer approval, its emergency transfer and its recovery orders; decisions 44 and 45 pin the trees that do not depend on the token and add the token's exit on the Asset Safe [s1]. The motion roles that such a motion writes through were built earlier on 2026-11-08 [s3]. This work builds the universal factory's operation that writes the motion, and runs it through the live Easy Track on the fork of block 26249900. It found two limits. The factory and the shape do not fit one contract, and EM accepted a companion contract (OD-117, ADR 013 decision 17). A motion's script of many calls does not fit one transaction. The agent first split a token into two motions, which EM did not accept; EM then chose a factory that holds the motion roles and makes a motion's writes in the motion's one call (OD-118, ADR 013 decision 18) [s12]. Nothing is deployed.

## What was built

- **One operation of the factory** [s4]. It adds a token: through the orders modifier's governance role, the operator's return, the emergency role's zeroing and transfer and the approvals role's relayer approval; through the approvals role, the approval itself; through the exit-governance role, the token's exit from the Asset Safe to the Aragon Agent or the orders account; through the governance role on the operator modifier, the operator's transfer into the orders account under a key that the factory derives for the token; and the token in the orders account's two lists, in its sorted place, with the three order trees written again. A new token's two ceilings come with it, as with an introduction (ADR 013, decision 15), and a budget operation in the same motion fills the key. It refuses a token that either list holds, so each token is added once.
- **The orders shape** [s5]. A companion contract builds the operation's writes, each tree in the roles SDK's form. The factory creates it in its own constructor, so its code is fixed with the factory's, and calls it only to read. It holds no state, makes no call and cannot be upgraded.
- **One call for each motion** [s4]. The factory holds the motion roles: governance and insurance funding on the operator modifier, exit governance and restart on the safety modifier, governance and approvals on the orders modifier, and the first-loss burn role. A motion's script makes one call, the factory's `applyMotion`, which only Easy Track's executor may make. The call checks the motion again, stores its versions and ceilings, and then makes its writes; a write that fails reverts the whole enactment. `writesOf` returns the writes that a motion makes if it is enacted now, for review. Easy Track registers the factory for `applyMotion` alone, and the factory's separate `commit` is gone.
- **Versions.** The orders lists have one version, which the enabling vote seeds and each token's motion changes, so two token motions cannot overwrite each other, and one motion adds one token.
- **The launch orders budgets.** Since 2026-11-07 the operator funds the orders account under six launch budget keys, but the factory knew only the three protocol keys. A budget motion for a launch order token would have set a key that the factory derived and that no permission spends. The factory now knows all nine launch keys, and the enabling vote seeds the budget ceilings of the three order tokens that lacked one.
- **The batch builder.** It now splits a Safe's calls by size as well as by gas, so that no batch passes the transaction pool's limit. The Asset Safe's batch holds 110,148 bytes of the 131,072, so the launch batches do not change yet.
- **The policy and the manifests.** The six motion roles that the compiled policy writes name the universal factory as their member, and the manifest names the factory in place of the executor. The rehearsal deploys the factory as its deployer's first creation, so the factory's address does not change with its code. The kit, which has no universal factory, names its mock script executor in the factory's place.

## One contract does not hold the shape

With the orders shape inside it, the factory's code is 26,026 bytes, 1,450 over EIP-170's 24,576 [s9]. With its tree builders internal it is 24,970 bytes, still 394 over, and a lower setting of the optimizer saves 45 bytes more. The shape is the factory's largest, and the other shapes of the launch are still to come. So the shape moved into its own contract. The factory was then 17,324 bytes, and with the one call it is 16,410, 8,166 under the limit; the orders shape is 10,489. The factory's deployment code, which carries the shape's, is 29,058 of the 49,152 bytes that a deployment may carry.

ADR 013's decision 11 falls back to raw writes if the shapes' checks prove too tough and complex, and asks for these figures first [s2]. The checks are neither: the code is too large for one contract. A companion contract keeps the typed shape, one factory for Easy Track, and no upgrade. It adds a contract to the audit (OD-117).

## One motion does not fit one transaction

When the factory built a script of many calls, the motion that prepared and listed a token made 17 calls in a script of 35,904 bytes. Its enactment needed 16,714,754 gas with cold accounts, and it failed under EIP-7825's cap of 16,777,216 [s8], because each frame of a nested call keeps a 64th of its gas back. These figures come from a scratch test that is not in the repository. Of that gas:

- the factory built the script again at enactment, as Easy Track requires: 3,721,582 gas;
- the 17 calls cost 6,653,874 gas when each ran alone, and 7,895,640 when each ran alone through Easy Track's script executor;
- the same calls in one script cost the executor 14,491,417 gas.

The difference is memory. Easy Track's executor runs Aragon's CallsScript, compiled with Solidity 0.4.24. For each call, its loop reads the script through three library helpers that take the script in memory, so the compiler copies the whole script from calldata into memory three times for each call, and memory is never freed within a call [s7]. For 17 calls and 36 kilobytes that is about 1.8 megabytes, whose expansion costs about 6.5 million gas. The cost grows with the script's size times its number of calls, so every token that joins the lists made the one motion larger.

The agent first split the token into two motions, its preparation and its listing: 4,032,986 and 5,432,158 gas, each under the cap. A token then took two objection windows, one after the other, and EM did not accept two motions for one token (OD-118) [s12].

## One motion with one call

EM asked whether a helper with which the factory approves particular hashes could keep one motion. Since the executor's cost grows with the script's size times its number of calls, what matters is that the script makes one call. A scratch test, not in the repository, measured that: one call from the executor that carried all 16 writes of a token, 37,024 bytes, cost 7,664,269 gas, where 17 separate calls cost 14,491,417. The agent offered two forms: the factory holds the roles and makes the writes in the motion's one call (A), or a motion approves the hash of its writes and a helper makes them in a second transaction (B). B needs a second transaction for each motion, an expiry for an approval that nobody applies, and its checks again at execution. EM chose A (ADR 013, decision 18) [s12].

Built, one motion that adds WBTC, with its budget, enacts in 7,796,336 gas with cold accounts, 46 percent of EIP-7825's cap [s6]. The factory now checks every motion twice at enactment, once in Easy Track's rebuild and once in `applyMotion`, but it no longer builds a script of many calls. Every other motion of the prototype costs less gas than on main, except a ceiling's enactment, which costs about 2,000 more. The same test ran on main at 077d045 and with the one call, both on the fork, with warm accounts [s10][s11]:

| Motion | Creation, main | Creation, one call | Enactment, main | Enactment, one call |
|---|---|---|---|---|
| An approval list, one spender added | 345,136 | 302,046 | 471,764 | 444,201 |
| A budget | 252,875 | 237,447 | 229,884 | 219,595 |
| A ceiling | 229,331 | 224,083 | 58,894 | 60,892 |
| Insurance money | 236,477 | 222,955 | 119,748 | 108,704 |
| A token's introduction, with one budget | 333,142 | 279,310 | 701,916 | 673,573 |
| An approval list of 32 spenders | 1,137,163 | 690,298 | 3,791,533 | 3,473,904 |
| 16 budgets in one motion | 920,336 | 639,220 | 3,600,651 | 2,904,876 |
| The restore of a revoked target | 230,280 | 216,214 | 110,901 | 99,139 |
| The restart | 228,582 | 214,210 | 114,670 | 101,634 |

The factory, not Easy Track's executor, holds the motion roles. So the role holder that ADR 005, ADR 006, ADR 007, ADR 008, ADR 013 and ADR 014 named changes. Easy Track's executor, which every Easy Track factory of the DAO shares, holds no Clutch role. Another Easy Track factory reaches the vault only if Aragon Voting registers it for `applyMotion`, and that call checks the motion again. A vote that replaces the factory also moves the roles to the new one.

## The form of the trees

The orders shape writes each order tree byte for byte as the policy compiler writes it. For the launch lists, its signer, TWAP and recovery trees equal the committed artifact's; with a new token, they equal the artifact's trees with one leaf in each list's sorted place, the rule that the compiler's tests check against the SDK [s3]. So the trees on chain after a motion can be compared with a compile.

## The fork tests

| What the operation owes | Test | Result |
|---|---|---|
| The trees in the compiler's form | `test_factory_orders_trees_match_the_compiler` | For the launch lists and with a new token, each of the three trees equals the artifact's, or the artifact's with the token in its sorted place. A motion's 15 writes end with the listing's three. |
| A token by one motion, through the live Easy Track | `test_factory_orders_token_motion` | The motion enacts in 7,796,336 gas, under EIP-7825's cap with cold accounts. After it, the operator funds the orders account within the token's budget and no further, an operator order in the token settles and pays the Asset Safe, a TWAP order in it is created, and the emergency role moves the token from the Asset Safe to the orders account and sells it by a recovery order that pays the Agent. The stand-in is WBTC; no decision lists it. |
| The checks | `test_factory_orders_token_refusals` | At creation: a token that either list holds, a launch token among them; the orders account, the Asset Safe and the Agent as a token; two tokens in one motion; lists that are not the current ones; and ceilings for a token that a motion introduced earlier. A token that a motion introduced earlier is added with no ceilings and keeps its own. |
| Versions keep token motions apart | `test_factory_orders_tokens_one_after_another` | Two token motions created against the same lists both pass at creation; the second fails at enactment. A motion against the new lists then adds the second token, and an order between the two new tokens is signed. The second stand-in is LINK; no decision lists it. |
| The launch orders budgets | `test_factory_budget_motion_sets_a_launch_orders_budget` | A budget motion for USDC's orders budget sets its launch key, and the operator then funds the orders account under the new figure. |
| One call, and the roles in the factory | `test_uf_address_book_is_the_registration`, `test_uf_the_factory_holds_the_motion_roles`, `test_uf_a_refused_write_fails_the_whole_motion` | The registration is `applyMotion` alone, and a motion's script is one call. Easy Track's executor holds no role, and its own call of `applyMotion` is refused like a motion that the checks refuse; `writesOf` shows the writes. With the operator modifier disabled and the counter left as it is, a budget motion fails at enactment and its version stays [s10]. |

The factory's own tests take PYUSD, a token outside the launch lists, for the introduction of a new token: USDT has a launch orders budget, so the enabling vote introduces it.

## Checks

- The fork suite passes 100 tests: the kit's 53, and at block 26249900 the rehearsal's 6, the factory's 20, the orders account's 18 and the exit-governance role's 3.
- 26 mutants of the one call, the orders operation and the orders shape, each of which breaks one check or one write, each fail at least one fork test. Two mutants of the policy, each of which gives a motion role to the committee's Safe, each fail the compiler's tests. An earlier run, on the two motions, first missed an order life of 91 days, because the trees test took the life from the test; the test has since decoded the listing's own writes. The mutants ran from a local script, not in the repository.
- The compiler passes its 52 tests, and the committed artifacts equal a fresh compile. The rehearsal's artifact changes only in the six grants of the motion roles, which now name the factory.

## For EM

- **OD-117, decided.** EM accepted the companion contract on 2026-11-08 (ADR 013, decision 17).
- **OD-118, decided.** EM chose on 2026-11-08 that the factory holds the motion roles and makes a motion's writes in the motion's one call (ADR 013, decision 18).

## Not tested, and not built

- The other shapes of the launch, their exits and their companions.
- The motion command that builds these motions from a merged policy, prints their writes from `writesOf`, and drafts the forum post that goes with each.
- The removal of a token from the orders account's lists.
- The first-loss burn and the insurance roles on the first-loss modifier as operations of the factory. The rehearsal's vote gives the factory the burn role already.
