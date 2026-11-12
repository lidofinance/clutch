// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";

/// @title OrdersShape — the universal factory's shape for the orders account.
/// @notice A stateless companion of the universal factory. The factory creates it in its own constructor and calls
///         it only to read. It holds no state, makes no call and cannot be upgraded. It builds the writes of the
///         orders operation: a token's own permissions on the orders modifier and its exit on the safety
///         modifier, and the orders account's lists, each tree in the roles SDK's form, so that a motion writes
///         what the policy compiler would write. The factory checks the versions, the lists and the ceilings, and
///         writes the operator's funding transfer on the operator modifier itself.
/// @dev It exists because the factory and this shape together exceed EIP-170's 24,576 bytes.
contract OrdersShape {
    /// @dev The vault's accounts that the writes name, from the factory's own immutables.
    struct Context {
        address assetSafe;
        address agent;
        address ordersAccount;
        address ordersModifier;
        address safetyModifier;
    }

    bytes32 internal constant OPERATOR = "operator";
    bytes32 internal constant EMERGENCY = "emergency";
    bytes32 internal constant GOVERNANCE = "governance";
    bytes32 internal constant APPROVALS_ROLE = "approvals";
    bytes32 internal constant EXIT_GOVERNANCE = "exit-governance";

    /// @dev CoW Protocol's deployed contracts that the orders policy names, and the two tokens that a
    ///      recovery order buys: USDC, then USDT, in the SDK's order.
    address public constant ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;
    address public constant COMPOSABLE_COW = 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74;
    address public constant TWAP_HANDLER = 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5;
    address public constant TIMESTAMP_FACTORY = 0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc;
    address public constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    bytes4 internal constant SIGN_ORDER = 0x569d3489; // signOrder(GPv2Order.Data,uint32,uint256)
    bytes4 internal constant CREATE_WITH_CONTEXT = 0x0d0d9800; // createWithContext((address,bytes32,bytes),address,bytes,bool)
    bytes4 internal constant UNSIGN_ORDER = 0x5a66c223; // unsignOrder(GPv2Order.Data)
    bytes4 internal constant REMOVE = 0x95bc2673; // remove(bytes32)
    bytes4 internal constant APPROVE = 0x095ea7b3; // approve(address,uint256)
    bytes4 internal constant TRANSFER = 0xa9059cbb; // transfer(address,uint256)

    /// @dev `GPv2Order.BALANCE_ERC20`: plain ERC-20 balances.
    bytes32 internal constant ERC20_BALANCE = keccak256("erc20");
    /// @dev An operator order lives at most 90 days, a recovery order 1 day.
    uint256 public constant ORDER_LIFE = 90 days;
    uint256 public constant RECOVERY_LIFE = 1 days;
    /// @dev A grant's execution option for the order signer, which runs only by delegatecall.
    uint8 internal constant DELEGATECALL = 2;

    // Roles v2 encodings (see IRoles): parameter types and operators.
    uint8 internal constant T_NONE = 0;
    uint8 internal constant T_STATIC = 1;
    uint8 internal constant T_TUPLE = 3;
    uint8 internal constant T_CALLDATA = 5;
    uint8 internal constant T_ABI_ENCODED = 6;
    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_OR = 2;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO = 16;
    uint8 internal constant OP_LESS_THAN = 18;

    /// @notice The ten calls that give `token` its own permissions on the orders account, and its exit:
    ///         - on the orders modifier, through its governance role: the operator's return of the token, the
    ///           emergency role's zeroing and transfer, and the approvals role's relayer approval, each tree that
    ///           the role's guard pins whole; then, through the approvals role, the relayer approval itself;
    ///         - on the safety modifier, through the exit-governance role: the token's exit, a transfer to the
    ///           Aragon Agent or to the orders account.
    function tokenWrites(Context calldata x, address token) external pure returns (address[] memory to, bytes[] memory data) {
        to = new address[](10);
        data = new bytes[](10);
        IRoles.ConditionFlat[] memory returnTree = _anyOfTwo(x.assetSafe, x.agent);
        bytes[7] memory orders = [
            abi.encodeCall(IRoles.scopeTarget, (OPERATOR, token)),
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, TRANSFER, returnTree, 0)),
            abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)),
            abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, _approval(true), 0)),
            abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, returnTree, 0)),
            abi.encodeCall(IRoles.scopeTarget, (APPROVALS_ROLE, token)),
            abi.encodeCall(IRoles.scopeFunction, (APPROVALS_ROLE, token, APPROVE, _approval(false), 0))
        ];
        for (uint256 i = 0; i < 7; i++) (to[i], data[i]) = (x.ordersModifier, _govern(x.ordersModifier, orders[i]));
        bytes memory approval = abi.encodeWithSelector(APPROVE, COW_VAULT_RELAYER, type(uint256).max);
        to[7] = x.ordersModifier;
        data[7] = abi.encodeCall(IRoles.execTransactionWithRole, (token, 0, approval, 0, APPROVALS_ROLE, true));
        bytes[2] memory exits = [
            abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)),
            abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, _anyOfTwo(x.agent, x.ordersAccount), 0))
        ];
        for (uint256 i = 0; i < 2; i++) {
            to[8 + i] = x.safetyModifier;
            data[8 + i] = abi.encodeCall(IRoles.execTransactionWithRole, (x.safetyModifier, 0, exits[i], 0, EXIT_GOVERNANCE, true));
        }
    }

    /// @notice The three calls that write the orders account's lists, through the orders modifier's governance
    ///         role: the operator's signer and TWAP orders, on both sides, and the recovery orders' sell side.
    function listWrites(Context calldata x, address[] calldata operatorTokens, address[] calldata recoveryTokens)
        external
        pure
        returns (address[] memory to, bytes[] memory data)
    {
        return _listWrites(x, operatorTokens, recoveryTokens);
    }

    /// @notice The calls that give the operator back its authority on the orders account after the emergency role
    ///         revoked it, for the current lists: its two targets, the three order trees, its two cancels, and each
    ///         operator token's target with its return; then, through the approvals role, the relayer approval of
    ///         each token in `approvalTokens`, which the emergency role set to zero.
    function restoreWrites(
        Context calldata x,
        address[] calldata operatorTokens,
        address[] calldata recoveryTokens,
        address[] calldata approvalTokens
    ) external pure returns (address[] memory to, bytes[] memory data) {
        uint256 n = 7 + 2 * operatorTokens.length + approvalTokens.length;
        to = new address[](n);
        data = new bytes[](n);
        for (uint256 i = 0; i < n; i++) to[i] = x.ordersModifier;
        data[0] = _govern(x.ordersModifier, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, ORDER_SIGNER)));
        data[1] = _govern(x.ordersModifier, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, COMPOSABLE_COW)));
        (, bytes[] memory trees) = _listWrites(x, operatorTokens, recoveryTokens);
        (data[2], data[3], data[4]) = (trees[0], trees[1], trees[2]);
        data[5] = _govern(x.ordersModifier, abi.encodeCall(IRoles.allowFunction, (OPERATOR, ORDER_SIGNER, UNSIGN_ORDER, DELEGATECALL)));
        data[6] = _govern(x.ordersModifier, abi.encodeCall(IRoles.allowFunction, (OPERATOR, COMPOSABLE_COW, REMOVE, 0)));
        IRoles.ConditionFlat[] memory returnTree = _anyOfTwo(x.assetSafe, x.agent);
        uint256 k = 7;
        for (uint256 i = 0; i < operatorTokens.length; i++) {
            data[k++] = _govern(x.ordersModifier, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, operatorTokens[i])));
            data[k++] = _govern(
                x.ordersModifier, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, operatorTokens[i], TRANSFER, returnTree, 0))
            );
        }
        bytes memory approval = abi.encodeWithSelector(APPROVE, COW_VAULT_RELAYER, type(uint256).max);
        for (uint256 i = 0; i < approvalTokens.length; i++) {
            data[k++] = abi.encodeCall(IRoles.execTransactionWithRole, (approvalTokens[i], 0, approval, 0, APPROVALS_ROLE, true));
        }
    }

    function _listWrites(Context memory x, address[] memory operatorTokens, address[] memory recoveryTokens)
        internal
        pure
        returns (address[] memory to, bytes[] memory data)
    {
        address[] memory recoveryBuy = new address[](2);
        (recoveryBuy[0], recoveryBuy[1]) = (USDC, USDT);
        to = new address[](3);
        data = new bytes[](3);
        (to[0], to[1], to[2]) = (x.ordersModifier, x.ordersModifier, x.ordersModifier);
        data[0] = _govern(
            x.ordersModifier,
            abi.encodeCall(
                IRoles.scopeFunction,
                (OPERATOR, ORDER_SIGNER, SIGN_ORDER, signTree(operatorTokens, operatorTokens, x.assetSafe, ORDER_LIFE), DELEGATECALL)
            )
        );
        data[1] = _govern(
            x.ordersModifier,
            abi.encodeCall(
                IRoles.scopeFunction,
                (OPERATOR, COMPOSABLE_COW, CREATE_WITH_CONTEXT, twapTree(operatorTokens, operatorTokens, x.assetSafe), 0)
            )
        );
        data[2] = _govern(
            x.ordersModifier,
            abi.encodeCall(
                IRoles.scopeFunction,
                (EMERGENCY, ORDER_SIGNER, SIGN_ORDER, signTree(recoveryTokens, recoveryBuy, x.agent, RECOVERY_LIFE), DELEGATECALL)
            )
        );
    }

    /// @dev A write of the orders modifier's governance role, which executes as the orders account.
    function _govern(address ordersModifier, bytes memory write) internal pure returns (bytes memory) {
        return abi.encodeCall(IRoles.execTransactionWithRole, (ordersModifier, 0, write, 0, GOVERNANCE, true));
    }

    /// @notice The condition tree of `signOrder` on the order signer, in the SDK's form: the listed tokens on
    ///         each side, the receiver, plain ERC-20 balances, zero app data, no signed fee, a fee bound of zero
    ///         and a `validDuration` of at most `life`. Each list is sorted, as
    ///         the SDK sorts an Or of values, and holds at least two tokens.
    function signTree(address[] memory sell, address[] memory buy, address receiver, uint256 life)
        public
        pure
        returns (IRoles.ConditionFlat[] memory c)
    {
        c = new IRoles.ConditionFlat[](16 + sell.length + buy.length);
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, T_TUPLE, OP_MATCHES, "");
        c[2] = _lte(0, life);
        c[3] = _zero(0);
        // the order's twelve fields
        c[4] = IRoles.ConditionFlat(1, T_NONE, OP_OR, "");
        c[5] = IRoles.ConditionFlat(1, T_NONE, OP_OR, "");
        c[6] = _equal(1, abi.encode(receiver));
        c[7] = _pass(1);
        c[8] = _pass(1);
        c[9] = _pass(1);
        c[10] = _zero(1);
        c[11] = _zero(1);
        c[12] = _pass(1);
        c[13] = _pass(1);
        c[14] = _equal(1, abi.encode(ERC20_BALANCE));
        c[15] = _equal(1, abi.encode(ERC20_BALANCE));
        _leaves(c, _leaves(c, 16, 4, sell), 5, buy);
    }

    /// @notice The condition tree of a TWAP order through ComposableCoW, in the SDK's form: CoW's TWAP handler and
    ///         current-timestamp factory, and one of the two allowed shapes, each with the listed tokens, the
    ///         receiver, a start at creation and zero app data. The shape of 12 parts at most 7 days apart comes
    ///         first, as the SDK orders the two.
    function twapTree(address[] memory sell, address[] memory buy, address receiver)
        public
        pure
        returns (IRoles.ConditionFlat[] memory c)
    {
        c = new IRoles.ConditionFlat[](28 + 2 * (sell.length + buy.length));
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, T_TUPLE, OP_MATCHES, "");
        c[2] = _equal(0, abi.encode(TIMESTAMP_FACTORY));
        c[3] = _equal(1, abi.encode(TWAP_HANDLER));
        c[4] = _pass(1);
        c[5] = IRoles.ConditionFlat(1, T_NONE, OP_OR, "");
        c[6] = IRoles.ConditionFlat(5, T_ABI_ENCODED, OP_MATCHES, "");
        c[7] = IRoles.ConditionFlat(5, T_ABI_ENCODED, OP_MATCHES, "");
        _twapShape(c, 8, 6, receiver, 12, 7 days);
        _twapShape(c, 18, 7, receiver, 90, 1 days);
        _leaves(c, _leaves(c, _leaves(c, _leaves(c, 28, 8, sell), 9, buy), 18, sell), 19, buy);
    }

    /// @dev One TWAP shape's ten fields, from `at`, under the AbiEncoded node `parent`: at most `parts` parts at
    ///      most `spacing` apart.
    function _twapShape(IRoles.ConditionFlat[] memory c, uint256 at, uint8 parent, address receiver, uint256 parts, uint256 spacing)
        internal
        pure
    {
        c[at] = IRoles.ConditionFlat(parent, T_NONE, OP_OR, "");
        c[at + 1] = IRoles.ConditionFlat(parent, T_NONE, OP_OR, "");
        c[at + 2] = _equal(parent, abi.encode(receiver));
        c[at + 3] = _pass(parent);
        c[at + 4] = _pass(parent);
        c[at + 5] = _zero(parent);
        c[at + 6] = _lte(parent, parts);
        c[at + 7] = _lte(parent, spacing);
        c[at + 8] = _pass(parent);
        c[at + 9] = _zero(parent);
    }

    /// @dev One EqualTo leaf per token under `parent`, from `at`; returns the next index.
    function _leaves(IRoles.ConditionFlat[] memory c, uint256 at, uint8 parent, address[] memory tokens)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < tokens.length; i++) c[at + i] = _equal(parent, abi.encode(tokens[i]));
        return at + tokens.length;
    }

    /// @dev A one-parameter call pinned to either of two accounts: an Or of the two, sorted.
    function _anyOfTwo(address a, address b) internal pure returns (IRoles.ConditionFlat[] memory c) {
        if (a > b) (a, b) = (b, a);
        c = new IRoles.ConditionFlat[](4);
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, T_NONE, OP_OR, "");
        c[2] = _equal(1, abi.encode(a));
        c[3] = _equal(1, abi.encode(b));
    }

    /// @dev An approval pinned to CoW's vault relayer, with the amount zero or open.
    function _approval(bool zeroAmount) internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](zeroAmount ? 3 : 2);
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = _equal(0, abi.encode(COW_VAULT_RELAYER));
        if (zeroAmount) c[2] = _zero(0);
    }

    function _equal(uint8 parent, bytes memory value) internal pure returns (IRoles.ConditionFlat memory) {
        return IRoles.ConditionFlat(parent, T_STATIC, OP_EQUAL_TO, value);
    }

    function _zero(uint8 parent) internal pure returns (IRoles.ConditionFlat memory) {
        return _equal(parent, abi.encode(uint256(0)));
    }

    function _pass(uint8 parent) internal pure returns (IRoles.ConditionFlat memory) {
        return IRoles.ConditionFlat(parent, T_STATIC, OP_PASS, "");
    }

    /// @dev At most `bound`, written as the SDK writes `lte`: LessThan the bound plus one.
    function _lte(uint8 parent, uint256 bound) internal pure returns (IRoles.ConditionFlat memory) {
        return IRoles.ConditionFlat(parent, T_STATIC, OP_LESS_THAN, abi.encode(bound + 1));
    }
}
