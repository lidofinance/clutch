// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {console2} from "forge-std/Test.sol";
import {ISafe} from "../../src/interfaces/ISafe.sol";
import {IRoles} from "../../src/interfaces/IRoles.sol";
import {IERC20} from "../../src/interfaces/Tokens.sol";
import {UniversalFactory} from "../../src/factory/UniversalFactory.sol";
import {Mainnet} from "./Mainnet.sol";
import {VoteBuilder} from "./VoteBuilder.sol";
import {
    RehearsalBase,
    IVoting,
    ITokenManager,
    IFinance,
    IEasyTrack,
    ISafeAdmin,
    IExtensibleFallbackHandler,
    ISettlement
} from "./RehearsalBase.sol";

/// @title EnabledVault — the enabling vote of the enabling-vote spec, run against the live
///        Aragon Voting, Easy Track, Finance and treasury on a mainnet fork, and the motion
///        helpers of the universal factory.
/// @dev The vote registers the universal factory with its address book, pays the first
///      tranche through Finance, and approves the hash of each Safe batch (OD-92, OD-102,
///      OD-106). Figures marked STANDIN are test values, not production figures.
abstract contract EnabledVault is RehearsalBase {
    struct Batch {
        ISafe safe;
        bytes data; // multiSend(bytes) calldata
        bytes32 hash;
        uint256 calls;
        string label;
    }

    Batch[] internal batches;
    address internal proposer;

    /// @dev The sum of the measured gas of the calls in one Safe batch. The
    ///      Safe, MultiSend and calldata overheads come on top, and each
    ///      executed batch is then checked against the cap itself.
    uint256 internal constant BATCH_CALL_GAS_BUDGET = 12_000_000;

    // The first tranche, an item of the enabling vote: STANDIN amounts under the
    // launch cap of one million dollars (ADR 014, decision 2; OD-55).
    uint256 internal constant TRANCHE_USDC = 500_000e6;
    uint256 internal constant TRANCHE_STETH = 100e18;

    // ---------------------------------------------------------------------
    // The enabling vote
    // ---------------------------------------------------------------------

    function _enable() internal {
        _buildBatches();
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory items = _voteItems(false);
        bytes memory voteScript = VoteBuilder.script(items);
        vm.resumeGasMetering();
        console2.log("REHEARSAL vote: items", items.length);
        console2.log("REHEARSAL vote: script bytes", voteScript.length);

        _proposer();
        (bool ok, uint256 gasUsed, bytes memory txData) = _newVote(voteScript);
        assertTrue(ok, "newVote must fit in one transaction");
        console2.log("REHEARSAL vote: newVote gas", gasUsed);
        console2.log("REHEARSAL vote: newVote calldata bytes", txData.length);

        uint256 usdcBefore = IERC20(Mainnet.USDC).balanceOf(address(asset));
        uint256 used = _passAndExecute();
        console2.log("REHEARSAL vote: executeVote gas", used);

        // The first tranche reaches the Asset Safe when the vote executes, before the batches.
        assertEq(IERC20(Mainnet.USDC).balanceOf(address(asset)) - usdcBefore, TRANCHE_USDC, "the first tranche in USDC");
        assertApproxEqAbs(IERC20(Mainnet.STETH).balanceOf(address(asset)), TRANCHE_STETH, 2, "the first tranche in stETH");
        assertFalse(asset.isModuleEnabled(address(opMod)), "no permission applies before the batches");

        for (uint256 i = 0; i < batches.length; i++) _runBatch(batches[i]);
    }

    /// @dev A later tranche: one Aragon vote with one Finance payment (ADR 014, decision 1).
    function _trancheVote(address token, uint256 amount) internal {
        VoteBuilder.Item[] memory items = new VoteBuilder.Item[](1);
        items[0] = _payment(token, amount, "Clutch tranche (rehearsal)");
        if (proposer == address(0)) _proposer();
        (bool ok,,) = _newVote(VoteBuilder.script(items));
        assertTrue(ok, "a tranche vote starts");
        _passAndExecute();
    }

    function _passAndExecute() internal returns (uint256 used) {
        IVoting voting = IVoting(Mainnet.VOTING);
        uint256 id = voting.votesLength() - 1;
        vm.prank(proposer);
        voting.vote(id, true, false);
        vm.warp(block.timestamp + voting.voteTime() + 1);
        assertTrue(voting.canExecute(id), "the vote must pass");
        bytes memory exec = abi.encodeCall(IVoting.executeVote, (id));
        (uint256 std,) = VoteBuilder.intrinsicGas(exec);
        _coolGovernance();
        vm.prank(anyone);
        uint256 g = gasleft();
        (bool done,) = Mainnet.VOTING.call{gas: TX_GAS_CAP - std}(exec);
        used = g - gasleft() + std;
        assertTrue(done, "executeVote must fit in one transaction");
    }

    /// @dev The factory's registration, the first tranche, then one approved hash
    ///      per Safe batch; `direct` carries the batches themselves instead.
    function _voteItems(bool direct) internal view returns (VoteBuilder.Item[] memory items) {
        uint256 first = 3;
        items = new VoteBuilder.Item[](first + batches.length);
        items[0] = VoteBuilder.Item(
            Mainnet.EASY_TRACK,
            abi.encodeCall(IEasyTrack.addEVMScriptFactory, (address(uf), uf.addressBook())),
            "Easy Track: register the universal factory with its address book"
        );
        items[1] = _payment(Mainnet.USDC, TRANCHE_USDC, "Clutch tranche 1 (rehearsal)");
        items[2] = _payment(Mainnet.STETH, TRANCHE_STETH, "Clutch tranche 1 (rehearsal)");
        bytes memory votingSig = abi.encodePacked(bytes32(uint256(uint160(Mainnet.VOTING))), bytes32(0), uint8(1));
        for (uint256 i = 0; i < batches.length; i++) {
            Batch storage b = batches[i];
            items[first + i] = direct
                ? VoteBuilder.Item(
                    address(b.safe),
                    abi.encodeCall(
                        ISafe.execTransaction,
                        (Mainnet.MULTISEND_CALL_ONLY, 0, b.data, 1, 0, 0, 0, address(0), payable(address(0)), votingSig)
                    ),
                    b.label
                )
                : VoteBuilder.Item(address(b.safe), abi.encodeCall(ISafe.approveHash, (b.hash)), b.label);
        }
    }

    function _payment(address token, uint256 amount, string memory ref) internal view returns (VoteBuilder.Item memory) {
        return VoteBuilder.Item(
            Mainnet.FINANCE,
            abi.encodeCall(IFinance.newImmediatePayment, (token, address(asset), amount, ref)),
            "Finance: pay a tranche to the Asset Safe"
        );
    }

    function _checkEnabled() internal view {
        assertTrue(asset.isModuleEnabled(address(opMod)) && asset.isModuleEnabled(address(safetyMod)), "Asset Safe modifiers");
        assertTrue(orders.isModuleEnabled(address(ordersMod)), "orders modifier");
        assertTrue(firstLoss.isModuleEnabled(address(firstLossMod)), "first-loss modifier");
        IEasyTrack et = IEasyTrack(Mainnet.EASY_TRACK);
        assertTrue(et.isEVMScriptFactory(address(uf)), "the universal factory");
        assertEq(et.evmScriptFactoryPermissions(address(uf)), uf.addressBook(), "its permissions are its address book");
        bytes32 domain = ISettlement(Mainnet.COW_SETTLEMENT).domainSeparator();
        assertEq(
            IExtensibleFallbackHandler(Mainnet.COW_FALLBACK_HANDLER).domainVerifiers(address(orders), domain),
            Mainnet.COMPOSABLE_COW,
            "domain verifier"
        );
        assertEq(IERC20(Mainnet.USDC).allowance(address(orders), Mainnet.COW_VAULT_RELAYER), type(uint256).max, "relayer approval");
    }

    // ---------------------------------------------------------------------
    // The Safe batches
    // ---------------------------------------------------------------------

    function _buildBatches() internal {
        vm.pauseGasMetering();
        VoteBuilder.Item[] memory calls = _assetCalls();
        vm.resumeGasMetering();
        uint256[] memory gasOf = _measure(calls, address(asset));
        vm.pauseGasMetering();
        uint256 total;
        for (uint256 i = 0; i < gasOf.length; i++) total += gasOf[i];
        console2.log("REHEARSAL Asset Safe policy: calls", calls.length);
        console2.log("REHEARSAL Asset Safe policy: gas of the calls, each cold", total);

        uint256 start;
        uint256 sum;
        for (uint256 i = 0; i < calls.length; i++) {
            if (sum + gasOf[i] > BATCH_CALL_GAS_BUDGET && i > start) {
                _addBatch(asset, calls, start, i, "Asset Safe: approve a policy batch");
                start = i;
                sum = 0;
            }
            sum += gasOf[i];
        }
        _addBatch(asset, calls, start, calls.length, "Asset Safe: approve a policy batch");
        VoteBuilder.Item[] memory o = _ordersCalls();
        _addBatch(orders, o, 0, o.length, "Orders account: approve its setup batch");
        VoteBuilder.Item[] memory f = _firstLossCalls();
        _addBatch(firstLoss, f, 0, f.length, "First-loss Safe: approve its setup batch");
        vm.resumeGasMetering();
        console2.log("REHEARSAL Safe batches", batches.length);
    }

    function _addBatch(ISafe safe, VoteBuilder.Item[] memory calls, uint256 from, uint256 to, string memory label)
        internal
    {
        VoteBuilder.Item[] memory part = new VoteBuilder.Item[](to - from);
        for (uint256 i = from; i < to; i++) part[i - from] = calls[i];
        bytes memory data = VoteBuilder.multiSend(part);
        uint256 nonce = safe.nonce();
        for (uint256 i = 0; i < batches.length; i++) if (batches[i].safe == safe) nonce++;
        bytes32 hash = safe.getTransactionHash(
            Mainnet.MULTISEND_CALL_ONLY, 0, data, 1, 0, 0, 0, address(0), address(0), nonce
        );
        batches.push(Batch({safe: safe, data: data, hash: hash, calls: to - from, label: label}));
    }

    function _assetCalls() internal view returns (VoteBuilder.Item[] memory calls) {
        string memory j = vm.readFile(ARTIFACT);
        address[] memory to = vm.parseJsonAddressArray(j, ".calls.to");
        bytes[] memory data = vm.parseJsonBytesArray(j, ".calls.data");
        calls = new VoteBuilder.Item[](to.length + 2);
        calls[0] = VoteBuilder.Item(address(asset), abi.encodeCall(ISafe.enableModule, (address(opMod))), "");
        calls[1] = VoteBuilder.Item(address(asset), abi.encodeCall(ISafe.enableModule, (address(safetyMod))), "");
        for (uint256 i = 0; i < to.length; i++) calls[i + 2] = VoteBuilder.Item(to[i], data[i], "");
    }

    /// @dev ADR 007: CoW's fallback handler, ComposableCoW as the settlement
    ///      domain's verifier, the orders modifier with its two roles, and the
    ///      relayer approvals for the operator's order tokens; LDO left the
    ///      launch list (OD-91). The orders policy itself is not built yet.
    function _ordersCalls() internal view returns (VoteBuilder.Item[] memory c) {
        address[6] memory tokens =
            [Mainnet.STETH, Mainnet.WSTETH, Mainnet.WETH, Mainnet.USDC, Mainnet.USDT, Mainnet.USDS];
        bytes32 domain = ISettlement(Mainnet.COW_SETTLEMENT).domainSeparator();
        c = new VoteBuilder.Item[](5 + tokens.length);
        c[0] = VoteBuilder.Item(address(orders), abi.encodeCall(ISafeAdmin.setFallbackHandler, (Mainnet.COW_FALLBACK_HANDLER)), "");
        c[1] = VoteBuilder.Item(
            address(orders), abi.encodeCall(IExtensibleFallbackHandler.setDomainVerifier, (domain, Mainnet.COMPOSABLE_COW)), ""
        );
        c[2] = VoteBuilder.Item(address(orders), abi.encodeCall(ISafe.enableModule, (address(ordersMod))), "");
        c[3] = VoteBuilder.Item(address(ordersMod), _assign(Mainnet.COMMITTEE_SAFE, OPERATOR), "");
        c[4] = VoteBuilder.Item(address(ordersMod), _assign(address(emergency), EMERGENCY), "");
        for (uint256 i = 0; i < tokens.length; i++) {
            c[5 + i] = VoteBuilder.Item(tokens[i], abi.encodeCall(IERC20.approve, (Mainnet.COW_VAULT_RELAYER, type(uint256).max)), "");
        }
    }

    /// @dev ADR 008: the first-loss modifier and its two roles. Its policy is not built yet.
    function _firstLossCalls() internal view returns (VoteBuilder.Item[] memory c) {
        c = new VoteBuilder.Item[](3);
        c[0] = VoteBuilder.Item(address(firstLoss), abi.encodeCall(ISafe.enableModule, (address(firstLossMod))), "");
        c[1] = VoteBuilder.Item(address(firstLossMod), _assign(Mainnet.COMMITTEE_SAFE, FIRST_LOSS), "");
        c[2] = VoteBuilder.Item(address(firstLossMod), _assign(Mainnet.ET_EXECUTOR, FIRST_LOSS_BURN), "");
    }

    function _assign(address member, bytes32 key) internal pure returns (bytes memory) {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = key;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        return abi.encodeCall(IRoles.assignRoles, (member, keys, yes));
    }

    /// @dev The gas of each call on its own, with cold accounts, applied in
    ///      order and then rolled back.
    function _measure(VoteBuilder.Item[] memory calls, address from) internal returns (uint256[] memory gasOf) {
        uint256 snap = vm.snapshotState();
        gasOf = new uint256[](calls.length);
        address[] memory touched = new address[](3);
        touched[0] = address(asset);
        touched[1] = address(opMod);
        touched[2] = address(safetyMod);
        for (uint256 i = 0; i < calls.length; i++) {
            _cold(touched);
            vm.prank(from);
            uint256 g = gasleft();
            (bool ok,) = calls[i].to.call(calls[i].data);
            gasOf[i] = g - gasleft();
            require(ok, "measure: a policy call failed");
        }
        vm.revertToState(snap);
    }

    function _runBatch(Batch storage b) internal {
        vm.pauseGasMetering();
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(Mainnet.VOTING))), bytes32(0), uint8(1));
        bytes memory txData = abi.encodeCall(
            ISafe.execTransaction,
            (Mainnet.MULTISEND_CALL_ONLY, 0, b.data, 1, 0, 0, 0, address(0), payable(address(0)), sig)
        );
        (uint256 std, uint256 floor) = VoteBuilder.intrinsicGas(txData);
        vm.resumeGasMetering();
        uint256 intrinsic = std > floor ? std : floor;
        address[] memory touched = new address[](6);
        touched[0] = address(b.safe);
        touched[1] = Mainnet.MULTISEND_CALL_ONLY;
        touched[2] = address(opMod);
        touched[3] = address(safetyMod);
        touched[4] = address(ordersMod);
        touched[5] = address(firstLossMod);
        _cold(touched);
        vm.prank(anyone);
        uint256 g = gasleft();
        (bool ok, bytes memory ret) = address(b.safe).call{gas: TX_GAS_CAP - intrinsic}(txData);
        uint256 used = g - gasleft() + std;
        assertTrue(ok && abi.decode(ret, (bool)), string.concat("batch failed: ", b.label));
        console2.log(string.concat("REHEARSAL batch gas (", vm.toString(b.calls), " calls), calldata bytes"), used, txData.length);
        assertLe(used, TX_GAS_CAP, "a batch must fit in one transaction");
        assertLe(txData.length, TX_SIZE_LIMIT, "a batch must fit in the txpool's size limit");
    }

    // ---------------------------------------------------------------------
    // Creating and running a vote
    // ---------------------------------------------------------------------

    /// @dev An LDO holder above the quorum, funded from the treasury on the fork only.
    function _proposer() internal {
        proposer = makeAddr("ldo-proposer");
        vm.prank(Mainnet.AGENT);
        IERC20(Mainnet.LDO).transfer(proposer, 60_000_000e18);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function _newVote(bytes memory voteScript) internal returns (bool ok, uint256 gasUsed, bytes memory txData) {
        VoteBuilder.Item[] memory fwd = new VoteBuilder.Item[](1);
        fwd[0] = VoteBuilder.Item(
            Mainnet.VOTING, abi.encodeWithSignature("newVote(bytes,string)", voteScript, "Clutch enabling vote, rehearsal"), ""
        );
        vm.pauseGasMetering();
        txData = abi.encodeCall(ITokenManager.forward, (VoteBuilder.script(fwd)));
        (uint256 std, uint256 floor) = VoteBuilder.intrinsicGas(txData);
        vm.resumeGasMetering();
        uint256 intrinsic = std > floor ? std : floor;
        if (intrinsic >= TX_GAS_CAP) return (false, intrinsic, txData);
        _coolGovernance();
        vm.prank(proposer);
        uint256 g = gasleft();
        (ok,) = Mainnet.TOKEN_MANAGER.call{gas: TX_GAS_CAP - intrinsic}(txData);
        gasUsed = g - gasleft() + std;
    }

    function _coolGovernance() internal {
        address[] memory a = new address[](4);
        a[0] = Mainnet.VOTING;
        a[1] = Mainnet.TOKEN_MANAGER;
        a[2] = Mainnet.LDO;
        a[3] = Mainnet.EASY_TRACK;
        _cold(a);
    }

    // ---------------------------------------------------------------------
    // Motions of the universal factory
    // ---------------------------------------------------------------------

    function _op(uint8 kind, bytes memory data) internal pure returns (UniversalFactory.Op memory) {
        return UniversalFactory.Op(kind, data);
    }

    function _one(UniversalFactory.Op memory op) internal pure returns (UniversalFactory.Op[] memory ops) {
        ops = new UniversalFactory.Op[](1);
        ops[0] = op;
    }

    /// @dev A motion's calldata: the counter that the motion saw, and its operations.
    function _calldata(UniversalFactory.Op[] memory ops) internal view returns (bytes memory) {
        return abi.encode(uf.epoch(), ops);
    }

    function _create(bytes memory cd) internal returns (uint256 id) {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        id = IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(uf), cd);
    }

    function _afterWindow() internal {
        vm.warp(block.timestamp + IEasyTrack(Mainnet.EASY_TRACK).motionDuration() + 1);
    }

    function _enact(uint256 id, bytes memory cd) internal {
        vm.prank(anyone);
        IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id, cd);
    }

    /// @dev Creates a motion, waits out its objection window and enacts it.
    function _motion(UniversalFactory.Op[] memory ops) internal returns (uint256 id) {
        bytes memory cd = _calldata(ops);
        id = _create(cd);
        _afterWindow();
        _enact(id, cd);
    }

    function _approvalsOp(address token, UniversalFactory.Entry[] memory current, UniversalFactory.Entry[] memory next)
        internal
        view
        returns (UniversalFactory.Op memory)
    {
        return _op(uf.APPROVALS(), abi.encode(token, current, next));
    }

    function _budgetOp(address token, address spender, uint128 perMonth, bytes32 expected)
        internal
        view
        returns (UniversalFactory.Op memory)
    {
        return _op(uf.BUDGET(), abi.encode(token, spender, perMonth, perMonth, perMonth, MONTH, expected));
    }

    function _ceilingOp(bytes32 key, uint256 expected, uint256 value) internal view returns (UniversalFactory.Op memory) {
        return _op(uf.CEILING(), abi.encode(key, expected, value));
    }

    /// @dev A token's introduction: its first approval list and both of its ceilings
    ///      (ADR 013, decision 15).
    function _introduceOp(
        address token,
        UniversalFactory.Entry[] memory list,
        uint256 budgetCeiling,
        uint256 approvalCeiling
    ) internal view returns (UniversalFactory.Op memory) {
        return _op(uf.INTRODUCE(), abi.encode(token, list, budgetCeiling, approvalCeiling));
    }

    // ---------------------------------------------------------------------
    // The vault's roles
    // ---------------------------------------------------------------------

    function _moveFirstLossShare(address share, string memory name) internal {
        uint256 bal = IERC20(share).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE);
        vm.prank(Mainnet.GROWTH_COMMITTEE_SAFE);
        (bool ok, bytes memory ret) = share.call(abi.encodeCall(IERC20.transfer, (address(firstLoss), bal)));
        console2.log(string.concat("REHEARSAL first-loss ", name, ": balance, moved (1 = yes)"), bal, ok ? 1 : 0);
        if (!ok) console2.logBytes(ret);
    }

    function _operator(address to, bytes memory data, bool expectOk) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE);
        (bool ok,) = address(opMod).call(abi.encodeCall(IRoles.execTransactionWithRole, (to, 0, data, 0, OPERATOR, true)));
        assertEq(ok, expectOk, "operator call outcome");
    }

    /// @dev The switch runbook: the emergency Safe disables the operator modifier,
    ///      then raises the factory's counter, so that no queued motion enacts.
    function _emergencySwitch() internal {
        (address[] memory mods,) = asset.getModulesPaginated(address(0x1), 10);
        address prev = address(0x1);
        for (uint256 i = 0; i < mods.length; i++) {
            if (mods[i] == address(opMod)) break;
            prev = mods[i];
        }
        vm.prank(address(emergency));
        safetyMod.execTransactionWithRole(
            address(asset), 0, abi.encodeCall(ISafe.disableModule, (prev, address(opMod))), 0, EMERGENCY, true
        );
        assertFalse(asset.isModuleEnabled(address(opMod)), "the switch is off");
        vm.prank(address(emergency));
        uf.raiseCounter();
    }
}
