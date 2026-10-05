// SPDX-License-Identifier: AGPL-3.0-or-later
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
    /// @dev Returns shares, not stETH. Read the stETH amount from the balance.
    function submit(address referral) external payable returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function getPooledEthByShares(uint256 sharesAmount) external view returns (uint256);
}

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

interface IWETH {
    function deposit() external payable;

    /// @dev Pays ETH to the caller with a transfer that forwards 2,300 gas.
    function withdraw(uint256 wad) external;
}

/// @dev ERC-4626 subset; sUSDS implements it.
interface IERC4626 {
    function deposit(uint256 _assets, address _receiver) external returns (uint256);

    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256);

    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256);
}

/// @dev Sky's DaiUsds converter, 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A:
///      one to one, no fee, pays `usr`.
interface IDaiUsds {
    function daiToUsds(address usr, uint256 wad) external;

    function usdsToDai(address usr, uint256 wad) external;
}

/// @dev Lido withdrawal queue, 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1.
interface IWithdrawalQueue {
    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds);

    /// @dev Pays each request's ETH to the caller, who must own the request.
    function claimWithdrawals(uint256[] calldata _requestIds, uint256[] calldata _hints) external;

    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getLastRequestId() external view returns (uint256);

    function getLastCheckpointIndex() external view returns (uint256);

    function unfinalizedStETH() external view returns (uint256);

    function findCheckpointHints(uint256[] calldata _requestIds, uint256 _firstIndex, uint256 _lastIndex)
        external
        view
        returns (uint256[] memory hintIds);

    function ownerOf(uint256 _requestId) external view returns (address);
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

/// @dev Lido Earn queues. The kit checked these signatures on chain at the
///      fork block 25946643.
interface ILidoEarnDepositQueue {
    function deposit(uint224 amount, address referral, bytes32[] calldata proof) external;

    function cancelDepositRequest() external;

    function claim(address receiver) external;
}

interface ILidoEarnRedeemQueue {
    function redeem(uint256 shareAmount) external;

    function claim(address receiver, uint32[] calldata redeemIds) external;
}
