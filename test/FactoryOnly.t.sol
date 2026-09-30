// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ReviewBase} from "./ReviewProbe.t.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Policy} from "../src/policy/Policy.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {MockEasyTrack} from "../src/mocks/MockEasyTrack.sol";
import {RoleToggleEVMScriptFactory} from "../src/gov/RoleToggleEVMScriptFactory.sol";

/// @title Factory-only governance: no controller, all enforcement in the
///        modifier plus Easy Track's own re-invocation rule.
contract FactoryOnly is ReviewBase {
    bytes32 constant K_SDAI = keccak256("preapproved:sdai");

    MockAragonAgent internal agent2;
    MockEVMScriptExecutor internal executor2;
    MockEasyTrack internal et;
    RoleToggleEVMScriptFactory internal factory;

    function _setUpGovernance() internal {
        agent2 = new MockAragonAgent();
        executor2 = new MockEVMScriptExecutor(agent2);
        et = new MockEasyTrack(executor2, IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32), 3 days, 5_000_000e18);
        factory = new RoleToggleEVMScriptFactory(
            roles, tmc, Policy.POLICY_ADMIN(), tmc, address(safe)
        );
        et.addEVMScriptFactory(address(factory));

        // DAO pre-scopes the role by vote, and makes the executor the sole
        // member of the governance role.
        _own(address(roles), abi.encodeCall(IRoles.scopeTarget, (K_SDAI, a.sdai)));
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (K_SDAI, a.sdai, IERC20.approve.selector, 0)));
        bytes32[] memory pa = new bytes32[](1);
        pa[0] = Policy.POLICY_ADMIN();
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _own(address(roles), abi.encodeCall(IRoles.assignRoles, (address(executor2), pa, yes)));
        _own(address(roles), abi.encodeCall(IRoles.setDefaultRole, (address(executor2), Policy.POLICY_ADMIN())));

        // and constrains what that role may do: assignRoles only, member
        // pinned to the operator Safe, every key drawn from the approved set.
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](6);
        c[0] = IRoles.ConditionFlat(0, 5, 5, "");                          // calldata
        c[1] = IRoles.ConditionFlat(0, 1, 16, abi.encode(tmc));            // member pinned
        c[2] = IRoles.ConditionFlat(0, 4, 7, "");                          // keys: ArrayEvery
        c[3] = IRoles.ConditionFlat(0, 4, 7, "");                          // memberOf: ArrayEvery
        c[4] = IRoles.ConditionFlat(2, 1, 16, abi.encodePacked(K_SDAI));   // every key approved
        c[5] = IRoles.ConditionFlat(3, 1, 0, "");                          // any bool
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (Policy.POLICY_ADMIN(), address(roles), IRoles.assignRoles.selector, c, 0)));

        vm.prank(address(safe));
        factory.setRoleKeyAllowed(K_SDAI, true);
    }

    function test_factory_only_toggle_enacts_and_grants_the_prescoped_role() public {
        _setUpGovernance();
        bytes memory callData = abi.encode(K_SDAI, true);
        vm.prank(tmc);
        uint256 id = et.createMotion(address(factory), callData);
        vm.warp(block.timestamp + 3 days + 1);
        et.enactMotion(id, callData);

        deal(a.sdai, address(safe), 1e18);
        vm.prank(tmc);
        assertTrue(roles.execTransactionWithRole(a.sdai, 0,
            abi.encodeCall(IERC20.approve, (a.aavePool, 1)), 0, K_SDAI, true),
            "operator holds the pre-scoped role after enactment");
    }

    /// The property that removes the need for a version counter: withdrawing
    /// the key kills a motion already in its objection window, because
    /// enactment rebuilds the script through the factory.
    function test_factory_only_dao_withdrawal_kills_a_queued_motion() public {
        _setUpGovernance();
        bytes memory callData = abi.encode(K_SDAI, true);
        vm.prank(tmc);
        uint256 id = et.createMotion(address(factory), callData);

        // DAO withdraws approval during the objection window
        vm.prank(address(safe));
        factory.setRoleKeyAllowed(K_SDAI, false);

        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert();
        et.enactMotion(id, callData);
        emit log("queued motion died when the DAO withdrew the key: no version counter needed");
    }

    function test_factory_only_rejects_an_unapproved_key_and_a_foreign_creator() public {
        _setUpGovernance();
        bytes memory evil = abi.encode(keccak256("never-scoped"), true);
        vm.prank(tmc);
        vm.expectRevert();
        et.createMotion(address(factory), evil);

        bytes memory callData = abi.encode(K_SDAI, true);
        vm.prank(attacker);
        vm.expectRevert();
        et.createMotion(address(factory), callData);
    }
}
