// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

/// @title ModuleProxyFactory — verbatim copy of gnosisguild/zodiac-core
///        contracts/factory/ModuleProxyFactory.sol (fetched 2026-09-10).
/// @dev Deployed fresh in the dry-run. EIP-1167-style minimal proxies are the
///      ONLY proxy shape compatible with the deployed Roles v4 mastercopy,
///      whose storage layout starts at slot 0 (see ISafe.sol note).
contract ModuleProxyFactory {
    event ModuleProxyCreation(address indexed proxy, address indexed masterCopy);

    error ZeroAddress(address target);
    error TargetHasNoCode(address target);
    error TakenAddress(address address_);
    error FailedInitialization();

    function createProxy(address target, bytes32 salt) internal returns (address result) {
        if (address(target) == address(0)) revert ZeroAddress(target);
        if (address(target).code.length == 0) revert TargetHasNoCode(target);
        bytes memory deployment =
            abi.encodePacked(hex"602d8060093d393df3363d3d373d3d3d363d73", target, hex"5af43d82803e903d91602b57fd5bf3");
        assembly {
            result := create2(0, add(deployment, 0x20), mload(deployment), salt)
        }
        if (result == address(0)) revert TakenAddress(result);
    }

    function deployModule(address masterCopy, bytes memory initializer, uint256 saltNonce)
        public
        returns (address proxy)
    {
        proxy = createProxy(masterCopy, keccak256(abi.encodePacked(keccak256(initializer), saltNonce)));
        (bool success,) = proxy.call(initializer);
        if (!success) revert FailedInitialization();

        emit ModuleProxyCreation(proxy, masterCopy);
    }
}
