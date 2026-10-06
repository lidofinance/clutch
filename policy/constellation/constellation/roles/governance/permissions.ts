// SPDX-License-Identifier: AGPL-3.0-or-later
import { anyOf, c, call, key, noneOf } from "../../lib";
import { manifest } from "../../addresses";
import * as budgets from "../../allowances";
import { MIN_REFILL_PERIOD } from "../../parameters";

const MODIFIER = manifest.operatorModifier;
const OPERATOR = key("operator");

/**
 * Pinning only the role key leaves an indirect escalation: a motion grants
 * the operator a permission whose target is the Asset Safe or one of its
 * modules, and the operator then reaches owner-only administration through
 * the avatar. A fork probe did this with the safety modifier (OD-38). So
 * every scope below forbids, as the administered target, the Asset Safe and
 * every module that the manifest lists, with Nor, and the compiler checks
 * the guard. This deny-list is necessary and not sufficient: the Easy Track
 * template factories carry the positive rules (ADR 006).
 */
if (!Array.isArray(manifest.modules) || manifest.modules.length === 0) {
  throw new Error("the manifest must list every module of the Asset Safe in `modules` (OD-38)");
}
const NOT_ADMINISTRATION = noneOf(manifest.assetSafe, ...manifest.modules);

/**
 * The execution options that a motion may grant: None or Send. DelegateCall
 * and Both are refused, because a delegatecall from the Asset Safe runs
 * foreign code in the Safe's own storage (OD-36). Delegatecall for the
 * operator needs a DAO vote.
 */
const NO_DELEGATECALL = c.lt(2);

/** The operator's own budget keys: the only keys that a budget motion may set. */
const BUDGET_KEYS = Object.values(budgets).map((budget) => key(budget.key));

/**
 * What an enacted Easy Track motion may do, as the governance role on the
 * operator modifier (ADR 006). It writes the operator's permissions and sets
 * the operator's budgets. It holds no membership setter and no unscoped
 * `allowTarget`: membership is a DAO-vote action. It cannot touch another
 * role, it cannot grant delegatecall (OD-36), and a budget motion cannot set
 * a refill period below 30 days (OD-08).
 */
export default [
  call(MODIFIER, "scopeTarget(bytes32,address)", OPERATOR, NOT_ADMINISTRATION),
  call(MODIFIER, "revokeTarget(bytes32,address)", OPERATOR, NOT_ADMINISTRATION),
  call(MODIFIER, "allowFunction(bytes32,address,bytes4,uint8)", OPERATOR, NOT_ADMINISTRATION, undefined, NO_DELEGATECALL),
  call(MODIFIER, "revokeFunction(bytes32,address,bytes4)", OPERATOR, NOT_ADMINISTRATION),
  call(
    MODIFIER,
    "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)",
    OPERATOR,
    NOT_ADMINISTRATION,
    undefined,
    undefined,
    NO_DELEGATECALL,
  ),
  call(
    MODIFIER,
    "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)",
    anyOf(BUDGET_KEYS),
    undefined,
    undefined,
    undefined,
    c.gt(MIN_REFILL_PERIOD - 1n),
  ),
] satisfies Permissions;
