// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IDaiUsds} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

interface IConverterDependencies {
    function dai() external view returns (address);
    function usds() external view returns (address);
    function daiJoin() external view returns (address);
    function usdsJoin() external view returns (address);
}
interface IConverterJoin {
    function vat() external view returns (address);
    function live() external view returns (uint256);
    function wards(address) external view returns (uint256);
    function cage() external;
}
interface IConverterToken {
    function totalSupply() external view returns (uint256);
    function wards(address) external view returns (uint256);
    function deny(address) external;
    function rely(address) external;
}
interface IConverterChainlog { function getAddress(bytes32) external view returns (address); }
interface IConverterVat { function dai(address) external view returns (uint256); }

/// @dev ADR 011 fixed 1:1 route and ADR 005 exit authority; legacy-key fork profile.
contract MainnetConverterCoverageTest is ClutchFixture {
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));
    address internal daiJoin; address internal usdsJoin; IConverterVat internal vat;
    struct State {
        uint256 dai; uint256 usds; uint256 daiSupply; uint256 usdsSupply;
        uint256 daiAllowance; uint256 usdsAllowance; uint256 converterDai; uint256 converterUsds;
        uint256 daiJoinRad; uint256 usdsJoinRad; uint256 converterRad;
    }
    function setUp() public override {
        super.setUp(); IConverterDependencies converter = IConverterDependencies(a.daiUsds);
        assertEq(converter.dai(), a.dai); assertEq(converter.usds(), a.usds);
        daiJoin = converter.daiJoin(); usdsJoin = converter.usdsJoin();
        assertEq(daiJoin, 0x9759A6Ac90977b93B58547b4A71c78317f391A28);
        assertEq(usdsJoin, 0x3C0f895007CA717Aa01c8693e59DF1e8C3777FEB);
        vat = IConverterVat(IConverterJoin(daiJoin).vat());
        assertEq(address(vat), IConverterJoin(usdsJoin).vat());
        deal(a.dai, address(safe), 1000e18); deal(a.usds, address(safe), 1000e18);
    }
    function state() internal view returns (State memory s) {
        s.dai = IERC20(a.dai).balanceOf(address(safe)); s.usds = IERC20(a.usds).balanceOf(address(safe));
        s.daiSupply = IConverterToken(a.dai).totalSupply(); s.usdsSupply = IConverterToken(a.usds).totalSupply();
        s.daiAllowance = IERC20(a.dai).allowance(address(safe), a.daiUsds);
        s.usdsAllowance = IERC20(a.usds).allowance(address(safe), a.daiUsds);
        s.converterDai = IERC20(a.dai).balanceOf(a.daiUsds); s.converterUsds = IERC20(a.usds).balanceOf(a.daiUsds);
        s.daiJoinRad = vat.dai(daiJoin); s.usdsJoinRad = vat.dai(usdsJoin); s.converterRad = vat.dai(a.daiUsds);
    }
    function data(bool reverse, address receiver, uint256 amount) internal pure returns (bytes memory) {
        return reverse ? abi.encodeCall(IDaiUsds.usdsToDai, (receiver, amount)) : abi.encodeCall(IDaiUsds.daiToUsds, (receiver, amount));
    }
    function execute(bool emergency, address target, bytes memory callData) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(target, 0, callData, 0, emergency ? EMERGENCY : OPERATOR, true));
    }
    function refused(bool emergency, address target, uint256 value, bytes memory callData, uint8 operation, bytes4 error_) internal {
        bytes32 before = keccak256(abi.encode(state()));
        vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (target, value, callData, operation, emergency ? EMERGENCY : OPERATOR, true)));
        assertFalse(ok); assertEq(bytes4(reason), error_); assertEq(keccak256(abi.encode(state())), before);
    }
    function approve(bool reverse, bool emergency, uint256 amount) internal {
        address token = reverse ? a.usds : a.dai;
        execute(emergency, token, abi.encodeCall(IERC20.approve, (a.daiUsds, amount)));
        assertEq(IERC20(token).allowance(address(safe), a.daiUsds), amount);
    }
    function convertAndCheck(bool reverse, uint256 amount) internal {
        State memory before = state(); vm.recordLogs(); execute(false, a.daiUsds, data(reverse, address(safe), amount));
        State memory after_ = state(); uint256 rad = amount * 1e27;
        assertEq(after_.dai, reverse ? before.dai + amount : before.dai - amount);
        assertEq(after_.usds, reverse ? before.usds - amount : before.usds + amount);
        assertEq(after_.daiSupply, reverse ? before.daiSupply + amount : before.daiSupply - amount);
        assertEq(after_.usdsSupply, reverse ? before.usdsSupply - amount : before.usdsSupply + amount);
        assertEq(after_.daiAllowance, reverse ? before.daiAllowance : before.daiAllowance - amount);
        assertEq(after_.usdsAllowance, reverse ? before.usdsAllowance - amount : before.usdsAllowance);
        assertEq(after_.daiJoinRad, reverse ? before.daiJoinRad + rad : before.daiJoinRad - rad);
        assertEq(after_.usdsJoinRad, reverse ? before.usdsJoinRad - rad : before.usdsJoinRad + rad);
        assertEq(after_.converterRad, before.converterRad); assertEq(after_.converterDai, before.converterDai); assertEq(after_.converterUsds, before.converterUsds);
        assertEq(IERC20(a.dai).balanceOf(attacker), 0); assertEq(IERC20(a.usds).balanceOf(attacker), 0);
        Vm.Log[] memory logs = vm.getRecordedLogs(); uint256 count;
        bytes32 eventId = keccak256(bytes(reverse ? "UsdsToDai(address,address,uint256)" : "DaiToUsds(address,address,uint256)"));
        for (uint256 i; i < logs.length; ++i) if (logs[i].emitter == a.daiUsds && logs[i].topics[0] == eventId) {
            assertEq(logs[i].topics.length, 3); assertEq(logs[i].topics[1], bytes32(uint256(uint160(address(safe)))));
            assertEq(logs[i].topics[2], logs[i].topics[1]); assertEq(logs[i].data, abi.encode(amount)); ++count;
        }
        assertEq(count, 1);
    }
    function test_MAIN04_both_directions_zero_one_partial_full_and_largest_single_approval() public {
        uint256[5] memory amounts = [uint256(0), uint256(1), uint256(17e18 + 1), uint256(1000e18), SIZE_STANDIN_USD - 1];
        for (uint256 direction; direction < 2; ++direction) for (uint256 i; i < amounts.length; ++i) {
            uint256 snap = vm.snapshotState(); bool reverse = direction == 1;
            deal(reverse ? a.usds : a.dai, address(safe), amounts[i]); approve(reverse, false, amounts[i]);
            convertAndCheck(reverse, amounts[i]); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN04_both_approval_ceilings_zero_wrong_spender_and_emergency_zero() public {
        for (uint256 direction; direction < 2; ++direction) {
            bool reverse = direction == 1; address token = reverse ? a.usds : a.dai;
            approve(reverse, false, SIZE_STANDIN_USD - 1);
            uint256[3] memory denied = [SIZE_STANDIN_USD, SIZE_STANDIN_USD + 1, type(uint256).max];
            for (uint256 i; i < denied.length; ++i) refused(false, token, 0, abi.encodeCall(IERC20.approve, (a.daiUsds, denied[i])), 0, CONDITION);
            refused(false, token, 0, abi.encodeCall(IERC20.approve, (attacker, 1)), 0, CONDITION);
            assertEq(IERC20(token).allowance(address(safe), attacker), 0);
            approve(reverse, false, 0); approve(reverse, false, 1);
            refused(true, token, 0, abi.encodeCall(IERC20.approve, (a.daiUsds, 1)), 0, CONDITION); approve(reverse, true, 0);
        }
    }
    function test_MAIN04_both_directions_missing_short_approval_balance_excess_max_and_retry() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snap = vm.snapshotState(); bool reverse = direction == 1;
            refused(false, a.daiUsds, 0, data(reverse, address(safe), 1 ether), 0, FAILED);
            approve(reverse, false, 1 ether - 1); refused(false, a.daiUsds, 0, data(reverse, address(safe), 1 ether), 0, FAILED);
            approve(reverse, false, SIZE_STANDIN_USD - 1);
            refused(false, a.daiUsds, 0, data(reverse, address(safe), 1000e18 + 1), 0, FAILED);
            refused(false, a.daiUsds, 0, data(reverse, address(safe), type(uint256).max), 0, FAILED);
            convertAndCheck(reverse, 1000e18); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN04_both_directions_wrong_receivers_value_delegatecall_and_emergency_conversion_refused() public {
        vm.deal(address(safe), 1);
        for (uint256 direction; direction < 2; ++direction) {
            bool reverse = direction == 1; approve(reverse, false, 1 ether);
            refused(false, a.daiUsds, 0, data(reverse, attacker, 1 ether), 0, CONDITION);
            refused(false, a.daiUsds, 0, data(reverse, address(agent), 1 ether), 0, CONDITION);
            refused(false, a.daiUsds, 1, data(reverse, address(safe), 1 ether), 0, CONDITION);
            refused(false, a.daiUsds, 0, data(reverse, address(safe), 1 ether), 1, CONDITION);
            refused(true, a.daiUsds, 0, data(reverse, address(safe), 1 ether), 0, CONDITION);
        }
    }
    function test_MAIN04_stop_emergency_zero_and_return_both_tokens_owner_restart() public {
        approve(false, false, 100e18); convertAndCheck(false, 40e18); approve(true, true, 0); approve(false, true, 0);
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 10); address previous = SENTINEL;
        for (uint256 i; i < modules.length && modules[i] != address(roles); ++i) previous = modules[i];
        execute(true, address(safe), abi.encodeCall(ISafe.disableModule, (previous, address(roles))));
        bytes32 before = keccak256(abi.encode(state())); vm.prank(operatorSafe); vm.expectRevert("GS104");
        roles.execTransactionWithRole(a.daiUsds, 0, data(false, address(safe), 1), 0, OPERATOR, true);
        assertEq(keccak256(abi.encode(state())), before);
        address[2] memory tokens = [a.dai, a.usds];
        for (uint256 i; i < tokens.length; ++i) {
            uint256 amount = IERC20(tokens[i]).balanceOf(address(safe)); uint256 treasury = IERC20(tokens[i]).balanceOf(address(agent));
            execute(true, tokens[i], abi.encodeCall(IERC20.transfer, (address(agent), amount)));
            assertEq(IERC20(tokens[i]).balanceOf(address(safe)), 0); assertEq(IERC20(tokens[i]).balanceOf(address(agent)), treasury + amount);
        }
        assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles)));
        vm.startPrank(principal); SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))); vm.stopPrank();
        deal(a.dai, address(safe), 1 ether); approve(false, false, 1 ether); convertAndCheck(false, 1 ether);
    }
    function test_MAIN04_dai_join_cage_refuses_known_actors_without_balance_changes() public {
        IConverterChainlog chainlog = IConverterChainlog(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);
        address[5] memory callers = [address(safe), operatorSafe, emergencySafe,
            chainlog.getAddress(bytes32("MCD_PAUSE_PROXY")), chainlog.getAddress(bytes32("MCD_END"))];
        bytes32 before = keccak256(abi.encode(state())); assertEq(IConverterJoin(daiJoin).live(), 1);
        for (uint256 i; i < callers.length; ++i) {
            assertEq(IConverterJoin(daiJoin).wards(callers[i]), 0);
            vm.prank(callers[i]); vm.expectRevert("DaiJoin/not-authorized"); IConverterJoin(daiJoin).cage();
            assertEq(IConverterJoin(daiJoin).live(), 1); assertEq(keccak256(abi.encode(state())), before);
        }
        approve(false, false, 1 ether); convertAndCheck(false, 1 ether);
        approve(true, false, 1 ether); convertAndCheck(true, 1 ether);
    }
    function test_MAIN04_usds_join_mint_permission_loss_reverse_exit_and_real_rely_retry() public {
        address governor = IConverterChainlog(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F).getAddress(bytes32("MCD_PAUSE_PROXY"));
        assertEq(IConverterToken(a.usds).wards(governor), 1); assertEq(IConverterToken(a.usds).wards(usdsJoin), 1);
        approve(false, false, 1 ether); approve(true, false, 1 ether);
        vm.prank(governor); IConverterToken(a.usds).deny(usdsJoin); assertEq(IConverterToken(a.usds).wards(usdsJoin), 0);
        refused(false, a.daiUsds, 0, data(false, address(safe), 1 ether), 0, FAILED);
        vm.prank(address(safe)); vm.expectRevert("Usds/not-authorized"); IDaiUsds(a.daiUsds).daiToUsds(address(safe), 1 ether);
        convertAndCheck(true, 1 ether);
        vm.prank(governor); IConverterToken(a.usds).rely(usdsJoin); assertEq(IConverterToken(a.usds).wards(usdsJoin), 1);
        convertAndCheck(false, 1 ether);
    }

}
