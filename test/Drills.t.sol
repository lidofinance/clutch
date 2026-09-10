// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IStETH, IWstETH, ISDAI, IAaveV3Pool, ILidoEarnDepositQueue, ICowSettlement} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {MockEasyTrack, PassThroughEVMScriptFactory} from "../src/mocks/MockEasyTrack.sol";
import {ModuleProxyFactory} from "../src/mocks/ModuleProxyFactory.sol";
import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";
import {SafeExec, EVMScriptLib} from "../src/policy/SafeExec.sol";

/// @title Drills — the WS-M dry-run drill suite, executed against a pinned
///        mainnet fork. D1 expansion via mock ET; D2 direct DAO path; D3
///        operator lifecycle; D4 emergency; D5 budgets; D6 adversarial.
contract Drills is Test {
    uint256 internal constant FORK_BLOCK = 25946643; // WS-B pin
    address internal constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant SAFE_PROXY_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;

    address internal constant SENTINEL = address(0x0000000000000000000000000000000000000001);

    MockAragonAgent internal agent;
    MockEVMScriptExecutor internal executor;
    MockEasyTrack internal easyTrack;
    PassThroughEVMScriptFactory internal factory;
    ISafe internal safe;
    IRoles internal roles;

    address internal tmc = makeAddr("tmc-standin"); // operator stand-in
    address internal eb = makeAddr("eb-standin"); // emergency stand-in
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
        agent.permitRunner(address(executor));
        easyTrack = new MockEasyTrack(executor, IERC20(LDO), 3 days, 5_000_000e18);
        factory = new PassThroughEVMScriptFactory();
        easyTrack.addEVMScriptFactory(address(factory));

        ISafeProxyFactory proxyFactory = ISafeProxyFactory(SAFE_PROXY_FACTORY);
        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        bytes memory safeInit = abi.encodeCall(
            ISafe.setup,
            (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        safe = ISafe(payable(proxyFactory.createProxyWithNonce(SAFE_SINGLETON, safeInit, uint256(0x22))));
        ModuleProxyFactory moduleProxyFactory = new ModuleProxyFactory();
        bytes memory rolesInit =
            abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe))));
        roles = IRoles(
            moduleProxyFactory.deployModule(ROLES_MASTERCOPY, rolesInit, uint256(0x11d0))
        );

        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))
        );

        Policy.Addresses memory m;
        m.safe = address(safe);
        m.agent = address(agent);
        m.operator = tmc;
        m.emergency = eb;
        Policy.fillTokens(m);
        Policy.fillProtocols(m);
        Policy.fillAtokens(m);
        a = m;

        Policy.Call[] memory calls = FullPolicy.build(m, address(roles));
        for (uint256 i = 0; i < calls.length; i++) {
            SafeExec.execAsOwner(agent, safe, calls[i].to, calls[i].data);
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
        vm.prank(tmc);
        (bool ok, bytes memory ret) = address(roles).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole, (to, 0, data, 0, Policy.OPERATOR(), true)
            )
        );
        if (!ok) {
            if (ret.length >= 4 && bytes4(ret) == 0xd0a9bf58) {
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
        vm.prank(tmc);
        vm.expectRevert();
        roles.execTransactionWithRole(to, 0, data, 0, Policy.OPERATOR(), true);
    }

    function _em(address to, bytes memory data) internal {
        vm.prank(eb);
        bool ok = roles.execTransactionWithRole(to, 0, data, 0, Policy.EMERGENCY(), true);
        assertTrue(ok, "emergency call failed");
    }

    function _emRevert(address to, bytes memory data) internal {
        vm.prank(eb);
        vm.expectRevert();
        roles.execTransactionWithRole(to, 0, data, 0, Policy.EMERGENCY(), true);
    }

    // ------------------------------------------------------------------
    // D1 + D2: both governance paths apply the same permission change
    // ------------------------------------------------------------------
    function test_D1_expansion_via_mock_ET() public {
        // expansion motion: allow the operator to also supply sUSDS? No —
        // use a fresh, harmless target: allow wstETH.wrap on EMERGENCY? no.
        // Expansion = widen operator with a new scoped function on a token
        // it already touches: usdc.approve already eq-pinned to aavePool;
        // add a *new function* entirely: wsteth.transfer? No (never).
        // Representative + safe: allow the operator to read-style call
        // stETH.submit? Not a treasury action. Use: allowFunction(operator,
        // aavePool, setUserUseReserveAsCollateral? that alters collateral
        // (forbidden in spirit). Chosen: mint-free, harmless — allow the
        // operator wstETH.approve to a NEW spender (a deposit queue it did
        // not have: earnUSD redeem queue is not a spender; use a dummy
        // target 0xdEaD) — pure permission-shape drill.
        address dummySpender = address(0xdEaD);
        Policy.Call[] memory calls = new Policy.Call[](1);
        calls[0] = Policy._opApproveEq(address(roles), a.wsteth, dummySpender, Policy.OPERATOR());

        bytes memory script = EVMScriptLib.build(agent, safe, calls);
        vm.prank(tmc);
        uint256 id = easyTrack.createMotion(address(factory), script);

        // objection path: whale kills it before enactment
        vm.prank(whale);
        easyTrack.object(id);
        (,,,,,,, uint256 status) = _motion(id);
        assertEq(uint256(status), 1, "motion should be rejected"); // 1 = Rejected

        vm.expectRevert();
        easyTrack.enactMotion(id);

        // a second motion with no objection passes and applies
        vm.prank(tmc);
        uint256 id2 = easyTrack.createMotion(address(factory), script);
        vm.warp(block.timestamp + 3 days + 1);
        easyTrack.enactMotion(id2);

        // the widened permission now works for the operator
        _op(a.wsteth, abi.encodeCall(IERC20.approve, (dummySpender, 1 ether)));
        assertEq(IERC20(a.wsteth).allowance(address(safe), dummySpender), 1 ether);
    }

    function _motion(uint256 id)
        internal
        view
        returns (
            address creator,
            address f,
            bytes memory cd,
            bytes memory script,
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
            m.evmScript,
            m.startDate,
            m.snapshotDate,
            m.objectionsAmount,
            uint8(m.status)
        );
    }

    function test_D2_direct_DAO_path() public {
        // the same change applied directly by the owner, no Easy Track
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
        _op(a.wsteth, abi.encodeCall(IERC20.approve, (address(0xbee5), 5)));
        assertEq(IERC20(a.wsteth).allowance(address(safe), address(0xbee5)), 5);
    }

    // ------------------------------------------------------------------
    // D3: operator lifecycle on real mainnet contracts
    // ------------------------------------------------------------------
    function test_D3_operator_lifecycle() public {
        // fund the Safe directly (bootstrap path is covered separately)
        deal(a.usdc, address(safe), 2_000e6);
        deal(a.dai, address(safe), 2_000e18);

        // Aave: approve then supply within allowance (avatar-pinned onBehalfOf)
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, 1_000e6)));
        _op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 500e6, address(safe), 0)));
        assertGt(IERC20(a.atokenUsdc).balanceOf(address(safe)), 0, "no aUSDC minted");

        // withdraw back to the avatar
        uint256 aBal = IERC20(a.atokenUsdc).balanceOf(address(safe));
        _op(a.aavePool, abi.encodeCall(IAaveV3Pool.withdraw, (a.usdc, aBal, address(safe))));
        assertEq(IERC20(a.atokenUsdc).balanceOf(address(safe)), 0);

        // Sky savings: approve then deposit
        _op(a.dai, abi.encodeCall(IERC20.approve, (a.sdai, 1_000e18)));
        _op(a.sdai, abi.encodeCall(ISDAI.deposit, (400e18, address(safe))));
        assertGt(IERC20(a.sdai).balanceOf(address(safe)), 0, "no sDAI");
        _op(a.sdai, abi.encodeCall(ISDAI.redeem, (IERC20(a.sdai).balanceOf(address(safe)), address(safe), address(safe))));
        assertEq(IERC20(a.sdai).balanceOf(address(safe)), 0);

        // wstETH unwrap (wrap needs stETH which vm.deal cannot fund on a
        // fork without breaking rebase accounting; the wrap permission shape
        // is identical to unwrap and covered by policy-build assertions)
        deal(a.wsteth, address(safe), 1 ether);
        _op(a.wsteth, abi.encodeCall(IWstETH.unwrap, (IERC20(a.wsteth).balanceOf(address(safe)))));
        assertGt(IERC20(a.steth).balanceOf(address(safe)), 0);

        // CoW presign: uid = orderHash (32) ++ owner (20) ++ validTo (4);
        // the settlement enforces uid.owner == caller (the Safe)
        bytes memory uid = abi.encodePacked(
            bytes32(uint256(0xdeadbeef)),
            bytes20(address(safe)),
            bytes4(uint32(block.timestamp + 3600))
        );
        _op(a.cowSettlement, abi.encodeCall(ICowSettlement.setPreSignature, (uid, true)));
        // approving setPreSignature(false) must fail: approved pinned to true
        _opRevert(a.cowSettlement, abi.encodeCall(ICowSettlement.setPreSignature, (uid, false)));

        // LDO sell-leg approval exists post A5/B5
        _op(a.ldo, abi.encodeCall(IERC20.approve, (a.cowVaultRelayer, 10e18)));
        assertEq(IERC20(a.ldo).allowance(address(safe), a.cowVaultRelayer), 10e18);
    }

    function test_D3_operator_cannot_route_around_avatar() public {
        deal(a.usdc, address(safe), 1_000e6);
        // supply with onBehalfOf = attacker must fail (EqualToAvatar)
        _opRevert(
            a.aavePool,
            abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 100e6, attacker, 0))
        );
        // plain transfer is not in the permission set at all
        _opRevert(a.usdc, abi.encodeCall(IERC20.transfer, (attacker, 1e6)));
    }

    // ------------------------------------------------------------------
    // D4: emergency drill
    // ------------------------------------------------------------------
    function test_D4_emergency_flow() public {
        deal(a.usdc, address(safe), 500e6);
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, 500e6)));
        _op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 200e6, address(safe), 0)));

        // 1. block the operator: revokeTarget on aavePool (roleKey pinned)
        _em(address(roles), abi.encodeCall(IRoles.revokeTarget, (Policy.OPERATOR(), a.aavePool)));
        // operator can no longer supply
        _opRevert(
            a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 100e6, address(safe), 0))
        );

        // 2. revoke approvals to zero
        _em(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, 0)));
        assertEq(IERC20(a.usdc).allowance(address(safe), a.aavePool), 0);

        // 3. exit the position to the avatar
        uint256 aBal = IERC20(a.atokenUsdc).balanceOf(address(safe));
        _em(a.aavePool, abi.encodeCall(IAaveV3Pool.withdraw, (a.usdc, aBal, address(safe))));

        // 4. return to treasury: transfer pinned to the Agent literal
        uint256 bal = IERC20(a.usdc).balanceOf(address(safe));
        _em(a.usdc, abi.encodeCall(IERC20.transfer, (address(agent), bal)));
        assertEq(IERC20(a.usdc).balanceOf(address(agent)), bal);
        // any other destination is denied
        _emRevert(a.usdc, abi.encodeCall(IERC20.transfer, (attacker, 1e6)));
    }

    function test_D4_disable_module_unpinned_R3() public {
        // R3 evidence: emergency can disable the module with ANY (prev,module)
        // arguments — reproducing the proposal's unpinned scope on mainnet
        // singleton bytecode. The scope reaches only modules the Safe has.
        _em(address(safe), abi.encodeCall(ISafe.disableModule, (SENTINEL, address(roles))));
        assertFalse(safe.isModuleEnabled(address(roles)), "module should be off");
        // roles path dead: both roles blocked
        _opRevert(a.wsteth, abi.encodeCall(IWstETH.wrap, (1 ether)));
        _emRevert(a.wsteth, abi.encodeCall(IWstETH.unwrap, (1 ether)));
        // owner still reaches the Safe (DAO recovery equivalence)
        vm.startPrank(principal);
        SafeExec.execAsOwner(
            agent,
            safe,
            address(safe),
            abi.encodeCall(ISafe.enableModule, (address(roles)))
        );
        vm.stopPrank();
        assertTrue(safe.isModuleEnabled(address(roles)));
    }

    // ------------------------------------------------------------------
    // D5: budgets
    // ------------------------------------------------------------------
    function test_D5_budget_enforcement_and_refill() public {
        deal(a.usdc, address(safe), 2_000e6);
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, 2_000e6)));
        // within: 600 USDC fits the 1000 USDC/USDT shared budget
        _op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 600e6, address(safe), 0)));
        // over: another 600 exceeds the remaining ~400
        _opRevert(
            a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 600e6, address(safe), 0))
        );
        // shared across the USDC/USDT budget key: USDT draw must fail too
        deal(a.usdt, address(safe), 1_000e6);
        _op(a.usdt, abi.encodeCall(IERC20.approve, (a.aavePool, 1_000e6)));
        _opRevert(
            a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdt, 600e6, address(safe), 0))
        );
        // refill after one period restores the budget
        vm.warp(block.timestamp + 30 days + 1);
        (uint128 refill, uint128 maxRefill, uint64 period,,) = roles.allowances(Policy.K_AAVE_USDC_USDT);
        assertEq(uint256(refill), 1_000e6);
        assertEq(uint256(maxRefill), 1_000e6);
        assertEq(uint256(period), 30 days);
        _op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 900e6, address(safe), 0)));
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
        vm.expectRevert();
        roles.execTransactionWithRole(
            a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (1 ether)), 0, Policy.OPERATOR(), true
        );
        // CoW unbounded-sell demo (R1): an arbitrarily large presignable order
        // is only bounded by approvals — reproduce by approving max to the
        // relayer, which the current proposal permits. Evidence, not exploit.
        deal(a.usdc, address(safe), 1e12);
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max)));
        assertEq(IERC20(a.usdc).allowance(address(safe), a.aavePool), type(uint256).max);
        // note: approvals to non-approved spenders are denied by scope
        _opRevert(a.usdc, abi.encodeCall(IERC20.approve, (attacker, 1)));
    }

    // ------------------------------------------------------------------
    // Earn deposit permission shape (underlying protocol flow is async and
    // oracle-paced; the drill asserts the ROLES layer admits the verified
    // signature and that the protocol layer, not the policy, gates the rest)
    // ------------------------------------------------------------------
    function test_D3b_earn_deposit_policy_layer() public {
        deal(a.usdc, address(safe), 1_000e6);
        bytes32[] memory noProof = new bytes32[](0);
        // policy layer: call shape must be deposit(uint224,address,bytes32[])
        // with referral pinned to avatar. Protocol may still revert for its
        // own reasons (queue state); either way the ROLES layer must not be
        // the blocker. We assert the Roles check passes by expecting either
        // success or a protocol-origin revert.
        vm.prank(tmc);
        (bool ok,) = address(roles).call(
            abi.encodeCall(
                IRoles.execTransactionWithRole,
                (
                    a.earnUsdDepositQueue,
                    0,
                    abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(50e6), address(safe), noProof)),
                    0,
                    Policy.OPERATOR(),
                    false // shouldRevert=false: inspect the raw outcome
                )
            )
        );
        // ok=false means the Roles layer blocked it — that would be a defect.
        assertTrue(ok, "Roles layer rejected a policy-conformant earn deposit");
        // a referral to another address must be blocked by EqualToAvatar
        _opRevert(
            a.earnUsdDepositQueue,
            abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(50e6), attacker, noProof))
        );
    }

    receive() external payable {}
}
