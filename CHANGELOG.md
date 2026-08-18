# Changelog

All notable changes to AgentOre are documented in this file.

## [Unreleased]

### Website

- added the official responsive AgentOre project website and GitHub Pages deployment workflow.

## [0.0.5] - 2026-08-18

### Fixed

- changed the default Base Mainnet RPC to `https://base-rpc.publicnode.com`;
- migrated existing v0.0.4 configurations that still use the previous default RPC while preserving custom RPC endpoints and automatic-submission preferences.

## [0.0.4] - 2026-08-18

### Fixed

- changed the primary menu-bar metric from lifetime usage to pending mining weight since the last accepted cumulative counter;
- made the wallet address directly clickable and keyboard-accessible for clipboard copying;
- stopped automatic and manual submissions before broadcast when the local wallet has no Base ETH;
- replaced raw web3swift HTTP 429 errors with an actionable Base RPC retry message and reduced routine RPC refresh frequency.

## [0.0.3] - 2026-08-18

### macOS application

- added a unified AgentOre token logo, macOS app icon, and branded menu bar icon;
- enabled automatic Base Mainnet submission by default, including a one-time migration for pre-v0.0.3 configurations;
- added lifetime token usage directly to the menu bar;
- added a compact dashboard with epoch progress, a live automatic-submission countdown, full wallet address, Base ETH balance, and AORE balance.

## [0.0.2] - 2026-08-18

### Deployment

- deployed and verified AgentOre v0.0.1 on Base Mainnet at [`0xcd5aB54841e0571671CbFBf15328097D6143De76`](https://basescan.org/address/0xcd5ab54841e0571671cbfbf15328097d6143de76);
- configured the macOS client to use the verified Base Mainnet deployment by default;
- added Base Mainnet deployment, preflight, and verification tooling.

### macOS application

- added a universal macOS application bundle for Apple Silicon and Intel Macs;
- embedded the verified Base Mainnet contract as the default deployment;
- added automatic migration for legacy configurations with an empty contract address;
- added reproducible GitHub Release packaging, ad-hoc signing, and SHA-256 checksums.

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
[0.0.2]: https://github.com/smallyunet/agentore/releases/tag/v0.0.2
[0.0.3]: https://github.com/smallyunet/agentore/releases/tag/v0.0.3
[0.0.4]: https://github.com/smallyunet/agentore/releases/tag/v0.0.4
[0.0.5]: https://github.com/smallyunet/agentore/releases/tag/v0.0.5
[Unreleased]: https://github.com/smallyunet/agentore/compare/v0.0.5...HEAD
