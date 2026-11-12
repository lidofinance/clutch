// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * An example policy change for the tests of the `motion` command: the onboarding of an ERC-4626 lending vault,
 * with a larger Earn budget. No decision lists this vault or these figures. The committed example motion, which
 * the fork suite enacts through the live Easy Track, is built from this change.
 */
import { AbiCoder, id } from "ethers";
import type { Artifact } from "./compile";

/** A deployed ERC-4626 vault of WETH on mainnet, a stand-in for the lender vault of Lido Lend's WETH market. */
export const EXAMPLE_VAULT = "0x2371e134e3455e0593363cBF89d3b6cf53740618";
export const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const SUSDS = "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD";
const EARN_USD_SHARE_NAME = "earnUSD share";
/** The example's budgets, in token units. */
export const EXAMPLE_WETH_BUDGET = 50n * 10n ** 18n;
export const EXAMPLE_EARN_USD_BUDGET = 400_000n * 10n ** 6n;
const MONTH = 30n * 24n * 60n * 60n;

const lower = (value: string) => value.toLowerCase();
const selector = (signature: string) => id(signature).slice(0, 10) as `0x${string}`;

/** The derived budget key of a spender and a token: "k:", the spender, the token's first ten bytes (ADR 013, decision 9). */
export function derivedKey(token: string, spender: string): `0x${string}` {
  return `0x6b3a${lower(spender).slice(2)}${lower(token).slice(2, 22)}`;
}

/** The example fund's token, payout address and cap. Stand-ins: no decision lists them. */
export const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
export const FUND_PAYOUT = "0x000000000000000000000000000000000000F00D";
export const FUND_CAP = 30_000n * 10n ** 6n;

/**
 * The policy `base` with a fund that has a fixed payout address (ADR 014, decision 6): the insurance role's
 * transfer of the token, pinned to the payout address, and the cap as a budget that never refills. Its maximum
 * refill and its timestamp are zero in the policy; the modifier stores other values in their place.
 */
export function exampleFund(base: Artifact): Artifact {
  const head = JSON.parse(JSON.stringify(base)) as Artifact;
  const modifier = head.modifiers.find((m) => m.ref === "first_loss_modifier")!;
  const key = derivedKey(USDT, FUND_PAYOUT);
  modifier.allowances.push({ name: "fund_usdt_example", key, balance: String(FUND_CAP), maxRefill: "0", refill: "0", period: "0", timestamp: "0" });
  const payout: { parent: number; paramType: number; operator: number; compValue: `0x${string}` }[] = [
    { parent: 0, paramType: 5, operator: 5, compValue: "0x" },
    { parent: 0, paramType: 1, operator: 16, compValue: AbiCoder.defaultAbiCoder().encode(["address"], [FUND_PAYOUT]) as `0x${string}` },
    { parent: 0, paramType: 1, operator: 28, compValue: key },
  ];
  modifier.roles
    .find((r) => r.name === "insurance")!
    .targets.push({ address: USDT, name: "USDT", clearance: 2, executionOptions: 0, functions: [{ selector: selector("transfer(address,uint256)"), signature: "transfer(address,uint256)", executionOptions: 0, wildcarded: false, conditions: payout }] });
  return head;
}

/** The policy `base` with the example change applied. */
export function exampleHead(base: Artifact): Artifact {
  const head = JSON.parse(JSON.stringify(base)) as Artifact;
  const modifier = (ref: string) => head.modifiers.find((m) => m.ref === ref)!;
  const role = (ref: string, name: string) => modifier(ref).roles.find((r) => r.name === name)!;
  const clone = <T>(value: T) => JSON.parse(JSON.stringify(value)) as T;
  const key = derivedKey(WETH, EXAMPLE_VAULT);

  // budgets: a larger Earn budget, and a budget for the new spender under its derived key
  const operatorModifier = modifier("operator_modifier");
  const earn = operatorModifier.allowances.find((a) => a.name === "earn_usd_deposit")!;
  earn.balance = earn.maxRefill = earn.refill = String(EXAMPLE_EARN_USD_BUDGET);
  const budget = String(EXAMPLE_WETH_BUDGET);
  operatorModifier.allowances.push({ name: "weth_to_example_vault", key, balance: budget, maxRefill: budget, refill: budget, period: String(MONTH), timestamp: "0" });

  // the operator: the WETH approval under the new key, and the vault's functions in sUSDS's form,
  // with the receiver and the owner pinned to the avatar
  const operator = role("operator_modifier", "operator");
  const approve: { parent: number; paramType: number; operator: number; compValue: `0x${string}` }[] = [
    { parent: 0, paramType: 5, operator: 5, compValue: "0x" },
    { parent: 0, paramType: 1, operator: 16, compValue: AbiCoder.defaultAbiCoder().encode(["address"], [EXAMPLE_VAULT]) as `0x${string}` },
    { parent: 0, paramType: 1, operator: 28, compValue: key },
  ];
  operator.targets
    .find((t) => lower(t.address) === lower(WETH))!
    .functions.push({ selector: selector("approve(address,uint256)"), signature: "approve(address,uint256)", executionOptions: 0, wildcarded: false, conditions: approve });
  const savings = operator.targets.find((t) => lower(t.address) === lower(SUSDS))!;
  operator.targets.push({ address: EXAMPLE_VAULT, name: "example ERC-4626 vault", clearance: 2, executionOptions: 0, functions: clone(savings.functions) });

  // the emergency role: the vault's redeem in sUSDS's form, and a transfer of its shares to the Aragon Agent
  const emergency = role("safety_modifier", "emergency");
  const redeem = emergency.targets.find((t) => lower(t.address) === lower(SUSDS))!.functions.find((f) => f.signature === "redeem(uint256,address,address)")!;
  const toAgent = emergency.targets.find((t) => t.name === EARN_USD_SHARE_NAME)!.functions.find((f) => f.signature === "transfer(address,uint256)")!;
  emergency.targets.push({ address: EXAMPLE_VAULT, name: "example ERC-4626 vault", clearance: 2, executionOptions: 0, functions: [clone(redeem), clone(toAgent)] });
  return head;
}
