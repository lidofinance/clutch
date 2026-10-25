// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {
    RehearsalBase,
    IVoting,
    ITokenManager,
    IACL,
    IFinance,
    IEasyTrack,
    IRecipientsRegistry,
    IAllowedTokensRegistry,
    ISafeAdmin,
    IExtensibleFallbackHandler,
    ISettlement
} from "./rehearsal/RehearsalBase.sol";

interface IPausableToken {
    function pauser() external view returns (address);
    function paused() external view returns (bool);
    function pause() external;
    function unpause() external;
}

interface IEasyTrackActions {
    function cancelMotion(uint256 motionId) external;
    function objectToMotion(uint256 motionId) external;
}

interface ILdoSnapshots {
    function balanceOfAt(address account, uint256 blockNumber) external view returns (uint256);
    function totalSupplyAt(uint256 blockNumber) external view returns (uint256);
}

/// @title EnablingVoteRehearsal — the enabling vote and the first weeks of
///        operation, rehearsed end to end on a mainnet fork.
/// @dev The live Aragon Voting, token manager, Easy Track, script executor,
///      Aragon Finance, ACL and treasury take part. Only the Clutch accounts,
///      registries and factories are new. Lines that start with "REHEARSAL"
///      are the measurements that docs/research/enabling-vote-rehearsal-2026-10-15.md
///      reports. Run: RPC=<archive RPC> forge test --match-contract EnablingVoteRehearsal -vv
contract EnablingVoteRehearsal is RehearsalBase {
    struct Batch {
        ISafe safe;
        bytes data; // multiSend(bytes) calldata
        bytes32 hash;
        uint256 calls;
        string label;
    }

    Batch[] internal batches;
    address internal proposer;

    /// @dev The sum of the measured gas of the calls in one Safe batch. The
    ///      Safe, MultiSend and calldata overheads come on top, and each
    ///      executed batch is then checked against the cap itself.
    uint256 internal constant BATCH_CALL_GAS_BUDGET = 12_000_000;

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFunding();
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
    // 1. The vote as the spec describes it: the Safe batches inside the vote
    // ---------------------------------------------------------------------

    /// @dev Aragon Voting stores the whole script at `newVote` and runs it in
    ///      one transaction at `executeVote`. With the policy inside, the
    ///      script is too large for one transaction under EIP-7825.
    function test_01_a_vote_that_carries_the_policy_cannot_be_created() public {
        _buildBatches();
        vm.pauseGasMetering();
        bytes memory voteScript = VoteBuilder.script(_voteItems(true, true));
        vm.resumeGasMetering();
        console2.log("REHEARSAL direct vote: script bytes", voteScript.length);
        _proposer();
        uint256 snap = vm.snapshotState();
        (bool ok, uint256 gasUsed, bytes memory txData) = _newVote(voteScript);
        console2.log("REHEARSAL direct vote: newVote calldata bytes", txData.length);
        assertFalse(ok, "a vote that stores the policy must not fit in one transaction");
        assertLe(txData.length, TX_SIZE_LIMIT, "its size alone would pass the txpool");
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
        gasUsed;
    }

    // ---------------------------------------------------------------------
    // 2. The vote that fits: hash approvals, then batches that anyone runs
    // ---------------------------------------------------------------------

    function test_02_enabling_vote_end_to_end() public {
        _enable();
        _checkEnabled();
    }

    // ---------------------------------------------------------------------
    // 3. The first weeks: first-loss shares, seed, top-ups, budgets, the switch
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

        // 3c. The seed and the first top-ups, through the live Easy Track and Finance.
        uint256 usdc = 500_000e6; // STANDIN, under the launch cap (OD-55)
        _topUp(stableTopUp, Mainnet.USDC, usdc);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), usdc, "seed in USDC");
        _topUp(stethTopUp, Mainnet.STETH, 100e18); // STANDIN
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)), 100e18, 2, "stETH top-up");
        console2.log("REHEARSAL stable registry: spendable after the seed", IRecipientsRegistry(stableRegistry).spendableBalance());

        // 3d. USDS: the token list and the payment permission accept it after
        //     the vote, but the Agent holds no USDS. The fork gives it some.
        console2.log("REHEARSAL Agent USDS before the fork deal", IERC20(Mainnet.USDS).balanceOf(Mainnet.AGENT));
        deal(Mainnet.USDS, Mainnet.AGENT, 100_000e18);
        _topUp(stableTopUp, Mainnet.USDS, 50_000e18);
        assertEq(IERC20(Mainnet.USDS).balanceOf(address(asset)), 50_000e18, "USDS top-up after the vote");

        // 3e. Budgets set the pace: an approval spends the key (OD-08).
        (,,, uint128 earnBudget,) = opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL earn_usd_deposit budget at launch (STANDIN, USDC units)", uint256(earnBudget));
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, earnBudget)), true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 1e6)), false);

        // 3f. A budget motion through the live Easy Track, its executor and the
        //     governance role (stand-in factory; the real one is not built).
        bytes memory cd = abi.encode(bytes32("earn_usd_deposit"), uint128(400_000e6), uint128(400_000e6), uint128(400_000e6), uint64(30 days));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(address(budgetFactory), cd);
        vm.warp(block.timestamp + et.motionDuration() + 1);
        vm.prank(anyone);
        et.enactMotion(id, cd);
        (uint128 refill, uint128 maxRefill, uint64 period, uint128 balance, uint64 timestamp) =
            opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL budget motion: balance after enactment", uint256(balance));
        console2.log("REHEARSAL budget motion: refill, period", uint256(refill), uint256(period));
        console2.log("REHEARSAL budget motion: stored timestamp", uint256(timestamp));
        assertEq(maxRefill, 400_000e6);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 300_000e6)), true);

        // 3g. The switch: the emergency Safe disables the operator modifier.
        _emergencySwitch();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("GS104"));
        opMod.execTransactionWithRole(Mainnet.USDC, 0, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), 0, OPERATOR, true);
    }

    function test_MAIN09_paused_usdc_topup_rolls_back_and_retries() public {
        _enable();
        address[] memory recipients = new address[](1); recipients[0] = address(asset);
        uint256[] memory amounts = new uint256[](1); amounts[0] = 1e6;
        bytes memory data = abi.encode(Mainnet.USDC, recipients, amounts);
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 openBefore = et.getMotions().length;
        uint256 safeBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 registryBefore = IRecipientsRegistry(stableRegistry).spendableBalance();
        vm.prank(Mainnet.COMMITTEE_SAFE); uint256 id = et.createMotion(stableTopUp, data);
        assertEq(et.getMotions().length, openBefore + 1);
        vm.warp(block.timestamp + et.motionDuration() + 1);

        IPausableToken token = IPausableToken(Mainnet.USDC);
        address pauser = token.pauser(); assertTrue(pauser != address(0)); assertFalse(token.paused());
        vm.prank(pauser); token.pause(); assertTrue(token.paused());
        IEasyTrack.Motion[] memory motionsBefore = et.getMotions();
        (bool ok, bytes memory reason) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, data)));
        assertFalse(ok); assertEq(bytes4(reason), bytes4(keccak256("Error(string)")));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore);
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), registryBefore);
        IEasyTrack.Motion[] memory motionsAfter = et.getMotions();
        assertEq(motionsAfter.length, motionsBefore.length); assertEq(motionsAfter[motionsAfter.length - 1].id, id);

        vm.prank(pauser); token.unpause(); assertFalse(token.paused());
        vm.prank(anyone); et.enactMotion(id, data);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore + 1e6);
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), registryBefore - 1e18);
        assertEq(et.getMotions().length, openBefore);
    }

    function test_MAIN09_topup_factory_rejects_untrusted_creator_and_recipient() public {
        _enable();
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 openBefore = et.getMotions().length;
        bytes memory validData = _stableTopUpData(1e6, address(asset));
        vm.expectRevert(bytes("CALLER_IS_FORBIDDEN"));
        vm.prank(anyone);
        et.createMotion(stableTopUp, validData);

        bytes memory unlistedRecipient = _stableTopUpData(1e6, anyone);
        vm.expectRevert(bytes("RECIPIENT_NOT_ALLOWED"));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        et.createMotion(stableTopUp, unlistedRecipient);
        assertEq(et.getMotions().length, openBefore);
    }

    function test_MAIN09_registry_limit_changes_require_voting_role() public {
        _enable();
        IRecipientsRegistry registry = IRecipientsRegistry(stableRegistry);
        (uint256 limit, uint256 months) = registry.getLimitParameters();
        assertTrue(registry.hasRole(SET_PARAMETERS_ROLE, Mainnet.VOTING));
        assertFalse(registry.hasRole(SET_PARAMETERS_ROLE, anyone));
        (bool ok, bytes memory reason) = address(registry).call(
            abi.encodeCall(IRecipientsRegistry.setLimitParameters, (limit + 1, months))
        );
        assertFalse(ok);
        assertEq(bytes4(reason), bytes4(keccak256("Error(string)")));
        (uint256 unchangedLimit, uint256 unchangedMonths) = registry.getLimitParameters();
        assertEq(unchangedLimit, limit);
        assertEq(unchangedMonths, months);
        vm.prank(Mainnet.VOTING);
        registry.setLimitParameters(limit, months);
    }

    function test_MAIN09_topup_creator_can_cancel_before_enactment() public {
        _enable();
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        IEasyTrackActions actions = IEasyTrackActions(Mainnet.EASY_TRACK);
        uint256 openBefore = et.getMotions().length;
        bytes memory data = _stableTopUpData(1e6, address(asset));
        uint256 safeBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 registryBefore = IRecipientsRegistry(stableRegistry).spendableBalance();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(stableTopUp, data);

        vm.expectRevert(bytes("NOT_CREATOR"));
        vm.prank(anyone);
        actions.cancelMotion(id);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        actions.cancelMotion(id);
        assertEq(et.getMotions().length, openBefore);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore);
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), registryBefore);
        vm.expectRevert(bytes("MOTION_NOT_FOUND"));
        vm.prank(anyone);
        et.enactMotion(id, data);
    }

    function test_MAIN09_late_lido_objection_rejects_topup_without_payment() public {
        _enable();
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        IEasyTrackActions actions = IEasyTrackActions(Mainnet.EASY_TRACK);
        uint256 openBefore = et.getMotions().length;
        vm.prank(Mainnet.AGENT);
        IERC20(Mainnet.LDO).transfer(anyone, 10_000_000e18);
        bytes memory data = _stableTopUpData(1e6, address(asset));
        uint256 safeBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 registryBefore = IRecipientsRegistry(stableRegistry).spendableBalance();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(stableTopUp, data);
        IEasyTrack.Motion[] memory motions = et.getMotions();
        IEasyTrack.Motion memory motion = motions[motions.length - 1];
        vm.roll(block.number + 1);
        uint256 weight = ILdoSnapshots(Mainnet.LDO).balanceOfAt(anyone, motion.snapshotBlock);
        uint256 supply = ILdoSnapshots(Mainnet.LDO).totalSupplyAt(motion.snapshotBlock);
        assertGe(weight * 10_000 / supply, motion.objectionsThreshold);
        vm.prank(anyone);
        IERC20(Mainnet.LDO).transfer(Mainnet.AGENT, 10_000_000e18);
        vm.prank(anyone);
        actions.objectToMotion(id);

        assertEq(et.getMotions().length, openBefore);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore);
        assertEq(IRecipientsRegistry(stableRegistry).spendableBalance(), registryBefore);
        vm.expectRevert(bytes("MOTION_NOT_FOUND"));
        vm.prank(anyone);
        et.enactMotion(id, data);
    }

    function test_MAIN09_monthly_topup_limit_exact_boundary_race_and_rollover() public {
        _enable();
        IRecipientsRegistry registry = IRecipientsRegistry(stableRegistry);
        vm.prank(Mainnet.VOTING);
        registry.setLimitParameters(2_000_000e18, 1);
        deal(Mainnet.USDC, Mainnet.AGENT, 2_000_000e6);
        uint256 safeBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        bytes memory overBoundary = _stableTopUpData(1_500_000e6, address(asset));
        bytes memory competing = _stableTopUpData(1_000_000e6, address(asset));
        bytes memory exactRemainder = _stableTopUpData(500_000e6, address(asset));
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        uint256 openBefore = et.getMotions().length;
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 first = et.createMotion(stableTopUp, overBoundary);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 second = et.createMotion(stableTopUp, competing);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 third = et.createMotion(stableTopUp, exactRemainder);
        vm.warp(block.timestamp + et.motionDuration() + 1);

        vm.prank(anyone);
        et.enactMotion(first, overBoundary);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore + 1_500_000e6);
        assertEq(registry.spendableBalance(), 500_000e18);
        vm.expectRevert(bytes("SUM_EXCEEDS_SPENDABLE_BALANCE"));
        vm.prank(anyone);
        et.enactMotion(second, competing);
        assertEq(et.getMotions().length, openBefore + 2);
        assertEq(registry.spendableBalance(), 500_000e18);

        vm.prank(anyone);
        et.enactMotion(third, exactRemainder);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore + 2_000_000e6);
        assertEq(registry.spendableBalance(), 0);
        assertEq(et.getMotions().length, openBefore + 1);
        (uint256 spentBefore, uint256 spendableBefore,, uint256 periodEnd) = registry.getPeriodState();
        assertEq(spentBefore, 2_000_000e18);
        assertEq(spendableBefore, 0);
        assertGe(block.timestamp + et.motionDuration(), periodEnd);
        deal(Mainnet.USDC, Mainnet.AGENT, 1_000_000e6);
        bytes memory nextPeriod = _stableTopUpData(1_000_000e6, address(asset));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 rollover = et.createMotion(stableTopUp, nextPeriod);
        IEasyTrack.Motion[] memory pending = et.getMotions();
        IEasyTrack.Motion memory rolloverMotion = pending[pending.length - 1];
        assertGe(rolloverMotion.startDate + rolloverMotion.duration, periodEnd);
        vm.warp(rolloverMotion.startDate + rolloverMotion.duration + 1);
        vm.prank(anyone);
        et.enactMotion(rollover, nextPeriod);
        (uint256 spentAfter, uint256 spendableAfter,, uint256 nextPeriodEnd) = registry.getPeriodState();
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)), safeBefore + 3_000_000e6);
        assertEq(spentAfter, 1_000_000e18);
        assertEq(spendableAfter, 1_000_000e18);
        assertGt(nextPeriodEnd, periodEnd);
    }

    // ---------------------------------------------------------------------
    // 4. Where the money can go at launch: Lido Earn deposits
    // ---------------------------------------------------------------------

    /// @dev The Roles layer allows the deposits (Drills D3b); this asks
    ///      whether the live queues accept them from a new Safe.
    function test_04_earn_deposits_from_the_asset_safe() public {
        _enable();
        _topUp(stableTopUp, Mainnet.USDC, 200_000e6); // STANDIN
        _topUp(stethTopUp, Mainnet.STETH, 50e18); // STANDIN
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
        // the stETH approval to wstETH has a fixed ceiling: 10 stETH at dry-run scale (STANDIN)
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

    address internal constant EARN_ETH_DEPOSIT_QUEUE = 0xe39EED9A454C4918F8d0682062777cB251cd513F;
    address internal constant EARN_USD_REDEEM_QUEUE = 0x9e36A74FE278906a76e7615263e46a83fC40c47F;

    // ---------------------------------------------------------------------
    // 5. The first-loss Safe: a burn by motion and a redemption request
    // ---------------------------------------------------------------------

    /// @dev The first-loss policy is not built. The owner path grants the
    ///      two minimal permissions that ADR 008 describes, so the probe can
    ///      ask whether the share tokens accept them from the first-loss Safe.
    function test_05_first_loss_burn_and_redemption_request() public {
        _enable();
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        _moveFirstLossShare(Mainnet.EARN_USD_SHARE, "earnUSD");
        vm.startPrank(address(firstLoss));
        firstLossMod.scopeTarget(FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE);
        firstLossMod.allowFunction(FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE, bytes4(keccak256("burn(uint256)")), 0);
        firstLossMod.scopeTarget(FIRST_LOSS, EARN_USD_REDEEM_QUEUE);
        firstLossMod.allowFunction(FIRST_LOSS, EARN_USD_REDEEM_QUEUE, bytes4(keccak256("redeem(uint256)")), 0);
        vm.stopPrank();

        uint256 before = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        vm.prank(Mainnet.ET_EXECUTOR);
        firstLossMod.execTransactionWithRole(
            Mainnet.EARN_ETH_SHARE, 0, abi.encodeWithSignature("burn(uint256)", 10e18), 0, FIRST_LOSS_BURN, true
        );
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), before - 10e18, "the burn by the executor");
        console2.log("REHEARSAL first-loss burn of 10 earnETH shares by the executor's role: done");

        // The committee's role asks for a redemption; the queue takes the shares.
        uint256 usdBefore = IERC20(Mainnet.EARN_USD_SHARE).balanceOf(address(firstLoss));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        firstLossMod.execTransactionWithRole(
            EARN_USD_REDEEM_QUEUE, 0, abi.encodeWithSignature("redeem(uint256)", 1_000e18), 0, FIRST_LOSS, true
        );
        assertEq(IERC20(Mainnet.EARN_USD_SHARE).balanceOf(address(firstLoss)), usdBefore - 1_000e18, "the redemption request");
        console2.log("REHEARSAL first-loss redemption request of 1,000 earnUSD shares by the committee's role: done");
    }

    // ---------------------------------------------------------------------
    // 6. The shared payment permission: only USDS changes
    // ---------------------------------------------------------------------

    /// @dev Every Easy Track payment factory of every committee pays through
    ///      this one permission, and the vote overwrites it whole. The test
    ///      asks the live ACL the same questions before and after the vote:
    ///      each token at amounts around every ceiling in the chain.
    function test_06_the_payment_rewrite_changes_only_usds() public {
        address[9] memory tokens = [
            address(0), Mainnet.STETH, Mainnet.DAI, Mainnet.USDC, Mainnet.USDT, Mainnet.SUSDS, Mainnet.LDO, Mainnet.USDS, Mainnet.WETH
        ];
        uint256[12] memory amounts = [
            uint256(0), 1, 1_000e6, 2_000_000e6, 2_000_000e6 + 1, 1_000e18, 1_000e18 + 1,
            2_000_000e18, 2_000_000e18 + 1, 5_000_000e18, 5_000_000e18 + 1, type(uint256).max
        ];
        bool[12][9] memory before;
        for (uint256 t = 0; t < tokens.length; t++) {
            for (uint256 a = 0; a < amounts.length; a++) before[t][a] = _mayPay(tokens[t], amounts[a]);
        }
        // The questions reach the ceilings: USDC 2,000,000 and stETH 1,000 per payment
        assertTrue(before[3][3] && !before[3][4], "the USDC ceiling");
        assertTrue(before[1][5] && !before[1][6], "the stETH ceiling");
        _enable();
        uint256 changed;
        for (uint256 t = 0; t < tokens.length; t++) {
            for (uint256 a = 0; a < amounts.length; a++) {
                bool afterVote = _mayPay(tokens[t], amounts[a]);
                if (tokens[t] == Mainnet.USDS) {
                    assertFalse(before[t][a], "USDS was denied before the vote");
                    assertEq(afterVote, amounts[a] <= 2_000_000e18, "USDS: at most 2,000,000 per payment");
                    if (afterVote) changed++;
                } else {
                    assertEq(afterVote, before[t][a], "every other answer is unchanged");
                }
            }
        }
        console2.log("REHEARSAL payment permission: questions asked before and after", tokens.length * amounts.length);
        console2.log("REHEARSAL payment permission: answers changed, all of them USDS", changed);
    }

    // ---------------------------------------------------------------------
    // 7. USDS without the USDS items: DAI, Sky's converter, then savings
    // ---------------------------------------------------------------------

    /// @dev The Agent holds DAI and no USDS. DAI is already on the shared
    ///      list and in the payment permission, and the operator converts
    ///      DAI to USDS one to one (OD-22). So the vault can hold USDS and
    ///      sUSDS after a vote without the four USDS items.
    function test_07_usds_reaches_the_vault_without_the_usds_items() public {
        _enableWith(false);
        assertFalse(IAllowedTokensRegistry(Mainnet.STABLECOIN_LIST).isTokenAllowed(Mainnet.USDS), "USDS stays off the list");
        uint256 dai = 5_000e18; // STANDIN, under the converter ceiling stand-in
        _topUp(stableTopUp, Mainnet.DAI, dai);
        _operator(Mainnet.DAI, abi.encodeCall(IERC20.approve, (DAI_USDS, dai)), true);
        _operator(DAI_USDS, abi.encodeWithSignature("daiToUsds(address,uint256)", address(asset), dai), true);
        assertEq(IERC20(Mainnet.USDS).balanceOf(address(asset)), dai, "DAI became USDS one to one");
        (,,, uint128 sky,) = opMod.allowances(bytes32("sky_savings_usds"));
        _operator(Mainnet.USDS, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, sky)), true);
        _operator(Mainnet.SUSDS, abi.encodeWithSignature("deposit(uint256,address)", uint256(sky), address(asset)), true);
        assertGt(IERC20(Mainnet.SUSDS).balanceOf(address(asset)), 0, "USDS in Sky savings");
        console2.log("REHEARSAL without the USDS items: DAI topped up, converted to USDS, USDS saved (STANDIN amounts): done");
    }

    address internal constant DAI_USDS = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;

    function _mayPay(address token, uint256 amount) internal view returns (bool) {
        uint256[] memory how = new uint256[](3);
        how[0] = uint256(uint160(token));
        how[1] = uint256(uint160(anyone));
        how[2] = amount;
        return IACL(Mainnet.ACL).hasPermission(Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE, how);
    }

    function _probe(string memory what, address to, bytes memory data) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok, bytes memory ret) =
            address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
        console2.log(string.concat("REHEARSAL ", what, ": done (1 = yes)"), ok ? 1 : 0);
        if (!ok) console2.logBytes(ret);
    }

    // ---------------------------------------------------------------------
    // The enabling vote
    // ---------------------------------------------------------------------

    function _enable() internal {
        _enableWith(true);
    }

    /// @dev `usds` adds the four USDS funding items: the payment rewrite and
    ///      the three items on the shared token list.
    function _enableWith(bool usds) internal {
        _buildBatches();
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory items = _voteItems(false, usds);
        bytes memory voteScript = VoteBuilder.script(items);
        vm.resumeGasMetering();
        console2.log("REHEARSAL vote: items", items.length);
        console2.log("REHEARSAL vote: script bytes", voteScript.length);

        _proposer();
        (bool ok, uint256 gasUsed, bytes memory txData) = _newVote(voteScript);
        assertTrue(ok, "newVote must fit in one transaction");
        console2.log("REHEARSAL vote: newVote gas", gasUsed);
        console2.log("REHEARSAL vote: newVote calldata bytes", txData.length);

        IVoting voting = IVoting(Mainnet.VOTING);
        uint256 id = voting.votesLength() - 1;
        vm.prank(proposer);
        voting.vote(id, true, false);
        vm.warp(block.timestamp + voting.voteTime() + 1);
        assertTrue(voting.canExecute(id), "the vote must pass");

        bytes memory exec = abi.encodeCall(IVoting.executeVote, (id));
        (uint256 std,) = VoteBuilder.intrinsicGas(exec);
        _coolGovernance();
        vm.prank(anyone);
        uint256 g = gasleft();
        (bool done,) = Mainnet.VOTING.call{gas: TX_GAS_CAP - std}(exec);
        uint256 used = g - gasleft() + std;
        assertTrue(done, "executeVote must fit in one transaction");
        console2.log("REHEARSAL vote: executeVote gas", used);

        for (uint256 i = 0; i < batches.length; i++) _runBatch(batches[i]);
    }

    function _voteItems(bool direct, bool usds) internal view returns (VoteBuilder.Item[] memory items) {
        uint256 first = usds ? 7 : 3;
        items = new VoteBuilder.Item[](first + batches.length);
        items[0] = _register(stableTopUp, abi.encodePacked(
            VoteBuilder.permission(stableRegistry, IRecipientsRegistry.updateSpentAmount.selector),
            VoteBuilder.permission(Mainnet.FINANCE, IFinance.newImmediatePayment.selector)
        ), "Easy Track: register the stablecoin top-up factory");
        items[1] = _register(stethTopUp, abi.encodePacked(
            VoteBuilder.permission(stethRegistry, IRecipientsRegistry.updateSpentAmount.selector),
            VoteBuilder.permission(Mainnet.FINANCE, IFinance.newImmediatePayment.selector)
        ), "Easy Track: register the stETH top-up factory");
        items[2] = _register(address(budgetFactory),
            VoteBuilder.permission(address(opMod), IRoles.execTransactionWithRole.selector),
            "Easy Track: register the budget factory (stand-in)");
        if (usds) _usdsItems(items);
        bytes memory votingSig = abi.encodePacked(bytes32(uint256(uint160(Mainnet.VOTING))), bytes32(0), uint8(1));
        for (uint256 i = 0; i < batches.length; i++) {
            Batch storage b = batches[i];
            items[first + i] = direct
                ? VoteBuilder.Item(
                    address(b.safe),
                    abi.encodeCall(
                        ISafe.execTransaction,
                        (Mainnet.MULTISEND_CALL_ONLY, 0, b.data, 1, 0, 0, 0, address(0), payable(address(0)), votingSig)
                    ),
                    b.label
                )
                : VoteBuilder.Item(address(b.safe), abi.encodeCall(ISafe.approveHash, (b.hash)), b.label);
        }
    }

    function _usdsItems(VoteBuilder.Item[] memory items) internal view {
        items[3] = VoteBuilder.Item(
            Mainnet.ACL,
            abi.encodeCall(IACL.grantPermissionP, (Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE, _paymentParamsWithUsds())),
            "ACL: rewrite the executor's payment permission to add USDS (OD-11, OD-24)"
        );
        // Voting is the list's admin but holds no add-token role (finding 3).
        items[4] = VoteBuilder.Item(
            Mainnet.STABLECOIN_LIST,
            abi.encodeCall(IAllowedTokensRegistry.grantRole, (ADD_TOKEN_ROLE, Mainnet.VOTING)),
            "Stablecoin list: Voting takes the add-token role"
        );
        items[5] = VoteBuilder.Item(
            Mainnet.STABLECOIN_LIST, abi.encodeCall(IAllowedTokensRegistry.addToken, (Mainnet.USDS)), "Stablecoin list: add USDS"
        );
        items[6] = VoteBuilder.Item(
            Mainnet.STABLECOIN_LIST,
            abi.encodeCall(IAllowedTokensRegistry.renounceRole, (ADD_TOKEN_ROLE, Mainnet.VOTING)),
            "Stablecoin list: Voting gives the add-token role up"
        );
    }

    function _register(address factory, bytes memory permissions, string memory label)
        internal
        pure
        returns (VoteBuilder.Item memory)
    {
        return VoteBuilder.Item(Mainnet.EASY_TRACK, abi.encodeCall(IEasyTrack.addEVMScriptFactory, (factory, permissions)), label);
    }

    /// @dev The live chain of the executor's payment permission ends in RET
    ///      false. The new chain replaces that end with one more branch: USDS
    ///      at most 2,000,000 per payment (OD-24), then RET false.
    function _paymentParamsWithUsds() internal view returns (uint256[] memory p) {
        IACL acl = IACL(Mainnet.ACL);
        uint256 n = acl.getPermissionParamsLength(Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE);
        (uint8 lastId, uint8 lastOp, uint240 lastValue) =
            acl.getPermissionParam(Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE, n - 1);
        require(lastId == 205 && lastOp == 7 && lastValue == 0, "the chain must end in RET false");
        p = new uint256[](n + 3);
        for (uint256 i = 0; i < n - 1; i++) {
            (uint8 id, uint8 op, uint240 value) = acl.getPermissionParam(Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE, i);
            p[i] = VoteBuilder.aclParam(id, op, value);
        }
        uint240 ifElse = uint240(n) | (uint240(n + 1) << 32) | (uint240(n + 2) << 64);
        p[n - 1] = VoteBuilder.aclParam(204, 12, ifElse); // LOGIC_OP IF_ELSE
        p[n] = VoteBuilder.aclParam(0, 1, uint240(uint160(Mainnet.USDS))); // arg 0, the token, EQ USDS
        p[n + 1] = VoteBuilder.aclParam(2, 6, 2_000_000e18); // arg 2, the amount, LTE
        p[n + 2] = VoteBuilder.aclParam(205, 7, 0); // PARAM_VALUE RET false
    }

    // ---------------------------------------------------------------------
    // The Safe batches
    // ---------------------------------------------------------------------

    function _buildBatches() internal {
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory calls = _assetCalls();
        vm.resumeGasMetering();
        uint256[] memory gasOf = _measure(calls, address(asset));
        vm.pauseGasMetering();
        uint256 total;
        for (uint256 i = 0; i < gasOf.length; i++) total += gasOf[i];
        console2.log("REHEARSAL Asset Safe policy: calls", calls.length);
        console2.log("REHEARSAL Asset Safe policy: gas of the calls, each cold", total);

        uint256 start;
        uint256 sum;
        for (uint256 i = 0; i < calls.length; i++) {
            if (sum + gasOf[i] > BATCH_CALL_GAS_BUDGET && i > start) {
                _addBatch(asset, calls, start, i, "Asset Safe: approve a policy batch");
                start = i;
                sum = 0;
            }
            sum += gasOf[i];
        }
        _addBatch(asset, calls, start, calls.length, "Asset Safe: approve a policy batch");
        VoteBuilder.Item[] memory o = _ordersCalls();
        _addBatch(orders, o, 0, o.length, "Orders account: approve its setup batch");
        VoteBuilder.Item[] memory f = _firstLossCalls();
        _addBatch(firstLoss, f, 0, f.length, "First-loss Safe: approve its setup batch");
        vm.resumeGasMetering();
        console2.log("REHEARSAL Safe batches", batches.length);
    }

    function _addBatch(ISafe safe, VoteBuilder.Item[] memory calls, uint256 from, uint256 to, string memory label)
        internal
    {
        VoteBuilder.Item[] memory part = new VoteBuilder.Item[](to - from);
        for (uint256 i = from; i < to; i++) part[i - from] = calls[i];
        bytes memory data = VoteBuilder.multiSend(part);
        uint256 nonce = safe.nonce();
        for (uint256 i = 0; i < batches.length; i++) if (batches[i].safe == safe) nonce++;
        bytes32 hash = safe.getTransactionHash(
            Mainnet.MULTISEND_CALL_ONLY, 0, data, 1, 0, 0, 0, address(0), address(0), nonce
        );
        batches.push(Batch({safe: safe, data: data, hash: hash, calls: to - from, label: label}));
    }

    function _assetCalls() internal view returns (VoteBuilder.Item[] memory calls) {
        string memory j = vm.readFile(ARTIFACT);
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        calls = new VoteBuilder.Item[](to.length + 2);
        calls[0] = VoteBuilder.Item(address(asset), abi.encodeCall(ISafe.enableModule, (address(opMod))), "");
        calls[1] = VoteBuilder.Item(address(asset), abi.encodeCall(ISafe.enableModule, (address(safetyMod))), "");
        for (uint256 i = 0; i < to.length; i++) calls[i + 2] = VoteBuilder.Item(to[i], data[i], "");
    }

    /// @dev ADR 007: CoW's fallback handler, ComposableCoW as the settlement
    ///      domain's verifier, the orders modifier with its two roles, and the
    ///      relayer approvals for the operator's order tokens; LDO left the
    ///      launch list (OD-91). The orders policy itself is not built yet.
    function _ordersCalls() internal view returns (VoteBuilder.Item[] memory c) {
        address[6] memory tokens =
            [Mainnet.STETH, Mainnet.WSTETH, Mainnet.WETH, Mainnet.USDC, Mainnet.USDT, Mainnet.USDS];
        bytes32 domain = ISettlement(Mainnet.COW_SETTLEMENT).domainSeparator();
        c = new VoteBuilder.Item[](5 + tokens.length);
        c[0] = VoteBuilder.Item(address(orders), abi.encodeCall(ISafeAdmin.setFallbackHandler, (Mainnet.COW_FALLBACK_HANDLER)), "");
        c[1] = VoteBuilder.Item(
            address(orders), abi.encodeCall(IExtensibleFallbackHandler.setDomainVerifier, (domain, Mainnet.COMPOSABLE_COW)), ""
        );
        c[2] = VoteBuilder.Item(address(orders), abi.encodeCall(ISafe.enableModule, (address(ordersMod))), "");
        c[3] = VoteBuilder.Item(address(ordersMod), _assign(Mainnet.COMMITTEE_SAFE, OPERATOR), "");
        c[4] = VoteBuilder.Item(address(ordersMod), _assign(address(emergency), EMERGENCY), "");
        for (uint256 i = 0; i < tokens.length; i++) {
            c[5 + i] = VoteBuilder.Item(tokens[i], abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, type(uint256).max)), "");
        }
    }

    /// @dev ADR 008: the first-loss modifier and its two roles. Its policy is not built yet.
    function _firstLossCalls() internal view returns (VoteBuilder.Item[] memory c) {
        c = new VoteBuilder.Item[](3);
        c[0] = VoteBuilder.Item(address(firstLoss), abi.encodeCall(ISafe.enableModule, (address(firstLossMod))), "");
        c[1] = VoteBuilder.Item(address(firstLossMod), _assign(Mainnet.COMMITTEE_SAFE, FIRST_LOSS), "");
        c[2] = VoteBuilder.Item(address(firstLossMod), _assign(Mainnet.ET_EXECUTOR, FIRST_LOSS_BURN), "");
    }

    function _assign(address member, bytes32 key) internal pure returns (bytes memory) {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = key;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        return abi.encodeCall(IRoles.assignRoles, (member, keys, yes));
    }

    /// @dev The gas of each call on its own, with cold accounts, applied in
    ///      order and then rolled back.
    function _measure(VoteBuilder.Item[] memory calls, address from) internal returns (uint256[] memory gasOf) {
        uint256 snap = vm.snapshotState();
        gasOf = new uint256[](calls.length);
        address[] memory touched = new address[](3);
        touched[0] = address(asset);
        touched[1] = address(opMod);
        touched[2] = address(safetyMod);
        for (uint256 i = 0; i < calls.length; i++) {
            _cold(touched);
            vm.prank(from);
            uint256 g = gasleft();
            (bool ok,) = calls[i].to.call(calls[i].data);
            gasOf[i] = g - gasleft();
            require(ok, "measure: a policy call failed");
        }
        vm.revertToState(snap);
    }

    function _runBatch(Batch storage b) internal {
        vm.pauseGasMetering();
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(Mainnet.VOTING))), bytes32(0), uint8(1));
        bytes memory txData = abi.encodeCall(
            ISafe.execTransaction,
            (Mainnet.MULTISEND_CALL_ONLY, 0, b.data, 1, 0, 0, 0, address(0), payable(address(0)), sig)
        );
        (uint256 std, uint256 floor) = VoteBuilder.intrinsicGas(txData);
        vm.resumeGasMetering();
        uint256 intrinsic = std > floor ? std : floor;
        address[] memory touched = new address[](6);
        touched[0] = address(b.safe);
        touched[1] = Mainnet.MULTISEND_CALL_ONLY;
        touched[2] = address(opMod);
        touched[3] = address(safetyMod);
        touched[4] = address(ordersMod);
        touched[5] = address(firstLossMod);
        _cold(touched);
        vm.prank(anyone);
        uint256 g = gasleft();
        (bool ok, bytes memory ret) = address(b.safe).call{gas: TX_GAS_CAP - intrinsic}(txData);
        uint256 used = g - gasleft() + std;
        assertTrue(ok && abi.decode(ret, (bool)), string.concat("batch failed: ", b.label));
        console2.log(string.concat("REHEARSAL batch gas (", vm.toString(b.calls), " calls), calldata bytes"), used, txData.length);
        assertLe(used, TX_GAS_CAP, "a batch must fit in one transaction");
        assertLe(txData.length, TX_SIZE_LIMIT, "a batch must fit in the txpool's size limit");
    }

    // ---------------------------------------------------------------------
    // Creating and running the vote
    // ---------------------------------------------------------------------

    /// @dev An LDO holder above the quorum, funded from the treasury on the fork only.
    function _proposer() internal {
        proposer = makeAddr("ldo-proposer");
        vm.prank(Mainnet.AGENT);
        IERC20(Mainnet.LDO).transfer(proposer, 60_000_000e18);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function _newVote(bytes memory voteScript) internal returns (bool ok, uint256 gasUsed, bytes memory txData) {
        VoteBuilder.Item[] memory fwd = new VoteBuilder.Item[](1);
        fwd[0] = VoteBuilder.Item(
            Mainnet.VOTING, abi.encodeWithSignature("newVote(bytes,string)", voteScript, "Clutch enabling vote, rehearsal"), ""
        );
        vm.pauseGasMetering();
        txData = abi.encodeCall(ITokenManager.forward, (VoteBuilder.script(fwd)));
        (uint256 std, uint256 floor) = VoteBuilder.intrinsicGas(txData);
        vm.resumeGasMetering();
        uint256 intrinsic = std > floor ? std : floor;
        if (intrinsic >= TX_GAS_CAP) return (false, intrinsic, txData);
        _coolGovernance();
        vm.prank(proposer);
        uint256 g = gasleft();
        (ok,) = Mainnet.TOKEN_MANAGER.call{gas: TX_GAS_CAP - intrinsic}(txData);
        gasUsed = g - gasleft() + std;
    }

    function _coolGovernance() internal {
        address[] memory a = new address[](4);
        a[0] = Mainnet.VOTING;
        a[1] = Mainnet.TOKEN_MANAGER;
        a[2] = Mainnet.LDO;
        a[3] = Mainnet.EASY_TRACK;
        _cold(a);
    }

    function _checkEnabled() internal view {
        assertTrue(asset.isModuleEnabled(address(opMod)) && asset.isModuleEnabled(address(safetyMod)), "Asset Safe modifiers");
        assertTrue(orders.isModuleEnabled(address(ordersMod)), "orders modifier");
        assertTrue(firstLoss.isModuleEnabled(address(firstLossMod)), "first-loss modifier");
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertTrue(et.isEVMScriptFactory(stableTopUp) && et.isEVMScriptFactory(stethTopUp), "top-up factories");
        assertTrue(et.isEVMScriptFactory(address(budgetFactory)), "budget factory");
        assertTrue(IAllowedTokensRegistry(Mainnet.STABLECOIN_LIST).isTokenAllowed(Mainnet.USDS), "USDS listed");
        assertEq(
            IACL(Mainnet.ACL).getPermissionParamsLength(Mainnet.ET_EXECUTOR, Mainnet.FINANCE, CREATE_PAYMENTS_ROLE),
            25,
            "payment permission rewritten"
        );
        bytes32 domain = ISettlement(Mainnet.COW_SETTLEMENT).domainSeparator();
        assertEq(
            IExtensibleFallbackHandler(Mainnet.COW_FALLBACK_HANDLER).domainVerifiers(address(orders), domain),
            Mainnet.COMPOSABLE_COW,
            "domain verifier"
        );
        assertEq(IERC20(Mainnet.USDC).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), type(uint256).max, "relayer approval");
        // Without the standard builder, nothing asserts the registries' roles
        // at deployment, so the check before the vote must (finding 2).
        address[2] memory regs = [stableRegistry, stethRegistry];
        for (uint256 i = 0; i < regs.length; i++) {
            IRecipientsRegistry r = IRecipientsRegistry(regs[i]);
            assertTrue(r.hasRole(bytes32(0), Mainnet.VOTING), "registry admin: Voting");
            assertFalse(r.hasRole(bytes32(0), Mainnet.AGENT), "registry admin: not the Agent");
            assertFalse(r.hasRole(bytes32(0), deployer), "registry admin: not the deployer");
            assertFalse(r.hasRole(ADD_RECIPIENT_ROLE, deployer), "the deployer gave up adding");
            assertFalse(r.hasRole(SET_PARAMETERS_ROLE, deployer), "the deployer gave up the limit");
            assertTrue(r.hasRole(SET_PARAMETERS_ROLE, Mainnet.VOTING), "Voting sets the limit");
            assertFalse(r.hasRole(ADD_RECIPIENT_ROLE, Mainnet.ET_EXECUTOR), "no recipient by motion");
            assertTrue(r.hasRole(keccak256("UPDATE_SPENT_AMOUNT_ROLE"), Mainnet.ET_EXECUTOR), "the executor counts spending");
        }
    }

    // ---------------------------------------------------------------------
    // Ramp-up helpers
    // ---------------------------------------------------------------------

    function _moveFirstLossShare(address share, string memory name) internal {
        uint256 bal = IERC20(share).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE);
        vm.prank(Mainnet.GROWTH_COMMITTEE_SAFE);
        (bool ok, bytes memory ret) = share.call(abi.encodeCall(IERC20.transfer, (address(firstLoss), bal)));
        console2.log(string.concat("REHEARSAL first-loss ", name, ": balance, moved (1 = yes)"), bal, ok ? 1 : 0);
        if (!ok) console2.logBytes(ret);
    }

    function _topUp(address factory, address token, uint256 amount) internal {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        address[] memory to = new address[](1);
        to[0] = address(asset);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory cd = factory == stethTopUp ? abi.encode(to, amounts) : abi.encode(token, to, amounts);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 id = et.createMotion(factory, cd);
        vm.warp(block.timestamp + et.motionDuration() + 1);
        vm.prank(anyone);
        et.enactMotion(id, cd);
    }

    function _stableTopUpData(uint256 amount, address recipient) internal pure returns (bytes memory) {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        return abi.encode(Mainnet.USDC, recipients, amounts);
    }

    function _operator(address to, bytes memory data, bool expectOk) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok,) = address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
        assertEq(ok, expectOk, "operator call outcome");
    }

    function _emergencySwitch() internal {
        (address[] memory mods,) = asset.getModulesPaginated(address(0x1), 10);
        address prev = address(0x1);
        for (uint256 i = 0; i < mods.length; i++) {
            if (mods[i] == address(opMod)) break;
            prev = mods[i];
        }
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(
            address(asset), 0, abi.encodeCall(ISafe.disableModule, (prev, address(opMod))), 0, EMERGENCY, true
        );
        assertFalse(asset.isModuleEnabled(address(opMod)), "the switch is off");
    }
}
