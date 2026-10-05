# Roadmap

The roadmap is gated, not dated. A phase starts when the gates of the previous phase are closed. External dates enter only where an external process sets them.

| Phase | Main job | Gate to leave the phase |
|---|---|---|
| 0. Decisions | Accept the setup ADRs 001–004 and the design ADRs 005–011. Close the open decisions. Get the screening vendor's written confirmations: Safe v1.5.0 support, no standing approvals, and consent to be named. | EM accepts each ADR, with the Emergency Brakes multisig verifying those that constrain the operator. Every open decision is closed or explicitly deferred. |
| 1. Specification | Write the conceptual specs: architecture, roles matrix, permission model, threat model, monitoring specification. Give every invariant an ID. Define the policy data format and the compiler. Draft the runbooks. Import the budget computation once the mandate is approved. | The acceptor accepts the specs. Every invariant has an ID and names its ADR. |
| 2. Build | Build the policy compiler and the round-trip check. Move the policy to the data file with the accepted launch scope and the Stonks swap path. Build the Easy Track factories. Configure the funding path. Deploy-script the swap instances. Build the report generator. Add the invariant-to-test check and the one-command verification. | Every invariant maps to a passing test, and CI enforces it. Every permission change is verifiable by one command. |
| 3. Assurance | External audit of the factories, the policy and the deployment. Lido's review of the one change in the vendor's guard after its audit. Fork drills of every emergency and technical action. Review of the LIP against the specs. | Audit findings closed or accepted. Every emergency action is initiated within six hours in a drill. |
| 4. Governance and deployment | Forum post and Snapshot vote on the mandate. The LIP. The enabling on-chain vote. Deployment. | The repository is public no later than deployment. The vote passes. The deployed state matches the artifacts. |
| 5. Operation | Fortnightly budget retune. Monthly reports to IPFS. Recurring drills. | Continuous. |

## Standing gates

- **Traceability.** Every permission traces to a spec clause, an ADR, a test and a deployed artifact.
- **One-command verification.** Every permission change is verifiable by one command.
- **Six hours.** Every emergency action is initiated within six hours, proven in fork drills.
- No financial figure enters a document unless an attested computation produced it.
- No ADR is accepted without EM or the Treasury Management Committee, and no ADR that constrains the committee without the Emergency Brakes multisig.
