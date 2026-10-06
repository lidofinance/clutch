---
type: Specification
title: "LIP draft: Active Treasury Management Vault"
description: The external proposal for Clutch in Lido Improvement Proposal format, drafted during the design review and aligned with the ADRs; it summarises the specifications and must never contradict them.
tags: [lip, proposal, governance, specification]
status: draft
review_status: slop
generated:
  by: claude-code/opus-5.5
  at: 2026-10-06T08:52:19Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's design answers of 2026-09-22
  - id: s2
    resource: /adr/index.md
    title: Decision records ADR 001 to ADR 011
  - id: s3
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads at block 26092572
  - id: s4
    resource: "https://github.com/lidofinance/clutch/tree/7a8c6613602a0078807298b1cebb513af2d74bd5/test"
    title: Kit test suites at 7a8c661
  - id: s5
    resource: "https://github.com/safe-global/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/base/ModuleManager.sol#L94-L108"
    title: Safe v1.5.0 ModuleManager — the module guard is called for every enabled module
  - id: s6
    resource: "urn:clutch:restricted:screening-guard-2026-10-02"
    title: Restricted evidence on the screening vendor's existing guard; held outside the repository until the vendor is announced
  - id: s7
    resource: /research/funding-registries-2026-10-02.md
    title: Easy Track funding registries, 2026-10-02 — how a registry counts, the fixed payment reference, and the live registries
  - id: s8
    resource: /research/safe-v150-due-diligence-2026-10-05.md
    title: Safe v1.5.0 due diligence, 2026-10-05 — audits, advisories, use and value on mainnet, incidents, and the Safe paths the vault uses
  - id: s9
    resource: /research/stonks-pricing-2026-10-05.md
    title: Stonks 2.0 pricing, 2026-10-05 — the converter, the shared router, Chainlink's registry, feed replacements, and the WETH route
  - id: s10
    resource: /research/legacy-investments-2026-10-05.md
    title: Legacy investments, 2026-10-05 — the first-loss Earn shares and their Growth Committee holder
---

# LIP-XX: Active Treasury Management Vault

| LIP field | Value |
|---|---|
| lip | to be assigned |
| title | Active Treasury Management Vault |
| status | WIP |
| author | to be filled by proposers |
| discussions-to | a thread on https://research.lido.fi/, to be created |
| created | 2026-09-22 |

> **Where this draft stands.** It was written during the design review of 2026-09-10 to 2026-09-22 and moved into this repository on 2026-09-30. The [ADRs](/adr/index.md) record the decisions, and this draft must never contradict them [s2]. The chain facts that the ADRs rely on were re-read at block 26092572 [s3]. Any other chain fact in this draft is a claim from the design review that was not re-run. EM chose the screening route on 2026-10-02, and section 9.1 records it. EM chose the funding period and limit the same day, and section 5.2 records them. Open items are in the [open-decisions register](/registers/open-decisions.md).

> **Draft status.** Sections marked **[Implemented]** are built and covered by tests against deployed mainnet bytecode on a pinned fork. Sections marked **[Specified]** are designed but not built. Sections marked **[Open]** need a decision before this proposal can be finalised. No component has been deployed to mainnet. No audit has been performed.

## Simple Summary

Give the Treasury Management Committee a way to put a bounded slice of the DAO treasury to work in approved DeFi protocols, without ever letting it, or any service provider, take the assets. The DAO keeps ownership. An on-chain permission layer decides what the committee may do. An emergency Safe, held by the committee's own signers at a lower quorum, can pull everything back. The Emergency Brakes multisig can switch the operator off. Easy Track motions onboard protocols, inside templates fixed at audit time. Every removal is an immediate action of the emergency Safe.

## Abstract

We propose to deploy a Safe controlled solely by the Aragon Agent, and to attach two Zodiac Roles modifiers to it that enforce default-deny permissions. The **operator modifier** carries an **operator** role held by the Treasury Management Committee multisig and a **governance** role held by the Easy Track script executor. The **safety modifier** carries an **emergency** role held by a new Safe with a threshold of two and the same signer set as that committee, and a **technical** role held by the Emergency Brakes multisig.

All swapping, routine and emergency, runs through the DAO's existing treasury swap contracts, which price orders from an on-chain oracle and settle to a receiver fixed at deployment. Easy Track motions onboard new protocols and assets and adjust budgets within ceilings. Every removal is the emergency Safe's immediate revoke. Motions never submit a permission tree. Each factory generates the tree itself from a fixed template, so the shape of every permission is decided at audit time and only its parameters arrive by motion.

The only new contracts are Easy Track EVM script factories. No bespoke access-control, vault, or accounting contract is introduced. Funding reuses the existing Finance application and allowed-recipients machinery already in production.

## Motivation

### Background

The DAO treasury holds idle assets. A [Treasury Management Committee](https://docs.lido.fi/multisigs/committees#25-treasury-management-committee) exists and, by the principles under which it was formed, never takes custody. Putting treasury assets to work therefore requires a system where the committee can transact but cannot possess, and where the DAO can reverse any of it.

### Problem

Three properties are needed at once and no existing Lido component provides them together.

1. **Custody must stay with the DAO.** The Aragon Agent must remain the only owner of the assets, and no provider outage, suspension, or contract termination may change that.
2. **Authority must be bounded before execution, not after.** A report-and-remediate control does not stop a transaction. The system must deny unapproved targets, functions, and parameters at execution time.
3. **Routine changes must not require a full DAO vote, and must still not be arbitrary.** Adding an approved strategy should be an Easy Track motion with an objection window. That motion must not be able to widen authority beyond what the DAO already approved.

A conventional multisig fails the second property. A provider-operated vault fails the first. Granting Easy Track general execution authority over the Agent fails the third, because it would let a motion forward any script as the Agent and would put the entire treasury behind a three-day objection window.

### Solution

Separate **custody**, **authority**, and **change control** into three layers that are already audited, and add only the thin glue that Easy Track's interface requires.

- Custody: a Safe owned one-of-one by the Aragon Agent.
- Authority: two Zodiac Roles modifiers enabled as modules on that Safe, with the Safe as their owner.
- Change control: Easy Track motions through purpose-built script factories, which build every permission from a template fixed at audit time.

## Specification

### Overview

```mermaid
flowchart TD
    VOTE["LDO vote"] --> DG["Dual Governance<br/>admin executor"]
    DG --> AGENT["Aragon Agent<br/>final authority"]
    AGENT -->|sole owner 1/1| SAFE["Asset Safe<br/>holds all assets"]
    SAFE -->|owns| ROLES["Operator modifier<br/>default deny"]
    SAFE -->|owns| SAFETY["Safety modifier<br/>default deny, never screened"]
    GUARD["Screening guard<br/>vendor-supplied"] -.->|screens| OPS

    ET["Easy Track"] --> EXEC["EVMScriptExecutor"]
    FACTORY["ET factories<br/>NEW CONTRACTS"] -.->|builds script| ET
    EXEC -->|governance role| ROLES

    TMC["TMC signers"] -.->|same signers| OPS["Operator Safe<br/>holds nothing, screened"]
    OPS -->|operator role| ROLES
    OPS -->|trusted caller, creates motions| ET
    EMS["Emergency Safe 2/7<br/>same signers as TMC"] -->|emergency role<br/>financial| SAFETY
    EB["Emergency Brakes 3/5<br/>technical committee"] -->|technical role<br/>disables operator modifier| SAFETY
    EB -.->|global pause| ET

    ROLES -->|approved calls only| DEFI["Approved protocols"]
    SAFE --> DEFI

    FIN["Finance app"] -->|payments| SAFE
    EXEC -->|parametrized payment role| FIN
```

Every role executes **as the Safe**. The modifier checks the call against that role's permissions, then calls `execTransactionFromModule` on the Safe. Because the Safe owns the modifier, a role can also be permitted to administer the modifier itself, which is how the emergency and governance roles work without anyone holding authority over the Agent.

### Rationale

**Why the Safe owns the modifier, rather than the Agent.** A role's call executes with the avatar's authority. If the avatar owns the modifier, a narrowly scoped role can perform administrative calls on the modifier without the Agent being involved. This is what lets the emergency committee revoke the operator in minutes, and what lets Easy Track change policy without ever holding Agent authority. It is a deviation from the naive layout where the Agent owns the modifier directly, and it is load-bearing.

**Why Easy Track never gets Agent authority.** At block 26092572 the Easy Track script executor holds neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Agent. Only the Dual Governance admin executor holds them [s3]. Granting the executor either role would make every Easy Track motion capable of forwarding arbitrary scripts as the Agent, which contradicts the requirement that Easy Track have no unrestricted execution authority. The governance role on the modifier gives exactly the needed power and nothing else.

**Why template factories instead of motion-authored permissions.** A permission in the modifier is a condition tree stored per role, target, and selector, and a write replaces that slot entirely rather than merging into it. If motions could submit trees, every motion would have to be checked on-chain for being strictly narrower than what it replaces, which is a tree-comparison problem nobody should solve under an objection window.

Template factories remove the problem without forcing a vote for every new protocol. A factory accepts a small, typed parameter set — a target address, an asset, a budget key — and builds the condition tree itself from a shape fixed in its own code. The operator can therefore onboard a protocol through an ordinary motion, and still cannot express a permission the template does not describe. What an audit reviews is the finite set of templates, not an open-ended space of trees.

**Why the emergency role is easier to reach than the operator role.** The emergency role can only reduce exposure: revoke, exit, and return assets to the Agent. Its powers point one way. A lower quorum on a one-way power shortens response time without widening what can be done with it.

**Why no bespoke controller.** An earlier design used a purpose-built controller contract to hold an allowlist, a stale-motion counter, and budget ceilings. Each of those jobs turned out to be available without new code. Easy Track re-invokes the factory at enactment and requires the regenerated script to hash-match, so the factory's own allowlist doubles as the stale-motion rule. Budget ceilings and a refill-rate floor are expressible as native conditions. Escalation guards belong in the modifier. The controller was removed.

**Why every swap goes through the treasury swap contracts.** A pre-signed exchange order is opaque to the permission layer: the sell token, buy token, amounts and receiver are committed inside a hash the modifier cannot read, so neither price nor destination can be constrained there, and the only bound left is a standing approval. Routing every swap through the DAO's existing treasury swap contracts moves both guarantees into audited code already in production. The minimum output is computed on-chain from an oracle rather than supplied by the caller, and the settlement receiver is fixed in the instance at deployment rather than chosen per order. The permission the vault needs then shrinks to a transfer with the recipient pinned, and no role needs a standing approval to an exchange relayer at all.

**Why approvals spend the budget.** An approval snapshot is not a loss bound if the operator can restore it, and a spender can pull what it is approved for without any deposit call. Each approval to a protocol spender therefore spends the budget of the key that the spender serves, so approvals per key per period cannot exceed the budget, whatever the spender does (OD-08).

### Technical Specification

---

#### Part 1: Account graph **[Implemented]**

| Component | Address | Source |
| --- | --- | --- |
| Aragon Agent | `0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c` | existing |
| Aragon ACL | `0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb` | existing, resolved via `Agent.kernel().acl()` |
| Dual Governance admin executor | `0x23E0B465633FF5178808F4A75186E2F2F9537021` | existing |
| Finance application | `0xB9E5CBB9CA5b0d659238807E84D0176930753d86` | existing, `vault()` returns the Agent |
| Easy Track | `0xF0211b7660680B49De1A7E9f25C65660F0a13Fea` | existing |
| EVMScriptExecutor | `0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977` | existing |
| TMC multisig | `0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647` | existing, threshold 4 of 7; its signers also sign the Operator Safe and the Emergency Safe |
| Emergency Brakes multisig | `0x73b047fe6337183A454c5217241D780a932777bD` | existing, threshold 3 of 5; holds the **technical** role and the global Easy Track pause |
| **Emergency Safe** | to be deployed | new Safe v1.5.0 instance, **threshold 2**, owner set identical to the TMC multisig. No guard |
| Safe singleton v1.5.0 | `0xFf51A5898e281Db6DfC7855790607438dF2ca44b` | reused. `VERSION()` returns `1.5.0`, and the runtime codehash equals `0xdda019cbd7c867a533a2a86e5c53434fdc50b13122b5a5ddb4a8df61b31c20f2`, matching the published deployment record. Released 2025-07-03, audited by Certora and Ackee at pinned commits, covered by the Safe bug-bounty programme. The Asset Safe, the Operator Safe and the Emergency Safe use v1.5.0, by EM's decisions of 2026-10-02 and 2026-10-05 [s1]. The screening vendor's guard passed the same fork suite on v1.3.0, v1.4.1 and v1.5.0 [s6], and the vendor confirmed its support for v1.5.0, as EM reported on 2026-10-05. None of the six Lido Safes checked runs v1.5.0 today. Its record of holding value is short; see Security Considerations [s8] |
| Safe proxy factory v1.5.0 | `0x14F2982D601c9458F93bd70B218933A6f8165e7b` | reused |
| Zodiac Roles mastercopy | `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5` | reused, `owner()` is `0x…01`, i.e. locked |
| Zodiac ModuleProxyFactory | `0x000000000000aDdB49795b0f9bA5BC298cDda236` | reused |
| **Asset Safe** | to be deployed | new instance of the singleton. No guard and no fallback handler are set on it. The Aragon Agent authorizes its transactions only by `approveHash` or by sending them itself, never by a contract signature (OD-17) |
| **Operator Safe** | to be deployed | new Safe instance with the TMC signers. Holds no assets and no modules. Threshold 4 of 7. Holds the operator role, is the trusted caller of every factory, and carries the screening guard |
| **Operator modifier** | to be deployed | minimal proxy of the mastercopy. Carries the operator and governance roles. The operator role is held by the Operator Safe, whose transactions are screened |
| **Safety modifier** | to be deployed | minimal proxy of the mastercopy. Carries the emergency and technical roles. Never screened |
| **Screening guard** | vendor-supplied | the screening vendor's existing transaction guard, one instance for the Operator Safe, set with `setGuard`. Not written by Lido |

The Emergency Safe and the Operator Safe are new instances of the audited Safe singleton, not new contract code. Their owner sets must be kept in step with the TMC multisig: a signer rotation on one is a rotation owed on all three, and that reconciliation is an operational duty with no on-chain enforcement.

**Deployment constraints.**

1. The Roles mastercopy keeps its own storage from slot 0. Deploying it behind a Safe proxy overwrites the proxy's implementation pointer with the avatar address and bricks the instance. It **must** be deployed through the Zodiac `ModuleProxyFactory`, which produces EIP-1167 minimal proxies that hold the implementation in bytecode.
2. The deployed mastercopy predates the current upstream source. Its initialiser is `setUp(bytes)` taking `abi.encode(owner, avatar, target)`, not the three-argument form. Audits and deployment tooling must pin the deployed bytecode, not repository HEAD.
3. `owner`, `avatar`, and `target` are all set to the Asset Safe.
4. The Asset Safe is set up with no fallback handler. Without one, it refuses ERC-721 and ERC-1155 safe transfers and cannot sign a message by EIP-1271. A protocol that needs either comes back to EM (OD-17).

#### Part 2: Roles and authority **[Implemented]**

Four principals. Role keys are `bytes32`; the encoding must match the tooling that applies the policy and is a deployment-time check.

| Role | Holder | May do | May not do |
| --- | --- | --- | --- |
| DAO | Aragon Agent, reached by vote through Dual Governance | Everything: owns the Safe, may replace the whole policy, may add or remove role members | — |
| `operator` | Operator Safe, the TMC signers, screened | Open, adjust, and close positions in approved protocols within budgets; approve approved spenders, each approval spending its spender's budget key or staying below a fixed ceiling (OD-08); stake ETH, and request and claim Lido withdrawals pinned to the Asset Safe; convert DAI to USDS and back through Sky's converter, pinned to the Asset Safe | Transfer any asset out; borrow; create debt; administer the modifier or the Safe; change its own permissions |
| `emergency` | Emergency Safe, two of seven, same signers as the operator. **Safety modifier** | Set approvals to zero; exit positions to the Safe; unwrap wstETH and WETH, stake ETH and redeem sUSDS so that recovery can sell them; swap to stablecoins through the recovery-family instances; transfer recovered assets to the Agent only; revoke the operator's targets and functions, which is how every removal happens | Add any permission; enter any protocol except by staking ETH; borrow; redeem the first-loss Earn shares (OD-28); change the recovery destination; disable the module |
| `technical` | Emergency Brakes multisig, three of five. **Safety modifier** | Disable the **operator** modifier, with the module argument pinned to it, for a defect in the permission layer or for a cap breach that gets worse (OD-29) | Anything else. It cannot touch assets or permissions, and it cannot disable the safety modifier |
| `governance` | EVMScriptExecutor, driven by Easy Track | Write operator permissions from a fixed template, for a target named in a motion; set operator budgets within ceilings | Submit a condition tree; grant or remove any role; touch the emergency role; target a modifier or the Safe; grant delegatecall |

The emergency role's ability to revoke the operator works because the Safe owns the modifier: a call through the emergency role executes as the Safe, which the modifier accepts as its owner.

**Two classes of risk, and who answers each.**

*Financial risk* is the common case: a depeg, a dependency failure, a curator acting against the vault's interest, a position that must be unwound now. These need someone who watches the portfolio daily, understands the positions, and can act in minutes. That is the treasury committee, and the emergency role is a low-quorum subset of exactly those people. Its powers match the job: revoke, exit, swap to stablecoins, return to the Agent.

*Technical risk* is rarer and different in kind: a defect in the permission layer itself, or a report arriving through the bug-bounty programme. Two mechanisms cover it. The global Easy Track pause, held by the Emergency Brakes multisig, stops any pending governance change from enacting. Module disabling, held by the technical role, switches the operator modifier off. The safety modifier keeps working, so recovery survives.

Both technical remedies are therefore held by the same technical committee. It already holds the global Easy Track pause, it already contains engineering members, and technical risk already reaches it through the engineering organisation's existing channels including the bug-bounty programme. No new committee is created; an existing one receives one additional, single-function role.

This separation matters because the two remedies answer different failures. Pausing Easy Track stops a pending governance change from enacting. It does not stop an operator transaction and it does not stop a defect in the permission layer from being exercised. Only module disabling does that. Putting both in the hands of the people who recognise a technical defect removes the paging dependency that would otherwise sit on the critical path.

**Composition note.** The emergency role is deliberately drawn from the same people as the operator, at a lower quorum. This buys response time and removes the coordination cost of a separate body. It also means the two roles do not fail independently: a compromise of two operator signers is a compromise of the emergency role, and the guarantee that the operator cannot veto an emergency action now rests on role scoping alone rather than on separation of persons. The Easy Track pause role stays with the Emergency Brakes multisig, which is a different body, so freezing queued motions during an incident requires paging them. **The fast exit is therefore not independent of the committee** (OD-30). No body outside the committee can return assets within six hours: the Emergency Brakes multisig can only stop the operator, and the path that is independent of the committee is a DAO vote, which carries the Dual Governance delay.

#### Part 3: Permission encoding **[Implemented]**

Permissions are condition trees stored per `(roleKey, target, selector)`. Enum values below are from the deployed mastercopy and are normative for tooling.

`ParameterType`: `None=0`, `Static=1`, `Dynamic=2`, `Tuple=3`, `Array=4`, `Calldata=5`, `AbiEncoded=6`.

`Operator`: `Pass=0`, `And=1`, `Or=2`, `Nor=3`, `Matches=5`, `ArraySome=6`, `ArrayEvery=7`, `ArraySubset=8`, `EqualToAvatar=15`, `EqualTo=16`, `GreaterThan=17`, `LessThan=18`, `Bitmask=21`, `Custom=22`, `WithinAllowance=28`, `EtherWithinAllowance=29`, `CallWithinAllowance=30`.

Rules that constrain how policy must be written:

- **A write replaces a slot.** A second `scopeFunction` on the same role, target, and selector discards the previous tree. Policy must therefore be emitted as complete trees, and any tooling that appends permissions per-token must merge them before writing.
- **`Matches` requires exactly as many children as the call has parameters** at the level being matched. Trailing parameters that need no constraint take `Pass`.
- **Alternative calldata shapes use `Or` at the root** over full `Matches` branches. This is how per-spender budgets are expressed on `approve`: one branch per spender, each with its own `EqualTo` on the spender and its own `WithinAllowance` on the amount, or a `LessThan` ceiling for a spender with no key. Budget keys are independent across branches.
- **A budget key counts token units**, so a key shared across assets of different decimals is a defect. Each decimal class needs its own key.
- **Array elements are constrained with `ArrayEvery`** over a single child condition.
- **`Custom=22` invokes an external adapter by `staticcall`.** The adapter address is the leading 20 bytes of the 32-byte comparison value; 12 bytes of caller-defined data follow. Because it is a static call the adapter can read state but cannot write, cannot maintain a ledger, and cannot consume an allowance. No adapter is used in this proposal.

#### Part 4: Governance — the new contracts **[Implemented in part]**

The **only** new contracts are Easy Track EVM script factories. Each is small, holds no assets, and carries no authority of its own: it builds a script, and the modifier decides whether the resulting call is permitted.

##### 4.1 `RoleToggleEVMScriptFactory` **[Retired, OD-09]**

The kit built and tested a factory that switched the operator's membership of role keys that the DAO had scoped. EM retired it on 2026-10-05, and the kit no longer contains it. The design uses no DAO-scoped role keys: every operator permission lives under the `operator` key, which the emergency role's revoke reaches. The governance role holds no `assignRoles` permission.

Every remaining factory emits the production script format, `[specId(4)][to(20)][calldataLength(uint32)][calldata]`, where the length covers the selector and the arguments. This matches `EVMScriptCreator` in the Easy Track source. A 32-byte length field is **not** the production format and must be rejected.

##### 4.2 Defence in depth in the modifier **[Implemented]**

The governance role is separately constrained so that a factory bug cannot widen anything.

- Every administrative selector granted to the governance role pins the role key to `operator` by `EqualTo`, and refuses the modifier and the Safe as the administered target using `Nor(EqualTo(roles), EqualTo(safe))`.
- `setAllowance` takes only an operator budget key, and a period of at least 30 days (OD-08).
- `allowFunction` and `scopeFunction` take only the execution options None or Send. A motion cannot grant delegatecall (OD-36).
- `assignRoles` and `setDefaultRole` are **not** granted (OD-09). Membership changes are a DAO vote.

The target refusal is necessary because pinning the role key alone is insufficient: without it, a motion could grant the operator a permission whose target is the modifier, and the operator would then reach owner-only administration through the avatar.

##### 4.3 Template factories for onboarding **[Specified]**

Not yet built. These let Easy Track onboard a protocol or asset without a DAO vote and without submitting a condition tree. Each factory owns one template. Motion call data carries only typed parameters; the factory constructs the tree.

The catalogue below is the set that EM accepted on 2026-09-22 [s1]. EM dropped its two removal templates on 2026-10-05 (OD-09).

| Factory | Motion parameters | Emits |
| --- | --- | --- |
| `AddWrapFactory` | wrapper, underlying | `wrap` and `unwrap`, or `deposit` and `withdraw` on WETH; the output returns to the avatar |
| `AddERC4626VaultFactory` | vault, asset, budget key | the asset's `approve` to the vault, spending the budget key; `deposit` with receiver `EqualToAvatar`; `redeem` and `withdraw` with receiver and owner `EqualToAvatar` |
| `AddQueueVaultFactory` | vault, asset, budget key | the asset's `approve` to the queue, spending the budget key; the asynchronous deposit request with any owner pinned to the avatar; the redeem request, cancel and claim with receiver and owner pinned to the avatar |
| `AddSpenderApprovalFactory` | token, spender, budget key | a branch of the token's `approve` scope with that spender pinned and the amount spending the budget key; zero spends nothing |
| `AddSwapInstanceFactory` | swap instance | `transfer` scoped with the recipient pinned to that instance, for the rebalancing family only |
| `AddMorphoBlueMarketFactory` | market parameters, budget key | the loan token's `approve` to Morpho Blue, spending the budget key; `supply` with `onBehalf` pinned to the avatar; `withdraw` with `onBehalf` and `receiver` pinned to the avatar. **Ships at launch even though no market address exists yet.** Acceptance requires end-to-end tests against the deployed Morpho Blue contract on a fork, so the template is proven before the market it will be pointed at exists |

A lending-pool template for markets such as Aave is not in the catalogue, because third-party lending markets are outside the launch scope.

The trusted caller on every factory is the **operator multisig**, matching the pattern already used by the treasury swap factories. Every factory hard-codes the role key to `operator` and refuses the modifier and the Safe as a target.

**Disclosure required with an onboarding motion.** A forum post published before the motion, covering the target, the template applied, the initial budget, and the diligence performed; monitoring and alerting configured for the new target before enactment; and the incident runbook updated. The stop mechanisms are the objection threshold and, failing that, the global Easy Track pause held by the Emergency Brakes multisig.

**Removals do not use Easy Track (OD-09, decided).** Easy Track gives every motion the global window, and that window can never be below 48 hours. EM decided on 2026-10-05 that every removal is the emergency Safe's immediate revoke, `revokeTarget` or `revokeFunction` pinned to the `operator` key, posted on the forum afterwards. A removal only narrows, so a window would protect nothing. Easy Track only expands.

Invariants an audit must confirm for each template: no receiver, owner, or beneficiary field is ever left open; every value-moving amount is either budgeted or capped; no template can emit an administrative selector; and the emitted script parses under the production script format.

Residual risk to state in the mandate: a motion can point the operator at a contract nobody has audited. The template bounds *how* the vault interacts with it — receivers pinned, amounts budgeted — so the loss ceiling is the attached budget, not the balance. The controls are the objection window, the diligence published with the motion, and monitoring. This is what optimistic governance means here, and it should be said plainly rather than implied.

##### 4.4 `BudgetEVMScriptFactory` **[Specified]**

Not yet built. Adjusts an operator budget. The modifier constrains `setAllowance` natively. The kit's policy already has the key list and the period floor. The per-key ceilings wait for the attested figures; a kit test shows the shape [s4].

- the allowance key must be one of the operator's budget keys, by `Or` of `EqualTo`;
- `balance`, `maxRefill`, and `refill` are each bounded by `LessThan` the ceiling of their key, in one branch per key;
- `period` is bounded below by `GreaterThan` 30 days minus one second, so the shortest period is 30 days (OD-08). This prevents a motion from turning a monthly budget into a per-second one.

#### Part 5: Funding **[Specified]**

Funding reuses production machinery. No new contract class beyond a factory.

The Easy Track script executor already holds `CREATE_PAYMENTS_ROLE` on the Finance application with 22 Aragon ACL parameters attached. Those parameters form a conditional chain binding argument 0 (token) and argument 2 (amount). Argument 1 is the **receiver and is not constrained at the ACL layer**; recipient control lives one layer above, in the registry and factory.

Per-payment ceilings recorded in the ACL parameter tree, re-read at block 26092572 [s3] and unchanged at block 26125804 [s7]. The enabling vote adds USDS with a ceiling of 2,000,000 per payment (OD-11, OD-24):

| Token | Ceiling per payment |
| --- | --- |
| stETH | 1,000 |
| ETH | 1,000 |
| DAI | 2,000,000 |
| USDC | 2,000,000 |
| USDT | 2,000,000 |
| sUSDS | 2,000,000 |
| USDS | 2,000,000, once the enabling vote adds it |
| LDO | 5,000,000 |

Many allowed-recipient setups already run on mainnet, each combining an `AllowedRecipientsRegistry` with period limits, optionally an `AllowedTokensRegistry`, add and remove factories, and a `TopUpAllowedRecipients` factory. Twelve top-up registries are live, and the committee's existing Safe is the trusted caller of two of them [s7].

**Setup, decided by EM on 2026-10-02 (OD-06):** two dedicated registries, one for stablecoins and one for stETH. The Asset Safe is the only recipient of each, and the Easy Track executor cannot add recipients. Each registry has a period of one calendar month and a limit of one TM Floor Value per period. Two `TopUpAllowedRecipients` factories, the stablecoin one with the shared stablecoin token list, to which the vote adds USDS (OD-11), take the operator Safe as trusted caller and are registered by DAO vote [s7]. Section 5.2 gives the reasons and the gaps.

##### 5.1 Scaling the existing caps to the mandate size **[Investigated]**

Findings, first read at block 26017715 and re-read at block 26092572 [s3].

- **The ACL ceilings are per call, not per motion or per period.** Each `newImmediatePayment` is authorised separately. A single motion whose script contains several payment calls is therefore bounded by the number of calls, not by the ceiling.
- **The Finance application adds no second cap.** Token budgets are disabled: `getBudget` returns amount 0 with the budgeted flag false for USDC, DAI, and stETH. The 30-day period exists but binds nothing.
- **The grant is shared.** The parametrized `CREATE_PAYMENTS_ROLE` is held by the single Easy Track script executor, which every Lido top-up factory routes through. Raising a ceiling raises it for every allowed-recipient setup at once.
- **The permission manager is Aragon Voting** at `0x2e59A20f205bB85a89C53f1936454680651E618e`, so any parameter change is an Aragon vote, and the whole 22-entry parameter array is rewritten as one unit.

**Decision: add USDS to the shared parameters (OD-11).** EM decided on 2026-10-05 that a DAO vote rewrites the array to add USDS, and that the stablecoin registry uses the shared token list with USDS added. Seed and top up through several payments inside one motion, and let the real ceiling be the period limits on the two dedicated registries (section 5.2). The number of payments follows from the limits and the ceilings, and an attested computation must produce it. The rewrite is DAO-wide: every setup that shares the token list can then pay USDS too, and the vote must say so.

Two consequences to accept. A per-payment ceiling is not a per-motion ceiling, so the registry period limit is the backstop that matters, and section 5.2 sizes it. And **funding in sUSDS goes beyond the mandate's funding rule**, which names stETH and the top-four stablecoins: the mandate text must add it, and an sUSDS top-up counts at once against its yield-bearing cap. The funding assets are USDC, USDT, DAI, USDS, sUSDS and stETH. ETH is not one: the Agent holds less than 8 ETH (OD-11) [s7].

##### 5.2 Period and limit **[Decided, OD-06]**

The mandate puts seeding and top-ups on Easy Track, and it makes the objection the control of a top-up. The registry is the backstop.

**The legacy Earn shares (OD-21).** The DAO's first-loss shares in EarnETH and EarnUSD, approved by Snapshot in March 2026, sit in a Growth Committee Safe [s10]. After the enabling vote, the Growth Committee transfers them to the Asset Safe, and the seed is one floor less their value. This proposal takes over the first-loss terms of that allocation: a burn is a DAO vote, and neither the operator nor the emergency role redeems the first-loss shares. In an emergency they go to the Agent (OD-28). That rule is written, not enforced, because the shares are the same token as any Earn shares the vault buys. Monitoring alerts when the vault's Earn balance falls below the first-loss amount. A Twyne position counts against the seed only when its holder and form are shown.

- **Period: one calendar month.** The mandate's top-up follows each month-end snapshot, so each month's top-up has its own limit. No live Lido registry uses one month; they use three, six or twelve [s7].
- **Limit: one TM Floor Value per registry per month.** Stablecoins count at par. The stETH limit is the floor at the Coingecko price pinned when the enabling vote is prepared, set by attested computation. Either asset can carry a full refill, as the mandate allows for the seed and for the runway protection's stETH top-up.
- **Why two registries.** A registry counts token units after scaling decimals, so 1 stETH counts as 1 USDC. One limit cannot hold both assets to a dollar figure [s7].
- **Gap 1: more than one floor a month.** Without an objection, the operator Safe can pull one floor per registry each month. Around a month boundary, one registry can pay two full limits within about 72 hours, because a motion that can only be enacted in the next period is checked against that period's full limit [s7]. The mandate's limit on the vault's size is therefore a procedure, not code.
- **Gap 2: the stETH limit is fixed in tokens.** The mandate values stETH at the Coingecko price at each motion. After an ETH fall, a refill in stETH alone reaches less than the floor in one month; the rest follows the next month or in stablecoins. After an ETH rise, the stETH limit is worth more than a floor. The DAO re-pins the limit by vote when needed.
- **Compensating controls.** The operator Safe creates every top-up motion, so each one passes the screening guard and the 72-hour objection window. Monitoring flags a top-up motion outside days 1 to 10 of a month, apart from the seed; a month's top-ups above the shortfall posted on the forum; and any top-up motion after an objected one. The screening policy carries a dollar rule per motion, if the vendor supports it (OD-07).
- **What the registry cannot enforce.** The mandate's rule that, after an objection, a further pull needs a Snapshot vote. A DAO vote can set the limit to zero.
- **Not chosen.** A three-month period; a stETH limit at a stress price; one floor split between the registries; and one registry with one dollar limit, through a token registry that counts stETH at a DAO-pinned rate, which needs a new contract. That registry could not use a live rate: Easy Track rebuilds the script at enactment and checks its hash, so a rate that moves during the objection window blocks the motion [s7].

#### Part 6: Emergency response **[Implemented]**

All permissions in this part are written into the **safety modifier**. Its holders never pass through the screening guard.

The emergency role holds, and nothing else:

- `approve(spender, 0)` on each token that the operator can approve, spender drawn from the operator's spenders;
- exits: savings-vault redeem and withdraw with receiver and owner pinned to the avatar; asynchronous vault cancel, claim, and redeem, but never a redemption of the first-loss Earn shares, which go to the Agent instead (OD-28, a written rule); the claim of a finalized Lido withdrawal, which pays the Safe;
- conversions before a recovery: `unwrap` on wstETH and on WETH, and `submit` on stETH with the referral pinned to zero (OD-20);
- `transfer(to, amount)` with `to` pinned by `EqualTo` to the Agent literal, on every asset and receipt token the Safe can hold;
- `revokeTarget(operator, …)` and `revokeFunction(operator, …)` on the modifier, role key pinned to the operator;
- `transfer(to, amount)` with `to` pinned by `EqualTo` to an approved recovery-family swap instance (see 6.1). This one is specified, not built: the instances do not exist yet.
Module disabling is **not** in this role. It belongs to the technical role; see 6.2.

Separately and already deployed: the Emergency Brakes multisig holds the pause role on Easy Track and does not hold unpause. Pausing Easy Track during an incident freezes every queued motion, and only the DAO can resume. This is the durable answer to a queued expansion re-enabling something the emergency role just revoked, and it must be a step in the incident runbook.

##### 6.1 Swapping — the default engine for both roles **[Specified]**

Neither role receives a direct exchange permission. Every swap, routine or emergency, goes through the DAO's treasury swap contracts.

The path is two steps and only the first needs a permission:

1. The role calls `transfer` on the asset, with the recipient pinned by `EqualTo` to an approved swap instance.
2. The instance's manager calls `placeOrder`. The operator Safe manages the rebalancing instances and the emergency Safe the recovery instances (OD-05). The order's minimum output is the oracle quote less the instance's margin; the manager can raise it, never lower it. Its settlement receiver is fixed in the instance.

**The receiver is what separates the two roles.** It is an immutable set at deployment, so the destination of proceeds is structural rather than chosen per order. Two families of instances are deployed:

| Family | Used by | `RECEIVER` | Effect |
| --- | --- | --- | --- |
| Rebalancing | `operator` | Asset Safe | Proceeds return to the vault, so the operator can trade but cannot move value out |
| Recovery | `emergency` | Aragon Agent | Proceeds go to the DAO treasury, matching the mandate's fixed recovery destination |

The operator therefore cannot route proceeds anywhere but the vault, and the emergency role cannot route them anywhere but the Agent, without either constraint being expressed as a condition.

Properties confirmed on the deployed instances: `RECEIVER()` is a per-instance immutable and the two live instances differ, one settling to the Agent and one to another contract; `estimateTradeOutput` returns a live oracle quote; `ORDER_DURATION_IN_SECONDS`, `MARGIN_IN_BASIS_POINTS` and `PRICE_TOLERANCE_IN_BASIS_POINTS` are per-instance immutables, currently 1800, 110 and 550 on the live instances; and `recoverERC20`, `recoverEther` and `recoverERC721` exist, so assets are not stranded when an order does not fill. Only an instance's admin or manager can place an order or recover tokens, and recovered tokens always go to the instance's fixed recovery address. Every instance from the standard factory has Aragon Voting as admin and the Aragon Agent as recovery address. The Stonks 2.0 instances also fix a maximum improvement and allow partial fills.

What this removes from the design: the operator needs no order pre-signing permission, and no role needs a standing approval to an exchange relayer. The unbounded-approval exposure and the opaque-order problem both disappear for swapping.

What it costs, and what must be planned:

- **An instance is one `(tokenFrom, tokenTo, receiver)` triple, fixed at deployment.** Every instance in this system is deployed fresh from the existing factory. None of the nine existing treasury instances is reused: they are the earlier revision with the receiver hardcoded, and their manager is the operator committee.

##### 6.1.1 Instance matrix **[Open — topology]**

Sellable assets are stETH, LDO and the four dollar stablecoins: the tokens that the Stonks price router can price (OD-20). wstETH is unwrapped and sUSDS redeemed before a sale. WETH is unwrapped and the ETH staked to stETH through Lido's `submit`; WETH is bought back by unstaking stETH through Lido's withdrawal queue. The savings and queue vault positions are redeemed through their own contracts, not swapped, so they need no instance.

| Family | Receiver | Scope decided so far |
| --- | --- | --- |
| Recovery | Aragon Agent | Any sellable asset into a dollar stablecoin, **including stablecoin to stablecoin** |
| Rebalancing | Asset Safe | Among stETH, wstETH, USDC, USDT, USDS and LDO |

The topology is the remaining decision, and it changes the deployment surface by roughly a factor of three.

- **Full mesh.** Recovery covers stETH and LDO into four stablecoins, plus each stablecoin into the other three: 20 instances. Rebalancing covers every ordered pair of stETH, LDO, USDC, USDT and USDS, because wstETH is a wrap rather than a swap: 20 instances. About 40 in total.
- **Hub.** One canonical stablecoin is the hub. Recovery sells everything into it, and a small number of stablecoin pairs cover the rest. Rebalancing routes through the hub in both directions. Roughly 17 in total.

**Decision: hub, with a second recovery destination.** USDC is the hub. Rebalancing routes through it, so every rebalancing pair is one hop and the rare non-hub route costs two. Recovery sells every asset directly into the hub, so nothing needs two hops under stress.

Recovery additionally carries USDT as a **second destination** for stETH, LDO and the stablecoins that carry USDC risk: USDC itself, USDS and DAI (OD-26). A single hub has one failure mode that matters here: if the asset being fled is the hub itself, recovery into it is exactly wrong, and a hub depeg would strand the recovery path. USDS and DAI share the risk, because Sky's peg stability module holds USDC, and DAI lost its peg together with USDC in March 2023. The second destination removes that dependency.

That gives ten recovery instances and eight rebalancing instances, eighteen in total, against about forty for a full mesh. A rebalancing pair can be added later by motion where a route proves costly in practice; a recovery pair needs a DAO vote, because the safety policy pins it. Each instance is an address the transfer permission must pin, so an unused instance still costs deployment, configuration and monitoring surface.

Each instance's address is pinned in the transfer permission of the token it sells, so the set is fixed at policy-application time and grows only by a policy change.
- **Swaps are not instant.** Orders run for a bounded duration with an oracle-derived floor, so a rebalance is a queued action, not an immediate one. The emergency service level remains time-to-initiate.
- **Assets sit in the instance between transfer and settlement.** This is a short custody excursion out of the Asset Safe and should be stated plainly rather than glossed.
- **The committee Safes are the managers** (OD-05). The operator Safe manages the rebalancing instances, and its orders pass the screening guard. The emergency Safe manages the recovery instances. A manager cannot take tokens: recovery always pays the Aragon Agent. Tokens recovered from a rebalancing instance therefore leave the vault for the treasury, and a top-up motion brings them back if the mandate allows it.
- **Pricing.** Every instance prices through a converter and the Stonks price router that the NEST buyback shares. The router takes its feeds from Chainlink's Feed Registry, which has USD feeds for USDC, USDT, DAI and USDS and no entry for wstETH, WETH or sUSDS [s9]. The TMC multisig, the router's manager since vote 204, adds the four feeds before the enabling vote, and Lido deploys one USD-anchored converter for the vault through the existing converter factory. The vote starts only if every vault token is configured and in sync. When Chainlink replaces a feed, as it did for USDC and USDT twice in September 2026, the router refuses that token until the TMC multisig re-syncs it; during an emergency, recovery can send assets to the Agent instead (OD-20).
- **No existing instance is reused.** The deployed treasury instances are the earlier revision with the receiver hardcoded, and their manager is the operator committee. Both properties are wrong for this system, and sharing an instance would mix vault flows with ordinary DAO swaps in one balance.

##### 6.2 Module disabling — the technical role **[Implemented]**

One role, one function, held by the technical committee.

```
scopeTarget(technical, assetSafe)
scopeFunction(technical, assetSafe, disableModule(address,address), [
    root:        Calldata  Matches
    prevModule:  Static    Pass        // linked-list pointer, varies with the module set
    module:      Static    EqualTo(rolesModifier)
])
```

The module argument is pinned, so the power cannot be turned on a future second module. The predecessor pointer must stay open because its value depends on the Safe's module list at call time. This closes the long-standing objection to an unpinned disabling scope: the original proposal left both arguments open because its tooling could not place a not-yet-deployed address into a condition, and applying the policy after deployment removes that constraint.

Disabling switches off the operator and governance roles at once. The safety modifier stays enabled, so the emergency role can still revoke, exit and return assets. The owner path restores service by re-enabling the module. Because recovery survives the switch, the technical committee does not need to wait for the financial committee to finish, and no cross-committee sequencing rule is needed.

If the defect is in the safety modifier itself, the technical role cannot help: its pin is exact. Recovery then runs through a DAO vote acting as the Safe's owner, which carries the Dual Governance delay.

Tested: the emergency role and the operator are both refused; the technical role cannot point the call at another module address; it can disable the operator modifier; the operator then stops working while the safety modifier stays enabled and the emergency role still moves assets to the Agent; the technical role cannot disable the safety modifier; and the owner path restores the operator modifier [s4].

**Recovery semantics to state honestly.** Exiting a position and receiving the assets are different events. Where a protocol has no liquidity, the emergency role transfers the receipt token to the Agent, which moves custody without completing the exit. Where a vault settles asynchronously, the role can start the exit and claim later. The target is time-to-initiate, not time-to-receive.

#### Part 7: Budgets **[Implemented]**

Budgets are consumable allowances keyed by `bytes32`, drawn by `WithinAllowance` nodes in the operator's permissions. They are drawn at the approval, not at the deposit (OD-08), and the kit draws them that way. Semantics verified against the deployed mastercopy: consumption happens only on success, a reverted call consumes nothing, a key shared across branches draws across them, and refills accrue by elapsed periods capped at the maximum.

The `Allowance` struct field order in the deployed mastercopy is `refill, maxRefill, period, balance, timestamp`. Tooling that reads the getter must use this order; transposing balance and timestamp yields a Unix timestamp where a balance is expected.

#### Part 8: Launch asset and action matrix **[Open in part]**

| Asset | Role in the system | Notes |
| --- | --- | --- |
| ETH | Held | Not a funding asset (OD-11). Still in the payment chain for other setups, ceiling 1,000 per payment |
| WETH | Held, wrap and unwrap | No price feed: staked to stETH before a sale, and bought back through Lido's withdrawal queue (OD-20) |
| stETH | Held, funding inbound | In the payment chain, ceiling 1,000 per payment |
| wstETH | Held, wrap and unwrap | No price feed: unwrapped to stETH before a sale (OD-20) |
| USDC | Held, funding inbound | In the payment chain, ceiling 2,000,000 per payment |
| USDT | Held, funding inbound | In the payment chain, ceiling 2,000,000 per payment |
| DAI | Held, funding inbound | In the payment chain, ceiling 2,000,000 per payment. Added so the mandate's definition of the top four stablecoins matches the launch set. The operator converts it to USDS and back through Sky's converter, one to one; recovery sells it into USDC (OD-22) |
| USDS | Held, funding inbound | **Added to the payment chain by the enabling vote (OD-11)**; ceiling 2,000,000 per payment (OD-24). Receives converted DAI (OD-22) |
| sUSDS | Held, savings position, funding inbound | Template: tokenized vault. In the payment chain, ceiling 2,000,000 per payment (OD-11) |
| earnETH | Held, vault position | Asynchronous deposit and redeem queues |
| earnUSD | Held, vault position | Asynchronous deposit and redeem queues |
| LDO | Held, in the rebalancing set | |
| Swap instances | Rebalancing and recovery venue | Both roles, through the treasury swap contracts. Price is oracle-bounded and the destination is fixed per instance; no direct exchange permission and no standing relayer approval exists |
| Lido Lend | Lending venue | Expected October 2026, Morpho-Blue-compatible. **Zero-day ready by design:** the Morpho-Blue template ships at launch with end-to-end tests against the live Morpho Blue deployment, so onboarding is one Easy Track motion carrying the market address once it exists. No vote, no new contract, no policy migration. The protocol cap applies for its first three months, then none as a Lido own product (OD-04) |

Assets explicitly **not** in the launch set: sDAI and third-party lending markets other than Lido Lend.

After OD-11, **seeding and top-ups use USDC, USDT, DAI, USDS, sUSDS or stETH**. USDS needs the enabling vote to add it to the payment chain. ETH is not a funding asset.

#### Part 9: Reporting and detective controls **[Specified]**

Exposure ratios are **detective** controls. The permission layer cannot see valuation, so the caps in the mandate are enforced by measurement, publication and remediation, not by reverting a transaction. This must be stated in the mandate in exactly those words.

Reporting is published so that a third party can check it later without trusting the publisher's own website.

- **Payload on IPFS.** The full report — balances, positions, per-asset and per-protocol exposure, the ratios with their numerator and denominator, the price source and its timestamp — is a document addressed by content hash.
- **Anchor on chain.** The content identifier is published so the report cannot be silently replaced.

On the anchor, one finding matters. The DAO's DataBus contract is **not deployed on Ethereum mainnet**. It exists at the same address on Gnosis Chain, Base, Optimism and Polygon PoS. Using it means the anchor lives on a sidechain with that chain's security assumptions, while the assets live on Ethereum. Its `sendMessage` is permissionless, so any consumer must filter by the indexed sender, and the event is anonymous, so an indexer must be configured for it deliberately.

**Decision: IPFS, and no sidechain.** The payload is content-addressed on IPFS. An earlier draft put a funding motion's report identifier in the Aragon payment's `reference` field. That does not work: the standard top-up factory writes a fixed reference, "Easy Track: top up recipient" [s7]. The identifier goes in the report's forum post. There is no on-chain anchor (OD-14).

DataBus is **not adopted**, at least for now. It is not deployed on Ethereum, so it would put the anchor on a sidechain while the assets sit on Ethereum, and that is a trust step this proposal does not need to take.

The honest consequence, which must be stated rather than glossed: no report has an **on-chain anchor**, a funding motion's report included (OD-14). Its immutability rests on content addressing plus the forum post that cites the identifier. That is adequate for an informational control and it is not an Ethereum guarantee. If that is later judged insufficient, an anchor can be added without changing anything else in the design.

Report operations, decided by EM on 2026-10-05 (OD-14): the committee publishes on the mandate's schedule, from a report generator in this repository that anyone can re-run. Prices come from Coingecko's close at the Snapshot Date; a missing or stale price falls back to the asset's on-chain rate, and an asset with neither is shown as unpriced and left out of the ratios. No top-up rests on a snapshot with an unpriced asset, and none starts while the monthly report is late.

##### 9.1 Detection, response, and the limits of blocking **[Open]**

**Detection** runs in two estates in parallel. The Lido on-chain monitoring suite carries the rules that are cheap to express over block data: policy drift against the intended permission set, approval inventory, budget burn rate, repeated budget motions on one key, module, owner and singleton changes on the three new Safes, and motion lifecycle events. A commercial monitoring service carries the rules that need market and threat context: depegs, protocol compromise signals, and counterparty anomalies. Findings from both route into the existing notification and incident channels. The defi-tech team specifies the on-chain rules and makes the important updates; the team that owns the Lido monitoring bots reviews them and maintains the engine and the bots. The committee configures the vault's rules in the commercial service (OD-13).

**Response to a ratio breach** is a financial judgement and belongs to the operator committee, working to the mandate's remediation window after the fortnightly review. If a breach worsens rather than resolves, the escalation is the technical role disabling the operator modifier, which stops all operator activity while recovery stays available. The trigger is fixed (OD-29): a published cap breach that is still there after the committee's rebalancing window of two working days, and that is larger at the next fortnightly snapshot. A DAO vote can also disable the modifier. Monitoring publishes the cap reading of each fortnightly snapshot to IPFS, from the report generator at the snapshot's pinned block, so the trigger does not depend on the committee in breach (OD-32). Its alert pages the Emergency Brakes multisig when the trigger is met.

**Blocking a transaction before it executes** is a hard requirement. EM chose the route on 2026-10-02 [s1]: a dedicated operator Safe with its own screening guard, which is also the trusted caller of every factory (ADR 010) [s2].

##### 9.1.1 The screening guard **[Decided — transaction guard on the Operator Safe]**

- The operator role is held by the Operator Safe, a new Safe with the TMC signers. It holds no assets and has no modules.
- The screening vendor's existing transaction guard is set on the Operator Safe with `setGuard`. It is the vendor's code, already deployed for other Lido multisigs and audited by an external firm. Lido writes nothing here [s6]. The vault uses the same build as those multisigs. That build adds one change after the audit, both timelocks raised from 1 day to 10 days, which Lido reviews (OD-07).
- The guard checks every transaction that the Operator Safe executes. The vendor's key must approve the exact transaction, once, before it executes. A transaction without an approval reverts, so the guard fails closed [s6].
- The Operator Safe is the trusted caller of every factory, so every motion is created through the guard. Motion enactment is not screened, but the hash check fixes a motion's content at creation.
- Recovery and the technical role never touch vendor code. The emergency Safe and the Emergency Brakes multisig act through the safety modifier, and no guard is set on the Asset Safe.
- The Operator Safe's owners can remove the guard only through a fixed 10-day timelock that the vendor cannot block. A vendor outage therefore stops operator activity for at most ten days, and a hostile removal stays visible for ten days [s6].
- The enabling vote grants the operator role only after the guard is set and its bypass mode is off. The owners cannot turn the bypass on again without the vendor's approval and a 10-day timelock (OD-07).
- The vendor agreement forbids standing approvals on this guard: approvals of one call at any nonce, or of one function with any arguments. Only the guard's two built-in timelock approvals stay (OD-07).
- The vendor has confirmed that its approval service supports Safe v1.5.0, as EM reported on 2026-10-05, so the Operator Safe runs v1.5.0 (OD-07, OD-17).
- The vendor is asked to refuse every delegatecall from the Operator Safe except to Safe's MultiSendCallOnly v1.5.0, `0xA83c336B20401Af773B6219BA5027174338D1836`. At Bybit in 2025, one signed delegatecall replaced a Safe's implementation [s8]. On the Operator Safe, such a call could also remove the guard. This is a request, not a gate (OD-17).

Lido's on-chain monitoring already has a detector for this guard. It alerts on the start of the removal or bypass timelock, the bypass mode turning on, any approval that is not bound to one transaction, any keeper change, any added policy contract, and any module, guard or owner change on the guarded Safe. It must add Safe v1.5.0 and the Operator Safe's instance. Every operator transaction calls the same modifier function, so one standing approval of that function would approve all vault activity. Lido's monitoring also alerts, as critical, on any change of the singleton of the three new Safes, because a delegatecall can replace a Safe's implementation without any Safe event (OD-17).

##### 9.1.2 Why not a module guard on the Asset Safe **[Rejected]**

Safe v1.5.0 calls a module guard for every enabled module, the safety modifier included [s5]. Recovery would then pass only because the vendor's code let the safety modifier through, and only a DAO vote, with the Dual Governance delay, could remove a failed guard. A module guard also receives no signatures, so a per-transaction approval needs a separate step on chain. The screening vendor's existing guard is a transaction guard and cannot be set as a module guard [s6].

##### 9.1.3 Failure behaviour, authority and costs **[Decided]**

**Failure behaviour: fail closed.** A guard that cannot reach a verdict refuses the operator transaction. Recovery is unscreened by construction, so a stuck guard stops new risk being taken while still allowing exit. The trade is a frozen operator during a vendor outage, which is accepted.

**Flagging authority: the vendor, unilaterally.** No Lido co-signature is required to block, because adding one would trade away the response time the control exists to buy. The counterweights are that the Operator Safe's owners can remove the guard after its 10-day timelock, the DAO can give the operator role to another Safe, and the technical role can disable the operator modifier outright.

**The guard is vendor-supplied.** It is the one component in this design that can stop operator activity and motion creation, and Lido does not write it. That makes it a dependency with its own audit and its own liveness risk. Three mitigations are structural rather than contractual: recovery never passes through it, the owners can remove it after ten days, and the technical role can disable the operator modifier outright. This is a deliberate narrowing of the provider-independence property, and it should be stated in those terms rather than presented as cost-free.

**The split also removes a sequencing hazard that existed independently.** Previously, disabling the module removed every role at once, so the emergency role had to finish exiting before the technical role acted, and that ordering crossed committee boundaries with nothing enforcing it. Now the technical role disables the operator modifier while the safety modifier keeps working, so recovery survives the kill switch and the ordering constraint disappears.

**Governance is screened at creation.** The governance role sits on the operator modifier and is held by the Easy Track executor, which no guard covers. Because the Operator Safe is the trusted caller, every motion is created through the guard, so a hostile onboarding motion meets the screening at creation. A screening outage therefore delays new motions as well as operator activity. This is acceptable because motions already carry a three-day window.

**Modifier replacement is a documented procedure, not an automatic one.** The safety modifier pins the operator modifier's address in the emergency revoke permissions and in the technical disable permission. Replacing the operator modifier therefore invalidates those pins, and the safety policy must be rewritten by DAO vote in the same action. This is accepted and belongs in the runbook; it is the cost of pinning, and pinning is what makes the technical role safe.

Costs: a third Safe with the TMC signers, two policy applications, two sets of role keys, two modules enabled on the Asset Safe, a module argument pinned per instance, and the Operator Safe pinned as the immutable trusted caller of every factory.

### Test Cases

40 tests pass against deployed mainnet bytecode on a fork pinned at block 25946643, at commit 7a8c661 of this repository [s4]. Nothing has been deployed to mainnet. The [invariants](/specs/invariants.md) map these tests to the invariants they check.

| Group | n | Covers |
| --- | --- | --- |
| Governance script encoding | 6 | Production CallsScript format accepted; 32-byte length rejected; truncated length rejected; multi-call script; script substituted at enactment rejected; objection rejection |
| Governance change types | 4 | Spender, target, selector, budget |
| Direct DAO path | 1 | The owner path applies the same change without Easy Track |
| Escalation guards | 4 | Governance cannot change membership, cannot touch the emergency role, cannot grant the operator an administrative target, cannot raise a foreign allowance key |
| Budget motions | 3 | A motion and the governance role cannot set a refill period below 30 days; per-key ceilings are expressible with native conditions |
| Operator lifecycle | 5 | sUSDS, staking, wstETH and WETH round trips on real contracts; the DAI–USDS converter pays the Safe both ways, with a fixed ceiling on its approvals; a withdrawal-queue round trip buys WETH; receiver pinning enforced; asynchronous vault deposit authorised at the policy layer |
| Emergency and module | 3 | Revoke, zero approval, exit, and return-to-Agent flow; WETH unwrapped, staked and sent to the Agent, through WETH's 2,300-gas transfer; module disabling with owner recovery |
| Approvals | 3 | An approval spends its spender's key or stays below a fixed ceiling, and zero is free; the operator cannot restore an approval after revocation; one approve scope per token keeps every spender |
| Budgets | 2 | Consumption, exhaustion, refill; keys of different assets and decimals are independent |
| Adversarial and launch scope | 3 | The operator cannot widen, reach administration or act as another role; it holds only the `operator` key; no order pre-signing, CoW relayer approval, Aave or sDAI |
| Policy shape | 3 | The policy builds; the `operator` key is the only operator key; no out-of-scope target, spender or receiver |
| Asset Safe shape | 1 | The Agent is the only owner, threshold one; pinned singleton; no fallback handler, guard or module guard; the Safe owns both modifiers |
| Known limits recorded as tests | 1 | A single-child match leaves trailing parameters unconstrained |
| Funding bootstrap | 1 | The dry-run funding script |
| **Total** | **40** | |

Reproduce with `forge test` against an archive RPC, fork block 25946643.

## Configuration

### Parameters

| Parameter | Meaning | Proposed value |
| --- | --- | --- |
| Objection period | Easy Track window before a motion may enact | 72 hours, the Easy Track default |
| Objection threshold | Share of LDO supply that rejects a motion | 0.5 percent, the Easy Track default |
| Approval bound | How an operator approval is bounded | An approval to a protocol spender spends the budget of the key it serves; zero is free; deposits no longer spend budget. The stETH approval to the wstETH contract keeps a fixed ceiling of one TM Floor Value in stETH, and so do the DAI and USDS approvals to Sky's DAI–USDS converter (OD-22) and the stETH approval to Lido's withdrawal queue (OD-27). Swapping needs no approval (OD-08, decided) |
| Budget per key | Monthly token-unit allowance | **Derived, run and attested** on 2026-09-22 outside this repository. Monthly flow equals the stock cap for that key, because exits are unbudgeted and a tighter flow would throttle re-entry after a defensive exit. Yield-bearing keys get the headroom against the literal base, the stablecoins plus yield-bearing stablecoins held directly, from a holdings snapshot at each retune (OD-03). The inputs include unapproved mandate terms, so the computation and its result enter this repository when the mandate is approved |
| Lido own-product budgets | Monthly allowance for the vault products | The mandate sets no per-product cap and the whole vault may sit in Lido products, so these keys are bounded by the mandate size rather than by a ratio. That is a weak control. The budget exists to bound blast radius per month, not to enforce a ratio |
| Budget retune cadence | How often unit budgets are re-derived | Fortnightly, riding the existing rebalancing review. Budgets are token units and caps are ratios, so they drift with price |
| Budget refill period floor | Lower bound enforced on `period` | 30 days (OD-08, decided) |
| Swap order duration | Per-instance immutable on each swap instance | 1800 seconds, as on the live instances (OD-05) |
| Swap margin | Per-instance immutable, basis points | 110 for volatile pairs, 30 for stablecoin pairs (OD-05) |
| Swap price tolerance | Per-instance immutable, basis points | 550 for volatile pairs, 150 for stablecoin pairs (OD-05) |
| Swap maximum improvement and partial fills | Per-instance immutables | 1000 basis points; partial fills on (OD-05) |
| Price feeds | The vault's tokens on the Stonks price router | USDC, USDT, DAI and USDS added by the TMC multisig, quoted in USD, with a maximum price age equal to Chainlink's heartbeat; stETH and LDO as already configured (OD-20) |
| Funding period and limit | Funding cap per period, in each of the two registries | One calendar month; one TM Floor Value per period in each registry; stablecoins at par; stETH at the Coingecko price pinned when the enabling vote is prepared. Set by attested computation; the figures enter with the approved mandate (OD-06, decided) |

### Roles and Authority

| Action | Who | Path | Latency |
| --- | --- | --- | --- |
| Open or close a position | Operator Safe, with the vendor's approval | Through the operator modifier | After the approval lands |
| Remove a strategy | Emergency Safe, two signatures | Direct through the safety modifier: `revokeTarget` or `revokeFunction` on the `operator` key | Minutes |
| Adjust a budget within ceilings | Operator proposes | Easy Track motion, governance role | 72 hours |
| Onboard a new protocol or asset | Operator proposes | Easy Track motion, template factory | 72 hours |
| Top up the vault | Operator Safe proposes with the vendor's approval, anyone enacts | Easy Track motion, top-up factory, paying the Asset Safe only | 72 hours |
| Revoke the operator | Emergency Safe, two signatures | Direct through the modifier | Minutes |
| Disable the operator modifier | Emergency Brakes multisig, three signatures | Direct through the safety modifier, technical role | Minutes |
| Re-sync a price feed | TMC multisig, four signatures, as the price router's manager | `syncTokenFeed` on the Stonks price router | Minutes, subject to signer availability |
| Freeze queued motions | Emergency Brakes multisig, a separate body | Easy Track pause | Minutes, subject to paging them |
| Return assets to the DAO | Emergency Safe, two signatures | Direct through the modifier | Minutes to initiate |
| Replace the whole policy | DAO | Vote through Dual Governance to the Agent | Vote plus Dual Governance timelock |
| Burn first-loss Earn shares | DAO | Vote through Dual Governance; the Asset Safe calls `burn` on the share token | Vote plus Dual Governance timelock |

Signer-set reconciliation between the operator multisig and the Emergency Safe is a manual runbook duty, handled the same way as consensus-member and committee rotations elsewhere in the protocol. There is no on-chain enforcement, so a rotation is not complete until both Safes are updated.

Note that the direct DAO path runs through Dual Governance, because the Dual Governance admin executor is the holder of the Agent's execution roles. Any statement about DAO-side response time must include that delay.

## Security Considerations

**Composition is the primary risk.** Each component is audited separately. The composition — a Safe that owns the modifier that administers the Safe — is the novel part and is what an audit must cover. Specifically: whether any role can reach an owner-only surface, directly or through a permission granted to another role.

**Escalation through granted targets.** Pinning a role key is not sufficient. A governance role that can grant the operator a permission targeting the modifier has effectively granted itself administration. Both the target refusal in the modifier and the factory's allowlist address this, and neither should be treated as sufficient alone.

**Escalation through execution options.** A delegatecall from the Asset Safe runs the target's code in the Safe's own storage, so a grant of delegatecall is a grant of the Safe. A fork probe on 2026-10-06 showed this through the governance role before the fix. The governance role now grants only None or Send, and delegatecall for the operator needs a DAO vote (OD-36).

**Replacement semantics.** Because a write replaces a permission slot rather than merging, an additive-looking change can silently drop earlier constraints. This design avoids the hazard by never letting a motion write a tree, but any future tooling that applies policy directly must emit complete trees.

**Order pre-signing is opaque.** The settlement contract's pre-signature call carries only an order identifier and a boolean. Sell token, buy token, amounts, and receiver are committed inside a hash the modifier cannot read. No parameter condition can cap a sell amount or pin a receiver on that path. Exposure is bounded only by the standing approval and by monitoring. This design removes the path: no role needs a pre-signing permission, because every swap runs through Stonks instances (ADR 007). A router path, where destination token and recipient are ordinary calldata, is enforceable for destination but not for price, because a minimum-output argument is an absolute number.

**The operator and the emergency role do not fail independently.** They are the same people at different quorums. Two consequences. A signer-set compromise that reaches two keys reaches the emergency role, whose powers are one-way. And the requirement that the operator cannot veto an emergency action is now carried entirely by role scoping, since it is no longer supported by separation of persons. The compensating controls are that the emergency role can only reduce exposure, that its transfers are pinned to the Agent literal, and that the DAO can replace the whole policy. A third consequence: the fast exit is not independent of the committee. The path that is independent of it is a DAO vote, which takes days (OD-30).

**The technical and financial remedies are separated by design.** The global Easy Track pause stops a pending governance change from enacting; it does not stop an operator transaction or a defect in the permission layer from being exercised. Only module disabling does that. Both remedies are held by the technical committee, so the people who recognise a technical defect hold the switch that answers it. Because the switch disables only the operator modifier, the financial emergency role keeps its powers, and the two bodies do not need to coordinate on sequencing.

**Template factories are the widening surface.** Onboarding no longer needs a vote, so the audit question moves from "is this tree narrower" to "can this template ever emit something unsafe". Each template must be shown to pin every receiver and owner field, to bound every value-moving amount, and to be incapable of emitting an administrative selector. A template flaw is reachable by any motion that survives its objection window.

**Policy encoding.** The policy that the test suite exercises is this team's hand-written encoding. [ADR 004](/adr/004-specifications-and-policy-as-data.md) replaces it with a Zodiac constellation, a compiler and a round-trip check that reads the applied conditions back from the chain: the constellation in TypeScript, Clutch's own compiler that emits one committed JSON artifact, and a check that rebuilds the trees from the modifier's events (OD-33). The team works in the Zodiac UI, and local tooling verifies every transaction that the UI builds. The fork tests run on the compiled artifact. The round-trip check is phase 2 work; until it exists, nothing independent checks the encoding.

**Safe v1.5.0 has a short record.** The three new Safes run Safe v1.5.0. Certora and Ackee audited it, Certora's formal verification covers the vault's main Safe paths, no advisory concerns it, and Safe's bug bounty covers it. But it has held little value for a short time. Before March 2026, only 57 Safes were created on it through Safe's factory, and Safe{Wallet} made it the version of new Safes only on 2026-09-22 [s8]. The design keeps the vault off the code that changed most in v1.5.0: the Aragon Agent never signs for the Asset Safe as a contract, and the Asset Safe has no fallback handler. Safe's releases and advisories are checked again before the enabling vote, and a change on the vault's paths goes back to EM (OD-17). The large losses at Safe accounts so far came from falsified signing interfaces, third-party modules and signers' own permission changes, not from Safe's contracts [s8].

**Deployment provenance.** Explorer-verified source is not a build-to-bytecode comparison. Before funding, every reused component should be verified against a locally compiled tagged release.

## Failure Modes

| Failure | Trigger | Mitigation | Detection |
| --- | --- | --- | --- |
| Modifier bricked at deployment | Roles proxy deployed through a Safe proxy rather than a minimal proxy | Mandatory use of the Zodiac ModuleProxyFactory; deployment rehearsal on a fork | Deployment self-test before any funding |
| Role key mismatch | Deployment tooling and factories derive role keys differently | Pin the derivation and assert it at deployment | Deployment self-test |
| Operator key compromise | Signer compromise | Default deny, no transfer permission, receivers pinned to the avatar, budgets, approvals bounded by each spender's budget | Policy-drift and approval monitoring; budget burn-rate alerts |
| Emergency key compromise | Signer compromise | Emergency cannot add permissions, enter protocols beyond staking ETH, or change the recovery destination | Any emergency action pages the DAO; a revoke-only action pages at a lower severity than a transfer or a swap |
| Defect in Safe or Roles code | A bug in the Safe v1.5.0 singleton or in the Roles mastercopy | The vault's main Safe paths are ones that Certora formally verified, and the vault uses no fallback handler and no contract signature; Safe's releases and advisories are checked again before the enabling vote; the technical role can disable the operator modifier; the DAO can replace the policy or move the assets by vote | Safe's advisories and releases; the engineering organisation's watch on technical risk, including bug-bounty submissions; alerts on singleton, module and owner changes |
| Falsified signing interface | A signer's device or wallet interface shows one transaction and has another signed, as at Bybit in 2025 | The Operator Safe holds no assets, and each of its transactions needs the vendor's approval; the vendor is asked to refuse delegatecalls except to MultiSendCallOnly; the operator's permissions bound what a signing quorum can do; the emergency role's powers are one-way | Alerts on owner, guard, module and singleton changes of the three new Safes |
| Queued motion restores a revoked permission | An expansion motion enacts after an incident | Easy Track pause, held by the Emergency Brakes multisig; the operator Safe can cancel its own motion; after enactment, the emergency Safe revokes the permission again at once | Motion monitoring; the incident runbook must page the pause holder |
| Operator modifier disabled while positions are open | The technical committee acts during a defect | The safety modifier keeps working, so the emergency role can still exit and return assets | Module-enabled monitoring on the Safe, alert on any change |
| Technical committee unreachable during a permission-layer defect | Signer availability | The DAO path can replace the policy outright; the financial role can still revoke and exit through the safety modifier | Escalation clock in the runbook |
| Onboarding motion points at a malicious contract | A motion survives its objection window | Template pins receivers and bounds amounts, so loss is capped by the attached budget rather than the balance | Published diligence per motion; position and budget monitoring |
| Signer sets drift apart | The operator multisig rotates a signer and the emergency Safe does not | Operational reconciliation duty; no on-chain enforcement | Owner-set monitoring on both Safes |
| Budget drains too fast | A motion sets a very short refill period | `GreaterThan` floor of 30 days on `period` | Budget monitoring |
| Budget reset by repeated motions | Budget motions run in parallel, and each one resets a balance | The ceiling of each key; the objection window | A second budget motion on the same key within 14 days |
| Top-up above the shortfall | The operator Safe pulls more than the mandate allows, or outside the monthly cycle | A limit of one TM Floor Value per registry per month; the 72-hour objection; the screening guard; the emergency Safe can return funds to the Agent | Alerts on out-of-cycle motions, on a month's top-ups above the posted shortfall, and on a motion after an objected one |
| Spender pulls without a deposit | A protocol spender is upgraded to steal, or an approval stands too long | Each approval spends its key's budget, so approvals per period cannot exceed it; approvals in the same transaction as the deposit; the emergency role zeroes approvals and can revoke the approve permission | Approval inventory and budget burn monitoring |
| Exit impossible when it matters | Protocol illiquidity or asynchronous settlement | Receipt-token transfer to the Agent; claim later | Position inventory monitoring |
| First-loss shares redeemed | The operator or the emergency role redeems the Earn shares that carry the first-loss terms | A written rule; the redemption queue's delay; the proceeds stay in the Asset Safe, and a DAO vote can deposit them again | Alert when the vault's earnETH or earnUSD balance falls below the first-loss amount, or a redeem request would cross it |
| Price feed out of sync | Chainlink replaces an aggregator in its registry, as it did for USDC and USDT twice in September 2026 | The TMC multisig re-syncs the feed as the router's manager; recovery can send assets to the Agent, which needs no price | Alert when a vault token's feed is out of sync, or when the registry confirms a new aggregator for it |
| Screening vendor outage | The vendor's key stops approving | Fail closed: operator activity and new motions stop; recovery is unaffected; the owners can remove the guard after ten days | Approval-latency and vendor-heartbeat monitoring |
| Cap breach gets worse | The committee does not rebalance within its window | The Emergency Brakes multisig disables the operator modifier on the fixed trigger; the safety modifier keeps working, so recovery stays available | Monitoring's fortnightly cap reading on IPFS; its alert pages the Emergency Brakes multisig when the trigger is met |
| Monitoring unavailable | Service outage | On-chain permissions are the enforcement layer and do not widen when monitoring stops | Heartbeat on the monitor itself |

## Open Items

The [open-decisions register](/registers/open-decisions.md) tracks every open item. These can change the shape of this proposal:

1. **The vendor's confirmations (OD-07, decided).** Before deployment the vendor confirms in writing that it accepts the exclusion of standing approvals and agrees to be named. Its support for Safe v1.5.0 is confirmed, as EM reported on 2026-10-05 (OD-17). It is also asked to merge and document the 10-day build, and to refuse delegatecalls from the Operator Safe except to MultiSendCallOnly. The Lido-side party is the one that already holds the vendor's arrangement for the guarded Lido multisigs (OD-12).
2. **Mandate text owed.** The own-product limit and the protocol cap must state that Lido Lend counts against the protocol cap for its first three months (OD-04). The illustrative balance renames its "USD-denominated" heading (OD-03). The funding rules must allow sUSDS (OD-11). The reporting section must state the price rule and the late-report rule (OD-14). The legacy section must state that the mandate takes over the first-loss terms of the March 2026 Earn allocation: the Asset Safe holds the shares, a DAO vote executes any burn, and neither the operator nor the emergency role redeems them (OD-21, OD-28). The emergency section must describe the emergency Safe as the committee's signers at two of seven, the technical role of the Emergency Brakes multisig, and a DAO vote as the path that is independent of the committee (OD-30). The emergency swap goes into USDC, or into USDT as the second destination, not into any of the four main stablecoins (OD-26).
3. **Twyne.** The mandate lists a Twyne investment. No Lido address checked holds a Twyne position, and its form is not known. It reduces the seed only when its holder and form are shown (OD-21).

## Links

- Zodiac Roles modifier, deployed mastercopy: `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`
- Safe smart account v1.5.0 release: https://github.com/safe-fndn/safe-smart-account/releases/tag/v1.5.0
- Easy Track: https://docs.lido.fi/deployed-contracts/#easy-track
- Treasury Management Committee: https://docs.lido.fi/multisigs/committees#25-treasury-management-committee
- Emergency Brakes: https://docs.lido.fi/multisigs/emergency-brakes#12-emergency-brakes-ethereum

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
