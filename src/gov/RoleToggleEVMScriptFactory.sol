// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";

/// @title RoleToggleEVMScriptFactory — the only new contract class the design allows.
/// @dev Governance may switch the operator between role keys the DAO has already
///      scoped by vote. It may not author a condition tree, name a target, or
///      name a member. Those are fixed here or refused by the modifier.
///
///      Two properties come from Easy Track itself and are why no separate
///      controller is needed:
///
///      1. `enactMotion` re-invokes this factory and requires the regenerated
///         script to hash-match the one recorded at creation. So if the DAO
///         removes a key from `allowedRoleKey` while a motion sits in its
///         objection window, that motion can no longer enact. The allow-list
///         is therefore also the stale-motion rule.
///      2. `enactMotion` is `whenNotPaused`, and the emergency committee holds
///         the pause role on Easy Track. Freezing motions during an incident
///         is an existing deployed control.
///
///      `createEVMScript` is `view`, so this contract can read its allow-list
///      but can never record anything at enactment. All enforcement is either
///      here at build time, re-checked at enactment, or in the modifier.
contract RoleToggleEVMScriptFactory {
    /// @dev The modifier being administered, and the member being toggled.
    ///      Both immutable: a motion can never redirect them.
    IRoles public immutable roles;
    address public immutable operatorSafe;
    bytes32 public immutable policyAdminRoleKey;
    /// @dev Only this address may create motions with this factory.
    address public immutable trustedCaller;
    /// @dev The DAO, reached by vote. Sets which role keys are togglable.
    address public immutable owner;

    mapping(bytes32 => bool) public allowedRoleKey;

    error CallerIsForbidden(address caller);
    error NotOwner();
    error RoleKeyNotAllowed(bytes32 roleKey);
    error ZeroAddress();

    event RoleKeyAllowed(bytes32 indexed roleKey, bool allowed);

    constructor(
        IRoles _roles,
        address _operatorSafe,
        bytes32 _policyAdminRoleKey,
        address _trustedCaller,
        address _owner
    ) {
        if (
            address(_roles) == address(0) || _operatorSafe == address(0)
                || _trustedCaller == address(0) || _owner == address(0)
        ) revert ZeroAddress();
        roles = _roles;
        operatorSafe = _operatorSafe;
        policyAdminRoleKey = _policyAdminRoleKey;
        trustedCaller = _trustedCaller;
        owner = _owner;
    }

    /// @notice DAO vote pre-approves a role key it has already scoped, or
    ///         withdraws one. Withdrawing also kills any motion in flight for
    ///         that key, because enactment rebuilds the script through here.
    function setRoleKeyAllowed(bytes32 roleKey, bool allowed) external {
        if (msg.sender != owner) revert NotOwner();
        allowedRoleKey[roleKey] = allowed;
        emit RoleKeyAllowed(roleKey, allowed);
    }

    /// @notice Builds the Aragon CallsScript for one toggle.
    /// @param _creator Motion creator, checked against the trusted caller.
    /// @param _evmScriptCallData abi.encode(bytes32 roleKey, bool enable)
    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        view
        returns (bytes memory)
    {
        if (_creator != trustedCaller) revert CallerIsForbidden(_creator);
        (bytes32 roleKey, bool enable) = abi.decode(_evmScriptCallData, (bytes32, bool));
        if (!allowedRoleKey[roleKey]) revert RoleKeyNotAllowed(roleKey);

        bytes32[] memory keys = new bytes32[](1);
        keys[0] = roleKey;
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = enable;

        bytes memory inner = abi.encodeCall(
            IRoles.execTransactionWithRole,
            (
                address(roles),
                0,
                abi.encodeCall(IRoles.assignRoles, (operatorSafe, keys, memberOf)),
                0,
                policyAdminRoleKey,
                true
            )
        );
        // spec id, then [to (20)][calldata length (uint32)][calldata]
        return abi.encodePacked(bytes4(0x00000001), bytes20(address(roles)), uint32(inner.length), inner);
    }
}
