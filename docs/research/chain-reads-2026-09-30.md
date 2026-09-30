---
type: Research Note
title: Chain reads for the design ADRs, 2026-09-30
description: Every on-chain fact that the design ADRs rely on, read at Ethereum block 26092572 with the exact command, so that anyone can reproduce it.
tags: [chain, evidence, governance, funding, swaps, safe]
status: stable
review_status: slop
valid_as_of: 2026-09-30
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-09-30T20:28:17Z
verified: []
sources:
  - id: s1
    resource: "https://etherscan.io/block/26092572"
    title: Ethereum block 26092572, the block every read on this page uses
  - id: s2
    resource: "https://etherscan.io/address/0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb"
    title: Lido DAO Aragon ACL
  - id: s3
    resource: "https://etherscan.io/address/0xF0211b7660680B49De1A7E9f25C65660F0a13Fea"
    title: Easy Track
  - id: s4
    resource: "https://etherscan.io/address/0xB9E5CBB9CA5b0d659238807E84D0176930753d86"
    title: Lido DAO Aragon Finance
  - id: s5
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EasyTrack.sol#L147"
    title: Easy Track source at 3183d1f — a motion takes its duration from the global setting
  - id: s6
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/EasyTrack.sol#L184"
    title: Easy Track source at 3183d1f — enactment requires the rebuilt script to match the stored hash
  - id: s7
    resource: "https://github.com/lidofinance/easy-track/blob/3183d1f68d47f5713e0183720aacd10a7dd12670/contracts/libraries/EVMScriptCreator.sol#L11-L25"
    title: Easy Track EVMScriptCreator at 3183d1f — spec id 0x00000001 and a uint32 length
  - id: s8
    resource: "https://github.com/safe-global/safe-deployments/blob/7b1fb6d615ab2d2999550ec9166554b180e813e5/src/assets/v1.5.0/safe.json"
    title: Safe deployments record for v1.5.0 — canonical address and codeHash
  - id: s9
    resource: "https://github.com/safe-global/safe-smart-account/releases/tag/v1.5.0"
    title: Safe smart account v1.5.0 release, published 2025-07-03
  - id: s10
    resource: "https://github.com/safe-global/safe-smart-account/tree/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/docs"
    title: Safe smart account docs at the v1.5.0 tag — Ackee and Certora audit reports for 1.5.0
  - id: s11
    resource: "https://etherscan.io/address/0x632C0CCDca849eeD780FC685BBa9AbC3c7407Cb2"
    title: Stonks factory
---

# Chain reads for the design ADRs, 2026-09-30

An agent ran every read on this page on 2026-09-30. All chain reads use Ethereum mainnet block 26092572, hash `0x7edb82d69fe2c018376bc6404ac94b278578e0f42af90fc2c7a217f23bfe23c5`, time 2026-09-30T20:05:47Z [s1]. Every command exited with status 0, except the two `RECEIVER()` calls that the Stonks table marks as reverted.

## How to reproduce

Set `ETH_RPC_URL` to an Ethereum RPC in your shell. `cast` reads it from the environment. Never write the URL into a file, because it often contains a key. Then set these variables and run the commands in the tables.

```sh
B=26092572
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c
ACL=0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb
DG=0x23E0B465633FF5178808F4A75186E2F2F9537021      # Dual Governance admin executor
EXE=0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977     # Easy Track EVMScriptExecutor
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea      # Easy Track
FIN=0xB9E5CBB9CA5b0d659238807E84D0176930753d86     # Aragon Finance
TMC=0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647     # Treasury Management Committee Safe
EB=0x73b047fe6337183A454c5217241D780a932777bD      # Emergency Brakes Safe
PAY=$(cast keccak CREATE_PAYMENTS_ROLE)
```

## Governance authority

| Fact | Command | Result |
|---|---|---|
| The Agent's ACL is the ACL used below | `cast call $(cast call $AGENT 'kernel()(address)' --block $B) 'acl()(address)' --block $B` | `0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb` |
| The Easy Track executor cannot run scripts as the Agent | `cast call $ACL 'hasPermission(address,address,bytes32)(bool)' $EXE $AGENT $(cast keccak RUN_SCRIPT_ROLE) --block $B` | `false`, and `getPermissionParamsLength` returns 0 |
| The Easy Track executor cannot execute calls as the Agent | the same call with `EXECUTE_ROLE` | `false`, 0 parameters |
| The Dual Governance admin executor holds both roles | the same two calls with `$DG` | `true` and `true`, 0 parameters each |

These results agree with the ACL [s2].

## Funding path

| Fact | Command | Result |
|---|---|---|
| Finance pays out of the Agent | `cast call $FIN 'vault()(address)' --block $B` | the Agent |
| The Easy Track executor holds a parametrised payment permission | `cast call $ACL 'getPermissionParamsLength(address,address,bytes32)(uint256)' $EXE $FIN $PAY --block $B` | 22 |
| Aragon Voting manages that permission | `cast call $ACL 'getPermissionManager(address,bytes32)(address)' $FIN $PAY --block $B` | `0x2e59A20f205bB85a89C53f1936454680651E618e` |
| Finance token budgets are off | `cast call $FIN $(cast calldata 'getBudget(address)' <token>) --block $B` for USDC, DAI and stETH | 64 zero bytes: budget 0, budgeted flag false |
| The committee is the trusted caller of an existing top-up factory | `cast call 0x6e04aED774B7c89BB43721AcDD7D03C872a51B69 'trustedCaller()(address)' --block $B` | the committee Safe; the factory's `finance()` is Finance and its `token()` is stETH |
| That factory's registry limits spending per period | `cast call 0x1a7cFA9EFB4D5BfFDE87B0FaEb1fC65d653868C0 'getLimitParameters()(uint256,uint256)' --block $B` | limit `12000000000000000000000`, period 6 months |

The 22 parameters come from `cast call $ACL 'getPermissionParam(address,address,bytes32,uint256)(uint8,uint8,uint240)' $EXE $FIN $PAY <i> --block $B` for `i` from 0 to 21 [s2][s4]. They form one chain: for each token, if argument 0 equals the token, then argument 2 must be at most the ceiling. The last entry returns false for every other token. Argument 1, the receiver, appears nowhere in the chain.

| Entries | Token, argument 0 | Ceiling on argument 2, raw | Ceiling in token units |
|---|---|---|---|
| 0–2 | stETH `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84` | `1000000000000000000000` | 1,000 |
| 3–5 | DAI `0x6B175474E89094C44Da98b954EedeAC495271d0F` | `2000000000000000000000000` | 2,000,000 |
| 6–8 | LDO `0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32` | `5000000000000000000000000` | 5,000,000 |
| 9–11 | USDC `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | `2000000000000` | 2,000,000 |
| 12–14 | USDT `0xdAC17F958D2ee523a2206206994597C13D831ec7` | `2000000000000` | 2,000,000 |
| 15–17 | ETH, address zero | `1000000000000000000000` | 1,000 |
| 18–20 | sUSDS `0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD` | `2000000000000000000000000` | 2,000,000 |
| 21 | any other token | — | denied |

USDS does not appear in the chain. The token-unit column divides by 10^6 for USDC and USDT and by 10^18 for the others.

## Easy Track

| Fact | Command or source | Result |
|---|---|---|
| Objection period | `cast call $ET 'motionDuration()(uint256)' --block $B` | 259200 seconds, 72 hours |
| Objection threshold | `cast call $ET 'objectionsThreshold()(uint256)' --block $B` | 50 basis points |
| Executor | `cast call $ET 'evmScriptExecutor()(address)' --block $B` | `$EXE` |
| Not paused | `cast call $ET 'paused()(bool)' --block $B` | `false` |
| Emergency Brakes can pause | `cast call $ET 'hasRole(bytes32,address)(bool)' $(cast call $ET 'PAUSE_ROLE()(bytes32)') $EB --block $B` | `true` |
| Emergency Brakes cannot unpause | the same call with `UNPAUSE_ROLE()` | `false` |
| A motion's duration comes from the global setting | source | `newMotion.duration = motionDuration;` [s5] |
| Enactment rebuilds the script and checks its hash | source | `require(evmScriptHash == keccak256(evmScript), ...)` [s6] |
| Script format | source | spec id `0x00000001`, then per call a 20-byte address, a `uint32` length and the call data [s7] |

These results agree with Easy Track on chain [s3].

## Committees

| Fact | Command | Result |
|---|---|---|
| Committee Safe version and quorum | `cast call $TMC 'VERSION()(string)'`, `'getThreshold()(uint256)'`, `'getOwners()(address[])'`, each with `--block $B` | 1.3.0, threshold 4, 7 owners |
| No guard is set on the committee Safe | `cast storage $TMC 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8 --block $B` | zero |
| Emergency Brakes Safe version and quorum | the same three calls on `$EB` | 1.3.0, threshold 3, 5 owners |
| The two Safes share no owner address | compare the `getOwners()` results of `$TMC` and `$EB` | no address in common. This does not prove that no person controls an address in both |

## Safe and Zodiac

| Fact | Command or source | Result |
|---|---|---|
| Safe v1.5.0 singleton version | `cast call 0xFf51A5898e281Db6DfC7855790607438dF2ca44b 'VERSION()(string)' --block $B` | 1.5.0 |
| Its runtime code matches the published record | `cast keccak $(cast code 0xFf51A5898e281Db6DfC7855790607438dF2ca44b --block $B)` | `0xdda019cbd7c867a533a2a86e5c53434fdc50b13122b5a5ddb4a8df61b31c20f2`, equal to the canonical `codeHash` in the deployment record [s8] |
| v1.5.0 release and audits | source | published 2025-07-03 [s9]; audit reports by Ackee and Certora at the tag [s10] |
| Only v1.5.0 has a module guard setter | selector `setModuleGuard(address)` searched in the runtime code of v1.5.0, v1.4.1 `0x41675C099F32341bf84BFc5382aF534df5C7461a` and v1.3.0 `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` | present in v1.5.0 only; `setGuard(address)` is present in all three |
| The Roles mastercopy is locked | `cast call 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5 'owner()(address)' --block $B` | `0x0000000000000000000000000000000000000001` |
| The Roles mastercopy has no guard hook | selectors `setGuard(address)` and `setModuleGuard(address)` searched in its runtime code | both absent |

Runtime code hashes recorded for later provenance checks, each from `cast keccak $(cast code <address> --block $B)`:

| Contract | Address | Runtime code hash |
|---|---|---|
| Safe v1.5.0 proxy factory | `0x14F2982D601c9458F93bd70B218933A6f8165e7b` | `0x967dae4cda22b0c9ef7f31b010bdc1ceb0af9904b0c3dc060b5302e4c18a4529` |
| Roles mastercopy | `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5` | `0x471d8b3b419f1eb955230c0326c8812176df49bf3c7b414a563fda5a3c6c10b6` |
| Zodiac module proxy factory | `0x000000000000aDdB49795b0f9bA5BC298cDda236` | `0x01623cbcf010a1c326230f1b2d5f48a66b440232ee49096102bc84967dc5f21e` |
| Stonks factory | `0x632C0CCDca849eeD780FC685BBa9AbC3c7407Cb2` | `0x9df901283e3dea92a6255ef02ee93821876141faa13e7243145f97d67a8fbe83` |

## Stonks

Each row calls `RECEIVER()`, `manager()`, `TOKEN_FROM()`, `TOKEN_TO()`, `ORDER_DURATION_IN_SECONDS()`, `MARGIN_IN_BASIS_POINTS()` and `PRICE_TOLERANCE_IN_BASIS_POINTS()` on the instance with `--block $B`.

| Instance | Pair | `RECEIVER` | `manager` | Duration, margin, tolerance |
|---|---|---|---|---|
| Stonks 2.0 `0xb368586CB980895E51e1D82102E63b3F69d3F151` | stETH to LDO | the Agent | `0x6c213ca5A10Cc26548C742229569B4AeD2A9C9B7` | 1800 s, 110 bp, 550 bp |
| Stonks 2.0 `0x8c595aA4AEc6F42B9e7D77F83179768D37CE3042` | stETH to LDO | `0x6c213ca5A10Cc26548C742229569B4AeD2A9C9B7` | `0x6c213ca5A10Cc26548C742229569B4AeD2A9C9B7` | 1800 s, 110 bp, 550 bp |
| earlier revision `0xf4F6A03E3dbf0aA22083be80fDD340943d275Ea5` | stETH to USDC | reverted: no receiver getter | the committee Safe | 1800 s, 110 bp, 550 bp |
| earlier revision `0x278f7B6CBB3Cc37374e6a40bDFEBfff08f65A5C7` | USDC to USDT | reverted: no receiver getter | the committee Safe | 1800 s, 30 bp, 150 bp |

The first Stonks 2.0 instance exposes `estimateTradeOutput(uint256)`, `placeOrder(uint256)`, `recoverERC20(address,uint256)`, `recoverEther()` and `recoverERC721(address,uint256)`: each selector is present in its runtime code. New instances come from the Stonks factory [s11].

## Limits of these reads

- A selector search shows that a selector is present in runtime code. It is strong evidence that the function exists. It is not proof of what the function does.
- Every result describes block 26092572. Governance can change any of them.
- These reads do not cover DataBus, Morpho Blue, the Lido Earn vaults or Lido Lend, which is not deployed.
