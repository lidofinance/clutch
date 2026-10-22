// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IERC20} from "../interfaces/Tokens.sol";
import {IRoles} from "../interfaces/IRoles.sol";
import {MockEasyTrack, IEVMScriptFactory} from "./MockEasyTrack.sol";
import {MockEVMScriptExecutor} from "./MockEVMScriptExecutor.sol";
import {Call, EVMScriptLib} from "../exec/SafeExec.sol";

/// @dev Test assets have no financial value. The controller can mint them.
contract SepoliaToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    address public immutable controller;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_, address controller_) {
        name = name_;
        symbol = symbol_;
        controller = controller_;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == controller, "fixture: controller");
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 permitted = allowance[from][msg.sender];
        if (permitted != type(uint256).max) allowance[from][msg.sender] = permitted - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract SepoliaShares is SepoliaToken {
    address public queue;

    constructor(string memory symbol_, address controller_)
        SepoliaToken("First-loss test shares", symbol_, controller_)
    {}

    function setQueue(address queue_) external {
        require(msg.sender == controller && queue == address(0), "fixture: queue setup");
        queue = queue_;
    }

    function lock(address account, uint256 amount) external {
        require(msg.sender == queue, "fixture: queue");
        _transfer(account, queue, amount);
    }
}

/// @dev Earn's redeem/claim ABI and queue lock path, with a synthetic 1:1 settlement.
///      This fixture does not model Earn prices, fees, liquidity or oracle reports.
contract SepoliaRedeemQueue {
    SepoliaShares public immutable share;
    SepoliaToken public immutable asset;
    address public immutable controller;
    mapping(address => mapping(uint32 => uint256)) public requested;
    mapping(address => mapping(uint32 => uint256)) public claimable;

    constructor(SepoliaShares share_, address controller_) {
        share = share_;
        controller = controller_;
        asset = new SepoliaToken("First-loss test claim asset", "tCLAIM", address(this));
    }

    function redeem(uint256 amount) external {
        require(amount > 0, "fixture: zero request");
        share.lock(msg.sender, amount);
        requested[msg.sender][uint32(block.timestamp)] += amount;
    }

    function settle(address account, uint32 timestamp) external {
        require(msg.sender == controller, "fixture: controller");
        uint256 amount = requested[account][timestamp];
        require(amount > 0, "fixture: no request");
        delete requested[account][timestamp];
        share.burn(amount);
        asset.mint(address(this), amount);
        claimable[account][timestamp] += amount;
    }

    function claim(address receiver, uint32[] calldata timestamps) external returns (uint256 amount) {
        for (uint256 i; i < timestamps.length; ++i) {
            amount += claimable[msg.sender][timestamps[i]];
            delete claimable[msg.sender][timestamps[i]];
        }
        asset.transfer(receiver, amount);
    }
}

contract SepoliaEasyTrack is MockEasyTrack {
    address public immutable voting;

    constructor(MockEVMScriptExecutor executor_, IERC20 token_, uint256 duration_, address voting_)
        MockEasyTrack(executor_, token_, duration_, 1 ether)
    {
        voting = voting_;
    }

    function cancelMotions(uint256[] calldata ids) external {
        require(msg.sender == voting, "fixture: Voting only");
        for (uint256 i; i < ids.length; ++i) {
            require(ids[i] < motionsCount && motions[ids[i]].status == MotionStatus.Pending, "fixture: not pending");
            motions[ids[i]].status = MotionStatus.Canceled;
            emit MotionCanceled(ids[i]);
        }
    }
}

/// @dev Typed burn factory for the stand. The two share tokens and trusted caller are fixed.
contract SepoliaFirstLossBurnFactory is IEVMScriptFactory {
    address public immutable trustedCaller;
    IRoles public immutable modifier_;
    address public immutable usdShare;
    address public immutable ethShare;

    constructor(address caller_, IRoles modifier__, address usd_, address eth_) {
        trustedCaller = caller_;
        modifier_ = modifier__;
        usdShare = usd_;
        ethShare = eth_;
    }

    function createEVMScript(address creator, bytes calldata data) external view returns (bytes memory) {
        require(creator == trustedCaller, "burn factory: trusted caller");
        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        require((token == usdShare || token == ethShare) && amount > 0, "burn factory: input");
        Call[] memory calls = new Call[](1);
        calls[0] = Call(token, abi.encodeWithSignature("burn(uint256)", amount));
        return EVMScriptLib.buildAsGovernance(modifier_, bytes32("first-loss-burn"), calls);
    }
}
