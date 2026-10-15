---
type: Research Note
title: The committee's Safe as the operator, reviewed again, 2026-10-15
description: The evidence behind keeping OD-80 and OD-83 on 2026-10-15 — the other duties and the activity of the committee's Safe, Lido's practice for trusted callers, the two alternatives (a new Safe with the same signers, and a Safe owned by the committee's Safe), and EM's answer.
tags: [safe, screening, governance, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-15
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-15T06:46:39Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's answer of 2026-10-15 on the operator Safe
  - id: s2
    resource: "https://etherscan.io/address/0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647"
    title: The Treasury Management Committee's Safe
  - id: s3
    resource: "https://github.com/lidofinance/docs/blob/1db0d3cbdb31ac84a941aa8c307b2d7d5a292c78/docs/multisigs/committees.md"
    title: Lido docs at 1db0d3c — the committees, their Safes, their purposes and their Easy Track factories
  - id: s4
    resource: "https://api.safe.global/tx-service/eth/api/v1/safes/0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647/multisig-transactions/?executed=true&limit=100"
    title: Safe Transaction Service — the executed transactions of the committee's Safe, read 2026-10-15
  - id: s5
    resource: "https://github.com/safe-global/safe-smart-account/blob/186a21a74b327f17fc41217a927dea7064f74604/contracts/GnosisSafe.sol#L286-L291"
    title: Safe v1.3.0 — an owner that sends the transaction itself signs with a type-1 signature
  - id: s6
    resource: "https://governance.aave.com/t/arfc-aave-finance-steward-deployment/21495"
    title: Aave — the finance committee's Safe is the guardian of the Finance Steward
  - id: s7
    resource: "https://governance.aave.com/t/arfc-update-signers-and-safe-configuration/22442"
    title: Aave, 2025-06-24 — several Safes brought back to the finance committee's signer composition
  - id: s8
    resource: "https://frameworks.securityalliance.org/wallet-security/secure-multisig-best-practices.html"
    title: SEAL Frameworks — secure multisig best practices
  - id: s9
    resource: "urn:clutch:restricted:operator-safe-review-2026-10-15"
    title: Restricted evidence of 2026-10-15 — the screening vendor's guard on Lido committee Safes, and a fork test of a Safe owned by a Safe under that guard
  - id: s10
    resource: /adr/010-pre-execution-screening.md
    title: ADR 010 — pre-execution screening and decision 24 (OD-83)
---

# The committee's Safe as the operator, reviewed again, 2026-10-15

On 2026-10-15 EM asked whether reusing the committee's Safe as the operator (OD-80, with the guard on it from the lift, OD-83) is better than the earlier design of a new operator Safe with the same signers. EM asked for a corridor test, the strongest and weakest case of each design, and Lido's earlier practice. This note keeps the evidence that can be published. The parts that identify the screening vendor stay restricted [s9].

## The answer

EM kept the recorded design: "let it be A still, I don't like to have a nested interim safe" [s1]. OD-80 and OD-83 stand. The committee's Safe holds the operator role and the first-loss role, it is the trusted caller of every Clutch factory, and from the lift of the launch cap it carries the screening guard ([ADR 010](/adr/010-pre-execution-screening.md) decision 24).

## What else the committee's Safe does

From the lift, the guard screens every transaction of the committee's Safe, so its other duties come under screening too [s10]. Those duties, read on chain for the committee's Safe [s2] (commands below):

| Duty | Contract | Read |
|---|---|---|
| Places treasury swaps on the Stonks instances, and creates their top-up motions | the Stonks instances [s4]; Easy Track factories `0x6e04…1B69` (stETH) and `0x0d2a…F5f6` (stablecoins) | the committee's Safe is the factories' `trustedCaller()` [s3] |
| Manages the Stonks 2.0 price router | `0x79ef…5a31` | `manager()` is the committee's Safe |
| Manages the LDO buyback executor, and can pause it | `0x6c21…C9B7` | the committee's Safe holds `MANAGER_ROLE` and `EMERGENCY_ROLE` |
| Manages the LDO buyback allocator | `0xAA56…D889` | the committee's Safe holds `MANAGER_ROLE` |

The Emergency Brakes multisig also holds `EMERGENCY_ROLE` on the buyback executor. No guard screens it, so the buyback pause stays available during a vendor outage.

From 2024-04-19 to 2026-09-14 the committee's Safe executed 80 transactions, 18 of them in the last 12 months [s4]:
- 47 Stonks orders;
- 28 transactions that create Easy Track motions;
- 3 owner rotations, with 6 seat changes in all (2024-07-01, 2025-12-22, 2026-06-10);
- 1 token recovery;
- 1 batch to the price router.

None was urgent.

## Lido's practice

- **Committees act through one Safe.** At block 26196058, Easy Track has 52 factories, and 49 of them name a trusted caller. They name 14 distinct Safes. 13 of them are committee Safes listed in Lido's docs [s3], and the 14th is the Safe of a Lido programme [s9]. Several committees run four to nine factories from that one Safe. None uses a separate operator Safe.
- **Screening covers whole committee Safes.** Lido's arrangement with the screening vendor covers four committee Safes. On 2026-10-15 one of them enforces its guard, and three are not attached yet [s9].
  - It has enforced since 2026-07-17: 23 screened executions.
  - The median from the vendor's approval to execution is 207 blocks, about 41 minutes.
  - No one has started the removal timelock.

## The two alternatives

1. **A new operator Safe with the same seven signers** (the design of 2026-10-02 to 2026-10-14). This needs a second signer set that must follow the committee by hand. The committee changed six seats in 29 months. At Aave, a governance post of 2025-06-24 had to bring several Safes back to the finance committee's signer composition [s7]. SEAL also advises a dedicated signer address per multisig [s8], which would add seven new signer addresses.
2. **An operator Safe owned 1 of 1 by the committee's Safe, with the guard on it only.** Safe accepts a transaction that its owner sends itself (a type-1 signature) [s5].
   - A restricted fork test passed with the vendor's guard bytecode on Safe v1.3.0 and v1.5.0 [s9]: the guard refused an unapproved action and let an approved one run through the Roles modifier as the Asset Safe; the owner swap and the 10-day removal path also worked.
   - Gain: the guard stays on vault activity, and one owner swap could move the operator without new factories.
   - Cost: one more Safe, and every operator action becomes a nested execution.
   - EM did not choose it [s1].

Aave's finance committee holds its scoped Finance Steward role directly on its own Safe [s6][s7]. That is the same shape as OD-80.

## Consequences of keeping the design

- A vendor outage can stop the duties in the table for at most the 10 days of the removal timelock. The buyback pause stays with Emergency Brakes.
- The committee's Safe keeps no module while the guard is set (INV-010).
- To move the operator role to another Safe, the DAO must vote to deploy and register every Clutch factory again, because the trusted caller is fixed.

## How to reproduce

Set `ETH_RPC_URL` to an Ethereum RPC in your shell. Never write the URL into a file. Then:

```sh
TMC=0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647   # the committee's Safe
EB=0x73b047fe6337183A454c5217241D780a932777bD    # the Emergency Brakes Safe
ET=0xF0211b7660680B49De1A7E9f25C65660F0a13Fea    # Easy Track
BX=0x6c213ca5A10Cc26548C742229569B4AeD2A9C9B7    # LDO buyback executor
BA=0xAA568141c051f2D1132b110f8391F18D48E8D889    # LDO buyback allocator
OR=0x79ef3a538200Fe4981D67E7e886bfb36D4Cb5a31    # Stonks 2.0 price router

# the Safe's shape, block 26193529: 1.3.0, 4 of 7, no modules, no guard, nonce 80
B=26193529
cast call $TMC 'VERSION()(string)' --block $B
cast call $TMC 'getModulesPaginated(address,uint256)(address[],address)' 0x0000000000000000000000000000000000000001 10 --block $B
cast storage $TMC 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8 --block $B

# the other roles, block 26196103
B=26196103
for R in EMERGENCY_ROLE MANAGER_ROLE; do H=$(cast call $BX "$R()(bytes32)" --block $B)
  cast call $BX 'hasRole(bytes32,address)(bool)' $H $TMC --block $B
  cast call $BX 'hasRole(bytes32,address)(bool)' $H $EB --block $B; done
cast call $BA 'hasRole(bytes32,address)(bool)' $(cast call $BA 'MANAGER_ROLE()(bytes32)' --block $B) $TMC --block $B
cast call $OR 'manager()(address)' --block $B

# the trusted callers of Easy Track's factories, block 26196058
B=26196058
for F in $(cast call $ET 'getEVMScriptFactories()(address[])' --block $B | tr -d '[] ' | tr ',' ' '); do
  echo "$F $(cast call $F 'trustedCaller()(address)' --block $B 2>/dev/null || echo none)"; done

# the transaction history (Safe Transaction Service, no key needed)
curl -s "https://api.safe.global/tx-service/eth/api/v1/safes/$TMC/multisig-transactions/?executed=true&limit=100"
```

Read on 2026-10-15. Results: the buyback executor's `EMERGENCY_ROLE` is true for both Safes, and its `MANAGER_ROLE` is true for the committee's Safe only. The allocator's `MANAGER_ROLE` is true for the committee's Safe. The router's manager is the committee's Safe. Two factories name the committee's Safe as trusted caller.
