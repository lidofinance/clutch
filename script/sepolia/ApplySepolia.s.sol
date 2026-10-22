// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe} from "../../src/interfaces/ISafe.sol";
import {MockAragonAgent} from "../../src/mocks/MockAragonAgent.sol";
import {SafeExec} from "../../src/exec/SafeExec.sol";

contract ApplySepolia is Script {
    function run() external {
        require(block.chainid == 11155111 && vm.envOr("CLUTCH_SEPOLIA", uint256(0)) == 1, "Sepolia opt-in required");
        string memory json = vm.readFile(vm.envOr("SEPOLIA_ARTIFACT", string("cache/sepolia/policy.json")));
        require(vm.parseJsonUint(json, ".manifest.chainId") == block.chainid, "Artifact network");
        address controller = vm.envAddress("SEPOLIA_SENDER");
        require(vm.parseJsonAddress(json, ".manifest.controller") == controller, "Artifact controller");
        address[] memory to = vm.parseJsonAddressArray(json, ".calls.to");
        address[] memory avatars = vm.parseJsonAddressArray(json, ".calls.avatar");
        bytes[] memory data = vm.parseJsonBytesArray(json, ".calls.data");
        require(to.length > 0 && to.length == avatars.length && to.length == data.length, "Artifact calls");
        MockAragonAgent voting = MockAragonAgent(payable(vm.parseJsonAddress(json, ".manifest.voting")));
        vm.startBroadcast(controller);
        for (uint256 i; i < to.length; ++i) {
            require(ISafe(payable(avatars[i])).getOwners()[0] == address(voting), "Safe owner differs");
            SafeExec.execAsOwner(voting, ISafe(payable(avatars[i])), to[i], data[i]);
        }
        vm.stopBroadcast();
        console2.log("Applied Sepolia policy calls:", to.length);
    }
}
