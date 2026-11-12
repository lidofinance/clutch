// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @dev A factory that tries to reach past the universal factory's address book.
contract RogueFactory {
    function createEVMScript(address, bytes calldata) external pure returns (bytes memory) {
        bytes memory transfer = abi.encodeCall(IERC20.transfer, (address(0xdEaD), 1));
        return abi.encodePacked(bytes4(0x00000001), Mainnet.USDC, uint32(transfer.length), transfer);
    }
}

/// @title UniversalFactoryRehearsal — the universal factory's prototype (ADR 013) against the
///        live Easy Track, its executor and the vault that the enabling vote sets up, on a
///        mainnet fork (enabling-vote spec, "Rebuilding the rehearsal", step 1).
/// @dev Each test names the invariant that it checks. Lines that start with "PROTOTYPE" are
///      the measures for EM's choice between options A and B (ADR 013, decision 11).
///      Run: RPC=<archive RPC> forge test --match-contract UniversalFactoryRehearsal -vv
contract UniversalFactoryRehearsal is EnabledVault {
    address internal newVault = makeAddr("new-vault");
    address internal otherVault = makeAddr("other-vault");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote runs inside each test, as in the rehearsal: the batch
    ///      measurements cool the new accounts, and accounts cooled in setUp do not
    ///      reach the test.
    modifier enabled() {
        _enable();
        _;
    }

    // ---------------------------------------------------------------------
    // INV-032: the address book
    // ---------------------------------------------------------------------

    /// @dev The registration that the enabling vote writes is the address book:
    ///      one call, the factory's own `applyMotion` (ADR 013, decision 18). A
    ///      script that reaches anything else does not pass Easy Track, and only
    ///      Aragon Voting registers a factory.
    function test_uf_address_book_is_the_registration() public enabled {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        bytes memory book = et.evmScriptFactoryPermissions(address(uf));
        assertEq(book, abi.encodePacked(address(uf), uf.applyMotion.selector), "the address book");

        RogueFactory rogue = new RogueFactory();
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert();
        et.addEVMScriptFactory(address(rogue), book);
        vm.prank(Mainnet.VOTING);
        et.addEVMScriptFactory(address(rogue), book);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(bytes("HAS_NO_PERMISSIONS"));
        et.createMotion(address(rogue), "");
    }

    /// @dev The universal factory holds the motion roles, and Easy Track's executor, which every
    ///      Easy Track factory shares, holds none (decision 18). A motion's script is one call,
    ///      `applyMotion`, which checks the motion again: the executor's own call of it is refused
    ///      like a motion that the checks refuse. `writesOf` shows the writes that it would make.
    function test_uf_the_factory_holds_the_motion_roles() public enabled {
        bytes memory restore = abi.encodeCall(IRoles.scopeTarget, (OPERATOR, newVault));
        bytes memory viaRole = abi.encodeCall(IRoles.execTransactionWithRole, (address(opMod), 0, restore, 0, GOVERNANCE, true));
        vm.prank(Mainnet.ET_EXECUTOR);
        (bool ok,) = address(opMod).call(viaRole);
        assertFalse(ok, "the executor holds no role");

        bytes memory cd = _calldata(_one(_op(uf.RESTORE(), abi.encode(newVault))));
        bytes memory call = abi.encodeCall(uf.applyMotion, (cd));
        assertEq(
            uf.createEVMScript(Mainnet.COMMITTEE_SAFE, cd),
            abi.encodePacked(bytes4(0x00000001), address(uf), uint32(call.length), call),
            "a script of one call"
        );
        (address[] memory to, bytes[] memory data) = uf.writesOf(cd);
        assertEq(to.length, 1, "one write");
        assertEq(to[0], address(opMod), "on the operator modifier");
        assertEq(data[0], viaRole, "through the governance role");

        bytes memory protectedTarget = _calldata(_one(_op(uf.RESTORE(), abi.encode(address(asset)))));
        vm.prank(Mainnet.ET_EXECUTOR);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, address(asset)));
        uf.applyMotion(protectedTarget);

        _motion(_one(_op(uf.RESTORE(), abi.encode(newVault))));
        vm.prank(address(uf));
        (ok,) = address(opMod).call(viaRole);
        assertTrue(ok, "the factory holds the governance role");
    }

    /// @dev A write that the vault refuses fails the whole enactment, and the motion's versions
    ///      stay as they were: with the operator modifier disabled, and the counter left as it
    ///      is, a budget motion fails at enactment.
    function test_uf_a_refused_write_fails_the_whole_motion() public enabled {
        bytes memory cd = _calldata(_one(_budgetOp(Mainnet.USDC, newVault, 1_000e6, bytes32(0))));
        bytes32 scope = uf.allowanceScope(uf.keyFor(Mainnet.USDC, newVault));
        uint256 id = _create(cd);
        _afterWindow();
        _disableOperatorModifier();
        vm.prank(anyone);
        (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, cd)));
        assertFalse(ok, "the enactment fails");
        assertEq(uf.versions(scope), bytes32(0), "the version stays");
    }

    /// @dev The factory writes an approval list exactly as the policy compiler does, so the
    ///      launch lists that seed its versions are the lists that the vote applies (ADR 004).
    function test_uf_approval_tree_matches_the_compiler() public enabled {
        string memory j = vm.readFile(ARTIFACT);
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        uint256 seen;
        for (uint256 i = 0; i < to.length; i++) {
            if (to[i] != address(opMod) || bytes4(data[i]) != IRoles.scopeFunction.selector) continue;
            (bytes32 key, address target, bytes4 selector, IRoles.ConditionFlat[] memory c, uint8 options) =
                abi.decode(_args(data[i]), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (key != OPERATOR || selector != IERC20.approve.selector) continue;
            IRoles.ConditionFlat[] memory built = uf.approvalTree(launchApprovals(target));
            assertEq(built.length, c.length, "the same size");
            for (uint256 k = 0; k < c.length; k++) {
                assertEq(built[k].parent, c[k].parent, "parent");
                assertEq(built[k].paramType, c[k].paramType, "paramType");
                assertEq(built[k].operator_, c[k].operator_, "operator");
                assertEq(built[k].compValue, c[k].compValue, "compValue");
            }
            assertEq(options, 0, "no delegatecall");
            seen++;
        }
        assertEq(seen, 5, "every launch approval list");
    }

    /// @dev The factory writes the operator's `transfer` tree of an orders token exactly as the policy compiler
    ///      does: the return to the Aragon Agent, or the funding of the orders account under the token's key.
    function test_uf_transfer_tree_matches_the_compiler() public enabled {
        string memory j = vm.readFile(ARTIFACT);
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        uint256 seen;
        for (uint256 i = 0; i < to.length; i++) {
            if (to[i] != address(opMod) || bytes4(data[i]) != IRoles.scopeFunction.selector) continue;
            (bytes32 key, address target, bytes4 selector, IRoles.ConditionFlat[] memory c, uint8 options) =
                abi.decode(_args(data[i]), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (key != OPERATOR || selector != IERC20.transfer.selector) continue;
            IRoles.ConditionFlat[] memory built = uf.transferTree(uf.keyFor(target, address(orders)));
            assertEq(abi.encode(built), abi.encode(c), "the same tree");
            assertEq(options, 0, "no delegatecall");
            seen++;
        }
        assertEq(seen, 6, "every launch order token");
    }

    // ---------------------------------------------------------------------
    // INV-033: versions and the counter
    // ---------------------------------------------------------------------

    function test_uf_same_scope_conflict_the_first_enactment_wins() public enabled {
        _conflict(true);
    }

    function test_uf_same_scope_conflict_in_the_other_order() public enabled {
        _conflict(false);
    }

    /// @dev Two motions on one scope, both created against the same version: the first
    ///      enactment wins, the second fails at enactment and stays open until its creator
    ///      cancels it.
    function _conflict(bool firstA) internal {
        UniversalFactory.Entry[] memory current = launchApprovals(Mainnet.USDC);
        bytes memory a = _calldata(_one(_approvalsOp(Mainnet.USDC, current, _with(current, _derived(Mainnet.USDC, newVault)))));
        bytes memory b = _calldata(_one(_approvalsOp(Mainnet.USDC, current, _with(current, _derived(Mainnet.USDC, otherVault)))));
        uint256 idA = _create(a);
        uint256 idB = _create(b);
        _afterWindow();
        (uint256 winner, bytes memory w, uint256 loser, bytes memory l) = firstA ? (idA, a, idB, b) : (idB, b, idA, a);
        _enact(winner, w);
        bytes32 scope = uf.functionScope(Mainnet.USDC, IERC20.approve.selector);
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleVersion.selector, scope));
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(loser, l);
        // The loser stays open until its creator cancels it.
        uint256 open = IEasyTrack(Mainnet.EASY_TRACK).getMotions().length;
        vm.prank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(loser);
        assertEq(IEasyTrack(Mainnet.EASY_TRACK).getMotions().length, open - 1, "the cancel frees the slot");
        address won = firstA ? newVault : otherVault;
        address lost = firstA ? otherVault : newVault;
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (won, 0)), true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (lost, 0)), false);
    }

    function test_uf_disjoint_scopes_enact_in_any_order() public enabled {
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        UniversalFactory.Entry[] memory dai = launchApprovals(Mainnet.DAI);
        bytes memory a = _calldata(_one(_approvalsOp(Mainnet.USDC, usdc, _with(usdc, _derived(Mainnet.USDC, newVault)))));
        bytes memory b = _calldata(_one(_approvalsOp(Mainnet.DAI, dai, _with(dai, _derived(Mainnet.DAI, newVault)))));
        bytes32 seeded = uf.budgetVersion(EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, MONTH);
        bytes memory c = _calldata(_one(_budgetOp(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, 1_000e6, seeded)));
        uint256 idA = _create(a);
        uint256 idB = _create(b);
        uint256 idC = _create(c);
        _afterWindow();
        _enact(idC, c);
        _enact(idB, b);
        _enact(idA, a);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (newVault, 0)), true);
        _operator(Mainnet.DAI, abi.encodeCall(IERC20.approve, (newVault, 0)), true);
    }

    /// @dev The emergency Safe raises the counter, and every open motion fails at enactment.
    ///      Aragon Voting can raise it too; nobody else can.
    function test_uf_counter_fails_every_open_motion() public enabled {
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        bytes memory a = _calldata(_one(_approvalsOp(Mainnet.USDC, usdc, _with(usdc, _derived(Mainnet.USDC, newVault)))));
        bytes memory r = _calldata(_one(_op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(1e6)))));
        uint256 idA = _create(a);
        uint256 idR = _create(r);

        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotAllowedToRaiseCounter.selector, Mainnet.COMMITTEE_SAFE));
        uf.raiseCounter();
        vm.prank(address(emergency));
        uf.raiseCounter();

        _afterWindow();
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(idA, a);
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(idR, r);
        vm.startPrank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(idA);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(idR);
        vm.stopPrank();

        vm.prank(Mainnet.VOTING);
        uf.raiseCounter();
        assertEq(uf.epoch(), 2, "Aragon Voting raised it too");
        _motion(_one(_approvalsOp(Mainnet.USDC, usdc, _with(usdc, _derived(Mainnet.USDC, newVault)))));
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (newVault, 0)), true);
    }

    // ---------------------------------------------------------------------
    // INV-034: widening only through the shape; raw writes only narrow
    // ---------------------------------------------------------------------

    /// @dev A new spender widens with the key that the factory derives, and its budget comes
    ///      from a budget motion within the token's ceiling. The governance role's guard
    ///      accepts the derived key (ADR 013, decision 9).
    function test_uf_widening_fills_the_shape() public enabled {
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        UniversalFactory.Op[] memory ops = new UniversalFactory.Op[](2);
        ops[0] = _approvalsOp(Mainnet.USDC, usdc, _with(usdc, _derived(Mainnet.USDC, newVault)));
        ops[1] = _budgetOp(Mainnet.USDC, newVault, 50_000e6, bytes32(0));
        _motion(ops);
        bytes32 key = uf.keyFor(Mainnet.USDC, newVault);
        assertEq(bytes2(key), bytes2("k:"), "a derived key");
        (,,, uint128 balance,) = opMod.allowances(key);
        assertEq(balance, 50_000e6, "its budget");
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (newVault, 50_000e6)), true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (newVault, 1)), false);
        // the launch spender keeps its own key
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), true);
    }

    function test_uf_refuses_a_widening_outside_the_shape() public enabled {
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        UniversalFactory.Entry[] memory usds = launchApprovals(Mainnet.USDS);

        // a budgeted spender whose key is not the derived one
        UniversalFactory.Entry memory foreign = UniversalFactory.Entry(newVault, bytes32("sky_savings_usds"), 0);
        _refuse(
            _approvalsOp(Mainnet.USDC, usdc, _with(usdc, foreign)),
            abi.encodeWithSelector(UniversalFactory.KeyNotDerived.selector, newVault, bytes32("sky_savings_usds"))
        );
        // a capped spender above the token's approval ceiling, and a token without one
        _refuse(
            _approvalsOp(Mainnet.USDS, usds, _with(usds, UniversalFactory.Entry(newVault, bytes32(0), SIZE_STANDIN_USD + 1))),
            abi.encodeWithSelector(UniversalFactory.CapAboveCeiling.selector, Mainnet.USDS, SIZE_STANDIN_USD + 1, SIZE_STANDIN_USD)
        );
        _refuse(
            _approvalsOp(Mainnet.USDC, usdc, _with(usdc, UniversalFactory.Entry(newVault, bytes32(0), 1))),
            abi.encodeWithSelector(UniversalFactory.CapAboveCeiling.selector, Mainnet.USDC, 1, 0)
        );
        // a cap raised on an existing spender is a widening
        UniversalFactory.Entry[] memory dai = launchApprovals(Mainnet.DAI);
        UniversalFactory.Entry[] memory raised = launchApprovals(Mainnet.DAI);
        raised[0].cap = SIZE_STANDIN_USD + 1;
        _refuse(
            _approvalsOp(Mainnet.DAI, dai, raised),
            abi.encodeWithSelector(UniversalFactory.CapAboveCeiling.selector, Mainnet.DAI, SIZE_STANDIN_USD + 1, SIZE_STANDIN_USD)
        );
        // a vault account as spender or token
        address[4] memory vault = [address(asset), address(opMod), address(safetyMod), address(firstLoss)];
        for (uint256 i = 0; i < vault.length; i++) {
            _refuse(
                _approvalsOp(Mainnet.USDC, usdc, _with(usdc, UniversalFactory.Entry(vault[i], uf.keyFor(Mainnet.USDC, vault[i]), 0))),
                abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, vault[i])
            );
        }
        _refuse(
            _approvalsOp(address(asset), new UniversalFactory.Entry[](0), usdc),
            abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, address(asset))
        );
        // a list out of its canonical order, and a stale current list
        UniversalFactory.Entry[] memory unsorted = new UniversalFactory.Entry[](2);
        unsorted[0] = usds[1];
        unsorted[1] = usds[0];
        _refuse(_approvalsOp(Mainnet.USDS, usds, unsorted), abi.encodeWithSelector(UniversalFactory.NotCanonical.selector));
        _refuse(
            _approvalsOp(Mainnet.USDC, new UniversalFactory.Entry[](0), usdc),
            abi.encodeWithSelector(UniversalFactory.StaleVersion.selector, uf.functionScope(Mainnet.USDC, IERC20.approve.selector))
        );
    }

    /// @dev Removing a spender, lowering a cap and revoking a function need no shape.
    function test_uf_raw_writes_only_narrow() public enabled {
        UniversalFactory.Entry[] memory usds = launchApprovals(Mainnet.USDS);
        UniversalFactory.Entry[] memory dai = launchApprovals(Mainnet.DAI);
        UniversalFactory.Entry[] memory lower = launchApprovals(Mainnet.DAI);
        lower[0].cap = 1_000e18;
        UniversalFactory.Op[] memory ops = new UniversalFactory.Op[](3);
        ops[0] = _approvalsOp(Mainnet.USDS, usds, _without(usds, DAI_USDS));
        ops[1] = _approvalsOp(Mainnet.DAI, dai, lower);
        ops[2] = _op(
            uf.REVOKE(),
            abi.encode(Mainnet.WSTETH, IERC20.approve.selector, uf.versions(uf.functionScope(Mainnet.WSTETH, IERC20.approve.selector)))
        );
        _motion(ops);
        _operator(Mainnet.USDS, abi.encodeCall(IERC20.approve, (DAI_USDS, 0)), false);
        _operator(Mainnet.USDS, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, 0)), true);
        _operator(Mainnet.DAI, abi.encodeCall(IERC20.approve, (DAI_USDS, 1_000e18)), false);
        _operator(Mainnet.DAI, abi.encodeCall(IERC20.approve, (DAI_USDS, 999e18)), true);
        _operator(Mainnet.WSTETH, abi.encodeCall(IERC20.approve, (EARN_ETH_DEPOSIT_QUEUE, 0)), false);
        assertEq(uf.versions(uf.functionScope(Mainnet.WSTETH, IERC20.approve.selector)), bytes32(0), "a revoked scope holds nothing");
    }

    // ---------------------------------------------------------------------
    // INV-012 and INV-036: budgets within ceilings, and the limit on raises
    // ---------------------------------------------------------------------

    function test_uf_budget_stays_within_its_ceiling() public enabled {
        bytes32 seeded = uf.budgetVersion(EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, EARN_USD_DEPOSIT, MONTH);
        bytes32 key = bytes32("earn_usd_deposit");
        _refuse(
            _budgetOp(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, uint128(BUDGET_CEILING_USDC + 1), seeded),
            abi.encodeWithSelector(UniversalFactory.BudgetAboveCeiling.selector, key, BUDGET_CEILING_USDC)
        );
        _refuse(
            _op(uf.BUDGET(), abi.encode(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, uint128(1), uint128(1), uint128(1), uint64(29 days), seeded)),
            abi.encodeWithSelector(UniversalFactory.PeriodTooShort.selector, uint64(29 days))
        );
        _refuse(
            _budgetOp(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, 1, bytes32(uint256(1))),
            abi.encodeWithSelector(UniversalFactory.StaleVersion.selector, uf.allowanceScope(key))
        );
        // a token without a budget ceiling takes no budget
        _refuse(
            _budgetOp(Mainnet.PYUSD, newVault, 1, bytes32(0)),
            abi.encodeWithSelector(UniversalFactory.BudgetAboveCeiling.selector, uf.keyFor(Mainnet.PYUSD, newVault), 0)
        );
        _motion(_one(_budgetOp(Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, uint128(BUDGET_CEILING_USDC), seeded)));
        (,,, uint128 balance,) = opMod.allowances(key);
        assertEq(balance, BUDGET_CEILING_USDC, "a budget at its ceiling");
    }

    function test_uf_ceiling_rises_at_most_twofold_once_in_15_days() public enabled {
        bytes32 key = uf.ceilingKey(uf.BUDGET_CEILING(), Mainnet.USDC);
        uint256 c = BUDGET_CEILING_USDC;
        // the launch seed counts as the first raise, so the next one waits 15 days from it
        (, uint64 seededAt,) = uf.ceilings(key);
        assertEq(seededAt, deployedAt, "the seed's time");
        _refuse(_ceilingOp(key, c, 2 * c), abi.encodeWithSelector(UniversalFactory.RaiseTooSoon.selector, key, uint256(seededAt) + 15 days));
        vm.warp(uint256(seededAt) + 15 days);
        _refuse(_ceilingOp(key, c, 2 * c + 1), abi.encodeWithSelector(UniversalFactory.RaiseTooLarge.selector, key, 2 * c + 1, 2 * c));
        _motion(_one(_ceilingOp(key, c, 2 * c)));
        (, uint64 raisedAt,) = uf.ceilings(key);
        assertEq(raisedAt, block.timestamp, "the raise's time");
        _refuse(
            _ceilingOp(key, 2 * c, 2 * c + 1),
            abi.encodeWithSelector(UniversalFactory.RaiseTooSoon.selector, key, uint256(raisedAt) + 15 days)
        );
        // lowering needs no wait
        _motion(_one(_ceilingOp(key, 2 * c, c)));
        vm.warp(uint256(raisedAt) + 15 days);
        _motion(_one(_ceilingOp(key, c, 2 * c)));
        (uint256 value,,) = uf.ceilings(key);
        assertEq(value, 2 * c, "a raise 15 days after the last one");
        // a ceiling lowered to zero cannot rise by motion
        _motion(_one(_ceilingOp(key, 2 * c, 0)));
        _refuse(_ceilingOp(key, 0, 1), abi.encodeWithSelector(UniversalFactory.RaiseFromZero.selector, key));
        // a ceiling that was never set changes only with its token's introduction (decision 15)
        bytes32 none = uf.ceilingKey(uf.BUDGET_CEILING(), Mainnet.PYUSD);
        _refuse(_ceilingOp(none, 0, 1), abi.encodeWithSelector(UniversalFactory.CeilingNotSet.selector, none));
    }

    // ---------------------------------------------------------------------
    // INV-036 and decision 15: a token's introduction sets its ceilings
    // ---------------------------------------------------------------------

    uint256 internal constant INTRO_BUDGET_CEILING = 1_000_000e6;
    uint256 internal constant INTRO_APPROVAL_CEILING = 1_000e6;

    /// @dev A token outside the launch lists takes its first approval list and both of its
    ///      ceilings in one operation, and the same motion's budget for it stays under the new
    ///      budget ceiling. Without an introduction the token takes no list and no ceiling.
    function test_uf_a_new_token_is_introduced_with_its_ceilings() public enabled {
        address token = Mainnet.PYUSD;
        UniversalFactory.Entry[] memory list = _introList();
        bytes32 budgetKey = uf.ceilingKey(uf.BUDGET_CEILING(), token);

        // without an introduction, no list and no ceiling
        _refuse(
            _approvalsOp(token, new UniversalFactory.Entry[](0), list),
            abi.encodeWithSelector(UniversalFactory.TokenNotIntroduced.selector, token)
        );
        _refuse(_ceilingOp(budgetKey, 0, 1), abi.encodeWithSelector(UniversalFactory.CeilingNotSet.selector, budgetKey));
        // the introduction's own figures bound its list and the motion's budgets
        _refuse(
            _introduceOp(token, list, INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING - 1),
            abi.encodeWithSelector(
                UniversalFactory.CapAboveCeiling.selector, token, INTRO_APPROVAL_CEILING, INTRO_APPROVAL_CEILING - 1
            )
        );
        _refuse(
            _introduceOp(token, new UniversalFactory.Entry[](0), INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING),
            abi.encodeWithSelector(UniversalFactory.EmptyIntroduction.selector, token)
        );
        bytes32 newKey = uf.keyFor(token, newVault);
        _refuseMotion(
            _introduction(uint128(INTRO_BUDGET_CEILING + 1), false),
            abi.encodeWithSelector(UniversalFactory.BudgetAboveCeiling.selector, newKey, INTRO_BUDGET_CEILING)
        );
        // a budget before the introduction still sees no ceiling
        _refuseMotion(
            _introduction(500_000e6, true), abi.encodeWithSelector(UniversalFactory.BudgetAboveCeiling.selector, newKey, 0)
        );

        // one motion introduces the token, sets its ceilings and the new spender's budget
        _motion(_introduction(500_000e6, false));
        (uint256 value, uint64 raisedAt, bool set) = uf.ceilings(budgetKey);
        assertEq(value, INTRO_BUDGET_CEILING, "the budget ceiling");
        assertTrue(set, "the budget ceiling is set");
        assertEq(raisedAt, block.timestamp, "the introduction counts as the first raise");
        (value,, set) = uf.ceilings(uf.ceilingKey(uf.APPROVAL_CAP_CEILING(), token));
        assertEq(value, INTRO_APPROVAL_CEILING, "the approval ceiling");
        assertTrue(set, "the approval ceiling is set");
        assertEq(uf.versions(uf.functionScope(token, IERC20.approve.selector)), uf.listVersion(list), "the list's version");
        _operator(token, abi.encodeCall(IERC20.approve, (newVault, 500_000e6)), true);
        _operator(token, abi.encodeCall(IERC20.approve, (otherVault, INTRO_APPROVAL_CEILING)), false);
        _operator(token, abi.encodeCall(IERC20.approve, (otherVault, INTRO_APPROVAL_CEILING - 1)), true);
    }

    /// @dev A token is introduced once, also after its list is emptied, and the enabling vote
    ///      introduced the launch tokens. From then on decision 13 holds: the introduction is
    ///      the first raise, so the next raise waits 15 days.
    function test_uf_a_token_is_introduced_once() public enabled {
        address token = Mainnet.PYUSD;
        UniversalFactory.Entry[] memory list = _introList();
        _motion(_introduction(500_000e6, false));
        bytes memory again = abi.encodeWithSelector(UniversalFactory.AlreadyIntroduced.selector, token);
        _refuse(_introduceOp(token, list, 2 * INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING), again);
        _motion(_one(_approvalsOp(token, list, new UniversalFactory.Entry[](0))));
        _refuse(_introduceOp(token, list, 2 * INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING), again);
        _refuse(
            _introduceOp(Mainnet.USDC, launchApprovals(Mainnet.USDC), INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING),
            abi.encodeWithSelector(UniversalFactory.AlreadyIntroduced.selector, Mainnet.USDC)
        );

        bytes32 budgetKey = uf.ceilingKey(uf.BUDGET_CEILING(), token);
        (, uint64 raisedAt,) = uf.ceilings(budgetKey);
        _refuse(
            _ceilingOp(budgetKey, INTRO_BUDGET_CEILING, 2 * INTRO_BUDGET_CEILING),
            abi.encodeWithSelector(UniversalFactory.RaiseTooSoon.selector, budgetKey, uint256(raisedAt) + 15 days)
        );
        vm.warp(uint256(raisedAt) + 15 days);
        _motion(_one(_ceilingOp(budgetKey, INTRO_BUDGET_CEILING, 2 * INTRO_BUDGET_CEILING)));
        (uint256 value,,) = uf.ceilings(budgetKey);
        assertEq(value, 2 * INTRO_BUDGET_CEILING, "a twofold raise 15 days after the introduction");
    }

    /// @dev The new token's first list: a derived key for one new spender and a capped entry for another.
    function _introList() internal view returns (UniversalFactory.Entry[] memory list) {
        list = new UniversalFactory.Entry[](1);
        list[0] = _derived(Mainnet.PYUSD, newVault);
        list = _with(list, UniversalFactory.Entry(otherVault, bytes32(0), INTRO_APPROVAL_CEILING));
    }

    /// @dev The new token's introduction and a budget for its derived key, in this order or the other.
    function _introduction(uint128 budget, bool budgetFirst) internal view returns (UniversalFactory.Op[] memory ops) {
        ops = new UniversalFactory.Op[](2);
        UniversalFactory.Op memory intro =
            _introduceOp(Mainnet.PYUSD, _introList(), INTRO_BUDGET_CEILING, INTRO_APPROVAL_CEILING);
        UniversalFactory.Op memory b = _budgetOp(Mainnet.PYUSD, newVault, budget, bytes32(0));
        (ops[0], ops[1]) = budgetFirst ? (b, intro) : (intro, b);
    }

    // ---------------------------------------------------------------------
    // OD-104 and OD-114: a revoked target comes back by motion
    // ---------------------------------------------------------------------

    /// @dev The emergency role revokes a whole target, and a restore motion scopes it again. The
    ///      approval list stored under the target comes back as it was, with no list written
    ///      again; a spender outside the stored list stays refused. A stop fails a restore motion
    ///      that was open before it, and no motion restores one of the vault's own accounts.
    function test_uf_restore_brings_back_a_revoked_target() public enabled {
        bytes memory approve = abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 1e6));
        _operator(Mainnet.USDC, approve, true);
        _emergencyRevokeTarget(Mainnet.USDC);
        _operator(Mainnet.USDC, approve, false);

        // a stop fails a restore motion that was open before it
        bytes memory early = _calldata(_one(_op(uf.RESTORE(), abi.encode(Mainnet.USDC))));
        uint256 id = _create(early);
        vm.prank(address(emergency));
        uf.raiseCounter();
        _afterWindow();
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, early);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(id);

        // the restore brings the stored list back: its version does not change
        bytes32 scope = uf.functionScope(Mainnet.USDC, IERC20.approve.selector);
        bytes32 version = uf.versions(scope);
        _motion(_one(_op(uf.RESTORE(), abi.encode(Mainnet.USDC))));
        _operator(Mainnet.USDC, approve, true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (newVault, 1e6)), false);
        assertEq(uf.versions(scope), version, "the list was not written again");

        // never one of the vault's own accounts
        _refuse(
            _op(uf.RESTORE(), abi.encode(address(opMod))),
            abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, address(opMod))
        );
        _refuse(
            _op(uf.RESTORE(), abi.encode(address(asset))),
            abi.encodeWithSelector(UniversalFactory.ProtectedAddress.selector, address(asset))
        );
    }

    // ---------------------------------------------------------------------
    // INV-035 and INV-039: the restart and insurance money
    // ---------------------------------------------------------------------

    function test_uf_restart_motion_after_the_switch() public enabled {
        bytes memory early = _calldata(_one(_op(uf.RESTART(), "")));
        uint256 idEarly = _create(early);
        _emergencySwitch();
        _afterWindow();
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(idEarly, early);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(idEarly);

        _motion(_one(_op(uf.RESTART(), "")));
        assertTrue(asset.isModuleEnabled(address(opMod)), "the restart motion enabled the operator modifier");
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), true);
    }

    /// @dev Insurance money spends the budget key that the factory derives for the token and the first-loss
    ///      Safe. One motion sets the budget and moves the money. Without a budget, and above it, the move
    ///      fails at enactment as a whole, and a budget above the token's ceiling is refused at creation.
    function test_uf_insurance_money_goes_to_the_first_loss_safe() public enabled {
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(firstLoss));
        bytes32 key = uf.keyFor(Mainnet.USDC, address(firstLoss));
        assertEq(key, bytes32(abi.encodePacked(bytes2("k:"), address(firstLoss), bytes10(bytes20(Mainnet.USDC)))), "the derived key");

        // no budget yet: nothing moves
        _enactmentFails(_calldata(_one(_op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(1))))));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), before, "no insurance money without a budget");

        UniversalFactory.Op[] memory ops = new UniversalFactory.Op[](2);
        ops[0] = _budgetOp(Mainnet.USDC, address(firstLoss), 10_000e6, bytes32(0));
        ops[1] = _op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(10_000e6)));
        _motion(ops);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)) - before, 10_000e6, "insurance money");
        (,,, uint128 left,) = opMod.allowances(key);
        assertEq(left, 0, "the budget is spent");

        // above the budget: nothing more moves
        _enactmentFails(_calldata(_one(_op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(1))))));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)) - before, 10_000e6, "no insurance money above the budget");

        _refuse(_op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(0))), abi.encodeWithSelector(UniversalFactory.ZeroAmount.selector));
        _refuse(
            _budgetOp(Mainnet.USDC, address(firstLoss), uint128(BUDGET_CEILING_USDC + 1), uf.budgetVersion(10_000e6, 10_000e6, 10_000e6, uint64(MONTH))),
            abi.encodeWithSelector(UniversalFactory.BudgetAboveCeiling.selector, key, BUDGET_CEILING_USDC)
        );
    }

    // ---------------------------------------------------------------------
    // The factory's own guards
    // ---------------------------------------------------------------------

    function test_uf_guards() public enabled {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        // Every argument is computed first: a call inside an argument would take the
        // prank and the expected revert.
        bytes memory restart = _calldata(_one(_op(uf.RESTART(), "")));
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        UniversalFactory.Op[] memory twice = new UniversalFactory.Op[](2);
        twice[0] = _approvalsOp(Mainnet.USDC, usdc, _without(usdc, Mainnet.EARN_USD_DEPOSIT_QUEUE));
        twice[1] = _approvalsOp(Mainnet.USDC, usdc, usdc);
        bytes memory duplicate = _calldata(twice);
        bytes32 scope = uf.functionScope(Mainnet.USDC, IERC20.approve.selector);
        bytes memory empty = _calldata(new UniversalFactory.Op[](0));
        bytes memory otherCounter = abi.encode(uint256(7), _one(_op(uf.RESTART(), "")));

        // only the committee's Safe creates a motion
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotTrustedCaller.selector, Mainnet.VOTING));
        uf.createEVMScript(Mainnet.VOTING, restart);
        // only the executor applies a motion
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotExecutor.selector, address(this)));
        uf.applyMotion(restart);
        // a motion writes each scope once, and carries known operations only
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.DuplicateScope.selector, scope));
        et.createMotion(address(uf), duplicate);
        _refuse(_op(99, ""), abi.encodeWithSelector(UniversalFactory.UnknownOperation.selector, uint8(99)));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NoOperations.selector));
        et.createMotion(address(uf), empty);
        // a motion built against another counter
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 7, 0));
        et.createMotion(address(uf), otherCounter);
    }

    // ---------------------------------------------------------------------
    // Measures for EM (ADR 013, decision 11)
    // ---------------------------------------------------------------------

    function test_uf_measures() public enabled {
        console2.log("PROTOTYPE factory runtime bytes (EIP-170 limit 24,576)", address(uf).code.length);
        UniversalFactory.Entry[] memory usdc = launchApprovals(Mainnet.USDC);
        _measureMotion("approval list, one spender added", _one(_approvalsOp(Mainnet.USDC, usdc, _with(usdc, _derived(Mainnet.USDC, newVault)))));
        _measureMotion("budget", _one(_budgetOp(Mainnet.USDC, newVault, 1_000e6, bytes32(0))));
        bytes32 key = uf.ceilingKey(uf.BUDGET_CEILING(), Mainnet.USDC);
        (, uint64 seededAt,) = uf.ceilings(key);
        vm.warp(uint256(seededAt) + 15 days);
        _measureMotion("ceiling", _one(_ceilingOp(key, BUDGET_CEILING_USDC, 2 * BUDGET_CEILING_USDC)));
        UniversalFactory.Op[] memory money = new UniversalFactory.Op[](2);
        money[0] = _budgetOp(Mainnet.USDC, address(firstLoss), 1_000e6, bytes32(0));
        money[1] = _op(uf.FUND(), abi.encode(Mainnet.USDC, uint256(1_000e6)));
        _measureMotion("insurance money with its budget", money);
        UniversalFactory.Entry[] memory fresh = new UniversalFactory.Entry[](1);
        fresh[0] = _derived(Mainnet.PYUSD, newVault);
        UniversalFactory.Op[] memory intro = new UniversalFactory.Op[](2);
        intro[0] = _introduceOp(Mainnet.PYUSD, fresh, 1_000_000e6, 1_000e6);
        intro[1] = _budgetOp(Mainnet.PYUSD, newVault, 1_000e6, bytes32(0));
        _measureMotion("introduction of a token, with one budget", intro);

        // a full list: 32 spenders, the most that one list may hold
        UniversalFactory.Entry[] memory current = launchApprovals(Mainnet.USDC);
        current = _with(current, _derived(Mainnet.USDC, newVault));
        UniversalFactory.Entry[] memory full = current;
        for (uint256 i = 0; full.length < uf.MAX_SPENDERS(); i++) {
            full = _with(full, _derived(Mainnet.USDC, address(uint160(0x1000 + i))));
        }
        _measureMotion("approval list of 32 spenders", _one(_approvalsOp(Mainnet.USDC, current, full)));

        // a motion with 16 operations: one budget per derived key
        UniversalFactory.Op[] memory many = new UniversalFactory.Op[](16);
        for (uint256 i = 0; i < 16; i++) many[i] = _budgetOp(Mainnet.USDC, address(uint160(0x1000 + i)), 1e6, bytes32(0));
        _measureMotion("16 budgets in one motion", many);

        _emergencyRevokeTarget(Mainnet.USDS);
        _measureMotion("restore of a revoked target", _one(_op(uf.RESTORE(), abi.encode(Mainnet.USDS))));

        _emergencySwitch();
        _measureMotion("restart", _one(_op(uf.RESTART(), "")));
    }

    function _measureMotion(string memory what, UniversalFactory.Op[] memory ops) internal {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        bytes memory cd = _calldata(ops);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        uint256 g = gasleft();
        uint256 id = et.createMotion(address(uf), cd);
        uint256 created = g - gasleft();
        _afterWindow();
        vm.prank(anyone);
        g = gasleft();
        et.enactMotion(id, cd);
        uint256 enacted = g - gasleft();
        console2.log(string.concat("PROTOTYPE ", what, ": createMotion gas, enactMotion gas"), created, enacted);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _refuse(UniversalFactory.Op memory op, bytes memory err) internal {
        _refuseMotion(_one(op), err);
    }

    function _refuseMotion(UniversalFactory.Op[] memory ops, bytes memory err) internal {
        bytes memory cd = _calldata(ops);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(err);
        IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(uf), cd);
    }

    function _derived(address token, address spender) internal view returns (UniversalFactory.Entry memory) {
        return UniversalFactory.Entry(spender, uf.keyFor(token, spender), 0);
    }

    /// @dev The list with one more entry, in the canonical order.
    function _with(UniversalFactory.Entry[] memory list, UniversalFactory.Entry memory add)
        internal
        pure
        returns (UniversalFactory.Entry[] memory out)
    {
        out = new UniversalFactory.Entry[](list.length + 1);
        uint256 j;
        bool placed;
        for (uint256 i = 0; i < list.length; i++) {
            if (!placed && add.spender < list[i].spender) {
                out[j++] = add;
                placed = true;
            }
            out[j++] = list[i];
        }
        if (!placed) out[j] = add;
    }

    function _without(UniversalFactory.Entry[] memory list, address spender)
        internal
        pure
        returns (UniversalFactory.Entry[] memory out)
    {
        out = new UniversalFactory.Entry[](list.length - 1);
        uint256 j;
        for (uint256 i = 0; i < list.length; i++) if (list[i].spender != spender) out[j++] = list[i];
    }

    function _args(bytes memory d) internal pure returns (bytes memory args) {
        args = new bytes(d.length - 4);
        for (uint256 i = 4; i < d.length; i++) args[i - 4] = d[i];
    }
}
