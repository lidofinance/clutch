// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../../src/interfaces/IRoles.sol";

/// @title BudgetFactoryStandIn — a test stand-in for the budget factory of ADR 009.
/// @dev Not the production factory, which is not built yet. It lets the
///      rehearsal drive the live Easy Track, its live script executor and the
///      governance role end to end: a motion sets one budget key through
///      `execTransactionWithRole` on the operator modifier. The production
///      factory must also bound each key's figures; this stand-in does not.
contract BudgetFactoryStandIn {
    bytes32 internal constant GOVERNANCE = bytes32("governance");

    address public immutable trustedCaller;
    address public immutable operatorModifier;

    constructor(address _trustedCaller, address _operatorModifier) {
        trustedCaller = _trustedCaller;
        operatorModifier = _operatorModifier;
    }

    function createEVMScript(address _creator, bytes memory _evmScriptCallData) external view returns (bytes memory) {
        require(_creator == trustedCaller, "CALLER_IS_FORBIDDEN");
        (bytes32 key, uint128 balance, uint128 maxRefill, uint128 refill, uint64 period) =
            abi.decode(_evmScriptCallData, (bytes32, uint128, uint128, uint128, uint64));
        bytes memory inner = abi.encodeCall(IRoles.setAllowance, (key, balance, maxRefill, refill, period, 0));
        bytes memory call_ =
            abi.encodeCall(IRoles.execTransactionWithRole, (operatorModifier, 0, inner, 0, GOVERNANCE, true));
        return abi.encodePacked(bytes4(0x00000001), bytes20(operatorModifier), uint32(call_.length), call_);
    }

    function decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        external
        pure
        returns (bytes32, uint128, uint128, uint128, uint64)
    {
        return abi.decode(_evmScriptCallData, (bytes32, uint128, uint128, uint128, uint64));
    }
}
