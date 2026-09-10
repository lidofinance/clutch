# Lido ATM — mainnet dry-run kit (WS-M)

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
| `MockAragonAgent` | Aragon Agent 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c | `forward(address,bytes)` gated like RUN_SCRIPT_ROLE; sole owner (1/1) of the Asset Safe; EOA-controlled |
| `MockEVMScriptExecutor` | EVMScriptExecutor 0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977 | decodes the real Aragon CallsScript spec 0x00000001; executes chunks as itself; same calldata a production ET factory emits rehearses unchanged |
| `MockEasyTrack` | Easy Track 0xF0211b7660680B49De1A7E9f25C65660F0a13Fea | factory allowlist, LDO-weighted objections vs threshold, permissionless enactment, 72 h duration compressible for drills |
| `PassThroughEVMScriptFactory` | future Lido ET factories | passes a prebuilt script through — the shape-validation the real factories must do is WS-D work, deliberately not mocked here |

Owner-path execution uses the production two-step pattern
(`Agent → Safe.approveHash` then `execTransaction` with the v=1 owner signature).

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

- **D1** permission expansion via mock ET incl. objection-rejection
- **D2** the same change via the direct owner path, no ET
- **D3** operator lifecycle: Aave supply/withdraw (real pool), sDAI
  deposit/redeem, wstETH unwrap, CoW presign (uid.owner-enforced), LDO
  sell-leg approval (LDO sellable per interview B5/A5)
- **D3b** earn-deposit permission shape on the verified 3-param signature
- **D4** emergency: block operator via `revokeTarget`, approve-to-zero,
  avatar-pinned exits, return-to-Agent-only transfers; plus the **unpinned
  `disableModule`** demonstration (R3) and owner-path recovery
- **D5** budgets: consumption on execution, exhaustion revert, shared-key
  cross-token draw, refill after the period
- **D6** adversarial: operator cannot reach the admin surface or disable
  modules; emergency cannot widen or grant roles; unscoped spenders denied;
  the R1 unbounded-approval demo
- **Bootstrap** 0.5 ETH → stETH/wstETH/USDC/USDT/DAI/LDO/(USDS best-effort) →
  sDAI/sUSDS → Safe, with gas reserve preserved

## DD findings proven here (see notes/atm-* in the CTO KB)

1. **Proxy shape is load-bearing**: the deployed Roles v4 mastercopy keeps
   state from slot 0; deploying it behind a SafeProxy re-points the proxy at
   whatever `setUp` writes first (reproduced: recursion into the Safe). Zodiac's
   `ModuleProxyFactory` (EIP-1167-style) is required.
2. **`setUp(bytes)`**: the deployed mastercopy uses the FactoryFriendly
   signature, not the repo-HEAD `setUp(address,address,address)`.
3. **One scope per (role, target, selector)**: a second `scopeFunction`
   replaces the first entirely — provider/ET-factory widening must emit full
   replacement scopes, not additive grants.
4. **Per-asset budgets are not expressible**: logical-operator children keep
   the same evaluation scope, so the proposal's three separate Aave budgets
   cannot all bind `supply`; only one allowance key per selector position binds.
5. **EqualTo compValues are raw padded words** (the packer keccaks on store);
   Matches (not Pass) at the root is what binds children to parameters.
6. **No liquid WETH→USDS Uniswap venue** exists at any fee tier; production
   USDS acquisition needs a Sky PSM path or manual funding.
7. **Earn deposit signature is `deposit(uint224,address,bytes32[])`** — the
   constellation source passes a single amount condition; flagged for
   provider-side confirmation.
8. **DAI-quirk** in scripts: typed `transfer` calls revert on DAI (no bool
   return); low-level calls required.

## Status

Execution-ready. `forge test` green on the pinned fork (11/11). The mainnet
`just dry-run` path is one command with a funded throwaway EOA.
