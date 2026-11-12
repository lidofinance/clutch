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

/// @title MotionReplay — a motion that the `motion` command built (policy/constellation/compiler/motion.ts),
///        enacted through the live Easy Track on the vault that the enabling vote sets up (ADR 013).
/// @dev The test takes the motion's calldata as the command wrote it, so it checks the command's encoding, its
///      choice of the motion roles and the order of its writes against the deployed Roles modifier and the
///      factory. Lines that start with "MOTION" are the measures.
///      Run: RPC=<archive RPC> forge test --match-contract MotionReplay -vv
///      A motion of one's own: `just motion <base> <head>`, then `just motion-replay`.
contract MotionReplay is EnabledVault {
    /// @dev The committed example motion: the onboarding of an ERC-4626 lending vault, with a larger Earn budget.
    string internal constant EXAMPLE = "policy/constellation/artifacts/motion-example-rehearsal-26249900.json";
    /// @dev The repository's pending motion of the rehearsal's network, and its base policy (ADR 013, decision 19).
    string internal constant PENDING_MOTION = "policy/constellation/pending/rehearsal-26249900/motion.json";
    string internal constant PENDING_BASE = "policy/constellation/pending/rehearsal-26249900/base.json";
    /// @dev The example's vault and budgets (policy/constellation/compiler/motion.example.ts). No decision lists them.
    address internal constant EXAMPLE_VAULT = 0x2371e134e3455e0593363cBF89d3b6cf53740618;
    uint256 internal constant EXAMPLE_WETH_BUDGET = 50e18;
    uint256 internal constant EXAMPLE_EARN_USD_BUDGET = 400_000e6;
    bytes4 internal constant CONDITION_VIOLATION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));

    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    /// @dev The vote runs inside the test, so that the motion's writes meet cold accounts.
    modifier enabled() {
        _enable();
        _;
    }

    /// @dev The example motion enacts as one transaction under EIP-7825's cap. After it, the budgets are the
    ///      head policy's. The operator lends within the new budget and no further, every receiver and owner is
    ///      the Asset Safe, and the emergency role exits to the Asset Safe and to the Aragon Agent only.
    function test_replay_the_example_motion() public enabled {
        string memory file = vm.readFile(EXAMPLE);
        uint256 writes = _replay(file);
        assertEq(writes, 10, "the example's ten writes");
        (,,, uint128 earn,) = opMod.allowances(bytes32("earn_usd_deposit"));
        assertEq(earn, EXAMPLE_EARN_USD_BUDGET, "the larger Earn budget");

        // the operator lends within the budget, and no further
        deal(Mainnet.WETH, address(asset), 100e18);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (EXAMPLE_VAULT, 40e18)), true);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (EXAMPLE_VAULT, EXAMPLE_WETH_BUDGET - 40e18 + 1)), false);
        _operator(EXAMPLE_VAULT, abi.encodeCall(IVault4626.deposit, (40e18, address(asset))), true);
        uint256 shares = IERC20(EXAMPLE_VAULT).balanceOf(address(asset));
        assertGt(shares, 0, "the Asset Safe holds the vault's shares");
        assertEq(IERC20(Mainnet.WETH).balanceOf(address(asset)), 60e18, "the WETH went into the vault");

        // every receiver and owner is the Asset Safe; no other spender; no transfer of the shares
        _operator(EXAMPLE_VAULT, abi.encodeCall(IVault4626.deposit, (1, stranger)), false);
        _operator(EXAMPLE_VAULT, abi.encodeCall(IVault4626.redeem, (1, stranger, address(asset))), false);
        _operator(EXAMPLE_VAULT, abi.encodeCall(IVault4626.withdraw, (1, address(asset), stranger)), false);
        _operator(Mainnet.WETH, abi.encodeCall(IERC20.approve, (stranger, 1)), false);
        _operator(EXAMPLE_VAULT, abi.encodeCall(IERC20.transfer, (stranger, 1)), false);

        // the operator takes a part back; the emergency role exits a part to the Asset Safe and the rest to the Agent
        _operator(EXAMPLE_VAULT, abi.encodeCall(IVault4626.redeem, (shares / 4, address(asset), address(asset))), true);
        _emergency(EXAMPLE_VAULT, abi.encodeCall(IVault4626.redeem, (shares / 4, address(asset), address(asset))), true);
        assertGt(IERC20(Mainnet.WETH).balanceOf(address(asset)), 79e18, "half of the position came back as WETH");
        _emergency(EXAMPLE_VAULT, abi.encodeCall(IVault4626.redeem, (1, stranger, address(asset))), false);
        _emergency(EXAMPLE_VAULT, abi.encodeCall(IERC20.transfer, (stranger, 1)), false);
        uint256 left = IERC20(EXAMPLE_VAULT).balanceOf(address(asset));
        _emergency(EXAMPLE_VAULT, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, left)), true);
        assertEq(IERC20(EXAMPLE_VAULT).balanceOf(Mainnet.AGENT), left, "the Agent holds the remaining shares");
    }

    /// @dev The repository's pending motion, or a motion file of `just motion`, on the vault with the motion's
    ///      base policy. This is the acceptance check of a motion: the deployed modifiers and the factory take
    ///      every write, in order, or the test fails. The suite replays the pending motion whenever the
    ///      repository holds one, so CI refuses a pending motion that would fail at its enactment.
    ///      `just motion-replay` replays `.motion/motion.json`. With neither, the test is skipped.
    function test_replay_a_motion_file() public {
        string memory path = vm.envOr("MOTION_FILE", string(""));
        policyArtifact = vm.envOr("POLICY_ARTIFACT", string(""));
        if (bytes(path).length == 0 && vm.exists(PENDING_MOTION)) {
            path = PENDING_MOTION;
            policyArtifact = PENDING_BASE;
        }
        if (bytes(path).length == 0) {
            vm.skip(true);
            return;
        }
        _enable();
        uint256 writes = _replay(vm.readFile(path));
        console2.log("MOTION file: writes", writes);
    }

    /// @dev Creates the file's motion from its calldata, waits out the objection window and enacts it. Then every
    ///      budget of the head policy is on chain. Returns the number of the motion's writes.
    function _replay(string memory file) internal returns (uint256 writes) {
        bytes memory cd = vm.parseJsonBytes(file, ".calldata");
        (uint256 motionEpoch, uint256 motionVersion, UniversalFactory.Write[] memory ws) = uf.decodeEVMScriptCallData(cd);
        assertEq(motionEpoch, uf.epoch(), "the motion names the factory's counter");
        assertEq(motionVersion, uf.policyVersion(), "the motion names the factory's policy version");
        writes = ws.length;

        uint256 id = _create(cd);
        _afterWindow();
        vm.prank(anyone);
        uint256 g = gasleft();
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, cd);
        uint256 gasUsed = g - gasleft();
        assertLt(gasUsed, 16_777_216, "under EIP-7825's cap");
        console2.log("MOTION writes, calldata bytes, enactMotion gas", writes, cd.length, gasUsed);

        if (vm.parseJsonUint(file, ".budgetCount") == 0) return writes;
        address[] memory modifier_ = vm.parseJsonAddressArray(file, ".budgets.modifier");
        bytes32[] memory key = vm.parseJsonBytes32Array(file, ".budgets.key");
        uint256[] memory balance = vm.parseJsonUintArray(file, ".budgets.balance");
        uint256[] memory refill = vm.parseJsonUintArray(file, ".budgets.refill");
        uint256[] memory period = vm.parseJsonUintArray(file, ".budgets.period");
        for (uint256 i = 0; i < key.length; i++) {
            (uint128 r,, uint64 p, uint128 b,) = IRoles(modifier_[i]).allowances(key[i]);
            assertEq(b, balance[i], "a budget's balance is the head policy's");
            assertEq(r, refill[i], "a budget's refill is the head policy's");
            assertEq(p, period[i], "a budget's period is the head policy's");
        }
    }

    function _emergency(address to, bytes memory data, bool expectOk) internal {
        vm.prank(address(emergency));
        (bool ok, bytes memory ret) =
            address(safetyMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, EMERGENCY, true)));
        assertEq(ok, expectOk, "emergency call outcome");
        if (!ok) assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }
}
