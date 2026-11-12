// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {SepoliaStandFixture} from "./utils/SepoliaStandFixture.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {MockAragonVoting} from "../src/mocks/MockAragonVoting.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {SepoliaDepositQueue, SepoliaEasyTrack} from "../src/mocks/SepoliaStand.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";
import {DeployFactorySepolia} from "../script/sepolia/DeployFactorySepolia.s.sol";

interface IComposableCoWRemove {
    function remove(bytes32 singleOrderHash) external;
}

interface IWETH {
    function withdraw(uint256 amount) external;
}

/// @dev The migration of the existing stand to the universal factory, on a fork of the stand. The test deploys
///      what `deploy-factory` deploys, from the controller, and applies the artifact that the runner compiled for
///      those addresses. Run it with scripts/sepolia_factory_migration.py.
contract SepoliaFactoryMigrationTest is SepoliaStandFixture {
    bytes32 internal constant GOVERNANCE = "governance";
    bytes32 internal constant INSURANCE_FUNDING = "insurance-funding";
    bytes32 internal constant RESTART = "restart";
    bytes32 internal constant EXIT_GOVERNANCE = "exit-governance";
    bytes32 internal constant APPROVALS = "approvals";
    bytes32 internal constant BURN = "first-loss-burn";
    bytes32 internal constant INSURANCE = "insurance";
    bytes32 internal constant INSURANCE_GOVERNANCE = "insurance-governance";

    UniversalFactory internal uf;
    SepoliaEasyTrack internal et;
    SepoliaDepositQueue internal ethDeposits;
    address internal weth;

    function setUp() public override {
        if (vm.envOr("SEPOLIA_STAND_BLOCK", uint256(0)) == 0 || bytes(vm.envOr("SEPOLIA_ARTIFACT", string(""))).length == 0) {
            vm.skip(true);
            return;
        }
        super.setUp();
        et = SepoliaEasyTrack(a("easyTrack"));
        weth = token("weth");
        UniversalFactory.Config memory config = new DeployFactorySepolia().config(manifest);
        // The fixture's pranked top-ups raise the controller's nonce on the fork; deploy from the block's nonce.
        vm.setNonceUnsafe(controller, uint64(vm.envUint("SEPOLIA_CONTROLLER_NONCE")));
        vm.startPrank(controller);
        SepoliaDepositQueue usdDeposits = new SepoliaDepositQueue(IERC20(token("usdc")));
        ethDeposits = new SepoliaDepositQueue(IERC20(weth));
        uf = new UniversalFactory(config);
        assertEq(address(usdDeposits), a("usdDepositQueue"), "runner predicted the USD queue");
        assertEq(address(ethDeposits), a("ethDepositQueue"), "runner predicted the ETH queue");
        assertEq(address(uf), a("universalFactory"), "runner predicted the factory");
        et.addEVMScriptFactory(address(uf));
        string memory artifact = vm.readFile(vm.envString("SEPOLIA_ARTIFACT"));
        address[] memory to = vm.parseJsonAddressArray(artifact, ".calls.to");
        address[] memory avatars = vm.parseJsonAddressArray(artifact, ".calls.avatar");
        bytes[] memory data = vm.parseJsonBytesArray(artifact, ".calls.data");
        MockAragonVoting voting = MockAragonVoting(payable(a("voting")));
        for (uint256 i; i < to.length; ++i) {
            SafeExec.execAsOwner(voting, ISafe(payable(avatars[i])), to[i], data[i]);
        }
        vm.stopPrank();
    }

    // --- helpers ---

    function write(IRoles modifier_, bytes32 role, address to, bytes memory data)
        internal
        pure
        returns (UniversalFactory.Write memory)
    {
        return UniversalFactory.Write(address(modifier_), role, to, data);
    }

    function one(UniversalFactory.Write memory w) internal pure returns (UniversalFactory.Write[] memory writes) {
        writes = new UniversalFactory.Write[](1);
        writes[0] = w;
    }

    function create(UniversalFactory.Write[] memory writes) internal returns (uint256 id, bytes memory input) {
        input = abi.encode(uf.epoch(), uf.policyVersion(), writes);
        id = et.motionsCount();
        committeeCall(address(et), abi.encodeCall(et.createMotion, (address(uf), input)));
        vm.warp(block.timestamp + et.motionDuration());
    }

    function enact(UniversalFactory.Write[] memory writes) internal {
        (uint256 id, bytes memory input) = create(writes);
        et.enactMotion(id, input);
    }

    function enactRefused(UniversalFactory.Write[] memory writes) internal {
        (uint256 id, bytes memory input) = create(writes);
        vm.expectPartialRevert(MockEVMScriptExecutor.CallFailed.selector);
        et.enactMotion(id, input);
    }

    function derivedKeyOf(address token_, address spender) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(bytes2(0x6b3a), spender, bytes10(bytes20(token_))));
    }

    function emergencyCall(address to, bytes memory data) internal {
        bytes memory signature = abi.encodePacked(bytes32(uint256(uint160(controller))), bytes32(0), uint8(1));
        vm.prank(controller);
        assertTrue(
            ISafe(payable(emergency)).execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature)
        );
    }

    function stopOperator() internal {
        (address[] memory modules,) = ISafe(payable(asset)).getModulesPaginated(address(1), 10);
        address previous = address(1);
        for (uint256 i; i < modules.length && modules[i] != address(operator); ++i) previous = modules[i];
        exec(emergency, safety, assetEmergency, asset, abi.encodeCall(ISafe.disableModule, (previous, address(operator))), 0);
    }

    // --- the old motion path ---

    function test_MIG_executor_loses_governance_and_burn_roles() public {
        address executor = a("easyTrackExecutor");
        bytes memory revoke = abi.encodeCall(IRoles.revokeFunction, (assetOperator, weth, IERC20.transfer.selector));
        vm.prank(executor);
        (bool ok,) = address(operator)
            .call(abi.encodeCall(IRoles.execTransactionWithRole, (address(operator), 0, revoke, 0, GOVERNANCE, true)));
        assertFalse(ok, "executor keeps governance");
        vm.prank(executor);
        (ok,) = address(firstLossRoles)
            .call(
                abi.encodeCall(
                    IRoles.execTransactionWithRole, (a("usdShare"), 0, abi.encodeCall(IERC20.transfer, (asset, 1)), 0, BURN, true)
                )
            );
        assertFalse(ok, "executor keeps the burn role");
    }

    // --- one motion for each role ---

    function test_MIG_budget_motion_sets_insurance_cap_and_funding_spends_it() public {
        bytes32 wethKey = derivedKeyOf(weth, firstLoss);
        enact(
            one(
                write(
                    operator,
                    GOVERNANCE,
                    address(operator),
                    abi.encodeCall(IRoles.setAllowance, (wethKey, 1 ether, 1 ether, 1 ether, uint64(30 days), 0))
                )
            )
        );
        assertEq(uf.policyVersion(), 1);
        (,,, uint128 balance,) = operator.allowances(wethKey);
        assertEq(balance, 1 ether);
        deal(weth, asset, 2 ether);
        uint256 before = IERC20(weth).balanceOf(firstLoss);
        UniversalFactory.Write[] memory fund =
            one(write(operator, INSURANCE_FUNDING, weth, abi.encodeCall(IERC20.transfer, (firstLoss, 1 ether))));
        enact(fund);
        assertEq(IERC20(weth).balanceOf(firstLoss), before + 1 ether);
        assertEq(uf.policyVersion(), 1, "a transfer is no policy write");
        fund[0].data = abi.encodeCall(IERC20.transfer, (firstLoss, 1));
        enactRefused(fund);
        fund[0].data = abi.encodeCall(IERC20.transfer, (committee, 0));
        enactRefused(fund);
    }

    function test_MIG_budget_motion_refuses_a_short_period() public {
        enactRefused(
            one(
                write(
                    operator,
                    GOVERNANCE,
                    address(operator),
                    abi.encodeCall(
                        IRoles.setAllowance, (derivedKeyOf(weth, firstLoss), 1, 1, 1, uint64(30 days - 1), 0)
                    )
                )
            )
        );
    }

    function test_MIG_restart_motion_enables_operator_after_a_stop() public {
        stopOperator();
        assertFalse(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        enact(one(write(safety, RESTART, asset, abi.encodeCall(ISafe.enableModule, (address(operator))))));
        assertTrue(ISafe(payable(asset)).isModuleEnabled(address(operator)));
        enactRefused(one(write(safety, RESTART, asset, abi.encodeCall(ISafe.enableModule, (address(0xBEEF))))));
    }

    function test_MIG_exit_governance_motion_gives_emergency_one_plain_exit() public {
        deal(weth, asset, 1 ether);
        bytes memory unwrap = abi.encodeCall(IWETH.withdraw, (1));
        denied(emergency, safety, assetEmergency, weth, unwrap, 0);
        enact(
            one(
                write(
                    safety,
                    EXIT_GOVERNANCE,
                    address(safety),
                    abi.encodeCall(IRoles.allowFunction, (assetEmergency, weth, IWETH.withdraw.selector, uint8(0)))
                )
            )
        );
        exec(emergency, safety, assetEmergency, weth, unwrap, 0);
        enactRefused(
            one(
                write(
                    safety,
                    EXIT_GOVERNANCE,
                    address(safety),
                    abi.encodeCall(IRoles.allowFunction, (assetOperator, weth, IWETH.withdraw.selector, uint8(0)))
                )
            )
        );
    }

    function test_MIG_orders_governance_motion_restores_a_revoked_cancel() public {
        address cow = d("composableCow");
        bytes memory remove = abi.encodeCall(IComposableCoWRemove.remove, (bytes32(0)));
        exec(committee, ordersRoles, ordersOperator, cow, remove, 0);
        exec(
            emergency,
            ordersRoles,
            ordersEmergency,
            address(ordersRoles),
            abi.encodeCall(IRoles.revokeFunction, (ordersOperator, cow, IComposableCoWRemove.remove.selector)),
            0
        );
        denied(committee, ordersRoles, ordersOperator, cow, remove, 0);
        enact(
            one(
                write(
                    ordersRoles,
                    GOVERNANCE,
                    address(ordersRoles),
                    abi.encodeCall(IRoles.allowFunction, (ordersOperator, cow, IComposableCoWRemove.remove.selector, uint8(0)))
                )
            )
        );
        exec(committee, ordersRoles, ordersOperator, cow, remove, 0);
    }

    function test_MIG_approvals_motion_sets_the_relayer_approval() public {
        address relayer = d("vaultRelayer");
        enact(one(write(ordersRoles, APPROVALS, weth, abi.encodeCall(IERC20.approve, (relayer, 5)))));
        assertEq(IERC20(weth).allowance(orders, relayer), 5);
        enactRefused(one(write(ordersRoles, APPROVALS, weth, abi.encodeCall(IERC20.approve, (committee, 5)))));
    }

    function test_MIG_burn_motion_burns_first_loss_shares() public {
        IERC20 share = IERC20(a("usdShare"));
        uint256 before = share.balanceOf(firstLoss);
        enact(one(write(firstLossRoles, BURN, address(share), abi.encodeWithSignature("burn(uint256)", 1 ether))));
        assertEq(share.balanceOf(firstLoss), before - 1 ether);
        enactRefused(one(write(firstLossRoles, BURN, address(share), abi.encodeCall(IERC20.transfer, (asset, 1)))));
    }

    function test_MIG_insurance_motion_deposits_into_the_queue() public {
        deal(weth, firstLoss, 1 ether);
        UniversalFactory.Write[] memory writes = new UniversalFactory.Write[](2);
        writes[0] = write(firstLossRoles, INSURANCE, weth, abi.encodeCall(IERC20.approve, (address(ethDeposits), 1 ether)));
        writes[1] = write(
            firstLossRoles,
            INSURANCE,
            address(ethDeposits),
            abi.encodeCall(SepoliaDepositQueue.deposit, (uint224(1 ether), address(0), new bytes32[](0)))
        );
        enact(writes);
        assertEq(ethDeposits.requested(firstLoss), 1 ether);
        deal(weth, firstLoss, 1 ether);
        writes[1].data = abi.encodeCall(SepoliaDepositQueue.deposit, (uint224(1 ether), committee, new bytes32[](0)));
        enactRefused(writes);
    }

    function test_MIG_insurance_governance_motion_sets_a_cap_without_refill() public {
        bytes32 fundKey = derivedKeyOf(weth, committee);
        enact(
            one(
                write(
                    firstLossRoles,
                    INSURANCE_GOVERNANCE,
                    address(firstLossRoles),
                    abi.encodeCall(IRoles.setAllowance, (fundKey, 1 ether, 0, 0, 0, 0))
                )
            )
        );
        (uint128 refill,,, uint128 balance,) = firstLossRoles.allowances(fundKey);
        assertEq(refill, 0);
        assertEq(balance, 1 ether);
        enactRefused(
            one(
                write(
                    firstLossRoles,
                    INSURANCE_GOVERNANCE,
                    address(firstLossRoles),
                    abi.encodeCall(IRoles.setAllowance, (fundKey, 1 ether, 1 ether, 1 ether, uint64(30 days), 0))
                )
            )
        );
        enactRefused(
            one(
                write(
                    firstLossRoles,
                    INSURANCE_GOVERNANCE,
                    address(firstLossRoles),
                    abi.encodeCall(IRoles.scopeTarget, (INSURANCE, firstLoss))
                )
            )
        );
    }

    // --- the factory's own checks on the stand ---

    function test_MIG_emergency_counter_raise_fails_an_open_motion() public {
        (uint256 id, bytes memory input) = create(one(write(safety, RESTART, asset, abi.encodeCall(ISafe.enableModule, (address(operator))))));
        emergencyCall(address(uf), abi.encodeCall(UniversalFactory.raiseCounter, ()));
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StaleCounter.selector, 0, 1));
        et.enactMotion(id, input);
    }

    function test_MIG_policy_version_fails_the_second_of_two_policy_motions() public {
        UniversalFactory.Write[] memory writes = one(
            write(
                operator,
                GOVERNANCE,
                address(operator),
                abi.encodeCall(IRoles.setAllowance, (derivedKeyOf(weth, firstLoss), 1, 1, 1, uint64(30 days), 0))
            )
        );
        (uint256 first, bytes memory input) = create(writes);
        (uint256 second,) = create(writes);
        et.enactMotion(first, input);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.StalePolicyVersion.selector, 0, 1));
        et.enactMotion(second, input);
    }

    function test_MIG_only_the_committee_creates_and_voting_cancels() public {
        bytes memory input = abi.encode(
            uint256(0),
            uint256(0),
            one(write(safety, RESTART, asset, abi.encodeCall(ISafe.enableModule, (address(operator)))))
        );
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(UniversalFactory.NotTrustedCaller.selector, controller));
        et.createMotion(address(uf), input);
        (uint256 id,) = create(one(write(safety, RESTART, asset, abi.encodeCall(ISafe.enableModule, (address(operator))))));
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        vm.prank(controller);
        MockAragonVoting(payable(a("voting"))).execute(address(et), 0, abi.encodeCall(SepoliaEasyTrack.cancelMotions, (ids)));
        vm.expectRevert("ET: motion not pending");
        et.enactMotion(id, input);
    }
}
