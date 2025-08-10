# create-ava-zk

Scaffolding tool for creating ZK proof cross-chain projects.

## Usage

Create a new ZK proof project with one command:

```bash
npx create-ava-zk@latest
```

## What it does

The tool will prompt you to:

1. **Choose a project name** - Your project directory name
2. **Select a circuit template** from:
   - **Age Verification Circuit** - Proves age is above 18 using date of birth without revealing exact age
   - **Credit Score & Balance Check Circuit** - Proves both credit score and balance meet minimum requirements
   - **Minimum Balance Proof Circuit** - Proves account balance meets minimum requirement without revealing exact amount
3. **Install dependencies** - Automatically runs `npm install`

## Generated Project Structure

```
my-zk-project/
├── contracts/                 # Solidity smart contracts
│   ├── Groth16Verifier.sol   # Generated verifier contract
│   ├── ZKProofSender.sol     # Cross-chain sender
│   ├── ZKProofReceiver.sol   # Cross-chain receiver
│   └── interfaces/           # Teleporter interfaces
├── [circuit].circom         # Your selected circuit
├── input.json               # Circuit inputs
├── circom_workflow.sh       # Complete workflow automation
├── deploy.sh                # Contract deployment
├── send_proof.sh           # Send proofs cross-chain
├── receive_proof.sh        # Receive and verify proofs
├── package.json            # Project configuration
└── README.md               # Documentation
```

## Example Usage

```bash
# Create a new project
npm create-ava-zk@latest my-zk-app

# Enter the project
cd my-zk-app

# Set up environment
cp .env.example .env
# Edit .env with your private key and RPC URLs

# Run the complete workflow
npm run compile  # Generate ZK proof
npm run deploy   # Deploy contracts to both chains
npm run send     # Send proof cross-chain
npm run verify   # Verify received proof
```

## Circuit Templates

### Age Verification Circuit
Proves you are over 18 using date of birth (days since epoch) without revealing your exact age. Perfect for age-gated services, voting eligibility, or access control.

### Credit Score & Balance Check Circuit  
Proves both your credit score and account balance meet minimum requirements without revealing exact values. Comprehensive financial verification for lending and services.

### Minimum Balance Proof Circuit
Proves your account balance meets minimum requirements without revealing the exact amount. Useful for financial services, lending protocols, or membership verification.

## Requirements

- Node.js ≥ 16.0.0
- [Circom](https://docs.circom.io/getting-started/installation/)
- [Foundry](https://getfoundry.sh/) (forge, cast)
- Python 3

## License

MIT 