#!/bin/bash

# Cross-Chain ZK Proof Receiver Monitoring Script
# Usage: ./receive_proof.sh [receiver_address] [chain2_rpc_url]

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

print_step "Cross-Chain ZK Proof Receiver Monitor"

# Function to load deployment information
load_deployment_info() {
    # Find the most recent deployment log file
    LATEST_DEPLOYMENT_LOG=$(ls -t cross_chain_deployments_*.log 2>/dev/null | head -n 1)
    
    if [ -n "$LATEST_DEPLOYMENT_LOG" ] && [ -f "$LATEST_DEPLOYMENT_LOG" ]; then
        print_success "Found deployment log: $LATEST_DEPLOYMENT_LOG"
        
        # Extract information from deployment log
        CHAIN2_RPC_URL=$(grep "Chain 2 RPC:" "$LATEST_DEPLOYMENT_LOG" | cut -d' ' -f4-)
        RECEIVER_CONTRACT=$(grep "Chain 2 - ZKProofReceiver:" "$LATEST_DEPLOYMENT_LOG" | awk '{print $5}')
        
        if [ -n "$RECEIVER_CONTRACT" ] && [ -n "$CHAIN2_RPC_URL" ]; then
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
    echo "Using deployment info from: $LATEST_DEPLOYMENT_LOG"
else
    # Fallback to manual input or arguments
    RECEIVER_CONTRACT="$1"
    CHAIN2_RPC_URL="$2"
    
    if [ -z "$RECEIVER_CONTRACT" ]; then
        prompt_input "Enter ZKProofReceiver contract address (Chain 2)" "RECEIVER_CONTRACT"
    fi
    
    if [ -z "$CHAIN2_RPC_URL" ]; then
        prompt_input "Enter Chain 2 RPC URL (receiver chain)" "CHAIN2_RPC_URL" "https://api.avax-test.network/ext/bc/C/rpc"
    fi
fi

echo ""
print_step "Configuration"
echo "Receiver Contract: $RECEIVER_CONTRACT"
echo "Chain 2 RPC: $CHAIN2_RPC_URL"
echo ""

# Test connectivity
print_step "Testing Chain 2 Connectivity"
if command -v cast &> /dev/null; then
    CHAIN2_ID=$(cast chain-id --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "Chain 2 connection successful - Chain ID: $CHAIN2_ID"
    else
        print_error "Failed to connect to Chain 2"
        exit 1
    fi
else
    print_error "Cast not found. Please install Foundry: https://getfoundry.sh/"
    exit 1
fi

# Function to get latest proof data
get_latest_proof() {
    print_step "Getting Latest Proof Data"
    
    # Call getLatestProof function
    LATEST_PROOF_RESULT=$(cast call $RECEIVER_CONTRACT "getLatestProof()" --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$LATEST_PROOF_RESULT" ]; then
        # Parse the result (it returns uint[1] memory pubSignals)
        PUBLIC_SIGNAL=$(echo $LATEST_PROOF_RESULT | sed 's/0x//' | sed 's/^0*//' | sed 's/^$/0/')
        if [ -z "$PUBLIC_SIGNAL" ] || [ "$PUBLIC_SIGNAL" = "0" ]; then
            print_warning "No proof data stored yet"
            return 1
        else
            print_success "Latest stored public signal: $PUBLIC_SIGNAL"
            # Convert hex to decimal
            DECIMAL_SIGNAL=$((0x$PUBLIC_SIGNAL))
            echo "Public signal (decimal): $DECIMAL_SIGNAL"
            return 0
        fi
    else
        print_warning "Could not retrieve latest proof data"
        return 1
    fi
}

# Function to verify stored proof
verify_stored_proof() {
    print_step "Verifying Stored Proof"
    
    # Call verifyStoredProof function
    VERIFY_RESULT=$(cast call $RECEIVER_CONTRACT "verifyStoredProof()" --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        if [ "$VERIFY_RESULT" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
            print_success "Stored proof verification: VALID ✅"
            return 0
        elif [ "$VERIFY_RESULT" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
            print_error "Stored proof verification: INVALID ❌"
            return 1
        else
            print_warning "Unexpected verification result: $VERIFY_RESULT"
            return 1
        fi
    else
        print_error "Failed to call verifyStoredProof function"
        return 1
    fi
}

# Function to get recent events
get_recent_events() {
    print_step "Checking Recent Events"
    
    # Get current block number
    CURRENT_BLOCK=$(cast block-number --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    if [ $? -ne 0 ]; then
        print_error "Failed to get current block number"
        return 1
    fi
    
    # Calculate block range (last 1000 blocks)
    FROM_BLOCK=$((CURRENT_BLOCK - 1000))
    if [ $FROM_BLOCK -lt 0 ]; then
        FROM_BLOCK=0
    fi
    
    echo "Scanning blocks $FROM_BLOCK to $CURRENT_BLOCK..."
    
    # Check for ProofVerificationSuccess events
    echo ""
    echo "🔍 ProofVerificationSuccess Events:"
    echo "-----------------------------------"
    
    SUCCESS_LOGS=$(cast logs --from-block $FROM_BLOCK --to-block $CURRENT_BLOCK \
        --address $RECEIVER_CONTRACT \
        --rpc-url $CHAIN2_RPC_URL 2>/dev/null || true)
    
    if [ -n "$SUCCESS_LOGS" ]; then
        echo "$SUCCESS_LOGS" | while read -r log; do
            if [ -n "$log" ]; then
                echo "Event found: $log"
            fi
        done
    else
        print_warning "No ProofVerificationSuccess events found in recent blocks"
    fi
    
    echo ""
    echo "🔍 ProofReceived Events:"
    echo "------------------------"
    
    # Check for ProofReceived events
    RECEIVED_LOGS=$(cast logs --from-block $FROM_BLOCK --to-block $CURRENT_BLOCK \
        --address $RECEIVER_CONTRACT \
        --rpc-url $CHAIN2_RPC_URL 2>/dev/null || true)
    
    if [ -n "$RECEIVED_LOGS" ]; then
        echo "$RECEIVED_LOGS" | while read -r log; do
            if [ -n "$log" ]; then
                echo "Event found: $log"
            fi
        done
    else
        print_warning "No ProofReceived events found in recent blocks"
    fi
}

# Function to test direct proof verification
test_direct_verification() {
    print_step "Testing Direct Proof Verification"
    
    # Check if proof.json exists
    if [ ! -f "proof.json" ]; then
        print_warning "proof.json not found, skipping direct verification test"
        return 1
    fi
    
    if [ ! -f "public.json" ]; then
        print_warning "public.json not found, skipping direct verification test"
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found, skipping direct verification test"
        return 1
    fi
    
    print_success "Found local proof files, testing direct verification..."
    
    # Extract proof components and format as hex
    PA_X=$(jq -r '.pi_a[0]' proof.json | sed 's/^/0x/')
    PA_Y=$(jq -r '.pi_a[1]' proof.json | sed 's/^/0x/')
    
    PB_X_C0=$(jq -r '.pi_b[0][1]' proof.json | sed 's/^/0x/')
    PB_X_C1=$(jq -r '.pi_b[0][0]' proof.json | sed 's/^/0x/')
    PB_Y_C0=$(jq -r '.pi_b[1][1]' proof.json | sed 's/^/0x/')
    PB_Y_C1=$(jq -r '.pi_b[1][0]' proof.json | sed 's/^/0x/')
    
    PC_X=$(jq -r '.pi_c[0]' proof.json | sed 's/^/0x/')
    PC_Y=$(jq -r '.pi_c[1]' proof.json | sed 's/^/0x/')
    
    PUBLIC_SIGNAL_DEC=$(jq -r '.[0]' public.json)
    PUBLIC_SIGNAL=$(printf "0x%x" $PUBLIC_SIGNAL_DEC)
    
    # Call verifyProofDirectly
    DIRECT_VERIFY_RESULT=$(cast call $RECEIVER_CONTRACT \
        "verifyProofDirectly(uint256[2],uint256[2][2],uint256[2],uint256[1])" \
        "[$PA_X,$PA_Y]" \
        "[[$PB_X_C0,$PB_X_C1],[$PB_Y_C0,$PB_Y_C1]]" \
        "[$PC_X,$PC_Y]" \
        "[$PUBLIC_SIGNAL]" \
        --rpc-url $CHAIN2_RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        if [ "$DIRECT_VERIFY_RESULT" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
            print_success "Direct proof verification: VALID ✅"
            echo "Public signal verified: $PUBLIC_SIGNAL"
        else
            print_error "Direct proof verification: INVALID ❌"
        fi
    else
        print_error "Failed to call verifyProofDirectly function"
    fi
}

# Main monitoring loop
main_monitor() {
    echo ""
    print_step "ZK Proof Receiver Status Report"
    echo "=============================================="
    
    # Check latest proof data
    get_latest_proof
    echo ""
    
    # Verify stored proof
    verify_stored_proof
    echo ""
    
    # Test direct verification with local files
    test_direct_verification
    echo ""
    
    # Get recent events
    get_recent_events
    echo ""
    
    print_step "Monitoring Complete"
    echo "=============================================="
}

# Run the monitoring
main_monitor

# Ask if user wants continuous monitoring
echo ""
prompt_input "Do you want to enable continuous monitoring? (y/n)" "CONTINUOUS" "n"

if [ "$CONTINUOUS" = "y" ] || [ "$CONTINUOUS" = "Y" ]; then
    print_step "Starting Continuous Monitoring"
    echo "Press Ctrl+C to stop..."
    echo ""
    
    while true; do
        sleep 10
        echo "$(date): Checking for new events..."
        get_recent_events
        echo "---"
    done
else
    print_success "Monitoring completed! 🎉"
    echo ""
    echo "Tips:"
    echo "- Run this script again to check for updates"
    echo "- Use continuous monitoring mode for real-time updates"
    echo "- Check the contract events in a block explorer for more details"
fi 