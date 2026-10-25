// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ISafe, ISafeProxyFactory, IModuleProxyFactory} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20, ILidoEarnRedeemQueue} from "../src/interfaces/Tokens.sol";
import {Mainnet} from "./rehearsal/Mainnet.sol";
import {SepoliaFirstLossBurnFactory} from "../src/mocks/SepoliaStand.sol";
import {IEasyTrack} from "./rehearsal/RehearsalBase.sol";
import {IEarnDeposit, IEarnVault, IEarnShares, IEarnFee, IEarnOracle, IEarnRedeem} from "./MainnetEarnCoverage.t.sol";

interface IBurnExecutor {
    function executeEVMScript(bytes calldata) external returns (bytes memory);
    function easyTrack() external view returns (address);
    function callsScript() external view returns (address);
}
interface IEasyTrackBurn is IEasyTrack {
    function evmScriptExecutor() external view returns (address);
    function hasRole(bytes32,address) external view returns (bool);
    function removeEVMScriptFactory(address) external;
    function cancelMotion(uint256) external;
    function cancelMotions(uint256[] calldata) external;
    function objectToMotion(uint256) external;
    function objectionsThreshold() external view returns (uint256);
    function objections(uint256,address) external view returns (bool);
    function pause() external;
    function unpause() external;
}
interface IBurnToken {
    function totalSupply() external view returns (uint256);
    function balanceOfAt(address,uint256) external view returns (uint256);
    function totalSupplyAt(uint256) external view returns (uint256);
}


/// @dev ADR 008 decisions 21/23. Local role probes; burns use the real Easy Track and a typed stand factory.
contract MainnetFirstLossCoverageTest is Test {
    bytes32 internal constant FIRST_LOSS=bytes32("first-loss");
    address internal constant USD_QUEUE=0x9e36A74FE278906a76e7615263e46a83fC40c47F;
    address internal constant ETH_QUEUE=0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4;
    ISafe internal firstLoss;
    IRoles internal modifier_;
    address internal outsider;
    struct Venue { address queue; address token; address shares; IEarnVault vault; IEarnOracle oracle; }

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC"),25946643); outsider=makeAddr("outsider");
        address[] memory owners=new address[](1); owners[0]=Mainnet.AGENT;
        bytes memory init=abi.encodeCall(ISafe.setup,(owners,1,address(0),"",address(0),address(0),0,payable(address(0))));
        firstLoss=ISafe(payable(ISafeProxyFactory(Mainnet.SAFE_PROXY_FACTORY).createProxyWithNonce(Mainnet.SAFE_SINGLETON,init,707)));
        modifier_=IRoles(IModuleProxyFactory(Mainnet.MODULE_PROXY_FACTORY).deployModule(Mainnet.ROLES_MASTERCOPY,
            abi.encodeCall(IRoles.setUp,(abi.encode(address(firstLoss),address(firstLoss),address(firstLoss)))),707));
        // Owner impersonation configures only this local fixture; no vote or live policy grant is claimed.
        vm.startPrank(address(firstLoss)); firstLoss.enableModule(address(modifier_));
        bytes32[] memory keys=new bytes32[](1); keys[0]=FIRST_LOSS; bool[] memory member=new bool[](1); member[0]=true;
        modifier_.assignRoles(Mainnet.COMMITTEE_SAFE,keys,member);
        IRoles.ConditionFlat[] memory conditions=new IRoles.ConditionFlat[](2);
        conditions[0]=IRoles.ConditionFlat(0,5,5,""); conditions[1]=IRoles.ConditionFlat(0,1,16,abi.encode(Mainnet.AGENT));
        for (uint256 i;i<2;++i) {
            address q=i==0 ? USD_QUEUE : ETH_QUEUE; modifier_.scopeTarget(FIRST_LOSS,q);
            modifier_.allowFunction(FIRST_LOSS,q,ILidoEarnRedeemQueue.redeem.selector,0);
            modifier_.scopeFunction(FIRST_LOSS,q,ILidoEarnRedeemQueue.claim.selector,conditions,0);
        }
        vm.stopPrank();
        assertEq(modifier_.owner(),address(firstLoss)); assertEq(modifier_.avatar(),address(firstLoss)); assertEq(modifier_.target(),address(firstLoss));
        assertEq(firstLoss.getOwners()[0],Mainnet.AGENT); assertEq(firstLoss.getThreshold(),1);
        for (uint256 i;i<2;++i) {
            address share=i==0 ? Mainnet.EARN_USD_SHARE : Mainnet.EARN_ETH_SHARE;
            uint256 before=IERC20(share).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE); assertGe(before,100e18);
            vm.prank(Mainnet.GROWTH_COMMITTEE_SAFE); assertTrue(IERC20(share).transfer(address(firstLoss),100e18));
            assertEq(IERC20(share).balanceOf(address(firstLoss)),100e18); assertEq(IERC20(share).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE),before-100e18);
        }
    }
    function venue(bool eth) internal view returns (Venue memory v) {
        v.queue=eth ? ETH_QUEUE : USD_QUEUE; v.token=eth ? Mainnet.WSTETH : Mainnet.USDC;
        v.shares=eth ? Mainnet.EARN_ETH_SHARE : Mainnet.EARN_USD_SHARE;
        v.vault=IEarnVault(IEarnDeposit(v.queue).vault()); v.oracle=IEarnOracle(v.vault.oracle());
        assertEq(IEarnDeposit(v.queue).asset(),v.token); assertEq(v.vault.shareManager(),v.shares);
        assertTrue(v.vault.hasQueue(v.queue)); assertFalse(v.vault.isDepositQueue(v.queue));
    }
    function execute(address target,bytes memory data) internal {
        vm.prank(Mainnet.COMMITTEE_SAFE); assertTrue(modifier_.execTransactionWithRole(target,0,data,0,FIRST_LOSS,true));
    }
    function ids(uint32 timestamp) internal pure returns (uint32[] memory x) { x=new uint32[](1); x[0]=timestamp; }
    function state(Venue memory v) internal view returns (bytes32) {
        (uint256 i,uint256 b,uint256 d,uint256 p)=IEarnRedeem(v.queue).getState();
        return keccak256(abi.encode(i,b,d,p,IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20),
            IERC20(v.token).balanceOf(Mainnet.AGENT),IERC20(v.token).balanceOf(address(firstLoss)),IERC20(v.token).balanceOf(v.queue),
            IERC20(v.shares).balanceOf(address(firstLoss)),IERC20(v.shares).balanceOf(v.shares),IEarnShares(v.shares).totalShares()));
    }
    function refused(Venue memory v,address caller,address target,bytes memory data,bytes4 expectedError) internal {
        bytes32 before=state(v); vm.prank(caller);
        (bool ok,bytes memory reason)=address(modifier_).call(abi.encodeCall(IRoles.execTransactionWithRole,(target,0,data,0,FIRST_LOSS,true)));
        assertFalse(ok);
        if (expectedError!=bytes4(0)) assertEq(bytes4(reason),expectedError);
        assertEq(state(v),before);
    }
    function request(Venue memory v,uint256 amount) internal returns (uint32 timestamp) {
        uint256 balance=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 locked=IERC20(v.shares).balanceOf(v.shares);
        (,,,uint256 pending)=IEarnRedeem(v.queue).getState(); IEarnFee fees=IEarnFee(v.vault.feeManager());
        uint256 fee=fees.feeRecipient()==address(firstLoss) ? 0 : amount*fees.redeemFeeD6()/1e6;
        execute(v.queue,abi.encodeCall(ILidoEarnRedeemQueue.redeem,(amount)));
        IEarnRedeem.Request[] memory requests=IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20);
        timestamp=uint32(requests[requests.length-1].timestamp); assertEq(timestamp,block.timestamp);
        assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),balance-amount); assertEq(IERC20(v.shares).balanceOf(v.shares),locked+amount-fee);
        (,,,uint256 afterPending)=IEarnRedeem(v.queue).getState(); assertEq(afterPending,pending+amount-fee);
        assertEq(IERC20(v.shares).allowance(address(firstLoss),v.queue),0);
    }
    function settle(Venue memory v) internal returns (uint256 batch) {
        uint256 pending; (,batch,,pending)=IEarnRedeem(v.queue).getState();
        uint256 locked=IERC20(v.shares).balanceOf(v.shares); uint256 total=IEarnShares(v.shares).totalShares();
        IEarnOracle.DetailedReport memory old=v.oracle.getReport(v.token); assertFalse(old.suspicious);
        IEarnOracle.Params memory p=v.oracle.securityParams(); uint256 target=block.timestamp+p.redeemInterval+1;
        if (target<uint256(old.timestamp)+p.timeout+1) target=uint256(old.timestamp)+p.timeout+1; vm.warp(target);
        address holder=v.vault.getRoleMember(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"),0);
        assertTrue(v.vault.hasRole(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"),holder));
        IEarnOracle.Report[] memory reports=new IEarnOracle.Report[](1); reports[0]=IEarnOracle.Report(v.token,old.priceD18);
        vm.prank(holder); v.oracle.submitReports(reports);
        (uint256 assets,uint256 shares)=IEarnRedeem(v.queue).batchAt(batch); assertEq(shares,pending); assertEq(assets,pending*1e18/old.priceD18);
        assertEq(IERC20(v.shares).balanceOf(v.shares),locked-pending); assertEq(IEarnShares(v.shares).totalShares(),total-pending);
        assertGt(IEarnRedeem(v.queue).handleBatches(type(uint256).max),0);
    }
    function claim(Venue memory v,uint32 timestamp,uint256 batch) internal returns (uint256 expected) {
        IEarnRedeem.Request[] memory requests=IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20);
        (uint256 assets,uint256 shares)=IEarnRedeem(v.queue).batchAt(batch);
        for (uint256 i;i<requests.length;++i) if (requests[i].timestamp==timestamp && requests[i].claimable) expected=requests[i].shares*assets/shares;
        uint256 agentBefore=IERC20(v.token).balanceOf(Mainnet.AGENT); uint256 queueBefore=IERC20(v.token).balanceOf(v.queue);
        uint256 safeBefore=IERC20(v.token).balanceOf(address(firstLoss)); execute(v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.AGENT,ids(timestamp))));
        assertEq(IERC20(v.token).balanceOf(Mainnet.AGENT),agentBefore+expected); assertEq(IERC20(v.token).balanceOf(v.queue),queueBefore-expected);
        assertEq(IERC20(v.token).balanceOf(address(firstLoss)),safeBefore);
        (uint256 afterAssets,uint256 afterShares)=IEarnRedeem(v.queue).batchAt(batch); assertEq(afterAssets,assets-expected);
        if (expected>0) assertLt(afterShares,shares); else assertEq(afterShares,shares);
    }
    function test_MAIN07_first_loss_both_real_shares_report_claim_to_agent_and_no_double_payment() public {
        for (uint256 i;i<2;++i) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(i==1); uint32 timestamp=request(v,50e18);
            bytes32 before=state(v); execute(v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.AGENT,ids(timestamp)))); assertEq(state(v),before);
            uint256 batch=settle(v); assertGt(claim(v,timestamp,batch),0);
            assertEq(IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20).length,0); before=state(v);
            assertEq(claim(v,timestamp,batch),0); assertEq(state(v),before); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_first_loss_claim_receiver_and_role_isolation_with_funded_request() public {
        for (uint256 i;i<2;++i) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(i==1); uint32 timestamp=request(v,50e18); uint256 batch=settle(v);
            refused(v,Mainnet.COMMITTEE_SAFE,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(address(firstLoss),ids(timestamp))),bytes4(keccak256("ConditionViolation(uint8,bytes32)")));
            refused(v,Mainnet.COMMITTEE_SAFE,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.COMMITTEE_SAFE,ids(timestamp))),bytes4(keccak256("ConditionViolation(uint8,bytes32)")));
            refused(v,Mainnet.COMMITTEE_SAFE,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(outsider,ids(timestamp))),bytes4(keccak256("ConditionViolation(uint8,bytes32)")));
            refused(v,outsider,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.AGENT,ids(timestamp))),bytes4(keccak256("NotAuthorized(address)")));
            refused(v,Mainnet.ET_EXECUTOR,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.AGENT,ids(timestamp))),bytes4(keccak256("NotAuthorized(address)")));
            refused(v,Mainnet.COMMITTEE_SAFE,v.shares,abi.encodeCall(IERC20.transfer,(Mainnet.AGENT,1)),bytes4(0));
            refused(v,Mainnet.COMMITTEE_SAFE,v.shares,abi.encodeCall(IERC20.approve,(v.queue,1)),bytes4(0));
            refused(v,Mainnet.COMMITTEE_SAFE,v.shares,abi.encodeWithSignature("burn(uint256)",1),bytes4(0));
            assertGt(claim(v,timestamp,batch),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_first_loss_owner_revocation_preserves_pending_claim_and_regrant_recovers() public {
        for (uint256 i;i<2;++i) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(i==1); uint32 timestamp=request(v,50e18);
            bytes32[] memory keys=new bytes32[](1); keys[0]=FIRST_LOSS; bool[] memory member=new bool[](1);
            vm.prank(address(firstLoss)); modifier_.assignRoles(Mainnet.COMMITTEE_SAFE,keys,member);
            uint256 batch=settle(v); refused(v,Mainnet.COMMITTEE_SAFE,v.queue,abi.encodeCall(ILidoEarnRedeemQueue.claim,(Mainnet.AGENT,ids(timestamp))),bytes4(keccak256("NoMembership()")));
            member[0]=true; vm.prank(address(firstLoss)); modifier_.assignRoles(Mainnet.COMMITTEE_SAFE,keys,member);
            assertGt(claim(v,timestamp,batch),0); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN07_first_loss_both_real_shares_nonzero_fee_and_recipient_exemption_pay_agent() public {
        for (uint256 asset;asset<2;++asset) for (uint256 exempt;exempt<2;++exempt) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); IEarnFee fees=IEarnFee(v.vault.feeManager());
            address owner=fees.owner(); vm.startPrank(owner);
            fees.setFees(0,exempt==1 ? uint24(1e6) : uint24(333333),0,0);
            if (exempt==1) fees.setFeeRecipient(address(firstLoss)); vm.stopPrank();
            address recipient=fees.feeRecipient(); uint256 gross=37e18; uint256 fee=exempt==1 ? 0 : gross*333333/1e6;
            uint256 recipientBefore=IERC20(v.shares).balanceOf(recipient); uint256 total=IEarnShares(v.shares).totalShares();
            uint32 timestamp=request(v,gross); assertEq(IEarnShares(v.shares).totalShares(),total);
            assertEq(IERC20(v.shares).balanceOf(recipient),exempt==1 ? recipientBefore-gross : recipientBefore+fee);
            IEarnRedeem.Request[] memory requests=IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20); assertEq(requests[0].shares,gross-fee);
            uint256 batch=settle(v); assertGt(claim(v,timestamp,batch),0);
            assertEq(IERC20(v.shares).balanceOf(recipient),exempt==1 ? recipientBefore-gross : recipientBefore+fee);
            assertEq(IEarnRedeem(v.queue).requestsOf(address(firstLoss),0,20).length,0); assertTrue(vm.revertToState(snap));
        }
    }

    bytes32 internal constant FIRST_LOSS_BURN=bytes32("first-loss-burn");
    function burnSetup() internal returns (SepoliaFirstLossBurnFactory factory) {
        vm.startPrank(address(firstLoss)); bytes32[] memory keys=new bytes32[](1); keys[0]=FIRST_LOSS_BURN;
        bool[] memory member=new bool[](1); member[0]=true; modifier_.assignRoles(Mainnet.ET_EXECUTOR,keys,member);
        address[2] memory tokens=[Mainnet.EARN_USD_SHARE,Mainnet.EARN_ETH_SHARE];
        for (uint256 i;i<2;++i) { modifier_.scopeTarget(FIRST_LOSS_BURN,tokens[i]); modifier_.allowFunction(FIRST_LOSS_BURN,tokens[i],bytes4(keccak256("burn(uint256)")),0); }
        vm.stopPrank();
        factory=new SepoliaFirstLossBurnFactory(Mainnet.COMMITTEE_SAFE,modifier_,Mainnet.EARN_USD_SHARE,Mainnet.EARN_ETH_SHARE);
        IEasyTrackBurn et=IEasyTrackBurn(Mainnet.EASY_TRACK); assertTrue(et.hasRole(bytes32(0),Mainnet.VOTING));
        assertEq(et.evmScriptExecutor(),Mainnet.ET_EXECUTOR); assertEq(IBurnExecutor(Mainnet.ET_EXECUTOR).easyTrack(),Mainnet.EASY_TRACK);
        assertGt(IBurnExecutor(Mainnet.ET_EXECUTOR).callsScript().code.length,0);
        // Local registry setup through the existing admin; no public registration or vote.
        vm.prank(Mainnet.VOTING); et.addEVMScriptFactory(address(factory),abi.encodePacked(address(modifier_),IRoles.execTransactionWithRole.selector));
        assertTrue(et.isEVMScriptFactory(address(factory))); assertEq(et.motionDuration(),3 days);
        assertLt(et.getMotions().length,et.motionsCountLimit());
    }
    function burnState(Venue memory v) internal view returns (bytes32) {
        return keccak256(abi.encode(state(v),IBurnToken(v.shares).totalSupply(),IEasyTrack(Mainnet.EASY_TRACK).getMotions(),
            IERC20(v.shares).balanceOf(Mainnet.AGENT),IERC20(v.shares).balanceOf(Mainnet.COMMITTEE_SAFE),IERC20(v.shares).balanceOf(outsider)));
    }
    function motion(uint256 id) internal view returns (IEasyTrack.Motion memory m) {
        IEasyTrack.Motion[] memory motions=IEasyTrack(Mainnet.EASY_TRACK).getMotions();
        for (uint256 i;i<motions.length;++i) if (motions[i].id==id) return motions[i];
        revert("probe: motion missing");
    }
    function motionAbsent(uint256 id) internal view returns (bool) {
        IEasyTrack.Motion[] memory motions=IEasyTrack(Mainnet.EASY_TRACK).getMotions();
        for (uint256 i;i<motions.length;++i) if (motions[i].id==id) return false; return true;
    }
    function burnCreate(SepoliaFirstLossBurnFactory factory,Venue memory v,uint256 amount) internal returns (uint256 id) {
        uint256 count=IEasyTrack(Mainnet.EASY_TRACK).getMotions().length; uint256 before=IERC20(v.shares).balanceOf(address(firstLoss));
        vm.prank(Mainnet.COMMITTEE_SAFE); id=IEasyTrack(Mainnet.EASY_TRACK).createMotion(address(factory),abi.encode(v.shares,amount));
        IEasyTrack.Motion memory m=motion(id); assertEq(m.creator,Mainnet.COMMITTEE_SAFE); assertEq(m.evmScriptFactory,address(factory));
        bytes memory callData=abi.encodeCall(IRoles.execTransactionWithRole,(v.shares,0,abi.encodeWithSignature("burn(uint256)",amount),0,FIRST_LOSS_BURN,true));
        bytes memory expected=abi.encodePacked(bytes4(0x00000001),address(modifier_),uint32(callData.length),callData);
        assertEq(m.evmScriptHash,keccak256(expected)); assertEq(m.duration,3 days);
        assertEq(IEasyTrack(Mainnet.EASY_TRACK).getMotions().length,count+1); assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),before);
    }
    function burnEtRefused(Venue memory v,address caller,bytes memory data,string memory expected) internal {
        bytes32 before=burnState(v); vm.prank(caller); (bool ok,bytes memory reason)=Mainnet.EASY_TRACK.call(data); assertFalse(ok);
        if (bytes(expected).length>0) assertEq(keccak256(reason),keccak256(abi.encodeWithSignature("Error(string)",expected)));
        assertEq(burnState(v),before);
    }
    function burnEnact(Venue memory v,uint256 id,uint256 amount) internal {
        uint256 before=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 supply=IBurnToken(v.shares).totalSupply();
        uint256 total=IEarnShares(v.shares).totalShares(); uint256 allocated=IEarnShares(v.shares).allocatedShares();
        uint256 agentBefore=IERC20(v.shares).balanceOf(Mainnet.AGENT); uint256 queueBefore=IERC20(v.shares).balanceOf(v.shares);
        uint256 agentAssets=IERC20(v.token).balanceOf(Mainnet.AGENT); uint256 safeAssets=IERC20(v.token).balanceOf(address(firstLoss)); uint256 queueAssets=IERC20(v.token).balanceOf(v.queue);
        vm.prank(outsider); IEasyTrack(Mainnet.EASY_TRACK).enactMotion(id,abi.encode(v.shares,amount));
        assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),before-amount); assertEq(IBurnToken(v.shares).totalSupply(),supply-amount);
        assertEq(IEarnShares(v.shares).totalShares(),total-amount); assertEq(IEarnShares(v.shares).allocatedShares(),allocated);
        assertEq(IERC20(v.shares).balanceOf(Mainnet.AGENT),agentBefore); assertEq(IERC20(v.shares).balanceOf(v.shares),queueBefore); assertTrue(motionAbsent(id));
        assertEq(IERC20(v.token).balanceOf(Mainnet.AGENT),agentAssets); assertEq(IERC20(v.token).balanceOf(address(firstLoss)),safeAssets); assertEq(IERC20(v.token).balanceOf(v.queue),queueAssets);
    }
    function test_MAIN08_both_real_shares_trusted_factory_script_exact_window_burn_and_replay() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup(); uint256 id=burnCreate(factory,v,10e18);
            IEasyTrack.Motion memory m=motion(id); vm.warp(m.startDate+m.duration-1);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,10e18))),"MOTION_NOT_PASSED");
            vm.warp(m.startDate+m.duration); burnEnact(v,id,10e18);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,10e18))),"MOTION_NOT_FOUND"); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_creator_inputs_changed_script_and_direct_burn_refusals() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup();
            bytes memory script=factory.createEVMScript(Mainnet.COMMITTEE_SAFE,abi.encode(v.shares,10e18));
            for (uint256 actor;actor<2;++actor) {
                bytes32 initial=burnState(v); vm.prank(actor==0 ? outsider : Mainnet.COMMITTEE_SAFE);
                (bool directOk,bytes memory directReason)=Mainnet.ET_EXECUTOR.call(abi.encodeCall(IBurnExecutor.executeEVMScript,(script)));
                assertFalse(directOk); assertEq(keccak256(directReason),keccak256(abi.encodeWithSignature("Error(string)","CALLER_IS_FORBIDDEN"))); assertEq(burnState(v),initial);
            }
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.createMotion,(address(factory),abi.encode(v.shares,10e18))),"burn factory: trusted caller");
            burnEtRefused(v,Mainnet.COMMITTEE_SAFE,abi.encodeCall(IEasyTrack.createMotion,(address(factory),abi.encode(Mainnet.WETH,10e18))),"burn factory: input");
            burnEtRefused(v,Mainnet.COMMITTEE_SAFE,abi.encodeCall(IEasyTrack.createMotion,(address(factory),abi.encode(v.shares,0))),"burn factory: input");
            burnEtRefused(v,Mainnet.COMMITTEE_SAFE,abi.encodeCall(IEasyTrack.createMotion,(address(factory),hex"00")),"");
            bytes32 before=burnState(v); vm.prank(Mainnet.COMMITTEE_SAFE);
            (bool ok,bytes memory reason)=address(modifier_).call(abi.encodeCall(IRoles.execTransactionWithRole,(v.shares,0,abi.encodeWithSignature("burn(uint256)",1),0,FIRST_LOSS_BURN,true)));
            assertFalse(ok); assertEq(bytes4(reason),bytes4(keccak256("NoMembership()"))); assertEq(burnState(v),before);
            uint256 id=burnCreate(factory,v,10e18); IEasyTrack.Motion memory m=motion(id); vm.warp(m.startDate+m.duration);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,11e18))),"UNEXPECTED_EVM_SCRIPT");
            burnEnact(v,id,10e18); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_creator_and_voting_cancel_without_burn() public {
        for (uint256 asset;asset<2;++asset) for (uint256 ownerCancel;ownerCancel<2;++ownerCancel) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup(); uint256 id=burnCreate(factory,v,10e18);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrackBurn.cancelMotion,(id)),"NOT_CREATOR");
            uint256 balance=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 supply=IBurnToken(v.shares).totalSupply();
            if (ownerCancel==0) { vm.prank(Mainnet.COMMITTEE_SAFE); IEasyTrackBurn(Mainnet.EASY_TRACK).cancelMotion(id); }
            else {
                assertTrue(IEasyTrackBurn(Mainnet.EASY_TRACK).hasRole(keccak256("CANCEL_ROLE"),Mainnet.VOTING));
                uint256[] memory ids_=new uint256[](1); ids_[0]=id; vm.prank(Mainnet.VOTING); IEasyTrackBurn(Mainnet.EASY_TRACK).cancelMotions(ids_);
            }
            assertTrue(motionAbsent(id)); assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),balance); assertEq(IBurnToken(v.shares).totalSupply(),supply);
            IEasyTrackBurn et=IEasyTrackBurn(Mainnet.EASY_TRACK); uint256 duration=et.motionDuration(); vm.warp(block.timestamp+duration+1);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,10e18))),"MOTION_NOT_FOUND"); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_real_ldo_snapshot_objection_rejects_without_burn() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup();
            vm.prank(Mainnet.AGENT); assertTrue(IERC20(Mainnet.LDO).transfer(outsider,10_000_000e18));
            uint256 id=burnCreate(factory,v,10e18); IEasyTrack.Motion memory m=motion(id); vm.roll(block.number+1);
            uint256 weight=IBurnToken(Mainnet.LDO).balanceOfAt(outsider,m.snapshotBlock); uint256 total=IBurnToken(Mainnet.LDO).totalSupplyAt(m.snapshotBlock);
            assertGe(weight*10000/total,m.objectionsThreshold); vm.prank(outsider); assertTrue(IERC20(Mainnet.LDO).transfer(Mainnet.AGENT,10_000_000e18));
            assertEq(IERC20(Mainnet.LDO).balanceOf(outsider),0); uint256 balance=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 supply=IBurnToken(v.shares).totalSupply();
            vm.prank(outsider); IEasyTrackBurn(Mainnet.EASY_TRACK).objectToMotion(id); assertTrue(motionAbsent(id));
            assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),balance); assertEq(IBurnToken(v.shares).totalSupply(),supply);
            vm.warp(m.startDate+m.duration); burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,10e18))),"MOTION_NOT_FOUND"); assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_objection_threshold_minus_one_exact_and_plus_one() public {
        for (uint256 asset;asset<2;++asset) for (uint256 boundary;boundary<3;++boundary) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup();
            IEasyTrackBurn et=IEasyTrackBurn(Mainnet.EASY_TRACK); uint256 total=IBurnToken(Mainnet.LDO).totalSupply();
            uint256 threshold=et.objectionsThreshold(); assertGt(threshold,0);
            uint256 minimum=(total*threshold+9999)/10000;
            assertLt((minimum-1)*10000,total*threshold); assertGe(minimum*10000,total*threshold);
            uint256 weight=minimum-1+boundary;
            assertEq(IERC20(Mainnet.LDO).balanceOf(outsider),0);
            vm.prank(Mainnet.AGENT); assertTrue(IERC20(Mainnet.LDO).transfer(outsider,weight));
            uint256 id=burnCreate(factory,v,10e18); IEasyTrack.Motion memory m=motion(id); vm.roll(block.number+1);
            assertEq(m.objectionsThreshold,threshold); assertEq(m.objectionsAmount,0);
            assertEq(IBurnToken(Mainnet.LDO).balanceOfAt(outsider,m.snapshotBlock),weight);
            assertEq(IBurnToken(Mainnet.LDO).totalSupplyAt(m.snapshotBlock),total);
            uint256 balance=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 supply=IBurnToken(v.shares).totalSupply();
            vm.prank(outsider); et.objectToMotion(id); assertTrue(et.objections(id,outsider));
            if (boundary==0) {
                assertFalse(motionAbsent(id)); assertEq(motion(id).objectionsAmount,weight);
                burnEtRefused(v,outsider,abi.encodeCall(IEasyTrackBurn.objectToMotion,(id)),"ALREADY_OBJECTED");
            } else assertTrue(motionAbsent(id));
            assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),balance); assertEq(IBurnToken(v.shares).totalSupply(),supply);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_snapshot_transfers_no_weight_and_multiple_objectors() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup();
            IEasyTrackBurn et=IEasyTrackBurn(Mainnet.EASY_TRACK);
            uint256 total=IBurnToken(Mainnet.LDO).totalSupply();
            uint256 minimum=(total*et.objectionsThreshold()+9999)/10000; assertGt(minimum,1);
            address second=makeAddr("second snapshot objector"); address late=makeAddr("post snapshot recipient");
            assertEq(IERC20(Mainnet.LDO).balanceOf(outsider),0); assertEq(IERC20(Mainnet.LDO).balanceOf(second),0);
            assertEq(IERC20(Mainnet.LDO).balanceOf(late),0);
            vm.startPrank(Mainnet.AGENT); assertTrue(IERC20(Mainnet.LDO).transfer(outsider,minimum-1));
            assertTrue(IERC20(Mainnet.LDO).transfer(second,1)); vm.stopPrank();
            uint256 id=burnCreate(factory,v,10e18); IEasyTrack.Motion memory m=motion(id); vm.roll(block.number+1);
            vm.prank(outsider); assertTrue(IERC20(Mainnet.LDO).transfer(late,minimum-1));
            vm.prank(second); assertTrue(IERC20(Mainnet.LDO).transfer(late,1));
            assertEq(IERC20(Mainnet.LDO).balanceOf(outsider),0); assertEq(IERC20(Mainnet.LDO).balanceOf(second),0);
            assertEq(IERC20(Mainnet.LDO).balanceOf(late),minimum);
            assertEq(IBurnToken(Mainnet.LDO).balanceOfAt(outsider,m.snapshotBlock),minimum-1);
            assertEq(IBurnToken(Mainnet.LDO).balanceOfAt(second,m.snapshotBlock),1);
            assertEq(IBurnToken(Mainnet.LDO).balanceOfAt(late,m.snapshotBlock),0);
            burnEtRefused(v,late,abi.encodeCall(IEasyTrackBurn.objectToMotion,(id)),"NOT_ENOUGH_BALANCE");
            assertFalse(et.objections(id,late));
            uint256 balance=IERC20(v.shares).balanceOf(address(firstLoss)); uint256 supply=IBurnToken(v.shares).totalSupply();
            vm.prank(outsider); et.objectToMotion(id); assertEq(motion(id).objectionsAmount,minimum-1);
            assertTrue(et.objections(id,outsider)); assertFalse(et.objections(id,second));
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrackBurn.objectToMotion,(id)),"ALREADY_OBJECTED");
            vm.prank(second); et.objectToMotion(id); assertTrue(motionAbsent(id)); assertTrue(et.objections(id,second));
            assertFalse(et.objections(id,late));
            assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),balance); assertEq(IBurnToken(v.shares).totalSupply(),supply);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_MAIN08_both_real_shares_role_factory_pause_failures_preserve_motion_and_retry() public {
        for (uint256 asset;asset<2;++asset) for (uint256 failure;failure<4;++failure) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup(); uint256 id=burnCreate(factory,v,10e18);
            IEasyTrack.Motion memory m=motion(id); vm.warp(m.startDate+m.duration); IEasyTrackBurn et=IEasyTrackBurn(Mainnet.EASY_TRACK);
            bytes32[] memory keys=new bytes32[](1); keys[0]=FIRST_LOSS_BURN; bool[] memory member=new bool[](1);
            if (failure==0) { vm.prank(address(firstLoss)); modifier_.assignRoles(Mainnet.ET_EXECUTOR,keys,member); }
            else if (failure==1) { vm.prank(Mainnet.VOTING); et.removeEVMScriptFactory(address(factory)); }
            else if (failure==2) { assertTrue(et.hasRole(keccak256("PAUSE_ROLE"),Mainnet.VOTING)); vm.prank(Mainnet.VOTING); et.pause(); }
            else { vm.startPrank(Mainnet.VOTING); et.removeEVMScriptFactory(address(factory)); et.addEVMScriptFactory(address(factory),abi.encodePacked(address(modifier_),IERC20.transfer.selector)); vm.stopPrank(); }
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,10e18))),failure==1 ? "EVM_SCRIPT_FACTORY_NOT_FOUND" : failure==2 ? "Pausable: paused" : failure==3 ? "HAS_NO_PERMISSIONS" : "");
            if (failure==0) { member[0]=true; vm.prank(address(firstLoss)); modifier_.assignRoles(Mainnet.ET_EXECUTOR,keys,member); }
            else if (failure==1) { vm.prank(Mainnet.VOTING); et.addEVMScriptFactory(address(factory),abi.encodePacked(address(modifier_),IRoles.execTransactionWithRole.selector)); }
            else if (failure==2) { vm.prank(Mainnet.VOTING); et.unpause(); }
            else { vm.startPrank(Mainnet.VOTING); et.removeEVMScriptFactory(address(factory)); et.addEVMScriptFactory(address(factory),abi.encodePacked(address(modifier_),IRoles.execTransactionWithRole.selector)); vm.stopPrank(); }
            burnEnact(v,id,10e18); assertTrue(vm.revertToState(snap));
        }
    }

    function test_MAIN08_both_real_shares_excess_balance_enactment_rollback_topup_retry_and_full_burn() public {
        for (uint256 asset;asset<2;++asset) {
            uint256 snap=vm.snapshotState(); Venue memory v=venue(asset==1); SepoliaFirstLossBurnFactory factory=burnSetup();
            uint256 amount=IERC20(v.shares).balanceOf(address(firstLoss))+1; uint256 id=burnCreate(factory,v,amount);
            IEasyTrack.Motion memory m=motion(id); vm.warp(m.startDate+m.duration);
            burnEtRefused(v,outsider,abi.encodeCall(IEasyTrack.enactMotion,(id,abi.encode(v.shares,amount))),"");
            uint256 growthBefore=IERC20(v.shares).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE);
            vm.prank(Mainnet.GROWTH_COMMITTEE_SAFE); assertTrue(IERC20(v.shares).transfer(address(firstLoss),1));
            assertEq(IERC20(v.shares).balanceOf(Mainnet.GROWTH_COMMITTEE_SAFE),growthBefore-1); assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),amount);
            burnEnact(v,id,amount); assertEq(IERC20(v.shares).balanceOf(address(firstLoss)),0); assertTrue(vm.revertToState(snap));
        }
    }

}
