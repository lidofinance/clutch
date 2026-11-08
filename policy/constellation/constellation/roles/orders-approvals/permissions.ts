// SPDX-License-Identifier: AGPL-3.0-or-later
import { relayerApproval } from "../../cow";
import { RELAYER_TOKENS } from "../../orders";

/**
 * What an enacted motion may do as the approvals role on the orders account (ADR 007, decision 41): approve CoW's
 * vault relayer for a token that an order sells, for any amount. A motion can so raise an approval that the
 * emergency role set to zero. The role approves no other spender and calls nothing else. For a token that a
 * motion adds, the governance role writes the same permission, and nothing more, under this role's key.
 */
export default RELAYER_TOKENS.map(relayerApproval) satisfies Permissions;
