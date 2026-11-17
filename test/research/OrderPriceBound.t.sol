// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {UniversalFactory} from "../../src/factory/UniversalFactory.sol";
import {Mainnet} from "../rehearsal/Mainnet.sol";
import {EnabledVault} from "../rehearsal/EnabledVault.sol";
import {Order} from "../OrdersAccount.t.sol";
import {LikeForLikeBound, IWstETHRate} from "./LikeForLikeBound.sol";

interface ISigner {
    function signOrder(Order calldata order, uint32 validDuration, uint256 feeAmountBP) external;
}

struct TwapParams {
    address handler;
    bytes32 salt;
    bytes staticInput;
}

interface IConditional {
    function createWithContext(TwapParams calldata params, address factory, bytes calldata data, bool dispatch) external;
}

/// @title A research probe (OD-154): a price bound on chain for like-for-like orders, with no outside price feed
/// @dev The bound is a custom condition on the sold amount of an operator's order. A motion of the orders
///      modifier's governance role installs it. The probe shows what the bound refuses and what it lets through.
contract OrderPriceBoundResearch is EnabledVault {
    bytes32 internal constant KIND_SELL = keccak256("sell");
    bytes32 internal constant KIND_BUY = keccak256("buy");
    bytes32 internal constant BALANCE_ERC20 = keccak256("erc20");
    uint8 internal constant CALL = 0;
    uint8 internal constant DELEGATECALL = 1;
    uint8 internal constant OPTIONS_DELEGATECALL = 2;
    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_CUSTOM = 22;
    uint32 internal constant LIFE = 90 days;
    /// @dev A test value: 1%.
    uint96 internal constant TOLERANCE = 100;
    bytes4 internal constant SIGN = ISigner.signOrder.selector;
    bytes4 internal constant CREATE = IConditional.createWithContext.selector;
    bytes4 internal constant CONDITION_VIOLATION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    /// @dev `Status.CustomConditionViolation` of the modifier.
    uint8 internal constant CUSTOM_VIOLATION = 16;

    LikeForLikeBound internal condition;

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
        condition = new LikeForLikeBound(Mainnet.USDC, Mainnet.USDT, Mainnet.USDS, Mainnet.WETH, Mainnet.STETH, Mainnet.WSTETH);
    }

    modifier enabled() {
        _enable();
        _;
    }

    /// @dev Before the bound, the operator signs a stablecoin order at half of par. A motion installs the bound.
    ///      After it, the modifier refuses that order and takes orders within the tolerance.
    function test_research_a_motion_installs_the_bound_and_it_holds_like_for_like_orders() public enabled {
        Order memory half = _order(Mainnet.USDC, Mainnet.USDT, 4_000e6, 2_000e6, KIND_SELL);
        _sign(half, true);

        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](1);
        ws[0] = _w(
            ordersMod,
            GOVERNANCE,
            address(ordersMod),
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.ORDER_SIGNER, SIGN, _bounded(SIGN, 0), OPTIONS_DELEGATECALL))
        );
        uint256 gasUsed = _motion(ws);
        console2.log("RESEARCH bound installed by one motion: writes, enactMotion gas", ws.length, gasUsed);
        console2.log("RESEARCH condition contract: bytes of code", address(condition).code.length);

        // dollar stablecoins, at par across decimals
        _refusedByBound(half);
        _sign(_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_990e6, KIND_SELL), true);
        _sign(_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_980e6, KIND_SELL), true);
        _refusedByBound(_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_980e6 - 1, KIND_SELL));
        _sign(_order(Mainnet.USDC, Mainnet.USDS, 1_000e6, 995e18, KIND_SELL), true);
        // the bought amount in the sold token's decimals: a slip of twelve digits
        _refusedByBound(_order(Mainnet.USDC, Mainnet.USDS, 1_000e6, 995e6, KIND_SELL));
        _sign(_order(Mainnet.USDS, Mainnet.USDT, 1_000e18, 995e6, KIND_SELL), true);
        _refusedByBound(_order(Mainnet.USDS, Mainnet.USDT, 1_000e18, 500e6, KIND_SELL));
        // a buy order: at most 1,010.1 USDC for 1,000 USDT
        _sign(_order(Mainnet.USDC, Mainnet.USDT, 1_010e6, 1_000e6, KIND_BUY), true);
        _refusedByBound(_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_000e6, KIND_BUY));

        // ETH and its Lido tokens: stETH and WETH at par, wstETH at its own rate
        _sign(_order(Mainnet.STETH, Mainnet.WETH, 10e18, 9.95e18, KIND_SELL), true);
        _refusedByBound(_order(Mainnet.STETH, Mainnet.WETH, 10e18, 9e18, KIND_SELL));
        uint256 rate = IWstETHRate(Mainnet.WSTETH).stEthPerToken();
        _sign(_order(Mainnet.WSTETH, Mainnet.WETH, 10e18, 10 * rate * 995 / 1000, KIND_SELL), true);
        // wstETH counted as if it were stETH: about a fifth below its rate
        _refusedByBound(_order(Mainnet.WSTETH, Mainnet.WETH, 10e18, 10e18, KIND_SELL));
        _sign(_order(Mainnet.WETH, Mainnet.WSTETH, 10e18, 10e18 * 1e18 / rate * 995 / 1000, KIND_SELL), true);
        _refusedByBound(_order(Mainnet.WETH, Mainnet.WSTETH, 10e18, 5e18, KIND_SELL));
        console2.log("RESEARCH wstETH rate read from the token", rate);
    }

    /// @dev What the bound does not hold: an order of two classes. The contract reads no market price, so the
    ///      operator still signs 1,000,000 USDC for 1 wei of WETH, and 100 WETH for 1 unit of USDC.
    function test_research_the_bound_lets_an_order_of_two_classes_through() public enabled {
        _install();
        _sign(_order(Mainnet.USDC, Mainnet.WETH, 1_000_000e6, 1, KIND_SELL), true);
        _sign(_order(Mainnet.WETH, Mainnet.USDC, 100e18, 1, KIND_SELL), true);
        _sign(_order(Mainnet.WSTETH, Mainnet.USDT, 100e18, 1, KIND_SELL), true);
        // the same hostile signer cannot do it inside a class
        _refusedByBound(_order(Mainnet.USDC, Mainnet.USDT, 1_000_000e6, 1, KIND_SELL));
        _refusedByBound(_order(Mainnet.WETH, Mainnet.STETH, 100e18, 1, KIND_SELL));
    }

    /// @dev The emergency role's recovery orders keep no bound (OD-48), and the operator's other pins hold.
    function test_research_the_bound_leaves_the_other_rules_as_they_are() public enabled {
        _install();
        Order memory recovery = _order(Mainnet.USDS, Mainnet.USDC, 1_000e18, 1, KIND_SELL);
        recovery.receiver = Mainnet.AGENT;
        vm.prank(address(emergency));
        ordersMod.execTransactionWithRole(Mainnet.ORDER_SIGNER, 0, abi.encodeCall(ISigner.signOrder, (recovery, 1 days, 0)), DELEGATECALL, EMERGENCY, true);

        Order memory stranger = _order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_990e6, KIND_SELL);
        stranger.receiver = Mainnet.AGENT;
        _sign(stranger, false);
        Order memory unlisted = _order(Mainnet.DAI, Mainnet.USDT, 2_000e18, 1_990e6, KIND_SELL);
        _sign(unlisted, false);
    }

    /// @dev The same condition on a TWAP order's data: the part's sold amount and its least bought amount.
    function test_research_the_bound_on_a_twap_order() public enabled {
        vm.prank(address(orders));
        ordersMod.scopeFunction(OPERATOR, Mainnet.COMPOSABLE_COW, CREATE, _bounded(CREATE, 1), CALL);
        _twap(Mainnet.USDC, Mainnet.USDT, 1_000e6, 990e6, 2, 1 days, true);
        _twap(Mainnet.USDC, Mainnet.USDT, 1_000e6, 500e6, 3, 1 days, false);
        _twap(Mainnet.USDC, Mainnet.USDT, 1_000e6, 990e6, 12, 7 days, true);
        _twap(Mainnet.STETH, Mainnet.WETH, 1e18, 0.5e18, 12, 7 days, false);
        // two classes: through
        _twap(Mainnet.USDC, Mainnet.WETH, 1_000e6, 1, 4, 1 days, true);
    }

    /// @dev The contract's own answers at its edges.
    function test_research_the_condition_refuses_a_bad_layout_and_a_bad_tolerance() public {
        bytes memory data = abi.encodeCall(ISigner.signOrder, (_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 1_990e6, KIND_SELL), LIFE, 0));
        (bool ok,) = condition.check(address(0), 0, data, 0, 100, 32, bytes12(uint96(100)));
        assertTrue(ok, "the order's sold amount is at byte 100");
        // the check's own gas, on warm accounts: a stablecoin pair, and a pair that reads the wstETH rate
        uint256 g = gasleft();
        condition.check(address(0), 0, data, 0, 100, 32, bytes12(uint96(100)));
        uint256 stable = g - gasleft();
        bytes memory wrapped = abi.encodeCall(ISigner.signOrder, (_order(Mainnet.WSTETH, Mainnet.WETH, 10e18, 12.4e18, KIND_SELL), LIFE, 0));
        condition.check(address(0), 0, wrapped, 0, 100, 32, bytes12(uint96(100)));
        g = gasleft();
        (ok,) = condition.check(address(0), 0, wrapped, 0, 100, 32, bytes12(uint96(100)));
        console2.log("RESEARCH the check's gas: a stablecoin pair, a pair with wstETH", stable, g - gasleft());
        assertTrue(ok, "wstETH at its rate");
        (ok,) = condition.check(address(0), 0, data, 0, 100, 32, bytes12(uint96(10_001)));
        assertFalse(ok, "a tolerance above 100%");
        (ok,) = condition.check(address(0), 0, data, 0, 36, 32, bytes12(uint96(100)));
        assertFalse(ok, "too near the start");
        (ok,) = condition.check(address(0), 0, data, 0, data.length - 32, 32, bytes12(uint96(100)));
        assertFalse(ok, "no word after the amount");
        // a tolerance of zero takes par and refuses one unit less
        (ok,) = condition.check(address(0), 0, abi.encodeCall(ISigner.signOrder, (_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 2_000e6, KIND_SELL), LIFE, 0)), 0, 100, 32, bytes12(0));
        assertTrue(ok, "par");
        (ok,) = condition.check(address(0), 0, abi.encodeCall(ISigner.signOrder, (_order(Mainnet.USDC, Mainnet.USDT, 2_000e6, 2_000e6 - 1, KIND_SELL), LIFE, 0)), 0, 100, 32, bytes12(0));
        assertFalse(ok, "one unit below par");
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// @dev The operator's committed tree for `selector`, with the condition on each sold amount. In the order
    ///      signer's tree the sold amount is the fourth field of the order. In a TWAP order's tree each shape has
    ///      its own data, so each fourth field of a data node takes the condition.
    function _bounded(bytes4 selector, uint8 kind) internal returns (IRoles.ConditionFlat[] memory c) {
        c = _tree(ordersMod, OPERATOR, kind == 0 ? Mainnet.ORDER_SIGNER : Mainnet.COMPOSABLE_COW, selector);
        bytes memory value = abi.encodePacked(address(condition), bytes12(TOLERANCE));
        uint256 placed;
        for (uint256 parent = 0; parent < c.length; parent++) {
            // a node with at least ten children, of which the fourth passes: an order or a TWAP order's data
            uint256 seen;
            uint256 fourth;
            for (uint256 i = 0; i < c.length; i++) {
                if (i != parent && c[i].parent == parent) {
                    if (seen == 3) fourth = i;
                    seen++;
                }
            }
            if (seen >= 10 && c[fourth].operator_ == OP_PASS) {
                c[fourth].operator_ = OP_CUSTOM;
                c[fourth].compValue = value;
                placed++;
            }
        }
        assertEq(placed, kind == 0 ? 1 : 2, "one condition for the order, and one for each TWAP shape");
        console2.log("RESEARCH tree nodes, conditions placed", c.length, placed);
    }

    function _install() internal {
        vm.prank(address(orders));
        ordersMod.scopeFunction(OPERATOR, Mainnet.ORDER_SIGNER, SIGN, _bounded(SIGN, 0), OPTIONS_DELEGATECALL);
    }

    function _order(address sell, address buy, uint256 sellAmount, uint256 buyAmount, bytes32 kind) internal view returns (Order memory) {
        return Order(sell, buy, address(asset), sellAmount, buyAmount, uint32(block.timestamp + 1 hours), bytes32(0), 0, kind, false, BALANCE_ERC20, BALANCE_ERC20);
    }

    /// @dev The operator signs `o` through the order signer; returns the call's gas.
    function _sign(Order memory o, bool expectOk) internal returns (uint256 gasUsed) {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 g = gasleft();
        (bool ok,) = address(ordersMod).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (Mainnet.ORDER_SIGNER, 0, abi.encodeCall(ISigner.signOrder, (o, LIFE, 0)), DELEGATECALL, OPERATOR, true))
        );
        gasUsed = g - gasleft();
        assertEq(ok, expectOk, "the operator's order");
    }

    /// @dev Refused by the custom condition, and by nothing else.
    function _refusedByBound(Order memory o) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok, bytes memory ret) = address(ordersMod).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (Mainnet.ORDER_SIGNER, 0, abi.encodeCall(ISigner.signOrder, (o, LIFE, 0)), DELEGATECALL, OPERATOR, true))
        );
        assertFalse(ok, "the bound refuses the order");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "a condition violation");
        (uint8 status, bytes32 reason) = abi.decode(_tail(ret), (uint8, bytes32));
        assertEq(status, CUSTOM_VIOLATION, "the custom condition refused");
        assertEq(reason, bytes32("below par"), "the contract's reason");
    }

    function _twap(address sell, address buy, uint256 part, uint256 least, uint256 n, uint256 t, bool expectOk) internal {
        bytes memory input = abi.encode(sell, buy, address(asset), part, least, uint256(0), n, t, uint256(0), bytes32(0));
        TwapParams memory p = TwapParams(Mainnet.COW_TWAP, keccak256(abi.encode(sell, buy, part, least, n, t)), input);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok,) = address(ordersMod).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole,
                (Mainnet.COMPOSABLE_COW, 0, abi.encodeCall(IConditional.createWithContext, (p, Mainnet.COW_TIMESTAMP_FACTORY, "", true)), CALL, OPERATOR, true)
            )
        );
        assertEq(ok, expectOk, "the operator's TWAP order");
    }

    function _tail(bytes memory ret) internal pure returns (bytes memory out) {
        out = new bytes(ret.length - 4);
        for (uint256 i = 0; i < out.length; i++) out[i] = ret[i + 4];
    }
}
