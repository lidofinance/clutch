// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

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
            bytes memory cd = _calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(shares[i], amounts[i]))));
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

    /// @dev Only the committee's Safe creates a burn motion, and a burn of nothing is refused at
    ///      creation. A burn of a token that the first-loss policy does not name fails at
    ///      enactment as a whole, and so does a burn of more than the Safe holds.
    function test_first_loss_burn_refusals() public enabled {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        bytes memory cd = _calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(Mainnet.EARN_ETH_SHARE, uint256(1e18)))));
        vm.prank(stranger);
        vm.expectRevert();
        et.createMotion(address(uf), cd);

        bytes memory zero = _calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(Mainnet.EARN_ETH_SHARE, uint256(0)))));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(UniversalFactory.ZeroAmount.selector);
        et.createMotion(address(uf), zero);

        address[3] memory vault = [address(firstLoss), address(firstLossMod), address(asset)];
        for (uint256 i = 0; i < vault.length; i++) {
            bytes memory bad = _calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(vault[i], uint256(1)))));
            vm.prank(Mainnet.COMMITTEE_SAFE);
            vm.expectRevert(abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, vault[i]));
            et.createMotion(address(uf), bad);
        }

        // a token outside the policy: USDC, of which the first-loss Safe holds some
        deal(Mainnet.USDC, address(firstLoss), 5e6);
        _enactmentFails(_calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(Mainnet.USDC, uint256(1e6))))));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), 5e6, "nothing left the first-loss Safe");

        // more than the Safe holds
        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        _enactmentFails(_calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(Mainnet.EARN_ETH_SHARE, held + 1)))));
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

        bytes memory cd = _calldata(_one(_op(uf.FIRST_LOSS_BURN(), abi.encode(Mainnet.EARN_ETH_SHARE, uint256(1e18)))));
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
    // Helpers
    // ---------------------------------------------------------------------

    function _refused(address member, bytes32 role, address to, bytes memory data, bytes4 reason) internal {
        vm.prank(member);
        (bool ok, bytes memory ret) =
            address(firstLossMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, role, true)));
        assertFalse(ok, "the first-loss modifier must refuse");
        assertEq(bytes4(ret), reason, "the reason of the refusal");
    }

    /// @dev A motion that passes its creation and fails at enactment as a whole.
    function _enactmentFails(bytes memory cd) internal {
        uint256 id = _create(cd);
        _afterWindow();
        vm.prank(anyone);
        (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, cd)));
        assertFalse(ok, "the enactment fails");
    }
}
