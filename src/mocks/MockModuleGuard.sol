// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

/// @title MockModuleGuard — stand-in for a screening service's module guard.
/// @dev Test-only. In production this contract is supplied by the screening
///      vendor, not by Lido, and it is the one component in the design that can
///      halt the vault. Two properties the real one must also have:
///
///      1. It is told which module is calling, so it can let the safety
///         modifier through unconditionally. Recovery must never be blockable
///         by a screening outage.
///      2. The DAO can remove it through the owner path with
///         `setModuleGuard(address(0))`, so a failed or malicious guard is not
///         a permanent freeze.
contract MockModuleGuard {
    address public immutable safetyModifier;
    mapping(bytes32 => bool) public flagged;

    event Flagged(bytes32 indexed key, bool value);

    constructor(address _safetyModifier) {
        safetyModifier = _safetyModifier;
    }

    function flag(address to, bytes4 selector, bool value) external {
        bytes32 k = keccak256(abi.encodePacked(to, selector));
        flagged[k] = value;
        emit Flagged(k, value);
    }

    function checkModuleTransaction(
        address to,
        uint256,
        bytes memory data,
        uint8,
        address module
    ) external view returns (bytes32) {
        // the safety modifier is never screened
        if (module == safetyModifier) return bytes32(0);
        bytes4 selector;
        if (data.length >= 4) {
            assembly {
                selector := mload(add(data, 0x20))
            }
        }
        require(!flagged[keccak256(abi.encodePacked(to, selector))], "GUARD: blocked");
        return bytes32(0);
    }

    function checkAfterModuleExecution(bytes32, bool) external {}

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
