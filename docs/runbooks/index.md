# Runbooks

One runbook per emergency or technical action. Each maps to a permission and carries a fork drill record before it rises above `slop` ([ADR 004](/adr/004-specifications-and-policy-as-data.md), [specification policy](/specs/specification-policy.md)). The general Lido incident process owns paging and escalation; these runbooks own the vault-specific steps and transactions.

No runbook is written yet. The table lists the runbooks that the design owes, with the permission each exercises.

| Runbook | Holder | Permission | Written | Drilled |
|---|---|---|---|---|
| Revoke the operator | emergency Safe | `revokeTarget` and `revokeFunction` on the operator modifier, role key pinned to `operator` | No | No |
| Remove a strategy | emergency Safe | `revokeTarget` or `revokeFunction` on the operator modifier for one target or function, role key pinned to `operator`; then a forum post | No | No |
| Zero the approvals | emergency Safe | `approve(spender, 0)` on each token that the operator can approve | No | No |
| Exit positions to the Safe | emergency Safe | redeem, withdraw, cancel and claim on each position, receiver and owner pinned to the avatar; never a redemption of the first-loss Earn shares, which go to the Agent ([ADR 008](/adr/008-funding-through-existing-payments.md)) | No | No |
| Recovery swap | emergency Safe | `transfer` pinned to a recovery swap instance, then `placeOrder` by the emergency Safe as the instance's manager | No | No |
| Clear a stuck recovery order | emergency Safe | after expiry, anyone returns the tokens to the instance; the emergency Safe places a new order, or recovers the tokens to the Aragon Agent | No | No |
| Return assets to the Agent | emergency Safe | `transfer` pinned to the Aragon Agent | No | No |
| Disable the operator modifier | Emergency Brakes Safe | `disableModule` on the Asset Safe, module argument pinned to the operator modifier; for a defect in the permission layer, or on the cap-breach trigger of [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | No | No |
| Pause Easy Track | Emergency Brakes Safe | the existing Easy Track `pause()` | No | No |
| Top up the vault | operator Safe | `createMotion` on the vault's top-up factories, as their trusted caller: the seed once, then after a month-end snapshot | No | No |
| Move the legacy Earn shares | the Growth Committee's Safe | `transfer` of the DAO's first-loss earnETH and earnUSD shares to the Asset Safe, once, after the enabling vote ([ADR 008](/adr/008-funding-through-existing-payments.md)) | No | No |
| Burn first-loss Earn shares | DAO | a vote that has the Asset Safe call `burn` on the earnETH or earnUSD share token, after a flagged loss | No | No |
| Re-set a funding limit | DAO | `setLimitParameters` on a funding registry, by vote: re-pin the stETH limit, or set a limit to zero after an objected top-up | No | No |
| Re-sync a price feed | the committee's Safe, as the price router's manager | `syncTokenFeed`, or `syncEthUsdBridge` for the ETH/USD bridge, on the Stonks price router, after Chainlink replaces an aggregator ([ADR 007](/adr/007-swapping-through-stonks.md)) | No | No |
| Remove the screening guard | the operator Safe's owners | start the guard's 10-day removal timelock, then `setGuard` on the operator Safe once it expires | No | No |
| Replace the operator Safe | DAO | a vote that grants the operator role to a new Safe and registers every factory again with the new trusted caller | No | No |
| Rotate a signer on all three Safes | the committee's Safe, the operator Safe and the emergency Safe | owner management on each Safe; the rotation is complete only when all three match | No | No |
| Replace the operator modifier | DAO | a vote that deploys the new modifier and rewrites the safety policy in the same action | No | No |
