// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {AsyncAdversarialHook} from "../src/AsyncAdversarialHook.sol";

/// @title Pool Creation Utility
/// @notice Script to create Uniswap V4 pools that use AsyncAdversarialHook
contract CreatePoolWithHook is Script {
    /// @notice Mainnet PoolManager address
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    /// @notice Common pool configurations
    uint24 constant FEE_LOW = 500;      // 0.05%
    uint24 constant FEE_MEDIUM = 3000;  // 0.3%
    uint24 constant FEE_HIGH = 10000;   // 1%
    
    int24 constant TICK_SPACING_LOW = 10;
    int24 constant TICK_SPACING_MEDIUM = 60;
    int24 constant TICK_SPACING_HIGH = 200;
    
    /// @notice Square root of 1:1 price ratio
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get hook address from environment or use a default
        address hookAddress = vm.envOr("HOOK_ADDRESS", address(0));
        require(hookAddress != address(0), "HOOK_ADDRESS must be set");
        
        // Get token addresses
        address token0 = vm.envOr("TOKEN0_ADDRESS", address(0));
        address token1 = vm.envOr("TOKEN1_ADDRESS", address(0));
        require(token0 != address(0) && token1 != address(0), "Token addresses must be set");
        
        // Ensure token0 < token1 for Uniswap V4 ordering
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        console.log("Creating pools with AsyncAdversarialHook...");
        console.log("Hook address:", hookAddress);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        
        vm.startBroadcast(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        
        // Create multiple pools with different fee tiers
        _createPool(poolManager, hookAddress, token0, token1, FEE_LOW, TICK_SPACING_LOW);
        _createPool(poolManager, hookAddress, token0, token1, FEE_MEDIUM, TICK_SPACING_MEDIUM);
        _createPool(poolManager, hookAddress, token0, token1, FEE_HIGH, TICK_SPACING_HIGH);
        
        vm.stopBroadcast();
        
        console.log("Pool creation completed successfully!");
    }

    /// @notice Create a single pool with the hook
    /// @param poolManager The pool manager contract
    /// @param hookAddress The hook contract address
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    /// @param fee The pool fee
    /// @param tickSpacing The tick spacing
    function _createPool(
        IPoolManager poolManager,
        address hookAddress,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal {
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        
        console.log("Creating pool with fee:", fee);
        console.log("Tick spacing:", vm.toString(tickSpacing));
        
        try poolManager.initialize(poolKey, SQRT_PRICE_1_1) {
            console.log("✓ Pool created successfully");
        } catch Error(string memory reason) {
            console.log("✗ Pool creation failed:", reason);
        } catch {
            console.log("✗ Pool creation failed with unknown error");
        }
    }

    /// @notice Initialize hook settings after pool creation
    /// @param hookAddress The deployed hook address
    function initializeHookSettings(address hookAddress) external {
        require(hookAddress != address(0), "Invalid hook address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        AsyncAdversarialHook hook = AsyncAdversarialHook(hookAddress);
        
        console.log("Initializing AsyncAdversarialHook settings...");
        
        // Configure adversarial behavior
        bool enableAdversarial = vm.envOr("ENABLE_ADVERSARIAL", false);
        if (enableAdversarial) {
            hook.setAdversarialMode(true);
            console.log("✓ Adversarial mode enabled");
            
            // Set adversarial delay (default 5 minutes)
            uint256 delay = vm.envOr("ADVERSARIAL_DELAY", uint256(5 minutes));
            hook.setAdversarialDelay(delay);
            console.log("✓ Adversarial delay set to:", delay, "seconds");
            
            // Set gas consumption limit
            uint256 gasLimit = vm.envOr("MAX_GAS_CONSUMPTION", uint256(200000));
            hook.setMaxGasConsumption(gasLimit);
            console.log("✓ Max gas consumption set to:", gasLimit);
        } else {
            console.log("ℹ Adversarial mode disabled (normal operation)");
        }
        
        vm.stopBroadcast();
        
        console.log("Hook initialization completed!");
    }

    /// @notice Helper function to calculate approximate tick from price
    /// @param price The price ratio (token1/token0)
    /// @return tick The approximate tick value
    function priceToTick(uint256 price) public pure returns (int24 tick) {
        // Simplified price to tick conversion
        // In practice, you would use more precise math libraries
        require(price > 0, "Price must be positive");
        
        if (price == 1e18) {
            return 0; // 1:1 price ratio
        } else if (price > 1e18) {
            // Price > 1, positive tick
            return int24(int256((price - 1e18) / 1e15)); // Simplified
        } else {
            // Price < 1, negative tick
            return -int24(int256((1e18 - price) / 1e15)); // Simplified
        }
    }

    /// @notice Helper function to get sqrt price from tick
    /// @param tick The tick value
    /// @return sqrtPriceX96 The sqrt price in X96 format
    function tickToSqrtPrice(int24 tick) public pure returns (uint160 sqrtPriceX96) {
        // Simplified tick to sqrt price conversion
        // In practice, you would use the TickMath library
        if (tick == 0) {
            return SQRT_PRICE_1_1;
        }
        // This is a placeholder - use proper TickMath in production
        return SQRT_PRICE_1_1;
    }
}

/// @title Demonstration Script
/// @notice Shows the complete deployment and pool creation process
contract FullDeploymentDemo is Script {
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    function run() external {
        console.log("=== Full AsyncAdversarialHook Deployment Demo ===");
        console.log("");
        
        console.log("This script demonstrates the complete process:");
        console.log("1. Deploy AsyncAdversarialHook with salt mining");
        console.log("2. Create pools that use the hook");
        console.log("3. Initialize hook settings");
        console.log("4. Monitor for proper operation");
        console.log("");
        
        console.log("Required environment variables:");
        console.log("- PRIVATE_KEY: Deployer private key");
        console.log("- TOKEN0_ADDRESS: First token address");
        console.log("- TOKEN1_ADDRESS: Second token address");
        console.log("- HOOK_ADDRESS: Deployed hook address (after deployment)");
        console.log("");
        
        console.log("Optional environment variables:");
        console.log("- ENABLE_ADVERSARIAL: Enable adversarial mode (default: false)");
        console.log("- ADVERSARIAL_DELAY: Delay in seconds (default: 300)");
        console.log("- MAX_GAS_CONSUMPTION: Max gas for adversarial behavior (default: 200000)");
        console.log("");
        
        console.log("Run the following scripts in order:");
        console.log("1. forge script script/DeployAsyncAdversarialHook.s.sol --broadcast");
        console.log("2. forge script script/CreatePoolWithHook.s.sol --broadcast");
        console.log("3. Monitor transactions and hook behavior");
        console.log("");
        
        console.log("=== Demo completed ===");
    }
}