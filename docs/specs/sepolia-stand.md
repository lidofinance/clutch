---
type: Guide
title: Sepolia stand
description: The Sepolia test stand — its accounts, roles and addresses, the recipes that build and test it, and its open items.
tags: [sepolia, deployment, testing, cow, first-loss]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-11-16T17:54:56Z
verified: []
sources:
  - id: s1
    resource: /adr/005-account-graph-and-roles.md
    title: ADR 005 — account owners, modifiers, role holders and emergency controls
  - id: s2
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — market, limit and TWAP orders, recipients, approvals and cancellation
  - id: s3
    resource: /adr/008-funding-through-existing-payments.md
    title: ADR 008 — first-loss shares, redemption and burn motions
  - id: s4
    resource: /adr/013-one-easy-track-factory.md
    title: ADR 013 — one Easy Track factory that holds every motion role
  - id: s5
    resource: /adr/015-tests-on-sepolia.md
    title: ADR 015 — public Sepolia transactions by the stand owner, the guards and the Sepolia workspace
  - id: s6
    resource: /registers/decision-log.md
    title: Decision log — the stand owner's choices of 2026-11-13 and 2026-11-16
  - id: s7
    resource: /research/sepolia-test-results.md
    title: Sepolia test results — runs, public transactions and findings
  - id: s8
    resource: /specs/sepolia-setup-checklist.md
    title: Sepolia setup coverage checklist — coverage IDs and their states
  - id: s9
    resource: urn:clutch:instruction:2026-10-20:sepolia-one-key
    title: Stand owner instruction — Committee and Emergency 1/1, one controller for test Voting
  - id: s10
    resource: urn:clutch:source:sepolia-current-stand-tests
    title: Current-stand runner and the Sepolia stand, coverage and motion tests
  - id: s11
    resource: urn:clutch:source:sepolia-stand-manifest
    title: scripts/fixtures/sepolia-stand-manifest.json — the stand's addresses
  - id: s12
    resource: https://docs.lido.fi/deployed-contracts/sepolia/
    title: Lido — deprecated Sepolia deployment
  - id: s13
    resource: urn:clutch:evidence:2026-11-10:sepolia-coverage-review
    title: Coverage review of 2026-11-10 — no Sepolia recipe in CI; fork inputs in the git-ignored cache
---

# Sepolia stand

The Sepolia stand is a copy of the Clutch account graph on the Sepolia test network.
Its tokens, shares and budgets have no value.
It tests the permissions, the recipes and the CoW and Easy Track paths before mainnet [s5][s7].

Only the stand owner sends public Sepolia transactions, through `sepolia.just` and its guards (OD-150 A) [s5].
Agents compile the policy, compare the chain with the artifact and test on forks. Agents never sign or send a transaction.
The [results](../research/sepolia-test-results.md) hold every public transaction and run. The [checklist](sepolia-setup-checklist.md) holds the coverage IDs [s7][s8].

## Accounts

| Safe | Version | Owner | Use |
|---|---|---|---|
| Committee | 1.3.0 | Controller, 1/1 | Calls the operator and first-loss roles; creates motions |
| Emergency | 1.5.0 | Controller, 1/1 | Calls the emergency roles on Asset and Orders |
| Asset | 1.5.0 | Test Voting | Operator and safety modifiers |
| Orders | 1.5.0 | Test Voting | Orders modifier, CoW fallback handler and domain verifier |
| First-loss | 1.5.0 | Test Voting | First-loss modifier |

One externally owned account, the controller, owns Committee and Emergency.
It also controls test Voting, test Agent and the mock Easy Track.
The stand therefore does not test signer independence [s9].
Test Agent is the recovery recipient, not an owner [s1].

## Roles

The four modifiers hold 14 roles. The universal factory holds the nine motion roles [s4][s6].

| Modifier | Committee | Emergency | Universal factory |
|---|---|---|---|
| operator | `asset-operator` | — | `governance`, `insurance-funding` |
| safety | — | `asset-emergency` | `restart`, `exit-governance` |
| orders | `orders-operator` | `orders-emergency` | `orders-governance`, `approvals` |
| first-loss | `first-loss` | — | `first-loss-burn`, `insurance`, `insurance-governance` |

The Easy Track executor holds no role and is not a module of a modifier. The burn factory is retired [s6].
The orders modifier's governance role has the key `orders-governance`. The [decision log](/registers/decision-log.md#2026-11-16--yt-renames-the-orders-modifiers-governance-role-on-the-sepolia-stand) records why. On `main`, the governance role has the key `governance` on both modifiers [s6].

## Addresses

The manifest fixture holds the current addresses [s11].

| Name | Address |
|---|---|
| Controller | `0x4CAE8fd384bbe8dec68CdFbC2CbE4b398902E03c` |
| Committee Safe | `0x1d7fC39145bb81dE7b36729760F873396555420a` |
| Emergency Safe | `0xbe6C8C7b8C25Cd971B5c9d3bA142B7Ddc8e33699` |
| Asset Safe | `0x464f188165BCbE8f7FB3776C10E7B185963922ae` |
| Orders Safe | `0x84d6FFF030e0899a7fbFE505e2dEa199d7842cF0` |
| First-loss Safe | `0xA95A6404282Ecd4E39Abe3FDc062754f3281E391` |
| Operator modifier | `0x6b3dB3a3B4D9cB4bd697256E9fb1f1D19992DAC3` |
| Safety modifier | `0xC81495c3a0EEFADb9267060fB27537b0A3175BE9` |
| Orders modifier | `0x05E79600EC4d5f2c36DFD863ABe62753f3c6447a` |
| First-loss modifier | `0xaD714Fc01DFb104Eb9438d54472193884A8a2B27` |
| Test Voting | `0x70974d5DB20099A785BE59b13DB327a251829D89` |
| Test Agent | `0x23fD73dBaA3A5EcE6d388f8f7C0022a869826061` |
| Mock Easy Track | `0x0b72857f6Ee18185d709a14479C8d0a02957c619` |
| Easy Track executor | `0x61e0EdCDd74035C36AA218D964899CC74c201f25` |
| Universal factory | `0x07F2B0ede13A13c808D4ae0Aa0977748630c564F` |
| Burn factory (retired) | `0xf1C2Ccd3c37f86A3a0742543d325d5a4Ed78175a` |
| Objection token | `0xf5f05f6BAE35E6471e29b44913F2f4bDCc181b44` |
| USD share, redemption queue, claim asset | `0xF8956fe3a1AFA82Cca47Bf4bC18Cf0c947f14DE3`, `0xab0C036cC97Bb6139431c4559Ff3139DFA90560B`, `0x68532fC13E23EfC5205d223ba022f18bA3C93e9e` |
| ETH share, redemption queue, claim asset | `0x86c6E0D5723eD67f5537e71A92a857b6a3Aa9290`, `0x22d549e6697042958678b6Ae44eE955a726ceef5`, `0xCd28060f257faF58aE14563fb8d199821e3D27ee` |
| USD and ETH deposit queues | `0x29f21a3132aF2F4Ed7Ec65d7f621a12562a5d617`, `0x7796bC1bd8A828D05557Bae0AdD3F0626C71217e` |
| WETH (18 decimals), test USDC (6 decimals) | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`, `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |

## Flow

Put `SEPOLIA_RPC`, `SEPOLIA_ACCOUNT`, `SEPOLIA_SENDER` and `ETHERSCAN_API_KEY` in the git-ignored `.env`.
Keep the keystore password and any private key out of `.env`.
Run each recipe as `just --justfile sepolia.just <recipe>`.
A public recipe runs only with `CLUTCH_SEPOLIA=1`.
It refuses to run in CI or when `PRIVATE_KEY` or `EXECUTOR_KEY` is set.
Foundry asks for the keystore password [s5].

| Recipe | What it does | Public |
|---|---|---|
| `check` | Runs the offline tests of the Sepolia scripts and policy code | No |
| `preflight` | Checks the chain ID and the code hash of each pinned dependency. Reads the sender's balance | No |
| `rehearse` | Builds a fresh stand on a local Anvil fork and runs deploy, compile, apply, fund, every motion, the comparison of the chain with the artifact and the drills. It stops Anvil after the run | No |
| `deploy` | Runs `preflight`, then deploys the stand, the deposit queues and the universal factory in one script. It writes `cache/sepolia/manifest.json`, and refuses to run when that file exists | Yes |
| `compile` | Compiles the policy for the manifest into `cache/sepolia/policy.json` | No |
| `apply` | Compiles the policy, then applies the artifact through test Voting | Yes |
| `fund` | Wraps Sepolia ETH and sends the WETH to the Asset Safe. Sends test shares to the First-loss Safe | Yes |
| `motion <name>`, `enact <id>` | `motion` creates one motion from the Committee Safe and saves its input under the motion id. `enact` enacts the motion after the motion duration | Yes |
| `emergency-stop` | The Emergency Safe disables the operator modifier on the Asset Safe | Yes |
| `constellation <workspace>` | Compares the chain with the artifact, then writes the local SDK payload | No |
| `test-current` | Runs the stand suites on a pinned fork of the current stand | No |
| `constellation-resolve`, `constellation-publish` | Hosted calls to the Sepolia workspace, for the stand owner only | No transaction |

Rules for each run:

1. Run `check`, `preflight` and `rehearse` before a public run. The rehearsal must pass.
2. `deploy` stops if a manifest exists. The current stand has a manifest. A second stand needs a new decision (OD-150 A) [s5].
3. No recipe resumes an interrupted public run. Inspect the receipts of the run and the chain. Then run the recipe again from the start. A second `fund` wraps and sends the full amounts again.
4. Enact each policy motion before you create the next one, because a policy motion changes the policy version.
5. After each public change, run `constellation <workspace>`. It must show 0 differences. Then run `test-current`. All suites must pass. To replay a recorded block, set `SEPOLIA_STAND_BLOCK=<block>` [s10].

Example of a `fund` run:

```sh
SEPOLIA_FUND_WETH_WEI=20000000000000000 \
SEPOLIA_FUND_SHARES_WEI=10000000000000000000 \
CLUTCH_SEPOLIA=1 just --justfile sepolia.just fund
```

### Public motions

`motion <name>` takes one of the names below. Create the motions in this order. Run `emergency-stop` before `restart`.
Each motion that changes only the policy scopes a target that the policy already scopes. After the motion, the chain still matches the artifact [s7].

| Name | Role | Writes |
|---|---|---|
| `caps` | `governance` | Insurance-funding caps of 1 WETH and 1000 USDC in 30 days, under the First-loss Safe's derived keys |
| `insurance-funding` | `insurance-funding` | 0.005 WETH from the Asset Safe to the First-loss Safe |
| `insurance` | `insurance` | Approve and deposit 0.005 WETH in the ETH deposit queue |
| `first-loss-burn` | `first-loss-burn` | Burn 1 USD share |
| `approvals` | `approvals` | The maximum WETH approval of the Orders Safe to the vault relayer (no change) |
| `orders-governance` | `orders-governance` | `scopeTarget(orders-operator, WETH)` (no change) |
| `exit-governance` | `exit-governance` | `scopeTarget(asset-emergency, WETH)` (no change) |
| `insurance-governance` | `insurance-governance` | `scopeTarget(insurance, WETH)` (no change) |
| `restart` | `restart` | `enableModule(operator modifier)` on the Asset Safe |

Read the Asset Safe's WETH balance before `insurance-funding`. No stand suite checks the public balance [s7].

### Hosted calls

Only the stand owner runs `constellation-resolve` and `constellation-publish`, with `CLUTCH_SEPOLIA_PUSH=1`, `SEPOLIA_ZODIAC_API_KEY` and `SEPOLIA_ZODIAC_WORKSPACE` in `.env` [s5].
Both recipes refuse to run in these cases:

- in CI
- on another branch
- with local changes
- with a commit that is not pushed
- without the API key
- for a workspace other than the workspace of the prepared payload

Each recipe compares the chain with the artifact again, and checks the payload against the chain's allowances. Then it calls resolve and compares the result with the payload.
`constellation-publish` calls apply only once for each API URL, workspace and payload hash. It writes an attempt record and refuses a second apply for the same record.
Review the transactions of a Zodiac draft before you deploy the draft.

## Test cases

`test-current` runs these test families. The runner lists the exact test set [s10].

| Case | What to test | Tests |
|---|---|---|
| Configuration | Owners, thresholds, modules, guards, handlers, runtime code, approvals; Safe nonce and signature replay | `test_account_graph_and_domain_verifier`, `test_CFG_*` |
| Roles | Account keys, holders and avatars; old keys, wrong-account keys and non-members | `test_role_keys_*`, `test_CFG_actor_matrix_*` |
| Funding | WETH and USDC from Asset to Orders; budget edges, decimals, recipient, refill, rollback | `test_funding_budget_*`, `test_usdc_budget_*`, `test_FUND_*` |
| Orders | Sign and unsign; directions, kinds, fills; EIP-712 fields, UID, expiry, fee and receiver bounds | `test_typed_order_*`, `test_order_boundaries_*`, `test_quote_*`, `test_ORD_*` |
| Settlement | Market and resting orders; deltas, prices, fees, overfill, cancellation, missing funds or approval | `test_market_and_limit_*`, `test_SETTLE_*` |
| TWAP | Two settled parts; schedules, interval edges, proofs, replay, removal, forbidden handlers | `test_twap_*`, `test_TWAP_*` |
| First-loss | Redeem, synthetic settlement, claim to Agent, duplicate claims, forbidden routes | `test_first_loss_*`, `test_FL_*` |
| Burn motions | Trusted caller, window, objection, cancellation, removed factory, failed burn | `test_burn_motion_*`, `test_ET_*` |
| Motion roles | One universal-factory motion for each motion role; counter, policy version, creator and cancellation | `test_MOT_*` |
| Governance | Target and function changes, key restrictions, delegatecall, allowance bounds, stale owner restore | `test_governance_executor_*`, `test_GOV_*` |
| Emergency | Asset switch, Orders revokes, cancellations, recovery to Agent, sweeps, zero approvals, restart | `test_emergency_*`, `test_EM_*` |
| Scripts | Configuration drift, submission retry, guards and result integrity | `check` |

Section K of the checklist lists the mainnet cases that the stand cannot test [s8].

## Differences from production

| Stand | Production check |
|---|---|
| One controller owns the 1/1 Committee and Emergency Safes | Use the accepted owners and thresholds, and test each signer's path [s9] |
| Voting, Agent and Easy Track are test contracts that the controller controls | Test the production contracts on a mainnet fork [s1] |
| The First-loss Safe uses test shares and queues with 1:1 settlement | Test the real shares, prices, liquidity and oracle reports. Lido's Sepolia deployment is deprecated [s3][s12] |
| Budgets, motion timing and objection settings are test values | Use the accepted configuration and repeat the allowed and refused cases [s2] |

## Open items

- OPS-01: connect the Committee signer in a browser wallet and sign an allowed call through its role [s8].
- OPS-02: the Zodiac UI shows a budget's key, not its remaining amount. Read budgets through RPC [s8].
- The checklist rows still at P (partial evidence): CFG-02, SETTLE-04, ET-05, GOV-09, EM-05, OPS-03, OPS-04, OPS-06, OPS-07, OPS-08 and OPS-10 [s8].
- No Sepolia recipe runs in CI, so a regression does not block a merge [s13].
- The evidence and two fork inputs are in the git-ignored `cache/`. A clean clone cannot repeat the fork run [s13].
