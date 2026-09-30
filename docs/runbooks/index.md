# Runbooks

One runbook per emergency or technical action. Each maps to a permission and carries a fork drill record before it rises above `slop` ([ADR 004](/adr/004-specifications-and-policy-as-data.md), [specification policy](/specs/specification-policy.md)). The general Lido incident process owns paging and escalation; these runbooks own the vault-specific steps and transactions.

No runbook is written yet. The table lists the runbooks that the design owes, with the permission each exercises.

| Runbook | Holder | Permission | Written | Drilled |
|---|---|---|---|---|
| Revoke the operator | emergency Safe | `revokeTarget` and `revokeFunction` on the operator modifier, role key pinned to `operator` | No | No |
| Zero the approvals | emergency Safe | `approve(spender, 0)` on each launch token | No | No |
| Exit positions to the Safe | emergency Safe | redeem, withdraw, cancel and claim on each position, receiver and owner pinned to the avatar | No | No |
| Recovery swap | emergency Safe | `transfer` pinned to a recovery swap instance, then `placeOrder` by anyone | No | No |
| Return assets to the Agent | emergency Safe | `transfer` pinned to the Aragon Agent | No | No |
| Disable the operator modifier | Emergency Brakes Safe | `disableModule` on the Asset Safe, module argument pinned to the operator modifier | No | No |
| Pause Easy Track | Emergency Brakes Safe | the existing Easy Track `pause()` | No | No |
| Detach the screening guard | DAO, owner path | `setModuleGuard(address(0))` on the Asset Safe, or `setGuard(address(0))` on the operator Safe in route B | No | No |
| Rotate a signer on both Safes | the committee and the emergency Safe | owner management on each Safe; the rotation is complete only when both match | No | No |
| Replace the operator modifier | DAO | a vote that deploys the new modifier and rewrites the safety policy in the same action | No | No |
