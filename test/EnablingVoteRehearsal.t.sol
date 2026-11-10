// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {ITokenManager, IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @title EnablingVoteRehearsal — the enabling vote and the first weeks of
///        operation, rehearsed end to end on a mainnet fork.
/// @dev The live Aragon Voting, token manager, Easy Track, script executor,
///      Aragon Finance and treasury take part. Only the Clutch accounts and
///      the universal factory are new. The vote registers the factory and pays
///      the first tranche (OD-102, OD-106; enabling-vote spec, "Rebuilding the
///      rehearsal", step 1). Lines that start with "REHEARSAL" are the
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
    // 2. The vote that fits: the factory, the first tranche, then hash approvals
    // ---------------------------------------------------------------------

    /// @dev The vote registers the universal factory with its address book and
    ///      pays the first tranche, which reaches the Asset Safe when the vote
    ///      executes, before the batches (checked in `_enable`).
    function test_02_enabling_vote_end_to_end() public {
        _enable();
        _checkEnabled();
    }

    // ---------------------------------------------------------------------
    // 3. The first weeks: tranches, budgets, a ceiling, the switch, the restart
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

        // 3c. A later tranche in another token, by its own vote (ADR 014, decision 3).
        //     The Agent holds no USDS at the fork block, so the fork gives it some.
        deal(Mainnet.USDS, Mainnet.AGENT, 100_000e18);
        _trancheVote(Mainnet.USDS, 50_000e18); // STANDIN
        assertEq(IERC20(Mainnet.USDS).balanceOf(address(asset)), 50_000e18, "a later tranche in USDS");

        // 3d. Budgets set the pace: an approval spends the key (OD-08).
        (,,, uint128 earnBudget,) = opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL earn_usd_deposit budget at launch (STANDIN, USDC units)", uint256(earnBudget));
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, earnBudget)), true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 1e6)), false);

        // 3e. A budget motion of the universal factory, within the token's ceiling.
        bytes32 seeded = uf.budgetVersion(EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, MONTH);
        _motion(_one(_budgetOp(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, 400_000e6, seeded)));
        (uint128 refill, uint128 maxRefill, uint64 period, uint128 balance,) = opMod.allowances(bytes32("earn_usd_deposit"));
        console2.log("REHEARSAL budget motion: balance after enactment", uint256(balance));
        console2.log("REHEARSAL budget motion: refill, period", uint256(refill), uint256(period));
        assertEq(maxRefill, 400_000e6);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 300_000e6)), true);

        // 3f. A ceiling motion: twofold now, and no second raise within 15 days (OD-105).
        bytes32 key = uf.ceilingKey(uf.BUDGET_CEILING(), Mainnet.USDC);
        _motion(_one(_ceilingOp(key, BUDGET_CEILING_USDC, 2 * BUDGET_CEILING_USDC)));
        (uint256 ceiling,,) = uf.ceilings(key);
        assertEq(ceiling, 2 * BUDGET_CEILING_USDC, "the ceiling rose twofold");
        bytes memory again = _calldata(_one(_ceilingOp(key, ceiling, ceiling + 1)));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert();
        et.createMotion(address(uf), again);
        console2.log("REHEARSAL ceiling motion: raised twofold; a second raise within 15 days refused");

        // 3g. The switch, and the counter that it raises.
        _emergencySwitch();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("GS104"));
        opMod.execTransactionWithRole(Mainnet.USDC, 0, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), 0, OPERATOR, true);

        // 3h. A restart motion enables the operator modifier again (ADR 013, decision 12).
        _motion(_one(_op(uf.RESTART(), "")));
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

    function _probe(string memory what, address to, bytes memory data) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok, bytes memory ret) =
            address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
        console2.log(string.concat("REHEARSAL ", what, ": done (1 = yes)"), ok ? 1 : 0);
        if (!ok) console2.logBytes(ret);
    }
}
