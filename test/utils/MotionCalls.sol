// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {Call} from "../../src/exec/SafeExec.sol";

/// @title MotionCalls — test inputs for governance motions.
/// @dev Encodes the admin calls that a governance motion carries in the
///      drills, such as a replacement approve scope. These are test inputs,
///      not the policy: the policy comes only from the compiled artifact
///      (ADR 004, decision 15). The Easy Track template factories will build
///      such trees on chain (ADR 006).
library MotionCalls {
    bytes32 internal constant OPERATOR = bytes32("operator");

    /// @dev One spender of an operator approval: the budget key that the
    ///      spender serves, or a fixed ceiling for a spender with no key.
    struct Spender {
        address spender;
        bytes32 key; // non-zero: the approval spends this budget key
        uint256 cap; // used when key is zero: the approval must be below it
    }

    function keyed(address spender, bytes32 key) internal pure returns (Spender memory) {
        return Spender({spender: spender, key: key, cap: 0});
    }

    function capped(address spender, uint256 cap) internal pure returns (Spender memory) {
        return Spender({spender: spender, key: bytes32(0), cap: cap});
    }

    function spenders(Spender memory s) internal pure returns (Spender[] memory r) {
        r = new Spender[](1);
        r[0] = s;
    }

    function spenders(Spender memory s0, Spender memory s1) internal pure returns (Spender[] memory r) {
        r = new Spender[](2);
        r[0] = s0;
        r[1] = s1;
    }

    /// @dev token.approve(spender, amount) for the operator (ADR 009, OD-08):
    ///      a root Or with one Matches branch per spender. A keyed branch
    ///      spends the key; a capped branch must stay below the ceiling.
    ///      Layout (BFS): [0] Or; [1..n] Matches; then, per branch, the
    ///      spender EqualTo and the amount condition.
    function opApprove(address roles, address token, Spender[] memory s) internal pure returns (Call memory) {
        uint256 n = s.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](1 + 3 * n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 0, operator_: 2, compValue: ""});
        for (uint256 i = 0; i < n; i++) {
            uint8 b = uint8(1 + i);
            uint256 k = 1 + n + 2 * i;
            c[b] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""});
            c[k] = IRoles.ConditionFlat({
                parent: b,
                paramType: 1,
                operator_: 16,
                compValue: abi.encodePacked(bytes32(uint256(uint160(s[i].spender))))
            });
            c[k + 1] = s[i].key != bytes32(0)
                ? IRoles.ConditionFlat({parent: b, paramType: 1, operator_: 28, compValue: abi.encodePacked(s[i].key)})
                : IRoles.ConditionFlat({parent: b, paramType: 1, operator_: 18, compValue: abi.encodePacked(bytes32(s[i].cap))});
        }
        return Call({
            to: roles,
            data: abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, IERC20.approve.selector, c, 0))
        });
    }
}
