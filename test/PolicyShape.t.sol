// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";

/// @title PolicyShape — static checks of the built policy, with no fork.
/// @dev Decodes every admin call and checks who gets which role key and which
///      targets and spenders the policy names.
contract PolicyShape is Test {
    address internal constant OPERATOR_ROLES = address(0x401e5);
    address internal constant SAFETY_ROLES = address(0x5a7e7);

    // Outside the launch scope (ADR 007, ADR 011).
    address internal constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    function _addresses() internal pure returns (Policy.Addresses memory a) {
        a.safe = address(0x51);
        a.agent = address(0xA1);
        a.operator = address(0x0F);
        a.emergency = address(0xE5);
        a.technical = address(0x7E);
        a.policyAdmin = address(0xAD);
        Policy.fillTokens(a);
        Policy.fillProtocols(a);
        a.rolesOperator = OPERATOR_ROLES;
        a.rolesSafety = SAFETY_ROLES;
    }

    function _args(bytes memory data) internal pure returns (bytes4 sel, bytes memory args) {
        sel = bytes4(data);
        args = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; i++) args[i - 4] = data[i];
    }

    /// @dev Role key and target of a permission call; zero for other calls.
    function _keyAndTarget(bytes memory data) internal pure returns (bytes32 key, address target) {
        (bytes4 sel, bytes memory args) = _args(data);
        if (
            sel == IRoles.scopeTarget.selector || sel == IRoles.allowFunction.selector
                || sel == IRoles.scopeFunction.selector
        ) {
            (key, target) = abi.decode(args, (bytes32, address));
        }
    }

    function _isOutOfScope(address x) internal pure returns (bool) {
        return x == AAVE_V3_POOL || x == SDAI || x == COW_SETTLEMENT || x == COW_VAULT_RELAYER;
    }

    function test_policy_builds() public pure {
        Policy.Addresses memory a = _addresses();
        Policy.Call[] memory calls = FullPolicy.buildOperator(a, OPERATOR_ROLES);
        Policy.Call[] memory saf = FullPolicy.buildSafety(a, SAFETY_ROLES, OPERATOR_ROLES);
        assertGt(calls.length, 0, "empty operator policy");
        assertGt(saf.length, 0, "empty safety policy");
        for (uint256 i = 0; i < calls.length; i++) {
            assertGt(calls[i].data.length, 4, "empty calldata");
            assertEq(calls[i].to, OPERATOR_ROLES, "target must be the operator modifier");
        }
        for (uint256 i = 0; i < saf.length; i++) {
            assertGt(saf[i].data.length, 4, "empty calldata");
            assertEq(saf[i].to, SAFETY_ROLES, "target must be the safety modifier");
        }
    }

    /// @dev INV-018: the operator holds only the `operator` key, every
    ///      operator-modifier permission is either the operator's or the
    ///      governance role's on the modifier itself, and the safety modifier
    ///      never names the operator.
    function test_operator_holds_only_the_operator_key() public pure {
        Policy.Addresses memory a = _addresses();
        Policy.Call[] memory calls = FullPolicy.buildOperator(a, OPERATOR_ROLES);
        for (uint256 i = 0; i < calls.length; i++) {
            (bytes4 sel, bytes memory args) = _args(calls[i].data);
            if (sel == IRoles.assignRoles.selector) {
                (address member, bytes32[] memory keys,) = abi.decode(args, (address, bytes32[], bool[]));
                assertEq(keys.length, 1);
                if (member == a.operator) assertEq(keys[0], Policy.OPERATOR(), "operator key only");
                else assertEq(member, a.policyAdmin, "unexpected member");
            }
            (bytes32 key, address target) = _keyAndTarget(calls[i].data);
            if (key == bytes32(0)) continue;
            if (key == Policy.POLICY_ADMIN()) {
                assertEq(target, OPERATOR_ROLES, "governance administers only the modifier");
            } else {
                assertEq(key, Policy.OPERATOR(), "every other permission is the operator's");
            }
        }
        Policy.Call[] memory saf = FullPolicy.buildSafety(a, SAFETY_ROLES, OPERATOR_ROLES);
        for (uint256 i = 0; i < saf.length; i++) {
            (bytes4 sel, bytes memory args) = _args(saf[i].data);
            if (sel == IRoles.assignRoles.selector) {
                (address member,,) = abi.decode(args, (address, bytes32[], bool[]));
                assertTrue(member != a.operator, "the operator holds no safety key");
            }
            (bytes32 key,) = _keyAndTarget(saf[i].data);
            if (key == bytes32(0)) continue;
            assertTrue(key == Policy.EMERGENCY() || key == Policy.TECHNICAL(), "safety keys only");
        }
    }

    /// @dev INV-013 and INV-015: no permission targets Aave, sDAI or the CoW
    ///      settlement, and no condition names any of them or the CoW relayer
    ///      as a spender or receiver.
    function test_policy_names_no_out_of_scope_venue() public pure {
        Policy.Addresses memory a = _addresses();
        Policy.Call[] memory ops = FullPolicy.buildOperator(a, OPERATOR_ROLES);
        Policy.Call[] memory saf = FullPolicy.buildSafety(a, SAFETY_ROLES, OPERATOR_ROLES);
        Policy.Call[] memory all = new Policy.Call[](ops.length + saf.length);
        for (uint256 i = 0; i < ops.length; i++) all[i] = ops[i];
        for (uint256 i = 0; i < saf.length; i++) all[ops.length + i] = saf[i];

        for (uint256 i = 0; i < all.length; i++) {
            (bytes32 key, address target) = _keyAndTarget(all[i].data);
            if (key == bytes32(0)) continue;
            assertFalse(_isOutOfScope(target), "out-of-scope target");
            (bytes4 sel, bytes memory args) = _args(all[i].data);
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
