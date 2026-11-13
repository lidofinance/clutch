// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {ITokenManager, IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";

/// @title EnablingVoteRehearsal — the enabling vote and the first weeks of
///        operation, rehearsed end to end on a mainnet fork.
/// @dev The live Aragon Voting, token manager, Easy Track, script executor,
///      Aragon Finance and treasury take part. Only the Clutch accounts and
///      the universal factory are new; the two top-up factories are new
///      instances of Lido's own code. The vote registers the three factories and
///      pays nothing, and the launch tranche comes by top-up motions (OD-102,
///      OD-142; enabling-vote spec). Lines that start with "REHEARSAL" are the
///      measurements that the research notes report.
///      Run: RPC=<archive RPC> forge test --match-contract EnablingVoteRehearsal -vv
contract EnablingVoteRehearsal is EnabledVault {
    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    // ---------------------------------------------------------------------
    // 0. The manifest that the policy compiles against
    // ---------------------------------------------------------------------

    function test_00_manifest_matches_the_deployment() public {
        if (vm.envOr("REHEARSAL_WRITE_MANIFEST", false)) {
            // the manifests folder is read-only for tests; move the file there
            vm.writeJson(_manifestJson(), "./rehearsal-manifest.json");
            return;
        }
        _checkManifest();
    }

    // ---------------------------------------------------------------------
    // 1. The vote as the spec first described it: the Safe batches inside the vote
    // ---------------------------------------------------------------------

    /// @dev Aragon Voting stores the whole script at `newVote` and runs it in
    ///      one transaction at `executeVote`. With the policy inside, the
    ///      script is too large for one transaction under EIP-7825.
    function test_01_a_vote_that_carries_the_policy_cannot_be_created() public {
        _buildBatches();
        vm.pauseGasMetering();
        bytes memory voteScript = VoteBuilder.script(_voteItems(true));
        vm.resumeGasMetering();
        console2.log("REHEARSAL direct vote: script bytes", voteScript.length);
        _proposer();
        uint256 snap = vm.snapshotState();
        (bool ok,, bytes memory txData) = _newVote(voteScript);
        console2.log("REHEARSAL direct vote: newVote calldata bytes", txData.length);
        assertFalse(ok, "a vote that stores the policy must not fit in one transaction");
        // Until the orders policy, the size alone passed the txpool and only the gas cap stopped the vote. With
        // it, the vote's calldata passes the txpool's limit too (ADR 007).
        console2.log("REHEARSAL direct vote: above the txpool's size limit (1 = yes)", txData.length > TX_SIZE_LIMIT ? 1 : 0);
        // The gas that newVote needs without the cap
        vm.revertToState(snap);
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory fwd = new VoteBuilder.Item[](1);
        fwd[0] = VoteBuilder.Item(
            Mainnet.VOTING, abi.encodeWithSignature("newVote(bytes,string)", voteScript, "Clutch enabling vote, rehearsal"), ""
        );
        bytes memory data = abi.encodeCall(ITokenManager.forward, (VoteBuilder.script(fwd)));
        (uint256 std,) = VoteBuilder.intrinsicGas(data);
        vm.resumeGasMetering();
        _coolGovernance();
        vm.prank(proposer);
        uint256 g = gasleft();
        (bool okUncapped,) = Mainnet.TOKEN_MANAGER.call(data);
        uint256 need = g - gasleft() + std;
        assertTrue(okUncapped, "without the cap it would pass");
        console2.log("REHEARSAL direct vote: newVote gas without the cap", need);
        console2.log("REHEARSAL direct vote: the cap", TX_GAS_CAP);
        assertGt(need, TX_GAS_CAP);
    }

    // ---------------------------------------------------------------------
    // 2. The vote that fits: the three factories, then hash approvals; the launch tranche by motion
    // ---------------------------------------------------------------------

    /// @dev The vote registers the universal factory with its address book and
    ///      the two top-up factories, and pays nothing. After the batches, the
    ///      launch tranche reaches the Asset Safe by two top-up motions (checked
    ///      in `_enable`).
    function test_02_enabling_vote_end_to_end() public {
        _enable();
        _checkEnabled();
    }

    // ---------------------------------------------------------------------
    // 3. The first weeks: a top-up, budgets, the switch, the counter, the restart
    // ---------------------------------------------------------------------

    function test_03_ramp_up() public {
        _enable();

        // 3a. The Growth Committee moves the first-loss shares (ADR 008).
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        _moveFirstLossShare(Mainnet.EARN_USD_SHARE, "earnUSD");

        // 3b. Easy Track's motion slots are shared by every committee.
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        console2.log("REHEARSAL motion slots: limit", et.motionsCountLimit());
        console2.log("REHEARSAL motion slots: open at the fork block", et.getMotions().length);

        // 3c. A later top-up in another token, by its own motion (ADR 014, decisions 13 and 15). USDS is on no
        //     top-up list, so the vault gets it as DAI, which the operator converts through Sky's converter.
        _topUp(stableTopUp, abi.encode(Mainnet.DAI, _recipient(), _amount(5_000e18))); // STANDIN
        assertEq(IERC20(Mainnet.DAI).balanceOf(address(asset)), 5_000e18, "a later top-up in DAI");
        _operator(Mainnet.DAI, abi.encodeCall(IERC20.approve, (DAI_USDS, 5_000e18)), true);
        _operator(DAI_USDS, abi.encodeWithSignature("daiToUsds(address,uint256)", address(asset), 5_000e18), true);
        assertEq(IERC20(Mainnet.USDS).balanceOf(address(asset)), 5_000e18, "the DAI became USDS, one to one");

        // 3d. Budgets set the pace: an approval spends the key (OD-08).
        (,,, uint128 earnBudget,) = opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL earn_usd_deposit budget at launch (STANDIN, USDC units)", uint256(earnBudget));
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, earnBudget)), true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 1e6)), false);

        // 3e. A budget motion of the universal factory: one write of the governance role sets the key.
        _motion(_one(_budgetKey(bytes32("earn_usd_deposit"), 400_000e6)));
        (uint128 refill, uint128 maxRefill, uint64 period, uint128 balance,) = opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL budget motion: balance after enactment", uint256(balance));
        console2.log("REHEARSAL budget motion: refill, period", uint256(refill), uint256(period));
        assertEq(maxRefill, 400_000e6);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 300_000e6)), true);

        // 3f. A motion that was open when the emergency stop came fails at enactment (ADR 013, decision 5).
        bytes memory open = _calldata(_one(_budgetKey(bytes32("earn_usd_deposit"), 500_000e6)));
        uint256 openId = _create(open);

        // 3g. The switch, and the counter that it raises.
        _emergencySwitch();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("GS104"));
        opMod.execTransactionWithRole(Mainnet.USDC, 0, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), 0, OPERATOR, true);

        _afterWindow();
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        et.enactMotion(openId, open);
        console2.log("REHEARSAL the counter: a motion that was open at the switch fails at enactment");

        // 3h. A restart motion enables the operator modifier again (ADR 013, decision 12).
        _motion(_one(_w(safetyMod, bytes32("restart"), address(asset), abi.encodeWithSignature("enableModule(address)", address(opMod)))));
        assertTrue(asset.isModuleEnabled(address(opMod)), "the restart motion");
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), true);
    }

    // ---------------------------------------------------------------------
    // 4. Where the money can go at launch: Lido Earn deposits
    // ---------------------------------------------------------------------

    /// @dev The Roles layer allows the deposits (Drills D3b); this asks
    ///      whether the live queues accept them from a new Safe. The first
    ///      tranche holds the USDC and the stETH.
    function test_04_earn_deposits_from_the_asset_safe() public {
        _enable();
        // Budgets wide enough for the probe, set by the owner path (Voting via the Asset Safe)
        vm.startPrank(address(asset));
        opMod.setAllowance(bytes32("earn_usd_deposit"), 200_000e6, 200_000e6, 200_000e6, 30 days, 0);
        opMod.setAllowance(bytes32("earn_eth_deposit_wsteth"), 100e18, 100e18, 100e18, 30 days, 0);
        vm.stopPrank();

        // earnUSD: USDC into the deposit queue
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 100_000e6)), true);
        bytes32[] memory noProof = new bytes32[](0);
        _probe(
            "earnUSD deposit of 100,000 USDC",
            Mainnet.EARN_USD_DEPOSIT_QUEUE,
            abi.encodeWithSignature("deposit(uint224,address,bytes32[])", uint224(100_000e6), address(0), noProof)
        );

        // earnETH: stETH -> wstETH under the fixed ceiling, then into the queue
        // the stETH approval to wstETH has a ceiling: 10 stETH at dry-run scale (STANDIN)
        uint256 st = 9e18;
        _operator(Mainnet.STETH, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, st)), true);
        _operator(Mainnet.WSTETH, abi.encodeWithSignature("wrap(uint256)", st), true);
        uint256 w = IERC20(Mainnet.WSTETH).balanceOf(address(asset));
        _operator(Mainnet.WSTETH, abi.encodeCall(IERC20.approve, (EARN_ETH_DEPOSIT_QUEUE, w)), true);
        _probe(
            "earnETH deposit of the wrapped stETH",
            EARN_ETH_DEPOSIT_QUEUE,
            abi.encodeWithSignature("deposit(uint224,address,bytes32[])", uint224(w), address(0), noProof)
        );
    }

    // ---------------------------------------------------------------------
    // 4b. The published Safe batches, for the command that computes each hash again
    // ---------------------------------------------------------------------

    /// @dev The vote approves the hash of each Safe batch (OD-92), so the batches are published before it. This
    ///      test writes them to `.batches/`, each with the hash that its Safe computes, and then runs the vote and
    ///      the batches, so the file holds batches that execute. `just test-fork` then runs the command, which
    ///      computes each hash again and checks each batch's calls against the policy.
    function test_06_safe_batches_are_written_for_the_hash_command() public {
        _buildBatches();
        _writeBatches(".batches", "rehearsal-26249900.json");
        _voteAndRunBatches();
        _checkEnabled();
    }

    // ---------------------------------------------------------------------
    // 5. The first-loss Safe: a burn by motion and a redemption request
    // ---------------------------------------------------------------------

    /// @dev The enabling vote's first-loss batch applies the first-loss policy
    ///      (ADR 008, decisions 21 and 23). The probe asks whether the share
    ///      tokens accept its two actions from the first-loss Safe.
    function test_05_first_loss_burn_and_redemption_request() public {
        _enable();
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        _moveFirstLossShare(Mainnet.EARN_USD_SHARE, "earnUSD");

        uint256 before = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        vm.prank(address(uf));
        firstLossMod.execTransactionWithRole(
            Mainnet.EARN_ETH_SHARE, 0, abi.encodeWithSignature("burn(uint256)", 10e18), 0, FIRST_LOSS_BURN, true
        );
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), before - 10e18, "the burn by the factory's role");
        console2.log("REHEARSAL first-loss burn of 10 earnETH shares by the universal factory's role: done");

        // The committee's role asks for a redemption; the queue takes the shares.
        uint256 usdBefore = IERC20(Mainnet.EARN_USD_SHARE).balanceOf(address(firstLoss));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        firstLossMod.execTransactionWithRole(
            EARN_USD_REDEEM_QUEUE, 0, abi.encodeWithSignature("redeem(uint256)", 1_000e18), 0, FIRST_LOSS, true
        );
        assertEq(IERC20(Mainnet.EARN_USD_SHARE).balanceOf(address(firstLoss)), usdBefore - 1_000e18, "the redemption request");
        console2.log("REHEARSAL first-loss redemption request of 1,000 earnUSD shares by the committee's role: done");
    }

    function _probe(string memory what, address to, bytes memory data) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok, bytes memory ret) =
            address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
        console2.log(string.concat("REHEARSAL ", what, ": done (1 = yes)"), ok ? 1 : 0);
        if (!ok) console2.logBytes(ret);
    }
}
