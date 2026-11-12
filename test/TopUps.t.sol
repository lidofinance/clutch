// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {IEasyTrack, IFinance} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

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

/// @title TopUps — top-up motions from the treasury to the Asset Safe, with Lido's existing top-up tooling in new
///        instances, on the vault that the enabling vote sets up (ADR 014, decision 13; OD-140).
/// @dev A probe of the mechanics, before the decisions on the limits, the periods and the vote that registers the
///      factories (OD-141 to OD-144). Two registries list the Asset Safe as their only recipient, one for stETH and
///      one for the DAO's stablecoin list. Aragon Voting is each registry's admin, so a change of a limit passes no
///      Dual Governance. The committee's Safe is the trusted caller of both top-up factories, and a vote after the
///      enabling vote registers them in the live Easy Track. Figures marked STANDIN are test values.
///      Run: RPC=<archive RPC> forge test --match-contract TopUps -vv
contract TopUps is EnabledVault {
    bytes32 internal constant ADD_RECIPIENT_ROLE = keccak256("ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE");
    bytes32 internal constant SET_PARAMETERS_ROLE = keccak256("SET_PARAMETERS_ROLE");

    /// @dev STANDIN limits of one period, and the period in months. A registry counts every token in 18 decimals.
    uint256 internal constant STETH_LIMIT = 3_000e18;
    uint256 internal constant STABLE_LIMIT = 5_000_000e18;
    uint256 internal constant PERIOD_MONTHS = 3;
    /// @dev The Easy Track executor's ceiling on one payment, in Finance's payment permission (chain reads of
    ///      2026-09-30).
    uint256 internal constant STETH_PER_PAYMENT = 1_000e18;
    uint256 internal constant USDC_PER_PAYMENT = 2_000_000e6;

    address internal stethRegistry;
    address internal stableRegistry;
    address internal stethTopUp;
    address internal stableTopUp;
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote, then the vote that registers the two top-up factories.
    modifier withTopUps() {
        _enable();
        _deployTopUps();
        _registerTopUps();
        _;
    }

    /// @dev One motion of the committee's Safe pays stETH from the treasury to the Asset Safe after the objection
    ///      window, and the registry counts it against the period's limit.
    function test_topup_steth_motion_pays_the_asset_safe() public withTopUps {
        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        uint256 agent = IERC20(Mainnet.STETH).balanceOf(Mainnet.AGENT);
        uint256 gasUsed = _topUp(stethTopUp, _stethCall(_one(address(asset)), _one(400e18)));
        console2.log("TOPUP stETH, one payment: enactMotion gas", gasUsed);
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, 400e18, 2, "the Asset Safe receives the top-up");
        assertApproxEqAbs(agent - IERC20(Mainnet.STETH).balanceOf(Mainnet.AGENT), 400e18, 2, "the Aragon Agent pays it");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), STETH_LIMIT - 400e18, "the registry counts the top-up");
    }

    /// @dev Only the committee's Safe creates a top-up motion, and only the Asset Safe receives one.
    function test_topup_only_the_committee_creates_and_only_the_asset_safe_receives() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        bytes memory cd = _stethCall(_one(address(asset)), _one(1e18));
        vm.prank(stranger);
        vm.expectRevert(bytes("CALLER_IS_FORBIDDEN"));
        et.createMotion(stethTopUp, cd);
        vm.prank(address(emergency));
        vm.expectRevert(bytes("CALLER_IS_FORBIDDEN"));
        et.createMotion(stethTopUp, cd);

        address[4] memory others = [stranger, Mainnet.COMMITTEE_SAFE, address(orders), address(firstLoss)];
        for (uint256 i = 0; i < others.length; i++) {
            vm.prank(Mainnet.COMMITTEE_SAFE);
            vm.expectRevert(bytes("RECIPIENT_NOT_ALLOWED"));
            et.createMotion(stethTopUp, _stethCall(_one(others[i]), _one(1e18)));
        }
    }

    /// @dev The registry's limit holds for a period: a motion above what is left fails at its creation, and the
    ///      next period starts with the whole limit again. A period starts on the first day of a calendar month.
    function test_topup_registry_limit_holds_for_a_period() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        _topUp(stethTopUp, _stethCall(_one(address(asset)), _one(STETH_PER_PAYMENT)));
        uint256 left = IRecipientsRegistry(stethRegistry).spendableBalance();
        assertEq(left, STETH_LIMIT - STETH_PER_PAYMENT, "what is left in the period");
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("SUM_EXCEEDS_SPENDABLE_BALANCE"));
        et.createMotion(stethTopUp, _stethCall(_two(address(asset)), _two(STETH_PER_PAYMENT, left - STETH_PER_PAYMENT + 1)));

        // after the period's end, a motion for the whole limit passes: the limit is there again
        vm.warp(block.timestamp + (PERIOD_MONTHS + 1) * 31 days);
        address[] memory to = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) (to[i], amounts[i]) = (address(asset), STETH_PER_PAYMENT);
        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        _topUp(stethTopUp, _stethCall(to, amounts));
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, STETH_LIMIT, 6, "the next period pays the whole limit");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), 0, "and no more");
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("SUM_EXCEEDS_SPENDABLE_BALANCE"));
        et.createMotion(stethTopUp, _stethCall(_one(address(asset)), _one(1)));
    }

    /// @dev The executor's payment permission caps one payment at 1,000 stETH. A motion above the cap in one
    ///      payment passes its creation and fails at its enactment. One motion carries several payments to the
    ///      Asset Safe, each within the cap, up to the registry's limit.
    function test_topup_one_motion_carries_several_payments() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        bytes memory over = _stethCall(_one(address(asset)), _one(STETH_PER_PAYMENT + 1e18));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(stethTopUp, over);
        vm.warp(block.timestamp + et.motionDuration() + 1);
        vm.prank(anyone);
        (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, over)));
        assertFalse(ok, "one payment above the executor's ceiling fails at enactment");
        vm.prank(Mainnet.COMMITTEE_SAFE);
        et.cancelMotion(id);

        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        address[] memory to = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) (to[i], amounts[i]) = (address(asset), STETH_PER_PAYMENT);
        uint256 gasUsed = _topUp(stethTopUp, _stethCall(to, amounts));
        console2.log("TOPUP stETH, three payments in one motion: enactMotion gas", gasUsed);
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, 3 * STETH_PER_PAYMENT, 6, "three payments in one motion");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), 0, "the period's limit is spent");
    }

    /// @dev The stablecoin factory pays a token of the DAO's stablecoin list, and no other token. The registry
    ///      counts a stablecoin at 18 decimals. USDS is not on the list.
    function test_topup_stablecoins_from_the_dao_list() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 gasUsed = _topUp(stableTopUp, abi.encode(Mainnet.USDC, _two(address(asset)), _two(USDC_PER_PAYMENT, 1_000_000e6)));
        console2.log("TOPUP USDC, two payments in one motion: enactMotion gas", gasUsed);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - before, 3_000_000e6, "the Asset Safe receives the USDC");
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), STABLE_LIMIT - 3_000_000e18, "USDC counts at 18 decimals");

        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("TOKEN_NOT_ALLOWED"));
        et.createMotion(stableTopUp, abi.encode(Mainnet.USDS, _one(address(asset)), _one(1e18)));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("TOKEN_NOT_ALLOWED"));
        et.createMotion(stableTopUp, abi.encode(Mainnet.STETH, _one(address(asset)), _one(1e18)));
    }

    /// @dev Aragon Voting is each registry's admin and the only holder of its limit and recipient roles. The
    ///      Aragon Agent holds none, so a change of a limit is a vote without Dual Governance. The deployer and the
    ///      committee's Safe hold none.
    function test_topup_only_voting_changes_a_limit_or_a_recipient() public withTopUps {
        address[2] memory registries = [stethRegistry, stableRegistry];
        for (uint256 i = 0; i < 2; i++) {
            IRecipientsRegistry r = IRecipientsRegistry(registries[i]);
            assertTrue(r.hasRole(bytes32(0), Mainnet.VOTING), "the admin is Aragon Voting");
            address[4] memory others = [Mainnet.AGENT, deployer, Mainnet.COMMITTEE_SAFE, address(emergency)];
            for (uint256 k = 0; k < others.length; k++) {
                assertFalse(r.hasRole(bytes32(0), others[k]), "no other admin");
                assertFalse(r.hasRole(SET_PARAMETERS_ROLE, others[k]), "no other holder of the limit");
                assertFalse(r.hasRole(ADD_RECIPIENT_ROLE, others[k]), "no other holder of the recipients");
                vm.prank(others[k]);
                (bool ok,) = address(r).call(abi.encodeCall(IRecipientsRegistry.setLimitParameters, (type(uint128).max, 1)));
                assertFalse(ok, "only Aragon Voting sets a limit");
                vm.prank(others[k]);
                (ok,) = address(r).call(abi.encodeCall(IRecipientsRegistry.addRecipient, (stranger, "stranger")));
                assertFalse(ok, "only Aragon Voting adds a recipient");
            }
            vm.prank(Mainnet.VOTING);
            r.setLimitParameters(1e18, 1);
            (uint256 limit, uint256 months) = r.getLimitParameters();
            assertEq(limit, 1e18, "Aragon Voting set the limit");
            assertEq(months, 1, "Aragon Voting set the period");
        }
    }

    // ---------------------------------------------------------------------
    // Deployment and registration
    // ---------------------------------------------------------------------

    /// @dev The registries and the top-up factories, from Lido's deployed factories. The deployer adds the Asset
    ///      Safe and sets each limit, then gives up its roles.
    function _deployTopUps() internal {
        vm.startPrank(deployer);
        stethRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_SINGLE, STETH_LIMIT);
        stableRegistry = _registry(Mainnet.RECIPIENTS_FACTORY_MULTI, STABLE_LIMIT);
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
        IRecipientsRegistry(reg).setLimitParameters(limit, PERIOD_MONTHS);
        IRecipientsRegistry(reg).renounceRole(ADD_RECIPIENT_ROLE, deployer);
        IRecipientsRegistry(reg).renounceRole(SET_PARAMETERS_ROLE, deployer);
    }

    /// @dev One Aragon vote registers both factories in Easy Track. Each may call its own registry's
    ///      `updateSpentAmount` and Finance's `newImmediatePayment`, and nothing else.
    function _registerTopUps() internal {
        VoteBuilder.Item[] memory items = new VoteBuilder.Item[](2);
        items[0] = _register(stethTopUp, stethRegistry, "Easy Track: register the stETH top-up factory");
        items[1] = _register(stableTopUp, stableRegistry, "Easy Track: register the stablecoin top-up factory");
        (bool ok,,) = _newVote(VoteBuilder.script(items));
        assertTrue(ok, "the vote that registers the top-up factories starts");
        _passAndExecute();
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertTrue(et.isEVMScriptFactory(stethTopUp) && et.isEVMScriptFactory(stableTopUp), "both factories are registered");
    }

    function _register(address factory, address registry, string memory label) internal pure returns (VoteBuilder.Item memory) {
        bytes memory permissions = abi.encodePacked(
            VoteBuilder.permission(registry, IRecipientsRegistry.updateSpentAmount.selector),
            VoteBuilder.permission(Mainnet.FINANCE, IFinance.newImmediatePayment.selector)
        );
        return VoteBuilder.Item(Mainnet.EASY_TRACK, abi.encodeCall(IEasyTrack.addEVMScriptFactory, (factory, permissions)), label);
    }

    // ---------------------------------------------------------------------
    // A top-up motion
    // ---------------------------------------------------------------------

    /// @dev The committee's Safe creates the motion, and anyone enacts it after the objection window.
    function _topUp(address factory, bytes memory cd) internal returns (uint256 gasUsed) {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(factory, cd);
        vm.warp(block.timestamp + et.motionDuration() + 1);
        vm.prank(anyone);
        uint256 g = gasleft();
        et.enactMotion(id, cd);
        gasUsed = g - gasleft();
        assertLt(gasUsed, TX_GAS_CAP, "under EIP-7825's cap");
    }

    function _stethCall(address[] memory to, uint256[] memory amounts) internal pure returns (bytes memory) {
        return abi.encode(to, amounts);
    }

    function _one(address a) internal pure returns (address[] memory r) {
        r = new address[](1);
        r[0] = a;
    }

    function _one(uint256 a) internal pure returns (uint256[] memory r) {
        r = new uint256[](1);
        r[0] = a;
    }

    function _two(address a) internal pure returns (address[] memory r) {
        r = new address[](2);
        (r[0], r[1]) = (a, a);
    }

    function _two(uint256 a, uint256 b) internal pure returns (uint256[] memory r) {
        r = new uint256[](2);
        (r[0], r[1]) = (a, b);
    }
}
