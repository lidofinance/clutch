# Lido ATM — mainnet dry-run kit (WS-M)

STATUS, stated plainly: **nothing has been deployed to mainnet.** All results
below come from `forge test` against a pinned mainnet fork (block 25946643).
The `just dry-run` / `just fund` mainnet path exists, is one command each,
and has NOT been executed. D7 (walk-away) and D8 (monitoring) from the plan
are not built. This kit tests a hand-derived re-encoding of the provider
policy (`src/policy/`); a diff against the provider toolchain's own applied
policy is a required follow-up before any finding about the proposal itself.

Due-diligence execution harness for the Lido Active Treasury Management RFP ×
the Zodiac constellation proposal (gnosisguild/lido-atm-constellation @ 02ea37d,
tracking HEAD). Everything downstream of the mocked governance heads is
**production-grade**: the Safe deploys from the v1.4.1 singleton
(0x41675C099F32341bf84BFc5382aF534df5C7461a), the Roles modifier proxies the
**deployed** v4 mastercopy (0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5), and all
tokens/protocols are mainnet contracts exercised on a pinned fork
(block 25946643).

## What is mocked, and how faithfully

| Mock | Stands in for | Fidelity mechanism |
|---|---|---|
| `MockAragonAgent` | Aragon Agent 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c | `forward(bytes)` (the deployed single-argument Aragon forwarder, 0xd948d468) + `execute` + `canForward`; runner set starts EMPTY, mirroring the pinned-block ACL where the ET executor holds no Agent role and the DG admin executor is the only role holder |
| `MockEVMScriptExecutor` | EVMScriptExecutor 0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977 | decodes the real Aragon CallsScript spec 0x00000001; executes chunks as itself; same calldata a production ET factory emits rehearses unchanged |
| `MockEasyTrack` | Easy Track 0xF0211b7660680B49De1A7E9f25C65660F0a13Fea | factory allowlist, LDO-weighted objections vs threshold, permissionless enactment, 72 h duration compressible for drills |
| `PassThroughEVMScriptFactory` | future Lido ET factories | passes a prebuilt script through — the shape-validation the real factories must do is WS-D work, deliberately not mocked here |

Owner-path execution uses the production two-step pattern
(`Agent → Safe.approveHash` then `execTransaction` with the v=1 owner signature).

**Governance shape (corrected 2026-09-10).** At the pinned block the Easy
Track EVM script executor holds NEITHER `RUN_SCRIPT_ROLE` NOR `EXECUTE_ROLE`
on the Agent; the only holder of both is the Dual Governance admin executor
`0x23E0B465633FF5178808F4A75186E2F2F9537021`. Granting the ET executor
`RUN_SCRIPT_ROLE` would be unrestricted execution behind a 3-day objection
window — the RFP forbids it. The kit therefore drives ET policy changes
through a third `policy-admin` role on the Roles modifier (the same
avatar-execution mechanism the emergency role uses): enacted motions call
`roles.execTransactionWithRole(adminCall, policy-admin)` and never touch
Agent authority. Production member: a Lido-built, shape-validating contract
(WS-D deliverable).

## One-click

```
just test-fork   # D1–D6 + bootstrap on the pinned fork (no keys)
just dry-run     # deploy mocks + Safe + Roles + full policy on MAINNET
just fund        # split 0.5 ETH into every base asset, deliver to the Safe
just teardown    # sweep all tracked tokens out, disable the module, manifest
```

Env: `RPC` (mainnet), `PRIVATE_KEY` (dedicated throwaway executor EOA),
optional `OPERATOR_STANDIN` / `EMERGENCY_STANDIN` (defaults = executor; use
separate throwaway keys for role separation in a serious rehearsal).

## Policy

`src/policy/` expresses the constellation permission set as Roles v4 admin
calls: both roles, merged spender Or-lists, avatar-pinned receivers, budget
allowances (dust-scale, structure-identical), the emergency revoke-only admin
surface, unpinned `disableModule` (kept deliberately — R3 evidence), and
return-to-Agent transfers. Budgets are dust-scale by design; production sizing
is WS-F work.

## Drill coverage (test/Drills.t.sol)

- **D1** all four RFP change types through the mock ET motion path via the
  policy-admin role (asset add/remove by full replacement scope that must not
  widen or drop; protocol target add/remove via scopeTarget/revokeTarget;
  selector add/remove; parameter-constraint tightening), objection-rejection,
  and golden-calldata parity through the Agent's real `forward(bytes)` shape
- **D2** the same change via the direct owner path, no ET
- **D3** operator lifecycle: Aave supply/withdraw for USDC **and the
  18-decimal DAI/wstETH legs under their own budget keys**, sDAI
  deposit/redeem, wstETH unwrap, CoW presign (uid.owner-enforced), LDO
  sell-leg approval (LDO sellable per interview B5/A5)
- **D3b** earn-deposit permission shape on the verified 3-param signature
- **D4** emergency: block operator via `revokeTarget`, approve-to-zero,
  avatar-pinned exits, return-to-Agent-only transfers; plus the **unpinned
  `disableModule`** demonstration (R3) and owner-path recovery
- **D5** budgets: consumption on execution, exhaustion revert, per-group key
  independence (k1 exhaustion does not touch k2/k3), refill after the period
- **D6** adversarial incl. the CoW opacity evidence: a hostile-receiver order
  presigns successfully because the order uid commits receiver/amounts inside
  the digest — no parameter condition on `setPreSignature` can pin a receiver
  or cap a sell amount; the enforceable part of R1 is capping the standing
  vault-relayer approval
- **D6** adversarial: operator cannot reach the admin surface or disable
  modules; emergency cannot widen or grant roles; unscoped spenders denied;
  the R1 unbounded-approval demo
- **Bootstrap** 0.05 ETH (reduced from 0.5 by principal instruction) →
  stETH/wstETH, USDC/USDT/DAI/LDO via Uniswap with slot0-derived minimum-out
  bounds, USDS via the Sky DaiUsds converter (`daiToUsds`), sDAI/sUSDS vault
  deposits → Safe, 0.01 ETH gas reserve, explicit `FUNDER`, resumable legs

## DD findings proven here (see notes/atm-* in the CTO KB)

1. **Proxy shape is load-bearing**: the deployed Roles v4 mastercopy keeps
   state from slot 0; deploying it behind a SafeProxy re-points the proxy at
   whatever `setUp` writes first (reproduced: recursion into the Safe). The
   canonical deployed `ModuleProxyFactory`
   `0x000000000000aDdB49795b0f9bA5BC298cDda236` is used (EIP-1167-style).
2. **`setUp(bytes)`**: the deployed mastercopy uses the FactoryFriendly
   signature, not the repo-HEAD `setUp(address,address,address)`.
3. **One scope per (role, target, selector)**: a second `scopeFunction`
   replaces the first entirely — provider/ET-factory widening must emit full
   replacement scopes, not additive grants.
4. RETRACTED 2026-09-10 (independent review): per-asset budgets ARE
   expressible — a root `Or` over full `Matches` branches, one per
   (asset-group, budget) pair, couples each branch's amount to its own
   allowance key. The kit now ships exactly the provider's three-budget shape;
   see `ReviewProbe.test_FX4_per_asset_budgets_ARE_expressible`. The narrow
   true statement that remains: an allowance key counts token UNITS, so a key
   shared across decimals is a defect (the provider's own note says so).
5. **EqualTo compValues are raw padded words** (the packer keccaks on store);
   Matches (not Pass) at the root is what binds children to parameters.
6. RETRACTED 2026-09-10: the "no USDS venue" claim was an artifact of calling
   a QuoterV1 signature against QuoterV2. USDS is acquired via the Sky
   DaiUsds converter `0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A`
   (`daiToUsds`, 1:1).
7. RETRACTED 2026-09-10: the provider's single-condition earn deposit entry
   is correct — a Matches root with fewer children than parameters legally
   leaves trailing parameters (referral, proof) unconstrained
   (`ReviewProbe.test_FX7`). The kit now matches the provider exactly; its
   earlier avatar-pinning of the referral parameter was a divergence.
8. **DAI-quirk** in scripts: typed `transfer` calls revert on DAI (no bool
   return); low-level calls required.

## Status

`forge test` green on the pinned fork: **21/21** across four suites (drills,
review probes, bootstrap, policy shape). The mainnet `just dry-run` path is
one command with a funded throwaway EOA (~0.05 ETH) and has not been run.
Required before provider-facing conclusions: apply the provider's own
constellation with its toolchain and diff the on-chain condition trees
against this kit
