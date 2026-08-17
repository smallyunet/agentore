# Base Mainnet Deployment

This runbook deploys AgentOre v0.0.1 to Base Mainnet, Chain ID `8453`.

The contract is non-upgradeable. Deployment fixes `genesisTime` to the deployment block timestamp, `epochDuration` to one day, and the finalizer share to 1%. Review `script/Deploy.s.sol` and the security documentation before broadcasting.

## 1. Install and select Foundry

Use a stable Foundry release and confirm the tools are available:

```bash
foundryup
forge --version
cast --version
```

## 2. Create a dedicated deployment key

Create or select a dedicated EVM private key:

```bash
cast wallet new
```

Store the key only in the ignored `contracts/.env` file. The preflight derives and displays its address. Do not commit it, paste it into a support conversation, or reuse a wallet that holds other assets. Restrict the file locally with `chmod 600 .env`.

Fund the resulting address with Base Mainnet ETH. The deployment simulation on 2026-08-18 estimated approximately 1.36 million gas, but the wallet should carry a safety margin for changing fees.

## 3. Configure the environment

`contracts/.env` is already created locally and ignored by Git. Fill in:

```dotenv
BASE_RPC_URL=https://your-production-base-rpc.example
BASE_CHAIN_ID=8453
PRIVATE_KEY=0xYour64HexCharacterPrivateKey
ETHERSCAN_API_KEY=your-etherscan-api-key
```

The RPC must connect to Base Mainnet. Use an Etherscan API key for BaseScan verification.

## 4. Run the preflight

```bash
cd contracts
./scripts/preflight-base.sh
```

The preflight checks the RPC Chain ID, requires a funded deployer, runs formatting, tests, build-size checks, and performs a non-broadcast deployment simulation. It never broadcasts.

## 5. Broadcast and verify

```bash
./scripts/deploy-base.sh --broadcast
```

The deployment script repeats the full preflight and requires an exact interactive confirmation before it broadcasts with the key loaded from `.env`. It then requests source verification through Etherscan/BaseScan.

## 6. Record and validate the deployment

After the transaction confirms:

1. record the contract address, deployment transaction, block number, deployer, Git commit, and `v0.0.1` tag;
2. confirm verified source code on BaseScan;
3. read `name`, `symbol`, `MAX_SUPPLY`, `epochDuration`, `finalizerBps`, `genesisTime`, and `currentEpoch` from the deployed contract;
4. update the macOS configuration with the production RPC and deployed address; v0.0.3 and later enable `autoSubmit` by default, so fund and verify the dedicated local wallet before launching;
5. fund each participant/finalizer wallet with Base ETH before submitting transactions.

Foundry writes local deployment records under `contracts/broadcast/` and `contracts/cache/`; both paths are ignored by Git and may contain sensitive transaction context.
