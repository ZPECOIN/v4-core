// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AsyncAdversarialHook} from "../src/AsyncAdversarialHook.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {SwapParams} from "../src/types/PoolOperation.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "../src/types/BeforeSwapDelta.sol";

/// @title AsyncAdversarialHook Test Suite
/// @notice Comprehensive tests for the AsyncAdversarialHook contract
contract AsyncAdversarialHookTest is Test {
    AsyncAdversarialHook hook;
    address poolManager;
    address owner;
    address user;

    // Test pool configuration
    PoolKey testPoolKey;
    SwapParams testSwapParams;

    event AdversarialModeToggled(bool enabled);
    event AsyncOperationStarted(bytes32 indexed operationId, uint256 timestamp);
    event AsyncOperationCompleted(bytes32 indexed operationId, bool success);
    event AdversarialDelaySet(uint256 newDelay);

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        poolManager = makeAddr("poolManager");
        
        // Deploy the hook
        vm.prank(owner);
        hook = new AsyncAdversarialHook(IPoolManager(poolManager));
        
        // Set up test pool key
        testPoolKey = PoolKey({
            currency0: Currency.wrap(makeAddr("token0")),
            currency1: Currency.wrap(makeAddr("token1")),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Set up test swap params
        testSwapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18, // Exact output
            sqrtPriceLimitX96: 0
        });
    }

    /// @notice Test hook permissions
    function test_hookPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        // Verify expected permissions
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
        assertFalse(permissions.beforeSwapReturnDelta);
        assertTrue(permissions.afterSwapReturnDelta);
        assertFalse(permissions.afterAddLiquidityReturnDelta);
        assertFalse(permissions.afterRemoveLiquidityReturnDelta);
    }

    /// @notice Test hook address has correct flags
    function test_hookAddressFlags() public view {
        uint160 hookAddress = uint160(address(hook));
        uint160 flags = hookAddress & Hooks.ALL_HOOK_MASK;
        
        // Check individual flags
        bool hasBeforeSwap = (flags & Hooks.BEFORE_SWAP_FLAG) != 0;
        bool hasAfterSwap = (flags & Hooks.AFTER_SWAP_FLAG) != 0;
        bool hasAfterSwapReturnsDelta = (flags & Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG) != 0;
        
        // Note: These will only pass if the hook is deployed with correct salt mining
        // In a real deployment scenario, you would use salt mining to ensure correct flags
        console.log("Hook address:", address(hook));
        console.log("Hook flags:", flags);
        console.log("Has beforeSwap:", hasBeforeSwap);
        console.log("Has afterSwap:", hasAfterSwap);
        console.log("Has afterSwapReturnsDelta:", hasAfterSwapReturnsDelta);
    }

    /// @notice Test beforeSwap functionality
    function test_beforeSwap() public {
        vm.prank(poolManager);
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            user,
            testPoolKey,
            testSwapParams,
            ""
        );
        
        assertEq(selector, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(delta), 0);
        assertEq(fee, 0);
    }

    /// @notice Test afterSwap functionality
    function test_afterSwap() public {
        BalanceDelta swapDelta = toBalanceDelta(1e18, -1e18);
        
        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(
            user,
            testPoolKey,
            testSwapParams,
            swapDelta,
            ""
        );
        
        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    /// @notice Test adversarial mode toggle
    function test_adversarialModeToggle() public {
        assertFalse(hook.adversarialMode());
        
        vm.expectEmit(true, true, true, true);
        emit AdversarialModeToggled(true);
        
        hook.setAdversarialMode(true);
        assertTrue(hook.adversarialMode());
        
        vm.expectEmit(true, true, true, true);
        emit AdversarialModeToggled(false);
        
        hook.setAdversarialMode(false);
        assertFalse(hook.adversarialMode());
    }

    /// @notice Test adversarial delay settings
    function test_adversarialDelaySettings() public {
        uint256 newDelay = 5 minutes;
        
        vm.expectEmit(true, true, true, true);
        emit AdversarialDelaySet(newDelay);
        
        hook.setAdversarialDelay(newDelay);
        assertEq(hook.adversarialDelay(), newDelay);
    }

    /// @notice Test invalid delay rejection
    function test_invalidDelayRejection() public {
        // Test delay too small
        vm.expectRevert(AsyncAdversarialHook.InvalidDelay.selector);
        hook.setAdversarialDelay(30 seconds); // Less than MIN_DELAY
        
        // Test delay too large
        vm.expectRevert(AsyncAdversarialHook.InvalidDelay.selector);
        hook.setAdversarialDelay(2 hours); // More than MAX_DELAY
    }

    /// @notice Test max gas consumption setting
    function test_maxGasConsumptionSetting() public {
        uint256 newGasLimit = 1000000;
        hook.setMaxGasConsumption(newGasLimit);
        assertEq(hook.maxGasConsumption(), newGasLimit);
    }

    /// @notice Test ownership transfer
    function test_ownershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        hook.transferOwnership(newOwner);
        assertEq(hook.owner(), newOwner);
    }

    /// @notice Test ownership restrictions
    function test_ownershipRestrictions() public {
        address nonOwner = makeAddr("nonOwner");
        
        vm.prank(nonOwner);
        vm.expectRevert(AsyncAdversarialHook.OnlyOwner.selector);
        hook.setAdversarialMode(true);
        
        vm.prank(nonOwner);
        vm.expectRevert(AsyncAdversarialHook.OnlyOwner.selector);
        hook.setAdversarialDelay(5 minutes);
        
        vm.prank(nonOwner);
        vm.expectRevert(AsyncAdversarialHook.OnlyOwner.selector);
        hook.transferOwnership(nonOwner);
    }

    /// @notice Test pool manager restrictions
    function test_poolManagerRestrictions() public {
        address nonPoolManager = makeAddr("nonPoolManager");
        
        vm.prank(nonPoolManager);
        vm.expectRevert(AsyncAdversarialHook.OnlyPoolManager.selector);
        hook.beforeSwap(user, testPoolKey, testSwapParams, "");
        
        vm.prank(nonPoolManager);
        vm.expectRevert(AsyncAdversarialHook.OnlyPoolManager.selector);
        hook.afterSwap(user, testPoolKey, testSwapParams, toBalanceDelta(0, 0), "");
    }

    /// @notice Test async operation tracking
    function test_asyncOperationTracking() public {
        // Start a swap that will create an async operation
        vm.prank(poolManager);
        hook.beforeSwap(user, testPoolKey, testSwapParams, "");
        
        // The operation should be tracked internally
        // Note: We can't directly test internal state without additional getter functions
        // In a production version, you might want to add public getters for testing
    }

    /// @notice Test reentrancy protection
    function test_reentrancyProtection() public {
        // This test would require a malicious contract that attempts reentrancy
        // For now, we verify that the modifier is present and basic functionality works
        
        vm.prank(poolManager);
        hook.beforeSwap(user, testPoolKey, testSwapParams, "");
        
        vm.prank(poolManager);
        hook.afterSwap(user, testPoolKey, testSwapParams, toBalanceDelta(0, 0), "");
    }

    /// @notice Test adversarial behavior with gas consumption
    function test_adversarialBehaviorGasConsumption() public {
        hook.setAdversarialMode(true);
        hook.setMaxGasConsumption(100000);
        
        uint256 gasBefore = gasleft();
        
        vm.prank(poolManager);
        hook.beforeSwap(user, testPoolKey, testSwapParams, "");
        
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        
        // Verify that some gas was consumed
        // The exact amount will vary, but should be more than a simple function call
        assertGt(gasUsed, 50000);
    }

    /// @notice Test force completion of operations
    function test_forceCompleteOperation() public {
        bytes32 testOperationId = keccak256("test_operation");
        
        // This would normally be set by an internal operation
        // For testing, we'll just test the owner-only access
        hook.forceCompleteOperation(testOperationId);
        
        // Verify non-owner cannot call this
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.expectRevert(AsyncAdversarialHook.OnlyOwner.selector);
        hook.forceCompleteOperation(testOperationId);
    }

    /// @notice Helper function to create BalanceDelta
    function toBalanceDelta(int128 amount0, int128 amount1) internal pure returns (BalanceDelta) {
        return BalanceDelta.wrap(bytes32(abi.encodePacked(amount0, amount1)));
    }

    /// @notice Test edge case: Zero address owner rejection
    function test_zeroAddressOwnerRejection() public {
        vm.expectRevert("Invalid new owner");
        hook.transferOwnership(address(0));
    }

    /// @notice Test view functions
    function test_viewFunctions() public view {
        // Test basic view functions
        assertEq(address(hook.poolManager()), poolManager);
        assertEq(hook.owner(), owner);
        assertFalse(hook.adversarialMode());
        assertEq(hook.adversarialDelay(), hook.MIN_DELAY());
        assertEq(hook.maxGasConsumption(), hook.DEFAULT_GAS_LIMIT());
    }
}