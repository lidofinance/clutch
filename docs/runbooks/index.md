# Runbooks

One runbook per emergency or technical action. Each maps to a permission and carries a fork drill record before it rises above `slop` ([ADR 004](/adr/004-specifications-and-policy-as-data.md), [specification policy](/specs/specification-policy.md)). The general Lido incident process owns paging and escalation; these runbooks own the vault-specific steps and transactions.

No runbook is written yet. The table lists the runbooks that the design owes, with the permission each exercises.

| Runbook | Holder | Permission | Written | Drilled |
|---|---|---|---|---|
| Revoke the operator | emergency Safe | `revokeTarget` and `revokeFunction` on the operator modifier, role key pinned to `operator` | No | No |
| Zero the approvals | emergency Safe | `approve(spender, 0)` on each launch token | No | No |
| Exit positions to the Safe | emergency Safe | redeem, withdraw, cancel and claim on each position, receiver and owner pinned to the avatar | No | No |
| Recovery swap | emergency Safe | `transfer` pinned to a recovery swap instance, then `placeOrder` by the emergency Safe as the instance's manager | No | No |
| Clear a stuck recovery order | emergency Safe | after expiry, anyone returns the tokens to the instance; the emergency Safe places a new order, or recovers the tokens to the Aragon Agent | No | No |
| Return assets to the Agent | emergency Safe | `transfer` pinned to the Aragon Agent | No | No |
| Disable the operator modifier | Emergency Brakes Safe | `disableModule` on the Asset Safe, module argument pinned to the operator modifier | No | No |
| Pause Easy Track | Emergency Brakes Safe | the existing Easy Track `pause()` | No | No |
| Remove the screening guard | the operator Safe's owners | start the guard's 10-day removal timelock, then `setGuard` on the operator Safe once it expires | No | No |
| Replace the operator Safe | DAO | a vote that grants the operator role to a new Safe, updates the governance role's conditions and registers every factory again with the new trusted caller | No | No |
| Rotate a signer on all three Safes | the committee's Safe, the operator Safe and the emergency Safe | owner management on each Safe; the rotation is complete only when all three match | No | No |
| Replace the operator modifier | DAO | a vote that deploys the new modifier and rewrites the safety policy in the same action | No | No |
