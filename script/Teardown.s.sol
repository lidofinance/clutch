// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {SafeExec} from "../src/policy/SafeExec.sol";

/// @title Teardown — reverses a dry-run.
/// @dev Sweeps every tracked token from the Asset Safe back to the funder
///      through the owner path (the same power a DAO recovery action has),
///      then disables the Roles module. Writes a final manifest.
contract Teardown is Script {
    address internal constant SENTINEL = address(0x0000000000000000000000000000000000000001);

    function _tokens() internal pure returns (address[17] memory TOKENS) {
        TOKENS[0] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // stETH
        TOKENS[1] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        TOKENS[2] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // LDO
        TOKENS[3] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        TOKENS[4] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        TOKENS[5] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        TOKENS[6] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA; // sDAI
        TOKENS[7] = 0xdC035D45d973E3EC169d2276DDab16f1e407384F; // USDS
        TOKENS[8] = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD; // sUSDS
        TOKENS[9] = 0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981; // earnUSD share
        TOKENS[10] = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4; // earnETH share
        TOKENS[11] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c; // aUSDC
        TOKENS[12] = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a; // aUSDT
        TOKENS[13] = 0x018008bfb33d285247A21d44E50697654f754e63; // aDAI
        TOKENS[14] = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259; // aUSDS
        TOKENS[15] = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371; // awstETH
        TOKENS[16] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH (dust)
    }

    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        address payable agentAddr = payable(vm.envAddress("AGENT"));
        address safeAddr = vm.envAddress("SAFE");
        address rolesAddr = vm.envAddress("ROLES");
        vm.startBroadcast(deployer);
        address beneficiary = msg.sender;

        MockAragonAgent agent = MockAragonAgent(agentAddr);
        ISafe safe = ISafe(payable(safeAddr));

        // sweep as the owner — the DAO-recovery-equivalent power
        address[17] memory tokens = _tokens();
        uint256 swept = 0;
        for (uint256 i = 0; i < 17; i++) {
            uint256 bal = IERC20(tokens[i]).balanceOf(safeAddr);
            if (bal > 0) {
                SafeExec.execAsOwner(
                    agent,
                    safe,
                    tokens[i],
                    abi.encodeCall(IERC20.transfer, (beneficiary, bal))
                );
                swept++;
            }
        }
        // native dust left in the Safe is intentionally not swept: the exec
        // helper is value-less and the amounts are negligible. Documented.

        // disable the Roles module (leave the Safe inert under owner control)
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        bool disabled = false;
        for (uint256 i = 0; i < mods.length; i++) {
            if (mods[i] == rolesAddr) {
                address prev = i == 0 ? SENTINEL : mods[i - 1];
                SafeExec.execAsOwner(
                    agent,
                    safe,
                    safeAddr,
                    abi.encodeCall(ISafe.disableModule, (prev, rolesAddr))
                );
                disabled = true;
            }
        }

        vm.stopBroadcast();
        string memory json = string.concat(
            '{"teardown":{"safe":"',
            vm.toString(safeAddr),
            '","tokensSwept":',
            vm.toString(swept),
            ',"moduleDisabled":',
            disabled ? "true" : "false",
            ',"beneficiary":"',
            vm.toString(beneficiary),
            '","timestamp":',
            vm.toString(block.timestamp),
            "}}"
        );
        vm.writeFile("teardown-manifest.json", json);
        console2.log(json);
    }
}
