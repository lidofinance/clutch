// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

interface IVault4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}

/// @dev A factory that tries to reach past the universal factory's address book.
contract RogueFactory {
    function createEVMScript(address, bytes calldata) external pure returns (bytes memory) {
        bytes memory transfer = abi.encodeCall(IERC20.transfer, (address(0xdEaD), 1));
        return abi.encodePacked(bytes4(0x00000001), Mainnet.USDC, uint32(transfer.length), transfer);
    }
}

/// @title UniversalFactoryRehearsal — the universal factory (ADR 013) against the live Easy Track, its executor
///        and the vault that the enabling vote sets up, on a mainnet fork.
/// @dev A motion is a list of raw writes. The factory builds no permission and reads no content: each modifier's
///      own policy decides what a role may write. Each test names the invariant that it checks. Lines that
///      start with "FACTORY" are the measures.
///      Run: RPC=<archive RPC> forge test --match-contract UniversalFactoryRehearsal -vv
contract UniversalFactoryRehearsal is EnabledVault {
    bytes32 internal constant EXIT_GOVERNANCE = bytes32("exit-governance");
    bytes32 internal constant RESTART = bytes32("restart");
    bytes32 internal constant INSURANCE_FUNDING = bytes32("insurance-funding");

    bytes4 internal constant APPROVE = IERC20.approve.selector;
    bytes4 internal constant TRANSFER = IERC20.transfer.selector;
    bytes4 internal constant DEPOSIT = IVault4626.deposit.selector;
    bytes4 internal constant REDEEM = IVault4626.redeem.selector;
    bytes4 internal constant WITHDRAW = IVault4626.withdraw.selector;
    bytes4 internal constant CONDITION_VIOLATION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));

    uint8 internal constant T_STATIC = 1;
    uint8 internal constant T_CALLDATA = 5;
    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO = 16;
    uint8 internal constant OP_WITHIN_ALLOWANCE = 28;

    /// @dev A lending vault that the launch policy does not know: an ERC-4626 vault for WETH on Morpho Blue. It
    ///      stands in for the lender vault of Lido Lend's WETH market, which does not exist on mainnet.
    address internal constant NEW_VAULT = 0x2371e134e3455e0593363cBF89d3b6cf53740618;

    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote runs inside each test, as in the rehearsal: the batch measurements cool the new
    ///      accounts, and accounts cooled in setUp do not reach the test.
    modifier enabled() {
        _enable();
        _;
    }

    // ---------------------------------------------------------------------
    // INV-032: the address book, and the motion roles
    // ---------------------------------------------------------------------

    /// @dev The registration that the enabling vote writes is the address book: one call, the factory's own
    ///      `applyMotion` (ADR 013, decision 18). A script that reaches anything else does not pass Easy Track,
    ///      and only Aragon Voting registers a factory.
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

    /// @dev The universal factory holds the motion roles, and Easy Track's executor, which every Easy Track
    ///      factory shares, holds none (decision 18). A motion's script is one call, `applyMotion`.
    function test_uf_the_factory_holds_the_motion_roles() public enabled {
        bytes memory write = abi.encodeCall(IRoles.scopeTarget, (OPERATOR, NEW_VAULT));
        bytes memory viaRole = abi.encodeCall(IRoles.execTransactionWithRole, (address(opMod), 0, write, 0, GOVERNANCE, true));
        vm.prank(Mainnet.ET_EXECUTOR);
        (bool ok,) = address(opMod).call(viaRole);
        assertFalse(ok, "the executor holds no role");

        bytes memory cd = _calldata(_one(_govern(write)));
        bytes memory call = abi.encodeCall(uf.applyMotion, (cd));
        assertEq(
            uf.createEVMScript(Mainnet.COMMITTEE_SAFE, cd),
            abi.encodePacked(bytes4(0x00000001), address(uf), uint32(call.length), call),
            "a script of one call"
        );
        (uint256 epoch, uint256 version, UniversalFactory.Write[] memory ws) = uf.decodeEVMScriptCallData(cd);
        assertEq(epoch + version, 0, "the counter and the policy version that the motion saw");
        assertEq(ws.length, 1, "one write");
        assertEq(ws[0].modifier_, address(opMod), "on the operator modifier");
        assertEq(ws[0].data, write, "the write itself");

        _motion(_one(_govern(write)));
        vm.prank(address(uf));
        (ok,) = address(opMod).call(viaRole);
        assertTrue(ok, "the factory holds the governance role");
    }

    // ---------------------------------------------------------------------
    // The motion's gates
    // ---------------------------------------------------------------------

    /// @dev Easy Track holds one permission for the factory, its own `applyMotion`. Only the committee's Safe
    ///      creates a motion, and only Easy Track's executor applies one.
    function test_uf_only_the_committee_creates_and_only_the_executor_applies() public enabled {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertEq(et.evmScriptFactoryPermissions(address(uf)), abi.encodePacked(address(uf), uf.applyMotion.selector), "the address book");
        bytes memory cd = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        vm.prank(stranger);
        vm.expectRevert();
        et.createMotion(address(uf), cd);
        address[3] memory callers = [Mainnet.COMMITTEE_SAFE, address(emergency), stranger];
        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotExecutor.selector, callers[i]));
            uf.applyMotion(cd);
        }
    }

    /// @dev A motion names only the vault's four modifiers, carries at least one write and at most 64.
    function test_uf_refuses_another_modifier_and_an_empty_or_oversized_motion() public enabled {
        UniversalFactory.Write[] memory w = _one(UniversalFactory.Write(stranger, GOVERNANCE, stranger, ""));
        _refusedAtCreation(w, abi.encodeWithSelector(UniversalFactory.UnknownModifier.selector, stranger));
        _refusedAtCreation(new UniversalFactory.Write[](0), abi.encodeWithSelector(UniversalFactory.NoWrites.selector));
        UniversalFactory.Write[] memory many = new UniversalFactory.Write[](65);
        for (uint256 i = 0; i < many.length; i++) many[i] = _budget(Mainnet.WETH, NEW_VAULT, 1e18);
        _refusedAtCreation(many, abi.encodeWithSelector(UniversalFactory.TooManyWrites.selector));
    }

    /// @dev The counter: a raise by the emergency Safe or by Aragon Voting fails every open motion, of either
    ///      kind, and nobody else raises it.
    function test_uf_counter_fails_every_open_motion() public enabled {
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        bytes memory policy = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        bytes memory action = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        uint256 a = _create(policy);
        uint256 b = _create(action);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotAllowedToRaiseCounter.selector, Mainnet.COMMITTEE_SAFE));
        uf.raiseCounter();
        vm.prank(address(emergency));
        uf.raiseCounter();
        _afterWindow();
        _enactRefused(a, policy, abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        _enactRefused(b, action, abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        vm.prank(Mainnet.VOTING);
        uf.raiseCounter();
        assertEq(uf.epoch(), 2, "Aragon Voting raises it too");
    }

    /// @dev The policy version: of two motions that write on a modifier and were created at the same version,
    ///      the second to enact fails, so it cannot undo the first. A motion that only acts is not affected.
    function test_uf_policy_version_orders_permission_writes_and_spares_actions() public enabled {
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        bytes memory first = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        bytes memory second = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18)));
        bytes memory action = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        uint256 a = _create(first);
        uint256 b = _create(second);
        uint256 c = _create(action);
        _afterWindow();
        _enact(a, first);
        assertEq(uf.policyVersion(), 1, "the first permission motion raises the version");
        _enactRefused(b, second, abi.encodeWithSelector(UniversalFactory.StalePolicyVersion.selector, 0, 1));
        (,,, uint128 balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 10e18, "the first motion's budget stands");

        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        _enact(c, action);
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), held - 1e18, "the burn enacts at the old version");
        assertEq(uf.policyVersion(), 1, "an action leaves the version");

        // the committee creates the second motion again, at the current version
        uint256 again = _create(_calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18))));
        _afterWindow();
        _enact(again, _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18))));
        (,,, balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 20e18, "the second budget, after the first");

        // a write on any of the four modifiers is a permission write, also through another modifier;
        // a write on any other target states the counter alone
        UniversalFactory.Write memory across =
            _w(opMod, GOVERNANCE, address(safetyMod), abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.WETH)));
        bytes memory stale = abi.encode(uf.epoch(), uf.policyVersion() + 1, _one(across));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StalePolicyVersion.selector, 3, 2));
        IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(uf), stale);
        _create(abi.encode(uf.epoch(), uf.policyVersion() + 1, _one(_burn(Mainnet.EARN_ETH_SHARE, 1e18))));
    }

    // ---------------------------------------------------------------------
    // A new protocol by one raw motion
    // ---------------------------------------------------------------------

    /// @dev One motion onboards an ERC-4626 lending vault that the launch policy does not know, with no code
    ///      for its kind in the factory: the operator's approval under a budget key, its deposit, redeem and
    ///      withdraw with the receiver and the owner pinned to the Asset Safe, and the emergency role's exits,
    ///      the zeroing of the new approval among them.
    ///      Then the operator lends within the budget and no further, and the emergency role exits.
    function test_uf_motion_onboards_an_erc4626_lending_vault() public enabled {
        deal(Mainnet.WETH, address(asset), 100e18);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 1e18)), false);
        UniversalFactory.Write[] memory w = _onboarding(40e18);
        uint256 gasUsed = _motion(w);
        console2.log("FACTORY onboarding of an ERC-4626 vault: writes, enactMotion gas", w.length, gasUsed);

        // the operator lends within the budget, and no further
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 40e18)), true);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 40e18)), false);
        _operator(NEW_VAULT, abi.encodeCall(IVault4626.deposit, (40e18, address(asset))), true);
        uint256 shares = IERC20(NEW_VAULT).balanceOf(address(asset));
        assertGt(shares, 0, "the Asset Safe holds the vault's shares");
        assertEq(IERC20(Mainnet.WETH).balanceOf(address(asset)), 60e18, "the WETH went into the vault");

        // every receiver and owner is the Asset Safe; no other spender; no transfer of the shares
        _operator(NEW_VAULT, abi.encodeCall(IVault4626.deposit, (1, stranger)), false);
        _operator(NEW_VAULT, abi.encodeCall(IVault4626.redeem, (1, stranger, address(asset))), false);
        _operator(NEW_VAULT, abi.encodeCall(IVault4626.withdraw, (1, address(asset), stranger)), false);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (stranger, 1)), false);
        _operator(NEW_VAULT, abi.encodeCall(IERC20.transfer, (stranger, 1)), false);

        // the emergency role sets the new approval to zero, and gives none; the owner refills the spent budget
        // first, so that an approval is open
        vm.prank(address(asset));
        opMod.setAllowance(_key(Mainnet.WETH, NEW_VAULT), 10e18, 10e18, 10e18, 30 days, 0);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 10e18)), true);
        _emergencyRefused(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 1)));
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(Mainnet.WETH, 0, abi.encodeCall(IERC20.approve, (NEW_VAULT, 0)), 0, EMERGENCY, true);
        assertEq(IERC20(Mainnet.WETH).allowance(address(asset), NEW_VAULT), 0, "the emergency role set the approval to zero");

        // the operator takes a part back; the emergency role exits the rest to the Asset Safe
        _operator(NEW_VAULT, abi.encodeCall(IVault4626.redeem, (shares / 4, address(asset), address(asset))), true);
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(
            NEW_VAULT, 0, abi.encodeCall(IVault4626.redeem, (shares / 4, address(asset), address(asset))), 0, EMERGENCY, true
        );
        assertGt(IERC20(Mainnet.WETH).balanceOf(address(asset)), 79e18, "half of the position came back as WETH");
        _emergencyRefused(NEW_VAULT, abi.encodeCall(IVault4626.redeem, (1, stranger, address(asset))));
        // the emergency role sends the remaining shares to the Aragon Agent
        uint256 left = IERC20(NEW_VAULT).balanceOf(address(asset));
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(NEW_VAULT, 0, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, left)), 0, EMERGENCY, true);
        assertEq(IERC20(NEW_VAULT).balanceOf(Mainnet.AGENT), left, "the Agent holds the remaining shares");
    }

    /// @dev The modifiers' own guards still bind a raw motion. A write that a modifier refuses fails the whole
    ///      motion: a grant on a vault account, a grant with delegatecall, a budget with a refill period below
    ///      30 days, and a write under the governance role's own key. Nothing of the motion stays.
    function test_uf_motion_fails_as_a_whole_on_a_write_that_a_modifier_refuses() public enabled {
        IRoles.ConditionFlat[] memory deposit = _operatorTree(Mainnet.SUSDS, DEPOSIT);
        bytes[4] memory refused = [
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, address(safetyMod), DEPOSIT, deposit, 0)),
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, NEW_VAULT, DEPOSIT, deposit, 2)),
            abi.encodeCall(IRoles.setAllowance, (_key(Mainnet.WETH, NEW_VAULT), 1e18, 1e18, 1e18, 29 days, 0)),
            abi.encodeCall(IRoles.scopeFunction, (GOVERNANCE, NEW_VAULT, DEPOSIT, deposit, 0))
        ];
        for (uint256 i = 0; i < refused.length; i++) {
            UniversalFactory.Write[] memory w = new UniversalFactory.Write[](2);
            w[0] = _budget(Mainnet.WETH, NEW_VAULT, 7e18);
            w[1] = UniversalFactory.Write(address(opMod), GOVERNANCE, address(opMod), refused[i]);
            bytes memory cd = _calldata(w);
            uint256 id = _create(cd);
            _afterWindow();
            vm.prank(anyone);
            (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, cd)));
            assertFalse(ok, "the enactment fails");
            vm.prank(Mainnet.COMMITTEE_SAFE);
            IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(id);
        }
        (,,, uint128 balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 0, "the motion's first write did not stay");
        assertEq(uf.policyVersion(), 0, "the version did not move");
    }

    /// @dev What the factory does not stop (ADR 013, decision 11): a motion gives the operator a transfer of WETH
    ///      to any address, with no budget. The modifier's guard accepts it, because the target is no vault account and
    ///      the call is plain. Only an objection in the 72 hours stops such a motion.
    function test_uf_motion_can_widen_without_a_receiver_or_a_budget() public enabled {
        deal(Mainnet.WETH, address(asset), 50e18);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.transfer, (stranger, 1e18)), false);
        UniversalFactory.Write[] memory w = new UniversalFactory.Write[](1);
        w[0] = UniversalFactory.Write(
            address(opMod), GOVERNANCE, address(opMod), abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.WETH, TRANSFER, 0))
        );
        _motion(w);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.transfer, (stranger, 50e18)), true);
        assertEq(IERC20(Mainnet.WETH).balanceOf(stranger), 50e18, "the operator sent all of it to a stranger");
    }

    // ---------------------------------------------------------------------
    // INV-035 and INV-039: the restart and insurance money
    // ---------------------------------------------------------------------

    /// @dev A motion restarts the operator after the switch (ADR 013, decision 12). A restart motion that was
    ///      open at the switch fails, because the switch raises the counter; a new one enables the operator
    ///      modifier again, and the restart role can enable no other module.
    function test_uf_restart_motion_after_the_switch() public enabled {
        UniversalFactory.Write memory restart =
            _w(safetyMod, RESTART, address(asset), abi.encodeWithSignature("enableModule(address)", address(opMod)));
        bytes memory early = _calldata(_one(restart));
        uint256 idEarly = _create(early);
        _emergencySwitch();
        _afterWindow();
        _enactRefused(idEarly, early, abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(idEarly);

        _enactmentFails(_calldata(_one(_w(safetyMod, RESTART, address(asset), abi.encodeWithSignature("enableModule(address)", stranger)))));
        assertFalse(asset.isModuleEnabled(stranger), "the restart role enables no other module");

        _motion(_one(restart));
        assertTrue(asset.isModuleEnabled(address(opMod)), "the restart motion enabled the operator modifier");
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 0)), true);
    }

    /// @dev A motion brings back a target that the emergency role revoked (ADR 013, decision 16). A restore
    ///      motion that was open at the stop fails on the counter. A new one writes the target's scope again,
    ///      and the operator's function permissions that the modifier stored under the target work as before.
    function test_uf_restore_motion_brings_back_a_revoked_target() public enabled {
        bytes memory approve = abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 1e6));
        _operator(Mainnet.USDC, approve, true);
        _emergencyRevokeTarget(Mainnet.USDC);
        _operator(Mainnet.USDC, approve, false);

        UniversalFactory.Write memory restore = _govern(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.USDC)));
        bytes memory early = _calldata(_one(restore));
        uint256 id = _create(early);
        vm.prank(address(emergency));
        uf.raiseCounter();
        _afterWindow();
        _enactRefused(id, early, abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        _operator(Mainnet.USDC, approve, false);

        _motion(_one(restore));
        _operator(Mainnet.USDC, approve, true);
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (stranger, 1e6)), false);
    }

    /// @dev Insurance money spends the budget key of its token and the first-loss Safe (ADR 014, decision 11).
    ///      One motion sets the budget and moves the money. Without a budget, and above it, the move fails at
    ///      enactment as a whole, and the money reaches no other receiver.
    function test_uf_insurance_money_goes_to_the_first_loss_safe() public enabled {
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(firstLoss));
        bytes32 key = _key(Mainnet.USDC, address(firstLoss));
        UniversalFactory.Write memory one = _money(Mainnet.USDC, address(firstLoss), 1);

        // no budget yet: nothing moves
        _enactmentFails(_calldata(_one(one)));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)), before, "no insurance money without a budget");

        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](2);
        ws[0] = _budget(Mainnet.USDC, address(firstLoss), 10_000e6);
        ws[1] = _money(Mainnet.USDC, address(firstLoss), 10_000e6);
        _motion(ws);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)) - before, 10_000e6, "insurance money");
        (,,, uint128 left,) = opMod.allowances(key);
        assertEq(left, 0, "the budget is spent");

        // above the budget, and to another receiver: nothing more moves
        _enactmentFails(_calldata(_one(one)));
        _enactmentFails(_calldata(_one(_money(Mainnet.USDC, stranger, 1))));
        _enactmentFails(_calldata(_one(_money(Mainnet.USDC, Mainnet.AGENT, 1))));
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)) - before, 10_000e6, "no insurance money above the budget");
    }

    /// @dev The factory's measures.
    function test_uf_measures() public enabled {
        console2.log("FACTORY factory runtime bytes (EIP-170 limit 24,576)", address(uf).code.length);
        uint256 g = _motion(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        console2.log("FACTORY budget: enactMotion gas", g);
        UniversalFactory.Write[] memory many = new UniversalFactory.Write[](16);
        for (uint256 i = 0; i < many.length; i++) many[i] = _budget(Mainnet.WETH, address(uint160(0x1000 + i)), 1e18);
        g = _motion(many);
        console2.log("FACTORY 16 budgets in one motion: enactMotion gas", g);
    }

    // ---------------------------------------------------------------------
    // Helpers: the writes
    // ---------------------------------------------------------------------

    /// @dev The onboarding of NEW_VAULT, as ten writes. The trees are the ones that the policy compiler writes
    ///      for the launch policy's own ERC-4626 venue, sUSDS, whose trees name no address but the avatar.
    function _onboarding(uint128 budget) internal returns (UniversalFactory.Write[] memory w) {
        bytes32 key = _key(Mainnet.WETH, NEW_VAULT);
        IRoles.ConditionFlat[] memory approve = new IRoles.ConditionFlat[](3);
        approve[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        approve[1] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(NEW_VAULT));
        approve[2] = IRoles.ConditionFlat(0, T_STATIC, OP_WITHIN_ALLOWANCE, abi.encode(key));
        IRoles.ConditionFlat[] memory exit = _emergencyTree(Mainnet.SUSDS, REDEEM);
        IRoles.ConditionFlat[] memory toAgent = _emergencyTree(Mainnet.EARN_USD_SHARE, TRANSFER);
        // an approval set to zero, for any spender: the exit-governance role's pinned form
        IRoles.ConditionFlat[] memory zero = new IRoles.ConditionFlat[](3);
        zero[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        zero[1] = IRoles.ConditionFlat(0, T_STATIC, OP_PASS, "");
        zero[2] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(uint256(0)));
        w = new UniversalFactory.Write[](10);
        // the operator modifier, as the governance role
        w[0] = _govern(abi.encodeCall(IRoles.setAllowance, (key, budget, budget, budget, 30 days, 0)));
        w[1] = _govern(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WETH, APPROVE, approve, 0)));
        w[2] = _govern(abi.encodeCall(IRoles.scopeTarget, (OPERATOR, NEW_VAULT)));
        w[3] = _govern(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, NEW_VAULT, DEPOSIT, _operatorTree(Mainnet.SUSDS, DEPOSIT), 0)));
        w[4] = _govern(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, NEW_VAULT, REDEEM, _operatorTree(Mainnet.SUSDS, REDEEM), 0)));
        w[5] = _govern(abi.encodeCall(IRoles.scopeFunction, (OPERATOR, NEW_VAULT, WITHDRAW, _operatorTree(Mainnet.SUSDS, WITHDRAW), 0)));
        // the safety modifier, as the exit-governance role
        w[6] = _exitWrite(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, NEW_VAULT)));
        w[7] = _exitWrite(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, NEW_VAULT, REDEEM, exit, 0)));
        w[8] = _exitWrite(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, NEW_VAULT, TRANSFER, toAgent, 0)));
        w[9] = _exitWrite(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WETH, APPROVE, zero, 0)));
    }

    function _exitWrite(bytes memory write) internal view returns (UniversalFactory.Write memory) {
        return _w(safetyMod, EXIT_GOVERNANCE, address(safetyMod), write);
    }

    function _burn(address share, uint256 amount) internal view returns (UniversalFactory.Write memory) {
        return _w(firstLossMod, FIRST_LOSS_BURN, share, abi.encodeWithSignature("burn(uint256)", amount));
    }

    /// @dev Insurance money: the insurance-funding role's transfer of a token from the Asset Safe.
    function _money(address token, address receiver, uint256 amount) internal view returns (UniversalFactory.Write memory) {
        return _w(opMod, INSURANCE_FUNDING, token, abi.encodeCall(IERC20.transfer, (receiver, amount)));
    }

    /// @dev The tree of one operator function in the compiled launch policy.
    function _operatorTree(address target, bytes4 selector) internal returns (IRoles.ConditionFlat[] memory) {
        return _tree(opMod, OPERATOR, target, selector);
    }

    /// @dev The tree of one emergency exit in the compiled launch policy.
    function _emergencyTree(address target, bytes4 selector) internal returns (IRoles.ConditionFlat[] memory) {
        return _tree(safetyMod, EMERGENCY, target, selector);
    }

    function _enactRefused(uint256 id, bytes memory cd, bytes memory reason) internal {
        vm.prank(anyone);
        vm.expectRevert(reason);
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, cd);
    }

    function _emergencyRefused(address to, bytes memory data) internal {
        vm.prank(address(emergency));
        (bool ok, bytes memory ret) =
            address(safetyMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, EMERGENCY, true)));
        assertFalse(ok, "the safety modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }
}
