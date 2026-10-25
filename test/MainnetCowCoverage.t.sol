// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ClutchFixture} from "./utils/Fixture.sol";
import {ISafe, ISafeProxyFactory} from "../src/interfaces/ISafe.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";
import {CoWOrder} from "../script/sepolia/CoWInterfaces.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";

interface IMainnetCowSettlement {
    struct Trade {
        uint256 sellTokenIndex;
        uint256 buyTokenIndex;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        uint256 flags;
        uint256 executedAmount;
        bytes signature;
    }

    struct Interaction {
        address target;
        uint256 value;
        bytes callData;
    }

    function authenticator() external view returns (address);
    function domainSeparator() external view returns (bytes32);
    function filledAmount(bytes calldata uid) external view returns (uint256);
    function preSignature(bytes calldata uid) external view returns (uint256);
    function setPreSignature(bytes calldata orderUid, bool signed) external;
    function settle(address[] calldata tokens, uint256[] calldata prices, Trade[] calldata trades,
        Interaction[][3] calldata interactions) external;
}

interface IMainnetCowAuthenticator {
    function isSolver(address solver) external view returns (bool);
}

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

interface IStETHFork {
    function submit(address referral) external payable returns (uint256);
    function sharesOf(address account) external view returns (uint256);
    function getTotalShares() external view returns (uint256);
    function getExternalShares() external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function getExternalEther() external view returns (uint256);
}

interface ITetherFork {
    function deprecated() external view returns (bool);
}

/// @dev The order Safe is local. Settlement, Vault Relayer and every token are live mainnet contracts.
///      These tests do not install the Clutch Orders policy or order signer.
contract MainnetCowCoverageTest is ClutchFixture {
    address internal constant SOLVER = 0xB222dA0F9c22AD2aDdCb0b0d6b150f398E44157A;
    address internal constant SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    IMainnetCowSettlement internal settlement;
    ISafe internal orders;

    function setUp() public override {
        super.setUp();
        settlement = IMainnetCowSettlement(SETTLEMENT);
        assertTrue(IMainnetCowAuthenticator(settlement.authenticator()).isSolver(SOLVER), "pinned solver is allowed");
        assertEq(Mainnet.USDT.codehash, 0xb44fb4e949d0f78f87f79ee46428f23a2a5713ce6fc6e0beb3dda78c2ac1ea55);
        assertFalse(ITetherFork(Mainnet.USDT).deprecated(), "USDT must use the verified original transfer path");

        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        bytes memory initializer = abi.encodeCall(
            ISafe.setup, (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        orders = ISafe(payable(ISafeProxyFactory(SAFE_PROXY_FACTORY).createProxyWithNonce(
            SAFE_SINGLETON, initializer, uint256(keccak256(abi.encodePacked("mainnet-cow-orders", address(this))))
        )));

        address[6] memory tokens = launchTokens();
        for (uint256 i; i < tokens.length; ++i) {
            ownerCall(address(orders), tokens[i], abi.encodeCall(IERC20.approve, (VAULT_RELAYER, type(uint256).max)));
            assertEq(IERC20(tokens[i]).allowance(address(orders), VAULT_RELAYER), type(uint256).max);
            assertEq(IERC20(tokens[i]).allowance(address(orders), attacker), 0);
        }
    }

    function test_MAIN11_all_ordered_launch_token_pairs_settle_with_exact_deltas() public {
        address[6] memory tokens = launchTokens();
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j; j < tokens.length; ++j) {
                if (i == j) continue;
                _settle(tokens[i], tokens[j], address(safe), uint256(1) + i * 6 + j);
            }
        }
    }

    function test_MAIN11_recovery_destinations_settle_launch_tokens_into_usdc_or_usdt() public {
        address[6] memory sells = launchTokens();
        address[2] memory buys = [Mainnet.USDC, Mainnet.USDT];
        for (uint256 i; i < sells.length; ++i) {
            for (uint256 j; j < buys.length; ++j) {
                if (sells[i] == buys[j]) continue;
                _settle(sells[i], buys[j], address(agent), uint256(100) + i * 2 + j);
            }
        }
    }

    function test_MAIN11_launch_token_decimals_match_the_order_unit_matrix() public view {
        address[6] memory tokens = launchTokens();
        uint8[6] memory expected = [uint8(18), 18, 18, 6, 6, 18];
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(IERC20Decimals(tokens[i]).decimals(), expected[i]);
        }
    }

    function _settle(address sellToken, address buyToken, address receiver, uint256 salt) internal {
        uint256 sellAmount = 10 ** uint256(IERC20Decimals(sellToken).decimals()) + 1;
        uint256 buyAmount = 2 * 10 ** uint256(IERC20Decimals(buyToken).decimals()) + 1;
        uint256 allowanceBefore = IERC20(sellToken).allowance(address(orders), VAULT_RELAYER);
        uint256 sellBefore = IERC20(sellToken).balanceOf(address(orders));
        uint256 receiverBefore = IERC20(buyToken).balanceOf(receiver);
        uint256 receiverSharesBefore = IStETHFork(Mainnet.STETH).sharesOf(receiver);

        if (sellToken == Mainnet.STETH) _fundStETH(address(orders));
        else deal(sellToken, address(orders), sellBefore + sellAmount);
        if (buyToken == Mainnet.STETH) _fundStETH(SETTLEMENT);
        else deal(buyToken, SETTLEMENT, IERC20(buyToken).balanceOf(SETTLEMENT) + buyAmount);
        uint256 sellSharesFunded = IStETHFork(Mainnet.STETH).sharesOf(address(orders));
        uint256 settlementBefore = IERC20(buyToken).balanceOf(SETTLEMENT);
        uint256 settlementSharesBefore = IStETHFork(Mainnet.STETH).sharesOf(SETTLEMENT);
        uint256 stethShares;
        if (sellToken == Mainnet.STETH || buyToken == Mainnet.STETH) {
            IStETHFork ledger = IStETHFork(Mainnet.STETH);
            uint256 internalShares = ledger.getTotalShares() - ledger.getExternalShares();
            uint256 internalEther = ledger.getTotalPooledEther() - ledger.getExternalEther();
            uint256 amount = sellToken == Mainnet.STETH ? sellAmount : buyAmount;
            stethShares = amount * internalShares / internalEther;
        }

        CoWOrder.Data memory order = CoWOrder.Data({
            sellToken: sellToken,
            buyToken: buyToken,
            receiver: receiver,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: uint32(block.timestamp + 1 days),
            appData: bytes32(salt),
            feeAmount: 0,
            kind: keccak256("sell"),
            partiallyFillable: false,
            sellTokenBalance: keccak256("erc20"),
            buyTokenBalance: keccak256("erc20")
        });
        bytes memory uid = abi.encodePacked(CoWOrder.digest(order, settlement.domainSeparator()), address(orders), order.validTo);
        ownerCall(address(orders), SETTLEMENT, abi.encodeCall(IMainnetCowSettlement.setPreSignature, (uid, true)));
        assertGt(settlement.preSignature(uid), 0);

        address[] memory settlementTokens = new address[](2);
        settlementTokens[0] = sellToken;
        settlementTokens[1] = buyToken;
        uint256[] memory prices = new uint256[](2);
        prices[0] = buyAmount;
        prices[1] = sellAmount;
        IMainnetCowSettlement.Trade[] memory trades = new IMainnetCowSettlement.Trade[](1);
        trades[0] = IMainnetCowSettlement.Trade(
            0, 1, receiver, sellAmount, buyAmount, order.validTo, order.appData, 0, 3 << 5, sellAmount,
            abi.encodePacked(address(orders))
        );
        IMainnetCowSettlement.Interaction[][3] memory interactions;
        for (uint256 i; i < interactions.length; ++i) interactions[i] = new IMainnetCowSettlement.Interaction[](0);

        vm.prank(SOLVER);
        settlement.settle(settlementTokens, prices, trades, interactions);

        assertEq(settlement.filledAmount(uid), sellAmount);
        if (sellToken == Mainnet.STETH) {
            assertEq(sellSharesFunded - stethShares, IStETHFork(Mainnet.STETH).sharesOf(address(orders)));
        } else {
            assertEq(IERC20(sellToken).balanceOf(address(orders)), sellBefore);
        }
        if (buyToken == Mainnet.STETH) {
            assertEq(IStETHFork(Mainnet.STETH).sharesOf(receiver), receiverSharesBefore + stethShares);
            assertEq(IStETHFork(Mainnet.STETH).sharesOf(SETTLEMENT), settlementSharesBefore - stethShares);
        } else {
            assertEq(IERC20(buyToken).balanceOf(receiver), receiverBefore + buyAmount);
            assertEq(IERC20(buyToken).balanceOf(SETTLEMENT), settlementBefore - buyAmount);
        }
        uint256 allowanceAfter = IERC20(sellToken).allowance(address(orders), VAULT_RELAYER);
        uint256 expectedAllowance = allowanceBefore;
        if (sellToken == Mainnet.USDC || sellToken == Mainnet.WSTETH) expectedAllowance -= sellAmount;
        assertEq(allowanceAfter, expectedAllowance, "Unexpected token-specific relayer allowance");
    }

    function _fundStETH(address recipient) internal {
        vm.deal(recipient, 2 ether);
        vm.prank(recipient);
        IStETHFork(Mainnet.STETH).submit{value: 2 ether}(address(0));
    }

    function launchTokens() internal pure returns (address[6] memory) {
        return [Mainnet.STETH, Mainnet.WSTETH, Mainnet.WETH, Mainnet.USDC, Mainnet.USDT, Mainnet.USDS];
    }

    function ownerCall(address account, address to, bytes memory data) internal {
        vm.startPrank(principal);
        SafeExec.execAsOwner(MockAragonAgent(payable(address(agent))), ISafe(payable(account)), to, data);
        vm.stopPrank();
    }
}
