// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script} from "forge-std/Script.sol";

/// @title Broadcast — the signer of the dry-run scripts (ADR 012).
/// @dev A mainnet run signs with a Foundry keystore that the command line names,
///      `--account <name> --sender <address>`, and forge asks for its password, so
///      no private key sits in `.env`. A local anvil rehearsal may set PRIVATE_KEY
///      in the environment of one command instead.
abstract contract Broadcast is Script {
    /// @return signer The address that signs every broadcast transaction.
    function _startBroadcast() internal returns (address signer) {
        uint256 key = vm.envOr("PRIVATE_KEY", uint256(0));
        if (key != 0) {
            vm.startBroadcast(key);
            return vm.addr(key);
        }
        vm.startBroadcast();
        (, signer,) = vm.readCallers();
    }
}
