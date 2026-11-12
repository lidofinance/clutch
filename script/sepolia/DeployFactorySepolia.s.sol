// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../../src/factory/UniversalFactory.sol";
import {MockEasyTrack} from "../../src/mocks/MockEasyTrack.sol";
import {SepoliaDepositQueue} from "../../src/mocks/SepoliaStand.sol";

/// @notice Adds the universal factory and two deposit queues to the existing Sepolia stand, and
///         registers the factory in the stand's Easy Track. The stand's controller owns that Easy Track.
contract DeployFactorySepolia is Script {
    function config(string memory json) public pure returns (UniversalFactory.Config memory) {
        return UniversalFactory.Config({
            trustedCaller: vm.parseJsonAddress(json, ".operatorSafe"),
            executor: vm.parseJsonAddress(json, ".easyTrackExecutor"),
            emergencySafe: vm.parseJsonAddress(json, ".emergencySafe"),
            voting: vm.parseJsonAddress(json, ".voting"),
            operatorModifier: vm.parseJsonAddress(json, ".operatorModifier"),
            safetyModifier: vm.parseJsonAddress(json, ".safetyModifier"),
            ordersModifier: vm.parseJsonAddress(json, ".ordersModifier"),
            firstLossModifier: vm.parseJsonAddress(json, ".firstLossModifier")
        });
    }

    /// @dev The order of deployment fixes the addresses: the USD queue, the ETH queue, then the factory.
    function deploy(string memory json) public returns (SepoliaDepositQueue usd, SepoliaDepositQueue eth, UniversalFactory factory) {
        usd = new SepoliaDepositQueue(IERC20(vm.parseJsonAddress(json, ".dependencies.tokens.usdc.address")));
        eth = new SepoliaDepositQueue(IERC20(vm.parseJsonAddress(json, ".dependencies.tokens.weth.address")));
        factory = new UniversalFactory(config(json));
        MockEasyTrack(vm.parseJsonAddress(json, ".easyTrack")).addEVMScriptFactory(address(factory));
    }

    function run() external {
        require(block.chainid == 11155111 && vm.envOr("CLUTCH_SEPOLIA", uint256(0)) == 1, "Sepolia opt-in required");
        require(vm.envOr("PRIVATE_KEY", uint256(0)) == 0 && vm.envOr("EXECUTOR_KEY", uint256(0)) == 0, "Use a keystore");
        string memory file = vm.envOr("SEPOLIA_MANIFEST", string("cache/sepolia/manifest.json"));
        string memory json = vm.readFile(file);
        address controller = vm.envAddress("SEPOLIA_SENDER");
        require(
            vm.parseJsonUint(json, ".chainId") == block.chainid
                && vm.parseJsonAddress(json, ".controller") == controller,
            "Manifest differs"
        );
        require(!vm.keyExistsJson(json, ".universalFactory"), "Factory exists");
        require(MockEasyTrack(vm.parseJsonAddress(json, ".easyTrack")).owner() == controller, "Easy Track owner differs");
        vm.startBroadcast(controller);
        (SepoliaDepositQueue usd, SepoliaDepositQueue eth, UniversalFactory factory) = deploy(json);
        vm.stopBroadcast();
        vm.writeJson(vm.toString(address(usd)), file, ".usdDepositQueue");
        vm.writeJson(vm.toString(address(eth)), file, ".ethDepositQueue");
        vm.writeJson(vm.toString(address(factory)), file, ".universalFactory");
        console2.log("Universal factory:", address(factory));
    }
}
