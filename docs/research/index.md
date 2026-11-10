# Research

* [A token for the orders account by motion, 2026-11-08](orders-token-motions-2026-11-08.md) - OD-117 and OD-118: the factory's orders operation, a companion contract for EIP-170, and the factory that holds the motion roles and makes a motion's writes in one call, so that one motion adds a token under EIP-7825's gas cap.
* [The orders account's motion roles and the exit-governance role on a fork, 2026-11-08](orders-motion-roles-2026-11-08.md) - OD-103 and OD-49: the orders modifier's governance and approvals roles, the exit-governance role, the compiler's grant rules, and a token motion's writes run by hand.
* [The orders account's policy on a fork, 2026-11-07](orders-account-fork-tests-2026-11-07.md) - ADR 007's fork tests: the order signer and TWAP orders from Safe v1.5.0; OD-115 and OD-116.
* [The universal factory's prototype, 2026-11-05](universal-factory-prototype-2026-11-05.md) - OD-102 to OD-104, OD-113 and OD-114: the factory's core, an approval list, introductions and restores, on a fork.
* [One Easy Track factory and funding by tranche votes, 2026-11-05](easy-track-first-2026-11-05.md) - OD-100 to OD-112: Easy Track's script permissions, cancel and pause; Roles storage; Merkle-root engines; the two-modifier alternative; Finance payments by Aragon Voting; the flows to the Aragon Agent.
* [The enabling vote rehearsed on a mainnet fork, 2026-10-15](enabling-vote-rehearsal-2026-10-15.md) - OD-92 to OD-94: the vote run on forks of 2026-10-15 and 2026-10-22, the vote of approved hashes under EIP-7825, and the ramp-up. Since OD-106 the vote has no registries and no USDS items; the approved-hash evidence stands.
* [The committee's Safe as the operator, reviewed again, 2026-10-15](operator-safe-review-2026-10-15.md) - OD-80 and OD-83: operator account alternatives, other duties and the fork probe.
* [One Aragon vote to launch, Easy Track afterwards, 2026-10-14](single-vote-review-2026-10-14.md) - OD-68–OD-73: launch vote composition and later actions that still require a vote. OD-78, OD-92, OD-101 and OD-106 later changed the vote and the list; the OD-73 evidence stands.
* [The committee's feedback of 2026-10-12](cfo-feedback-2026-10-13.md) - OD-58–OD-67: emergency powers, first-loss terms, order life and pricing.
* [The onboarding guide's tests and pins, 2026-10-12](guide-invariants-2026-10-12.md) - ADR 012: presentation defects, source pins and guide drift.
* [Chain reads for the design ADRs, 2026-09-30](chain-reads-2026-09-30.md) - Pinned on-chain reads and the commands used by the design ADRs.
* [The Zodiac constellation as the policy backbone, 2026-10-06](zodiac-constellation-2026-10-06.md) - OD-33 and OD-34: upstream policy, local tooling and differences from the design.
* [The repository and many contributors with agents, 2026-10-07](contributor-readiness-2026-10-07.md) - ADR 012: contributor workflow, CI coverage and the keystore rehearsal.
* [The request for solution against the decided design, 2026-10-07](request-for-solution-2026-10-07.md) - Lido's asks to the policy provider, without allocation figures; the guide maps them to the design.
* [CoW orders from a dedicated orders account, 2026-10-06](cow-orders-account-2026-10-06.md) - OD-43: order signer, conditional orders, fallback handler and UI limits.
* [Safe v1.5.0 and the screening guard, 2026-10-02](safe-v150-guard-compatibility-2026-10-02.md) - OD-02: guard compatibility, support and the restricted fork test. Since OD-80 and OD-83 the guard goes on the committee's v1.3.0 Safe.
* [Safe v1.5.0 due diligence, 2026-10-05](safe-v150-due-diligence-2026-10-05.md) - OD-17: audit scope, advisories, incidents and the Safe paths Clutch uses.
* [Recovery into USDT and the withdrawal-queue approval, 2026-10-05](recovery-and-withdrawal-queue-2026-10-05.md) - OD-26 and OD-27: stablecoin exposure and withdrawal-queue constraints. The withdrawal queue left the design on 2026-10-08 (ADR 007, decision 27).
* [DAI and the DAI–USDS converter, 2026-10-05](dai-usds-conversion-2026-10-05.md) - OD-22: treasury assets, converter behaviour and token upgradeability.
* [Legacy investments, 2026-10-05](legacy-investments-2026-10-05.md) - OD-21: first-loss Earn shares, their holder and transferability; the Twyne search.
* [AI-first repository practice, September 2026](ai-first-practice-2026-09.md) - Evidence behind ADRs 002 and 003.

## Archived

Later decisions replaced the designs in these notes. They stay as the evidence of the decisions that closed them.

* [Easy Track funding registries, 2026-10-02](funding-registries-2026-10-02.md) - OD-06: registry limits, periods, payment reference and live examples. OD-106 replaced the registries with tranche votes on 2026-11-05.
* [Simplification options, 2026-10-08](simplification-2026-10-08.md) - OD-54–OD-57: launch cap, budgets and modifier alternatives. EM answered on 2026-10-08 and 2026-10-09; OD-58, OD-80 and OD-83 changed the design again.
* [Stonks 2.0 pricing, 2026-10-05](stonks-pricing-2026-10-05.md) - OD-20: router, feeds and WETH pricing. OD-43 replaced this design on 2026-10-06.
* [Stonks 2.0 instances, 2026-10-02](stonks-instances-2026-10-02.md) - OD-05 and OD-18: roles, orders, funding and pricing. OD-43 replaced this design on 2026-10-06.
