// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ISafe} from "../interfaces/ISafe.sol";
import {IRoles} from "../interfaces/IRoles.sol";
import {MockAragonAgent} from "../mocks/MockAragonAgent.sol";
import {Policy} from "../policy/Policy.sol";

/// @dev Executes transactions through the Asset Safe *as its owner* (the
///      MockAragonAgent in the dry-run; in production the owner is the Aragon
///      Agent and authority reaches it through the Dual Governance admin
///      executor — the only RUN_SCRIPT/EXECUTE holder at the fork block).
///      Uses the Agent's `execute(address,uint256,bytes)` plus the Safe
///      approveHash + v=1 signature flow, the only authorization path that
///      ADR 005 allows the Agent (OD-17).
library SafeExec {
    address internal constant SENTINEL_MODULES = address(0x0000000000000000000000000000000000000001);

    function execAsOwner(MockAragonAgent agent, ISafe safe, address to, bytes memory data)
        internal
    {
        bytes32 txHash =
            safe.getTransactionHash(to, 0, data, 0, 0, 0, 0, address(0), address(0), safe.nonce());
        agent.execute(address(safe), 0, abi.encodeCall(ISafe.approveHash, (txHash)));
        bytes memory sig =
            abi.encodePacked(bytes32(uint256(uint160(address(agent)))), bytes32(0), uint8(1));
        bool ok =
            safe.execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sig);
        require(ok, "SafeExec: execTransaction failed");
    }
}

/// @dev Builds Aragon CallsScript payloads (spec 0x00000001) for the
///      production wire format: [spec(4)][to(20)][len(uint32)][calldata],
///      where len covers selector+args. Matches EVMScriptCreator of the
///      Easy Track source at commit 3183d1f6. The length field is a uint32;
///      no production executor accepts a 32-byte word.
///      Governance path: each policy admin call becomes one chunk targeting
///      the Roles modifier through `execTransactionWithRole` as the
///      governance role — the same avatar-execution mechanism the emergency
///      role uses. The mock EVMScript executor is a member of that role, so
///      enacted motions change policy without any Agent authority, and Easy
///      Track never needs RUN_SCRIPT_ROLE on the Agent (docs/specs/lip-draft.md).
library EVMScriptLib {
    bytes4 internal constant SPEC = 0x00000001;

    function buildAsPolicyAdmin(IRoles roles, Policy.Call[] memory calls)
        internal
        view
        returns (bytes memory script)
    {
        script = abi.encodePacked(SPEC);
        for (uint256 i = 0; i < calls.length; i++) {
            bytes memory chunkData = abi.encodeCall(
                IRoles.execTransactionWithRole,
                (calls[i].to, 0, calls[i].data, 0, Policy.POLICY_ADMIN(), true)
            );
            script = abi.encodePacked(
                script, bytes20(address(roles)), uint32(chunkData.length), chunkData
            );
        }
    }

    /// @dev Golden-calldata helper: a CallsScript whose chunks are addressed
    ///      directly — the shape a production ET factory emits for scripts
    ///      that execute as the Agent. Used by the parity test against
    ///      MockAragonAgent.forward(bytes).
    function buildDirect(Policy.Call[] memory calls)
        internal
        pure
        returns (bytes memory script)
    {
        script = abi.encodePacked(SPEC);
        for (uint256 i = 0; i < calls.length; i++) {
            script = abi.encodePacked(
                script, bytes20(calls[i].to), uint32(calls[i].data.length), calls[i].data
            );
        }
    }
}
