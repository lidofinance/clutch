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
| Committee's Safe, emergency Safe | plain addresses that stand in for them |
| The policy | `policy/constellation/artifacts/fork-25946643.json`, compiled from the constellation against `manifests/fork-25946643.json`; `utils/Fixture.sol` deploys at the manifest's addresses, checks each, checks that the manifest's `modules` are exactly the Asset Safe's modules (OD-38), and applies the artifact's calls through the Agent and the Asset Safe |

## What the policy follows

The constellation in `policy/constellation/constellation` follows the decisions in [ADR 005](../docs/adr/005-account-graph-and-roles.md) to [ADR 011](../docs/adr/011-launch-scope.md):

- The launch scope of ADR 011: no Aave, no sDAI and no other third-party lending market. The operator converts DAI to USDS and back through Sky's converter, with the receiver pinned to the Asset Safe (OD-22).
- No order pre-signing and no CoW relayer approval on the Asset Safe (ADR 007).
- Staking and WETH (OD-20): the operator and the emergency role stake ETH through Lido's `submit` with the referral pinned to zero; the operator wraps and unwraps WETH; the emergency role unwraps WETH. The withdrawal queue left the design on 2026-10-08, and both roles are refused it (ADR 007, decision 27).
- Approvals (ADR 009, OD-08): an approval to a protocol spender spends the budget key that the spender serves; zero spends nothing; deposits spend no budget. The stETH approval to the wstETH contract, and the DAI and USDS approvals to the converter, have a fixed ceiling instead (OD-08, OD-22).
- Governance (ADR 006): every operator permission lives under the `operator` key; the governance role holds no `assignRoles`, and a budget motion cannot set a refill period below 30 days.
- Emergency (ADR 005, decisions 23 to 26): the emergency Safe holds the only role on the safety modifier. Its switch disables the operator modifier, pinned to it, and also freezes the queued motions. It restores nothing: the compiler refuses a grant or a budget for it, and only the DAO enables the modifier again. The Emergency Brakes multisig holds no role.
- Keys: each role and budget key is its label as `bytes32`, such as `bytes32("operator")`, which is how the Zodiac app encodes a key (ADR 004, decision 10).

Budgets and fixed ceilings are dry-run stand-ins. The production figures come from the attested computation and are not in this repository.

## Known divergence from the design

- **Swaps.** The shared mainnet policy fixture deploys no Orders account, so neither role has a swap path ([ADR 007](../docs/adr/007-swapping-through-an-orders-account.md)). `MainnetCowCoverage.t.sol` adds a local Orders Safe for the live Settlement/token matrix through owner presigning. It installs no Clutch Orders policy or order signer. The separate Sepolia stand tests those components for WETH/USDC.
- **First-loss Safe.** The harness deploys no first-loss Safe ([ADR 008](../docs/adr/008-funding-through-existing-payments.md)). It enters the deployment in phase 2.
- **Exit-governance role.** The safety modifier has no exit-governance role yet, so no motion can add an emergency exit ([ADR 006](../docs/adr/006-governance-through-easy-track-factories.md) decision 13). It comes with the template factories in phase 2.
- **Pre-execution screening.** The operator is a plain address, not the committee's Safe with the screening vendor's transaction guard ([ADR 010](../docs/adr/010-pre-execution-screening.md)). The harness has no guard test.
- **Factories and registries.** The budget factory, the template factories and the funding registries are not built ([ADR 006](../docs/adr/006-governance-through-easy-track-factories.md), [ADR 008](../docs/adr/008-funding-through-existing-payments.md)). The drills drive Easy Track with a pass-through factory.
- **Per-key budget ceilings.** The governance role's budget permission pins the key and the period floor only. Ceilings per key wait for the attested figures; `test_budget_motion_bounds_are_expressible_per_key` shows the shape.

## The policy pipeline

1. `policy/constellation/constellation/` holds the policy as a Zodiac constellation in TypeScript.
2. `bun compiler/compile.ts --manifest manifests/fork-25946643.json` writes `artifacts/fork-25946643.json`: the ordered modifier calls, the expected condition tree for every role, target and selector, and the allowances.
3. The fork suites apply that artifact and nothing else.
4. `just policy-check` fails when the committed artifact differs from a fresh compile, and runs the compiler's tests. CI runs the same check in `.github/workflows/policy.yml`.

A change to the policy changes the TypeScript and the artifact in the same commit. Reviewers approve the artifact (ADR 004, decision 14).

## Commands

For the existing Sepolia stand after its role-key migration:

```sh
just --justfile sepolia.just constellation <workspace-uuid>
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
just policy-check                        # fail if the artifact differs from a fresh compile; compiler tests
```

The mainnet recipes are in `mainnet.just`, which the Justfile never loads. They broadcast real transactions, so agents never run them (AGENTS.md). A human runs one with `CLUTCH_MAINNET=1 just --justfile mainnet.just <recipe>`, and a Foundry keystore signs it after a password prompt; `.env` holds the keystore's name and address, never a key (ADR 012):

```sh
CLUTCH_MAINNET=1 just --justfile mainnet.just dry-run    # deploy on mainnet, compile against its manifest, apply; not run
CLUTCH_MAINNET=1 just --justfile mainnet.just fund       # fund from a throwaway EOA with 0.05 ETH; not run
CLUTCH_MAINNET=1 just --justfile mainnet.just teardown   # sweep, disable both modifiers, write a manifest; not run
```

A local rehearsal on an anvil fork may set `PRIVATE_KEY` to one of anvil's public test keys in the environment of a single command; `mainnet.just` refuses to run while `PRIVATE_KEY` is set.

The dry run was rehearsed on a local anvil fork of mainnet on 2026-10-06: deploy, compile against the written manifest, apply 105 calls, then a permitted and a refused operator call. It was rehearsed again after OD-38, at block 26133512: the written manifest lists both modules, and the governance role is refused the safety modifier, the operator modifier and the Asset Safe as targets.

`RPC` must be an archive node, because the suite forks block 25946643. Never commit a key or an RPC URL that contains one; keep them in a local `.env`.

## Suites

| File | Covers |
| --- | --- |
| `MainnetCowCoverage.t.sol` | three cases cover 30 distinct six-token pairs to Asset, 10 stablecoin-destination pairs to Agent and decimals through live Settlement/relayer, with exact balances, independently calculated stETH shares and token-specific unlimited allowance deltas; local Safe, owner presigning, controlled funding/prices and solver impersonation do not establish production Orders policy or role allowlists |
| `MainnetEarnCoverage.t.sol` | twenty-four real EarnUSD/EarnETH cases: eight deposit and sixteen Asset redemption cases through Oracle/Vault/Queue/Hook, with exact custody/supply/bounded batches, delayed reports, timestamp claims, restrictions, fee conservation/exemption/extremes, dust/zero-net cleanup, USDC blacklist rollback/retry, injected hook faults and Emergency completion; production First-loss policy, controlled fork grants and legacy governance/signing limits remain explicit |
| `MainnetFirstLossCoverage.t.sol` | twelve real EarnUSD/EarnETH First-loss cases: four redemption and eight burn-motion cases with a separate Safe, Growth share transfers, Oracle/Hook settlement, exact Agent-only claims, deployed Easy Track, exact objection thresholds and historical weights after token transfers, motion lifecycle, exact burn accounting, role/receiver refusals and recovery; local factory registration and handwritten permissions do not verify production policy or signing |
| `MainnetSavingsCoverage.t.sol` | eight real sUSDS cases for independent share rounding, exact custody/events, approvals and budgets, failures/maxima, one-second pending yield and Emergency stop/exit/restart; legacy roles and mock governance remain limits |
| `MainnetConverterCoverage.t.sol` | seven real DaiUsds cases for exact token supply/balances and Vat RAD, approval boundaries, rollback, Emergency return/restart, actual USDS deny/rely recovery and five cage refusals; legacy keys and mock governance remain limits |
| `MainnetWstethCoverage.t.sol` | five real wstETH cases for independently computed share rounding/dust, approval boundaries/zeroing, rollback, both unwrap roles and stop/recovery/restart; legacy roles and mock governance remain explicit limits |
| `MainnetLidoCoverage.t.sol` | six real Lido v4 submission cases: independent internal-share accounting, boundaries, pause/resume with fork-only ACL prerequisites, stake limit and stop/restart; legacy roles and mocked governance remain explicit limits |
| `EnablingVoteRehearsal.t.sol` | fourteen fork cases use live Aragon Voting, ACL, Finance and Easy Track for the enabling vote, USDC/stETH/USDS top-ups, payment permissions, creator/recipient and limit-role refusals, objection/cancellation, monthly-limit race/rollover and paused-USDC rollback/retry; registry deployments and funding limits are local stand-ins, and budget factory is not production |
| `MainnetWethCoverage.t.sol` | five WETH boundary, balance/event, malformed-route and stop/recovery/restart cases on the committed legacy-key mainnet fork profile; production role migration and signer configuration remain separate |
| `Drills.t.sol` | governance encoding and enactment, the four kinds of permission change and the budget-motion floor, the direct DAO path, operator lifecycle on in-scope venues, the emergency role and its switch, budgets, adversarial cases, the launch scope, and the Asset Safe's shape |
| `ReviewProbe.t.sol` | escalation guards, approval bounds, budget keys, budget-motion bounds, and regression tests and probes for defects found in review |
| `PolicyShape.t.sol` | static checks of the committed artifact: role keys and members, and no out-of-scope target, spender or receiver |
| `SingleModifierProbe.t.sol` | one modifier per account (OD-57), on a stand-in for the orders account: the emergency role's revoke on its own modifier, and the membership removal that ADR 005 decision 25 replaced |
| `utils/Fixture.sol` | the shared deployment at the manifest's addresses, with the artifact applied |
| `utils/MotionCalls.sol` | the admin calls that the governance drills put in a motion; test inputs, not the policy |
| `Bootstrap.t.sol` | the funding script |
| `SepoliaCoverage.t.sol` | current-stand role and failure matrices, governance and emergency key/target cross-products, combined queue/order/governance restart, alternate stop orderings and pending-burn cancellation in the separate `SepoliaStopOrderingCoverageTest` suite, delegatecall downgrade, allowance timestamp overflow/recovery, typed-order domains, all 104 minimum/daily/weekly TWAP part identities, cancellation isolation, conditional entrypoint and StopLoss-payload refusals in `SepoliaConditionalEntryCoverageTest`, nonzero-remainder partial fee/price rounding in `SepoliaSettlementRoundingCoverageTest`, overfill rollback, approvals and synthetic First-loss failures |

Negative drills require the modifier's own error, so a revert inside a protocol cannot pass for a refused permission.
