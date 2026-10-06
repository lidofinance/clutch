import { encodeKey } from "@zodiaceco/sdk";
import config from "../../../zodiac.config";
import { assetSafeNode, treasuryRolesNode } from "../../nodes";
import { ARAGON_AGENT, COW_VAULT_RELAYER } from "../../addresses";

const {
  steth,
  wsteth,
  ldo,
  usdc,
  usdt,
  dai,
  sdai,
  usds,
  susds,
  aave_v3,
  lido_earn,
} = config.contracts.eth;

const { earneth, earnusd } = lido_earn;

/**
 * What the Emergency Brakes multisig may do, within hours and without a
 * governance motion: cut approvals, unwind positions, narrow the operator, and
 * send what it recovers to the DAO.
 *
 * The RFP's constraints on this role all hold by omission:
 *
 * - It cannot widen permissions. The only calls it holds on the modifier are
 *   `revokeTarget` and `revokeFunction`, the revoke-only half of its admin
 *   surface, with `roleKey` pinned to the operator. They work because the Safe
 *   owns the modifier and a call through a role executes as the Safe.
 * - It cannot enter a protocol. No `supply`, no vault `deposit`, no non-zero
 *   `approve` appears below.
 * - It cannot create debt. No `borrow`, as for the operator.
 * - It cannot change the recovery destination. Every `transfer` pins the
 *   recipient to `ARAGON_AGENT` as a literal, so the destination is fixed at
 *   the permission level rather than chosen at call time.
 */

/** Every spender the operator role can approve. Revoking is the first move in
 * the emergency flow, so this list must stay in step with that role. */
const APPROVED_SPENDERS = [
  aave_v3.pool,
  sdai,
  susds,
  wsteth,
  earnusd.deposit_queue_usdc,
  earneth.deposit_queue_wsteth,
  COW_VAULT_RELAYER,
] as const;

const revokeApprovals = [
  allow.eth.steth.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
  allow.eth.wsteth.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
  allow.eth.usdc.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
  allow.eth.usdt.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
  allow.eth.dai.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
  allow.eth.usds.approve(c.or(...APPROVED_SPENDERS), c.eq(0)),
];

/** Assets the recovered position ends up denominated in, all of which may be
 * returned to the DAO. LDO is included because the Asset Safe can hold it, not
 * because a position unwinds into it. */
const returnToTreasury = [
  allow.eth.steth.transfer(ARAGON_AGENT),
  allow.eth.wsteth.transfer(ARAGON_AGENT),
  allow.eth.ldo.transfer(ARAGON_AGENT),
  allow.eth.usdc.transfer(ARAGON_AGENT),
  allow.eth.usdt.transfer(ARAGON_AGENT),
  allow.eth.dai.transfer(ARAGON_AGENT),
  allow.eth.sdai.transfer(ARAGON_AGENT),
  allow.eth.usds.transfer(ARAGON_AGENT),
  allow.eth.susds.transfer(ARAGON_AGENT),
  allow.eth.lido_earn.earnusd.share.transfer(ARAGON_AGENT),
  allow.eth.lido_earn.earneth.share.transfer(ARAGON_AGENT),

  // Aave receipts. `withdraw` reverts when a reserve has no liquidity, and
  // that is exactly when an exit matters most; the aToken stays transferable,
  // so the DAO's claim can move to the Agent and be withdrawn once liquidity
  // returns. Every other position token is already covered above.
  allow.eth.aave_v3.atoken_usdc.transfer(ARAGON_AGENT),
  allow.eth.aave_v3.atoken_usdt.transfer(ARAGON_AGENT),
  allow.eth.aave_v3.atoken_dai.transfer(ARAGON_AGENT),
  allow.eth.aave_v3.atoken_usds.transfer(ARAGON_AGENT),
  allow.eth.aave_v3.atoken_wsteth.transfer(ARAGON_AGENT),
];

/**
 * Cutting the operator off, which the RFP's emergency flow opens with and
 * leaves the mechanism of open.
 *
 * These name nodes this same push creates, which works because the Safe owns
 * the modifier: a call through a role executes as the Safe, so the modifier
 * accepts it from its owner. `revokeTarget` and `revokeFunction` are the whole
 * revoking half of that admin surface, with no widening counterpart among them,
 * so this scope can only narrow. `roleKey` is pinned so it narrows the operator
 * and not the role holding it.
 */
const blockTheOperator = [
  // Built from the typed `allow` kit against the mastercopy each account runs
  // as a proxy, then pointed at the node: the kit is keyed by address and these
  // two have none until they deploy.
  {
    ...allow.eth.zodiac.roles_mastercopy.revokeTarget(encodeKey("operator")),
    targetAddress: treasuryRolesNode,
  },
  {
    ...allow.eth.zodiac.roles_mastercopy.revokeFunction(encodeKey("operator")),
    targetAddress: treasuryRolesNode,
  },
  {
    // A Safe administers itself through its own module, so this turns the
    // policy off wholesale and leaves the assets under the Agent alone.
    //
    // Both parameters are left open. Pinning `module` would mean putting a node
    // reference inside a condition's compValue, which is resolved for a
    // permission's target but not there. The Asset Safe has exactly one module
    // today, so the scope is the same; if a second is ever enabled, this should
    // be pinned to an address by then.
    ...allow.eth.zodiac.safe_mastercopy.disableModule(),
    targetAddress: assetSafeNode,
  },
] satisfies Permissions;

export default [
  ...revokeApprovals,

  // ── Exit positions ──────────────────────────────────────────────────────
  // Withdrawal targets are pinned to the avatar: recovered assets land back in
  // the Asset Safe first, and only then move to the DAO through the transfers
  // below. That keeps the two steps separately auditable.
  allow.eth.aave_v3.pool.withdraw(
    c.or(usdc, usdt, dai, usds, wsteth),
    undefined,
    c.avatar,
  ),

  allow.eth.sdai.redeem(undefined, c.avatar, c.avatar),
  allow.eth.susds.redeem(undefined, c.avatar, c.avatar),
  allow.eth.sdai.withdraw(undefined, c.avatar, c.avatar),
  allow.eth.susds.withdraw(undefined, c.avatar, c.avatar),

  // Lido Earn redemptions settle asynchronously, so an exit is `redeem` now and
  // `claim` once the batch is handled — the emergency role needs both halves or
  // it can start an exit it cannot finish.
  allow.eth.lido_earn.earnusd.redeem_queue.redeem(),
  allow.eth.lido_earn.earnusd.redeem_queue.claim(c.avatar),
  allow.eth.lido_earn.earneth.redeem_queue.redeem(),
  allow.eth.lido_earn.earneth.redeem_queue.claim(c.avatar),

  // An Earn deposit is cancelled while it is still pending. Once the oracle has
  // priced it, cancelling reverts and the shares are allocated but not yet
  // active, so claiming is the only way to reach a state `redeem` accepts.
  // Both legs are granted for both queues or the unwind stalls mid-settlement.
  allow.eth.lido_earn.earnusd.deposit_queue_usdc.cancelDepositRequest(),
  allow.eth.lido_earn.earnusd.deposit_queue_usdc.claim(c.avatar),
  allow.eth.lido_earn.earneth.deposit_queue_wsteth.cancelDepositRequest(),
  allow.eth.lido_earn.earneth.deposit_queue_wsteth.claim(c.avatar),

  // wstETH unwraps to stETH, which is liquid. Wrapping is not granted: it is a
  // position change, not an exit.
  allow.eth.wsteth.unwrap(),

  ...blockTheOperator,

  ...returnToTreasury,
] satisfies Permissions;
