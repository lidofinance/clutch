// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";
import {ISafe} from "../interfaces/ISafe.sol";
import {IERC20, IStETH, IWstETH, ISDAI, IAaveV3Pool, ILidoEarnDepositQueue, ILidoEarnRedeemQueue, ICowSettlement} from "../interfaces/Tokens.sol";

/// @title Policy — the lido-atm-constellation permission set, expressed as
///        Roles v4 admin calls.
/// @dev Compiled from gnosisguild/lido-atm-constellation @ 02ea37d
///      (constellation/roles/*/permissions.ts, allowances/index.ts) against
///      the Roles v4 interface pinned at gnosisguild/zodiac-modifier-roles
///      @ 820e5bc. Two deliberate divergences, both recorded in the DD notes:
///      1. Drill budgets are dust-scale; structure (refill/maxRefill/period)
///         is identical to the proposal. Production sizing is WS-F work.
///      2. The proposal's `swap()` SDK action is approximated by a scoped
///         CoW `setPreSignature` permission plus scoped approvals to the CoW
///         vault relayer. Parity with the SDK-compiled output is a WS-C check.
///      3. Earn deposit is scoped to the on-chain verified signature
///         deposit(uint224,address,bytes32[]); the constellation source passes
///         a single amount condition — flagged as a repo parity question.
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
    uint8 internal constant OP_LESS_THAN = 18;
    uint8 internal constant OP_WITHIN_ALLOWANCE = 28;

    uint8 internal constant EXEC_NONE = 0;

    // ------------------------------------------------------------------
    // Role keys and allowance keys
    // ------------------------------------------------------------------
    // Parity note: the production keys come from the Zodiac SDK's
    // `encodeKey(...)`. The dry-run derives them as keccak256 of the label;
    // the derivation only has to be internally consistent between
    // setAllowance and the WithinAllowance compValue. SDK parity = WS-C item.
    function OPERATOR() internal pure returns (bytes32) {
        return keccak256("operator");
    }

    function EMERGENCY() internal pure returns (bytes32) {
        return keccak256("emergency");
    }

    /// @dev Third role for the corrected governance path: ET-driven policy
    ///      changes execute through the Roles modifier as this role (same
    ///      mechanism the emergency role uses), so Easy Track never needs
    ///      RUN_SCRIPT authority on the Agent. Dry-run member: the mock EVMScript
    ///      executor. Production member: a Lido-built, shape-validating
    ///      contract (WS-D).
    /// @dev Technical emergency: the Emergency Brakes multisig. Holds one
    ///      power, module disabling, with the module argument pinned.
    function TECHNICAL() internal pure returns (bytes32) {
        return keccak256("technical-emergency");
    }

    function POLICY_ADMIN() internal pure returns (bytes32) {
        return keccak256("policy-admin");
    }

    bytes32 internal constant K_AAVE_USDC_USDT = keccak256("aave_supply_usdc_usdt");
    bytes32 internal constant K_AAVE_DAI_USDS = keccak256("aave_supply_dai_usds");
    bytes32 internal constant K_AAVE_WSTETH = keccak256("aave_supply_wsteth");
    bytes32 internal constant K_SKY_DAI_USDS = keccak256("sky_savings_dai_usds");
    bytes32 internal constant K_EARN_USD = keccak256("earn_usd_deposit");
    bytes32 internal constant K_EARN_ETH = keccak256("earn_eth_deposit_wsteth");

    uint64 internal constant MONTH = 30 days;

    // ------------------------------------------------------------------
    // Mainnet addresses (from constellation zodiac.config.ts + addresses.ts,
    // on-chain verified in WS-B at block 25946643)
    // ------------------------------------------------------------------
    struct Addresses {
        address safe; // the dry-run Asset Safe (Roles owner)
        address agent; // dry-run: MockAragonAgent; production: Aragon Agent
        address operator; // dry-run: stand-in for the TMC Safe
        address emergency; // dry-run: stand-in for the EB Safe
        address policyAdmin; // dry-run: mock EVMScript executor; production: the ET script executor
        address technical; // Emergency Brakes multisig: module disabling only
        address rolesOperator; // modifier carrying operator + governance, guarded
        address rolesSafety; // modifier carrying emergency + technical, unguarded
        address steth;
        address wsteth;
        address ldo;
        address usdc;
        address usdt;
        address dai;
        address sdai;
        address usds;
        address susds;
        address aavePool;
        address earnUsdDepositQueue; // USDC
        address earnUsdRedeemQueue;
        address earnUsdShare;
        address earnEthDepositQueue; // wstETH
        address earnEthRedeemQueue;
        address earnEthShare;
        address cowVaultRelayer;
        address cowSettlement;
        address atokenUsdc;
        address atokenUsdt;
        address atokenDai;
        address atokenUsds;
        address atokenWsteth;
    }

    function mainnetTokens()
        internal
        pure
        returns (
            address steth,
            address wsteth,
            address ldo,
            address usdc,
            address usdt,
            address dai,
            address sdai,
            address usds,
            address susds
        )
    {
        steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        ldo = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        sdai = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
        usds = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
        susds = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    }

    function mainnetProtocols()
        internal
        pure
        returns (
            address aavePool,
            address earnUsdDq,
            address earnUsdRq,
            address earnUsdShare,
            address earnEthDq,
            address earnEthRq,
            address earnEthShare,
            address cowVaultRelayer,
            address cowSettlement
        )
    {
        aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        earnUsdDq = 0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76;
        earnUsdRq = 0x9e36A74FE278906a76e7615263e46a83fC40c47F;
        earnUsdShare = 0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981;
        earnEthDq = 0xe39EED9A454C4918F8d0682062777cB251cd513F;
        earnEthRq = 0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4;
        earnEthShare = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4;
        cowVaultRelayer = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
        cowSettlement = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    }

    function fillTokens(Addresses memory a) internal pure {
        (
            a.steth,
            a.wsteth,
            a.ldo,
            a.usdc,
            a.usdt,
            a.dai,
            a.sdai,
            a.usds,
            a.susds
        ) = mainnetTokens();
    }

    function fillProtocols(Addresses memory a) internal pure {
        (
            a.aavePool,
            a.earnUsdDepositQueue,
            a.earnUsdRedeemQueue,
            a.earnUsdShare,
            a.earnEthDepositQueue,
            a.earnEthRedeemQueue,
            a.earnEthShare,
            a.cowVaultRelayer,
            a.cowSettlement
        ) = mainnetProtocols();
    }

    function fillAtokens(Addresses memory a) internal pure {
        a.atokenUsdc = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
        a.atokenUsdt = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;
        a.atokenDai = 0x018008bfb33d285247A21d44E50697654f754e63;
        a.atokenUsds = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259;
        a.atokenWsteth = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
    }

    // ------------------------------------------------------------------
    // Condition builders (BFS-ordered per Integrity.sol)
    // ------------------------------------------------------------------
    function _root() internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](1);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
    }

    function _rootWith(uint256 n) internal pure returns (IRoles.ConditionFlat[] memory c, uint256 next) {
        c = new IRoles.ConditionFlat[](1 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        next = 1;
    }

    function _padAddress(address a) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(a))));
    }

    /// @dev EqualTo compValues are the RAW padded words: the modifier's
    ///      BufferPacker stores keccak256(compValue) and PermissionChecker
    ///      compares keccak256(param word) against it (probe evidence
    ///      test_D_matches_direct_raw vs test_C_matches_direct_keccak,
    ///      2026-09-10).
    function _eqAddress(address a) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(a))));
    }

    function _eqUint(uint256 v) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(v));
    }

    function _eqBytes32(bytes32 v) internal pure returns (bytes memory) {
        return abi.encodePacked(v);
    }

    function _eqBool(bool v) internal pure returns (bytes memory) {
        return _eqUint(v ? 1 : 0);
    }

    function _padUint(uint256 v) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(v));
    }

    function _padBool(bool v) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(v ? 1 : 0)));
    }

    // ------------------------------------------------------------------
    // Admin-call records applied by the deployer through Safe -> Roles.
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
    // Scoped permission builders (each mirrors one constellation entry)
    // ------------------------------------------------------------------

    /// @dev P0-3: token.approve(spender pinned, amount bounded).
    ///      Revision 4 showed the operator could set an unlimited relayer
    ///      approval and restore it after an emergency revocation, so an
    ///      approval snapshot was never a loss bound. The amount is now
    ///      either exactly zero (self-revocation stays available) or strictly
    ///      below a per-token ceiling.
    function _opApproveEq(
        address roles,
        address token,
        address spender,
        bytes32 roleKey,
        uint256 cap
    ) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](5);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(spender)});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqUint(0)});
        c[4] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_LESS_THAN, compValue: _eqUint(cap)});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (roleKey, token, IERC20.approve.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev P0-3: token.approve(spender in list, amount bounded). See above.
    function _opApproveOr(
        address roles,
        address token,
        address[] memory spenders,
        bytes32 roleKey,
        uint256 cap
    ) internal pure returns (Call memory) {
        uint256 n = spenders.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](3 + n + 2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        for (uint256 i = 0; i < n; i++) {
            c[3 + i] = IRoles.ConditionFlat({parent: 1, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(spenders[i])});
        }
        c[3 + n] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqUint(0)});
        c[4 + n] = IRoles.ConditionFlat({parent: 2, paramType: PARAM_STATIC, operator_: OP_LESS_THAN, compValue: _eqUint(cap)});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (roleKey, token, IERC20.approve.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev Aave v3 Core supply(asset, amount, onBehalfOf, referralCode)
    ///      with per-asset-group budgets: a root Or whose children are FULL
    /// Matches branches, one per (asset-group, budget-key) pair. Each branch
    /// re-describes the whole call and carries its own WithinAllowance in
    /// the amount position, so USDC/USDT share k1, DAI/USDS share k2 and
    /// wstETH draws k3 — the provider's declared shape, verified on the
    /// deployed mastercopy (ReviewProbe.test_FX4_per_asset_budgets_ARE_
    /// expressible). CORRECTION 2026-09-10: an earlier revision claimed this
    /// shape was inexpressible; the claim was wrong and is retracted.
    ///      Layout (BFS): [0] root Or; [1..n] Matches branches (parent 0);
    ///      then per-branch children in call-param order: asset EqualTo,
    ///      amount WithinAllowance, onBehalfOf EqualToAvatar, referral Pass.
    function _opAaveSupplyMulti(
        address roles,
        address[] memory assets,
        bytes32[] memory keys,
        bytes32 roleKey,
        address pool
    ) internal pure returns (Call memory) {
        uint256 n = assets.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](1 + 5 * n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        for (uint256 i = 0; i < n; i++) {
            uint256 b = 1 + i; // branch node index
            uint256 k = 1 + n + 4 * i; // first child index of branch i (exact stride, no ghost slots)
            c[b] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
            c[k] = IRoles.ConditionFlat({parent: uint8(b), paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(assets[i])});
            c[k + 1] = IRoles.ConditionFlat({parent: uint8(b), paramType: PARAM_STATIC, operator_: OP_WITHIN_ALLOWANCE, compValue: abi.encodePacked(keys[i])});
            c[k + 2] = IRoles.ConditionFlat({parent: uint8(b), paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
            c[k + 3] = IRoles.ConditionFlat({parent: uint8(b), paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        }
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (roleKey, pool, IAaveV3Pool.supply.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev Aave v3 withdraw(asset, amount, to): asset in list, amount pass, to avatar.
    function _exitAaveWithdraw(address roles, address[] memory assets, address pool, bytes32 roleKey)
        internal
        pure
        returns (Call memory)
    {
        uint256 n = assets.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](4 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        for (uint256 i = 0; i < n; i++) {
            c[4 + i] = IRoles.ConditionFlat({parent: 1, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqAddress(assets[i])});
        }
        return _call(
            roles,
            abi.encodeCall(IRoles.scopeFunction, (roleKey, pool, IAaveV3Pool.withdraw.selector, c, EXEC_NONE))
        );
    }

    /// @dev sDAI/sUSDS deposit(uint256,address): amount within allowance, receiver avatar.
    function _opSavingsDeposit(address roles, address vault, bytes32 key, bytes32 roleKey)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_WITHIN_ALLOWANCE, compValue: abi.encodePacked(key)});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO_AVATAR, compValue: ""});
        return _call(
            roles,
            abi.encodeCall(IRoles.scopeFunction, (roleKey, vault, ISDAI.deposit.selector, c, EXEC_NONE))
        );
    }

    /// @dev redeem/withdraw(uint256,address,address): amount pass, receiver+owner avatar.
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

    /// @dev Earn deposit(uint224,address,bytes32[]) matching the provider:
    ///      amount within allowance; referral (param 2) unconstrained — it
    ///      carries no custody and the provider leaves it open; proof array
    ///      unconstrained. A Matches root with fewer children than parameters
    ///      is legal (ReviewProbe.test_FX7); undescribed trailing parameters
    ///      are simply unconstrained.
    function _opEarnDeposit(address roles, address queue, bytes32 key, bytes32 roleKey)
        internal
        pure
        returns (Call memory)
    {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_WITHIN_ALLOWANCE, compValue: abi.encodePacked(key)});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (roleKey, queue, ILidoEarnDepositQueue.deposit.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev Emergency approve-to-zero on `token`: spender in APPROVED_SPENDERS, amount == 0.
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

    /// @dev The Safe-owns-modifier mechanism: emergency may call
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

    /// @dev CoW order presign: orderUid pass, approved == true.
    ///      NOTE (R1): sell-amount is NOT bounded here — this reproduces the
    ///      proposal's current TODO so drill D6 can demonstrate the gap.
    function _opCowPresign(address roles, address settlement) internal pure returns (Call memory) {
        IRoles.ConditionFlat[] memory c;
        (c,) = _rootWith(2);
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_DYNAMIC, operator_: OP_PASS, compValue: ""});
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_EQUAL_TO, compValue: _eqBool(true)});
        return _call(
            roles,
            abi.encodeCall(
                IRoles.scopeFunction,
                (OPERATOR(), settlement, ICowSettlement.setPreSignature.selector, c, EXEC_NONE)
            )
        );
    }

    /// @dev disableModule(prevModule, module) for the technical emergency role.
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
    // P0-2: bounded policy-admin scopes.
    //
    // Revision 4 proved that pinning only the role key leaves an indirect
    // escalation: the governance role grants the OPERATOR a permission whose
    // target is the modifier itself, and the operator then calls owner-only
    // administration through the avatar. Every policy-admin scope below
    // therefore pins the role key to OPERATOR *and* forbids the modifier and
    // the Safe as the target, using Nor over the two admin addresses.
    //
    // This is the in-modifier layer only. It is a deny-list of the two
    // addresses that grant administration, which is necessary and not
    // sufficient; the positive allow-list and the stale-motion rule live in
    // PolicyAdminController.
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
    ///      the key must be one of the operator's own budget keys.
    function _paSetAllowance(address roles, bytes32[] memory keys) internal pure returns (Call memory) {
        uint256 n = keys.length;
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](7 + n);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_CALLDATA, operator_: OP_MATCHES, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_NONE, operator_: OP_OR, compValue: ""});
        for (uint256 k = 0; k < 5; k++) {
            c[2 + k] = IRoles.ConditionFlat({parent: 0, paramType: PARAM_STATIC, operator_: OP_PASS, compValue: ""});
        }
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
        k = new bytes32[](6);
        k[0] = K_AAVE_USDC_USDT;
        k[1] = K_AAVE_DAI_USDS;
        k[2] = K_AAVE_WSTETH;
        k[3] = K_SKY_DAI_USDS;
        k[4] = K_EARN_USD;
        k[5] = K_EARN_ETH;
    }

    /// @dev CoW swap sell legs: approvals of each sell token to the vault relayer.
    function _opCowApprove(address roles, address token, address relayer, uint256 cap)
        internal
        pure
        returns (Call memory)
    {
        return _opApproveEq(roles, token, relayer, OPERATOR(), cap);
    }
}
