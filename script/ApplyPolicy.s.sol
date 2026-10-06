// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

/// @title ApplyPolicy — the policy half of the mainnet dry run.
/// @dev Applies a compiled policy artifact (ADR 004, decisions 13 and 14)
///      through Agent -> Safe -> Roles, call by call, in the artifact's order.
///      The artifact names the Agent and the Asset Safe in its manifest, so
///      it must be compiled against the manifest that DeployDryRun wrote.
///
///      Usage (see Justfile, `just dry-run`):
///        RPC=... PRIVATE_KEY=0x... ARTIFACT=dryrun-artifact.json \
///          forge script script/ApplyPolicy.s.sol --broadcast
contract ApplyPolicy is Script {
    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        string memory path = vm.envOr("ARTIFACT", string("dryrun-artifact.json"));
        string memory j = vm.readFile(path);
        MockAragonAgent agent = MockAragonAgent(payable(vm.parseJsonAddress(j, ".manifest.agent")));
        ISafe safe = ISafe(payable(vm.parseJsonAddress(j, ".manifest.assetSafe")));
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        require(to.length > 0 && to.length == data.length, "artifact: calls");

        vm.startBroadcast(deployer);
        for (uint256 i = 0; i < to.length; i++) {
            SafeExec.execAsOwner(agent, safe, to[i], data[i]);
        }
        vm.stopBroadcast();
        console2.log("applied policy calls:", to.length);
    }
}
