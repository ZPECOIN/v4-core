// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Hooks} from "./libraries/Hooks.sol";
import {SafeCast} from "./libraries/SafeCast.sol";
import {IHooks} from "./interfaces/IHooks.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {ModifyLiquidityParams, SwapParams} from "./types/PoolOperation.sol";
import {PoolKey} from "./types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "./types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "./types/BeforeSwapDelta.sol";
import {Currency} from "./types/Currency.sol";
import {BaseTestHooks} from "./test/BaseTestHooks.sol";

/// @title AsyncAdversarialHook
/// @notice A Uniswap V4 hook that implements adversarial and asynchronous patterns
/// @dev This hook demonstrates advanced patterns including reentrancy protection and async operations
contract AsyncAdversarialHook is BaseTestHooks {
    using Hooks for IHooks;
    using SafeCast for uint256;
    using SafeCast for int128;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice The pool manager instance
    IPoolManager public immutable poolManager;

    /// @notice Owner of the contract
    address public owner;

    /// @notice Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    /// @notice Async operation tracking
    mapping(bytes32 => bool) public pendingOperations;
    mapping(bytes32 => uint256) public operationTimestamps;
    
    /// @notice Adversarial behavior settings
    bool public adversarialMode;
    uint256 public adversarialDelay;
    uint256 public maxGasConsumption;
    
    /// @notice Constants
    uint256 public constant MIN_DELAY = 1 minutes;
    uint256 public constant MAX_DELAY = 1 hours;
    uint256 public constant DEFAULT_GAS_LIMIT = 500000;

    /// @notice Events
    event AdversarialModeToggled(bool enabled);
    event AsyncOperationStarted(bytes32 indexed operationId, uint256 timestamp);
    event AsyncOperationCompleted(bytes32 indexed operationId, bool success);
    event AdversarialDelaySet(uint256 newDelay);

    /// @notice Errors
    error OnlyPoolManager();
    error OnlyOwner();
    error ReentrantCall();
    error InvalidDelay();
    error OperationNotReady();
    error AdversarialModeActive();

    /// @notice Modifier to prevent reentrancy
    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /// @notice Modifier to restrict access to pool manager
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        _;
    }

    /// @notice Modifier to restrict access to owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /// @notice Constructor
    /// @param _poolManager The pool manager contract
    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
        owner = msg.sender;
        _status = _NOT_ENTERED;
        adversarialDelay = MIN_DELAY;
        maxGasConsumption = DEFAULT_GAS_LIMIT;
    }

    /// @notice Returns the hook permissions
    /// @return Hooks.Permissions The permissions for this hook
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Hook called before a swap
    /// @param sender The swap initiator
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param hookData Additional data for the hook
    /// @return bytes4 The function selector
    /// @return BeforeSwapDelta The delta to apply before swap
    /// @return uint24 Optional fee override
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        // Adversarial behavior: potentially delay or consume gas
        if (adversarialMode) {
            _executeAdversarialBehavior();
        }

        // Start async operation
        bytes32 operationId = _startAsyncOperation(key, params);
        
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice Hook called after a swap
    /// @param sender The swap initiator
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param delta The balance delta from the swap
    /// @param hookData Additional data for the hook
    /// @return bytes4 The function selector
    /// @return int128 The hook's delta
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyPoolManager nonReentrant returns (bytes4, int128) {
        // Complete any pending async operations
        bytes32 operationId = keccak256(abi.encode(key, params, block.timestamp));
        if (pendingOperations[operationId]) {
            _completeAsyncOperation(operationId);
        }

        return (IHooks.afterSwap.selector, 0);
    }

    /// @notice Start an asynchronous operation
    /// @param key The pool key
    /// @param params The swap parameters
    /// @return operationId The unique operation identifier
    function _startAsyncOperation(
        PoolKey calldata key,
        SwapParams calldata params
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encode(key, params, block.timestamp));
        pendingOperations[operationId] = true;
        operationTimestamps[operationId] = block.timestamp;
        
        emit AsyncOperationStarted(operationId, block.timestamp);
        return operationId;
    }

    /// @notice Complete an asynchronous operation
    /// @param operationId The operation identifier
    function _completeAsyncOperation(bytes32 operationId) internal {
        if (!pendingOperations[operationId]) return;
        
        // Check if enough time has passed
        if (block.timestamp < operationTimestamps[operationId] + adversarialDelay) {
            revert OperationNotReady();
        }
        
        pendingOperations[operationId] = false;
        emit AsyncOperationCompleted(operationId, true);
    }

    /// @notice Execute adversarial behavior patterns
    function _executeAdversarialBehavior() internal view {
        // Consume gas up to the limit
        uint256 gasStart = gasleft();
        uint256 gasToConsume = maxGasConsumption;
        
        while (gasStart - gasleft() < gasToConsume && gasleft() > 10000) {
            // Perform meaningless operations to consume gas
            keccak256(abi.encode(block.timestamp, msg.sender, gasleft()));
        }
    }

    /// @notice Toggle adversarial mode (owner only)
    /// @param enabled Whether to enable adversarial mode
    function setAdversarialMode(bool enabled) external onlyOwner {
        adversarialMode = enabled;
        emit AdversarialModeToggled(enabled);
    }

    /// @notice Set adversarial delay (owner only)
    /// @param delay The delay in seconds
    function setAdversarialDelay(uint256 delay) external onlyOwner {
        if (delay < MIN_DELAY || delay > MAX_DELAY) revert InvalidDelay();
        adversarialDelay = delay;
        emit AdversarialDelaySet(delay);
    }

    /// @notice Set maximum gas consumption for adversarial behavior (owner only)
    /// @param gasLimit The maximum gas to consume
    function setMaxGasConsumption(uint256 gasLimit) external onlyOwner {
        maxGasConsumption = gasLimit;
    }

    /// @notice Manually complete a pending operation (owner only)
    /// @param operationId The operation identifier
    function forceCompleteOperation(bytes32 operationId) external onlyOwner {
        if (pendingOperations[operationId]) {
            pendingOperations[operationId] = false;
            emit AsyncOperationCompleted(operationId, true);
        }
    }

    /// @notice Transfer ownership (owner only)
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    /// @notice Check if an operation is pending
    /// @param operationId The operation identifier
    /// @return bool Whether the operation is pending
    function isOperationPending(bytes32 operationId) external view returns (bool) {
        return pendingOperations[operationId];
    }

    /// @notice Get operation timestamp
    /// @param operationId The operation identifier
    /// @return uint256 The operation timestamp
    function getOperationTimestamp(bytes32 operationId) external view returns (uint256) {
        return operationTimestamps[operationId];
    }
}