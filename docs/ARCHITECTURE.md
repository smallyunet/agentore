# Architecture

## Overview

```text
~/.codex/sessions/**/*.jsonl
              │ aggregate token_count events
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

No AgentOre server is part of the required path. The RPC endpoint observes chain requests but receives no AI conversation content from the app.

## macOS modules

### UsageReader

`CodexJSONLUsageReader` recursively scans the configured Codex sessions directory. It first filters lines for `token_count`, parses only matching JSON, and extracts `payload.info.total_token_usage.total_tokens`. The reader takes the maximum cumulative total per session file and sums the maxima.

The adapter is intentionally isolated because local log formats can change.

### WalletStore

`WalletStore` creates `~/.agentore/wallet.json`, derives its Ethereum address with web3swift, and enforces restrictive local permissions. The key never leaves the process except as a locally signed transaction.

### LocalStateStore

`state.json` contains non-secret client state such as last observed usage, last submitted epoch, and transaction hashes. It is disposable; the contract is authoritative for accepted submissions.

### EthereumClient

The client loads a minimal ABI, signs `submit(uint256)` locally, and sends the raw transaction to a configurable RPC. The MVP does not contain a relayer or gas sponsorship path.

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
1. App refreshes aggregate local usage.
2. App computes the current UTC-aligned contract epoch.
3. When automatic submission is enabled, the app submits once.
4. Contract derives delta from the wallet's previous cumulative counter.
5. After the epoch closes, any address calls finalize(epoch).
6. Contract selects one weighted interval and mints the epoch reward.
```

The first submission establishes a baseline. It intentionally produces no mining weight so a new wallet cannot claim all historical usage immediately.

## Configuration

`~/.agentore/config.json` is created with automatic submission disabled:

```json
{
  "rpcURL": "https://sepolia.base.org",
  "contractAddress": "",
  "autoSubmit": false
}
```

Users must verify the chain and contract before enabling writes.
