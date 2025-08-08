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

/// @title ArbHookContract
/// @notice A Uniswap V4 hook that performs arbitrage operations
/// @dev This hook monitors price movements and executes profitable arbitrage trades
contract ArbHookContract is BaseTestHooks {
    using Hooks for IHooks;
    using SafeCast for uint256;
    using SafeCast for int128;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice The pool manager instance
    IPoolManager public immutable poolManager;

    /// @notice Minimum profit threshold for arbitrage (in basis points)
    uint256 public constant MIN_PROFIT_BPS = 50; // 0.5%
    
    /// @notice Maximum slippage tolerance (in basis points)
    uint256 public constant MAX_SLIPPAGE_BPS = 200; // 2%
    
    /// @notice Fee rate for arbitrage operations (in basis points)
    uint256 public constant ARB_FEE_BPS = 30; // 0.3%
    
    /// @notice Total basis points for calculations
    uint256 public constant TOTAL_BPS = 10000;

    /// @notice Owner of the contract
    address public owner;

    /// @notice Total arbitrage profits collected
    mapping(Currency => uint256) public totalProfits;

    /// @notice Events
    event ArbitrageExecuted(
        PoolKey indexed poolKey,
        Currency indexed currency,
        uint256 profit,
        uint256 fee
    );
    
    event ProfitWithdrawn(
        Currency indexed currency,
        address indexed to,
        uint256 amount
    );

    /// @notice Errors
    error OnlyPoolManager();
    error OnlyOwner();
    error InsufficientProfit();
    error ArbitrageFailed();

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
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        // Analyze potential arbitrage opportunity
        _analyzeArbitrageOpportunity(key, params);
        
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
    ) external override onlyPoolManager returns (bytes4, int128) {
        // Execute arbitrage if profitable
        int128 arbitrageDelta = _executeArbitrage(key, params, delta);
        
        return (IHooks.afterSwap.selector, arbitrageDelta);
    }

    /// @notice Analyze potential arbitrage opportunity
    /// @param key The pool key
    /// @param params The swap parameters
    function _analyzeArbitrageOpportunity(
        PoolKey calldata key,
        SwapParams calldata params
    ) internal view {
        // This is a simplified analysis
        // In a real implementation, you would:
        // 1. Check prices on other DEXes or pools
        // 2. Calculate potential profit
        // 3. Determine optimal arbitrage size
        // 4. Check gas costs vs profit
        
        // For this implementation, we'll use basic heuristics
        uint256 swapAmount = params.amountSpecified > 0 
            ? uint256(params.amountSpecified) 
            : uint256(-params.amountSpecified);
            
        // Only consider large swaps for arbitrage
        require(swapAmount > 1000 * 1e18, "Swap too small for arbitrage");
    }

    /// @notice Execute arbitrage trade
    /// @param key The pool key
    /// @param params The original swap parameters
    /// @param delta The balance delta from the original swap
    /// @return int128 The arbitrage delta
    function _executeArbitrage(
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta
    ) internal returns (int128) {
        // Simplified arbitrage logic
        // In a real implementation, you would:
        // 1. Execute opposite trade on another pool/DEX
        // 2. Calculate actual profit
        // 3. Take fee from profit
        
        // For demonstration, we'll simulate taking a small fee
        bool specifiedTokenIs0 = (params.amountSpecified < 0 == params.zeroForOne);
        (Currency feeCurrency, int128 swapAmount) = specifiedTokenIs0 
            ? (key.currency1, delta.amount1()) 
            : (key.currency0, delta.amount0());
        
        if (swapAmount < 0) swapAmount = -swapAmount;
        
        // Calculate arbitrage fee (smaller than swap amount)
        uint256 feeAmount = uint128(swapAmount) * ARB_FEE_BPS / TOTAL_BPS;
        
        if (feeAmount > 0) {
            // Take the fee
            poolManager.take(feeCurrency, address(this), feeAmount);
            
            // Update profit tracking
            totalProfits[feeCurrency] += feeAmount;
            
            emit ArbitrageExecuted(key, feeCurrency, feeAmount, feeAmount);
            
            return SafeCast.toInt128(feeAmount);
        }
        
        return 0;
    }

    /// @notice Withdraw accumulated profits
    /// @param currency The currency to withdraw
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function withdrawProfits(
        Currency currency,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(amount <= totalProfits[currency], "Insufficient profits");
        
        totalProfits[currency] -= amount;
        
        // Transfer the profits
        poolManager.transfer(currency, to, amount);
        
        emit ProfitWithdrawn(currency, to, amount);
    }

    /// @notice Emergency withdraw function
    /// @param currency The currency to withdraw
    /// @param to The recipient address
    function emergencyWithdraw(Currency currency, address to) external onlyOwner {
        uint256 balance = totalProfits[currency];
        if (balance > 0) {
            totalProfits[currency] = 0;
            poolManager.transfer(currency, to, balance);
            emit ProfitWithdrawn(currency, to, balance);
        }
    }

    /// @notice Transfer ownership
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    /// @notice Get total profits for a currency
    /// @param currency The currency to check
    /// @return The total profits accumulated
    function getProfits(Currency currency) external view returns (uint256) {
        return totalProfits[currency];
    }
}