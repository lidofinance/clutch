// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../interfaces/IRoles.sol";

/// @title UniversalFactory — a prototype of Clutch's one Easy Track factory (ADR 013).
/// @notice Easy Track registers this factory with an address book: `execTransactionWithRole`
///         on the vault's four modifiers, and this factory's own `commit` (ADR 013, decision 6).
///         A motion carries the counter that it saw and a list of operations. The factory checks
///         every operation when the motion is created and again when it is enacted, because
///         Easy Track builds the script again at enactment and compares its hash. The script's
///         last call, `commit`, stores the new versions (decision 10).
/// @dev Prototype scope: versions and the counter; the operator's approval list of one token,
///      which widens only through its typed shape and narrows by removal (decision 7); the
///      revoke of one function; budgets within ceilings; ceilings that a motion lowers at any
///      time and raises at most twofold, once in 15 days (decision 13); the introduction of a
///      token, which sets its ceilings in the same operation (decision 15); the restore of a
///      target that the emergency role revoked (OD-104, decision 16); the restart (decision
///      12); and insurance money from the Asset Safe to the first-loss Safe (ADR 014,
///      decision 7). The other shapes, and each shape's emergency exit, come with the
///      exit-governance role. Every check here sits behind the modifiers' own guards.
contract UniversalFactory {
    // ------------------------------------------------------------------
    // The kinds of operation that a motion may carry
    // ------------------------------------------------------------------

    /// @dev The operator's `approve` list of one token. The motion states the current list and
    ///      the next one. An entry that the current list lacks, or that the next list changes,
    ///      widens and must fill the shape; an entry that leaves narrows.
    uint8 public constant APPROVALS = 1;
    /// @dev The revoke of one operator function: a raw write that only narrows.
    uint8 public constant REVOKE = 2;
    /// @dev One budget key of the operator, within the budget ceiling of its token.
    uint8 public constant BUDGET = 3;
    /// @dev One ceiling: lower it at any time, or raise it at most twofold, once in 15 days.
    uint8 public constant CEILING = 4;
    /// @dev Enable the operator modifier again after the switch.
    uint8 public constant RESTART = 5;
    /// @dev Move a token from the Asset Safe to the first-loss Safe, for insurance.
    uint8 public constant FUND = 6;
    /// @dev Introduce a token: its first approval list and both of its ceilings, together
    ///      (decision 15). A token is introduced once; the enabling vote introduces the launch
    ///      tokens by seeding their ceilings.
    uint8 public constant INTRODUCE = 7;
    /// @dev Scope again, for the operator, a target that the emergency role revoked as a whole.
    ///      It writes no new permission: the function permissions stored under the target, each
    ///      written by the enabling vote or by a motion, come back as they were last written.
    uint8 public constant RESTORE = 8;

    /// @dev The classes of ceiling, each per token: a budget key's figures, and the fixed cap
    ///      of an approval that spends no key.
    uint8 public constant BUDGET_CEILING = 1;
    uint8 public constant APPROVAL_CAP_CEILING = 2;

    uint256 public constant MIN_PERIOD = 30 days;
    uint256 public constant RAISE_INTERVAL = 15 days;
    uint256 public constant MAX_OPS = 16;
    uint256 public constant MAX_SPENDERS = 32;

    bytes32 internal constant OPERATOR = "operator";
    bytes32 internal constant GOVERNANCE = "governance";
    bytes32 internal constant RESTART_ROLE = "restart";
    bytes32 internal constant INSURANCE_FUNDING = "insurance-funding";

    bytes4 internal constant APPROVE = 0x095ea7b3; // approve(address,uint256)
    bytes4 internal constant TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 internal constant ENABLE_MODULE = 0x610b5925; // enableModule(address)

    /// @dev The prefix of a derived budget key. The governance role's guard on
    ///      `setAllowance` accepts a key with this prefix or a launch key.
    bytes2 public constant DERIVED_KEY_PREFIX = "k:";

    // Roles v2 encodings (see IRoles): parameter types and operators.
    uint8 internal constant T_NONE = 0;
    uint8 internal constant T_STATIC = 1;
    uint8 internal constant T_CALLDATA = 5;
    uint8 internal constant OP_OR = 2;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO = 16;
    uint8 internal constant OP_LESS_THAN = 18;
    uint8 internal constant OP_WITHIN_ALLOWANCE = 28;

    // ------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------

    struct Op {
        uint8 kind;
        bytes data;
    }

    /// @dev One spender of an approval list. A budgeted entry names its key and no cap; a
    ///      capped entry names its cap and no key.
    struct Entry {
        address spender;
        bytes32 key;
        uint256 cap;
    }

    /// @dev `set` marks a ceiling that the enabling vote seeded or that a token's
    ///      introduction set. A ceiling that was never set changes only by an introduction.
    struct Ceiling {
        uint256 value;
        uint64 lastRaise;
        bool set;
    }

    /// @dev A launch budget key: the key that the enabling vote's policy gives a spender.
    struct LaunchKey {
        address token;
        address spender;
        bytes32 key;
    }

    struct Seed {
        bytes32 scope;
        bytes32 version;
    }

    struct CeilingSeed {
        bytes32 key;
        uint256 value;
    }

    struct Config {
        address trustedCaller; // the committee's Safe
        address executor; // Easy Track's script executor
        address emergencySafe;
        address voting;
        address assetSafe;
        address operatorModifier;
        address safetyModifier;
        address ordersModifier;
        address firstLossModifier;
        address firstLossSafe;
    }

    /// @dev What one motion changes, collected while its operations are checked.
    struct Plan {
        address[] to;
        bytes[] data;
        uint256 calls;
        bytes32[] scopes;
        bytes32[] versions;
        uint256 writes;
        bytes32[] ceilingKeys;
        uint256[] ceilingValues;
        uint256 ceilings;
        bytes32[] claimed;
        uint256 claims;
        address[] introduced;
        uint256[] introducedBudgetCeilings;
        uint256 introductions;
    }

    // ------------------------------------------------------------------
    // Errors and events
    // ------------------------------------------------------------------

    error NotTrustedCaller(address creator);
    error NotExecutor(address caller);
    error NotAllowedToRaiseCounter(address caller);
    error StaleCounter(uint256 motion, uint256 current);
    error StaleVersion(bytes32 scope);
    error DuplicateScope(bytes32 scope);
    error NoOperations();
    error TooManyOperations();
    error UnknownOperation(uint8 kind);
    error NotCanonical();
    error BadEntry(address spender);
    error ProtectedAddress(address account);
    error KeyNotDerived(address spender, bytes32 key);
    error CapAboveCeiling(address token, uint256 cap, uint256 ceiling);
    error BudgetAboveCeiling(bytes32 key, uint256 ceiling);
    error PeriodTooShort(uint64 period);
    error RaiseFromZero(bytes32 key);
    error CeilingNotSet(bytes32 key);
    error TokenNotIntroduced(address token);
    error AlreadyIntroduced(address token);
    error EmptyIntroduction(address token);
    error RaiseTooLarge(bytes32 key, uint256 value, uint256 limit);
    error RaiseTooSoon(bytes32 key, uint256 next);
    error ZeroAmount();
    error LengthMismatch();

    event CounterRaised(uint256 epoch, address by);
    event VersionSet(bytes32 indexed scope, bytes32 version);
    event CeilingSet(bytes32 indexed key, uint256 value, bool raised);

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------

    address public immutable trustedCaller;
    address public immutable executor;
    address public immutable emergencySafe;
    address public immutable voting;
    address public immutable assetSafe;
    address public immutable operatorModifier;
    address public immutable safetyModifier;
    address public immutable ordersModifier;
    address public immutable firstLossModifier;
    address public immutable firstLossSafe;

    /// @notice The counter. A raise makes every open motion fail at enactment.
    uint256 public epoch;
    /// @notice The version of each scope: the hash of its content as this factory last wrote
    ///         it, or as the enabling vote wrote it. Zero for a scope that holds nothing.
    mapping(bytes32 scope => bytes32 version) public versions;
    /// @notice Each ceiling, by its key, with the time of its last raise.
    mapping(bytes32 key => Ceiling) public ceilings;
    /// @dev The launch budget keys, by the hash of their token and spender.
    mapping(bytes32 pair => bytes32 key) internal launchKeys;

    constructor(Config memory c, LaunchKey[] memory keys, Seed[] memory seeds, CeilingSeed[] memory caps) {
        trustedCaller = c.trustedCaller;
        executor = c.executor;
        emergencySafe = c.emergencySafe;
        voting = c.voting;
        assetSafe = c.assetSafe;
        operatorModifier = c.operatorModifier;
        safetyModifier = c.safetyModifier;
        ordersModifier = c.ordersModifier;
        firstLossModifier = c.firstLossModifier;
        firstLossSafe = c.firstLossSafe;
        for (uint256 i = 0; i < keys.length; i++) {
            launchKeys[_pair(keys[i].token, keys[i].spender)] = keys[i].key;
        }
        for (uint256 i = 0; i < seeds.length; i++) {
            versions[seeds[i].scope] = seeds[i].version;
            emit VersionSet(seeds[i].scope, seeds[i].version);
        }
        for (uint256 i = 0; i < caps.length; i++) {
            ceilings[caps[i].key].value = caps[i].value;
            ceilings[caps[i].key].set = true;
            emit CeilingSet(caps[i].key, caps[i].value, false);
        }
    }

    // ------------------------------------------------------------------
    // Easy Track
    // ------------------------------------------------------------------

    /// @notice Builds the script of a motion, after every check. Easy Track calls this at
    ///         creation and again at enactment.
    function createEVMScript(address creator, bytes calldata callData) external view returns (bytes memory) {
        if (creator != trustedCaller) revert NotTrustedCaller(creator);
        (uint256 motionEpoch, Op[] memory ops) = abi.decode(callData, (uint256, Op[]));
        if (motionEpoch != epoch) revert StaleCounter(motionEpoch, epoch);
        if (ops.length == 0) revert NoOperations();
        if (ops.length > MAX_OPS) revert TooManyOperations();

        Plan memory p = _plan(ops.length);
        for (uint256 i = 0; i < ops.length; i++) {
            uint8 kind = ops[i].kind;
            if (kind == APPROVALS) _approvals(p, ops[i].data);
            else if (kind == REVOKE) _revoke(p, ops[i].data);
            else if (kind == BUDGET) _budget(p, ops[i].data);
            else if (kind == CEILING) _ceiling(p, ops[i].data);
            else if (kind == RESTART) _restart(p);
            else if (kind == FUND) _fund(p, ops[i].data);
            else if (kind == INTRODUCE) _introduce(p, ops[i].data);
            else if (kind == RESTORE) _restore(p, ops[i].data);
            else revert UnknownOperation(kind);
        }
        return _script(p, motionEpoch);
    }

    /// @notice The motion's calldata, decoded for display.
    function decodeEVMScriptCallData(bytes calldata callData)
        external
        pure
        returns (uint256 motionEpoch, Op[] memory ops)
    {
        return abi.decode(callData, (uint256, Op[]));
    }

    /// @notice Easy Track's permissions for this factory: the address book (ADR 013, decision 6).
    function addressBook() public view returns (bytes memory) {
        bytes4 exec = IRoles.execTransactionWithRole.selector;
        return abi.encodePacked(
            operatorModifier,
            exec,
            safetyModifier,
            exec,
            ordersModifier,
            exec,
            firstLossModifier,
            exec,
            address(this),
            this.commit.selector
        );
    }

    /// @notice The last call of every script: stores the versions and ceilings that the motion
    ///         wrote. Only Easy Track's executor calls it, at enactment.
    function commit(
        uint256 motionEpoch,
        bytes32[] calldata scopes,
        bytes32[] calldata newVersions,
        bytes32[] calldata ceilingKeys,
        uint256[] calldata ceilingValues
    ) external {
        if (msg.sender != executor) revert NotExecutor(msg.sender);
        if (motionEpoch != epoch) revert StaleCounter(motionEpoch, epoch);
        if (scopes.length != newVersions.length || ceilingKeys.length != ceilingValues.length) revert LengthMismatch();
        for (uint256 i = 0; i < scopes.length; i++) {
            versions[scopes[i]] = newVersions[i];
            emit VersionSet(scopes[i], newVersions[i]);
        }
        for (uint256 i = 0; i < ceilingKeys.length; i++) {
            Ceiling storage c = ceilings[ceilingKeys[i]];
            bool raised = ceilingValues[i] > c.value;
            if (raised) c.lastRaise = uint64(block.timestamp);
            c.value = ceilingValues[i];
            c.set = true;
            emit CeilingSet(ceilingKeys[i], ceilingValues[i], raised);
        }
    }

    /// @notice Raises the counter, so that every open motion fails at enactment. The emergency
    ///         Safe raises it at every stop; Aragon Voting can raise it as the owner.
    function raiseCounter() external {
        if (msg.sender != emergencySafe && msg.sender != voting) revert NotAllowedToRaiseCounter(msg.sender);
        epoch += 1;
        emit CounterRaised(epoch, msg.sender);
    }

    // ------------------------------------------------------------------
    // Views for the motion builder and the checks
    // ------------------------------------------------------------------

    /// @notice The scope of one operator function.
    function functionScope(address target, bytes4 selector) public pure returns (bytes32) {
        return keccak256(abi.encode(OPERATOR, target, selector));
    }

    /// @notice The scope of one budget key.
    function allowanceScope(bytes32 key) public pure returns (bytes32) {
        return keccak256(abi.encode("allowance", key));
    }

    /// @notice The key of one ceiling.
    function ceilingKey(uint8 class, address token) public pure returns (bytes32) {
        return keccak256(abi.encode(class, token));
    }

    /// @notice The version of an approval list: zero when it is empty.
    function listVersion(Entry[] memory entries) public pure returns (bytes32) {
        return entries.length == 0 ? bytes32(0) : keccak256(abi.encode(entries));
    }

    /// @notice The version of a budget key's figures.
    function budgetVersion(uint128 balance, uint128 maxRefill, uint128 refill, uint64 period)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(balance, maxRefill, refill, period));
    }

    /// @notice The budget key of a spender of a token: its launch key, or the derived key, "k:"
    ///         then the spender then the token's first ten bytes (ADR 013, decision 9).
    function keyFor(address token, address spender) public view returns (bytes32) {
        bytes32 launch = launchKeys[_pair(token, spender)];
        if (launch != bytes32(0)) return launch;
        return bytes32(abi.encodePacked(DERIVED_KEY_PREFIX, spender, bytes10(bytes20(token))));
    }

    /// @notice The condition tree of an approval list, in the roles SDK's canonical form, so
    ///         that the factory writes what the policy compiler would write.
    function approvalTree(Entry[] memory entries) public pure returns (IRoles.ConditionFlat[] memory c) {
        uint256 n = entries.length;
        if (n == 1) {
            c = new IRoles.ConditionFlat[](3);
            c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
            c[1] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(entries[0].spender));
            c[2] = _amount(0, entries[0]);
            return c;
        }
        // An Or of one Matches per spender, sorted as the SDK sorts them: by spender.
        c = new IRoles.ConditionFlat[](1 + 3 * n);
        c[0] = IRoles.ConditionFlat(0, T_NONE, OP_OR, "");
        for (uint256 i = 0; i < n; i++) {
            c[1 + i] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
            uint8 branch = uint8(1 + i);
            c[1 + n + 2 * i] = IRoles.ConditionFlat(branch, T_STATIC, OP_EQUAL_TO, abi.encode(entries[i].spender));
            c[2 + n + 2 * i] = _amount(branch, entries[i]);
        }
    }

    // ------------------------------------------------------------------
    // Operations
    // ------------------------------------------------------------------

    function _approvals(Plan memory p, bytes memory data) internal view {
        (address token, Entry[] memory current, Entry[] memory next) = abi.decode(data, (address, Entry[], Entry[]));
        _protected(token);
        _canonical(current);
        _canonical(next);
        if (!_introduced(token)) revert TokenNotIntroduced(token);
        bytes32 scope = functionScope(token, APPROVE);
        if (versions[scope] != listVersion(current)) revert StaleVersion(scope);
        uint256 approvalCeiling = ceilings[ceilingKey(APPROVAL_CAP_CEILING, token)].value;

        // Every entry of the next list either stays as it is, lowers a cap, or widens.
        uint256 j;
        for (uint256 i = 0; i < next.length; i++) {
            Entry memory e = next[i];
            while (j < current.length && current[j].spender < e.spender) j++;
            bool found = j < current.length && current[j].spender == e.spender;
            if (found && current[j].key == e.key && current[j].cap == e.cap) continue;
            if (found && current[j].key == bytes32(0) && e.key == bytes32(0) && e.cap < current[j].cap) continue;
            _widen(token, e, approvalCeiling);
        }

        bytes memory write = next.length == 0
            ? abi.encodeCall(IRoles.revokeFunction, (OPERATOR, token, APPROVE))
            : abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, APPROVE, approvalTree(next), 0));
        _govern(p, write);
        _write(p, scope, listVersion(next));
    }

    /// @dev A widening entry fills the shape: a spender that is no vault account, and either the
    ///      key that the factory derives for it, or a cap within the token's approval ceiling.
    function _widen(address token, Entry memory e, uint256 approvalCeiling) internal view {
        _protected(e.spender);
        if (e.key != bytes32(0)) {
            bytes32 expected = keyFor(token, e.spender);
            if (e.key != expected) revert KeyNotDerived(e.spender, e.key);
        } else if (e.cap > approvalCeiling) {
            revert CapAboveCeiling(token, e.cap, approvalCeiling);
        }
    }

    /// @dev A token's introduction (decision 15): the token's first approval list, which fills
    ///      the shape under the new approval ceiling, and both of its ceilings. The operations
    ///      after it in the same motion check the token's budgets against the new budget
    ///      ceiling. The introduction counts as each ceiling's first raise.
    function _introduce(Plan memory p, bytes memory data) internal view {
        (address token, Entry[] memory list, uint256 budgetCeiling, uint256 approvalCeiling) =
            abi.decode(data, (address, Entry[], uint256, uint256));
        _protected(token);
        bytes32 scope = functionScope(token, APPROVE);
        if (_introduced(token) || versions[scope] != bytes32(0)) revert AlreadyIntroduced(token);
        _canonical(list);
        if (list.length == 0) revert EmptyIntroduction(token);
        for (uint256 i = 0; i < list.length; i++) _widen(token, list[i], approvalCeiling);
        _govern(p, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, token)));
        _govern(p, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, token, APPROVE, approvalTree(list), 0)));
        _write(p, scope, listVersion(list));
        _setCeiling(p, ceilingKey(BUDGET_CEILING, token), budgetCeiling);
        _setCeiling(p, ceilingKey(APPROVAL_CAP_CEILING, token), approvalCeiling);
        p.introduced[p.introductions] = token;
        p.introducedBudgetCeilings[p.introductions++] = budgetCeiling;
    }

    /// @dev The restore of a target (OD-104): `scopeTarget` under the operator key. Roles keeps a
    ///      target's function permissions when the target is revoked, so they come back as they
    ///      were; a target with none stored gives the operator nothing. The policy holds no
    ///      whole-target clearance, so a restore never narrows one.
    function _restore(Plan memory p, bytes memory data) internal view {
        address target = abi.decode(data, (address));
        _protected(target);
        _govern(p, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, target)));
    }

    function _revoke(Plan memory p, bytes memory data) internal view {
        (address target, bytes4 selector, bytes32 expected) = abi.decode(data, (address, bytes4, bytes32));
        bytes32 scope = functionScope(target, selector);
        if (versions[scope] != expected) revert StaleVersion(scope);
        _govern(p, abi.encodeCall(IRoles.revokeFunction, (OPERATOR, target, selector)));
        _write(p, scope, bytes32(0));
    }

    function _budget(Plan memory p, bytes memory data) internal view {
        (
            address token,
            address spender,
            uint128 balance,
            uint128 maxRefill,
            uint128 refill,
            uint64 period,
            bytes32 expected
        ) = abi.decode(data, (address, address, uint128, uint128, uint128, uint64, bytes32));
        bytes32 key = keyFor(token, spender);
        bytes32 scope = allowanceScope(key);
        if (versions[scope] != expected) revert StaleVersion(scope);
        uint256 ceiling = _budgetCeiling(p, token);
        if (balance > ceiling || maxRefill > ceiling || refill > ceiling) revert BudgetAboveCeiling(key, ceiling);
        if (period < MIN_PERIOD) revert PeriodTooShort(period);
        _govern(p, abi.encodeCall(IRoles.setAllowance, (key, balance, maxRefill, refill, period, 0)));
        _write(p, scope, budgetVersion(balance, maxRefill, refill, period));
    }

    function _ceiling(Plan memory p, bytes memory data) internal view {
        (bytes32 key, uint256 expected, uint256 value) = abi.decode(data, (bytes32, uint256, uint256));
        Ceiling memory c = ceilings[key];
        // A token's first ceilings come only with its introduction (decision 15).
        if (!c.set) revert CeilingNotSet(key);
        // The ceiling's value is its version.
        if (c.value != expected) revert StaleVersion(_ceilingScope(key));
        if (value > c.value) {
            if (c.value == 0) revert RaiseFromZero(key);
            if (value > 2 * c.value) revert RaiseTooLarge(key, value, 2 * c.value);
            uint256 next = uint256(c.lastRaise) + RAISE_INTERVAL;
            if (c.lastRaise != 0 && block.timestamp < next) revert RaiseTooSoon(key, next);
        }
        _setCeiling(p, key, value);
    }

    function _restart(Plan memory p) internal view {
        bytes memory enable = abi.encodeWithSelector(ENABLE_MODULE, operatorModifier);
        _call(
            p,
            safetyModifier,
            abi.encodeCall(IRoles.execTransactionWithRole, (assetSafe, 0, enable, 0, RESTART_ROLE, true))
        );
    }

    function _fund(Plan memory p, bytes memory data) internal view {
        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        _protected(token);
        if (amount == 0) revert ZeroAmount();
        bytes memory transfer = abi.encodeWithSelector(TRANSFER, firstLossSafe, amount);
        _call(
            p,
            operatorModifier,
            abi.encodeCall(IRoles.execTransactionWithRole, (token, 0, transfer, 0, INSURANCE_FUNDING, true))
        );
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// @dev An introduction makes two calls, sets two ceilings and claims three scopes, so the
    ///      plan holds room for that many per operation, and one more call for `commit`.
    function _plan(uint256 n) internal pure returns (Plan memory p) {
        p.to = new address[](2 * n + 1);
        p.data = new bytes[](2 * n + 1);
        p.scopes = new bytes32[](n);
        p.versions = new bytes32[](n);
        p.ceilingKeys = new bytes32[](2 * n);
        p.ceilingValues = new uint256[](2 * n);
        p.claimed = new bytes32[](3 * n);
        p.introduced = new address[](n);
        p.introducedBudgetCeilings = new uint256[](n);
    }

    /// @dev A token is introduced once one of its ceilings is set.
    function _introduced(address token) internal view returns (bool) {
        return ceilings[ceilingKey(BUDGET_CEILING, token)].set || ceilings[ceilingKey(APPROVAL_CAP_CEILING, token)].set;
    }

    /// @dev The budget ceiling of a token: the one that this motion's introduction of the token
    ///      sets, or the stored one.
    function _budgetCeiling(Plan memory p, address token) internal view returns (uint256) {
        for (uint256 i = 0; i < p.introductions; i++) {
            if (p.introduced[i] == token) return p.introducedBudgetCeilings[i];
        }
        return ceilings[ceilingKey(BUDGET_CEILING, token)].value;
    }

    function _ceilingScope(bytes32 key) internal pure returns (bytes32) {
        return keccak256(abi.encode("ceiling", key));
    }

    function _setCeiling(Plan memory p, bytes32 key, uint256 value) internal pure {
        _claim(p, _ceilingScope(key));
        p.ceilingKeys[p.ceilings] = key;
        p.ceilingValues[p.ceilings] = value;
        p.ceilings++;
    }

    /// @dev One write of the governance role: a call of the operator modifier on itself, which
    ///      executes as the Asset Safe, the modifier's owner.
    function _govern(Plan memory p, bytes memory write) internal view {
        _call(
            p,
            operatorModifier,
            abi.encodeCall(IRoles.execTransactionWithRole, (operatorModifier, 0, write, 0, GOVERNANCE, true))
        );
    }

    function _call(Plan memory p, address to, bytes memory data) internal pure {
        p.to[p.calls] = to;
        p.data[p.calls] = data;
        p.calls++;
    }

    function _write(Plan memory p, bytes32 scope, bytes32 version) internal pure {
        _claim(p, scope);
        p.scopes[p.writes] = scope;
        p.versions[p.writes] = version;
        p.writes++;
    }

    /// @dev One motion writes each scope at most once.
    function _claim(Plan memory p, bytes32 scope) internal pure {
        for (uint256 i = 0; i < p.claims; i++) if (p.claimed[i] == scope) revert DuplicateScope(scope);
        p.claimed[p.claims++] = scope;
    }

    function _script(Plan memory p, uint256 motionEpoch) internal view returns (bytes memory s) {
        bytes32[] memory scopes = _trim32(p.scopes, p.writes);
        bytes32[] memory vers = _trim32(p.versions, p.writes);
        bytes32[] memory keys = _trim32(p.ceilingKeys, p.ceilings);
        uint256[] memory values = new uint256[](p.ceilings);
        for (uint256 i = 0; i < p.ceilings; i++) values[i] = p.ceilingValues[i];
        _call(p, address(this), abi.encodeCall(this.commit, (motionEpoch, scopes, vers, keys, values)));
        s = abi.encodePacked(bytes4(0x00000001));
        for (uint256 i = 0; i < p.calls; i++) {
            s = bytes.concat(s, abi.encodePacked(p.to[i], uint32(p.data[i].length), p.data[i]));
        }
    }

    function _trim32(bytes32[] memory a, uint256 n) internal pure returns (bytes32[] memory r) {
        r = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) r[i] = a[i];
    }

    function _amount(uint8 parent, Entry memory e) internal pure returns (IRoles.ConditionFlat memory) {
        return e.key != bytes32(0)
            ? IRoles.ConditionFlat(parent, T_STATIC, OP_WITHIN_ALLOWANCE, abi.encode(e.key))
            : IRoles.ConditionFlat(parent, T_STATIC, OP_LESS_THAN, abi.encode(e.cap));
    }

    /// @dev Entries in the canonical form: sorted by spender, each once, each either budgeted
    ///      or capped, and at most MAX_SPENDERS of them.
    function _canonical(Entry[] memory entries) internal pure {
        if (entries.length > MAX_SPENDERS) revert NotCanonical();
        for (uint256 i = 0; i < entries.length; i++) {
            Entry memory e = entries[i];
            if (e.spender == address(0) || (e.key == bytes32(0)) == (e.cap == 0)) revert BadEntry(e.spender);
            if (i > 0 && entries[i - 1].spender >= e.spender) revert NotCanonical();
        }
    }

    /// @dev The vault's own accounts are never a spender or a token of a shape.
    function _protected(address account) internal view {
        if (
            account == address(0) || account == assetSafe || account == operatorModifier || account == safetyModifier
                || account == ordersModifier || account == firstLossModifier || account == firstLossSafe
                || account == address(this)
        ) revert ProtectedAddress(account);
    }

    function _pair(address token, address spender) internal pure returns (bytes32) {
        return keccak256(abi.encode(token, spender));
    }
}
