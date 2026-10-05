# Decision records

One global sequence. Every record is agent-drafted and `proposed` until EM accepts it. The Treasury Management Committee is the permanent acceptor, and a record that constrains the operator also needs a verification from the Emergency Brakes multisig ([ADR 002](002-decision-and-review-process.md)). Open items are in the [open-decisions register](/registers/open-decisions.md).

# Repository and process

* [ADR 001: Repository scope, visibility, licence and name](001-repository-scope-visibility-licence-name.md) - one repository, private until deployment, AGPL-3.0-or-later with GPL-3.0 kept for Easy Track-derived files, named Clutch.
* [ADR 002: Decision and review process](002-decision-and-review-process.md) - EM accepts in the interim, the committee permanently, Emergency Brakes verifies constraining records; a review ladder that an edit resets.
* [ADR 003: Agent operating model](003-agent-operating-model.md) - a 60-line AGENTS.md of rules, skills for procedures, and hard limits on what agents do.
* [ADR 004: Specifications and the permission policy as data](004-specifications-and-policy-as-data.md) - conceptual specs, invariants mapped to tests, the LIP as an external layer, runbooks, and a policy data file with a round-trip check.

# System design

* [ADR 005: Account graph and roles](005-account-graph-and-roles.md) - an Agent-owned Safe, two Roles modifiers, an operator Safe and an emergency Safe with the committee's signers, a technical role for Emergency Brakes, and Safe v1.5.0 for the three new Safes.
* [ADR 006: Governance through Easy Track factories](006-governance-through-easy-track-factories.md) - factories are the only new contracts and only expand; templates fixed at audit time; the operator Safe is the trusted caller; every removal is the emergency Safe's immediate revoke.
* [ADR 007: Swapping through Stonks 2.0](007-swapping-through-stonks.md) - fresh instances managed by the operator Safe and the emergency Safe; the receiver separates rebalancing from recovery; USDC hub, USDT second recovery destination; the committee's Safe keeps the vault's feeds; wstETH, sUSDS, WETH and ETH are converted before a sale.
* [ADR 008: Funding through the existing payment path](008-funding-through-existing-payments.md) - Finance and two dedicated recipients registries, stablecoins and stETH, each with a one-month period and a limit of one TM Floor Value; the shared payment ACL stays unchanged.
* [ADR 009: Budgets, exposure caps, reporting and monitoring](009-budgets-caps-reporting-and-monitoring.md) - detective caps, reports on IPFS, budgets by attested computation, two monitoring estates.
* [ADR 010: Pre-execution screening](010-pre-execution-screening.md) - the screening vendor's transaction guard on a dedicated operator Safe that is also the trusted caller; fail closed; recovery never screened.
* [ADR 011: Launch scope](011-launch-scope.md) - the launch assets and venues; Lido Lend by motion through a Morpho Blue template; WETH through stETH; DAI earns through Sky's DAI–USDS converter; no sDAI or third-party lending.
