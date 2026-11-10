// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {console2} from "forge-std/Test.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {OrdersShape} from "../src/factory/OrdersShape.sol";

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

interface IEasyTrackMotions {
    function createMotion(address evmScriptFactory, bytes calldata evmScriptCallData) external returns (uint256);
    function enactMotion(uint256 motionId, bytes calldata evmScriptCallData) external;
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
///      that the allow-list's manager adds, and the settlement paying the buy side from its own balance. The
///      universal factory's governance and approvals roles (decision 41; INV-040) are tested here too, up to a
///      motion's writes that add a token, with its exit on the Asset Safe through the exit-governance role (decision
///      45), run by hand, and then the universal factory's motion that writes them through the live Easy Track.
///      Run: RPC=<archive RPC> forge test --match-contract OrdersAccountRehearsal
contract OrdersAccountRehearsal is EnabledVault {
    /// @dev The artifact's condition trees on the orders modifier that a motion writes again or for a new token.
    struct Trees {
        IRoles.ConditionFlat[] sign; // the operator's signer orders
        IRoles.ConditionFlat[] recovery; // the emergency role's signer orders
        IRoles.ConditionFlat[] twap; // the operator's TWAP orders
        IRoles.ConditionFlat[] transfer; // the operator's transfer of a token, here USDC
        IRoles.ConditionFlat[] sweep; // the emergency role's transfer of a token
        IRoles.ConditionFlat[] zero; // the emergency role's zeroing of a relayer approval
        IRoles.ConditionFlat[] relayer; // the approvals role's relayer approval
        IRoles.ConditionFlat[] assetExit; // the emergency role's transfer from the Asset Safe to the Agent or the orders account
    }

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

    /// @dev The orders modifier's role for relayer approvals (ADR 007, decision 41).
    bytes32 internal constant APPROVALS = bytes32("approvals");
    /// @dev The safety modifier's role that writes the emergency role's exits (ADR 006, decision 13).
    bytes32 internal constant EXIT_GOVERNANCE = bytes32("exit-governance");
    /// @dev A grant's execution options, as the modifier numbers them; `CALL` and `DELEGATECALL` above are a call's
    ///      operation.
    uint8 internal constant OPTION_SEND = 1;
    uint8 internal constant OPTION_DELEGATECALL = 2;
    uint8 internal constant OPTION_BOTH = 3;
    bytes4 internal constant TRANSFER = IERC20.transfer.selector;
    bytes4 internal constant APPROVE = IERC20.approve.selector;
    bytes4 internal constant TRANSFER_FROM = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 internal constant SIGN_ORDER = IOrderSigner.signOrder.selector;
    bytes4 internal constant UNSIGN_ORDER = IOrderSigner.unsignOrder.selector;
    bytes4 internal constant CREATE_WITH_CONTEXT = IComposableCoW.createWithContext.selector;
    bytes4 internal constant REMOVE = IComposableCoW.remove.selector;
    uint8 internal constant T_STATIC = 1;
    uint8 internal constant T_ABI_ENCODED = 6;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO = 16;
    uint8 internal constant OP_LESS_THAN = 18;

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
    // The universal factory's orders token (ADR 007, decisions 41, 44 and 45; ADR 013)
    // ---------------------------------------------------------------------

    /// @dev The factory's shape writes each order tree in the compiler's form: for the launch lists, byte for byte
    ///      the artifact's trees; with a new token, the artifact's trees with one leaf in each list's sorted place.
    ///      The listing's own writes carry exactly these trees, for the right role, target, function and options.
    function test_factory_orders_trees_match_the_compiler() public {
        Trees memory t = _trees();
        OrdersShape shape = uf.ordersShape();
        address[] memory operatorTokens = launchOrderTokens();
        address[] memory recoveryTokens = launchRecoveryTokens();
        address[] memory buy = new address[](2);
        (buy[0], buy[1]) = (Mainnet.USDC, Mainnet.USDT);
        assertEq(abi.encode(shape.signTree(operatorTokens, operatorTokens, address(asset), LIFE)), abi.encode(t.sign), "signer orders");
        assertEq(abi.encode(shape.twapTree(operatorTokens, operatorTokens, address(asset))), abi.encode(t.twap), "TWAP orders");
        assertEq(abi.encode(shape.signTree(recoveryTokens, buy, Mainnet.AGENT, RECOVERY_LIFE)), abi.encode(t.recovery), "recovery orders");

        address token = Mainnet.WBTC;
        address[] memory operatorNext = _listWith(operatorTokens, token);
        address[] memory recoveryNext = _listWith(recoveryTokens, token);
        IRoles.ConditionFlat[] memory sign = _withToken(_withToken(t.sign, _child(t.sign, _child(t.sign, 0, 0), 0), token), 5, token);
        assertEq(abi.encode(shape.signTree(operatorNext, operatorNext, address(asset), LIFE)), abi.encode(sign), "signer orders, new token");
        IRoles.ConditionFlat[] memory twap = t.twap;
        for (uint256 shapeIndex = 0; shapeIndex < 2; shapeIndex++) {
            for (uint256 side = 0; side < 2; side++) {
                twap = _withToken(twap, _child(twap, _nth(twap, T_ABI_ENCODED, OP_MATCHES, shapeIndex), side), token);
            }
        }
        assertEq(abi.encode(shape.twapTree(operatorNext, operatorNext, address(asset))), abi.encode(twap), "TWAP orders, new token");
        IRoles.ConditionFlat[] memory recovery = _withToken(t.recovery, _child(t.recovery, _child(t.recovery, 0, 0), 0), token);
        assertEq(abi.encode(shape.signTree(recoveryNext, buy, Mainnet.AGENT, RECOVERY_LIFE)), abi.encode(recovery), "recovery orders, new token");

        (address[] memory to, bytes[] memory calls) = shape.listWrites(
            OrdersShape.Context(address(asset), Mainnet.AGENT, address(orders), address(ordersMod), address(safetyMod)),
            operatorNext,
            recoveryNext
        );
        assertEq(to.length, 3, "three writes");
        _assertWrite(to[0], calls[0], OPERATOR, Mainnet.ORDER_SIGNER, SIGN_ORDER, OPTION_DELEGATECALL, sign);
        _assertWrite(to[1], calls[1], OPERATOR, Mainnet.COMPOSABLE_COW, CREATE_WITH_CONTEXT, 0, twap);
        _assertWrite(to[2], calls[2], EMERGENCY, Mainnet.ORDER_SIGNER, SIGN_ORDER, OPTION_DELEGATECALL, recovery);

        // the motion's writes: the token's own ten, the operator's funding transfer with its target, then the trees
        (address[] memory motionTo, bytes[] memory motionData) = uf.writesOf(_calldata(_one(_ordersTokenOp(token, 10e8, 0))));
        assertEq(motionTo.length, 15, "fifteen writes");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(motionTo[12 + i], to[i], "the listing's writes come last");
            assertEq(motionData[12 + i], calls[i], "the listing's writes come last");
        }
    }

    /// @dev Decisions 41, 44 and 45 by one motion, through the live Easy Track: the token's relayer approval, its
    ///      exits, its funding budget and its place in the lists. The enactment fits one transaction under
    ///      EIP-7825's cap, with cold accounts. After it, the operator funds the orders account within the token's
    ///      budget and no further, an operator order in the token settles and pays the Asset Safe, a TWAP order in
    ///      it is created, and a recovery order sells it and pays the Agent.
    function test_factory_orders_token_motion() public enabled {
        address token = Mainnet.WBTC;
        UniversalFactory.Op[] memory ops = new UniversalFactory.Op[](2);
        ops[0] = _ordersTokenOp(token, 10e8, 0);
        ops[1] = _budgetOp(token, address(orders), 1e8, bytes32(0));
        console2.log("FACTORY orders token: enactMotion gas under the cap", _motionUnderCap(ops));
        assertEq(IERC20(token).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), type(uint256).max, "the relayer approval");
        assertEq(
            uf.versions(uf.ORDERS_SCOPE()),
            uf.ordersVersion(_listWith(launchOrderTokens(), token), _listWith(launchRecoveryTokens(), token)),
            "the lists' version"
        );

        // the operator funds the orders account within the token's budget, and no further
        deal(token, address(asset), 2e8);
        _operator(token, abi.encodeCall(IERC20.transfer, (address(orders), 6e7)), true);
        _operatorRefused(token, abi.encodeCall(IERC20.transfer, (address(orders), 5e7)));
        _operatorRefused(token, abi.encodeCall(IERC20.transfer, (stranger, 1)));

        // an operator order sells it and pays the Asset Safe; a TWAP order in it is created
        Order memory o = _order(token, Mainnet.USDC, address(asset), 6e7, 36_000e6, _in(1 hours));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.ORDER_SIGNER, _sign(o, LIFE, 0), DELEGATECALL);
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(asset));
        _settle(o, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - before, 36_000e6, "the Asset Safe receives the proceeds");
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.COMPOSABLE_COW, _create(_twap(token, Mainnet.USDC, address(asset), 12, 7 days)), CALL);
        _refused(OPERATOR, Mainnet.ORDER_SIGNER, _sign(_order(token, Mainnet.USDC, Mainnet.AGENT, 1, 1, _in(1 hours)), LIFE, 0), DELEGATECALL);
        _refused(OPERATOR, Mainnet.ORDER_SIGNER, _sign(_order(token, Mainnet.USDC, address(asset), 1, 1, _in(1 hours)), LIFE + 1, 0), DELEGATECALL);

        // the emergency role moves the rest from the Asset Safe to the orders account, and a recovery order sells it
        _safety(token, abi.encodeCall(IERC20.transfer, (address(orders), 1e8)));
        _safetyRefused(token, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        Order memory r = _order(token, Mainnet.USDC, Mainnet.AGENT, 1e8, 59_000e6, _in(1 hours));
        _ordersOk(address(emergency), EMERGENCY, Mainnet.ORDER_SIGNER, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        uint256 agentBefore = IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT);
        _settle(r, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT) - agentBefore, 59_000e6, "the recovery order pays the Agent");
    }

    /// @dev The operation's checks, each refused when the motion is created: a token that either list holds, such
    ///      as a launch token; a vault account; two tokens in one motion; ceilings for a token that is already
    ///      introduced; and lists that are not the current ones. A token that a motion introduced earlier is added
    ///      with no ceilings, and keeps them.
    function test_factory_orders_token_refusals() public enabled {
        _refusedAtCreation(_one(_ordersTokenOp(Mainnet.USDC, 0, 0)), abi.encodeWithSelector(UniversalFactory.AlreadyListed.selector, Mainnet.USDC));
        _refusedAtCreation(_one(_ordersTokenOp(Mainnet.DAI, 0, 0)), abi.encodeWithSelector(UniversalFactory.AlreadyListed.selector, Mainnet.DAI));
        address[3] memory vault = [address(orders), address(asset), Mainnet.AGENT];
        for (uint256 i = 0; i < vault.length; i++) {
            _refusedAtCreation(_one(_ordersTokenOp(vault[i], 1, 0)), abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, vault[i]));
        }
        address token = Mainnet.WBTC;
        UniversalFactory.Op[] memory two = new UniversalFactory.Op[](2);
        two[0] = _ordersTokenOp(token, 10e8, 0);
        two[1] = _ordersTokenOp(Mainnet.LINK, 1e24, 0);
        _refusedAtCreation(two, abi.encodeWithSelector(UniversalFactory.DuplicateScope.selector, uf.ORDERS_SCOPE()));
        address[] memory shortList = new address[](5);
        for (uint256 i = 0; i < 5; i++) shortList[i] = launchOrderTokens()[i];
        _refusedAtCreation(
            _one(_ordersTokenOp(token, 10e8, 0, shortList, launchRecoveryTokens())),
            abi.encodeWithSelector(UniversalFactory.StaleVersion.selector, uf.ORDERS_SCOPE())
        );

        // a token that an earlier motion introduced, with an approval list, is added without ceilings
        UniversalFactory.Entry[] memory list = new UniversalFactory.Entry[](1);
        list[0] = UniversalFactory.Entry(makeAddr("a-spender"), bytes32(0), 1e8);
        _motion(_one(_introduceOp(token, list, 5e8, 1e8)));
        _refusedAtCreation(
            _one(_ordersTokenOp(token, 1, 0)), abi.encodeWithSelector(UniversalFactory.CeilingsForIntroducedToken.selector, token)
        );
        UniversalFactory.Op[] memory ops = new UniversalFactory.Op[](2);
        ops[0] = _ordersTokenOp(token, 0, 0);
        ops[1] = _budgetOp(token, address(orders), 1e8, bytes32(0));
        _motion(ops);
        (uint256 budgetCeiling,,) = uf.ceilings(uf.ceilingKey(uf.BUDGET_CEILING(), token));
        assertEq(budgetCeiling, 5e8, "the introduction's budget ceiling stays");
        deal(token, address(asset), 1e8);
        _operator(token, abi.encodeCall(IERC20.transfer, (address(orders), 1e8)), true);

        // the launch lists are no longer the current ones
        _refusedAtCreation(
            _one(_ordersTokenOp(Mainnet.LINK, 1e24, 0)), abi.encodeWithSelector(UniversalFactory.StaleVersion.selector, uf.ORDERS_SCOPE())
        );
    }

    /// @dev Versions keep two token motions apart: two motions created against the same lists both pass at
    ///      creation, and the second fails at enactment once the first changed the lists. A motion against the
    ///      new lists then adds the second token.
    function test_factory_orders_tokens_one_after_another() public enabled {
        address first = Mainnet.WBTC;
        address second = Mainnet.LINK;
        bytes memory cd1 = _calldata(_one(_ordersTokenOp(first, 10e8, 0)));
        bytes memory cd2 = _calldata(_one(_ordersTokenOp(second, 1e24, 0)));
        uint256 id1 = _create(cd1);
        uint256 id2 = _create(cd2);
        _afterWindow();
        _enact(id1, cd1);
        vm.prank(anyone);
        (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrackMotions.enactMotion, (id2, cd2)));
        assertFalse(ok, "a motion against the old lists fails at enactment");

        address[] memory operatorNext = _listWith(launchOrderTokens(), first);
        address[] memory recoveryNext = _listWith(launchRecoveryTokens(), first);
        _motion(_one(_ordersTokenOp(second, 1e24, 0, operatorNext, recoveryNext)));
        assertEq(
            uf.versions(uf.ORDERS_SCOPE()),
            uf.ordersVersion(_listWith(operatorNext, second), _listWith(recoveryNext, second)),
            "both tokens are listed"
        );
        _ordersOk(
            Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.ORDER_SIGNER, _sign(_order(first, second, address(asset), 1, 1, _in(1 hours)), LIFE, 0), DELEGATECALL
        );
    }

    /// @dev A budget motion for a launch order token now sets the token's launch orders budget, which the
    ///      operator's funding transfer spends; before, the factory derived a key that no permission spends.
    function test_factory_budget_motion_sets_a_launch_orders_budget() public enabled {
        assertEq(uf.keyFor(Mainnet.USDC, address(orders)), bytes32("orders_usdc"), "the launch key");
        _motion(_one(_budgetOp(Mainnet.USDC, address(orders), 20_000e6, uf.budgetVersion(ORDERS_USD6, ORDERS_USD6, ORDERS_USD6, MONTH))));
        deal(Mainnet.USDC, address(asset), 20_000e6);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.transfer, (address(orders), 15_000e6)), true);
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
    // INV-040: the universal factory's governance and approvals roles (ADR 007, decision 41)
    // ---------------------------------------------------------------------

    /// @dev The governance role writes under the operator, emergency and approvals keys, never under its own or
    ///      another, and refuses the vault's accounts as the administered target. It holds no membership setter, no
    ///      `allowTarget`, no revoke and no `setAllowance`, and only the universal factory holds it.
    function test_orders_governance_writes_only_its_keys_and_targets() public enabled {
        Trees memory t = _trees();
        address token = Mainnet.WBTC;
        _governOk(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, token)));
        _governOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)));
        _governOk(abi.encodeCall(IRoles.scopeTarget, (APPROVALS, token)));
        _governRefused(abi.encodeCall(IRoles.scopeTarget, (GOVERNANCE, token)));
        _governRefused(abi.encodeCall(IRoles.scopeTarget, (FIRST_LOSS, token)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (GOVERNANCE, token, TRANSFER, t.transfer, 0)));

        address[5] memory vault = [address(orders), address(ordersMod), address(asset), address(opMod), address(safetyMod)];
        for (uint256 i = 0; i < vault.length; i++) {
            _governRefused(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, vault[i])));
            _governRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, vault[i], TRANSFER, t.sweep, 0)));
            _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, vault[i], APPROVE, t.relayer, 0)));
        }

        bytes32[] memory keys = new bytes32[](1);
        keys[0] = OPERATOR;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _governRefused(abi.encodeCall(IRoles.assignRoles, (stranger, keys, yes)));
        _governRefused(abi.encodeCall(IRoles.setDefaultRole, (stranger, OPERATOR)));
        _governRefused(abi.encodeCall(IRoles.allowTarget, (OPERATOR, token, 0)));
        _governRefused(abi.encodeCall(IRoles.revokeTarget, (OPERATOR, Mainnet.ORDER_SIGNER)));
        _governRefused(abi.encodeCall(IRoles.revokeFunction, (OPERATOR, Mainnet.ORDER_SIGNER, SIGN_ORDER)));
        _governRefused(abi.encodeCall(IRoles.setAllowance, (bytes32("k:any"), 1, 1, 1, 30 days, 0)));

        bytes memory write = abi.encodeCall(IRoles.scopeTarget, (OPERATOR, token));
        (bool ok,) = _orders(stranger, GOVERNANCE, address(ordersMod), write, CALL);
        assertFalse(ok, "only the universal factory holds the governance role");
        (ok,) = _orders(Mainnet.COMMITTEE_SAFE, GOVERNANCE, address(ordersMod), write, CALL);
        assertFalse(ok, "the committee's Safe does not hold it");
        (ok,) = _orders(Mainnet.ET_EXECUTOR, GOVERNANCE, address(ordersMod), write, CALL);
        assertFalse(ok, "Easy Track's executor does not hold it");
    }

    /// @dev The one delegatecall that a motion may grant is the order signer's: `signOrder` with a condition, for the
    ///      operator or the emergency role, and the operator's `unsignOrder` without one. Every other grant is a plain
    ///      call, and `allowFunction` restores only the operator's two functions without conditions.
    function test_orders_governance_grants_delegatecall_only_for_the_signer() public enabled {
        Trees memory t = _trees();
        address signer = Mainnet.ORDER_SIGNER;
        address cow = Mainnet.COMPOSABLE_COW;
        IRoles.ConditionFlat[] memory sign = t.sign;
        IRoles.ConditionFlat[] memory twap = t.twap;
        IRoles.ConditionFlat[] memory transfer = t.sweep;
        // the policy's own trees, written again
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, signer, SIGN_ORDER, sign, OPTION_DELEGATECALL)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, signer, SIGN_ORDER, t.recovery, OPTION_DELEGATECALL)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, cow, CREATE_WITH_CONTEXT, twap, 0)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.USDC, TRANSFER, transfer, 0)));
        _governOk(abi.encodeCall(IRoles.allowFunction, (OPERATOR, signer, UNSIGN_ORDER, OPTION_DELEGATECALL)));
        _governOk(abi.encodeCall(IRoles.allowFunction, (OPERATOR, cow, REMOVE, 0)));

        // delegatecall elsewhere, for another function or key, or with Send; Send for a plain call
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, signer, SIGN_ORDER, sign, OPTION_BOTH)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, cow, CREATE_WITH_CONTEXT, twap, OPTION_DELEGATECALL)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, signer, UNSIGN_ORDER, sign, OPTION_DELEGATECALL)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, signer, SIGN_ORDER, sign, OPTION_DELEGATECALL)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.USDC, TRANSFER, transfer, OPTION_SEND)));
        // no signOrder without a condition, no restore for the emergency role, nothing else without conditions
        _governRefused(abi.encodeCall(IRoles.allowFunction, (OPERATOR, signer, SIGN_ORDER, OPTION_DELEGATECALL)));
        _governRefused(abi.encodeCall(IRoles.allowFunction, (OPERATOR, signer, UNSIGN_ORDER, OPTION_BOTH)));
        _governRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, signer, UNSIGN_ORDER, OPTION_DELEGATECALL)));
        _governRefused(abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.USDC, TRANSFER, 0)));
        _governRefused(abi.encodeCall(IRoles.allowFunction, (OPERATOR, cow, CREATE_WITH_CONTEXT, 0)));
    }

    /// @dev Beyond signer and TWAP orders, governance writes only trees pinned whole: the return of a token to the
    ///      Asset Safe or the Agent, for the operator and the emergency role; the emergency role's zeroing of the
    ///      relayer's approval; and the approvals role's relayer approval. So a motion gives no role another receiver
    ///      or spender, only the approvals role raises an approval (INV-008), and TWAP orders stay the operator's.
    function test_orders_governance_pins_transfers_and_approvals() public enabled {
        Trees memory t = _trees();
        address token = Mainnet.WBTC;
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, TRANSFER, t.transfer, 0)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, t.sweep, 0)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, t.zero, 0)));

        // another receiver, or a function outside the shapes
        IRoles.ConditionFlat[] memory anyone = new IRoles.ConditionFlat[](2);
        anyone[0] = t.relayer[0];
        anyone[1] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(stranger));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, TRANSFER, anyone, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, anyone, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, TRANSFER_FROM, t.transfer, 0)));
        // only the approvals role raises an approval; the emergency role only zeroes one; the operator has none
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, APPROVE, t.relayer, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, APPROVE, t.zero, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, t.relayer, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, t.zero, 0)));
        // TWAP orders: the operator's, on ComposableCoW only
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.COMPOSABLE_COW, CREATE_WITH_CONTEXT, t.twap, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, CREATE_WITH_CONTEXT, t.twap, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.COMPOSABLE_COW, REMOVE, t.twap, 0)));
    }

    /// @dev A motion restores what the emergency role revoked from the operator, with no DAO vote: a revoked target
    ///      comes back with its functions by `scopeTarget`, a revoked function without conditions by
    ///      `allowFunction`, and a revoked signer order by writing its tree again.
    function test_orders_governance_restores_what_the_emergency_role_revoked() public enabled {
        Trees memory t = _trees();
        address signer = Mainnet.ORDER_SIGNER;
        Order memory o = _order(Mainnet.USDC, Mainnet.USDT, address(asset), 1e6, 1e6, _in(1 hours));
        _ordersOk(address(emergency), EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeTarget, (OPERATOR, signer)), CALL);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        _governOk(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, signer)));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);

        _ordersOk(address(emergency), EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeFunction, (OPERATOR, signer, UNSIGN_ORDER)), CALL);
        _refused(OPERATOR, signer, abi.encodeCall(IOrderSigner.unsignOrder, (o)), DELEGATECALL);
        _governOk(abi.encodeCall(IRoles.allowFunction, (OPERATOR, signer, UNSIGN_ORDER, OPTION_DELEGATECALL)));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, abi.encodeCall(IOrderSigner.unsignOrder, (o)), DELEGATECALL);
        assertEq(settlement.preSignature(_uid(o)), 0, "the operator cancels its order again");

        _ordersOk(address(emergency), EMERGENCY, address(ordersMod), abi.encodeCall(IRoles.revokeFunction, (OPERATOR, signer, SIGN_ORDER)), CALL);
        _refused(OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, signer, SIGN_ORDER, t.sign, OPTION_DELEGATECALL)));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
    }

    /// @dev The approvals role approves only CoW's vault relayer: it raises an approval that the emergency role set
    ///      to zero, and nothing else. Under its key, governance writes only the same relayer approval for a new
    ///      token, the tree pinned whole: another spender, an extra condition, Send or another function is refused.
    function test_orders_approvals_role_approves_only_the_relayer() public enabled {
        Trees memory t = _trees();
        _ordersOk(address(emergency), EMERGENCY, Mainnet.USDT, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 0)), CALL);
        assertEq(IERC20(Mainnet.USDT).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), 0, "the emergency role zeroed it");
        _approvalsOk(Mainnet.USDT, type(uint256).max);
        assertEq(IERC20(Mainnet.USDT).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), type(uint256).max, "a motion raised it");
        _refused(APPROVALS, Mainnet.USDC, abi.encodeCall(IERC20.approve, (stranger, 1)), CALL);
        _refused(APPROVALS, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 1)), CALL);
        _refused(APPROVALS, Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 1)), DELEGATECALL);
        (bool ok,) = _orders(
            Mainnet.COMMITTEE_SAFE, APPROVALS, Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 1)), CALL
        );
        assertFalse(ok, "only the universal factory holds the approvals role");

        address token = Mainnet.WBTC;
        _refused(APPROVALS, token, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 1)), CALL);
        IRoles.ConditionFlat[] memory relayer = t.relayer;
        IRoles.ConditionFlat[] memory other = new IRoles.ConditionFlat[](2);
        other[0] = relayer[0];
        other[1] = IRoles.ConditionFlat(relayer[1].parent, relayer[1].paramType, relayer[1].operator_, abi.encode(stranger));
        IRoles.ConditionFlat[] memory longer = new IRoles.ConditionFlat[](3);
        longer[0] = relayer[0];
        longer[1] = relayer[1];
        longer[2] = IRoles.ConditionFlat(0, T_STATIC, OP_LESS_THAN, abi.encode(uint256(2)));
        _governOk(abi.encodeCall(IRoles.scopeTarget, (APPROVALS, token)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, other, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, longer, 0)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, relayer, OPTION_SEND)));
        _governRefused(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, TRANSFER, relayer, 0)));
        _governRefused(abi.encodeCall(IRoles.allowFunction, (APPROVALS, token, APPROVE, 0)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, relayer, 0)));
        _approvalsOk(token, type(uint256).max);
        assertEq(IERC20(token).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), type(uint256).max, "the new token's approval");
        _refused(APPROVALS, token, abi.encodeCall(IERC20.approve, (stranger, 1)), CALL);
    }

    /// @dev Decisions 41 and 45 end to end, with the motion's writes run by hand: a token joins the operator's lists
    ///      on the sell side and the buy side, for signer and TWAP orders, and the recovery orders' sell side, with
    ///      its relayer approval, the emergency role's zeroing and transfer, the operator's transfer back, and its
    ///      exit on the Asset Safe. Each write passes the governance role or the exit-governance role. An operator
    ///      order in the token settles; the emergency role then moves the token from the Asset Safe to the orders
    ///      account, and a recovery order sells it. Each list still refuses what it refused.
    function test_orders_motion_adds_a_token() public enabled {
        address token = Mainnet.WBTC;
        address signer = Mainnet.ORDER_SIGNER;
        _refused(OPERATOR, signer, _sign(_order(token, Mainnet.USDC, address(asset), 1e8, 1e6, _in(1 hours)), LIFE, 0), DELEGATECALL);
        _refused(EMERGENCY, signer, _sign(_order(token, Mainnet.USDC, Mainnet.AGENT, 1e8, 1e6, _in(1 hours)), RECOVERY_LIFE, 0), DELEGATECALL);
        // an operator order's proceeds in the token would arrive in the Asset Safe; the emergency role cannot move them yet
        deal(token, address(asset), 1e8);
        _safetyRefused(token, abi.encodeCall(IERC20.transfer, (address(orders), 1e8)));

        _addToken(_trees(), token);

        // the operator sells the token, and may buy it, by signer order and by TWAP order
        deal(token, address(orders), 1e8);
        Order memory o = _order(token, Mainnet.USDC, address(asset), 1e8, 60_000e6, _in(1 hours));
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(o, LIFE, 0), DELEGATECALL);
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(asset));
        _settle(o, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - before, 60_000e6, "the Asset Safe receives the proceeds");
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, signer, _sign(_order(Mainnet.USDC, token, address(asset), 1e6, 1, _in(1 hours)), LIFE, 0), DELEGATECALL);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.COMPOSABLE_COW, _create(_twap(token, Mainnet.USDC, address(asset), 90, 1 days)), CALL);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, Mainnet.COMPOSABLE_COW, _create(_twap(Mainnet.USDT, token, address(asset), 12, 7 days)), CALL);
        _refused(OPERATOR, signer, _sign(_order(token, Mainnet.USDC, Mainnet.AGENT, 1, 1, _in(1 hours)), LIFE, 0), DELEGATECALL);
        _refused(OPERATOR, signer, _sign(_order(token, Mainnet.DAI, address(asset), 1, 1, _in(1 hours)), LIFE, 0), DELEGATECALL);

        // the emergency role moves the token from the Asset Safe to the orders account, through the motion's exit,
        // and a recovery order sells it for USDC and pays the Agent; it still buys nothing else
        _safety(token, abi.encodeCall(IERC20.transfer, (address(orders), 1e8)));
        _safetyRefused(token, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        Order memory r = _order(token, Mainnet.USDC, Mainnet.AGENT, 1e8, 59_000e6, _in(1 hours));
        _ordersOk(address(emergency), EMERGENCY, signer, _sign(r, RECOVERY_LIFE, 0), DELEGATECALL);
        uint256 agentBefore = IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT);
        _settle(r, PRESIGN, abi.encodePacked(address(orders)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(Mainnet.AGENT) - agentBefore, 59_000e6, "the recovery order pays the Agent");
        _refused(EMERGENCY, signer, _sign(_order(Mainnet.USDC, token, Mainnet.AGENT, 1, 1, _in(1 hours)), RECOVERY_LIFE, 0), DELEGATECALL);

        // the emergency role zeroes its approval and sweeps it; a motion raises the approval again
        _ordersOk(address(emergency), EMERGENCY, token, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 0)), CALL);
        _refused(EMERGENCY, token, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, 1)), CALL);
        deal(token, address(orders), 5);
        _ordersOk(address(emergency), EMERGENCY, token, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 5)), CALL);
        _approvalsOk(token, type(uint256).max);

        // the operator sends the token back to the Asset Safe, and nowhere else
        deal(token, address(orders), 7);
        _ordersOk(Mainnet.COMMITTEE_SAFE, OPERATOR, token, abi.encodeCall(IERC20.transfer, (address(asset), 7)), CALL);
        _refused(OPERATOR, token, abi.encodeCall(IERC20.transfer, (stranger, 1)), CALL);
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
        address member = role == OPERATOR ? Mainnet.COMMITTEE_SAFE : role == EMERGENCY ? address(emergency) : address(uf);
        (bool ok, bytes memory ret) = _orders(member, role, to, data, operation);
        assertFalse(ok, "the orders modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    /// @dev A write of the governance role on the orders modifier, as the universal factory makes it.
    function _governOk(bytes memory write) internal {
        _ordersOk(address(uf), GOVERNANCE, address(ordersMod), write, CALL);
    }

    function _governRefused(bytes memory write) internal {
        _refused(GOVERNANCE, address(ordersMod), write, CALL);
    }

    /// @dev The universal factory's orders operation against the launch lists.
    function _ordersTokenOp(address token, uint256 budgetCeiling, uint256 approvalCeiling)
        internal
        view
        returns (UniversalFactory.Op memory)
    {
        return _ordersTokenOp(token, budgetCeiling, approvalCeiling, launchOrderTokens(), launchRecoveryTokens());
    }

    /// @dev The universal factory's orders operation against the lists that the motion states.
    function _ordersTokenOp(
        address token,
        uint256 budgetCeiling,
        uint256 approvalCeiling,
        address[] memory operatorTokens,
        address[] memory recoveryTokens
    ) internal view returns (UniversalFactory.Op memory) {
        return _op(uf.ORDERS_TOKEN(), abi.encode(token, budgetCeiling, approvalCeiling, operatorTokens, recoveryTokens));
    }

    /// @dev A motion that the factory refuses at creation, with `reason`.
    function _refusedAtCreation(UniversalFactory.Op[] memory ops, bytes memory reason) internal {
        bytes memory cd = _calldata(ops);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(reason);
        IEasyTrackMotions(Mainnet.EASY_TRACK).createMotion(address(uf), cd);
    }

    /// @dev Creates a motion, waits out its objection window and enacts it in one transaction under EIP-7825's cap,
    ///      with the accounts that it touches cold, as a fresh transaction finds them. Returns the gas, intrinsic
    ///      gas included.
    function _motionUnderCap(UniversalFactory.Op[] memory ops) internal returns (uint256 used) {
        bytes memory cd = _calldata(ops);
        uint256 id = _create(cd);
        _afterWindow();
        bytes memory txData = abi.encodeCall(IEasyTrackMotions.enactMotion, (id, cd));
        (uint256 std, uint256 floor) = VoteBuilder.intrinsicGas(txData);
        uint256 intrinsic = std > floor ? std : floor;
        address[] memory touched = new address[](8);
        (touched[0], touched[1], touched[2], touched[3]) = (Mainnet.EASY_TRACK, address(uf), address(uf.ordersShape()), Mainnet.ET_EXECUTOR);
        (touched[4], touched[5], touched[6], touched[7]) = (address(opMod), address(safetyMod), address(ordersMod), address(orders));
        _cold(touched);
        vm.prank(anyone);
        uint256 g = gasleft();
        (bool ok,) = Mainnet.EASY_TRACK.call{gas: TX_GAS_CAP - intrinsic}(txData);
        used = g - gasleft() + std;
        assertTrue(ok, "the motion must enact in one transaction under EIP-7825's cap");
    }

    /// @dev A write of the orders modifier's governance role: the call, the role, the target, the function, the
    ///      execution options and the whole tree.
    function _assertWrite(
        address to,
        bytes memory call,
        bytes32 role,
        address target,
        bytes4 selector,
        uint8 options,
        IRoles.ConditionFlat[] memory tree
    ) internal view {
        assertEq(to, address(ordersMod), "a call of the orders modifier");
        assertEq(bytes4(call), IRoles.execTransactionWithRole.selector, "through a role");
        (address modifier_, uint256 value, bytes memory write, uint8 operation, bytes32 viaRole, bool shouldRevert) =
            abi.decode(_params(call), (address, uint256, bytes, uint8, bytes32, bool));
        assertEq(modifier_, address(ordersMod), "on the modifier itself");
        assertTrue(value == 0 && operation == CALL && shouldRevert, "a plain call that reverts on failure");
        assertEq(viaRole, GOVERNANCE, "as the governance role");
        assertEq(bytes4(write), IRoles.scopeFunction.selector, "a scopeFunction");
        (bytes32 k, address t, bytes4 s, IRoles.ConditionFlat[] memory c, uint8 o) =
            abi.decode(_params(write), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
        assertEq(k, role, "the role key");
        assertEq(t, target, "the target");
        assertEq(s, selector, "the function");
        assertEq(o, options, "the execution options");
        assertEq(abi.encode(c), abi.encode(tree), "the tree");
    }

    /// @dev A sorted token list with `token` in its place.
    function _listWith(address[] memory tokens, address token) internal pure returns (address[] memory next) {
        next = new address[](tokens.length + 1);
        uint256 j;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (j == i && token < tokens[i]) next[j++] = token;
            next[j++] = tokens[i];
        }
        if (j == tokens.length) next[j] = token;
    }

    /// @dev The approvals role's approval of CoW's vault relayer, as the universal factory makes it.
    function _approvalsOk(address token, uint256 amount) internal {
        _ordersOk(address(uf), APPROVALS, token, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, amount)), CALL);
    }

    /// @dev The writes of a motion that adds `token` (decision 41), each through the governance role, then the
    ///      approvals role's approval. Each list gains the token where the SDK sorts it, so every tree stays in the
    ///      compiler's form; the compiler's tests check that rule against the SDK.
    function _addToken(Trees memory t, address token) internal {
        address signer = Mainnet.ORDER_SIGNER;
        address cow = Mainnet.COMPOSABLE_COW;
        // the operator's lists: the sell side and the buy side of signer orders and of both TWAP shapes
        IRoles.ConditionFlat[] memory sign = t.sign;
        sign = _withToken(sign, _child(sign, _child(sign, 0, 0), 0), token);
        sign = _withToken(sign, _child(sign, _child(sign, 0, 0), 1), token);
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, signer, SIGN_ORDER, sign, OPTION_DELEGATECALL)));
        IRoles.ConditionFlat[] memory twap = t.twap;
        for (uint256 shape = 0; shape < 2; shape++) {
            for (uint256 side = 0; side < 2; side++) {
                twap = _withToken(twap, _child(twap, _nth(twap, T_ABI_ENCODED, OP_MATCHES, shape), side), token);
            }
        }
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, cow, CREATE_WITH_CONTEXT, twap, 0)));
        _governOk(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, token)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, TRANSFER, t.transfer, 0)));
        // the recovery orders' sell side
        IRoles.ConditionFlat[] memory recovery = t.recovery;
        recovery = _withToken(recovery, _child(recovery, _child(recovery, 0, 0), 0), token);
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, signer, SIGN_ORDER, recovery, OPTION_DELEGATECALL)));
        // the emergency role's zeroing and transfer
        _governOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, t.zero, 0)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, t.sweep, 0)));
        // the relayer approval
        _governOk(abi.encodeCall(IRoles.scopeTarget, (APPROVALS, token)));
        _governOk(abi.encodeCall(IRoles.scopeFunction, (APPROVALS, token, APPROVE, t.relayer, 0)));
        _approvalsOk(token, type(uint256).max);
        // the token's exit on the Asset Safe, through the exit-governance role on the safety modifier (decision 45)
        _exitOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, t.assetExit, 0)));
    }

    /// @dev A write of the exit-governance role on the safety modifier, as the universal factory makes it.
    function _exitOk(bytes memory write) internal {
        vm.prank(address(uf));
        (bool ok, bytes memory ret) = address(safetyMod).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (address(safetyMod), 0, write, CALL, EXIT_GOVERNANCE, true))
        );
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @dev The artifact's trees that the tests write, read in one pass: the artifact is large, and memory is not
    ///      freed within a test. Reading it is not metered, as in the enabling vote's helpers.
    function _trees() internal returns (Trees memory t) {
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory calls = _policyCalls(address(ordersMod), address(0));
        for (uint256 i = 0; i < calls.length; i++) {
            if (bytes4(calls[i].data) != IRoles.scopeFunction.selector) continue;
            (bytes32 k, address target, bytes4 s, IRoles.ConditionFlat[] memory c,) =
                abi.decode(_params(calls[i].data), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (target == Mainnet.ORDER_SIGNER && s == SIGN_ORDER && k == OPERATOR) t.sign = c;
            else if (target == Mainnet.ORDER_SIGNER && s == SIGN_ORDER && k == EMERGENCY) t.recovery = c;
            else if (target == Mainnet.COMPOSABLE_COW && s == CREATE_WITH_CONTEXT && k == OPERATOR) t.twap = c;
            else if (target == Mainnet.USDC && s == TRANSFER && k == OPERATOR) t.transfer = c;
            else if (target == Mainnet.USDC && s == TRANSFER && k == EMERGENCY) t.sweep = c;
            else if (target == Mainnet.USDC && s == APPROVE && k == EMERGENCY) t.zero = c;
            else if (target == Mainnet.USDC && s == APPROVE && k == APPROVALS) t.relayer = c;
        }
        calls = _policyCalls(address(safetyMod), address(0));
        for (uint256 i = 0; i < calls.length; i++) {
            if (bytes4(calls[i].data) != IRoles.scopeFunction.selector) continue;
            (bytes32 k, address target, bytes4 s, IRoles.ConditionFlat[] memory c,) =
                abi.decode(_params(calls[i].data), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (target == Mainnet.USDC && s == TRANSFER && k == EMERGENCY) t.assetExit = c;
        }
        vm.resumeGasMetering();
        require(
            t.sign.length != 0 && t.recovery.length != 0 && t.twap.length != 0 && t.transfer.length != 0
                && t.sweep.length != 0 && t.zero.length != 0 && t.relayer.length != 0 && t.assetExit.length != 0,
            "the artifact lacks a tree"
        );
    }

    /// @dev Calldata without its selector.
    function _params(bytes memory data) internal pure returns (bytes memory p) {
        p = new bytes(data.length - 4);
        for (uint256 i = 0; i < p.length; i++) p[i] = data[i + 4];
    }

    /// @dev The index of the `k`-th child of `node` in a flat tree.
    function _child(IRoles.ConditionFlat[] memory c, uint256 node, uint256 k) internal pure returns (uint256) {
        for (uint256 i = 1; i < c.length; i++) {
            if (c[i].parent != node) continue;
            if (k == 0) return i;
            k--;
        }
        revert("no such child");
    }

    /// @dev The index of the `n`-th node with a parameter type and an operator, in flat order.
    function _nth(IRoles.ConditionFlat[] memory c, uint8 paramType, uint8 op, uint256 n) internal pure returns (uint256) {
        for (uint256 i = 0; i < c.length; i++) {
            if (c[i].paramType != paramType || c[i].operator_ != op) continue;
            if (n == 0) return i;
            n--;
        }
        revert("no such node");
    }

    /// @dev `c` with `token` added to the token list `list`, an Or of EqualTo: one more leaf, placed before the
    ///      first leaf of a greater value, as the SDK sorts them. The tree stays in breadth-first order: each later
    ///      node moves one place, and so does each parent index from the new leaf on.
    function _withToken(IRoles.ConditionFlat[] memory c, uint256 list, address token)
        internal
        pure
        returns (IRoles.ConditionFlat[] memory r)
    {
        bytes memory value = abi.encode(token);
        uint256 at;
        uint256 last;
        for (uint256 i = 1; i < c.length; i++) {
            if (c[i].parent != list) continue;
            require(keccak256(c[i].compValue) != keccak256(value), "the token is on the list already");
            if (at == 0 && uint256(bytes32(c[i].compValue)) > uint256(uint160(token))) at = i;
            last = i;
        }
        require(last != 0, "not a list");
        if (at == 0) at = last + 1;
        r = new IRoles.ConditionFlat[](c.length + 1);
        for (uint256 i = 0; i < r.length; i++) {
            if (i == at) {
                r[i] = IRoles.ConditionFlat(uint8(list), T_STATIC, OP_EQUAL_TO, value);
                continue;
            }
            IRoles.ConditionFlat memory n = c[i < at ? i : i - 1];
            uint8 parent = i != 0 && n.parent >= at ? n.parent + 1 : n.parent;
            r[i] = IRoles.ConditionFlat(parent, n.paramType, n.operator_, n.compValue);
        }
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

    function _safetyRefused(address to, bytes memory data) internal {
        vm.prank(address(emergency));
        (bool ok, bytes memory ret) =
            address(safetyMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, CALL, EMERGENCY, true)));
        assertFalse(ok, "the safety modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
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
