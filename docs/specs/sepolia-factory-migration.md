---
type: Guide
title: Sepolia stand migration to the universal factory
description: Deploy and test plan that moves the existing Sepolia stand's motion roles from the Easy Track executor to the universal factory.
tags: [sepolia, factory, migration, deployment, testing]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-16T12:00:00Z
verified: []
sources:
  - id: s1
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — one Easy Track factory that holds every motion role
  - id: s2
    resource: /adr/015-tests-on-sepolia.md
    title: ADR 015 — the Sepolia stand, its owner and its public transactions
  - id: s3
    resource: /specs/sepolia-stand-plan.md
    title: Sepolia stand deployment plan — the stand's contracts, roles and recipes
  - id: s4
    resource: urn:clutch:evidence:2026-11-12:factory-migration
    title: Local runs — `factory-migration` at blocks 11992758 and 12120386, and `rehearse` at block 11954838; logs in `cache/sepolia/factory-migration/` and `cache/sepolia/rehearsal/`
  - id: s5
    resource: urn:clutch:evidence:2026-11-13:factory-migration-public
    title: Public Sepolia run of 2026-11-13 — receipts in `broadcast/DeployFactorySepolia.s.sol/`, `broadcast/ApplySepolia.s.sol/` and `broadcast/retire-executor-module/`, the `constellation` comparison at block 12127573 and `test-current` at block 12127646
  - id: s6
    resource: urn:clutch:evidence:2026-11-16:factory-motions-public
    title: Public Sepolia motions of 2026-11-16 — Easy Track and Asset Safe events from block 12147161 to 12147925, the comparison of the chain with the artifact and `test-current` at block 12147931
---

# Sepolia stand migration to the universal factory

The universal factory holds every motion role on the four modifiers [s1]. On the stand, the Easy Track executor holds `governance` and `first-loss-burn`, and a separate burn factory makes the burn motion [s3]. `assignRoles` enables its module, also when it removes a role. The executor therefore stays an enabled module after it loses its roles, until the Safe disables it. This plan moves the existing stand to the universal factory. The stand stays: its controller owns Easy Track, and test Voting owns the Safes [s3].

Only the stand owner sends public Sepolia transactions [s2].

| Modifier | Roles of the universal factory |
|---|---|
| operator | `governance`, `insurance-funding` |
| safety | `restart`, `exit-governance` |
| orders | `governance`, `approvals` |
| first-loss | `first-loss-burn`, `insurance`, `insurance-governance` |

## Pre-Deploy

- [x] Scope: the stand takes every motion role of `main`; the executor leaves its two roles; the burn factory retires [s4].
- [x] Parameter: the insurance-funding caps are 1 WETH and 1000 USDC in 30 days, the same as `orders_weth` and `orders_usdc` [s4].
- [x] Freeze the deploy commit on `testnet/sepolia`: `7169df4` for steps 1 to 4 [s5].
- [x] Get Sepolia ETH for about 210 transactions. The local rehearsal used 4 transactions for the factory and 204 for the policy [s4].
- [x] Confirm that `cache/sepolia/manifest.json` has no `universalFactory`, `usdDepositQueue` or `ethDepositQueue`.

## Environment Setup

- [x] Check out the deploy commit. Set `SEPOLIA_RPC`, `SEPOLIA_ACCOUNT`, `SEPOLIA_SENDER` and `ETHERSCAN_API_KEY` in `.env` [s3].
- [x] Run the local checks.

```sh
just check
just --justfile sepolia.just check
```

- [x] Rehearse a fresh stand on Anvil: deploy, `deploy-factory`, compile, apply, fund, the caps motion, `retire-burn-factory`, the comparison of the chain with the artifact, and 7 drills. Then it sends the other public motions of the table below, with `emergency-stop` before `restart`, and compares the chain again. The run checks the caps, the policy version, the retired burn factory and the operator module. All pass [s4].

```sh
just --justfile sepolia.just rehearse
```

- [x] Rehearse the move on a fork of the existing stand with `factory-migration`. The runner predicted the new addresses from the controller's nonce, applied the policy on the fork, and ran the migration test and every stand suite. 101 of 101 tests passed at blocks `11992758`, `12120386` and `12126341`, the last on deploy day [s4]. The runner was removed after the deploy. Its motion tests run in `test-current` as `SepoliaMotionCoverageTest` [s5].

## Deploy

Set the guard before each step.

```sh
export CLUTCH_SEPOLIA=1
```

### 1. Deposit queues and the factory

`deploy-factory` deploys the USD queue, the ETH queue and the factory, in this order. It registers the factory in the stand's Easy Track and writes the three addresses to the manifest.

- [x] Run: 4 of 4 receipts have status `1`, blocks `12126368–12126371` [s5].

```sh
just --justfile sepolia.just deploy-factory
```

- [x] Record the addresses from the manifest [s5]:

| Name | Address |
|---|---|
| `usdDepositQueue` | `0x29f21a3132aF2F4Ed7Ec65d7f621a12562a5d617` |
| `ethDepositQueue` | `0x7796bC1bd8A828D05557Bae0AdD3F0626C71217e` |
| `universalFactory` | `0x07F2B0ede13A13c808D4ae0Aa0977748630c564F` |

- [x] Confirm the Etherscan verification of the three contracts [s5].

### 2. Policy

The artifact gives the roles to the factory. It also sets `orders_weth` and `orders_usdc` again, so their balances refill to the cap. The artifact does not name the executor, because `assignRoles` would enable it again.

The stand owner applied the artifact of commit `7169df4`: 102 calls. Its last two calls removed the executor from `governance` and `first-loss-burn` [s5].

- [x] Compile, then read `cache/sepolia/policy.json`: 100 calls, and no call names the executor.

```sh
just --justfile sepolia.just compile
```

- [x] Apply: 204 of 204 receipts have status `1`, blocks `12126388–12126591` [s5].

```sh
just --justfile sepolia.just apply
```

### 3. Insurance-funding caps

The compiler sets no derived key. A budget motion sets it, as on mainnet [s1]. `motion-input caps` prints the motion's input: two `setAllowance` writes of the `governance` role, under the keys `0x6b3a`, the First-loss Safe and the first ten bytes of the token.

- [x] Create the motion from the Committee Safe, and record its id: motion `7`, transaction `0xe402d64a04342007b667261cf1169fd42715bb12d70c6f2be98b4328c999db49`, block `12126985` [s5].

```sh
just --justfile sepolia.just motion caps
```

- [x] After the motion duration, enact it: transaction `0x61a10b1b301eec75df0ff56c8e95b2cde4d8a8fb205ae3bf37019bad775b6f50`, block `12127004` [s5].

```sh
just --justfile sepolia.just enact <id>
```

### 4. Retire the burn factory

- [x] Run: transaction `0x839e5e714f357a39a1142bf9ac5b79840d2390312b968ba4ef236d51b1d45bf5`, block `12127372` [s5].

```sh
just --justfile sepolia.just retire-burn-factory
```

### 5. Disable the executor module

`retire-executor-module` disables the executor on the operator and first-loss modifiers. It reads the previous module from the chain, and sends two calls through test Voting.

- [x] Run, from commit `d2517bb`: 4 of 4 receipts have status `1`, blocks `12127565–12127568` [s5].

```sh
just --justfile sepolia.just retire-executor-module
```

## Post-Deploy Checks

- [x] Compare the chain with the artifact: every role, module and allowance. The result must show 0 differences. At block `12127573`: 0 differences, 310 events [s5].

```sh
just --justfile sepolia.just constellation <workspace UUID>
```

- [x] Run the stand suites on the new state. All must pass. They check the factory's immutables, its registration, the retired burn factory, each role's members, and one motion for each motion role. At block `12127646`: 16 suites, 101 of 101 tests [s5].

```sh
SEPOLIA_STAND_BLOCK=<block after step 5> just --justfile sepolia.just test-current
```

- [x] `policyVersion() == 1` on the factory, and `allowances(key)` on the operator modifier hold the caps of step 3. The artifact expects these two caps without a call.

### Public motions

`motion <name>` creates one motion from the Committee Safe and saves its input under its id. `enact <id>` enacts it after the motion duration. A policy motion changes the policy version, so enact each motion before the next is created. The motion `caps` of step 3 used the operator's `governance` role. Where a role can only change the policy, its motion scopes a target that the policy already scopes, so the chain still matches the artifact.

| Name | Role | Writes |
|---|---|---|
| `insurance-funding` | `insurance-funding` | 0.005 WETH from the Asset Safe to the First-loss Safe |
| `insurance` | `insurance` | approve and deposit 0.005 WETH in the ETH deposit queue |
| `first-loss-burn` | `first-loss-burn` | burn 1 USD share |
| `approvals` | `approvals` | the maximum WETH approval of the Orders Safe to the vault relayer, as now |
| `orders-governance` | orders `governance` | `scopeTarget(orders-operator, WETH)`, as now |
| `exit-governance` | `exit-governance` | `scopeTarget(asset-emergency, WETH)`, as now |
| `insurance-governance` | `insurance-governance` | `scopeTarget(insurance, WETH)`, as now |
| `restart` | `restart` | `enableModule(operator modifier)` on the Asset Safe, after `emergency-stop` |

- [x] Send the motions in the order of the table. Before `restart`, stop the operator from the Emergency Safe. Motions `8` to `15` were created and enacted in the order of the table, from block `12147161` to `12147925`. `emergency-stop` disabled the operator at block `12147875`, and motion `15` enabled it again. The [test plan](sepolia-test-plan.md#public-sepolia-transaction-sequences) has the transactions [s6].

```sh
just --justfile sepolia.just motion <name>
just --justfile sepolia.just enact <id>
just --justfile sepolia.just emergency-stop
```

- [x] Compare the chain with the artifact again: 0 differences. The comparison reads the latest block. It ran just after block `12147931`, and again at block `12148104`. The stand's contracts logged no event between the two blocks. After the motions, `policyVersion()` is `4`, the First-loss Safe holds 1 USD share less, and the ETH deposit queue holds 0.005 WETH [s6].
- [x] Run the stand suites again: 16 suites, 101 of 101 tests at block `12147931`. The motion `insurance-funding` left 0.0073 WETH on the Asset Safe, so `test_FUND_first_transfer_logs_nonces_and_unchanged_configuration` gives the Asset Safe 0.01 WETH on the fork when it holds less. No stand suite checks the public stand's balance now: read it before a public transfer [s6].

## Record Deploy Artifacts

- [x] Copy the new manifest fields to `scripts/fixtures/sepolia-stand-manifest.json`. Remove the synthetic addresses from `verify-test-payload.test.ts`.
- [x] `verify-deployment.ts` checks the initial deployment at its last block. It skips the factory and the queues, which came later; the stand suites check them. Its burn-factory checks stay, because the initial deployment registered the burn factory.
- [ ] Publish the 14 roles to the Zodiac workspace with `constellation-resolve` and `constellation-publish` [s2]. The workspace names each allowance, so the declaration has no `insurance_weth` and `insurance_usdc`: a derived key has no name. The payload check accepts these two keys on the chain, and refuses any other allowance that the declaration does not name. Read the resolve output before publish. If it plans a change to a derived key, stop. The first resolve, on 2026-11-16 at commit `54e3c9a`, returned HTTP 400: the API refused permissions with Nor on `exit-governance` and `insurance-governance`. The payload now sends each role with Nor as targets, as it sends `governance` [s6].
- [x] Change the [stand plan](sepolia-stand-plan.md), the [test plan](sepolia-test-plan.md), the [setup checklist](sepolia-setup-checklist.md) and ADR 015 for the new roles.
- [x] Record the stand owner's choices of scope and caps in the decision log.

## Contingency

If a check after step 1 or step 2 fails:

- Do not send step 3.
- Remove the factory from Easy Track with `removeEVMScriptFactory(universalFactory)`. An open motion can still enact, so raise the counter from the Emergency Safe with `raiseCounter()`.
- Apply the artifact of the previous commit to give the roles back to the executor.
- Find the cause, fix it, and run this plan again from Environment Setup.
