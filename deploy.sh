#!/bin/bash

# ZK Proof Contract Deployment Script using Forge
# Usage: ./deploy.sh [network]
# Example: ./deploy.sh fuji

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    print_success "Loaded environment variables from .env"
else
    print_warning "No .env file found, using environment variables"
fi

# Set network based on argument
NETWORK=${1:-local}

case $NETWORK in
    "fuji")
        RPC_URL=$AVALANCHE_FUJI_URL
        NETWORK_NAME="Avalanche Fuji Testnet"
        ;;
    "mainnet")
        RPC_URL=$AVALANCHE_MAINNET_URL
        NETWORK_NAME="Avalanche Mainnet"
        ;;
    "local"|"subnet-a")
        RPC_URL=$SUBNET_A_RPC_URL
        NETWORK_NAME="Local Subnet A"
        ;;
    "subnet-b")
        RPC_URL=$SUBNET_B_RPC_URL
        NETWORK_NAME="Local Subnet B"
        ;;
    *)
        print_error "Unknown network: $NETWORK"
        echo "Available networks: fuji, mainnet, local, subnet-a, subnet-b"
        exit 1
        ;;
esac

# Validate required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    print_error "PRIVATE_KEY not set in environment"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    print_error "RPC_URL not configured for network: $NETWORK"
    exit 1
fi

print_step "Starting Deployment on $NETWORK_NAME"
echo "RPC URL: $RPC_URL"
echo "Network: $NETWORK"
echo ""

# Basic connectivity test
print_step "Pre-flight Checks"
echo "Testing RPC connectivity..."
if command -v cast &> /dev/null; then
    CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "RPC connection successful - Chain ID: $CHAIN_ID"
    else
        print_warning "RPC connection failed - continuing anyway"
    fi
else
    print_warning "Cast not available - skipping connectivity test"
fi

# Check if contract file exists
if [ -f "contracts/Groth16Verifier.sol" ]; then
    print_success "Contract file found: contracts/Groth16Verifier.sol"
else
    print_error "Contract file not found: contracts/Groth16Verifier.sol"
    exit 1
fi
echo ""

# Create deployment log file
DEPLOYMENT_LOG="deployments_${NETWORK}_$(date +%Y%m%d_%H%M%S).log"
echo "Deployment Log - $(date)" > $DEPLOYMENT_LOG
echo "Network: $NETWORK_NAME" >> $DEPLOYMENT_LOG
echo "RPC URL: $RPC_URL" >> $DEPLOYMENT_LOG
echo "===========================================" >> $DEPLOYMENT_LOG

# Deploy Groth16Verifier
print_step "1. Deploying Groth16Verifier Contract"
echo "Running: forge create contracts/Groth16Verifier.sol:Groth16Verifier"

# First check if we have the required tools
if ! command -v forge &> /dev/null; then
    print_error "Forge not found. Please install Foundry: https://getfoundry.sh/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_error "jq not found. Please install jq for JSON parsing"
    exit 1
fi

# Deploy using forge create with --broadcast flag
echo "Deploying contract..."
VERIFIER_DEPLOYMENT=$(forge create contracts/Groth16Verifier.sol:Groth16Verifier \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast 2>&1)

DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    # Extract address and transaction hash from the broadcast output
    VERIFIER_ADDRESS=$(echo "$VERIFIER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
    VERIFIER_TX=$(echo "$VERIFIER_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
    
    if [ -n "$VERIFIER_ADDRESS" ] && [ -n "$VERIFIER_TX" ]; then
        print_success "Groth16Verifier deployed to: $VERIFIER_ADDRESS"
        echo "Transaction: $VERIFIER_TX"
        
        # Log deployment
        echo "Groth16Verifier: $VERIFIER_ADDRESS" >> $DEPLOYMENT_LOG
        echo "TX: $VERIFIER_TX" >> $DEPLOYMENT_LOG
    else
        print_error "Could not parse deployment output"
        echo "Full output: $VERIFIER_DEPLOYMENT"
        exit 1
    fi
else
    print_error "Failed to deploy Groth16Verifier"
    echo "Error output: $VERIFIER_DEPLOYMENT"
    echo "Possible issues:"
    echo "- Check if PRIVATE_KEY is correct (without 0x prefix)"
    echo "- Verify RPC_URL is accessible: $RPC_URL"
    echo "- Ensure you have enough gas/native tokens"
    echo "- Check if contracts/Groth16Verifier.sol exists"
    exit 1
fi

# Set default Teleporter address if not provided
if [ -z "$TELEPORTER_ADDRESS" ] || [ "$TELEPORTER_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    TELEPORTER_ADDRESS="0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf"
    print_success "Using default Teleporter address: $TELEPORTER_ADDRESS"
fi

# Deploy ZK Handler contracts
if [ -n "$TELEPORTER_ADDRESS" ]; then
    
    print_step "2. Deploying ZKProofSender Contract"
    echo "Teleporter Address: $TELEPORTER_ADDRESS"
    echo "Verifier Address: $VERIFIER_ADDRESS"
    
    SENDER_DEPLOYMENT=$(forge create contracts/ZKProofSender.sol:ZKProofSender \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --constructor-args $TELEPORTER_ADDRESS $VERIFIER_ADDRESS 
        )
    
    if [ $? -eq 0 ]; then
        SENDER_ADDRESS=$(echo "$SENDER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
        SENDER_TX=$(echo "$SENDER_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
        if [ -n "$SENDER_ADDRESS" ] && [ -n "$SENDER_TX" ]; then
            print_success "ZKProofSender deployed to: $SENDER_ADDRESS"
            echo "Transaction: $SENDER_TX"
            
            # Log deployment
            echo "ZKProofSender: $SENDER_ADDRESS" >> $DEPLOYMENT_LOG
            echo "TX: $SENDER_TX" >> $DEPLOYMENT_LOG
        else
            print_error "Could not parse ZKProofSender deployment output"
            exit 1
        fi
    else
        print_error "Failed to deploy ZKProofSender"
        exit 1
    fi
    
    print_step "3. Deploying ZKProofReceiver Contract"
    
    RECEIVER_DEPLOYMENT=$(forge create contracts/ZKProofReceiver.sol:ZKProofReceiver \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --constructor-args $TELEPORTER_ADDRESS $VERIFIER_ADDRESS \
        --broadcast 2>&1)
    
    if [ $? -eq 0 ]; then
        RECEIVER_ADDRESS=$(echo "$RECEIVER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
        RECEIVER_TX=$(echo "$RECEIVER_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
        
        if [ -n "$RECEIVER_ADDRESS" ] && [ -n "$RECEIVER_TX" ]; then
            print_success "ZKProofReceiver deployed to: $RECEIVER_ADDRESS"
            echo "Transaction: $RECEIVER_TX"
            
            # Log deployment
            echo "ZKProofReceiver: $RECEIVER_ADDRESS" >> $DEPLOYMENT_LOG
            echo "TX: $RECEIVER_TX" >> $DEPLOYMENT_LOG
        else
            print_error "Could not parse ZKProofReceiver deployment output"
            exit 1
        fi
    else
        print_error "Failed to deploy ZKProofReceiver"
        exit 1
    fi
    
fi

# Final summary
print_step "Deployment Summary"
echo "==============================================="
echo "Network: $NETWORK_NAME"
echo "Groth16Verifier: $VERIFIER_ADDRESS"

if [ -n "$SENDER_ADDRESS" ]; then
    echo "ZKProofSender: $SENDER_ADDRESS"
fi

if [ -n "$RECEIVER_ADDRESS" ]; then
    echo "ZKProofReceiver: $RECEIVER_ADDRESS"
fi

echo "==============================================="
echo "Deployment log saved to: $DEPLOYMENT_LOG"





print_success "Deployment completed successfully! 🎉"
echo ""
echo "Next steps:"
echo "1. Generate proofs: ./generate_proof.sh multiplier2.circom"
echo "2. Test verification using the deployed contracts"
echo "3. For cross-subnet demo: deploy on both subnets and test messaging" 