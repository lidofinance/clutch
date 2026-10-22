// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

/// @title VoteBuilder — encodings for the enabling-vote rehearsal.
/// @dev Aragon CallsScript (spec 1): [spec(4)] then, per call, [to(20)][len(uint32)][calldata].
///      Safe MultiSendCallOnly: per call, [operation(1)][to(20)][value(32)][len(32)][calldata].
///      Easy Track permissions: per allowed call, [target(20)][selector(4)].
///      Aragon ACL param: [id(8 bits)][op(8 bits)][value(240 bits)].
///      The encoders size the output first and copy each part once, because
///      repeated concatenation of a 60 KB payload costs quadratic memory gas.
library VoteBuilder {
    bytes4 internal constant SPEC = 0x00000001;

    struct Item {
        address to;
        bytes data;
        string label;
    }

    function script(Item[] memory items) internal pure returns (bytes memory s) {
        uint256 size = 4;
        for (uint256 i = 0; i < items.length; i++) size += 24 + items[i].data.length;
        s = new bytes(size);
        uint256 at = _put(s, 0, abi.encodePacked(SPEC));
        for (uint256 i = 0; i < items.length; i++) {
            at = _put(s, at, abi.encodePacked(bytes20(items[i].to), uint32(items[i].data.length)));
            at = _put(s, at, items[i].data);
        }
    }

    function multiSend(Item[] memory calls) internal pure returns (bytes memory) {
        uint256 size;
        for (uint256 i = 0; i < calls.length; i++) size += 85 + calls[i].data.length;
        bytes memory packed = new bytes(size);
        uint256 at;
        for (uint256 i = 0; i < calls.length; i++) {
            at = _put(packed, at, abi.encodePacked(uint8(0), calls[i].to, uint256(0), uint256(calls[i].data.length)));
            at = _put(packed, at, calls[i].data);
        }
        return abi.encodeWithSignature("multiSend(bytes)", packed);
    }

    function permission(address target, bytes4 selector) internal pure returns (bytes memory) {
        return abi.encodePacked(target, selector);
    }

    function aclParam(uint8 id, uint8 op, uint240 value) internal pure returns (uint256) {
        return (uint256(id) << 248) | (uint256(op) << 240) | uint256(value);
    }

    /// @dev The intrinsic gas of a transaction with this calldata, and the
    ///      EIP-7623 floor. A transaction is valid only if its gas limit covers
    ///      the larger one, and EIP-7825 caps that limit at 2^24.
    function intrinsicGas(bytes memory data) internal pure returns (uint256 standard, uint256 floor) {
        uint256 zeros;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0) zeros++;
        }
        uint256 tokens = zeros + 4 * (data.length - zeros);
        standard = 21_000 + 4 * tokens;
        floor = 21_000 + 10 * tokens;
    }

    /// @dev Copies `part` into `out` at byte offset `at`; returns the next
    ///      offset. Whole words first, then the tail byte by byte, so nothing
    ///      is written outside `out`.
    function _put(bytes memory out, uint256 at, bytes memory part) private pure returns (uint256) {
        uint256 n = part.length;
        require(at + n <= out.length, "VoteBuilder: overflow");
        uint256 whole = n - (n % 32);
        assembly {
            let dst := add(add(out, 0x20), at)
            let src := add(part, 0x20)
            for { let i := 0 } lt(i, whole) { i := add(i, 0x20) } { mstore(add(dst, i), mload(add(src, i))) }
        }
        for (uint256 i = whole; i < n; i++) out[at + i] = part[i];
        return at + n;
    }
}
