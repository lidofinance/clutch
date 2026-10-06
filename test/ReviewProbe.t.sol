// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, ILidoEarnDepositQueue} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";
import {ClutchFixture} from "./utils/Fixture.sol";

/// @title ReviewProbe — regression tests for defects found in review, and
///        probes of what the deployed Roles mastercopy can express.
/// @dev Each test decides one claim against the deployed Roles v4
///      mastercopy on the pinned fork.
abstract contract ReviewBase is ClutchFixture {
    function _own(address to, bytes memory data) internal {
        vm.startPrank(principal);
        SafeExec.execAsOwner(agent, safe, to, data);
        vm.stopPrank();
    }

    // The deployed modifier's error for a refused permission.
    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;

    function _opCall(address to, bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(operatorSafe);
        (ok, ret) = address(roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
    }

    function _op(address to, bytes memory data) internal returns (bool ok) {
        (ok,) = _opCall(to, data);
    }

    /// @dev The modifier itself must refuse the call, not the protocol.
    function _opRefused(address to, bytes memory data, string memory why) internal {
        (bool ok, bytes memory ret) = _opCall(to, data);
        assertFalse(ok, why);
        assertEq(bytes4(ret), CONDITION_VIOLATION, why);
    }

    function _paCall(bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(a.governance);
        (ok, ret) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, data, 0, GOVERNANCE, true)));
    }

    function _pa(bytes memory data) internal returns (bool ok) {
        (ok,) = _paCall(data);
    }

    function _paRefused(bytes memory data, string memory why) internal {
        (bool ok, bytes memory ret) = _paCall(data);
        assertFalse(ok, why);
        assertEq(bytes4(ret), CONDITION_VIOLATION, why);
    }

    function _emCall(address to, bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(a.emergency);
        (ok, ret) = address(safety).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, EMERGENCY, true)));
    }

    function _approve(address spender, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(IERC20.approve, (spender, amount));
    }

    function _balance(bytes32 key) internal view returns (uint128 balance) {
        (,,, balance,) = roles.allowances(key);
    }
}

contract ReviewProbe is ReviewBase {
    // =================================================================
    // INV-011: budget keys of different assets and decimals are
    // independent. Each approval branch carries its own key, so exhausting
    // the 6-decimal earnUSD key leaves the 18-decimal keys untouched.
    // =================================================================
    function test_budget_keys_of_different_assets_are_independent() public {
        assertTrue(_op(a.usdc, _approve(a.earnUsdDepositQueue, 500e6)), "usdc within its key");
        _opRefused(a.usdc, _approve(a.earnUsdDepositQueue, 1), "usdc must exhaust its key");

        assertTrue(_op(a.usds, _approve(a.susds, 900e18)), "usds within its key");
        _opRefused(a.usds, _approve(a.susds, 200e18), "usds must exhaust its key");
        assertTrue(_op(a.wsteth, _approve(a.earnEthDepositQueue, 9e17)), "wsteth within its key");
        _opRefused(a.wsteth, _approve(a.earnEthDepositQueue, 2e17), "wsteth must exhaust its key");

        assertEq(_balance(K_EARN_USD), 0, "earnUSD key consumed only by usdc");
        assertEq(_balance(K_SUSDS), 100e18, "sUSDS key consumed only by usds");
        assertEq(_balance(K_EARN_ETH), 1e17, "earnETH key consumed only by wsteth");
    }

    // =================================================================
    // REGRESSION GUARD (duplicate-scope wipe): a second scope on the same
    // function replaces the first, so every spender of a token must sit in
    // one approve scope. USDS and stETH each have two spenders.
    // =================================================================
    function test_regression_one_approve_scope_per_token_keeps_every_spender() public {
        assertTrue(_op(a.usds, _approve(a.susds, 1e18)), "usds->sUSDS");
        assertTrue(_op(a.usds, _approve(a.daiUsds, 1e18)), "usds->converter (no wipe)");
        assertTrue(_op(a.dai, _approve(a.daiUsds, 1e18)), "dai->converter");
        assertTrue(_op(a.steth, _approve(a.wsteth, 1e18)), "steth->wstETH");
        assertTrue(_op(a.steth, _approve(a.withdrawalQueue, 1e17)), "steth->queue (no wipe)");
    }

    // =================================================================
    // PROBE: a single-child Matches on a three-parameter function. The
    // probe writes its own deposit scope with the amount under a budget
    // key; the trailing parameters stay unconstrained.
    // =================================================================
    function test_single_child_matches_leaves_trailing_parameters_unconstrained() public {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: 1, operator_: 28, compValue: abi.encodePacked(K_EARN_USD)});
        // Integrity accepts it at write time
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (OPERATOR, a.earnUsdDepositQueue, ILidoEarnDepositQueue.deposit.selector, c, 0)));
        emit log("Integrity ACCEPTED a 1-child Matches on a 3-param function");
        deal(a.usdc, address(safe), 1_000e6);
        assertTrue(_op(a.usdc, _approve(a.earnUsdDepositQueue, 100e6)), "approve within the key");
        bytes32[] memory noProof = new bytes32[](0);
        bool ok = _op(a.earnUsdDepositQueue,
            abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(10e6), address(safe), noProof)));
        emit log_named_string("call with 3 params against a 1-child condition", ok ? "ALLOWED" : "DENIED at check time");
        assertTrue(ok, "a 1-child Matches leaves trailing params unconstrained and allows the call");
    }

    // =================================================================
    // INV-004: the governance role is bounded. Two escalation routes found
    // in review must stay closed: a direct one through membership or the
    // emergency role, and an indirect one through an administrative target.
    // =================================================================
    function test_policyadmin_cannot_change_role_membership() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = OPERATOR;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _paRefused(abi.encodeCall(IRoles.assignRoles, (attacker, keys, yes)), "membership setters must not be reachable from governance");
    }

    function test_policyadmin_cannot_touch_the_emergency_role() public {
        _paRefused(abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, a.usdc)), "role key must be pinned to the operator");
    }

    /// @dev The indirect route: grant the operator a permission whose target
    ///      is the modifier itself, then reach owner-only administration
    ///      through the avatar.
    function test_policyadmin_cannot_grant_operator_admin_targets() public {
        _paRefused(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(roles))), "the modifier must be refused as an administered target");
        _paRefused(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(safe))), "the Safe must be refused as an administered target");
        _paRefused(abi.encodeCall(IRoles.allowFunction,
            (OPERATOR, address(roles), IRoles.revokeTarget.selector, 0)), "granting an admin selector to the operator must fail");
        // and the emergency role still works afterwards
        deal(a.usdc, address(safe), 10e6);
        vm.prank(a.emergency);
        assertTrue(safety.execTransactionWithRole(a.usdc, 0,
            abi.encodeCall(IERC20.transfer, (a.agent, 1e6)), 0, EMERGENCY, true),
            "emergency must remain armed");
    }

    function test_policyadmin_cannot_raise_a_foreign_allowance_key() public {
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (keccak256("not-an-operator-budget"), 1e30, 1e30, 1e30, 30 days, 0)), "allowance key must be one of the operator budgets");
    }

    // =================================================================
    // INV-012: a budget motion cannot set a refill period below 30 days
    // (OD-08). The per-key ceilings wait for the attested figures.
    // =================================================================
    function test_policyadmin_cannot_set_a_refill_period_below_30_days() public {
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (K_SUSDS, 1e18, 1e18, 1e18, 30 days - 1, 0)), "a period below the floor must be refused");
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (K_SUSDS, 1e18, 1e18, 1e18, 1, 0)), "a one-second period must be refused");
        assertTrue(_pa(abi.encodeCall(IRoles.setAllowance,
            (K_SUSDS, 1e18, 1e18, 1e18, 30 days, 0))), "the floor itself must pass");
    }

    /// @dev PROBE for the budget factory: native conditions can give each key
    ///      its own ceilings on balance, maxRefill and refill, and bound the
    ///      period below, with one Matches branch per key. The ceilings are
    ///      dry-run stand-ins at each key's own decimals.
    function test_budget_motion_bounds_are_expressible_per_key() public {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](15);
        c[0] = IRoles.ConditionFlat(0, 0, 2, "");  // Or over the keys
        c[1] = IRoles.ConditionFlat(0, 5, 5, "");  // branch: earnUSD key (6 decimals)
        c[2] = IRoles.ConditionFlat(0, 5, 5, "");  // branch: sUSDS key (18 decimals)
        bytes32[2] memory keys = [K_EARN_USD, K_SUSDS];
        uint256[2] memory ceilings = [uint256(2_000e6), uint256(2_000e18)];
        for (uint256 b = 0; b < 2; b++) {
            uint8 parent = uint8(1 + b);
            uint256 k = 3 + 6 * b;
            c[k] = IRoles.ConditionFlat(parent, 1, 16, abi.encodePacked(keys[b]));                   // key
            c[k + 1] = IRoles.ConditionFlat(parent, 1, 18, abi.encode(ceilings[b]));              // balance   <  ceiling
            c[k + 2] = IRoles.ConditionFlat(parent, 1, 18, abi.encode(ceilings[b]));              // maxRefill <  ceiling
            c[k + 3] = IRoles.ConditionFlat(parent, 1, 18, abi.encode(ceilings[b]));              // refill    <  ceiling
            c[k + 4] = IRoles.ConditionFlat(parent, 1, 17, abi.encode(uint256(30 days - 1)));     // period    >= 30 days
            c[k + 5] = IRoles.ConditionFlat(parent, 1, 0, "");                                    // timestamp
        }
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (GOVERNANCE, address(roles), IRoles.setAllowance.selector, c, 0)));

        assertTrue(_pa(abi.encodeCall(IRoles.setAllowance,
            (K_EARN_USD, 1_500e6, 1_500e6, 1_500e6, 30 days, 0))), "a 6-decimal key within its ceiling");
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (K_EARN_USD, 9_000e6, 9_000e6, 9_000e6, 30 days, 0)), "the 6-decimal ceiling must bind");
        assertTrue(_pa(abi.encodeCall(IRoles.setAllowance,
            (K_SUSDS, 1_500e18, 1_500e18, 1_500e18, 30 days, 0))), "an 18-decimal key within its own ceiling");
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (K_SUSDS, 9_000e18, 9_000e18, 9_000e18, 30 days, 0)), "the 18-decimal ceiling must bind");
        _paRefused(abi.encodeCall(IRoles.setAllowance,
            (K_EARN_USD, 1_500e6, 1_500e6, 1_500e6, 1, 0)), "the period floor must bind");
    }

    // =================================================================
    // INV-008: approval authority is bounded, and an incident action
    // cannot be undone by the operator.
    // =================================================================
    function test_operator_approval_is_bounded_by_key_or_ceiling() public {
        // a keyed spender: an unlimited approval exceeds any budget
        _opRefused(a.usdc, _approve(a.earnUsdDepositQueue, type(uint256).max), "unlimited approval must be rejected");
        // a capped spender: the ceiling binds, below it passes
        _opRefused(a.steth, _approve(a.wsteth, FLOOR_STANDIN_STETH), "the ceiling must bind");
        assertTrue(_op(a.steth, _approve(a.wsteth, FLOOR_STANDIN_STETH - 1)), "below the ceiling passes");
        _opRefused(a.steth, _approve(a.withdrawalQueue, FLOOR_STANDIN_STETH), "the queue ceiling must bind");
        assertTrue(_op(a.steth, _approve(a.withdrawalQueue, FLOOR_STANDIN_STETH - 1)), "below the queue ceiling passes");
        // zero is always allowed, even with the key exhausted
        assertTrue(_op(a.usdc, _approve(a.earnUsdDepositQueue, 500e6)), "a bounded approval is allowed");
        assertTrue(_op(a.usdc, _approve(a.earnUsdDepositQueue, 0)), "self-revocation must stay available");
    }

    /// @dev ADR 005: the emergency role zeroes approvals and cannot give one.
    ///      Found by the mutation check of the constellation port: no test
    ///      refused a non-zero emergency approval.
    function test_emergency_cannot_give_a_non_zero_approval() public {
        (bool ok, bytes memory ret) = _emCall(a.usds, _approve(a.susds, 1));
        assertFalse(ok, "a non-zero approval must be refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the modifier, not the token, must refuse it");
        (ok, ret) = _emCall(a.usds, _approve(attacker, 0));
        assertFalse(ok, "a spender outside the operator's list must be refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the modifier, not the token, must refuse it");
        (ok,) = _emCall(a.usds, _approve(a.susds, 0));
        assertTrue(ok, "zeroing an approved spender must pass");
    }

    function test_emergency_can_durably_stop_operator_reapproval() public {
        assertTrue(_op(a.usdc, _approve(a.earnUsdDepositQueue, 100e6)));
        // incident: zero the approval AND remove the operator's ability to set it
        vm.startPrank(a.emergency);
        assertTrue(safety.execTransactionWithRole(a.usdc, 0,
            _approve(a.earnUsdDepositQueue, 0), 0, EMERGENCY, true));
        assertTrue(safety.execTransactionWithRole(address(roles), 0,
            abi.encodeCall(IRoles.revokeFunction, (OPERATOR, a.usdc, IERC20.approve.selector)),
            0, EMERGENCY, true), "emergency must be able to revoke the operator's approve");
        vm.stopPrank();
        assertEq(IERC20(a.usdc).allowance(address(safe), a.earnUsdDepositQueue), 0);
        _opRefused(a.usdc, _approve(a.earnUsdDepositQueue, 1e6), "operator must not be able to restore the approval after the incident");
    }
}
