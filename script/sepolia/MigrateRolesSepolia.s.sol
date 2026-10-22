// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe} from "../../src/interfaces/ISafe.sol";
import {MockAragonAgent} from "../../src/mocks/MockAragonAgent.sol";

/// @dev Human-only execution of the reviewed OD-100 package, through the existing test Voting.
contract MigrateRolesSepolia is Script {
    function run() external {
        require(block.chainid == 11155111 && vm.envOr("CLUTCH_SEPOLIA", uint256(0)) == 1, "Sepolia opt-in required");
        string memory json = vm.readFile("cache/sepolia/role-key-migration/package.json");
        require(keccak256(bytes(vm.parseJsonString(json, ".format"))) == keccak256("clutch.sepolia-role-migration/1"), "Package format");
        address controller = vm.envAddress("SEPOLIA_SENDER");
        require(vm.parseJsonAddress(json, ".sourceManifest.controller") == controller, "Package controller");
        address voting = vm.parseJsonAddress(json, ".sourceManifest.voting");
        require(MockAragonAgent(payable(voting)).owner() == controller, "Voting owner changed");
        for (uint256 i; i < 5; ++i) {
            string memory prefix = string.concat(".safes[", vm.toString(i), "]");
            ISafe safe = ISafe(payable(vm.parseJsonAddress(json, string.concat(prefix, ".address"))));
            require(safe.nonce() == vm.parseUint(vm.parseJsonString(json, string.concat(prefix, ".nonce"))), "Safe nonce changed");
            require(safe.getThreshold() == 1, "Safe threshold changed");
            address[] memory owners = safe.getOwners();
            require(owners.length == 1 && owners[0] == (i < 3 ? voting : controller), "Safe owner changed");
        }
        address executor = vm.parseJsonAddress(json, ".batchExecutor.address");
        require(executor.codehash == vm.parseJsonBytes32(json, ".batchExecutor.codeHash"), "Batch executor changed");
        vm.startBroadcast(controller);
        for (uint256 i; i < 2; ++i) {
            string memory prefix = string.concat(".transactions[", vm.toString(i), "]");
            require(vm.parseJsonAddress(json, string.concat(prefix, ".to")) == voting, "Package Voting");
            address avatar = vm.parseJsonAddress(json, string.concat(prefix, ".avatar"));
            bytes memory safeData = vm.parseJsonBytes(json, string.concat(prefix, ".safeData"));
            MockAragonAgent(payable(voting)).execute(avatar, 0, safeData);
        }
        vm.stopBroadcast();
        console2.log("Migrated four Sepolia role instances in two atomic Safe batches");
    }
}
