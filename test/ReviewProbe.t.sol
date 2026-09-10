// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, IWstETH, IAaveV3Pool, ILidoEarnDepositQueue} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {IModuleProxyFactory} from "../src/interfaces/ISafe.sol";
import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";
import {SafeExec} from "../src/policy/SafeExec.sol";

/// @title ReviewProbe — independent review of the WS-M findings (2026-09-10).
/// @dev Not part of the kit's own suite. Each test decides one contested claim
///      against the deployed Roles v4 mastercopy on the pinned fork.
contract ReviewProbe is Test {
    uint256 internal constant FORK_BLOCK = 25946643;
    address internal constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant SAFE_PROXY_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;

    bytes32 internal constant K_USDC = keccak256("probe_usdc");
    bytes32 internal constant K_DAI = keccak256("probe_dai");
    bytes32 internal constant K_WSTETH = keccak256("probe_wsteth");

    MockAragonAgent internal agent;
    ISafe internal safe;
    IRoles internal roles;
    address internal tmc = makeAddr("tmc-standin");
    address internal attacker = makeAddr("attacker");
    address internal principal;
    Policy.Addresses internal a;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC"), FORK_BLOCK);
        principal = makeAddr("executor-eoa");
        vm.startPrank(principal);
        agent = new MockAragonAgent();
        ISafeProxyFactory pf = ISafeProxyFactory(SAFE_PROXY_FACTORY);
        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        safe = ISafe(payable(pf.createProxyWithNonce(SAFE_SINGLETON,
            abi.encodeCall(ISafe.setup, (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))), 0x77)));
        roles = IRoles(IModuleProxyFactory(0x000000000000aDdB49795b0f9bA5BC298cDda236).deployModule(ROLES_MASTERCOPY,
            abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe)))), 0x11d1));
        SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles))));
        Policy.Addresses memory m;
        m.safe = address(safe); m.agent = address(agent); m.operator = tmc; m.emergency = makeAddr("eb"); m.policyAdmin = makeAddr("policy-admin");
        Policy.fillTokens(m); Policy.fillProtocols(m); Policy.fillAtokens(m);
        a = m;
        Policy.Call[] memory calls = FullPolicy.build(m, address(roles));
        for (uint256 i = 0; i < calls.length; i++) SafeExec.execAsOwner(agent, safe, calls[i].to, calls[i].data);
        vm.stopPrank();
    }

    function _own(address to, bytes memory data) internal {
        vm.startPrank(principal);
        SafeExec.execAsOwner(agent, safe, to, data);
        vm.stopPrank();
    }

    function _op(address to, bytes memory data) internal returns (bool ok) {
        vm.prank(tmc);
        (ok,) = address(roles).call(abi.encodeCall(
            IRoles.execTransactionWithRole, (to, 0, data, 0, Policy.OPERATOR(), true)));
    }

    function _word(bytes memory raw, uint256 i) internal pure returns (bytes memory w) {
        w = new bytes(32);
        for (uint256 j = 0; j < 32; j++) w[j] = raw[i * 32 + j];
    }

    function _eqA(address x) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(x))));
    }

    // =================================================================
    // CLAIM F-X4: "per-asset budget coupling is NOT expressible in Roles v4"
    // Provider's declared policy: three supply() entries, one budget each.
    // Probe: root Or over three Matches branches, one allowance key each.
    // =================================================================
    function test_FX4_per_asset_budgets_ARE_expressible() public {
        // fresh allowance keys, deliberately different scales
        _own(address(roles), abi.encodeCall(IRoles.setAllowance, (K_USDC, 1_000e6, 1_000e6, 1_000e6, 30 days, 0)));
        _own(address(roles), abi.encodeCall(IRoles.setAllowance, (K_DAI, 1_000e18, 1_000e18, 1_000e18, 30 days, 0)));
        _own(address(roles), abi.encodeCall(IRoles.setAllowance, (K_WSTETH, 1e18, 1e18, 1e18, 30 days, 0)));

        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](16);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 0, operator_: 2, compValue: ""}); // Or
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""}); // Matches USDC
        c[2] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""}); // Matches DAI
        c[3] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""}); // Matches wstETH
        // USDC branch
        c[4] = IRoles.ConditionFlat({parent: 1, paramType: 1, operator_: 16, compValue: _eqA(a.usdc)});
        c[5] = IRoles.ConditionFlat({parent: 1, paramType: 1, operator_: 28, compValue: abi.encodePacked(K_USDC)});
        c[6] = IRoles.ConditionFlat({parent: 1, paramType: 1, operator_: 15, compValue: ""});
        c[7] = IRoles.ConditionFlat({parent: 1, paramType: 1, operator_: 0, compValue: ""});
        // DAI branch
        c[8] = IRoles.ConditionFlat({parent: 2, paramType: 1, operator_: 16, compValue: _eqA(a.dai)});
        c[9] = IRoles.ConditionFlat({parent: 2, paramType: 1, operator_: 28, compValue: abi.encodePacked(K_DAI)});
        c[10] = IRoles.ConditionFlat({parent: 2, paramType: 1, operator_: 15, compValue: ""});
        c[11] = IRoles.ConditionFlat({parent: 2, paramType: 1, operator_: 0, compValue: ""});
        // wstETH branch
        c[12] = IRoles.ConditionFlat({parent: 3, paramType: 1, operator_: 16, compValue: _eqA(a.wsteth)});
        c[13] = IRoles.ConditionFlat({parent: 3, paramType: 1, operator_: 28, compValue: abi.encodePacked(K_WSTETH)});
        c[14] = IRoles.ConditionFlat({parent: 3, paramType: 1, operator_: 15, compValue: ""});
        c[15] = IRoles.ConditionFlat({parent: 3, paramType: 1, operator_: 0, compValue: ""});

        // 1. the modifier ACCEPTS the shape (Integrity.sol)
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (Policy.OPERATOR(), a.aavePool, IAaveV3Pool.supply.selector, c, 0)));
        emit log("Integrity ACCEPTED root-Or over three Matches branches");

        deal(a.usdc, address(safe), 5_000e6);
        deal(a.dai, address(safe), 5_000e18);
        deal(a.wsteth, address(safe), 5e18);
        // isolate the budget mechanism from the shipped policy's approve scopes
        // (see test_regression_dai_and_usds_approvals_survive)
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (Policy.OPERATOR(), a.usdc, IERC20.approve.selector, 0)));
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (Policy.OPERATOR(), a.dai, IERC20.approve.selector, 0)));
        _own(address(roles), abi.encodeCall(IRoles.allowFunction, (Policy.OPERATOR(), a.wsteth, IERC20.approve.selector, 0)));
        assertTrue(_op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max))), "approve usdc");
        assertTrue(_op(a.dai, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max))), "approve dai");
        assertTrue(_op(a.wsteth, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max))), "approve wsteth");

        // 2. each asset draws its OWN key at its OWN scale
        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 900e6, address(safe), 0))), "usdc 900 within k1");
        assertFalse(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 200e6, address(safe), 0))), "usdc must exhaust k1");

        // 3. exhausting the USDC key does NOT touch the DAI key -> coupling proven
        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.dai, 900e18, address(safe), 0))), "dai 900 within k2");
        assertFalse(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.dai, 200e18, address(safe), 0))), "dai must exhaust k2");

        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.wsteth, 9e17, address(safe), 0))), "wsteth within k3");
        assertFalse(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.wsteth, 2e17, address(safe), 0))), "wsteth must exhaust k3");

        // 4. asset outside every branch is denied
        deal(a.usdt, address(safe), 1_000e6);
        assertFalse(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdt, 1e6, address(safe), 0))), "usdt not in any branch");

        // NB: the deployed Allowance struct is (refill, maxRefill, period,
        // balance, timestamp). The kit's IRoles declares timestamp before
        // balance, which is a separate defect; read the raw words instead.
        (, bytes memory rawUsdc) = address(roles).staticcall(abi.encodeWithSignature("allowances(bytes32)", K_USDC));
        (, bytes memory rawDai) = address(roles).staticcall(abi.encodeWithSignature("allowances(bytes32)", K_DAI));
        uint128 balUsdc = uint128(abi.decode(_word(rawUsdc, 3), (uint256)));
        uint128 balDai = uint128(abi.decode(_word(rawDai, 3), (uint256)));
        emit log_named_uint("k_usdc remaining", balUsdc);
        emit log_named_uint("k_dai  remaining", balDai);
        assertEq(balUsdc, 100e6, "k1 consumed only by usdc");
        assertEq(balDai, 100e18, "k2 consumed only by dai");
    }

    // =================================================================
    // REGRESSION GUARD (was a defect detector for the single-shared-budget
    // bug, fixed 2026-09-10): the shipped policy now gives 18-decimal assets
    // their OWN budget keys, so DAI and wstETH supplies must succeed at
    // 1-unit scale while the 6-decimal USDC budget stays untouched.
    // =================================================================
    function test_regression_18_decimal_supply_draws_own_budget() public {
        deal(a.usdc, address(safe), 5_000e6);
        deal(a.dai, address(safe), 5_000e18);
        deal(a.wsteth, address(safe), 5e18);
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max)));
        _op(a.dai, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max)));
        _op(a.wsteth, abi.encodeCall(IERC20.approve, (a.aavePool, type(uint256).max)));

        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.usdc, 100e6, address(safe), 0))), "usdc ok");
        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.dai, 1e18, address(safe), 0))), "1 DAI must draw its own k2 budget");
        assertTrue(_op(a.aavePool, abi.encodeCall(IAaveV3Pool.supply, (a.wsteth, 1e18, address(safe), 0))), "1 wstETH must draw its own k3 budget");
    }

    // =================================================================
    // REGRESSION GUARD (was a defect detector for the duplicate-scope wipe,
    // fixed 2026-09-10): the shipped policy now merges all spenders into ONE
    // approve scope per token, so the Aave pool, the savings vault AND the
    // CoW relayer must all remain approvable for DAI and USDS.
    // =================================================================
    function test_regression_dai_and_usds_approvals_survive() public {
        deal(a.dai, address(safe), 1_000e18);
        deal(a.usds, address(safe), 1_000e18);
        assertTrue(_op(a.dai, abi.encodeCall(IERC20.approve, (a.sdai, 1e18))), "dai->sDAI allowed");
        assertTrue(_op(a.usds, abi.encodeCall(IERC20.approve, (a.susds, 1e18))), "usds->sUSDS allowed");
        assertTrue(_op(a.dai, abi.encodeCall(IERC20.approve, (a.aavePool, 1e18))), "dai->Aave allowed (no wipe)");
        assertTrue(_op(a.dai, abi.encodeCall(IERC20.approve, (a.cowVaultRelayer, 1e18))), "dai->CoW allowed (no wipe)");
        assertTrue(_op(a.usds, abi.encodeCall(IERC20.approve, (a.aavePool, 1e18))), "usds->Aave allowed (no wipe)");
        assertTrue(_op(a.usds, abi.encodeCall(IERC20.approve, (a.cowVaultRelayer, 1e18))), "usds->CoW allowed (no wipe)");
    }

    // =================================================================
    // CLAIM F-X7 / R1: what can a condition on setPreSignature see?
    // =================================================================
    function test_cow_presign_is_opaque_to_the_modifier() public {
        // an order whose receiver is the attacker is indistinguishable to the
        // modifier: only orderDigest(32) ++ owner(20) ++ validTo(4) is visible.
        bytes32 digestOfAttackerOrder = keccak256("sell 5000 USDC, buy 1 wei DAI, receiver=attacker");
        bytes memory uid = abi.encodePacked(
            digestOfAttackerOrder, bytes20(address(safe)), bytes4(uint32(block.timestamp + 3600)));
        assertTrue(_op(a.cowSettlement, abi.encodeWithSignature("setPreSignature(bytes,bool)", uid, true)), "presign of an arbitrary order is permitted");
        emit log("setPreSignature carries no token, amount, price or receiver field");
    }

    // =================================================================
    // CLAIM F-X7: does a single-child Matches on a 3-param function work?
    // (the provider writes deposit(c.withinAllowance(key)) )
    // =================================================================
    function test_FX7_single_child_matches_on_three_param_function() public {
        IRoles.ConditionFlat[] memory c = new IRoles.ConditionFlat[](2);
        c[0] = IRoles.ConditionFlat({parent: 0, paramType: 5, operator_: 5, compValue: ""});
        c[1] = IRoles.ConditionFlat({parent: 0, paramType: 1, operator_: 28, compValue: abi.encodePacked(Policy.K_EARN_USD)});
        // Integrity accepts it at write time
        _own(address(roles), abi.encodeCall(IRoles.scopeFunction,
            (Policy.OPERATOR(), a.earnUsdDepositQueue, ILidoEarnDepositQueue.deposit.selector, c, 0)));
        emit log("Integrity ACCEPTED a 1-child Matches on a 3-param function");
        deal(a.usdc, address(safe), 1_000e6);
        _op(a.usdc, abi.encodeCall(IERC20.approve, (a.earnUsdDepositQueue, type(uint256).max)));
        bytes32[] memory noProof = new bytes32[](0);
        bool ok = _op(a.earnUsdDepositQueue,
            abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(10e6), address(safe), noProof)));
        emit log_named_string("call with 3 params against a 1-child condition", ok ? "ALLOWED" : "DENIED at check time");
        assertTrue(ok, "a 1-child Matches leaves trailing params unconstrained and allows the call");
    }
}
