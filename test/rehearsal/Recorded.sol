// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/Test.sol";
import {Mainnet} from "./Mainnet.sol";
import {EnabledVault} from "./EnabledVault.sol";

/// @title Recorded — the enabled vault with a record of every log that a modifier or Easy Track emits, from the
///        modifiers' deployment on.
/// @dev A test writes its record to a file under `.roundtrip/`, one JSON log on each line. The `rehearsal`
///      commands of `policy/constellation/compiler/roundtrip.ts` and `watch.ts` read the files.
abstract contract Recorded is EnabledVault {
    string internal constant DIR = ".roundtrip";

    Vm.Log[] internal recorded;

    /// @dev Deploys the accounts and runs the enabling vote, and keeps the modifiers' logs of both. The fixture
    ///      measures each batch on a snapshot that it rolls back; those logs are no chain events, so they go.
    function _deployAndEnable() internal {
        vm.recordLogs();
        _deployAccounts();
        _deployFactory();
        _keep();
        _buildBatches();
        vm.getRecordedLogs();
        _voteAndRunBatches();
        _keep();
    }

    /// @dev Moves the logs that the four modifiers and Easy Track emitted since the last call into `recorded`,
    ///      in order.
    function _keep() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            address e = logs[i].emitter;
            if (
                e == address(opMod) || e == address(safetyMod) || e == address(ordersMod) || e == address(firstLossMod)
                    || e == Mainnet.EASY_TRACK
            ) {
                recorded.push(logs[i]);
            }
        }
    }

    function _write(string memory name) internal {
        assertGt(recorded.length, 0, "the modifiers emitted events");
        vm.createDir(DIR, true);
        string memory path = string.concat(DIR, "/", name);
        vm.writeFile(path, "");
        for (uint256 i = 0; i < recorded.length; i++) {
            Vm.Log storage log = recorded[i];
            string memory topics = "";
            for (uint256 t = 0; t < log.topics.length; t++) {
                topics = string.concat(topics, t == 0 ? "" : ",", '"', vm.toString(log.topics[t]), '"');
            }
            vm.writeLine(
                path,
                string.concat('{"address":"', vm.toString(log.emitter), '","topics":[', topics, '],"data":"', vm.toString(log.data), '"}')
            );
        }
        console2.log("ROUNDTRIP logs written", recorded.length, path);
    }
}
