// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {SepoliaStandFixture} from "./utils/SepoliaStandFixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {SepoliaShares, SepoliaRedeemQueue, SepoliaEasyTrack} from "../src/mocks/SepoliaStand.sol";
import {
    CoWOrder,
    ICoWSettlement,
    IOrderSigner,
    ICoWFallback,
    IComposableCoW
} from "../script/sepolia/CoWInterfaces.sol";

/// @dev ADR 005/007/008 acceptance probes on a pinned existing stand or a local rehearsal.
contract SepoliaStandTest is SepoliaStandFixture {
    function test_account_graph_and_domain_verifier() public view {
        string[4] memory modifiers = ["operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier"];
        address[4] memory avatars = [asset, asset, orders, firstLoss];
        for (uint256 i; i < modifiers.length; ++i) {
            IRoles roles = IRoles(a(modifiers[i]));
            assertEq(roles.owner(), avatars[i]);
            assertEq(roles.avatar(), avatars[i]);
            assertEq(roles.target(), avatars[i]);
        }
        assertEq(ISafe(payable(committee)).getOwners()[0], controller);
        assertEq(ISafe(payable(emergency)).getOwners()[0], controller);
        assertEq(ISafe(payable(committee)).getThreshold(), 1);
        assertEq(ISafe(payable(emergency)).getThreshold(), 1);
        assertEq(ISafe(payable(asset)).getOwners()[0], a("voting"));
        assertEq(ISafe(payable(orders)).getOwners()[0], a("voting"));
        assertEq(ISafe(payable(firstLoss)).getOwners()[0], a("voting"));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        assertTrue(ISafe(payable(orders)).isModuleEnabled(address(ordersRoles)));
        assertTrue(ISafe(payable(firstLoss)).isModuleEnabled(address(firstLossRoles)));
        bytes32 domain = ICoWSettlement(d("settlement")).domainSeparator();
        assertEq(ICoWFallback(d("fallbackHandler")).domainVerifiers(orders, domain), d("composableCow"));
        assertEq(MockAragonAgent(payable(a("voting"))).owner(), controller);
        assertTrue(a("agent") != a("voting"));
        assertGe(SepoliaShares(a("usdShare")).balanceOf(firstLoss), 10 ether);
        assertGe(SepoliaShares(a("ethShare")).balanceOf(firstLoss), 10 ether);
    }

    function test_funding_budget_and_safe_owner_path() public {
        address weth = token("weth");
        uint256 ordersBefore = IERC20(weth).balanceOf(orders);
        (uint128 refill,,uint64 period,uint128 available,) = operator.allowances(bytes32("orders_weth"));
        assertGt(available, 0);
        deal(weth, asset, uint256(available) + refill);
        committeeCall(
            address(operator),
            abi.encodeCall(
                IRoles.execTransactionWithRole,
                (weth, 0, abi.encodeCall(IERC20.transfer, (orders, available)), 0, assetOperator, true)
            )
        );
        assertEq(IERC20(weth).balanceOf(orders), ordersBefore + available);
        denied(committee, operator, assetOperator, weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        denied(committee, operator, assetOperator, weth, abi.encodeCall(IERC20.transfer, (controller, 1)), 0);
        vm.warp(vm.getBlockTimestamp() + period);
        exec(committee, operator, assetOperator, weth, abi.encodeCall(IERC20.transfer, (orders, refill)), 0);
        assertEq(IERC20(weth).balanceOf(orders), ordersBefore + available + refill);
    }



    function test_typed_order_presign_unsign_and_receivers() public {
        CoWOrder.Data memory o = order();
        exec(
            committee,
            ordersRoles,
            ordersOperator,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)),
            1
        );
        bytes memory uid =
            abi.encodePacked(CoWOrder.digest(o, ICoWSettlement(d("settlement")).domainSeparator()), orders, o.validTo);
        assertGt(ICoWSettlement(d("settlement")).preSignature(uid), 0);
        exec(committee, ordersRoles, ordersOperator, d("orderSigner"), abi.encodeCall(IOrderSigner.unsignOrder, (o)), 1);
        assertEq(ICoWSettlement(d("settlement")).preSignature(uid), 0);
        o.receiver = controller;
        denied(
            committee,
            ordersRoles,
            ordersOperator,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)),
            1
        );
        o.receiver = asset;
        denied(
            committee,
            ordersRoles,
            ordersOperator,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(90 days + 1), 0)),
            1
        );
        denied(committee, ordersRoles, ordersOperator, token("weth"), abi.encodeCall(IERC20.approve, (d("vaultRelayer"), 1)), 0);
    }



    function test_twap_two_parts_signature_and_cancellation() public {
        IComposableCoW cow = IComposableCoW(d("composableCow"));
        IComposableCoW.Params memory p = twap(asset, 2);
        exec(
            committee,
            ordersRoles,
            ordersOperator,
            address(cow),
            abi.encodeCall(IComposableCoW.createWithContext, (p, d("timestampFactory"), bytes(""), true)),
            0
        );
        (CoWOrder.Data memory first, bytes memory sig) =
            cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        bytes32 hash = CoWOrder.digest(first, ICoWSettlement(d("settlement")).domainSeparator());
        assertEq(first.receiver, asset);
        assertEq(ICoWFallback(orders).isValidSignature(hash, sig), bytes4(0x1626ba7e));
        vm.warp(vm.getBlockTimestamp() + 60);
        (CoWOrder.Data memory second,) = cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        assertGt(second.validTo, first.validTo);
        assertTrue(CoWOrder.digest(second, ICoWSettlement(d("settlement")).domainSeparator()) != hash);
        exec(
            emergency,
            ordersRoles,
            ordersEmergency,
            address(cow),
            abi.encodeCall(IComposableCoW.remove, (keccak256(abi.encode(p)))),
            0
        );
        vm.expectRevert();
        cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        denied(
            committee,
            ordersRoles,
            ordersOperator,
            address(cow),
            abi.encodeCall(
                IComposableCoW.createWithContext, (twap(controller, 2), d("timestampFactory"), bytes(""), true)
            ),
            0
        );
        denied(
            committee,
            ordersRoles,
            ordersOperator,
            address(cow),
            abi.encodeCall(IComposableCoW.createWithContext, (twap(asset, 91), d("timestampFactory"), bytes(""), true)),
            0
        );
    }

    function test_first_loss_redeem_claim_both_assets_and_denied_bypass() public {
        for (uint256 i; i < 2; ++i) {
            SepoliaShares share = SepoliaShares(a(i == 0 ? "usdShare" : "ethShare"));
            SepoliaRedeemQueue queue = SepoliaRedeemQueue(a(i == 0 ? "usdQueue" : "ethQueue"));
            uint256 sharesBefore = share.balanceOf(firstLoss);
            uint256 queuedBefore = share.balanceOf(address(queue));
            uint256 agentBefore = queue.asset().balanceOf(a("agent"));
            uint32 timestamp = uint32(block.timestamp);
            exec(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(queue),
                abi.encodeCall(SepoliaRedeemQueue.redeem, (3 ether)),
                0
            );
            assertEq(share.balanceOf(firstLoss), sharesBefore - 3 ether);
            assertEq(share.balanceOf(address(queue)), queuedBefore + 3 ether);
            vm.prank(controller);
            queue.settle(firstLoss, timestamp);
            uint32[] memory stamps = new uint32[](1);
            stamps[0] = timestamp;
            denied(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(queue),
                abi.encodeCall(SepoliaRedeemQueue.claim, (controller, stamps)),
                0
            );
            exec(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(queue),
                abi.encodeCall(SepoliaRedeemQueue.claim, (a("agent"), stamps)),
                0
            );
            assertEq(queue.asset().balanceOf(a("agent")), agentBefore + 3 ether);
            denied(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(share),
                abi.encodeWithSignature("burn(uint256)", 1),
                0
            );
            denied(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(share),
                abi.encodeCall(IERC20.transfer, (controller, 1)),
                0
            );
            denied(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(share),
                abi.encodeCall(IERC20.approve, (controller, 1)),
                0
            );
        }
    }

    function test_burn_motion_wait_objection_and_voting_cancellation() public {
        for (uint256 i; i < 2; ++i) {
            SepoliaShares share = SepoliaShares(a(i == 0 ? "usdShare" : "ethShare"));
            SepoliaEasyTrack et = SepoliaEasyTrack(a("easyTrack"));
            uint256 sharesBefore = share.balanceOf(firstLoss);
            uint256 motionId = et.motionsCount();
            bytes memory input = abi.encode(address(share), 2 ether);
            committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
            vm.expectRevert("ET: objection period not passed");
            et.enactMotion(motionId, input);
            vm.warp(vm.getBlockTimestamp() + et.motionDuration());
            et.enactMotion(motionId, input);
            assertEq(share.balanceOf(firstLoss), sharesBefore - 2 ether);
            committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
            vm.prank(controller);
            et.object(motionId + 1);
            vm.warp(vm.getBlockTimestamp() + et.motionDuration());
            vm.expectRevert("ET: motion not pending");
            et.enactMotion(motionId + 1, input);
            committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
            uint256[] memory ids = new uint256[](1);
            ids[0] = motionId + 2;
            vm.prank(controller);
            MockAragonAgent(payable(a("voting")))
                .execute(address(et), 0, abi.encodeCall(SepoliaEasyTrack.cancelMotions, (ids)));
            vm.warp(vm.getBlockTimestamp() + et.motionDuration());
            vm.expectRevert("ET: motion not pending");
            et.enactMotion(motionId + 2, input);
            assertEq(share.balanceOf(firstLoss), sharesBefore - 2 ether);
        }
    }

    function test_emergency_stops_asset_operator_but_cannot_restart() public {
        (address[] memory modules,) = ISafe(payable(asset)).getModulesPaginated(address(1), 10);
        address previous = address(1);
        for (uint256 i; i < modules.length && modules[i] != address(operator); ++i) {
            previous = modules[i];
        }
        exec(emergency, safety, assetEmergency, asset, abi.encodeCall(ISafe.disableModule, (previous, address(operator))), 0);
        assertFalse(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        denied(emergency, safety, assetEmergency, asset, abi.encodeCall(ISafe.enableModule, (address(operator))), 0);
        // The Asset switch leaves Orders and First-loss independent (ADR 005).
        assertTrue(ISafe(payable(orders)).isModuleEnabled(address(ordersRoles)));
        assertTrue(ISafe(payable(firstLoss)).isModuleEnabled(address(firstLossRoles)));
    }
}
