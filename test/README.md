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

The rehearsal suites, `EnablingVoteRehearsal.t.sol` and `UniversalFactory.t.sol`, fork block 26249900 and use the live Aragon Voting, Finance and Easy Track with its executor instead of the mocks. They deploy the universal factory's prototype from `src/factory/UniversalFactory.sol` ([ADR 013](../docs/adr/013-one-easy-track-factory.md)).

## What the policy follows

The constellation in `policy/constellation/constellation` follows [ADR 005](../docs/adr/005-account-graph-and-roles.md) to [ADR 011](../docs/adr/011-launch-scope.md), [ADR 013](../docs/adr/013-one-easy-track-factory.md) and [ADR 014](../docs/adr/014-funding-by-tranche-votes.md). The [invariants](../docs/specs/invariants.md) name the tests of each property. The harness adds these facts:

- Staking pins the referral of Lido's `submit` to zero.
- Each role and budget key is its label as `bytes32`, such as `bytes32("operator")`, which is how the Zodiac app encodes a key (ADR 004, decision 10). A key that the universal factory derives is `k:`, then the spender, then the token's first ten bytes. The governance role's `setAllowance` takes a launch key or a key that starts with `k:`.
- In the kit, the mock script executor stands in for the universal factory as the holder of every motion role (OD-118). Only the rehearsal deploys the orders modifier.
- The insurance-funding role may only transfer the eight listed tokens to the first-loss Safe, each within the budget key that the factory derives for the token and that Safe.
- The compiler refuses a grant or a budget for the emergency role, gives `enableModule` to the restart role alone and refuses a restart that is not pinned, keeps every key of the safety modifier but `emergency` from motions, and allows a delegatecall only on the orders modifier, to the order signer.
- Budgets and fixed ceilings are dry-run stand-ins. The production figures come from the attested computation and are not in this repository.

## Known divergence from the design

- **Swaps.** The kit deploys no orders account: its operator funds a plain address that stands in for it. The enabling-vote rehearsal deploys the orders account with its policy, and `OrdersAccount.t.sol` settles its orders through CoW's settlement contract ([ADR 007](../docs/adr/007-swapping-through-an-orders-account.md)). The orders modifier's governance and approvals roles are built, and the universal factory's two orders operations add a token and restore the account, one motion each, through the live Easy Track (decisions 41 and 46).
- **First-loss Safe.** The kit deploys no first-loss Safe; a plain address stands in for it as the receiver of the insurance-funding role ([ADR 008](../docs/adr/008-funding-through-existing-payments.md), [ADR 014](../docs/adr/014-funding-by-tranche-votes.md)). The enabling-vote rehearsal deploys one, with its modifier. It enters the kit's deployment in phase 2.
- **Exit-governance role.** The role is built, and `ExitGovernance.t.sol` tests it on the rehearsal ([ADR 006](../docs/adr/006-governance-through-easy-track-factories.md) decision 13). The orders token operation writes a token's exit through it; the other shapes that write exits come in phase 2.
- **Pre-execution screening.** The operator is a plain address, not the committee's Safe with the screening vendor's transaction guard ([ADR 010](../docs/adr/010-pre-execution-screening.md)). The harness has no guard test.
- **The universal factory.** The kit's drills drive the mock Easy Track with a pass-through factory. The factory's prototype, with its core and the shape of an approval list, runs against the live Easy Track in `UniversalFactory.t.sol`; its orders shape is a thin companion contract (OD-117). The factory holds the motion roles and makes a motion's writes in the motion's one call (OD-118), and `OrdersAccount.t.sol` adds a token in one motion through the live Easy Track. Its other shapes and their emergency exits are not built ([ADR 013](../docs/adr/013-one-easy-track-factory.md)).
- **Budget ceilings.** The governance role's budget permission pins the key and the period floor only. The universal factory holds a ceiling for each token, and the prototype's ceilings are stand-ins until the attested figures. `test_budget_motion_bounds_are_expressible_per_key` shows how native conditions could also bound a key.

## The policy pipeline

1. `policy/constellation/constellation/` holds the policy as a Zodiac constellation in TypeScript.
2. `bun compiler/compile.ts --manifest manifests/fork-25946643.json` writes `artifacts/fork-25946643.json`: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances.
3. The fork suites apply that artifact and nothing else.
4. `just check-policy` fails when the committed artifact differs from a fresh compile, and runs the compiler's tests. CI runs the same check in `.github/workflows/policy.yml`.

A change to the policy changes the TypeScript and the artifact in the same commit. Reviewers approve the artifact (ADR 004, decision 14).

## Commands

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
| `EnablingVoteRehearsal.t.sol` | the enabling vote on a fork of block 26249900, with the live Aragon Voting, Finance and Easy Track: a vote that carries the policy cannot start; the vote that registers the universal factory, pays the first tranche and approves the Safe batches; a later tranche vote, a budget motion, a ceiling motion, the switch and a restart motion; Earn deposits; the first-loss burn and redemption request; the manifest |
| `UniversalFactory.t.sol` | the universal factory's prototype against the live Easy Track: its address book of one call, the motion roles that it holds, a refused write that fails the whole motion, its trees against the compiler's, versions and the counter, the shape of an approval list, budgets and ceilings, a token's introduction with its ceilings, the restore of a revoked target, the restart, insurance money, its guards and its measures |
| `OrdersAccount.t.sol` | the orders account's policy on the rehearsal's vault, with CoW's deployed contracts: signer and TWAP orders settled through CoW's settlement contract, their refusals and life limits, the emergency role's cancels, sweeps and recovery orders, the revoke that keeps recovery, the funding from the Asset Safe, the operator's return to the Aragon Agent, the universal factory's governance and approvals roles on the orders modifier, a token's motion writes run by hand, and the factory's orders operations through the live Easy Track: one motion for a token, and the restore after an emergency stop |
| `FirstLoss.t.sol` | the first-loss Safe's policy on the rehearsal's vault, with the live Earn vaults: the Safe's shape, a burn by motion through the live Easy Track and its refusals, the committee's redemption request, a claim that pays only the Asset Safe, the refusal of every transfer and approval of the shares, an insurance deposit into each Earn vault's queue by motion with its refusals, and a fund with a fixed payout address: its creation, its payouts within the cap, its exit to the Asset Safe and the governance role's refusals |
| `RawFactory.t.sol` | the prototype of the universal factory with raw writes, beside the typed factory: its gates, the counter and the policy version, one motion that onboards an ERC-4626 lending vault, the modifiers' guards on a raw motion, a widening that no typed shape allowed, and the actions as raw writes |
| `ExitGovernance.t.sol` | the exit-governance role on the rehearsal's vault: only the emergency role's exits, a new token's exit on the Asset Safe, and an ERC-4626 position's exit |
| `rehearsal/` | the rehearsal's deployment, the vote's builder, and the helpers that create and enact the factory's motions |

Negative drills require the modifier's own error, so a revert inside a protocol cannot pass for a refused permission.
