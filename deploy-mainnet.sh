#!/bin/bash

# Mainnet Deployment Script for AsyncAdversarialHook Contract
# This script deploys the AsyncAdversarialHook to Ethereum mainnet with proper salt mining

set -e

echo "🚀 Starting deployment of AsyncAdversarialHook to Ethereum Mainnet"
echo "=============================================================="

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
echo "  Contract: AsyncAdversarialHook"
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

echo "🔨 Building contracts with IR optimization..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"
echo ""

# Verify foundry configuration
echo "🔧 Verifying Foundry configuration..."
grep -q "via_ir = true" foundry.toml && echo "✅ IR compilation enabled" || echo "⚠️ Warning: IR compilation not enabled"
grep -q "optimizer_runs = 44444444" foundry.toml && echo "✅ High optimization enabled" || echo "⚠️ Warning: Default optimization settings"
echo ""

echo "🎯 Deploying AsyncAdversarialHook with salt mining..."
echo "This may take several minutes on mainnet (salt mining + deployment)..."
echo ""

# Deploy the contract with salt mining
forge script script/DeployAsyncAdversarialHook.s.sol:DeployAsyncAdversarialHook \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --chain-id $CHAIN_ID

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 AsyncAdversarialHook deployment successful!"
    echo "=============================================================="
    echo "Next steps:"
    echo "1. Note the deployed contract address from the output above"
    echo "2. Create pools using: forge script script/CreatePoolWithHook.s.sol"
    echo "3. Configure hook settings if needed"
    echo "4. Monitor async operations and adversarial behavior"
    echo ""
    echo "📋 Available commands:"
    echo "  - Set adversarial mode: setAdversarialMode(bool)"
    echo "  - Configure delays: setAdversarialDelay(uint256)"
    echo "  - Set gas limits: setMaxGasConsumption(uint256)"
    echo "  - Transfer ownership: transferOwnership(address)"
    echo ""
    echo "⚠️  Important: Save the contract address for future interactions!"
    echo "⚠️  Security: Review adversarial settings before enabling on mainnet!"
else
    echo "❌ Deployment failed"
    echo "Please check the error messages above and try again"
    echo ""
    echo "Common issues:"
    echo "- Insufficient gas or ETH balance"
    echo "- Network connectivity problems"
    echo "- Salt mining timeout (try running again)"
    exit 1
fi