# Privacy

AgentOre is designed to derive aggregate token counts locally.

## Data read

- local Codex JSONL files containing `token_count` events;
- local AgentOre configuration, state, and wallet key;
- standard public-chain data through the configured RPC.

## Data intentionally excluded

- prompts and responses;
- source-code contents;
- repository names and working-directory paths;
- OpenAI credentials, cookies, or account identifiers;
- session identifiers in onchain transactions.

The parser reads matching JSONL lines from a user-controlled file system but retains only integer totals. The RPC submission contains the wallet address, cumulative token integer, chain metadata, and transaction signature.

## Local files

```text
~/.agentore/config.json   RPC and contract configuration
~/.agentore/state.json    disposable client state
~/.agentore/wallet.json   passwordless testnet keystore
```

The MVP does not send analytics or crash telemetry. Users can inspect and delete the entire directory, but deleting the wallet without a backup permanently loses access to that address.
