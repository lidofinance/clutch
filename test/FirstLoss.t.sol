// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

interface ISupply {
    function totalSupply() external view returns (uint256);
}

interface IDepositQueue {
    function requestOf(address account) external view returns (uint256 timestamp, uint256 assets);
}

/// @title FirstLossRehearsal — the first-loss Safe's policy (ADR 008) on the vault that the
///        enabling vote sets up, on a mainnet fork, with the live Earn vaults and the live Easy Track.
/// @dev Each test names the invariant that it checks.
///      Run: RPC=<archive RPC> forge test --match-contract FirstLossRehearsal -vv
contract FirstLossRehearsal is EnabledVault {
    bytes4 internal constant CONDITION_VIOLATION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    /// @dev The modifier's two refusals of a caller: one that holds no role at all, and one that
    ///      holds a role but not the one that it names.
    bytes4 internal constant NOT_AUTHORIZED = bytes4(keccak256("NotAuthorized(address)"));
    bytes4 internal constant NO_MEMBERSHIP = bytes4(keccak256("NoMembership()"));
    address internal constant EARN_ETH_REDEEM_QUEUE = 0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4;
    bytes32 internal constant INSURANCE = bytes32("insurance");
    bytes32 internal constant INSURANCE_FUNDING = bytes32("insurance-funding");
    bytes32 internal constant GOVERNANCE_OF_FUNDS = bytes32("insurance-governance");
    /// @dev A stand-in for a fund's payout address, which the Lend team names (OD-131).
    address internal payout = makeAddr("fund-payout-address");
    bytes32 internal constant FALLBACK_HANDLER_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
    bytes32 internal constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 internal constant MODULE_GUARD_SLOT = 0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947;
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote runs inside each test, and the Growth Committee then moves the
    ///      DAO's first-loss shares to the first-loss Safe (ADR 008, decision 13).
    modifier enabled() {
        _enable();
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        _moveFirstLossShare(Mainnet.EARN_USD_SHARE, "earnUSD");
        _;
    }

    // ---------------------------------------------------------------------
    // INV-021: the first-loss Safe and its modifier
    // ---------------------------------------------------------------------

    /// @dev Aragon Voting is the only owner, at threshold one. The Safe runs the pinned singleton and
    ///      has no fallback handler and no guard. The first-loss modifier is the only module, and
    ///      the Safe holds both first-loss share balances.
    function test_first_loss_safe_shape() public enabled {
        address[] memory owners = firstLoss.getOwners();
        assertEq(owners.length, 1, "one owner");
        assertEq(owners[0], Mainnet.VOTING, "Aragon Voting owns it");
        assertEq(firstLoss.getThreshold(), 1, "threshold one");
        assertEq(address(uint160(uint256(vm.load(address(firstLoss), bytes32(0))))), Mainnet.SAFE_SINGLETON, "pinned singleton");
        assertEq(vm.load(address(firstLoss), FALLBACK_HANDLER_SLOT), bytes32(0), "no fallback handler");
        assertEq(vm.load(address(firstLoss), GUARD_SLOT), bytes32(0), "no transaction guard");
        assertEq(vm.load(address(firstLoss), MODULE_GUARD_SLOT), bytes32(0), "no module guard");
        (address[] memory modules,) = firstLoss.getModulesPaginated(address(1), 10);
        assertEq(modules.length, 1, "one module");
        assertEq(modules[0], address(firstLossMod), "the first-loss modifier");
        assertGt(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), 0, "earnETH first-loss shares");
        assertGt(IERC20(Mainnet.EARN_USD_SHARE).balanceOf(address(firstLoss)), 0, "earnUSD first-loss shares");
    }

    /// @dev A burn runs only as an enacted motion: the committee's Safe creates it, it waits for
    ///      the objection window, and the factory then burns the shares of the first-loss Safe
    ///      (ADR 008, decision 23). The share's supply falls by the burned amount.
    function test_first_loss_burn_by_motion() public enabled {
        address[2] memory shares = [Mainnet.EARN_ETH_SHARE, Mainnet.EARN_USD_SHARE];
        uint256[2] memory amounts = [uint256(10e18), uint256(1_000e18)];
        for (uint256 i = 0; i < shares.length; i++) {
            uint256 held = IERC20(shares[i]).balanceOf(address(firstLoss));
            uint256 supply = ISupply(shares[i]).totalSupply();
            bytes memory cd = _calldata(_one(_burn(shares[i], amounts[i])));
            uint256 id = _create(cd);

            // before the objection window ends, nothing burns
            vm.prank(anyone);
            (bool early,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, cd)));
            assertFalse(early, "no enactment inside the objection window");
            assertEq(IERC20(shares[i]).balanceOf(address(firstLoss)), held, "nothing burned yet");

            _afterWindow();
            _enact(id, cd);
            assertEq(IERC20(shares[i]).balanceOf(address(firstLoss)), held - amounts[i], "the first-loss Safe's shares");
            assertEq(ISupply(shares[i]).totalSupply(), supply - amounts[i], "the supply falls by the burn");
        }
    }

    /// @dev Only the committee's Safe creates a burn motion. A burn of a token that the first-loss policy does
    ///      not name fails at enactment as a whole, and so does a burn of more than the Safe holds.
    function test_first_loss_burn_refusals() public enabled {
        bytes memory cd = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        vm.prank(stranger);
        vm.expectRevert();
        IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(uf), cd);

        // a token outside the policy: USDC, of which the first-loss Safe holds some
        deal(Mainnet.USDC, address(firstLoss), 5e6);
        _enactmentFails(_calldata(_one(_burn(Mainnet.USDC, 1e6))));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), 5e6, "nothing left the first-loss Safe");

        // more than the Safe holds
        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        _enactmentFails(_calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, held + 1))));
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), held, "the shares stay");
    }

    /// @dev No account burns outside a motion: the committee's Safe holds no burn permission, and
    ///      the factory's role acts only through `applyMotion`, which only Easy Track's executor calls.
    function test_first_loss_burn_needs_a_motion() public enabled {
        bytes memory burn = abi.encodeWithSignature("burn(uint256)", 1e18);
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, Mainnet.EARN_ETH_SHARE, burn, CONDITION_VIOLATION);
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE, burn, NO_MEMBERSHIP);
        _refused(address(emergency), FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE, burn, NOT_AUTHORIZED);
        _refused(stranger, FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE, burn, NOT_AUTHORIZED);

        bytes memory cd = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        address[3] memory callers = [Mainnet.COMMITTEE_SAFE, address(emergency), stranger];
        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotExecutor.selector, callers[i]));
            uf.applyMotion(cd);
        }
    }

    /// @dev The committee's `first-loss` role requests a redemption on each Earn vault's redeem
    ///      queue, which takes the shares from the first-loss Safe (ADR 008, decision 21).
    function test_first_loss_role_requests_a_redemption() public enabled {
        address[2] memory shares = [Mainnet.EARN_ETH_SHARE, Mainnet.EARN_USD_SHARE];
        address[2] memory queues = [EARN_ETH_REDEEM_QUEUE, EARN_USD_REDEEM_QUEUE];
        uint256[2] memory amounts = [uint256(5e18), uint256(1_000e18)];
        for (uint256 i = 0; i < shares.length; i++) {
            uint256 held = IERC20(shares[i]).balanceOf(address(firstLoss));
            vm.prank(Mainnet.COMMITTEE_SAFE);
            firstLossMod.execTransactionWithRole(
                queues[i], 0, abi.encodeWithSignature("redeem(uint256)", amounts[i]), 0, FIRST_LOSS, true
            );
            assertEq(IERC20(shares[i]).balanceOf(address(firstLoss)), held - amounts[i], "the queue takes the shares");
        }
    }

    /// @dev A claim pays only the Asset Safe (ADR 014, decision 10; INV-038): the policy accepts
    ///      that receiver and refuses every other one. The queue itself decides whether a request
    ///      is ready, so the accepted claim may still fail inside the queue.
    function test_first_loss_claim_pays_only_the_asset_safe() public enabled {
        uint32[] memory none = new uint32[](0);
        address[2] memory queues = [EARN_ETH_REDEEM_QUEUE, EARN_USD_REDEEM_QUEUE];
        address[5] memory others =
            [Mainnet.AGENT, Mainnet.COMMITTEE_SAFE, address(firstLoss), address(orders), stranger];
        for (uint256 i = 0; i < queues.length; i++) {
            for (uint256 k = 0; k < others.length; k++) {
                bytes memory bad = abi.encodeWithSignature("claim(address,uint32[])", others[k], none);
                _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, queues[i], bad, CONDITION_VIOLATION);
            }
            bytes memory good = abi.encodeWithSignature("claim(address,uint32[])", address(asset), none);
            vm.prank(Mainnet.COMMITTEE_SAFE);
            (bool ok, bytes memory ret) = address(firstLossMod).call(
                abi.encodeCall(IRoles.execTransactionWithRole, (queues[i], 0, good, 0, FIRST_LOSS, true))
            );
            if (!ok) assertTrue(bytes4(ret) != CONDITION_VIOLATION, "the policy accepts a claim to the Asset Safe");
        }
    }

    /// @dev The `first-loss` role holds no call of a share token: it cannot transfer, approve or
    ///      burn the shares, and it reaches no other target.
    function test_first_loss_role_cannot_move_the_shares() public enabled {
        address[2] memory shares = [Mainnet.EARN_ETH_SHARE, Mainnet.EARN_USD_SHARE];
        for (uint256 i = 0; i < shares.length; i++) {
            bytes[4] memory calls = [
                abi.encodeCall(IERC20.transfer, (address(asset), 1)),
                abi.encodeCall(IERC20.transfer, (Mainnet.COMMITTEE_SAFE, 1)),
                abi.encodeCall(IERC20.approve, (Mainnet.COMMITTEE_SAFE, 1)),
                abi.encodeWithSignature("burn(uint256)", 1)
            ];
            for (uint256 k = 0; k < calls.length; k++) {
                _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, shares[i], calls[k], CONDITION_VIOLATION);
            }
        }
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (stranger, 1)), CONDITION_VIOLATION);
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, address(firstLoss), abi.encodeCall(ISafe.enableModule, (stranger)), CONDITION_VIOLATION);
    }

    /// @dev The burn role holds the two burns and nothing else: no transfer and no approval of a
    ///      share, and no burn of another token. The factory's own address is the member.
    function test_first_loss_burn_role_holds_only_the_two_burns() public enabled {
        address[2] memory shares = [Mainnet.EARN_ETH_SHARE, Mainnet.EARN_USD_SHARE];
        for (uint256 i = 0; i < shares.length; i++) {
            _refused(address(uf), FIRST_LOSS_BURN, shares[i], abi.encodeCall(IERC20.transfer, (stranger, 1)), CONDITION_VIOLATION);
            _refused(address(uf), FIRST_LOSS_BURN, shares[i], abi.encodeCall(IERC20.approve, (stranger, 1)), CONDITION_VIOLATION);
        }
        _refused(address(uf), FIRST_LOSS_BURN, Mainnet.USDC, abi.encodeWithSignature("burn(uint256)", 1), CONDITION_VIOLATION);
        _refused(address(uf), FIRST_LOSS, EARN_USD_REDEEM_QUEUE, abi.encodeWithSignature("redeem(uint256)", 1), NO_MEMBERSHIP);
    }

    /// @dev No role of the Asset Safe's modifiers or of the orders modifier reaches the first-loss
    ///      shares: each acts as another Safe, and none is a member of a first-loss role.
    function test_other_roles_do_not_reach_the_first_loss_shares() public enabled {
        bytes memory burn = abi.encodeWithSignature("burn(uint256)", 1e18);
        bytes memory move = abi.encodeCall(IERC20.transfer, (address(asset), 1e18));
        address[3] memory safes = [address(asset), address(orders), address(emergency)];
        for (uint256 i = 0; i < safes.length; i++) {
            _refused(safes[i], FIRST_LOSS, Mainnet.EARN_ETH_SHARE, move, NOT_AUTHORIZED);
            _refused(safes[i], FIRST_LOSS_BURN, Mainnet.EARN_ETH_SHARE, burn, NOT_AUTHORIZED);
        }
        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        bytes memory pull = abi.encodeCall(IERC20.transferFrom, (address(firstLoss), address(asset), 1e18));
        _operator(Mainnet.EARN_ETH_SHARE, pull, false);
        vm.prank(address(emergency));
        (bool ok,) = address(safetyMod).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (Mainnet.EARN_ETH_SHARE, 0, pull, 0, EMERGENCY, true))
        );
        assertFalse(ok, "the emergency role cannot pull them");
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), held, "the shares stay");
    }

    // ---------------------------------------------------------------------
    // INV-039: the insurance deposit (ADR 014, decisions 11 and 12)
    // ---------------------------------------------------------------------

    /// @dev One motion sets the insurance budget, moves USDC from the Asset Safe to the first-loss Safe and
    ///      deposits it into earnUSD's deposit queue. The queue records the request for the first-loss Safe,
    ///      and no approval stays.
    function test_insurance_deposit_by_motion() public enabled {
        uint256 amount = 50_000e6;
        address queue = Mainnet.EARN_USD_DEPOSIT_QUEUE;
        uint256 assetBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 firstLossBefore = IERC20(Mainnet.USDC).balanceOf(address(firstLoss));
        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](4);
        ws[0] = _budget(Mainnet.USDC, address(firstLoss), uint128(amount));
        ws[1] = _money(Mainnet.USDC, amount);
        (ws[2], ws[3]) = _deposit(Mainnet.USDC, queue, amount);
        _motion(ws);

        assertEq(assetBefore - IERC20(Mainnet.USDC).balanceOf(address(asset)), amount, "the Asset Safe pays the insurance money");
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), firstLossBefore, "the first-loss Safe keeps none of it");
        assertEq(IERC20(Mainnet.USDC).allowance(address(firstLoss), queue), 0, "no approval stays");
        (uint256 at, uint256 assets) = IDepositQueue(queue).requestOf(address(firstLoss));
        console2.log("FIRST-LOSS earnUSD deposit request: timestamp, assets", at, assets);
        assertEq(assets, amount, "the queue records the first-loss Safe's request");
        (, uint256 assetSafeRequest) = IDepositQueue(queue).requestOf(address(asset));
        assertEq(assetSafeRequest, 0, "the Asset Safe has no request");

        // The queue's claim names the account that it pays, and anyone may call it: the shares reach the
        // first-loss Safe without a role. Before the vault's next report it claims nothing.
        vm.prank(stranger);
        (bool ok, bytes memory ret) = queue.call(abi.encodeWithSignature("claim(address)", address(firstLoss)));
        console2.log("FIRST-LOSS claim by a stranger for the first-loss Safe: accepted (1 = yes), returned bytes", ok ? 1 : 0, ret.length);
        assertTrue(ok, "anyone may call the claim for the first-loss Safe");
    }

    /// @dev The earnETH queue takes wstETH that the first-loss Safe holds.
    function test_insurance_deposit_into_earn_eth() public enabled {
        uint256 amount = 5e18;
        deal(Mainnet.WSTETH, address(firstLoss), amount);
        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](2);
        (ws[0], ws[1]) = _deposit(Mainnet.WSTETH, EARN_ETH_DEPOSIT_QUEUE, amount);
        _motion(ws);
        assertEq(IERC20(Mainnet.WSTETH).balanceOf(address(firstLoss)), 0, "the wstETH went into the queue");
        assertEq(IERC20(Mainnet.WSTETH).allowance(address(firstLoss), EARN_ETH_DEPOSIT_QUEUE), 0, "no approval stays");
        (, uint256 assets) = IDepositQueue(EARN_ETH_DEPOSIT_QUEUE).requestOf(address(firstLoss));
        assertEq(assets, amount, "the queue records the first-loss Safe's request");
    }

    /// @dev The first-loss modifier's policy names each token with its queue. A token with another vault's queue,
    ///      a token outside the policy and a queue outside the policy each fail at enactment as a whole, and the
    ///      money and the approvals stay as they were.
    function test_insurance_deposit_refusals() public enabled {
        address queue = Mainnet.EARN_USD_DEPOSIT_QUEUE;
        deal(Mainnet.USDC, address(firstLoss), 9e6);
        deal(Mainnet.USDT, address(firstLoss), 9e6);
        address[3] memory tokens = [Mainnet.USDC, Mainnet.USDT, Mainnet.USDC];
        address[3] memory queues = [EARN_ETH_DEPOSIT_QUEUE, queue, stranger];
        for (uint256 i = 0; i < tokens.length; i++) {
            UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](2);
            (ws[0], ws[1]) = _deposit(tokens[i], queues[i], 1e6);
            _enactmentFails(_calldata(ws));
        }
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), 9e6, "the USDC stays");
        assertEq(IERC20(Mainnet.USDT).balanceOf(address(firstLoss)), 9e6, "the USDT stays");
        assertEq(IERC20(Mainnet.USDC).allowance(address(firstLoss), EARN_ETH_DEPOSIT_QUEUE), 0, "no approval for another queue");
        assertEq(IERC20(Mainnet.USDC).allowance(address(firstLoss), stranger), 0, "no approval for a stranger");
    }

    /// @dev The insurance role approves only each token's own deposit queue and deposits only with no referral.
    ///      It holds no transfer and no call of a share token, and only the factory holds it.
    function test_insurance_role_holds_only_its_calls() public enabled {
        address queue = Mainnet.EARN_USD_DEPOSIT_QUEUE;
        bytes32[] memory noProof = new bytes32[](0);
        _refused(address(uf), INSURANCE, Mainnet.USDC, abi.encodeCall(IERC20.approve, (stranger, 1)), CONDITION_VIOLATION);
        _refused(address(uf), INSURANCE, Mainnet.USDC, abi.encodeCall(IERC20.approve, (EARN_ETH_DEPOSIT_QUEUE, 1)), CONDITION_VIOLATION);
        _refused(address(uf), INSURANCE, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (stranger, 1)), CONDITION_VIOLATION);
        _refused(address(uf), INSURANCE, Mainnet.USDT, abi.encodeCall(IERC20.approve, (queue, 1)), CONDITION_VIOLATION);
        _refused(address(uf), INSURANCE, Mainnet.EARN_USD_SHARE, abi.encodeCall(IERC20.approve, (queue, 1)), CONDITION_VIOLATION);
        _refused(address(uf), INSURANCE, Mainnet.EARN_USD_SHARE, abi.encodeWithSignature("burn(uint256)", 1), CONDITION_VIOLATION);
        _refused(
            address(uf), INSURANCE, queue,
            abi.encodeWithSignature("deposit(uint224,address,bytes32[])", uint224(1e6), stranger, noProof), CONDITION_VIOLATION
        );
        _refused(address(uf), INSURANCE, queue, abi.encodeWithSignature("cancelDepositRequest()"), CONDITION_VIOLATION);
        _refused(Mainnet.COMMITTEE_SAFE, INSURANCE, Mainnet.USDC, abi.encodeCall(IERC20.approve, (queue, 1)), NO_MEMBERSHIP);
        _refused(stranger, INSURANCE, Mainnet.USDC, abi.encodeCall(IERC20.approve, (queue, 1)), NOT_AUTHORIZED);
    }

    // ---------------------------------------------------------------------
    // INV-039: a fund with a fixed payout address (ADR 014, decision 6)
    // ---------------------------------------------------------------------

    /// @dev One motion creates the fund: it pins the payout address and sets the cap. A later motion pays out,
    ///      only to that address and only within what is left of the cap, which never refills.
    function test_fund_create_and_payout_by_motion() public enabled {
        address token = Mainnet.USDC;
        uint256 cap = 30_000e6;
        _insuranceMoney(token, 40_000e6);
        _motion(_fund(token, payout, cap));
        bytes32 key = _key(token, payout);
        (uint128 refill,, uint64 period, uint128 left,) = firstLossMod.allowances(key);
        assertEq(left, cap, "the cap");
        assertEq(uint256(refill) + period, 0, "no refill and no period: the cap never refills");
        assertEq(IERC20(token).balanceOf(payout), 0, "the creation pays nothing");

        _motion(_one(_payout(token, payout, 10_000e6)));
        assertEq(IERC20(token).balanceOf(payout), 10_000e6, "the payout address receives the payout");
        assertEq(IERC20(token).balanceOf(address(firstLoss)), 30_000e6, "the first-loss Safe pays it");
        (,,, left,) = firstLossMod.allowances(key);
        assertEq(left, 20_000e6, "what is left of the cap");

        // above what is left: nothing moves, also after a month, because the cap does not refill
        _enactmentFails(_calldata(_one(_payout(token, payout, 20_000e6 + 1))));
        vm.warp(block.timestamp + 40 days);
        _enactmentFails(_calldata(_one(_payout(token, payout, 20_000e6 + 1))));
        assertEq(IERC20(token).balanceOf(payout), 10_000e6, "no payout above the cap");

        _motion(_one(_payout(token, payout, 20_000e6)));
        assertEq(IERC20(token).balanceOf(payout), cap, "the whole cap, and no more");
        _enactmentFails(_calldata(_one(_payout(token, payout, 1))));
    }

    /// @dev A payout goes only to the fund's own address, in the fund's own token: before the fund exists, to
    ///      another address and in another token, it fails at enactment as a whole.
    function test_fund_payout_refusals() public enabled {
        address token = Mainnet.USDC;
        _insuranceMoney(token, 40_000e6);
        deal(Mainnet.USDT, address(firstLoss), 1e6);
        _enactmentFails(_calldata(_one(_payout(token, payout, 1e6))));

        _motion(_fund(token, payout, 30_000e6));
        _enactmentFails(_calldata(_one(_payout(token, stranger, 1e6))));
        _enactmentFails(_calldata(_one(_payout(token, Mainnet.COMMITTEE_SAFE, 1e6))));
        _enactmentFails(_calldata(_one(_payout(Mainnet.USDT, payout, 1e6))));
        assertEq(IERC20(token).balanceOf(payout), 0, "nothing was paid");
        assertEq(IERC20(token).balanceOf(address(firstLoss)), 40_000e6, "the insurance money stays");
    }

    /// @dev The governance role's guard binds a fund's creation: a fund in a first-loss share token, and one on
    ///      the first-loss Safe or its modifier, fail at enactment as a whole. A cap that refills fails too.
    function test_fund_create_refusals() public enabled {
        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        address[3] memory kept = [Mainnet.EARN_ETH_SHARE, address(firstLoss), address(firstLossMod)];
        for (uint256 i = 0; i < kept.length; i++) {
            _enactmentFails(_calldata(_fund(kept[i], payout, held)));
        }
        (,,, uint128 left,) = firstLossMod.allowances(_key(Mainnet.EARN_ETH_SHARE, payout));
        assertEq(left, 0, "no fund of first-loss shares");

        UniversalFactory.Write[] memory refills = _fund(Mainnet.USDT, payout, 1e6);
        refills[2] = _fundGovern(abi.encodeCall(IRoles.setAllowance, (_key(Mainnet.USDT, payout), 1e6, 1e6, 1e6, 30 days, 0)));
        _enactmentFails(_calldata(refills));
        deal(Mainnet.USDT, address(firstLoss), 1e6);
        _refused(address(uf), INSURANCE, Mainnet.USDT, abi.encodeCall(IERC20.transfer, (payout, 1)), CONDITION_VIOLATION);
    }

    /// @dev The exit of a fund (ADR 008, decision 28; INV-038): the committee's Safe sends insurance money back
    ///      to the Asset Safe, and to no other receiver. It cannot send a share token or a token outside the list.
    function test_fund_exit_pays_only_the_asset_safe() public enabled {
        deal(Mainnet.USDC, address(firstLoss), 9_000e6);
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(asset));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        firstLossMod.execTransactionWithRole(
            Mainnet.USDC, 0, abi.encodeCall(IERC20.transfer, (address(asset), 9_000e6)), 0, FIRST_LOSS, true
        );
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - before, 9_000e6, "the Asset Safe receives the exit");
        deal(Mainnet.USDC, address(firstLoss), 1e6);
        address[4] memory others = [Mainnet.AGENT, Mainnet.COMMITTEE_SAFE, payout, stranger];
        for (uint256 i = 0; i < others.length; i++) {
            _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (others[i], 1)), CONDITION_VIOLATION);
        }
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, Mainnet.EARN_USD_SHARE, abi.encodeCall(IERC20.transfer, (address(asset), 1)), CONDITION_VIOLATION);
        _refused(Mainnet.COMMITTEE_SAFE, FIRST_LOSS, Mainnet.WBTC, abi.encodeCall(IERC20.transfer, (address(asset), 1)), CONDITION_VIOLATION);
    }

    /// @dev The insurance-governance role writes only a fund: under the insurance key, a plain transfer, on no
    ///      vault account and no share token, and a cap that never refills. It holds no membership setter and no
    ///      other grant, and only the factory holds it.
    function test_insurance_governance_writes_only_a_fund() public enabled {
        IRoles.ConditionFlat[] memory tree = _payoutTree(payout, _key(Mainnet.USDT, payout));
        bytes4 transfer = IERC20.transfer.selector;
        address mod = address(firstLossMod);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (INSURANCE, Mainnet.USDT, IERC20.approve.selector, tree, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (FIRST_LOSS, Mainnet.USDT, transfer, tree, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (FIRST_LOSS_BURN, Mainnet.USDT, transfer, tree, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (GOVERNANCE_OF_FUNDS, Mainnet.USDT, transfer, tree, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (INSURANCE, Mainnet.USDT, transfer, tree, 1)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (INSURANCE, Mainnet.USDT, transfer, tree, 2)), CONDITION_VIOLATION);
        address[4] memory kept = [Mainnet.EARN_ETH_SHARE, Mainnet.EARN_USD_SHARE, address(firstLoss), address(firstLossMod)];
        for (uint256 i = 0; i < kept.length; i++) {
            _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeTarget, (INSURANCE, kept[i])), CONDITION_VIOLATION);
            _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeFunction, (INSURANCE, kept[i], transfer, tree, 0)), CONDITION_VIOLATION);
        }
        bytes32 key = _key(Mainnet.USDT, payout);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.setAllowance, (key, 1e6, 1e6, 1, 30 days, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.setAllowance, (key, 1e6, 1, 0, 0, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.setAllowance, (bytes32("not-derived"), 1e6, 0, 0, 0, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.allowTarget, (INSURANCE, Mainnet.USDT, 0)), CONDITION_VIOLATION);
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.allowFunction, (INSURANCE, Mainnet.USDT, transfer, 0)), CONDITION_VIOLATION);
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = INSURANCE;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _refused(address(uf), GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.assignRoles, (stranger, keys, yes)), CONDITION_VIOLATION);
        _refused(Mainnet.COMMITTEE_SAFE, GOVERNANCE_OF_FUNDS, mod, abi.encodeCall(IRoles.scopeTarget, (INSURANCE, Mainnet.USDT)), NO_MEMBERSHIP);
        // before a fund exists, the insurance role holds no transfer
        deal(Mainnet.USDT, address(firstLoss), 1e6);
        _refused(address(uf), INSURANCE, Mainnet.USDT, abi.encodeCall(IERC20.transfer, (payout, 1)), CONDITION_VIOLATION);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// @dev Insurance money in the first-loss Safe: one motion sets the budget and moves the money.
    function _insuranceMoney(address token, uint256 amount) internal {
        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](2);
        ws[0] = _budget(token, address(firstLoss), uint128(amount));
        ws[1] = _money(token, amount);
        _motion(ws);
    }

    /// @dev The insurance-funding role's transfer of a token from the Asset Safe to the first-loss Safe.
    function _money(address token, uint256 amount) internal view returns (UniversalFactory.Write memory) {
        return _w(opMod, INSURANCE_FUNDING, token, abi.encodeCall(IERC20.transfer, (address(firstLoss), amount)));
    }

    function _burn(address share, uint256 amount) internal view returns (UniversalFactory.Write memory) {
        return _w(firstLossMod, FIRST_LOSS_BURN, share, abi.encodeWithSignature("burn(uint256)", amount));
    }

    /// @dev An insurance deposit: the approval of the queue for the exact amount, and the deposit with no referral.
    function _deposit(address token, address queue, uint256 amount)
        internal
        view
        returns (UniversalFactory.Write memory approve, UniversalFactory.Write memory deposit)
    {
        approve = _w(firstLossMod, INSURANCE, token, abi.encodeCall(IERC20.approve, (queue, amount)));
        deposit = _w(
            firstLossMod,
            INSURANCE,
            queue,
            abi.encodeWithSignature("deposit(uint224,address,bytes32[])", uint224(amount), address(0), new bytes32[](0))
        );
    }

    /// @dev A write of the insurance-governance role: a call of the first-loss modifier on itself.
    function _fundGovern(bytes memory write) internal view returns (UniversalFactory.Write memory) {
        return _w(firstLossMod, GOVERNANCE_OF_FUNDS, address(firstLossMod), write);
    }

    /// @dev The creation of a fund: the insurance role's transfer of the token, pinned to the payout address,
    ///      and the cap as a budget key that never refills.
    function _fund(address token, address to, uint256 cap) internal view returns (UniversalFactory.Write[] memory ws) {
        bytes32 key = _key(token, to);
        ws = new UniversalFactory.Write[](3);
        ws[0] = _fundGovern(abi.encodeCall(IRoles.scopeTarget, (INSURANCE, token)));
        ws[1] = _fundGovern(abi.encodeCall(IRoles.scopeFunction, (INSURANCE, token, IERC20.transfer.selector, _payoutTree(to, key), 0)));
        ws[2] = _fundGovern(abi.encodeCall(IRoles.setAllowance, (key, uint128(cap), 0, 0, 0, 0)));
    }

    /// @dev A payout: the insurance role's transfer from the first-loss Safe.
    function _payout(address token, address to, uint256 amount) internal view returns (UniversalFactory.Write memory) {
        return _w(firstLossMod, INSURANCE, token, abi.encodeCall(IERC20.transfer, (to, amount)));
    }

    /// @dev A transfer's tree that pins the receiver and spends `key`, in the policy compiler's form.
    function _payoutTree(address to, bytes32 key) internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](3);
        c[0] = IRoles.ConditionFlat(0, 5, 5, "");
        c[1] = IRoles.ConditionFlat(0, 1, 16, abi.encode(to));
        c[2] = IRoles.ConditionFlat(0, 1, 28, abi.encode(key));
    }

    function _refused(address member, bytes32 role, address to, bytes memory data, bytes4 reason) internal {
        vm.prank(member);
        (bool ok, bytes memory ret) =
            address(firstLossMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, role, true)));
        assertFalse(ok, "the first-loss modifier must refuse");
        assertEq(bytes4(ret), reason, "the reason of the refusal");
    }
}
