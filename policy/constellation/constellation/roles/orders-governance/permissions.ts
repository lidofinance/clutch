// SPDX-License-Identifier: AGPL-3.0-or-later
import { id } from "ethers";
import { anyOf, call, flatTree, key } from "../../lib";
import { COMPOSABLE_COW, manifest, ORDER_SIGNER, USDC } from "../../addresses";
import { NOT_ADMINISTRATION } from "../../administration";
import { ORDER, relayerApproval, relayerZero } from "../../cow";
import { returnTransfer } from "../../orders";

/** The kit deploys no orders modifier; a manifest without one never compiles this role. */
const MODIFIER = manifest.ordersModifier ?? "0x0000000000000000000000000000000000000000";
const OPERATOR = key("operator");
const EMERGENCY = key("emergency");
const APPROVALS = key("approvals");

const selector = (signature: string) => id(signature).slice(0, 10);
const SIGN_ORDER = selector(`signOrder(${ORDER},uint32,uint256)`);
const UNSIGN_ORDER = selector(`unsignOrder(${ORDER})`);
const CREATE_WITH_CONTEXT = selector("createWithContext((address,bytes32,bytes),address,bytes,bool)");
const REMOVE = selector("remove(bytes32)");
const TRANSFER = selector("transfer(address,uint256)");
const APPROVE = selector("approve(address,uint256)");

const SCOPE_TARGET = "scopeTarget(bytes32,address)";
const SCOPE_FUNCTION = "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)";
const ALLOW_FUNCTION = "allowFunction(bytes32,address,bytes4,uint8)";

/** The execution options of a grant, as the modifier numbers them: a plain call, or a delegatecall. */
const CALL = 0n;
const DELEGATECALL = 2n;

/**
 * The trees that do not depend on the token, pinned whole. Each is the tree that the operator's or the emergency
 * role's own permission compiles to, for any token: the return to the Asset Safe or the Agent, the emergency role's
 * zeroing of the relayer's approval, and the approvals role's relayer approval.
 */
const RETURN_TREE = flatTree(returnTransfer(USDC));
const ZERO_TREE = flatTree(relayerZero(USDC));
const RELAYER_TREE = flatTree(relayerApproval(USDC));

/**
 * What an enacted Easy Track motion may do, as the governance role on the orders modifier (ADR 007, decision 41):
 * write what a token needs when a motion adds it to the lists, and restore what the emergency role revoked from the
 * operator. Every grant refuses the vault's own accounts as the administered target (OD-38).
 *
 * - Signer orders, for the operator and the emergency role: `signOrder` on the order signer, by delegatecall, the
 *   one delegatecall that a motion may grant (OD-96).
 * - TWAP orders, for the operator: `createWithContext` on ComposableCoW.
 * - The return of a token to the Asset Safe or the Agent, for the operator and the emergency role; the emergency
 *   role's zeroing of the relayer's approval; and, under the approvals key, the relayer approval. Each tree is pinned
 *   whole, so a motion cannot give a role another receiver or spender, and only the approvals role raises an
 *   approval (INV-008).
 * - `allowFunction` restores the operator's two functions without conditions: cancelling a signer order, by
 *   delegatecall, and removing a TWAP order.
 *
 * Every other grant is refused, and so is any grant under the role's own key. The role holds no membership setter,
 * no `allowTarget`, no revoke and no `setAllowance`: membership is a DAO-vote action, a token leaves the lists when a
 * motion writes its orders again without it, and the orders account has no budgets of its own. The content of a
 * signer or TWAP order's tree, whose token lists change, comes with the motion (ADR 013).
 */
export default [
  call(MODIFIER, SCOPE_TARGET, anyOf([OPERATOR, EMERGENCY, APPROVALS]), NOT_ADMINISTRATION),
  call(MODIFIER, SCOPE_FUNCTION, anyOf([OPERATOR, EMERGENCY]), ORDER_SIGNER, SIGN_ORDER, undefined, DELEGATECALL),
  call(MODIFIER, SCOPE_FUNCTION, OPERATOR, COMPOSABLE_COW, CREATE_WITH_CONTEXT, undefined, CALL),
  call(MODIFIER, SCOPE_FUNCTION, anyOf([OPERATOR, EMERGENCY]), NOT_ADMINISTRATION, TRANSFER, RETURN_TREE, CALL),
  call(MODIFIER, SCOPE_FUNCTION, EMERGENCY, NOT_ADMINISTRATION, APPROVE, ZERO_TREE, CALL),
  call(MODIFIER, SCOPE_FUNCTION, APPROVALS, NOT_ADMINISTRATION, APPROVE, RELAYER_TREE, CALL),
  call(MODIFIER, ALLOW_FUNCTION, OPERATOR, ORDER_SIGNER, UNSIGN_ORDER, DELEGATECALL),
  call(MODIFIER, ALLOW_FUNCTION, OPERATOR, COMPOSABLE_COW, REMOVE, CALL),
] satisfies Permissions;
