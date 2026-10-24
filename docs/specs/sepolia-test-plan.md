---
type: Guide
title: Sepolia stand test plan
description: Test the existing Sepolia stand after its role-key migration, then complete the public execution drills.
tags: [sepolia, testing, roles, cow, first-loss]
status: draft
review_status: slop
generated:
  by: codex/gpt-6
  at: 2026-10-23T15:44:44Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account isolation, emergency stop and DAO restart
  - id: s2
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — CoW orders, TWAP, recipients, approvals and cancellation
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — First-loss redemption, burn motions and objection
  - id: s4
    resource: /adr/006-governance-through-easy-track-factories.md
    title: ADR 006 — governance permissions and motion restrictions
  - id: s5
    resource: /adr/013-tests-on-sepolia.md
    title: ADR 013 — four account-specific keys and Sepolia execution boundaries
  - id: s6
    resource: /specs/sepolia-stand-plan.md
    title: Existing stand, funding procedure and recorded deployment evidence
  - id: s7
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: test/SepoliaStand.t.sol, test/SepoliaCurrentStand.t.sol, test/utils/SepoliaStandFixture.sol and scripts/sepolia_test_current.py
  - id: s8
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2Settlement.sol
    title: CoW primary source checked on 2026-10-23 — settlement, limit-price checks and filled amounts
  - id: s9
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/libraries/GPv2Trade.sol
    title: CoW primary source checked on 2026-10-23 — trade ABI and signature flags
  - id: s10
    resource: https://github.com/cowprotocol/contracts/blob/main/src/contracts/mixins/GPv2Signing.sol
    title: CoW primary source checked on 2026-10-23 — presign and EIP-1271 signatures
  - id: s11
    resource: urn:clutch:evidence:2026-10-23:sepolia-current-stand-fork
    title: Pinned existing-stand fork logs and result under cache/sepolia/current-stand/
  - id: s12
    resource: /specs/sepolia-setup-checklist.md
    title: Complete setup coverage inventory, assertion-level status and review findings
  - id: s13
    resource: urn:clutch:evidence:2026-10-23:sepolia-first-transfer
    title: Prepared first-transfer payload, eth_call and two fork tests at block 11977379
---

# Sepolia stand test plan

The [setup coverage checklist](sepolia-setup-checklist.md) holds the integration inventory and 120 coverage obligations.
It separates exact fork assertions from open variants and dependencies absent from this stand.
The 14 named tests below are selected executions, not complete integration coverage [s12].

## Scope and acceptance

Test the existing stand on chain `11155111` after the role-key migration.
Use `asset-operator`, `orders-operator`, `asset-emergency` and `orders-emergency` on their respective modifiers.
Keep `governance`, `first-loss`, `first-loss-burn` and both allowance keys unchanged [s5].

Each case must check its resulting state.
A forbidden call must fail at the expected permission check.
A protocol failure from missing funds must not count as a policy refusal.
A settlement case must check the filled amount and the recipient's balance.
A green suite with a missing or skipped case must fail the runner [s7][s8].

## 1. Prepare the fork

1. Keep `SEPOLIA_RPC` in the ignored `.env`. Use an RPC that can read the pinned block. No signer or Zodiac API key is needed [s5][s7].
2. Keep the existing manifest at `cache/sepolia/manifest.json`. It must identify Sepolia and `roleKeyScheme: account`. The runner must not deploy, migrate or reapply the policy [s5][s7].
3. Pin the block number and hash. Discover an existing solver from recent canonical CoW settlement logs. Check its authorization through the deployed authenticator [s7][s8].
4. Check the account owners, thresholds, enabled modules and CoW domain verifier. Check successful calls under the four new keys and refusals under the old or wrong-account keys [s1][s5][s7].
5. Supply test balances only inside the fork. Transfer test shares from the controller to First-loss. Use Forge balance fixtures for WETH, USDC and settlement liquidity. Keep deployed permissions, allowance settings and solver authorization intact [s7].

The budget boundary cases expect the stand's existing full test budgets.
They must fail if prior public consumption changes that precondition.
Do not reset a public allowance to make a test pass [s6][s7].

## 2. Run the cases

```sh
# Pin the latest block and run the existing stand's three test suites.
just --justfile sepolia.just test-current

# Repeat at the recorded block.
SEPOLIA_STAND_BLOCK=11977056 just --justfile sepolia.just test-current
```

All mutations run in Forge's isolated forks.
Tests use impersonation and time changes.
The runner sends only RPC reads to Sepolia.
It checks the canonical block hash again after the run.
It saves the block, solver evidence, test names and source hashes with the result.
Each attempt removes the previous success report before preparation [s7].

| Flow | Observable acceptance | Named test | Basis |
|---|---|---|---|
| Account graph | Expected owners, thresholds, modules and CoW verifier remain present | `test_account_graph_and_domain_verifier` | [s1][s7] |
| Keys and holders | All four new roles execute; old and wrong-account keys fail with `NoMembership`; a non-member fails with `NotAuthorized` | `test_role_keys_reject_old_wrong_account_and_non_member` | [s5][s7] |
| WETH funding | Committee Safe funds Orders at the budget boundary; excess and a wrong recipient fail; refill permits another transfer | `test_funding_budget_and_safe_owner_path` | [s2][s7] |
| USDC funding | Transfer consumes the budget; one extra raw unit fails; refill permits another transfer | `test_usdc_budget_boundary_and_refill` | [s2][s7] |
| Presign and cancellation | Exact order gets a presignature; unsign clears it; wrong receiver, excessive duration and operator approval fail | `test_typed_order_presign_unsign_and_receivers` | [s2][s7] |
| Order bounds and Asset isolation | Operator duration at 90 days succeeds; unlisted tokens and excess fee fail; Asset cannot presign or approve the relayer | `test_order_boundaries_and_asset_signing_are_restricted` | [s2][s7] |
| Market and limit execution | Synthetic clearing settles to Asset; a price below the limit fails without a fill or debit; cancellation prevents settlement | `test_market_and_limit_settlement_and_cancelled_order_refusal` | [s2][s7][s8] |
| TWAP signatures | Two parts have distinct digests; emergency removal blocks further generation; wrong receiver and excessive parts fail | `test_twap_two_parts_signature_and_cancellation` | [s2][s7] |
| TWAP execution | Two parts settle to Asset through EIP-1271; removal makes the cached next signature unusable | `test_twap_settles_two_parts_and_cancelled_next_part_fails` | [s2][s7][s8][s9][s10] |
| First-loss redemption | Both shares complete redeem, synthetic queue settlement and claim to Agent; direct burn, transfer, approve and another receiver fail | `test_first_loss_redeem_claim_both_assets_and_denied_bypass` | [s3][s7] |
| First-loss burn | Both shares burn after the window; early enactment, an objected motion and a Voting-cancelled motion fail | `test_burn_motion_wait_objection_and_voting_cancellation` | [s3][s7] |
| Governance restrictions | Executor revokes the new Asset key; old/wrong keys, administrative targets, delegatecall expansion and membership changes fail; Orders has no governance role | `test_governance_executor_restricts_keys_membership_and_administrative_targets` | [s4][s5][s7] |
| Asset switch | Emergency disables the operator modifier; safety remains enabled; Emergency cannot re-enable the operator | `test_emergency_stops_asset_operator_but_cannot_restart` | [s1][s7] |
| Recovery and restart | Stop both operator paths, cancel an existing order and TWAP, settle a bounded recovery order to Agent, sweep funds and zero approvals; Voting restores operations; cancelled orders stay invalid | `test_emergency_recovery_zero_approvals_and_voting_restart` | [s1][s2][s5][s7] |

Passing a named test closes only its explicit assertions.
For example, the WETH funding test checks a wrong receiver after budget exhaustion.
Its generic `ConditionViolation` does not isolate the receiver check.
FUND-03 therefore stays open.
The account graph case checks expected owner/module presence, not exact sets; CFG-03/04 stay partial [s7][s12].

The suites are `SepoliaStandTest`, `SepoliaCurrentStandTest` and `SepoliaCoWSettlementTest`.
The original `rehearse` recipe still creates a separate disposable local stand.
Its seven shared cases select role keys from that rehearsal's manifest [s7].

## 3. Record results

Keep `drills.log` and `result.json` under `cache/sepolia/current-stand/`.
The result must identify the canonical block hash, the solver's source transaction and the SHA-256 hashes of the test sources and manifest.
Keep these local evidence files outside Git.
Record the outcome and its limitations in this plan [s7].

The initial run at block `11977056`, hash `0xd348dd8716e26bfbc5f611e883d1209e7a9591448f4dc1774a87f62021eb6291`, failed all seven original cases.
The failures exposed obsolete role keys and missing First-loss funding assumptions.
The updated seven shared cases passed at the same block before the additional cases were added.
The initial output is retained as `before-role-update.log` [s11].

The final current-stand run on 2026-10-23 passed all 14 named cases across three suites, with no failures or skips.
It used block `11977122`, hash `0xf8f1f619be3392ac883deea5b83d569c0f2e8ff239d7cb77e49a62ebf5bb12ef`.
The solver `0xe40cbca4d703642778b40e1e866ebfec1e619872` came from settlement transaction `0x0a631f36cf1f5c6dd352b30d0aa941494665f969a53be57ecd83d1f4f32b18df`.
The deployed authenticator confirmed its authorization at the pinned block.
The runner checked the source hashes and canonical block hash after the tests [s7][s11].

## TC-SEP-001: First Committee funding transfer

**Purpose:** verify one actual Committee-to-Asset-role WETH transfer and its accounting.
This case closes only the checks selected in the table below.
It does not close the allowance boundary, receiver-denial, refill, USDC, CoW or emergency cases [s1][s2][s12][s13].

**Scope:** owner EOA → Committee Safe → Asset Roles `execTransactionWithRole` → Asset Safe → WETH `transfer` → Orders.
The role is `asset-operator`; the budget key is `orders_weth`.
Both execution operations are CALL, and the ETH value is zero [s5][s13].

**Preconditions:** Sepolia `11155111`; correct Committee owner and threshold; active Asset operator module; correct Roles wiring; sufficient WETH and allowance.
Record the block/hash, both token balances, allowance and Committee nonce before execution.
The prepared snapshot uses block `11977379`, hash `0x9b4d72bf304a1f027ed97376ab5670148fbf048a1c173d3d96d6d53a748c32b4` [s13].

| Item | Prepared value |
|---|---|
| Committee | `0x1d7fC39145bb81dE7b36729760F873396555420a` |
| Asset | `0x464f188165BCbE8f7FB3776C10E7B185963922ae` |
| Asset Roles | `0x6b3dB3a3B4D9cB4bd697256E9fb1f1D19992DAC3` |
| WETH | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| Orders receiver | `0x84d6FFF030e0899a7fbFE505e2dEa199d7842cF0` |
| Transfer amount | `10000000000000000` raw WETH units |
| Initial Asset / Orders WETH | `20000000000000000` / `0` raw units |
| Initial stored budget / Committee nonce | `1000000000000000000` raw units / `0` |

Prepared values and outcomes below come from the saved payload and fork assertions [s13].

| Check ID | Selected component and acceptance | Fork result | Public result |
|---|---|---|---|
| TC-SEP-001-01 | Committee executes the exact prepared payload; low-level call succeeds and Safe returns true | PASS | OPEN |
| TC-SEP-001-02 | Asset WETH decreases by exactly `10000000000000000` | PASS | OPEN |
| TC-SEP-001-03 | Orders WETH increases by exactly the same amount | PASS | OPEN |
| TC-SEP-001-04 | Stored `orders_weth` balance decreases by exactly that amount, to `990000000000000000` | PASS | OPEN |
| TC-SEP-001-05 | Committee nonce increases from 0 to 1 | PASS | OPEN |
| TC-SEP-001-06 | Direct owner-EOA call to the same Roles payload fails with `NotAuthorized(controller)` | PASS | OPEN: read-only simulation is sufficient |
| TC-SEP-001-07 | WETH Transfer log, Safe execution outcome and canonical receipt agree with the payload and state deltas | OPEN: logs were not asserted in the prepared fork test | OPEN |
| TC-SEP-001-08 | Complete owners/modules/permissions/approvals diff contains no unintended change | OPEN: not asserted by this test | OPEN |
| TC-SEP-001-09 | Browser-imported envelope and displayed chain, role, target, amount and receiver match the reviewed payload | NOT APPLICABLE to the direct fork call | OPEN |

**Recorded execution:** two tests passed, none failed or skipped.
`test_exact_committee_transaction_moves_weth_and_consumes_budget` supplies checks 01–05.
`test_controller_cannot_call_the_committee_role_directly` supplies check 06.
These tests use the real fork balances and existing permissions, without balance top-ups or policy application.
The owner is impersonated with a prevalidated Safe signature; browser signing and an actual wallet signature remain open [s13].
The assertions compare relative deltas.
They do not assert the literal initial balances listed above or verify the canonical block hash.
The saved payload and post-state describe that historical snapshot; a repeat run needs its own precondition and canonicality record [s13].

**Evidence:** `cache/sepolia/first-transfer/transaction.json`, `safe-transaction-builder.json`, `FirstTransfer.t.sol`, `fork-tests.log` and `fork-result.json`.
The payload file SHA-256 is `2f86eea467bdc5ea2dfd431cc9e9de5b69844e58a8b81017b57eb7a99fcf1c49`.
The test-source SHA-256 is `9cc2f0cfaf3fe446e5338bbb016bfc8e5bac9f2600036f54fab345cf312e29e4`.
The log SHA-256 is `97400b50b871cf8ddddf599de287b1b672389fd9037c2bdd7e487fa6bd98e7b3` [s13].

**Public procedure:** refresh the preconditions; decode and compare the imported Committee transaction; run a fresh simulation; the owner reviews and signs; save the canonical receipt and read the post-state.
Mark checks 01–05 and 07–09 PASS only from their own public evidence.
Do not copy a fork PASS into the public column.
Record negative cases through simulation or on a fork unless a public failed transaction is needed.
Until these checks close, the public case is OPEN [s5][s12][s13].

## 4. Complete the public Sepolia drills

The owner must first check current balances, budgets, approvals, open orders and pending motions.
The owner must review the exact calls and choose the test funding amounts.
Use the existing guarded recipes and the owner's signing path [s5][s6].

- [ ] Repeat a fresh policy and account-state comparison before signing.
- [ ] Fund the stand once. Verify canonical receipts and balances before retrying an interrupted funding run.
- [ ] Execute an allowed call through the Committee wallet and inspect its displayed role, target and recipient.
- [ ] Submit market and limit orders to the Sepolia orderbook. Save UIDs and canonical settlement receipts.
- [ ] Submit and settle two TWAP parts. Cancel a separate order and TWAP before their next execution.
- [ ] Run both First-loss redemption and burn paths. Record objection and Voting cancellation separately.
- [ ] Run emergency stop, cancellation, recovery and approval cleanup after the ordinary flows.
- [ ] Review a separate Voting restart package. Confirm cancelled orders and motions remain unusable.

Public completion needs receipts, UIDs and before/after state.
A quote, API acceptance or a fork settlement cannot close a public settlement case [s6][s8].

## Coverage limits

- Fork settlement uses an impersonated, already-authorized solver and synthetic prices and liquidity. It tests the deployed settlement, signature, transfer and receiver paths. It does not test orderbook admission, solver discovery, competition, market pricing or public settlement availability [s7][s8][s9][s10].
- Most role calls impersonate the Committee or Emergency Safe. The funding and burn-motion cases also execute through the Committee Safe. Browser-wallet signing, independent signers and the screening guard need separate coverage [s1][s6][s7].
- First-loss uses the stand's deployed synthetic shares and queues. Its settlement is 1:1. These cases do not test real Earn shares, prices, liquidity or oracle reports [s3][s6][s7].
- The governance case enters the deployed test executor as Easy Track. It tests the executor-to-role path. It does not build a missing governance factory or prove its full motion lifecycle. The burn factory's motion lifecycle is tested separately [s4][s7].
- Mainnet Treasury funding, production governance, staking, wrapper/converter and vault integrations need their mainnet-fork coverage. Stop-loss and the token template are outside the launch scope [s2][s4][s6].
