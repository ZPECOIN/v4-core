# AsyncAdversarialHook Deployment Guide

This guide explains how to deploy the `AsyncAdversarialHook` to Ethereum mainnet for Uniswap V4 advanced hook patterns.

## Overview

The `AsyncAdversarialHook` is a sophisticated Uniswap V4 hook that demonstrates advanced patterns including:

- **Asynchronous Operations**: Manages operations across multiple blocks with proper state tracking
- **Adversarial Behavior**: Implements controlled adversarial patterns for testing and research
- **Reentrancy Protection**: Full protection against reentrancy attacks
- **Gas Optimization**: Designed for efficient mainnet operation with IR compilation

## Hook Implementation Features

- `beforeSwap`: Analyzes incoming swaps and initiates async operations
- `afterSwap`: Completes async operations and applies results
- `afterSwapReturnDelta`: Returns deltas from async operations
- **Owner Controls**: Configurable adversarial behavior and emergency functions
- **Security**: Comprehensive reentrancy protection and access controls

## Prerequisites

1. **Foundry**: Ensure Foundry is installed and up to date
2. **Private Key**: Have your wallet private key ready
3. **RPC Access**: Access to Ethereum mainnet RPC (Alchemy endpoint provided)
4. **ETH for Gas**: Sufficient ETH for deployment gas costs
5. **Hook Address Mining**: Understanding of Uniswap V4 hook address requirements

## Hook Address Requirements

### Critical: Correct Flag Values

The hook address must have specific bits set to enable the required callbacks:

```solidity
// Required flags for AsyncAdversarialHook
uint160 flags = 
    Hooks.BEFORE_SWAP_FLAG |           // 1 << 7 = 0x80
    Hooks.AFTER_SWAP_FLAG |            // 1 << 6 = 0x40  
    Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG; // 1 << 2 = 0x04

// Combined: 0x80 | 0x40 | 0x04 = 0xC4
```

**Important**: The hook address must end with `0x...xxC4` to enable these specific hooks.

### Flag Bug Fix

This implementation fixes a critical bug in the original salt mining where flag constants didn't match the Hooks library:

- ✅ **Fixed**: `BEFORE_SWAP_FLAG = 1 << 7`, `AFTER_SWAP_FLAG = 1 << 6`
- ❌ **Previous**: Had incorrect bit positions causing deployment failures

## Prerequisites

1. **Foundry**: Ensure Foundry is installed and up to date
2. **Private Key**: Have your wallet private key ready
3. **RPC Access**: Access to Ethereum mainnet RPC (Alchemy endpoint provided)
4. **ETH for Gas**: Sufficient ETH for deployment gas costs

## Deployment Configuration

The deployment uses the following configuration:

```bash
Private Key: a13f4defe240b8b83203d48c11288fbe12943d3f2f49b7aac87513356a15689a
RPC URL: https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc
Chain ID: 1 (Ethereum Mainnet)
```

## Deployment Steps

### 1. Clone and Setup

```bash
git clone <repository>
cd v4-core
git submodule update --init --recursive
```

### 2. Install Dependencies

```bash
# Install Foundry if not already installed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build the project
forge build
```

### 3. Configure Environment

Create or update your environment variables:

```bash
# Create .env file with your settings
PRIVATE_KEY=your_private_key_here
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
CHAIN_ID=1
GAS_LIMIT=3000000
GAS_PRICE=20000000000
```

**Security Note**: Never commit private keys to version control.

### 4. Deploy AsyncAdversarialHook

Run the deployment script with salt mining:

```bash
# Deploy with integrated salt mining
forge script script/DeployAsyncAdversarialHook.s.sol:DeployAsyncAdversarialHook \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

# Or use the simplified deployment script
./deploy-mainnet.sh
```

This script will:
1. Mine for a salt that produces the correct hook address flags
2. Deploy `AsyncAdversarialHook` with the mined salt
3. Verify the deployment and flag correctness
4. Display the deployed contract address

### 5. Verify Deployment

Check that the hook is deployed correctly:

```bash
# Check hook owner
cast call <HOOK_ADDRESS> "owner()" --rpc-url $RPC_URL

# Verify hook permissions
cast call <HOOK_ADDRESS> "getHookPermissions()" --rpc-url $RPC_URL

# Check hook address flags
cast call <HOOK_ADDRESS> "adversarialMode()" --rpc-url $RPC_URL
```

#### Manual Deployment

```bash
forge script script/DeployArbHook.s.sol:DeployArbHook \
    --rpc-url https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc \
    --private-key a13f4defe240b8b83203d48c11288fbe12943d3f2f49b7aac87513356a15689a \
    --broadcast \
    --verify
```

#### Mining for Optimal Address

```bash
forge script script/DeployArbHook.s.sol:DeployArbHookWithMine \
    --rpc-url https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc \
    --private-key a13f4defe240b8b83203d48c11288fbe12943d3f2f49b7aac87513356a15689a \
    --broadcast
```

## Hook Address Requirements

The hook contract must be deployed to an address with specific flags in the least significant bits:

- Bit 7 (0x80): `beforeSwap` hook enabled
- Bit 6 (0x40): `afterSwap` hook enabled  
- Bit 2 (0x04): `afterSwapReturnDelta` enabled

Target address should end with `0x00C4` (196 in decimal).

## Post-Deployment

### 1. Verify Deployment

Check that the contract is deployed correctly:

```bash
cast call <CONTRACT_ADDRESS> "owner()" --rpc-url https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc
```

### 2. Initialize Pools

Create Uniswap V4 pools that use this hook:

```solidity
PoolKey memory key = PoolKey({
    currency0: currency0,
    currency1: currency1, 
    fee: fee,
    tickSpacing: tickSpacing,
    hooks: IHooks(DEPLOYED_HOOK_ADDRESS)
});
```

### 3. Monitor Operations

The hook will automatically:
- Monitor all swaps on pools that use it
- Execute arbitrage when profitable
- Collect fees on arbitrage profits

### 4. Withdraw Profits

As the owner, you can withdraw accumulated profits:

```bash
cast send <CONTRACT_ADDRESS> "withdrawProfits(address,address,uint256)" \
    <CURRENCY_ADDRESS> <TO_ADDRESS> <AMOUNT> \
    --private-key a13f4defe240b8b83203d48c11288fbe12943d3f2f49b7aac87513356a15689a \
    --rpc-url https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc
```

## Security Considerations

1. **Private Key Security**: The private key is exposed in this configuration for demo purposes. In production, use secure key management.

2. **Owner Controls**: Only the owner can withdraw profits. Ensure the owner address is secure.

3. **Emergency Functions**: The contract includes emergency withdrawal functions for safety.

4. **Gas Optimization**: Monitor gas costs vs profits to ensure profitability.

## Troubleshooting

### Build Issues

If you encounter build issues:

```bash
# Clean and rebuild
forge clean
forge build
```

### Deployment Failures

Common issues:
- Insufficient gas: Increase `GAS_LIMIT` in `.env.mainnet`
- Network issues: Verify RPC URL is accessible
- Private key issues: Ensure private key is correct and has ETH

### Hook Address Issues

If the deployed address doesn't have correct flags:
- Use the mining deployment script
- Or manually calculate CREATE2 salt for desired address

## Contract Interface

### Key Functions

```solidity
// Get accumulated profits
function getProfits(Currency currency) external view returns (uint256)

// Withdraw profits (owner only)
function withdrawProfits(Currency currency, address to, uint256 amount) external

// Emergency withdraw (owner only)  
function emergencyWithdraw(Currency currency, address to) external

// Transfer ownership (owner only)
function transferOwnership(address newOwner) external
```

### Events

```solidity
event ArbitrageExecuted(PoolKey indexed poolKey, Currency indexed currency, uint256 profit, uint256 fee)
event ProfitWithdrawn(Currency indexed currency, address indexed to, uint256 amount)
```

## Support

For issues or questions:
1. Check the deployment logs for error messages
2. Verify all configuration values
3. Ensure sufficient ETH for gas costs
4. Review the Uniswap V4 documentation for pool initialization

## Important Notes

⚠️ **Mainnet Deployment**: This deploys to Ethereum mainnet with real ETH. Ensure you understand the costs and risks.

⚠️ **V4 Status**: Uniswap V4 may not be deployed to mainnet yet. You may need to update the `POOL_MANAGER_ADDRESS` when V4 launches.

⚠️ **Arbitrage Risk**: Arbitrage trading involves financial risk. Monitor the contract's performance and withdraw profits regularly.