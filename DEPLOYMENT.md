# Arbitrage Hook Contract Deployment Guide

This guide explains how to deploy the `ArbHookContract` to Ethereum mainnet for Uniswap V4 arbitrage opportunities.

## Overview

The `ArbHookContract` is a Uniswap V4 hook that automatically detects and executes arbitrage opportunities. It implements the following hooks:

- `beforeSwap`: Analyzes incoming swaps for arbitrage potential
- `afterSwap`: Executes arbitrage trades and collects fees
- `afterSwapReturnDelta`: Returns profit deltas to the pool

## Features

- **Automated Arbitrage**: Monitors swaps and executes profitable arbitrage trades
- **Fee Collection**: Collects 0.3% fee on arbitrage profits
- **Owner Controls**: Owner can withdraw accumulated profits
- **Emergency Functions**: Emergency withdrawal capabilities
- **Gas Optimized**: Designed for efficient mainnet operation

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

The deployment configuration is already set up in `.env.mainnet`:

```bash
PRIVATE_KEY=a13f4defe240b8b83203d48c11288fbe12943d3f2f49b7aac87513356a15689a
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/5Y5e6ggXcsf8bvvWSyrSc
CHAIN_ID=1
GAS_LIMIT=3000000
GAS_PRICE=20000000000
```

### 4. Deploy to Mainnet

Run the deployment script:

```bash
./deploy-mainnet.sh
```

This script will:
1. Build the contracts
2. Deploy `ArbHookContract` with correct hook flags
3. Verify the deployment
4. Display the deployed contract address

### 5. Alternative Deployment Methods

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