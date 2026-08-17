# Privacy

AgentOre reads an aggregate lifetime token count without opening Codex conversation files.

## Data read

- the `lifetimeTokens` integer returned by the local Codex App Server;
- local AgentOre configuration, state, and wallet key;
- standard public-chain data through the configured RPC.

## Data intentionally excluded

- prompts and responses;
- source-code contents;
- repository names and working-directory paths;
- OpenAI credentials, cookies, account identifiers, or Codex session files;
- session identifiers in onchain transactions.

AgentOre launches the local Codex App Server, which uses the user's existing Codex authentication. AgentOre does not read or store that authentication material. The App Server response supplies only the aggregate fields from `account/usage/read`; AgentOre retains the lifetime token integer. The EVM RPC submission contains the wallet address, cumulative token integer, chain metadata, and transaction signature.

## Local files

```text
~/.agentore/config.json   RPC and contract configuration
~/.agentore/state.json    disposable client state
~/.agentore/wallet.json   passwordless testnet keystore
```

Version v0.0.1 does not send analytics or crash telemetry. Users can inspect and delete the entire directory, but deleting the wallet without a backup permanently loses access to that address.
