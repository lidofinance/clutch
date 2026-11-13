# Dry-run harness

This harness runs the Clutch permission policy against production contracts on a pinned mainnet fork. Only the governance heads are mocked: Aragon Voting, which owns the Asset Safe (OD-73), the Aragon Agent, the Easy Track script executor and Easy Track. The Safe, the Roles modifier, the tokens and the protocols are the deployed mainnet contracts. The policy comes only from the committed artifact that the constellation compiler writes ([ADR 004](../docs/adr/004-specifications-and-policy-as-data.md)).

**Nothing has been deployed to mainnet.** Every result comes from `forge test` against a fork.

## What is real and what is mocked

| Component | Source |
| --- | --- |
| Safe v1.5.0 singleton | deployed, `0xFf51A5898e281Db6DfC7855790607438dF2ca44b`; the deploy preflight asserts its runtime codehash |
| Safe v1.5.0 proxy factory | deployed, `0x14F2982D601c9458F93bd70B218933A6f8165e7b` |
| Roles modifier mastercopy | deployed, `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`, behind minimal proxies from the canonical module proxy factory |
| Tokens and protocols | deployed mainnet contracts |
| `MockAragonVoting` | Aragon Voting, the Asset Safe's only owner (OD-73): `execute` stands in for one call of a passed vote's script, which approves a Safe transaction's hash |
| `MockAragonAgent` | the Aragon Agent, where recovery returns assets: single-argument `forward(bytes)`, `execute`, `canForward` |
| `MockEVMScriptExecutor` | the Easy Track script executor: parses the production CallsScript format |
| `MockEasyTrack` | Easy Track: re-invokes the factory at enactment and requires a matching script hash |
| Committee's Safe, emergency Safe, first-loss Safe, orders account | plain addresses that stand in for them |
| The policy | `policy/constellation/artifacts/fork-25946643.json`, compiled from the constellation against `manifests/fork-25946643.json`; `utils/Fixture.sol` deploys at the manifest's addresses, checks each, checks that the manifest's `modules` are exactly the Asset Safe's modules (OD-38), and applies the artifact's calls through Voting and the Asset Safe |

The rehearsal suites, `EnablingVoteRehearsal.t.sol` and `UniversalFactory.t.sol`, fork block 26249900 and use the live Aragon Voting, Finance and Easy Track with its executor instead of the mocks. They deploy the universal factory from `src/factory/UniversalFactory.sol` ([ADR 013](../docs/adr/013-one-easy-track-factory.md)).

## What the policy follows

The constellation in `policy/constellation/constellation` follows [ADR 005](../docs/adr/005-account-graph-and-roles.md) to [ADR 011](../docs/adr/011-launch-scope.md), [ADR 013](../docs/adr/013-one-easy-track-factory.md) and [ADR 014](../docs/adr/014-funding-by-top-up-motions.md). The [invariants](../docs/specs/invariants.md) name the tests of each property. The harness adds these facts:

- Staking pins the referral of Lido's `submit` to zero.
- Each role and budget key is its label as `bytes32`, such as `bytes32("operator")`, which is how the Zodiac app encodes a key (ADR 004, decision 10). The derived key of a new spender is `k:`, then the spender, then the token's first ten bytes; the motion states it. The governance role's `setAllowance` takes a launch key or a key that starts with `k:`.
- In the kit, the mock script executor stands in for the universal factory as the holder of every motion role (OD-118). Only the rehearsal deploys the orders modifier.
- The insurance-funding role may only transfer the eight listed tokens to the first-loss Safe, each within the derived budget key of the token and that Safe.
- The compiler refuses a grant or a budget for the emergency role, gives `enableModule` to the restart role alone and refuses a restart that is not pinned, keeps every key of the safety modifier but `emergency` from motions, and allows a delegatecall only on the orders modifier, to the order signer.
- Budgets and fixed ceilings are dry-run stand-ins. The production figures come from the attested computation and are not in this repository.

## Known divergence from the design

- **Swaps.** The kit deploys no orders account: its operator funds a plain address that stands in for it. The enabling-vote rehearsal deploys the orders account with its policy, and `OrdersAccount.t.sol` settles its orders through CoW's settlement contract ([ADR 007](../docs/adr/007-swapping-through-an-orders-account.md)). The orders modifier's governance and approvals roles are built, and two raw motions add a token and restore the account, one motion each, through the live Easy Track (decisions 41 and 46). The separate Sepolia stand tests the order signer for WETH/USDC.
- **First-loss Safe.** The kit deploys no first-loss Safe; a plain address stands in for it as the receiver of the insurance-funding role ([ADR 008](../docs/adr/008-funding-through-existing-payments.md), [ADR 014](../docs/adr/014-funding-by-top-up-motions.md)). The enabling-vote rehearsal deploys one, with its modifier. It enters the kit's deployment in phase 2.
- **Exit-governance role.** The role is built, and `ExitGovernance.t.sol` tests it on the rehearsal ([ADR 006](../docs/adr/006-governance-through-easy-track-factories.md) decision 13). The orders token motion writes a token's exit through it, and the onboarding motion of an ERC-4626 lending vault writes that vault's exits.
- **Pre-execution screening.** The operator is a plain address, not the committee's Safe with the screening vendor's transaction guard ([ADR 010](../docs/adr/010-pre-execution-screening.md)). The harness has no guard test.
- **The universal factory.** The kit's drills drive the mock Easy Track with a pass-through factory. The factory takes raw writes (OD-134) and runs against the live Easy Track in `UniversalFactory.t.sol`. It holds the motion roles and makes a motion's writes in the motion's one call (OD-118). Most tests build each motion's writes by hand, with trees from the compiled artifact. `MotionReplay.t.sol` enacts a motion that the `motion` command built from a policy change ([ADR 013](../docs/adr/013-one-easy-track-factory.md)).
- **Budget amounts.** The governance role's budget permission pins the key and the period floor only, and the factory keeps no ceiling (OD-134). `test_budget_motion_bounds_are_expressible_per_key` shows how native conditions could bound a key.

## The policy pipeline

1. `policy/constellation/constellation/` holds the policy as a Zodiac constellation in TypeScript.
2. `bun compiler/compile.ts --manifest manifests/fork-25946643.json` writes `artifacts/fork-25946643.json`: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances.
3. The fork suites apply that artifact and nothing else.
4. `just check-policy` fails when the committed artifact differs from a fresh compile, and runs the compiler's tests. CI runs the same check in `.github/workflows/policy.yml`.

A change to the policy changes the TypeScript and the artifact in the same commit. Reviewers approve the artifact (ADR 004, decision 14).

## Commands

For the existing Sepolia stand (the [stand plan](../docs/specs/sepolia-stand-plan.md) lists the deploy, apply, fund and Constellation recipes):

```sh
just --justfile sepolia.just test-current
SEPOLIA_STAND_BLOCK=<recorded-block> just --justfile sepolia.just test-current
```

The command reads `SEPOLIA_RPC` from the ignored `.env` and uses the existing
`cache/sepolia/manifest.json` with account-specific role keys. It runs the shared
stand, current-role and CoW settlement suites on a pinned fork. It sends no public
transaction and does not reapply the policy. Test balances, solver impersonation
and time changes stay in Forge. The runner requires the complete named test set
with no failures or skips. Logs and the block/hash report stay under
`cache/sepolia/current-stand/`. See the [test plan](../docs/specs/sepolia-test-plan.md)
for the cases and transaction sequences. See the [test results](../docs/research/sepolia-test-results.md)
for recorded outcomes, findings and coverage limits.

For a captured CoW sell quote, prepare the feeAmount=0 order fields with:

```sh
python3 scripts/sepolia_cow_order.py < quote.json > order.json
just --justfile sepolia.just check
```

The sell helper adds the quote fee to sellAmount and preserves the minimum buy and receiver. The signed zero fee field does not remove protocol fees. Buy quotes require their own conversion.

The runner requires a saved local `cache/sepolia/constellation/payload.json`. It recompiles that declaration with both funding allowance balances/timestamps read at the fork block. It records the exact payload hash and refuses stale or changed inputs before reporting success. Refresh the local declaration after funding changes. A historical replay requires the matching archived payload, manifest and source revision. This does not check hosted workspace state.

Before Forge starts, the current-stand runner validates the manifest network, named addresses, aliases, deployment block and code presence. It pins each runtime hash and checks the 13 declared dependency hashes. Observed code without a declared expectation remains separate from approved runtime verification.

The current-stand runner derives Circle USDC's consumed relayer allowance from max Approval and subsequent direct settle Trade logs. It supplies SEPOLIA_EXPECTED_USDC_ALLOWANCE to the fixture and refuses unsupported event history. WETH retains its max approval. The USDC funding test uses the current remainder and the declared refill policy.

Operational guard tests execute the actual resolve CLI in a disposable repository with a real local Git origin. A preload blocks hosted transport. The tests cover branch, dirty/unpushed state, opt-in, CI, workspace/manifest mismatch and wrong chain, plus the actual public recipe env guard. They use only synthetic credentials and do not exercise live publication or wallet signing.

Workflow receipt-guard tests use a captured public four-call funding run to cover all 16 receipt subsets. Incomplete local records still require chain reconciliation before resume. The fixture excludes RPC URLs and signing material.

Protocol-fee tests reconcile all seven public fills against captured policy rates, custom/uniform prices, Transfer logs and full-block buffer balances. They cover improvement-bound SELL and cap-bound BUY priceImprovement fees. Weekly fee payout and unobserved policy/rounding boundaries remain separate.

The policy diff tests also check owners, threshold and both guard slots across all five Safes. Local fork mutations reproduce the old false matches and verify exact drift paths after correction. These checks use the reduced Sepolia signer profile and do not test production screening or alert delivery.

The mainnet fork commands remain:

```sh
RPC=<archive mainnet RPC> forge test     # the whole suite on the pinned fork
just test-fork                           # the same
just policy-compile                      # compile the constellation into the committed artifact
just check-policy                        # fail if the artifact differs from a fresh compile; compiler tests
```

The mainnet recipes are in `mainnet.just`, which the Justfile never loads. They broadcast real transactions, so agents never run them (AGENTS.md). A human runs one with `CLUTCH_MAINNET=1 just --justfile mainnet.just <recipe>`, and a Foundry keystore signs it after a password prompt; `.env` holds the keystore's name and address, never a key (ADR 012):

```sh
CLUTCH_MAINNET=1 just --justfile mainnet.just dry-run    # deploy on mainnet, compile against its manifest, apply; not run
CLUTCH_MAINNET=1 just --justfile mainnet.just fund       # fund from a throwaway EOA with 0.05 ETH; not run
CLUTCH_MAINNET=1 just --justfile mainnet.just teardown   # sweep, disable both modifiers, write a manifest; VOTING, SAFE and ROLES from dryrun-manifest.json; not run
```

A local rehearsal on an anvil fork may set `PRIVATE_KEY` to one of anvil's public test keys in the environment of a single command; `mainnet.just` refuses to run while `PRIVATE_KEY` is set.

The dry run's last rehearsal on a local anvil fork, at block 26249900 with Aragon Voting's stand-in as the Asset Safe's only owner: deploy, compile against the written manifest, apply 97 calls as Voting, a permitted and a refused operator call, and the teardown, which disabled both modifiers. The written manifest lists both modules, and the governance role is refused the safety modifier, the operator modifier and the Asset Safe as targets (OD-38).

`RPC` must be an archive node, because the suite forks block 25946643. Never commit a key or an RPC URL that contains one; keep them in a local `.env`.

## Suites

| File | Covers |
| --- | --- |
| `Drills.t.sol` | governance encoding and enactment, the four kinds of permission change and the budget-motion floor, the direct DAO path, operator lifecycle on in-scope venues, the emergency role and its switch, the restart and insurance-funding roles, budgets, adversarial cases, the launch scope, and the Asset Safe's shape |
| `ReviewProbe.t.sol` | escalation guards, approval bounds, budget keys, budget-motion bounds, and regression tests and probes for defects found in review |
| `PolicyShape.t.sol` | static checks of the committed artifact: role keys and members, and no out-of-scope target, spender or receiver |
| `utils/Fixture.sol` | the shared deployment at the manifest's addresses, with the artifact applied |
| `utils/MotionCalls.sol` | the admin calls that the governance drills put in a motion; test inputs, not the policy |
| `Bootstrap.t.sol` | the funding script |
| `SepoliaCoverage.t.sol` | current-stand role and failure matrices, governance and emergency key/target cross-products, combined queue/order/governance restart, alternate stop orderings and pending-burn cancellation in the separate `SepoliaStopOrderingCoverageTest` suite, delegatecall downgrade, allowance timestamp overflow/recovery, typed-order domains, all 104 minimum/daily/weekly TWAP part identities, cancellation isolation, conditional entrypoint and StopLoss-payload refusals in `SepoliaConditionalEntryCoverageTest`, nonzero-remainder partial fee/price rounding in `SepoliaSettlementRoundingCoverageTest`, overfill rollback, approvals and synthetic First-loss failures |
| `EnablingVoteRehearsal.t.sol` | the enabling vote on a fork of block 26249900, with the live Aragon Voting, Finance and Easy Track: a vote that carries the policy cannot start; the vote that registers the universal factory and the two top-up factories, pays nothing and approves the Safe batches; the first top-up by two motions after the batches; a later top-up in DAI, which the operator converts into USDS, a budget motion, the switch, the counter and a restart motion; Earn deposits; the first-loss burn and redemption request; the manifest; and the Safe batches, written to `.batches/` with the hash that each Safe computes, for `just batches-check`, which computes each hash again and checks each batch's calls against the policy (OD-92); the fork workflow runs that check after the suite |
| `UniversalFactory.t.sol` | the universal factory against the live Easy Track: its address book of one call, the motion roles that it holds, its gates, the counter and the policy version, one motion that onboards an ERC-4626 lending vault, the modifiers' guards on a raw motion, a widening that the factory does not stop, the restart, insurance money and its measures |
| `OrdersAccount.t.sol` | the orders account's policy on the rehearsal's vault, with CoW's deployed contracts: signer and TWAP orders settled through CoW's settlement contract, their refusals and life limits, the emergency role's cancels, sweeps and recovery orders, the revoke that keeps recovery, the funding from the Asset Safe, the operator's return to the Aragon Agent, the universal factory's governance and approvals roles on the orders modifier, a token's motion writes run by hand, and three raw motions through the live Easy Track: one for a token, the committed retirement of a token, and the restore after an emergency stop |
| `TopUps.t.sol` | top-up motions from the treasury to the Asset Safe, with Lido's deployed registry factories in new instances and the live Easy Track and Finance: the enabling vote's registration of the two factories; a stETH registry and a stablecoin registry with Aragon Voting as admin and the committee's Safe as trusted caller; DAI, USDC, USDT and sUSDS through the DAO's stablecoin list; the limit for a period of three months; the executor's ceiling on one payment, and several payments in one motion (ADR 014, decisions 13 to 16). Both limits are stand-ins |
| `LaunchOnboarding.t.sol` | the onboarding motion of each launch protocol, which `policy/constellation/compiler/launch.ts` builds from the committed policy: the modifiers' owner takes the protocol out, the motion enacts through the live Easy Track, the operator uses the protocol within the policy, and the emergency role exits. Each test writes the modifiers' events to `.roundtrip/` for the round-trip check |
| `FirstLoss.t.sol` | the first-loss Safe's policy on the rehearsal's vault, with the live Earn vaults: the Safe's shape, a burn by motion through the live Easy Track and its refusals, the committee's redemption request, a claim that pays only the Asset Safe, the refusal of every transfer and approval of the shares, an insurance deposit into each Earn vault's queue by motion with its refusals, and a fund with a fixed payout address: its creation, its payouts within the cap, its exit to the Asset Safe and the governance role's refusals |
| `ExitGovernance.t.sol` | the exit-governance role on the rehearsal's vault: only the emergency role's exits, a new token's exit on the Asset Safe, and an ERC-4626 position's exit |
| `MotionReplay.t.sol` | a motion that the `motion` command built, enacted from its calldata through the live Easy Track: the committed example, which onboards an ERC-4626 lending vault with its budget and its emergency exits, and then the operator's and the emergency role's calls on it; and the repository's pending motion, if it holds one, or with `just motion-replay` a motion file of one's own, on the vault with its base policy |
| `RoundTrip.t.sol` | the events of the four modifiers and of the live Easy Track, from the modifiers' deployment on, written to `.roundtrip/`. For the round-trip check: after the enabling vote, after the example motion, after the creation of a fund with a cap that never refills, after the committed retirement of a token, and after the operator spent a budget and the emergency role revoked a target and a function. For the two detectors: the example motion open after a cancelled motion, a motion open that the repository does not hold, the example motion open after a revoke, and another motion that enacts the example's writes and one more action. For the motion check: the deployed modifiers' answers to 66 writes of the motion roles, which the check's evaluation must match. `just round-trip` and `just test-fork` then rebuild each modifier's state from the files, compare it with the policy and check each open motion (INV-016; ADR 013, decision 19) |
| `rehearsal/` | the rehearsal's deployment, the vote's builder, the helpers that create and enact the factory's motions, and the record of the modifiers' events |

Negative drills require the modifier's own error, so a revert inside a protocol cannot pass for a refused permission.
