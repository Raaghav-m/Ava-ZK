# ava-zk

Cross-chain ZK proof system using Circom, snarkjs, and Solidity smart contracts with Teleporter bridge integration for Avalanche subnets.

## Overview

This package provides a complete workflow for generating zero-knowledge proofs with Circom circuits and sending them cross-chain between Avalanche subnets using the Teleporter bridge.

## Installation

```bash
npm install ava-zk
```

## Prerequisites

Make sure you have the following tools installed:

- [Circom](https://docs.circom.io/getting-started/installation/) - Circuit compiler
- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit (forge, cast)
- [Python 3](https://www.python.org/) - For proof data parsing
- [Node.js](https://nodejs.org/) >= 16.0.0

## Environment Setup

Create a `.env` file in your project root:

```env
PRIVATE_KEY=your_private_key_without_0x_prefix
CHAIN1_RPC_URL=https://subnets.avax.network/dispatch/testnet/rpc
CHAIN2_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
TELEPORTER_MESSENGER_CHAIN1=0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf
TELEPORTER_MESSENGER_CHAIN2=0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf
```

## Usage

The workflow consists of 4 simple commands:

### 1. Compile Circuit & Generate Proof

```bash
npm run compile
```

This command:
- Compiles the Circom circuit (`multiplier2.circom`)
- Sets up the trusted ceremony (Powers of Tau)
- Generates ZK proof from `input.json`
- Creates Solidity verifier contract
- Outputs `proof.json`, `public.json`, and verification files

### 2. Deploy Contracts

```bash
npm run deploy
```

This command:
- Deploys `Groth16Verifier` contracts on both chains
- Deploys `ZKProofSender` on Chain 1 (Dispatch Testnet)
- Deploys `ZKProofReceiver` on Chain 2 (Avalanche Fuji)
- Logs all contract addresses for reference

### 3. Send Proof Cross-Chain

```bash
npm run send
```

This command:
- Reads the generated proof from `proof.json`
- Sends the ZK proof from Chain 1 to Chain 2 via Teleporter
- Returns transaction hash and details

### 4. Verify Received Proof

```bash
npm run verify
```

This command:
- Monitors Chain 2 for received proofs
- Retrieves the latest stored proof
- Verifies the proof on-chain
- Shows verification results and event logs

## Example Workflow

```bash
# 1. Generate ZK proof from circuit
npm run compile

# 2. Deploy contracts to both chains
npm run deploy

# 3. Send proof cross-chain
npm run send

# 4. Verify received proof
npm run verify
```

## Input Configuration

Modify `input.json` to change the circuit inputs:

```json
{
  "a": 3,
  "b": 11
}
```

The circuit proves that `a * b = 33` without revealing the values of `a` and `b`.

## Chain Configuration

- **Chain 1 (Sender)**: Dispatch Testnet
- **Chain 2 (Receiver)**: Avalanche Fuji Testnet
- **Bridge**: Teleporter Messenger

## CLI Binaries

After installation, you can also use the CLI commands directly:

```bash
zk-compile     # Compile circuit and generate proof
zk-deploy      # Deploy contracts
zk-send        # Send proof cross-chain
zk-receive     # Verify received proof
```

## License

MIT
 