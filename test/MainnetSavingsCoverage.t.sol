// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IERC4626} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

interface ISavingsLedger {
    function asset() external view returns (address);
    function getImplementation() external view returns (address);
    function chi() external view returns (uint256);
    function rho() external view returns (uint256);
    function ssr() external view returns (uint256);
    function drip() external returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function previewDeposit(uint256) external view returns (uint256);
    function previewWithdraw(uint256) external view returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
}

/// @dev ADR 009 approval spending and ADR 005 exit authority; legacy-key fork profile.
contract MainnetSavingsCoverageTest is ClutchFixture {
    uint256 internal constant RAY = 1e27;
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));
    ISavingsLedger internal ledger;
    struct State {
        uint256 assets; uint256 shares; uint256 backing; uint256 supply; uint256 usdsSupply;
        uint256 allowance; uint256 chi; uint256 rho; bytes32 budget; bytes32 otherBudgets;
    }
    function setUp() public override {
        super.setUp(); ledger = ISavingsLedger(a.susds); assertEq(ledger.asset(), a.usds);
        assertEq(ledger.getImplementation(), 0x4e7991e5C547ce825BdEb665EE14a3274f9F61e0);
        ledger.drip(); assertEq(ledger.rho(), block.timestamp); assertGt(ledger.chi(), RAY);
        deal(a.usds, address(safe), 1000e18); assertEq(budget(), 1000e18);
    }
    function keyState(bytes32 key) internal view returns (bytes32) {
        (uint128 r, uint128 m, uint64 p, uint128 b, uint64 t) = roles.allowances(key);
        return keccak256(abi.encode(r, m, p, b, t));
    }
    function budget() internal view returns (uint256 b) { (,,,b,) = roles.allowances(K_SUSDS); }
    function state() internal view returns (State memory s) {
        s.assets = IERC20(a.usds).balanceOf(address(safe)); s.shares = IERC20(a.susds).balanceOf(address(safe));
        s.backing = IERC20(a.usds).balanceOf(a.susds); s.supply = ledger.totalSupply();
        s.usdsSupply = ISavingsLedger(a.usds).totalSupply(); s.allowance = IERC20(a.usds).allowance(address(safe), a.susds);
        s.chi = ledger.chi(); s.rho = ledger.rho(); s.budget = keyState(K_SUSDS);
        s.otherBudgets = keccak256(abi.encode(keyState(K_EARN_USD), keyState(K_EARN_ETH)));
    }
    function execute(bool emergency, address target, bytes memory callData) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(target, 0, callData, 0, emergency ? EMERGENCY : OPERATOR, true));
    }
    function refused(bool emergency, address target, uint256 value, bytes memory callData, uint8 operation, bytes4 error_) internal {
        bytes32 before = keccak256(abi.encode(state())); vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (target, value, callData, operation, emergency ? EMERGENCY : OPERATOR, true)));
        assertFalse(ok); assertEq(bytes4(reason), error_); assertEq(keccak256(abi.encode(state())), before);
    }
    function approve(bool emergency, uint256 amount) internal {
        uint256 before = budget(); bytes32 other = state().otherBudgets;
        execute(emergency, a.usds, abi.encodeCall(IERC20.approve, (a.susds, amount)));
        assertEq(IERC20(a.usds).allowance(address(safe), a.susds), amount);
        assertEq(budget(), before - amount); assertEq(state().otherBudgets, other);
    }
    function nextChi(State memory before) internal view returns (uint256) {
        if (block.timestamp == before.rho) return before.chi;
        assertEq(block.timestamp - before.rho, 1, "Only a one-second accrual step is used");
        return ledger.ssr() * before.chi / RAY;
    }
    function yieldAndCommon(State memory before, State memory after_, uint256 chi, uint256 backing) internal view {
        uint256 yield = before.supply * chi / RAY - before.supply * before.chi / RAY;
        assertEq(after_.chi, chi); assertEq(after_.rho, block.timestamp);
        assertEq(after_.backing, backing + yield); assertEq(after_.usdsSupply, before.usdsSupply + yield);
        assertEq(after_.budget, before.budget); assertEq(after_.otherBudgets, before.otherBudgets);
        assertEq(ledger.totalAssets(), after_.supply * chi / RAY);
        assertEq(ledger.maxRedeem(address(safe)), after_.shares);
        assertEq(ledger.maxWithdraw(address(safe)), after_.shares * chi / RAY);
        assertEq(IERC20(a.susds).balanceOf(attacker), 0); assertEq(IERC20(a.usds).balanceOf(attacker), 0);
    }
    function depositAndCheck(uint256 assets) internal returns (uint256 shares) {
        State memory before = state(); uint256 chi = nextChi(before); shares = assets * RAY / chi;
        assertEq(ledger.previewDeposit(assets), shares); vm.recordLogs();
        execute(false, a.susds, abi.encodeCall(IERC4626.deposit, (assets, address(safe))));
        State memory after_ = state(); assertEq(after_.assets, before.assets - assets);
        assertEq(after_.shares, before.shares + shares); assertEq(after_.supply, before.supply + shares);
        assertEq(after_.allowance, before.allowance - assets); yieldAndCommon(before, after_, chi, before.backing + assets);
        checkEvent(vm.getRecordedLogs(), false, assets, shares);
    }
    function exitAndCheck(bool emergency, bool withdraw, uint256 amount) internal {
        State memory before = state(); uint256 chi = nextChi(before);
        uint256 shares = withdraw ? (amount * RAY + chi - 1) / chi : amount;
        uint256 assets = withdraw ? amount : amount * chi / RAY;
        assertEq(withdraw ? ledger.previewWithdraw(amount) : ledger.previewRedeem(amount), withdraw ? shares : assets);
        vm.recordLogs(); execute(emergency, a.susds, withdraw
            ? abi.encodeCall(IERC4626.withdraw, (amount, address(safe), address(safe)))
            : abi.encodeCall(IERC4626.redeem, (amount, address(safe), address(safe))));
        State memory after_ = state(); assertEq(after_.assets, before.assets + assets);
        assertEq(after_.shares, before.shares - shares); assertEq(after_.supply, before.supply - shares);
        assertEq(after_.allowance, before.allowance); yieldAndCommon(before, after_, chi, before.backing - assets);
        checkEvent(vm.getRecordedLogs(), true, assets, shares);
    }
    function checkEvent(Vm.Log[] memory logs, bool exit_, uint256 assets, uint256 shares) internal view {
        bytes32 eventId = keccak256(bytes(exit_ ? "Withdraw(address,address,address,uint256,uint256)" : "Deposit(address,address,uint256,uint256)")); uint256 count;
        for (uint256 i; i < logs.length; ++i) if (logs[i].emitter == a.susds && logs[i].topics[0] == eventId) {
            assertEq(logs[i].topics.length, exit_ ? 4 : 3);
            for (uint256 j = 1; j < logs[i].topics.length; ++j) assertEq(logs[i].topics[j], bytes32(uint256(uint160(address(safe)))));
            assertEq(logs[i].data, abi.encode(assets, shares)); ++count;
        }
        assertEq(count, 1);
    }
    function test_MAIN05_deposit_zero_one_partial_full_exact_shares_and_custody() public {
        assertEq(ledger.maxDeposit(address(safe)), type(uint256).max);
        uint256[4] memory amounts = [uint256(0), uint256(1), uint256(100e18 + 1), uint256(1000e18)];
        for (uint256 i; i < amounts.length; ++i) {
            uint256 snap = vm.snapshotState(); approve(false, amounts[i]); depositAndCheck(amounts[i]); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN05_both_roles_redeem_zero_one_partial_full_and_next_unit_failure() public {
        approve(false, 400e18); uint256 full = depositAndCheck(400e18);
        for (uint256 role; role < 2; ++role) {
            uint256[4] memory amounts = [uint256(0), uint256(1), full / 2, full];
            for (uint256 i; i < amounts.length; ++i) {
                uint256 snap = vm.snapshotState(); exitAndCheck(role == 1, false, amounts[i]);
                if (i == 3) refused(role == 1, a.susds, 0, abi.encodeCall(IERC4626.redeem, (1, address(safe), address(safe))), 0, FAILED);
                assertTrue(vm.revertToState(snap));
            }
        }
    }
    function test_MAIN05_both_roles_withdraw_zero_one_partial_exact_max_and_plus_one() public {
        approve(false, 400e18); depositAndCheck(400e18); uint256 max = state().shares * ledger.chi() / RAY;
        for (uint256 role; role < 2; ++role) {
            refused(role == 1, a.susds, 0, abi.encodeCall(IERC4626.withdraw, (max + 1, address(safe), address(safe))), 0, FAILED);
            uint256[4] memory amounts = [uint256(0), uint256(1), uint256(100e18 + 1), max];
            for (uint256 i; i < amounts.length; ++i) {
                uint256 snap = vm.snapshotState(); exitAndCheck(role == 1, true, amounts[i]); assertTrue(vm.revertToState(snap));
            }
        }
    }
    function test_MAIN05_budget_counts_replaced_approvals_zero_is_free_and_deposit_is_unbudgeted() public {
        approve(false, 400e18); assertEq(budget(), 600e18); approve(false, 100e18); assertEq(budget(), 500e18);
        approve(false, 0); approve(false, 500e18); assertEq(budget(), 0);
        refused(false, a.usds, 0, abi.encodeCall(IERC20.approve, (a.susds, 1)), 0, CONDITION);
        uint256 shares = depositAndCheck(500e18); approve(false, 0); approve(true, 0); exitAndCheck(true, false, shares); assertEq(budget(), 0);
    }
    function test_MAIN05_failed_deposits_and_max_exits_preserve_balances_rates_and_budgets_then_retry() public {
        refused(false, a.susds, 0, abi.encodeCall(IERC4626.deposit, (1, address(safe))), 0, FAILED);
        approve(false, 100e18); refused(false, a.susds, 0, abi.encodeCall(IERC4626.deposit, (100e18 + 1, address(safe))), 0, FAILED);
        deal(a.usds, address(safe), 99e18); refused(false, a.susds, 0, abi.encodeCall(IERC4626.deposit, (100e18, address(safe))), 0, FAILED);
        refused(false, a.susds, 0, abi.encodeCall(IERC4626.deposit, (type(uint256).max, address(safe))), 0, FAILED);
        for (uint256 role; role < 2; ++role) {
            refused(role == 1, a.susds, 0, abi.encodeCall(IERC4626.redeem, (type(uint256).max, address(safe), address(safe))), 0, FAILED);
            refused(role == 1, a.susds, 0, abi.encodeCall(IERC4626.withdraw, (type(uint256).max, address(safe), address(safe))), 0, FAILED);
        }
        deal(a.usds, address(safe), 100e18); depositAndCheck(100e18);
    }
    function test_MAIN05_wrong_receivers_owners_referral_mint_value_delegatecall_and_emergency_deposit_refused() public {
        approve(false, 100e18); depositAndCheck(100e18); vm.deal(address(safe), 1);
        for (uint256 role; role < 2; ++role) {
            bool emergency = role == 1;
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.deposit, (1, attacker)), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.redeem, (1, attacker, address(safe))), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.redeem, (1, address(safe), attacker)), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.withdraw, (1, attacker, address(safe))), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.withdraw, (1, address(safe), attacker)), 0, CONDITION);
            refused(emergency, a.susds, 1, abi.encodeCall(IERC4626.redeem, (1, address(safe), address(safe))), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeCall(IERC4626.redeem, (1, address(safe), address(safe))), 1, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeWithSignature("deposit(uint256,address,uint16)", 1, address(safe), 0), 0, CONDITION);
            refused(emergency, a.susds, 0, abi.encodeWithSignature("mint(uint256,address)", 1, address(safe)), 0, CONDITION);
        }
        refused(true, a.susds, 0, abi.encodeCall(IERC4626.deposit, (1, address(safe))), 0, CONDITION);
    }
    function test_MAIN05_one_second_pending_yield_preview_and_failed_drip_rollback_then_success() public {
        approve(false, 100e18); depositAndCheck(50e18); vm.warp(block.timestamp + 1);
        assertGt(nextChi(state()), ledger.chi());
        refused(false, a.susds, 0, abi.encodeCall(IERC4626.deposit, (50e18 + 1, address(safe))), 0, FAILED);
        depositAndCheck(50e18); exitAndCheck(true, true, 1);
    }
    function test_MAIN05_stop_emergency_zero_withdraw_redeem_and_owner_restart() public {
        approve(false, 500e18); depositAndCheck(400e18);
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 10); address previous = SENTINEL;
        for (uint256 i; i < modules.length && modules[i] != address(roles); ++i) previous = modules[i];
        execute(true, address(safe), abi.encodeCall(ISafe.disableModule, (previous, address(roles))));
        bytes32 before = keccak256(abi.encode(state())); vm.prank(operatorSafe); vm.expectRevert("GS104");
        roles.execTransactionWithRole(a.susds, 0, abi.encodeCall(IERC4626.deposit, (1, address(safe))), 0, OPERATOR, true);
        assertEq(keccak256(abi.encode(state())), before); approve(true, 0); exitAndCheck(true, true, 100e18);
        exitAndCheck(true, false, state().shares); assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles)));
        vm.startPrank(principal); SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))); vm.stopPrank();
        approve(false, 10e18); depositAndCheck(10e18);
    }
}
