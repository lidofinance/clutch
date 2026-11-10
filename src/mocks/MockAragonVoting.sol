// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {OwnableInline} from "./MockAragonAgent.sol";

/// @title MockAragonVoting — dry-run stand-in for Aragon Voting
///        (0x2e59A20f205bB85a89C53f1936454680651E618e), the only owner of the
///        vault's Safes (OD-73).
/// @dev A passed vote runs its call script with Voting's own authority. The
///      mock's `execute` stands in for one call of such a script; it has no
///      vote, quorum or delay. Voting authorizes a Safe transaction only by
///      `approveHash` or by sending it itself, never by a contract signature
///      (INV-001), so the kit calls `approveHash` through `execute`
///      (src/exec/SafeExec.sol). The enabling-vote rehearsal runs the real
///      Voting instead (test/EnablingVoteRehearsal.t.sol).
contract MockAragonVoting is OwnableInline {
    event Executed(address indexed to, uint256 value, bytes data);

    constructor() OwnableInline(msg.sender) {}

    /// @dev One call of a passed vote's script, with Voting's authority.
    function execute(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = to.call{value: value}(data);
        require(ok, "VOTING: execute reverted");
        emit Executed(to, value, data);
        return ret;
    }

    receive() external payable {}
}
