// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";

interface ISepoliaWETH is IERC20 {
    function deposit() external payable;
}

contract FundSepolia is Script {
    function run() external {
        require(block.chainid == 11155111 && vm.envOr("CLUTCH_SEPOLIA", uint256(0)) == 1, "Sepolia opt-in required");
        string memory json = vm.readFile(vm.envOr("SEPOLIA_MANIFEST", string("cache/sepolia/manifest.json")));
        address controller = vm.envAddress("SEPOLIA_SENDER");
        require(
            vm.parseJsonUint(json, ".chainId") == block.chainid
                && vm.parseJsonAddress(json, ".controller") == controller,
            "Manifest differs"
        );
        uint256 wethAmount = vm.envUint("SEPOLIA_FUND_WETH_WEI");
        uint256 shareAmount = vm.envUint("SEPOLIA_FUND_SHARES_WEI");
        require(wethAmount > 0 && shareAmount > 0, "Select positive test funding");
        ISepoliaWETH weth = ISepoliaWETH(vm.parseJsonAddress(json, ".dependencies.tokens.weth.address"));
        address asset = vm.parseJsonAddress(json, ".assetSafe");
        address firstLoss = vm.parseJsonAddress(json, ".firstLossSafe");
        vm.startBroadcast(controller);
        weth.deposit{value: wethAmount}();
        require(weth.transfer(asset, wethAmount), "WETH funding");
        require(IERC20(vm.parseJsonAddress(json, ".usdShare")).transfer(firstLoss, shareAmount), "USD share funding");
        require(IERC20(vm.parseJsonAddress(json, ".ethShare")).transfer(firstLoss, shareAmount), "ETH share funding");
        vm.stopBroadcast();
    }
}
