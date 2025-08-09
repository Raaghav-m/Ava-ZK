# Circom Workflow Automation

This repository contains automated scripts for working with Circom circuits, from compilation to proof generation and verification.

## Scripts

### 1. `circom_workflow.sh` - Complete Workflow

This script automates the entire circom workflow from compilation to proof generation.

**Usage:**

```bash
./circom_workflow.sh <circuit_filename>
```

**Example:**

```bash
./circom_workflow.sh multiplier2.circom
```

**What it does:**

1. Compiles the circom circuit with all necessary outputs (`--r1cs --wasm --sym --c`)
2. Sets up the JavaScript directory and witness generation
3. Performs the Powers of Tau ceremony (if not already done)
4. Executes Phase 2 setup (circuit-specific trusted setup)
5. Generates a zk-proof using Groth16
6. Verifies the proof
7. Generates a Solidity verifier contract
8. Shows call parameters for smart contract verification

### 2. `generate_proof.sh` - Quick Proof Generation

This script is for when you already have the circuit compiled and setup done, and just want to generate new proofs with different inputs.

**Usage:**

```bash
./generate_proof.sh <circuit_filename> [input_file]
```

**Examples:**

```bash
./generate_proof.sh multiplier2.circom                    # Uses default input.json
./generate_proof.sh multiplier2.circom custom_input.json  # Uses custom input file
```

**What it does:**

1. Computes witness with the provided input
2. Generates a zk-proof
3. Verifies the proof
4. Shows proof summary and smart contract call parameters

## Prerequisites

Make sure you have the following tools installed:

- [Circom](https://docs.circom.io/getting-started/installation/)
- [snarkjs](https://github.com/iden3/snarkjs)
- Node.js
- jq (for JSON formatting)

Install snarkjs:

```bash
npm install -g snarkjs
```

## File Structure

After running the complete workflow, you'll have:

```
your-circuit.circom              # Your circuit file
your-circuit.r1cs               # Constraint system
your-circuit.sym                # Symbols file
input.json                      # Circuit inputs (main directory)
verifier.sol                    # Solidity verifier contract (main directory)
your-circuit_cpp/               # C++ files (if using --c flag)
your-circuit_js/                # JavaScript directory containing:
  ├── your-circuit.wasm         # WebAssembly circuit
  ├── generate_witness.js       # Witness generator
  ├── witness.wtns             # Computed witness
  ├── pot12_*.ptau             # Powers of tau files
  ├── your-circuit_*.zkey      # Zero-knowledge keys
  ├── verification_key.json    # Verification key
  ├── proof.json              # Generated proof
  └── public.json             # Public inputs/outputs
```

## Input Format

Your input file should be a JSON object with the circuit's input signals:

```json
{
  "a": "3",
  "b": "11"
}
```

For the multiplier2 circuit, this proves that 3 \* 11 = 33.

## Smart Contract Deployment

After running the scripts, you can deploy the generated Solidity verifier:

1. Copy the content of `verifier.sol` (located in the main directory)
2. Deploy it on your preferred network (testnet recommended for testing)
3. Use the call parameters shown by the script with the `verifyProof` function

The `verifyProof` function will return `true` if the proof is valid.

## Example: Multiplier2 Circuit

The included `multiplier2.circom` circuit proves knowledge of two factors of a number:

```circom
pragma circom 2.0.0;

template Multiplier2() {
    signal input a;
    signal input b;
    signal output c;
    c <== a*b;
}

component main = Multiplier2();
```

This circuit proves that you know two numbers `a` and `b` such that `a * b = c`, without revealing `a` and `b`.

## Troubleshooting

1. **"Command not found" errors**: Make sure circom and snarkjs are installed and in your PATH
2. **"File not found" errors**: Ensure your circuit file exists and you're running the script from the correct directory
3. **Permission denied**: Make sure the scripts are executable (`chmod +x script_name.sh`)
4. **Node.js errors**: Ensure Node.js is installed and the witness calculator files are present

## Security Note

The Powers of Tau ceremony in these scripts is for development/testing purposes only. For production use, you should:

1. Use a more secure ceremony
2. Participate in a trusted setup with multiple contributors
3. Use larger parameter sizes for stronger security
 