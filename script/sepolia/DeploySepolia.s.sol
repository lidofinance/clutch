// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../../src/mocks/MockAragonAgent.sol";
import {MockEVMScriptExecutor} from "../../src/mocks/MockEVMScriptExecutor.sol";
import {
    SepoliaToken,
    SepoliaShares,
    SepoliaRedeemQueue,
    SepoliaEasyTrack,
    SepoliaFirstLossBurnFactory
} from "../../src/mocks/SepoliaStand.sol";
import {SafeExec} from "../../src/exec/SafeExec.sol";
import {ICoWSettlement, ICoWFallback} from "./CoWInterfaces.sol";

contract DeploySepolia is Script {
    string internal network;
    MockAragonAgent internal voting;
    uint256 internal salt;

    struct Stand {
        MockAragonAgent agent;
        ISafe committee;
        ISafe emergency;
        ISafe asset;
        ISafe orders;
        ISafe firstLoss;
        IRoles operator;
        IRoles safety;
        IRoles ordersRoles;
        IRoles firstLossRoles;
        SepoliaToken objection;
        MockEVMScriptExecutor executor;
        SepoliaEasyTrack et;
        SepoliaShares usd;
        SepoliaShares eth;
        SepoliaRedeemQueue usdQueue;
        SepoliaRedeemQueue ethQueue;
        SepoliaFirstLossBurnFactory factory;
    }
    Stand internal s;

    function dependency(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(network, string.concat(".contracts.", name, ".address"));
    }

    function _safe(address singleton, address owner, address handler, uint256 nonce) internal returns (ISafe safe) {
        address[] memory owners = new address[](1);
        owners[0] = owner;
        bytes memory init =
            abi.encodeCall(ISafe.setup, (owners, 1, address(0), "", handler, address(0), 0, payable(address(0))));
        safe = ISafe(
            payable(ISafeProxyFactory(dependency("safeProxyFactory")).createProxyWithNonce(singleton, init, nonce))
        );
    }

    function _modifier(ISafe safe, uint256 nonce) internal returns (IRoles roles) {
        bytes memory init = abi.encodeCall(IRoles.setUp, (abi.encode(address(safe), address(safe), address(safe))));
        roles = IRoles(
            IModuleProxyFactory(dependency("moduleProxyFactory")).deployModule(dependency("roles"), init, nonce)
        );
        SafeExec.execAsOwner(voting, safe, address(safe), abi.encodeCall(ISafe.enableModule, (address(roles))));
    }

    function run() external {
        require(block.chainid == 11155111, "Sepolia only");
        require(vm.envOr("CLUTCH_SEPOLIA", uint256(0)) == 1, "Set CLUTCH_SEPOLIA=1");
        require(vm.envOr("PRIVATE_KEY", uint256(0)) == 0 && vm.envOr("EXECUTOR_KEY", uint256(0)) == 0, "Use a keystore");
        address controller = vm.envAddress("SEPOLIA_SENDER");
        salt = vm.envOr("SEPOLIA_SALT", uint256(20261020));
        network = vm.readFile("policy/constellation/sepolia/network.json");
        string[12] memory names = [
            "safe15",
            "safe13",
            "safeProxyFactory",
            "moduleProxyFactory",
            "roles",
            "settlement",
            "vaultRelayer",
            "fallbackHandler",
            "composableCow",
            "twap",
            "timestampFactory",
            "orderSigner"
        ];
        for (uint256 i; i < names.length; ++i) {
            require(
                dependency(names[i]).codehash
                    == vm.parseJsonBytes32(network, string.concat(".contracts.", names[i], ".codeHash")),
                "Dependency hash changed"
            );
        }
        vm.startBroadcast(controller);
        _accounts(controller);
        _fixtures(controller);
        vm.stopBroadcast();
        _manifest(controller);
    }

    function _accounts(address controller) internal {
        // Two instances of the existing Agent mock: Voting owns; Agent receives recovery.
        voting = new MockAragonAgent();
        s.agent = new MockAragonAgent();
        s.committee = _safe(dependency("safe13"), controller, address(0), salt);
        s.emergency = _safe(dependency("safe15"), controller, address(0), salt + 1);
        s.asset = _safe(dependency("safe15"), address(voting), address(0), salt + 2);
        s.orders = _safe(dependency("safe15"), address(voting), dependency("fallbackHandler"), salt + 3);
        s.firstLoss = _safe(dependency("safe15"), address(voting), address(0), salt + 4);
        s.operator = _modifier(s.asset, salt);
        s.safety = _modifier(s.asset, salt + 1);
        s.ordersRoles = _modifier(s.orders, salt + 2);
        s.firstLossRoles = _modifier(s.firstLoss, salt + 3);
        SafeExec.execAsOwner(
            voting,
            s.orders,
            address(s.orders),
            abi.encodeCall(
                ICoWFallback.setDomainVerifier,
                (ICoWSettlement(dependency("settlement")).domainSeparator(), dependency("composableCow"))
            )
        );
    }

    function _fixtures(address controller) internal {
        s.objection = new SepoliaToken("Test objection weight", "tVOTE", controller);
        s.executor = new MockEVMScriptExecutor(s.agent);
        s.et = new SepoliaEasyTrack(
            s.executor, IERC20(address(s.objection)), vm.envOr("SEPOLIA_MOTION_DURATION", uint256(60)), address(voting)
        );
        s.usd = new SepoliaShares("tEarnUSD", controller);
        s.eth = new SepoliaShares("tEarnETH", controller);
        s.usdQueue = new SepoliaRedeemQueue(s.usd, controller);
        s.ethQueue = new SepoliaRedeemQueue(s.eth, controller);
        s.usd.setQueue(address(s.usdQueue));
        s.eth.setQueue(address(s.ethQueue));
        s.factory =
            new SepoliaFirstLossBurnFactory(address(s.committee), s.firstLossRoles, address(s.usd), address(s.eth));
        s.et.addEVMScriptFactory(address(s.factory));
        s.objection.mint(controller, 1000 ether);
        s.usd.mint(controller, 100 ether);
        s.eth.mint(controller, 100 ether);
        address weth = vm.parseJsonAddress(network, ".tokens.weth.address");
        address usdc = vm.parseJsonAddress(network, ".tokens.usdc.address");
        SafeExec.execAsOwner(
            voting, s.orders, weth, abi.encodeCall(IERC20.approve, (dependency("vaultRelayer"), type(uint256).max))
        );
        SafeExec.execAsOwner(
            voting, s.orders, usdc, abi.encodeCall(IERC20.approve, (dependency("vaultRelayer"), type(uint256).max))
        );
    }

    function _manifest(address controller) internal {
        string memory k = "sepolia";
        vm.serializeString(k, "network", "sepolia");
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeUint(k, "deploymentSalt", salt);
        vm.serializeUint(k, "simulationBlock", block.number);
        vm.serializeAddress(k, "controller", controller);
        vm.serializeAddress(k, "voting", address(voting));
        vm.serializeAddress(k, "agent", address(s.agent));
        vm.serializeAddress(k, "assetSafe", address(s.asset));
        vm.serializeAddress(k, "ordersSafe", address(s.orders));
        vm.serializeAddress(k, "firstLossSafe", address(s.firstLoss));
        vm.serializeAddress(k, "operatorSafe", address(s.committee));
        vm.serializeAddress(k, "emergencySafe", address(s.emergency));
        vm.serializeAddress(k, "operatorModifier", address(s.operator));
        vm.serializeAddress(k, "safetyModifier", address(s.safety));
        vm.serializeAddress(k, "ordersModifier", address(s.ordersRoles));
        vm.serializeAddress(k, "firstLossModifier", address(s.firstLossRoles));
        vm.serializeAddress(k, "easyTrackExecutor", address(s.executor));
        vm.serializeAddress(k, "easyTrack", address(s.et));
        vm.serializeAddress(k, "burnFactory", address(s.factory));
        vm.serializeAddress(k, "objectionToken", address(s.objection));
        vm.serializeAddress(k, "usdShare", address(s.usd));
        vm.serializeAddress(k, "ethShare", address(s.eth));
        vm.serializeAddress(k, "usdQueue", address(s.usdQueue));
        vm.serializeAddress(k, "ethQueue", address(s.ethQueue));
        vm.serializeAddress(k, "usdClaimAsset", address(s.usdQueue.asset()));
        vm.serializeAddress(k, "ethClaimAsset", address(s.ethQueue.asset()));
        address[] memory modules = new address[](2);
        modules[0] = address(s.operator);
        modules[1] = address(s.safety);
        string memory output = vm.serializeAddress(k, "modules", modules);
        string memory file = vm.envOr("SEPOLIA_MANIFEST", string("cache/sepolia/manifest.json"));
        vm.writeFile(file, output);
        vm.writeJson(network, file, ".dependencies");
        console2.log("TEST ONLY: Committee and Emergency 1/1; test Voting controller:", controller);
        console2.log("Sepolia manifest:", file);
    }
}
