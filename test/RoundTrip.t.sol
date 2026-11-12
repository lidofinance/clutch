// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";

/// @title RoundTrip — the events of the vault's four Roles modifiers and of Easy Track, written out for the
///        round-trip check (ADR 004, decision 13; INV-016) and for the two detectors (ADR 013, decision 19).
/// @dev Each test records every log that a modifier or Easy Track emits, from the modifiers' deployment on, and
///      writes the logs to a file under `.roundtrip/`, one JSON log on each line. `just round-trip` runs these
///      tests and then the `rehearsal` commands of `policy/constellation/compiler/roundtrip.ts` and `watch.ts`,
///      which rebuild each modifier's state from its file, compare it with the policy and check each open
///      motion. A test alone asserts only that the modifiers emitted events.
///      Run: just round-trip
contract RoundTrip is EnabledVault {
    string internal constant DIR = ".roundtrip";
    /// @dev The committed example motion (policy/constellation/compiler/motion.example.ts).
    string internal constant EXAMPLE = "policy/constellation/artifacts/motion-example-rehearsal-26249900.json";

    bytes32 internal constant APPROVALS = bytes32("approvals");
    /// @dev The example fund's payout address and cap (policy/constellation/compiler/motion.example.ts). Stand-ins:
    ///      no decision lists them.
    address internal constant FUND_PAYOUT = 0x000000000000000000000000000000000000F00D;
    uint128 internal constant FUND_CAP = 30_000e6;

    Vm.Log[] internal recorded;
    string internal guardFile;
    uint256 internal accepted;
    uint256 internal refused;
    bool internal integrity;
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
    }

    /// @dev After the enabling vote and the Safe batches: the modifiers hold the committed policy.
    function test_roundtrip_events_after_the_enabling_vote() public {
        _deployAndEnable();
        _write("enabling-vote.ndjson");
    }

    /// @dev After a motion that the `motion` command built: the modifiers hold the motion's head policy.
    function test_roundtrip_events_after_the_example_motion() public {
        _deployAndEnable();
        bytes memory cd = vm.parseJsonBytes(vm.readFile(EXAMPLE), ".calldata");
        uint256 id = _create(cd);
        _afterWindow();
        _enact(id, cd);
        _keep();
        _write("example-motion.ndjson");
    }

    /// @dev After the operator spent a budget and the emergency role revoked a target and a function: the chain
    ///      no longer holds the policy, and the check must report exactly these revokes.
    function test_roundtrip_events_after_an_emergency_revoke() public {
        _deployAndEnable();
        _operator(Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.EARN_USD_DEPOSIT_QUEUE, 100e6)), true);
        _emergencyRevokeTarget(Mainnet.SUSDS);
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(
            address(opMod), 0, abi.encodeCall(IRoles.revokeFunction, (OPERATOR, Mainnet.USDC, IERC20.approve.selector)), 0, EMERGENCY, true
        );
        _keep();
        _write("emergency-revoke.ndjson");
    }

    /// @dev A motion creates a fund with a fixed payout address. The fund's cap is a budget with a maximum refill
    ///      of zero and a timestamp of zero. The deployed modifier stores the largest value and the block's time
    ///      in their place, and emits what it stores. The round-trip check must rebuild the fund's policy from
    ///      these events, so its reading of the two values is checked against the modifier here.
    function test_roundtrip_events_after_a_fund_is_created() public {
        _deployAndEnable();
        bytes32 insurance = bytes32("insurance");
        bytes32 insuranceGovernance = bytes32("insurance-governance");
        bytes32 key = _key(Mainnet.USDT, FUND_PAYOUT);
        IRoles.ConditionFlat[] memory payout = new IRoles.ConditionFlat[](3);
        payout[0] = IRoles.ConditionFlat(0, 5, 5, "");
        payout[1] = IRoles.ConditionFlat(0, 1, 16, abi.encode(FUND_PAYOUT));
        payout[2] = IRoles.ConditionFlat(0, 1, 28, abi.encode(key));
        UniversalFactory.Write[] memory ws = new UniversalFactory.Write[](3);
        address mod = address(firstLossMod);
        ws[0] = _w(firstLossMod, insuranceGovernance, mod, abi.encodeCall(IRoles.scopeTarget, (insurance, Mainnet.USDT)));
        ws[1] = _w(firstLossMod, insuranceGovernance, mod, abi.encodeCall(IRoles.scopeFunction, (insurance, Mainnet.USDT, IERC20.transfer.selector, payout, 0)));
        ws[2] = _w(firstLossMod, insuranceGovernance, mod, abi.encodeCall(IRoles.setAllowance, (key, FUND_CAP, 0, 0, 0, 0)));
        _motion(ws);

        (uint128 refill, uint128 maxRefill, uint64 period, uint128 balance, uint64 timestamp) = firstLossMod.allowances(key);
        assertEq(balance, FUND_CAP, "the cap");
        assertEq(uint256(refill) + period, 0, "no refill and no period");
        assertEq(maxRefill, type(uint128).max, "the modifier stores a maximum refill of zero as the largest value");
        assertEq(timestamp, block.timestamp, "the modifier stores a timestamp of zero as the block's time");
        _keep();
        _write("fund-created.ndjson");
    }

    /// @dev The example motion is open: the chain holds the motion's base policy, and the detector must pass the
    ///      motion. Before it, the committee created another motion and cancelled it, which the detector skips.
    function test_watch_events_with_the_example_motion_open() public {
        _deployAndEnable();
        uint256 other = _create(_calldata(_one(_widening())));
        vm.prank(Mainnet.COMMITTEE_SAFE);
        IEasyTrack(Mainnet.EASY_TRACK).cancelMotion(other);
        _create(vm.parseJsonBytes(vm.readFile(EXAMPLE), ".calldata"));
        _keep();
        _write("watch-example-open.ndjson");
    }

    /// @dev A motion that the repository does not hold is open: it gives the operator a transfer of WETH to any
    ///      address. The detector must fail it.
    function test_watch_events_with_a_widening_motion_open() public {
        _deployAndEnable();
        _create(_calldata(_one(_widening())));
        _keep();
        _write("watch-widening-open.ndjson");
    }

    /// @dev The example motion is open after the emergency role revoked a target: the chain no longer holds the
    ///      motion's base policy, and the detector must fail the motion and report the drift.
    function test_watch_events_with_the_example_motion_open_after_a_revoke() public {
        _deployAndEnable();
        _emergencyRevokeTarget(Mainnet.SUSDS);
        _create(vm.parseJsonBytes(vm.readFile(EXAMPLE), ".calldata"));
        _keep();
        _write("watch-revoke-example-open.ndjson");
    }

    /// @dev Another motion enacts the example motion's writes and one more action, a relayer approval, which no
    ///      modifier's state holds. The chain then holds the example's head policy, but the pending motion did
    ///      not enact: the detector must not settle it, and must report the enacted motion.
    function test_watch_events_after_another_motion_enacts_the_pending_writes() public {
        _deployAndEnable();
        (,, UniversalFactory.Write[] memory writes) = uf.decodeEVMScriptCallData(vm.parseJsonBytes(vm.readFile(EXAMPLE), ".calldata"));
        UniversalFactory.Write[] memory more = new UniversalFactory.Write[](writes.length + 1);
        for (uint256 i = 0; i < writes.length; i++) more[i] = writes[i];
        more[writes.length] =
            _w(ordersMod, APPROVALS, Mainnet.USDC, abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, type(uint256).max)));
        bytes memory cd = _calldata(more);
        uint256 id = _create(cd);
        _afterWindow();
        _enact(id, cd);
        _keep();
        _write("watch-other-enacted.ndjson");
    }

    /// @dev What the deployed modifiers say to writes of the motion roles, one by one: the ground truth for the
    ///      motion check's evaluation of a role's conditions. Each case is a call of a modifier on itself, made
    ///      as the universal factory, on the state after the enabling vote. The file holds each write with
    ///      whether the modifier accepted it.
    function test_guard_cases_for_the_motion_check() public {
        _deployAndEnable();
        vm.createDir(DIR, true);
        guardFile = string.concat(DIR, "/guard-cases.ndjson");
        vm.writeFile(guardFile, "");
        bytes4 transfer = IERC20.transfer.selector;
        bytes4 approve = IERC20.approve.selector;
        // a well-formed tree that pins nothing: both arguments of transfer or approve pass
        IRoles.ConditionFlat[] memory any = new IRoles.ConditionFlat[](3);
        any[0] = IRoles.ConditionFlat(0, 5, 5, "");
        any[1] = IRoles.ConditionFlat(0, 1, 0, "");
        any[2] = IRoles.ConditionFlat(0, 1, 0, "");
        // a tree that the modifier's own integrity check refuses, whatever the role's policy says
        IRoles.ConditionFlat[] memory malformed = new IRoles.ConditionFlat[](1);
        malformed[0] = IRoles.ConditionFlat(0, 5, 5, "");

        // the governance role on the operator modifier
        bytes32 derived = _key(Mainnet.WBTC, stranger);
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (bytes32("earn_usd_deposit"), 1, 1, 1, 30 days, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (bytes32("earn_usd_deposit"), 1, 1, 1, 30 days - 1, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (bytes32("earn_usd_deposit"), 1, 1, 1, 0, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (bytes32("foreign"), 1, 1, 1, 30 days, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (derived, 1, 1, 1, 30 days, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.setAllowance, (bytes32(uint256(derived) >> 8), 1, 1, 1, 30 days, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.WBTC)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, Mainnet.WBTC)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (GOVERNANCE, Mainnet.WBTC)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(asset))));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(opMod))));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(safetyMod))));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(orders))));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(ordersMod))));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.revokeTarget, (OPERATOR, Mainnet.SUSDS)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, Mainnet.SUSDS)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.revokeFunction, (OPERATOR, Mainnet.SUSDS, transfer)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.revokeFunction, (OPERATOR, address(asset), transfer)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, any, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, any, 1)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, any, 2)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, any, 3)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, transfer, any, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, address(safetyMod), transfer, any, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.WBTC, transfer, 0)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.WBTC, transfer, 2)));
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.allowFunction, (OPERATOR, address(asset), transfer, 0)));
        _case(opMod, GOVERNANCE, abi.encodeWithSignature("assignRoles(address,bytes32[],bool[])", stranger, new bytes32[](0), new bool[](0)));
        _case(opMod, bytes32("insurance-funding"), abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.WBTC)));

        // the exit-governance role on the safety modifier: only pinned exits
        bytes32 exitGovernance = bytes32("exit-governance");
        IRoles.ConditionFlat[] memory toAgent = _tree(safetyMod, EMERGENCY, Mainnet.EARN_USD_SHARE, transfer);
        IRoles.ConditionFlat[] memory redeem = _tree(safetyMod, EMERGENCY, Mainnet.SUSDS, bytes4(keccak256("redeem(uint256,address,address)")));
        IRoles.ConditionFlat[] memory toStranger = new IRoles.ConditionFlat[](2);
        toStranger[0] = IRoles.ConditionFlat(0, 5, 5, "");
        toStranger[1] = IRoles.ConditionFlat(0, 1, 16, abi.encode(stranger));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, Mainnet.WBTC)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.WBTC)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, address(asset))));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, transfer, toAgent, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, transfer, toStranger, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, transfer, any, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, transfer, toAgent, 1)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, approve, toAgent, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, Mainnet.WBTC, bytes4(keccak256("redeem(uint256,address,address)")), redeem, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, address(opMod), transfer, toAgent, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.allowFunction, (EMERGENCY, Mainnet.WBTC, bytes4(keccak256("unwrap(uint256)")), 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.allowFunction, (EMERGENCY, Mainnet.WBTC, transfer, 0)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, Mainnet.SUSDS)));
        _case(safetyMod, exitGovernance, abi.encodeCall(IRoles.setAllowance, (derived, 1, 1, 1, 30 days, 0)));
        _case(safetyMod, bytes32("restart"), abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, Mainnet.WBTC)));

        // the governance role on the orders modifier
        IRoles.ConditionFlat[] memory relayer = _tree(ordersMod, APPROVALS, Mainnet.USDC, approve);
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, Mainnet.WBTC)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (APPROVALS, Mainnet.WBTC)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (GOVERNANCE, Mainnet.WBTC)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeTarget, (OPERATOR, address(orders))));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (APPROVALS, Mainnet.WBTC, approve, relayer, 0)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (APPROVALS, Mainnet.WBTC, approve, toStranger, 0)));
        bytes4 signOrder = bytes4(keccak256("signOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32),uint32,uint256)"));
        IRoles.ConditionFlat[] memory sign = _tree(ordersMod, OPERATOR, Mainnet.ORDER_SIGNER, signOrder);
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.ORDER_SIGNER, signOrder, sign, 2)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.ORDER_SIGNER, signOrder, sign, 0)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, any, 2)));
        _case(ordersMod, GOVERNANCE, abi.encodeCall(IRoles.revokeTarget, (OPERATOR, Mainnet.USDC)));

        // the insurance-governance role on the first-loss modifier
        bytes32 insurance = bytes32("insurance");
        bytes32 insuranceGovernance = bytes32("insurance-governance");
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.setAllowance, (derived, 5, 0, 0, 0, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.setAllowance, (derived, 5, 0, 1, 0, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.setAllowance, (derived, 5, 5, 0, 0, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.setAllowance, (bytes32("foreign"), 5, 0, 0, 0, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeTarget, (insurance, Mainnet.USDT)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeTarget, (insurance, Mainnet.EARN_ETH_SHARE)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeTarget, (FIRST_LOSS, Mainnet.USDT)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeFunction, (insurance, Mainnet.USDT, transfer, toStranger, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeFunction, (insurance, Mainnet.USDT, approve, toStranger, 0)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeFunction, (insurance, Mainnet.USDT, transfer, toStranger, 2)));
        _case(firstLossMod, insuranceGovernance, abi.encodeCall(IRoles.scopeFunction, (insurance, Mainnet.EARN_USD_SHARE, transfer, toStranger, 0)));

        // the limit of the offline evaluation: the role's policy accepts this write, and the modifier refuses the tree
        integrity = true;
        _case(opMod, GOVERNANCE, abi.encodeCall(IRoles.scopeFunction, (OPERATOR, Mainnet.WBTC, transfer, malformed, 0)));
        integrity = false;

        assertGt(accepted, 10, "some writes are accepted");
        assertGt(refused, 10, "some writes are refused");
        console2.log("ROUNDTRIP guard cases: accepted, refused", accepted, refused);
    }

    /// @dev One guard case: the write as the universal factory, with the modifier's answer, on a state that the
    ///      case does not keep.
    function _case(IRoles modifier_, bytes32 role, bytes memory data) internal {
        uint256 snap = vm.snapshotState();
        vm.prank(address(uf));
        (bool ok,) = address(modifier_).call(abi.encodeCall(IRoles.execTransactionWithRole, (address(modifier_), 0, data, 0, role, true)));
        vm.revertToState(snap);
        if (ok) accepted++;
        else refused++;
        vm.writeLine(
            guardFile,
            string.concat(
                '{"modifier":"', vm.toString(address(modifier_)), '","role":"', vm.toString(role), '","to":"', vm.toString(address(modifier_)),
                '","data":"', vm.toString(data), '","accepted":', ok ? "true" : "false", ',"malformedTree":', integrity ? "true" : "false", "}"
            )
        );
    }

    /// @dev A write that no policy change holds: a transfer of WETH for the operator, with no condition.
    function _widening() internal view returns (UniversalFactory.Write memory) {
        return _govern(abi.encodeCall(IRoles.allowFunction, (OPERATOR, Mainnet.WETH, IERC20.transfer.selector, 0)));
    }

    /// @dev Deploys the accounts and runs the enabling vote, and keeps the modifiers' logs of both. The fixture
    ///      measures each batch on a snapshot that it rolls back; those logs are no chain events, so they go.
    function _deployAndEnable() internal {
        vm.recordLogs();
        _deployAccounts();
        _deployFactory();
        _keep();
        _buildBatches();
        vm.getRecordedLogs();
        _voteAndRunBatches();
        _keep();
    }

    /// @dev Moves the logs that the four modifiers and Easy Track emitted since the last call into `recorded`,
    ///      in order.
    function _keep() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            address e = logs[i].emitter;
            if (
                e == address(opMod) || e == address(safetyMod) || e == address(ordersMod) || e == address(firstLossMod)
                    || e == Mainnet.EASY_TRACK
            ) {
                recorded.push(logs[i]);
            }
        }
    }

    function _write(string memory name) internal {
        assertGt(recorded.length, 0, "the modifiers emitted events");
        vm.createDir(DIR, true);
        string memory path = string.concat(DIR, "/", name);
        vm.writeFile(path, "");
        for (uint256 i = 0; i < recorded.length; i++) {
            Vm.Log storage log = recorded[i];
            string memory topics = "";
            for (uint256 t = 0; t < log.topics.length; t++) {
                topics = string.concat(topics, t == 0 ? "" : ",", '"', vm.toString(log.topics[t]), '"');
            }
            vm.writeLine(
                path,
                string.concat('{"address":"', vm.toString(log.emitter), '","topics":[', topics, '],"data":"', vm.toString(log.data), '"}')
            );
        }
        console2.log("ROUNDTRIP logs written", recorded.length, path);
    }
}
