# Dry-run harness

This harness runs the Clutch permission policy against production contracts on a pinned mainnet fork. Only the governance heads are mocked: the Aragon Agent, the Easy Track script executor and Easy Track. The Safe, the Roles modifier, the tokens and the protocols are the deployed mainnet contracts.

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
| `MockModuleGuard` | a module guard on the Asset Safe, the screening route that [ADR 010](../docs/adr/010-pre-execution-screening.md) rejected |

## Known divergence from the accepted design

The harness predates five design decisions and does not yet follow them:

- The launch scope in [ADR 011](../docs/adr/011-launch-scope.md). The policy still grants Aave v3 supply and withdraw and sDAI deposits, which are outside the launch scope.
- Swapping through Stonks 2.0 in [ADR 007](../docs/adr/007-swapping-through-stonks.md). The policy still grants the operator direct order pre-signing. It also lacks the conversions that OD-20 and OD-22 added: staking ETH through Lido's `submit`, the Lido withdrawal queue, the emergency role's WETH unwrap, and the DAI–USDS converter.
- Approvals in [ADR 009](../docs/adr/009-budgets-caps-reporting-and-monitoring.md). The policy caps each approval and spends the budget at the deposit. The decision spends the budget at the approval, and deposits no longer spend it.
- Pre-execution screening in [ADR 010](../docs/adr/010-pre-execution-screening.md). The harness tests a module guard on the Asset Safe. The decision is the screening vendor's transaction guard on a dedicated operator Safe, which is also the trusted caller of every factory.
- Governance in [ADR 006](../docs/adr/006-governance-through-easy-track-factories.md). The harness still has the role-toggle factory and tests of DAO-scoped role keys. The design retired both: every operator permission lives under the `operator` key.

The first three are resolved when the policy moves to a data file under [ADR 004](../docs/adr/004-specifications-and-policy-as-data.md). The fourth needs the guard tests rewritten for a mock operator Safe. The fifth is resolved by removing the toggle factory and its tests. Until then, results about these venues and about screening describe the harness, not the design.

## Commands

```sh
RPC=<archive mainnet RPC> forge test     # the whole suite on the pinned fork
just test-fork                           # the same
just dry-run                             # deploy mocks, Safe, modifiers and policy on mainnet; not run
just fund                                # fund from a throwaway EOA with 0.05 ETH; not run
just teardown                            # sweep, disable, write a manifest; not run
```

`RPC` must be an archive node, because the suite forks block 25946643. Never commit a key or an RPC URL that contains one; keep them in a local `.env`.

## Suites

| File | Covers |
| --- | --- |
| `Drills.t.sol` | governance encoding and enactment, the four change types, operator lifecycle, emergency flow, technical module disabling, budgets, adversarial cases, pre-execution screening |
| `ReviewProbe.t.sol` | escalation guards, approval bounds, order invalidation, and regression tests for defects found in review |
| `FactoryOnly.t.sol` | governance through the role-toggle factory, including a queued motion dying when its key is withdrawn; the factory is retired (OD-09) |
| `NoNewContract.t.sol` | native constraints on role toggles and on allowance changes |
| `Bootstrap.t.sol` | the funding script |
| `PolicyShape.t.sol` | the policy builds within bounds |
