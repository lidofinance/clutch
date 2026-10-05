// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

/// @dev Interface subset of the deployed Safe v1.5.0 singleton
///      (0xFf51A5898e281Db6DfC7855790607438dF2ca44b), which the fork tests
///      call; only functions used by the dry-run are declared.
interface ISafe {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool success);

    function approveHash(bytes32 hashToApprove) external;

    function enableModule(address module) external;

    /// @dev Safe v1.5.0. Guards the module execution path, which v1.4.1 does
    ///      not do at all. The callback receives the calling module, which is
    ///      why the policy is split across two modifier instances.
    function setModuleGuard(address moduleGuard) external;

    function setGuard(address guard) external;

    function disableModule(address prevModule, address module) external;

    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);

    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, uint256 next);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes32);

    function nonce() external view returns (uint256);

    function isModuleEnabled(address module) external view returns (bool);

    receive() external payable;
}

/// @dev Safe proxy factory v1.5.0:
///      0x14F2982D601c9458F93bd70B218933A6f8165e7b
interface ISafeProxyFactory {
    function createProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}

/// @dev The CANONICAL deployed ModuleProxyFactory (verified code at the
///      pinned block): 0x000000000000aDdB49795b0f9bA5BC298cDda236.
///      The kit previously deployed a local copy, breaking its own
///      production-components-only rule; corrected 2026-09-10.
interface IModuleProxyFactory {
    function deployModule(address masterCopy, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}

