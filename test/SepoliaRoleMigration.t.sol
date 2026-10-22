// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";
import {CoWOrder, ICoWSettlement, IOrderSigner} from "../script/sepolia/CoWInterfaces.sol";

/// @dev OD-100 acceptance on a pinned fork of the existing Sepolia stand. No deployment or public writes.
contract SepoliaRoleMigrationTest is Test {
    string internal manifest;
    string internal packageFile;
    address internal controller;
    address internal committee;
    address internal emergency;
    address internal asset;
    address internal orders;
    MockAragonAgent internal voting;
    IRoles internal operator;
    IRoles internal safety;
    IRoles internal ordersRoles;

    function a(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".", name));
    }

    function dependency(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".dependencies.contracts.", name, ".address"));
    }

    function token(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(manifest, string.concat(".dependencies.tokens.", name, ".address"));
    }

    function setUp() public {
        string memory file = vm.envOr("SEPOLIA_MIGRATION_ARTIFACT", string(""));
        if (bytes(file).length == 0) { vm.skip(true); return; }
        packageFile = file;
        string memory package = vm.readFile(file);
        vm.createSelectFork(vm.envString("SEPOLIA_RPC"), vm.parseJsonUint(package, ".block"));
        manifest = vm.readFile(vm.envOr("SEPOLIA_MANIFEST", string("cache/sepolia/manifest.json")));
        require(block.chainid == 11155111, "Sepolia fork required");
        controller = a("controller"); committee = a("operatorSafe"); emergency = a("emergencySafe");
        asset = a("assetSafe"); orders = a("ordersSafe");
        voting = MockAragonAgent(payable(a("voting")));
        operator = IRoles(a("operatorModifier")); safety = IRoles(a("safetyModifier"));
        ordersRoles = IRoles(a("ordersModifier"));
    }

    function transactionData(uint256 index) internal view returns (bytes memory) {
        return vm.parseJsonBytes(vm.readFile(packageFile), string.concat(".transactions[", vm.toString(index), "].data"));
    }

    function executeBatch(uint256 index) internal {
        bytes memory data = transactionData(index);
        vm.prank(controller);
        (bool ok,) = address(voting).call(data);
        require(ok, "Migration batch failed");
    }

    function migrate() internal {
        executeBatch(0);
        executeBatch(1);
    }

    function exec(address member, IRoles roles, bytes32 role, address to, bytes memory data, uint8 operation) internal {
        vm.prank(member);
        assertTrue(roles.execTransactionWithRole(to, 0, data, operation, role, true));
    }

    function denied(address member, IRoles roles, bytes32 role, address to, bytes memory data, uint8 operation) internal {
        vm.prank(member);
        (bool ok,) = address(roles).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, operation, role, true)));
        assertFalse(ok, "permission must reject");
    }

    function allowanceState(bytes32 key) internal view returns (bytes32) {
        (uint128 r, uint128 m, uint64 p, uint128 b, uint64 t) = operator.allowances(key);
        return keccak256(abi.encode(r, m, p, b, t));
    }

    function test_migration_preserves_allowances_accounts_and_first_loss() public {
        bytes32 weth = allowanceState(bytes32("orders_weth"));
        bytes32 usdc = allowanceState(bytes32("orders_usdc"));
        uint256 firstLossNonce = ISafe(payable(a("firstLossSafe"))).nonce();
        uint256 shares = IERC20(a("usdShare")).balanceOf(a("firstLossSafe"));
        for (uint256 i; i < 2; ++i) {
            bytes memory data = transactionData(i);
            uint256 start = gasleft();
            vm.prank(controller);
            (bool ok,) = address(voting).call(data);
            uint256 used = start - gasleft();
            assertTrue(ok, "Migration batch failed");
            emit log_named_uint("Atomic Safe batch execution gas", used);
            assertLt(used + 21000 + data.length * 16, 16_777_216, "Sepolia transaction gas cap");
        }
        assertEq(allowanceState(bytes32("orders_weth")), weth);
        assertEq(allowanceState(bytes32("orders_usdc")), usdc);
        assertEq(ISafe(payable(a("firstLossSafe"))).nonce(), firstLossNonce);
        assertEq(IERC20(a("usdShare")).balanceOf(a("firstLossSafe")), shares);
        assertEq(ISafe(payable(asset)).getOwners()[0], address(voting));
        assertEq(ISafe(payable(orders)).getOwners()[0], address(voting));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        assertTrue(ISafe(payable(orders)).isModuleEnabled(address(ordersRoles)));
    }

    function test_new_roles_execute_and_old_keys_and_wrong_accounts_fail() public {
        migrate();
        address weth = token("weth");
        deal(weth, asset, 10);
        deal(weth, orders, 10);
        bytes memory toOrders = abi.encodeCall(IERC20.transfer, (orders, 1));
        bytes memory toAsset = abi.encodeCall(IERC20.transfer, (asset, 1));
        bytes memory toAgent = abi.encodeCall(IERC20.transfer, (a("agent"), 1));
        exec(committee, operator, bytes32("asset-operator"), weth, toOrders, 0);
        exec(committee, ordersRoles, bytes32("orders-operator"), weth, toAsset, 0);
        exec(emergency, safety, bytes32("asset-emergency"), weth, toAgent, 0);
        exec(emergency, ordersRoles, bytes32("orders-emergency"), weth, toAgent, 0);
        denied(committee, operator, bytes32("operator"), weth, toOrders, 0);
        denied(committee, ordersRoles, bytes32("operator"), weth, toAsset, 0);
        denied(emergency, safety, bytes32("emergency"), weth, toAgent, 0);
        denied(emergency, ordersRoles, bytes32("emergency"), weth, toAgent, 0);
        denied(committee, operator, bytes32("orders-operator"), weth, toOrders, 0);
        denied(committee, ordersRoles, bytes32("asset-operator"), weth, toAsset, 0);
        denied(emergency, safety, bytes32("orders-emergency"), weth, toAgent, 0);
        denied(emergency, ordersRoles, bytes32("asset-emergency"), weth, toAgent, 0);
        denied(controller, operator, bytes32("asset-operator"), weth, toOrders, 0);
        denied(committee, operator, bytes32("asset-operator"), weth, toAgent, 0);
    }

    function test_between_batches_each_account_keeps_its_operator_and_emergency_revoke() public {
        executeBatch(0);
        address weth = token("weth"); deal(weth, asset, 10); deal(weth, orders, 10);
        exec(committee, operator, bytes32("asset-operator"), weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        denied(committee, operator, bytes32("operator"), weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        exec(committee, ordersRoles, bytes32("operator"), weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        denied(committee, ordersRoles, bytes32("orders-operator"), weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        exec(emergency, safety, bytes32("asset-emergency"), address(operator), abi.encodeCall(IRoles.revokeTarget, (bytes32("asset-operator"), weth)), 0);
        denied(committee, operator, bytes32("asset-operator"), weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        exec(emergency, ordersRoles, bytes32("emergency"), address(ordersRoles), abi.encodeCall(IRoles.revokeTarget, (bytes32("operator"), weth)), 0);
        denied(committee, ordersRoles, bytes32("operator"), weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        exec(emergency, safety, bytes32("asset-emergency"), weth, abi.encodeCall(IERC20.transfer, (a("agent"), 1)), 0);
        exec(emergency, ordersRoles, bytes32("emergency"), weth, abi.encodeCall(IERC20.transfer, (a("agent"), 1)), 0);
    }

    function test_governance_writes_only_the_new_asset_operator_key() public {
        migrate();
        address weth = token("weth");
        bytes memory wrongOld = abi.encodeCall(IRoles.revokeFunction, (bytes32("operator"), weth, IERC20.transfer.selector));
        bytes memory wrongOrders = abi.encodeCall(IRoles.revokeFunction, (bytes32("orders-operator"), weth, IERC20.transfer.selector));
        address executor = a("easyTrackExecutor");
        denied(executor, operator, bytes32("governance"), address(operator), wrongOld, 0);
        denied(executor, operator, bytes32("governance"), address(operator), wrongOrders, 0);
        exec(executor, operator, bytes32("governance"), address(operator), abi.encodeCall(IRoles.revokeFunction, (bytes32("asset-operator"), weth, IERC20.transfer.selector)), 0);
        denied(committee, operator, bytes32("asset-operator"), weth, abi.encodeCall(IERC20.transfer, (orders, 0)), 0);
        bytes32[] memory keys = new bytes32[](1); keys[0] = bytes32("asset-operator");
        bool[] memory enabled = new bool[](1); enabled[0] = true;
        denied(executor, operator, bytes32("governance"), address(operator), abi.encodeCall(IRoles.assignRoles, (controller, keys, enabled)), 0);
        denied(executor, ordersRoles, bytes32("governance"), address(ordersRoles), wrongOrders, 0);
    }

    function test_emergency_revokes_new_operators_and_keeps_its_recovery_path() public {
        migrate();
        address weth = token("weth"); deal(weth, asset, 10); deal(weth, orders, 10);
        exec(emergency, safety, bytes32("asset-emergency"), address(operator), abi.encodeCall(IRoles.revokeTarget, (bytes32("asset-operator"), weth)), 0);
        denied(committee, operator, bytes32("asset-operator"), weth, abi.encodeCall(IERC20.transfer, (orders, 1)), 0);
        exec(emergency, safety, bytes32("asset-emergency"), weth, abi.encodeCall(IERC20.transfer, (a("agent"), 1)), 0);
        exec(emergency, ordersRoles, bytes32("orders-emergency"), address(ordersRoles), abi.encodeCall(IRoles.revokeTarget, (bytes32("orders-operator"), weth)), 0);
        denied(committee, ordersRoles, bytes32("orders-operator"), weth, abi.encodeCall(IERC20.transfer, (asset, 1)), 0);
        exec(emergency, ordersRoles, bytes32("orders-emergency"), weth, abi.encodeCall(IERC20.transfer, (a("agent"), 1)), 0);
        denied(emergency, safety, bytes32("asset-emergency"), address(operator), abi.encodeCall(IRoles.scopeTarget, (bytes32("asset-operator"), weth)), 0);
        denied(emergency, ordersRoles, bytes32("orders-emergency"), weth, abi.encodeCall(IERC20.approve, (dependency("vaultRelayer"), 1)), 0);
    }

    function test_asset_switch_stops_operator_and_cannot_be_reversed_by_emergency() public {
        migrate();
        (address[] memory modules,) = ISafe(payable(asset)).getModulesPaginated(address(1), 100);
        address previous = address(1);
        for (uint256 i; i < modules.length && modules[i] != address(operator); ++i) previous = modules[i];
        exec(emergency, safety, bytes32("asset-emergency"), asset, abi.encodeCall(ISafe.disableModule, (previous, address(operator))), 0);
        assertFalse(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
        denied(committee, operator, bytes32("asset-operator"), token("weth"), abi.encodeCall(IERC20.transfer, (orders, 0)), 0);
        denied(emergency, safety, bytes32("asset-emergency"), asset, abi.encodeCall(ISafe.enableModule, (address(operator))), 0);
        deal(token("weth"), asset, 1);
        exec(emergency, safety, bytes32("asset-emergency"), token("weth"), abi.encodeCall(IERC20.transfer, (a("agent"), 1)), 0);
    }

    function test_orders_signing_uses_the_new_key_and_preserves_receiver_limits() public {
        migrate();
        CoWOrder.Data memory order = CoWOrder.Data(token("weth"), token("usdc"), asset, 1, 1,
            uint32(block.timestamp + 1 hours - 1), bytes32(0), 0, keccak256("sell"), false, keccak256("erc20"), keccak256("erc20"));
        exec(committee, ordersRoles, bytes32("orders-operator"), dependency("orderSigner"), abi.encodeCall(IOrderSigner.signOrder, (order, uint32(1 hours), 0)), 1);
        bytes memory uid = abi.encodePacked(CoWOrder.digest(order, ICoWSettlement(dependency("settlement")).domainSeparator()), orders, order.validTo);
        assertGt(ICoWSettlement(dependency("settlement")).preSignature(uid), 0);
        exec(committee, ordersRoles, bytes32("orders-operator"), dependency("orderSigner"), abi.encodeCall(IOrderSigner.unsignOrder, (order)), 1);
        assertEq(ICoWSettlement(dependency("settlement")).preSignature(uid), 0);
        order.receiver = controller;
        denied(committee, ordersRoles, bytes32("orders-operator"), dependency("orderSigner"), abi.encodeCall(IOrderSigner.signOrder, (order, uint32(1 hours), 0)), 1);
    }

    function test_failure_rolls_back_the_entire_migration_and_non_owner_cannot_execute() public {
        uint256 nonce = ISafe(payable(asset)).nonce();
        bytes32 allowance = allowanceState(bytes32("orders_weth"));
        bytes memory packageBytes = bytes(vm.readFile(packageFile));
        string memory document = string(packageBytes);
        bytes memory batch = vm.parseJsonBytes(document, ".transactions[0].batch");
        bytes memory bad = abi.encodePacked(batch, uint8(0), address(voting), uint256(0), uint256(4), bytes4(0xdeadbeef));
        address executor = vm.parseJsonAddress(document, ".batchExecutor.address");
        bytes memory signature = abi.encodePacked(bytes32(uint256(uint160(address(voting)))), bytes32(0), uint8(1));
        bytes memory safeData = abi.encodeCall(ISafe.execTransaction,
            (executor, 0, abi.encodeWithSignature("multiSend(bytes)", bad), 1, 0, 0, 0, address(0), payable(address(0)), signature));
        vm.prank(controller); vm.expectRevert(); voting.execute(asset, 0, safeData);
        assertEq(ISafe(payable(asset)).nonce(), nonce);
        assertEq(allowanceState(bytes32("orders_weth")), allowance);
        denied(committee, operator, bytes32("asset-operator"), token("weth"), abi.encodeCall(IERC20.transfer, (orders, 0)), 0);
        exec(committee, operator, bytes32("operator"), token("weth"), abi.encodeCall(IERC20.transfer, (orders, 0)), 0);
        bytes memory data = transactionData(0);
        vm.prank(committee);
        (bool permitted,) = address(voting).call(data);
        assertFalse(permitted);
    }

    function test_old_function_slots_cannot_reactivate_after_membership_and_target_are_restored() public {
        migrate();
        bytes32[] memory keys = new bytes32[](1); keys[0] = bytes32("operator");
        bool[] memory enabled = new bool[](1); enabled[0] = true;
        vm.startPrank(controller);
        SafeExec.execAsOwner(voting, ISafe(payable(asset)), address(operator), abi.encodeCall(IRoles.assignRoles, (committee, keys, enabled)));
        SafeExec.execAsOwner(voting, ISafe(payable(asset)), address(operator), abi.encodeCall(IRoles.scopeTarget, (bytes32("operator"), token("weth"))));
        vm.stopPrank();
        denied(committee, operator, bytes32("operator"), token("weth"), abi.encodeCall(IERC20.transfer, (orders, 0)), 0);
    }
}
