// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {
    IERC20,
    IStETH,
    IWstETH,
    IWETH,
    IERC4626,
    IDaiUsds,
    IWithdrawalQueue,
    ILidoEarnDepositQueue
} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {MockEasyTrack, PassThroughEVMScriptFactory} from "../src/mocks/MockEasyTrack.sol";

import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";
import {SafeExec, EVMScriptLib} from "../src/policy/SafeExec.sol";

/// @title Drills — the dry-run drill suite, executed against a pinned
///        mainnet fork. D1 governance through the mock Easy Track; D2 the
///        direct DAO path; D3 operator lifecycle; D4 emergency and technical
///        roles; D5 budgets; D6 adversarial cases and the launch scope.
contract Drills is Test {
    uint256 internal constant FORK_BLOCK = 25946643;
    // Safe v1.5.0: EM's choice for the three new Safes (OD-02, OD-17).
    address internal constant SAFE_SINGLETON = 0xFf51A5898e281Db6DfC7855790607438dF2ca44b;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant SAFE_PROXY_FACTORY = 0x14F2982D601c9458F93bd70B218933A6f8165e7b;
    address internal constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;

    // Outside the launch scope (ADR 007, ADR 011). Only the negative drills use them.
    address internal constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    // Safe storage slots: keccak256 of "fallback_manager.handler.address",
    // "guard_manager.guard.address" and "module_manager.module_guard.address".
    bytes32 internal constant FALLBACK_HANDLER_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
    bytes32 internal constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 internal constant MODULE_GUARD_SLOT = 0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947;

    address internal constant SENTINEL = address(0x0000000000000000000000000000000000000001);

    // Errors of the deployed Roles modifier: a refused permission; a member
    // that does not hold the role key; a caller that holds no role there.
    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;
    bytes4 internal constant NO_MEMBERSHIP = 0xfd8e9f28;
    bytes4 internal constant NOT_AUTHORIZED = 0x4a0bfec1;

    MockAragonAgent internal agent;
    MockEVMScriptExecutor internal executor;
    MockEasyTrack internal easyTrack;
    PassThroughEVMScriptFactory internal factory;
    ISafe internal safe;
    IRoles internal roles; // operator + governance
    IRoles internal safety; // emergency + technical

    address internal operatorSafe = makeAddr("operator-safe-standin");
    address internal emergencySafe = makeAddr("emergency-safe-standin");
    address internal whale = makeAddr("ldo-whale"); // objection whale
    address internal attacker = makeAddr("attacker");
    address internal principal;

    Policy.Addresses internal a;

    function setUp() public {
        string memory rpc = vm.envOr("RPC", string("https://ethereum-rpc.publicnode.com"));
        vm.createSelectFork(rpc, FORK_BLOCK);

        principal = makeAddr("executor-eoa");
        vm.startPrank(principal);
        agent = new MockAragonAgent();
        executor = new MockEVMScriptExecutor(agent);
        // NOTE: the executor is deliberately NOT a permitted runner of the
        // mock Agent. At the fork block the real EVMScriptExecutor holds
        // neither RUN_SCRIPT_ROLE nor EXECUTE_ROLE on the Agent (the only
        // holder is the Dual Governance admin executor). Easy Track policy
        // changes therefore run through the governance role below, not
        // through Agent authority.
        easyTrack = new MockEasyTrack(executor, IERC20(LDO), 3 days, 5_000_000e18);
        factory = new PassThroughEVMScriptFactory();
        easyTrack.addEVMScriptFactory(address(factory));

        ISafeProxyFactory proxyFactory = ISafeProxyFactory(SAFE_PROXY_FACTORY);
        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        // no fallback handler (OD-17)
        bytes memory safeInit = abi.encodeCall(
            ISafe.setup,
            (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        safe = ISafe(payable(proxyFactory.createProxyWithNonce(SAFE_SINGLETON, safeInit, uint256(0x22))));
        // canonical deployed factory — production component, not a copy
        bytes memory rolesInit =
            abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe))));
        roles = IRoles(
            IModuleProxyFactory(MODULE_PROXY_FACTORY).deployModule(
                ROLES_MASTERCOPY, rolesInit, uint256(0x11d0)
            )
        );
        safety = IRoles(
            IModuleProxyFactory(MODULE_PROXY_FACTORY).deployModule(
                ROLES_MASTERCOPY, rolesInit, uint256(0x11d1)
            )
        );

        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))
        );
        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(safety)))
        );

        Policy.Addresses memory m;
        m.safe = address(safe);
        m.agent = address(agent);
        m.operator = operatorSafe;
        m.emergency = emergencySafe;
        m.technical = makeAddr("emergency-brakes-standin");
        m.policyAdmin = address(executor);
        m.rolesOperator = address(roles);
        m.rolesSafety = address(safety);
        Policy.fillTokens(m);
        Policy.fillProtocols(m);
        a = m;

        Policy.Call[] memory ops = FullPolicy.buildOperator(m, address(roles));
        for (uint256 i = 0; i < ops.length; i++) {
            SafeExec.execAsOwner(agent, safe, ops[i].to, ops[i].data);
        }
        Policy.Call[] memory saf = FullPolicy.buildSafety(m, address(safety), address(roles));
        for (uint256 i = 0; i < saf.length; i++) {
            SafeExec.execAsOwner(agent, safe, saf[i].to, saf[i].data);
        }
        vm.stopPrank();

        // objection whale with > threshold LDO (simulated holder). LDO is an
        // Aragon MiniMe token whose storage forge cannot manipulate safely;
        // the mock ET only reads balanceOf, so mock that view for the whale.
        vm.mockCall(
            LDO,
            abi.encodeWithSelector(IERC20.balanceOf.selector, whale),
            abi.encode(6_000_000e18)
        );
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function _op(address to, bytes memory data) internal {
        _opValue(to, 0, data);
    }

    function _opValue(address to, uint256 value, bytes memory data) internal {
        vm.prank(operatorSafe);
        (bool ok, bytes memory ret) = address(roles).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole, (to, value, data, 0, Policy.OPERATOR(), true)
            )
        );
        if (!ok) {
            if (ret.length >= 4 && bytes4(ret) == CONDITION_VIOLATION) {
                (uint8 st, bytes32 info) = abi.decode(_slice4(ret), (uint8, bytes32));
                revert(string(abi.encodePacked("ConditionViolation status=", vm.toString(st), " info=", vm.toString(uint256(info)))));
            }
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function _slice4(bytes memory d) internal pure returns (bytes memory) {
        bytes memory o = new bytes(d.length - 4);
        for (uint256 i = 4; i < d.length; i++) o[i - 4] = d[i];
        return o;
    }

    function _opRevert(address to, bytes memory data) internal {
        _opValueRevert(to, 0, data);
    }

    /// @dev The modifier itself must refuse the call. A revert inside the
    ///      protocol would not show that the permission binds.
    function _opValueRevert(address to, uint256 value, bytes memory data) internal {
        vm.prank(operatorSafe);
        (bool ok, bytes memory ret) = address(roles).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole, (to, value, data, 0, Policy.OPERATOR(), true)
            )
        );
        assertFalse(ok, "the operator call must be refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the modifier, not the protocol, must refuse it");
    }

    function _em(address to, bytes memory data) internal {
        _emValue(to, 0, data);
    }

    function _emValue(address to, uint256 value, bytes memory data) internal {
        vm.prank(emergencySafe);
        bool ok = safety.execTransactionWithRole(to, value, data, 0, Policy.EMERGENCY(), true);
        assertTrue(ok, "emergency call failed");
    }

    function _emRevert(address to, bytes memory data) internal {
        _emValueRevert(to, 0, data);
    }

    function _emValueRevert(address to, uint256 value, bytes memory data) internal {
        vm.prank(emergencySafe);
        (bool ok, bytes memory ret) = address(safety).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole, (to, value, data, 0, Policy.EMERGENCY(), true)
            )
        );
        assertFalse(ok, "the emergency call must be refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the modifier, not the protocol, must refuse it");
    }

    function _approve(address spender, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(IERC20.approve, (spender, amount));
    }

    // ------------------------------------------------------------------
    // D1: the four kinds of permission change through the mock Easy Track
    // motion path. Motions act as the governance role on the modifier; the
    // script executor holds no Agent authority, as at the fork block.
    // ------------------------------------------------------------------
    function _rc(bytes memory data) internal view returns (Policy.Call memory) {
        return Policy.Call({to: address(roles), data: data});
    }

    function _motionEnact(Policy.Call[] memory calls) internal {
        bytes memory script = EVMScriptLib.buildAsPolicyAdmin(roles, calls);
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), script);
        vm.warp(block.timestamp + 3 days + 1);
        easyTrack.enactMotion(id, script);
    }

    function test_D1_change_type_1_asset() public {
        // Add a spender: a full replacement scope for wstETH approvals keeps
        // the earnETH queue under its key and adds a new spender with a
        // fixed ceiling. The replacement must not drop or widen anything
        // else; the negative checks assert that.
        address newSpender = address(0xdEaD);
        Policy.Call[] memory calls = new Policy.Call[](1);
        calls[0] = Policy._opApprove(
            address(roles),
            a.wsteth,
            FullPolicy._spenders(
                Policy.keyed(a.earnEthDepositQueue, Policy.K_EARN_ETH),
                Policy.capped(newSpender, 10 ether)
            )
        );
        _motionEnact(calls);

        // the new spender works, and the old one still works
        _op(a.wsteth, _approve(newSpender, 1 ether));
        _op(a.wsteth, _approve(a.earnEthDepositQueue, 0.5 ether));
        // nothing else widened: the ceiling binds and an unlisted spender is denied
        _opRevert(a.wsteth, _approve(newSpender, 10 ether));
        _opRevert(a.wsteth, _approve(attacker, 1));
    }

    function test_D1_change_type_2_target() public {
        // Add a protocol target: grant the operator a function on a fresh
        // target; remove it again with revokeTarget and prove removal.
        address newTarget = address(0xBEEF);
        Policy.Call[] memory add = new Policy.Call[](2);
        add[0] = _rc(abi.encodeCall(IRoles.scopeTarget, (Policy.OPERATOR(), newTarget)));
        add[1] = _rc(
            abi.encodeCall(
                IRoles.allowFunction, (Policy.OPERATOR(), newTarget, IERC20.approve.selector, 0)
            )
        );
        _motionEnact(add);

        Policy.Call[] memory remove = new Policy.Call[](1);
        remove[0] = _rc(abi.encodeCall(IRoles.revokeTarget, (Policy.OPERATOR(), newTarget)));
        _motionEnact(remove);

        // removal cannot have widened anything else: the operator's wstETH
        // spender still works and only that one
        _op(a.wsteth, _approve(a.earnEthDepositQueue, 0.5 ether));
        _opRevert(a.wsteth, _approve(attacker, 1));
    }

    function test_D1_change_type_3_selector() public {
        // Add a function selector on an existing target, then remove it with
        // revokeFunction.
        Policy.Call[] memory add = new Policy.Call[](1);
        add[0] = _rc(
            abi.encodeCall(
                IRoles.allowFunction, (Policy.OPERATOR(), a.wsteth, IERC20.symbol.selector, 0)
            )
        );
        _motionEnact(add);
        _op(a.wsteth, abi.encodeCall(IERC20.symbol, ()));

        Policy.Call[] memory remove = new Policy.Call[](1);
        remove[0] = _rc(
            abi.encodeCall(
                IRoles.revokeFunction, (Policy.OPERATOR(), a.wsteth, IERC20.symbol.selector)
            )
        );
        _motionEnact(remove);
        _opRevert(a.wsteth, abi.encodeCall(IERC20.symbol, ()));
    }

    function test_D1_change_type_4_parameter_constraint() public {
        // Change a bound inside an allowed function: tighten the sUSDS budget
        // and prove that the old bound no longer admits the previous amount.
        Policy.Call[] memory tighten = new Policy.Call[](1);
        tighten[0] = _rc(
            abi.encodeCall(
                IRoles.setAllowance,
                (Policy.K_SUSDS, 100e18, 100e18, 100e18, 30 days, uint64(0))
            )
        );
        _motionEnact(tighten);
        // 90e18 fits the tightened budget; another 150e18 exceeds it
        _op(a.usds, _approve(a.susds, 90e18));
        _opRevert(a.usds, _approve(a.susds, 150e18));
    }

    /// @dev OD-08: a budget motion cannot set a refill period below 30 days.
    function test_D1_budget_motion_cannot_shorten_the_refill_period() public {
        Policy.Call[] memory calls = new Policy.Call[](1);
        calls[0] = _rc(
            abi.encodeCall(
                IRoles.setAllowance,
                (Policy.K_SUSDS, 100e18, 100e18, 100e18, 30 days - 1, uint64(0))
            )
        );
        bytes memory script = EVMScriptLib.buildAsPolicyAdmin(roles, calls);
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), script);
        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert();
        easyTrack.enactMotion(id, script);
    }

    function test_D1_objection_rejection() public {
        Policy.Call[] memory calls = new Policy.Call[](1);
        calls[0] = _rc(
            abi.encodeCall(
                IRoles.allowFunction, (Policy.OPERATOR(), a.wsteth, IWstETH.wrap.selector, 0)
            )
        );
        bytes memory script = EVMScriptLib.buildAsPolicyAdmin(roles, calls);
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), script);
        vm.prank(whale);
        easyTrack.object(id);
        (,,,,,,, uint256 status) = _motion(id);
        assertEq(uint256(status), 1, "motion should be rejected");
        vm.expectRevert();
        easyTrack.enactMotion(id, script);
    }

    /// @dev Governance-encoding parity. Builds a CallsScript in the exact
    ///      production wire format of EVMScriptCreator @ 3183d1f6 —
    ///      [spec(4)][to(20)][uint32 len][calldata], len covering selector and
    ///      args — and drives it through the mock executor. A harness with a
    ///      32-byte length field would only prove that the mock agrees with
    ///      itself.
    function test_D1_production_callscript_encoding_accepted() public {
        vm.prank(principal);
        agent.permitRunner(address(executor));
        bytes memory inner = abi.encodeCall(MockAragonAgent.canForward, (address(executor), ""));
        bytes memory innerScript = _callsScript(address(agent), inner);
        bytes memory outer = abi.encodeCall(MockAragonAgent.forward, (innerScript));
        bytes memory blob = _callsScript(address(agent), outer);

        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), blob);
        vm.warp(block.timestamp + 3 days + 1);
        easyTrack.enactMotion(id, blob);
    }

    /// @dev A 32-byte length field is not the production format. Production
    ///      never emits it and the executor must reject it.
    function test_D1_nonstandard_length_encoding_rejected() public {
        bytes memory inner = abi.encodeCall(MockAragonAgent.canForward, (address(executor), ""));
        bytes memory bad = abi.encodePacked(
            bytes4(0x00000001), bytes20(address(agent)), bytes32(inner.length), inner
        );
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), bad);
        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert();
        easyTrack.enactMotion(id, bad);
    }

    /// @dev A truncated length must not read past the script.
    function test_D1_malformed_length_rejected() public {
        bytes memory inner = abi.encodeCall(MockAragonAgent.canForward, (address(executor), ""));
        bytes memory bad = abi.encodePacked(
            bytes4(0x00000001), bytes20(address(agent)), uint32(inner.length + 64), inner
        );
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), bad);
        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert();
        easyTrack.enactMotion(id, bad);
    }

    /// @dev Several calls in one script, the normal factory output shape.
    function test_D1_multi_call_script_executes_in_order() public {
        address dummyA = address(0xdEaD);
        address dummyB = address(0xbEEF);
        Policy.Call[] memory calls = new Policy.Call[](2);
        calls[0] = Policy._opApprove(
            address(roles), a.wsteth, FullPolicy._spenders(Policy.capped(dummyA, type(uint256).max))
        );
        calls[1] = Policy._opApprove(
            address(roles), a.steth, FullPolicy._spenders(Policy.capped(dummyB, type(uint256).max))
        );
        bytes memory script = EVMScriptLib.buildAsPolicyAdmin(roles, calls);
        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), script);
        vm.warp(block.timestamp + 3 days + 1);
        easyTrack.enactMotion(id, script);
        _op(a.wsteth, _approve(dummyA, 1 ether));
        _op(a.steth, _approve(dummyB, 1 ether));
        assertEq(IERC20(a.wsteth).allowance(address(safe), dummyA), 1 ether);
    }

    /// @dev Stale-script rejection. Production regenerates the script from
    ///      the re-supplied factory call data and compares it with the hash
    ///      recorded at creation, so a substituted script cannot enact.
    function test_D1_substituted_script_rejected_at_enactment() public {
        Policy.Call[] memory good = new Policy.Call[](1);
        good[0] = Policy._opApprove(
            address(roles), a.wsteth, FullPolicy._spenders(Policy.capped(address(0xdEaD), type(uint256).max))
        );
        bytes memory goodScript = EVMScriptLib.buildAsPolicyAdmin(roles, good);

        Policy.Call[] memory evil = new Policy.Call[](1);
        evil[0] = Policy._opApprove(
            address(roles), a.wsteth, FullPolicy._spenders(Policy.capped(attacker, type(uint256).max))
        );
        bytes memory evilScript = EVMScriptLib.buildAsPolicyAdmin(roles, evil);

        vm.prank(operatorSafe);
        uint256 id = easyTrack.createMotion(address(factory), goodScript);
        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert(bytes("ET: unexpected evm script"));
        easyTrack.enactMotion(id, evilScript);
        easyTrack.enactMotion(id, goodScript);
    }

    function _callsScript(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000001), bytes20(to), uint32(data.length), data);
    }

    function _motion(uint256 id)
        internal
        view
        returns (
            address creator,
            address f,
            bytes memory cd,
            bytes32 scriptHash,
            uint256 startDate,
            uint256 snapshot,
            uint256 objections,
            uint256 status
        )
    {
        MockEasyTrack.Motion memory m = easyTrack.getMotion(id);
        return (
            m.creator,
            m.evmScriptFactory,
            m.evmScriptCallData,
            m.evmScriptHash,
            m.startDate,
            m.snapshotDate,
            m.objectionsAmount,
            uint8(m.status)
        );
    }

    function test_D2_direct_DAO_path() public {
        // the same change applied directly by the owner, no Easy Track.
        // NOTE: this drill intentionally replaces a scoped approve with an
        // unscoped allowFunction. It shows that a function has one scope and
        // the last write wins. Owner actions must emit full replacement
        // scopes, exactly like the Easy Track factories.
        vm.startPrank(principal);
        SafeExec.execAsOwner(
            agent,
            safe,
            address(roles),
            abi.encodeCall(
                IRoles.allowFunction,
                (Policy.OPERATOR(), a.wsteth, IERC20.approve.selector, 0)
            )
        );
        vm.stopPrank();
        // now unconstrained approve on wstETH works for the operator
        _op(a.wsteth, _approve(address(0xbee5), 5));
        assertEq(IERC20(a.wsteth).allowance(address(safe), address(0xbee5)), 5);
    }

    // ------------------------------------------------------------------
    // D3: operator lifecycle on real mainnet contracts
    // ------------------------------------------------------------------
    function test_D3_operator_lifecycle() public {
        // sUSDS: the approval spends its key; deposit to the avatar, redeem back
        deal(a.usds, address(safe), 1_000e18);
        _op(a.usds, _approve(a.susds, 400e18));
        _op(a.susds, abi.encodeCall(IERC4626.deposit, (400e18, address(safe))));
        uint256 shares = IERC20(a.susds).balanceOf(address(safe));
        assertGt(shares, 0, "no sUSDS");
        _op(a.susds, abi.encodeCall(IERC4626.redeem, (shares, address(safe), address(safe))));
        assertEq(IERC20(a.susds).balanceOf(address(safe)), 0);

        // staking: ETH -> stETH, minted to the Asset Safe (OD-20)
        vm.deal(address(safe), 2 ether);
        _opValue(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));
        uint256 st = IERC20(a.steth).balanceOf(address(safe));
        assertApproxEqAbs(st, 1 ether, 2, "staking must mint stETH to the Asset Safe");

        // stETH -> wstETH under the fixed ceiling, and back
        _op(a.steth, _approve(a.wsteth, st));
        _op(a.wsteth, abi.encodeCall(IWstETH.wrap, (st)));
        uint256 w = IERC20(a.wsteth).balanceOf(address(safe));
        assertGt(w, 0, "no wstETH");
        _op(a.wsteth, abi.encodeCall(IWstETH.unwrap, (w)));
        assertGt(IERC20(a.steth).balanceOf(address(safe)), 0);

        // WETH: wrap the remaining ETH and unwrap it again
        _opValue(a.weth, 1 ether, abi.encodeCall(IWETH.deposit, ()));
        assertEq(IERC20(a.weth).balanceOf(address(safe)), 1 ether);
        _op(a.weth, abi.encodeCall(IWETH.withdraw, (1 ether)));
        assertEq(IERC20(a.weth).balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether, "WETH must pay the Asset Safe");
    }

    /// @dev OD-22: DAI earns through Sky's DAI–USDS converter, one to one,
    ///      with the receiver pinned to the Asset Safe and a fixed ceiling on
    ///      both approvals (ADR 011, owed fork tests).
    function test_D3_dai_usds_conversion_pays_the_asset_safe() public {
        deal(a.dai, address(safe), 1_000e18);
        _op(a.dai, _approve(a.daiUsds, 600e18));
        _op(a.daiUsds, abi.encodeCall(IDaiUsds.daiToUsds, (address(safe), 600e18)));
        assertEq(IERC20(a.usds).balanceOf(address(safe)), 600e18, "one to one, to the Asset Safe");
        assertEq(IERC20(a.dai).balanceOf(address(safe)), 400e18);

        _op(a.usds, _approve(a.daiUsds, 200e18));
        _op(a.daiUsds, abi.encodeCall(IDaiUsds.usdsToDai, (address(safe), 200e18)));
        assertEq(IERC20(a.dai).balanceOf(address(safe)), 600e18);
        assertEq(IERC20(a.usds).balanceOf(address(safe)), 400e18);

        // any other receiver is refused, in both directions
        _opRevert(a.daiUsds, abi.encodeCall(IDaiUsds.daiToUsds, (attacker, 1e18)));
        _opRevert(a.daiUsds, abi.encodeCall(IDaiUsds.usdsToDai, (attacker, 1e18)));

        // an approval at or above the ceiling is refused; below it, and zero, pass
        _opRevert(a.dai, _approve(a.daiUsds, FullPolicy.FLOOR_STANDIN_USD));
        _opRevert(a.usds, _approve(a.daiUsds, FullPolicy.FLOOR_STANDIN_USD));
        _op(a.dai, _approve(a.daiUsds, FullPolicy.FLOOR_STANDIN_USD - 1));
        _op(a.dai, _approve(a.daiUsds, 0));
    }

    /// @dev OD-20: WETH is bought through the withdrawal queue. The request's
    ///      owner is pinned to the Asset Safe, the claim pays it, and the vault
    ///      wraps the ETH (ADR 007, owed fork tests). The oracle report that
    ///      finalizes requests is simulated: the Lido contract, which holds
    ///      the queue's FINALIZE_ROLE at the fork block, finalizes every
    ///      pending request at the current share rate.
    function test_D3_withdrawal_queue_round_trip_buys_weth() public {
        vm.deal(address(safe), 1 ether);
        _opValue(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));

        uint256 amount = 0.5 ether;
        _op(a.steth, _approve(a.withdrawalQueue, amount));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        _opRevert(a.withdrawalQueue, abi.encodeCall(IWithdrawalQueue.requestWithdrawals, (amounts, attacker)));
        _op(a.withdrawalQueue, abi.encodeCall(IWithdrawalQueue.requestWithdrawals, (amounts, address(safe))));
        IWithdrawalQueue wq = IWithdrawalQueue(a.withdrawalQueue);
        uint256 id = wq.getLastRequestId();
        assertEq(wq.ownerOf(id), address(safe), "the Asset Safe owns the request");

        uint256 eth = wq.unfinalizedStETH();
        uint256 shareRate = IStETH(a.steth).getPooledEthByShares(1e27);
        vm.deal(a.steth, a.steth.balance + eth);
        vm.prank(a.steth);
        wq.finalize{value: eth}(id, shareRate);

        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256[] memory hints = wq.findCheckpointHints(ids, 1, wq.getLastCheckpointIndex());
        uint256 before = address(safe).balance;
        _op(a.withdrawalQueue, abi.encodeCall(IWithdrawalQueue.claimWithdrawals, (ids, hints)));
        uint256 claimed = address(safe).balance - before;
        assertApproxEqAbs(claimed, amount, 2, "the claim must pay the Asset Safe");

        _opValue(a.weth, claimed, abi.encodeCall(IWETH.deposit, ()));
        assertEq(IERC20(a.weth).balanceOf(address(safe)), claimed);
    }

    function test_D3_operator_cannot_route_around_avatar() public {
        deal(a.usds, address(safe), 1_000e18);
        _op(a.usds, _approve(a.susds, 100e18));
        // a deposit, redeem or withdraw that pays anyone but the avatar is refused
        _opRevert(a.susds, abi.encodeCall(IERC4626.deposit, (100e18, attacker)));
        _op(a.susds, abi.encodeCall(IERC4626.deposit, (100e18, address(safe))));
        uint256 shares = IERC20(a.susds).balanceOf(address(safe));
        _opRevert(a.susds, abi.encodeCall(IERC4626.redeem, (shares, attacker, address(safe))));
        _opRevert(a.susds, abi.encodeCall(IERC4626.withdraw, (1e18, attacker, address(safe))));
        // conversions, withdrawal requests and Earn claims pay only the avatar
        _opRevert(a.daiUsds, abi.encodeCall(IDaiUsds.daiToUsds, (attacker, 1e18)));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e17;
        _opRevert(a.withdrawalQueue, abi.encodeCall(IWithdrawalQueue.requestWithdrawals, (amounts, attacker)));
        _opRevert(a.earnUsdDepositQueue, abi.encodeCall(ILidoEarnDepositQueue.claim, (attacker)));
        // staking takes no referral
        vm.deal(address(safe), 1 ether);
        _opValueRevert(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (attacker)));
        // plain transfers, of a token or of ETH, are not in the permission set at all
        _opRevert(a.usdc, abi.encodeCall(IERC20.transfer, (attacker, 1e6)));
        _opRevert(a.weth, abi.encodeCall(IERC20.transfer, (attacker, 1)));
        _opValueRevert(attacker, 1 ether, "");
    }

    /// @dev Earn deposits. The approval to the queue spends the earnUSD key,
    ///      so the deposit call carries no budget (OD-08). The queue itself
    ///      may still refuse a deposit for protocol reasons (allowlist, queue
    ///      state); that is outside the policy by design.
    function test_D3b_earn_deposit_policy_layer() public {
        deal(a.usdc, address(safe), 1_000e6);
        // an approval beyond the key is refused at the Roles layer
        _opRevert(a.usdc, _approve(a.earnUsdDepositQueue, 600e6));
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 400e6));
        bytes32[] memory noProof = new bytes32[](0);
        vm.prank(operatorSafe);
        (bool authorized,) = address(roles).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole,
                (
                    a.earnUsdDepositQueue,
                    0,
                    abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(400e6), address(0), noProof)),
                    0,
                    Policy.OPERATOR(),
                    false
                )
            )
        );
        // authorized=false only if the ROLES layer rejected the shape
        assertTrue(authorized, "Roles layer rejected a policy-conformant earn deposit");
    }

    // ------------------------------------------------------------------
    // D4: emergency drill
    // ------------------------------------------------------------------
    function test_D4_emergency_flow() public {
        deal(a.usds, address(safe), 500e18);
        _op(a.usds, _approve(a.susds, 500e18));
        _op(a.susds, abi.encodeCall(IERC4626.deposit, (200e18, address(safe))));

        // 1. block the operator: revokeTarget on sUSDS (roleKey pinned)
        _em(address(roles), abi.encodeCall(IRoles.revokeTarget, (Policy.OPERATOR(), a.susds)));
        _opRevert(a.susds, abi.encodeCall(IERC4626.deposit, (100e18, address(safe))));

        // 2. zero the standing approval
        _em(a.usds, _approve(a.susds, 0));
        assertEq(IERC20(a.usds).allowance(address(safe), a.susds), 0);

        // 3. exit the position to the avatar
        uint256 shares = IERC20(a.susds).balanceOf(address(safe));
        _em(a.susds, abi.encodeCall(IERC4626.redeem, (shares, address(safe), address(safe))));
        assertEq(IERC20(a.susds).balanceOf(address(safe)), 0);

        // 4. return to treasury: transfer pinned to the Agent literal
        uint256 bal = IERC20(a.usds).balanceOf(address(safe));
        _em(a.usds, abi.encodeCall(IERC20.transfer, (address(agent), bal)));
        assertEq(IERC20(a.usds).balanceOf(address(agent)), bal);
        // any other destination is denied
        _emRevert(a.usds, abi.encodeCall(IERC20.transfer, (attacker, 1)));
    }

    /// @dev OD-20: in an emergency, WETH goes through stETH. The emergency
    ///      role unwraps WETH, stakes the ETH and sends the stETH to the
    ///      Agent. WETH pays out with a transfer that forwards only 2,300 gas,
    ///      so the drill also shows that the Asset Safe accepts it.
    function test_D4_emergency_weth_route_to_agent() public {
        vm.deal(address(safe), 2 ether);
        _opValue(a.weth, 2 ether, abi.encodeCall(IWETH.deposit, ()));

        _em(a.weth, abi.encodeCall(IWETH.withdraw, (1 ether)));
        assertEq(address(safe).balance, 1 ether, "WETH's 2,300-gas transfer must reach the Asset Safe");
        _emValue(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));
        uint256 st = IERC20(a.steth).balanceOf(address(safe));
        _em(a.steth, abi.encodeCall(IERC20.transfer, (address(agent), st)));
        assertApproxEqAbs(IERC20(a.steth).balanceOf(address(agent)), 1 ether, 3);

        // WETH can also go to the Agent as it is
        _em(a.weth, abi.encodeCall(IERC20.transfer, (address(agent), 1 ether)));
        assertEq(IERC20(a.weth).balanceOf(address(agent)), 1 ether);

        // the emergency role's staking takes no referral either
        vm.deal(address(safe), 1 ether);
        _emValueRevert(a.steth, 1 ether, abi.encodeCall(IStETH.submit, (attacker)));
    }

    function _tech(address to, bytes memory data) internal returns (bool ok) {
        vm.prank(a.technical);
        (ok,) = address(safety).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (to, 0, data, 0, Policy.TECHNICAL(), true)));
    }

    /// @dev With two modules enabled the linked-list predecessor is no longer
    ///      the sentinel, so it must be resolved from the Safe.
    function _prevModule(address module) internal view returns (address) {
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        address prev = SENTINEL;
        for (uint256 i = 0; i < mods.length; i++) {
            if (mods[i] == module) return prev;
            prev = mods[i];
        }
        revert("module not enabled");
    }

    /// @dev Module disabling answers a defect in the permission layer, so it
    ///      sits with the technical role, not the financial one, and the
    ///      module argument is pinned.
    function test_D4_module_disabling_is_technical_only_and_pinned() public {
        // the financial emergency role does not hold it
        _emRevert(address(safe), abi.encodeCall(ISafe.disableModule, (_prevModule(address(roles)), address(roles))));
        // nor does the operator
        _opRevert(address(safe), abi.encodeCall(ISafe.disableModule, (_prevModule(address(roles)), address(roles))));
        // the technical role cannot point it at some other module
        assertFalse(
            _tech(address(safe), abi.encodeCall(ISafe.disableModule, (SENTINEL, address(0xdEaD)))),
            "module argument must be pinned to the operator modifier"
        );
        // it can disable this modifier
        assertTrue(
            _tech(address(safe), abi.encodeCall(ISafe.disableModule, (_prevModule(address(roles)), address(roles)))),
            "technical role must be able to disable the operator modifier"
        );
        assertFalse(safe.isModuleEnabled(address(roles)), "operator modifier should be off");
        // the operator is dead: the Safe refuses a disabled module
        vm.prank(operatorSafe);
        vm.expectRevert(bytes("GS104"));
        roles.execTransactionWithRole(a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, Policy.OPERATOR(), true);
        // but recovery survives, which is the point of the split
        assertTrue(safe.isModuleEnabled(address(safety)), "safety modifier must stay enabled");
        deal(a.usdc, address(safe), 10e6);
        _em(a.usdc, abi.encodeCall(IERC20.transfer, (address(agent), 1e6)));
        // it cannot switch off the safety modifier either: the pin is exact
        assertFalse(
            _tech(address(safe), abi.encodeCall(ISafe.disableModule, (SENTINEL, address(safety)))),
            "the safety modifier must not be disablable through this role"
        );
        // and the owner path restores it
        vm.startPrank(principal);
        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))
        );
        vm.stopPrank();
        assertTrue(safe.isModuleEnabled(address(roles)));
    }

    // ------------------------------------------------------------------
    // D5: budgets. An approval spends the key of its spender; zero spends
    // nothing; deposits spend nothing (OD-08).
    // ------------------------------------------------------------------
    function test_D5_budget_enforcement_and_refill() public {
        // the earnUSD key holds 500 USDC at dry-run scale
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 300e6));
        // a second approval spends again: 300 more exceeds the remaining 200
        _opRevert(a.usdc, _approve(a.earnUsdDepositQueue, 300e6));
        // zero is always allowed and spends nothing
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 0));
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 200e6));
        _opRevert(a.usdc, _approve(a.earnUsdDepositQueue, 1));
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 0));
        // keys of other spenders are independent
        _op(a.usds, _approve(a.susds, 1_000e18));
        _op(a.wsteth, _approve(a.earnEthDepositQueue, 1e18));
        // refill after one period restores the key
        vm.warp(block.timestamp + 30 days + 1);
        (uint128 refill, uint128 maxRefill, uint64 period,,) = roles.allowances(Policy.K_EARN_USD);
        assertEq(uint256(refill), 500e6);
        assertEq(uint256(maxRefill), 500e6);
        assertEq(uint256(period), 30 days);
        _op(a.usdc, _approve(a.earnUsdDepositQueue, 450e6));
    }

    // ------------------------------------------------------------------
    // D6: adversarial
    // ------------------------------------------------------------------
    function test_D6_adversarial() public {
        // operator cannot reach Roles admin surface
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = Policy.OPERATOR();
        bool[] memory member = new bool[](1);
        member[0] = true;
        _opRevert(
            address(roles), abi.encodeCall(IRoles.assignRoles, (attacker, keys, member))
        );
        _opRevert(
            address(roles),
            abi.encodeCall(IRoles.allowTarget, (Policy.OPERATOR(), attacker, 0))
        );
        // operator cannot disable the Safe's modules
        _opRevert(
            address(safe), abi.encodeCall(ISafe.disableModule, (SENTINEL, address(roles)))
        );
        // emergency cannot widen: allowTarget on its own role is not granted
        _emRevert(
            address(roles),
            abi.encodeCall(IRoles.allowTarget, (Policy.EMERGENCY(), attacker, 0))
        );
        // emergency cannot grant itself roles
        _emRevert(
            address(roles), abi.encodeCall(IRoles.assignRoles, (attacker, keys, member))
        );
        // emergency revokeTarget is pinned: cannot touch its own role
        _emRevert(
            address(roles), abi.encodeCall(IRoles.revokeTarget, (Policy.EMERGENCY(), a.usdc))
        );
        // a random address cannot execute as either role
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(NOT_AUTHORIZED, attacker));
        roles.execTransactionWithRole(
            a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, Policy.OPERATOR(), true
        );
        // an unlisted spender is refused for every approvable token
        _opRevert(a.usdc, _approve(attacker, 1));
        _opRevert(a.usds, _approve(attacker, 1));
        _opRevert(a.steth, _approve(attacker, 1));
    }

    /// @dev INV-018: the operator holds only the operator key, and only on
    ///      the operator modifier.
    function test_D6_operator_holds_only_the_operator_key() public {
        bytes memory zero = _approve(a.earnUsdDepositQueue, 0);
        bytes32[3] memory foreign = [Policy.EMERGENCY(), Policy.TECHNICAL(), Policy.POLICY_ADMIN()];
        for (uint256 i = 0; i < foreign.length; i++) {
            _assertRefusedAsNonMember(roles, foreign[i], zero, NO_MEMBERSHIP);
            _assertRefusedAsNonMember(safety, foreign[i], zero, NOT_AUTHORIZED);
        }
        _assertRefusedAsNonMember(safety, Policy.OPERATOR(), zero, NOT_AUTHORIZED);
        _op(a.usdc, zero);
    }

    function _assertRefusedAsNonMember(IRoles modifier_, bytes32 key, bytes memory data, bytes4 expected)
        internal
    {
        vm.prank(operatorSafe);
        (bool ok, bytes memory ret) = address(modifier_).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (a.usdc, 0, data, 0, key, true))
        );
        assertFalse(ok, "the operator must not hold this key");
        assertEq(bytes4(ret), expected, "the refusal must be for membership");
    }

    /// @dev INV-013 and INV-015: the operator cannot pre-sign a CoW order,
    ///      approve the CoW relayer, or reach Aave or sDAI.
    function test_D6_out_of_scope_venues_are_refused() public {
        deal(a.usdc, address(safe), 1_000e6);
        deal(a.dai, address(safe), 1_000e18);
        bytes memory uid = abi.encodePacked(
            keccak256("operator order"), bytes20(address(safe)), bytes4(uint32(block.timestamp + 3600))
        );
        _opRevert(COW_SETTLEMENT, abi.encodeWithSignature("setPreSignature(bytes,bool)", uid, true));
        _opRevert(a.usdc, _approve(COW_VAULT_RELAYER, 1e6));
        _opRevert(a.steth, _approve(COW_VAULT_RELAYER, 1e18));
        _opRevert(a.ldo, _approve(COW_VAULT_RELAYER, 1e18));
        _opRevert(a.usdc, _approve(AAVE_V3_POOL, 1e6));
        _opRevert(
            AAVE_V3_POOL,
            abi.encodeWithSignature("supply(address,uint256,address,uint16)", a.usdc, 1e6, address(safe), uint16(0))
        );
        _opRevert(a.dai, _approve(SDAI, 1e18));
        _opRevert(SDAI, abi.encodeWithSignature("deposit(uint256,address)", 1e18, address(safe)));
    }

    /// @dev INV-001 and INV-019 at deployment: the Agent is the only owner,
    ///      with threshold one; the Safe runs the pinned v1.5.0 singleton; it
    ///      has no fallback handler, no transaction guard and no module guard
    ///      (OD-17); it owns both modifiers, and they are its only modules.
    function test_asset_safe_shape() public view {
        address[] memory owners = safe.getOwners();
        assertEq(owners.length, 1, "one owner");
        assertEq(owners[0], address(agent), "the Agent is the owner");
        assertEq(safe.getThreshold(), 1, "threshold one");
        assertEq(
            address(uint160(uint256(vm.load(address(safe), bytes32(0))))), SAFE_SINGLETON, "pinned singleton"
        );
        assertEq(vm.load(address(safe), FALLBACK_HANDLER_SLOT), bytes32(0), "no fallback handler");
        assertEq(vm.load(address(safe), GUARD_SLOT), bytes32(0), "no transaction guard");
        assertEq(vm.load(address(safe), MODULE_GUARD_SLOT), bytes32(0), "no module guard");
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 2, "two modules");
        assertTrue(safe.isModuleEnabled(address(roles)));
        assertTrue(safe.isModuleEnabled(address(safety)));
        assertEq(roles.owner(), address(safe), "the Safe owns the operator modifier");
        assertEq(roles.avatar(), address(safe));
        assertEq(roles.target(), address(safe));
        assertEq(safety.owner(), address(safe), "the Safe owns the safety modifier");
        assertEq(safety.avatar(), address(safe));
        assertEq(safety.target(), address(safe));
    }

    receive() external payable {}
}
