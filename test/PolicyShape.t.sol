// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";

/// @title PolicyShape — static checks of the committed policy artifact, with no fork.
/// @dev Decodes every admin call of the artifact that the constellation
///      compiler writes (ADR 004, decision 14) and checks who gets which role
///      key and which targets, spenders and receivers the policy names.
contract PolicyShape is Test {
    string internal constant MANIFEST = "policy/constellation/manifests/fork-25946643.json";
    string internal constant ARTIFACT = "policy/constellation/artifacts/fork-25946643.json";

    bytes32 internal constant OPERATOR = bytes32("operator");
    bytes32 internal constant GOVERNANCE = bytes32("governance");
    bytes32 internal constant EMERGENCY = bytes32("emergency");
    bytes32 internal constant TECHNICAL = bytes32("technical");

    // Outside the launch scope (ADR 007, ADR 011).
    address internal constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address internal operatorRoles;
    address internal safetyRoles;
    address internal operatorSafe;
    address internal governanceMember;
    address[] internal to;
    bytes[] internal data;

    function setUp() public {
        string memory m = vm.readFile(MANIFEST);
        operatorRoles = vm.parseJsonAddress(m, ".operatorModifier");
        safetyRoles = vm.parseJsonAddress(m, ".safetyModifier");
        operatorSafe = vm.parseJsonAddress(m, ".operatorSafe");
        governanceMember = vm.parseJsonAddress(m, ".easyTrackExecutor");
        string memory j = vm.readFile(ARTIFACT);
        to = vm.parseJsonAddressArray(j, ".calls.to");
        data = vm.parseJsonBytesArray(j, ".calls.data");
    }

    function _args(bytes memory d) internal pure returns (bytes4 sel, bytes memory args) {
        sel = bytes4(d);
        args = new bytes(d.length - 4);
        for (uint256 i = 4; i < d.length; i++) args[i - 4] = d[i];
    }

    /// @dev Role key and target of a permission call; zero for other calls.
    function _keyAndTarget(bytes memory d) internal pure returns (bytes32 key, address target) {
        (bytes4 sel, bytes memory args) = _args(d);
        if (
            sel == IRoles.scopeTarget.selector || sel == IRoles.allowTarget.selector
                || sel == IRoles.allowFunction.selector || sel == IRoles.scopeFunction.selector
        ) {
            (key, target) = abi.decode(args, (bytes32, address));
        }
    }

    function _isOutOfScope(address x) internal pure returns (bool) {
        return x == AAVE_V3_POOL || x == SDAI || x == COW_SETTLEMENT || x == COW_VAULT_RELAYER;
    }

    function test_policy_builds() public view {
        assertEq(to.length, data.length, "one target per call");
        assertGt(to.length, 0, "empty policy");
        uint256 onOperator;
        uint256 onSafety;
        for (uint256 i = 0; i < to.length; i++) {
            assertGt(data[i].length, 4, "empty calldata");
            assertTrue(to[i] == operatorRoles || to[i] == safetyRoles, "every call targets one of the two modifiers");
            if (to[i] == operatorRoles) onOperator++;
            else onSafety++;
        }
        assertGt(onOperator, 0, "empty operator policy");
        assertGt(onSafety, 0, "empty safety policy");
    }

    /// @dev INV-018: the operator holds only the `operator` key, every
    ///      operator-modifier permission is either the operator's or the
    ///      governance role's on the modifier itself, and the safety modifier
    ///      never names the operator.
    function test_operator_holds_only_the_operator_key() public view {
        for (uint256 i = 0; i < to.length; i++) {
            (bytes4 sel, bytes memory args) = _args(data[i]);
            (bytes32 key, address target) = _keyAndTarget(data[i]);
            if (to[i] == operatorRoles) {
                if (sel == IRoles.assignRoles.selector) {
                    (address member, bytes32[] memory keys,) = abi.decode(args, (address, bytes32[], bool[]));
                    assertEq(keys.length, 1);
                    if (member == operatorSafe) assertEq(keys[0], OPERATOR, "operator key only");
                    else assertEq(member, governanceMember, "unexpected member");
                }
                if (key == bytes32(0)) continue;
                if (key == GOVERNANCE) {
                    assertEq(target, operatorRoles, "governance administers only the modifier");
                } else {
                    assertEq(key, OPERATOR, "every other permission is the operator's");
                }
            } else {
                if (sel == IRoles.assignRoles.selector) {
                    (address member,,) = abi.decode(args, (address, bytes32[], bool[]));
                    assertTrue(member != operatorSafe, "the operator holds no safety key");
                }
                if (key == bytes32(0)) continue;
                assertTrue(key == EMERGENCY || key == TECHNICAL, "safety keys only");
            }
        }
    }

    /// @dev INV-013 and INV-015: no permission targets Aave, sDAI or the CoW
    ///      settlement, and no condition names any of them or the CoW relayer
    ///      as a spender or receiver.
    function test_policy_names_no_out_of_scope_venue() public view {
        for (uint256 i = 0; i < to.length; i++) {
            (bytes32 key, address target) = _keyAndTarget(data[i]);
            if (key == bytes32(0)) continue;
            assertFalse(_isOutOfScope(target), "out-of-scope target");
            (bytes4 sel, bytes memory args) = _args(data[i]);
            if (sel != IRoles.scopeFunction.selector) continue;
            (,,, IRoles.ConditionFlat[] memory c,) =
                abi.decode(args, (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            for (uint256 j = 0; j < c.length; j++) {
                if (c[j].compValue.length != 32) continue;
                address named = address(uint160(uint256(bytes32(c[j].compValue))));
                assertFalse(_isOutOfScope(named), "out-of-scope spender or receiver");
            }
        }
    }
}
