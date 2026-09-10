// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {MockAragonAgent} from "./MockAragonAgent.sol";

/// @title MockEVMScriptExecutor — dry-run stand-in for the Lido Easy Track
///        EVMScriptExecutor (0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977).
/// @dev Fidelity contract (WS-M R17): reproduces the deployed executor's flow:
///      - callable only by the (mock) Easy Track, mirroring the deployed
///        executor's caller check;
///      - decodes the Aragon CallsScript EVM script spec (executor id
///        0x00000001: chunks of [to (20)][calldataLength (32)][calldata]);
///      - executes each chunk as *this contract*, exactly like the production
///        CallsScript runner. Scripts that need Agent authority therefore carry
///        chunks targeting `MockAragonAgent.forward(...)`, which the real
///        scripts do too — the same calldata a future ET factory will emit
///        rehearses unchanged through this path.
contract MockEVMScriptExecutor {
    bytes4 public constant EVM_SCRIPT_SPEC = 0x00000001; // CallsScript

    MockAragonAgent public immutable agent;
    address public easyTrack;

    error InvalidSpec(bytes4 spec);
    error MalformedScript();
    error CallFailed(uint256 index, bytes returndata);

    modifier onlyEasyTrack() {
        require(msg.sender == easyTrack, "EXECUTOR: only Easy Track");
        _;
    }

    constructor(MockAragonAgent _agent) {
        agent = _agent;
    }

    function setEasyTrack(address _easyTrack) external {
        require(easyTrack == address(0), "EXECUTOR: already set");
        require(
            _easyTrack != address(0) && msg.sender == _easyTrack,
            "EXECUTOR: must self-register"
        );
        easyTrack = _easyTrack;
    }

    /// @dev Mirrors EVMScriptExecutor.executeEVMScript(bytes) of the deployed
    ///      contract: permission check, then run the CallsScript payload.
    function executeEVMScript(bytes memory _evmScript) public onlyEasyTrack returns (bytes memory) {
        return _runCallsScript(_evmScript);
    }

    function _runCallsScript(bytes memory _evmScript) internal returns (bytes memory returndata) {
        if (_evmScript.length < 4) revert MalformedScript();
        bytes4 spec = bytes4(_evmScript[0]) | (bytes4(_evmScript[1]) >> 8) | (bytes4(_evmScript[2]) >> 16)
            | (bytes4(_evmScript[3]) >> 24);
        if (spec != EVM_SCRIPT_SPEC) revert InvalidSpec(spec);

        uint256 location = 4;
        uint256 index = 0;
        bytes memory ptr = _evmScript;
        assembly {
            ptr := add(ptr, 0x20) // point at data start
        }
        while (location < _evmScript.length) {
            address to;
            assembly {
                to := shr(96, mload(add(ptr, location)))
            }
            location += 20;
            uint256 calldataLength;
            assembly {
                calldataLength := mload(add(ptr, location))
            }
            location += 32;
            if (location + calldataLength > _evmScript.length) revert MalformedScript();

            bytes memory callData;
            assembly {
                callData := mload(0x40)
                mstore(callData, calldataLength)
                // ptr points at the data start of the script (length prefix
                // already skipped); chunk calldata starts at ptr + location
                let src := add(ptr, location)
                let dst := add(callData, 0x20)
                for {
                    let i := 0
                } lt(i, calldataLength) {
                    i := add(i, 32)
                } {
                    mstore(add(dst, i), mload(add(src, i)))
                }
                mstore(0x40, add(callData, add(0x20, calldataLength)))
            }

            (bool ok, bytes memory ret) = to.call{value: 0}(callData);
            if (!ok) revert CallFailed(index, ret);
            returndata = ret;
            location += calldataLength;
            unchecked {
                ++index;
            }
        }
    }
}
