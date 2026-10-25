// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IStETH} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

interface IMainnetLido {
    function implementation() external view returns (address);
    function getContractVersion() external view returns (uint256);
    function sharesOf(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function getTotalShares() external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function getExternalShares() external view returns (uint256);
    function getExternalEther() external view returns (uint256);
    function getBufferedEther() external view returns (uint256);
    function getCurrentStakeLimit() external view returns (uint256);
    function isStakingPaused() external view returns (bool);
    function pauseStaking() external;
    function resumeStaking() external;
}
interface IStakingAcl {
    function getPermissionManager(address, bytes32) external view returns (address);
    function hasPermission(address, address, bytes32) external view returns (bool);
    function grantPermission(address, address, bytes32) external;
}

/// @dev Real v4 Lido; committed legacy-key Clutch profile, not production signer coverage.
contract MainnetLidoCoverageTest is ClutchFixture {
    IMainnetLido internal ledger;
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));
    address internal constant ACL = 0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb;
    address internal constant MANAGER = 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c;
    struct State {
        uint256 eth; uint256 nativeLido; uint256 buffer; uint256 shares; uint256 total;
        uint256 externalShares; uint256 internalShares; uint256 internalEther; uint256 limit;
    }
    function setUp() public override {
        super.setUp(); ledger = IMainnetLido(a.steth);
        assertEq(ledger.getContractVersion(), 4);
        assertEq(ledger.implementation(), 0x028271E30a695c0527A0C50cA30603feD004cDb0);
        assertGt(ledger.getExternalShares(), 0, "Pin must exercise external-share accounting");
    }
    function state() internal view returns (State memory s) {
        s.eth = address(safe).balance; s.nativeLido = a.steth.balance; s.buffer = ledger.getBufferedEther();
        s.shares = ledger.sharesOf(address(safe)); s.total = ledger.getTotalShares();
        s.externalShares = ledger.getExternalShares(); s.internalShares = s.total - s.externalShares;
        s.internalEther = ledger.getTotalPooledEther() - ledger.getExternalEther(); s.limit = ledger.getCurrentStakeLimit();
    }
    function execute(bool emergency, uint256 value, bytes memory data, uint8 operation) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(a.steth, value, data, operation, emergency ? EMERGENCY : OPERATOR, true));
    }
    function refused(bool emergency, uint256 value, bytes memory data, uint8 operation, bytes4 error_) internal {
        bytes32 before = keccak256(abi.encode(state()));
        vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (a.steth, value, data, operation, emergency ? EMERGENCY : OPERATOR, true)));
        assertFalse(ok); assertEq(bytes4(reason), error_);
        if (error_ == bytes4(0)) assertEq(reason.length, 0);
        assertEq(keccak256(abi.encode(state())), before);
    }
    function submitAndCheck(bool emergency, uint256 value) internal {
        State memory before = state(); uint256 observerShares = ledger.sharesOf(a.wsteth);
        uint256 expectedShares = value * before.internalShares / before.internalEther;
        uint256 internalAfter = before.internalEther + value;
        uint256 sharesAfter = before.internalShares + expectedShares;
        vm.recordLogs(); execute(emergency, value, abi.encodeCall(IStETH.submit, (address(0))), 0);
        State memory after_ = state();
        assertEq(after_.eth, before.eth - value); assertEq(after_.nativeLido, before.nativeLido + value);
        assertEq(after_.buffer, before.buffer + value); assertEq(after_.shares, before.shares + expectedShares);
        assertEq(after_.total, before.total + expectedShares); assertEq(after_.externalShares, before.externalShares);
        assertEq(after_.internalShares, sharesAfter); assertEq(after_.internalEther, internalAfter);
        assertEq(ledger.getExternalEther(), before.externalShares * internalAfter / sharesAfter);
        assertEq(ledger.balanceOf(address(safe)), after_.shares * internalAfter / sharesAfter);
        assertEq(ledger.sharesOf(a.wsteth), observerShares);
        assertEq(ledger.balanceOf(a.wsteth), observerShares * internalAfter / sharesAfter);
        assertEq(after_.limit, before.limit - value);
        Vm.Log[] memory logs = vm.getRecordedLogs(); uint256 count;
        for (uint256 i; i < logs.length; ++i) if (logs[i].emitter == a.steth && logs[i].topics[0] == keccak256("Submitted(address,uint256,address)")) {
            assertEq(logs[i].topics[1], bytes32(uint256(uint160(address(safe)))));
            assertEq(logs[i].data, abi.encode(value, address(0))); ++count;
        }
        assertEq(count, 1);
    }
    function test_MAIN02_both_roles_exact_internal_share_math_one_wei_and_full_balance() public {
        uint256[3] memory amounts = [uint256(1), uint256(1 ether), uint256(2 ether)];
        for (uint256 role; role < 2; ++role) for (uint256 i; i < amounts.length; ++i) {
            uint256 snap = vm.snapshotState(); vm.deal(address(safe), 2 ether);
            submitAndCheck(role == 1, amounts[i]); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN02_zero_and_missing_eth_fail_without_shares_or_buffer_changes() public {
        vm.deal(address(safe), 0);
        for (uint256 role; role < 2; ++role) {
            refused(role == 1, 0, abi.encodeCall(IStETH.submit, (address(0))), 0, FAILED);
            refused(role == 1, 1, abi.encodeCall(IStETH.submit, (address(0))), 0, FAILED);
        }
        vm.prank(address(safe)); vm.expectRevert("ZERO_DEPOSIT"); IStETH(a.steth).submit(address(0));
        vm.deal(address(safe), 1 ether); submitAndCheck(false, 1 ether);
    }
    function test_MAIN02_referral_delegatecall_fallback_short_data_and_admin_are_refused() public {
        vm.deal(address(safe), 2 ether);
        for (uint256 role; role < 2; ++role) {
            bool emergency = role == 1;
            refused(emergency, 1 ether, abi.encodeCall(IStETH.submit, (attacker)), 0, CONDITION);
            refused(emergency, 1 ether, abi.encodeCall(IStETH.submit, (address(0))), 1, CONDITION);
            refused(emergency, 1, "", 0, CONDITION);
            refused(emergency, 1, abi.encodePacked(IStETH.submit.selector), 0, bytes4(0));
            refused(emergency, 0, abi.encodeCall(IMainnetLido.pauseStaking, ()), 0, CONDITION);
            refused(emergency, 0, abi.encodeCall(IMainnetLido.resumeStaking, ()), 0, CONDITION);
        }
    }
    function test_MAIN02_real_acl_pause_preserves_state_resume_retries_both_roles() public {
        IStakingAcl acl = IStakingAcl(ACL); bytes32 pause = keccak256("STAKING_PAUSE_ROLE"); bytes32 control = keccak256("STAKING_CONTROL_ROLE");
        assertEq(acl.getPermissionManager(a.steth, pause), MANAGER); assertEq(acl.getPermissionManager(a.steth, control), MANAGER);
        assertFalse(acl.hasPermission(principal, a.steth, pause)); assertFalse(acl.hasPermission(principal, a.steth, control));
        // Fork-only prerequisite: exercise the real manager/ACL route, not a storage or mocked pause.
        vm.startPrank(MANAGER); acl.grantPermission(principal, a.steth, pause); acl.grantPermission(principal, a.steth, control); vm.stopPrank();
        assertTrue(acl.hasPermission(principal, a.steth, pause)); assertTrue(acl.hasPermission(principal, a.steth, control));
        vm.prank(principal); ledger.pauseStaking(); assertTrue(ledger.isStakingPaused());
        vm.deal(address(safe), 2 ether);
        for (uint256 role; role < 2; ++role) refused(role == 1, 1 ether, abi.encodeCall(IStETH.submit, (address(0))), 0, FAILED);
        vm.prank(address(safe)); vm.expectRevert("STAKING_PAUSED"); IStETH(a.steth).submit{value: 1 ether}(address(0));
        vm.prank(principal); ledger.resumeStaking(); assertFalse(ledger.isStakingPaused());
        submitAndCheck(false, 1 ether); submitAndCheck(true, 1 ether);
    }
    function test_MAIN02_stake_limit_plus_one_exact_exhaustion_and_next_block_retry() public {
        uint256 limit = ledger.getCurrentStakeLimit(); assertGt(limit, 1 ether); assertLt(limit, type(uint128).max);
        vm.deal(address(safe), limit + 1);
        refused(false, limit + 1, abi.encodeCall(IStETH.submit, (address(0))), 0, FAILED);
        vm.prank(address(safe)); vm.expectRevert("STAKE_LIMIT"); IStETH(a.steth).submit{value: limit + 1}(address(0));
        submitAndCheck(false, limit); assertEq(ledger.getCurrentStakeLimit(), 0);
        refused(true, 1, abi.encodeCall(IStETH.submit, (address(0))), 0, FAILED);
        vm.roll(block.number + 1); assertGt(ledger.getCurrentStakeLimit(), 0);
        submitAndCheck(true, 1);
    }
    function test_MAIN02_asset_switch_preserves_emergency_staking_and_owner_restart() public {
        vm.deal(address(safe), 3 ether); submitAndCheck(false, 1 ether);
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 10); address previous = SENTINEL;
        for (uint256 i; i < modules.length && modules[i] != address(roles); ++i) previous = modules[i];
        vm.prank(emergencySafe); assertTrue(safety.execTransactionWithRole(address(safe), 0,
            abi.encodeCall(ISafe.disableModule, (previous, address(roles))), 0, EMERGENCY, true));
        bytes32 before = keccak256(abi.encode(state()));
        vm.prank(operatorSafe); vm.expectRevert("GS104"); roles.execTransactionWithRole(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (address(0))), 0, OPERATOR, true);
        assertEq(keccak256(abi.encode(state())), before); submitAndCheck(true, 1 ether);
        vm.startPrank(principal); SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))); vm.stopPrank();
        submitAndCheck(false, 1 ether); assertEq(address(safe).balance, 0);
    }
}
