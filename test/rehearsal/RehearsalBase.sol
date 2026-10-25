// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {Mainnet} from "./Mainnet.sol";
import {VoteBuilder} from "./VoteBuilder.sol";
import {BudgetFactoryStandIn} from "./BudgetFactoryStandIn.sol";

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

interface IACL {
    function grantPermissionP(address entity, address app, bytes32 role, uint256[] calldata params) external;
    function revokePermission(address entity, address app, bytes32 role) external;
    function hasPermission(address who, address where, bytes32 what, uint256[] calldata how) external view returns (bool);
    function getPermissionParamsLength(address entity, address app, bytes32 role) external view returns (uint256);
    function getPermissionParam(address entity, address app, bytes32 role, uint256 index)
        external
        view
        returns (uint8 id, uint8 op, uint240 value);
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
}

interface IRecipientsFactory {
    function deployAllowedRecipientsRegistry(
        address defaultAdmin,
        address[] calldata addRecipientHolders,
        address[] calldata removeRecipientHolders,
        address[] calldata setLimitParametersHolders,
        address[] calldata updateSpentAmountHolders,
        address dateTime
    ) external returns (address);

    /// @dev The multi-token factory takes a token registry and the
    ///      single-token factory a token; both take five addresses.
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
    function getPeriodState() external view returns (uint256, uint256, uint256, uint256);
    function updateSpentAmount(uint256 amount) external;
}

interface IAllowedTokensRegistry {
    function addToken(address token) external;
    function isTokenAllowed(address token) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
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
    bytes32 internal constant ADD_RECIPIENT_ROLE = keccak256("ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE");
    bytes32 internal constant SET_PARAMETERS_ROLE = keccak256("SET_PARAMETERS_ROLE");
    bytes32 internal constant ADD_TOKEN_ROLE = keccak256("ADD_TOKEN_TO_ALLOWED_LIST_ROLE");

    // Test stand-ins. The production limits are one mandate size per month, a
    // backstop under the mandate's ceiling (ADR 008, OD-89); they come from the
    // attested computation and are not in this repository.
    uint256 internal constant STABLE_LIMIT_STANDIN = 1_000_000e18;
    uint256 internal constant STETH_LIMIT_STANDIN = 300e18;

    ISafe internal asset;
    ISafe internal orders;
    ISafe internal firstLoss;
    ISafe internal emergency;
    IRoles internal opMod;
    IRoles internal safetyMod;
    IRoles internal ordersMod;
    IRoles internal firstLossMod;
    address[] internal emergencySigners;

    address internal stableRegistry;
    address internal stethRegistry;
    address internal stableTopUp;
    address internal stethTopUp;
    BudgetFactoryStandIn internal budgetFactory;

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

    /// @dev The funding registries and top-up factories. The standard
    ///      builders make the Aragon Agent each registry's admin, so the
    ///      rehearsal calls the same factories directly with Aragon Voting as
    ///      admin (finding 2 of the research note), then gives up its own roles.
    function _deployFunding() internal {
        vm.startPrank(deployer);
        stableRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_MULTI, STABLE_LIMIT_STANDIN, 1);
        stethRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_SINGLE, STETH_LIMIT_STANDIN, 1);
        stableTopUp = IRecipientsFactory(Mainnet.RECIPIENTS_FACTORY_MULTI).deployTopUpAllowedRecipients(
            Mainnet.COMMITTEE_SAFE, stableRegistry, Mainnet.STABLECOIN_LIST, Mainnet.FINANCE, Mainnet.EASY_TRACK
        );
        stethTopUp = IRecipientsFactory(Mainnet.RECIPIENTS_FACTORY_SINGLE).deployTopUpAllowedRecipients(
            Mainnet.COMMITTEE_SAFE, stethRegistry, Mainnet.STETH, Mainnet.FINANCE, Mainnet.EASY_TRACK
        );
        budgetFactory = new BudgetFactoryStandIn(Mainnet.COMMITTEE_SAFE, address(opMod));
        vm.stopPrank();
    }

    function _registry(address factory, uint256 limit, uint256 months) internal returns (address reg) {
        address[] memory add = new address[](2);
        add[0] = Mainnet.VOTING;
        add[1] = deployer;
        address[] memory remove = new address[](1);
        remove[0] = Mainnet.VOTING;
        address[] memory setLimit = new address[](2);
        setLimit[0] = Mainnet.VOTING;
        setLimit[1] = deployer;
        address[] memory spend = new address[](2);
        spend[0] = Mainnet.VOTING;
        spend[1] = Mainnet.ET_EXECUTOR;
        reg = IRecipientsFactory(factory).deployAllowedRecipientsRegistry(
            Mainnet.VOTING, add, remove, setLimit, spend, Mainnet.DATE_TIME
        );
        IRecipientsRegistry(reg).addRecipient(address(asset), "Clutch Asset Safe");
        IRecipientsRegistry(reg).setLimitParameters(limit, months);
        IRecipientsRegistry(reg).renounceRole(ADD_RECIPIENT_ROLE, deployer);
        IRecipientsRegistry(reg).renounceRole(SET_PARAMETERS_ROLE, deployer);
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
                " (test/EnablingVoteRehearsal.t.sol): the live Aragon Voting owns the Safes, and the live committee's Safe and Easy Track executor are members. Not a mainnet deployment."
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
        return vm.serializeAddress(o, "easyTrackExecutor", Mainnet.ET_EXECUTOR);
    }

    function _checkManifest() internal view {
        string memory m = vm.readFile(MANIFEST);
        assertEq(vm.parseJsonAddress(m, ".agent"), Mainnet.AGENT, "manifest: agent");
        assertEq(vm.parseJsonAddress(m, ".assetSafe"), address(asset), "manifest: Asset Safe");
        assertEq(vm.parseJsonAddress(m, ".operatorModifier"), address(opMod), "manifest: operator modifier");
        assertEq(vm.parseJsonAddress(m, ".safetyModifier"), address(safetyMod), "manifest: safety modifier");
        assertEq(vm.parseJsonAddress(m, ".operatorSafe"), Mainnet.COMMITTEE_SAFE, "manifest: committee's Safe");
        assertEq(vm.parseJsonAddress(m, ".emergencySafe"), address(emergency), "manifest: emergency Safe");
        assertEq(vm.parseJsonAddress(m, ".easyTrackExecutor"), Mainnet.ET_EXECUTOR, "manifest: executor");
    }

    function _cold(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) vm.cool(accounts[i]);
    }
}
