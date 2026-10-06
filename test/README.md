# Dry-run harness

This harness runs the Clutch permission policy against production contracts on a pinned mainnet fork. Only the governance heads are mocked: the Aragon Agent, the Easy Track script executor and Easy Track. The Safe, the Roles modifier, the tokens and the protocols are the deployed mainnet contracts. The policy comes only from the committed artifact that the constellation compiler writes ([ADR 004](../docs/adr/004-specifications-and-policy-as-data.md)).

**Nothing has been deployed to mainnet.** Every result comes from `forge test` against a fork.

## What is real and what is mocked

| Component | Source |
| --- | --- |
| Safe v1.5.0 singleton | deployed, `0xFf51A5898e281Db6DfC7855790607438dF2ca44b`; the deploy preflight asserts its runtime codehash |
| Safe v1.5.0 proxy factory | deployed, `0x14F2982D601c9458F93bd70B218933A6f8165e7b` |
| Roles modifier mastercopy | deployed, `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`, behind minimal proxies from the canonical module proxy factory |
| Tokens and protocols | deployed mainnet contracts |
| `MockAragonAgent` | the Aragon Agent: single-argument `forward(bytes)`, `execute`, `canForward` |
| `MockEVMScriptExecutor` | the Easy Track script executor: parses the production CallsScript format |
| `MockEasyTrack` | Easy Track: re-invokes the factory at enactment and requires a matching script hash |
| Operator Safe, emergency Safe, Emergency Brakes multisig | plain addresses that stand in for them |
| The policy | `policy/constellation/artifacts/fork-25946643.json`, compiled from the constellation against `manifests/fork-25946643.json`; `utils/Fixture.sol` deploys at the manifest's addresses, checks each, and applies the artifact's calls through the Agent and the Asset Safe |

## What the policy follows

The constellation in `policy/constellation/constellation` follows the decisions in [ADR 005](../docs/adr/005-account-graph-and-roles.md) to [ADR 011](../docs/adr/011-launch-scope.md):

- The launch scope of ADR 011: no Aave, no sDAI and no other third-party lending market. The operator converts DAI to USDS and back through Sky's converter, with the receiver pinned to the Asset Safe (OD-22).
- No order pre-signing and no CoW relayer approval (ADR 007).
- Staking and WETH (OD-20): the operator and the emergency role stake ETH through Lido's `submit` with the referral pinned to zero; the operator wraps and unwraps WETH and requests and claims Lido withdrawals pinned to the Asset Safe; the emergency role unwraps WETH and claims withdrawals.
- Approvals (ADR 009, OD-08): an approval to a protocol spender spends the budget key that the spender serves; zero spends nothing; deposits spend no budget. The stETH approvals to the wstETH contract and to the withdrawal queue, and the DAI and USDS approvals to the converter, have a fixed ceiling instead (OD-08, OD-22, OD-27).
- Governance (ADR 006): every operator permission lives under the `operator` key; the governance role holds no `assignRoles`, and a budget motion cannot set a refill period below 30 days.
- Keys: each role and budget key is its label as `bytes32`, such as `bytes32("operator")`, which is how the Zodiac app encodes a key (ADR 004, decision 10).

Budgets and fixed ceilings are dry-run stand-ins. The production figures come from the attested computation and are not in this repository.

## Known divergence from the design

- **Swap instances.** The harness deploys no Stonks 2.0 instance, so neither role has a swap path yet ([ADR 007](../docs/adr/007-swapping-through-stonks.md)). The instance list is a phase 1 deliverable.
- **Pre-execution screening.** The operator is a plain address, not an operator Safe with the screening vendor's transaction guard ([ADR 010](../docs/adr/010-pre-execution-screening.md)). The harness has no guard test.
- **Factories and registries.** The budget factory, the template factories and the funding registries are not built ([ADR 006](../docs/adr/006-governance-through-easy-track-factories.md), [ADR 008](../docs/adr/008-funding-through-existing-payments.md)). The drills drive Easy Track with a pass-through factory.
- **Per-key budget ceilings.** The governance role's budget permission pins the key and the period floor only. Ceilings per key wait for the attested figures; `test_budget_motion_bounds_are_expressible_per_key` shows the shape.

## The policy pipeline

1. `policy/constellation/constellation/` holds the policy as a Zodiac constellation in TypeScript.
2. `bun compiler/compile.ts --manifest manifests/fork-25946643.json` writes `artifacts/fork-25946643.json`: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances.
3. The fork suites apply that artifact and nothing else.
4. `just policy-check` fails when the committed artifact differs from a fresh compile, and runs the compiler's tests.

A change to the policy changes the TypeScript and the artifact in the same commit. Reviewers approve the artifact (ADR 004, decision 14).

## Commands

```sh
RPC=<archive mainnet RPC> forge test     # the whole suite on the pinned fork
just test-fork                           # the same
just policy-compile                      # compile the constellation into the committed artifact
just policy-check                        # fail if the artifact differs from a fresh compile; compiler tests
just dry-run                             # deploy on mainnet, compile against its manifest, apply; not run
just fund                                # fund from a throwaway EOA with 0.05 ETH; not run
just teardown                            # sweep, disable both modifiers, write a manifest; not run
```

The dry run was rehearsed on a local anvil fork of mainnet on 2026-10-06: deploy, compile against the written manifest, apply 105 calls, then a permitted and a refused operator call.

`RPC` must be an archive node, because the suite forks block 25946643. Never commit a key or an RPC URL that contains one; keep them in a local `.env`.

## Suites

| File | Covers |
| --- | --- |
| `Drills.t.sol` | governance encoding and enactment, the four kinds of permission change and the budget-motion floor, the direct DAO path, operator lifecycle on in-scope venues, the emergency and technical roles, budgets, adversarial cases, the launch scope, and the Asset Safe's shape |
| `ReviewProbe.t.sol` | escalation guards, approval bounds, budget keys, budget-motion bounds, and regression tests and probes for defects found in review |
| `PolicyShape.t.sol` | static checks of the committed artifact: role keys, and no out-of-scope target, spender or receiver |
| `utils/Fixture.sol` | the shared deployment at the manifest's addresses, with the artifact applied |
| `utils/MotionCalls.sol` | the admin calls that the governance drills put in a motion; test inputs, not the policy |
| `Bootstrap.t.sol` | the funding script |

Negative drills require the modifier's own error, so a revert inside a protocol cannot pass for a refused permission.
