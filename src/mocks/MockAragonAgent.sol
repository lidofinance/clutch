// SPDX-License-Identifier: LGPL-3.0-only
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
/// @dev Fidelity contract (WS-M R17): this mock implements the same execution
///      interface and flow the real Agent exposes to the treasury graph:
///      - `forward(address,bytes)`: gated exactly like the real Agent's
///        forward, which requires RUN_SCRIPT_ROLE on the ACL. Here the role is
///        emulated with an allowlist (the owner and explicitly permitted
///        runners, i.e. the MockEVMScriptExecutor).
///      - `execute(address,uint256,bytes)`: the direct execution path used by
///        EVM scripts that need Agent authority, owner-gated here.
///      - receives ETH and tokens like the real Agent.
///      Everything downstream (Safe, Roles modifier, tokens, protocols) is the
///      production deployment; only this head is mocked. Controlled by a
///      dedicated throwaway EOA (the "executor"), never a production signer.
contract MockAragonAgent is OwnableInline {
    event Forwarded(address indexed to, bytes data);
    event Executed(address indexed to, uint256 value, bytes data);

    /// @dev emulates ACL RUN_SCRIPT_ROLE holders on the real Agent.
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

    /// @dev Real Agent.forward: performs `to.call(data)` with Agent authority.
    ///      Restricted to RUN_SCRIPT_ROLE holders on mainnet; onlyRunner here.
    function forward(address to, bytes calldata data) external payable onlyRunner {
        (bool ok, bytes memory ret) = to.call{value: 0}(data);
        require(ok, _returndataToBubbles(ret));
        emit Forwarded(to, data);
    }

    /// @dev Real Agent.execute: performs a call with value from Agent authority.
    function execute(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = to.call{value: value}(data);
        require(ok, _returndataToBubbles(ret));
        emit Executed(to, value, data);
        return ret;
    }

    receive() external payable {}

    function _returndataToBubbles(bytes memory ret) internal pure returns (string memory) {
        // Bubble revert strings from downstream (Safe/Roles) for debuggability.
        if (ret.length >= 4) {
            bytes4 selector = bytes4(ret);
            // RoleViolation(bytes32,address) and similar custom errors surface as raw;
            // string errors decode cleanly.
            if (selector == 0x08c379a0) {
                return abi.decode(_slice(ret, 4), (string));
            }
        }
        return "AGENT: call reverted";
    }

    function _slice(bytes memory data, uint256 start) internal pure returns (bytes memory) {
        bytes memory out = new bytes(data.length - start);
        for (uint256 i = start; i < data.length; i++) {
            out[i - start] = data[i];
        }
        return out;
    }
}
