// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IWETH} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

/// @dev Actual mainnet WETH and Safe on the committed legacy-key fork profile.
contract MainnetWethCoverageTest is ClutchFixture {
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));

    function callWeth(bool emergency, uint256 value, bytes memory data) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(a.weth, value, data, 0, emergency ? EMERGENCY : OPERATOR, true));
    }

    function refused(bool emergency, uint256 value, bytes memory data, uint8 operation, bytes4 error_) internal {
        uint256 ethBefore = address(safe).balance;
        uint256 tokenBefore = IERC20(a.weth).balanceOf(address(safe));
        uint256 backingBefore = a.weth.balance;
        vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (a.weth, value, data, operation, emergency ? EMERGENCY : OPERATOR, true)));
        assertFalse(ok); assertEq(bytes4(reason), error_);
        assertEq(address(safe).balance, ethBefore); assertEq(IERC20(a.weth).balanceOf(address(safe)), tokenBefore);
        assertEq(a.weth.balance, backingBefore);
    }

    function checkWethEvent(Vm.Log[] memory logs, string memory signature, uint256 amount) internal view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) if (logs[i].emitter == a.weth && logs[i].topics[0] == keccak256(bytes(signature))) {
            assertEq(logs[i].topics.length, 2);
            assertEq(logs[i].topics[1], bytes32(uint256(uint160(address(safe)))));
            assertEq(logs[i].data, abi.encode(amount)); ++count;
        }
        assertEq(count, 1);
    }

    function test_MAIN01_operator_zero_one_and_full_balance_roundtrip_events() public {
        assertEq(IERC20(a.weth).balanceOf(address(safe)), 0);
        vm.deal(address(safe), 2 ether);
        uint256[3] memory amounts = [uint256(0), uint256(1), uint256(2 ether)];
        for (uint256 i; i < amounts.length; ++i) {
            uint256 snap = vm.snapshotState(); uint256 amount = amounts[i]; uint256 backing = a.weth.balance;
            vm.recordLogs(); callWeth(false, amount, abi.encodeCall(IWETH.deposit, ()));
            checkWethEvent(vm.getRecordedLogs(), "Deposit(address,uint256)", amount);
            assertEq(address(safe).balance, 2 ether - amount); assertEq(IERC20(a.weth).balanceOf(address(safe)), amount);
            assertEq(a.weth.balance, backing + amount);
            vm.recordLogs(); callWeth(false, 0, abi.encodeCall(IWETH.withdraw, (amount)));
            checkWethEvent(vm.getRecordedLogs(), "Withdrawal(address,uint256)", amount);
            assertEq(address(safe).balance, 2 ether); assertEq(IERC20(a.weth).balanceOf(address(safe)), 0);
            assertEq(a.weth.balance, backing); assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN01_missing_eth_and_excess_value_roll_back() public {
        vm.deal(address(safe), 0);
        refused(false, 1, abi.encodeCall(IWETH.deposit, ()), 0, FAILED);
        vm.deal(address(safe), 1);
        refused(false, 2, abi.encodeCall(IWETH.deposit, ()), 0, FAILED);
        refused(false, type(uint256).max, abi.encodeCall(IWETH.deposit, ()), 0, FAILED);
        callWeth(false, 1, abi.encodeCall(IWETH.deposit, ()));
        assertEq(IERC20(a.weth).balanceOf(address(safe)), 1); assertEq(address(safe).balance, 0);
    }

    function test_MAIN01_both_unwrap_roles_zero_missing_excess_and_max_then_retry() public {
        for (uint256 role; role < 2; ++role) {
            uint256 snap = vm.snapshotState(); bool emergency = role == 1;
            vm.deal(address(safe), 2);
            callWeth(emergency, 0, abi.encodeCall(IWETH.withdraw, (0)));
            refused(emergency, 0, abi.encodeCall(IWETH.withdraw, (1)), 0, FAILED);
            callWeth(false, 2, abi.encodeCall(IWETH.deposit, ()));
            refused(emergency, 0, abi.encodeCall(IWETH.withdraw, (3)), 0, FAILED);
            refused(emergency, 0, abi.encodeCall(IWETH.withdraw, (type(uint256).max)), 0, FAILED);
            callWeth(emergency, 0, abi.encodeCall(IWETH.withdraw, (1)));
            assertEq(address(safe).balance, 1); assertEq(IERC20(a.weth).balanceOf(address(safe)), 1);
            callWeth(emergency, 0, abi.encodeCall(IWETH.withdraw, (1)));
            assertEq(address(safe).balance, 2); assertEq(IERC20(a.weth).balanceOf(address(safe)), 0);
            assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN01_role_operation_value_fallback_and_malformed_routes() public {
        vm.deal(address(safe), 2 ether);
        refused(true, 1, abi.encodeCall(IWETH.deposit, ()), 0, CONDITION);
        for (uint256 role; role < 2; ++role) {
            bool emergency = role == 1;
            refused(emergency, 1, abi.encodeCall(IWETH.withdraw, (0)), 0, CONDITION);
            refused(emergency, 0, abi.encodeCall(IWETH.withdraw, (0)), 1, CONDITION);
            refused(emergency, 0, abi.encodeWithSignature("withdraw(uint256,address)", 0, attacker), 0, CONDITION);
            // The deployed legacy ABI decoder zero-fills the missing word.
            vm.recordLogs(); callWeth(emergency, 0, abi.encodePacked(IWETH.withdraw.selector));
            checkWethEvent(vm.getRecordedLogs(), "Withdrawal(address,uint256)", 0);
            refused(emergency, 0, abi.encodePacked(IWETH.withdraw.selector, bytes1(0x01)), 0, FAILED);
            refused(emergency, 1, "", 0, CONDITION);
        }
        assertEq(address(safe).balance, 2 ether); assertEq(IERC20(a.weth).balanceOf(address(safe)), 0);
    }

    function test_MAIN01_stop_recovery_owner_restart_and_exact_final_balances() public {
        vm.deal(address(safe), 3 ether); uint256 backing = a.weth.balance;
        callWeth(false, 2 ether, abi.encodeCall(IWETH.deposit, ()));
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 10); address previous = SENTINEL;
        for (uint256 i; i < modules.length && modules[i] != address(roles); ++i) previous = modules[i];
        vm.prank(emergencySafe); assertTrue(safety.execTransactionWithRole(address(safe), 0,
            abi.encodeCall(ISafe.disableModule, (previous, address(roles))), 0, EMERGENCY, true));
        vm.prank(operatorSafe); vm.expectRevert("GS104");
        roles.execTransactionWithRole(a.weth, 1, abi.encodeCall(IWETH.deposit, ()), 0, OPERATOR, true);
        vm.prank(operatorSafe); vm.expectRevert("GS104");
        roles.execTransactionWithRole(a.weth, 0, abi.encodeCall(IWETH.withdraw, (1)), 0, OPERATOR, true);
        callWeth(true, 0, abi.encodeCall(IWETH.withdraw, (1 ether)));
        assertEq(address(safe).balance, 2 ether); assertEq(IERC20(a.weth).balanceOf(address(safe)), 1 ether);
        assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles)));
        vm.startPrank(principal);
        SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles))));
        vm.stopPrank();
        callWeth(false, 1 ether, abi.encodeCall(IWETH.deposit, ()));
        callWeth(false, 0, abi.encodeCall(IWETH.withdraw, (2 ether)));
        assertEq(address(safe).balance, 3 ether); assertEq(IERC20(a.weth).balanceOf(address(safe)), 0); assertEq(a.weth.balance, backing);
    }
}
