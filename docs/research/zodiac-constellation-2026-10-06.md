---
type: Research Note
title: The Zodiac constellation as the policy backbone, 2026-10-06
description: OD-33 and OD-34 evidence on upstream policy, local and hosted tooling, design differences and required Clutch work.
tags: [policy, zodiac, constellation, toolchain, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-06
stale_after: 2026-12-31T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-11T11:50:32Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/gnosisguild/lido-atm-constellation/tree/02ea37d44efb324a7be395726618d5e76da490bc"
    title: The policy provider's constellation at 02ea37d — the copied configuration
  - id: s2
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/README.md#L186-L200"
    title: The provider's README at 02ea37d — the rollout, and the hand-off to an LDO vote or an Easy Track motion, which is still to be agreed
  - id: s3
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/constellation/addresses.ts#L6-L21"
    title: The provider's addresses at 02ea37d — the claim that Easy Track motions execute as the Agent
  - id: s4
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/constellation/roles/emergency/permissions.ts#L100-L124"
    title: The provider's emergency permissions at 02ea37d — revoke calls on the modifier, and disableModule with both parameters open
  - id: s5
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/CLAUDE.md#L58-L60"
    title: The provider's agent notes at 02ea37d — a node reference does not resolve inside a condition's compValue
  - id: s6
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/.lib/constellation.ts#L5-L9"
    title: The provider's codegen stub at 02ea37d — no accounts key
  - id: s7
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/index.mjs"
    title: "@zodiaceco/sdk 2.1.2 — push() sends entries as written, and the hosted app compiles them at deploy"
  - id: s8
    resource: "https://unpkg.com/@zodiaceco/sdk@2.1.2/dist/api-C49DoaPC.mjs"
    title: "@zodiaceco/sdk 2.1.2 — the API client: app.zodiac.eco/api/v1, a bearer ZODIAC_API_KEY, constellation/apply and constellation/resolve"
  - id: s9
    resource: "https://unpkg.com/@zodiaceco/api-types@1.12.0/dist/index.d.mts"
    title: "@zodiaceco/api-types 1.12.0 — the SAFE node fields, with no Safe version, guard or fallback handler"
  - id: s10
    resource: "https://unpkg.com/zodiac-roles-sdk@4.1.3/build/index-BAWTMWsX.d.mts"
    title: zodiac-roles-sdk 4.1.3 — the exports, the Operator enum without Nor, and fetchLicense
  - id: s11
    resource: "https://unpkg.com/zodiac-roles-sdk@4.1.3/build/main-DiBlmCWg.mjs"
    title: zodiac-roles-sdk 4.1.3 — the condition kit, postRole to the roles app, and fetchLicense from app.zodiac.eco
  - id: s12
    resource: "https://registry.npmjs.org/@zodiaceco/sdk"
    title: npm registry — @zodiaceco/sdk versions; 2.4.1 published on 2026-10-01
  - id: s13
    resource: "https://registry.npmjs.org/defi-kit/2.26.13"
    title: npm registry — defi-kit 2.26.13 has no licence field
  - id: s14
    resource: "https://github.com/lidofinance/clutch/blob/3bb5c065f6faf641cf9be087e190796fcd3e21e9/src/policy/Policy.sol#L258-L289"
    title: Kit policy at 3bb5c06 — the approval builder with one Matches branch per spender, and staking with ETH attached
  - id: s15
    resource: "https://github.com/lidofinance/clutch/blob/3bb5c065f6faf641cf9be087e190796fcd3e21e9/src/policy/Policy.sol#L463-L482"
    title: Kit policy at 3bb5c06 — the governance guard, with Nor over the modifier and the Safe
  - id: s16
    resource: "https://github.com/lidofinance/clutch/blob/3bb5c065f6faf641cf9be087e190796fcd3e21e9/src/interfaces/IRoles.sol#L9-L18"
    title: Kit interface at 3bb5c06 — the deployed mastercopy's enum values
  - id: s20
    resource: /adr/001-repository-scope-visibility-licence-name.md
    title: ADR 001 — the licence
  - id: s21
    resource: /registers/decision-log.md
    title: Decision log — EM's request of 2026-10-06, and the decisions behind the design
  - id: s22
    resource: "https://etherscan.io/block/26131786"
    title: Ethereum block 26131786, used for every chain read on this page
  - id: s23
    resource: /research/chain-reads-2026-09-30.md
    title: Chain reads of 2026-09-30 — the Easy Track executor's roles on the Agent, and the Safe versions
  - id: s24
    resource: "https://www.gnu.org/licenses/lgpl-3.0.html"
    title: GNU Lesser General Public License, version 3 — it adds permissions to the GNU GPL, version 3
  - id: s25
    resource: "https://github.com/gnosisguild/lido-atm-constellation/blob/02ea37d44efb324a7be395726618d5e76da490bc/README.md#L6-L7"
    title: The provider's README at 02ea37d — the graph is pushed to Zodiac, which diffs it against on-chain state and produces the transactions to sign
  - id: s27
    resource: "https://etherscan.io/address/0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5#code"
    title: The Roles mastercopy — its runtime code, read at block 26131786
---

# The Zodiac constellation as the policy backbone, 2026-10-06

EM asked on 2026-10-06 whether the policy provider's constellation still works, and whether Clutch can use the Zodiac constellation as its backbone [s21]. An agent copied the configuration to `policy/constellation/`, with a [provenance file](../../policy/constellation/PROVENANCE.md), and ran every check on this page on 2026-10-06.

- Chain reads use Ethereum mainnet block 26131786, hash `0x22e6cb309fad7adf163199b287ff30017a7aeabc9e350a6155eaa1d25d7a2707`, time 2026-10-06T07:16:35Z [s22].
- Package checks use bun 1.3.0 and the upstream lockfile: `@zodiaceco/sdk` 2.1.2, `@zodiaceco/api-types` 1.9.0, `zodiac-roles-sdk` 4.1.3 and `defi-kit` 2.26.13. A scratch install repeats the build with the newest releases, `@zodiaceco/sdk` 2.4.1 and `@zodiaceco/api-types` 1.12.0 [s12].
- No check called the hosted app. The push capture below replaces the API client with a local function.

## Answer

- **The configuration still builds after a one-line fix, and the addresses that the agent checked still match the chain.** Without the fix, the offline build stops. Its comment on Easy Track is false (section 1).
- **It does not match the Clutch design.** The roles, the role holders, the protocols, the approval rule and the governance path all differ (section 4). The change is a rewrite of `constellation/`, not an edit.
- **Clutch can use the constellation as the source of the policy.** A probe compiled three of the kit's condition shapes to the same flat condition arrays (section 3). The constellation describes Safes, modifiers, roles, permissions and allowances only [s9].
- **Clutch cannot use the hosted path as it is.** The hosted app compiles some entries, builds the transactions and compares the specification with the chain. That path needs an API key and has no hand-off to an Aragon vote or an Easy Track motion. Its Safe node cannot set the Safe version, a guard or the fallback handler (section 2).
- **Two decisions followed** on 2026-10-06: OD-33 ([ADR 004](/adr/004-specifications-and-policy-as-data.md) decisions 10 to 15) and OD-34, the ADR 001 exception for the copied LGPL-3.0-only files.

## 1. Does the configuration still work?

### The build

| Check | Result |
|---|---|
| `bun .lib/scripts/inspect.ts` with the lockfile (SDK 2.1.2) | Stops with `TypeError: undefined is not an object (evaluating 'codegen.accounts[opts.workspace]')`. The empty codegen stub has no `accounts` key [s6]. |
| The same with SDK 2.4.1 | The same error. `package.json` allows `^2.1.2`, so an install without the lockfile gets 2.4.1. |
| The same after the fix, `accounts: {}` in the stub | Runs on both versions. It prints two nodes, `asset_safe` and `treasury_roles`. |
| The push payload, 2.1.2 against 2.4.1 | The same, except that 2.4.1 writes `send: false` and `delegatecall: false` on each entry. |
| `bun pull-org`, `bun push` | Not run. Both need `ZODIAC_API_KEY` and the hosted app [s8]. |

### The chain

```sh
B=26131786
cast call 0x41675C099F32341bf84BFc5382aF534df5C7461a 'VERSION()(string)' --block $B
for Q in <the six Earn queues in zodiac.config.ts>; do
  V=$(cast call $Q 'vault()(address)' --block $B)
  cast call $V 'hasQueue(address)(bool)' $Q --block $B
  cast call $V 'isPausedQueue(address)(bool)' $Q --block $B
  cast call $V 'isDepositQueue(address)(bool)' $Q --block $B
done
cast call <vault> 'shareManager()(address)' --block $B
cast call 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 'getReserveAToken(address)(address)' <asset> --block $B
cast call <Safe> 'getThreshold()(uint256)' --block $B; cast call <Safe> 'getOwners()(address[])' --block $B
cast call 0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb 'hasPermission(address,address,bytes32)(bool)' \
  0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c $(cast keccak RUN_SCRIPT_ROLE) --block $B
```

| Item in the configuration | Result at block 26131786 |
|---|---|
| earnETH queues: ETH, WETH and wstETH deposit, and redeem | All four are queues of vault `0x6a37725ca7f4CE81c004c955f7280d5C704a249e`. None is paused. |
| earnUSD queues: USDC deposit, and redeem | Both are queues of vault `0x014e6DA8F283C4aF65B2AA0f201438680A004452`. Neither is paused. |
| earnETH and earnUSD share tokens | Each equals its vault's `shareManager()`. |
| Aave v3 Core aTokens for USDC, USDT, DAI, USDS and wstETH | Each equals the pool's `getReserveAToken`. |
| The committee's Safe `0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647` | 4 of 7, as the comment says. |
| The Emergency Brakes Safe `0x73b047fe6337183A454c5217241D780a932777bD` | 3 of 5, as the comment says. |
| The Safe singleton `0x41675C099F32341bf84BFc5382aF534df5C7461a` | `VERSION()` is `1.4.1`. Only v1.5.0 has the module guard setter [s23]. |
| "Easy Track motions execute *as* the Agent" [s3] | False. The Easy Track executor holds neither `RUN_SCRIPT_ROLE` nor `EXECUTE_ROLE` on the Agent, as on 2026-09-30 [s23]. |

The upstream head is still `02ea37d` of 2026-08-27. GitHub reports no later push.

The configuration is still valid for the proposal that it was written for, except for its governance path. An Easy Track motion cannot reach a Safe that only the Agent owns.

## 2. What runs locally and what only the hosted app runs

The capture replaced the API client of `push()` with a local function and wrote the payload to a file:

- The payload is one specification with a SAFE node and a ROLES node. Node references travel as `$asset_safe` and `$treasury_roles`.
- 32 of the 33 operator entries and all 39 emergency entries arrive as a target and a selector, with a condition tree where the entry has conditions. The `allow` kit and the `c` builders make these trees locally.
- The `swap` entry arrives as `{"action": {"type": "swap", "sell": [...], "buy": [...]}}`. The SDK states that entries "are compiled when the constellation is deployed", and that the hosted app fetches a DeFi Kit entry's permissions from an annotation URI at deploy [s7]. So the repository does not hold the permissions of these entries.
- The hosted app compares the specification with the chain and produces the transactions to sign [s25]. `push()` returns an id and a URL in the app [s7][s8].
- The API client needs `ZODIAC_API_KEY` and calls `https://app.zodiac.eco/api/v1` [s8]. `bun pull-org`, which fetches the workspace's users and accounts for the codegen, also needs the key. The CLI's login writes the key to `.env` in the project directory, which the copied `.gitignore` excludes.
- `zodiac-roles-sdk` 4.1.3 exports `processPermissions`, `flattenCondition` and `rolesAbi`. It exports no planner that turns a role into modifier calls [s10].
- `zodiac-roles-sdk` also exports `fetchLicense`, which reads a plan (`none`, `free`, `enterprise` or `blocked`) from the hosted app for an owner address, and `postRole`, which stores permissions in the roles app [s11]. The kit's fork tests apply and use the policy on the deployed mastercopy without a plan, so no plan gates the features that the kit uses on chain.
- `bun pull-contracts` fetches only missing ABIs, from `api.abi.pub`. The `allow` kit is built at run time from the committed `abis/` directory.

## 3. Can the constellation express the Clutch policy?

A probe built three of the kit's condition shapes with `zodiac-roles-sdk` 4.1.3 and flattened them. The agent compared each result with the kit's builder by reading the Solidity [s14][s15].

| Shape | Kit builder | Probe result |
|---|---|---|
| An approval with one branch per spender: `Or` at the root, then `Matches` of the spender and either `WithinAllowance(key)` or `LessThan(ceiling)` (OD-08) | `_opApprove` | The same 7 nodes in the same order, with the same parents, types and operators. The compValues have the same encoding; the key's value depends on how the key is named (see **Keys**). |
| Staking: `submit(referral)` with the referral pinned to zero, with ETH attached | `_stake`, `EXEC_SEND` | The same 2 nodes. `send: true` gives execution option 1. |
| The governance guard: role key equal to `operator`, target `Nor` over the modifier and the Safe | `_paGuard` | The same 5 nodes. The SDK accepts operator 3 only as a raw condition object. |

Other findings:

- **Operators.** The SDK's enum has the mastercopy's values for every operator that the kit uses, except `Nor`. `Nor`, `ArraySome` and `ArraySubset` are not in the SDK's enum or in its `c` builders [s10][s11][s16]. A raw condition with operator 3 passes `processPermissions` and `flattenCondition` unchanged.
- **Keys.** `encodeKey("operator")` is the text padded to 32 bytes, `0x6f70657261746f72…`. The kit uses `keccak256("operator")`. `c.withinAllowance` also encodes the text. The port must choose one form, because the tests and the runbooks name the keys.
- **Node references.** A node reference resolves as a target, an owner, an avatar or a module. It does not resolve inside a condition's compValue [s5]. That is why the provider left both parameters of `disableModule` open [s4]. The emergency role's switch pins the module ([ADR 005](/adr/005-account-graph-and-roles.md) decision 25), so the port needs the modifier's address as a literal.
- **The ABI.** The SDK's `rolesAbi` matches the deployed mastercopy. All 22 of its state-changing selectors are in the mastercopy's runtime code as `PUSH4` constants [s27]. They include `setUp(bytes)`, which the mastercopy uses instead of the newer `setUp(address,address,address)` [s16]. The topics of the policy events are in the code as `PUSH32` constants: `ScopeFunction`, `ScopeTarget`, `AllowTarget`, `AllowFunction`, `RevokeTarget`, `RevokeFunction`, `SetAllowance`, `ConsumeAllowance`, `AssignRoles` and `SetDefaultRole`. This check covers the signatures. It does not decode real events.
- **The Safe node.** Its fields are the chain, an optional address, the nonce, the ref, the threshold, the owners, the modules, the label and `vault` [s9]. No field sets the Safe version, a transaction guard, a module guard or the fallback handler. An existing Safe can be bound by address.

## 4. Differences from the decided design

ADR 005 to ADR 011 hold the decided design. This table records what the provider's constellation held [s1]:

| Area | Constellation at `02ea37d` |
|---|---|
| Modifiers | One, with `operator` and `emergency` [s1] |
| Operator holder | The committee's existing Safe [s1] |
| Emergency holder | The Emergency Brakes Safe [s1] |
| Module disabling | The emergency role holds `disableModule` with both parameters open [s4] |
| Governance | No role. It assumes that motions execute as the Agent, which is false (section 1) [s3] |
| Asset Safe | Agent-owned; `zodiac.config.ts` names the v1.4.1 singleton as its implementation; the Safe node cannot set the version, a guard or the fallback handler |
| Lending and savings | Aave v3 Core supply and withdraw, aToken transfers, and sDAI [s1] |
| Swaps | A CoW `swap` action over six sell and five buy tokens, with a TODO for bounds, compiled by the hosted app [s1] |
| DAI | No converter; DAI goes to Aave or sDAI [s1] |
| ETH and WETH | No permission for staking, WETH or the withdrawal queue |
| Approvals | Approvals pin the spender and leave the amount open; deposits spend six monthly budgets |
| Budgets | The provider's placeholder figures; no governance role, so no floor |
| Recovery | Transfers to the Agent only |
| First-loss Earn shares | Both roles can redeem Earn shares |
| LDO | Out of both sides of the swap |

## 5. What Clutch must build to use the constellation as the backbone

[ADR 004](/adr/004-specifications-and-policy-as-data.md) decisions 10 to 15 hold what Clutch builds. The evidence behind them, besides sections 2 and 3:

- **The hand-off.** The provider's README says that the provider "would like to agree how Zodiac should hand a permission change to an LDO vote or an Easy Track motion" [s2].
- **The toolchain.** The lockfile lists 182 packages. The npm package `defi-kit` 2.26.13, a dependency of the SDK, has no licence field [s13].
- **The licence.** The copied files are LGPL-3.0-only. ADR 001 allows AGPL-3.0-or-later and, for files derived from Easy Track, GPL-3.0 [s20]. LGPL-3.0 is the GNU GPL, version 3, with added permissions [s24], so the reasoning that ADR 001 uses for the Easy Track files also applies. This is the agent's reading, not a legal review (OD-34).

## Reproduce

```sh
git -C <clone> archive 02ea37d44efb324a7be395726618d5e76da490bc zodiac.config.ts constellation .lib abis \
  package.json bun.lock tsconfig.json LICENSE .gitignore .editorconfig .prettierignore | tar -x -C policy/constellation
cd policy/constellation && bun install --frozen-lockfile && bun .lib/scripts/inspect.ts
```

The ABI check, with `rolesAbi` printed as one selector or topic per line:

```sh
cast code 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5 --block 26131786 > roles.code
grep -ci "63<selector>" roles.code    # each state-changing function
grep -ci "7f<topic>" roles.code       # each event
```

The push capture, run from `policy/constellation/`:

```ts
import "./.lib/globals";
import { push } from "@zodiaceco/sdk";
const { default: _d, ...nodes } = (await import("./constellation/index.ts")) as any;
await push(nodes, { api: { applyConstellation: async (_ws: unknown, payload: unknown) => {
  await Bun.write("/tmp/push-payload.json", JSON.stringify(payload, null, 2));
  return { id: "local", url: "local" };
} } as any });
```

The probe builds each shape as a permission object and prints `flattenCondition(f.condition)` for each function that `processPermissions` returns. For example, the approval:

```ts
import { c, processPermissions, flattenCondition } from "zodiac-roles-sdk";
const { targets } = processPermissions([{ targetAddress: TOKEN, signature: "approve(address,uint256)",
  condition: c.or(
    c.calldataMatches([SPENDER_A, c.withinAllowance("k_a")], ["address", "uint256"]),
    c.calldataMatches([SPENDER_B, c.lt(10n)], ["address", "uint256"])) }]);
console.log(flattenCondition(targets[0].functions[0].condition!));
```
