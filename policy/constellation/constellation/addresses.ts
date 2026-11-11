// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the provider's governance actors are
// replaced by the contracts of the launch scope and a deployment manifest.
// See PROVENANCE.md.
// Changed for Clutch on 2026-10-09: the withdrawal queue left the scope
// (ADR 007, decision 27).
// Changed for Clutch on 2026-10-13: the Emergency Brakes multisig holds no
// role in the policy (ADR 005, decision 23).
// Changed for Clutch on 2026-10-14: the committee's own Safe holds the
// operator role (ADR 005, decision 31).
// Changed for Clutch on 2026-11-07: the orders account, its modifier and CoW's
// contracts (ADR 007).
// Changed for Clutch on 2026-11-08: the universal factory holds the motion
// roles in place of Easy Track's script executor (ADR 013, decision 18).
// Changed for Clutch on 2026-11-11: the first-loss modifier (ADR 008).
import { readFileSync } from "node:fs";

/**
 * The deployment: the Aragon Agent, the Asset Safe, the two modifiers and the
 * role holders. These addresses differ between the fork fixture and mainnet,
 * so they come from the manifest that `CLUTCH_MANIFEST` names. The compiler
 * sets the variable. Set it yourself for `inspect` or `push`.
 */
export type Manifest = {
  network: string;
  chainId: number;
  /** The Aragon Agent, or the mock that stands in for it on a fork. */
  agent: string;
  /** The Asset Safe: it holds the assets and owns both modifiers (ADR 005). */
  assetSafe: string;
  /** The modifier with the `operator` and `governance` roles. */
  operatorModifier: string;
  /** The modifier with the `emergency` role. */
  safetyModifier: string;
  /**
   * Every module that the Asset Safe enables, both modifiers included. The
   * governance role refuses each of them as an administered target, and the
   * compiler refuses a manifest that misses a compiled modifier (OD-38). A DAO
   * vote that enables another module lists it here and applies the policy
   * compiled again.
   */
  modules: string[];
  /** The holder of the operator role: the committee's own Safe, 4 of 7 (ADR 005, decision 31). */
  operatorSafe: string;
  /**
   * The emergency Safe, 3 of 5: two committee members, two Emergency Brakes
   * members and one member of neither body.
   */
  emergencySafe: string;
  /**
   * The universal factory, which holds the motion roles: governance, restart, insurance funding, exit governance,
   * and the orders modifier's governance and approvals. An enacted motion's one call makes its writes as these
   * roles (ADR 013, decision 18). The kit, which has no universal factory, names its mock script executor.
   */
  universalFactory: string;
  /** The first-loss Safe: the only receiver of insurance money (ADR 014, decision 7). */
  firstLossSafe: string;
  /**
   * The orders account: the Safe that owns the vault's CoW orders (ADR 007, decisions 17 and 28). The
   * operator funds it by transfers pinned to it, and the emergency role may send it assets for recovery orders.
   */
  ordersAccount: string;
  /**
   * The orders account's one modifier, with the operator and emergency roles (ADR 007, decision 30). The kit
   * deploys no orders account, so its manifest names none, and the orders policy compiles only where it does.
   */
  ordersModifier?: string;
  /**
   * The first-loss Safe's one modifier, with the `first-loss` and `first-loss-burn` roles (ADR 008, decisions 21
   * and 23). The kit deploys no first-loss Safe, so its manifest names none, and the first-loss policy compiles
   * only where it does.
   */
  firstLossModifier?: string;
};

/** The addresses that permissions pin: each must be in the manifest. */
const PINNED = [
  "agent",
  "assetSafe",
  "operatorModifier",
  "safetyModifier",
  "operatorSafe",
  "emergencySafe",
  "universalFactory",
  "firstLossSafe",
  "ordersAccount",
] as const;

/**
 * Refuses a manifest that misses an address that a permission pins. A missing one would not fail later: the
 * helpers leave an undefined parameter open, so a transfer pinned to it would pay any address.
 */
export function checkManifest(m: Record<string, unknown>) {
  const isAddress = (v: unknown) => typeof v === "string" && /^0x[0-9a-fA-F]{40}$/.test(v);
  for (const field of PINNED) {
    if (!isAddress(m[field])) throw new Error(`the manifest must name ${field} as an address: a permission pins it`);
  }
  if (m.ordersModifier !== undefined && !isAddress(m.ordersModifier)) {
    throw new Error("the manifest's ordersModifier must be an address");
  }
  if (m.firstLossModifier !== undefined && !isAddress(m.firstLossModifier)) {
    throw new Error("the manifest's firstLossModifier must be an address");
  }
}

const manifestPath = process.env.CLUTCH_MANIFEST;
if (!manifestPath) throw new Error("Set CLUTCH_MANIFEST to a manifest, such as manifests/fork-25946643.json.");
export const manifest: Manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
checkManifest(manifest);

/** Mainnet contracts that the policy names. The fork tests read each at block 25946643. */
export const STETH = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
export const WSTETH = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
export const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
export const LDO = "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32";
export const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
export const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
export const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
export const USDS = "0xdC035D45d973E3EC169d2276DDab16f1e407384F";
export const SUSDS = "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD";
/** Sky's DAI–USDS converter (OD-22). */
export const DAI_USDS = "0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A";
/** Lido earnUSD: the USDC deposit queue, the redeem queue and the share token. */
export const EARN_USD = {
  depositQueue: "0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76",
  redeemQueue: "0x9e36A74FE278906a76e7615263e46a83fC40c47F",
  share: "0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981",
};
/** Lido earnETH: the wstETH deposit queue, the redeem queue and the share token. */
export const EARN_ETH = {
  depositQueue: "0xe39EED9A454C4918F8d0682062777cB251cd513F",
  redeemQueue: "0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4",
  share: "0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4",
};

/**
 * CoW Protocol's deployed contracts that the orders policy names (ADR 007; research note of 2026-10-06). The
 * order signer runs only by delegatecall, so the Safe that calls it owns the order (OD-96).
 */
export const COW_SETTLEMENT = "0x9008D19f58AAbD9eD0D60971565AA8510560ab41";
export const COW_VAULT_RELAYER = "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110";
export const ORDER_SIGNER = "0x23dA9AdE38E4477b23770DeD512fD37b12381FAB";
export const COMPOSABLE_COW = "0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74";
export const TWAP_HANDLER = "0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5";
export const TIMESTAMP_FACTORY = "0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc";

/** Names for the artifact, so that a reviewer reads `stETH` and not an address. */
export const NAMES: Record<string, string> = {
  [STETH]: "stETH",
  [WSTETH]: "wstETH",
  [WETH]: "WETH",
  [LDO]: "LDO",
  [USDC]: "USDC",
  [USDT]: "USDT",
  [DAI]: "DAI",
  [USDS]: "USDS",
  [SUSDS]: "sUSDS",
  [DAI_USDS]: "DAI–USDS converter",
  [EARN_USD.depositQueue]: "earnUSD USDC deposit queue",
  [EARN_USD.redeemQueue]: "earnUSD redeem queue",
  [EARN_USD.share]: "earnUSD share",
  [EARN_ETH.depositQueue]: "earnETH wstETH deposit queue",
  [EARN_ETH.redeemQueue]: "earnETH redeem queue",
  [EARN_ETH.share]: "earnETH share",
  [manifest.agent]: "Aragon Agent",
  [manifest.assetSafe]: "Asset Safe",
  [manifest.operatorModifier]: "operator modifier",
  [manifest.safetyModifier]: "safety modifier",
  [manifest.operatorSafe]: "committee's Safe",
  [manifest.emergencySafe]: "emergency Safe",
  [manifest.universalFactory]: "universal factory",
  [manifest.firstLossSafe]: "first-loss Safe",
  [manifest.ordersAccount]: "orders account",
  ...(manifest.ordersModifier ? { [manifest.ordersModifier]: "orders modifier" } : {}),
  ...(manifest.firstLossModifier ? { [manifest.firstLossModifier]: "first-loss modifier" } : {}),
  [COW_SETTLEMENT]: "CoW settlement",
  [COW_VAULT_RELAYER]: "CoW vault relayer",
  [ORDER_SIGNER]: "CoW order signer",
  [COMPOSABLE_COW]: "ComposableCoW",
  [TWAP_HANDLER]: "CoW TWAP handler",
  [TIMESTAMP_FACTORY]: "CoW current-timestamp factory",
};
