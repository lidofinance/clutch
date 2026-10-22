// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../src/interfaces/IRoles.sol";
import {ClutchFixture} from "./utils/Fixture.sol";

contract RolesPaginationTest is ClutchFixture {
    // Zodiac ModuleManager uses an address cursor, including the sentinel.
    function test_pagination_abi_matches_deployed_roles() public view {
        (bool ok, bytes memory result) = address(roles).staticcall(
            abi.encodeWithSelector(IRoles.getModulesPaginated.selector, uint256(1), uint256(16))
        );
        assertTrue(ok, "pagination selector must match deployed Roles");
        (address[] memory members, address next) = abi.decode(result, (address[], address));
        assertEq(next, SENTINEL);
        assertEq(members.length, 2);
        assertTrue(
            (members[0] == operatorSafe && members[1] == address(executor))
                || (members[1] == operatorSafe && members[0] == address(executor)),
            "operator and governance members"
        );
    }
}
