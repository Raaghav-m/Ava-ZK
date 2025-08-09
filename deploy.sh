#!/bin/bash

# ZK Proof Cross-Chain Contract Deployment Script using Forge
# Usage: ./deploy.sh

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

# Function to prompt for user input
prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="$3"
    
    if [ -n "$default_value" ]; then
        echo -n "$prompt_text [$default_value]: "
    else
        echo -n "$prompt_text: "
    fi
    
    read user_input
    
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        user_input="$default_value"
    fi
    
    eval "$var_name='$user_input'"
}

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    print_success "Loaded environment variables from .env"
else
    print_warning "No .env file found, using environment variables"
fi

# Validate required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    print_error "PRIVATE_KEY not set in environment"
    exit 1
fi

print_step "Cross-Chain ZK Proof Deployment Setup"
echo "This script will deploy:"
echo "1. Groth16Verifier on both chains"
echo "2. ZKProofSender on Chain 1"
echo "3. ZKProofReceiver on Chain 2"
echo ""

# Prompt for RPC URLs
prompt_input "Enter Chain 1 RPC URL (for ZKProofSender)" "CHAIN1_RPC_URL" "https://api.avax-test.network/ext/bc/C/rpc"
prompt_input "Enter Chain 2 RPC URL (for ZKProofReceiver)" "CHAIN2_RPC_URL" "https://api.avax-test.network/ext/bc/C/rpc"

# Set default Teleporter address
TELEPORTER_ADDRESS="0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf"
prompt_input "Enter Teleporter address" "TELEPORTER_ADDRESS" "$TELEPORTER_ADDRESS"

echo ""
print_step "Configuration Summary"
echo "Chain 1 RPC: $CHAIN1_RPC_URL"
echo "Chain 2 RPC: $CHAIN2_RPC_URL"
echo "Teleporter: $TELEPORTER_ADDRESS"
echo ""

# Basic connectivity tests
print_step "Pre-flight Checks"
echo "Testing RPC connectivity..."

if command -v cast &> /dev/null; then
    echo "Testing Chain 1..."
    CHAIN1_ID=$(cast chain-id --rpc-url $CHAIN1_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "Chain 1 connection successful - Chain ID: $CHAIN1_ID"
    else
        print_warning "Chain 1 connection failed - continuing anyway"
    fi
    
    echo "Testing Chain 2..."
    CHAIN2_ID=$(cast chain-id --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "Chain 2 connection successful - Chain ID: $CHAIN2_ID"
    else
        print_warning "Chain 2 connection failed - continuing anyway"
    fi
else
    print_warning "Cast not available - skipping connectivity test"
fi

# Check if contract files exist
if [ -f "contracts/Groth16Verifier.sol" ]; then
    print_success "Contract file found: contracts/Groth16Verifier.sol"
else
    print_error "Contract file not found: contracts/Groth16Verifier.sol"
    exit 1
fi

if [ -f "contracts/ZKProofSender.sol" ]; then
    print_success "Contract file found: contracts/ZKProofSender.sol"
else
    print_error "Contract file not found: contracts/ZKProofSender.sol"
    exit 1
fi

if [ -f "contracts/ZKProofReceiver.sol" ]; then
    print_success "Contract file found: contracts/ZKProofReceiver.sol"
else
    print_error "Contract file not found: contracts/ZKProofReceiver.sol"
    exit 1
fi

echo ""

# Check required tools
if ! command -v forge &> /dev/null; then
    print_error "Forge not found. Please install Foundry: https://getfoundry.sh/"
    exit 1
fi

# Create deployment log file
DEPLOYMENT_LOG="cross_chain_deployments_$(date +%Y%m%d_%H%M%S).log"
echo "Cross-Chain Deployment Log - $(date)" > $DEPLOYMENT_LOG
echo "Chain 1 RPC: $CHAIN1_RPC_URL" >> $DEPLOYMENT_LOG
echo "Chain 2 RPC: $CHAIN2_RPC_URL" >> $DEPLOYMENT_LOG
echo "Teleporter: $TELEPORTER_ADDRESS" >> $DEPLOYMENT_LOG
echo "===========================================" >> $DEPLOYMENT_LOG

# Deploy Groth16Verifier on Chain 1
print_step "1. Deploying Groth16Verifier on Chain 1"
echo "Running: forge create contracts/Groth16Verifier.sol:Groth16Verifier"

VERIFIER1_DEPLOYMENT=$(forge create contracts/Groth16Verifier.sol:Groth16Verifier \
    --rpc-url $CHAIN1_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast 2>&1)

if [ $? -eq 0 ]; then
    VERIFIER1_ADDRESS=$(echo "$VERIFIER1_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
    VERIFIER1_TX=$(echo "$VERIFIER1_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
    
    if [ -n "$VERIFIER1_ADDRESS" ] && [ -n "$VERIFIER1_TX" ]; then
        print_success "Groth16Verifier deployed on Chain 1: $VERIFIER1_ADDRESS"
        echo "Transaction: $VERIFIER1_TX"
        echo "Chain 1 - Groth16Verifier: $VERIFIER1_ADDRESS" >> $DEPLOYMENT_LOG
        echo "Chain 1 - TX: $VERIFIER1_TX" >> $DEPLOYMENT_LOG
    else
        print_error "Could not parse Chain 1 verifier deployment output"
        exit 1
    fi
else
    print_error "Failed to deploy Groth16Verifier on Chain 1"
    exit 1
fi

# Deploy Groth16Verifier on Chain 2
print_step "2. Deploying Groth16Verifier on Chain 2"

VERIFIER2_DEPLOYMENT=$(forge create contracts/Groth16Verifier.sol:Groth16Verifier \
    --rpc-url $CHAIN2_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast 2>&1)

if [ $? -eq 0 ]; then
    VERIFIER2_ADDRESS=$(echo "$VERIFIER2_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
    VERIFIER2_TX=$(echo "$VERIFIER2_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
    
    if [ -n "$VERIFIER2_ADDRESS" ] && [ -n "$VERIFIER2_TX" ]; then
        print_success "Groth16Verifier deployed on Chain 2: $VERIFIER2_ADDRESS"
        echo "Transaction: $VERIFIER2_TX"
        echo "Chain 2 - Groth16Verifier: $VERIFIER2_ADDRESS" >> $DEPLOYMENT_LOG
        echo "Chain 2 - TX: $VERIFIER2_TX" >> $DEPLOYMENT_LOG
    else
        print_error "Could not parse Chain 2 verifier deployment output"
        exit 1
    fi
else
    print_error "Failed to deploy Groth16Verifier on Chain 2"
    exit 1
fi

# Deploy ZKProofSender on Chain 1
print_step "3. Deploying ZKProofSender on Chain 1"
echo "Teleporter Address: $TELEPORTER_ADDRESS"
echo "Verifier Address: $VERIFIER1_ADDRESS"

SENDER_DEPLOYMENT=$(forge create contracts/ZKProofSender.sol:ZKProofSender \
    --rpc-url $CHAIN1_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args $TELEPORTER_ADDRESS $VERIFIER1_ADDRESS 2>&1)

if [ $? -eq 0 ]; then
    SENDER_ADDRESS=$(echo "$SENDER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
    SENDER_TX=$(echo "$SENDER_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
    
    if [ -n "$SENDER_ADDRESS" ] && [ -n "$SENDER_TX" ]; then
        print_success "ZKProofSender deployed on Chain 1: $SENDER_ADDRESS"
        echo "Transaction: $SENDER_TX"
        echo "Chain 1 - ZKProofSender: $SENDER_ADDRESS" >> $DEPLOYMENT_LOG
        echo "Chain 1 - Sender TX: $SENDER_TX" >> $DEPLOYMENT_LOG
    else
        print_error "Could not parse ZKProofSender deployment output"
        exit 1
    fi
else
    print_error "Failed to deploy ZKProofSender on Chain 1"
    exit 1
fi

# Deploy ZKProofReceiver on Chain 2
print_step "4. Deploying ZKProofReceiver on Chain 2"
echo "Teleporter Address: $TELEPORTER_ADDRESS"
echo "Verifier Address: $VERIFIER2_ADDRESS"

RECEIVER_DEPLOYMENT=$(forge create contracts/ZKProofReceiver.sol:ZKProofReceiver \
    --rpc-url $CHAIN2_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args $TELEPORTER_ADDRESS $VERIFIER2_ADDRESS 2>&1)

if [ $? -eq 0 ]; then
    RECEIVER_ADDRESS=$(echo "$RECEIVER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
    RECEIVER_TX=$(echo "$RECEIVER_DEPLOYMENT" | grep "Transaction hash:" | awk '{print $3}')
    
    if [ -n "$RECEIVER_ADDRESS" ] && [ -n "$RECEIVER_TX" ]; then
        print_success "ZKProofReceiver deployed on Chain 2: $RECEIVER_ADDRESS"
        echo "Transaction: $RECEIVER_TX"
        echo "Chain 2 - ZKProofReceiver: $RECEIVER_ADDRESS" >> $DEPLOYMENT_LOG
        echo "Chain 2 - Receiver TX: $RECEIVER_TX" >> $DEPLOYMENT_LOG
    else
        print_error "Could not parse ZKProofReceiver deployment output"
        exit 1
    fi
else
    print_error "Failed to deploy ZKProofReceiver on Chain 2"
    exit 1
fi

# Final summary
print_step "Cross-Chain Deployment Summary"
echo "==============================================="
echo "CHAIN 1 (Sender Chain):"
echo "  Chain ID: $CHAIN1_ID"
echo "  RPC URL: $CHAIN1_RPC_URL"
echo "  Groth16Verifier: $VERIFIER1_ADDRESS"
echo "  ZKProofSender: $SENDER_ADDRESS"
echo ""
echo "CHAIN 2 (Receiver Chain):"
echo "  Chain ID: $CHAIN2_ID"
echo "  RPC URL: $CHAIN2_RPC_URL"
echo "  Groth16Verifier: $VERIFIER2_ADDRESS"
echo "  ZKProofReceiver: $RECEIVER_ADDRESS"
echo ""
echo "SHARED:"
echo "  Teleporter: $TELEPORTER_ADDRESS"
echo "==============================================="
echo "Deployment log saved to: $DEPLOYMENT_LOG"

print_success "Cross-chain deployment completed successfully! 🎉"
echo ""
echo "Next steps:"
echo "1. Generate proofs: ./generate_proof.sh multiplier2.circom"
echo "2. Test cross-chain proof sending from Chain 1 to Chain 2"
echo "3. Monitor ProofVerificationSuccess events on Chain 2" 