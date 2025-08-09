#!/bin/bash

# Simple Proof Generation Script
# Usage: ./generate_proof.sh <circuit_filename> [input_file]
# Example: ./generate_proof.sh multiplier2.circom input.json

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
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if filename is provided
if [ $# -eq 0 ]; then
    print_error "Please provide a circom filename"
    echo "Usage: $0 <circuit_filename> [input_file]"
    echo "Example: $0 multiplier2.circom"
    echo "Example: $0 multiplier2.circom custom_input.json"
    exit 1
fi

CIRCUIT_FILE="$1"
CIRCUIT_NAME="${CIRCUIT_FILE%.*}"  # Remove .circom extension
INPUT_FILE="${2:-input.json}"  # Use provided input file or default to input.json

# Check if input file is specified as relative path, convert to absolute path from main directory
if [[ "$INPUT_FILE" != /* ]] && [[ "$INPUT_FILE" != ../* ]]; then
    # If it's just a filename, check if it exists in main directory first
    if [ -f "../$INPUT_FILE" ]; then
        INPUT_FILE="../$INPUT_FILE"
    fi
fi

# Check if circom file exists
if [ ! -f "$CIRCUIT_FILE" ]; then
    print_error "Circuit file $CIRCUIT_FILE not found!"
    exit 1
fi

JS_DIR="${CIRCUIT_NAME}_js"

# Check if setup is complete
if [ ! -d "$JS_DIR" ]; then
    print_error "Directory $JS_DIR not found! Please run the full workflow first."
    exit 1
fi

cd "$JS_DIR"

# Check for required files
REQUIRED_FILES=("${CIRCUIT_NAME}.wasm" "${CIRCUIT_NAME}_0001.zkey" "verification_key.json" "generate_witness.js")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file $file not found! Please run the full workflow first."
        exit 1
    fi
done

# Check if input file exists, if not create default in main directory
if [ ! -f "$INPUT_FILE" ]; then
    if [ "$INPUT_FILE" = "input.json" ] || [ "$INPUT_FILE" = "../input.json" ]; then
        print_warning "Input file not found, creating default input.json in main directory..."
        echo '{ "a": "3", "b": "11" }' > ../input.json
        INPUT_FILE="../input.json"
        print_success "Created input.json with default values (a=3, b=11)"
    else
        print_error "Input file $INPUT_FILE not found!"
        exit 1
    fi
fi

print_step "Generating Proof for $CIRCUIT_FILE"

# Step 1: Generate witness
print_step "1. Computing Witness"
echo "Using input file: $INPUT_FILE"
echo "Running: node generate_witness.js ${CIRCUIT_NAME}.wasm $INPUT_FILE witness.wtns"
node generate_witness.js "${CIRCUIT_NAME}.wasm" "$INPUT_FILE" witness.wtns
print_success "Witness computed successfully"

# Step 2: Generate Proof
print_step "2. Generating Proof"
echo "Running: snarkjs groth16 prove ${CIRCUIT_NAME}_0001.zkey witness.wtns proof.json public.json"
snarkjs groth16 prove "${CIRCUIT_NAME}_0001.zkey" witness.wtns proof.json public.json
print_success "Proof generated successfully"

# Step 3: Verify Proof
print_step "3. Verifying Proof"
echo "Running: snarkjs groth16 verify verification_key.json public.json proof.json"
VERIFICATION_RESULT=$(snarkjs groth16 verify verification_key.json public.json proof.json)

if echo "$VERIFICATION_RESULT" | grep -q "OK"; then
    print_success "Proof verification: OK ✓"
else
    print_error "Proof verification failed!"
    echo "$VERIFICATION_RESULT"
    exit 1
fi

# Step 4: Show input and output
print_step "4. Proof Summary"
echo "Input file used: $INPUT_FILE"
echo "Input values:"
cat "$INPUT_FILE" | jq .
echo ""
echo "Public outputs:"
cat public.json | jq .
echo ""
echo "Call parameters for smart contract verification:"
echo "-----------------------------------------------"
snarkjs generatecall

cd ..

print_success "Proof generation complete!"
echo ""
echo "Files generated in ${JS_DIR}/:"
echo "  - proof.json: The zk-proof"
echo "  - public.json: Public inputs and outputs"
echo "  - witness.wtns: Computed witness" 