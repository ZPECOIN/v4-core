#!/bin/bash

# Mainnet Deployment Script for Arbitrage Hook Contract
# This script deploys the ArbHookContract to Ethereum mainnet

set -e

echo "🚀 Starting deployment of ArbHookContract to Ethereum Mainnet"
echo "=================================================="

# Check if .env.mainnet exists
if [ ! -f ".env.mainnet" ]; then
    echo "❌ Error: .env.mainnet file not found"
    echo "Please create .env.mainnet with required configuration"
    exit 1
fi

# Load environment variables
source .env.mainnet

echo "📋 Deployment Configuration:"
echo "  Chain ID: $CHAIN_ID"
echo "  RPC URL: $RPC_URL"
echo "  Gas Limit: $GAS_LIMIT"
echo "  Gas Price: $GAS_PRICE"
echo ""

# Verify private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY not set in .env.mainnet"
    exit 1
fi

# Verify RPC URL is set
if [ -z "$RPC_URL" ]; then
    echo "❌ Error: RPC_URL not set in .env.mainnet"
    exit 1
fi

echo "🔨 Building contracts..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"
echo ""

echo "🎯 Deploying ArbHookContract..."
echo "This may take a few minutes on mainnet..."

# Deploy the contract
forge script script/DeployArbHook.s.sol:DeployArbHook \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --chain-id $CHAIN_ID

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Deployment successful!"
    echo "=================================================="
    echo "Next steps:"
    echo "1. Note the deployed contract address from the output above"
    echo "2. Initialize pools with this hook address"
    echo "3. Monitor for arbitrage opportunities"
    echo "4. Use withdrawProfits() to claim accumulated profits"
    echo ""
    echo "⚠️  Important: Save the contract address for future interactions!"
else
    echo "❌ Deployment failed"
    echo "Please check the error messages above and try again"
    exit 1
fi