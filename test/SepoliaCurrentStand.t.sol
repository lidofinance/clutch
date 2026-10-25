// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {SepoliaStandFixture} from "./utils/SepoliaStandFixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {SepoliaEasyTrack} from "../src/mocks/SepoliaStand.sol";
import {SafeExec, Call, EVMScriptLib} from "../src/exec/SafeExec.sol";
import {CoWOrder, IOrderSigner, ICoWFallback, IComposableCoW} from "../script/sepolia/CoWInterfaces.sol";

// ABI and flags checked against cowprotocol/contracts GPv2Settlement, GPv2Trade and GPv2Signing.
interface IStandSettlement {
    struct Trade {
        uint256 sellTokenIndex;
        uint256 buyTokenIndex;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        uint256 flags;
        uint256 executedAmount;
        bytes signature;
    }
    struct Interaction { address target; uint256 value; bytes callData; }
    function authenticator() external view returns (address);
    function filledAmount(bytes calldata uid) external view returns (uint256);
    function domainSeparator() external view returns (bytes32);
    function preSignature(bytes calldata uid) external view returns (uint256);
    function settle(address[] calldata tokens, uint256[] calldata prices, Trade[] calldata trades,
        Interaction[][3] calldata interactions) external;
}

interface IStandAuthenticator {
    function isSolver(address solver) external view returns (bool);
}

/// @dev Current deployed permissions only. No migration, policy application or deployment.
abstract contract SepoliaCurrentStandFixture is SepoliaStandFixture {
    IStandSettlement internal settlement;
    address internal solver;

    function setUp() public virtual override {
        if (vm.envOr("SEPOLIA_STAND_BLOCK", uint256(0)) == 0) { vm.skip(true); return; }
        super.setUp();
        assertEq(assetOperator, bytes32("asset-operator"));
        assertEq(ordersOperator, bytes32("orders-operator"));
        assertEq(assetEmergency, bytes32("asset-emergency"));
        assertEq(ordersEmergency, bytes32("orders-emergency"));
        settlement = IStandSettlement(d("settlement"));
        solver = vm.envAddress("SEPOLIA_TEST_SOLVER");
        assertTrue(IStandAuthenticator(settlement.authenticator()).isSolver(solver), "Recorded solver must be allowed");
    }

    function permissionDenied(address member, IRoles roles, bytes32 role, address to, bytes memory data,
        uint8 operation, bytes4 expected) internal {
        vm.prank(member);
        (bool ok, bytes memory result) = address(roles).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, operation, role, true))
        );
        assertFalse(ok);
        assertEq(bytes4(result), expected, "Refusal must come from the expected policy check");
    }

    function ownerCall(address safe, address to, bytes memory data) internal {
        vm.startPrank(controller);
        SafeExec.execAsOwner(MockAragonAgent(payable(a("voting"))), ISafe(payable(safe)), to, data);
        vm.stopPrank();
    }

    function uid(CoWOrder.Data memory o) internal view returns (bytes memory) {
        return abi.encodePacked(CoWOrder.digest(o, settlement.domainSeparator()), orders, o.validTo);
    }

    // Test clearing prices and liquidity are synthetic. Solver authorization and settlement are real fork state.
    function settle(CoWOrder.Data memory o, bytes memory signature, bool conditional, uint256 buyAmount) internal {
        address[] memory tokens = new address[](2);
        tokens[0] = o.sellToken; tokens[1] = o.buyToken;
        uint256[] memory prices = new uint256[](2);
        prices[0] = buyAmount; prices[1] = o.sellAmount;
        IStandSettlement.Trade[] memory trades = new IStandSettlement.Trade[](1);
        uint256 flags = (conditional ? 2 : 3) << 5;
        if (o.kind == keccak256("buy")) flags |= 1;
        if (o.partiallyFillable) flags |= 2;
        trades[0] = IStandSettlement.Trade(0, 1, o.receiver, o.sellAmount, o.buyAmount, o.validTo,
            o.appData, o.feeAmount, flags, o.sellAmount, abi.encodePacked(orders, signature));
        IStandSettlement.Interaction[][3] memory interactions;
        for (uint256 i; i < 3; ++i) interactions[i] = new IStandSettlement.Interaction[](0);
        vm.prank(solver);
        settlement.settle(tokens, prices, trades, interactions);
    }

}

contract SepoliaCurrentStandTest is SepoliaCurrentStandFixture {
    function test_role_keys_reject_old_wrong_account_and_non_member() public {
        address weth = token("weth");
        deal(weth, asset, 10); deal(weth, orders, 10);
        bytes memory toOrders = abi.encodeCall(IERC20.transfer, (orders, 1));
        bytes memory toAsset = abi.encodeCall(IERC20.transfer, (asset, 1));
        bytes memory toAgent = abi.encodeCall(IERC20.transfer, (a("agent"), 1));
        bytes4 noMembership = bytes4(keccak256("NoMembership()"));
        permissionDenied(committee, operator, bytes32("operator"), weth, toOrders, 0, noMembership);
        permissionDenied(committee, ordersRoles, bytes32("operator"), weth, toAsset, 0, noMembership);
        permissionDenied(emergency, safety, bytes32("emergency"), weth, toAgent, 0, noMembership);
        permissionDenied(emergency, ordersRoles, bytes32("emergency"), weth, toAgent, 0, noMembership);
        permissionDenied(committee, operator, ordersOperator, weth, toOrders, 0, noMembership);
        permissionDenied(committee, ordersRoles, assetOperator, weth, toAsset, 0, noMembership);
        permissionDenied(emergency, safety, ordersEmergency, weth, toAgent, 0, noMembership);
        permissionDenied(emergency, ordersRoles, assetEmergency, weth, toAgent, 0, noMembership);
        permissionDenied(controller, operator, assetOperator, weth, toOrders, 0, bytes4(keccak256("NotAuthorized(address)")));
        permissionDenied(emergency, firstLossRoles, bytes32("first-loss"), a("usdQueue"),
            abi.encodeWithSignature("redeem(uint256)", 1), 0, bytes4(keccak256("NotAuthorized(address)")));
        permissionDenied(committee, firstLossRoles, bytes32("first-loss-burn"), a("usdShare"),
            abi.encodeWithSignature("burn(uint256)", 1), 0, noMembership);
        exec(committee, operator, assetOperator, weth, toOrders, 0);
        exec(committee, ordersRoles, ordersOperator, weth, toAsset, 0);
        uint256 before = IERC20(weth).balanceOf(a("agent"));
        exec(emergency, safety, assetEmergency, weth, toAgent, 0);
        exec(emergency, ordersRoles, ordersEmergency, weth, toAgent, 0);
        assertEq(IERC20(weth).balanceOf(a("agent")), before + 2);
    }

    function test_usdc_budget_boundary_and_refill() public {
        address usdc = token("usdc");
        uint256 before = IERC20(usdc).balanceOf(orders);
        deal(usdc, asset, 2000e6);
        (uint128 refill, uint128 maximum, uint64 period, uint128 remaining, uint64 timestamp) = operator.allowances(bytes32("orders_usdc"));
        assertEq(refill, 1000e6); assertEq(maximum, 1000e6); assertEq(period, 30 days); assertLe(remaining, maximum);
        uint256 available = remaining;
        if (block.timestamp >= uint256(timestamp) + period) {
            available += uint256(refill) * ((block.timestamp - timestamp) / period);
            if (available > maximum) available = maximum;
        }
        exec(committee, operator, assetOperator, usdc, abi.encodeCall(IERC20.transfer, (orders, available)), 0);
        assertEq(IERC20(usdc).balanceOf(orders), before + available);
        denied(committee, operator, assetOperator, usdc, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        (,,, uint128 balance,) = operator.allowances(bytes32("orders_usdc"));
        assertEq(balance, 0);
        vm.warp(block.timestamp + 30 days);
        exec(committee, operator, assetOperator, usdc, abi.encodeCall(IERC20.transfer, (orders, 1000e6)), 0);
        assertEq(IERC20(usdc).balanceOf(orders), before + available + 1000e6);
    }

    function test_order_boundaries_and_asset_signing_are_restricted() public {
        CoWOrder.Data memory o = order();
        o.validTo = uint32(block.timestamp + 90 days - 1);
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(90 days), 0)), 1);
        assertGt(settlement.preSignature(uid(o)), 0);
        o.sellToken = controller;
        denied(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        o = order(); o.buyToken = controller;
        denied(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        o = order();
        denied(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 101)), 1);
        denied(committee, operator, assetOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        denied(committee, operator, assetOperator, token("weth"),
            abi.encodeCall(IERC20.approve, (d("vaultRelayer"), 1)), 0);
    }

    function test_quote_1723885_zero_fee_order_passes_deployed_policy() public {
        CoWOrder.Data memory o = CoWOrder.Data(
            token("weth"), token("usdc"), asset, 9940004900000000, 384612077, 1792869431,
            bytes32(0), 0, keccak256("sell"), false, keccak256("erc20"), keccak256("erc20")
        );
        exec(
            committee,
            ordersRoles,
            ordersOperator,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(90 days), 100)),
            1
        );
        assertGt(settlement.preSignature(uid(o)), 0);
    }





    function test_governance_executor_restricts_keys_membership_and_administrative_targets() public {
        address weth = token("weth");
        address executor = a("easyTrackExecutor");
        bytes memory revoke = abi.encodeCall(IRoles.revokeFunction, (assetOperator, weth, IERC20.transfer.selector));
        Call[] memory calls = new Call[](1); calls[0] = Call(address(operator), revoke);
        vm.prank(a("easyTrack"));
        MockEVMScriptExecutor(executor).executeEVMScript(EVMScriptLib.buildAsGovernance(operator, bytes32("governance"), calls));
        permissionDenied(committee, operator, assetOperator, weth, abi.encodeCall(IERC20.transfer, (orders, 0)), 0, CONDITION_VIOLATION);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.revokeFunction, (bytes32("operator"), weth, IERC20.transfer.selector)), 0);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.revokeFunction, (ordersOperator, weth, IERC20.transfer.selector)), 0);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.scopeTarget, (assetOperator, asset)), 0);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.allowFunction, (assetOperator, weth, IERC20.approve.selector, uint8(2))), 0);
        bytes32[] memory keys = new bytes32[](1); keys[0] = assetOperator;
        bool[] memory enabled = new bool[](1); enabled[0] = true;
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.assignRoles, (controller, keys, enabled)), 0);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.setAllowance, (bytes32("orders_weth"), 1, 1, 1, uint64(30 days - 1), 0)), 0);
        denied(executor, operator, bytes32("governance"), address(operator),
            abi.encodeCall(IRoles.setAllowance, (bytes32("foreign"), 1, 1, 1, uint64(30 days), 0)), 0);
        permissionDenied(executor, ordersRoles, bytes32("governance"), address(ordersRoles), revoke, 0,
            bytes4(keccak256("NotAuthorized(address)")));
    }

    function test_emergency_recovery_zero_approvals_and_voting_restart() public {
        address weth = token("weth");
        deal(weth, asset, 1 ether); deal(weth, orders, 1 ether);
        deal(token("usdc"), address(settlement), 1000e6);
        SepoliaEasyTrack et = SepoliaEasyTrack(a("easyTrack"));
        uint256 burnId = et.motionsCount();
        bytes memory burnInput = abi.encode(a("usdShare"), 1 ether);
        committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), burnInput)));
        CoWOrder.Data memory o = order();
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        IComposableCoW cow = IComposableCoW(d("composableCow"));
        IComposableCoW.Params memory p = twap(asset, 2);
        exec(committee, ordersRoles, ordersOperator, address(cow),
            abi.encodeCall(IComposableCoW.createWithContext, (p, d("timestampFactory"), bytes(""), true)), 0);
        (address[] memory modules,) = ISafe(payable(asset)).getModulesPaginated(address(1), 10);
        address previous = address(1);
        for (uint256 i; i < modules.length && modules[i] != address(operator); ++i) previous = modules[i];
        exec(emergency, safety, assetEmergency, asset, abi.encodeCall(ISafe.disableModule, (previous, address(operator))), 0);
        vm.prank(committee);
        vm.expectRevert("GS104");
        operator.execTransactionWithRole(weth, 0, abi.encodeCall(IERC20.transfer, (orders, 1)), 0, assetOperator, true);
        address[3] memory targets = [weth, d("orderSigner"), address(cow)];
        for (uint256 i; i < targets.length; ++i) {
            exec(emergency, ordersRoles, ordersEmergency, address(ordersRoles),
                abi.encodeCall(IRoles.revokeTarget, (ordersOperator, targets[i])), 0);
        }
        denied(committee, ordersRoles, ordersOperator, weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        // Revocation stops new calls but does not cancel already signed orders.
        assertGt(settlement.preSignature(uid(o)), 0);
        exec(emergency, ordersRoles, ordersEmergency, d("orderSigner"), abi.encodeCall(IOrderSigner.unsignOrder, (o)), 1);
        exec(emergency, ordersRoles, ordersEmergency, address(cow), abi.encodeCall(IComposableCoW.remove, (keccak256(abi.encode(p)))), 0);
        CoWOrder.Data memory recovery = order(); recovery.receiver = a("agent"); recovery.buyAmount = 10e6;
        exec(emergency, ordersRoles, ordersEmergency, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (recovery, uint32(1 days), 0)), 1);
        uint256 proceedsBefore = IERC20(token("usdc")).balanceOf(a("agent"));
        settle(recovery, "", false, 10e6);
        assertEq(IERC20(token("usdc")).balanceOf(a("agent")), proceedsBefore + 10e6);
        recovery.receiver = asset;
        denied(emergency, ordersRoles, ordersEmergency, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (recovery, uint32(1 days), 0)), 1);
        recovery.receiver = a("agent");
        denied(emergency, ordersRoles, ordersEmergency, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (recovery, uint32(1 days + 1), 0)), 1);
        uint256 agentBefore = IERC20(weth).balanceOf(a("agent"));
        uint256 assetAmount = IERC20(weth).balanceOf(asset);
        uint256 ordersAmount = IERC20(weth).balanceOf(orders);
        exec(emergency, safety, assetEmergency, weth, abi.encodeCall(IERC20.transfer, (a("agent"), assetAmount)), 0);
        exec(emergency, ordersRoles, ordersEmergency, weth, abi.encodeCall(IERC20.transfer, (a("agent"), ordersAmount)), 0);
        assertEq(IERC20(weth).balanceOf(a("agent")), agentBefore + assetAmount + ordersAmount);
        for (uint256 i; i < 2; ++i) {
            address t = token(i == 0 ? "weth" : "usdc");
            exec(emergency, ordersRoles, ordersEmergency, t, abi.encodeCall(IERC20.approve, (d("vaultRelayer"), 0)), 0);
            assertEq(IERC20(t).allowance(orders, d("vaultRelayer")), 0);
            denied(emergency, ordersRoles, ordersEmergency, t, abi.encodeCall(IERC20.approve, (d("vaultRelayer"), 1)), 0);
        }
        denied(emergency, safety, assetEmergency, asset, abi.encodeCall(ISafe.enableModule, (address(operator))), 0);
        denied(emergency, ordersRoles, ordersEmergency, address(ordersRoles),
            abi.encodeCall(IRoles.scopeTarget, (ordersOperator, weth)), 0);
        uint256[] memory ids = new uint256[](1); ids[0] = burnId;
        vm.prank(controller);
        MockAragonAgent(payable(a("voting"))).execute(address(et), 0, abi.encodeCall(SepoliaEasyTrack.cancelMotions, (ids)));
        ownerCall(asset, asset, abi.encodeCall(ISafe.enableModule, (address(operator))));
        for (uint256 i; i < targets.length; ++i) {
            ownerCall(orders, address(ordersRoles), abi.encodeCall(IRoles.scopeTarget, (ordersOperator, targets[i])));
        }
        ownerCall(orders, weth, abi.encodeCall(IERC20.approve, (d("vaultRelayer"), type(uint256).max)));
        deal(weth, asset, 10); deal(weth, orders, 10);
        exec(committee, operator, assetOperator, weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        exec(committee, ordersRoles, ordersOperator, weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        assertEq(settlement.preSignature(uid(o)), 0);
        vm.expectRevert("GPv2: order not presigned"); settle(o, "", false, 1);
        vm.expectRevert(); cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        vm.warp(block.timestamp + et.motionDuration());
        vm.expectRevert("ET: motion not pending"); et.enactMotion(burnId, burnInput);
    }
}

contract SepoliaCoWSettlementTest is SepoliaCurrentStandFixture {
    function test_market_and_limit_settlement_and_cancelled_order_refusal() public {
        deal(token("weth"), orders, 1 ether);
        deal(token("usdc"), address(settlement), 1000e6);
        CoWOrder.Data memory o = order();
        o.buyAmount = 10e6;
        uint256 before = IERC20(o.buyToken).balanceOf(asset);
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        settle(o, "", false, 10e6);
        assertEq(settlement.filledAmount(uid(o)), o.sellAmount);
        assertEq(IERC20(o.buyToken).balanceOf(asset), before + 10e6);
        uint256 sold = IERC20(o.sellToken).balanceOf(orders);
        o.buyAmount = 20e6;
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        vm.expectRevert("GPv2: limit price not respected");
        settle(o, "", false, 19e6);
        assertEq(settlement.filledAmount(uid(o)), 0);
        assertEq(IERC20(o.sellToken).balanceOf(orders), sold);
        settle(o, "", false, 20e6);
        assertEq(IERC20(o.buyToken).balanceOf(asset), before + 30e6);
        o.sellAmount += 1;
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)), 1);
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"), abi.encodeCall(IOrderSigner.unsignOrder, (o)), 1);
        vm.expectRevert("GPv2: order not presigned");
        settle(o, "", false, 20e6);
        assertEq(settlement.filledAmount(uid(o)), 0);
    }

    function test_twap_settles_two_parts_and_cancelled_next_part_fails() public {
        deal(token("weth"), orders, 1 ether);
        deal(token("usdc"), address(settlement), 1000e6);
        IComposableCoW cow = IComposableCoW(d("composableCow"));
        IComposableCoW.Params memory p = twap(asset, 3);
        exec(committee, ordersRoles, ordersOperator, address(cow),
            abi.encodeCall(IComposableCoW.createWithContext, (p, d("timestampFactory"), bytes(""), true)), 0);
        uint256 before = IERC20(token("usdc")).balanceOf(asset);
        for (uint256 i; i < 2; ++i) {
            (CoWOrder.Data memory part, bytes memory sig) = cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
            settle(part, sig, true, 10e6);
            assertEq(settlement.filledAmount(uid(part)), part.sellAmount);
            vm.warp(block.timestamp + 60);
        }
        assertEq(IERC20(token("usdc")).balanceOf(asset), before + 20e6);
        (CoWOrder.Data memory next, bytes memory nextSig) = cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        exec(committee, ordersRoles, ordersOperator, address(cow), abi.encodeCall(IComposableCoW.remove, (keccak256(abi.encode(p)))), 0);
        bytes32 nextDigest = CoWOrder.digest(next, settlement.domainSeparator());
        vm.expectRevert();
        ICoWFallback(orders).isValidSignature(nextDigest, nextSig);
        vm.expectRevert();
        settle(next, nextSig, true, 10e6);
        assertEq(settlement.filledAmount(uid(next)), 0);
    }
}
