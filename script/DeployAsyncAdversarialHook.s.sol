// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {AsyncAdversarialHook} from "../src/AsyncAdversarialHook.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";

/// @title Deploy AsyncAdversarialHook
/// @notice Script to deploy the async adversarial hook contract with proper salt mining
contract DeployAsyncAdversarialHook is Script {
    /// @notice Mainnet PoolManager address (update with actual V4 mainnet address when available)
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying AsyncAdversarialHook with salt mining...");
        console.log("Deployer:", deployer);
        
        // Target flags: beforeSwap + afterSwap + afterSwapReturnsDelta
        uint160 targetFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        
        console.log("Target flags:");
        console.log("- BEFORE_SWAP_FLAG (1 << 7):", Hooks.BEFORE_SWAP_FLAG);
        console.log("- AFTER_SWAP_FLAG (1 << 6):", Hooks.AFTER_SWAP_FLAG);
        console.log("- AFTER_SWAP_RETURNS_DELTA_FLAG (1 << 2):", Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        console.log("- Combined target flags:", targetFlags);
        
        // Mine for a salt that gives us the right address
        uint256 salt = _mineSalt(deployer, targetFlags);
        
        console.log("Found salt:", salt);
        
        vm.startBroadcast(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        AsyncAdversarialHook hook = new AsyncAdversarialHook{salt: bytes32(salt)}(poolManager);
        
        console.log("AsyncAdversarialHook deployed at:", address(hook));
        console.log("Owner:", hook.owner());
        
        // Verify flags
        uint160 actualFlags = uint160(address(hook)) & Hooks.ALL_HOOK_MASK;
        require(actualFlags == targetFlags, "Incorrect flags");
        
        console.log("Hook flags verified successfully!");
        console.log("Actual flags:", actualFlags);
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Summary ===");
        console.log("Hook Contract: AsyncAdversarialHook");
        console.log("Address:", address(hook));
        console.log("Salt used:", salt);
        console.log("Required flags present:");
        console.log("- beforeSwap: true");
        console.log("- afterSwap: true");
        console.log("- afterSwapReturnsDelta: true");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Create pools that use this hook");
        console.log("2. Configure adversarial behavior settings");
        console.log("3. Test async operation patterns");
        console.log("4. Monitor for reentrancy protection");
        
        console.log("\n=== Pool Creation Example ===");
        console.log("Use the createPoolWithHook function below to create pools");
        console.log("that integrate with this AsyncAdversarialHook");
    }

    /// @notice Mine for a salt that produces the desired hook flags
    /// @param deployer The deployer address
    /// @param targetFlags The target hook flags
    /// @return The salt that produces the correct address
    function _mineSalt(address deployer, uint160 targetFlags) internal pure returns (uint256) {
        console.log("Starting salt mining...");
        console.log("Max iterations: 1,000,000");
        
        // Pre-compute the contract creation code hash for efficiency
        bytes32 contractHash = keccak256(abi.encodePacked(
            type(AsyncAdversarialHook).creationCode,
            abi.encode(POOL_MANAGER_MAINNET)
        ));
        
        console.log("Contract creation code hash:", vm.toString(contractHash));
        
        for (uint256 salt = 0; salt < 1000000; salt++) {
            address predicted = vm.computeCreate2Address(
                bytes32(salt),
                contractHash,
                deployer
            );
            
            uint160 flags = uint160(predicted) & Hooks.ALL_HOOK_MASK;
            if (flags == targetFlags) {
                console.log("SUCCESS: Found matching address:", predicted);
                console.log("Salt value:", salt);
                console.log("Iterations required:", salt + 1);
                console.log("Address flags:", flags);
                return salt;
            }
            
            // Log progress every 50,000 iterations
            if (salt % 50000 == 0 && salt > 0) {
                console.log("Checked", salt, "salts so far...");
            }
        }
        
        console.log("FAILED: Could not find suitable salt within 1,000,000 iterations");
        revert("Could not find suitable salt");
    }

    /// @notice Example function to create a pool with the AsyncAdversarialHook
    /// @param hookAddress The deployed hook address
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    /// @param fee The pool fee
    /// @param tickSpacing The tick spacing for the pool
    /// @param sqrtPriceX96 The initial price of the pool
    function createPoolWithHook(
        address hookAddress,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) external {
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        
        // Initialize the pool
        poolManager.initialize(poolKey, sqrtPriceX96);
        
        console.log("Pool created with AsyncAdversarialHook:");
        console.log("- Token0:", token0);
        console.log("- Token1:", token1);
        console.log("- Fee:", fee);
        console.log("- Hook:", hookAddress);
    }
}

/// @title Deploy with HookMiner Integration
/// @notice Alternative deployment that uses the standalone HookMiner utility
contract DeployAsyncAdversarialHookWithMiner is Script {
    /// @notice Mainnet PoolManager address
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Using HookMiner to find salt for AsyncAdversarialHook...");
        console.log("Deployer:", deployer);
        
        // Import and use the standalone SaltMiner
        // This demonstrates integration with the mining utility
        vm.startBroadcast(deployerPrivateKey);
        
        // Note: In practice, you would first run the SaltMiner to find the salt,
        // then use that salt here. For demonstration, we'll use a placeholder.
        uint256 minedSalt = 0; // This would come from SaltMiner.mineArbHookSalt()
        
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        AsyncAdversarialHook hook = new AsyncAdversarialHook{salt: bytes32(minedSalt)}(poolManager);
        
        console.log("AsyncAdversarialHook deployed at:", address(hook));
        
        vm.stopBroadcast();
        
        console.log("Deployment with HookMiner completed!");
    }
}