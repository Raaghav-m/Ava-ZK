#!/bin/bash

# Cross-Chain ZK Proof Sender Script
# Usage: ./send_proof.sh [sender_address] [receiver_address] [destination_chain_id]

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

print_step "Cross-Chain ZK Proof Sender"

# Function to load deployment information
load_deployment_info() {
    # Find the most recent deployment log file
    LATEST_DEPLOYMENT_LOG=$(ls -t cross_chain_deployments_*.log 2>/dev/null | head -n 1)
    
    if [ -n "$LATEST_DEPLOYMENT_LOG" ] && [ -f "$LATEST_DEPLOYMENT_LOG" ]; then
        print_success "Found deployment log: $LATEST_DEPLOYMENT_LOG"
        
        # Extract information from deployment log
        CHAIN1_RPC_URL=$(grep "Chain 1 RPC:" "$LATEST_DEPLOYMENT_LOG" | cut -d' ' -f4-)
        CHAIN2_RPC_URL=$(grep "Chain 2 RPC:" "$LATEST_DEPLOYMENT_LOG" | cut -d' ' -f4-)
        SENDER_CONTRACT=$(grep "Chain 1 - ZKProofSender:" "$LATEST_DEPLOYMENT_LOG" | awk '{print $5}')
        RECEIVER_CONTRACT=$(grep "Chain 2 - ZKProofReceiver:" "$LATEST_DEPLOYMENT_LOG" | awk '{print $5}')
        
        if [ -n "$SENDER_CONTRACT" ] && [ -n "$RECEIVER_CONTRACT" ] && [ -n "$CHAIN1_RPC_URL" ] && [ -n "$CHAIN2_RPC_URL" ]; then
            print_success "Loaded deployment information automatically"
            return 0
        else
            print_warning "Incomplete deployment information in log file"
            return 1
        fi
    else
        print_warning "No deployment log found"
        return 1
    fi
}

# Try to load from deployment log first
if load_deployment_info; then
    echo "Deployment information loaded successfully"
else
    # Fallback to manual input or arguments
    SENDER_CONTRACT="$1"
    RECEIVER_CONTRACT="$2"
    DESTINATION_CHAIN_ID="$3"
    
    if [ -z "$SENDER_CONTRACT" ]; then
        prompt_input "Enter ZKProofSender contract address (Chain 1)" "SENDER_CONTRACT"
    fi
    
    if [ -z "$RECEIVER_CONTRACT" ]; then
        prompt_input "Enter ZKProofReceiver contract address (Chain 2)" "RECEIVER_CONTRACT"
    fi
    
    if [ -z "$DESTINATION_CHAIN_ID" ]; then
        prompt_input "Enter destination blockchain ID (Chain 2)" "DESTINATION_CHAIN_ID"
    fi
    
         # Prompt for RPC URLs
     prompt_input "Enter Chain 1 RPC URL (sender chain)" "CHAIN1_RPC_URL" "https://api.avax-test.network/ext/bc/C/rpc"
fi

# Always prompt for destination chain ID
prompt_input "Enter destination blockchain ID (Chain 2) as hex string" "DESTINATION_CHAIN_ID"
print_success "Using destination chain ID: $DESTINATION_CHAIN_ID"

echo ""
print_step "Configuration"
echo "Sender Contract: $SENDER_CONTRACT"
echo "Receiver Contract: $RECEIVER_CONTRACT"
echo "Destination Chain ID: $DESTINATION_CHAIN_ID"
echo "Chain 1 RPC: $CHAIN1_RPC_URL"
echo ""

# Check if proof.json exists
if [ ! -f "proof.json" ]; then
    print_error "proof.json not found! Please run circom workflow first."
    exit 1
fi

if [ ! -f "public.json" ]; then
    print_error "public.json not found! Please run circom workflow first."
    exit 1
fi

print_success "Found proof.json and public.json"

# Parse proof.json and public.json using jq
if ! command -v jq &> /dev/null; then
    print_error "jq not found. Please install jq for JSON parsing"
    exit 1
fi

# Extract proof components and convert decimal to hex using Python
PA_X=$(jq -r '.pi_a[0]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")
PA_Y=$(jq -r '.pi_a[1]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")

PB_X_C0=$(jq -r '.pi_b[0][1]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")
PB_X_C1=$(jq -r '.pi_b[0][0]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")
PB_Y_C0=$(jq -r '.pi_b[1][1]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")
PB_Y_C1=$(jq -r '.pi_b[1][0]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")

PC_X=$(jq -r '.pi_c[0]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")
PC_Y=$(jq -r '.pi_c[1]' proof.json | python3 -c "import sys; print('0x' + hex(int(sys.stdin.read().strip()))[2:])")

# Extract public signals and convert decimal to hex
PUBLIC_SIGNAL_DEC=$(jq -r '.[0]' public.json)
PUBLIC_SIGNAL=$(printf "0x%x" $PUBLIC_SIGNAL_DEC)

print_step "Proof Components"
echo "pA: [$PA_X, $PA_Y]"
echo "pB: [[$PB_X_C0, $PB_X_C1], [$PB_Y_C0, $PB_Y_C1]]"
echo "pC: [$PC_X, $PC_Y]"
echo "Public Signal: $PUBLIC_SIGNAL"
echo ""

# Test connectivity
print_step "Testing Chain 1 Connectivity"
if command -v cast &> /dev/null; then
    CHAIN1_ID=$(cast chain-id --rpc-url $CHAIN1_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "Chain 1 connection successful - Chain ID: $CHAIN1_ID"
    else
        print_error "Failed to connect to Chain 1"
        exit 1
    fi
else
    print_error "Cast not found. Please install Foundry: https://getfoundry.sh/"
    exit 1
fi

# Send the proof
print_step "Sending Cross-Chain Proof"

echo ""
print_step "Sending Transaction"
echo "This will call sendProof on the ZKProofSender contract..."

# Construct the cast send command (hardcoded fee, no metadata)
cast send $SENDER_CONTRACT "sendProof(bytes32,address,uint256[2],uint256[2][2],uint256[2],uint256[1])" \
    $DESTINATION_CHAIN_ID \
    $RECEIVER_CONTRACT \
    "[$PA_X,$PA_Y]" \
    "[[$PB_X_C0,$PB_X_C1],[$PB_Y_C0,$PB_Y_C1]]" \
    "[$PC_X,$PC_Y]" \
    "[$PUBLIC_SIGNAL]" \
    --rpc-url $CHAIN1_RPC_URL \
    --private-key $PRIVATE_KEY



echo "Executing transaction..."
echo "$CAST_CMD"
echo ""

# Execute the transaction
echo "Running command..."
RESULT=$($CAST_CMD 2>&1)
EXIT_CODE=$?
echo "Command completed with exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 0 ]; then
    print_success "Cross-chain proof sent successfully!"
    echo "Transaction hash: $RESULT"
    
    # Create log file
    LOG_FILE="proof_send_$(date +%Y%m%d_%H%M%S).log"
    echo "Cross-Chain Proof Send Log - $(date)" > $LOG_FILE
    echo "Sender Contract: $SENDER_CONTRACT" >> $LOG_FILE
    echo "Receiver Contract: $RECEIVER_CONTRACT" >> $LOG_FILE
    echo "Destination Chain ID: $DESTINATION_CHAIN_ID" >> $LOG_FILE
    echo "Transaction Hash: $RESULT" >> $LOG_FILE
    echo "Public Signal: $PUBLIC_SIGNAL" >> $LOG_FILE
    
    print_success "Transaction logged to: $LOG_FILE"
    
    echo ""
    echo "Next Steps:"
    echo "1. Wait for cross-chain message delivery (may take a few minutes)"
    echo "2. Check for ProofVerificationSuccess event on Chain 2"
    echo "3. Monitor the ZKProofReceiver contract at: $RECEIVER_CONTRACT"
    
else
    print_error "Transaction failed!"
    echo "Error: $RESULT"
    echo ""
    echo "Possible issues:"
    echo "- Insufficient gas/native tokens"
    echo "- Invalid proof (verify with local verification first)"
    echo "- Contract addresses incorrect"
    echo "- RPC connection issues"
    exit 1
fi

print_success "Cross-chain ZK proof sending completed! 🎉" 