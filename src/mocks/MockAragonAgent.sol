// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

/// @dev Minimal owner guard, inlined to keep the dry-run kit dependency-free.
abstract contract OwnableInline {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "OWN: not owner");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }
}

/// @title MockAragonAgent — dry-run stand-in for the Lido DAO Aragon Agent
///        (0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c).
/// @dev Fidelity contract: the real Agent implements the Aragon forwarder with a SINGLE-argument
///      `forward(bytes)` (selector 0xd948d468; the two-argument form does not
///      exist on the deployed implementation), plus `execute(address,
///      uint256, bytes)` and `canForward(address,bytes)`. The Agent itself
///      parses the CallsScript blob it is handed and executes each chunk with
///      its own authority.
///      On the real Agent these are gated by Aragon ACL roles. At the pinned
///      block the ONLY holder of RUN_SCRIPT_ROLE and EXECUTE_ROLE on the
///      Agent is the Dual Governance admin executor
///      0x23E0B465633FF5178808F4A75186E2F2F9537021; the Easy Track EVM script
///      executor holds NEITHER. The mock mirrors that: `permittedRunners`
///      starts EMPTY. The dry-run must not paper over the missing Easy Track
///      grant — ET-driven policy changes run through the policy-admin role on
///      the Roles modifier instead (see FullPolicy / Drills D1), which needs
///      no Agent authority at all.
contract MockAragonAgent is OwnableInline {
    event Forwarded(bytes evmScript);
    event Executed(address indexed to, uint256 value, bytes data);

    /// @dev mirrors ACL RUN_SCRIPT_ROLE holders; deliberately empty at birth.
    mapping(address => bool) public permittedRunners;

    modifier onlyRunner() {
        require(permittedRunners[msg.sender] || msg.sender == owner, "AGENT: not a runner");
        _;
    }

    constructor() OwnableInline(msg.sender) {}

    function permitRunner(address runner) external onlyOwner {
        permittedRunners[runner] = true;
    }

    function revokeRunner(address runner) external onlyOwner {
        permittedRunners[runner] = false;
    }

    /// @dev Aragon forwarder: parse and execute a CallsScript blob as the
    ///      Agent. Spec 0x00000001, chunks of [to (20)][len (uint32)][calldata]
    ///      where len covers selector and args. The length field is a uint32;
    ///      no production script uses a 32-byte word.
    function forward(bytes memory evmScript) public payable onlyRunner {
        require(evmScript.length >= 4, "AGENT: short script");
        require(bytes4(evmScript) == 0x00000001, "AGENT: unknown spec");
        uint256 location = 4;
        while (location < evmScript.length) {
            require(location + 24 <= evmScript.length, "AGENT: truncated header");
            address to;
            uint256 len;
            assembly {
                to := shr(96, mload(add(add(evmScript, 0x20), location)))
                len := shr(224, mload(add(add(evmScript, 0x20), add(location, 20))))
            }
            location += 24;
            require(len != 0, "AGENT: empty chunk");
            require(location + len <= evmScript.length, "AGENT: truncated chunk");
            bytes memory cd = new bytes(len);
            for (uint256 i = 0; i < len; i++) {
                cd[i] = evmScript[location + i];
            }
            (bool ok,) = to.call(cd);
            require(ok, "AGENT: chunk reverted");
            location += len;
        }
        emit Forwarded(evmScript);
    }

    /// @dev AragonApp execute path: one arbitrary call with Agent authority.
    function execute(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = to.call{value: value}(data);
        require(ok, "AGENT: execute reverted");
        emit Executed(to, value, data);
        return ret;
    }

    /// @dev AragonForwarder::canForward — reports whether the ACL would let
    ///      the caller forward. Mirrors the deployed answer for the executor.
    function canForward(address, bytes memory) external view returns (bool) {
        return permittedRunners[msg.sender] || msg.sender == owner;
    }

    receive() external payable {}
}
