// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

import {IERC20} from "../interfaces/Tokens.sol";
import {MockEVMScriptExecutor} from "./MockEVMScriptExecutor.sol";

/// @title MockEasyTrack — dry-run stand-in for Lido Easy Track
///        (0xF0211b7660680B49De1A7E9f25C65660F0a13Fea).
/// @dev Fidelity contract: reproduces the deployed flow:
///      - only whitelisted EVM script factories can start motions
///        (mirrors governance-managed factory allowlist);
///      - the script is built by the factory at motion creation
///        (IEVMScriptFactory.createEVMScript(creator, callData));
///      - objections are weighted by the objector's LDO balance against a
///        configurable threshold (production: 0.5% of total LDO supply);
///      - motion duration is configurable so drills can compress the
///        production 72 h objection window to seconds;
///      - enactment is permissionless once the objection period has passed
///        without reaching threshold;
///      - enacted motions execute through the (mock) EVMScriptExecutor, which
///        reaches the (mock) Aragon Agent exactly as production does.
interface IEVMScriptFactory {
    function createEVMScript(address _creator, bytes calldata _callData)
        external
        returns (bytes memory);
}

contract MockEasyTrack {
    enum MotionStatus {
        Pending,
        Rejected,
        Enacted,
        Canceled
    }

    struct Motion {
        address creator;
        address evmScriptFactory;
        bytes evmScriptCallData;
        bytes32 evmScriptHash;
        uint256 startDate;
        uint256 snapshotDate;
        uint256 objectionsAmount;
        MotionStatus status;
    }

    event MotionCreated(
        uint256 indexed _motionId,
        address indexed _creator,
        address indexed _evmScriptFactory,
        bytes _evmScriptCallData,
        uint256 _startDate,
        uint256 _snapshotDate
    );
    event MotionObjected(
        uint256 indexed _motionId,
        address indexed _objector,
        uint256 _weight,
        uint256 _objectionsAmount
    );
    event MotionRejected(uint256 indexed _motionId);
    event MotionEnacted(uint256 indexed _motionId);
    event MotionCanceled(uint256 indexed _motionId);

    address public owner;
    MockEVMScriptExecutor public immutable evmScriptExecutor;
    IERC20 public immutable ldoToken;

    uint256 public motionDuration; // production: 72 h
    uint256 public objectionThreshold; // production: 0.5% of total LDO supply
    uint256 public motionsCount;

    mapping(uint256 => Motion) internal motions;
    mapping(address => bool) public evmScriptFactories;

    modifier onlyOwner() {
        require(msg.sender == owner, "ET: only owner");
        _;
    }

    modifier motionExists(uint256 _motionId) {
        require(_motionId < motionsCount, "ET: motion not found");
        _;
    }

    constructor(
        MockEVMScriptExecutor _evmScriptExecutor,
        IERC20 _ldoToken,
        uint256 _motionDuration,
        uint256 _objectionThreshold
    ) {
        owner = msg.sender;
        evmScriptExecutor = _evmScriptExecutor;
        ldoToken = _ldoToken;
        motionDuration = _motionDuration;
        objectionThreshold = _objectionThreshold;
        // self-register on the executor, mirroring the deployed wiring where
        // the executor only accepts calls from Easy Track
        MockEVMScriptExecutor(address(_evmScriptExecutor)).setEasyTrack(address(this));
    }

    // --- governance-managed configuration (mirrors DAO-managed params) ---

    function addEVMScriptFactory(address _factory) external onlyOwner {
        evmScriptFactories[_factory] = true;
    }

    function removeEVMScriptFactory(address _factory) external onlyOwner {
        evmScriptFactories[_factory] = false;
    }

    function setMotionDuration(uint256 _motionDuration) external onlyOwner {
        motionDuration = _motionDuration;
    }

    function setObjectionThreshold(uint256 _objectionThreshold) external onlyOwner {
        objectionThreshold = _objectionThreshold;
    }

    // --- motion lifecycle ---

    function createMotion(address _evmScriptFactory, bytes calldata _evmScriptCallData)
        external
        returns (uint256)
    {
        require(evmScriptFactories[_evmScriptFactory], "ET: factory not allowed");

        bytes memory evmScript =
            IEVMScriptFactory(_evmScriptFactory).createEVMScript(msg.sender, _evmScriptCallData);

        uint256 motionId = motionsCount++;
        motions[motionId] = Motion({
            creator: msg.sender,
            evmScriptFactory: _evmScriptFactory,
            evmScriptCallData: _evmScriptCallData,
            evmScriptHash: keccak256(evmScript),
            startDate: block.timestamp,
            snapshotDate: block.timestamp,
            objectionsAmount: 0,
            status: MotionStatus.Pending
        });

        emit MotionCreated(
            motionId, msg.sender, _evmScriptFactory, _evmScriptCallData, block.timestamp, block.timestamp
        );
        return motionId;
    }

    function object(uint256 _motionId) external motionExists(_motionId) {
        Motion storage motion = motions[_motionId];
        require(motion.status == MotionStatus.Pending, "ET: motion not pending");

        uint256 weight = ldoToken.balanceOf(msg.sender);
        require(weight > 0, "ET: no LDO");

        motion.objectionsAmount += weight;
        if (motion.objectionsAmount >= objectionThreshold) {
            motion.status = MotionStatus.Rejected;
            emit MotionRejected(_motionId);
        }
        emit MotionObjected(_motionId, msg.sender, weight, motion.objectionsAmount);
    }

    /// @dev Production signature: the caller re-supplies the factory call data,
    ///      the motion's script is regenerated from it, and the result must
    ///      hash to the value recorded at creation. This is what rejects a
    ///      stale or substituted script, so the harness must carry it too.
    ///      Mirrors EasyTrack.enactMotion(uint256,bytes) @ 3183d1f6.
    function enactMotion(uint256 _motionId, bytes memory _evmScriptCallData)
        external
        motionExists(_motionId)
    {
        Motion storage motion = motions[_motionId];
        require(motion.status == MotionStatus.Pending, "ET: motion not pending");
        require(
            block.timestamp >= motion.startDate + motionDuration,
            "ET: objection period not passed"
        );

        bytes memory evmScript = IEVMScriptFactory(motion.evmScriptFactory).createEVMScript(
            motion.creator, _evmScriptCallData
        );
        require(motion.evmScriptHash == keccak256(evmScript), "ET: unexpected evm script");

        motion.status = MotionStatus.Enacted;
        evmScriptExecutor.executeEVMScript(evmScript);
        emit MotionEnacted(_motionId);
    }

    function cancelMotion(uint256 _motionId) external motionExists(_motionId) {
        Motion storage motion = motions[_motionId];
        require(motion.status == MotionStatus.Pending, "ET: motion not pending");
        require(motion.creator == msg.sender, "ET: not creator");

        motion.status = MotionStatus.Canceled;
        emit MotionCanceled(_motionId);
    }

    function getMotion(uint256 _motionId) external view returns (Motion memory) {
        return motions[_motionId];
    }
}

/// @dev Drill helper: a pass-through EVM script factory. The production
///      factories are Lido-owned and validate parameter shapes, so that a
///      motion cannot make an arbitrary call (ADR 006). This mock accepts a
///      prebuilt CallsScript payload in `callData` and returns it verbatim.
///      The simplification is deliberate: the drills test the motion path,
///      not a factory.
contract PassThroughEVMScriptFactory is IEVMScriptFactory {
    function createEVMScript(address, bytes calldata _callData)
        external
        view
        override
        returns (bytes memory)
    {
        return _callData;
    }
}
