// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";
import {IWstETH, IWETH, IERC4626, IDaiUsds, IWithdrawalQueue, ILidoEarnDepositQueue, ILidoEarnRedeemQueue} from "../interfaces/Tokens.sol";
import {Policy} from "./Policy.sol";

/// @title FullPolicy — assembles the dry-run launch policy as an ordered list
///        of Roles admin calls, one list per modifier.
/// @dev Call order: role assignment -> budgets -> target scoping ->
///      permissions. The launch scope is ADR 011: no Aave, no sDAI and no
///      other third-party lending market. Swaps go through Stonks 2.0
///      instances (ADR 007), which the kit does not deploy yet, so the
///      operator holds no swap permission and no order pre-signing.
library FullPolicy {
    // Dry-run stand-ins for one TM Floor Value, the fixed ceiling of the
    // approvals that have no budget key (ADR 009, ADR 011). The production
    // figures come from the attested computation of OD-06 and are not in
    // this repository.
    uint256 internal constant FLOOR_STANDIN_STETH = 10e18;
    uint256 internal constant FLOOR_STANDIN_USD = 10_000e18;

    /// @notice Permissions written into the operator modifier: the operator
    ///         role and the governance role that administers it.
    function buildOperator(Policy.Addresses memory a, address roles)
        internal
        pure
        returns (Policy.Call[] memory)
    {
        Policy.Call[] memory calls = new Policy.Call[](64);
        uint256 i = 0;

        // -- membership ------------------------------------------------
        calls[i++] = Policy._assignRoles(roles, a.operator, Policy.OPERATOR());
        calls[i++] = Policy._setDefaultRole(roles, a.operator, Policy.OPERATOR());
        // governance path: enacted motions act as this role, not as the Agent
        calls[i++] = Policy._assignRoles(roles, a.policyAdmin, Policy.POLICY_ADMIN());
        calls[i++] = Policy._setDefaultRole(roles, a.policyAdmin, Policy.POLICY_ADMIN());

        // -- budgets, one per spender (dry-run scale) ---------------------
        calls[i++] = Policy._setAllowance(roles, Policy.K_SUSDS, 1_000e18);
        calls[i++] = Policy._setAllowance(roles, Policy.K_EARN_USD, 500e6);
        calls[i++] = Policy._setAllowance(roles, Policy.K_EARN_ETH, 1e18);

        // -- target scoping (required before any function grant) ----------
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.steth);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.wsteth);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.weth);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.usdc);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.dai);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.usds);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.susds);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.daiUsds);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.withdrawalQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnUsdDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnUsdRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnEthDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.OPERATOR(), a.earnEthRedeemQueue);

        // -- Lido staking: stake, wrap and unwrap, the withdrawal queue ----
        // stETH has two spenders, the wstETH contract and the withdrawal
        // queue. Both have a fixed ceiling and no budget key (OD-08, OD-27).
        calls[i++] = Policy._opApprove(
            roles,
            a.steth,
            _spenders(
                Policy.capped(a.wsteth, FLOOR_STANDIN_STETH),
                Policy.capped(a.withdrawalQueue, FLOOR_STANDIN_STETH)
            )
        );
        calls[i++] = Policy._stake(roles, a.steth, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.wsteth, IWstETH.wrap.selector);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.wsteth, IWstETH.unwrap.selector);
        calls[i++] = Policy._requestWithdrawals(roles, a.withdrawalQueue);
        // the queue pays a claim to the request's owner, the Asset Safe
        calls[i++] = Policy._allowFunction(
            roles, Policy.OPERATOR(), a.withdrawalQueue, IWithdrawalQueue.claimWithdrawals.selector
        );

        // -- WETH: wrap and unwrap (OD-20) ---------------------------------
        calls[i++] = Policy._allowFunctionWithValue(roles, Policy.OPERATOR(), a.weth, IWETH.deposit.selector);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.weth, IWETH.withdraw.selector);

        // -- stablecoins: sUSDS and the DAI–USDS converter (OD-22) ---------
        calls[i++] = Policy._opApprove(
            roles,
            a.usds,
            _spenders(
                Policy.keyed(a.susds, Policy.K_SUSDS),
                Policy.capped(a.daiUsds, FLOOR_STANDIN_USD)
            )
        );
        calls[i++] = Policy._opApprove(roles, a.dai, _spenders(Policy.capped(a.daiUsds, FLOOR_STANDIN_USD)));
        calls[i++] = Policy._convert(roles, a.daiUsds, IDaiUsds.daiToUsds.selector);
        calls[i++] = Policy._convert(roles, a.daiUsds, IDaiUsds.usdsToDai.selector);
        calls[i++] = Policy._savingsDeposit(roles, a.susds, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.susds, IERC4626.redeem.selector, Policy.OPERATOR());
        calls[i++] = Policy._exitSavings(roles, a.susds, IERC4626.withdraw.selector, Policy.OPERATOR());

        // -- Lido earnUSD ---------------------------------------------------
        // The approval spends the budget, so the deposit itself is unbudgeted.
        calls[i++] = Policy._opApprove(
            roles, a.usdc, _spenders(Policy.keyed(a.earnUsdDepositQueue, Policy.K_EARN_USD))
        );
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnUsdDepositQueue, ILidoEarnDepositQueue.deposit.selector);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnUsdDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnUsdDepositQueue, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnUsdRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnUsdRedeemQueue, Policy.OPERATOR());

        // -- Lido earnETH ---------------------------------------------------
        calls[i++] = Policy._opApprove(
            roles, a.wsteth, _spenders(Policy.keyed(a.earnEthDepositQueue, Policy.K_EARN_ETH))
        );
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnEthDepositQueue, ILidoEarnDepositQueue.deposit.selector);
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnEthDepositQueue, ILidoEarnDepositQueue.cancelDepositRequest.selector);
        calls[i++] = _claimScopedToAvatar(roles, a.earnEthDepositQueue, Policy.OPERATOR());
        calls[i++] = Policy._allowFunction(roles, Policy.OPERATOR(), a.earnEthRedeemQueue, ILidoEarnRedeemQueue.redeem.selector);
        calls[i++] = _claim2ScopedToAvatar(roles, a.earnEthRedeemQueue, Policy.OPERATOR());

        // -- governance: bounded scope (ADR 006) ----------------------------
        // Every scope below pins roleKey == OPERATOR and forbids the modifier
        // and the Safe as the administered target. Membership setters
        // (assignRoles, setDefaultRole) and the unscoped allowTarget are not
        // granted: membership is a DAO-vote action.
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

    /// @notice Permissions written into the safety modifier: the emergency and
    ///         technical roles. They sit on a separate module so that
    ///         disabling the operator's modifier does not disarm recovery.
    /// @param roles the safety modifier
    /// @param operatorRoles the operator modifier it polices
    function buildSafety(Policy.Addresses memory a, address roles, address operatorRoles)
        internal
        pure
        returns (Policy.Call[] memory)
    {
        Policy.Call[] memory calls = new Policy.Call[](64);
        uint256 i = 0;

        calls[i++] = Policy._assignRoles(roles, a.emergency, Policy.EMERGENCY());
        calls[i++] = Policy._setDefaultRole(roles, a.emergency, Policy.EMERGENCY());
        calls[i++] = Policy._assignRoles(roles, a.technical, Policy.TECHNICAL());
        calls[i++] = Policy._setDefaultRole(roles, a.technical, Policy.TECHNICAL());

        // -- emergency target scoping -------------------------------------
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.steth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.wsteth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.weth);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.ldo);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usdc);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usdt);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.dai);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.usds);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.susds);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.withdrawalQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthDepositQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthRedeemQueue);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnUsdShare);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), a.earnEthShare);
        calls[i++] = Policy._scopeTarget(roles, Policy.EMERGENCY(), operatorRoles);

        // -- emergency: zero approvals. The spender list must equal the
        // union of the operator's approval spenders.
        address[] memory spenders = new address[](6);
        spenders[0] = a.wsteth;
        spenders[1] = a.withdrawalQueue;
        spenders[2] = a.earnEthDepositQueue;
        spenders[3] = a.earnUsdDepositQueue;
        spenders[4] = a.susds;
        spenders[5] = a.daiUsds;
        calls[i++] = Policy._emApproveZero(roles, a.steth, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.wsteth, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.usdc, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.dai, spenders);
        calls[i++] = Policy._emApproveZero(roles, a.usds, spenders);

        // -- emergency: exits and conversions -------------------------------
        calls[i++] = Policy._exitSavings(roles, a.susds, IERC4626.redeem.selector, Policy.EMERGENCY());
        calls[i++] = Policy._exitSavings(roles, a.susds, IERC4626.withdraw.selector, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.wsteth, IWstETH.unwrap.selector);
        // WETH goes through stETH: unwrap, stake, then send or swap (OD-20)
        calls[i++] = Policy._allowFunction(roles, Policy.EMERGENCY(), a.weth, IWETH.withdraw.selector);
        calls[i++] = Policy._stake(roles, a.steth, Policy.EMERGENCY());
        calls[i++] = Policy._allowFunction(
            roles, Policy.EMERGENCY(), a.withdrawalQueue, IWithdrawalQueue.claimWithdrawals.selector
        );
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

        // -- technical: module disabling only, module pinned ----------------
        // Module disabling answers a defect in the permission layer, which the
        // engineering organisation recognises, so it sits with the technical
        // role rather than the financial one (ADR 005).
        calls[i++] = Policy._scopeTarget(roles, Policy.TECHNICAL(), a.safe);
        calls[i++] = Policy._techDisableModule(roles, a.safe, operatorRoles);

        // -- emergency: return to treasury (pinned to the Agent literal) ---
        calls[i++] = Policy._transferToAgent(roles, a.steth, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.wsteth, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.weth, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.ldo, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usdc, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usdt, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.dai, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.usds, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.susds, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.earnUsdShare, a.agent);
        calls[i++] = Policy._transferToAgent(roles, a.earnEthShare, a.agent);

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

    function _spenders(Policy.Spender memory s) internal pure returns (Policy.Spender[] memory r) {
        r = new Policy.Spender[](1);
        r[0] = s;
    }

    function _spenders(Policy.Spender memory s0, Policy.Spender memory s1)
        internal
        pure
        returns (Policy.Spender[] memory r)
    {
        r = new Policy.Spender[](2);
        r[0] = s0;
        r[1] = s1;
    }
}
