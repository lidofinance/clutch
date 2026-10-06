# Runbooks

One runbook per emergency or technical action. Each maps to a permission and carries a fork drill record before it rises above `slop` ([ADR 004](/adr/004-specifications-and-policy-as-data.md), [specification policy](/specs/specification-policy.md)). The general Lido incident process owns paging and escalation; these runbooks own the vault-specific steps and transactions.

No runbook is written yet. The table lists the runbooks that the design owes, with the permission each exercises.

| Runbook | Holder | Permission | Written | Drilled |
|---|---|---|---|---|
| Revoke the operator | emergency Safe | `revokeTarget` and `revokeFunction` on the operator modifier and on the orders operator modifier, role key pinned to `operator` | No | No |
| Remove a strategy | emergency Safe | `revokeTarget` or `revokeFunction` on the operator modifier, or on the orders operator modifier, for one target or function, role key pinned to `operator`; then a forum post | No | No |
| Zero the approvals | emergency Safe | `approve(spender, 0)` on each token that the operator can approve | No | No |
| Exit positions to the Safe | emergency Safe | redeem, withdraw, cancel and claim on each position, receiver and owner pinned to the avatar; the first-loss shares sit in the first-loss Safe, out of reach ([ADR 008](/adr/008-funding-through-existing-payments.md)) | No | No |
| Recovery order | emergency Safe | `transfer` pinned to the orders account; then, on the orders account, a delegatecall to the CoW order signer for an order that buys USDC or USDT, pays the Aragon Agent and lives at most 1 day; a new order if it does not fill ([ADR 007](/adr/007-swapping-through-an-orders-account.md)) | No | No |
| Cancel orders and sweep the orders account | emergency Safe | on the orders account: `unsignOrder` on the order signer and `remove` on ComposableCoW for each open order, then `transfer` of each token to the Aragon Agent or the Asset Safe; where needed, an approval of CoW's vault relayer set to zero, which also stops recovery orders in that token until a DAO vote | No | No |
| Return assets to the Agent | emergency Safe | `transfer` pinned to the Aragon Agent | No | No |
| Disable the operator modifier | Emergency Brakes Safe | `disableModule` on the Asset Safe, module argument pinned to the operator modifier, and the same on the orders account for the orders operator modifier; for a defect in the permission layer, or on the cap-breach trigger of [ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md) | No | No |
| Pause Easy Track | Emergency Brakes Safe | the existing Easy Track `pause()` | No | No |
| Top up the vault | operator Safe | `createMotion` on the vault's top-up factories, as their trusted caller: the seed once, then after a month-end snapshot | No | No |
| Move the legacy Earn shares | the Growth Committee's Safe | `transfer` of the DAO's first-loss earnETH and earnUSD shares to the first-loss Safe, once, after the enabling vote ([ADR 008](/adr/008-funding-through-existing-payments.md)) | No | No |
| Burn first-loss Earn shares | DAO | a vote that has the first-loss Safe call `burn` on the earnETH or earnUSD share token, after a flagged loss | No | No |
| Re-set a funding limit | DAO | `setLimitParameters` on a funding registry, by vote: re-pin the stETH limit, or set a limit to zero after an objected top-up | No | No |
| Restore the liquidity buffer | operator Safe | the operator's own permissions: exit a position, or sell through a CoW order into a stablecoin, within the mandate's window after the buffer alert ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) | No | No |
| Unlock a matured product | operator Safe, as the budget factory's trusted caller | a forum post that names the maturity criteria the product meets, then a budget motion that raises the product's key to the bound of an own product ([ADR 009](/adr/009-budgets-caps-reporting-and-monitoring.md)) | No | No |
| Remove the screening guard | the operator Safe's owners | start the guard's 10-day removal timelock, then `setGuard` on the operator Safe once it expires | No | No |
| Replace the operator Safe | DAO | a vote that grants the operator role to a new Safe and registers every factory again with the new trusted caller | No | No |
| Rotate a signer on all three Safes | the committee's Safe, the operator Safe and the emergency Safe | owner management on each Safe; the rotation is complete only when all three match | No | No |
| Replace the operator modifier | DAO | a vote that deploys the new modifier and rewrites the safety policy in the same action | No | No |
