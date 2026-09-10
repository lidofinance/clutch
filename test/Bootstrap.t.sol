// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {BootstrapFunds} from "../script/BootstrapFunds.s.sol";

/// @title BootstrapDrill — proves the 0.5 ETH splitter on a mainnet fork:
///        real Lido submit, real wstETH wrap, real Uniswap V3 swaps, real
///        sDAI/sUSDS deposits, everything landing in the Asset Safe.
contract BootstrapDrill is Test {
    function test_bootstrap_from_half_eth() public {
        string memory rpc = vm.envOr("RPC", string("https://ethereum-rpc.publicnode.com"));
        vm.createSelectFork(rpc, 25946643);
        address safe = makeAddr("asset-safe");
        deal(address(this), 0.5 ether);

        BootstrapFunds bf = new BootstrapFunds();
        vm.deal(address(bf), 0.05 ether);
        vm.prank(address(bf));
        bf.bootstrap(safe, address(bf));

        assertGt(IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84).balanceOf(safe), 0, "stETH");
        assertGt(IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0).balanceOf(safe), 0, "wstETH");
        assertGt(IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(safe), 0, "USDC");
        assertGt(IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(safe), 0, "USDT");
        assertGt(IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(safe), 0, "DAI");
        assertGt(IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32).balanceOf(safe), 0, "LDO");
        assertGt(IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F).balanceOf(safe), 0, "USDS");
        assertGt(IERC20(0x83F20F44975D03b1b09e64809B757c47f942BEeA).balanceOf(safe), 0, "sDAI");
        assertGt(IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD).balanceOf(safe), 0, "sUSDS");
        // gas reserve preserved
        assertGe(address(bf).balance, 0.009 ether, "gas reserve");
    }
}
