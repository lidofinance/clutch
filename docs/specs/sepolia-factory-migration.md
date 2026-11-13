---
type: Guide
title: Sepolia stand migration to the universal factory
description: Deploy and test plan that moves the existing Sepolia stand's motion roles from the Easy Track executor to the universal factory.
tags: [sepolia, factory, migration, deployment, testing]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-12T17:43:05Z
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
---

# Sepolia stand migration to the universal factory

The universal factory holds every motion role on the four modifiers [s1]. On the stand, the Easy Track executor holds `governance` and `first-loss-burn`, and a separate burn factory makes the burn motion [s3]. This plan moves the existing stand to the universal factory. The stand stays: its controller owns Easy Track, and test Voting owns the Safes [s3].

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
- [ ] Freeze the deploy commit on `testnet/sepolia`.
- [ ] Get Sepolia ETH for about 210 transactions. The local rehearsal used 4 transactions for the factory and 204 for the policy [s4].
- [ ] Confirm that `cache/sepolia/manifest.json` has no `universalFactory`, `usdDepositQueue` or `ethDepositQueue`.

## Environment Setup

- [ ] Check out the deploy commit. Set `SEPOLIA_RPC`, `SEPOLIA_ACCOUNT`, `SEPOLIA_SENDER` and `ETHERSCAN_API_KEY` in `.env` [s3].
- [x] Run the local checks.

```sh
just check
just --justfile sepolia.just check
```

- [x] Rehearse a fresh stand on Anvil: deploy, `deploy-factory`, compile, apply, fund, `caps-motion`, `caps-enact`, `retire-burn-factory` and 7 drills. The run checks the caps, the policy version and the retired burn factory. All pass [s4].

```sh
just --justfile sepolia.just rehearse
```

- [x] Rehearse the move on a fork of the existing stand. The runner predicts the new addresses from the controller's nonce, applies the policy on the fork, and runs the migration test and every stand suite. At block `11992758`, 101 of 101 tests pass [s4].

```sh
SEPOLIA_STAND_BLOCK=<latest block> just --justfile sepolia.just factory-migration
```

- [x] Run `factory-migration` again at a recent block: 101 of 101 tests pass at block `12120386` [s4].
- [ ] Run `factory-migration` once more on deploy day.

## Deploy

Set the guard before each step.

```sh
export CLUTCH_SEPOLIA=1
```

### 1. Deposit queues and the factory

`deploy-factory` deploys the USD queue, the ETH queue and the factory, in this order. It registers the factory in the stand's Easy Track and writes the three addresses to the manifest.

- [ ] Run

```sh
just --justfile sepolia.just deploy-factory
```

- [ ] Record `usdDepositQueue`, `ethDepositQueue` and `universalFactory` from the manifest.
- [ ] Confirm the Etherscan verification of the three contracts.

### 2. Policy

The artifact gives the roles to the factory and removes the executor from `governance` and `first-loss-burn`. It also sets `orders_weth` and `orders_usdc` again, so their balances refill to the cap.

- [ ] Compile, then read `cache/sepolia/policy.json`: 102 calls; the last two are `assignRoles(executor, …, false)`.

```sh
just --justfile sepolia.just compile
```

- [ ] Apply

```sh
just --justfile sepolia.just apply
```

### 3. Insurance-funding caps

The compiler sets no derived key. A budget motion sets it, as on mainnet [s1]. `caps-input` prints the motion's input: two `setAllowance` writes of the `governance` role, under the keys `0x6b3a`, the First-loss Safe and the first ten bytes of the token.

- [ ] Create the motion from the Committee Safe, and record its id.

```sh
just --justfile sepolia.just caps-motion
```

- [ ] After the motion duration, enact it.

```sh
just --justfile sepolia.just caps-enact <id>
```

### 4. Retire the burn factory

- [ ] Run

```sh
just --justfile sepolia.just retire-burn-factory
```

## Post-Deploy Checks

- [ ] Run the stand suites on the new state. All must pass. They check the factory's immutables, its registration, the retired burn factory, and each role's members.

```sh
SEPOLIA_STAND_BLOCK=<block after step 4> just --justfile sepolia.just test-current
```

- [ ] `policyVersion() == 1` on the factory, and `allowances(key)` on the operator modifier hold the caps of step 3.

### Public motions

- [ ] Send one motion for each new role, as `SepoliaFactoryMigrationTest` does on the fork. Record the transactions in the [test plan](sepolia-test-plan.md#public-sepolia-transaction-sequences).

## Record Deploy Artifacts

- [ ] Copy the new manifest fields to `scripts/fixtures/sepolia-stand-manifest.json`. Remove the synthetic addresses from `verify-test-payload.test.ts`.
- [ ] Check the factory and the queues in `verify-deployment.ts`. Remove the burn-factory checks and `SepoliaFirstLossBurnFactory`.
- [ ] Publish the 14 roles to the Zodiac workspace with `constellation-resolve` and `constellation-publish` [s2].
- [ ] Change the [stand plan](sepolia-stand-plan.md), the [test plan](sepolia-test-plan.md), the [setup checklist](sepolia-setup-checklist.md) and ADR 015 for the new roles.
- [ ] Record the scope and the caps in the decision log, with a new OD number from `main`.

## Contingency

If a check after step 1 or step 2 fails:

- Do not send step 3.
- Remove the factory from Easy Track with `removeEVMScriptFactory(universalFactory)`. An open motion can still enact, so raise the counter from the Emergency Safe with `raiseCounter()`.
- Apply the artifact of the previous commit to give the roles back to the executor.
- Find the cause, fix it, and run this plan again from Environment Setup.
