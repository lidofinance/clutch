// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";

/// @title PolicyAdminController — the bounded controller for governance-driven
///        permission changes (P0-2).
/// @dev Revision 4 rejected exposing the modifier's raw admin selectors to an
///      Easy Track motion, even with the role key pinned: the governance role
///      could grant the operator a permission whose target is the modifier, and
///      the operator then reached owner-only administration through the avatar.
///      A deny-list of two addresses inside the modifier is necessary but not a
///      proof of safety, so the positive controls live here.
///
///      This contract is the sole member of the policy-admin role. Easy Track
///      motions call it; it validates and then executes through the modifier as
///      the avatar. Four properties it enforces that the modifier cannot:
///
///      1. A positive allow-list of administrable targets and selectors, set by
///         the DAO, not by a motion.
///      2. Hard refusal of the modifier and the Safe as an administered target,
///         repeating the in-modifier guard so neither layer is load-bearing
///         alone.
///      3. A policy version. Every mutating call names the version it was built
///         against and bumps it on success, so a motion queued before an
///         incident cannot enact afterwards and silently restore a permission
///         that the emergency role revoked.
///      4. Allowance ceilings, so a budget motion cannot raise a cap beyond what
///         the DAO approved.
///
///      Membership changes are deliberately absent. Adding a member to a role is
///      a DAO-vote action through the Agent, not an objection-window motion.
contract PolicyAdminController {
    IRoles public immutable roles;
    address public immutable safe;
    bytes32 public immutable operatorRoleKey;
    bytes32 public immutable policyAdminRoleKey;

    /// @dev The DAO-controlled administrator: the Safe, reached by the Agent.
    address public owner;
    /// @dev The Easy Track script executor permitted to drive changes.
    address public governance;
    /// @dev Bumped on every successful change; names the state a motion assumed.
    uint256 public policyVersion;

    mapping(address => bool) public targetAllowed;
    mapping(address => mapping(bytes4 => bool)) public selectorAllowed;
    mapping(bytes32 => uint128) public allowanceCeiling;

    error NotOwner();
    error NotGovernance();
    error StaleVersion(uint256 expected, uint256 actual);
    error AdministrativeTarget(address target);
    error TargetNotAllowed(address target);
    error SelectorNotAllowed(address target, bytes4 selector);
    error AboveCeiling(bytes32 key, uint128 requested, uint128 ceiling);
    error ModifierCallFailed();

    event PolicyVersionBumped(uint256 newVersion, address by);
    event TargetAllowanceSet(address target, bool allowed);
    event SelectorAllowanceSet(address target, bytes4 selector, bool allowed);
    event AllowanceCeilingSet(bytes32 key, uint128 ceiling);
    event GovernanceSet(address governance);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyGovernance(uint256 expectedVersion) {
        if (msg.sender != governance) revert NotGovernance();
        if (expectedVersion != policyVersion) revert StaleVersion(expectedVersion, policyVersion);
        _;
        unchecked {
            policyVersion++;
        }
        emit PolicyVersionBumped(policyVersion, msg.sender);
    }

    constructor(
        IRoles _roles,
        address _safe,
        address _owner,
        address _governance,
        bytes32 _operatorRoleKey,
        bytes32 _policyAdminRoleKey
    ) {
        roles = _roles;
        safe = _safe;
        owner = _owner;
        governance = _governance;
        operatorRoleKey = _operatorRoleKey;
        policyAdminRoleKey = _policyAdminRoleKey;
    }

    // ------------------------------------------------------------------
    // DAO-controlled configuration
    // ------------------------------------------------------------------

    function setGovernance(address _governance) external onlyOwner {
        governance = _governance;
        emit GovernanceSet(_governance);
    }

    function setTargetAllowed(address target, bool allowed) external onlyOwner {
        _requireNotAdministrative(target);
        targetAllowed[target] = allowed;
        emit TargetAllowanceSet(target, allowed);
    }

    function setSelectorAllowed(address target, bytes4 selector, bool allowed) external onlyOwner {
        _requireNotAdministrative(target);
        selectorAllowed[target][selector] = allowed;
        emit SelectorAllowanceSet(target, selector, allowed);
    }

    function setAllowanceCeiling(bytes32 key, uint128 ceiling) external onlyOwner {
        allowanceCeiling[key] = ceiling;
        emit AllowanceCeilingSet(key, ceiling);
    }

    /// @dev Incident control: invalidates every motion built against the
    ///      current version without changing any permission.
    function bumpPolicyVersion() external onlyOwner {
        unchecked {
            policyVersion++;
        }
        emit PolicyVersionBumped(policyVersion, msg.sender);
    }

    // ------------------------------------------------------------------
    // Governance-driven changes — the four RFP change types
    // ------------------------------------------------------------------

    function addTarget(address target, uint256 expectedVersion)
        external
        onlyGovernance(expectedVersion)
    {
        _requireAllowedTarget(target);
        _exec(abi.encodeCall(IRoles.scopeTarget, (operatorRoleKey, target)));
    }

    function removeTarget(address target, uint256 expectedVersion)
        external
        onlyGovernance(expectedVersion)
    {
        _requireNotAdministrative(target);
        _exec(abi.encodeCall(IRoles.revokeTarget, (operatorRoleKey, target)));
    }

    function addFunction(
        address target,
        bytes4 selector,
        IRoles.ConditionFlat[] calldata conditions,
        uint256 expectedVersion
    ) external onlyGovernance(expectedVersion) {
        _requireAllowedSelector(target, selector);
        _exec(
            abi.encodeCall(IRoles.scopeFunction, (operatorRoleKey, target, selector, conditions, 0))
        );
    }

    function removeFunction(address target, bytes4 selector, uint256 expectedVersion)
        external
        onlyGovernance(expectedVersion)
    {
        _requireNotAdministrative(target);
        _exec(abi.encodeCall(IRoles.revokeFunction, (operatorRoleKey, target, selector)));
    }

    function setOperatorAllowance(
        bytes32 key,
        uint128 balance,
        uint128 maxRefill,
        uint128 refill,
        uint64 period,
        uint64 timestamp,
        uint256 expectedVersion
    ) external onlyGovernance(expectedVersion) {
        uint128 ceiling = allowanceCeiling[key];
        if (balance > ceiling) revert AboveCeiling(key, balance, ceiling);
        if (maxRefill > ceiling) revert AboveCeiling(key, maxRefill, ceiling);
        if (refill > ceiling) revert AboveCeiling(key, refill, ceiling);
        _exec(
            abi.encodeCall(
                IRoles.setAllowance, (key, balance, maxRefill, refill, period, timestamp)
            )
        );
    }

    // ------------------------------------------------------------------
    // internals
    // ------------------------------------------------------------------

    function _requireNotAdministrative(address target) internal view {
        if (target == address(roles) || target == safe) revert AdministrativeTarget(target);
    }

    function _requireAllowedTarget(address target) internal view {
        _requireNotAdministrative(target);
        if (!targetAllowed[target]) revert TargetNotAllowed(target);
    }

    function _requireAllowedSelector(address target, bytes4 selector) internal view {
        _requireAllowedTarget(target);
        if (!selectorAllowed[target][selector]) revert SelectorNotAllowed(target, selector);
    }

    function _exec(bytes memory data) internal {
        bool ok = roles.execTransactionWithRole(
            address(roles), 0, data, 0, policyAdminRoleKey, true
        );
        if (!ok) revert ModifierCallFailed();
    }
}
