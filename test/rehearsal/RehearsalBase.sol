// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {Mainnet} from "./Mainnet.sol";
import {VoteBuilder} from "./VoteBuilder.sol";
import {UniversalFactory} from "../../src/factory/UniversalFactory.sol";

interface IVoting {
    function vote(uint256 voteId, bool inSupport, bool executesIfDecidedDeprecated) external;
    function executeVote(uint256 voteId) external;
    function votesLength() external view returns (uint256);
    function voteTime() external view returns (uint64);
    function canExecute(uint256 voteId) external view returns (bool);
}

interface ITokenManager {
    function forward(bytes calldata evmScript) external;
}

interface IFinance {
    function newImmediatePayment(address token, address receiver, uint256 amount, string calldata paymentReference) external;
}

interface IEasyTrack {
    struct Motion {
        uint256 id;
        address evmScriptFactory;
        address creator;
        uint256 duration;
        uint256 startDate;
        uint256 snapshotBlock;
        uint256 objectionsThreshold;
        uint256 objectionsAmount;
        bytes32 evmScriptHash;
    }

    function addEVMScriptFactory(address factory, bytes calldata permissions) external;
    function isEVMScriptFactory(address factory) external view returns (bool);
    function createMotion(address factory, bytes calldata callData) external returns (uint256);
    function enactMotion(uint256 motionId, bytes calldata callData) external;
    function getMotions() external view returns (Motion[] memory);
    function motionsCountLimit() external view returns (uint256);
    function motionDuration() external view returns (uint256);
    function cancelMotion(uint256 motionId) external;
    function evmScriptFactoryPermissions(address factory) external view returns (bytes memory);
}

/// @dev Lido's deployed factory of allowed-recipients registries and top-up factories. Its caller names the
///      registry's admin and role holders; the standard builders name the Aragon Agent.
interface IRecipientsFactory {
    function deployAllowedRecipientsRegistry(
        address defaultAdmin,
        address[] calldata addRecipientHolders,
        address[] calldata removeRecipientHolders,
        address[] calldata setLimitParametersHolders,
        address[] calldata updateSpentAmountHolders,
        address dateTime
    ) external returns (address);

    /// @dev The multi-token factory takes a token registry, and the single-token factory a token.
    function deployTopUpAllowedRecipients(
        address trustedCaller,
        address registry,
        address tokenOrTokenRegistry,
        address finance,
        address easyTrack
    ) external returns (address);
}

interface IRecipientsRegistry {
    function addRecipient(address recipient, string calldata title) external;
    function setLimitParameters(uint256 limit, uint256 periodDurationMonths) external;
    function renounceRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getLimitParameters() external view returns (uint256, uint256);
    function spendableBalance() external view returns (uint256);
    function updateSpentAmount(uint256 amount) external;
}

interface ISafeAdmin {
    function setFallbackHandler(address handler) external;
}

interface IExtensibleFallbackHandler {
    function setDomainVerifier(bytes32 domainSeparator, address verifier) external;
    function domainVerifiers(address safe, bytes32 domainSeparator) external view returns (address);
}

interface ISettlement {
    function domainSeparator() external view returns (bytes32);
}

/// @title RehearsalBase — the enabling vote rehearsed against the live Aragon
///        Voting, Easy Track, Aragon Finance and treasury on a mainnet fork.
/// @dev The accounts and modifiers are deterministic proxies, so their
///      addresses depend only on the initializer and the salt. The manifest
///      that the policy compiles against lists them (test_00 writes or checks
///      it). Figures marked STANDIN are test values, not production figures.
abstract contract RehearsalBase is Test {
    uint256 internal constant FORK_BLOCK = 26249900;
    /// @dev EIP-7825, live on mainnet since Fusaka (2025-12-03): no
    ///      transaction may have a gas limit above 2^24.
    uint256 internal constant TX_GAS_CAP = 16_777_216;
    /// @dev The txpool limit of geth and reth: four 32 KiB slots. A policy,
    ///      not a consensus rule.
    uint256 internal constant TX_SIZE_LIMIT = 128 * 1024;

    string internal constant MANIFEST = "policy/constellation/manifests/rehearsal-26249900.json";
    string internal constant ARTIFACT = "policy/constellation/artifacts/rehearsal-26249900.json";

    bytes32 internal constant OPERATOR = bytes32("operator");
    bytes32 internal constant GOVERNANCE = bytes32("governance");
    bytes32 internal constant EMERGENCY = bytes32("emergency");
    bytes32 internal constant FIRST_LOSS = bytes32("first-loss");
    bytes32 internal constant FIRST_LOSS_BURN = bytes32("first-loss-burn");
    bytes32 internal constant CREATE_PAYMENTS_ROLE = keccak256("CREATE_PAYMENTS_ROLE");

    // The approval caps of the launch policy: one mandate size, at dry-run scale
    // (policy/constellation/constellation/parameters.ts).
    uint256 internal constant SIZE_STANDIN_STETH = 10e18;
    uint256 internal constant SIZE_STANDIN_USD = 10_000e18;
    // The launch budgets (policy/constellation/constellation/allowances).
    uint128 internal constant SKY_SAVINGS_USDS = 1_000e18;
    uint128 internal constant EARN_USD_DEPOSIT = 500e6;
    uint128 internal constant EARN_ETH_DEPOSIT_WSTETH = 1e18;
    // The orders budgets, one per order token (ADR 007, decision 18).
    uint128 internal constant ORDERS_ETH_TOKEN = 10e18;
    uint128 internal constant ORDERS_USD6 = 10_000e6;
    uint128 internal constant ORDERS_USDS = 10_000e18;
    uint64 internal constant MONTH = 30 days;

    address internal constant DAI_USDS = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
    address internal constant EARN_ETH_DEPOSIT_QUEUE = 0xe39EED9A454C4918F8d0682062777cB251cd513F;
    address internal constant EARN_USD_REDEEM_QUEUE = 0x9e36A74FE278906a76e7615263e46a83fC40c47F;

    ISafe internal asset;
    ISafe internal orders;
    ISafe internal firstLoss;
    ISafe internal emergency;
    IRoles internal opMod;
    IRoles internal safetyMod;
    IRoles internal ordersMod;
    IRoles internal firstLossMod;
    address[] internal emergencySigners;

    UniversalFactory internal uf;

    // The top-up path (ADR 014, decisions 13 to 16): two registries with the Asset Safe as their only recipient,
    // and a top-up factory for each, with the committee's Safe as its trusted caller.
    address internal stethRegistry;
    address internal stableRegistry;
    address internal stethTopUp;
    address internal stableTopUp;
    bytes32 internal constant ADD_RECIPIENT_ROLE = keccak256("ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE");
    bytes32 internal constant SET_PARAMETERS_ROLE = keccak256("SET_PARAMETERS_ROLE");
    /// @dev A registry's period, in calendar months (OD-143).
    uint256 internal constant TOPUP_PERIOD_MONTHS = 3;
    /// @dev STANDIN: the stablecoin registry's limit for a period, in units of a stablecoin at par. A registry
    ///      counts every token in 18 decimals. The production figure comes from the attested computation.
    uint256 internal constant TOPUP_STABLE_LIMIT = 8_000_000e18;
    /// @dev STANDIN: the stETH registry's limit for a period, in stETH. The production units come from the
    ///      attested computation, at a pinned price.
    uint256 internal constant TOPUP_STETH_LIMIT = 5_000e18;

    address internal deployer = makeAddr("clutch-deployer");
    address internal anyone = makeAddr("anyone");

    function _fork() internal {
        vm.createSelectFork(vm.envString("RPC"), FORK_BLOCK);
    }

    function _salt(string memory name) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked("clutch.rehearsal.", name)));
    }

    function _safe(address[] memory owners, uint256 threshold, uint256 salt) internal returns (ISafe) {
        bytes memory init = abi.encodeCall(
            ISafe.setup, (owners, threshold, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        return ISafe(
            payable(ISafeProxyFactory(Mainnet.SAFE_PROXY_FACTORY).createProxyWithNonce(Mainnet.SAFE_SINGLETON, init, salt))
        );
    }

    function _modifier(address account, uint256 salt) internal returns (IRoles) {
        bytes memory init = abi.encodeCall(IRoles.setUp, (abi.encode(account, account, account)));
        return IRoles(IModuleProxyFactory(Mainnet.MODULE_PROXY_FACTORY).deployModule(Mainnet.ROLES_MASTERCOPY, init, salt));
    }

    /// @dev Everything that needs no authority: the four Safes and the four
    ///      modifiers (enabling-vote page, "Before the vote").
    function _deployAccounts() internal {
        address[] memory voting = new address[](1);
        voting[0] = Mainnet.VOTING;
        asset = _safe(voting, 1, _salt("asset-safe"));
        orders = _safe(voting, 1, _salt("orders-account"));
        firstLoss = _safe(voting, 1, _salt("first-loss-safe"));
        for (uint256 i = 0; i < 5; i++) {
            emergencySigners.push(makeAddr(string.concat("emergency-signer-", vm.toString(i))));
        }
        emergency = _safe(emergencySigners, 3, _salt("emergency-safe"));
        opMod = _modifier(address(asset), _salt("operator-modifier"));
        safetyMod = _modifier(address(asset), _salt("safety-modifier"));
        ordersMod = _modifier(address(orders), _salt("orders-modifier"));
        firstLossMod = _modifier(address(firstLoss), _salt("first-loss-modifier"));
    }

    /// @dev The universal factory (ADR 013). Its trusted caller is the committee's Safe, and only the live
    ///      executor calls `applyMotion`. The deployer's first creation makes it, so its address, which the
    ///      manifest names as the holder of the motion roles (decision 18), does not change with its code.
    function _deployFactory() internal {
        UniversalFactory.Config memory c = UniversalFactory.Config({
            trustedCaller: Mainnet.COMMITTEE_SAFE,
            executor: Mainnet.ET_EXECUTOR,
            emergencySafe: address(emergency),
            voting: Mainnet.VOTING,
            operatorModifier: address(opMod),
            safetyModifier: address(safetyMod),
            ordersModifier: address(ordersMod),
            firstLossModifier: address(firstLossMod)
        });
        vm.prank(deployer);
        uf = new UniversalFactory(c);
        assertEq(address(uf), vm.computeCreateAddress(deployer, 0), "the deployer's first creation");
        _deployTopUps();
    }

    /// @dev The two funding registries and their top-up factories, from Lido's deployed factories, with Aragon
    ///      Voting as each registry's admin: the standard builders name the Aragon Agent, and a change of a limit
    ///      would then pass Dual Governance. The deployer adds the Asset Safe and sets each limit, then gives up
    ///      its roles. The stablecoin factory pays the tokens of the DAO's stablecoin list (OD-141).
    function _deployTopUps() internal {
        vm.startPrank(deployer);
        stethRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_SINGLE, TOPUP_STETH_LIMIT);
        stableRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_MULTI, TOPUP_STABLE_LIMIT);
        stethTopUp = IRecipientsFactory(Mainnet.RECIPIENTS_FACTORY_SINGLE).deployTopUpAllowedRecipients(
            Mainnet.COMMITTEE_SAFE, stethRegistry, Mainnet.STETH, Mainnet.FINANCE, Mainnet.EASY_TRACK
        );
        stableTopUp = IRecipientsFactory(Mainnet.RECIPIENTS_FACTORY_MULTI).deployTopUpAllowedRecipients(
            Mainnet.COMMITTEE_SAFE, stableRegistry, Mainnet.STABLECOIN_LIST, Mainnet.FINANCE, Mainnet.EASY_TRACK
        );
        vm.stopPrank();
    }

    function _registry(address factory, uint256 limit) internal returns (address reg) {
        address[] memory add = new address[](2);
        (add[0], add[1]) = (Mainnet.VOTING, deployer);
        address[] memory remove = new address[](1);
        remove[0] = Mainnet.VOTING;
        address[] memory setLimit = new address[](2);
        (setLimit[0], setLimit[1]) = (Mainnet.VOTING, deployer);
        address[] memory spend = new address[](2);
        (spend[0], spend[1]) = (Mainnet.VOTING, Mainnet.ET_EXECUTOR);
        reg = IRecipientsFactory(factory).deployAllowedRecipientsRegistry(Mainnet.VOTING, add, remove, setLimit, spend, Mainnet.DATE_TIME);
        IRecipientsRegistry(reg).addRecipient(address(asset), "Clutch Asset Safe");
        IRecipientsRegistry(reg).setLimitParameters(limit, TOPUP_PERIOD_MONTHS);
        IRecipientsRegistry(reg).renounceRole(ADD_RECIPIENT_ROLE, deployer);
        IRecipientsRegistry(reg).renounceRole(SET_PARAMETERS_ROLE, deployer);
    }

    /// @dev The operator's order tokens at launch, sorted as the SDK sorts them (ADR 007, decision 22).
    function launchOrderTokens() public pure returns (address[] memory t) {
        t = new address[](6);
        (t[0], t[1], t[2], t[3], t[4], t[5]) =
            (Mainnet.WSTETH, Mainnet.USDC, Mainnet.STETH, Mainnet.WETH, Mainnet.USDT, Mainnet.USDS);
    }

    function _manifestJson() internal returns (string memory) {
        string memory o = "manifest";
        vm.serializeString(o, "network", string.concat("rehearsal-", vm.toString(FORK_BLOCK)));
        vm.serializeUint(o, "chainId", 1);
        vm.serializeUint(o, "forkBlock", FORK_BLOCK);
        vm.serializeString(
            o,
            "note",
            string.concat(
                "The enabling-vote rehearsal on a fork of block ",
                vm.toString(FORK_BLOCK),
                " (test/EnablingVoteRehearsal.t.sol): the live Aragon Voting owns the Safes, the live committee's Safe holds the operator role, and the universal factory, which the live Easy Track calls through its executor, holds the motion roles. Not a mainnet deployment."
            )
        );
        vm.serializeAddress(o, "agent", Mainnet.AGENT);
        vm.serializeAddress(o, "assetSafe", address(asset));
        vm.serializeAddress(o, "operatorModifier", address(opMod));
        vm.serializeAddress(o, "safetyModifier", address(safetyMod));
        address[] memory mods = new address[](2);
        mods[0] = address(opMod);
        mods[1] = address(safetyMod);
        vm.serializeAddress(o, "modules", mods);
        vm.serializeAddress(o, "operatorSafe", Mainnet.COMMITTEE_SAFE);
        vm.serializeAddress(o, "emergencySafe", address(emergency));
        vm.serializeAddress(o, "universalFactory", address(uf));
        vm.serializeAddress(o, "firstLossSafe", address(firstLoss));
        vm.serializeAddress(o, "firstLossModifier", address(firstLossMod));
        vm.serializeAddress(o, "ordersAccount", address(orders));
        return vm.serializeAddress(o, "ordersModifier", address(ordersMod));
    }

    function _checkManifest() internal view {
        string memory m = vm.readFile(MANIFEST);
        assertEq(vm.parseJsonAddress(m, ".agent"), Mainnet.AGENT, "manifest: agent");
        assertEq(vm.parseJsonAddress(m, ".assetSafe"), address(asset), "manifest: Asset Safe");
        assertEq(vm.parseJsonAddress(m, ".operatorModifier"), address(opMod), "manifest: operator modifier");
        assertEq(vm.parseJsonAddress(m, ".safetyModifier"), address(safetyMod), "manifest: safety modifier");
        assertEq(vm.parseJsonAddress(m, ".operatorSafe"), Mainnet.COMMITTEE_SAFE, "manifest: committee's Safe");
        assertEq(vm.parseJsonAddress(m, ".emergencySafe"), address(emergency), "manifest: emergency Safe");
        assertEq(vm.parseJsonAddress(m, ".universalFactory"), address(uf), "manifest: universal factory");
        assertEq(vm.parseJsonAddress(m, ".firstLossSafe"), address(firstLoss), "manifest: first-loss Safe");
        assertEq(vm.parseJsonAddress(m, ".firstLossModifier"), address(firstLossMod), "manifest: first-loss modifier");
        assertEq(vm.parseJsonAddress(m, ".ordersAccount"), address(orders), "manifest: orders account");
        assertEq(vm.parseJsonAddress(m, ".ordersModifier"), address(ordersMod), "manifest: orders modifier");
    }

    function _cold(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) vm.cool(accounts[i]);
    }
}
