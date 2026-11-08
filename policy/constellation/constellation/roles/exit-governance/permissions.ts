// SPDX-License-Identifier: AGPL-3.0-or-later
import { id } from "ethers";
import { anyOf, call, flatTree, key } from "../../lib";
import { EARN_USD, manifest, SUSDS, USDC } from "../../addresses";
import { NOT_ADMINISTRATION } from "../../administration";
import {
  PLAIN_EXITS,
  queueClaim,
  queueClaimRequests,
  toAgent,
  toAgentOrOrders,
  vaultRedeem,
  vaultWithdraw,
  zeroApproval,
} from "../../exits";

const MODIFIER = manifest.safetyModifier;
const EMERGENCY = key("emergency");

const selector = (signature: string) => id(signature).slice(0, 10);
const TRANSFER = selector("transfer(address,uint256)");
const APPROVE = selector("approve(address,uint256)");
const VAULT_EXITS = ["redeem(uint256,address,address)", "withdraw(uint256,address,address)"].map(selector);
const CLAIMS = ["claim(address)", "claim(address,uint32[])"].map(selector);

const SCOPE_TARGET = "scopeTarget(bytes32,address)";
const SCOPE_FUNCTION = "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)";
const ALLOW_FUNCTION = "allowFunction(bytes32,address,bytes4,uint8)";

/** Every exit is a plain call: no Send and no delegatecall. */
const CALL = 0n;

/**
 * The exit trees, pinned whole. None depends on its target: the emergency role's own permissions for the launch
 * venues compile to the same trees, from the same builders. A redeem and a withdrawal share one tree, and so do the
 * two claims; the check below keeps that true.
 */
const TO_AGENT = flatTree(toAgent(USDC));
const TO_AGENT_OR_ORDERS = flatTree(toAgentOrOrders(USDC));
const ZERO = flatTree(zeroApproval(USDC));
const VAULT_EXIT = flatTree(vaultRedeem(SUSDS));
const CLAIM = flatTree(queueClaim(EARN_USD.depositQueue));
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
if (!same(VAULT_EXIT, flatTree(vaultWithdraw(SUSDS))) || !same(CLAIM, flatTree(queueClaimRequests(EARN_USD.redeemQueue)))) {
  throw new Error("the exit-governance role pins one tree for two exits that no longer share it");
}

/**
 * What an enacted Easy Track motion may do, as the exit-governance role on the safety modifier (ADR 006, decision
 * 13; OD-49): write the emergency role's exit for a target that the motion names, and nothing else. The exits are
 * the emergency role's own kinds, each tree pinned whole:
 *
 * - a transfer to the Aragon Agent, or to the Agent or the orders account for a token that a recovery order sells
 *   (ADR 007, decisions 19 and 45);
 * - an approval set to zero, for any spender;
 * - an ERC-4626 redeem or withdrawal from the Asset Safe's own shares, paid to the Asset Safe;
 * - a queue's claim, paid to the Asset Safe;
 * - without conditions, only the exits that act for the calling Safe alone: cancel a pending deposit, ask a redeem
 *   queue to redeem, and unwrap.
 *
 * Every grant writes under the emergency key only, as a plain call, and refuses the vault's own accounts as the
 * administered target, so the role cannot reach the switch (INV-025). It holds no membership setter, no
 * `allowTarget`, no revoke and no `setAllowance`, and it cannot write under its own key or the restart role's.
 */
export default [
  call(MODIFIER, SCOPE_TARGET, EMERGENCY, NOT_ADMINISTRATION),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, TRANSFER, TO_AGENT, CALL),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, TRANSFER, TO_AGENT_OR_ORDERS, CALL),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, APPROVE, ZERO, CALL),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, anyOf(VAULT_EXITS), VAULT_EXIT, CALL),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, anyOf(CLAIMS), CLAIM, CALL),
  call(MODIFIER, ALLOW_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, anyOf(PLAIN_EXITS.map(selector)), CALL),
] satisfies Permissions;
