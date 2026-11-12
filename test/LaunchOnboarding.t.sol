// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {
    IERC20,
    IStETH,
    IWstETH,
    IWETH,
    IERC4626,
    IDaiUsds,
    ILidoEarnDepositQueue,
    ILidoEarnRedeemQueue
} from "../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../src/factory/UniversalFactory.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {Recorded} from "./rehearsal/Recorded.sol";

/// @title LaunchOnboarding — the onboarding motion of each launch protocol, enacted through the live Easy Track
///        (ADR 006, decision 13; ADR 013).
/// @dev The enabling vote writes the whole launch policy, so each test first takes one protocol out, as the owner
///      of the modifiers, which is what a DAO vote would do. It then enacts the protocol's committed motion
///      (policy/constellation/compiler/launch.ts), which writes the operator's permissions, the budget and the
///      emergency exits. After it, the operator uses the protocol within the policy, and the emergency role exits.
///      Each test writes the modifiers' events to `.roundtrip/`, and the round-trip rehearsal checks that the
///      chain holds the committed policy again. Lines that start with "LAUNCH" are the measures.
///      Run: just round-trip, or RPC=<archive RPC> forge test --match-contract LaunchOnboarding -vv
contract LaunchOnboarding is Recorded {
    string internal constant FILE = "policy/constellation/artifacts/launch-onboarding-rehearsal-26249900.json";
    bytes4 internal constant CONDITION_VIOLATION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));

    address internal stranger = makeAddr("stranger");
    string internal file;

    function setUp() public {
        _fork();
        file = vm.readFile(FILE);
    }

    /// @dev Lido staking. The emergency role's staking of ETH is no motion's to write, so the removal leaves it,
    ///      and it works throughout.
    function test_launch_onboarding_of_lido_staking() public {
        _deployAndEnable();
        vm.deal(address(asset), 10 ether);
        _remove("lido");
        _opRefused(Mainnet.STETH, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));
        _opRefused(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.wrap, (1)));
        _emRefused(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.unwrap, (1)));
        _em(Mainnet.STETH, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));
        _emRefused(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 0)));

        _onboard("lido", 6);
        uint256 before = IERC20(Mainnet.STETH).balanceOf(address(asset));
        _op(Mainnet.STETH, 5 ether, abi.encodeCall(IStETH.submit, (address(0))));
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)) - before, 5 ether, 2, "the operator staked 5 ETH");
        _opRefused(Mainnet.STETH, 1 ether, abi.encodeCall(IStETH.submit, (stranger)));
        // the approval to the wstETH contract stays below its ceiling
        _opRefused(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, SIZE_STANDIN_STETH)));
        _opRefused(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (stranger, 1)));
        _op(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 4 ether)));
        _op(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.wrap, (4 ether)));
        uint256 wrapped = IERC20(Mainnet.WSTETH).balanceOf(address(asset));
        assertGt(wrapped, 0, "the operator wrapped stETH");
        _op(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.unwrap, (wrapped / 2)));
        _em(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.unwrap, (wrapped - wrapped / 2)));
        assertEq(IERC20(Mainnet.WSTETH).balanceOf(address(asset)), 0, "the emergency role unwrapped the rest");
        // the emergency role sets an approval of stETH to zero, for any spender, and gives none
        _op(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 1 ether)));
        _emRefused(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 1)));
        _em(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 0)));
        assertEq(IERC20(Mainnet.STETH).allowance(address(asset), Mainnet.WSTETH), 0, "the emergency role set the approval to zero");
        _em(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (stranger, 0)));
        _write("launch-lido.ndjson");
    }

    /// @dev WETH: the operator wraps and unwraps ETH, and the emergency role unwraps.
    function test_launch_onboarding_of_weth() public {
        _deployAndEnable();
        vm.deal(address(asset), 10 ether);
        _remove("weth");
        _opRefused(Mainnet.WETH, 1 ether, abi.encodeCall(IWETH.deposit, ()));
        _emRefused(Mainnet.WETH, 0, abi.encodeCall(IWETH.withdraw, (1)));

        _onboard("weth", 3);
        _op(Mainnet.WETH, 3 ether, abi.encodeCall(IWETH.deposit, ()));
        assertEq(IERC20(Mainnet.WETH).balanceOf(address(asset)), 3 ether, "the operator wrapped 3 ETH");
        _op(Mainnet.WETH, 0, abi.encodeCall(IWETH.withdraw, (1 ether)));
        _em(Mainnet.WETH, 0, abi.encodeCall(IWETH.withdraw, (2 ether)));
        assertEq(IERC20(Mainnet.WETH).balanceOf(address(asset)), 0, "the emergency role unwrapped the rest");
        assertEq(address(asset).balance, 10 ether, "the ETH is back");
        _write("launch-weth.ndjson");
    }

    /// @dev Sky: the converter one to one with the Asset Safe as receiver, and sUSDS savings within the budget.
    ///      The emergency role redeems to the Asset Safe and sends the rest of the shares to the Aragon Agent.
    function test_launch_onboarding_of_sky() public {
        _deployAndEnable();
        deal(Mainnet.DAI, address(asset), 2_000e18);
        _remove("sky");
        _opRefused(Mainnet.DAI, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 1)));
        _opRefused(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, 1)));
        _opRefused(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.deposit, (1, address(asset))));
        _emRefused(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.redeem, (1, address(asset), address(asset))));
        (,,, uint128 emptied,) = opMod.allowances(bytes32("sky_savings_usds"));
        assertEq(emptied, 0, "the removal emptied the budget");
        _emRefused(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, 0)));
        _emRefused(Mainnet.DAI, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 0)));

        _onboard("sky", 17);
        (,,, uint128 budget,) = opMod.allowances(bytes32("sky_savings_usds"));
        assertEq(budget, SKY_SAVINGS_USDS, "the motion set the budget");
        _op(Mainnet.DAI, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 1_500e18)));
        _opRefused(DAI_USDS, 0, abi.encodeCall(IDaiUsds.daiToUsds, (stranger, 1)));
        _op(DAI_USDS, 0, abi.encodeCall(IDaiUsds.daiToUsds, (address(asset), 1_500e18)));
        assertEq(IERC20(Mainnet.USDS).balanceOf(address(asset)), 1_500e18, "DAI became USDS, one to one");
        // sUSDS within the budget, and no further
        _op(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, SKY_SAVINGS_USDS)));
        _opRefused(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (Mainnet.SUSDS, 1)));
        _opRefused(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.deposit, (1, stranger)));
        _op(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.deposit, (SKY_SAVINGS_USDS, address(asset))));
        uint256 shares = IERC20(Mainnet.SUSDS).balanceOf(address(asset));
        assertGt(shares, 0, "the Asset Safe holds sUSDS");
        _op(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.redeem, (shares / 4, address(asset), address(asset))));
        // back into DAI, under the converter's ceiling
        _op(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 100e18)));
        _op(DAI_USDS, 0, abi.encodeCall(IDaiUsds.usdsToDai, (address(asset), 100e18)));
        // the emergency role sets the approvals of DAI and USDS to zero, and gives none
        _op(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 50e18)));
        _emRefused(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 1)));
        _em(Mainnet.USDS, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 0)));
        assertEq(IERC20(Mainnet.USDS).allowance(address(asset), DAI_USDS), 0, "the emergency role set the approval to zero");
        _em(Mainnet.DAI, 0, abi.encodeCall(IERC20.approve, (DAI_USDS, 0)));
        // the emergency role exits to the Asset Safe, and sends the rest to the Aragon Agent only
        _emRefused(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.redeem, (1, stranger, address(asset))));
        _em(Mainnet.SUSDS, 0, abi.encodeCall(IERC4626.redeem, (shares / 4, address(asset), address(asset))));
        _emRefused(Mainnet.SUSDS, 0, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        uint256 left = IERC20(Mainnet.SUSDS).balanceOf(address(asset));
        uint256 agent = IERC20(Mainnet.SUSDS).balanceOf(Mainnet.AGENT);
        _em(Mainnet.SUSDS, 0, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, left)));
        assertEq(IERC20(Mainnet.SUSDS).balanceOf(Mainnet.AGENT) - agent, left, "the Agent holds the remaining shares");
        _write("launch-sky.ndjson");
    }

    /// @dev Lido earnUSD: the USDC approval to the deposit queue within the budget, the deposit, and the
    ///      emergency role's cancel, which brings the USDC back to the Asset Safe.
    function test_launch_onboarding_of_earn_usd() public {
        _deployAndEnable();
        _remove("earnUsd");
        _earn("earnUsd", Mainnet.USDC, Mainnet.EARN_USD_DEPOSIT_QUEUE, EARN_USD_REDEEM_QUEUE, Mainnet.EARN_USD_SHARE, EARN_USD_DEPOSIT);
        (,,, uint128 budget,) = opMod.allowances(bytes32("earn_usd_deposit"));
        assertEq(budget, 0, "the approval spent the budget");
        _write("launch-earnUsd.ndjson");
    }

    /// @dev Lido earnETH: the same with wstETH, which the operator wraps first.
    function test_launch_onboarding_of_earn_eth() public {
        _deployAndEnable();
        _op(Mainnet.STETH, 0, abi.encodeCall(IERC20.approve, (Mainnet.WSTETH, 9e18)));
        _op(Mainnet.WSTETH, 0, abi.encodeCall(IWstETH.wrap, (9e18)));
        _remove("earnEth");
        _earn("earnEth", Mainnet.WSTETH, EARN_ETH_DEPOSIT_QUEUE, 0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4, Mainnet.EARN_ETH_SHARE, EARN_ETH_DEPOSIT_WSTETH);
        _write("launch-earnEth.ndjson");
    }

    /// @dev An Earn vault after its removal: nothing of it works for the operator or the emergency role. Then the
    ///      motion, the operator's approval and deposit within the budget, and the emergency role's exits.
    function _earn(string memory key, address token, address depositQueue, address redeemQueue, address share, uint128 budget)
        internal
    {
        bytes32[] memory noProof = new bytes32[](0);
        uint32[] memory noIds = new uint32[](0);
        bytes memory deposit = abi.encodeCall(ILidoEarnDepositQueue.deposit, (uint224(budget / 2), address(0), noProof));
        _opRefused(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, 1)));
        _opRefused(depositQueue, 0, deposit);
        _opRefused(redeemQueue, 0, abi.encodeCall(ILidoEarnRedeemQueue.redeem, (1)));
        _emRefused(depositQueue, 0, abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest, ()));
        _emRefused(redeemQueue, 0, abi.encodeCall(ILidoEarnRedeemQueue.claim, (address(asset), noIds)));
        _emRefused(share, 0, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 1)));
        _emRefused(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, 0)));

        _onboard(key, 18);
        uint256 held = IERC20(token).balanceOf(address(asset));
        assertGe(held, budget, "the Asset Safe holds the token");
        _opRefused(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, uint256(budget) + 1)));
        _opRefused(token, 0, abi.encodeCall(IERC20.approve, (stranger, 1)));
        _op(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, budget)));
        _opRefused(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, 1)));
        // the operator deposits half of what it approved, so an approval of the other half stays open
        _op(depositQueue, 0, deposit);
        assertEq(IERC20(token).balanceOf(address(asset)), held - budget / 2, "the deposit left the Asset Safe");
        assertEq(IERC20(token).allowance(address(asset), depositQueue), budget - budget / 2, "an approval is left open");
        // the emergency role sets the open approval to zero, and gives none
        _emRefused(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, 1)));
        _em(token, 0, abi.encodeCall(IERC20.approve, (depositQueue, 0)));
        assertEq(IERC20(token).allowance(address(asset), depositQueue), 0, "the emergency role set the approval to zero");
        _em(token, 0, abi.encodeCall(IERC20.approve, (stranger, 0)));
        // every claim pays the Asset Safe
        _opRefused(depositQueue, 0, abi.encodeCall(ILidoEarnDepositQueue.claim, (stranger)));
        _emRefused(depositQueue, 0, abi.encodeCall(ILidoEarnDepositQueue.claim, (stranger)));
        _emRefused(redeemQueue, 0, abi.encodeCall(ILidoEarnRedeemQueue.claim, (stranger, noIds)));
        _emRefused(share, 0, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        // the emergency role cancels the pending deposit, and the token is back
        _em(depositQueue, 0, abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest, ()));
        assertEq(IERC20(token).balanceOf(address(asset)), held, "the cancelled deposit came back");
        // the redeem queue and the share's way to the Agent pass the policy: the queue takes a redeem of no shares
        // or refuses it itself, and the transfer of no shares goes through
        _passes(address(emergency), safetyMod, EMERGENCY, share, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 0)));
        _passes(address(emergency), safetyMod, EMERGENCY, redeemQueue, abi.encodeCall(ILidoEarnRedeemQueue.redeem, (0)));
        _passes(Mainnet.COMMITTEE_SAFE, opMod, OPERATOR, redeemQueue, abi.encodeCall(ILidoEarnRedeemQueue.redeem, (0)));
        _passes(Mainnet.COMMITTEE_SAFE, opMod, OPERATOR, redeemQueue, abi.encodeCall(ILidoEarnRedeemQueue.claim, (address(asset), noIds)));
        _passes(address(emergency), safetyMod, EMERGENCY, redeemQueue, abi.encodeCall(ILidoEarnRedeemQueue.claim, (address(asset), noIds)));
    }

    // ---------------------------------------------------------------------
    // The removal and the motion
    // ---------------------------------------------------------------------

    /// @dev The owner of both modifiers, the Asset Safe, takes the protocol out of the policy: the file's calls.
    function _remove(string memory key) internal {
        address[] memory to = vm.parseJsonAddressArray(file, string.concat(".protocols.", key, ".removal.to"));
        bytes[] memory data = vm.parseJsonBytesArray(file, string.concat(".protocols.", key, ".removal.data"));
        assertGt(to.length, 0, "the removal has calls");
        for (uint256 i = 0; i < to.length; i++) {
            vm.prank(address(asset));
            (bool ok,) = to[i].call(data[i]);
            assertTrue(ok, "the owner's removal");
        }
        _keep();
    }

    /// @dev Creates the protocol's committed motion, waits out the objection window and enacts it.
    function _onboard(string memory key, uint256 expectedWrites) internal {
        bytes memory cd = vm.parseJsonBytes(file, string.concat(".protocols.", key, ".calldata"));
        (uint256 motionEpoch, uint256 motionVersion, UniversalFactory.Write[] memory ws) = uf.decodeEVMScriptCallData(cd);
        assertEq(motionEpoch, uf.epoch(), "the motion names the factory's counter");
        assertEq(motionVersion, uf.policyVersion(), "the motion names the factory's policy version");
        assertEq(ws.length, expectedWrites, "the motion's writes");
        uint256 id = _create(cd);
        _afterWindow();
        vm.prank(anyone);
        uint256 g = gasleft();
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, cd);
        uint256 gasUsed = g - gasleft();
        assertLt(gasUsed, TX_GAS_CAP, "under EIP-7825's cap");
        console2.log(string.concat("LAUNCH onboarding of ", key, ": writes, calldata bytes, enactMotion gas"), ws.length, cd.length, gasUsed);
        _keep();
    }

    // ---------------------------------------------------------------------
    // Calls through the roles
    // ---------------------------------------------------------------------

    function _call(address member, IRoles modifier_, bytes32 role, address to, uint256 value, bytes memory data)
        internal
        returns (bool ok, bytes memory ret)
    {
        vm.prank(member);
        (ok, ret) = address(modifier_).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, value, data, 0, role, true)));
    }

    function _op(address to, uint256 value, bytes memory data) internal {
        (bool ok,) = _call(Mainnet.COMMITTEE_SAFE, opMod, OPERATOR, to, value, data);
        assertTrue(ok, "the operator's call");
    }

    function _opRefused(address to, uint256 value, bytes memory data) internal {
        (bool ok, bytes memory ret) = _call(Mainnet.COMMITTEE_SAFE, opMod, OPERATOR, to, value, data);
        assertFalse(ok, "the operator's call is refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    function _em(address to, uint256 value, bytes memory data) internal {
        (bool ok,) = _call(address(emergency), safetyMod, EMERGENCY, to, value, data);
        assertTrue(ok, "the emergency role's call");
    }

    function _emRefused(address to, uint256 value, bytes memory data) internal {
        (bool ok, bytes memory ret) = _call(address(emergency), safetyMod, EMERGENCY, to, value, data);
        assertFalse(ok, "the emergency role's call is refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    /// @dev The policy lets the call through: it succeeds, or the called contract itself refuses it.
    function _passes(address member, IRoles modifier_, bytes32 role, address to, bytes memory data) internal {
        (bool ok, bytes memory ret) = _call(member, modifier_, role, to, 0, data);
        if (!ok) assertTrue(bytes4(ret) != CONDITION_VIOLATION, "the policy lets the call through");
    }
}
