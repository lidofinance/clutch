// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the provider's governance actors are
// replaced by the contracts of the launch scope and a deployment manifest.
// See PROVENANCE.md.
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
  /** The modifier with the `emergency` and `technical` roles. */
  safetyModifier: string;
  /**
   * Every module that the Asset Safe enables, both modifiers included. The
   * governance role refuses each of them as an administered target, and the
   * compiler refuses a manifest that misses a compiled modifier (OD-38). A DAO
   * vote that enables another module lists it here and applies the policy
   * compiled again.
   */
  modules: string[];
  /** The operator Safe: the committee's signers, 4 of 7, with the screening guard. */
  operatorSafe: string;
  /** The emergency Safe: the committee's signers, 2 of 7. */
  emergencySafe: string;
  /** The Emergency Brakes multisig, which holds the technical role. */
  emergencyBrakes: string;
  /** The Easy Track script executor, which holds the governance role. */
  easyTrackExecutor: string;
};

const manifestPath = process.env.CLUTCH_MANIFEST;
if (!manifestPath) throw new Error("Set CLUTCH_MANIFEST to a manifest, such as manifests/fork-25946643.json.");
export const manifest: Manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

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
/** Lido's withdrawal queue (OD-20, OD-27). */
export const WITHDRAWAL_QUEUE = "0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1";
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
  [WITHDRAWAL_QUEUE]: "Lido withdrawal queue",
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
  [manifest.operatorSafe]: "operator Safe",
  [manifest.emergencySafe]: "emergency Safe",
  [manifest.emergencyBrakes]: "Emergency Brakes multisig",
  [manifest.easyTrackExecutor]: "Easy Track script executor",
};
