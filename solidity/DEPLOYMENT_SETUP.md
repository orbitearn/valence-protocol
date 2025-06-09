

## Required Environment Variables

The deployment script requires the following environment variables:

### Private Keys
- `OWNER_PRIVATE_KEY` - Private key for the contract owner account
- `PROCESSOR_PRIVATE_KEY` - Private key for the processor account

### Optional Environment Variables
- `SEPOLIA_RPC_URL` - RPC URL for Sepolia testnet (if using custom RPC)
- `MAINNET_RPC_URL` - RPC URL for mainnet (if using custom RPC)
- `ETHERSCAN_API_KEY` - For contract verification

## Setup Methods

### Method 1: Using .env file (Recommended)

1. Create a `.env` file in the `solidity/` directory:

```bash
# Generate new private keys for testing (DO NOT use these in production!)
OWNER_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
PROCESSOR_PRIVATE_KEY=0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890

# Optional RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# Optional Etherscan API key
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

## Generating Test Private Keys

You can generate new private keys for testing using Foundry's cast tool:

```bash
# Generate a new wallet
cast wallet new

# This will output something like:
# Successfully created new keypair.
# Address:     0x1234567890123456789012345678901234567890
# Private key: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

## Running the Deployment

Once you have set up your environment variables, you can run the deployment:

### Ethereum Sepolia Deployment
```bash
# Deploy to Ethereum Sepolia testnet (full suite)
forge script script/DeployAll.script.sol --fork-url sepolia --broadcast --verify

# Or with custom RPC
forge script script/DeployAll.script.sol --fork-url https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY --broadcast --verify
```

### Arbitrum Sepolia Deployment
```bash
# Deploy to Arbitrum Sepolia testnet (PancakeSwap + Compound + Splitter)
forge script script/DeployArbitrumSepolia.script.sol --fork-url arbitrum-sepolia --broadcast --verify

# Or with custom RPC
forge script script/DeployArbitrumSepolia.script.sol --fork-url https://sepolia-rollup.arbitrum.io/rpc --broadcast --verify
```

