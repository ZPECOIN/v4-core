// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ArbHookContract} from "../src/arb-hook-contract.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {Hooks} from "../src/libraries/Hooks.sol";

/// @title Deploy ArbHookContract
/// @notice Script to deploy the arbitrage hook contract to mainnet
contract DeployArbHook is Script {
    /// @notice Mainnet PoolManager address (this needs to be updated with actual V4 mainnet address)
    /// @dev This is a placeholder - update with real V4 PoolManager address when available
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    /// @notice Salt for CREATE2 deployment to get desired hook address
    /// @dev The hook address determines which hook functions are called
    uint256 constant HOOK_SALT = 0x4444000000000000000000000000000000000000000000000000000000000000;

    function run() external {
        // Get the deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting with the private key
        vm.startBroadcast(deployerPrivateKey);

        // Get the PoolManager contract
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        
        // Calculate the target hook address with required flags
        address targetHookAddress = _getTargetHookAddress();
        
        console.log("Deploying ArbHookContract to:", targetHookAddress);
        console.log("PoolManager address:", address(poolManager));
        
        // Deploy the hook contract using CREATE2 to get the target address
        ArbHookContract hook = new ArbHookContract{salt: bytes32(HOOK_SALT)}(poolManager);
        
        console.log("ArbHookContract deployed at:", address(hook));
        console.log("Owner:", hook.owner());
        
        // Verify the hook address has the correct flags
        _verifyHookFlags(address(hook));
        
        vm.stopBroadcast();
        
        console.log("Deployment completed successfully!");
        console.log("Next steps:");
        console.log("1. Initialize pools with this hook");
        console.log("2. Monitor for arbitrage opportunities");
        console.log("3. Withdraw profits using withdrawProfits()");
    }

    /// @notice Calculate the target hook address with required flags
    /// @return The target hook address
    function _getTargetHookAddress() internal pure returns (address) {
        // For an arbitrage hook, we want beforeSwap and afterSwap flags
        // beforeSwap flag: 1 << 7 = 0x80
        // afterSwap flag: 1 << 6 = 0x40
        // afterSwapReturnDelta flag: 1 << 2 = 0x04
        // Combined: 0x80 | 0x40 | 0x04 = 0xC4
        
        // The hook address should end with 0x00C4 to enable these hooks
        return address(uint160(HOOK_SALT | 0xC4));
    }

    /// @notice Verify that the deployed hook has the correct flags
    /// @param hookAddress The deployed hook address
    function _verifyHookFlags(address hookAddress) internal pure {
        uint160 flags = uint160(hookAddress) & Hooks.ALL_HOOK_MASK;
        
        console.log("Hook address flags:", flags);
        
        // Check beforeSwap flag (bit 7)
        bool hasBeforeSwap = (flags & Hooks.BEFORE_SWAP_FLAG) != 0;
        console.log("Has beforeSwap:", hasBeforeSwap);
        
        // Check afterSwap flag (bit 6)  
        bool hasAfterSwap = (flags & Hooks.AFTER_SWAP_FLAG) != 0;
        console.log("Has afterSwap:", hasAfterSwap);
        
        // Check afterSwapReturnsDelta flag (bit 2)
        bool hasAfterSwapReturnsDelta = (flags & Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG) != 0;
        console.log("Has afterSwapReturnsDelta:", hasAfterSwapReturnsDelta);
        
        require(hasBeforeSwap, "Missing beforeSwap flag");
        require(hasAfterSwap, "Missing afterSwap flag");
        require(hasAfterSwapReturnsDelta, "Missing afterSwapReturnsDelta flag");
        
        console.log("Hook flags verified successfully!");
    }
}

/// @title Deploy ArbHook with Mine
/// @notice Alternative deployment script that mines for the correct address
contract DeployArbHookWithMine is Script {
    /// @notice Mainnet PoolManager address
    address constant POOL_MANAGER_MAINNET = 0x0000000000000000000000000000000000000000;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Mining for hook address with correct flags...");
        console.log("Deployer:", deployer);
        
        // Target flags: beforeSwap + afterSwap + afterSwapReturnsDelta
        uint160 targetFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        
        // Mine for a salt that gives us the right address
        uint256 salt = _mineSalt(deployer, targetFlags);
        
        console.log("Found salt:", salt);
        
        vm.startBroadcast(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_MAINNET);
        ArbHookContract hook = new ArbHookContract{salt: bytes32(salt)}(poolManager);
        
        console.log("ArbHookContract deployed at:", address(hook));
        
        // Verify flags
        uint160 actualFlags = uint160(address(hook)) & Hooks.ALL_HOOK_MASK;
        require(actualFlags == targetFlags, "Incorrect flags");
        
        vm.stopBroadcast();
        
        console.log("Deployment with mining completed successfully!");
    }

    /// @notice Mine for a salt that produces the desired hook flags
    /// @param deployer The deployer address
    /// @param targetFlags The target hook flags
    /// @return The salt that produces the correct address
    function _mineSalt(address deployer, uint160 targetFlags) internal pure returns (uint256) {
        console.log("Starting salt mining...");
        console.log("Deployer:", deployer);
        console.log("Target flags:", targetFlags);
        console.log("Target flags (hex):", vm.toString(abi.encodePacked(targetFlags)));
        
        // Pre-compute the contract creation code hash for efficiency
        bytes32 contractHash = keccak256(abi.encodePacked(
            type(ArbHookContract).creationCode,
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
}