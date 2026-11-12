// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {RawFactory} from "../src/factory/RawFactory.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

interface IVault4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}

/// @title RawFactoryRehearsal — a prototype of the universal factory with raw writes, against the
///        live Easy Track, its executor and the vault that the enabling vote sets up, on a mainnet fork.
/// @dev The prototype stands beside the typed factory, which the enabling vote of the fixture registers. Each
///      test registers the raw factory as Aragon Voting and gives it the motion roles as each modifier's owner.
///      Lines that start with "RAW" are the measures for EM.
///      Run: RPC=<archive RPC> forge test --match-contract RawFactoryRehearsal -vv
contract RawFactoryRehearsal is EnabledVault {
    bytes32 internal constant EXIT_GOVERNANCE = bytes32("exit-governance");
    bytes32 internal constant RESTART = bytes32("restart");
    bytes32 internal constant INSURANCE_FUNDING = bytes32("insurance-funding");
    bytes32 internal constant APPROVALS = bytes32("approvals");
    bytes32 internal constant INSURANCE = bytes32("insurance");
    bytes32 internal constant GOVERNANCE_OF_FUNDS = bytes32("insurance-governance");

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

    RawFactory internal raw;
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The enabling vote runs inside each test. Then Aragon Voting registers the raw factory with its one
    ///      call, and each modifier's owner gives it the motion roles that the typed factory holds.
    modifier enabled() {
        _enable();
        raw = new RawFactory(
            RawFactory.Config({
                trustedCaller: Mainnet.COMMITTEE_SAFE,
                executor: Mainnet.ET_EXECUTOR,
                emergencySafe: address(emergency),
                voting: Mainnet.VOTING,
                operatorModifier: address(opMod),
                safetyModifier: address(safetyMod),
                ordersModifier: address(ordersMod),
                firstLossModifier: address(firstLossMod)
            })
        );
        bytes memory book = raw.addressBook();
        vm.prank(Mainnet.VOTING);
        IEasyTrack(Mainnet.EASY_TRACK).addEVMScriptFactory(address(raw), book);
        _grant(address(asset), opMod, GOVERNANCE, INSURANCE_FUNDING, bytes32(0));
        _grant(address(asset), safetyMod, EXIT_GOVERNANCE, RESTART, bytes32(0));
        _grant(address(orders), ordersMod, GOVERNANCE, APPROVALS, bytes32(0));
        _grant(address(firstLoss), firstLossMod, FIRST_LOSS_BURN, INSURANCE, GOVERNANCE_OF_FUNDS);
        _;
    }

    // ---------------------------------------------------------------------
    // The motion's gates
    // ---------------------------------------------------------------------

    /// @dev Easy Track holds one permission for the factory, its own `applyMotion`. Only the committee's Safe
    ///      creates a motion, and only Easy Track's executor applies one.
    function test_raw_only_the_committee_creates_and_only_the_executor_applies() public enabled {
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertEq(et.evmScriptFactoryPermissions(address(raw)), abi.encodePacked(address(raw), raw.applyMotion.selector), "the address book");
        bytes memory cd = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        vm.prank(stranger);
        vm.expectRevert();
        et.createMotion(address(raw), cd);
        address[3] memory callers = [Mainnet.COMMITTEE_SAFE, address(emergency), stranger];
        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(abi.encodeWithSelector(RawFactory.NotExecutor.selector, callers[i]));
            raw.applyMotion(cd);
        }
    }

    /// @dev A motion names only the vault's four modifiers, carries at least one write and at most 64.
    function test_raw_refuses_another_modifier_and_an_empty_or_oversized_motion() public enabled {
        RawFactory.Write[] memory w = _one(RawFactory.Write(stranger, GOVERNANCE, stranger, ""));
        _refusedAtCreation(w, abi.encodeWithSelector(RawFactory.UnknownModifier.selector, stranger));
        _refusedAtCreation(new RawFactory.Write[](0), abi.encodeWithSelector(RawFactory.NoWrites.selector));
        RawFactory.Write[] memory many = new RawFactory.Write[](65);
        for (uint256 i = 0; i < many.length; i++) many[i] = _budget(Mainnet.WETH, NEW_VAULT, 1e18);
        _refusedAtCreation(many, abi.encodeWithSelector(RawFactory.TooManyWrites.selector));
    }

    /// @dev The counter: a raise by the emergency Safe or by Aragon Voting fails every open motion, of either
    ///      kind, and nobody else raises it.
    function test_raw_counter_fails_every_open_motion() public enabled {
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        bytes memory policy = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        bytes memory action = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        uint256 a = _createRaw(policy);
        uint256 b = _createRaw(action);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(abi.encodeWithSelector(RawFactory.NotAllowedToRaiseCounter.selector, Mainnet.COMMITTEE_SAFE));
        raw.raiseCounter();
        vm.prank(address(emergency));
        raw.raiseCounter();
        _afterWindow();
        _enactRefused(a, policy, abi.encodeWithSelector(RawFactory.StaleCounter.selector, 0, 1));
        _enactRefused(b, action, abi.encodeWithSelector(RawFactory.StaleCounter.selector, 0, 1));
        vm.prank(Mainnet.VOTING);
        raw.raiseCounter();
        assertEq(raw.epoch(), 2, "Aragon Voting raises it too");
    }

    /// @dev The policy version: of two motions that write on a modifier and were created at the same version,
    ///      the second to enact fails, so it cannot undo the first. A motion that only acts is not affected.
    function test_raw_policy_version_orders_permission_writes_and_spares_actions() public enabled {
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        bytes memory first = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        bytes memory second = _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18)));
        bytes memory action = _calldata(_one(_burn(Mainnet.EARN_ETH_SHARE, 1e18)));
        uint256 a = _createRaw(first);
        uint256 b = _createRaw(second);
        uint256 c = _createRaw(action);
        _afterWindow();
        _enact(a, first);
        assertEq(raw.policyVersion(), 1, "the first permission motion raises the version");
        _enactRefused(b, second, abi.encodeWithSelector(RawFactory.StalePolicyVersion.selector, 0, 1));
        (,,, uint128 balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 10e18, "the first motion's budget stands");

        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        _enact(c, action);
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), held - 1e18, "the burn enacts at the old version");
        assertEq(raw.policyVersion(), 1, "an action leaves the version");

        // the committee creates the second motion again, at the current version
        uint256 again = _createRaw(_calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18))));
        _afterWindow();
        _enact(again, _calldata(_one(_budget(Mainnet.WETH, NEW_VAULT, 20e18))));
        (,,, balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 20e18, "the second budget, after the first");
    }

    // ---------------------------------------------------------------------
    // A new protocol by one raw motion
    // ---------------------------------------------------------------------

    /// @dev One motion onboards an ERC-4626 lending vault that the launch policy does not know, with no code
    ///      for its kind in the factory: the operator's approval under a budget key, its deposit, redeem and
    ///      withdraw with the receiver and the owner pinned to the Asset Safe, and the emergency role's exits.
    ///      Then the operator lends within the budget and no further, and the emergency role exits.
    function test_raw_motion_onboards_an_erc4626_lending_vault() public enabled {
        deal(Mainnet.WETH, address(asset), 100e18);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (NEW_VAULT, 1e18)), false);
        RawFactory.Write[] memory w = _onboarding(40e18);
        uint256 gasUsed = _motion(w);
        console2.log("RAW onboarding of an ERC-4626 vault: writes, enactMotion gas", w.length, gasUsed);

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
    function test_raw_motion_fails_as_a_whole_on_a_write_that_a_modifier_refuses() public enabled {
        IRoles.ConditionFlat[] memory deposit = _operatorTree(Mainnet.SUSDS, DEPOSIT);
        bytes[4] memory refused = [
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, address(safetyMod), DEPOSIT, deposit, 0)),
            abi.encodeCall(IRoles.scopeFunction, (OPERATOR, NEW_VAULT, DEPOSIT, deposit, 2)),
            abi.encodeCall(IRoles.setAllowance, (_key(Mainnet.WETH, NEW_VAULT), 1e18, 1e18, 1e18, 29 days, 0)),
            abi.encodeCall(IRoles.scopeFunction, (GOVERNANCE, NEW_VAULT, DEPOSIT, deposit, 0))
        ];
        for (uint256 i = 0; i < refused.length; i++) {
            RawFactory.Write[] memory w = new RawFactory.Write[](2);
            w[0] = _budget(Mainnet.WETH, NEW_VAULT, 7e18);
            w[1] = RawFactory.Write(address(opMod), GOVERNANCE, address(opMod), refused[i]);
            bytes memory cd = _calldata(w);
            uint256 id = _createRaw(cd);
            _afterWindow();
            vm.prank(anyone);
            (bool ok,) = Mainnet.EASY_TRACK.call(abi.encodeCall(IEasyTrack.enactMotion, (id, cd)));
            assertFalse(ok, "the enactment fails");
            vm.prank(Mainnet.COMMITTEE_SAFE);
            IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(id);
        }
        (,,, uint128 balance,) = opMod.allowances(_key(Mainnet.WETH, NEW_VAULT));
        assertEq(balance, 0, "the motion's first write did not stay");
        assertEq(raw.policyVersion(), 0, "the version did not move");
    }

    /// @dev What a raw motion can do that a typed shape refused: it gives the operator a transfer of WETH to any
    ///      address, with no budget. The modifier's guard accepts it, because the target is no vault account and
    ///      the call is plain. Only an objection in the 72 hours stops such a motion.
    function test_raw_motion_can_widen_without_a_receiver_or_a_budget() public enabled {
        deal(Mainnet.WETH, address(asset), 50e18);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.transfer, (stranger, 1e18)), false);
        RawFactory.Write[] memory w = new RawFactory.Write[](1);
        w[0] = RawFactory.Write(
            address(opMod), GOVERNANCE, address(opMod), abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.WETH, TRANSFER, 0))
        );
        _motion(w);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.transfer, (stranger, 50e18)), true);
        assertEq(IERC20(Mainnet.WETH).balanceOf(stranger), 50e18, "the operator sent all of it to a stranger");
    }

    // ---------------------------------------------------------------------
    // Actions
    // ---------------------------------------------------------------------

    /// @dev The actions of the typed factory as raw writes: a restart after the switch, insurance money with its
    ///      budget, and a first-loss burn.
    function test_raw_actions_restart_insurance_money_and_burn() public enabled {
        _moveFirstLossShare(Mainnet.EARN_ETH_SHARE, "earnETH");
        _disableOperatorModifier();
        _motion(_one(RawFactory.Write(address(safetyMod), RESTART, address(asset), abi.encodeWithSignature("enableModule(address)", address(opMod)))));
        assertTrue(asset.isModuleEnabled(address(opMod)), "the restart motion");

        RawFactory.Write[] memory money = new RawFactory.Write[](2);
        money[0] = _budget(Mainnet.USDC, address(firstLoss), 25_000e6);
        money[1] = RawFactory.Write(
            address(opMod), INSURANCE_FUNDING, Mainnet.USDC, abi.encodeCall(IERC20.transfer, (address(firstLoss), 25_000e6))
        );
        uint256 before = IERC20(Mainnet.USDC).balanceOf(address(firstLoss));
        _motion(money);
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(firstLoss)) - before, 25_000e6, "insurance money");

        uint256 held = IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss));
        _motion(_one(_burn(Mainnet.EARN_ETH_SHARE, 3e18)));
        assertEq(IERC20(Mainnet.EARN_ETH_SHARE).balanceOf(address(firstLoss)), held - 3e18, "the burn");
    }

    /// @dev The prototype's measures.
    function test_raw_measures() public enabled {
        console2.log("RAW factory runtime bytes (EIP-170 limit 24,576)", address(raw).code.length);
        uint256 g = _motion(_one(_budget(Mainnet.WETH, NEW_VAULT, 10e18)));
        console2.log("RAW budget: enactMotion gas", g);
        RawFactory.Write[] memory many = new RawFactory.Write[](16);
        for (uint256 i = 0; i < many.length; i++) many[i] = _budget(Mainnet.WETH, address(uint160(0x1000 + i)), 1e18);
        g = _motion(many);
        console2.log("RAW 16 budgets in one motion: enactMotion gas", g);
    }

    // ---------------------------------------------------------------------
    // Helpers: the writes
    // ---------------------------------------------------------------------

    /// @dev The onboarding of NEW_VAULT, as nine writes. The trees are the ones that the policy compiler writes
    ///      for the launch policy's own ERC-4626 venue, sUSDS, whose trees name no address but the avatar.
    function _onboarding(uint128 budget) internal returns (RawFactory.Write[] memory w) {
        bytes32 key = _key(Mainnet.WETH, NEW_VAULT);
        IRoles.ConditionFlat[] memory approve = new IRoles.ConditionFlat[](3);
        approve[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        approve[1] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(NEW_VAULT));
        approve[2] = IRoles.ConditionFlat(0, T_STATIC, OP_WITHIN_ALLOWANCE, abi.encode(key));
        IRoles.ConditionFlat[] memory exit = _emergencyTree(Mainnet.SUSDS, REDEEM);
        IRoles.ConditionFlat[] memory toAgent = _emergencyTree(Mainnet.EARN_USD_SHARE, TRANSFER);
        w = new RawFactory.Write[](9);
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
    }

    function _govern(bytes memory write) internal view returns (RawFactory.Write memory) {
        return RawFactory.Write(address(opMod), GOVERNANCE, address(opMod), write);
    }

    function _exitWrite(bytes memory write) internal view returns (RawFactory.Write memory) {
        return RawFactory.Write(address(safetyMod), EXIT_GOVERNANCE, address(safetyMod), write);
    }

    /// @dev A budget of the operator: `perMonth` now, and again every 30 days.
    function _budget(address token, address spender, uint128 perMonth) internal view returns (RawFactory.Write memory) {
        return _govern(abi.encodeCall(IRoles.setAllowance, (_key(token, spender), perMonth, perMonth, perMonth, 30 days, 0)));
    }

    function _burn(address share, uint256 amount) internal view returns (RawFactory.Write memory) {
        return RawFactory.Write(address(firstLossMod), FIRST_LOSS_BURN, share, abi.encodeWithSignature("burn(uint256)", amount));
    }

    /// @dev A budget key in the form that the governance role's guard accepts: "k:", the spender, and the
    ///      token's first ten bytes.
    function _key(address token, address spender) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(bytes2("k:"), spender, bytes10(bytes20(token))));
    }

    /// @dev The tree of one operator function in the compiled launch policy.
    function _operatorTree(address target, bytes4 selector) internal returns (IRoles.ConditionFlat[] memory) {
        return _tree(address(opMod), OPERATOR, target, selector);
    }

    /// @dev The tree of one emergency exit in the compiled launch policy.
    function _emergencyTree(address target, bytes4 selector) internal returns (IRoles.ConditionFlat[] memory) {
        return _tree(address(safetyMod), EMERGENCY, target, selector);
    }

    function _tree(address modifier_, bytes32 role, address target, bytes4 selector)
        internal
        returns (IRoles.ConditionFlat[] memory)
    {
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory calls = _policyCalls(modifier_, address(0));
        for (uint256 i = 0; i < calls.length; i++) {
            if (bytes4(calls[i].data) != IRoles.scopeFunction.selector) continue;
            (bytes32 k, address t, bytes4 s, IRoles.ConditionFlat[] memory c,) =
                abi.decode(_args(calls[i].data), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (k == role && t == target && s == selector) {
                vm.resumeGasMetering();
                return c;
            }
        }
        revert("the artifact lacks the tree");
    }

    // ---------------------------------------------------------------------
    // Helpers: motions of the raw factory
    // ---------------------------------------------------------------------

    function _one(RawFactory.Write memory w) internal pure returns (RawFactory.Write[] memory ws) {
        ws = new RawFactory.Write[](1);
        ws[0] = w;
    }

    function _calldata(RawFactory.Write[] memory ws) internal view returns (bytes memory) {
        return abi.encode(raw.epoch(), raw.policyVersion(), ws);
    }

    function _createRaw(bytes memory cd) internal returns (uint256 id) {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        id = IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(raw), cd);
    }

    /// @dev Creates a motion, waits out its objection window and enacts it. Returns the enactment's gas.
    function _motion(RawFactory.Write[] memory ws) internal returns (uint256 gasUsed) {
        bytes memory cd = _calldata(ws);
        uint256 id = _createRaw(cd);
        _afterWindow();
        vm.prank(anyone);
        uint256 g = gasleft();
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, cd);
        gasUsed = g - gasleft();
        assertLt(gasUsed, 16_777_216, "under EIP-7825's cap");
    }

    function _refusedAtCreation(RawFactory.Write[] memory ws, bytes memory reason) internal {
        bytes memory cd = _calldata(ws);
        vm.prank(Mainnet.COMMITTEE_SAFE);
        vm.expectRevert(reason);
        IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(raw), cd);
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

    /// @dev The owner of a modifier gives the raw factory up to three motion roles.
    function _grant(address owner, IRoles modifier_, bytes32 a, bytes32 b, bytes32 c) internal {
        uint256 n = c == bytes32(0) ? 2 : 3;
        bytes32[] memory keys = new bytes32[](n);
        bool[] memory yes = new bool[](n);
        keys[0] = a;
        keys[1] = b;
        if (n == 3) keys[2] = c;
        for (uint256 i = 0; i < n; i++) yes[i] = true;
        vm.prank(owner);
        modifier_.assignRoles(address(raw), keys, yes);
    }
}
