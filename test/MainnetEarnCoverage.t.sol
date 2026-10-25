// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {ClutchFixture} from "./utils/Fixture.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IERC20, IStETH, IWstETH, ILidoEarnDepositQueue, ILidoEarnRedeemQueue} from "../src/interfaces/Tokens.sol";
import {SafeExec} from "../src/exec/SafeExec.sol";

interface IEarnDeposit {
    function vault() external view returns (address);
    function asset() external view returns (address);
    function requestOf(address) external view returns (uint256, uint256);
    function claimableOf(address) external view returns (uint256);
    function unclaimedRequests() external view returns (uint256);
}
interface IEarnVault {
    function shareManager() external view returns (address);
    function riskManager() external view returns (address);
    function feeManager() external view returns (address);
    function oracle() external view returns (address);
    function hasQueue(address) external view returns (bool);
    function isDepositQueue(address) external view returns (bool);
    function isPausedQueue(address) external view returns (bool);
    function setQueueStatus(address, bool) external;
    function hasRole(bytes32, address) external view returns (bool);
    function getRoleMember(bytes32, uint256) external view returns (address);
    function grantRole(bytes32, address) external;
    function getLiquidAssets() external view returns (uint256);
    function getHook(address) external view returns (address);
    function setCustomHook(address, address) external;
    function setDefaultRedeemHook(address) external;
}
interface IEarnShares {
    struct Flags { bool mintPause; bool burnPause; bool transferPause; bool whitelist; bool transferWhitelist; uint32 lockup; }
    function flags() external view returns (Flags memory);
    function setFlags(Flags calldata) external;
    function setWhitelistMerkleRoot(bytes32) external;
    struct AccountInfo { bool canDeposit; bool canTransfer; bool blacklisted; }
    function setAccountInfo(address, AccountInfo calldata) external;
    function accounts(address) external view returns (AccountInfo memory);
    function whitelistMerkleRoot() external view returns (bytes32);
    function activeSharesOf(address) external view returns (uint256);
    function allocatedShares() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function isDepositorWhitelisted(address, bytes32[] calldata) external view returns (bool);
}
interface IEarnRisk {
    function pendingAssets(address) external view returns (int256);
    function pendingShares(address) external view returns (int256);
    function pendingBalance() external view returns (int256);
    function vaultState() external view returns (int256 balance, int256 limit);
    function setVaultLimit(int256) external;
}
interface IEarnFee {
    function depositFeeD6() external view returns (uint256);
    function redeemFeeD6() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function setFeeRecipient(address) external;
    function owner() external view returns (address);
    function performanceFeeD6() external view returns (uint256);
    function protocolFeeD6() external view returns (uint256);
    function setFees(uint24,uint24,uint24,uint24) external;
}
interface IEarnOracle {
    struct Params { uint224 maxAbs; uint224 suspiciousAbs; uint64 maxRel; uint64 suspiciousRel; uint32 timeout; uint32 depositInterval; uint32 redeemInterval; }
    struct Report { address asset; uint224 priceD18; }
    struct DetailedReport { uint224 priceD18; uint32 timestamp; bool suspicious; }
    function getReport(address) external view returns (DetailedReport memory);
    function securityParams() external view returns (Params memory);
    function submitReports(Report[] calldata) external;
}

interface IERC20Blacklist {
    function blacklister() external view returns (address);
    function isBlacklisted(address) external view returns (bool);
    function blacklist(address) external;
    function unBlacklist(address) external;
}
interface IEarnRedeem {
    struct Request { uint256 timestamp; uint256 shares; bool claimable; uint256 assets; }
    function requestsOf(address,uint256,uint256) external view returns (Request[] memory);
    function getState() external view returns (uint256 iterator, uint256 batches, uint256 demand, uint256 pending);
    function batchAt(uint256) external view returns (uint256 assets,uint256 shares);
    function handleBatches(uint256) external returns (uint256);
}

/// @dev ADR 011 asynchronous deposits; real queues, reports and hooks under the legacy-key fixture.
contract MainnetEarnCoverageTest is ClutchFixture {
    bytes4 internal constant CONDITION = bytes4(keccak256("ConditionViolation(uint8,bytes32)"));
    bytes4 internal constant FAILED = bytes4(keccak256("ModuleTransactionFailed()"));
    struct Venue { address queue; address token; address shares; IEarnVault vault; IEarnOracle oracle; bytes32 key; uint224 amount; }
    struct State { uint256 assets; uint256 queued; uint256 active; uint256 allocated; uint256 total; uint256 allowance; uint256 timestamp; uint256 request; uint256 count; int256 pending; bytes32 budget; }
    function setUp() public override {
        super.setUp(); deal(a.usdc, address(safe), 1000e6); vm.deal(address(safe), 1 ether);
        execute(false, a.steth, 1 ether, abi.encodeCall(IStETH.submit, (address(0))));
        uint256 st = IERC20(a.steth).balanceOf(address(safe));
        execute(false, a.steth, 0, abi.encodeCall(IERC20.approve, (a.wsteth, st)));
        execute(false, a.wsteth, 0, abi.encodeCall(IWstETH.wrap, (st)));
    }
    function venue(bool eth) internal view returns (Venue memory v) {
        v.queue = eth ? a.earnEthDepositQueue : a.earnUsdDepositQueue; v.token = eth ? a.wsteth : a.usdc;
        v.shares = eth ? a.earnEthShare : a.earnUsdShare; v.key = eth ? K_EARN_ETH : K_EARN_USD;
        v.amount = eth ? uint224(1e17) : uint224(100e6); v.vault = IEarnVault(IEarnDeposit(v.queue).vault()); v.oracle = IEarnOracle(v.vault.oracle());
        assertEq(IEarnDeposit(v.queue).asset(), v.token); assertEq(v.vault.shareManager(), v.shares);
        assertTrue(v.vault.hasQueue(v.queue)); assertTrue(v.vault.isDepositQueue(v.queue));
    }
    function keyState(bytes32 key) internal view returns (bytes32) {
        (uint128 r, uint128 m, uint64 p, uint128 b, uint64 t) = roles.allowances(key); return keccak256(abi.encode(r,m,p,b,t));
    }
    function state(Venue memory v) internal view returns (State memory s) {
        s.assets = IERC20(v.token).balanceOf(address(safe)); s.queued = IERC20(v.token).balanceOf(v.queue);
        s.active = IEarnShares(v.shares).activeSharesOf(address(safe)); s.allocated = IEarnShares(v.shares).allocatedShares(); s.total = IEarnShares(v.shares).totalShares();
        s.allowance = IERC20(v.token).allowance(address(safe), v.queue); (s.timestamp,s.request) = IEarnDeposit(v.queue).requestOf(address(safe));
        s.count = IEarnDeposit(v.queue).unclaimedRequests(); s.pending = IEarnRisk(v.vault.riskManager()).pendingAssets(v.token); s.budget = keyState(v.key);
    }
    function execute(bool emergency, address target, uint256 value, bytes memory data) internal {
        vm.prank(emergency ? emergencySafe : operatorSafe);
        assertTrue((emergency ? safety : roles).execTransactionWithRole(target,value,data,0,emergency ? EMERGENCY : OPERATOR,true));
    }
    function refused(Venue memory v, bool emergency, bytes memory data, bytes4 error_) internal {
        bytes32 before = keccak256(abi.encode(state(v))); vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok, bytes memory reason) = address(emergency ? safety : roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (v.queue,0,data,0,emergency ? EMERGENCY : OPERATOR,true)));
        assertFalse(ok); assertEq(bytes4(reason),error_); assertEq(keccak256(abi.encode(state(v))),before);
    }
    function protocolRefused(Venue memory v, bytes memory data, string memory signature) internal {
        bytes32 before=keccak256(abi.encode(state(v))); vm.prank(address(safe));
        (bool ok,bytes memory reason)=v.queue.call(data); assertFalse(ok); assertEq(bytes4(reason),bytes4(keccak256(bytes(signature))));
        assertEq(keccak256(abi.encode(state(v))),before);
    }
    function forkGrant(Venue memory v, bytes32 role) internal returns (address admin) {
        admin=v.vault.getRoleMember(bytes32(0),0); assertTrue(v.vault.hasRole(bytes32(0),admin));
        // Controlled fork precondition through the real default admin; no live grant.
        vm.prank(admin); v.vault.grantRole(role,admin); assertTrue(v.vault.hasRole(role,admin));
    }
    function approve(Venue memory v) internal {
        (,,,uint128 before,) = roles.allowances(v.key); bytes32 other = keyState(v.key == K_EARN_ETH ? K_EARN_USD : K_EARN_ETH);
        execute(false,v.token,0,abi.encodeCall(IERC20.approve,(v.queue,uint256(v.amount))));
        (,,,uint128 after_,) = roles.allowances(v.key); assertEq(after_,before-v.amount);
        assertEq(keyState(v.key == K_EARN_ETH ? K_EARN_USD : K_EARN_ETH),other);
    }
    function depositData(uint224 amount, address referral, bytes32[] memory proof) internal pure returns (bytes memory) {
        return abi.encodeCall(ILidoEarnDepositQueue.deposit,(amount,referral,proof));
    }
    function deposit(Venue memory v) internal {
        State memory before = state(v); execute(false,v.queue,0,depositData(v.amount,address(0),new bytes32[](0))); State memory after_ = state(v);
        assertEq(after_.assets,before.assets-v.amount); assertEq(after_.queued,before.queued+v.amount); assertEq(after_.request,v.amount);
        assertEq(after_.timestamp,block.timestamp); assertEq(after_.count,before.count+1); assertEq(after_.pending,before.pending+int256(uint256(v.amount)));
        assertEq(after_.allowance,before.allowance-v.amount); assertEq(after_.budget,before.budget); assertEq(after_.active,before.active); assertEq(after_.total,before.total);
    }
    function cancel(Venue memory v, bool emergency) internal {
        State memory before = state(v); execute(emergency,v.queue,0,abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest,())); State memory after_ = state(v);
        assertEq(after_.assets,before.assets+before.request); assertEq(after_.queued,before.queued-before.request); assertEq(after_.request,0); assertEq(after_.timestamp,0);
        assertEq(after_.count,before.count-1); assertEq(after_.pending,before.pending-int256(before.request)); assertEq(after_.budget,before.budget);
        assertEq(after_.active,before.active); assertEq(after_.total,before.total); assertEq(after_.allowance,before.allowance);
    }
    function submit(Venue memory v, bool eligible) internal returns (uint256 expectedShares) {
        IEarnOracle.DetailedReport memory old = v.oracle.getReport(v.token); assertFalse(old.suspicious); assertGt(old.priceD18,0);
        IEarnOracle.Params memory p = v.oracle.securityParams(); uint256 target = old.timestamp + p.timeout + 1;
        uint256 age = block.timestamp + (eligible ? p.depositInterval + 1 : 1); if (target < age) target = age;
        vm.warp(target); (uint256 requested,) = IEarnDeposit(v.queue).requestOf(address(safe));
        if (!eligible) assertLt(target-p.depositInterval,requested,"Pinned report must allow an early report");
        bytes32 role = keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"); address holder = v.vault.getRoleMember(role,0); assertTrue(v.vault.hasRole(role,holder));
        IEarnOracle.Report[] memory reports = new IEarnOracle.Report[](1); reports[0] = IEarnOracle.Report(v.token,old.priceD18);
        vm.prank(holder); v.oracle.submitReports(reports);
        uint256 feePrice = uint256(old.priceD18)*IEarnFee(v.vault.feeManager()).depositFeeD6()/1e6;
        expectedShares = uint256(v.amount)*(uint256(old.priceD18)-feePrice)/1e18;
        assertEq(IEarnDeposit(v.queue).claimableOf(address(safe)),eligible ? expectedShares : 0);
    }
    function claim(Venue memory v, bool emergency, uint256 expected) internal {
        State memory before = state(v); execute(emergency,v.queue,0,abi.encodeCall(ILidoEarnDepositQueue.claim,(address(safe)))); State memory after_ = state(v);
        assertEq(after_.active,before.active+expected); assertEq(after_.allocated,before.allocated-expected); assertEq(after_.total,before.total);
        assertEq(after_.request,0); assertEq(after_.timestamp,0); assertEq(after_.count,before.count-1); assertEq(after_.assets,before.assets); assertEq(after_.queued,before.queued);
        assertEq(after_.budget,before.budget); assertEq(after_.pending,before.pending); assertEq(IEarnDeposit(v.queue).claimableOf(address(safe)),0);
        assertEq(IEarnShares(v.shares).activeSharesOf(attacker),0);
    }
    function test_MAIN06_both_venues_exact_request_duplicate_early_claim_both_cancellers_and_no_refund() public {
        for (uint256 asset;asset<2;++asset) for (uint256 role;role<2;++role) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); assertTrue(IEarnShares(v.shares).isDepositorWhitelisted(address(safe),new bytes32[](0)));
            approve(v); deposit(v); refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED);
            protocolRefused(v,depositData(v.amount,address(0),new bytes32[](0)),"PendingRequestExists()");
            bytes32 before=keccak256(abi.encode(state(v))); execute(role==1,v.queue,0,abi.encodeCall(ILidoEarnDepositQueue.claim,(address(safe)))); assertEq(keccak256(abi.encode(state(v))),before);
            cancel(v,role==1); refused(v,role==1,abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest,()),FAILED);
            protocolRefused(v,abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest,()),"NoPendingRequest()");
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_real_oracle_early_eligible_reports_both_claimers_and_no_double_claim() public {
        for (uint256 asset;asset<2;++asset) for (uint256 role;role<2;++role) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1);
            IEarnOracle.Params memory timing=v.oracle.securityParams(); IEarnOracle.DetailedReport memory old=v.oracle.getReport(v.token);
            uint256 nextReport=uint256(old.timestamp)+timing.timeout+1;
            assertGt(nextReport,block.timestamp+timing.depositInterval);
            vm.warp(nextReport-timing.depositInterval+1); approve(v); deposit(v); submit(v,false);
            uint256 expected=submit(v,true); refused(v,role==1,abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest,()),FAILED);
            protocolRefused(v,abi.encodeCall(ILidoEarnDepositQueue.cancelDepositRequest,()),"ClaimableRequestExists()"); claim(v,role==1,expected);
            bytes32 before=keccak256(abi.encode(state(v))); execute(role==1,v.queue,0,abi.encodeCall(ILidoEarnDepositQueue.claim,(address(safe)))); assertEq(keccak256(abi.encode(state(v))),before);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_new_deposit_auto_claims_priced_request_referral_and_open_root_proof() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); approve(v); deposit(v); uint256 expected=submit(v,true); approve(v);
            State memory before=state(v); bytes32[] memory proof=new bytes32[](1); proof[0]=bytes32(uint256(1)); assertEq(IEarnShares(v.shares).whitelistMerkleRoot(),bytes32(0));
            execute(false,v.queue,0,depositData(v.amount,attacker,proof)); State memory after_=state(v);
            assertEq(after_.active,before.active+expected); assertEq(after_.request,v.amount); assertEq(after_.timestamp,block.timestamp); assertEq(after_.count,before.count);
            assertEq(after_.assets,before.assets-v.amount); assertEq(after_.queued,before.queued+v.amount); assertEq(after_.budget,before.budget);
            assertEq(IERC20(v.token).balanceOf(attacker),0); cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_real_pause_cancel_retry_and_whitelist_flag_restoration() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); approve(v); deposit(v);
            address holder=v.vault.getRoleMember(keccak256("modules.ShareModule.SET_QUEUE_STATUS_ROLE"),0);
            vm.prank(holder); v.vault.setQueueStatus(v.queue,true); assertTrue(v.vault.isPausedQueue(v.queue));
            refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED);
            protocolRefused(v,depositData(v.amount,address(0),new bytes32[](0)),"QueuePaused()"); cancel(v,true);
            vm.prank(holder); v.vault.setQueueStatus(v.queue,false); approve(v); deposit(v); cancel(v,false);
            IEarnShares.Flags memory original=IEarnShares(v.shares).flags(); IEarnShares.Flags memory restricted=IEarnShares(v.shares).flags(); restricted.whitelist=true;
            holder=v.vault.getRoleMember(keccak256("managers.ShareManager.SET_FLAGS_ROLE"),0); vm.prank(holder); IEarnShares(v.shares).setFlags(restricted);
            assertFalse(IEarnShares(v.shares).isDepositorWhitelisted(address(safe),new bytes32[](0))); approve(v); refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED);
            protocolRefused(v,depositData(v.amount,address(0),new bytes32[](0)),"DepositNotAllowed()");
            vm.prank(holder); IEarnShares(v.shares).setFlags(original); deposit(v); cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_zero_missing_approval_balance_failure_and_policy_receiver_pins() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1);
            refused(v,false,depositData(0,address(0),new bytes32[](0)),FAILED);
            protocolRefused(v,depositData(0,address(0),new bytes32[](0)),"ZeroValue()"); refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED);
            approve(v); uint256 funds=IERC20(v.token).balanceOf(address(safe)); deal(v.token,address(safe),uint256(v.amount)-1);
            refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED); deal(v.token,address(safe),funds); deposit(v);
            refused(v,true,depositData(v.amount,address(0),new bytes32[](0)),CONDITION);
            for (uint256 role;role<2;++role) refused(v,role==1,abi.encodeCall(ILidoEarnDepositQueue.claim,(attacker)),CONDITION);
            cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_stopped_operator_emergency_cancel_or_claim_owner_restart() public {
        for (uint256 asset;asset<2;++asset) for (uint256 priced;priced<2;++priced) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); approve(v); deposit(v); uint256 expected;
            if (priced==1) expected=submit(v,true);
            (address[] memory modules,)=safe.getModulesPaginated(SENTINEL,10); address previous=SENTINEL;
            for (uint256 i;i<modules.length && modules[i]!=address(roles);++i) previous=modules[i];
            execute(true,address(safe),0,abi.encodeCall(ISafe.disableModule,(previous,address(roles))));
            bytes32 before=keccak256(abi.encode(state(v))); vm.prank(operatorSafe); vm.expectRevert("GS104");
            roles.execTransactionWithRole(v.queue,0,abi.encodeCall(ILidoEarnDepositQueue.claim,(address(safe))),0,OPERATOR,true); assertEq(keccak256(abi.encode(state(v))),before);
            if (priced==1) claim(v,true,expected); else cancel(v,true);
            assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles)));
            vm.startPrank(principal); SafeExec.execAsOwner(agent,safe,address(safe),abi.encodeCall(ISafe.enableModule,(address(roles)))); vm.stopPrank();
            approve(v); deposit(v); cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_merkle_proof_and_account_permission_are_independent() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1);
            address admin=forkGrant(v,keccak256("managers.ShareManager.SET_WHITELIST_MERKLE_ROOT_ROLE"));
            forkGrant(v,keccak256("managers.ShareManager.SET_ACCOUNT_INFO_ROLE"));
            bytes32 leaf=keccak256(abi.encodePacked(keccak256(abi.encode(address(safe)))));
            bytes32 sibling=keccak256(abi.encodePacked(keccak256(abi.encode(attacker))));
            bytes32 root=leaf<sibling ? keccak256(abi.encodePacked(leaf,sibling)) : keccak256(abi.encodePacked(sibling,leaf));
            vm.prank(admin); IEarnShares(v.shares).setWhitelistMerkleRoot(root); approve(v);
            protocolRefused(v,depositData(v.amount,address(0),new bytes32[](0)),"DepositNotAllowed()");
            bytes32[] memory proof=new bytes32[](1); proof[0]=sibling;
            assertTrue(IEarnShares(v.shares).isDepositorWhitelisted(address(safe),proof));
            IEarnShares.Flags memory f=IEarnShares(v.shares).flags(); f.whitelist=true;
            address flagsHolder=v.vault.getRoleMember(keccak256("managers.ShareManager.SET_FLAGS_ROLE"),0);
            vm.prank(flagsHolder); IEarnShares(v.shares).setFlags(f);
            protocolRefused(v,depositData(v.amount,address(0),proof),"DepositNotAllowed()");
            vm.prank(admin); IEarnShares(v.shares).setAccountInfo(address(safe),IEarnShares.AccountInfo(true,false,false));
            proof[0]=bytes32(uint256(1)); protocolRefused(v,depositData(v.amount,address(0),proof),"DepositNotAllowed()");
            proof[0]=sibling; State memory before=state(v); execute(false,v.queue,0,depositData(v.amount,address(0),proof));
            assertEq(state(v).assets,before.assets-v.amount); assertEq(state(v).request,v.amount); assertEq(state(v).budget,before.budget);
            cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN06_both_venues_vault_cap_exact_boundary_and_one_share_below_rolls_back() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); approve(v);
            IEarnRisk risk=IEarnRisk(v.vault.riskManager()); (int256 balance,)=risk.vaultState();
            int256 pending=risk.pendingAssets(v.token)+int256(uint256(v.amount)); assertGe(pending,0);
            uint256 price=v.oracle.getReport(v.token).priceD18;
            int256 target=balance+risk.pendingBalance()+int256(uint256(pending)*price/1e18)-risk.pendingShares(v.token);
            address admin=forkGrant(v,keccak256("managers.RiskManager.SET_VAULT_LIMIT_ROLE"));
            vm.prank(admin); risk.setVaultLimit(target-1);
            refused(v,false,depositData(v.amount,address(0),new bytes32[](0)),FAILED);
            protocolRefused(v,depositData(v.amount,address(0),new bytes32[](0)),"LimitExceeded(int256,int256)");
            vm.prank(admin); risk.setVaultLimit(target); deposit(v); cancel(v,true); assertTrue(vm.revertToState(snap));
        }
    }

    function redeemQueue(Venue memory v) internal view returns (address q) {
        q=v.token==a.wsteth ? a.earnEthRedeemQueue : a.earnUsdRedeemQueue;
        assertTrue(v.vault.hasQueue(q)); assertFalse(v.vault.isDepositQueue(q));
        assertEq(IEarnDeposit(q).asset(),v.token); assertEq(IEarnDeposit(q).vault(),address(v.vault));
    }
    function position(Venue memory v) internal returns (uint256 shares) {
        approve(v); deposit(v); shares=submit(v,true); claim(v,false,shares);
    }
    function redemptionState(Venue memory v) internal view returns (bytes32) {
        address q=redeemQueue(v); (uint256 i,uint256 b,uint256 d,uint256 p)=IEarnRedeem(q).getState();
        return keccak256(abi.encode(state(v),i,b,d,p,IEarnRedeem(q).requestsOf(address(safe),0,20),
            IERC20(v.token).balanceOf(q),IERC20(v.shares).balanceOf(v.shares)));
    }
    function redeemRefused(Venue memory v,bool emergency,uint256 value,bytes memory data,uint8 operation,bytes4 error_) internal {
        bytes32 before=redemptionState(v); address q=redeemQueue(v); vm.prank(emergency ? emergencySafe : operatorSafe);
        (bool ok,bytes memory reason)=address(emergency ? safety : roles).call(abi.encodeCall(IRoles.execTransactionWithRole,
            (q,value,data,operation,emergency ? EMERGENCY : OPERATOR,true)));
        assertFalse(ok); assertEq(bytes4(reason),error_); assertEq(redemptionState(v),before);
    }
    function requestRedeem(Venue memory v,bool emergency,uint256 gross) internal returns (uint32 timestamp) {
        address q=redeemQueue(v); uint256 balance=IEarnShares(v.shares).activeSharesOf(address(safe));
        uint256 locked=IERC20(v.shares).balanceOf(v.shares); uint256 total=IEarnShares(v.shares).totalShares();
        (,,,uint256 pending)=IEarnRedeem(q).getState(); bytes32 key=keyState(v.key);
        IEarnFee feeManager=IEarnFee(v.vault.feeManager());
        uint256 fee=feeManager.feeRecipient()==address(safe) ? 0 : gross*feeManager.redeemFeeD6()/1e6;
        execute(emergency,q,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(gross)));
        IEarnRedeem.Request[] memory requests=IEarnRedeem(q).requestsOf(address(safe),0,20);
        timestamp=uint32(requests[requests.length-1].timestamp); assertEq(timestamp,block.timestamp);
        assertEq(IEarnShares(v.shares).activeSharesOf(address(safe)),balance-gross);
        assertEq(IERC20(v.shares).balanceOf(v.shares),locked+gross-fee); assertEq(IEarnShares(v.shares).totalShares(),total);
        (,,,uint256 afterPending)=IEarnRedeem(q).getState(); assertEq(afterPending,pending+gross-fee);
        assertEq(IERC20(v.shares).allowance(address(safe),q),0); assertEq(keyState(v.key),key);
    }
    function priceRedeems(Venue memory v) internal returns (uint256 batch) {
        address q=redeemQueue(v); uint256 pending; (,batch,,pending)=IEarnRedeem(q).getState();
        uint256 locked=IERC20(v.shares).balanceOf(v.shares); uint256 total=IEarnShares(v.shares).totalShares();
        (,,uint256 demand,)=IEarnRedeem(q).getState();
        IEarnOracle.DetailedReport memory old=v.oracle.getReport(v.token); IEarnOracle.Params memory p=v.oracle.securityParams();
        uint256 target=block.timestamp+p.redeemInterval+1; uint256 deadline=uint256(old.timestamp)+p.timeout+1; if (target<deadline) target=deadline;
        vm.warp(target); bytes32 role=keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"); address holder=v.vault.getRoleMember(role,0); assertTrue(v.vault.hasRole(role,holder));
        IEarnOracle.Report[] memory reports=new IEarnOracle.Report[](1); reports[0]=IEarnOracle.Report(v.token,old.priceD18);
        vm.prank(holder); v.oracle.submitReports(reports);
        (uint256 assets,uint256 shares)=IEarnRedeem(q).batchAt(batch); assertEq(shares,pending); assertEq(assets,pending*1e18/old.priceD18);
        (,,uint256 afterDemand,uint256 afterPending)=IEarnRedeem(q).getState(); assertEq(afterPending,0); assertEq(afterDemand,demand+assets);
        assertEq(IERC20(v.shares).balanceOf(v.shares),locked-pending); assertEq(IEarnShares(v.shares).totalShares(),total-pending);
    }
    function handleRedeems(Venue memory v,uint256 limit) internal returns (uint256 expected) {
        address q=redeemQueue(v); (uint256 iterator,uint256 length,uint256 demand,)=IEarnRedeem(q).getState();
        vm.prank(q); uint256 liquid=v.vault.getLiquidAssets(); uint256 assets;
        for (uint256 i=iterator;i<length && expected<limit;++i) {
            (uint256 next,)=IEarnRedeem(q).batchAt(i); if (assets+next>liquid) break; assets+=next; ++expected;
        }
        uint256 before=IERC20(v.token).balanceOf(q); assertEq(IEarnRedeem(q).handleBatches(limit),expected);
        (uint256 afterIterator,,uint256 afterDemand,)=IEarnRedeem(q).getState(); assertEq(afterIterator,iterator+expected); assertEq(afterDemand,demand-assets);
        assertEq(IERC20(v.token).balanceOf(q),before+assets);
    }
    // Keep the payout model outside Solc 0.8.24's inlined claim stack.
    function expectedClaimPayout(IEarnRedeem.Request[] memory requests,uint32[] memory ids,uint256 assets,uint256 shares)
        external pure returns (uint256 expected,uint256 remainingAssets,uint256 remainingShares)
    {
        bool[] memory used=new bool[](requests.length);
        for (uint256 i;i<ids.length;++i) for (uint256 j;j<requests.length;++j) {
            if (used[j] || requests[j].timestamp!=ids[i] || !requests[j].claimable) continue;
            uint256 payout=requests[j].shares*assets/shares; expected+=payout; assets-=payout; shares-=requests[j].shares; used[j]=true;
        }
        return (expected,assets,shares);
    }
    function claimRedeems(Venue memory v,bool emergency,uint32[] memory ids,uint256 batch) internal returns (uint256 expected) {
        address q=redeemQueue(v); IEarnRedeem.Request[] memory requests=IEarnRedeem(q).requestsOf(address(safe),0,20);
        (uint256 assets,uint256 shares)=IEarnRedeem(q).batchAt(batch);
        (expected,assets,shares)=this.expectedClaimPayout(requests,ids,assets,shares);
        uint256 safeBefore=IERC20(v.token).balanceOf(address(safe)); uint256 queueBefore=IERC20(v.token).balanceOf(q); bytes32 key=keyState(v.key);
        execute(emergency,q,0,abi.encodeCall(ILidoEarnRedeemQueue.claim,(address(safe),ids)));
        assertEq(IERC20(v.token).balanceOf(address(safe)),safeBefore+expected); assertEq(IERC20(v.token).balanceOf(q),queueBefore-expected);
        (uint256 afterAssets,uint256 afterShares)=IEarnRedeem(q).batchAt(batch); assertEq(afterAssets,assets); assertEq(afterShares,shares); assertEq(keyState(v.key),key);
    }
    function oneId(uint32 timestamp) internal pure returns (uint32[] memory ids) { ids=new uint32[](1); ids[0]=timestamp; }
    function test_MAIN07_both_venues_both_roles_lock_report_batch_exact_claim_and_no_replay() public {
        for (uint256 asset;asset<2;++asset) for (uint256 role;role<2;++role) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); uint32 id=requestRedeem(v,role==1,shares/2);
            bytes32 before=redemptionState(v); execute(role==1,redeemQueue(v),0,abi.encodeCall(ILidoEarnRedeemQueue.claim,(address(safe),oneId(id)))); assertEq(redemptionState(v),before);
            uint256 batch=priceRedeems(v); assertFalse(IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,1)[0].claimable);
            assertEq(claimRedeems(v,role==1,oneId(id),batch),0); assertGt(handleRedeems(v,type(uint256).max),0);
            assertGt(claimRedeems(v,role==1,oneId(id),batch),0); assertEq(IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20).length,0);
            before=redemptionState(v); assertEq(claimRedeems(v,role==1,oneId(id),batch),0); assertEq(redemptionState(v),before); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_same_timestamp_merge_multiple_ids_empty_unknown_duplicate_and_partial_claim() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v);
            uint32 first=requestRedeem(v,false,shares/4); requestRedeem(v,true,shares/4); vm.warp(block.timestamp+1); uint32 second=requestRedeem(v,false,shares/4);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20); assertEq(requests.length,2); assertEq(requests[0].shares,2*(shares/4));
            uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max); bytes32 before=redemptionState(v);
            assertEq(claimRedeems(v,false,new uint32[](0),batch),0); assertEq(claimRedeems(v,true,oneId(type(uint32).max),batch),0); assertEq(redemptionState(v),before);
            uint32[] memory ids=new uint32[](3); ids[0]=first; ids[1]=first; ids[2]=0; assertGt(claimRedeems(v,false,ids,batch),0);
            assertEq(IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20).length,1); assertGt(claimRedeems(v,true,oneId(second),batch),0);
            assertEq(IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20).length,0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_zero_excess_max_wrong_receiver_value_delegatecall_are_atomic() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); vm.deal(address(safe),1);
            for (uint256 role;role<2;++role) {
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(0)),0,FAILED);
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(shares+1)),0,FAILED);
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(type(uint256).max)),0,FAILED);
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.claim,(attacker,new uint32[](0))),0,CONDITION);
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.claim,(address(agent),new uint32[](0))),0,CONDITION);
                redeemRefused(v,role==1,1,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(1)),0,CONDITION);
                redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(1)),1,CONDITION);
            }
            requestRedeem(v,true,shares); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_queue_pause_existing_claim_and_resume_redeem() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); uint32 id=requestRedeem(v,false,shares/2);
            uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max); address q=redeemQueue(v);
            address holder=v.vault.getRoleMember(keccak256("modules.ShareModule.SET_QUEUE_STATUS_ROLE"),0); vm.prank(holder); v.vault.setQueueStatus(q,true);
            for (uint256 role;role<2;++role) redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(1)),0,FAILED);
            assertGt(claimRedeems(v,true,oneId(id),batch),0); vm.prank(holder); v.vault.setQueueStatus(q,false); requestRedeem(v,false,shares/4); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_zero_batch_limit_controlled_cash_shortage_snapshot_restore_retry() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); uint32 id=requestRedeem(v,false,shares/2); uint256 batch=priceRedeems(v);
            bytes32 before=redemptionState(v); assertEq(handleRedeems(v,0),0); assertEq(redemptionState(v),before);
            uint256 branch=vm.snapshotState(); address q=redeemQueue(v); address original=v.vault.getHook(q);
            address admin=forkGrant(v,keccak256("modules.ShareModule.SET_HOOK_ROLE")); vm.startPrank(admin);
            v.vault.setCustomHook(q,address(0)); v.vault.setDefaultRedeemHook(address(0)); vm.stopPrank(); assertEq(v.vault.getHook(q),address(0));
            (uint256 demand,)=IEarnRedeem(q).batchAt(batch); assertLt(IERC20(v.token).balanceOf(address(v.vault)),demand);
            handleRedeems(v,type(uint256).max); assertEq(claimRedeems(v,true,oneId(id),batch),0);
            assertTrue(vm.revertToState(branch)); assertEq(v.vault.getHook(q),original); assertGt(handleRedeems(v,type(uint256).max),0); assertGt(claimRedeems(v,false,oneId(id),batch),0);
            before=redemptionState(v); assertEq(handleRedeems(v,type(uint256).max),0); assertEq(redemptionState(v),before); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_operator_stop_preserves_emergency_request_report_and_claim() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v);
            (address[] memory modules,)=safe.getModulesPaginated(SENTINEL,10); address previous=SENTINEL;
            for (uint256 i;i<modules.length && modules[i]!=address(roles);++i) previous=modules[i];
            execute(true,address(safe),0,abi.encodeCall(ISafe.disableModule,(previous,address(roles))));
            address q=redeemQueue(v); vm.prank(operatorSafe); vm.expectRevert("GS104");
            roles.execTransactionWithRole(q,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(1)),0,OPERATOR,true);
            uint32 id=requestRedeem(v,true,shares); uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max); assertGt(claimRedeems(v,true,oneId(id),batch),0);
            assertTrue(safe.isModuleEnabled(address(safety))); assertFalse(safe.isModuleEnabled(address(roles))); assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN07_both_venues_valid_early_report_keeps_request_unpriced_until_redeem_delay() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v);
            uint32 id=requestRedeem(v,false,shares/2); address q=redeemQueue(v);
            IEarnOracle.DetailedReport memory old=v.oracle.getReport(v.token); IEarnOracle.Params memory p=v.oracle.securityParams();
            vm.warp(uint256(old.timestamp)+p.timeout+1); assertLt(block.timestamp-p.redeemInterval,id);
            IEarnOracle.Report[] memory reports=new IEarnOracle.Report[](1); reports[0]=IEarnOracle.Report(v.token,old.priceD18);
            address holder=v.vault.getRoleMember(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"),0);
            vm.prank(holder); v.oracle.submitReports(reports);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(q).requestsOf(address(safe),0,1);
            assertEq(requests[0].timestamp,id); assertFalse(requests[0].claimable); assertEq(requests[0].assets,0);
            bytes32 before=redemptionState(v); execute(true,q,0,abi.encodeCall(ILidoEarnRedeemQueue.claim,(address(safe),oneId(id))));
            assertEq(redemptionState(v),before); uint256 batch=priceRedeems(v); assertGt(handleRedeems(v,type(uint256).max),0);
            assertGt(claimRedeems(v,true,oneId(id),batch),0); assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN07_both_venues_two_report_batches_bounded_fifo_and_reverse_claim_order() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); address q=redeemQueue(v);
            uint32 first=requestRedeem(v,false,shares/4); uint256 firstBatch=priceRedeems(v);
            uint32 second=requestRedeem(v,true,shares/4); uint256 secondBatch=priceRedeems(v); assertEq(secondBatch,firstBatch+1);
            (uint256 iterator,uint256 length,,)=IEarnRedeem(q).getState(); assertEq(length,secondBatch+1);
            while (iterator<firstBatch) { assertEq(handleRedeems(v,1),1); (iterator,,,)=IEarnRedeem(q).getState(); }
            assertEq(handleRedeems(v,1),1); (iterator,,,)=IEarnRedeem(q).getState(); assertEq(iterator,secondBatch);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(q).requestsOf(address(safe),0,20);
            assertTrue(requests[0].claimable); assertFalse(requests[1].claimable);
            bytes32 before=redemptionState(v); assertEq(claimRedeems(v,true,oneId(second),secondBatch),0); assertEq(redemptionState(v),before);
            assertEq(handleRedeems(v,1),1); assertGt(claimRedeems(v,true,oneId(second),secondBatch),0);
            assertGt(claimRedeems(v,false,oneId(first),firstBatch),0); assertEq(IEarnRedeem(q).requestsOf(address(safe),0,20).length,0);
            assertEq(handleRedeems(v,1),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_burn_pause_blacklist_lockup_atomic_refusal_and_restore() public {
        for (uint256 asset;asset<2;++asset) for (uint256 restriction;restriction<3;++restriction) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); address q=redeemQueue(v);
            IEarnShares.Flags memory original=IEarnShares(v.shares).flags(); IEarnShares.Flags memory restricted=IEarnShares(v.shares).flags();
            address holder=v.vault.getRoleMember(keccak256("managers.ShareManager.SET_FLAGS_ROLE"),0); address admin;
            IEarnShares.AccountInfo memory account=IEarnShares(v.shares).accounts(address(safe)); bytes4 expected;
            if (restriction==0) { restricted.burnPause=true; expected=bytes4(keccak256("BurnPaused()")); }
            else if (restriction==1) { restricted.lockup=uint32(block.timestamp+100); expected=bytes4(keccak256("GlobalLockupNotExpired(uint256,uint32)")); }
            else {
                admin=forkGrant(v,keccak256("managers.ShareManager.SET_ACCOUNT_INFO_ROLE"));
                vm.prank(admin); IEarnShares(v.shares).setAccountInfo(address(safe),IEarnShares.AccountInfo(account.canDeposit,account.canTransfer,true));
                expected=bytes4(keccak256("Blacklisted(address)"));
            }
            if (restriction<2) { vm.prank(holder); IEarnShares(v.shares).setFlags(restricted); }
            for (uint256 role;role<2;++role) redeemRefused(v,role==1,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(shares/4)),0,FAILED);
            bytes32 before=redemptionState(v); vm.prank(address(safe)); (bool ok,bytes memory reason)=q.call(abi.encodeCall(ILidoEarnRedeemQueue.redeem,(shares/4)));
            assertFalse(ok); assertEq(bytes4(reason),expected); assertEq(redemptionState(v),before);
            if (restriction==1) {
                vm.warp(uint256(restricted.lockup)-1); redeemRefused(v,false,0,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(1)),0,FAILED);
                vm.warp(restricted.lockup);
            } else if (restriction==0) { vm.prank(holder); IEarnShares(v.shares).setFlags(original); }
            else { vm.prank(admin); IEarnShares(v.shares).setAccountInfo(address(safe),account); }
            requestRedeem(v,true,shares/4); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_pending_report_burn_pause_reverts_oracle_and_queue_then_retries() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); uint32 id=requestRedeem(v,false,shares/2);
            IEarnShares.Flags memory original=IEarnShares(v.shares).flags(); IEarnShares.Flags memory restricted=IEarnShares(v.shares).flags(); restricted.burnPause=true;
            address holder=v.vault.getRoleMember(keccak256("managers.ShareManager.SET_FLAGS_ROLE"),0); vm.prank(holder); IEarnShares(v.shares).setFlags(restricted);
            IEarnOracle.DetailedReport memory old=v.oracle.getReport(v.token); IEarnOracle.Params memory p=v.oracle.securityParams(); vm.warp(block.timestamp+p.redeemInterval+1);
            IEarnOracle.Report[] memory reports=new IEarnOracle.Report[](1); reports[0]=IEarnOracle.Report(v.token,old.priceD18);
            address reporter=v.vault.getRoleMember(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"),0); bytes32 before=redemptionState(v);
            vm.prank(reporter); (bool ok,bytes memory reason)=address(v.oracle).call(abi.encodeCall(IEarnOracle.submitReports,(reports)));
            assertFalse(ok); assertEq(bytes4(reason),bytes4(keccak256("BurnPaused()"))); assertEq(redemptionState(v),before);
            assertEq(keccak256(abi.encode(v.oracle.getReport(v.token))),keccak256(abi.encode(old)));
            vm.prank(holder); IEarnShares(v.shares).setFlags(original); uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max);
            assertGt(claimRedeems(v,true,oneId(id),batch),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_nonzero_redemption_fee_exact_net_request_supply_conservation_and_no_locked_fee() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); IEarnFee fees=IEarnFee(v.vault.feeManager());
            uint24 testFee=1234; address owner=fees.owner(); assertTrue(owner!=address(0));
            // Controlled fork fee; not a proposed or accepted live setting.
            uint24 depositFee=uint24(fees.depositFeeD6()); uint24 performanceFee=uint24(fees.performanceFeeD6()); uint24 protocolFee=uint24(fees.protocolFeeD6());
            vm.prank(owner); fees.setFees(depositFee,testFee,performanceFee,protocolFee);
            assertEq(fees.redeemFeeD6(),testFee); address recipient=fees.feeRecipient(); assertTrue(recipient!=address(safe));
            uint256 gross=shares/2; uint256 fee=gross*testFee/1e6; assertGt(fee,0);
            uint256 locked=IERC20(v.shares).balanceOf(v.shares); (,,,uint256 priorPending)=IEarnRedeem(redeemQueue(v)).getState();
            uint256 recipientBefore=IERC20(v.shares).balanceOf(recipient);
            uint32 id=requestRedeem(v,false,gross); assertEq(IERC20(v.shares).balanceOf(recipient),recipientBefore+fee);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20); assertEq(requests[0].shares,gross-fee);
            uint256 batch=priceRedeems(v); assertEq(IERC20(v.shares).balanceOf(v.shares),locked-priorPending);
            handleRedeems(v,type(uint256).max); assertGt(claimRedeems(v,true,oneId(id),batch),0);
            assertEq(IERC20(v.shares).balanceOf(v.shares),locked-priorPending); assertEq(IERC20(v.shares).balanceOf(recipient),recipientBefore+fee);
            assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN07_both_venues_injected_hook_read_execution_faults_rollback_clear_and_retry() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); uint32 id=requestRedeem(v,false,shares/2);
            uint256 batch=priceRedeems(v); address q=redeemQueue(v); address hook=v.vault.getHook(q); assertTrue(hook!=address(0));
            for (uint256 fault;fault<2;++fault) {
                bytes32 before=redemptionState(v); uint256 vaultAssets=IERC20(v.token).balanceOf(address(v.vault));
                (int256 balance,int256 limit)=IEarnRisk(v.vault.riskManager()).vaultState();
                bytes memory data=fault==0 ? abi.encodeWithSignature("getLiquidAssets(address)",v.token) : abi.encodePacked(bytes4(keccak256("callHook(address,uint256)")));
                bytes memory injected=abi.encodeWithSignature("Error(string)",fault==0 ? "liquidity-read-fault" : "hook-execution-fault");
                vm.mockCallRevert(hook,data,injected);
                (bool ok,bytes memory reason)=q.call(abi.encodeCall(IEarnRedeem.handleBatches,(type(uint256).max)));
                assertFalse(ok); assertEq(keccak256(reason),keccak256(injected)); vm.clearMockedCalls();
                assertEq(redemptionState(v),before); assertEq(IERC20(v.token).balanceOf(address(v.vault)),vaultAssets);
                (int256 afterBalance,int256 afterLimit)=IEarnRisk(v.vault.riskManager()).vaultState(); assertEq(afterBalance,balance); assertEq(afterLimit,limit);
            }
            assertGt(handleRedeems(v,type(uint256).max),0); assertGt(claimRedeems(v,true,oneId(id),batch),0); assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN07_usdc_queue_blacklist_reverts_hook_funding_atomically_then_retries() public {
        uint256 snap=vm.snapshotState(); Venue memory v=venue(false); uint256 shares=position(v);
        uint32 id=requestRedeem(v,false,shares/2); uint256 batch=priceRedeems(v); address q=redeemQueue(v);
        IERC20Blacklist token=IERC20Blacklist(v.token); address blacklister=token.blacklister();
        assertTrue(blacklister!=address(0)); assertFalse(token.isBlacklisted(q));
        vm.prank(blacklister); token.blacklist(q); assertTrue(token.isBlacklisted(q));
        bytes32 before=redemptionState(v); uint256 vaultAssets=IERC20(v.token).balanceOf(address(v.vault));
        (int256 balance,int256 limit)=IEarnRisk(v.vault.riskManager()).vaultState();
        (bool ok,bytes memory reason)=q.call(abi.encodeCall(IEarnRedeem.handleBatches,(type(uint256).max)));
        assertFalse(ok); assertEq(bytes4(reason),bytes4(keccak256("Error(string)"))); assertEq(redemptionState(v),before);
        assertEq(IERC20(v.token).balanceOf(address(v.vault)),vaultAssets);
        (int256 afterBalance,int256 afterLimit)=IEarnRisk(v.vault.riskManager()).vaultState();
        assertEq(afterBalance,balance); assertEq(afterLimit,limit);
        vm.prank(blacklister); token.unBlacklist(q); assertFalse(token.isBlacklisted(q));
        assertGt(handleRedeems(v,type(uint256).max),0); assertGt(claimRedeems(v,false,oneId(id),batch),0);
        assertTrue(vm.revertToState(snap));
    }

    function test_MAIN07_both_venues_fee_recipient_exemption_at_max_fee_both_roles() public {
        for (uint256 asset;asset<2;++asset) for (uint256 role;role<2;++role) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v);
            IEarnFee fees=IEarnFee(v.vault.feeManager()); address owner=fees.owner();
            // Controlled local recipient and fee; no live configuration change.
            vm.startPrank(owner); fees.setFees(0,1e6,0,0); fees.setFeeRecipient(address(safe)); vm.stopPrank();
            uint256 total=IEarnShares(v.shares).totalShares(); uint256 locked=IERC20(v.shares).balanceOf(v.shares);
            uint32 id=requestRedeem(v,role==1,shares/2);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20);
            assertEq(requests[0].shares,shares/2); assertEq(IERC20(v.shares).balanceOf(v.shares),locked+shares/2);
            assertEq(IEarnShares(v.shares).totalShares(),total); uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max);
            assertGt(claimRedeems(v,role==1,oneId(id),batch),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_minimum_share_fee_rounding_and_zero_asset_claim_removal() public {
        uint256[4] memory amounts=[uint256(1),3,4,1_000_001];
        for (uint256 asset;asset<2;++asset) for (uint256 n;n<amounts.length;++n) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); position(v); IEarnFee fees=IEarnFee(v.vault.feeManager());
            address owner=fees.owner(); vm.prank(owner); fees.setFees(0,333333,0,0);
            uint256 gross=amounts[n]; uint256 fee=gross*333333/1e6; address recipient=fees.feeRecipient();
            uint256 before=IERC20(v.shares).balanceOf(recipient); uint32 id=requestRedeem(v,n%2==1,gross);
            assertEq(IERC20(v.shares).balanceOf(recipient),before+fee);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20); assertEq(requests[0].shares,gross-fee);
            uint256 batch=priceRedeems(v); handleRedeems(v,type(uint256).max);
            (uint256 assets,uint256 shares)=IEarnRedeem(redeemQueue(v)).batchAt(batch); uint256 expected=(gross-fee)*assets/shares;
            assertEq(claimRedeems(v,n%2==0,oneId(id),batch),expected);
            assertEq(IEarnRedeem(redeemQueue(v)).requestsOf(address(safe),0,20).length,0);
            if (asset==0) assertEq(expected,0,"Sub-USDC-unit requests have a zero asset payout");
            assertEq(claimRedeems(v,n%2==1,oneId(id),batch),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_both_venues_max_fee_zero_net_request_report_reset_and_positive_request_cleanup() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); uint256 shares=position(v); address q=redeemQueue(v);
            (,,,uint256 priorPending)=IEarnRedeem(q).getState(); if (priorPending>0) priceRedeems(v); handleRedeems(v,type(uint256).max);
            IEarnFee fees=IEarnFee(v.vault.feeManager()); address owner=fees.owner(); vm.prank(owner); fees.setFees(0,1e6,0,0);
            bytes32 config=keccak256(abi.encode(fees.depositFeeD6(),fees.redeemFeeD6(),fees.performanceFeeD6(),fees.protocolFeeD6(),fees.feeRecipient()));
            vm.prank(owner); (bool ok,bytes memory reason)=address(fees).call(abi.encodeCall(IEarnFee.setFees,(uint24(1),uint24(1e6),uint24(0),uint24(0))));
            assertFalse(ok); assertEq(bytes4(reason),bytes4(keccak256("InvalidFees(uint24,uint24,uint24,uint24)")));
            assertEq(keccak256(abi.encode(fees.depositFeeD6(),fees.redeemFeeD6(),fees.performanceFeeD6(),fees.protocolFeeD6(),fees.feeRecipient())),config);
            uint256 gross=shares/2; address recipient=fees.feeRecipient(); uint256 before=IERC20(v.shares).balanceOf(recipient);
            uint32 zeroId=requestRedeem(v,false,gross); assertEq(IERC20(v.shares).balanceOf(recipient),before+gross);
            (uint256 iterator,uint256 length,uint256 demand,uint256 pending)=IEarnRedeem(q).getState(); assertEq(pending,0); assertEq(iterator,length); assertEq(demand,0);
            uint256 batch=priceRedeems(v); (uint256 afterIterator,uint256 afterLength,,)=IEarnRedeem(q).getState(); assertEq(afterLength,length); assertEq(afterIterator,iterator);
            assertEq(handleRedeems(v,type(uint256).max),0); assertEq(claimRedeems(v,true,oneId(zeroId),batch),0);
            assertEq(IEarnRedeem(q).requestsOf(address(safe),0,20).length,1);
            vm.prank(owner); fees.setFees(0,0,0,0); assertEq(claimRedeems(v,false,oneId(zeroId),batch),0);
            assertEq(IEarnRedeem(q).requestsOf(address(safe),0,20).length,1);
            uint32 positiveId=requestRedeem(v,true,1); batch=priceRedeems(v); assertEq(handleRedeems(v,1),1);
            uint32[] memory timestamps=new uint32[](2); timestamps[0]=zeroId; timestamps[1]=positiveId;
            claimRedeems(v,true,timestamps,batch); assertEq(IEarnRedeem(q).requestsOf(address(safe),0,20).length,0);
            assertEq(IERC20(v.shares).balanceOf(recipient),before+gross); assertTrue(vm.revertToState(snap));
        }
    }

}
