// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {MockEasyTrack, PassThroughEVMScriptFactory} from "../src/mocks/MockEasyTrack.sol";

import {IERC20} from "../src/interfaces/Tokens.sol";
import {Policy} from "../src/policy/Policy.sol";
import {FullPolicy} from "../src/policy/FullPolicy.sol";
import {SafeExec} from "../src/policy/SafeExec.sol";

/// @title DeployDryRun — one-click mainnet dry-run deployment.
/// @dev Everything downstream of the governance heads is production grade:
///      the Safe proxy deploys from the v1.4.1 singleton and the Roles proxy
///      from the deployed v4 mastercopy; only Agent/ET are mocks. The policy
///      is applied through Agent -> Safe -> Roles, i.e. the exact production
///      permission-change path (drill D2 runs through it by construction).
///
///      Usage (see Justfile):
///        RPC=... EXECUTOR=0x... forge script script/DeployDryRun.s.sol --broadcast
contract DeployDryRun is Script {
    // Production singletons (WS-B verified at block 25946643).
    // Safe v1.5.0: required, because only from this release does the Safe
    // call a guard on the module execution path.
    address internal constant SAFE_SINGLETON = 0xFf51A5898e281Db6DfC7855790607438dF2ca44b;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant SAFE_PROXY_FACTORY = 0x14F2982D601c9458F93bd70B218933A6f8165e7b;
    address internal constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;

    // Production Easy Track timing (WS-B verified).
    uint256 internal constant MOTION_DURATION = 72 hours;
    uint256 internal constant OBJECTION_THRESHOLD = 5_000_000e18; // 0.5% of 1B LDO

    function run() external {
        uint256 executorKey = vm.envOr("EXECUTOR_KEY", uint256(0));
        uint256 deployer = executorKey != 0 ? executorKey : vm.envUint("PRIVATE_KEY");
        address operatorStandin = vm.envOr("OPERATOR_STANDIN", address(0));
        address emergencyStandin = vm.envOr("EMERGENCY_STANDIN", address(0));

        vm.startBroadcast(deployer);
        address executor = msg.sender;

        if (operatorStandin == address(0)) operatorStandin = executor;
        if (emergencyStandin == address(0)) emergencyStandin = executor;

        // --- sanity: singletons must carry code -------------------------
        require(SAFE_SINGLETON.code.length > 0, "singleton missing");
        require(
            keccak256(SAFE_SINGLETON.code)
                == 0xdda019cbd7c867a533a2a86e5c53434fdc50b13122b5a5ddb4a8df61b31c20f2,
            "safe singleton codehash mismatch"
        );
        require(ROLES_MASTERCOPY.code.length > 0, "roles mastercopy missing");
        require(SAFE_PROXY_FACTORY.code.length > 0, "proxy factory missing");

        // --- governance heads (mocked, interface-faithful) ----------------
        MockAragonAgent agent = new MockAragonAgent();
        MockEVMScriptExecutor executor_ = new MockEVMScriptExecutor(agent);
        MockEasyTrack easyTrack =
            new MockEasyTrack(executor_, IERC20(LDO), MOTION_DURATION, OBJECTION_THRESHOLD);
        PassThroughEVMScriptFactory factory = new PassThroughEVMScriptFactory();
        easyTrack.addEVMScriptFactory(address(factory));

        // --- production-grade accounts ------------------------------------
        ISafeProxyFactory proxyFactory = ISafeProxyFactory(SAFE_PROXY_FACTORY);

        address[] memory owners = new address[](1);
        owners[0] = address(agent);
        bytes memory safeInit = abi.encodeCall(
            ISafe.setup,
            (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        ISafe safe = ISafe(
            payable(proxyFactory.createProxyWithNonce(SAFE_SINGLETON, safeInit, uint256(0x11d0)))
        );

        // canonical deployed factory — production component, not a copy
        bytes memory rolesInit =
            abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe))));
        IRoles roles = IRoles(
            IModuleProxyFactory(MODULE_PROXY_FACTORY).deployModule(
                ROLES_MASTERCOPY, rolesInit, uint256(0x11d0)
            )
        );
        IRoles safety = IRoles(
            IModuleProxyFactory(MODULE_PROXY_FACTORY).deployModule(
                ROLES_MASTERCOPY, rolesInit, uint256(0x11d1)
            )
        );

        // enable the modifier as a Safe module, as the owner (production path)
        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles)))
        );
        SafeExec.execAsOwner(
            agent, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(safety)))
        );

        // --- apply the full policy through the production change path ------
        Policy.Addresses memory a;
        a.safe = address(safe);
        a.agent = address(agent);
        a.operator = operatorStandin;
        a.emergency = emergencyStandin;
        Policy.fillTokens(a);
        Policy.fillProtocols(a);
        Policy.fillAtokens(a);

        a.rolesOperator = address(roles);
        a.rolesSafety = address(safety);
        Policy.Call[] memory calls = FullPolicy.buildOperator(a, address(roles));
        for (uint256 i = 0; i < calls.length; i++) {
            SafeExec.execAsOwner(agent, safe, calls[i].to, calls[i].data);
        }
        Policy.Call[] memory safCalls = FullPolicy.buildSafety(a, address(safety), address(roles));
        for (uint256 i = 0; i < safCalls.length; i++) {
            SafeExec.execAsOwner(agent, safe, safCalls[i].to, safCalls[i].data);
        }

        vm.stopBroadcast();

        // --- manifest -------------------------------------------------------
        string memory manifest = string.concat(
            '{"dryrun":{"network":"mainnet",',
            '"agent":"',
            vm.toString(address(agent)),
            '","evmScriptExecutor":"',
            vm.toString(address(executor_)),
            '","easyTrack":"',
            vm.toString(address(easyTrack)),
            '","passThroughFactory":"',
            vm.toString(address(factory)),
            '","assetSafe":"',
            vm.toString(address(safe)),
            '","rolesModifier":"',
            vm.toString(address(roles)),
            '","operatorStandin":"',
            vm.toString(operatorStandin),
            '","emergencyStandin":"',
            vm.toString(emergencyStandin),
            '","safeSingleton":"',
            vm.toString(SAFE_SINGLETON),
            '","rolesMastercopy":"',
            vm.toString(ROLES_MASTERCOPY),
            '","policyCalls":',
            vm.toString(calls.length),
            ',"constellationSha":"',
            vm.envOr("CONSTELLATION_SHA", string("02ea37d")),
            '","rolesV4Sha":"820e5bc",',
            '"deployedAt":"',
            vm.toString(block.timestamp),
            '","deployBlock":',
            vm.toString(block.number),
            "}}"
        );
        vm.writeFile("dryrun-manifest.json", manifest);
        console2.log("MANIFEST written: dryrun-manifest.json");
        console2.log(manifest);
    }
}

