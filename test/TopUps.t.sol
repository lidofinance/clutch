// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {IEasyTrack, IFinance, IRecipientsRegistry} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @title TopUps — top-up motions from the treasury to the Asset Safe, with Lido's existing top-up tooling in new
///        instances, on the vault that the enabling vote sets up (ADR 014, decisions 13 to 17).
/// @dev Two registries list the Asset Safe as their only recipient: one for stETH, and one for the tokens of the
///      DAO's stablecoin list, which are DAI, USDC, USDT and sUSDS (OD-141). Aragon Voting is each registry's admin,
///      so a change of a limit passes no Dual Governance. The committee's Safe is the trusted caller of both top-up
///      factories, and the enabling vote registers them (OD-142). A period is three calendar months (OD-143). The
///      fixture's first top-up already spent a part of each limit. Both limits are stand-ins.
///      Run: RPC=<archive RPC> forge test --match-contract TopUps -vv
contract TopUps is EnabledVault {
    /// @dev The Easy Track executor's ceiling on one payment, in Finance's payment permission (chain reads of
    ///      2026-09-30).
    uint256 internal constant STETH_PER_PAYMENT = 1_000e18;
    uint256 internal constant USDC_PER_PAYMENT = 2_000_000e6;

    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote registers the two top-up factories, and the first top-up comes by two motions.
    modifier withTopUps() {
        _enable();
        _;
    }

    /// @dev The enabling vote registers both factories with their two calls each, and pays nothing. The launch
    ///      top-up then comes by two motions, and each registry counts its part.
    function test_topup_the_enabling_vote_registers_the_factories_and_the_first_top_up_is_two_motions() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertTrue(et.isEVMScriptFactory(stethTopUp) && et.isEVMScriptFactory(stableTopUp), "both factories are registered");
        assertEq(
            et.evmScriptFactoryPermissions(stethTopUp),
            abi.encodePacked(
                VoteBuilder.permission(stethRegistry, IRecipientsRegistry.updateSpentAmount.selector),
                VoteBuilder.permission(Mainnet.FINANCE, IFinance.newImmediatePayment.selector)
            ),
            "the stETH factory calls its registry and Finance's payment, and nothing else"
        );
        assertEq(
            et.evmScriptFactoryPermissions(stableTopUp),
            abi.encodePacked(
                VoteBuilder.permission(stableRegistry, IRecipientsRegistry.updateSpentAmount.selector),
                VoteBuilder.permission(Mainnet.FINANCE, IFinance.newImmediatePayment.selector)
            ),
            "the stablecoin factory calls its registry and Finance's payment, and nothing else"
        );
        (uint256 limit, uint256 months) = IRecipientsRegistry(stableRegistry).getLimitParameters();
        assertEq(limit, TOPUP_STABLE_LIMIT, "the stablecoin limit");
        assertEq(months, TOPUP_PERIOD_MONTHS, "a period of three months");
        (, months) = IRecipientsRegistry(stethRegistry).getLimitParameters();
        assertEq(months, TOPUP_PERIOD_MONTHS, "a period of three months");
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), TOPUP_STABLE_LIMIT - 500_000e18, "the first top-up's USDC counts");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), TOPUP_STETH_LIMIT - FIRST_TOPUP_STETH, "the first top-up's stETH counts");
    }

    /// @dev One motion of the committee's Safe pays stETH from the treasury to the Asset Safe after the objection
    ///      window, and the registry counts it against the period's limit.
    function test_topup_steth_motion_pays_the_asset_safe() public withTopUps {
        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        uint256 agent = IERC20(Mainnet.STETH).balanceOf(Mainnet.AGENT);
        uint256 spendable = IRecipientsRegistry(stethRegistry).spendableBalance();
        uint256 gasUsed = _topUp(stethTopUp, _stethCall(_one(address(asset)), _one(400e18)));
        console2.log("TOPUP stETH, one payment: enactMotion gas", gasUsed);
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, 400e18, 2, "the Asset Safe receives the top-up");
        assertApproxEqAbs(agent - IERC20(Mainnet.STETH).balanceOf(Mainnet.AGENT), 400e18, 2, "the Aragon Agent pays it");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), spendable - 400e18, "the registry counts the top-up");
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
    ///      next period has the whole limit again. A period starts on the first day of a calendar month.
    function test_topup_registry_limit_holds_for_a_period() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 left = IRecipientsRegistry(stethRegistry).spendableBalance();
        (address[] memory to, uint256[] memory amounts) = _payments(left + 1);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("SUM_EXCEEDS_SPENDABLE_BALANCE"));
        et.createMotion(stethTopUp, _stethCall(to, amounts));
        (to, amounts) = _payments(left);
        _topUp(stethTopUp, _stethCall(to, amounts));
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), 0, "the period's limit is spent");
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("SUM_EXCEEDS_SPENDABLE_BALANCE"));
        et.createMotion(stethTopUp, _stethCall(_one(address(asset)), _one(1)));

        // after the period's end, a motion for the whole limit passes: the limit is there again
        vm.warp(block.timestamp + (TOPUP_PERIOD_MONTHS + 1) * 31 days);
        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        (to, amounts) = _payments(TOPUP_STETH_LIMIT);
        _topUp(stethTopUp, _stethCall(to, amounts));
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, TOPUP_STETH_LIMIT, 2 * to.length, "the next period pays the whole limit");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), 0, "and no more");
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
        uint256 spendable = IRecipientsRegistry(stethRegistry).spendableBalance();
        address[] memory to = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) (to[i], amounts[i]) = (address(asset), STETH_PER_PAYMENT);
        uint256 gasUsed = _topUp(stethTopUp, _stethCall(to, amounts));
        console2.log("TOPUP stETH, three payments in one motion: enactMotion gas", gasUsed);
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, 3 * STETH_PER_PAYMENT, 6, "three payments in one motion");
        assertEq(IRecipientsRegistry(stethRegistry).spendableBalance(), spendable - 3 * STETH_PER_PAYMENT, "the registry counts the three payments");
    }

    /// @dev The stablecoin factory pays each token of the DAO's stablecoin list: DAI, USDC, USDT and sUSDS (OD-141).
    ///      The registry counts each at 18 decimals, in one limit. USDS and stETH are not on the list.
    function test_topup_stablecoins_from_the_dao_list() public withTopUps {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 spendable = IRecipientsRegistry(stableRegistry).spendableBalance();
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 gasUsed = _topUp(stableTopUp, abi.encode(Mainnet.USDC, _two(address(asset)), _two(USDC_PER_PAYMENT, 1_000_000e6)));
        console2.log("TOPUP USDC, two payments in one motion: enactMotion gas", gasUsed);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - before, 3_000_000e6, "the Asset Safe receives the USDC");

        address[3] memory tokens = [Mainnet.DAI, Mainnet.USDT, Mainnet.SUSDS];
        uint256[3] memory amounts = [uint256(1_000_000e18), 1_000_000e6, 500_000e18];
        for (uint256 i = 0; i < 3; i++) {
            before = IERC20(tokens[i]).balanceOf(address(asset));
            _topUp(stableTopUp, abi.encode(tokens[i], _one(address(asset)), _one(amounts[i])));
            assertEq(IERC20(tokens[i]).balanceOf(address(asset)) - before, amounts[i], "the Asset Safe receives the listed token");
        }
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), spendable - 5_500_000e18, "each token counts at 18 decimals, in one limit");

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
    // Calldata
    // ---------------------------------------------------------------------

    /// @dev Payments to the Asset Safe that sum to `total`, each at most the executor's ceiling on one payment.
    function _payments(uint256 total) internal view returns (address[] memory to, uint256[] memory amounts) {
        uint256 n = (total + STETH_PER_PAYMENT - 1) / STETH_PER_PAYMENT;
        to = new address[](n);
        amounts = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            to[i] = address(asset);
            amounts[i] = total > STETH_PER_PAYMENT ? STETH_PER_PAYMENT : total;
            total -= amounts[i];
        }
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
