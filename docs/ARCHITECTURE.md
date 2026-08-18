# Architecture

## Overview

```text
Codex account token activity
              │ account/usage/read → lifetimeTokens
              ▼
      AgentOre macOS app
       ├── UsageReader
       ├── LocalStateStore
       ├── WalletStore
       └── EthereumClient
              │ signed JSON-RPC transaction
              ▼
        AgentOre contract
       ├── cumulative counters
       ├── epoch weight intervals
       ├── weighted winner selection
       └── ERC-20 issuance
```

No AgentOre-operated server is part of the required path. The local Codex App Server uses the user's existing Codex authentication to fetch account token activity. The EVM RPC endpoint observes chain requests but receives no AI conversation content from the app.

## macOS modules

### UsageReader

`CodexAccountUsageReader` starts the local `codex app-server` stdio transport, completes the required `initialize` and `initialized` handshake, and calls `account/usage/read`. It accepts only `summary.lifetimeTokens` as the cumulative counter.

There is intentionally no session-file fallback. Missing Codex authentication, an unavailable lifetime counter, an App Server error, or a timeout stops the refresh and prevents submission.

### WalletStore

`WalletStore` creates `~/.agentore/wallet.json`, derives its Ethereum address with web3swift, and enforces restrictive local permissions. The key never leaves the process except as a locally signed transaction.

### LocalStateStore

`state.json` contains non-secret client state such as last observed usage, last submitted epoch, and transaction hashes. It is disposable; the contract is authoritative for accepted submissions.

### EthereumClient

The client loads a minimal ABI, signs `submit(uint256)` locally, and sends the raw transaction to a configurable RPC. Version v0.0.1 does not contain a relayer or gas sponsorship path.

## Contract storage

Each weighted entry stores:

```solidity
struct Entry {
    address account;
    uint256 cumulativeWeight;
}
```

The cumulative representation permits winner lookup by binary search. It also avoids one hash computation per virtual token or per ticket.

## Daily lifecycle

```text
1. App refreshes authenticated account lifetime usage through Codex App Server.
2. App computes the current UTC-aligned contract epoch.
3. When automatic submission is enabled, the app submits once.
4. Contract derives delta from the wallet's previous cumulative counter.
5. After the epoch closes, any address calls finalize(epoch).
6. Contract selects one weighted interval and mints the epoch reward.
```

The first submission establishes a baseline. It intentionally produces no mining weight so a new wallet cannot claim all historical usage immediately.

## Configuration

`~/.agentore/config.json` is created for the verified Base Mainnet deployment with automatic submission enabled:

```json
{
  "rpcURL": "https://base-rpc.publicnode.com",
  "contractAddress": "0xcd5aB54841e0571671CbFBf15328097D6143De76",
  "autoSubmit": true,
  "schemaVersion": 1
}
```

Existing configurations with an empty contract address are migrated to this deployment. Custom configurations that already contain a contract address are preserved. Because automatic writes are enabled by default, users must verify the chain and contract and fund only the dedicated local wallet before launching.
