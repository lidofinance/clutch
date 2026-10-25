// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IStETH, IWstETH} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

interface IWrapperLedger {
    function sharesOf(address) external view returns (uint256);
    function getTotalShares() external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function getExternalShares() external view returns (uint256);
    function getExternalEther() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @dev ADR 005 exit authority and ADR 011 wrapper scope; legacy-key fork profile.
contract MainnetWstethCoverageTest is ClutchFixture {
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));
    IWrapperLedger internal ledger;
    struct State {
        uint256 safeShares; uint256 backingShares; uint256 wrapped; uint256 supply;
        uint256 allowance; uint256 internalShares; uint256 internalEther; uint256 eth;
    }
    function setUp() public override {
        super.setUp(); ledger = IWrapperLedger(a.steth);
        vm.deal(address(safe), 2 ether);
        execute(false, a.steth, 2 ether, abi.encodeCall(IStETH.submit, (address(0))));
    }
    function state() internal view returns (State memory s) {
        s.safeShares = ledger.sharesOf(address(safe)); s.backingShares = ledger.sharesOf(a.wsteth);
        s.wrapped = IERC20(a.wsteth).balanceOf(address(safe)); s.supply = IWrapperLedger(a.wsteth).totalSupply();
        s.allowance = IERC20(a.steth).allowance(address(safe), a.wsteth);
        s.internalShares = ledger.getTotalShares() - ledger.getExternalShares();
        s.internalEther = ledger.getTotalPooledEther() - ledger.getExternalEther(); s.eth = address(safe).balance;
    }
    function execute(bool emergency, address target, uint256 value, bytes memory data) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(target, value, data, 0, emergency ? EMERGENCY : OPERATOR, true));
    }
    function refused(bool emergency, address target, uint256 value, bytes memory data, uint8 operation, bytes4 error_) internal {
        bytes32 before = keccak256(abi.encode(state()));
        vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (target, value, data, operation, emergency ? EMERGENCY : OPERATOR, true)));
        assertFalse(ok); assertEq(bytes4(reason), error_);
        assertEq(keccak256(abi.encode(state())), before);
    }
    function approve(bool emergency, uint256 amount) internal {
        execute(emergency, a.steth, 0, abi.encodeCall(IERC20.approve, (a.wsteth, amount)));
        assertEq(IERC20(a.steth).allowance(address(safe), a.wsteth), amount);
    }
    function wrapAndCheck(uint256 amount) internal returns (uint256 minted) {
        State memory before = state(); minted = amount * before.internalShares / before.internalEther;
        execute(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (amount)));
        State memory after_ = state();
        assertEq(after_.safeShares, before.safeShares - minted); assertEq(after_.backingShares, before.backingShares + minted);
        assertEq(after_.wrapped, before.wrapped + minted); assertEq(after_.supply, before.supply + minted);
        assertEq(after_.allowance, before.allowance - amount); unchangedRateAndBalances(before, after_);
    }
    function unwrapAndCheck(bool emergency, uint256 amount) internal {
        State memory before = state();
        uint256 tokenAmount = amount * before.internalEther / before.internalShares;
        uint256 transferredShares = tokenAmount * before.internalShares / before.internalEther;
        execute(emergency, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (amount)));
        State memory after_ = state();
        assertEq(after_.safeShares, before.safeShares + transferredShares);
        assertEq(after_.backingShares, before.backingShares - transferredShares);
        assertEq(after_.wrapped, before.wrapped - amount); assertEq(after_.supply, before.supply - amount);
        assertEq(after_.allowance, before.allowance); unchangedRateAndBalances(before, after_);
    }
    function unchangedRateAndBalances(State memory before, State memory after_) internal view {
        assertEq(after_.internalShares, before.internalShares); assertEq(after_.internalEther, before.internalEther);
        assertEq(after_.eth, before.eth);
        assertEq(IERC20(a.steth).balanceOf(address(safe)), after_.safeShares * after_.internalEther / after_.internalShares);
        assertEq(IERC20(a.steth).balanceOf(a.wsteth), after_.backingShares * after_.internalEther / after_.internalShares);
        assertEq(IERC20(a.wsteth).balanceOf(attacker), 0);
    }
    function test_MAIN03_exact_rounding_one_wei_partial_full_and_both_unwrap_roles() public {
        uint256 full = IERC20(a.steth).balanceOf(address(safe));
        uint256[4] memory amounts = [uint256(1), uint256(2), uint256(1 ether), full];
        for (uint256 role; role < 2; ++role) for (uint256 i; i < amounts.length; ++i) {
            uint256 snap = vm.snapshotState(); approve(false, amounts[i]); uint256 minted = wrapAndCheck(amounts[i]);
            assertEq(IERC20(a.steth).allowance(address(safe), a.wsteth), 0);
            if (minted != 0) unwrapAndCheck(role == 1, minted);
            else { assertEq(amounts[i], 1); refused(role == 1, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (0)), 0, FAILED); }
            assertEq(IERC20(a.wsteth).balanceOf(address(safe)), 0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN03_approval_ceiling_zero_wrong_spender_and_emergency_authority() public {
        approve(false, SIZE_STANDIN_STETH - 1);
        uint256[3] memory denied = [SIZE_STANDIN_STETH, SIZE_STANDIN_STETH + 1, type(uint256).max];
        for (uint256 i; i < denied.length; ++i) refused(false, a.steth, 0, abi.encodeCall(IERC20.approve, (a.wsteth, denied[i])), 0, CONDITION);
        refused(false, a.steth, 0, abi.encodeCall(IERC20.approve, (attacker, 1)), 0, CONDITION);
        assertEq(IERC20(a.steth).allowance(address(safe), attacker), 0);
        approve(false, 0); approve(false, 1 ether);
        refused(true, a.steth, 0, abi.encodeCall(IERC20.approve, (a.wsteth, 1)), 0, CONDITION);
        approve(true, 0); refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, FAILED);
        approve(false, 1 ether); wrapAndCheck(1 ether);
    }
    function test_MAIN03_missing_short_approval_balance_excess_max_and_retry() public {
        refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (0)), 0, FAILED);
        refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, FAILED);
        approve(false, 1 ether - 1); refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, FAILED);
        approve(false, SIZE_STANDIN_STETH - 1);
        refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (2 ether + 3)), 0, FAILED);
        refused(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (type(uint256).max)), 0, FAILED);
        uint256 minted = wrapAndCheck(1 ether);
        for (uint256 role; role < 2; ++role) {
            refused(role == 1, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (minted + 1)), 0, FAILED);
            refused(role == 1, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (type(uint256).max)), 0, FAILED);
            refused(role == 1, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (0)), 0, FAILED);
        }
        unwrapAndCheck(true, minted);
    }
    function test_MAIN03_emergency_wrap_value_delegatecall_fallback_and_receiver_variants_refused() public {
        approve(false, 1 ether); vm.deal(address(safe), 1);
        refused(true, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, CONDITION);
        for (uint256 role; role < 2; ++role) {
            refused(role == 1, a.wsteth, 1, abi.encodeCall(IWstETH.unwrap, (1)), 0, CONDITION);
            refused(role == 1, a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (1)), 1, CONDITION);
            refused(role == 1, a.wsteth, 1, "", 0, CONDITION);
            refused(role == 1, a.wsteth, 0, abi.encodeWithSignature("unwrap(uint256,address)", 1, attacker), 0, CONDITION);
        }
    }
    function test_MAIN03_stop_emergency_zero_approval_unwrap_owner_restart() public {
        approve(false, 2 ether); uint256 minted = wrapAndCheck(1 ether);
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 10); address previous = SENTINEL;
        for (uint256 i; i < modules.length && modules[i] != address(roles); ++i) previous = modules[i];
        execute(true, address(safe), 0, abi.encodeCall(ISafe.disableModule, (previous, address(roles))));
        bytes32 before = keccak256(abi.encode(state()));
        vm.prank(operatorSafe); vm.expectRevert("GS104");
        roles.execTransactionWithRole(a.wsteth, 0, abi.encodeCall(IWstETH.unwrap, (minted)), 0, OPERATOR, true);
        assertEq(keccak256(abi.encode(state())), before); approve(true, 0); unwrapAndCheck(true, minted);
        assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles)));
        vm.startPrank(principal); SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))); vm.stopPrank();
        approve(false, 1 ether); minted = wrapAndCheck(1 ether); unwrapAndCheck(false, minted);
    }
}
