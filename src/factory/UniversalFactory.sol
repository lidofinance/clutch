// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";

/// @title UniversalFactory — Clutch's one Easy Track factory.
/// @notice Easy Track registers this factory with one permission: its own `applyMotion`. The
///         factory holds the motion roles on the vault's four modifiers. A motion is a list of
///         raw writes: each names a modifier, a role, a target and the call's data, and the
///         factory makes it as that role through the modifier. The factory builds no permission
///         and checks no content: each modifier's own policy decides what a role may write.
/// @dev The factory keeps two numbers. The counter fails every open motion when the emergency
///      Safe or Aragon Voting raises it. The policy version fails a motion that writes on one
///      of the four modifiers if another such motion was enacted after its creation, so two
///      motions cannot undo each other's permission writes. A motion that only acts, such as a burn or
///      a payout, states the counter alone. A script of one call keeps the enactment under
///      EIP-7825's cap on a transaction's gas, because Easy Track's executor copies a script
///      into memory three times for each call.
contract UniversalFactory {
    /// @dev One call of a modifier's `execTransactionWithRole`, as a plain call without value.
    struct Write {
        address modifier_;
        bytes32 role;
        address to;
        bytes data;
    }

    struct Config {
        address trustedCaller; // the committee's Safe
        address executor; // Easy Track's script executor
        address emergencySafe;
        address voting;
        address operatorModifier;
        address safetyModifier;
        address ordersModifier;
        address firstLossModifier;
    }

    uint256 public constant MAX_WRITES = 64;

    error NotTrustedCaller(address creator);
    error NotExecutor(address caller);
    error NotAllowedToRaiseCounter(address caller);
    error StaleCounter(uint256 motion, uint256 current);
    error StalePolicyVersion(uint256 motion, uint256 current);
    error NoWrites();
    error TooManyWrites();
    error UnknownModifier(address modifier_);
    error WriteFailed(uint256 index);

    event CounterRaised(uint256 epoch, address by);
    event PolicyVersionSet(uint256 version);

    address public immutable trustedCaller;
    address public immutable executor;
    address public immutable emergencySafe;
    address public immutable voting;
    address public immutable operatorModifier;
    address public immutable safetyModifier;
    address public immutable ordersModifier;
    address public immutable firstLossModifier;

    /// @notice The counter. A raise makes every open motion fail at enactment.
    uint256 public epoch;
    /// @notice The number of enacted motions that wrote on one of the four modifiers.
    uint256 public policyVersion;

    constructor(Config memory c) {
        trustedCaller = c.trustedCaller;
        executor = c.executor;
        emergencySafe = c.emergencySafe;
        voting = c.voting;
        operatorModifier = c.operatorModifier;
        safetyModifier = c.safetyModifier;
        ordersModifier = c.ordersModifier;
        firstLossModifier = c.firstLossModifier;
    }

    /// @notice Builds the script of a motion, after the checks. The script makes one call: this
    ///         factory's `applyMotion`, with the motion's calldata. Easy Track calls this at
    ///         creation and again at enactment.
    function createEVMScript(address creator, bytes calldata callData) external view returns (bytes memory) {
        if (creator != trustedCaller) revert NotTrustedCaller(creator);
        _check(callData);
        bytes memory call = abi.encodeCall(this.applyMotion, (callData));
        return abi.encodePacked(bytes4(0x00000001), address(this), uint32(call.length), call);
    }

    /// @notice The one call of every motion's script, which only Easy Track's executor makes, at
    ///         enactment. It checks the motion again and makes its writes, in order. A write
    ///         that its modifier refuses fails the whole motion.
    function applyMotion(bytes calldata callData) external {
        if (msg.sender != executor) revert NotExecutor(msg.sender);
        (Write[] memory writes, bool policy) = _check(callData);
        if (policy) {
            policyVersion += 1;
            emit PolicyVersionSet(policyVersion);
        }
        for (uint256 i = 0; i < writes.length; i++) {
            Write memory w = writes[i];
            (bool ok, bytes memory ret) =
                w.modifier_.call(abi.encodeCall(IRoles.execTransactionWithRole, (w.to, 0, w.data, 0, w.role, true)));
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 32), mload(ret))
                }
            }
            // A modifier's `execTransactionWithRole` returns true. An account without code returns nothing.
            if (ret.length != 32 || !abi.decode(ret, (bool))) revert WriteFailed(i);
        }
    }

    /// @notice The motion's calldata, decoded for display: the counter and the policy version
    ///         that the motion saw, and its writes.
    function decodeEVMScriptCallData(bytes calldata callData)
        external
        pure
        returns (uint256 motionEpoch, uint256 motionPolicyVersion, Write[] memory writes)
    {
        return abi.decode(callData, (uint256, uint256, Write[]));
    }

    /// @notice Easy Track's permissions for this factory: one call, its own `applyMotion`.
    function addressBook() public view returns (bytes memory) {
        return abi.encodePacked(address(this), this.applyMotion.selector);
    }

    /// @notice Raises the counter, so that every open motion fails at enactment. The emergency
    ///         Safe raises it at every stop; Aragon Voting can raise it as the owner.
    function raiseCounter() external {
        if (msg.sender != emergencySafe && msg.sender != voting) revert NotAllowedToRaiseCounter(msg.sender);
        epoch += 1;
        emit CounterRaised(epoch, msg.sender);
    }

    /// @dev The checks of a motion: the counter, the number of writes, the modifier of each
    ///      write, and the policy version if a write's target is one of the four modifiers.
    function _check(bytes calldata callData) internal view returns (Write[] memory writes, bool policy) {
        uint256 motionEpoch;
        uint256 motionPolicyVersion;
        (motionEpoch, motionPolicyVersion, writes) = abi.decode(callData, (uint256, uint256, Write[]));
        if (motionEpoch != epoch) revert StaleCounter(motionEpoch, epoch);
        if (writes.length == 0) revert NoWrites();
        if (writes.length > MAX_WRITES) revert TooManyWrites();
        for (uint256 i = 0; i < writes.length; i++) {
            if (!_isModifier(writes[i].modifier_)) revert UnknownModifier(writes[i].modifier_);
            if (_isModifier(writes[i].to)) policy = true;
        }
        if (policy && motionPolicyVersion != policyVersion) {
            revert StalePolicyVersion(motionPolicyVersion, policyVersion);
        }
    }

    function _isModifier(address a) internal view returns (bool) {
        return a == operatorModifier || a == safetyModifier || a == ordersModifier || a == firstLossModifier;
    }
}
