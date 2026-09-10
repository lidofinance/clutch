// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

/// @dev Interface subset of the deployed Zodiac Roles v4-lineage mastercopy
///      (0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5), verified against
///      gnosisguild/zodiac-modifier-roles @ 820e5bc (Permissions builder +
///      Types). Enum orderings are load-bearing and must match the deployed
///      bytecode exactly.
interface IRoles {
    // --- enum orderings (from contracts/Types.sol @ 820e5bc) ---
    // ExecutionOptions: None=0, Send=1, DelegateCall=2, Both=3
    // Clearance: None=0, Target=1, Function=2
    // AbiType: None=0, Static=1, Dynamic=2, Tuple=3, Array=4, Calldata=5, AbiEncoded=6
    // Operator: Pass=0, And=1, Or=2, Nor=3, Matches=5, ArraySome=6, ArrayEvery=7,
    //           ArraySubset=8, EqualToAvatar=15, EqualTo=16, GreaterThan=17,
    //           LessThan=18, SignedIntGreaterThan=19, SignedIntLessThan=20,
    //           Bitmask=21, Custom=22, WithinAllowance=28,
    //           EtherWithinAllowance=29, CallWithinAllowance=30

    struct ConditionFlat {
        uint8 parent;
        uint8 paramType; // AbiType
        uint8 operator_; // Operator
        bytes compValue;
    }

    // --- admin surface (owner: the Asset Safe) ---
    /// @dev The deployed v4-lineage mastercopy uses the FactoryFriendly
    ///      pattern: setUp(bytes) with abi-encoded (owner, avatar, target).
    ///      Newer repo HEAD refactored to setUp(address,address,address);
    ///      the deployed bytecode does NOT have that selector.
    function setUp(bytes memory initParams) external;

    function assignRoles(
        address module,
        bytes32[] calldata roleKeys,
        bool[] calldata memberOf
    ) external;

    function setDefaultRole(address module, bytes32 roleKey) external;

    function allowTarget(bytes32 roleKey, address targetAddress, uint8 options) external;

    function revokeTarget(bytes32 roleKey, address targetAddress) external;

    function scopeTarget(bytes32 roleKey, address targetAddress) external;

    function allowFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        uint8 options
    ) external;

    function revokeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector
    ) external;

    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] calldata conditions,
        uint8 options
    ) external;

    function setAllowance(
        bytes32 key,
        uint128 balance,
        uint128 maxRefill,
        uint128 refill,
        uint64 period,
        uint64 timestamp
    ) external;

    function setTransactionUnwrapper(
        address to,
        bytes4 selector,
        address adapter
    ) external;

    // --- module surface ---
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success);

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success, bytes memory returnData);

    function execTransactionWithRole(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        bytes32 roleKey,
        bool shouldRevert
    ) external returns (bool success);

    // --- views used by monitors ---
    function owner() external view returns (address);

    function avatar() external view returns (address);

    function target() external view returns (address);

    function allowances(bytes32 key)
        external
        view
        returns (
            uint128 refill,
            uint128 maxRefill,
            uint64 period,
            uint128 balance,
            uint64 timestamp
        );

    function getModulesPaginated(uint256 start, uint256 pageSize)
        external
        view
        returns (address[] memory array, uint256 next);

    function isModuleEnabled(address module) external view returns (bool);
}
