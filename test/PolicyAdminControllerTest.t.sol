// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {ReviewBase} from "./ReviewProbe.t.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Policy} from "../src/policy/Policy.sol";
import {PolicyAdminController} from "../src/gov/PolicyAdminController.sol";

/// @title P0-2 acceptance tests for the bounded governance controller.
/// @dev The modifier-level guard is a deny-list of two addresses. These tests
///      cover the positive controls the report required on top of it: an
///      allow-list the DAO sets, a stale-motion rule, and bounded budgets.
contract PolicyAdminControllerTest is ReviewBase {
    PolicyAdminController internal controller;
    address internal etExecutor = makeAddr("et-executor");

    function _deployController() internal {
        controller = new PolicyAdminController(
            roles, address(safe), address(safe), etExecutor, Policy.OPERATOR(), Policy.POLICY_ADMIN()
        );
        // the controller becomes the sole member of the governance role
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = Policy.POLICY_ADMIN();
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _own(address(roles), abi.encodeCall(IRoles.assignRoles, (address(controller), keys, yes)));
        _own(address(roles), abi.encodeCall(IRoles.setDefaultRole, (address(controller), Policy.POLICY_ADMIN())));
    }

    function _dao(bytes memory data) internal {
        vm.startPrank(address(safe));
        (bool ok,) = address(controller).call(data);
        vm.stopPrank();
        assertTrue(ok, "DAO configuration call failed");
    }

    function test_p0_controller_applies_an_allowlisted_change() public {
        _deployController();
        _dao(abi.encodeCall(PolicyAdminController.setTargetAllowed, (a.sdai, true)));
        uint256 v = controller.policyVersion();
        vm.prank(etExecutor);
        controller.addTarget(a.sdai, v);
        assertEq(controller.policyVersion(), v + 1, "version must advance");
    }

    function test_p0_controller_rejects_a_target_outside_the_allowlist() public {
        _deployController();
        uint256 v = controller.policyVersion();
        vm.prank(etExecutor);
        vm.expectRevert(abi.encodeWithSelector(PolicyAdminController.TargetNotAllowed.selector, a.sdai));
        controller.addTarget(a.sdai, v);
    }

    function test_p0_controller_refuses_administrative_targets() public {
        _deployController();
        vm.startPrank(address(safe));
        vm.expectRevert(abi.encodeWithSelector(PolicyAdminController.AdministrativeTarget.selector, address(roles)));
        controller.setTargetAllowed(address(roles), true);
        vm.expectRevert(abi.encodeWithSelector(PolicyAdminController.AdministrativeTarget.selector, address(safe)));
        controller.setTargetAllowed(address(safe), true);
        vm.stopPrank();
        uint256 v = controller.policyVersion();
        vm.prank(etExecutor);
        vm.expectRevert(abi.encodeWithSelector(PolicyAdminController.AdministrativeTarget.selector, address(roles)));
        controller.addTarget(address(roles), v);
    }

    /// @dev The stale-motion rule: a motion built against an older policy
    ///      version must not enact after the policy has moved on.
    function test_p0_controller_rejects_a_stale_motion() public {
        _deployController();
        _dao(abi.encodeCall(PolicyAdminController.setTargetAllowed, (a.sdai, true)));
        _dao(abi.encodeCall(PolicyAdminController.setTargetAllowed, (a.susds, true)));
        uint256 queued = controller.policyVersion();
        // another change lands first
        vm.prank(etExecutor);
        controller.addTarget(a.sdai, queued);
        // the queued motion now names a version that no longer exists
        vm.prank(etExecutor);
        vm.expectRevert(
            abi.encodeWithSelector(PolicyAdminController.StaleVersion.selector, queued, queued + 1)
        );
        controller.addTarget(a.susds, queued);
    }

    /// @dev Incident control: the DAO invalidates every queued motion without
    ///      touching a permission, so a pending expansion cannot restore what
    ///      the emergency role revoked.
    function test_p0_dao_can_invalidate_queued_motions_during_an_incident() public {
        _deployController();
        _dao(abi.encodeCall(PolicyAdminController.setTargetAllowed, (a.sdai, true)));
        uint256 queued = controller.policyVersion();
        _dao(abi.encodeCall(PolicyAdminController.bumpPolicyVersion, ()));
        vm.prank(etExecutor);
        vm.expectRevert(
            abi.encodeWithSelector(PolicyAdminController.StaleVersion.selector, queued, queued + 1)
        );
        controller.addTarget(a.sdai, queued);
    }

    function test_p0_controller_bounds_budget_changes() public {
        _deployController();
        _dao(abi.encodeCall(PolicyAdminController.setAllowanceCeiling, (Policy.K_AAVE_USDC_USDT, 2_000e6)));
        uint256 v = controller.policyVersion();
        vm.prank(etExecutor);
        vm.expectRevert(
            abi.encodeWithSelector(
                PolicyAdminController.AboveCeiling.selector, Policy.K_AAVE_USDC_USDT, uint128(9_000e6), uint128(2_000e6)
            )
        );
        controller.setOperatorAllowance(Policy.K_AAVE_USDC_USDT, 9_000e6, 9_000e6, 9_000e6, 30 days, 0, v);
        vm.prank(etExecutor);
        controller.setOperatorAllowance(Policy.K_AAVE_USDC_USDT, 1_500e6, 1_500e6, 1_500e6, 30 days, 0, v);
    }

    function test_p0_only_governance_may_drive_changes() public {
        _deployController();
        _dao(abi.encodeCall(PolicyAdminController.setTargetAllowed, (a.sdai, true)));
        uint256 v = controller.policyVersion();
        vm.prank(attacker);
        vm.expectRevert(PolicyAdminController.NotGovernance.selector);
        controller.addTarget(a.sdai, v);
        vm.prank(attacker);
        vm.expectRevert(PolicyAdminController.NotOwner.selector);
        controller.setTargetAllowed(a.usdc, true);
    }
}
