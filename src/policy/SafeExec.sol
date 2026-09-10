// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {ISafe} from "../interfaces/ISafe.sol";
import {MockAragonAgent} from "../mocks/MockAragonAgent.sol";
import {Policy} from "../policy/Policy.sol";

/// @dev Executes transactions through the Asset Safe *as its owner* (the
///      MockAragonAgent in the dry-run, the Aragon Agent in production).
///      Uses the approveHash + v=1 signature flow — the same two-step owner
///      pattern production DAO scripts use when a contract owns a Safe.
library SafeExec {
    address internal constant SENTINEL_MODULES = address(0x0000000000000000000000000000000000000001);

    function execAsOwner(MockAragonAgent agent, ISafe safe, address to, bytes memory data)
        internal
    {
        bytes32 txHash =
            safe.getTransactionHash(to, 0, data, 0, 0, 0, 0, address(0), address(0), safe.nonce());
        agent.forward(address(safe), abi.encodeCall(ISafe.approveHash, (txHash)));
        bytes memory sig =
            abi.encodePacked(bytes32(uint256(uint160(address(agent)))), bytes32(0), uint8(1));
        bool ok =
            safe.execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sig);
        require(ok, "SafeExec: execTransaction failed");
    }
}

/// @dev Builds Aragon CallsScript payloads (spec 0x00000001) for governance
///      motions. Each policy call becomes two chunks through the (mock) Agent:
///      approveHash, then execTransaction with the v=1 owner signature — the
///      exact shape a production ET factory must emit, rehearsed unchanged.
library EVMScriptLib {
    bytes4 internal constant SPEC = 0x00000001;

    function build(MockAragonAgent agent, ISafe safe, Policy.Call[] memory calls)
        internal
        view
        returns (bytes memory script)
    {
        script = abi.encodePacked(SPEC);
        uint256 nonce = safe.nonce();
        bytes memory sig =
            abi.encodePacked(bytes32(uint256(uint160(address(agent)))), bytes32(0), uint8(1));
        for (uint256 i = 0; i < calls.length; i++) {
            bytes32 txHash = safe.getTransactionHash(
                calls[i].to, 0, calls[i].data, 0, 0, 0, 0, address(0), address(0), nonce
            );
            unchecked {
                ++nonce;
            }
            bytes memory approveCall = abi.encodeCall(
                MockAragonAgent.forward,
                (address(safe), abi.encodeCall(ISafe.approveHash, (txHash)))
            );
            script = abi.encodePacked(script, bytes20(address(agent)), bytes32(approveCall.length), approveCall);
            bytes memory execData = abi.encodeCall(
                ISafe.execTransaction,
                (calls[i].to, 0, calls[i].data, 0, 0, 0, 0, address(0), payable(address(0)), sig)
            );
            bytes memory execCall =
                abi.encodeCall(MockAragonAgent.forward, (address(safe), execData));
            script = abi.encodePacked(script, bytes20(address(agent)), bytes32(execCall.length), execCall);
        }
    }
}
