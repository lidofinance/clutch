// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";
import {ClutchFixture} from "./utils/Fixture.sol";

/// @title SingleModifierProbe — option C of the simplification note
///        (docs/research/simplification-2026-10-08.md): one Roles modifier
///        per account instead of two.
/// @dev The probe disables the safety modifier and puts the emergency and
///      technical roles on the operator modifier. The technical role's switch
///      is then `assignRoles(operatorSafe, [operator], [false])` on its own
///      modifier, with every argument pinned, instead of `disableModule` on
///      the Asset Safe. A role's call executes as the Asset Safe, which owns
///      the modifier, so a role can administer its own modifier. This probe
///      tests that path on the deployed Roles mastercopy. EM chose one
///      modifier for the orders account on 2026-10-09 (OD-57); the Asset Safe
///      keeps two. The harness has no orders account yet, so the Asset Safe of
///      the fixture stands in for the orders account here.
contract SingleModifierProbe is ClutchFixture {
    // AbiType and Operator values of the deployed mastercopy (IRoles.sol).
    uint8 internal constant STATIC = 1;
    uint8 internal constant ARRAY = 4;
    uint8 internal constant CALLDATA = 5;
    uint8 internal constant MATCHES = 5;
    uint8 internal constant PASS = 0;
    uint8 internal constant EQUAL_TO = 16;
    uint8 internal constant NONE = 0; // ExecutionOptions.None

    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;
    bytes4 internal constant NO_MEMBERSHIP = 0xfd8e9f28;

    function setUp() public override {
        super.setUp();
        vm.startPrank(principal);
        // One modifier: switch the safety modifier off.
        _owner(address(safe), abi.encodeCall(ISafe.disableModule, (_prev(address(safety)), address(safety))));

        // The emergency role on the operator modifier: a return to the Agent,
        // and the revoke of an operator target on its own modifier.
        _owner(address(roles), abi.encodeCall(IRoles.assignRoles, (emergencySafe, _keys(EMERGENCY), _flags(true))));
        _owner(address(roles), abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, a.usdc)));
        _owner(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (EMERGENCY, a.usdc, IERC20.transfer.selector, _firstArgEquals(abi.encode(address(agent)), 1), NONE)));
        _owner(address(roles), abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, address(roles))));
        _owner(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (EMERGENCY, address(roles), IRoles.revokeTarget.selector, _firstArgEquals(abi.encode(OPERATOR), 1), NONE)));

        // The technical role: remove the operator Safe's membership, and nothing else.
        _owner(address(roles), abi.encodeCall(IRoles.assignRoles, (brakes, _keys(TECHNICAL), _flags(true))));
        _owner(address(roles), abi.encodeCall(IRoles.scopeTarget, (TECHNICAL, address(roles))));
        _owner(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (TECHNICAL, address(roles), IRoles.assignRoles.selector, _unassignOperator(), NONE)));
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // the probe
    // ------------------------------------------------------------------

    function test_C1_one_modifier_is_enabled() public view {
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 1, "only the operator modifier is enabled");
        assertEq(mods[0], address(roles));
    }

    function test_C2_unassign_stops_the_operator_and_recovery_survives() public {
        // the operator works before the switch
        assertTrue(_as(operatorSafe, OPERATOR, a.usds, abi.encodeCall(IERC20.approve, (a.susds, 1e18))), "operator before");

        vm.recordLogs();
        assertTrue(_as(brakes, TECHNICAL, address(roles), _unassign(operatorSafe, OPERATOR, false)), "the switch");
        assertEq(vm.getRecordedLogs().length > 0, true, "the switch emits AssignRoles for monitoring");

        // the operator is out: the modifier refuses its role
        vm.prank(operatorSafe);
        (bool ok, bytes memory ret) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (a.usds, 0, abi.encodeCall(IERC20.approve, (a.susds, 1e18)), 0, OPERATOR, true)));
        assertFalse(ok, "operator after the switch");
        assertEq(bytes4(ret), NO_MEMBERSHIP, "refused by membership, not by a condition");

        // recovery on the same modifier still works
        deal(a.usdc, address(safe), 10e6);
        assertTrue(_as(emergencySafe, EMERGENCY, a.usdc, abi.encodeCall(IERC20.transfer, (address(agent), 4e6))), "recovery");
        assertEq(IERC20(a.usdc).balanceOf(address(agent)), 4e6);
    }

    function test_C3_the_switch_is_pinned() public {
        // another module, another key, assign instead of remove, or a longer list
        _refused(brakes, TECHNICAL, address(roles), _unassign(attacker, OPERATOR, false), "another module");
        _refused(brakes, TECHNICAL, address(roles), _unassign(emergencySafe, EMERGENCY, false), "the emergency role");
        _refused(brakes, TECHNICAL, address(roles), _unassign(operatorSafe, OPERATOR, true), "assign instead of remove");
        _refused(brakes, TECHNICAL, address(roles), _unassign(brakes, EMERGENCY, true), "self-promotion");
        bytes32[] memory two = new bytes32[](2);
        (two[0], two[1]) = (OPERATOR, EMERGENCY);
        bool[] memory off = new bool[](2);
        _refused(brakes, TECHNICAL, address(roles),
            abi.encodeCall(IRoles.assignRoles, (operatorSafe, two, off)), "a longer list");
        // nor any other administrative call on the modifier
        _refused(brakes, TECHNICAL, address(roles),
            abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, a.usdc)), "another selector");
        // nor anything on the Asset Safe
        _refused(brakes, TECHNICAL, address(safe),
            abi.encodeCall(ISafe.disableModule, (SENTINEL, address(roles))), "the Asset Safe");
    }

    function test_C4_the_operator_cannot_restore_itself() public {
        assertTrue(_as(brakes, TECHNICAL, address(roles), _unassign(operatorSafe, OPERATOR, false)), "the switch");
        vm.prank(operatorSafe);
        (bool ok, bytes memory ret) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, _unassign(operatorSafe, OPERATOR, true), 0, OPERATOR, true)));
        assertFalse(ok);
        assertEq(bytes4(ret), NO_MEMBERSHIP);
        // and before the switch, no operator permission reaches the modifier
        vm.startPrank(principal);
        _owner(address(roles), _unassign(operatorSafe, OPERATOR, true));
        vm.stopPrank();
        _refused(operatorSafe, OPERATOR, address(roles), _unassign(operatorSafe, TECHNICAL, true), "operator self-admin");
    }

    function test_C5_emergency_revoke_on_its_own_modifier() public {
        assertTrue(_as(operatorSafe, OPERATOR, a.usds, abi.encodeCall(IERC20.approve, (a.susds, 1e18))), "operator before");
        assertTrue(_as(emergencySafe, EMERGENCY, address(roles),
            abi.encodeCall(IRoles.revokeTarget, (OPERATOR, a.usds))), "the revoke through the same modifier");
        _refused(operatorSafe, OPERATOR, a.usds, abi.encodeCall(IERC20.approve, (a.susds, 1e18)), "operator after the revoke");
        // the revoke stays pinned to the operator key
        _refused(emergencySafe, EMERGENCY, address(roles),
            abi.encodeCall(IRoles.revokeTarget, (TECHNICAL, address(roles))), "another key");
    }

    function test_C6_the_dao_restores_the_operator() public {
        assertTrue(_as(brakes, TECHNICAL, address(roles), _unassign(operatorSafe, OPERATOR, false)), "the switch");
        vm.startPrank(principal);
        _owner(address(roles), _unassign(operatorSafe, OPERATOR, true));
        vm.stopPrank();
        assertTrue(_as(operatorSafe, OPERATOR, a.usds, abi.encodeCall(IERC20.approve, (a.susds, 1e18))), "operator restored");
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    function _owner(address to, bytes memory data) internal {
        SafeExec.execAsOwner(agent, safe, to, data);
    }

    function _as(address member, bytes32 roleKey, address to, bytes memory data) internal returns (bool ok) {
        vm.prank(member);
        (ok,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, roleKey, true)));
    }

    function _refused(address member, bytes32 roleKey, address to, bytes memory data, string memory what) internal {
        vm.prank(member);
        (bool ok, bytes memory ret) =
            address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, roleKey, true)));
        assertFalse(ok, what);
        assertEq(bytes4(ret), CONDITION_VIOLATION, what);
    }

    function _unassign(address module, bytes32 roleKey, bool memberOf) internal pure returns (bytes memory) {
        return abi.encodeCall(IRoles.assignRoles, (module, _keys(roleKey), _flags(memberOf)));
    }

    function _keys(bytes32 k) internal pure returns (bytes32[] memory out) {
        out = new bytes32[](1);
        out[0] = k;
    }

    function _flags(bool f) internal pure returns (bool[] memory out) {
        out = new bool[](1);
        out[0] = f;
    }

    /// @dev Matches(calldata) with the first static argument equal to `value`
    ///      and `rest` more static arguments that pass.
    function _firstArgEquals(bytes memory value, uint256 rest) internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](2 + rest);
        c[0] = IRoles.ConditionFlat(0, CALLDATA, MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, STATIC, EQUAL_TO, value);
        for (uint256 i = 0; i < rest; i++) c[2 + i] = IRoles.ConditionFlat(0, STATIC, PASS, "");
    }

    /// @dev assignRoles(operatorSafe, [operator], [false]): the module, a
    ///      one-element key list and a one-element flag list, each pinned.
    ///      Matches on an array also pins its length.
    function _unassignOperator() internal view returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](6);
        c[0] = IRoles.ConditionFlat(0, CALLDATA, MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, STATIC, EQUAL_TO, abi.encode(operatorSafe));
        c[2] = IRoles.ConditionFlat(0, ARRAY, MATCHES, "");
        c[3] = IRoles.ConditionFlat(0, ARRAY, MATCHES, "");
        c[4] = IRoles.ConditionFlat(2, STATIC, EQUAL_TO, abi.encode(OPERATOR));
        c[5] = IRoles.ConditionFlat(3, STATIC, EQUAL_TO, abi.encode(false));
    }

    function _prev(address module) internal view returns (address) {
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        address prev = SENTINEL;
        for (uint256 i = 0; i < mods.length; i++) {
            if (mods[i] == module) return prev;
            prev = mods[i];
        }
        revert("module not enabled");
    }
}
