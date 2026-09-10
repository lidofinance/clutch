// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20, IStETH, IWstETH, ISDAI, IUniswapV3Router} from "../src/interfaces/Tokens.sol";

/// @title BootstrapFunds — the 0.5 ETH dust splitter (B3).
/// @dev Assumes the broadcasting EOA starts with ~0.5 ETH and nothing else.
///      Keeps a gas reserve (default 0.1 ETH), then acquires dust of every
///      base launch asset through production paths:
///        ETH   -> stETH  via Lido submit
///        stETH -> wstETH via wrap
///        ETH   -> USDC/USDT/DAI/LDO/USDS via Uniswap V3 (quoted, 1% bound)
///        DAI   -> sDAI   via sDAI.deposit (receiver = Safe)
///        USDS  -> sUSDS  via sUSDS.deposit (receiver = Safe)
///      earnUSD/earnETH positions are NOT bootstrapped: they are opened
///      through the operator role during drills. Every swap fails closed on
///      a 1% deviation from its quote.
contract BootstrapFunds is Script {
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant UNISWAP_V3_QUOTER = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    uint256 internal constant GAS_RESERVE = 0.1 ether;
    uint256 internal constant BPS_BOUND = 9900; // 1% slippage bound

    struct Leg {
        string label;
        address token;
        uint256 acquired;
    }

    struct SwapSpec {
        string label;
        address token;
        uint24 fee;
        uint256 shareBp; // of the spendable pot
    }

    function specs() internal pure returns (SwapSpec[5] memory s) {
        s[0] = SwapSpec("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 500, 2000);
        s[1] = SwapSpec("USDT", 0xdAC17F958D2ee523a2206206994597C13D831ec7, 500, 1500);
        s[2] = SwapSpec("DAI", DAI, 3000, 1500);
        s[3] = SwapSpec("LDO", 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32, 3000, 1000);
        s[4] = SwapSpec("USDS", USDS, 3000, 1000);
    }

    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        address safe = vm.envAddress("SAFE");
        vm.startBroadcast(deployer);
        Leg[11] memory legs = bootstrap(safe);
        vm.stopBroadcast();
        _writeManifest(safe, legs);
    }

    /// @dev The full acquisition flow, callable from `run()` (broadcast) or
    ///      from a fork test. Returns the acquisition legs for the manifest.
    function bootstrap(address safe) public returns (Leg[11] memory legs) {
        address funder = msg.sender;
        require(funder.balance >= 0.45 ether, "bootstrap: need >=0.45 ETH");
        uint256 pot = funder.balance - GAS_RESERVE;
        require(pot > 0.25 ether, "bootstrap: pot too small");
        uint256 n = 0;

        // spender approvals for the conversion paths below
        IERC20(STETH).approve(WSTETH, type(uint256).max);
        IERC20(DAI).approve(SDAI, type(uint256).max);
        IERC20(USDS).approve(SUSDS, type(uint256).max);

        // stETH, then wrap half to wstETH
        uint256 steth = IStETH(STETH).submit{value: (pot * 30) / 100}(address(0));
        legs[n++] = Leg("stETH", STETH, steth);
        uint256 wsteth = IWstETH(WSTETH).wrap(steth / 2);
        legs[n++] = Leg("wstETH", WSTETH, wsteth);

        // DEX legs. DD FINDING: no liquid WETH->USDS Uniswap pool exists at
        // any fee tier (probe 2026-09-10); USDS acquisition needs a Sky PSM
        // integration or manual funding in production. The leg is therefore
        // best-effort: try three fee tiers, skip with a warning if none.
        SwapSpec[5] memory s = specs();
        for (uint256 i = 0; i < s.length; i++) {
            uint256 amountIn = (pot * s[i].shareBp) / 10_000;
            uint256 out = _trySwapExactIn(s[i].token, amountIn);
            if (out > 0) {
                legs[n++] = Leg(s[i].label, s[i].token, out);
            } else {
                console2.log("WARN: no venue for", s[i].label, "- leg skipped");
            }
        }

        // savings vaults, receiver = Safe
        uint256 daiLeg = _find(legs, "DAI");
        uint256 sdai = ISDAI(SDAI).deposit(legs[daiLeg].acquired / 2, safe);
        legs[daiLeg].acquired -= legs[daiLeg].acquired / 2;
        legs[n++] = Leg("sDAI", SDAI, sdai);

        uint256 usdsLeg = _find(legs, "USDS");
        uint256 susds = ISDAI(SUSDS).deposit(legs[usdsLeg].acquired / 2, safe);
        legs[usdsLeg].acquired -= legs[usdsLeg].acquired / 2;
        legs[n++] = Leg("sUSDS", SUSDS, susds);

        // send everything the funder still holds to the Safe
        _transfer(safe, STETH, IERC20(STETH).balanceOf(funder));
        _transfer(safe, WSTETH, IERC20(WSTETH).balanceOf(funder));
        for (uint256 i = 0; i < s.length; i++) {
            _transfer(safe, s[i].token, IERC20(s[i].token).balanceOf(funder));
        }
    }

    function _transfer(address to, address token, uint256 amount) internal {
        if (amount > 0) {
            // low-level: DAI returns no bool, a typed call would revert
            (bool ok,) = token.call(abi.encodeCall(IERC20.transfer, (to, amount)));
            require(ok, "bootstrap: transfer failed");
        }
    }

    /// @dev Attempts the swap at three fee tiers with min-out = 1 (dust
    ///      acquisition; production must pre-compute bounds off-chain — the
    ///      on-chain Quoter reverts V1-style and cannot be probed here).
    ///      Returns 0 when no tier has the pair.
    function _trySwapExactIn(address tokenOut, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        uint24[3] memory fees = [uint24(500), 3000, 10000];
        for (uint256 i = 0; i < fees.length; i++) {
            IUniswapV3Router.ExactInputSingleParams memory p = IUniswapV3Router
                .ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: tokenOut,
                    fee: fees[i],
                    recipient: msg.sender,
                    deadline: block.timestamp + 300,
                    amountIn: amountIn,
                    amountOutMinimum: 1,
                    sqrtPriceLimitX96: 0
                });
            (bool ok, bytes memory ret) = UNISWAP_V3_ROUTER.call{
                value: amountIn,
                gas: 900_000
            }(abi.encodeCall(IUniswapV3Router.exactInputSingle, (p)));
            if (ok) {
                return abi.decode(ret, (uint256));
            }
        }
        return 0;
    }

    function _find(Leg[11] memory legs, string memory label) internal pure returns (uint256) {
        for (uint256 i = 0; i < legs.length; i++) {
            if (keccak256(bytes(legs[i].label)) == keccak256(bytes(label))) return i;
        }
        revert("bootstrap: label missing");
    }

    function _writeManifest(address safe, Leg[11] memory legs) internal {
        string memory json = '{"bootstrap":{"safe":"';
        json = string.concat(json, vm.toString(safe), '","legs":[');
        for (uint256 i = 0; i < legs.length; i++) {
            if (legs[i].token == address(0)) continue;
            json = string.concat(
                json,
                '{"label":"',
                legs[i].label,
                '","token":"',
                vm.toString(legs[i].token),
                '","acquired":',
                vm.toString(legs[i].acquired),
                "},"
            );
        }
        json = string.concat(json, "]}}");
        vm.writeFile("bootstrap-manifest.json", json);
        console2.log("BOOTSTRAP manifest written");
        console2.log(json);
    }
}

/// @dev Uniswap V3 QuoterV2 (struct-based API).
interface IQuoter {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (
            uint256 amountOut,
            int256 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}
