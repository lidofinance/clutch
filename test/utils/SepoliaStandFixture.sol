// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {SepoliaShares} from "../../src/mocks/SepoliaStand.sol";
import {CoWOrder, IComposableCoW} from "../../script/sepolia/CoWInterfaces.sol";

/// @dev Shared setup reads deployed permissions and supplies test shares only on the local fork.
abstract contract SepoliaStandFixture is Test {
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
    bytes32 internal assetOperator;
    bytes32 internal ordersOperator;
    bytes32 internal assetEmergency;
    bytes32 internal ordersEmergency;
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

    function setUp() public virtual {
        uint256 pinnedBlock = vm.envOr("SEPOLIA_STAND_BLOCK", uint256(0));
        if (pinnedBlock != 0) {
            vm.createSelectFork(vm.envString("SEPOLIA_RPC"), pinnedBlock);
        } else {
            string memory rpc = vm.envOr("SEPOLIA_REHEARSAL_RPC", string(""));
            if (bytes(rpc).length == 0) {
                vm.skip(true);
                return;
            }
            require(keccak256(bytes(rpc)) == keccak256("http://127.0.0.1:8547"), "Local rehearsal only");
            vm.createSelectFork(rpc);
        }
        require(block.chainid == 11155111, "Sepolia fork required");
        manifest = vm.readFile(vm.envOr("SEPOLIA_MANIFEST", string("cache/sepolia/manifest.json")));
        bool accountKeys = vm.keyExistsJson(manifest, ".roleKeyScheme")
            && keccak256(bytes(vm.parseJsonString(manifest, ".roleKeyScheme"))) == keccak256("account");
        require(pinnedBlock == 0 || accountKeys, "Current stand requires account keys");
        assetOperator = accountKeys ? bytes32("asset-operator") : bytes32("operator");
        ordersOperator = accountKeys ? bytes32("orders-operator") : bytes32("operator");
        assetEmergency = accountKeys ? bytes32("asset-emergency") : bytes32("emergency");
        ordersEmergency = accountKeys ? bytes32("orders-emergency") : bytes32("emergency");
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
        supplyFirstLossShares();
    }

    function supplyFirstLossShares() internal virtual {
        // Local fixture top-ups only. Keep the deployed permissions and allowances untouched.
        for (uint256 i; i < 2; ++i) {
            SepoliaShares share = SepoliaShares(a(i == 0 ? "usdShare" : "ethShare"));
            uint256 balance = share.balanceOf(firstLoss);
            if (balance < 10 ether) {
                vm.prank(controller);
                share.transfer(firstLoss, 10 ether - balance);
            }
        }
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
}
