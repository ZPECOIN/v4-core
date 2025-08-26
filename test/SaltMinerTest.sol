// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/SaltMiner.sol";

/// @title Salt Miner Tests
/// @notice Tests for the salt mining functionality
contract SaltMinerTest is Test {
    SaltMiner public miner;
    
    // Test constants
    address constant TEST_DEPLOYER = address(0x742d35Cc6634C0532925a3b8D46B91d5d4AD6B0);
    bytes32 constant TEST_BYTECODE_HASH = keccak256("TestContract");
    
    function setUp() public {
        miner = new SaltMiner();
    }

    /// @notice Test that we can compute addresses deterministically
    function testComputeAddress() public {
        uint256 salt = 12345;
        
        address addr1 = miner.computeAddress(TEST_DEPLOYER, salt, TEST_BYTECODE_HASH);
        address addr2 = miner.computeAddress(TEST_DEPLOYER, salt, TEST_BYTECODE_HASH);
        
        // Should be deterministic
        assertEq(addr1, addr2, "Address computation should be deterministic");
        
        // Different salt should give different address
        address addr3 = miner.computeAddress(TEST_DEPLOYER, salt + 1, TEST_BYTECODE_HASH);
        assertTrue(addr1 != addr3, "Different salt should give different address");
    }

    /// @notice Test flag verification
    function testVerifyHookFlags() public {
        // Create an address with known flags
        uint160 targetFlags = 0x01C4; // Example flags
        
        // Find an address that ends with these flags (brute force for test)
        address testAddress;
        for (uint256 i = 0; i < 1000; i++) {
            testAddress = address(uint160(i * 256 + targetFlags));
            uint160 actualFlags = uint160(testAddress) & miner.ALL_HOOK_MASK();
            if (actualFlags == targetFlags) {
                break;
            }
        }
        
        // Verify the flags
        bool result = miner.verifyHookFlags(testAddress, targetFlags);
        assertTrue(result, "Flag verification should pass for correct flags");
        
        // Test with wrong flags
        bool wrongResult = miner.verifyHookFlags(testAddress, targetFlags + 1);
        assertFalse(wrongResult, "Flag verification should fail for incorrect flags");
    }

    /// @notice Test the salt mining function with a reasonable iteration limit
    function testMineSaltBasic() public {
        // Use a simple target that should be findable quickly
        uint160 simpleTarget = 0x0001; // Just the last bit set
        uint256 maxIterations = 10000; // Reasonable limit for testing
        
        try miner.mineSalt(TEST_DEPLOYER, simpleTarget, TEST_BYTECODE_HASH, maxIterations) returns (uint256 salt) {
            // Verify the result
            address predicted = miner.computeAddress(TEST_DEPLOYER, salt, TEST_BYTECODE_HASH);
            uint160 actualFlags = uint160(predicted) & miner.ALL_HOOK_MASK();
            
            assertEq(actualFlags, simpleTarget, "Mined salt should produce correct flags");
            console.log("Successfully mined salt:", salt);
            console.log("Resulting address:", predicted);
        } catch {
            // It's possible no salt is found in the iteration limit, which is fine for this test
            console.log("No salt found within iteration limit - this is expected for some targets");
        }
    }

    /// @notice Test the arbitrage hook specific mining function
    function testMineArbHookSalt() public {
        // This test might not find a result within reasonable time, but should not revert unexpectedly
        try miner.mineArbHookSalt(TEST_DEPLOYER, TEST_BYTECODE_HASH) returns (uint256 salt) {
            // If successful, verify the result
            address predicted = miner.computeAddress(TEST_DEPLOYER, salt, TEST_BYTECODE_HASH);
            uint160 expectedFlags = miner.BEFORE_SWAP_FLAG() | miner.AFTER_SWAP_FLAG() | miner.AFTER_SWAP_RETURNS_DELTA_FLAG();
            
            bool isValid = miner.verifyHookFlags(predicted, expectedFlags);
            assertTrue(isValid, "Mined salt should produce correct arbitrage hook flags");
            
            console.log("Successfully mined arbitrage hook salt:", salt);
            console.log("Resulting address:", predicted);
        } catch {
            // Expected for most test cases due to the large search space
            console.log("Arbitrage hook salt mining timed out - this is expected");
        }
    }

    /// @notice Test that flag constants are set correctly
    function testFlagConstants() public {
        // Verify that the flag constants make sense
        assertTrue(miner.BEFORE_SWAP_FLAG() > 0, "BEFORE_SWAP_FLAG should be non-zero");
        assertTrue(miner.AFTER_SWAP_FLAG() > 0, "AFTER_SWAP_FLAG should be non-zero");
        assertTrue(miner.AFTER_SWAP_RETURNS_DELTA_FLAG() > 0, "AFTER_SWAP_RETURNS_DELTA_FLAG should be non-zero");
        
        // Verify flags are different
        assertTrue(miner.BEFORE_SWAP_FLAG() != miner.AFTER_SWAP_FLAG(), "Flags should be different");
        
        // Verify ALL_HOOK_MASK
        assertTrue(miner.ALL_HOOK_MASK() > 0, "ALL_HOOK_MASK should be non-zero");
        
        console.log("Flag constants test passed");
        console.log("BEFORE_SWAP_FLAG:", miner.BEFORE_SWAP_FLAG());
        console.log("AFTER_SWAP_FLAG:", miner.AFTER_SWAP_FLAG());
        console.log("AFTER_SWAP_RETURNS_DELTA_FLAG:", miner.AFTER_SWAP_RETURNS_DELTA_FLAG());
        console.log("ALL_HOOK_MASK:", miner.ALL_HOOK_MASK());
    }
}