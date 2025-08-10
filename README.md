# ZK Local Testing Harness for Avalanche

Cross-subnet ZK proof system using Circom, snarkjs, and Solidity smart contracts with simulated Avalanche Warp Messaging (AWM) for hackathon testing.

## Overview

This project provides a complete workflow for generating zero-knowledge proofs with Circom circuits and testing cross-subnet communication between Avalanche subnets using simulated Teleporter messaging. The system consists of:

- **Subnet A (Prover)**: Generates ZK proofs and sends them cross-chain
- **Subnet B (Verifier)**: Receives and verifies ZK proofs on-chain
- **Cross-Chain Bridge**: Teleporter messaging

## Prerequisites

Make sure you have the following tools installed:

- [Circom](https://docs.circom.io/getting-started/installation/) - Circuit compiler
- [snarkjs](https://github.com/iden3/snarkjs) - ZK proof generation and verification
- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit (forge, cast)
- [Node.js](https://nodejs.org/) >= 16.0.0

## Environment Setup

Set your private key as an environment variable:

```env
PRIVATE_KEY=your_private_key_without_0x_prefix
```

## Usage

The workflow consists of 4 main steps:

### 1. Generate ZK Proof

```bash
npm run compile
```

This script:

- Compiles the Circom circuit (`multiplier2.circom`)
- Sets up the trusted ceremony (Powers of Tau + Phase 2)
- Generates ZK proof from `input.json`
- Creates Solidity verifier contract in `contracts/Groth16Verifier.sol`
- Outputs `proof.json`, `public.json`, and verification files in the main directory

**Example Input** (`input.json`):

```json
{
  "a": 3,
  "b": 11
}
```

The circuit proves that `a * b = 33` without revealing the values of `a` and `b`.

### 2. Deploy Contracts

```bash
npm run deploy
```

This script prompts for:

- `CHAIN1_RPC_URL` - RPC URL for Chain 1 (Subnet A)
- `CHAIN2_RPC_URL` - RPC URL for Chain 2 (Subnet B)

Then deploys:

- `Groth16Verifier` on both Chain 1 and Chain 2
- `ZKProofSender` on Chain 1 (using Chain 1 verifier)
- `ZKProofReceiver` on Chain 2 (using Chain 2 verifier)

Uses hardcoded Teleporter address: `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf`

Creates `cross_chain_deployments_*.log` with all contract addresses.

### 3. Send Proof Cross-Chain

```bash
npm run send
```

This script:

- Automatically loads deployment info from the latest log file
- Parses `proof.json` and `public.json`
- Prompts for destination chain ID
- Sends ZK proof from Chain 1 to Chain 2 via Teleporter
- Returns transaction hash

**Proof Components**:

- `pA`, `pB`, `pC`: Groth16 proof components (converted to hex with 0x prefix)
- `publicSignal`: Public output (33 → 0x21)

### 4. Verify Received Proof

```bash
npm run verify
```

This script:

- Automatically loads deployment info from the latest log file
- Monitors Chain 2 for received proofs
- Retrieves the latest stored proof
- Verifies the proof on-chain
- Shows verification results and `ProofVerificationSuccess` events
- Optionally tests direct verification with local `proof.json`

## Example Complete Workflow

```bash
# 1. Generate ZK proof from circuit
npm run compile

# 2. Deploy contracts to both chains
npm run deploy
# Enter RPC URLs when prompted

# 3. Send proof cross-chain
npm run send
# Enter destination chain ID when prompted

# 4. Verify received proof
npm run verify
```

## Circuit Examples

### Basic Multiplier (`multiplier2.circom`)

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

### Age Verification (`age-verification/age.circom`)

```circom
pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";

template AgeVerification() {
    signal input age;
    signal input minimumAge;
    signal output isValid;

    component greaterThan = GreaterThan(8);
    greaterThan.in[0] <== age;
    greaterThan.in[1] <== minimumAge;
    isValid <== greaterThan.out;
}

component main = AgeVerification();
```

## Contract Architecture

### ZKProofSender.sol

- Deployed on Subnet A (Chain 1)
- Verifies proof locally before sending
- Sends proof via Teleporter to Subnet B
- Function: `sendProof(bytes32 destinationBlockchainID, address destinationAddress, uint[2] _pA, uint[2][2] _pB, uint[2] _pC, uint[1] _pubSignals)`

### ZKProofReceiver.sol

- Deployed on Subnet B (Chain 2)
- Receives proof via Teleporter
- Verifies proof on-chain using Groth16Verifier
- Emits `ProofVerificationSuccess` event
- Functions: `receiveTeleporterMessage()`, `verifyProofDirectly()`

### Groth16Verifier.sol

- Auto-generated from snarkjs
- Performs actual Groth16 proof verification
- Function: `verifyProof(uint[2] _pA, uint[2][2] _pB, uint[2] _pC, uint[1] _pubSignals)`

## Troubleshooting

### Common Issues

1. **Missing circomlib**: Install with `npm install circomlib` or clone from GitHub
2. **Permission denied**: Make scripts executable with `chmod +x *.sh`
3. **PRIVATE_KEY not set**: Export your private key as environment variable
4. **RPC timeout**: Check network connectivity and RPC URL validity
5. **Proof verification failed**: Ensure `Groth16Verifier.sol` matches the trusted setup used for proof generation

### Debug Commands

```bash
# Check script permissions
ls -la *.sh

# Test RPC connectivity
cast block-number --rpc-url $CHAIN1_RPC_URL

# Verify proof locally
snarkjs groth16 verify verification_key.json public.json proof.json

# Check contract deployment
cast code $CONTRACT_ADDRESS --rpc-url $RPC_URL
```

## License

MIT
