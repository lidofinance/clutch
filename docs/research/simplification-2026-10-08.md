---
type: Research Note
title: Simplification options, 2026-10-08
description: The evidence behind OD-54 to OD-57 — eleven options to cut complexity and effort, checked against Lido practice and outside trust models (the ENS endowment, Aave's Finance Steward); EM's answers; a fork probe of one modifier per account; the budget keys that a retune touches; and how a capped launch without the screening guard holds on chain.
tags: [simplification, scope, governance, screening, budgets, modifiers, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-08
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-08T18:05:14Z
verified: []
sources:
  - id: s1
    resource: /registers/decision-log.md
    title: Decision log — EM's request for options and EM's answers, 2026-10-08
  - id: s2
    resource: "https://research.lido.fi/t/4279"
    title: Lido forum — Treasury Management Principles and the Treasury Management Committee, 2023-04-04
  - id: s3
    resource: "https://research.lido.fi/t/6860"
    title: Lido forum — Lido Stonks, treasury swaps through optimistic governance, 2024-03-14
  - id: s4
    resource: "https://research.lido.fi/t/8616"
    title: Lido forum — TMC-4, the committee's Easy Track limits changed by a DAO vote, 2024-10-09
  - id: s5
    resource: "https://research.lido.fi/t/10868"
    title: Lido forum — TMC-6, sUSDS added to the Easy Track configuration, 2025-11-03
  - id: s6
    resource: "https://research.lido.fi/t/9344"
    title: Lido forum — the Lido Labs BORG Foundation; configurations go to the nearest omnibus vote, 2025-01-16
  - id: s7
    resource: "https://discuss.ens.domains/t/draft-executable-next-era-of-ens-dao-empowering-the-ens-foundation/22329"
    title: ENS forum — the endowment's new timelock, its proposer and the Security Council's cancel, 2026-07-30
  - id: s8
    resource: "https://docs.ens.domains/dao/proposals/5.12"
    title: ENS EP 5.12 — the endowment's Roles modifier v2, owned by the endowment's Safe, with a manager role
  - id: s9
    resource: "https://governance.aave.com/t/arfc-aave-finance-steward-deployment/21495"
    title: Aave ARFC — the Finance Steward, owned by the DAO, with budgets that only governance adjusts, 2025-03-18
  - id: s10
    resource: "https://docs.safe.global/advanced/smart-account-guards"
    title: Safe documentation — a broken guard can cause a denial of service for a Safe
  - id: s11
    resource: "https://etherscan.io/block/26147727"
    title: Ethereum block 26147727, hash 0xf3b0d599a5ec5500297aa7c4a5d14f58441fbd37e68416676bab9bb8608fe2e8, 2026-10-08T12:37:23Z, used for every chain read on this page
  - id: s12
    resource: "https://eth.blockscout.com/address/0x703806E61847984346d2D7DDd853049627e50A40?tab=logs"
    title: Blockscout — the 617 decoded events of the ENS endowment's Roles modifier, read on 2026-10-08
  - id: s13
    resource: /research/funding-registries-2026-10-02.md
    title: Research note — how an Easy Track registry counts, its periods and who sets its limit
  - id: s14
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — budget keys, the fortnightly retune and the detective caps
---

# Simplification options, 2026-10-08

## Answer

- EM asked for options that keep most of Clutch's result with much less complexity and effort, each checked against Lido practice and established trust models [s1].
- The agent measured the result by the four properties of the request for solution, the committee's daily work and the six-hour exit. It measured the effort by counted items: new contracts, accounts, roles, invariants, outside dependencies and recurring work.
- EM answered on 2026-10-08 [s1]:
  - Not taken: no new contracts with DAO votes for every change (A), CoW market and limit orders only (B), orders from the Asset Safe (B2), recovery without swaps (D), no Lido-built display (G), Safe v1.4.1 (H) and the process cuts (K).
  - The withdrawal queue leaves the design (F). The rest of the launch list stays.
  - A launch without the screening guard is acceptable under a cap of about one to three million dollars (J). OD-54 and OD-55 ask how.
  - EM wants to discuss the budget retune (E). OD-56 asks it.
  - EM asked the agent to test and research one modifier per account (C). OD-57 asks it.
- EM answered OD-54 to OD-56 on 2026-10-09: the cap holds by procedure and a forum post lifts it (OD-54 C), the cap is one million dollars (OD-55 A), and budgets have no routine retune (OD-56 C) [s1]. EM chose one modifier on the orders account and two on the Asset Safe (OD-57 B) [s1].
- A fork probe shows that one modifier can carry the operator, emergency and technical roles. The technical role removes the operator Safe's membership, and recovery keeps working. Six tests pass, and four mutants each fail at least one of them.

## The options and EM's answers

EM's words are quoted exactly [s1].

| Option | What it cuts | EM, 2026-10-08 | Where it goes |
|---|---|---|---|
| A | The template factories, the exit-governance role and the budget factory; permissions and budgets change by DAO vote | "A is not an option, we must not do it basically it's a lot of ops burden" | [ADR 006](/adr/006-governance-through-easy-track-factories.md) stands |
| B | TWAP and stop-loss orders; ComposableCoW and the watch-tower | "possible but still undesirable" | [ADR 007](/adr/007-swapping-through-an-orders-account.md) stands |
| B2 | The orders account; orders from the Asset Safe | "agree to not consider, too scary" | ADR 007 stands |
| C | The second modifier on each account | "let's test it and research" | OD-57 |
| D | The emergency role's recovery orders | "agree to not consider, weak escape hatch without it" | ADR 007 stands |
| E | The fortnightly budget retune | "I want to talk a bit more" | OD-56 |
| F | The withdrawal queue, DAI with the converter, LDO and ETH staking at launch | "we can cut withdrawal queue; others should stay IMO" | ADR 007, [ADR 011](/adr/011-launch-scope.md) |
| G | The display that Lido would build, and five requested vendor rules | "a bit too weak to cut — we won't get rid of the on-chain code but we will lose UX a lot" | [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) stands |
| H | Safe v1.5.0, for v1.4.1 | "possible, but saves is too low" | [ADR 005](/adr/005-account-graph-and-roles.md), [ADR 010](/adr/010-pre-execution-screening.md) stand |
| J | The screening guard at launch | "we can launch without guard but under a cap of ~$1-3M only" | OD-54, OD-55 |
| K | Process: freeze the guide, batch refinements, one specification | "too early" | — |

## Evidence from Lido and outside models

### Lido

- **A DAO vote takes at least nine days on chain.** Aragon's vote time is 432,000 seconds, and its last 172,800 seconds are the objection phase. Dual Governance then waits 259,200 seconds after submission and 86,400 seconds after scheduling. Its state is Normal. Veto signalling starts at 1 percent of stETH for 5 days and grows to 45 days at 10 percent [s11].
- **Lido votes about once a month.** Aragon's vote count rose from 193 at block 23519727 (2025-10-06) to 206 at block 26147727 [s11].
- **Easy Track.** A motion lasts 259,200 seconds, the objection threshold is 50 basis points, at most 20 motions run at once, and 52 factories are registered [s11].
- **The committee never takes custody.** "The Committee multisig will strictly never take custody of Aragon funds" [s2]. Its Safe is a v1.3.0 Safe with a threshold of 4 of 7, no guard and no module [s11].
- **The committee's limits change by vote, not by new code.** Stonks moves tokens by "Easy Track motion or Aragon vote (in case of emergency)" [s3]. TMC-4 raised the committee's Easy Track limit by a DAO vote: "Minor risks as no new deployments are needed" [s4]. TMC-6 says the same [s5].
- **Configuration goes to an omnibus vote.** The BORG foundation posts a configuration "two weeks before an on-chain vote" and asks that it be "included in the nearest omnibus vote on Aragon" [s6].

### The ENS endowment

- **One modifier, one role.** The endowment's Safe `0x4F2083f5fBede34C2714aFfb3105539775f7FE64` runs v1.3.0 with no guard. Its modules are the Roles modifier `0x703806E61847984346d2D7DDd853049627e50A40` and a Safe allowance module [s11]. The endowment's Safe owns the modifier [s8]. The modifier has one role key, `MANAGER`, assigned once, to the Safe `0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978` (2 of 6) [s12][s11].
- **Orders from the asset Safe.** The only permissions with delegatecall are `signOrder` and `unsignOrder` on the CowswapOrderSigner `0x23dA9AdE38E4477b23770DeD512fD37b12381FAB`, scoped since block 19741836 [s12]. The Safe's fallback handler is Safe's `CompatibilityFallbackHandler` `0xf48f2b2d2a534e402487b3ee7c18c33aec0fe5e4`, not CoW's handler [s11].
- **Changes were executable proposals.** Seven permission updates, from 2024-09-02 to 2026-05-10, were each a transaction to the ENS Governor `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3`. At each of their blocks, the DAO's timelock `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` was the Safe's only owner [s12][s11].
- **Since 2026-08-11, a timelock owns the Safe.** The owner is a TimelockController `0x0bcC3dA6aD796F59288C0961602675E88A2B406C` with a minimum delay of 777,600 seconds (nine days) and an open executor. Its proposer is the ENS Foundation's Safe `0x9C7dB6B1085ec4D07f75c0BD91AD3FcD368fA19E` (3 of 5). A Security Council contract `0x0A9387643ce6291f8C545286675D76bCd0Ba3EdD` also holds the proposer role, exposes `cancel(bytes32)`, expires on 2028-08-07 and is owned by the Safe `0x7101B78638e34444F0a5AdE9e1149fbEeC029931` (5 of 8) [s11]. The forum post states that "the Security Council can veto the Foundation's proposals to the Endowment" during the delay [s7]. The swap of owners is in block 25729925 [s11].

### Aave's Finance Steward

- The steward's contracts "have the DAO as the owner", and their budget per token "can only be adjusted through Aave's governance" [s9].
- The guardian Safe `0x22740deBa78d5a0c24C58C740e3715ec29de1bFa` runs v1.4.1 with a threshold of 2 of 3 and no guard [s11]. The ARFC planned "a 3-out-of-4 multi-sig" [s9].

### Guards

- None of the four established Safes read has a transaction guard: the committee's Safe, the Emergency Brakes multisig (v1.3.0, 3 of 5), the ENS endowment and Aave's guardian Safe [s11]. They rely on default-deny policies, thresholds and governance.
- Safe's documentation warns that "a broken Guard can cause a denial of service for a Safe" [s10].
- Lido runs the screening vendor's guard on four multisigs and enforces it on one (ADR 010).

## A launch without the guard under a cap (OD-54, OD-55)

- **What the cap must do.** Without the guard, the operator's policy, the four-of-seven threshold, monitoring, the emergency revoke and the technical switch stay. The cap bounds what a compromised or mistaken operator can reach.
- **What it counts.** The Asset Safe and the orders account. The first-loss Safe has no module, so no role can reach it.
- **How a registry holds a cap.** A registry's period can be 12 calendar months, aligned to January. The limit is checked when a motion starts and spent at enactment. Only the registry's admin, the Aragon Agent, sets the limit and the period [s13]. Three of the twelve live top-up registries use 12 months [s13]. Around the boundary of a period, two full limits can be paid within about 72 hours [s13].
- **What moves from the launch to the lift.** The guard on the operator Safe with its bypass mode off, the vendor's written terms on standing approvals, Lido's review of the guard's post-audit change, the detector's support for Safe v1.5.0 and the requested rules. The gate of ADR 010 decision 8 then applies to the lift instead of the enabling vote.
- **What stays from day one.** The dedicated operator Safe. It is the immutable trusted caller of every factory, so it must exist before the factories. Its owners set the guard later with a Safe transaction, and no factory changes.
- **Outside practice.** The ENS endowment and Aave's guardian Safe run without a guard at far larger sizes, behind default-deny policies or budgets. The committee runs Stonks without a guard, with oracle-checked prices [s3][s11].

## Budgets (OD-56)

- **The keys.** One key per protocol spender on the Asset Safe: USDS to sUSDS, USDC to the earnUSD deposit queue, wstETH to the earnETH deposit queue, and Lido Lend's key after onboarding. One key per token on transfers into the orders account [s14].
- **Which keys a retune changes.** The yield-bearing key gets the headroom of its cap and needs a holdings snapshot at each retune. A new Lido product's key stays within the protocol cap until it matures. The keys for Lido's own products allow the whole mandate each month, which ADR 009 calls a weak control [s14]. A retune changes little on them, except after a change of the floor or a large price move. The orders keys bound swap flow per token; their figures are not set yet.
- **What a retune costs.** One budget motion that the operator Safe signs at four of seven, a forum disclosure (ADR 006 decision 4), the 72-hour objection window and the monitoring flag for a second budget motion on a key within 14 days. One motion can carry several keys. Every two weeks, that is about 26 motions a year.
- **The computation can run by itself.** An attested computation needs an attester that re-checks the result with deterministic code. A script that reads the chain at the snapshot's pinned block and the pricing source can produce the figures, as the report generator does (ADR 009 decision 19).

## One modifier per account (OD-57)

### The probe

`test/SingleModifierProbe.t.sol` runs on the pinned fork against the deployed Roles mastercopy `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`. It disables the safety modifier and puts the emergency and technical roles on the operator modifier. The technical role holds `assignRoles(operatorSafe, [operator], [false])` on its own modifier, with the module, the key list and the flag list pinned. `Matches` on an array also pins its length.

| Test | Shows |
|---|---|
| `test_C1_one_modifier_is_enabled` | The Asset Safe has one module |
| `test_C2_unassign_stops_the_operator_and_recovery_survives` | After the switch, the modifier refuses the operator with `NoMembership`, and the emergency role still returns USDC to the Agent |
| `test_C3_the_switch_is_pinned` | The technical role cannot remove another module or key, cannot assign, cannot pass a longer list, and reaches no other call |
| `test_C4_the_operator_cannot_restore_itself` | The operator cannot reassign itself, before or after the switch |
| `test_C5_emergency_revoke_on_its_own_modifier` | The emergency role revokes an operator target on its own modifier |
| `test_C6_the_dao_restores_the_operator` | The owner path assigns the role again |

- Result on 2026-10-08: 6 of 6 pass.
- Mutants: the flag pin loosened, the module pin loosened, the safety modifier left on, and the switch removed. Each one fails at least one test.
- **Why the path works.** A role's call executes as the Asset Safe, which owns the modifier. `assignRoles` is owner-only, and the modifier checks membership on every call [s11]. The governance role already administers its own modifier this way in the D1 drills.

### What the split still buys

- **On the Asset Safe.** Two motion writers act there: the governance role and the exit-governance role. With two modifiers, their writes can never reach the safety policy's storage. With one, only the role-key pin in each of their permissions keeps them out of the emergency and technical roles. The technical role can also disable a whole module at the Safe, which works even if a defect let a role pass the membership check.
- **On the orders account.** The governance role has nothing to write there. No template targets the orders account. A token joins its lists only by DAO vote (ADR 006 decision 12), and the delegatecall to the order signer comes only from a vote (OD-36). So no motion writer acts on the orders account, and one modifier there loses no isolation.

## How to reproduce

Set `ETH_RPC_URL` to an archive RPC in your shell. Never write the URL into a file.

```sh
B=26147727
cast call --block $B 0x2e59A20f205bB85a89C53f1936454680651E618e 'voteTime()(uint64)'
cast call --block $B 0x2e59A20f205bB85a89C53f1936454680651E618e 'objectionPhaseTime()(uint64)'
cast call --block $B 0x2e59A20f205bB85a89C53f1936454680651E618e 'votesLength()(uint256)'
cast call --block 23519727 0x2e59A20f205bB85a89C53f1936454680651E618e 'votesLength()(uint256)'
cast call --block $B 0xCE0425301C85c5Ea2A0873A2dEe44d78E02D2316 'getAfterSubmitDelay()(uint32)'
cast call --block $B 0xCE0425301C85c5Ea2A0873A2dEe44d78E02D2316 'getAfterScheduleDelay()(uint32)'
cast call --block $B 0xC1db28B3301331277e307FDCfF8DE28242A4486E 'getEffectiveState()(uint8)'
cast call --block $B 0xa1692Af6FDfdD1030E4E9c4Bc429986FA64CB5EF 'getDualGovernanceConfig()'   # raw words
cast call --block $B 0xF0211b7660680B49De1A7E9f25C65660F0a13Fea 'motionDuration()(uint256)'
# Safes: getThreshold(), getOwners(), VERSION(), the guard slot, getModulesPaginated(address,uint256)
cast storage --block $B <safe> 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8
cast call --block $B 0x0bcC3dA6aD796F59288C0961602675E88A2B406C 'getMinDelay()(uint256)'
cast call --block $B 0x0bcC3dA6aD796F59288C0961602675E88A2B406C 'hasRole(bytes32,address)(bool)' $(cast keccak PROPOSER_ROLE) 0x9C7dB6B1085ec4D07f75c0BD91AD3FcD368fA19E
RPC=$ETH_RPC_URL forge test --match-contract SingleModifierProbe
```

The Blockscout log API needs a browser user agent and the header `Referer: https://eth.blockscout.com/`: `/api/v2/addresses/0x703806E61847984346d2D7DDd853049627e50A40/logs`, paged with `next_page_params`.

## Limits

- Every read describes its block. A vote can change any setting above.
- Whether ComposableCoW orders could validate for the ENS endowment is inferred from its fallback handler, not tested.
- The seven ENS updates are identified as Governor executions, not mapped to proposal numbers.
- Lido Lend's deployment date is not public. The only source is EM's statement of 2026-09-22.
- The probe tests the switch and recovery on a single modifier. It does not test the exit-governance role on a single modifier, because the harness does not have that role yet.
