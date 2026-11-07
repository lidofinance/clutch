// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @dev CoW Protocol's `GPv2Order.Data`.
struct Order {
    address sellToken;
    address buyToken;
    address receiver;
    uint256 sellAmount;
    uint256 buyAmount;
    uint32 validTo;
    bytes32 appData;
    uint256 feeAmount;
    bytes32 kind;
    bool partiallyFillable;
    bytes32 sellTokenBalance;
    bytes32 buyTokenBalance;
}

/// @dev CoW Protocol's `GPv2Trade.Data` and `GPv2Interaction.Data`.
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

/// @dev ComposableCoW's `ConditionalOrderParams`, and the TWAP handler's `TWAPOrder.Data`.
struct Params {
    address handler;
    bytes32 salt;
    bytes staticInput;
}

struct TwapData {
    address sellToken;
    address buyToken;
    address receiver;
    uint256 partSellAmount;
    uint256 minPartLimit;
    uint256 t0;
    uint256 n;
    uint256 t;
    uint256 span;
    bytes32 appData;
}

interface IOrderSigner {
    function signOrder(Order calldata order, uint32 validDuration, uint256 feeAmountBP) external;
    function unsignOrder(Order calldata order) external;
}

interface ICowSettlement {
    function domainSeparator() external view returns (bytes32);
    function preSignature(bytes calldata orderUid) external view returns (uint256);
    function authenticator() external view returns (address);
    function settle(
        address[] calldata tokens,
        uint256[] calldata clearingPrices,
        Trade[] calldata trades,
        Interaction[][3] calldata interactions
    ) external;
}

interface ISolverAllowList {
    function manager() external view returns (address);
    function addSolver(address solver) external;
}

interface IComposableCoW {
    function create(Params calldata params, bool dispatch) external;
    function createWithContext(Params calldata params, address factory, bytes calldata data, bool dispatch) external;
    function remove(bytes32 singleOrderHash) external;
    function singleOrders(address owner, bytes32 orderHash) external view returns (bool);
    function cabinet(address owner, bytes32 ctx) external view returns (bytes32);
    function hash(Params memory params) external pure returns (bytes32);
    function getTradeableOrderWithSignature(
        address owner,
        Params calldata params,
        bytes calldata offchainInput,
        bytes32[] calldata proof
    ) external view returns (Order memory order, bytes memory signature);
}

/// @title OrdersAccountRehearsal — the orders account's policy (ADR 007) on the enabling vote's vault, with
///        CoW Protocol's deployed contracts on a mainnet fork.
/// @dev The fork tests that ADR 007's confirmation owes: the order signer by delegatecall from a Safe v1.5.0
///      through the orders modifier, with the receiver pinned; TWAP orders through ComposableCoW and CoW's
///      fallback handler; the life limits of decisions 25 and 29; the emergency role's cancels, sweeps and
///      recovery orders, settled with the vote's relayer approvals; and the emergency revoke, after which
///      recovery still works. Each order settles through CoW's settlement contract, with this test as a solver
///      that the allow-list's manager adds, and the settlement paying the buy side from its own balance.
///      Run: RPC=<archive RPC> forge test --match-contract OrdersAccountRehearsal
contract OrdersAccountRehearsal is EnabledVault {
    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;
    uint8 internal constant CALL = 0;
    uint8 internal constant DELEGATECALL = 1;
    bytes32 internal constant KIND_SELL = keccak256("sell");
    bytes32 internal constant BALANCE_ERC20 = keccak256("erc20");
    bytes32 internal constant ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"
    );
    /// @dev `GPv2Signing.PRE_SIGNED`: the value of a pre-signed order in the settlement's `preSignature`.
    uint256 internal constant PRE_SIGNED = uint256(keccak256("GPv2Signing.Scheme.PreSign"));
    /// @dev The signing scheme in a trade's flags, bits 5 and 6.
    uint256 internal constant EIP1271 = 2 << 5;
    uint256 internal constant PRESIGN = 3 << 5;
    uint32 internal constant LIFE = 90 days;
    uint32 internal constant RECOVERY_LIFE = 1 days;

    ICowSettlement internal settlement = ICowSettlement(Mainnet.COW_SETTLEMENT);
    IComposableCoW internal composableCow = IComposableCoW(Mainnet.COMPOSABLE_COW);
    address internal solver = makeAddr("cow-solver");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote runs inside each test, as in the factory's tests.
    modifier enabled() {
        _enable();
        _;
    }

    // ---------------------------------------------------------------------
    // INV-022: market and limit orders through the order signer
    // ---------------------------------------------------------------------

    /// @dev The operator funds the orders account under its orders budget, signs a market order through the
    ///      order signer by delegatecall from the Safe v1.5.0, and the order settles with the vote's relayer
    ///      approval, paying the Asset Safe.
    function test_orders_signer_order_settles_to_the_asset_safe() public enabled {
        _fund(Mainnet.USDC, 5_000e6);
        Order memory o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 5_000e6, 4_990e6, _in(1 hours));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.ORDER_SIGNER, _sign(o, LIFE, 0), DELEGATECALL);
        assertEq(settlement.preSignature(_uid(o)), PRE_SIGNED, "the orders account pre-signed the order");

        uint256 before = IERC20(Mainnet.USDT).balanceOf(address(asset));
        _settle(o, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDT).balanceOf(address(asset)) - before, 4_990e6, "the Asset Safe receives the proceeds");
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(orders)), 0, "the orders account sold what it held");
    }

    /// @dev The operator's signer orders pay only the Asset Safe, trade only listed tokens with ERC-20
    ///      balances and zero app data, live at most 90 days and sign no fee, not even 1 wei. Only the order signer is
    ///      delegatecalled, and only the operator holds the role.
    function test_orders_signer_refusals() public enabled {
        address signer = Mainnet.ORDER_SIGNER;
        uint32 soon = _in(1 hours);
        Order memory o = _order(Mainnet.USDC, Mainnet.USDT, Mainnet.AGENT, 1e6, 1e6, soon);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.USDC, Mainnet.USDT, address(0), 1e6, 1e6, soon);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.DAI, Mainnet.USDT, address(asset), 1e6, 1e6, soon);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.USDC, Mainnet.SUSDS, address(asset), 1e6, 1e6, soon);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, soon);
        o.appData = keccak256("hooks or a partner fee");
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, soon);
        o.sellTokenBalance = keccak256("external");
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, soon);
        o.buyTokenBalance = keccak256("internal");
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);

        // decision 29: at most 90 days; decision 43: no signed fee, not even the 1 wei that the signer allows
        o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, soon);
        _refused(OPERATOR, signer, _sign(o, LIFE + 1, 0), DELEGATECALL);
        _refused(OPERATOR, signer, _sign(o, LIFE, 1), DELEGATECALL);
        o.feeAmount = 1;
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        Order memory longest = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, _in(LIFE - 1));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(longest, LIFE, 0), DELEGATECALL);
        // the signer itself refuses an expiry beyond the duration that the policy pins
        Order memory beyond = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, _in(LIFE));
        (bool ok,) = _orders(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(beyond, LIFE, 0), DELEGATECALL);
        assertFalse(ok, "the signer refuses validTo at or beyond now + validDuration");

        // delegatecall goes only to the signer; a stranger holds no role
        _refused(OPERATOR, Mainnet.COMPOSABLE_COW, abi.encodeCall(IComposableCoW.remove, (bytes32(0))), DELEGATECALL);
        (ok,) = _orders(stranger, OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        assertFalse(ok, "only the committee's Safe holds the operator role");
    }

    // ---------------------------------------------------------------------
    // INV-022 and INV-024: TWAP orders through ComposableCoW
    // ---------------------------------------------------------------------

    /// @dev The operator creates a TWAP order that starts at its creation. ComposableCoW builds its first
    ///      part, and the part settles through the Safe v1.5.0's EIP-1271 check, which CoW's fallback handler
    ///      answers with ComposableCoW as the domain's verifier. The part pays the Asset Safe.
    function test_orders_twap_part_settles_through_the_fallback_handler() public enabled {
        _fund(Mainnet.USDC, 2_000e6);
        Params memory p = _twap(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.COMPOSABLE_COW, _create(p), CALL);
        bytes32 h = composableCow.hash(p);
        assertTrue(composableCow.singleOrders(address(orders), h), "the TWAP order exists");
        assertEq(uint256(composableCow.cabinet(address(orders), h)), block.timestamp, "it starts at its creation");

        (Order memory part, bytes memory signature) =
            composableCow.getTradeableOrderWithSignature(address(orders), p, "", new bytes32[](0));
        assertEq(part.receiver, address(asset), "the part pays the Asset Safe");
        assertEq(part.sellAmount, 1_000e6, "one part");
        uint256 before = IERC20(Mainnet.USDT).balanceOf(address(asset));
        _settle(part, EIP1271, abi.encodePacked(address(orders), signature));
        assertEq(IERC20(Mainnet.USDT).balanceOf(address(asset)) - before, 990e6, "the Asset Safe receives the part's proceeds");
    }

    /// @dev A TWAP order pays only the Asset Safe, uses only CoW's TWAP handler and the current-timestamp
    ///      factory, starts at its creation, carries zero app data, and takes one of decision 29's two shapes:
    ///      at most 90 parts at most a day apart, or at most 12 parts at most 7 days apart.
    function test_orders_twap_refusals() public enabled {
        address cow = Mainnet.COMPOSABLE_COW;
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 90, 1 days)), CALL);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 12, 7 days)), CALL);

        _refused(OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, Mainnet.AGENT, 2, 1 days)), CALL);
        _refused(OPERATOR, cow, _create(_twap(Mainnet.DAI, Mainnet.USDT, address(asset), 2, 1 days)), CALL);
        _refused(OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 91, 1 days)), CALL);
        _refused(OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 90, 1 days + 1)), CALL);
        _refused(OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 13, 7 days)), CALL);
        _refused(OPERATOR, cow, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 12, 7 days + 1)), CALL);

        Params memory p = _twap(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        _refused(OPERATOR, cow, abi.encodeCall(IComposableCoW.create, (p, true)), CALL);
        _refused(
            OPERATOR, cow, abi.encodeCall(IComposableCoW.createWithContext, (p, Mainnet.COW_STOP_LOSS, "", true)), CALL
        );
        Params memory other = _twap(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        other.handler = Mainnet.COW_STOP_LOSS;
        _refused(OPERATOR, cow, _create(other), CALL);
        TwapData memory d = _twapData(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        d.t0 = block.timestamp + 1 days;
        _refused(OPERATOR, cow, _create(Params(Mainnet.COW_TWAP, keccak256("late"), abi.encode(d))), CALL);
        d = _twapData(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        d.appData = keccak256("hooks or a partner fee");
        _refused(OPERATOR, cow, _create(Params(Mainnet.COW_TWAP, keccak256("app"), abi.encode(d))), CALL);
    }

    // ---------------------------------------------------------------------
    // ADR 007, decisions 19, 25, 26 and 30: the emergency role
    // ---------------------------------------------------------------------

    /// @dev The emergency Safe cancels the operator's signer order and TWAP order, sends a token to the Agent,
    ///      zeroes a relayer approval and raises none, and places a recovery order: the Asset Safe's DAI goes to
    ///      the orders account and sells for USDC, which the settlement pays to the Agent. A recovery order
    ///      buys only USDC or USDT, pays only the Agent and lives at most 1 day.
    function test_orders_emergency_cancels_sweeps_and_recovers() public enabled {
        _fund(Mainnet.USDC, 3_000e6);
        Order memory o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1_000e6, 990e6, _in(1 hours));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.ORDER_SIGNER, _sign(o, LIFE, 0), DELEGATECALL);
        Params memory p = _twap(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.COMPOSABLE_COW, _create(p), CALL);

        // cancel both
        _ordersOk(address(emergency), EMERGENCY, Mainnet.ORDER_SIGNER, abi.encodeCall(IOrderSigner.unsignOrder, (o)), DELEGATECALL);
        assertEq(settlement.preSignature(_uid(o)), 0, "the signer order is cancelled");
        _ordersOk(
            address(emergency), EMERGENCY, Mainnet.COMPOSABLE_COW, abi.encodeCall(IComposableCoW.remove, (composableCow.hash(p))), CALL
        );
        assertFalse(composableCow.singleOrders(address(orders), composableCow.hash(p)), "the TWAP order is cancelled");

        // sweep to the Agent; zero a relayer approval, and raise none
        uint256 agentUsdc = IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT);
        _ordersOk(address(emergency), EMERGENCY, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 3_000e6)), CALL);
        assertEq(IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT) - agentUsdc, 3_000e6, "the Agent receives the sweep");
        _ordersOk(address(emergency), EMERGENCY, Mainnet.WSTETH, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 0)), CALL);
        assertEq(IERC20(Mainnet.WSTETH).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), 0, "the approval is zero");
        _refused(EMERGENCY, Mainnet.WSTETH, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 1)), CALL);
        _refused(EMERGENCY, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (stranger, 1)), CALL);

        // a recovery order, settled with the vote's relayer approval
        _recover(Mainnet.DAI, 10_000e18, 9_990e6);

        Order memory r = _order(Mainnet.DAI, Mainnet.USDC, address(asset), 1e18, 1e6, _in(1 hours));
        _refused(EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        r = _order(Mainnet.DAI, Mainnet.USDS, Mainnet.AGENT, 1e18, 1e18, _in(1 hours));
        _refused(EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        r = _order(Mainnet.DAI, Mainnet.USDC, Mainnet.AGENT, 1e18, 1e6, _in(1 hours));
        _refused(EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE + 1, 0), DELEGATECALL);
        r.feeAmount = 1;
        _refused(EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        _refused(EMERGENCY, Mainnet.COMPOSABLE_COW, _create(p), CALL);
    }

    /// @dev Decision 30: the emergency role's revoke stops the operator on the orders account, and recovery
    ///      orders still work.
    function test_orders_emergency_revocation_keeps_recovery() public enabled {
        _ordersOk(
            address(emergency), EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeTarget, (OPERATOR, Mainnet.ORDER_SIGNER)), CALL
        );
        _ordersOk(
            address(emergency), EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeTarget, (OPERATOR, Mainnet.COMPOSABLE_COW)), CALL
        );
        Order memory o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, _in(1 hours));
        _refused(OPERATOR, Mainnet.ORDER_SIGNER, _sign(o, LIFE, 0), DELEGATECALL);
        _refused(OPERATOR, Mainnet.COMPOSABLE_COW, _create(_twap(Mainnet.USDC, Mainnet.USDT, address(asset), 2, 1 days)), CALL);
        // the revoke is pinned to the operator's key
        _refused(EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, Mainnet.ORDER_SIGNER)), CALL);

        _recover(Mainnet.USDS, 5_000e18, 4_990e6);
    }

    // ---------------------------------------------------------------------
    // INV-002: the Asset Safe funds the orders account
    // ---------------------------------------------------------------------

    /// @dev The operator sends an order token to the orders account under its orders budget, and nowhere
    ///      else; the emergency role may send a recovery asset there too.
    function test_orders_funding_from_the_asset_safe() public enabled {
        deal(Mainnet.USDC, address(asset), 20_000e6);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (address(orders), 10_000e6)), true);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(orders)), 10_000e6, "the orders account is funded");
        _operatorRefused(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (address(orders), 1)));
        _operatorRefused(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        _operatorRefused(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 1)));
        deal(Mainnet.DAI, address(asset), 1e18);
        _operatorRefused(Mainnet.DAI, abi.encodeCall(IERC20.transfer, (address(orders), 1e18)));

        _safety(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (address(orders), 1_000e6)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(orders)), 11_000e6, "the emergency role may fund recovery");
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _in(uint256 secondsFromNow) internal view returns (uint32) {
        return uint32(block.timestamp + secondsFromNow);
    }

    function _order(address sell, address buy, address receiver, uint256 sellAmount, uint256 buyAmount, uint32 validTo)
        internal
        pure
        returns (Order memory)
    {
        return Order(sell, buy, receiver, sellAmount, buyAmount, validTo, bytes32(0), 0, KIND_SELL, false, BALANCE_ERC20, BALANCE_ERC20);
    }

    function _sign(Order memory o, uint32 life, uint256 feeBP) internal pure returns (bytes memory) {
        return abi.encodeCall(IOrderSigner.signOrder, (o, life, feeBP));
    }

    /// @dev The order's identifier at the settlement, with the orders account as its owner.
    function _uid(Order memory o) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", settlement.domainSeparator(), keccak256(abi.encode(ORDER_TYPE_HASH, o)))
        );
        return abi.encodePacked(digest, address(orders), o.validTo);
    }

    function _twapData(address sell, address buy, address receiver, uint256 n, uint256 t)
        internal
        pure
        returns (TwapData memory)
    {
        return TwapData(sell, buy, receiver, 1_000e6, 990e6, 0, n, t, 0, bytes32(0));
    }

    function _twap(address sell, address buy, address receiver, uint256 n, uint256 t) internal pure returns (Params memory) {
        return Params(Mainnet.COW_TWAP, keccak256(abi.encode(n, t)), abi.encode(_twapData(sell, buy, receiver, n, t)));
    }

    function _create(Params memory p) internal pure returns (bytes memory) {
        return abi.encodeCall(IComposableCoW.createWithContext, (p, Mainnet.COW_TIMESTAMP_FACTORY, "", true));
    }

    /// @dev A call through the orders modifier.
    function _orders(address member, bytes32 role, address to, bytes memory data, uint8 operation)
        internal
        returns (bool ok, bytes memory ret)
    {
        vm.prank(member);
        (ok, ret) = address(ordersMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, operation, role, true)));
    }

    function _ordersOk(address member, bytes32 role, address to, bytes memory data, uint8 operation) internal {
        (bool ok, bytes memory ret) = _orders(member, role, to, data, operation);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @dev Refused by the orders modifier's policy, not by the call that it would make.
    function _refused(bytes32 role, address to, bytes memory data, uint8 operation) internal {
        address member = role == OPERATOR ? Mainnet.COMMITTEE_SAFE : address(emergency);
        (bool ok, bytes memory ret) = _orders(member, role, to, data, operation);
        assertFalse(ok, "the orders modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    function _operatorRefused(address to, bytes memory data) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok, bytes memory ret) =
            address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, CALL, OPERATOR, true)));
        assertFalse(ok, "the operator modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    function _safety(address to, bytes memory data) internal {
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(to, 0, data, CALL, EMERGENCY, true);
    }

    /// @dev The operator's funding of the orders account, from the Asset Safe.
    function _fund(address token, uint256 amount) internal {
        deal(token, address(asset), amount);
        _operator(token, abi.encodeCall(IERC20.transfer, (address(orders), amount)), true);
    }

    /// @dev A recovery order: the emergency Safe sends the Asset Safe's `token` to the orders account, signs an
    ///      order that sells it for USDC paid to the Agent, and the settlement fills it.
    function _recover(address token, uint256 amount, uint256 usdc) internal {
        deal(token, address(asset), amount);
        _safety(token, abi.encodeCall(IERC20.transfer, (address(orders), amount)));
        Order memory r = _order(token, Mainnet.USDC, Mainnet.AGENT, amount, usdc, _in(1 hours));
        _ordersOk(address(emergency), EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        uint256 before = IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT);
        _settle(r, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT) - before, usdc, "the recovery order pays the Agent");
    }

    /// @dev Settles one order alone at its limit price. This test is the solver, and the settlement pays the
    ///      buy side from its own balance.
    function _settle(Order memory o, uint256 scheme, bytes memory signature) internal {
        ISolverAllowList auth = ISolverAllowList(settlement.authenticator());
        vm.prank(auth.manager());
        auth.addSolver(solver);
        deal(o.buyToken, address(settlement), IERC20(o.buyToken).balanceOf(address(settlement)) + o.buyAmount);
        address[] memory tokens = new address[](2);
        tokens[0] = o.sellToken;
        tokens[1] = o.buyToken;
        uint256[] memory prices = new uint256[](2);
        prices[0] = o.buyAmount;
        prices[1] = o.sellAmount;
        Trade[] memory trades = new Trade[](1);
        trades[0] = Trade(0, 1, o.receiver, o.sellAmount, o.buyAmount, o.validTo, o.appData, o.feeAmount, scheme, 0, signature);
        Interaction[][3] memory none;
        vm.prank(solver);
        settlement.settle(tokens, prices, trades, none);
    }
}
