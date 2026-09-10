// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";

contract PolicyShape is Test {
    function test_policy_builds() public pure {
        Policy.Addresses memory a;
        a.safe = address(0x51);
        a.agent = address(0xA1);
        a.operator = address(0x0F);
        a.emergency = address(0xE5);
        Policy.fillTokens(a);
        Policy.fillProtocols(a);
        Policy.fillAtokens(a);
        Policy.Call[] memory calls = FullPolicy.build(a, address(0x401e5));
        assertGt(calls.length, 80, "policy too small");
        assertLe(calls.length, 136, "policy too large");
        for (uint256 i = 0; i < calls.length; i++) {
            assertGt(calls[i].data.length, 4, "empty calldata");
            assertEq(calls[i].to, address(0x401e5), "target must be roles");
        }
    }
}
