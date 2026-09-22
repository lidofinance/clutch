// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";
import {ISafe} from "../interfaces/ISafe.sol";
import {IWstETH, ISDAI, ILidoEarnDepositQueue, ILidoEarnRedeemQueue, ICowSettlement} from "../interfaces/Tokens.sol";
import {Policy} from "./Policy.sol";

/// @title FullPolicy — assembles the complete dry-run policy as an ordered
///        list of Roles admin calls, mirroring the constellation one-to-one.
/// @dev Call order: role assignment -> allowances -> operator permissions ->
///      emergency permissions. Every entry cites its constellation source.
library FullPolicy {
    // P0-3 approval ceilings. An approval is either exactly zero or strictly
    // below these values, so no role can leave an unlimited standing approval.
    // Dry-run scale; production sizing is a mandate decision.
    uint256 internal constant APPROVE_CAP_6 = 5_000_000e6;
    uint256 internal constant APPROVE_CAP_18 = 5_000_000e18;
    uint256 internal constant APPROVE_CAP_WSTETH = 2_500e18;


    /// @notice Permissions written into the OPERATOR modifier: the operator
    ///         role and the governance role that administers it. This modifier is
    ///         the one the module guard screens.
    function buildOperator(Policy.Addresses memory a, address roles)
        internal
        pure
        returns (Policy.Call[] memory)
    {
        Policy.Call[] memory calls = new Policy.Call[](160);
        uint256 i = 0;

        // -- membership ------------------------------------------------
        calls[i++] = Policy._assignRoles(roles, a.operator, Policy.OPERATOR());
        calls[i++] = Policy._setDefaultRole(roles, a.operator, Policy.OPERATOR());
        // corrected ET governance path: no Agent authority involved
        calls[i++] = Policy._assignRoles(roles, a.policyAdmin, Policy.POLICY_ADMIN());
        calls[i++] = Policy._setDefaultRole(roles, a.policyAdmin, Policy.POLICY_ADMIN());

        // -- allowances (dust scale; structure identical; sizing = WS-F) --
        calls[i++] = Policy._setAllowance(roles, Policy.K_AAVE_USDC_USDT, 1_000e6);
        calls[i++] = Policy._setAllowance(roles, Policy.K_AAVE_DAI_USDS, 1_000e18);
        calls[i++] = Policy._setAllowance(roles, Policy.K_AAVE_WSTETH, 1e18);
        calls[i++] = Policy._setAllowance(roles, Policy.K_SKY_DAI_USDS, 1_000e18);
        calls[i++] = Policy._setAllowance(roles, Policy.K_EARN_USD, 500e6);
        calls[i++] = Policy._setAllowance(roles, Policy.K_EARN_ETH, 1e18);

        // -- operator target scoping (required before any function grant) --
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.steth);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.wsteth);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.ldo);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.usdc);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.usdt);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.dai);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.usds);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.sdai);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.susds);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.aavePool);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnUsdDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnUsdRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnEthDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnEthRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.cowSettlement);

        // -- operator: Lido staking -------------------------------------
        // stETH.approve: wstETH (wrap) + CoW relayer (stETH is a swap sell leg)
        address[] memory stethSpenders = _two(a.wsteth, a.cowVaultRelayer);
        calls[i++] = Policy._opApproveOr(roles, a.steth, stethSpenders, Policy.OPERATOR(), APPROVE_CAP_18);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.wsteth, IWstETH.wrap.selector);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.wsteth, IWstETH.unwrap.selector);

        // -- operator: Aave v3 Core --------------------------------------
        // ONE approve scope per token: all spenders (Aave pool, Sky vault,
        // Earn queue, CoW relayer) merged into a single Or. A second scope on
        // the same (role, target, selector) would REPLACE the whole entry
        // (F-X3) — an earlier revision did exactly that for DAI/USDS and
        // silently wiped the Aave+CoW spenders; corrected 2026-09-10.
        calls[i++] = Policy._opApproveOr(roles, a.usdc, _three(a.aavePool, a.earnUsdDepositQueue, a.cowVaultRelayer), Policy.OPERATOR(), APPROVE_CAP_6);
        calls[i++] = Policy._opApproveOr(roles, a.usdt, _two(a.aavePool, a.cowVaultRelayer), Policy.OPERATOR(), APPROVE_CAP_6);
        calls[i++] = Policy._opApproveOr(roles, a.dai, _three(a.aavePool, a.sdai, a.cowVaultRelayer), Policy.OPERATOR(), APPROVE_CAP_18);
        calls[i++] = Policy._opApproveOr(roles, a.usds, _three(a.aavePool, a.susds, a.cowVaultRelayer), Policy.OPERATOR(), APPROVE_CAP_18);
        calls[i++] = Policy._opApproveOr(roles, a.wsteth, _three(a.aavePool, a.earnEthDepositQueue, a.cowVaultRelayer), Policy.OPERATOR(), APPROVE_CAP_WSTETH);

        // the provider's three-budget shape (see Policy._opAaveSupplyMulti):
        // USDC/USDT share k1, DAI/USDS share k2, wstETH draws k3
        address[] memory supplyAssets = new address[](5);
        supplyAssets[0] = a.usdc;
        supplyAssets[1] = a.usdt;
        supplyAssets[2] = a.dai;
        supplyAssets[3] = a.usds;
        supplyAssets[4] = a.wsteth;
        bytes32[] memory supplyKeys = new bytes32[](5);
        supplyKeys[0] = Policy.K_AAVE_USDC_USDT;
        supplyKeys[1] = Policy.K_AAVE_USDC_USDT;
        supplyKeys[2] = Policy.K_AAVE_DAI_USDS;
        supplyKeys[3] = Policy.K_AAVE_DAI_USDS;
        supplyKeys[4] = Policy.K_AAVE_WSTETH;
        calls[i++] = Policy._opAaveSupplyMulti(
            roles, supplyAssets, supplyKeys, Policy.OPERATOR(), a.aavePool
        );
        // withdraw is unbudgeted for both roles (risk-reducing direction)
        calls[i++] = Policy._exitAaveWithdraw(roles, _five(a.usdc, a.usdt, a.dai, a.usds, a.wsteth), a.aavePool, Policy.OPERATOR());

        // -- operator: Sky savings (spenders already merged above) ---------
        calls[i++] = Policy._opSavingsDeposit(roles, a.sdai, Policy.K_SKY_DAI_USDS, Policy.OPERATOR());
        calls[i++] = Policy._opSavingsDeposit(roles, a.susds, Policy.K_SKY_DAI_USDS, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.sdai, ISDAI.redeem.selector, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.sdai, ISDAI.withdraw.selector, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.susds, ISDAI.redeem.selector, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.susds, ISDAI.withdraw.selector, Policy.OPERATOR());

        // -- operator: Lido earnUSD ---------------------------------------
        calls[i++] = Policy._opEarnDeposit(roles, a.earnUsdDepositQueue, Policy.K_EARN_USD, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnUsdDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnUsdDepositQueue, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnUsdRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnUsdRedeemQueue, Policy.OPERATOR());

        // -- operator: Lido earnETH ---------------------------------------
        calls[i++] = Policy._opEarnDeposit(roles, a.earnEthDepositQueue, Policy.K_EARN_ETH, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnEthDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnEthDepositQueue, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnEthRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnEthRedeemQueue, Policy.OPERATOR());

        // -- operator: CoW rebalancing (incl. LDO sell leg per B5/A5) ------
        calls[i++] = Policy._opCowPresign(roles, a.cowSettlement);
        // NOTE: the CoW vault-relayer approvals for usdc/usdt/dai/usds/wsteth/
        // steth are folded into each token's merged spender Or-list above —
        // a second scopeFunction on the same (target, approve) would REPLACE
        // the whole scope (DD finding: last write wins). LDO keeps its own
        // single-spender scope.
        calls[i++] = Policy._opCowApprove(roles, a.ldo, a.cowVaultRelayer, APPROVE_CAP_18);

        // -- policy-admin: bounded scope (P0-2) ------------------------------
        // Revision 4 showed that role-key pinning alone leaves an indirect
        // escalation route: grant the OPERATOR a permission targeting the
        // modifier, then call owner-only administration through the avatar.
        // Every scope below pins roleKey == OPERATOR and forbids the modifier
        // and the Safe as the administered target. Membership setters
        // (assignRoles, setDefaultRole) and the unscoped allowTarget are
        // removed entirely: membership is a DAO-vote action.
        calls[i++] = Policy._scopeTarget(roles, Policy.POLICY_ADMIN(), address(roles));
        calls[i++] = Policy._paScoped(roles, a.safe, IRoles.scopeTarget.selector, 2);
        calls[i++] = Policy._paScoped(roles, a.safe, IRoles.revokeTarget.selector, 2);
        calls[i++] = Policy._paScoped(roles, a.safe, IRoles.allowFunction.selector, 4);
        calls[i++] = Policy._paScoped(roles, a.safe, IRoles.revokeFunction.selector, 3);
        calls[i++] = Policy._paScopeFunction(roles, a.safe);
        calls[i++] = Policy._paSetAllowance(roles, Policy.operatorBudgetKeys());

        // truncate to used length
        assembly {
            mstore(calls, i)
        }
        return calls;
    }

    /// @notice Permissions written into the SAFETY modifier: the emergency and
    ///         technical roles. Kept on a separate module so the guard can let
    ///         them through while screening the operator, and so disabling the
    ///         operator's modifier does not disarm recovery.
    /// @param roles the safety modifier
    /// @param operatorRoles the operator modifier it polices
    function buildSafety(Policy.Addresses memory a, address roles, address operatorRoles)
        internal
        pure
        returns (Policy.Call[] memory)
    {
        Policy.Call[] memory calls = new Policy.Call[](136);
        uint256 i = 0;

        calls[i++] = Policy._assignRoles(roles, a.emergency, Policy.EMERGENCY());
        calls[i++] = Policy._setDefaultRole(roles, a.emergency, Policy.EMERGENCY());
        calls[i++] = Policy._assignRoles(roles, a.technical, Policy.TECHNICAL());
        calls[i++] = Policy._setDefaultRole(roles, a.technical, Policy.TECHNICAL());

        // -- emergency target scoping -------------------------------------
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.steth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.wsteth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.ldo);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usdc);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usdt);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.dai);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usds);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.sdai);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.susds);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.aavePool);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdShare);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthShare);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.atokenUsdc);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.atokenUsdt);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.atokenDai);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.atokenUsds);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.atokenWsteth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), operatorRoles);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.safe);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.cowSettlement);

        // -- emergency: revoke approvals (spender list sync invariant R8) ---
        address[] memory spenders = _seven(
            a.aavePool, a.sdai, a.susds, a.wsteth, a.earnUsdDepositQueue, a.earnEthDepositQueue, a.cowVaultRelayer
        );
        calls[i++] = Policy._emApproveZero(roles, a.steth, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.wsteth, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.ldo, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.usdc, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.usdt, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.dai, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.usds, spenders);

        // -- emergency: exits ----------------------------------------------
        calls[i++] = Policy._exitAaveWithdraw(roles, _five(a.usdc, a.usdt, a.dai, a.usds, a.wsteth), a.aavePool, Policy.EMERGENCY());
        calls[i++] = Policy._exitSavings(roles, a.sdai, ISDAI.redeem.selector, Policy.EMERGENCY());
        calls[i++] = Policy._exitSavings(roles, a.sdai, ISDAI.withdraw.selector, Policy.EMERGENCY());
        calls[i++] = Policy._exitSavings(roles, a.susds, ISDAI.redeem.selector, Policy.EMERGENCY());
        calls[i++] = Policy._exitSavings(roles, a.susds, ISDAI.withdraw.selector, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.wsteth, IWstETH.unwrap.selector);
        // P0-3: outstanding orders. Zeroing an approval does not cancel an
        // order that is already pre-signed, so the emergency role must be able
        // to invalidate the UID. Invalidation marks it filled, which also
        // prevents reuse by re-signing.
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.cowSettlement, ICowSettlement.invalidateOrder.selector);
        // Earn exits (both vaults, both queue kinds) — claim legs pinned to avatar
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.earnUsdDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnUsdDepositQueue, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.earnUsdRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnUsdRedeemQueue, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.earnEthDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnEthDepositQueue, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.earnEthRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnEthRedeemQueue, Policy.EMERGENCY());

        // -- emergency: block the operator (revoke-only, roleKey pinned) ----
        calls[i++] = Policy._emRevokeTarget(roles, operatorRoles);
        calls[i++] = Policy._emRevokeFunction(roles, operatorRoles);
        // -- technical emergency: module disabling only, module pinned ------
        // Module disabling answers a defect in the permission layer, which the
        // engineering organisation recognises, so it sits with the technical
        // committee rather than the financial one. The module argument is
        // pinned, closing the long-standing unpinned-parameter finding.
        calls[i++] = Policy._assignRoles(roles, a.technical, Policy.TECHNICAL());
        calls[i++] = Policy._setDefaultRole(roles, a.technical, Policy.TECHNICAL());
        calls[i++] = Policy._scopeTarget(roles, Policy.TECHNICAL(), a.safe);
        calls[i++] = Policy._techDisableModule(roles, a.safe, operatorRoles);

        // -- emergency: return to treasury (pinned to the Agent literal) ---
        calls[i++] = Policy._transferToAgent(roles, a.steth, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.wsteth, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.ldo, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usdc, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usdt, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.dai, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.sdai, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usds, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.susds, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.earnUsdShare, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.earnEthShare, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.atokenUsdc, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.atokenUsdt, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.atokenDai, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.atokenUsds, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.atokenWsteth, a.agent);


        // truncate to used length
        assembly {
            mstore(calls, i)
        }
        return calls;
    }


    /// @dev claim(address) with receiver pinned to the avatar.
    function _claimScopedToAvatar(address roles, address queue, bytes32 roleKey)
        internal
        pure
        returns (Policy.Call memory)
    {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: 1, operator_: 15, compValue: ""});
        return Policy.Call({
            to: roles,
            data: abi.encodeCall(
                IRoles.scopeFunction, (roleKey, queue, ILidoEarnDepositQueue.claim.selector, c, 0)
            )
        });
    }

    /// @dev claim(address,uint32[]) with receiver pinned to avatar. The uint32[]
    ///      node carries a Static/Pass element child per Integrity.sol.
    function _claim2ScopedToAvatar(address roles, address queue, bytes32 roleKey)
        internal
        pure
        returns (Policy.Call memory)
    {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](4);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: 1, operator_: 15, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: 4, operator_: 0, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 2, paramType: 1, operator_: 0, compValue: ""});
        return Policy.Call({
            to: roles,
            data: abi.encodeCall(
                IRoles.scopeFunction, (roleKey, queue, ILidoEarnRedeemQueue.claim.selector, c, 0)
            )
        });
    }

    function _one(address a) internal pure returns (address[] memory r) {
        r = new address[](1);
        r[0] = a;
    }

    function _two(address a, address b) internal pure returns (address[] memory r) {
        r = new address[](2);
        r[0] = a;
        r[1] = b;
    }

    function _three(address a, address b, address c) internal pure returns (address[] memory r) {
        r = new address[](3);
        r[0] = a;
        r[1] = b;
        r[2] = c;
    }

    function _five(address a, address b, address c, address d, address e)
        internal
        pure
        returns (address[] memory r)
    {
        r = new address[](5);
        r[0] = a;
        r[1] = b;
        r[2] = c;
        r[3] = d;
        r[4] = e;
    }

    function _seven(address a, address b, address c, address d, address e, address f, address g)
        internal
        pure
        returns (address[] memory r)
    {
        r = new address[](7);
        r[0] = a;
        r[1] = b;
        r[2] = c;
        r[3] = d;
        r[4] = e;
        r[5] = f;
        r[6] = g;
    }
}
