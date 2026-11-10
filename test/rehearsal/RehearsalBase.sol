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

    // Test stand-ins for the factory's ceilings, per token. The production
    // figures come from the attested computation and are not in this repository.
    uint256 internal constant BUDGET_CEILING_USDC = 1_000_000e6;
    uint256 internal constant BUDGET_CEILING_USDS = 1_000_000e18;
    uint256 internal constant BUDGET_CEILING_WSTETH = 300e18;
    uint256 internal constant BUDGET_CEILING_STETH = 300e18;
    uint256 internal constant BUDGET_CEILING_WETH = 300e18;
    uint256 internal constant BUDGET_CEILING_USDT = 1_000_000e6;
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

    /// @dev The universal factory (ADR 013), seeded with what the enabling
    ///      vote's policy writes: the operator's approval lists and budgets,
    ///      the launch keys, the orders account's lists, and the ceilings per
    ///      token. Its trusted caller is the committee's Safe, and only the
    ///      live executor calls `applyMotion`. The deployer's first creation
    ///      makes it, so its address, which the manifest names as the holder
    ///      of the motion roles (decision 18), does not change with its code.
    function _deployFactory() internal {
        UniversalFactory.Config memory c = UniversalFactory.Config({
            trustedCaller: Mainnet.COMMITTEE_SAFE,
            executor: Mainnet.ET_EXECUTOR,
            emergencySafe: address(emergency),
            voting: Mainnet.VOTING,
            assetSafe: address(asset),
            operatorModifier: address(opMod),
            safetyModifier: address(safetyMod),
            ordersModifier: address(ordersMod),
            firstLossModifier: address(firstLossMod),
            firstLossSafe: address(firstLoss),
            agent: Mainnet.AGENT,
            ordersAccount: address(orders)
        });
        // The launch budget keys: the three protocol keys, and the six orders budgets, whose spender is
        // the orders account (ADR 007, decision 18).
        (address[6] memory orderTokens, bytes32[6] memory orderKeys, uint128[6] memory orderBudgets) = _ordersBudgets();
        UniversalFactory.LaunchKey[] memory keys = new UniversalFactory.LaunchKey[](9);
        keys[0] = UniversalFactory.LaunchKey(Mainnet.USDS, Mainnet.SUSDS, bytes32("sky_savings_usds"));
        keys[1] = UniversalFactory.LaunchKey(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, bytes32("earn_usd_deposit"));
        keys[2] = UniversalFactory.LaunchKey(Mainnet.WSTETH, EARN_ETH_DEPOSIT_QUEUE, bytes32("earn_eth_deposit_wsteth"));
        for (uint256 i = 0; i < 6; i++) keys[3 + i] = UniversalFactory.LaunchKey(orderTokens[i], address(orders), orderKeys[i]);

        // The factory's version helpers are pure, so a scratch instance computes the seeds.
        UniversalFactory scratch = new UniversalFactory(c, keys, new UniversalFactory.Seed[](0), new UniversalFactory.CeilingSeed[](0));
        UniversalFactory.Seed[] memory seeds = new UniversalFactory.Seed[](15);
        address[5] memory tokens = [Mainnet.STETH, Mainnet.USDS, Mainnet.DAI, Mainnet.USDC, Mainnet.WSTETH];
        for (uint256 i = 0; i < tokens.length; i++) {
            seeds[i] = UniversalFactory.Seed(
                scratch.functionScope(tokens[i], IERC20.approve.selector), scratch.listVersion(launchApprovals(tokens[i]))
            );
        }
        seeds[5] = _budgetSeed(scratch, bytes32("sky_savings_usds"), SKY_SAVINGS_USDS);
        seeds[6] = _budgetSeed(scratch, bytes32("earn_usd_deposit"), EARN_USD_DEPOSIT);
        seeds[7] = _budgetSeed(scratch, bytes32("earn_eth_deposit_wsteth"), EARN_ETH_DEPOSIT_WSTETH);
        for (uint256 i = 0; i < 6; i++) seeds[8 + i] = _budgetSeed(scratch, orderKeys[i], orderBudgets[i]);
        // the orders account's two token lists, as the enabling vote writes them (ADR 007, decisions 15 and 22)
        seeds[14] = UniversalFactory.Seed(scratch.ORDERS_SCOPE(), scratch.ordersVersion(launchOrderTokens(), launchRecoveryTokens()));

        UniversalFactory.CeilingSeed[] memory caps = new UniversalFactory.CeilingSeed[](9);
        uint8 budget = scratch.BUDGET_CEILING();
        uint8 cap = scratch.APPROVAL_CAP_CEILING();
        caps[0] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.USDC), BUDGET_CEILING_USDC);
        caps[1] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.USDS), BUDGET_CEILING_USDS);
        caps[2] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.WSTETH), BUDGET_CEILING_WSTETH);
        caps[3] = UniversalFactory.CeilingSeed(scratch.ceilingKey(cap, Mainnet.STETH), SIZE_STANDIN_STETH);
        caps[4] = UniversalFactory.CeilingSeed(scratch.ceilingKey(cap, Mainnet.DAI), SIZE_STANDIN_USD);
        caps[5] = UniversalFactory.CeilingSeed(scratch.ceilingKey(cap, Mainnet.USDS), SIZE_STANDIN_USD);
        caps[6] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.STETH), BUDGET_CEILING_STETH);
        caps[7] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.WETH), BUDGET_CEILING_WETH);
        caps[8] = UniversalFactory.CeilingSeed(scratch.ceilingKey(budget, Mainnet.USDT), BUDGET_CEILING_USDT);

        vm.prank(deployer);
        uf = new UniversalFactory(c, keys, seeds, caps);
        assertEq(address(uf), vm.computeCreateAddress(deployer, 0), "the deployer's first creation");
    }

    /// @dev The orders budgets of the launch policy (policy/constellation/constellation/allowances).
    function _ordersBudgets() internal pure returns (address[6] memory tokens, bytes32[6] memory keys, uint128[6] memory perMonth) {
        tokens = [Mainnet.STETH, Mainnet.WSTETH, Mainnet.WETH, Mainnet.USDC, Mainnet.USDT, Mainnet.USDS];
        keys = [
            bytes32("orders_steth"), bytes32("orders_wsteth"), bytes32("orders_weth"),
            bytes32("orders_usdc"), bytes32("orders_usdt"), bytes32("orders_usds")
        ];
        perMonth = [ORDERS_ETH_TOKEN, ORDERS_ETH_TOKEN, ORDERS_ETH_TOKEN, ORDERS_USD6, ORDERS_USD6, ORDERS_USDS];
    }

    /// @dev The operator's order tokens at launch, sorted as the SDK sorts them (ADR 007, decision 22).
    function launchOrderTokens() public pure returns (address[] memory t) {
        t = new address[](6);
        (t[0], t[1], t[2], t[3], t[4], t[5]) =
            (Mainnet.WSTETH, Mainnet.USDC, Mainnet.STETH, Mainnet.WETH, Mainnet.USDT, Mainnet.USDS);
    }

    /// @dev What a recovery order sells at launch, sorted as the SDK sorts them (ADR 007, decision 15).
    function launchRecoveryTokens() public pure returns (address[] memory t) {
        t = new address[](8);
        (t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]) = (
            Mainnet.DAI, Mainnet.WSTETH, Mainnet.USDC, Mainnet.SUSDS, Mainnet.STETH, Mainnet.WETH, Mainnet.USDT, Mainnet.USDS
        );
    }

    function _budgetSeed(UniversalFactory f, bytes32 key, uint128 perMonth) internal pure returns (UniversalFactory.Seed memory) {
        return UniversalFactory.Seed(f.allowanceScope(key), f.budgetVersion(perMonth, perMonth, perMonth, MONTH));
    }

    /// @dev The operator's approval list of a token at launch, sorted by spender: the
    ///      same entries as APPROVALS in policy/constellation/constellation/roles/operator.
    function launchApprovals(address token) public pure returns (UniversalFactory.Entry[] memory e) {
        if (token == Mainnet.STETH) {
            e = new UniversalFactory.Entry[](1);
            e[0] = UniversalFactory.Entry(Mainnet.WSTETH, bytes32(0), SIZE_STANDIN_STETH);
        } else if (token == Mainnet.USDS) {
            e = new UniversalFactory.Entry[](2);
            e[0] = UniversalFactory.Entry(DAI_USDS, bytes32(0), SIZE_STANDIN_USD);
            e[1] = UniversalFactory.Entry(Mainnet.SUSDS, bytes32("sky_savings_usds"), 0);
        } else if (token == Mainnet.DAI) {
            e = new UniversalFactory.Entry[](1);
            e[0] = UniversalFactory.Entry(DAI_USDS, bytes32(0), SIZE_STANDIN_USD);
        } else if (token == Mainnet.USDC) {
            e = new UniversalFactory.Entry[](1);
            e[0] = UniversalFactory.Entry(Mainnet.EARN_USD_DEPOSIT_QUEUE, bytes32("earn_usd_deposit"), 0);
        } else if (token == Mainnet.WSTETH) {
            e = new UniversalFactory.Entry[](1);
            e[0] = UniversalFactory.Entry(EARN_ETH_DEPOSIT_QUEUE, bytes32("earn_eth_deposit_wsteth"), 0);
        }
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
        assertEq(vm.parseJsonAddress(m, ".ordersAccount"), address(orders), "manifest: orders account");
        assertEq(vm.parseJsonAddress(m, ".ordersModifier"), address(ordersMod), "manifest: orders modifier");
    }

    function _cold(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) vm.cool(accounts[i]);
    }
}
