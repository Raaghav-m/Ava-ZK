#!/bin/bash

# Circom Workflow Automation Script
# Usage: ./circom_workflow.sh <circuit_filename>
# Example: ./circom_workflow.sh multiplier2.circom

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
    echo "Usage: $0 <circuit_filename>"
    echo "Example: $0 multiplier2.circom"
    exit 1
fi

CIRCUIT_FILE="$1"
CIRCUIT_NAME="${CIRCUIT_FILE%.*}"  # Remove .circom extension

# Check if circom file exists
if [ ! -f "$CIRCUIT_FILE" ]; then
    print_error "Circuit file $CIRCUIT_FILE not found!"
    exit 1
fi

print_step "Starting Circom Workflow for $CIRCUIT_FILE"

# Step 1: Compile the circuit
print_step "1. Compiling Circuit"
echo "Running: circom $CIRCUIT_FILE --r1cs --wasm --sym"
circom "$CIRCUIT_FILE" --r1cs --wasm --sym
print_success "Circuit compiled successfully"

# Step 2: Generate witness
print_step "2. Computing Witness with WebAssembly"

# Check if input.json exists in the js directory
JS_DIR="${CIRCUIT_NAME}_js"
if [ ! -d "$JS_DIR" ]; then
    print_error "Directory $JS_DIR not found!"
    exit 1
fi

cd "$JS_DIR"

if [ ! -f "input.json" ] && [ ! -f "../input.json" ]; then
    print_warning "input.json not found, creating default input in main directory..."
    echo '{ "a": "3", "b": "11" }' > ../input.json
    print_success "Created input.json with default values (a=3, b=11)"
fi

# Use input.json from main directory if it exists there, otherwise use local one
INPUT_FILE="input.json"
if [ -f "../input.json" ]; then
    INPUT_FILE="../input.json"
fi

echo "Running: node generate_witness.js ${CIRCUIT_NAME}.wasm $INPUT_FILE witness.wtns"
node generate_witness.js "${CIRCUIT_NAME}.wasm" "$INPUT_FILE" witness.wtns
print_success "Witness computed successfully"

# Step 3: Powers of Tau (if not already done)
print_step "3. Setting up Powers of Tau"

if [ ! -f "pot12_0000.ptau" ]; then
    echo "Running: snarkjs powersoftau new bn128 12 pot12_0000.ptau -v"
    snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
    print_success "Powers of tau ceremony started"
else
    print_success "pot12_0000.ptau already exists"
fi

if [ ! -f "pot12_0001.ptau" ]; then
    echo "Running: snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name=\"First contribution\" -v"
    snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
    print_success "Contributed to powers of tau ceremony"
else
    print_success "pot12_0001.ptau already exists"
fi

if [ ! -f "pot12_final.ptau" ]; then
    echo "Running: snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v"
    snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v
    print_success "Phase 2 preparation completed"
else
    print_success "pot12_final.ptau already exists"
fi

# Step 4: Phase 2 - Circuit-specific setup
print_step "4. Phase 2 Setup"

if [ ! -f "${CIRCUIT_NAME}_0000.zkey" ]; then
    echo "Running: snarkjs groth16 setup ../${CIRCUIT_NAME}.r1cs pot12_final.ptau ${CIRCUIT_NAME}_0000.zkey"
    snarkjs groth16 setup "../${CIRCUIT_NAME}.r1cs" pot12_final.ptau "${CIRCUIT_NAME}_0000.zkey"
    print_success "Initial zkey generated"
else
    print_success "${CIRCUIT_NAME}_0000.zkey already exists"
fi

if [ ! -f "${CIRCUIT_NAME}_0001.zkey" ]; then
    echo "Running: snarkjs zkey contribute ${CIRCUIT_NAME}_0000.zkey ${CIRCUIT_NAME}_0001.zkey --name=\"1st Contributor Name\" -v"
    snarkjs zkey contribute "${CIRCUIT_NAME}_0000.zkey" "${CIRCUIT_NAME}_0001.zkey" --name="1st Contributor Name" -v
    print_success "Contributed to phase 2"
else
    print_success "${CIRCUIT_NAME}_0001.zkey already exists"
fi

if [ ! -f "verification_key.json" ]; then
    echo "Running: snarkjs zkey export verificationkey ${CIRCUIT_NAME}_0001.zkey verification_key.json"
    snarkjs zkey export verificationkey "${CIRCUIT_NAME}_0001.zkey" verification_key.json
    print_success "Verification key exported"
else
    print_success "verification_key.json already exists"
fi

# Step 5: Generate Proof
print_step "5. Generating Proof"
echo "Running: snarkjs groth16 prove ${CIRCUIT_NAME}_0001.zkey witness.wtns proof.json public.json"
snarkjs groth16 prove "${CIRCUIT_NAME}_0001.zkey" witness.wtns proof.json public.json
print_success "Proof generated successfully"

# Step 6: Verify Proof
print_step "6. Verifying Proof"
echo "Running: snarkjs groth16 verify verification_key.json public.json proof.json"
VERIFICATION_RESULT=$(snarkjs groth16 verify verification_key.json public.json proof.json)

if echo "$VERIFICATION_RESULT" | grep -q "OK"; then
    print_success "Proof verification: OK ✓"
else
    print_error "Proof verification failed!"
    echo "$VERIFICATION_RESULT"
    exit 1
fi

# Step 7: Generate Solidity Verifier
print_step "7. Generating Solidity Verifier"
echo "Running: snarkjs zkey export solidityverifier ${CIRCUIT_NAME}_0001.zkey ../verifier.sol"
snarkjs zkey export solidityverifier "${CIRCUIT_NAME}_0001.zkey" ../verifier.sol
print_success "Solidity verifier generated: ../verifier.sol"

# Step 8: Generate call parameters
print_step "8. Generating Call Parameters for Smart Contract"
echo "Running: snarkjs generatecall"
echo "Call parameters for verifyProof function:"
echo "----------------------------------------"
snarkjs generatecall

cd ..

print_step "Workflow Complete!"
echo -e "${GREEN}All steps completed successfully!${NC}"
echo ""
echo "Generated files:"
echo "  - input.json: Circuit inputs (main directory)"
echo "  - verifier.sol: Solidity contract for on-chain verification (main directory)"
echo "  - ${JS_DIR}/proof.json: The zk-proof"
echo "  - ${JS_DIR}/public.json: Public inputs and outputs"
echo "  - ${JS_DIR}/verification_key.json: Verification key"
echo ""
echo "To deploy the verifier contract:"
echo "1. Copy the content of verifier.sol (in main directory)"
echo "2. Deploy it on your preferred network (testnet recommended)"
echo "3. Use the call parameters shown above with the verifyProof function"