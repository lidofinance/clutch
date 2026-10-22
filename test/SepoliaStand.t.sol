// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
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

/// @dev ADR 005/007/008 acceptance probes against the stand created on a local fork.
contract SepoliaStandTest is Test {
    string internal manifest;
    address internal controller;
    address internal committee;
    address internal emergency;
    address internal asset;
    address internal orders;
    address internal firstLoss;
    IRoles internal operator;
    IRoles internal safety;
    IRoles internal ordersRoles;
    IRoles internal firstLossRoles;
    bytes32 internal constant OP = bytes32("operator");
    bytes32 internal constant EM = bytes32("emergency");
    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;

    function a(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".", name));
    }

    function d(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".dependencies.contracts.", name, ".address"));
    }

    function token(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".dependencies.tokens.", name, ".address"));
    }

    function setUp() public {
        string memory rpc = vm.envOr("SEPOLIA_REHEARSAL_RPC", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        require(keccak256(bytes(rpc)) == keccak256("http://127.0.0.1:8547"), "Local rehearsal only");
        vm.createSelectFork(rpc);
        manifest = vm.readFile(vm.envString("SEPOLIA_MANIFEST"));
        controller = a("controller");
        committee = a("operatorSafe");
        emergency = a("emergencySafe");
        asset = a("assetSafe");
        orders = a("ordersSafe");
        firstLoss = a("firstLossSafe");
        operator = IRoles(a("operatorModifier"));
        safety = IRoles(a("safetyModifier"));
        ordersRoles = IRoles(a("ordersModifier"));
        firstLossRoles = IRoles(a("firstLossModifier"));
    }

    function exec(address member, IRoles roles, bytes32 role, address to, bytes memory data, uint8 operation) internal {
        vm.prank(member);
        assertTrue(roles.execTransactionWithRole(to, 0, data, operation, role, true));
    }

    function denied(address member, IRoles roles, bytes32 role, address to, bytes memory data, uint8 operation)
        internal
    {
        vm.prank(member);
        (bool ok, bytes memory ret) =
            address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, operation, role, true)));
        assertFalse(ok, "permission must reject");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "must reject in Roles");
    }

    function committeeCall(address to, bytes memory data) internal {
        bytes memory signature = abi.encodePacked(bytes32(uint256(uint160(controller))), bytes32(0), uint8(1));
        vm.prank(controller);
        assertTrue(
            ISafe(payable(committee))
                .execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature)
        );
    }

    function test_account_graph_and_domain_verifier() public view {
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
        assertEq(SepoliaShares(a("usdShare")).balanceOf(firstLoss), 10 ether);
        assertEq(SepoliaShares(a("ethShare")).balanceOf(firstLoss), 10 ether);
        assertEq(IERC20(token("weth")).balanceOf(asset), 0.02 ether);
    }

    function test_funding_budget_and_safe_owner_path() public {
        address weth = token("weth");
        deal(weth, asset, 2 ether);
        committeeCall(
            address(operator),
            abi.encodeCall(
                IRoles.execTransactionWithRole,
                (weth, 0, abi.encodeCall(IERC20.transfer, (orders, 1 ether)), 0, OP, true)
            )
        );
        assertEq(IERC20(weth).balanceOf(orders), 1 ether);
        denied(committee, operator, OP, weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        denied(committee, operator, OP, weth, abi.encodeCall(IERC20.transfer, (controller, 1)), 0);
        vm.warp(vm.getBlockTimestamp() + 30 days);
        exec(committee, operator, OP, weth, abi.encodeCall(IERC20.transfer, (orders, 1 ether)), 0);
        assertEq(IERC20(weth).balanceOf(orders), 2 ether);
    }

    function order() internal view returns (CoWOrder.Data memory) {
        return CoWOrder.Data(
            token("weth"),
            token("usdc"),
            asset,
            0.01 ether,
            1,
            uint32(block.timestamp + 1 hours - 1),
            bytes32(0),
            0,
            keccak256("sell"),
            false,
            keccak256("erc20"),
            keccak256("erc20")
        );
    }

    function test_typed_order_presign_unsign_and_receivers() public {
        CoWOrder.Data memory o = order();
        exec(
            committee,
            ordersRoles,
            OP,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)),
            1
        );
        bytes memory uid =
            abi.encodePacked(CoWOrder.digest(o, ICoWSettlement(d("settlement")).domainSeparator()), orders, o.validTo);
        assertGt(ICoWSettlement(d("settlement")).preSignature(uid), 0);
        exec(committee, ordersRoles, OP, d("orderSigner"), abi.encodeCall(IOrderSigner.unsignOrder, (o)), 1);
        assertEq(ICoWSettlement(d("settlement")).preSignature(uid), 0);
        o.receiver = controller;
        denied(
            committee,
            ordersRoles,
            OP,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(1 hours), 0)),
            1
        );
        o.receiver = asset;
        denied(
            committee,
            ordersRoles,
            OP,
            d("orderSigner"),
            abi.encodeCall(IOrderSigner.signOrder, (o, uint32(90 days + 1), 0)),
            1
        );
        denied(committee, ordersRoles, OP, token("weth"), abi.encodeCall(IERC20.approve, (d("vaultRelayer"), 1)), 0);
    }

    function twap(address receiver, uint256 count) internal view returns (IComposableCoW.Params memory) {
        return IComposableCoW.Params(
            d("twap"),
            bytes32(uint256(1)),
            abi.encode(
                token("weth"),
                token("usdc"),
                receiver,
                uint256(0.005 ether),
                uint256(1),
                uint256(0),
                count,
                uint256(60),
                uint256(0),
                bytes32(0)
            )
        );
    }

    function test_twap_two_parts_signature_and_cancellation() public {
        IComposableCoW cow = IComposableCoW(d("composableCow"));
        IComposableCoW.Params memory p = twap(asset, 2);
        exec(
            committee,
            ordersRoles,
            OP,
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
            EM,
            address(cow),
            abi.encodeCall(IComposableCoW.remove, (keccak256(abi.encode(p)))),
            0
        );
        vm.expectRevert();
        cow.getTradeableOrderWithSignature(orders, p, "", new bytes32[](0));
        denied(
            committee,
            ordersRoles,
            OP,
            address(cow),
            abi.encodeCall(
                IComposableCoW.createWithContext, (twap(controller, 2), d("timestampFactory"), bytes(""), true)
            ),
            0
        );
        denied(
            committee,
            ordersRoles,
            OP,
            address(cow),
            abi.encodeCall(IComposableCoW.createWithContext, (twap(asset, 91), d("timestampFactory"), bytes(""), true)),
            0
        );
    }

    function test_first_loss_redeem_claim_both_assets_and_denied_bypass() public {
        for (uint256 i; i < 2; ++i) {
            SepoliaShares share = SepoliaShares(a(i == 0 ? "usdShare" : "ethShare"));
            SepoliaRedeemQueue queue = SepoliaRedeemQueue(a(i == 0 ? "usdQueue" : "ethQueue"));
            uint32 timestamp = uint32(block.timestamp);
            exec(
                committee,
                firstLossRoles,
                bytes32("first-loss"),
                address(queue),
                abi.encodeCall(SepoliaRedeemQueue.redeem, (3 ether)),
                0
            );
            assertEq(share.balanceOf(firstLoss), 7 ether);
            assertEq(share.balanceOf(address(queue)), 3 ether);
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
            assertEq(queue.asset().balanceOf(a("agent")), 3 ether);
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
        SepoliaShares share = SepoliaShares(a("usdShare"));
        SepoliaEasyTrack et = SepoliaEasyTrack(a("easyTrack"));
        bytes memory input = abi.encode(address(share), 2 ether);
        committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
        vm.expectRevert("ET: objection period not passed");
        et.enactMotion(0, input);
        vm.warp(vm.getBlockTimestamp() + et.motionDuration());
        et.enactMotion(0, input);
        assertEq(share.balanceOf(firstLoss), 8 ether);
        committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
        vm.prank(controller);
        et.object(1);
        vm.warp(vm.getBlockTimestamp() + et.motionDuration());
        vm.expectRevert("ET: motion not pending");
        et.enactMotion(1, input);
        committeeCall(address(et), abi.encodeCall(et.createMotion, (a("burnFactory"), input)));
        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;
        vm.prank(controller);
        MockAragonAgent(payable(a("voting")))
            .execute(address(et), 0, abi.encodeCall(SepoliaEasyTrack.cancelMotions, (ids)));
        vm.warp(vm.getBlockTimestamp() + et.motionDuration());
        vm.expectRevert("ET: motion not pending");
        et.enactMotion(2, input);
        assertEq(share.balanceOf(firstLoss), 8 ether);
    }

    function test_emergency_stops_asset_operator_but_cannot_restart() public {
        (address[] memory modules,) = ISafe(payable(asset)).getModulesPaginated(address(1), 10);
        address previous = address(1);
        for (uint256 i; i < modules.length && modules[i] != address(operator); ++i) {
            previous = modules[i];
        }
        exec(emergency, safety, EM, asset, abi.encodeCall(ISafe.disableModule, (previous, address(operator))), 0);
        assertFalse(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        denied(emergency, safety, EM, asset, abi.encodeCall(ISafe.enableModule, (address(operator))), 0);
        // The Asset switch leaves Orders and First-loss independent (ADR 005).
        assertTrue(ISafe(payable(orders)).isModuleEnabled(address(ordersRoles)));
        assertTrue(ISafe(payable(firstLoss)).isModuleEnabled(address(firstLossRoles)));
    }
}
