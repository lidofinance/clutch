// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

/// @dev Interface subset of the deployed Gnosis Safe v1.4.1 singleton
///      (0x41675C099F32341bf84BFc5382aF534df5C7461a). Selectors match the
///      deployed bytecode; only functions used by the dry-run are declared.
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

/// @dev Safe proxy factory, v1.4.1 line:
///      0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67
interface ISafeProxyFactory {
    function createProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}

/// @dev Zodiac's ModuleProxyFactory (gnosisguild/zodiac-core). Deploys
///      EIP-1167-style minimal proxies whose implementation address lives in
///      proxy BYTECODE, not storage. This matters: the deployed Roles v4
///      mastercopy keeps its own state from slot 0, so a SafeProxy (singleton
///      pointer at slot 0) gets its implementation pointer overwritten by
///      setUp() and re-points at whatever address setUp wrote first. Foundry
///      drill evidence 2026-09-10; production must use the same proxy shape
///      the provider's tooling uses.
interface IModuleProxyFactory {
    function deployModule(address masterCopy, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}
