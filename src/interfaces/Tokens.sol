// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

/// @dev Minimal token and protocol interfaces used by the dry-run kit.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

interface IStETH {
    function submit(address referral) external payable returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

interface ISDAI {
    function deposit(uint256 _assets, address _receiver) external returns (uint256);

    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256);

    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256);
}

interface IAaveV3Pool {
    // Verified: supply is (asset, amount, onBehalfOf, referralCode).
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    function refundETH() external payable;
}

interface ILidoEarnDepositQueue {
    // Signatures verified against the constellation ABI set (docs.lido.fi earn
    // deployment) and cross-checked on-chain in WS-B:
    function deposit(uint224 amount, address referral, bytes32[] calldata proof) external;

    function cancelDepositRequest() external;

    function claim(address receiver) external;
}

interface ILidoEarnRedeemQueue {
    function redeem(uint256 shareAmount) external;

    function claim(address receiver, uint32[] calldata redeemIds) external;
}

interface ICowSettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
    /// @dev Marks the order UID filled so it cannot be reused by re-signing.
    ///      Checks that the caller owns the UID. Selector 0x15337bc0.
    function invalidateOrder(bytes calldata orderUid) external;
}
