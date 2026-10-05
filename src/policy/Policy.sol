// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";
import {ISafe} from "../interfaces/ISafe.sol";
import {IERC20, IStETH, IERC4626, IWithdrawalQueue} from "../interfaces/Tokens.sol";

/// @title Policy — the Clutch launch policy, expressed as Roles admin calls.
/// @dev The permissions follow the decision records ADR 005 to ADR 011 in
///      docs/adr, against the Roles interface pinned at
///      gnosisguild/zodiac-modifier-roles @ 820e5bc. The kit started as a
///      port of a provider's draft permission set and now differs from it by
///      decision. ADR 004 moves the policy to a data file and a compiler;
///      this library is the dry-run form until then.
///
///      Budgets and fixed ceilings are dry-run stand-ins. The production
///      figures come from the attested computation (ADR 009) and are not in
///      this repository.
library Policy {
    // ------------------------------------------------------------------
    // Roles v4 enum values (orderings pinned from Types.sol @ 820e5bc)
    // ------------------------------------------------------------------
    uint8 internal constant PARAM_NONE = 0;
    uint8 internal constant PARAM_STATIC = 1;
    uint8 internal constant PARAM_DYNAMIC = 2;
    uint8 internal constant PARAM_TUPLE = 3;
    uint8 internal constant PARAM_ARRAY = 4;
    uint8 internal constant PARAM_CALLDATA = 5;

    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_OR = 2;
    uint8 internal constant OP_NOR = 3;
    uint8 internal constant OP_EQUAL_TO_AVATAR = 15;
    uint8 internal constant OP_EQUAL_TO = 16;
    uint8 internal constant OP_GREATER_THAN = 17;
    uint8 internal constant OP_LESS_THAN = 18;
    uint8 internal constant OP_WITHIN_ALLOWANCE = 28;

    uint8 internal constant EXEC_NONE = 0;
    uint8 internal constant EXEC_SEND = 1;

    // ------------------------------------------------------------------
    // Role keys and budget keys
    // ------------------------------------------------------------------
    // The dry-run derives each key as keccak256 of a label. The setAllowance
    // call and the WithinAllowance compValue only have to agree with each
    // other. The policy compiler of ADR 004 fixes the production encoding.
    function OPERATOR() internal pure returns (bytes32) {
        return keccak256("operator");
    }

    function EMERGENCY() internal pure returns (bytes32) {
        return keccak256("emergency");
    }

    /// @dev Technical role: the Emergency Brakes multisig. Holds one power,
    ///      module disabling, with the module argument pinned (ADR 005).
    function TECHNICAL() internal pure returns (bytes32) {
        return keccak256("technical-emergency");
    }

    /// @dev Governance role: an enacted Easy Track motion changes the
    ///      operator's policy through the modifier as this role, so Easy
    ///      Track needs no authority on the Aragon Agent (ADR 006). Dry-run
    ///      member: the mock script executor.
    function POLICY_ADMIN() internal pure returns (bytes32) {
        return keccak256("policy-admin");
    }

    // One budget key per protocol spender. An approval to the spender spends
    // the key; deposits spend nothing (ADR 009, OD-08).
    bytes32 internal constant K_SUSDS = keccak256("sky_savings_usds");
    bytes32 internal constant K_EARN_USD = keccak256("earn_usd_deposit");
    bytes32 internal constant K_EARN_ETH = keccak256("earn_eth_deposit_wsteth");
    bytes32 internal constant K_WITHDRAWAL_QUEUE = keccak256("lido_withdrawal_queue_steth");

    uint64 internal constant MONTH = 30 days;
    /// @dev A budget motion cannot set a refill period below 30 days (OD-08).
    uint64 internal constant MIN_REFILL_PERIOD = 30 days;

    // ------------------------------------------------------------------
    // Mainnet addresses, read at the fork block 25946643
    // ------------------------------------------------------------------
    struct Addresses {
        address safe; // the Asset Safe; owner of both modifiers
        address agent; // dry-run: MockAragonAgent; production: the Aragon Agent
        address operator; // dry-run: an address that stands in for the operator Safe
        address emergency; // dry-run: an address that stands in for the emergency Safe
        address policyAdmin; // dry-run: the mock script executor; production: the Easy Track script executor
        address technical; // dry-run: an address that stands in for the Emergency Brakes multisig
        address rolesOperator; // modifier carrying the operator and governance roles
        address rolesSafety; // modifier carrying the emergency and technical roles
        address steth;
        address wsteth;
        address weth;
        address ldo;
        address usdc;
        address usdt;
        address dai;
        address usds;
        address susds;
        address daiUsds; // Sky's DAI–USDS converter
        address withdrawalQueue; // Lido withdrawal queue
        address earnUsdDepositQueue; // USDC
        address earnUsdRedeemQueue;
        address earnUsdShare;
        address earnEthDepositQueue; // wstETH
        address earnEthRedeemQueue;
        address earnEthShare;
    }

    function fillTokens(Addresses memory a) internal pure {
        a.steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        a.wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        a.weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        a.ldo = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
        a.usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        a.usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        a.dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        a.usds = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
        a.susds = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    }

    function fillProtocols(Addresses memory a) internal pure {
        a.daiUsds = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
        a.withdrawalQueue = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
        a.earnUsdDepositQueue = 0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76;
        a.earnUsdRedeemQueue = 0x9e36A74FE278906a76e7615263e46a83fC40c47F;
        a.earnUsdShare = 0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981;
        a.earnEthDepositQueue = 0xe39EED9A454C4918F8d0682062777cB251cd513F;
        a.earnEthRedeemQueue = 0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4;
        a.earnEthShare = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4;
    }

    // ------------------------------------------------------------------
    // Condition builders (BFS-ordered per Integrity.sol)
    // ------------------------------------------------------------------
    function _rootWith(uint256 n) internal pure returns (IRoles.ConditionFlat[] memory c, uint256 next) {
        c = new IRoles.ConditionFlat[](1 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        next = 1;
    }

    /// @dev EqualTo compValues are the RAW padded words: the modifier's
    ///      BufferPacker stores keccak256(compValue) and PermissionChecker
    ///      compares keccak256(param word) against it.
    function _eqAddress(address a) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(a))));
    }

    function _eqUint(uint256 v) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(v));
    }

    function _eqBytes32(bytes32 v) internal pure returns (bytes memory) {
        return abi.encodePacked(v);
    }

    // ------------------------------------------------------------------
    // Admin-call records applied through the Asset Safe -> Roles.
    // ------------------------------------------------------------------
    struct Call {
        address to;
        bytes data;
    }

    function _call(address roles, bytes memory data) internal pure returns (Call memory) {
        return Call({to: roles, data: data});
    }

    function _assignRoles(address roles, address member, bytes32 key) internal pure returns (Call memory) {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = key;
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = true;
        return _call(roles, abi.encodeCall(IRoles.assignRoles, (member, keys, memberOf)));
    }

    function _setDefaultRole(address roles, address member, bytes32 key) internal pure returns (Call memory) {
        return _call(roles, abi.encodeCall(IRoles.setDefaultRole, (member, key)));
    }

    function _allowFunction(address roles, bytes32 key, address target, bytes4 sel)
        internal
        pure
        returns (Call memory)
    {
        return _call(roles, abi.encodeCall(IRoles.allowFunction, (key, target, sel, EXEC_NONE)));
    }

    /// @dev allowFunction that lets the call carry ETH.
    function _allowFunctionWithValue(address roles, bytes32 key, address target, bytes4 sel)
        internal
        pure
        returns (Call memory)
    {
        return _call(roles, abi.encodeCall(IRoles.allowFunction, (key, target, sel, EXEC_SEND)));
    }

    function _scopeTarget(address roles, bytes32 key, address target)
        internal
        pure
        returns (Call memory)
    {
        return _call(roles, abi.encodeCall(IRoles.scopeTarget, (key, target)));
    }

    function _setAllowance(address roles, bytes32 key, uint128 amount)
        internal
        pure
        returns (Call memory)
    {
        return _call(
            roles,
            abi.encodeCall(
                IRoles.setAllowance,
                (
                    key,
                    amount, // balance starts full
                    amount, // maxRefill
                    amount, // refill per period
                    MONTH,
                    uint64(0) // timestamp -> now
                )
            )
        );
    }

    // ------------------------------------------------------------------
    // Scoped permission builders
    // ------------------------------------------------------------------

    /// @dev One spender of an operator approval: either the budget key that
    ///      the spender serves, or a fixed ceiling for a spender with no key.
    struct Spender {
        address spender;
        bytes32 key; // non-zero: the approval spends this budget key
        uint256 cap; // used when key is zero: the approval must be below it
    }

    function keyed(address spender, bytes32 key) internal pure returns (Spender memory) {
        return Spender({spender: spender, key: key, cap: 0});
    }

    function capped(address spender, uint256 cap) internal pure returns (Spender memory) {
        return Spender({spender: spender, key: bytes32(0), cap: cap});
    }

    /// @dev token.approve(spender, amount) for the operator (ADR 009, OD-08).
    ///      A root Or holds one Matches branch per spender. A keyed branch
    ///      spends the spender's budget key, so an approval of zero spends
    ///      nothing and is always allowed. A capped branch has no key, and
    ///      the amount must be below the fixed ceiling. All spenders of a
    ///      token share one scope, because a second scope on the same
    ///      function replaces the first.
    ///      Layout (BFS): [0] Or; [1..n] Matches; then, per branch, the
    ///      spender EqualTo and the amount condition.
    function _opApprove(address roles, address token, Spender[] memory spenders)
        internal
        pure
        returns (Call memory)
    {
        uint256 n = spenders.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](1 + 3 * n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        for (uint256 i = 0; i < n; i++) {
            uint8 b = uint8(1 + i);
            uint256 k = 1 + n + 2 * i;
            c[b] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
            c[k] = IRoles.ConditionFlat({parent: b, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(spenders[i].spender)});
            c[k + 1] = spenders[i].key != bytes32(0)
                ? IRoles.ConditionFlat({parent: b, paramType: PARAM_STATIC, operator_: OP_WITHIN_ALLOWANCE, compValue: abi.encodePacked(spenders[i].key)})
                : IRoles.ConditionFlat({parent: b, paramType: PARAM_STATIC, operator_: OP_LESS_THAN, compValue: _eqUint(spenders[i].cap)});
        }
        return _call(
            roles,
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR(), token, IERC20.approve.selector, c, EXEC_NONE))
        );
    }

    /// @dev stETH.submit(referral) with ETH attached and the referral pinned
    ///      to zero. Lido mints the stETH to the caller, the Asset Safe.
    function _stake(address roles, address steth, bytes32 roleKey) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(1);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(address(0))});
        return _call(roles, abi.encodeCall(IRoles.scopeFunction, (roleKey, steth, IStETH.submit.selector, c, EXEC_SEND)));
    }

    /// @dev Sky's DAI–USDS converter: daiToUsds or usdsToDai(usr, wad) with
    ///      the receiver pinned to the avatar (OD-22).
    function _convert(address roles, address converter, bytes4 sel) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        return _call(roles, abi.encodeCall(IRoles.scopeFunction, (OPERATOR(), converter, sel, c, EXEC_NONE)));
    }

    /// @dev Lido withdrawal queue: requestWithdrawals(amounts, owner) with
    ///      the owner pinned to the avatar. The uint256[] node carries a
    ///      Static/Pass element child per Integrity.sol.
    function _requestWithdrawals(address roles, address queue) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(3);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_ARRAY, operator_: OP_PASS, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 1, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR(), queue, IWithdrawalQueue.requestWithdrawals.selector, c, EXEC_NONE))
        );
    }

    /// @dev ERC-4626 deposit(assets, receiver): amount unbudgeted, receiver avatar.
    function _savingsDeposit(address roles, address vault, bytes32 roleKey)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(IRoles.scopeFunction, (roleKey, vault, IERC4626.deposit.selector, c, EXEC_NONE))
        );
    }

    /// @dev ERC-4626 redeem/withdraw(amount, receiver, owner): amount pass,
    ///      receiver and owner avatar.
    function _exitSavings(address roles, address vault, bytes4 sel, bytes32 roleKey)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(3);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        return _call(roles, abi.encodeCall(IRoles.scopeFunction, (roleKey, vault, sel, c, EXEC_NONE)));
    }

    /// @dev Emergency approve-to-zero on `token`: spender in the list, amount == 0.
    function _emApproveZero(address roles, address token, address[] memory spenders)
        internal
        pure
        returns (Call memory)
    {
        uint256 n = spenders.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](3 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqUint(0)});
        for (uint256 i = 0; i < n; i++) {
            c[3 + i] = IRoles.ConditionFlat({parent: 1, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(spenders[i])});
        }
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (EMERGENCY(), token, IERC20.approve.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev transfer(to, amount) pinned to a literal destination (the Agent).
    function _transferToAgent(address roles, address token, address agent)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(agent)});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (EMERGENCY(), token, IERC20.transfer.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev The Safe owns both modifiers, so the emergency role may call
    ///      roles.revokeTarget(roleKey pinned to operator, target pass).
    /// @param roles modifier the permission is written into (safety)
    /// @param target modifier whose operator scope may be revoked (operator)
    function _emRevokeTarget(address roles, address target) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBytes32(OPERATOR())});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (EMERGENCY(), target, IRoles.revokeTarget.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev Emergency may call roles.revokeFunction(roleKey pinned to
    ///      operator, target pass, selector pass).
    function _emRevokeFunction(address roles, address target) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(3);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBytes32(OPERATOR())});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (EMERGENCY(), target, IRoles.revokeFunction.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev disableModule(prevModule, module) for the technical role.
    ///      The module argument is pinned to this modifier by EqualTo, so the
    ///      power cannot be turned on a future second module. prevModule is a
    ///      linked-list pointer whose value depends on the Safe's module list
    ///      at call time, so it stays unconstrained.
    /// @param roles the modifier the permission is written into (safety)
    /// @param safe the avatar
    /// @param moduleToDisable the modifier this power may switch off (operator)
    function _techDisableModule(address roles, address safe, address moduleToDisable)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](3);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(moduleToDisable)});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction, (TECHNICAL(), safe, ISafe.disableModule.selector, c, EXEC_NONE)
            )
        );
    }

    // ------------------------------------------------------------------
    // Bounded governance scopes (ADR 006).
    //
    // Pinning only the role key leaves an indirect escalation: the
    // governance role grants the OPERATOR a permission whose target is the
    // modifier itself, and the operator then calls owner-only administration
    // through the avatar. Every governance scope below therefore pins the
    // role key to OPERATOR *and* forbids the modifier and the Safe as the
    // target, using Nor over the two admin addresses.
    //
    // This deny-list of the two addresses that grant administration is
    // necessary and not sufficient. The Easy Track factories carry the
    // positive rules: each one builds only its own kind of change.
    // ------------------------------------------------------------------

    /// @dev Layout for an admin call whose params are (roleKey, target, ...rest).
    ///      Node 0 root, node 1 roleKey == OPERATOR, node 2 target Nor-guard,
    ///      nodes 3..n Pass for the remaining params, then the Nor children.
    function _paGuard(uint256 paramCount, address roles, address safe)
        internal
        pure
        returns (IRoles.ConditionFlat[] memory c)
    {
        require(paramCount >= 2, "paGuard: params");
        uint256 trailing = paramCount - 2;
        c = new IRoles.ConditionFlat[](1 + paramCount + 2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBytes32(OPERATOR())});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_NOR, compValue: ""});
        for (uint256 k = 0; k < trailing; k++) {
            c[3 + k] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        }
        c[3 + trailing] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(roles)});
        c[4 + trailing] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(safe)});
    }

    function _paScoped(address roles, address safe, bytes4 sel, uint256 paramCount)
        internal
        pure
        returns (Call memory)
    {
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction, (POLICY_ADMIN(), roles, sel, _paGuard(paramCount, roles, safe), EXEC_NONE)
            )
        );
    }

    /// @dev scopeFunction(roleKey, target, selector, ConditionFlat[], options).
    ///      The condition array carries a Tuple element template so Integrity
    ///      accepts an unconstrained dynamic array of structs.
    function _paScopeFunction(address roles, address safe) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](13);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBytes32(OPERATOR())});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_NOR, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // selector
        c[4] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_ARRAY, operator_: OP_PASS, compValue: ""}); // conditions
        c[5] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // options
        c[6] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(roles)});
        c[7] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(safe)});
        c[8] = IRoles.ConditionFlat({parent: 4, paramType: PARAM_TUPLE, operator_: OP_PASS, compValue: ""});
        c[9] = IRoles.ConditionFlat({parent: 8, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[10] = IRoles.ConditionFlat({parent: 8, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[11] = IRoles.ConditionFlat({parent: 8, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[12] = IRoles.ConditionFlat({parent: 8, paramType: PARAM_DYNAMIC, operator_: OP_PASS, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction, (POLICY_ADMIN(), roles, IRoles.scopeFunction.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev setAllowance(key, balance, maxRefill, refill, period, timestamp):
    ///      the key must be one of the operator's own budget keys, and the
    ///      period must be at least MIN_REFILL_PERIOD. The per-key ceilings
    ///      need the attested figures and are not set here.
    function _paSetAllowance(address roles, bytes32[] memory keys) internal pure returns (Call memory) {
        uint256 n = keys.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](7 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // balance
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // maxRefill
        c[4] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // refill
        c[5] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_GREATER_THAN, compValue: _eqUint(MIN_REFILL_PERIOD - 1)}); // period
        c[6] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""}); // timestamp
        for (uint256 k = 0; k < n; k++) {
            c[7 + k] = IRoles.ConditionFlat({parent: 1, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBytes32(keys[k])});
        }
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction, (POLICY_ADMIN(), roles, IRoles.setAllowance.selector, c, EXEC_NONE)
            )
        );
    }

    function operatorBudgetKeys() internal pure returns (bytes32[] memory k) {
        k = new bytes32[](4);
        k[0] = K_SUSDS;
        k[1] = K_EARN_USD;
        k[2] = K_EARN_ETH;
        k[3] = K_WITHDRAWAL_QUEUE;
    }
}
