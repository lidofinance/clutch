// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {EnabledVault} from "./rehearsal/EnabledVault.sol";
import {VoteBuilder} from "./rehearsal/VoteBuilder.sol";

interface IERC4626Vault {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}

/// @title ExitGovernanceRehearsal — the exit-governance role on the enabling vote's vault (ADR 006, decision 13;
///        OD-49; INV-025), and the exit that a token gets when a motion adds it to the order lists (ADR 007,
///        decision 45).
/// @dev Each write is made as the universal factory, the role's member, makes it in an enacted motion's call.
///      Run: RPC=<archive RPC> forge test --match-contract ExitGovernanceRehearsal
contract ExitGovernanceRehearsal is EnabledVault {
    bytes4 internal constant CONDITION_VIOLATION = 0xd0a9bf58;
    bytes32 internal constant EXIT_GOVERNANCE = bytes32("exit-governance");
    bytes32 internal constant RESTART = bytes32("restart");
    uint8 internal constant CALL = 0;
    uint8 internal constant OPTION_SEND = 1;
    uint8 internal constant OPTION_DELEGATECALL = 2;
    bytes4 internal constant TRANSFER = IERC20.transfer.selector;
    bytes4 internal constant APPROVE = IERC20.approve.selector;
    bytes4 internal constant TRANSFER_FROM = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 internal constant DEPOSIT = IERC4626Vault.deposit.selector;
    bytes4 internal constant REDEEM = IERC4626Vault.redeem.selector;
    bytes4 internal constant WITHDRAW = IERC4626Vault.withdraw.selector;
    bytes4 internal constant CLAIM = bytes4(keccak256("claim(address)"));
    bytes4 internal constant CLAIM_REQUESTS = bytes4(keccak256("claim(address,uint32[])"));
    bytes4 internal constant CANCEL_DEPOSIT = bytes4(keccak256("cancelDepositRequest()"));
    bytes4 internal constant QUEUE_REDEEM = bytes4(keccak256("redeem(uint256)"));
    bytes4 internal constant UNWRAP = bytes4(keccak256("unwrap(uint256)"));
    bytes4 internal constant UNWRAP_WETH = bytes4(keccak256("withdraw(uint256)"));
    uint8 internal constant T_STATIC = 1;
    uint8 internal constant T_CALLDATA = 5;
    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO = 16;

    /// @dev A stand-in for an ERC-4626 position that an onboarding motion adds: Spark's savings DAI. No decision
    ///      lists it.
    address internal constant VAULT = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    address internal stranger = makeAddr("stranger");

    /// @dev The emergency role's own exit trees in the artifact, which exit-governance writes for a new target.
    struct Exits {
        IRoles.ConditionFlat[] toAgent; // a transfer to the Aragon Agent, as for an Earn share
        IRoles.ConditionFlat[] toAgentOrOrders; // to the Agent or the orders account, as for a token that recovery sells
        IRoles.ConditionFlat[] vault; // an ERC-4626 redeem or withdrawal paid to the Asset Safe
        IRoles.ConditionFlat[] claim; // a queue's claim paid to the Asset Safe
        IRoles.ConditionFlat[] zero; // an approval set to zero, for any spender
    }

    function setUp() public {
        _fork();
        _deployAccounts();
        _deployFactory();
    }

    modifier enabled() {
        _enable();
        _;
    }

    /// @dev INV-025: exit-governance writes the emergency role's exits and nothing else: only under the emergency key,
    ///      only the five pinned trees and the four exits without conditions, only as plain calls, and never on a
    ///      vault account. It holds no membership setter and no administration, and only the universal factory holds it.
    function test_exit_governance_writes_only_exits() public enabled {
        Exits memory e = _exits();
        address token = Mainnet.WBTC;
        _exitOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, e.toAgent, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, e.toAgentOrOrders, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, e.zero, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, REDEEM, e.vault, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, WITHDRAW, e.vault, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, CLAIM, e.claim, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, CLAIM_REQUESTS, e.claim, 0)));
        bytes4[4] memory plain = [CANCEL_DEPOSIT, QUEUE_REDEEM, UNWRAP, UNWRAP_WETH];
        for (uint256 i = 0; i < plain.length; i++) {
            _exitOk(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, VAULT, plain[i], 0)));
        }

        // another key: the operator's, the restart role's, its own, the governance role's
        bytes32[4] memory keys = [OPERATOR, RESTART, EXIT_GOVERNANCE, GOVERNANCE];
        for (uint256 i = 0; i < keys.length; i++) {
            _exitRefused(abi.encodeCall(IRoles.scopeTarget, (keys[i], token)));
            _exitRefused(abi.encodeCall(IRoles.scopeFunction, (keys[i], token, TRANSFER, e.toAgent, 0)));
        }
        // another receiver, a non-zero approval, a tree for another exit, a function that is no exit
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, _pinned(stranger), 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, APPROVE, _approval(1), 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, REDEEM, e.toAgent, 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, e.vault, 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER_FROM, e.toAgent, 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, DEPOSIT, e.claim, 0)));
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, CLAIM, _pinned(stranger), 0)));
        // Send or delegatecall; a transfer, an approval or a deposit without conditions
        _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, e.toAgent, OPTION_SEND)));
        _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, VAULT, UNWRAP, OPTION_DELEGATECALL)));
        _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, VAULT, UNWRAP, OPTION_SEND)));
        _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, token, TRANSFER, 0)));
        _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, token, APPROVE, 0)));
        _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, VAULT, DEPOSIT, 0)));

        // the vault's accounts, so never the switch
        address[5] memory vaultAccounts = [address(asset), address(opMod), address(safetyMod), address(orders), address(ordersMod)];
        for (uint256 i = 0; i < vaultAccounts.length; i++) {
            _exitRefused(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, vaultAccounts[i])));
            _exitRefused(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, vaultAccounts[i], TRANSFER, e.toAgent, 0)));
            _exitRefused(abi.encodeCall(IRoles.allowFunction, (EMERGENCY, vaultAccounts[i], UNWRAP, 0)));
        }

        // no membership, no administration
        bytes32[] memory emergencyKey = new bytes32[](1);
        emergencyKey[0] = EMERGENCY;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        _exitRefused(abi.encodeCall(IRoles.assignRoles, (stranger, emergencyKey, yes)));
        _exitRefused(abi.encodeCall(IRoles.setDefaultRole, (stranger, EMERGENCY)));
        _exitRefused(abi.encodeCall(IRoles.allowTarget, (EMERGENCY, token, 0)));
        _exitRefused(abi.encodeCall(IRoles.revokeTarget, (EMERGENCY, Mainnet.USDC)));
        _exitRefused(abi.encodeCall(IRoles.revokeFunction, (EMERGENCY, Mainnet.USDC, TRANSFER)));
        _exitRefused(abi.encodeCall(IRoles.setAllowance, (bytes32("k:any"), 1, 1, 1, 30 days, 0)));

        bytes memory write = abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token));
        address[3] memory others = [stranger, Mainnet.COMMITTEE_SAFE, address(emergency)];
        for (uint256 i = 0; i < others.length; i++) {
            vm.prank(others[i]);
            (bool ok,) = address(safetyMod).call(
                abi.encodeCall(IRoles.execTransactionWithRole, (address(safetyMod), 0, write, CALL, EXIT_GOVERNANCE, true))
            );
            assertFalse(ok, "only the universal factory holds the exit-governance role");
        }
    }

    /// @dev ADR 007, decision 45: a token that a motion adds to the order lists can arrive in the Asset Safe, as an
    ///      operator order's proceeds. Until the motion's exit, the emergency role cannot move it; after it, the
    ///      emergency role sends it to the Aragon Agent or to the orders account, and nowhere else.
    function test_exit_governance_gives_a_new_token_its_exit() public enabled {
        Exits memory e = _exits();
        address token = Mainnet.WBTC;
        deal(token, address(asset), 3e8);
        _emergencyRefused(token, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 1e8)));

        _exitOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, token)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, token, TRANSFER, e.toAgentOrOrders, 0)));

        _emergencyOk(token, abi.encodeCall(IERC20.transfer, (Mainnet.AGENT, 1e8)));
        _emergencyOk(token, abi.encodeCall(IERC20.transfer, (address(orders), 1e8)));
        assertEq(IERC20(token).balanceOf(address(orders)), 1e8, "the orders account holds it for a recovery order");
        _emergencyRefused(token, abi.encodeCall(IERC20.transfer, (stranger, 1)));
        _emergencyRefused(token, abi.encodeCall(IERC20.approve, (stranger, 1)));
        assertEq(IERC20(token).balanceOf(address(asset)), 1e8, "the rest stays in the Asset Safe");
    }

    /// @dev An onboarded ERC-4626 position gets its exit by motion: before it, the emergency role cannot redeem; after
    ///      it, the emergency role redeems and withdraws to the Asset Safe from the Asset Safe's own shares, and
    ///      neither pays nor takes from another account. The deposit stands in for an onboarding motion's operator.
    function test_exit_governance_exits_an_erc4626_position() public enabled {
        Exits memory e = _exits();
        deal(Mainnet.DAI, address(asset), 1_000e18);
        vm.startPrank(address(asset));
        IERC20(Mainnet.DAI).approve(VAULT, 1_000e18);
        uint256 shares = IERC4626Vault(VAULT).deposit(1_000e18, address(asset));
        vm.stopPrank();
        bytes memory redeemAll = abi.encodeCall(IERC4626Vault.redeem, (shares / 2, address(asset), address(asset)));
        _emergencyRefused(VAULT, redeemAll);

        _exitOk(abi.encodeCall(IRoles.scopeTarget, (EMERGENCY, VAULT)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, REDEEM, e.vault, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, WITHDRAW, e.vault, 0)));
        _exitOk(abi.encodeCall(IRoles.scopeFunction, (EMERGENCY, VAULT, APPROVE, e.zero, 0)));

        uint256 before = IERC20(Mainnet.DAI).balanceOf(address(asset));
        _emergencyOk(VAULT, redeemAll);
        _emergencyOk(VAULT, abi.encodeCall(IERC4626Vault.withdraw, (100e18, address(asset), address(asset))));
        assertGt(IERC20(Mainnet.DAI).balanceOf(address(asset)) - before, 599e18, "the Asset Safe gets its DAI back");
        _emergencyRefused(VAULT, abi.encodeCall(IERC4626Vault.redeem, (1, stranger, address(asset))));
        _emergencyRefused(VAULT, abi.encodeCall(IERC4626Vault.redeem, (1, address(asset), stranger)));
        _emergencyRefused(VAULT, abi.encodeCall(IERC4626Vault.withdraw, (1, stranger, address(asset))));
        _emergencyOk(VAULT, abi.encodeCall(IERC20.approve, (stranger, 0)));
        _emergencyRefused(VAULT, abi.encodeCall(IERC20.approve, (stranger, 1)));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// @dev A write of the exit-governance role on the safety modifier, as the universal factory makes it.
    function _exit(bytes memory write) internal returns (bool ok, bytes memory ret) {
        vm.prank(address(uf));
        (ok, ret) = address(safetyMod).call(
            abi.encodeCall(IRoles.execTransactionWithRole, (address(safetyMod), 0, write, CALL, EXIT_GOVERNANCE, true))
        );
    }

    function _exitOk(bytes memory write) internal {
        (bool ok, bytes memory ret) = _exit(write);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @dev Refused by the safety modifier's policy, not by the write that it would make.
    function _exitRefused(bytes memory write) internal {
        (bool ok, bytes memory ret) = _exit(write);
        assertFalse(ok, "the safety modifier must refuse");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    /// @dev A call of the emergency role through the safety modifier.
    function _emergency(address to, bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(address(emergency));
        (ok, ret) = address(safetyMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, CALL, EMERGENCY, true)));
    }

    function _emergencyOk(address to, bytes memory data) internal {
        (bool ok, bytes memory ret) = _emergency(to, data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function _emergencyRefused(address to, bytes memory data) internal {
        (bool ok, bytes memory ret) = _emergency(to, data);
        assertFalse(ok, "the emergency role must be refused");
        assertEq(bytes4(ret), CONDITION_VIOLATION, "the policy refuses it");
    }

    /// @dev The emergency role's own trees on the safety modifier, read from the artifact once: the artifact is large,
    ///      and memory is not freed within a test. Reading it is not metered, as in the enabling vote's helpers.
    function _exits() internal returns (Exits memory e) {
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory calls = _policyCalls(address(safetyMod), address(0));
        for (uint256 i = 0; i < calls.length; i++) {
            if (bytes4(calls[i].data) != IRoles.scopeFunction.selector) continue;
            (bytes32 k, address target, bytes4 s, IRoles.ConditionFlat[] memory c,) =
                abi.decode(_params(calls[i].data), (bytes32, address, bytes4, IRoles.ConditionFlat[], uint8));
            if (k != EMERGENCY) continue;
            if (target == Mainnet.EARN_USD_SHARE && s == TRANSFER) e.toAgent = c;
            else if (target == Mainnet.USDC && s == TRANSFER) e.toAgentOrOrders = c;
            else if (target == Mainnet.SUSDS && s == REDEEM) e.vault = c;
            else if (target == Mainnet.EARN_USD_DEPOSIT_QUEUE && s == CLAIM) e.claim = c;
        }
        vm.resumeGasMetering();
        require(
            e.toAgent.length != 0 && e.toAgentOrOrders.length != 0 && e.vault.length != 0 && e.claim.length != 0,
            "the artifact lacks an exit tree"
        );
        e.zero = _approval(0);
    }

    /// @dev `approve(any spender, amount)`, as the SDK compiles it.
    function _approval(uint256 amount) internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](3);
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, T_STATIC, OP_PASS, "");
        c[2] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(amount));
    }

    /// @dev A one-parameter call pinned to `account`.
    function _pinned(address account) internal pure returns (IRoles.ConditionFlat[] memory c) {
        c = new IRoles.ConditionFlat[](2);
        c[0] = IRoles.ConditionFlat(0, T_CALLDATA, OP_MATCHES, "");
        c[1] = IRoles.ConditionFlat(0, T_STATIC, OP_EQUAL_TO, abi.encode(account));
    }

    /// @dev Calldata without its selector.
    function _params(bytes memory data) internal pure returns (bytes memory p) {
        p = new bytes(data.length - 4);
        for (uint256 i = 0; i < p.length; i++) p[i] = data[i + 4];
    }
}
