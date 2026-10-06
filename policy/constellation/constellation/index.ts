import { ARAGON_AGENT } from "./addresses";
import { assetSafeNode, treasuryRolesNode } from "./nodes";
import { operator, emergency } from "./roles";
import {
  aave_supply_usdc_usdt,
  aave_supply_dai_usds,
  aave_supply_wsteth,
  sky_savings_dai_usds,
  earn_usd_deposit,
  earn_eth_deposit_wsteth,
} from "./allowances";

/**
 * Holds the allocated treasury assets and every protocol position. The Aragon
 * Agent is its only owner, which is what keeps the DAO's ownership independent
 * of any service: with a 1-of-1 owner set there is no signer whose absence can
 * block a DAO recovery action, and no provider in the path.
 *
 * The committee and the emergency signers are deliberately *not* owners. They
 * reach the assets only through the Roles modifier below, so their authority is
 * whatever the policy says and nothing more.
 */
export const asset_safe = assetSafeNode({
  nonce: 0n,
  threshold: 1,
  owners: [ARAGON_AGENT],
  modules: [treasuryRolesNode],
});

/**
 * The default-deny layer, owned by the Asset Safe it governs.
 *
 * Owning it from the Safe rather than from the Agent keeps every existing
 * authority intact: the Agent owns the Safe, so an LDO vote or an Easy Track
 * motion still reaches the policy one hop further along. It adds one thing the
 * Agent alone cannot give, which is that a role can be permissioned to call the
 * modifier's own admin functions. Calls made through a role execute as the avatar, which
 * is the Safe, which is the owner, so the modifier accepts them. That is the
 * mechanism behind the RFP's "block new operator transactions within hours":
 * scoped to the revoking half of the admin surface, the emergency role can
 * narrow the operator's permissions without a governance motion, while still
 * being unable to widen its own.
 *
 * Changing a role's members stays a Safe action and so stays with the Agent,
 * and so does re-enabling the module or re-granting what was revoked. Disabling
 * the module is deliberately granted to the emergency role as its kill switch;
 * neither role can widen its own scope or block its own removal.
 */
export const treasury_roles = treasuryRolesNode({
  nonce: 0n,
  owner: asset_safe,
  target: asset_safe,
  avatar: asset_safe,
  roles: { operator, emergency },
  allowances: {
    aave_supply_usdc_usdt,
    aave_supply_dai_usds,
    aave_supply_wsteth,
    sky_savings_dai_usds,
    earn_usd_deposit,
    earn_eth_deposit_wsteth,
  },
});
