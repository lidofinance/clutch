// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

interface IWstETHRate {
    function stEthPerToken() external view returns (uint256);
}

/// @title LikeForLikeBound — a research prototype, not a production contract
/// @notice A custom condition for a Roles modifier. It bounds the price of an order whose two tokens are of one
///         class: dollar stablecoins, or ETH and its Lido tokens. Inside a class the tokens count at par, and
///         wstETH counts at its own rate in stETH. An order of two classes, or of an unknown token, passes: the
///         contract reads no market price, so it cannot judge it.
/// @dev The modifier calls `check` with the whole calldata and the place of the parameter that carries the
///      condition. The condition sits on the sold amount, the fourth field of CoW's order and of a TWAP order's
///      data; both start with the sold token, the bought token, the receiver, the sold amount and the bought
///      amount. `extra` is the tolerance in basis points.
contract LikeForLikeBound {
    uint8 internal constant NONE = 0;
    uint8 internal constant DOLLAR = 1;
    uint8 internal constant ETHER = 2;

    address public immutable USDC;
    address public immutable USDT;
    address public immutable USDS;
    address public immutable WETH;
    address public immutable STETH;
    address public immutable WSTETH;

    constructor(address usdc, address usdt, address usds, address weth, address steth, address wsteth) {
        (USDC, USDT, USDS, WETH, STETH, WSTETH) = (usdc, usdt, usds, weth, steth, wsteth);
    }

    function check(address, uint256, bytes calldata data, uint8, uint256 location, uint256, bytes12 extra)
        external
        view
        returns (bool success, bytes32 reason)
    {
        uint256 tolerance = uint96(extra);
        if (tolerance > 10_000) return (false, "tolerance");
        // three words before the sold amount, and the bought amount after it
        if (location < 4 + 96 || data.length < location + 64) return (false, "layout");
        address sell = address(uint160(uint256(bytes32(data[location - 96:location - 64]))));
        address buy = address(uint160(uint256(bytes32(data[location - 64:location - 32]))));
        (uint8 sellClass, uint256 sold) = _value(sell, uint256(bytes32(data[location:location + 32])));
        (uint8 buyClass, uint256 bought) = _value(buy, uint256(bytes32(data[location + 32:location + 64])));
        if (sellClass == NONE || sellClass != buyClass) return (true, 0);
        if (bought * 10_000 < sold * (10_000 - tolerance)) return (false, "below par");
        return (true, 0);
    }

    /// @dev A token's class and an amount's value in the class's unit, with 18 decimals.
    function _value(address token, uint256 amount) internal view returns (uint8, uint256) {
        if (token == USDC || token == USDT) return (DOLLAR, amount * 1e12);
        if (token == USDS) return (DOLLAR, amount);
        if (token == WETH || token == STETH) return (ETHER, amount);
        if (token == WSTETH) return (ETHER, amount * IWstETHRate(WSTETH).stEthPerToken() / 1e18);
        return (NONE, 0);
    }
}
