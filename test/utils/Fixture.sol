// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../../src/mocks/MockEVMScriptExecutor.sol";
import {MockEasyTrack, PassThroughEVMScriptFactory} from "../../src/mocks/MockEasyTrack.sol";
import {SafeExec} from "../../src/exec/SafeExec.sol";

/// @title ClutchFixture — one deterministic deployment on the pinned fork,
///        with the committed policy artifact applied.
/// @dev The policy comes only from the artifact that the constellation
///      compiler writes (ADR 004, decisions 13 to 15). The fixture first
///      checks that it deployed every contract at the address in the
///      manifest that the artifact was compiled from, so a changed
///      deployment fails here and not inside a drill.
abstract contract ClutchFixture is Test {
    uint256 internal constant FORK_BLOCK = 25946643;
    string internal constant MANIFEST = "policy/constellation/manifests/fork-25946643.json";
    string internal constant ARTIFACT = "policy/constellation/artifacts/fork-25946643.json";

    // Safe v1.5.0: EM's choice for the three new Safes (OD-02, OD-17).
    address internal constant SAFE_SINGLETON = 0xFf51A5898e281Db6DfC7855790607438dF2ca44b;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant SAFE_PROXY_FACTORY = 0x14F2982D601c9458F93bd70B218933A6f8165e7b;
    address internal constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    // The head of a Safe's module list.
    address internal constant SENTINEL = address(0x0000000000000000000000000000000000000001);

    // Role and budget keys: the label as bytes32, which is how the Zodiac
    // app and the roles SDK encode a key (ADR 004, decisions 10 and 13).
    bytes32 internal constant OPERATOR = bytes32("operator");
    bytes32 internal constant GOVERNANCE = bytes32("governance");
    bytes32 internal constant EMERGENCY = bytes32("emergency");
    bytes32 internal constant TECHNICAL = bytes32("technical");
    bytes32 internal constant K_SUSDS = bytes32("sky_savings_usds");
    bytes32 internal constant K_EARN_USD = bytes32("earn_usd_deposit");
    bytes32 internal constant K_EARN_ETH = bytes32("earn_eth_deposit_wsteth");

    // The dry-run stand-ins that the tests expect, stated here and not read
    // from the artifact, so that the tests check the policy. They are test
    // values. The production figures come from the attested computation.
    uint256 internal constant FLOOR_STANDIN_STETH = 10e18;
    uint256 internal constant FLOOR_STANDIN_USD = 10_000e18;

    struct Addresses {
        address safe; // the Asset Safe; owner of both modifiers
        address agent; // dry-run: MockAragonAgent; production: the Aragon Agent
        address operator; // stand-in for the operator Safe
        address emergency; // stand-in for the emergency Safe
        address technical; // stand-in for the Emergency Brakes multisig
        address governance; // the governance role's member: the mock script executor
        address rolesOperator; // modifier with the operator and governance roles
        address rolesSafety; // modifier with the emergency and technical roles
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

    MockAragonAgent internal agent;
    MockEVMScriptExecutor internal executor;
    MockEasyTrack internal easyTrack;
    PassThroughEVMScriptFactory internal factory;
    ISafe internal safe;
    IRoles internal roles; // operator + governance
    IRoles internal safety; // emergency + technical

    address internal operatorSafe = makeAddr("operator-safe-standin");
    address internal emergencySafe = makeAddr("emergency-safe-standin");
    address internal brakes = makeAddr("emergency-brakes-standin");
    address internal whale = makeAddr("ldo-whale"); // objection whale
    address internal attacker = makeAddr("attacker");
    address internal principal;

    Addresses internal a;
    uint256 internal policyCalls;

    function setUp() public virtual {
        vm.createSelectFork(vm.envOr("RPC", string("https://ethereum-rpc.publicnode.com")), FORK_BLOCK);
        principal = makeAddr("executor-eoa");
        vm.startPrank(principal);
        _deploy();
        _fill();
        _checkManifest();
        _applyArtifact();
        vm.stopPrank();

        // objection whale with more LDO than the threshold. LDO is an Aragon
        // MiniMe token whose storage forge cannot set safely; the mock Easy
        // Track only reads balanceOf, so the fixture mocks that view.
        vm.mockCall(LDO, abi.encodeWithSelector(IERC20.balanceOf.selector, whale), abi.encode(6_000_000e18));
    }

    /// @dev The mocked governance heads, the Asset Safe without a fallback
    ///      handler (OD-17), and the two modifiers from the canonical module
    ///      proxy factory. Every address is deterministic.
    function _deploy() internal {
        agent = new MockAragonAgent();
        executor = new MockEVMScriptExecutor(agent);
        // The executor is deliberately not a permitted runner of the mock
        // Agent. At the fork block the real script executor holds neither
        // RUN_SCRIPT_ROLE nor EXECUTE_ROLE on the Agent, so motions change
        // the policy through the governance role, not through the Agent.
        easyTrack = new MockEasyTrack(executor, IERC20(LDO), 3 days, 5_000_000e18);
        factory = new PassThroughEVMScriptFactory();
        easyTrack.addEVMScriptFactory(address(factory));

        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        bytes memory safeInit = abi.encodeCall(
            ISafe.setup, (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        safe = ISafe(
            payable(ISafeProxyFactory(SAFE_PROXY_FACTORY).createProxyWithNonce(SAFE_SINGLETON, safeInit, uint256(0x22)))
        );
        bytes memory rolesInit =
            abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe))));
        IModuleProxyFactory mpf = IModuleProxyFactory(MODULE_PROXY_FACTORY);
        roles = IRoles(mpf.deployModule(ROLES_MASTERCOPY, rolesInit, uint256(0x11d0)));
        safety = IRoles(mpf.deployModule(ROLES_MASTERCOPY, rolesInit, uint256(0x11d1)));

        SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles))));
        SafeExec.execAsOwner(agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(safety))));
    }

    function _fill() internal {
        a.safe = address(safe);
        a.agent = address(agent);
        a.operator = operatorSafe;
        a.emergency = emergencySafe;
        a.technical = brakes;
        a.governance = address(executor);
        a.rolesOperator = address(roles);
        a.rolesSafety = address(safety);
        a.steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        a.wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        a.weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        a.ldo = LDO;
        a.usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        a.usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        a.dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        a.usds = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
        a.susds = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
        a.daiUsds = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
        a.withdrawalQueue = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
        a.earnUsdDepositQueue = 0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76;
        a.earnUsdRedeemQueue = 0x9e36A74FE278906a76e7615263e46a83fC40c47F;
        a.earnUsdShare = 0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981;
        a.earnEthDepositQueue = 0xe39EED9A454C4918F8d0682062777cB251cd513F;
        a.earnEthRedeemQueue = 0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4;
        a.earnEthShare = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4;
    }

    /// @dev The artifact names these addresses, so the deployment must match them.
    function _checkManifest() internal view {
        string memory m = vm.readFile(MANIFEST);
        assertEq(vm.parseJsonAddress(m, ".agent"), a.agent, "manifest: agent");
        assertEq(vm.parseJsonAddress(m, ".assetSafe"), a.safe, "manifest: Asset Safe");
        assertEq(vm.parseJsonAddress(m, ".operatorModifier"), a.rolesOperator, "manifest: operator modifier");
        assertEq(vm.parseJsonAddress(m, ".safetyModifier"), a.rolesSafety, "manifest: safety modifier");
        assertEq(vm.parseJsonAddress(m, ".operatorSafe"), a.operator, "manifest: operator Safe");
        assertEq(vm.parseJsonAddress(m, ".emergencySafe"), a.emergency, "manifest: emergency Safe");
        assertEq(vm.parseJsonAddress(m, ".emergencyBrakes"), a.technical, "manifest: Emergency Brakes");
        assertEq(vm.parseJsonAddress(m, ".easyTrackExecutor"), a.governance, "manifest: script executor");

        // The governance role refuses every listed module as an administered
        // target (OD-38), so the list must be exactly the Asset Safe's modules.
        address[] memory listed = vm.parseJsonAddressArray(m, ".modules");
        (address[] memory live,) = safe.getModulesPaginated(SENTINEL, 16);
        assertEq(listed.length, live.length, "manifest: every module of the Asset Safe");
        for (uint256 i = 0; i < listed.length; i++) {
            assertTrue(safe.isModuleEnabled(listed[i]), "manifest: a listed module is not enabled");
            for (uint256 j = 0; j < i; j++) assertTrue(listed[i] != listed[j], "manifest: a module is listed twice");
        }
    }

    /// @dev Applies the committed artifact's calls in order, each through the
    ///      Asset Safe as its owner, the Agent.
    function _applyArtifact() internal {
        string memory j = vm.readFile(ARTIFACT);
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        require(to.length > 0 && to.length == data.length, "artifact: calls");
        for (uint256 i = 0; i < to.length; i++) {
            SafeExec.execAsOwner(agent, safe, to[i], data[i]);
        }
        policyCalls = to.length;
    }
}
