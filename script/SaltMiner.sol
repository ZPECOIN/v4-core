// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/// @title Standalone Salt Miner
/// @notice A utility to mine salts for desired contract addresses
/// @dev This is a standalone version that can be used to find salts for CREATE2 deployments
contract SaltMiner is Script {
    /// @notice Hook flag constants (from Uniswap V4 Hooks library)
    /// @dev These MUST match the values in src/libraries/Hooks.sol exactly
    uint160 public constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 public constant BEFORE_INITIALIZE_FLAG = 1 << 13;
    uint160 public constant AFTER_INITIALIZE_FLAG = 1 << 12;

    uint160 public constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
    uint160 public constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 10;

    uint160 public constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
    uint160 public constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;

    uint160 public constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 public constant AFTER_SWAP_FLAG = 1 << 6;

    uint160 public constant BEFORE_DONATE_FLAG = 1 << 5;
    uint160 public constant AFTER_DONATE_FLAG = 1 << 4;

    uint160 public constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 3;
    uint160 public constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2;
    uint160 public constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 1;
    uint160 public constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0;

    /// @notice Mine for a salt that produces the desired hook flags
    /// @param deployer The deployer address
    /// @param targetFlags The target hook flags
    /// @param contractBytecodeHash The keccak256 hash of the contract creation code
    /// @param maxIterations Maximum number of iterations to try
    /// @return salt The salt that produces the correct address, or reverts if not found
    function mineSalt(
        address deployer,
        uint160 targetFlags,
        bytes32 contractBytecodeHash,
        uint256 maxIterations
    ) public pure returns (uint256 salt) {
        console.log("Mining salt for deployer:", deployer);
        console.log("Target flags:", targetFlags);
        console.log("Contract bytecode hash:", vm.toString(contractBytecodeHash));
        console.log("Max iterations:", maxIterations);
        
        for (salt = 0; salt < maxIterations; salt++) {
            address predicted = vm.computeCreate2Address(
                bytes32(salt),
                contractBytecodeHash,
                deployer
            );
            
            uint160 flags = uint160(predicted) & ALL_HOOK_MASK;
            
            if (flags == targetFlags) {
                console.log("SUCCESS! Found matching address:", predicted);
                console.log("Salt:", salt);
                console.log("Flags:", flags);
                return salt;
            }
            
            // Log progress every 10,000 iterations
            if (salt % 10000 == 0 && salt > 0) {
                console.log("Checked", salt, "salts so far...");
            }
        }
        
        console.log("FAILED: Could not find suitable salt within", maxIterations, "iterations");
        revert("Could not find suitable salt");
    }

    /// @notice Mine salt for arbitrage hook flags specifically
    /// @param deployer The deployer address
    /// @param contractBytecodeHash The contract bytecode hash
    /// @return salt The mined salt
    function mineArbHookSalt(
        address deployer,
        bytes32 contractBytecodeHash
    ) public pure returns (uint256 salt) {
        // Target flags for arbitrage hook: beforeSwap + afterSwap + afterSwapReturnsDelta
        uint160 targetFlags = BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG;
        
        console.log("Mining salt for Arbitrage Hook");
        console.log("Target flags breakdown:");
        console.log("- BEFORE_SWAP_FLAG:", BEFORE_SWAP_FLAG);
        console.log("- AFTER_SWAP_FLAG:", AFTER_SWAP_FLAG);
        console.log("- AFTER_SWAP_RETURNS_DELTA_FLAG:", AFTER_SWAP_RETURNS_DELTA_FLAG);
        console.log("- Combined target:", targetFlags);
        
        return mineSalt(deployer, targetFlags, contractBytecodeHash, 1000000);
    }

    /// @notice Mine salt for AsyncAdversarialHook flags specifically
    /// @param deployer The deployer address
    /// @param contractBytecodeHash The contract bytecode hash
    /// @return salt The mined salt
    function mineAsyncAdversarialHookSalt(
        address deployer,
        bytes32 contractBytecodeHash
    ) public pure returns (uint256 salt) {
        // Target flags for AsyncAdversarialHook: beforeSwap + afterSwap + afterSwapReturnsDelta
        uint160 targetFlags = BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG;
        
        console.log("Mining salt for AsyncAdversarialHook");
        console.log("Target flags breakdown:");
        console.log("- BEFORE_SWAP_FLAG (1 << 7):", BEFORE_SWAP_FLAG);
        console.log("- AFTER_SWAP_FLAG (1 << 6):", AFTER_SWAP_FLAG);
        console.log("- AFTER_SWAP_RETURNS_DELTA_FLAG (1 << 2):", AFTER_SWAP_RETURNS_DELTA_FLAG);
        console.log("- Combined target:", targetFlags);
        console.log("- Target flags (hex):", vm.toString(abi.encodePacked(targetFlags)));
        
        return mineSalt(deployer, targetFlags, contractBytecodeHash, 1000000);
    }

    /// @notice Verify that an address has the expected hook flags
    /// @param hookAddress The address to verify
    /// @param expectedFlags The expected flags
    /// @return hasCorrectFlags True if the address has the correct flags
    function verifyHookFlags(
        address hookAddress,
        uint160 expectedFlags
    ) public pure returns (bool hasCorrectFlags) {
        uint160 actualFlags = uint160(hookAddress) & ALL_HOOK_MASK;
        
        console.log("Verifying hook flags for address:", hookAddress);
        console.log("Expected flags:", expectedFlags);
        console.log("Actual flags:", actualFlags);
        
        hasCorrectFlags = (actualFlags == expectedFlags);
        
        if (hasCorrectFlags) {
            console.log("✓ Flags match!");
        } else {
            console.log("✗ Flags do not match!");
        }
        
        return hasCorrectFlags;
    }

    /// @notice Compute what address would be created with given parameters
    /// @param deployer The deployer address
    /// @param salt The salt value
    /// @param contractBytecodeHash The contract bytecode hash
    /// @return predicted The predicted address
    function computeAddress(
        address deployer,
        uint256 salt,
        bytes32 contractBytecodeHash
    ) public pure returns (address predicted) {
        predicted = vm.computeCreate2Address(
            bytes32(salt),
            contractBytecodeHash,
            deployer
        );
        
        console.log("Computed address:", predicted);
        console.log("Salt used:", salt);
        console.log("Deployer:", deployer);
        
        uint160 flags = uint160(predicted) & ALL_HOOK_MASK;
        console.log("Address flags:", flags);
        
        return predicted;
    }

    /// @notice Run the salt miner with example parameters
    function run() external {
        console.log("=== Salt Miner Demo ===");
        
        // Example deployer address (could be from env or hardcoded for demo)
        address deployer = address(0x742d35Cc6634C0532925a3b8D46B91d5d4AD6B0);
        
        // Example bytecode hash (this would normally be the actual contract creation code hash)
        bytes32 exampleBytecodeHash = keccak256("ExampleContractCreationCode");
        
        console.log("Demo: Finding salt for arbitrage hook flags");
        console.log("Using example deployer:", deployer);
        console.log("Using example bytecode hash:", vm.toString(exampleBytecodeHash));
        
        try this.mineArbHookSalt(deployer, exampleBytecodeHash) returns (uint256 salt) {
            console.log("Successfully found salt:", salt);
            
            // Verify the result
            address predictedAddress = this.computeAddress(deployer, salt, exampleBytecodeHash);
            uint160 targetFlags = BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG;
            bool isValid = this.verifyHookFlags(predictedAddress, targetFlags);
            
            if (isValid) {
                console.log("✓ Salt mining successful!");
            } else {
                console.log("✗ Salt mining verification failed!");
            }
        } catch {
            console.log("Salt mining failed - no suitable salt found");
        }
    }
}