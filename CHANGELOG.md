# Changelog

All notable changes to AgentOre are documented in this file.

## [Unreleased]

### Deployment

- deployed and verified AgentOre v0.0.1 on Base Mainnet at [`0xcd5aB54841e0571671CbFBf15328097D6143De76`](https://basescan.org/address/0xcd5ab54841e0571671cbfbf15328097d6143de76);
- configured the macOS client to use the verified Base Mainnet deployment by default;
- added Base Mainnet deployment, preflight, and verification tooling.

## [0.0.1] - 2026-08-18

Initial public testnet release.

### Included

- ERC-20 issuance weighted by self-reported cumulative AI token usage;
- Bitcoin-aligned issuance with 50 AORE per synthetic block, halvings every 210,000 synthetic blocks, and a 21 million AORE maximum supply;
- one submission per address per daily epoch and permissionless epoch finalization;
- native macOS menu bar client using Codex App Server `account/usage/read` without session-file fallback;
- locally generated Ethereum wallet and configurable EVM RPC submission;
- Foundry contract tests and Swift client tests;
- protocol, architecture, privacy, threat-model, and whitepaper documentation.

### Security scope

- v0.0.1 is intended for testnets and tokens with no monetary value;
- reported usage is self-reported and is not independently verified onchain;
- the finalization random source can be influenced by validators or strategic finalizers;
- local key storage is not suitable for valuable assets;
- the contracts have not been professionally audited.

[0.0.1]: https://github.com/smallyunet/agentore/releases/tag/v0.0.1
