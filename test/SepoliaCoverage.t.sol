// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {SepoliaCurrentStandFixture, IStandSettlement} from "./SepoliaCurrentStand.t.sol";
import {ISafe} from "../src/interfaces/ISafe.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IERC20} from "../src/interfaces/Tokens.sol";
import {MockAragonAgent} from "../src/mocks/MockAragonAgent.sol";
import {MockEasyTrack} from "../src/mocks/MockEasyTrack.sol";
import {MockEVMScriptExecutor} from "../src/mocks/MockEVMScriptExecutor.sol";
import {SepoliaToken, SepoliaShares, SepoliaRedeemQueue, SepoliaEasyTrack, SepoliaFirstLossBurnFactory} from "../src/mocks/SepoliaStand.sol";
import {CoWOrder, IOrderSigner, ICoWFallback, IComposableCoW} from "../script/sepolia/CoWInterfaces.sol";
import {Call, EVMScriptLib} from "../src/exec/SafeExec.sol";

interface ICoverageSafe {
    function getModulesPaginated(address start, uint256 size) external view returns (address[] memory, address);
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation) external returns (bool, bytes memory);
}

interface ICoverageSigner {
    function signing() external view returns (address);
    function deployedAt() external view returns (address);
    function domainSeparator() external view returns (bytes32);
}

abstract contract SepoliaCoverageFixture is SepoliaCurrentStandFixture {
    bytes32 internal constant GUARD_SLOT = keccak256("guard_manager.guard.address");
    bytes32 internal constant HANDLER_SLOT = keccak256("fallback_manager.handler.address");

    function balance(address t, address account) internal view returns (uint256) { return IERC20(t).balanceOf(account); }
    function budget(bytes32 key) internal view returns (uint128 b) { (,,, b,) = operator.allowances(key); }
    function allowanceHash(bytes32 key) internal view returns (bytes32) {
        (uint128 r, uint128 m, uint64 p, uint128 b, uint64 t) = operator.allowances(key);
        return keccak256(abi.encode(r,m,p,b,t));
    }
    function transferData(address to, uint256 amount) internal pure returns (bytes memory) { return abi.encodeCall(IERC20.transfer,(to,amount)); }
    function roleData(address to, bytes memory data, uint8 operation, bytes32 key, bool revertOnFailure) internal pure returns (bytes memory) {
        return abi.encodeCall(IRoles.execTransactionWithRole,(to,0,data,operation,key,revertOnFailure));
    }
    function reject(address member, IRoles mod, bytes32 key, address to, bytes memory data, uint8 operation, uint8 status) internal {
        vm.prank(member);
        (bool ok, bytes memory ret) = address(mod).call(roleData(to,data,operation,key,true));
        assertFalse(ok); assertEq(bytes4(ret),CONDITION_VIOLATION);
        (uint8 actual,) = abi.decode(sliceError(ret),(uint8,bytes32));
        assertEq(actual,status,"Wrong permission condition");
    }
    function sliceError(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for(uint256 i; i<result.length; ++i) result[i]=data[i+4];
    }
    function sign(CoWOrder.Data memory o) internal {
        exec(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(90 days),100)),1);
    }
    function unsign(CoWOrder.Data memory o,address member,bytes32 key) internal {
        exec(member,ordersRoles,key,d("orderSigner"),abi.encodeCall(IOrderSigner.unsignOrder,(o)),1);
    }
    function create(IComposableCoW.Params memory p) internal {
        exec(committee,ordersRoles,ordersOperator,d("composableCow"),abi.encodeCall(IComposableCoW.createWithContext,(p,d("timestampFactory"),bytes(""),true)),0);
    }
    function scheduled(uint256 parts,uint256 spacing,uint256 start,bytes32 salt) internal view returns(IComposableCoW.Params memory) {
        return IComposableCoW.Params(d("twap"),salt,abi.encode(token("weth"),token("usdc"),asset,uint256(0.005 ether),uint256(1),start,parts,spacing,uint256(0),bytes32(0)));
    }
    function part(IComposableCoW.Params memory p) internal view returns(CoWOrder.Data memory,bytes memory) {
        return IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
    }
    function remove(IComposableCoW.Params memory p,address member,bytes32 key) internal {
        exec(member,ordersRoles,key,d("composableCow"),abi.encodeCall(IComposableCoW.remove,(keccak256(abi.encode(p)))),0);
    }
    function invalidSignature(address account,bytes32 digest,bytes memory sig) internal view {
        (bool ok,bytes memory result)=account.staticcall(abi.encodeCall(ICoWFallback.isValidSignature,(digest,sig)));
        assertTrue(!ok||result.length!=32||abi.decode(result,(bytes4))!=bytes4(0x1626ba7e),"Invalid signature must not return magic");
    }
    function settleAmount(CoWOrder.Data memory o,uint256 executed,bytes memory signature,bool conditional,uint256 output) internal {
        address[] memory tokens=new address[](2); tokens[0]=o.sellToken;tokens[1]=o.buyToken;
        uint256[] memory prices=new uint256[](2);prices[0]=output;prices[1]=o.sellAmount;
        uint256 flags=(conditional ? 2 : 3)<<5;
        if(o.kind==keccak256("buy")) flags|=1;
        if(o.partiallyFillable) flags|=2;
        IStandSettlement.Trade[] memory trades=new IStandSettlement.Trade[](1);
        trades[0]=IStandSettlement.Trade(0,1,o.receiver,o.sellAmount,o.buyAmount,o.validTo,o.appData,o.feeAmount,flags,executed,abi.encodePacked(orders,signature));
        IStandSettlement.Interaction[][3] memory interactions;
        for(uint256 i;i<3;++i) interactions[i]=new IStandSettlement.Interaction[](0);
        vm.prank(solver);settlement.settle(tokens,prices,trades,interactions);
    }
    function motion(address share,uint256 amount) internal returns(uint256 id,bytes memory input) {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));id=et.motionsCount();input=abi.encode(share,amount);
        committeeCall(address(et),abi.encodeCall(et.createMotion,(a("burnFactory"),input)));
    }
    function configuration() internal view returns(bytes32 result) {
        address[5] memory safes=[committee,emergency,asset,orders,firstLoss];
        for(uint256 i;i<safes.length;++i){
            (address[] memory mods,address next)=ICoverageSafe(safes[i]).getModulesPaginated(address(1),100);
            result=keccak256(abi.encode(result,ISafe(payable(safes[i])).getOwners(),ISafe(payable(safes[i])).getThreshold(),mods,next,vm.load(safes[i],GUARD_SLOT),vm.load(safes[i],HANDLER_SLOT),vm.load(safes[i],bytes32(0))));
        }
        for(uint256 i;i<2;++i) result=keccak256(abi.encode(result,IERC20(token(i==0?"weth":"usdc")).allowance(orders,d("vaultRelayer"))));
    }
    function committeeExecute(address to,bytes memory data,uint8 operation,uint256 safeGas) internal returns(bool) {
        bytes memory sig=abi.encodePacked(bytes32(uint256(uint160(controller))),bytes32(0),uint8(1));
        vm.prank(controller);
        return ISafe(payable(committee)).execTransaction(to,0,data,operation,safeGas,0,0,address(0),payable(address(0)),sig);
    }
}

contract SepoliaConfigurationCoverageTest is SepoliaCoverageFixture {
    function test_CFG_exact_owners_thresholds_modules_guards_handlers_and_runtimes() public view {
        address[5] memory safes=[committee,emergency,asset,orders,firstLoss];
        for(uint256 i;i<5;++i){
            address[] memory owners=ISafe(payable(safes[i])).getOwners();assertEq(owners.length,1);
            assertEq(owners[0],i<2?controller:a("voting"));assertEq(ISafe(payable(safes[i])).getThreshold(),1);
            (address[] memory mods,address next)=ICoverageSafe(safes[i]).getModulesPaginated(address(1),1);
            uint256 count;
            while(true){
                for(uint256 j;j<mods.length;++j){
                    ++count;
                    assertTrue(i==2 ? (mods[j]==address(operator)||mods[j]==address(safety)) : i==3 ? mods[j]==address(ordersRoles) : i==4 && mods[j]==address(firstLossRoles));
                }
                if(next==address(1))break;
                (mods,next)=ICoverageSafe(safes[i]).getModulesPaginated(next,1);
            }
            assertEq(count,i<2?0:i==2?2:1);
            assertEq(vm.load(safes[i],GUARD_SLOT),bytes32(0));
            assertEq(address(uint160(uint256(vm.load(safes[i],HANDLER_SLOT)))),i==3?d("fallbackHandler"):address(0));
            assertEq(address(uint160(uint256(vm.load(safes[i],bytes32(0))))),d(i==0?"safe13":"safe15"));
        }
        string memory network=vm.readFile("policy/constellation/sepolia/network.json");
        string[13] memory names=["safe15","safe13","safeProxyFactory","moduleProxyFactory","roles","settlement","vaultRelayer","fallbackHandler","composableCow","twap","timestampFactory","orderSigner","weth"];
        for(uint256 i;i<names.length;++i) assertEq(d(names[i]).codehash,vm.parseJsonBytes32(network,string.concat(".contracts.",names[i],".codeHash")));
        address[4] memory modifiers_=[address(operator),address(safety),address(ordersRoles),address(firstLossRoles)];
        bytes memory proxy=abi.encodePacked(hex"363d3d373d3d3d363d73",d("roles"),hex"5af43d82803e903d91602b57fd5bf3");
        for(uint256 i;i<4;++i) assertEq(modifiers_[i].code,proxy);
        assertEq(ICoverageSigner(d("orderSigner")).signing(),address(settlement));
        assertEq(ICoverageSigner(d("orderSigner")).domainSeparator(),settlement.domainSeparator());
        assertEq(ICoverageSigner(d("orderSigner")).deployedAt(),d("orderSigner"));
    }
    function test_CFG_exact_initial_token_approvals_and_fixture_wiring() public view {
        address[5] memory safes=[committee,emergency,asset,orders,firstLoss];
        // Circle USDC consumes even a max allowance; the runner derives its remainder from Approval/Trade history.
        uint256 usdcApproval=vm.envUint("SEPOLIA_EXPECTED_USDC_ALLOWANCE");
        for(uint256 i;i<2;++i)for(uint256 j;j<5;++j) assertEq(IERC20(token(i==0?"weth":"usdc")).allowance(safes[j],d("vaultRelayer")),j==3?(i==0?type(uint256).max:usdcApproval):0);
        for(uint256 i;i<2;++i){
            SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));
            SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            assertEq(share.queue(),address(queue));assertEq(address(queue.share()),address(share));assertEq(queue.controller(),controller);
            assertEq(address(queue.asset()),a(i==0?"usdClaimAsset":"ethClaimAsset"));
            assertEq(share.controller(),controller);assertEq(queue.asset().controller(),address(queue));
        }
        SepoliaFirstLossBurnFactory factory=SepoliaFirstLossBurnFactory(a("burnFactory"));
        assertEq(factory.trustedCaller(),committee);assertEq(address(factory.modifier_()),address(firstLossRoles));
        assertEq(factory.usdShare(),a("usdShare"));assertEq(factory.ethShare(),a("ethShare"));
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));
        assertEq(et.voting(),a("voting"));assertTrue(et.evmScriptFactories(address(factory)));
        assertEq(address(et.evmScriptExecutor()),a("easyTrackExecutor"));assertEq(et.ldoToken().balanceOf(controller),1000 ether);
    }
    function test_CFG_approved_hash_nonce_replay_wrong_safe_chain_and_signatures() public {
        bytes memory data=roleData(token("weth"),transferData(orders,1),0,assetOperator,true);
        ISafe s=ISafe(payable(committee));uint256 nonce=s.nonce();address zero=address(0);
        bytes32 hash=s.getTransactionHash(address(operator),0,data,0,0,0,0,zero,zero,nonce);
        vm.prank(controller);s.approveHash(hash);
        bytes memory sig=abi.encodePacked(bytes32(uint256(uint160(controller))),bytes32(0),uint8(1));
        deal(token("weth"),asset,1);
        assertTrue(s.execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),sig));
        assertEq(s.nonce(),nonce+1);
        vm.expectRevert("GS025");s.execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),sig);
        vm.expectRevert("GS025");ISafe(payable(emergency)).execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),sig);
        hash=s.getTransactionHash(address(operator),0,data,0,0,0,0,zero,zero,s.nonce());vm.prank(controller);s.approveHash(hash);
        vm.chainId(1);vm.expectRevert("GS025");s.execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),sig);vm.chainId(11155111);
        vm.expectRevert("GS020");s.execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),"");
        bytes memory wrong=abi.encodePacked(bytes32(uint256(uint160(address(0xBAD)))),bytes32(0),uint8(1));
        vm.expectRevert();s.execTransaction(address(operator),0,data,0,0,0,0,zero,payable(zero),wrong);
    }
    function actorMatrix(uint256 j) internal {
        address[6] memory actors=[committee,emergency,controller,address(0xBAD),a("voting"),a("easyTrackExecutor")];
        bytes32[9] memory keys=[assetOperator,ordersOperator,assetEmergency,ordersEmergency,bytes32("operator"),bytes32("emergency"),bytes32("governance"),bytes32("first-loss-burn"),bytes32("first-loss")];
        IRoles[4] memory mods=[operator,safety,ordersRoles,firstLossRoles];
        for(uint256 i;i<6;++i)for(uint256 k;k<9;++k){
            bool allowed=(j==0&&actors[i]==committee&&keys[k]==assetOperator)||(j==1&&actors[i]==emergency&&keys[k]==assetEmergency)||(j==2&&((actors[i]==committee&&keys[k]==ordersOperator)||(actors[i]==emergency&&keys[k]==ordersEmergency)));
            uint256 snapshot=vm.snapshotState();deal(token("weth"),asset,10);deal(token("weth"),orders,10);
            address recipient=j==0?orders:j==1?a("agent"):asset;
            address target=token("weth");bytes memory payload=transferData(recipient,1);
            if(j==0&&keys[k]==bytes32("governance")){target=address(operator);payload=abi.encodeCall(IRoles.revokeFunction,(assetOperator,token("weth"),IERC20.transfer.selector));allowed=actors[i]==a("easyTrackExecutor");}
            if(j==3&&keys[k]==bytes32("first-loss")){target=a("usdQueue");payload=abi.encodeCall(SepoliaRedeemQueue.redeem,(1));allowed=actors[i]==committee;}
            if(j==3&&keys[k]==bytes32("first-loss-burn")){target=a("usdShare");payload=abi.encodeWithSignature("burn(uint256)",1);allowed=actors[i]==a("easyTrackExecutor");}
            vm.prank(actors[i]);(bool ok,bytes memory ret)=address(mods[j]).call(roleData(target,payload,0,keys[k],true));
            if(allowed){assertTrue(ok);assertTrue(abi.decode(ret,(bool)));}else{assertFalse(ok);assertTrue(bytes4(ret)!=bytes4(keccak256("ModuleTransactionFailed()")),"Must fail before token execution");}
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_CFG_actor_matrix_asset_operator() public { actorMatrix(0); }
    function test_CFG_actor_matrix_asset_safety() public { actorMatrix(1); }
    function test_CFG_actor_matrix_orders() public { actorMatrix(2); }
    function test_CFG_actor_matrix_first_loss() public { actorMatrix(3); }

}

contract SepoliaFundingCoverageTest is SepoliaCoverageFixture {
    function test_FUND_first_transfer_logs_nonces_and_unchanged_configuration() public {
        uint256 amount=0.01 ether;uint256 ab=balance(token("weth"),asset);uint256 ob=balance(token("weth"),orders);
        assertGe(ab,amount,"Public stand must be funded");bytes32 beforeConfig=configuration();uint256 n=ISafe(payable(committee)).nonce();uint256 an=ISafe(payable(asset)).nonce();uint256 b=budget(bytes32("orders_weth"));
        vm.recordLogs();committeeCall(address(operator),roleData(token("weth"),transferData(orders,amount),0,assetOperator,true));
        Vm.Log[] memory logs=vm.getRecordedLogs();bool transfer;bool safeSuccess;
        for(uint256 i;i<logs.length;++i){
            if(logs[i].emitter==token("weth")&&logs[i].topics[0]==keccak256("Transfer(address,address,uint256)")){
                assertEq(address(uint160(uint256(logs[i].topics[1]))),asset);assertEq(address(uint160(uint256(logs[i].topics[2]))),orders);assertEq(abi.decode(logs[i].data,(uint256)),amount);transfer=true;
            }
            if(logs[i].emitter==committee&&logs[i].topics[0]==keccak256("ExecutionSuccess(bytes32,uint256)"))safeSuccess=true;
            assertTrue(logs[i].topics[0]!=keccak256("ExecutionFailure(bytes32,uint256)"));
        }
        assertTrue(transfer);assertTrue(safeSuccess);assertEq(balance(token("weth"),asset),ab-amount);assertEq(balance(token("weth"),orders),ob+amount);
        assertEq(budget(bytes32("orders_weth")),b-amount);assertEq(ISafe(payable(committee)).nonce(),n+1);assertEq(ISafe(payable(asset)).nonce(),an);assertEq(configuration(),beforeConfig);
    }
    function test_FUND_receiver_checks_have_unspent_budget_and_exact_error() public {
        address[4] memory receivers=[address(0),controller,a("agent"),firstLoss];
        for(uint256 t;t<2;++t){address token_=token(t==0?"weth":"usdc");deal(token_,asset,100);
            bytes32 state=allowanceHash((t==0?bytes32("orders_weth"):bytes32("orders_usdc")));uint256 before=balance(token_,asset);
            for(uint256 i;i<receivers.length;++i)reject(committee,operator,assetOperator,token_,transferData(receivers[i],1),0,7);
            assertEq(balance(token_,asset),before);assertEq(allowanceHash((t==0?bytes32("orders_weth"):bytes32("orders_usdc"))),state);
        }
    }
    function test_FUND_wrong_token_selector_operation_value_and_malformed_data() public {
        deal(token("weth"),asset,100);
        reject(committee,operator,assetOperator,a("usdShare"),transferData(orders,1),0,2);
        reject(committee,operator,assetOperator,token("weth"),abi.encodeCall(IERC20.approve,(orders,1)),0,3);
        reject(committee,operator,assetOperator,token("weth"),transferData(orders,1),1,1);
        vm.prank(committee);vm.expectRevert();operator.execTransactionWithRole(token("weth"),1,transferData(orders,1),0,assetOperator,true);
        vm.prank(committee);vm.expectRevert();operator.execTransactionWithRole(token("weth"),0,hex"a9059cbb",0,assetOperator,true);
    }
    function test_FUND_partial_transfers_independent_decimals_zero_and_return_no_refund() public {
        bytes32[2] memory keys=[bytes32("orders_weth"),bytes32("orders_usdc")];
        for(uint256 t;t<2;++t){address token_=token(t==0?"weth":"usdc");uint256 cap=budget(keys[t]);deal(token_,asset,cap+1);
            bytes32 other=allowanceHash(keys[1-t]);uint256 start=balance(token_,orders);
            exec(committee,operator,assetOperator,token_,transferData(orders,0),0);assertEq(budget(keys[t]),cap);
            exec(committee,operator,assetOperator,token_,transferData(orders,1),0);
            exec(committee,operator,assetOperator,token_,transferData(orders,cap/2),0);
            exec(committee,operator,assetOperator,token_,transferData(orders,cap-cap/2-1),0);
            assertEq(budget(keys[t]),0);assertEq(balance(token_,orders),start+cap);
            reject(committee,operator,assetOperator,token_,transferData(orders,1),0,17);
            exec(committee,ordersRoles,ordersOperator,token_,transferData(asset,cap),0);
            assertEq(budget(keys[t]),0);assertEq(allowanceHash(keys[1-t]),other);
            address[3] memory invalid=[controller,a("agent"),firstLoss];
            for(uint256 i;i<3;++i)reject(committee,ordersRoles,ordersOperator,token_,transferData(invalid[i],1),0,7);
        }
    }
    function test_FUND_refill_before_exact_after_multiple_periods_and_cap() public {
        for(uint256 t;t<2;++t){
            address token_=token(t==0?"weth":"usdc");bytes32 key=(t==0?bytes32("orders_weth"):bytes32("orders_usdc"));
            (uint128 refill,uint128 maximum,uint64 period,uint128 available,)=operator.allowances(key);
            assertGt(available,0);
            deal(token_,asset,uint256(maximum)*3);exec(committee,operator,assetOperator,token_,transferData(orders,available),0);
            assertEq(budget(key),0);(,,,,uint64 timestamp)=operator.allowances(key);
            uint256 snap=vm.snapshotState();
            for(uint256 n;n<4;++n){
                vm.warp(uint256(timestamp)+period-1);reject(committee,operator,assetOperator,token_,transferData(orders,1),0,17);
                vm.warp(uint256(timestamp)+period+(n==0?0:n==1?1:n==2?uint256(period)*2:uint256(period)*10));
                exec(committee,operator,assetOperator,token_,transferData(orders,refill),0);assertEq(budget(key),maximum-refill);
                reject(committee,operator,assetOperator,token_,transferData(orders,1),0,17);
                assertTrue(vm.revertToState(snap));snap=vm.snapshotState();
            }
        }
    }
    function test_FUND_failed_token_call_rolls_back_allowance_and_safe_outcomes() public {
        address w=token("weth");deal(w,asset,0);bytes32 state=allowanceHash(bytes32("orders_weth"));uint256 ob=balance(w,orders);
        permissionDenied(committee,operator,assetOperator,w,transferData(orders,1),0,bytes4(keccak256("ModuleTransactionFailed()")));
        vm.prank(committee);assertFalse(operator.execTransactionWithRole(w,0,transferData(orders,1),0,assetOperator,false));
        assertEq(allowanceHash(bytes32("orders_weth")),state);assertEq(balance(w,orders),ob);
        uint256 nonce=ISafe(payable(committee)).nonce();
        vm.expectRevert("GS013");committeeExecute(address(operator),roleData(w,transferData(orders,1),0,assetOperator,true),0,0);
        assertEq(ISafe(payable(committee)).nonce(),nonce);assertEq(allowanceHash(bytes32("orders_weth")),state);
    }
    function test_FUND_safe_failure_event_consumes_nonce_but_not_budget() public {
        address w=token("weth");deal(w,asset,0);uint256 nonce=ISafe(payable(committee)).nonce();bytes32 state=allowanceHash(bytes32("orders_weth"));uint256 ob=balance(w,orders);
        vm.recordLogs();bool ok=committeeExecute(address(operator),roleData(w,transferData(orders,1),0,assetOperator,true),0,500000);
        assertFalse(ok);assertEq(ISafe(payable(committee)).nonce(),nonce+1);assertEq(allowanceHash(bytes32("orders_weth")),state);assertEq(balance(w,orders),ob);
        Vm.Log[] memory logs=vm.getRecordedLogs();bool failed;
        for(uint256 i;i<logs.length;++i)if(logs[i].emitter==committee&&logs[i].topics[0]==keccak256("ExecutionFailure(bytes32,uint256)"))failed=true;
        assertTrue(failed);
    }
    function test_FUND_safe_success_can_wrap_false_role_result_without_transfer() public {
        address w=token("weth");deal(w,asset,0);bytes32 state=allowanceHash(bytes32("orders_weth"));uint256 ob=balance(w,orders);
        vm.prank(committee);assertFalse(operator.execTransactionWithRole(w,0,transferData(orders,1),0,assetOperator,false));
        assertTrue(committeeExecute(address(operator),roleData(w,transferData(orders,1),0,assetOperator,false),0,0));
        assertEq(allowanceHash(bytes32("orders_weth")),state);assertEq(balance(w,orders),ob);
    }
    function test_FUND_empty_duplicate_reordered_and_failing_batches_are_atomic() public {
        string memory package=vm.readFile("cache/sepolia/role-key-migration/package.json");address multisend=vm.parseJsonAddress(package,".batchExecutor.address");
        assertEq(multisend.codehash,vm.parseJsonBytes32(package,".batchExecutor.codeHash"));
        assertTrue(committeeExecute(multisend,abi.encodeWithSignature("multiSend(bytes)",bytes("")),1,0));
        for(uint256 reverse_;reverse_<2;++reverse_){
            uint256 snap=vm.snapshotState();deal(token("weth"),asset,10);uint256 before=balance(token("weth"),orders);uint256 b=budget(bytes32("orders_weth"));
            bytes memory first=roleData(token("weth"),transferData(orders,reverse_==0?1:2),0,assetOperator,true);
            bytes memory second=roleData(token("weth"),transferData(orders,reverse_==0?2:1),0,assetOperator,true);
            bytes memory batch=abi.encodePacked(uint8(0),address(operator),uint256(0),uint256(first.length),first,uint8(0),address(operator),uint256(0),uint256(second.length),second);
            assertTrue(committeeExecute(multisend,abi.encodeWithSignature("multiSend(bytes)",batch),1,0));
            assertEq(balance(token("weth"),orders),before+3);assertEq(budget(bytes32("orders_weth")),b-3);
            assertTrue(vm.revertToState(snap));
        }
        for(uint256 mode;mode<2;++mode){uint256 snap=vm.snapshotState();deal(token("weth"),asset,1);uint256 before=balance(token("weth"),orders);bytes32 state=allowanceHash(bytes32("orders_weth"));
            bytes memory good=roleData(token("weth"),transferData(orders,1),0,assetOperator,true);
            bytes memory bad=roleData(token("weth"),transferData(orders,1),0,assetOperator,mode==0);
            bytes memory batch=abi.encodePacked(uint8(0),address(operator),uint256(0),uint256(good.length),good,uint8(0),address(operator),uint256(0),uint256(bad.length),bad);
            if(mode==0){vm.expectRevert("GS013");committeeExecute(multisend,abi.encodeWithSignature("multiSend(bytes)",batch),1,0);assertEq(balance(token("weth"),orders),before);assertEq(allowanceHash(bytes32("orders_weth")),state);}
            else{assertTrue(committeeExecute(multisend,abi.encodeWithSignature("multiSend(bytes)",batch),1,0));assertEq(balance(token("weth"),orders),before+1);}
            assertTrue(vm.revertToState(snap));
        }
    }
}

contract SepoliaOrderCoverageTest is SepoliaCoverageFixture {
    function test_ORD_chain_domain_and_every_typed_field_bind_presign() public {
        CoWOrder.Data memory o=order();sign(o);bytes memory original=uid(o);
        bytes32 domainType=keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domain=keccak256(abi.encode(domainType,keccak256("Gnosis Protocol"),keccak256("v2"),block.chainid,address(settlement)));
        assertEq(domain,settlement.domainSeparator());
        bytes32 foreign=keccak256(abi.encode(domainType,keccak256("Gnosis Protocol"),keccak256("v2"),block.chainid+1,address(settlement)));
        assertEq(settlement.preSignature(abi.encodePacked(CoWOrder.digest(o,foreign),orders,o.validTo)),0);
        bytes32 otherContract=keccak256(abi.encode(domainType,keccak256("Gnosis Protocol"),keccak256("v2"),block.chainid,asset));
        assertEq(settlement.preSignature(abi.encodePacked(CoWOrder.digest(o,otherContract),orders,o.validTo)),0);
        for(uint256 i;i<12;++i){CoWOrder.Data memory changed=order();
            if(i==0)changed.sellToken=token("usdc");if(i==1)changed.buyToken=token("weth");if(i==2)changed.receiver=firstLoss;
            if(i==3)changed.sellAmount+=1;if(i==4)changed.buyAmount+=1;if(i==5)changed.validTo-=1;
            if(i==6)changed.appData=bytes32(uint256(1));if(i==7)changed.feeAmount=1;if(i==8)changed.kind=keccak256("buy");
            if(i==9)changed.partiallyFillable=true;if(i==10)changed.sellTokenBalance=keccak256("internal");if(i==11)changed.buyTokenBalance=keccak256("internal");
            assertTrue(keccak256(uid(changed))!=keccak256(original));assertEq(settlement.preSignature(uid(changed)),0);
        }
        assertGt(settlement.preSignature(original),0);
    }
    function test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders() public {
        uint256 snap=vm.snapshotState();
        for(uint256 actor;actor<2;++actor){CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;
            address member=actor==0?committee:emergency;bytes32 key=actor==0?ordersOperator:ordersEmergency;
            if(actor==0)sign(o);else{o.receiver=a("agent");exec(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 days),0)),1);}
            CoWOrder.Data memory other=order();other.buyAmount=51;sign(other);
            uint256 sold=balance(o.sellToken,orders);uint256 received=balance(o.buyToken,o.receiver);
            for(uint256 n;n<2;++n){unsign(o,member,key);assertEq(settlement.preSignature(uid(o)),0);assertEq(settlement.filledAmount(uid(o)),0);assertGt(settlement.preSignature(uid(other)),0);}
            vm.expectRevert("GPv2: order not presigned");settleAmount(o,100,"",false,50);
            assertEq(balance(o.sellToken,orders),sold);assertEq(balance(o.buyToken,o.receiver),received);
            assertTrue(vm.revertToState(snap));snap=vm.snapshotState();
        }
    }
    function test_ORD_token_direction_kind_fill_mode_and_same_token_matrix() public {
        for(uint256 direction;direction<2;++direction)for(uint256 kind;kind<2;++kind)for(uint256 partial_;partial_<2;++partial_){
            CoWOrder.Data memory o=order();if(direction==1){o.sellToken=token("usdc");o.buyToken=token("weth");}
            o.kind=(kind==0?keccak256("sell"):keccak256("buy"));o.partiallyFillable=partial_==1;o.sellAmount=100+direction*10+kind*2+partial_;o.buyAmount=1;
            sign(o);assertGt(settlement.preSignature(uid(o)),0);unsign(o,committee,ordersOperator);assertEq(settlement.preSignature(uid(o)),0);
        }
        // The reduced profile allows equal listed tokens. Record this behavior, not an invented refusal.
        CoWOrder.Data memory same=order();same.buyToken=same.sellToken;sign(same);assertGt(settlement.preSignature(uid(same)),0);
    }
    function test_ORD_each_invalid_typed_field_fails_without_presign() public {
        for(uint256 i;i<11;++i){
            CoWOrder.Data memory o=order();
            if(i==0)o.sellToken=controller;if(i==1)o.buyToken=controller;if(i==2)o.receiver=address(0);if(i==3)o.receiver=orders;
            if(i==4)o.sellAmount=0;if(i==5)o.buyAmount=0;if(i==6)o.kind=keccak256("invalid");if(i==7)o.appData=bytes32(uint256(1));
            if(i==8)o.sellTokenBalance=keccak256("internal");if(i==9)o.sellTokenBalance=keccak256("external");if(i==10)o.buyTokenBalance=keccak256("internal");
            denied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),0)),1);
            assertEq(settlement.preSignature(uid(o)),0);
        }
        CoWOrder.Data memory o=order();
        permissionDenied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),0)),0,bytes4(keccak256("ModuleTransactionFailed()")));
        denied(committee,ordersRoles,ordersOperator,controller,abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),0)),1);
    }
    function test_ORD_expiry_duration_strict_boundaries_and_expired_settlement() public {
        uint32[3] memory durations=[uint32(1),uint32(1 hours),uint32(90 days)];
        for(uint256 i;i<3;++i){
            CoWOrder.Data memory o=order();o.validTo=uint32(vm.getBlockTimestamp()+durations[i]-1);
            exec(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,durations[i],0)),1);
            assertGt(settlement.preSignature(uid(o)),0);
            o.validTo+=1;permissionDenied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,durations[i],0)),1,bytes4(keccak256("ModuleTransactionFailed()")));
            o.validTo+=1;permissionDenied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,durations[i],0)),1,bytes4(keccak256("ModuleTransactionFailed()")));
        }
        CoWOrder.Data memory o=order();
        denied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(0),0)),1);
        denied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(90 days+1),0)),1);
        o.validTo=uint32(vm.getBlockTimestamp()-1);sign(o);assertGt(settlement.preSignature(uid(o)),0);
        vm.expectRevert("GPv2: order expired");settle(o,"",false,1);assertEq(settlement.filledAmount(uid(o)),0);
    }
    function test_ORD_fee_ceiling_rounding_plus_one_and_overflow() public {
        uint256[4] memory amounts=[uint256(1),uint256(9999),uint256(10000),uint256(10001)];
        for(uint256 i;i<4;++i)for(uint256 bp;bp<2;++bp){
            CoWOrder.Data memory o=order();o.sellAmount=amounts[i];uint256 feeBP=bp==0?0:100;
            uint256 maximum=amounts[i]*feeBP/10000+1;
            o.feeAmount=maximum;exec(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),feeBP)),1);assertGt(settlement.preSignature(uid(o)),0);
            o.feeAmount=maximum-1;exec(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),feeBP)),1);assertGt(settlement.preSignature(uid(o)),0);
            o.feeAmount=maximum+1;permissionDenied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),feeBP)),1,bytes4(keccak256("ModuleTransactionFailed()")));assertEq(settlement.preSignature(uid(o)),0);
        }
        CoWOrder.Data memory o=order();o.sellAmount=type(uint256).max;
        permissionDenied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),100)),1,bytes4(keccak256("ModuleTransactionFailed()")));
        denied(committee,ordersRoles,ordersOperator,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(order(),uint32(1 hours),101)),1);
    }
    function test_ORD_uid_mutations_cancellation_isolation_repeated_and_resign() public {
        CoWOrder.Data memory o=order();sign(o);bytes memory original=uid(o);
        for(uint256 i;i<7;++i){
            CoWOrder.Data memory changed=order();if(i==0)changed.sellAmount+=1;if(i==1)changed.buyAmount+=1;if(i==2)changed.validTo-=1;
            if(i==3)changed.receiver=orders;if(i==4)changed.sellToken=token("usdc");if(i==5)changed.partiallyFillable=true;if(i==6)changed.kind=keccak256("buy");
            assertTrue(keccak256(uid(changed))!=keccak256(original));assertEq(settlement.preSignature(uid(changed)),0);
        }
        bytes32 digest=CoWOrder.digest(o,settlement.domainSeparator());
        assertEq(settlement.preSignature(abi.encodePacked(digest,asset,o.validTo)),0);
        assertEq(settlement.preSignature(abi.encodePacked(CoWOrder.digest(o,bytes32(0)),orders,o.validTo)),0);
        CoWOrder.Data memory second=order();second.buyAmount+=1;sign(second);
        unsign(second,committee,ordersOperator);assertGt(settlement.preSignature(original),0);unsign(second,committee,ordersOperator);
        unsign(o,emergency,ordersEmergency);assertEq(settlement.preSignature(original),0);
        sign(o);assertGt(settlement.preSignature(original),0);unsign(o,committee,ordersOperator);
        CoWOrder.Data memory recovery=order();recovery.receiver=a("agent");
        exec(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(recovery,uint32(1 days),0)),1);
        unsign(recovery,emergency,ordersEmergency);assertEq(settlement.preSignature(uid(recovery)),0);
    }
}

contract SepoliaSettlementCoverageTest is SepoliaCoverageFixture {
    function test_SETTLE_overfill_before_and_after_partial_fill_is_atomic() public {
        uint256 snap=vm.snapshotState();
        for(uint256 kind;kind<2;++kind){CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;o.partiallyFillable=true;o.kind=kind==0?keccak256("sell"):keccak256("buy");
            deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);sign(o);
            uint256 total=kind==0?100:50;uint256 first=kind==0?60:30;
            uint256 received=balance(o.buyToken,asset);
            vm.expectRevert("GPv2: order filled");settleAmount(o,total+1,"",false,50);
            assertEq(settlement.filledAmount(uid(o)),0);assertEq(balance(o.sellToken,orders),1000);assertEq(balance(o.buyToken,asset),received);
            settleAmount(o,first,"",false,50);assertEq(settlement.filledAmount(uid(o)),first);
            assertEq(balance(o.sellToken,orders),940);assertEq(balance(o.buyToken,asset),received+30);
            vm.expectRevert("GPv2: order filled");settleAmount(o,total-first+1,"",false,50);
            assertEq(settlement.filledAmount(uid(o)),first);assertEq(balance(o.sellToken,orders),940);assertEq(balance(o.buyToken,asset),received+30);
            settleAmount(o,total-first,"",false,50);assertEq(settlement.filledAmount(uid(o)),total);
            assertEq(balance(o.sellToken,orders),900);assertEq(balance(o.buyToken,asset),received+50);
            assertTrue(vm.revertToState(snap));snap=vm.snapshotState();
        }
    }
    function test_SETTLE_approval_spender_amount_matrix_and_zero_allowance_transfer() public {
        address[5] memory spenders=[d("vaultRelayer"),controller,asset,orders,address(0)];
        uint256[3] memory amounts=[uint256(0),uint256(1),type(uint256).max];
        for(uint256 t;t<2;++t){address token_=token(t==0?"weth":"usdc");deal(token_,orders,10);
            for(uint256 i;i<spenders.length;++i)for(uint256 j;j<amounts.length;++j){
                bytes memory payload=abi.encodeCall(IERC20.approve,(spenders[i],amounts[j]));
                uint256 before=IERC20(token_).allowance(orders,spenders[i]);
                reject(committee,ordersRoles,ordersOperator,token_,payload,0,3);reject(committee,operator,assetOperator,token_,payload,0,3);
                if(i==0&&j==0){exec(emergency,ordersRoles,ordersEmergency,token_,payload,0);assertEq(IERC20(token_).allowance(orders,spenders[i]),0);}
                else{denied(emergency,ordersRoles,ordersEmergency,token_,payload,0);assertEq(IERC20(token_).allowance(orders,spenders[i]),before);}
            }
            uint256 agentBefore=balance(token_,a("agent"));exec(emergency,ordersRoles,ordersEmergency,token_,transferData(a("agent"),1),0);
            assertEq(balance(token_,a("agent")),agentBefore+1);assertEq(balance(token_,orders),9);assertEq(IERC20(token_).allowance(orders,d("vaultRelayer")),0);
            ownerCall(orders,token_,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),7)));assertEq(IERC20(token_).allowance(orders,d("vaultRelayer")),7);
        }
    }
    function test_SETTLE_both_directions_buy_sell_partial_full_and_exact_deltas() public {
        for(uint256 direction;direction<2;++direction)for(uint256 kind;kind<2;++kind)for(uint256 partial_;partial_<2;++partial_){
            uint256 snap=vm.snapshotState();CoWOrder.Data memory o=order();
            if(direction==1){o.sellToken=token("usdc");o.buyToken=token("weth");}
            o.kind=(kind==0?keccak256("sell"):keccak256("buy"));o.partiallyFillable=partial_==1;o.sellAmount=100;o.buyAmount=50;o.feeAmount=1;
            deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);sign(o);
            uint256 soldBefore=balance(o.sellToken,orders);uint256 receivedBefore=balance(o.buyToken,asset);
            uint256 executed=o.partiallyFillable?(kind==0?50:25):100;
            settleAmount(o,executed,"",false,50);
            uint256 sold=o.partiallyFillable?50:100;uint256 bought=o.partiallyFillable?25:50;uint256 fee=o.partiallyFillable?0:1;
            assertEq(balance(o.sellToken,orders),soldBefore-sold-fee);assertEq(balance(o.buyToken,asset),receivedBefore+bought);
            assertEq(settlement.filledAmount(uid(o)),kind==0?sold:bought);
            if(o.partiallyFillable){settleAmount(o,executed,"",false,50);assertEq(settlement.filledAmount(uid(o)),kind==0?100:50);assertEq(balance(o.sellToken,orders),soldBefore-100);assertEq(balance(o.buyToken,asset),receivedBefore+50);}
            vm.expectRevert("GPv2: order filled");settleAmount(o,executed,"",false,50);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_SETTLE_missing_funds_approval_unsigned_unauthorized_and_retry() public {
        CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;
        deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);
        vm.expectRevert("GPv2: order not presigned");settleAmount(o,100,"",false,50);
        sign(o);deal(o.sellToken,orders,0);
        vm.expectRevert();settleAmount(o,100,"",false,50);assertEq(settlement.filledAmount(uid(o)),0);
        deal(o.sellToken,orders,1000);
        exec(emergency,ordersRoles,ordersEmergency,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),0)),0);
        vm.expectRevert();settleAmount(o,100,"",false,50);assertEq(settlement.filledAmount(uid(o)),0);assertEq(balance(o.sellToken,orders),1000);
        ownerCall(orders,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),type(uint256).max)));
        address original=solver;solver=address(0xBAD);vm.expectRevert("GPv2: not a solver");settleAmount(o,100,"",false,50);solver=original;
        settleAmount(o,100,"",false,50);assertEq(settlement.filledAmount(uid(o)),100);
    }
    function test_SETTLE_cancel_partial_revoke_still_live_and_zero_approval_recovery() public {
        CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;o.partiallyFillable=true;
        deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);sign(o);
        exec(emergency,ordersRoles,ordersEmergency,address(ordersRoles),abi.encodeCall(IRoles.revokeTarget,(ordersOperator,d("orderSigner"))),0);
        settleAmount(o,50,"",false,50);assertEq(settlement.filledAmount(uid(o)),50);
        unsign(o,emergency,ordersEmergency);vm.expectRevert("GPv2: order not presigned");settleAmount(o,50,"",false,50);assertEq(settlement.filledAmount(uid(o)),50);
        ownerCall(orders,address(ordersRoles),abi.encodeCall(IRoles.scopeTarget,(ordersOperator,d("orderSigner"))));
        sign(o);settleAmount(o,50,"",false,50);assertEq(settlement.filledAmount(uid(o)),100);
        sign(o);vm.expectRevert("GPv2: order filled");settleAmount(o,50,"",false,50);
        for(uint256 i;i<2;++i){address t=token(i==0?"weth":"usdc");deal(t,orders,10);uint256 before=balance(t,a("agent"));
            exec(emergency,ordersRoles,ordersEmergency,t,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),0)),0);
            denied(emergency,ordersRoles,ordersEmergency,t,abi.encodeCall(IERC20.approve,(controller,0)),0);
            exec(emergency,ordersRoles,ordersEmergency,t,transferData(a("agent"),10),0);assertEq(balance(t,a("agent")),before+10);
        }
    }
}

contract SepoliaTwapCoverageTest is SepoliaCoverageFixture {
    struct ProofPayload { bytes32[] proof; IComposableCoW.Params params; bytes offchainInput; }
    function test_TWAP_before_start_and_complete_daily_weekly_uid_schedule() public {
        uint256[3] memory counts=[uint256(2),uint256(90),uint256(12)];uint256[3] memory spacing=[uint256(1),uint256(1 days),uint256(7 days)];
        IComposableCoW cow=IComposableCoW(d("composableCow"));bytes32 domain=settlement.domainSeparator();address weth=token("weth");address usdc=token("usdc");
        for(uint256 schedule;schedule<3;++schedule){uint256 start=vm.getBlockTimestamp();IComposableCoW.Params memory p=scheduled(counts[schedule],spacing[schedule],0,bytes32(schedule+500));create(p);
            vm.warp(start-1);vm.expectRevert(abi.encodeWithSignature("OrderNotValid(string)","before twap start"));cow.getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
            bytes memory previous;
            for(uint256 i;i<counts[schedule];++i){vm.warp(start+i*spacing[schedule]);(CoWOrder.Data memory o,bytes memory sig)=cow.getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
                uint32 expiry=uint32(start+(i+1)*spacing[schedule]-1);
                CoWOrder.Data memory expected=CoWOrder.Data(weth,usdc,asset,0.005 ether,1,expiry,bytes32(0),0,keccak256("sell"),false,keccak256("erc20"),keccak256("erc20"));
                bytes memory expectedUid=abi.encodePacked(CoWOrder.digest(expected,domain),orders,expiry);
                bytes memory actualUid=abi.encodePacked(CoWOrder.digest(o,domain),orders,o.validTo);
                assertEq(actualUid,expectedUid);if(i>0)assertTrue(keccak256(actualUid)!=keccak256(previous));previous=actualUid;
                assertEq(ICoWFallback(orders).isValidSignature(CoWOrder.digest(expected,domain),sig),bytes4(0x1626ba7e));
                vm.warp(start+(i+1)*spacing[schedule]-1);(CoWOrder.Data memory last,)=cow.getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));assertEq(abi.encodePacked(CoWOrder.digest(last,domain),orders,last.validTo),expectedUid);
            }
            vm.warp(start+counts[schedule]*spacing[schedule]);vm.expectRevert(abi.encodeWithSignature("OrderNotValid(string)","after twap finish"));cow.getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
        }
    }
    function test_TWAP_changed_merkle_proof_fails_generation_signature_and_settlement() public {
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(600)));create(p);(CoWOrder.Data memory o,bytes memory sig)=part(p);
        bytes32[] memory proof=new bytes32[](1);proof[0]=bytes32(uint256(1));
        vm.expectRevert(bytes4(keccak256("ProofNotAuthed()")));IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,p,"",proof);
        (bytes32 domain,bytes32 typeHash,bytes memory encoded,bytes memory payload)=abi.decode(sliceError(sig),(bytes32,bytes32,bytes,bytes));
        ProofPayload memory changed=abi.decode(payload,(ProofPayload));changed.proof=proof;
        bytes memory badSig=abi.encodeWithSignature("safeSignature(bytes32,bytes32,bytes,bytes)",domain,typeHash,encoded,abi.encode(changed));
        bytes32 digest=CoWOrder.digest(o,settlement.domainSeparator());
        vm.expectRevert(bytes4(keccak256("ProofNotAuthed()")));ICoWFallback(orders).isValidSignature(digest,badSig);
        deal(o.sellToken,orders,1 ether);deal(o.buyToken,address(settlement),1000e6);uint256 before=balance(o.buyToken,asset);
        vm.expectRevert(bytes4(keccak256("ProofNotAuthed()")));settle(o,badSig,true,10e6);
        assertEq(settlement.filledAmount(uid(o)),0);assertEq(balance(o.sellToken,orders),1 ether);assertEq(balance(o.buyToken,asset),before);
        settle(o,sig,true,10e6);assertEq(balance(o.buyToken,asset),before+10e6);
    }
    function test_TWAP_both_removal_roles_reject_cached_settlement_and_preserve_other_order() public {
        uint256 snap=vm.snapshotState();
        for(uint256 actor;actor<2;++actor){IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(700)));create(p);
            IComposableCoW.Params memory other=scheduled(2,60,0,bytes32(uint256(701)));other.staticInput=abi.encode(token("weth"),token("usdc"),asset,uint256(0.005 ether),uint256(2),uint256(0),uint256(2),uint256(60),uint256(0),bytes32(0));create(other);
            (CoWOrder.Data memory o,bytes memory sig)=part(p);(CoWOrder.Data memory unaffected,bytes memory otherSig)=part(other);
            assertTrue(keccak256(uid(o))!=keccak256(uid(unaffected)));deal(o.sellToken,orders,1 ether);deal(o.buyToken,address(settlement),1000e6);uint256 before=balance(o.buyToken,asset);
            remove(p,actor==0?committee:emergency,actor==0?ordersOperator:ordersEmergency);
            bytes32 digest=CoWOrder.digest(o,settlement.domainSeparator());
            vm.expectRevert(bytes4(keccak256("SingleOrderNotAuthed()")));ICoWFallback(orders).isValidSignature(digest,sig);
            vm.expectRevert(bytes4(keccak256("SingleOrderNotAuthed()")));settle(o,sig,true,10e6);
            assertEq(settlement.filledAmount(uid(o)),0);assertEq(balance(o.sellToken,orders),1 ether);assertEq(balance(o.buyToken,asset),before);
            settle(unaffected,otherSig,true,10e6);assertEq(balance(o.buyToken,asset),before+10e6);assertEq(settlement.filledAmount(uid(unaffected)),unaffected.sellAmount);
            assertTrue(vm.revertToState(snap));snap=vm.snapshotState();
        }
    }
    function test_TWAP_duplicate_create_preserves_identity_and_refreshes_context() public {
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(800)));create(p);(CoWOrder.Data memory first,bytes memory sig)=part(p);
        create(p);(CoWOrder.Data memory same,)=part(p);assertEq(uid(same),uid(first));assertEq(ICoWFallback(orders).isValidSignature(CoWOrder.digest(first,settlement.domainSeparator()),sig),bytes4(0x1626ba7e));
        vm.warp(vm.getBlockTimestamp()+1);create(p);(CoWOrder.Data memory refreshed,bytes memory refreshedSig)=part(p);
        assertEq(refreshed.validTo,first.validTo+1);assertTrue(keccak256(uid(refreshed))!=keccak256(uid(first)));
        invalidSignature(orders,CoWOrder.digest(first,settlement.domainSeparator()),sig);
        assertEq(ICoWFallback(orders).isValidSignature(CoWOrder.digest(refreshed,settlement.domainSeparator()),refreshedSig),bytes4(0x1626ba7e));
    }
    function test_TWAP_daily_weekly_exact_schedule_boundaries_and_invalid_shapes() public {
        uint256[4] memory counts=[uint256(2),uint256(90),uint256(2),uint256(12)];
        uint256[4] memory spacings=[uint256(1),uint256(1 days),uint256(1),uint256(7 days)];
        for(uint256 i;i<4;++i){IComposableCoW.Params memory p=scheduled(counts[i],spacings[i],0,bytes32(i));create(p);(CoWOrder.Data memory o,)=part(p);assertEq(o.sellAmount,0.005 ether);assertEq(o.buyAmount,1);assertEq(o.receiver,asset);assertEq(o.validTo,vm.getBlockTimestamp()+spacings[i]-1);}
        for(uint256 i;i<10;++i){IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(i+100));
            address factory=d("timestampFactory");bytes memory context="";bool dispatch=true;
            if(i==0)p=scheduled(1,60,0,p.salt);if(i==1)p=scheduled(91,1 days,0,p.salt);if(i==2)p=scheduled(13,7 days,0,p.salt);
            if(i==3)p=scheduled(90,1 days+1,0,p.salt);if(i==4)p=scheduled(12,7 days+1,0,p.salt);if(i==5)p=scheduled(2,0,0,p.salt);
            if(i==6)p=scheduled(2,60,vm.getBlockTimestamp()+1,p.salt);if(i==7)p.handler=controller;if(i==8)factory=controller;if(i==9)dispatch=false;
            denied(committee,ordersRoles,ordersOperator,d("composableCow"),abi.encodeCall(IComposableCoW.createWithContext,(p,factory,context,dispatch)),0);
        }
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(200)));
        denied(committee,ordersRoles,ordersOperator,d("composableCow"),abi.encodeCall(IComposableCoW.createWithContext,(p,d("timestampFactory"),hex"01",true)),0);
        p.staticInput=hex"00";vm.prank(committee);vm.expectRevert();ordersRoles.execTransactionWithRole(d("composableCow"),0,abi.encodeCall(IComposableCoW.createWithContext,(p,d("timestampFactory"),bytes(""),true)),0,ordersOperator,true);
    }
    function test_TWAP_part_replay_interval_edges_skips_final_and_amounts() public {
        deal(token("weth"),orders,1 ether);deal(token("usdc"),address(settlement),1000e6);
        uint256 start=vm.getBlockTimestamp();IComposableCoW.Params memory p=scheduled(3,60,0,bytes32(uint256(1)));create(p);
        (CoWOrder.Data memory first,bytes memory sig)=part(p);assertEq(first.validTo,start+59);settle(first,sig,true,10e6);
        vm.expectRevert("GPv2: order filled");settle(first,sig,true,10e6);
        vm.warp(start+59);(CoWOrder.Data memory stillFirst,)=part(p);assertEq(keccak256(uid(stillFirst)),keccak256(uid(first)));
        vm.warp(start+60);(CoWOrder.Data memory second,)=part(p);assertEq(second.validTo,start+119);assertEq(second.sellAmount,0.005 ether);
        vm.warp(start+121);(CoWOrder.Data memory third,bytes memory thirdSig)=part(p);assertEq(third.validTo,start+179);settle(third,thirdSig,true,10e6);
        bytes32 firstDigest=CoWOrder.digest(first,settlement.domainSeparator());invalidSignature(orders,firstDigest,sig);
        uint256 filled=settlement.filledAmount(uid(first));uint256 sold=balance(first.sellToken,orders);uint256 received=balance(first.buyToken,asset);
        vm.expectRevert();settle(first,sig,true,10e6);
        assertEq(settlement.filledAmount(uid(first)),filled);assertEq(balance(first.sellToken,orders),sold);assertEq(balance(first.buyToken,asset),received);
        vm.warp(start+180);vm.expectRevert();IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
    }
    function test_TWAP_signature_mutations_removal_isolation_recreate_and_context() public {
        IComposableCoW.Params memory p=scheduled(3,60,0,bytes32(uint256(1)));create(p);
        IComposableCoW.Params memory other=scheduled(3,60,0,bytes32(uint256(2)));create(other);
        (CoWOrder.Data memory o,bytes memory sig)=part(p);bytes32 digest=CoWOrder.digest(o,settlement.domainSeparator());
        invalidSignature(orders,bytes32(uint256(digest)^1),sig);
        invalidSignature(asset,digest,sig);
        remove(p,committee,ordersOperator);invalidSignature(orders,digest,sig);
        (CoWOrder.Data memory unaffected,bytes memory otherSig)=part(other);bytes32 otherDigest=CoWOrder.digest(unaffected,settlement.domainSeparator());assertEq(ICoWFallback(orders).isValidSignature(otherDigest,otherSig),bytes4(0x1626ba7e));
        vm.warp(vm.getBlockTimestamp()+1);create(p);(CoWOrder.Data memory recreated,)=part(p);assertEq(recreated.validTo,vm.getBlockTimestamp()+59);
        remove(p,emergency,ordersEmergency);vm.expectRevert();IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,p,"",new bytes32[](0));
        // Recreating identical params refreshes their timestamp context in this implementation.
        create(other);(CoWOrder.Data memory refreshed,)=part(other);assertEq(refreshed.validTo,vm.getBlockTimestamp()+59);
    }
    function test_TWAP_missing_funds_or_approval_does_not_fill_and_can_retry() public {
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(3)));create(p);(CoWOrder.Data memory o,bytes memory sig)=part(p);
        deal(o.sellToken,orders,0);deal(o.buyToken,address(settlement),1000e6);
        vm.expectRevert();settle(o,sig,true,10e6);assertEq(settlement.filledAmount(uid(o)),0);
        deal(o.sellToken,orders,1 ether);exec(emergency,ordersRoles,ordersEmergency,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),0)),0);
        vm.expectRevert();settle(o,sig,true,10e6);assertEq(settlement.filledAmount(uid(o)),0);
        ownerCall(orders,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),type(uint256).max)));settle(o,sig,true,10e6);assertEq(settlement.filledAmount(uid(o)),o.sellAmount);
    }
    function test_TWAP_reverse_direction_typed_fields_and_signature_binding() public {
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(77)));
        p.staticInput=abi.encode(token("usdc"),token("weth"),asset,uint256(100),uint256(50),uint256(0),uint256(2),uint256(60),uint256(0),bytes32(0));
        create(p);(CoWOrder.Data memory o,bytes memory sig)=part(p);assertEq(o.sellToken,token("usdc"));assertEq(o.buyToken,token("weth"));assertEq(o.sellAmount,100);assertEq(o.buyAmount,50);
        bytes32 digest=CoWOrder.digest(o,settlement.domainSeparator());assertEq(ICoWFallback(orders).isValidSignature(digest,sig),bytes4(0x1626ba7e));
        invalidSignature(orders,CoWOrder.digest(o,bytes32(0)),sig);
        IComposableCoW.Params memory mutated=p;mutated.salt=bytes32(uint256(78));vm.expectRevert();IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,mutated,"",new bytes32[](0));
        mutated=p;mutated.staticInput=abi.encode(token("weth"),token("usdc"),asset,uint256(101),uint256(50),uint256(0),uint256(2),uint256(60),uint256(0),bytes32(0));
        vm.expectRevert();IComposableCoW(d("composableCow")).getTradeableOrderWithSignature(orders,mutated,"",new bytes32[](0));
        for(uint256 i;i<7;++i){address sell=token("weth");address buy=token("usdc");address receiver=asset;uint256 amount=100;uint256 output=50;uint256 span;bytes32 appData;
            if(i==0)sell=controller;if(i==1)buy=controller;if(i==2)receiver=address(0);if(i==3)amount=0;if(i==4)output=0;if(i==5)span=1;if(i==6)appData=bytes32(uint256(1));
            IComposableCoW.Params memory bad=scheduled(2,60,0,bytes32(i+300));bad.staticInput=abi.encode(sell,buy,receiver,amount,output,uint256(0),uint256(2),uint256(60),span,appData);
            denied(committee,ordersRoles,ordersOperator,d("composableCow"),abi.encodeCall(IComposableCoW.createWithContext,(bad,d("timestampFactory"),bytes(""),true)),0);
        }
        deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);settleAmount(o,100,sig,true,50);assertEq(settlement.filledAmount(uid(o)),100);
    }
    function test_TWAP_remove_recreate_same_block_and_later_cached_signature_semantics() public {
        uint256 snap=vm.snapshotState();
        for(uint256 later;later<2;++later){
            IComposableCoW.Params memory p=scheduled(3,60,0,bytes32(uint256(88)));create(p);(CoWOrder.Data memory o,bytes memory sig)=part(p);bytes32 hash=CoWOrder.digest(o,settlement.domainSeparator());
            remove(p,committee,ordersOperator);invalidSignature(orders,hash,sig);
            if(later==1)vm.warp(vm.getBlockTimestamp()+1);
            create(p);
            if(later==0)assertEq(ICoWFallback(orders).isValidSignature(hash,sig),bytes4(0x1626ba7e));
            else invalidSignature(orders,hash,sig);
            assertTrue(vm.revertToState(snap));snap=vm.snapshotState();
        }
    }
}

contract SepoliaFirstLossCoverageTest is SepoliaCoverageFixture {
    function test_FL_failed_burn_and_claim_preserve_all_queue_and_share_state() public {
        for(uint256 i;i<2;++i){SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            uint32 stamp=uint32(vm.getBlockTimestamp());uint256 shares=share.balanceOf(firstLoss);uint256 supply=share.totalSupply();uint256 agentBefore=queue.asset().balanceOf(a("agent"));
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(3 ether)),0);
            vm.prank(controller);queue.settle(firstLoss,stamp);
            (uint256 id,bytes memory input)=motion(address(share),shares-3 ether+1);
            SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));vm.warp(vm.getBlockTimestamp()+et.motionDuration());
            vm.expectRevert(abi.encodeWithSelector(MockEVMScriptExecutor.CallFailed.selector,0,abi.encodeWithSignature("ModuleTransactionFailed()")));et.enactMotion(id,input);
            assertEq(uint256(et.getMotion(id).status),uint256(MockEasyTrack.MotionStatus.Pending));
            assertEq(share.balanceOf(firstLoss),shares-3 ether);assertEq(share.totalSupply(),supply-3 ether);assertEq(share.balanceOf(address(queue)),0);
            assertEq(queue.requested(firstLoss,stamp),0);assertEq(queue.claimable(firstLoss,stamp),3 ether);assertEq(queue.asset().balanceOf(address(queue)),3 ether);
            uint32[] memory stamps=new uint32[](1);stamps[0]=stamp;deal(address(queue.asset()),address(queue),0);
            permissionDenied(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0,bytes4(keccak256("ModuleTransactionFailed()")));
            assertEq(share.balanceOf(firstLoss),shares-3 ether);assertEq(share.totalSupply(),supply-3 ether);assertEq(share.balanceOf(address(queue)),0);
            assertEq(queue.requested(firstLoss,stamp),0);assertEq(queue.claimable(firstLoss,stamp),3 ether);assertEq(queue.asset().balanceOf(address(queue)),0);assertEq(queue.asset().balanceOf(a("agent")),agentBefore);
            deal(address(queue.asset()),address(queue),3 ether);exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);
            assertEq(queue.asset().balanceOf(a("agent")),agentBefore+3 ether);assertEq(queue.claimable(firstLoss,stamp),0);assertEq(share.totalSupply(),supply-3 ether);
        }
    }
    function test_FL_pending_redeem_survives_cancelled_burn_and_restart() public {
        for(uint256 i;i<2;++i){SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            uint32 stamp=uint32(vm.getBlockTimestamp());uint256 supply=share.totalSupply();uint256 shares=share.balanceOf(firstLoss);uint256 agentBefore=queue.asset().balanceOf(a("agent"));
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(1 ether)),0);
            (uint256 id,bytes memory input)=motion(address(share),1 ether);SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));
            (address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);for(uint256 j;j<mods.length&&mods[j]!=address(operator);++j)previous=mods[j];
            exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
            uint256[] memory ids=new uint256[](1);ids[0]=id;vm.prank(controller);MockAragonAgent(payable(a("voting"))).execute(address(et),0,abi.encodeCall(et.cancelMotions,(ids)));
            vm.warp(vm.getBlockTimestamp()+et.motionDuration());vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);
            assertEq(queue.requested(firstLoss,stamp),1 ether);assertEq(share.balanceOf(firstLoss),shares-1 ether);assertEq(share.totalSupply(),supply);
            ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));vm.prank(controller);queue.settle(firstLoss,stamp);
            uint32[] memory stamps=new uint32[](1);stamps[0]=stamp;exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);
            assertEq(queue.asset().balanceOf(a("agent")),agentBefore+1 ether);assertEq(queue.requested(firstLoss,stamp),0);assertEq(queue.claimable(firstLoss,stamp),0);assertEq(share.totalSupply(),supply-1 ether);
        }
    }
    function test_FL_request_boundaries_queue_authority_and_supply_accounting() public {
        for(uint256 i;i<2;++i){
            SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            uint256 shares=share.balanceOf(firstLoss);uint256 supply=share.totalSupply();uint32 stamp=uint32(vm.getBlockTimestamp());
            permissionDenied(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(0)),0,bytes4(keccak256("ModuleTransactionFailed()")));
            permissionDenied(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(shares+1)),0,bytes4(keccak256("ModuleTransactionFailed()")));
            assertEq(share.balanceOf(firstLoss),shares);assertEq(queue.requested(firstLoss,stamp),0);
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(shares)),0);
            assertEq(share.balanceOf(firstLoss),0);assertEq(queue.requested(firstLoss,stamp),shares);
            vm.prank(address(0xBAD));vm.expectRevert("fixture: controller");queue.settle(firstLoss,stamp);
            vm.prank(controller);vm.expectRevert("fixture: no request");queue.settle(firstLoss,stamp-1);
            vm.prank(controller);queue.settle(firstLoss,stamp);
            assertEq(share.totalSupply(),supply-shares);assertEq(share.balanceOf(address(queue)),0);assertEq(queue.claimable(firstLoss,stamp),shares);assertEq(queue.asset().balanceOf(address(queue)),shares);
            vm.prank(controller);vm.expectRevert("fixture: no request");queue.settle(firstLoss,stamp);
            vm.prank(controller);vm.expectRevert("fixture: queue");share.lock(firstLoss,1);
        }
    }
    function test_FL_same_and_multiple_timestamp_partial_duplicate_empty_and_double_claim() public {
        for(uint256 i;i<2;++i){SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            uint32 first=uint32(vm.getBlockTimestamp());
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(1 ether)),0);
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(2 ether)),0);assertEq(queue.requested(firstLoss,first),3 ether);
            uint32[] memory stamps=new uint32[](1);stamps[0]=first;
            uint256 before=queue.asset().balanceOf(a("agent"));
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);assertEq(queue.asset().balanceOf(a("agent")),before);assertEq(queue.requested(firstLoss,first),3 ether);
            vm.warp(vm.getBlockTimestamp()+1);uint32 second=uint32(vm.getBlockTimestamp());
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(1 ether)),0);
            vm.startPrank(controller);queue.settle(firstLoss,first);queue.settle(firstLoss,second);vm.stopPrank();
            stamps[0]=second;exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);
            assertEq(queue.asset().balanceOf(a("agent")),before+1 ether);assertEq(queue.claimable(firstLoss,first),3 ether);
            uint32[] memory duplicates=new uint32[](3);duplicates[0]=first;duplicates[1]=first;duplicates[2]=first-1;
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),duplicates)),0);
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),duplicates)),0);
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),new uint32[](0))),0);
            assertEq(queue.asset().balanceOf(a("agent")),before+4 ether);assertEq(queue.asset().balanceOf(address(queue)),0);
        }
    }
    function test_FL_denied_routes_both_shares_leave_all_state_unchanged() public {
        for(uint256 i;i<2;++i){address share=a(i==0?"usdShare":"ethShare");address queue=a(i==0?"usdQueue":"ethQueue");uint256 b=balance(share,firstLoss);uint256 supply=SepoliaShares(share).totalSupply();
            denied(committee,firstLossRoles,bytes32("first-loss"),share,abi.encodeWithSignature("burn(uint256)",1),0);
            denied(committee,firstLossRoles,bytes32("first-loss"),share,transferData(controller,1),0);
            denied(committee,firstLossRoles,bytes32("first-loss"),share,abi.encodeCall(IERC20.approve,(controller,1)),0);
            uint32[] memory stamps=new uint32[](1);stamps[0]=uint32(vm.getBlockTimestamp());
            address[3] memory receivers=[controller,asset,orders];for(uint256 j;j<3;++j)denied(committee,firstLossRoles,bytes32("first-loss"),queue,abi.encodeCall(SepoliaRedeemQueue.claim,(receivers[j],stamps)),0);
            permissionDenied(emergency,firstLossRoles,bytes32("first-loss"),queue,abi.encodeCall(SepoliaRedeemQueue.redeem,(1)),0,bytes4(keccak256("NotAuthorized(address)")));
            permissionDenied(committee,firstLossRoles,bytes32("first-loss-burn"),share,abi.encodeWithSignature("burn(uint256)",1),0,bytes4(keccak256("NoMembership()")));
            assertEq(balance(share,firstLoss),b);assertEq(SepoliaShares(share).totalSupply(),supply);assertEq(IERC20(share).allowance(firstLoss,controller),0);
        }
    }
    function test_FL_pending_claim_survives_unrelated_asset_stop_and_restart() public {
        for(uint256 index;index<2;++index){
        SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(index==0?"usdQueue":"ethQueue"));uint32 stamp=uint32(vm.getBlockTimestamp());
        exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(1 ether)),0);
        (address[] memory modules,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);
        for(uint256 i;i<modules.length&&modules[i]!=address(operator);++i)previous=modules[i];
        exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
        assertEq(queue.requested(firstLoss,stamp),1 ether);vm.prank(controller);queue.settle(firstLoss,stamp);
        uint32[] memory stamps=new uint32[](1);stamps[0]=stamp;uint256 before=queue.asset().balanceOf(a("agent"));
        exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);
        ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));
        exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(a("agent"),stamps)),0);
        assertEq(queue.asset().balanceOf(a("agent")),before+1 ether);
        }
    }
}

contract SepoliaBurnCoverageTest is SepoliaCoverageFixture {
    function test_ET_factory_callers_inputs_unknown_factory_and_unauthorized_cancellation() public {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));bytes memory valid=abi.encode(a("usdShare"),1 ether);uint256 before=et.motionsCount();
        vm.expectRevert("ET: factory not allowed");et.createMotion(address(0xBAD),valid);
        vm.prank(controller);vm.expectRevert("burn factory: trusted caller");et.createMotion(a("burnFactory"),valid);
        vm.expectRevert();committeeExecute(address(et),abi.encodeCall(et.createMotion,(a("burnFactory"),abi.encode(token("weth"),1 ether))),0,0);
        vm.expectRevert();committeeExecute(address(et),abi.encodeCall(et.createMotion,(a("burnFactory"),abi.encode(a("usdShare"),0))),0,0);
        vm.expectRevert();committeeExecute(address(et),abi.encodeCall(et.createMotion,(a("burnFactory"),hex"00")),0,0);
        assertEq(et.motionsCount(),before);
        (uint256 id,)=motion(a("usdShare"),1 ether);
        vm.prank(controller);vm.expectRevert("ET: not creator");et.cancelMotion(id);
        uint256[] memory ids=new uint256[](1);ids[0]=id;vm.expectRevert("fixture: Voting only");et.cancelMotions(ids);
        committeeCall(address(et),abi.encodeCall(et.cancelMotion,(id)));assertEq(uint256(et.getMotion(id).status),uint256(MockEasyTrack.MotionStatus.Canceled));
        vm.expectRevert("ET: motion not pending");et.cancelMotion(id);
        vm.expectRevert("ET: motion not found");et.enactMotion(id+100,valid);
    }
    function test_ET_window_exact_substituted_input_supply_and_reenactment_both_shares() public {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));
        for(uint256 i;i<2;++i){SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));uint256 supply=share.totalSupply();uint256 b=share.balanceOf(firstLoss);
            (uint256 id,bytes memory input)=motion(address(share),1 ether);uint256 enactAt=et.getMotion(id).startDate+et.motionDuration();
            vm.warp(enactAt-1);vm.expectRevert("ET: objection period not passed");et.enactMotion(id,input);
            vm.warp(enactAt);vm.expectRevert("ET: unexpected evm script");et.enactMotion(id,abi.encode(address(share),2 ether));
            assertEq(uint256(et.getMotion(id).status),uint256(MockEasyTrack.MotionStatus.Pending));assertEq(share.totalSupply(),supply);
            et.enactMotion(id,input);assertEq(share.balanceOf(firstLoss),b-1 ether);assertEq(share.totalSupply(),supply-1 ether);
            vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);
            vm.prank(controller);vm.expectRevert("ET: motion not pending");et.object(id);
        }
    }
    function test_ET_objection_threshold_multiple_current_weight_and_repeated_objector_fixture() public {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));SepoliaToken vote=SepoliaToken(a("objectionToken"));address alice=address(0xA11CE);address bob=address(0xB0B);
        vm.startPrank(controller);vote.transfer(alice,0.4 ether);vote.transfer(bob,0.6 ether);vm.stopPrank();
        (uint256 id,bytes memory input)=motion(a("usdShare"),1 ether);
        vm.prank(address(0xBAD));vm.expectRevert("ET: no LDO");et.object(id);
        vm.prank(alice);et.object(id);assertEq(et.getMotion(id).objectionsAmount,0.4 ether);assertEq(uint256(et.getMotion(id).status),0);
        vm.prank(bob);et.object(id);assertEq(et.getMotion(id).objectionsAmount,1 ether);assertEq(uint256(et.getMotion(id).status),1);
        vm.warp(vm.getBlockTimestamp()+et.motionDuration());vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);
        (id,input)=motion(a("usdShare"),1 ether);
        vm.prank(alice);et.object(id);vm.prank(alice);et.object(id);vm.prank(alice);et.object(id);
        assertEq(et.getMotion(id).objectionsAmount,1.2 ether);assertEq(uint256(et.getMotion(id).status),1);
        (id,input)=motion(a("usdShare"),1 ether);
        vm.prank(controller);vote.transfer(alice,1 ether);vm.prank(alice);et.object(id);assertEq(et.getMotion(id).objectionsAmount,1.4 ether);
    }
    function test_ET_failed_overbalance_competing_motions_and_removed_factory_behavior() public {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));SepoliaShares share=SepoliaShares(a("usdShare"));uint256 b=share.balanceOf(firstLoss);uint256 supply=share.totalSupply();
        (uint256 oversized,bytes memory tooMuch)=motion(address(share),b+1);
        (uint256 first,bytes memory input)=motion(address(share),b);
        (uint256 second,bytes memory secondInput)=motion(address(share),b);
        vm.warp(vm.getBlockTimestamp()+et.motionDuration());vm.expectRevert();et.enactMotion(oversized,tooMuch);
        assertEq(uint256(et.getMotion(oversized).status),0);assertEq(share.balanceOf(firstLoss),b);assertEq(share.totalSupply(),supply);
        // Removing the fixture factory prevents new creation, but does not invalidate an existing motion.
        vm.prank(et.owner());et.removeEVMScriptFactory(a("burnFactory"));assertFalse(et.evmScriptFactories(a("burnFactory")));
        vm.expectRevert();committeeExecute(address(et),abi.encodeCall(et.createMotion,(a("burnFactory"),input)),0,0);
        et.enactMotion(first,input);assertEq(share.balanceOf(firstLoss),0);assertEq(share.totalSupply(),supply-b);
        vm.expectRevert();et.enactMotion(second,secondInput);assertEq(uint256(et.getMotion(second).status),0);
    }
    function test_ET_voting_cancel_unknown_nonpending_mixed_ids_are_atomic() public {
        SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));(uint256 id,bytes memory input)=motion(a("usdShare"),1 ether);
        uint256[] memory ids=new uint256[](2);ids[0]=id;ids[1]=id+100;
        vm.prank(controller);vm.expectRevert("AGENT: execute reverted");MockAragonAgent(payable(a("voting"))).execute(address(et),0,abi.encodeCall(et.cancelMotions,(ids)));
        assertEq(uint256(et.getMotion(id).status),0);
        ids=new uint256[](1);ids[0]=id;vm.prank(controller);MockAragonAgent(payable(a("voting"))).execute(address(et),0,abi.encodeCall(et.cancelMotions,(ids)));
        vm.warp(vm.getBlockTimestamp()+et.motionDuration());vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);
    }
    function test_ET_executor_auth_encoding_and_batch_failure_are_atomic() public {
        MockEVMScriptExecutor executor=MockEVMScriptExecutor(a("easyTrackExecutor"));
        vm.expectRevert("EXECUTOR: only Easy Track");executor.executeEVMScript(hex"00000001");
        vm.prank(a("easyTrack"));vm.expectRevert();executor.executeEVMScript(hex"00000002");
        vm.prank(a("easyTrack"));vm.expectRevert();executor.executeEVMScript(hex"0000000101");
        vm.prank(a("easyTrack"));executor.executeEVMScript(hex"00000001");
        bytes memory revoke=roleData(address(operator),abi.encodeCall(IRoles.revokeFunction,(assetOperator,token("weth"),IERC20.transfer.selector)),0,bytes32("governance"),true);
        bytes memory chunk=abi.encodePacked(bytes20(address(operator)),uint32(revoke.length),revoke);
        bytes memory bad=abi.encodePacked(hex"00000001",chunk,bytes20(address(operator)),uint32(4),bytes4(0xdeadbeef));
        vm.prank(a("easyTrack"));vm.expectRevert();executor.executeEVMScript(bad);
        deal(token("weth"),asset,1);exec(committee,operator,assetOperator,token("weth"),transferData(orders,1),0);
        vm.prank(a("easyTrack"));executor.executeEVMScript(abi.encodePacked(hex"00000001",chunk));
        denied(committee,operator,assetOperator,token("weth"),transferData(orders,0),0);
    }
}

contract SepoliaGovernanceCoverageTest is SepoliaCoverageFixture {
    function conditions() internal view returns(IRoles.ConditionFlat[] memory tree) {
        tree=new IRoles.ConditionFlat[](3);
        tree[0]=IRoles.ConditionFlat(0,5,5,"");
        tree[1]=IRoles.ConditionFlat(0,1,16,abi.encode(orders));
        tree[2]=IRoles.ConditionFlat(0,1,28,abi.encode(bytes32("orders_weth")));
    }
    function govern(bytes memory data) internal { exec(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),data,0); }
    function test_GOV_all_target_function_admin_paths_and_options_roundtrip() public {
        address w=token("weth");deal(w,asset,100);IRoles.ConditionFlat[] memory tree=conditions();
        govern(abi.encodeCall(IRoles.revokeTarget,(assetOperator,w)));denied(committee,operator,assetOperator,w,transferData(orders,1),0);
        govern(abi.encodeCall(IRoles.scopeTarget,(assetOperator,w)));exec(committee,operator,assetOperator,w,transferData(orders,1),0);
        for(uint8 option;option<2;++option){
            govern(abi.encodeCall(IRoles.allowFunction,(assetOperator,w,IERC20.transfer.selector,option)));
            exec(committee,operator,assetOperator,w,transferData(orders,1),0);
            govern(abi.encodeCall(IRoles.scopeFunction,(assetOperator,w,IERC20.transfer.selector,tree,option)));
            reject(committee,operator,assetOperator,w,transferData(controller,1),0,7);
            exec(committee,operator,assetOperator,w,transferData(orders,1),0);
        }
        govern(abi.encodeCall(IRoles.revokeFunction,(assetOperator,w,IERC20.transfer.selector)));denied(committee,operator,assetOperator,w,transferData(orders,1),0);
        govern(abi.encodeCall(IRoles.scopeFunction,(assetOperator,w,IERC20.transfer.selector,tree,0)));exec(committee,operator,assetOperator,w,transferData(orders,1),0);
    }
    function test_GOV_all_admin_selectors_reject_wrong_keys_and_every_protected_target() public {
        address[9] memory protected_=[asset,orders,firstLoss,committee,emergency,address(operator),address(safety),address(ordersRoles),address(firstLossRoles)];
        bytes32[11] memory keys=[assetOperator,bytes32("operator"),bytes32("emergency"),ordersOperator,assetEmergency,ordersEmergency,bytes32("governance"),bytes32("first-loss"),bytes32("first-loss-burn"),bytes32(0),bytes32("foreign")];
        IRoles.ConditionFlat[] memory tree=conditions();address executor=a("easyTrackExecutor");address weth=token("weth");bytes32 before=configuration();
        for(uint256 k;k<keys.length;++k)for(uint256 t;t<10;++t){
            if(k==0&&t==0)continue;
            bytes32 key=keys[k];address target=t==0?weth:protected_[t-1];
            bytes[5] memory calls=[abi.encodeCall(IRoles.scopeTarget,(key,target)),abi.encodeCall(IRoles.revokeTarget,(key,target)),abi.encodeCall(IRoles.allowFunction,(key,target,IERC20.transfer.selector,uint8(0))),abi.encodeCall(IRoles.revokeFunction,(key,target,IERC20.transfer.selector)),abi.encodeCall(IRoles.scopeFunction,(key,target,IERC20.transfer.selector,tree,uint8(0)))];
            for(uint256 j;j<5;++j)denied(executor,operator,bytes32("governance"),address(operator),calls[j],0);
        }
        assertEq(configuration(),before);
        for(uint8 option=2;option<4;++option){
            denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),abi.encodeCall(IRoles.allowFunction,(assetOperator,token("weth"),IERC20.transfer.selector,option)),0);
            denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),abi.encodeCall(IRoles.scopeFunction,(assetOperator,token("weth"),IERC20.transfer.selector,tree,option)),0);
        }
    }
    function test_GOV_existing_delegatecall_can_only_be_downgraded() public {
        address weth=token("weth");bytes4 selector=IERC20.balanceOf.selector;bytes memory payload=abi.encodeCall(IERC20.balanceOf,(orders));
        for(uint8 original=2;original<4;++original)for(uint8 replacement;replacement<2;++replacement)for(uint256 scoped;scoped<2;++scoped){uint256 snap=vm.snapshotState();
            ownerCall(asset,address(operator),abi.encodeCall(IRoles.allowFunction,(assetOperator,weth,selector,original)));
            exec(committee,operator,assetOperator,weth,payload,1);
            IRoles.ConditionFlat[] memory tree=new IRoles.ConditionFlat[](2);tree[0]=IRoles.ConditionFlat(0,5,5,"");tree[1]=IRoles.ConditionFlat(0,1,16,abi.encode(orders));
            for(uint8 forbidden=2;forbidden<4;++forbidden){
                denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),abi.encodeCall(IRoles.allowFunction,(assetOperator,weth,selector,forbidden)),0);
                denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),abi.encodeCall(IRoles.scopeFunction,(assetOperator,weth,selector,tree,forbidden)),0);
            }
            exec(committee,operator,assetOperator,weth,payload,1);
            if(scoped==0)govern(abi.encodeCall(IRoles.allowFunction,(assetOperator,weth,selector,replacement)));
            else govern(abi.encodeCall(IRoles.scopeFunction,(assetOperator,weth,selector,tree,replacement)));
            denied(committee,operator,assetOperator,weth,payload,1);exec(committee,operator,assetOperator,weth,payload,0);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_GOV_fallback_and_singleton_routes_fail_at_policy_boundary() public {
        address[5] memory safes=[asset,orders,firstLoss,committee,emergency];address executor=a("easyTrackExecutor");bytes32 before=configuration();
        for(uint256 i;i<safes.length;++i){
            denied(executor,operator,bytes32("governance"),safes[i],abi.encodeWithSignature("setFallbackHandler(address)",controller),0);
            // Probe the legacy upgrade selector; this does not assert that the current Safe implements it.
            denied(executor,operator,bytes32("governance"),safes[i],abi.encodeWithSignature("changeMasterCopy(address)",controller),0);
            denied(executor,operator,bytes32("governance"),safes[i],abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)",controller,0,bytes(""),uint8(1)),0);
        }
        assertEq(configuration(),before);
    }
    function test_GOV_executor_cannot_use_direct_owner_or_module_routes() public {
        address executor=a("easyTrackExecutor");address voting=a("voting");address agent=a("agent");address[3] memory safes=[asset,orders,firstLoss];bytes32 before=configuration();
        for(uint256 i;i<safes.length;++i){
            vm.prank(executor);vm.expectRevert("GS031");ISafe(payable(safes[i])).enableModule(executor);
            vm.prank(executor);vm.expectRevert("GS030");ISafe(payable(safes[i])).approveHash(bytes32(uint256(1)));
            vm.prank(executor);vm.expectRevert("GS031");ISafe(payable(safes[i])).setGuard(executor);
            for(uint8 op;op<2;++op){vm.prank(executor);vm.expectRevert("GS104");ICoverageSafe(safes[i]).execTransactionFromModuleReturnData(controller,0,"",op);}
        }
        vm.prank(executor);vm.expectRevert("OWN: not owner");MockAragonAgent(payable(voting)).execute(asset,0,abi.encodeCall(ISafe.enableModule,(executor)));
        vm.prank(executor);vm.expectRevert("OWN: not owner");MockAragonAgent(payable(agent)).execute(asset,0,abi.encodeCall(ISafe.enableModule,(executor)));
        assertEq(configuration(),before);
    }
    function test_GOV_allowance_timestamp_classes_and_overflow_recovery() public {
        uint64 now_=uint64(vm.getBlockTimestamp());uint64[5] memory stamps=[uint64(0),now_-1,now_,now_+1,type(uint64).max];
        address weth=token("weth");address usdc=token("usdc");
        for(uint256 t;t<2;++t)for(uint256 i;i<stamps.length;++i){uint256 snap=vm.snapshotState();
            bytes32 key=t==0?bytes32("orders_weth"):bytes32("orders_usdc");bytes32 other=t==0?bytes32("orders_usdc"):bytes32("orders_weth");bytes32 untouched=allowanceHash(other);address token_=t==0?weth:usdc;
            deal(token_,asset,20);uint256 received=balance(token_,orders);
            govern(abi.encodeCall(IRoles.setAllowance,(key,uint128(5),uint128(10),uint128(2),uint64(30 days),stamps[i])));
            (uint128 refill,uint128 maximum,uint64 period,uint128 b,uint64 timestamp)=operator.allowances(key);
            assertEq(refill,2);assertEq(maximum,10);assertEq(period,30 days);assertEq(b,5);assertEq(timestamp,i==0?now_:stamps[i]);
            if(i==4){
                vm.prank(committee);vm.expectRevert(abi.encodeWithSignature("Panic(uint256)",uint256(0x11)));
                operator.execTransactionWithRole(token_,0,transferData(orders,1),0,assetOperator,true);
                assertEq(budget(key),5);assertEq(balance(token_,asset),20);assertEq(balance(token_,orders),received);
                ownerCall(asset,address(operator),abi.encodeCall(IRoles.setAllowance,(key,uint128(5),uint128(10),uint128(2),uint64(30 days),now_)));
            }
            exec(committee,operator,assetOperator,token_,transferData(orders,1),0);
            assertEq(budget(key),4);assertEq(balance(token_,asset),19);assertEq(balance(token_,orders),received+1);assertEq(allowanceHash(other),untouched);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_GOV_forbidden_administration_and_both_budget_key_updates() public {
        bytes32[] memory keys=new bytes32[](1);keys[0]=assetOperator;bool[] memory values=new bool[](1);values[0]=true;
        bytes[7] memory forbidden=[abi.encodeCall(IRoles.assignRoles,(controller,keys,values)),abi.encodeCall(IRoles.setDefaultRole,(controller,assetOperator)),abi.encodeWithSignature("transferOwnership(address)",controller),abi.encodeWithSignature("setAvatar(address)",controller),abi.encodeWithSignature("setTarget(address)",controller),abi.encodeCall(IRoles.setTransactionUnwrapper,(token("weth"),IERC20.transfer.selector,controller)),abi.encodeCall(IRoles.allowTarget,(assetOperator,token("weth"),uint8(0)))];
        for(uint256 i;i<7;++i)denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),forbidden[i],0);
        address[3] memory safes=[asset,orders,firstLoss];for(uint256 i;i<3;++i){
            denied(a("easyTrackExecutor"),operator,bytes32("governance"),safes[i],abi.encodeCall(ISafe.enableModule,(controller)),0);
            denied(a("easyTrackExecutor"),operator,bytes32("governance"),safes[i],abi.encodeCall(ISafe.setGuard,(controller)),0);
        }
        for(uint256 i;i<2;++i){bytes32 key=i==0?bytes32("orders_weth"):bytes32("orders_usdc");bytes32 other=allowanceHash(i==0?bytes32("orders_usdc"):bytes32("orders_weth"));
            govern(abi.encodeCall(IRoles.setAllowance,(key,uint128(5),uint128(10),uint128(2),uint64(30 days),uint64(vm.getBlockTimestamp()))));
            (uint128 refill,uint128 maximum,uint64 period,uint128 b,uint64 timestamp)=operator.allowances(key);assertEq(refill,2);assertEq(maximum,10);assertEq(period,30 days);assertEq(b,5);assertEq(timestamp,vm.getBlockTimestamp());assertEq(allowanceHash(i==0?bytes32("orders_usdc"):bytes32("orders_weth")),other);
            denied(a("easyTrackExecutor"),operator,bytes32("governance"),address(operator),abi.encodeCall(IRoles.setAllowance,(key,1,1,1,uint64(30 days-1),0)),0);
        }
    }
    function test_GOV_disabled_modifier_cannot_admin_and_only_voting_restores() public {
        (address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);
        for(uint256 i;i<mods.length&&mods[i]!=address(operator);++i)previous=mods[i];
        exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
        bytes memory revoke=abi.encodeCall(IRoles.revokeFunction,(assetOperator,token("weth"),IERC20.transfer.selector));
        vm.prank(a("easyTrackExecutor"));vm.expectRevert("GS104");operator.execTransactionWithRole(address(operator),0,revoke,0,bytes32("governance"),true);
        denied(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.enableModule,(address(operator))),0);
        vm.prank(controller);vm.expectRevert("GS031");ISafe(payable(asset)).enableModule(address(operator));
        ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));govern(revoke);denied(committee,operator,assetOperator,token("weth"),transferData(orders,0),0);
    }
    function test_GOV_owner_nonowner_and_failed_atomic_batch_preserve_state() public {
        bytes memory data=abi.encodeCall(IRoles.scopeTarget,(assetOperator,address(0xBEEF)));
        vm.prank(committee);vm.expectRevert("OWN: not owner");MockAragonAgent(payable(a("voting"))).execute(asset,0,data);
        string memory package=vm.readFile("cache/sepolia/role-key-migration/package.json");address multisend=vm.parseJsonAddress(package,".batchExecutor.address");
        assertEq(multisend.codehash,vm.parseJsonBytes32(package,".batchExecutor.codeHash"));uint256 nonce=ISafe(payable(asset)).nonce();
        bytes memory batch=abi.encodePacked(uint8(0),address(operator),uint256(0),uint256(data.length),data,uint8(0),address(operator),uint256(0),uint256(4),bytes4(0xdeadbeef));
        bytes memory signature=abi.encodePacked(bytes32(uint256(uint160(a("voting")))),bytes32(0),uint8(1));
        bytes memory safeData=abi.encodeCall(ISafe.execTransaction,(multisend,0,abi.encodeWithSignature("multiSend(bytes)",batch),1,0,0,0,address(0),payable(address(0)),signature));
        vm.prank(controller);vm.expectRevert("AGENT: execute reverted");MockAragonAgent(payable(a("voting"))).execute(asset,0,safeData);
        assertEq(ISafe(payable(asset)).nonce(),nonce);reject(committee,operator,assetOperator,address(0xBEEF),hex"00000000",0,2);
        ownerCall(asset,address(operator),data);
        // Owner authority can scope the target, but no function slot was granted by the rolled-back batch.
        reject(committee,operator,assetOperator,address(0xBEEF),hex"00000000",0,3);
    }
    function test_GOV_stale_owner_restore_rearms_later_revocation_selective_restart_preserves_it() public {
        address weth=token("weth");address usdc=token("usdc");
        deal(weth,asset,10);deal(usdc,asset,10);
        IRoles.ConditionFlat[] memory oldUsdc=conditions();oldUsdc[2].compValue=abi.encode(bytes32("orders_usdc"));
        bytes memory stale=abi.encodeCall(IRoles.scopeFunction,(assetOperator,usdc,IERC20.transfer.selector,oldUsdc,uint8(0)));
        bytes32 wethBudget=allowanceHash(bytes32("orders_weth"));bytes32 usdcBudget=allowanceHash(bytes32("orders_usdc"));
        exec(emergency,safety,assetEmergency,address(operator),abi.encodeCall(IRoles.revokeFunction,(assetOperator,weth,IERC20.transfer.selector)),0);
        (address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);
        for(uint256 i;i<mods.length&&mods[i]!=address(operator);++i)previous=mods[i];
        exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
        // A later owner decision removes a different permission while the operator is stopped.
        ownerCall(asset,address(operator),abi.encodeCall(IRoles.revokeFunction,(assetOperator,usdc,IERC20.transfer.selector)));
        uint256 stopped=vm.snapshotState();uint256 received=balance(usdc,orders);
        ownerCall(asset,address(operator),stale);
        ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));
        exec(committee,operator,assetOperator,usdc,transferData(orders,1),0);
        assertEq(balance(usdc,orders),received+1,"Old owner payload re-arms the later revocation");
        assertTrue(vm.revertToState(stopped));
        // Restore only the reviewed emergency removal, then enable execution last.
        ownerCall(asset,address(operator),abi.encodeCall(IRoles.scopeFunction,(assetOperator,weth,IERC20.transfer.selector,conditions(),uint8(0))));
        ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));
        assertEq(allowanceHash(bytes32("orders_weth")),wethBudget);assertEq(allowanceHash(bytes32("orders_usdc")),usdcBudget);
        reject(committee,operator,assetOperator,usdc,transferData(orders,1),0,3);
        assertEq(balance(usdc,orders),received);assertEq(balance(usdc,asset),10);
        uint256 wethReceived=balance(weth,orders);
        exec(committee,operator,assetOperator,weth,transferData(orders,1),0);
        assertEq(balance(weth,orders),wethReceived+1);assertEq(balance(weth,asset),9);
        assertEq(allowanceHash(bytes32("orders_usdc")),usdcBudget);
    }
}

contract SepoliaEmergencyCoverageTest is SepoliaCoverageFixture {
    function emergencyAdminMatrix(bool ordersAccount) internal {
        IRoles mod=ordersAccount?ordersRoles:safety;bytes32 emergencyKey=ordersAccount?ordersEmergency:assetEmergency;
        address weth=token("weth");address usdc=token("usdc");address relayer=d("vaultRelayer");
        address[4] memory targets=[address(operator),address(safety),address(ordersRoles),address(firstLossRoles)];
        address[5] memory safes=[asset,orders,firstLoss,committee,emergency];
        bytes32[13] memory keys=[assetOperator,ordersOperator,assetEmergency,ordersEmergency,bytes32("operator"),bytes32("emergency"),bytes32("governance"),bytes32("first-loss"),bytes32("first-loss-burn"),bytes32("orders_weth"),bytes32("orders_usdc"),bytes32(0),bytes32("foreign")];
        IRoles.ConditionFlat[] memory tree=new IRoles.ConditionFlat[](3);
        tree[0]=IRoles.ConditionFlat(0,5,5,"");tree[1]=IRoles.ConditionFlat(0,1,16,abi.encode(orders));tree[2]=IRoles.ConditionFlat(0,1,28,abi.encode(bytes32("orders_weth")));
        bytes32 before=configuration();bytes32 wethBudget=allowanceHash(bytes32("orders_weth"));bytes32 usdcBudget=allowanceHash(bytes32("orders_usdc"));
        bytes32[] memory assigned=new bytes32[](1);bool[] memory member=new bool[](1);
        for(uint256 t;t<targets.length;++t)for(uint256 k;k<keys.length;++k){assigned[0]=keys[k];member[0]=true;
            denied(emergency,mod,emergencyKey,targets[t],abi.encodeCall(IRoles.assignRoles,(controller,assigned,member)),0);
            member[0]=false;denied(emergency,mod,emergencyKey,targets[t],abi.encodeCall(IRoles.assignRoles,(controller,assigned,member)),0);
            bytes[7] memory calls=[abi.encodeCall(IRoles.setDefaultRole,(controller,keys[k])),abi.encodeCall(IRoles.allowTarget,(keys[k],weth,uint8(0))),abi.encodeCall(IRoles.scopeTarget,(keys[k],weth)),abi.encodeCall(IRoles.allowFunction,(keys[k],weth,IERC20.transfer.selector,uint8(0))),abi.encodeCall(IRoles.scopeFunction,(keys[k],weth,IERC20.transfer.selector,tree,uint8(0))),abi.encodeCall(IRoles.setAllowance,(keys[k],uint128(1),uint128(1),uint128(1),uint64(30 days),uint64(0))),abi.encodeWithSignature("transferOwnership(address)",controller)];
            for(uint256 j;j<calls.length;++j)denied(emergency,mod,emergencyKey,targets[t],calls[j],0);
        }
        for(uint256 i;i<safes.length;++i)for(uint256 t;t<targets.length;++t)denied(emergency,mod,emergencyKey,safes[i],abi.encodeCall(ISafe.enableModule,(targets[t])),0);
        for(uint256 t;t<2;++t){address token_=t==0?weth:usdc;address source=ordersAccount?orders:asset;uint256 approval=IERC20(token_).allowance(source,relayer);
            denied(emergency,mod,emergencyKey,token_,abi.encodeCall(IERC20.approve,(relayer,uint256(1))),0);
            denied(emergency,mod,emergencyKey,token_,abi.encodeCall(IERC20.approve,(relayer,type(uint256).max)),0);
            assertEq(IERC20(token_).allowance(source,relayer),approval);
        }
        assertEq(configuration(),before);assertEq(allowanceHash(bytes32("orders_weth")),wethBudget);assertEq(allowanceHash(bytes32("orders_usdc")),usdcBudget);
    }
    function test_EM_asset_administration_selector_key_matrix() public { emergencyAdminMatrix(false); }
    function test_EM_orders_administration_selector_key_matrix() public { emergencyAdminMatrix(true); }
    function test_EM_combined_filled_order_claims_frozen_governance_and_restart() public {
        CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);sign(o);settleAmount(o,100,"",false,50);
        address agent=a("agent");address executor=a("easyTrackExecutor");uint32 stamp=uint32(vm.getBlockTimestamp());
        uint256[2] memory proceeds;uint256[2] memory supply;uint32[] memory stamps=new uint32[](1);stamps[0]=stamp;
        for(uint256 i;i<2;++i){SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            supply[i]=share.totalSupply();proceeds[i]=queue.asset().balanceOf(agent);
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.redeem,(1 ether)),0);
            vm.prank(controller);queue.settle(firstLoss,stamp);exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(agent,stamps)),0);
            assertEq(queue.asset().balanceOf(agent),proceeds[i]+1 ether);assertEq(share.totalSupply(),supply[i]-1 ether);
        }
        bytes32 baseline=configuration();(address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);
        for(uint256 i;i<mods.length&&mods[i]!=address(operator);++i)previous=mods[i];
        exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
        exec(emergency,ordersRoles,ordersEmergency,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),0)),0);
        // scopeTarget is an allowed governance selector, so the disabled module must block it before it can grant a target.
        vm.prank(executor);vm.expectRevert("GS104");operator.execTransactionWithRole(address(operator),0,abi.encodeCall(IRoles.scopeTarget,(assetOperator,address(0xBEEF))),0,bytes32("governance"),true);
        ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));ownerCall(orders,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),type(uint256).max)));
        assertEq(configuration(),baseline);reject(committee,operator,assetOperator,address(0xBEEF),hex"deadbeef",0,2);
        vm.expectRevert("GPv2: order filled");settleAmount(o,100,"",false,50);
        for(uint256 i;i<2;++i){SepoliaShares share=SepoliaShares(a(i==0?"usdShare":"ethShare"));SepoliaRedeemQueue queue=SepoliaRedeemQueue(a(i==0?"usdQueue":"ethQueue"));
            exec(committee,firstLossRoles,bytes32("first-loss"),address(queue),abi.encodeCall(queue.claim,(agent,stamps)),0);
            assertEq(queue.asset().balanceOf(agent),proceeds[i]+1 ether);assertEq(queue.claimable(firstLoss,stamp),0);assertEq(queue.requested(firstLoss,stamp),0);assertEq(share.totalSupply(),supply[i]-1 ether);
        }
        o.buyAmount=51;sign(o);uint256 received=balance(o.buyToken,asset);settleAmount(o,100,"",false,51);assertEq(balance(o.buyToken,asset),received+51);
    }
    function test_EM_all_transfer_routes_tokens_and_forbidden_receivers() public {
        address[2] memory source=[asset,orders];address weth=token("weth");address usdc=token("usdc");address agent=a("agent");
        address[21] memory receivers=[asset,orders,firstLoss,committee,emergency,agent,controller,a("voting"),a("easyTrackExecutor"),address(operator),address(safety),address(ordersRoles),address(firstLossRoles),weth,usdc,address(0),address(0xBAD),a("easyTrack"),a("burnFactory"),a("usdQueue"),a("ethQueue")];
        for(uint256 i;i<2;++i)for(uint256 t;t<2;++t){address token_=t==0?weth:usdc;IRoles mod=i==0?safety:ordersRoles;bytes32 key=i==0?assetEmergency:ordersEmergency;deal(token_,source[i],20);
            for(uint256 j;j<receivers.length;++j){uint256 before=balance(token_,receivers[j]);uint256 held=balance(token_,source[i]);
                bool allowed=receivers[j]==agent||(i==0?receivers[j]==orders:receivers[j]==asset);
                if(allowed){exec(emergency,mod,key,token_,transferData(receivers[j],1),0);assertEq(balance(token_,receivers[j]),before+1);assertEq(balance(token_,source[i]),held-1);}
                else{reject(emergency,mod,key,token_,transferData(receivers[j],1),0,5);assertEq(balance(token_,receivers[j]),before);assertEq(balance(token_,source[i]),held);}
            }
            assertEq(balance(token_,source[i]),18);
        }
    }
    function test_EM_target_and_function_revokes_for_both_accounts_preserve_other_token() public {
        for(uint256 account;account<2;++account)for(uint256 mode;mode<2;++mode){uint256 snap=vm.snapshotState();
            IRoles emergencyMod=account==0?safety:ordersRoles;IRoles op=account==0?operator:ordersRoles;bytes32 ek=account==0?assetEmergency:ordersEmergency;bytes32 ok=account==0?assetOperator:ordersOperator;address src=account==0?asset:orders;address receiver=account==0?orders:asset;
            deal(token("weth"),src,10);deal(token("usdc"),src,10);
            bytes memory revoke=mode==0?abi.encodeCall(IRoles.revokeTarget,(ok,token("weth"))):abi.encodeCall(IRoles.revokeFunction,(ok,token("weth"),IERC20.transfer.selector));
            exec(emergency,emergencyMod,ek,address(op),revoke,0);denied(committee,op,ok,token("weth"),transferData(receiver,1),0);
            exec(committee,op,ok,token("usdc"),transferData(receiver,1),0);
            exec(emergency,emergencyMod,ek,token("weth"),transferData(a("agent"),1),0);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_EM_switch_wrong_predecessor_module_and_full_stop_only_admin_matrix() public {
        address[3] memory wrong=[address(safety),address(ordersRoles),address(firstLossRoles)];
        for(uint256 i;i<3;++i)denied(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(address(1),wrong[i])),0);
        vm.prank(emergency);vm.expectRevert();safety.execTransactionWithRole(asset,0,abi.encodeCall(ISafe.disableModule,(controller,address(operator))),0,assetEmergency,true);
        for(uint256 account;account<2;++account){bytes32 active=account==0?assetOperator:ordersOperator;IRoles mod=account==0?safety:ordersRoles;IRoles targetMod=account==0?operator:ordersRoles;bytes32 emergencyKey=account==0?assetEmergency:ordersEmergency;
            bytes32[] memory keys=new bytes32[](1);keys[0]=active;bool[] memory values=new bool[](1);values[0]=true;
            bytes[5] memory operations=[abi.encodeCall(IRoles.assignRoles,(controller,keys,values)),abi.encodeCall(IRoles.setAllowance,(bytes32("orders_weth"),1,1,1,uint64(30 days),0)),abi.encodeCall(IRoles.allowTarget,(active,token("weth"),uint8(0))),abi.encodeCall(IRoles.allowFunction,(active,token("weth"),IERC20.transfer.selector,uint8(0))),abi.encodeCall(IRoles.setDefaultRole,(controller,active))];
            for(uint256 i;i<5;++i)denied(emergency,mod,emergencyKey,address(targetMod),operations[i],0);
        }
        denied(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.enableModule,(address(operator))),0);
    }
    function test_EM_recovery_order_field_boundaries_and_token_directions() public {
        for(uint256 direction;direction<2;++direction){CoWOrder.Data memory o=order();o.receiver=a("agent");if(direction==1){o.sellToken=token("usdc");o.buyToken=token("weth");}
            if(direction==1){denied(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 days),0)),1);continue;}
            for(uint256 duration;duration<2;++duration){uint32 life=duration==0?uint32(1):uint32(1 days);o.validTo=uint32(vm.getBlockTimestamp()+life-1);
                exec(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,life,0)),1);assertGt(settlement.preSignature(uid(o)),0);unsign(o,emergency,ordersEmergency);
            }
            o.validTo=uint32(vm.getBlockTimestamp()+1 hours-1);o.buyToken=token("weth");denied(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),0)),1);
            o.buyToken=token("usdc");o.receiver=asset;denied(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 hours),0)),1);
            o.receiver=a("agent");denied(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(0),0)),1);
            denied(emergency,ordersRoles,ordersEmergency,d("orderSigner"),abi.encodeCall(IOrderSigner.signOrder,(o,uint32(1 days+1),0)),1);
        }
    }
    function test_EM_two_stop_restart_cycles_new_settlement_and_closed_uid_replay() public {
        CoWOrder.Data memory o=order();o.sellAmount=100;o.buyAmount=50;deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);sign(o);settleAmount(o,100,"",false,50);
        for(uint256 cycle;cycle<2;++cycle){
            (address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);for(uint256 i;i<mods.length&&mods[i]!=address(operator);++i)previous=mods[i];
            exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
            exec(emergency,ordersRoles,ordersEmergency,address(ordersRoles),abi.encodeCall(IRoles.revokeTarget,(ordersOperator,d("orderSigner"))),0);
            exec(emergency,ordersRoles,ordersEmergency,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),0)),0);
            unsign(o,emergency,ordersEmergency);assertEq(settlement.preSignature(uid(o)),0);
            ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));ownerCall(orders,address(ordersRoles),abi.encodeCall(IRoles.scopeTarget,(ordersOperator,d("orderSigner"))));
            ownerCall(orders,o.sellToken,abi.encodeCall(IERC20.approve,(d("vaultRelayer"),type(uint256).max)));
            sign(o);vm.expectRevert("GPv2: order filled");settleAmount(o,100,"",false,o.buyAmount);
            o.buyAmount+=1;sign(o);settleAmount(o,100,"",false,o.buyAmount);assertEq(settlement.filledAmount(uid(o)),100);
        }
    }
}

contract SepoliaStopOrderingCoverageTest is SepoliaCoverageFixture {
    function test_EM_zero_and_revoke_before_cancel_repeated_stop_and_retry() public {
        address weth=token("weth");address usdc=token("usdc");address signer=d("orderSigner");address relayer=d("vaultRelayer");
        for(uint256 direction;direction<2;++direction)for(uint256 ordering;ordering<2;++ordering){uint256 snap=vm.snapshotState();
            CoWOrder.Data memory o=order();if(direction==1){o.sellToken=usdc;o.buyToken=weth;}o.sellAmount=100;o.buyAmount=50;o.partiallyFillable=true;
            deal(o.sellToken,orders,1000);deal(o.buyToken,address(settlement),1000);uint256 received=balance(o.buyToken,asset);sign(o);settleAmount(o,40,"",false,50);
            uint256 filled=40;
            if(ordering==1){
                for(uint256 i;i<2;++i)exec(emergency,ordersRoles,ordersEmergency,address(ordersRoles),abi.encodeCall(IRoles.revokeTarget,(ordersOperator,signer)),0);
                settleAmount(o,20,"",false,50);filled=60;
            }
            uint256 approval=IERC20(o.sellToken).allowance(orders,relayer);
            for(uint256 i;i<2;++i)exec(emergency,ordersRoles,ordersEmergency,o.sellToken,abi.encodeCall(IERC20.approve,(relayer,0)),0);
            if(ordering==0)for(uint256 i;i<2;++i)exec(emergency,ordersRoles,ordersEmergency,address(ordersRoles),abi.encodeCall(IRoles.revokeTarget,(ordersOperator,signer)),0);
            assertGt(settlement.preSignature(uid(o)),0);
            if(direction==0)vm.expectRevert(bytes(""));else vm.expectRevert("ERC20: transfer amount exceeds allowance");
            settleAmount(o,100-filled,"",false,50);
            assertEq(settlement.filledAmount(uid(o)),filled);assertEq(balance(o.sellToken,orders),1000-filled);assertEq(balance(o.buyToken,asset),received+filled/2);
            for(uint256 i;i<2;++i)unsign(o,emergency,ordersEmergency);
            assertEq(settlement.preSignature(uid(o)),0);assertEq(IERC20(o.sellToken).allowance(orders,relayer),0);
            ownerCall(orders,o.sellToken,abi.encodeCall(IERC20.approve,(relayer,approval)));
            vm.expectRevert("GPv2: order not presigned");settleAmount(o,100-filled,"",false,50);
            assertEq(settlement.filledAmount(uid(o)),filled);
            ownerCall(orders,address(ordersRoles),abi.encodeCall(IRoles.scopeTarget,(ordersOperator,signer)));
            vm.expectRevert("GPv2: order not presigned");settleAmount(o,100-filled,"",false,50);
            sign(o);settleAmount(o,100-filled,"",false,50);
            assertEq(settlement.filledAmount(uid(o)),100);assertEq(balance(o.sellToken,orders),900);assertEq(balance(o.buyToken,asset),received+50);
            vm.expectRevert("GPv2: order filled");settleAmount(o,100-filled,"",false,50);
            assertTrue(vm.revertToState(snap));
        }
    }
    function test_EM_repeated_switch_pending_burn_cancel_and_restart() public {
        address voting=a("voting");SepoliaEasyTrack et=SepoliaEasyTrack(a("easyTrack"));
        for(uint256 tokenIndex;tokenIndex<2;++tokenIndex){uint256 snap=vm.snapshotState();SepoliaShares share=SepoliaShares(a(tokenIndex==0?"usdShare":"ethShare"));uint256 supply=share.totalSupply();uint256 held=share.balanceOf(firstLoss);bytes32 base=configuration();
            (uint256 id,bytes memory input)=motion(address(share),1 ether);
            (address[] memory mods,)=ICoverageSafe(asset).getModulesPaginated(address(1),10);address previous=address(1);for(uint256 i;i<mods.length&&mods[i]!=address(operator);++i)previous=mods[i];
            exec(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0);
            permissionDenied(emergency,safety,assetEmergency,asset,abi.encodeCall(ISafe.disableModule,(previous,address(operator))),0,bytes4(keccak256("ModuleTransactionFailed()")));
            assertFalse(ISafe(payable(asset)).isModuleEnabled(address(operator)));assertTrue(ISafe(payable(asset)).isModuleEnabled(address(safety)));
            uint256 stopped=vm.snapshotState();vm.warp(et.getMotion(id).startDate+et.motionDuration());et.enactMotion(id,input);
            assertEq(share.totalSupply(),supply-1 ether);assertEq(share.balanceOf(firstLoss),held-1 ether);assertTrue(vm.revertToState(stopped));
            uint256[] memory ids=new uint256[](1);ids[0]=id;vm.prank(controller);MockAragonAgent(payable(voting)).execute(address(et),0,abi.encodeCall(et.cancelMotions,(ids)));
            vm.warp(et.getMotion(id).startDate+et.motionDuration());vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);
            ownerCall(asset,asset,abi.encodeCall(ISafe.enableModule,(address(operator))));assertEq(configuration(),base);
            vm.expectRevert("ET: motion not pending");et.enactMotion(id,input);assertEq(share.totalSupply(),supply);assertEq(share.balanceOf(firstLoss),held);
            assertEq(uint256(et.getMotion(id).status),uint256(MockEasyTrack.MotionStatus.Canceled));assertTrue(vm.revertToState(snap));
        }
    }
}

interface IConditionalInventory {
    function roots(address owner) external view returns (bytes32);
    function singleOrders(address owner, bytes32 digest) external view returns (bool);
    function cabinet(address owner, bytes32 key) external view returns (bytes32);
    function swapGuards(address owner) external view returns (address);
}

contract SepoliaConditionalEntryCoverageTest is SepoliaCoverageFixture {
    struct RootProof { uint256 location; bytes data; }

    // These permission cases do not use First-loss shares.
    function supplyFirstLossShares() internal override {}

    function conditionalState(address cow,bytes32 digest) internal view returns(bytes32) {
        IConditionalInventory inventory=IConditionalInventory(cow);
        return keccak256(abi.encode(inventory.roots(orders),inventory.cabinet(orders,bytes32(0)),inventory.cabinet(orders,digest),inventory.singleOrders(orders,digest),inventory.swapGuards(orders)));
    }

    function test_TWAP_alternative_creation_roots_and_guard_setters_are_denied() public {
        address cow=d("composableCow");IConditionalInventory inventory=IConditionalInventory(cow);
        IComposableCoW.Params memory p=scheduled(2,60,0,bytes32(uint256(9100)));
        bytes32 digest=keccak256(abi.encode(p));bytes32 before=conditionalState(cow,digest);
        assertFalse(inventory.singleOrders(orders,digest));
        RootProof memory proof=RootProof(0,bytes(""));
        bytes[4] memory calls=[abi.encodeWithSignature("create((address,bytes32,bytes),bool)",p,true),
            abi.encodeWithSignature("setRoot(bytes32,(uint256,bytes))",digest,proof),
            abi.encodeWithSignature("setRootWithContext(bytes32,(uint256,bytes),address,bytes)",digest,proof,d("timestampFactory"),bytes("")),
            abi.encodeWithSignature("setSwapGuard(address)",controller)];
        for(uint256 actor;actor<2;++actor)for(uint256 i;i<calls.length;++i){
            reject(actor==0?committee:emergency,ordersRoles,actor==0?ordersOperator:ordersEmergency,cow,calls[i],0,3);
            assertEq(conditionalState(cow,digest),before);
        }
        create(p);assertTrue(inventory.singleOrders(orders,digest));
        (CoWOrder.Data memory o,bytes memory sig)=part(p);
        assertEq(ICoWFallback(orders).isValidSignature(CoWOrder.digest(o,settlement.domainSeparator()),sig),bytes4(0x1626ba7e));
        remove(p,committee,ordersOperator);assertEq(conditionalState(cow,digest),before);
    }

    function test_TWAP_stop_loss_payload_cannot_use_pinned_or_foreign_handler() public {
        address cow=d("composableCow");IConditionalInventory inventory=IConditionalInventory(cow);
        // StopLoss.Data field order comes from the primary handler ABI; oracle execution is out of scope.
        bytes memory stopLoss=abi.encode(token("weth"),token("usdc"),uint256(0.005 ether),uint256(1),bytes32(0),asset,true,false,uint32(vm.getBlockTimestamp()+3600),controller,controller,int256(1 ether),uint256(3600));
        for(uint256 handler;handler<2;++handler){
            IComposableCoW.Params memory p=IComposableCoW.Params(handler==0?address(0xDEAD):d("twap"),bytes32(uint256(9200+handler)),stopLoss);
            bytes32 digest=keccak256(abi.encode(p));assertFalse(inventory.singleOrders(orders,digest));
            for(uint256 actor;actor<2;++actor){
                denied(actor==0?committee:emergency,ordersRoles,actor==0?ordersOperator:ordersEmergency,cow,abi.encodeCall(IComposableCoW.createWithContext,(p,d("timestampFactory"),bytes(""),true)),0);
                assertFalse(inventory.singleOrders(orders,digest));assertEq(inventory.cabinet(orders,digest),bytes32(0));
            }
        }
    }
}

contract SepoliaSettlementRoundingCoverageTest is SepoliaCoverageFixture {
    function supplyFirstLossShares() internal override {}

    function test_SETTLE_nonzero_remainders_partial_fees_and_cumulative_rounding() public {
        for(uint256 direction;direction<2;++direction)for(uint256 kind;kind<2;++kind){
            uint256 snapshot=vm.snapshotState();CoWOrder.Data memory o=order();
            if(direction==1){o.sellToken=token("usdc");o.buyToken=token("weth");}
            o.sellAmount=1001;o.buyAmount=500;o.feeAmount=10;o.partiallyFillable=true;o.kind=kind==0?keccak256("sell"):keccak256("buy");
            deal(o.sellToken,orders,5000);deal(o.buyToken,address(settlement),5000);uint256 received=balance(o.buyToken,asset);sign(o);
            // Prices are sell=500, buy=1001. First-fill division and fee scaling both have a remainder.
            settleAmount(o,kind==0?501:251,"",false,500);
            assertEq(settlement.filledAmount(uid(o)),kind==0?501:251);
            assertEq(balance(o.sellToken,orders),5000-(kind==0?506:507));
            assertEq(balance(o.buyToken,asset),received+251);
            settleAmount(o,kind==0?500:249,"",false,500);
            // Per-fill ceilings give SELL one extra buy atom; BUY floors save one sell atom.
            // Proportional fee floors charge 5+4 atoms rather than the full-order 10.
            assertEq(settlement.filledAmount(uid(o)),kind==0?1001:500);
            assertEq(balance(o.sellToken,orders),5000-(kind==0?1010:1009));
            assertEq(balance(o.buyToken,asset),received+(kind==0?501:500));
            vm.expectRevert("GPv2: order filled");settleAmount(o,1,"",false,500);
            assertTrue(vm.revertToState(snapshot));
        }
    }
}
