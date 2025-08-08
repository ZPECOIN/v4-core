// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ArbHookContract} from "../src/arb-hook-contract.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {Hooks} from "../src/libraries/Hooks.sol";

contract ArbHookTest is Test {
    ArbHookContract hook;
    address mockPoolManager;
    address owner;

    function setUp() public {
        owner = address(this);
        mockPoolManager = address(0x1234567890123456789012345678901234567890);
        
        // Deploy the hook with mock pool manager
        hook = new ArbHookContract(IPoolManager(mockPoolManager));
    }

    function testInitialState() public {
        assertEq(hook.owner(), owner);
        assertEq(address(hook.poolManager()), mockPoolManager);
        assertEq(hook.MIN_PROFIT_BPS(), 50);
        assertEq(hook.MAX_SLIPPAGE_BPS(), 200);
        assertEq(hook.ARB_FEE_BPS(), 30);
        assertEq(hook.TOTAL_BPS(), 10000);
    }

    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
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

    function testOwnershipTransfer() public {
        address newOwner = address(0x999);
        
        hook.transferOwnership(newOwner);
        assertEq(hook.owner(), newOwner);
    }

    function testRevertOnInvalidOwner() public {
        vm.expectRevert("Invalid new owner");
        hook.transferOwnership(address(0));
    }

    function testOnlyOwnerModifier() public {
        address notOwner = address(0x888);
        
        vm.prank(notOwner);
        vm.expectRevert(ArbHookContract.OnlyOwner.selector);
        hook.transferOwnership(address(0x999));
    }
}