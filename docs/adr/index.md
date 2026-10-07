# Decision records

One global sequence. Every record is agent-drafted and `proposed` until EM accepts it. The Treasury Management Committee is the permanent acceptor, and a record that constrains the operator also needs a verification from the Emergency Brakes multisig ([ADR 002](002-decision-and-review-process.md)). Open items are in the [open-decisions register](/registers/open-decisions.md).

# Repository and process

* [ADR 001: Repository scope, visibility, licence and name](001-repository-scope-visibility-licence-name.md) - one repository, private until deployment, AGPL-3.0-or-later with GPL-3.0 kept for Easy Track-derived files, named Clutch.
* [ADR 002: Decision and review process](002-decision-and-review-process.md) - EM accepts in the interim, the committee permanently, Emergency Brakes verifies constraining records; a review ladder that an edit resets.
* [ADR 003: Agent operating model](003-agent-operating-model.md) - a 60-line AGENTS.md of rules, skills for procedures, and hard limits on what agents do.
* [ADR 004: Specifications and the permission policy as data](004-specifications-and-policy-as-data.md) - conceptual specs, invariants mapped to tests, the LIP as an external layer, runbooks, and a policy written as a Zodiac constellation, compiled into a committed artifact, with a round-trip check.
* [ADR 012: Contributing with many agents](012-contributing-with-many-agents.md) - any agent may author and only listed humans verify; agents own no GitHub accounts; a merge queue; decisions enter as complete rows and are decided in batched interviews; safe mainnet and hosted-app defaults, one command for setup and checks, and checks for restricted terms, licences, invariants and IDs.

# System design

* [ADR 005: Account graph and roles](005-account-graph-and-roles.md) - an Agent-owned Asset Safe with two Roles modifiers, an operator Safe and an emergency Safe with the committee's signers, a technical role for Emergency Brakes, an orders account and a first-loss Safe, and Safe v1.5.0 for the new Safes, for the orders account once a fork test passes.
* [ADR 006: Governance through Easy Track factories](006-governance-through-easy-track-factories.md) - factories are the only new contracts and only expand; templates fixed at audit time; the operator Safe is the trusted caller; every removal is the emergency Safe's immediate revoke.
* [ADR 007: Swapping through an orders account](007-swapping-through-an-orders-account.md) - CoW market, limit, TWAP and stop-loss orders from a dedicated Agent-owned orders account; the operator's orders pay the Asset Safe, recovery orders pay the Agent into USDC or USDT; CoW only at launch; Stonks 2.0 replaced.
* [ADR 008: Funding through the existing payment path](008-funding-through-existing-payments.md) - Finance and two dedicated recipients registries, stablecoins and stETH, each with a one-month period and a limit of one TM Floor Value; a DAO vote adds USDS to the shared payment permission; the DAO's first-loss Earn shares move from the Growth Committee into a dedicated first-loss Safe.
* [ADR 009: Budgets, exposure caps, reporting and monitoring](009-budgets-caps-reporting-and-monitoring.md) - layered controls with a control matrix, the liquidity buffer, the cap tier of new Lido products, reports on IPFS, budgets by attested computation, two monitoring estates, and the Zodiac UI's display of Lido's readings.
* [ADR 010: Pre-execution screening](010-pre-execution-screening.md) - the screening vendor's transaction guard on a dedicated operator Safe that is also the trusted caller; fail closed; recovery never screened; the vendor's rules are a written list, and a relaxation is under change control.
* [ADR 011: Launch scope](011-launch-scope.md) - the launch assets and venues; Lido Lend by motion through a Morpho Blue template, in the protocol cap until it matures; swaps through CoW orders; DAI earns through Sky's DAI–USDS converter; no sDAI, no third-party lending, and no router swaps at launch.
