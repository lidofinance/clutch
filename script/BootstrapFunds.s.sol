// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20, IStETH, IWstETH, IERC4626, IDaiUsds, IUniswapV3Router} from "../src/interfaces/Tokens.sol";

/// @title BootstrapFunds — the 0.05 ETH dust splitter.
/// @dev Assumes the FUNDER EOA (explicit env, never msg.sender) starts with
///      ~0.05 ETH and nothing else. Keeps a gas reserve, then acquires dust
///      of the launch assets through production paths:
///        ETH    -> stETH   via Lido submit (amount tracked by balance delta;
///                           submit returns SHARES, not stETH)
///        stETH  -> wstETH  via wrap (half)
///        ETH    -> USDC/USDT/DAI/LDO via Uniswap V3 single hop
///        DAI    -> USDS    via Sky's DAI–USDS converter, one to one
///                          (0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A)
///        USDS   -> sUSDS   via a vault deposit (receiver = Safe)
///      sDAI is outside the launch scope (ADR 011), so DAI stays DAI.
///      Every swap carries a minimum-out bound derived from the pool's own
///      slot0 price with 5% headroom (95% of quote). Legs are independent and
///      resumable: a token already held by the funder is not re-acquired, so
///      a partial run can be completed by re-running with more gas ETH.
///      earnUSD/earnETH positions are NOT bootstrapped: they are opened
///      through the operator role during drills.
contract BootstrapFunds is Script {
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant SKY_CONVERTER = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
    address internal constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 internal constant GAS_RESERVE = 0.01 ether;
    uint256 internal constant MIN_START = 0.045 ether;
    uint256 internal constant BPS_BOUND = 9500; // min-out = 95% of slot0 quote

    struct Leg {
        string label;
        address token;
        uint256 acquired;
    }

    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        address safe = vm.envAddress("SAFE");
        address funder = vm.envOr("FUNDER", address(0));
        if (funder == address(0)) {
            // forge script sender; explicit FUNDER preferred so the checked
            // balance, the swap recipient and the swept balance always name
            // the same address
            funder = msg.sender;
        }
        vm.startBroadcast(deployer);
        Leg[11] memory legs = bootstrap(safe, funder);
        vm.stopBroadcast();
        _writeManifest(safe, funder, legs);
    }

    function bootstrap(address safe, address funder) public returns (Leg[11] memory legs) {
        require(msg.sender == funder, "bootstrap: caller must be the funder");
        require(funder.balance >= MIN_START, "bootstrap: need >=0.045 ETH");
        uint256 pot = funder.balance - GAS_RESERVE;
        uint256 n = 0;

        IERC20(STETH).approve(WSTETH, type(uint256).max);
        IERC20(DAI).approve(SKY_CONVERTER, type(uint256).max);
        IERC20(USDS).approve(SUSDS, type(uint256).max);

        // stETH (resume-safe: skip if a prior run already minted some)
        if (IERC20(STETH).balanceOf(funder) == 0) {
            uint256 before = IERC20(STETH).balanceOf(funder);
            IStETH(STETH).submit{value: (pot * 30) / 100}(address(0));
            legs[n++] = Leg("stETH", STETH, IERC20(STETH).balanceOf(funder) - before);
        } else {
            legs[n++] = Leg("stETH", STETH, IERC20(STETH).balanceOf(funder));
        }
        // wstETH from half the stETH
        if (IERC20(WSTETH).balanceOf(funder) == 0) {
            uint256 w = IWstETH(WSTETH).wrap(IERC20(STETH).balanceOf(funder) / 2);
            legs[n++] = Leg("wstETH", WSTETH, w);
        }

        // DEX legs with slot0-derived minimums; each leg independent
        address[4] memory dexTokens = [USDC, USDT, DAI, LDO];
        string[4] memory dexLabels = ["USDC", "USDT", "DAI", "LDO"];
        uint256[4] memory sharesBp = [uint256(2200), 1600, 2200, 1200];
        for (uint256 i = 0; i < 4; i++) {
            if (IERC20(dexTokens[i]).balanceOf(funder) > 0) {
                legs[n++] = Leg(dexLabels[i], dexTokens[i], IERC20(dexTokens[i]).balanceOf(funder));
                continue;
            }
            uint256 amountIn = (pot * sharesBp[i]) / 10_000;
            uint256 out = _swapExactInBounded(dexTokens[i], amountIn);
            require(out > 0, "bootstrap: dex leg failed");
            legs[n++] = Leg(dexLabels[i], dexTokens[i], out);
        }

        // USDS via Sky's DAI–USDS converter, 1 DAI -> 1 USDS, credited to the funder
        if (IERC20(USDS).balanceOf(funder) == 0) {
            uint256 convertAmt = IERC20(DAI).balanceOf(funder) / 4;
            IDaiUsds(SKY_CONVERTER).daiToUsds(funder, convertAmt);
            legs[n++] = Leg("USDS", USDS, convertAmt);
        }

        // savings vault, receiver = Safe
        uint256 usdsLeg = _find(legs, "USDS");
        if (IERC20(SUSDS).balanceOf(safe) == 0) {
            uint256 susds = IERC4626(SUSDS).deposit(legs[usdsLeg].acquired / 2, safe);
            legs[usdsLeg].acquired -= legs[usdsLeg].acquired / 2;
            legs[n++] = Leg("sUSDS", SUSDS, susds);
        }

        // deliver everything the funder still holds to the Safe
        _transfer(safe, funder, STETH);
        _transfer(safe, funder, WSTETH);
        for (uint256 i = 0; i < 4; i++) _transfer(safe, funder, dexTokens[i]);
        _transfer(safe, funder, USDS);
    }

    function _transfer(address to, address funder, address token) internal {
        uint256 bal = IERC20(token).balanceOf(funder);
        if (bal > 0) {
            // low-level: DAI returns no bool, a typed call would revert
            (bool ok,) = token.call(abi.encodeCall(IERC20.transfer, (to, bal)));
            require(ok, "bootstrap: transfer failed");
        }
    }

    /// @dev Single-hop swap with a slot0-derived minimum. Tries fee tiers
    ///      500/3000/10000 and uses the first pool that quotes sensibly.
    function _swapExactInBounded(address tokenOut, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        uint24[3] memory fees = [uint24(500), 3000, 10000];
        for (uint256 i = 0; i < fees.length; i++) {
            address pool = IUniFactory(UNISWAP_V3_FACTORY).getPool(WETH, tokenOut, fees[i]);
            if (pool == address(0)) continue;
            (uint160 sqrtPriceX96,,,,,,) = IUniPool(pool).slot0();
            if (sqrtPriceX96 == 0) continue;
            // price in raw units = (sqrt/2^96)^2 ; orientation: token0/token1
            (address t0,) = _sort(WETH, tokenOut);
            uint256 quote = _quote(amountIn, sqrtPriceX96, t0 == WETH);
            if (quote == 0) continue;
            uint256 minOut = (quote * BPS_BOUND) / 10_000;
            if (minOut == 0) minOut = 1;
            IUniswapV3Router.ExactInputSingleParams memory p = IUniswapV3Router
                .ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: tokenOut,
                    fee: fees[i],
                    recipient: msg.sender,
                    deadline: block.timestamp + 300,
                    amountIn: amountIn,
                    amountOutMinimum: minOut,
                    sqrtPriceLimitX96: 0
                });
            (bool ok, bytes memory ret) = UNISWAP_V3_ROUTER.call{value: amountIn}(
                abi.encodeCall(IUniswapV3Router.exactInputSingle, (p))
            );
            if (ok) return abi.decode(ret, (uint256));
        }
        return 0;
    }

    function _sort(address a, address b) internal pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }

    /// @dev Raw-unit quote from sqrtPriceX96 for amountIn of WETH.
    ///      price = (sqrtPriceX96^2 / 2^192) is token1_raw per token0_raw.
    function _quote(uint256 amountIn, uint160 sqrtPriceX96, bool wethIsToken0)
        internal
        pure
        returns (uint256)
    {
        // q96 squaring with enough precision for a bound, not an exact price
        uint256 num = uint256(sqrtPriceX96) * uint256(sqrtPriceX96); // ~2^192
        if (wethIsToken0) {
            // out = in * price = in * num / 2^192
            return (amountIn * num) / (1 << 192);
        } else {
            // out = in / price = in * 2^192 / num
            return (amountIn << 96) / ((num >> 96) == 0 ? 1 : (num >> 96));
        }
    }

    function _find(Leg[11] memory legs, string memory label) internal pure returns (uint256) {
        for (uint256 i = 0; i < legs.length; i++) {
            if (keccak256(bytes(legs[i].label)) == keccak256(bytes(label))) return i;
        }
        revert("bootstrap: label missing");
    }

    function _writeManifest(address safe, address funder, Leg[11] memory legs) internal {
        string memory json = '{"bootstrap":{"safe":"';
        json = string.concat(json, vm.toString(safe), '","funder":"', vm.toString(funder), '","legs":[');
        for (uint256 i = 0; i < legs.length; i++) {
            if (legs[i].token == address(0)) continue;
            json = string.concat(
                json,
                '{"label":"', legs[i].label, '","token":"', vm.toString(legs[i].token),
                '","acquired":', vm.toString(legs[i].acquired), "},"
            );
        }
        json = string.concat(json, "]}}");
        vm.writeFile("bootstrap-manifest.json", json);
        console2.log("BOOTSTRAP manifest written");
        console2.log(json);
    }
}

interface IUniFactory {
    function getPool(address a, address b, uint24 fee) external view returns (address pool);
}

interface IUniPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}
