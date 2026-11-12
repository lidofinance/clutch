# Decision records

EM accepts ADRs in the interim. The Treasury Management Committee is the permanent acceptor.
No other body verifies an ADR before acceptance ([ADR 002](002-decision-and-review-process.md), OD-63).
Each ADR records its decision and review status, and shows the current design only: a replaced decision keeps its number as one line that names what holds now (OD-128). Pending questions are in the [open-decisions register](/registers/open-decisions.md).

## Repository and process

| ADR | Subject |
|---|---|
| [001](001-repository-scope-visibility-licence-name.md) | Repository scope, publication, licences and name |
| [002](002-decision-and-review-process.md) | Acceptance, verification and review states |
| [003](003-agent-operating-model.md) | Agent instructions, procedures and limits |
| [004](004-specifications-and-policy-as-data.md) | Specifications, policy artifacts and verification |
| [012](012-contributing-with-many-agents.md) | Contribution workflow, CI and source pins |
| [013](015-tests-on-sepolia.md) | Sepolia tests, the Zodiac workspace and role-key migration, with mainnet design dependencies |

## System design

| ADR | Subject |
|---|---|
| [005](005-account-graph-and-roles.md) | Accounts, ownership, roles and emergency powers |
| [006](006-governance-through-easy-track-factories.md) | The governance role's guards, onboarding by motion with its exit, removals and restores |
| [007](007-swapping-through-an-orders-account.md) | CoW orders and recovery through the orders account, and its restore |
| [008](008-funding-through-existing-payments.md) | First-loss shares, insurance funds and the mandate size |
| [009](009-budgets-caps-reporting-and-monitoring.md) | Budgets, exposure caps, pricing and monitoring |
| [010](010-pre-execution-screening.md) | Screening on the committee's Safe, the launch cap and the guard before the second tranche |
| [011](011-launch-scope.md) | Launch assets, venues and deferred integrations |
| [013](013-one-easy-track-factory.md) | One Easy Track factory with raw writes; Aragon votes after launch only for tranches and break-glass actions |
| [014](014-funding-by-tranche-votes.md) | Funding by tranche votes, insurance at launch, and the flows back to the treasury |
