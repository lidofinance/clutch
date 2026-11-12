---
type: Guide
title: Sepolia stand migration to the universal factory
description: Tasks that move the existing Sepolia stand from the Easy Track executor's roles to the universal factory, fork first.
tags: [sepolia, factory, migration, testing]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-12T16:41:48Z
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
---

# Sepolia stand migration to the universal factory

The universal factory holds every motion role on the vault's four modifiers [s1]. On the Sepolia stand, the Easy Track executor holds the `governance` and `first-loss-burn` roles, and a separate burn factory makes the burn motion [s3]. This page lists the tasks that move the existing stand to the factory. The stand stays: its owner controls Easy Track, the four modifiers and their Safes [s3].

Only the stand owner sends public Sepolia transactions [s2]. An agent does the fork and local tasks.

## Format

Each task is one line: `- [ ] (priority) number task +area @who key:value`.

- `@agent`: an agent can do the task locally or on a fork.
- `@human`: the task is a public Sepolia transaction or a decision.
- `dep:N`: the task needs task N first.

The stand's manifest is `cache/sepolia/manifest.json`. The current fork block is `11992758`.

## 0. Scope

- [x] (A) 0.1 Choose the roles that the stand takes from `main` +scope @human
  - The stand takes every motion role of `main`, with the universal factory as the member.
  - operator modifier: `governance`, `insurance-funding`
  - safety modifier: `restart`, `exit-governance`
  - orders modifier: `governance`, `approvals`
  - first-loss modifier: `first-loss-burn`, `insurance`, `insurance-governance`
- [x] (A) 0.2 Remove the old motion members: the Easy Track executor leaves `governance` and `first-loss-burn` +scope @human
- [x] (B) 0.3 Retire the burn factory after the universal factory works +scope @human

## 1. Fork first

No public transactions in this stage.

- [x] (A) 1.1 Write `script/sepolia/DeployFactorySepolia.s.sol`: the universal factory with the stand's addresses +code @agent
  - `trustedCaller` is the committee, `executor` is `easyTrackExecutor`; also `emergencySafe`, `voting` and the four modifiers.
  - The same script registers the factory in `SepoliaEasyTrack` and writes `universalFactory` to the manifest. The recipe is `deploy-factory`.
- [x] (A) 1.2 Change `policy/constellation/sepolia/compile.ts`: the new roles, with `universalFactory` as their member +policy @agent dep:0.1
- [x] (A) 1.3 Add the revocations to the Apply artifact: `assignRoles(executor, …, false)` and the old scopes +policy @agent dep:1.2
  - `ApplySepolia` only applies the calls in the artifact. It removes nothing on its own.
  - The artifact also sets `orders_weth` and `orders_usdc` again, so their balances refill to the cap.
- [x] (A) 1.4 Add `universalFactory`, `usdDepositQueue` and `ethDepositQueue` to the manifest and to the tests +policy @agent
- [x] (A) 1.5 Write the fork test `test/SepoliaFactoryMigration.t.sol`: on the stand's block, run 1.1 to 1.3 as the owners +test @agent dep:1.1,1.3
  - Register the factory in `SepoliaEasyTrack`, then create and enact one motion for each role.
  - Check the counter, the policy version and a cancel by Voting.
  - Run it with `SEPOLIA_STAND_BLOCK=<block> just --justfile sepolia.just factory-migration`. The runner predicts the addresses from the controller's nonce at that block.
  - The insurance-funding caps of 1 WETH and 1000 USDC in 30 days come from a budget motion, as on mainnet; the compiler sets no derived key.
- [ ] (B) 1.6 Rehearse on anvil with `sepolia.just rehearse` and the new steps +test @agent dep:1.5

## 2. Tests of the current stand

`test-current` fails from stage 1 until 3.3: the code describes the stand after the move, and the stand on chain is still before it.

- [ ] (A) 2.1 `SepoliaStandFixture`: replace `easyTrackExecutor` and `burnFactory` with `universalFactory` as the motion member +test @agent dep:1.2
- [ ] (A) 2.2 `SepoliaCoverage`: run the governance and burn matrices through `applyMotion` +test @agent dep:2.1
- [ ] (B) 2.3 Add motion cases: `StaleCounter`, `StalePolicyVersion`, `TooManyWrites`, `UnknownModifier`, `NotTrustedCaller` +test @agent
- [ ] (B) 2.4 Change the test names in `docs/specs/invariants.md` for the new tests +docs @agent dep:2.2

## 3. Public Sepolia

Only the stand owner does this stage.

- [ ] (A) 3.1 Run `sepolia.just deploy-factory`: it deploys the factory with `--verify` and registers it +deploy @human dep:1.5
- [ ] (A) 3.3 Run `just compile`, check `policy.json`, then run `just apply` +deploy @human dep:3.1
- [ ] (B) 3.4 Call `removeEVMScriptFactory(burnFactory)` if 0.3 retires the burn factory +deploy @human dep:3.3
- [ ] (B) 3.5 Send one public motion for each new role and keep the receipts in `cache/sepolia/` +deploy @human dep:3.3

## 4. After the public run

- [ ] (A) 4.1 Move `SEPOLIA_STAND_BLOCK` past 3.3 and run `test-current` +test @agent dep:3.3
- [ ] (B) 4.2 Check the factory's code and immutables in `verify-deployment` +test @agent dep:3.1
- [ ] (B) 4.3 Resolve the new roles in the Zodiac workspace with `constellation-resolve` and `constellation-publish` +ui @human dep:3.3
- [ ] (B) 4.4 Change the stand plan, the test plan, the setup checklist and ADR 015 +docs @agent dep:4.1
- [ ] (C) 4.5 Record the scope decisions of stage 0 in the decision log, with a new OD number from `main` +docs @human dep:0.1
