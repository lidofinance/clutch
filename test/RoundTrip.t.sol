// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @title RoundTrip — the events of the vault's four Roles modifiers, written out for the round-trip check
///        (ADR 004, decision 13; INV-016).
/// @dev Each test records every log that a modifier emits, from its deployment on, and writes the logs to a
///      file under `.roundtrip/`, one JSON log on each line. `just round-trip` runs these tests and then
///      `policy/constellation/compiler/roundtrip.ts rehearsal`, which rebuilds each modifier's state from its file
///      and compares it with the policy. A test alone asserts only that the modifiers emitted events.
///      Run: just round-trip
contract RoundTrip is EnabledVault {
    string internal constant DIR = ".roundtrip";
    /// @dev The committed example motion (policy/constellation/compiler/motion.example.ts).
    string internal constant EXAMPLE = "policy/constellation/artifacts/motion-example-rehearsal-26249900.json";

    Vm.Log[] internal recorded;

    function setUp() public {
        _fork();
    }

    /// @dev After the enabling vote and the Safe batches: the modifiers hold the committed policy.
    function test_roundtrip_events_after_the_enabling_vote() public {
        _deployAndEnable();
        _write("enabling-vote.ndjson");
    }

    /// @dev After a motion that the `motion` command built: the modifiers hold the motion's head policy.
    function test_roundtrip_events_after_the_example_motion() public {
        _deployAndEnable();
        bytes memory cd = vm.parseJsonBytes(vm.readFile(EXAMPLE), ".calldata");
        uint256 id = _create(cd);
        _afterWindow();
        _enact(id, cd);
        _keep();
        _write("example-motion.ndjson");
    }

    /// @dev After the operator spent a budget and the emergency role revoked a target and a function: the chain
    ///      no longer holds the policy, and the check must report exactly these revokes.
    function test_roundtrip_events_after_an_emergency_revoke() public {
        _deployAndEnable();
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 100e6)), true);
        _emergencyRevokeTarget(Mainnet.SUSDS);
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(
            address(opMod), 0, abi.encodeCall(IRoles.revokeFunction, (OPERATOR, Mainnet.USDC, IERC20.approve.selector)), 0, EMERGENCY, true
        );
        _keep();
        _write("emergency-revoke.ndjson");
    }

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

    /// @dev Moves the logs that the four modifiers emitted since the last call into `recorded`, in order.
    function _keep() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            address e = logs[i].emitter;
            if (e == address(opMod) || e == address(safetyMod) || e == address(ordersMod) || e == address(firstLossMod)) {
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
