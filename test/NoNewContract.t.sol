// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ReviewBase} from "./ReviewProbe.t.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IAaveV3Pool} from "../src/interfaces/Tokens.sol";
import {Policy} from "../src/policy/Policy.sol";

/// @title Can the governance controller's job be done with conditions alone?
contract NoNewContract is ReviewBase {
    bytes32 constant K_AAVE = keccak256("preapproved:aave");
    bytes32 constant K_SDAI = keccak256("preapproved:sdai");
    bytes32 constant K_EVIL = keccak256("not-preapproved");

    function _eqB(bytes32 v) internal pure returns (bytes memory) { return abi.encodePacked(v); }

    /// Pre-scoped role keys + assignRoles constrained to (operator Safe, approved keys).
    function test_native_toggle_of_preapproved_roles() public {
        // DAO pre-scopes two roles at launch (done once, by vote).
        _own(address(roles), abi.encodeCall(IRoles.scopeTarget, (K_AAVE, a.aavePool)));
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (K_AAVE, a.aavePool, IAaveV3Pool.withdraw.selector, 0)));
        _own(address(roles), abi.encodeCall(IRoles.scopeTarget, (K_SDAI, a.sdai)));
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (K_SDAI, a.sdai, IERC20.approve.selector, 0)));

        // Governance may ONLY call assignRoles(member == TMC, keys in {AAVE,SDAI}).
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](8);
        c[0] = IRoles.ConditionFlat(0, 5, 5, "");                       // calldata Matches
        c[1] = IRoles.ConditionFlat(0, 1, 16, abi.encode(tmc));         // member == operator Safe
        c[2] = IRoles.ConditionFlat(0, 4, 7, "");                       // roleKeys: Array ArrayEvery
        c[3] = IRoles.ConditionFlat(0, 4, 7, "");                       // memberOf: Array ArrayEvery
        c[4] = IRoles.ConditionFlat(2, 0, 2, "");                       // Or over approved keys
        c[5] = IRoles.ConditionFlat(3, 1, 0, "");                       // any bool
        c[6] = IRoles.ConditionFlat(4, 1, 16, _eqB(K_AAVE));
        c[7] = IRoles.ConditionFlat(4, 1, 16, _eqB(K_SDAI));
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (Policy.POLICY_ADMIN(), address(roles), IRoles.assignRoles.selector, c, 0)));
        emit log("Integrity ACCEPTED assignRoles constrained by ArrayEvery over approved keys");

        bytes32[] memory keys = new bytes32[](1);
        bool[] memory on = new bool[](1);
        on[0] = true;

        // approved key: governance may switch it on
        keys[0] = K_AAVE;
        vm.prank(a.policyAdmin);
        assertTrue(roles.execTransactionWithRole(address(roles), 0,
            abi.encodeCall(IRoles.assignRoles, (tmc, keys, on)), 0, Policy.POLICY_ADMIN(), true),
            "approved role key must be toggleable");

        // the operator can now use exactly that pre-scoped role, nothing more.
        // Switch on the sDAI role too and use its simple approve permission.
        keys[0] = K_SDAI;
        vm.prank(a.policyAdmin);
        assertTrue(roles.execTransactionWithRole(address(roles), 0,
            abi.encodeCall(IRoles.assignRoles, (tmc, keys, on)), 0, Policy.POLICY_ADMIN(), true));
        vm.prank(tmc);
        assertTrue(roles.execTransactionWithRole(a.sdai, 0,
            abi.encodeCall(IERC20.approve, (a.aavePool, 1)), 0, K_SDAI, true),
            "operator holds the pre-scoped role");
        // and cannot reach anything outside it under that key
        vm.prank(tmc);
        (bool outside,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (a.usdc, 0, abi.encodeCall(IERC20.approve, (attacker, 1)), 0, K_SDAI, true)));
        assertFalse(outside, "the pre-scoped role must not reach beyond its scope");

        // unapproved key: refused
        keys[0] = K_EVIL;
        vm.prank(a.policyAdmin);
        (bool evilKey,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, abi.encodeCall(IRoles.assignRoles, (tmc, keys, on)), 0, Policy.POLICY_ADMIN(), true)));
        assertFalse(evilKey, "a key the DAO never pre-scoped must be refused");

        // granting to somebody other than the operator Safe: refused
        keys[0] = K_AAVE;
        vm.prank(a.policyAdmin);
        (bool evilMember,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, abi.encodeCall(IRoles.assignRoles, (attacker, keys, on)), 0, Policy.POLICY_ADMIN(), true)));
        assertFalse(evilMember, "membership must be pinned to the operator Safe");
    }

    /// Allowance ceilings AND a refill-period floor, with no contract.
    function test_native_allowance_bounds_including_period_floor() public {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](9);
        c[0] = IRoles.ConditionFlat(0, 5, 5, "");
        c[1] = IRoles.ConditionFlat(0, 0, 2, "");                                  // key in approved set
        c[2] = IRoles.ConditionFlat(0, 1, 18, abi.encode(uint256(2_000e6)));       // balance   <  cap
        c[3] = IRoles.ConditionFlat(0, 1, 18, abi.encode(uint256(2_000e6)));       // maxRefill <  cap
        c[4] = IRoles.ConditionFlat(0, 1, 18, abi.encode(uint256(2_000e6)));       // refill    <  cap
        c[5] = IRoles.ConditionFlat(0, 1, 17, abi.encode(uint256(29 days)));       // period    >  floor
        c[6] = IRoles.ConditionFlat(0, 1, 0, "");                                  // timestamp
        c[7] = IRoles.ConditionFlat(1, 1, 16, _eqB(Policy.K_AAVE_USDC_USDT));
        c[8] = IRoles.ConditionFlat(1, 1, 16, _eqB(Policy.K_SKY_DAI_USDS));
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (Policy.POLICY_ADMIN(), address(roles), IRoles.setAllowance.selector, c, 0)));

        // within the ceiling and above the period floor
        vm.prank(a.policyAdmin);
        assertTrue(roles.execTransactionWithRole(address(roles), 0,
            abi.encodeCall(IRoles.setAllowance, (Policy.K_AAVE_USDC_USDT, 1_500e6, 1_500e6, 1_500e6, 30 days, 0)),
            0, Policy.POLICY_ADMIN(), true), "a compliant budget change must pass");

        // above the ceiling
        vm.prank(a.policyAdmin);
        (bool tooBig,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, abi.encodeCall(IRoles.setAllowance,
                (Policy.K_AAVE_USDC_USDT, 9_000e6, 9_000e6, 9_000e6, 30 days, 0)), 0, Policy.POLICY_ADMIN(), true)));
        assertFalse(tooBig, "ceiling must bind");

        // the gap my contract had: a one-second refill period
        vm.prank(a.policyAdmin);
        (bool tooFast,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (address(roles), 0, abi.encodeCall(IRoles.setAllowance,
                (Policy.K_AAVE_USDC_USDT, 1_500e6, 1_500e6, 1_500e6, 1, 0)), 0, Policy.POLICY_ADMIN(), true)));
        assertFalse(tooFast, "period floor must bind");
        emit log("native conditions bound both the amount and the refill rate");
    }
}
