# Changelog

All notable changes to AgentOre are documented in this file.

## [Unreleased]

## [0.0.11] - 2026-08-21

### macOS application

- automatically finalize the previous epoch when it has mining weight, remains unsettled, automatic finalization is enabled, and the local wallet has Base ETH;
- preserve the `Finalize Previous Epoch` action-required badge and show an actionable error when automatic finalization cannot complete;
- describe a broadcast finalization transaction as submitted until its onchain state is observed.

## [0.0.10] - 2026-08-18

### macOS application

- display zero pending tokens instead of an ambiguous dash when Codex revises lifetime usage below the accepted onchain baseline;
- show the exact counter-recovery deficit as an inline warning with accessible explanatory text;
- pause automatic submission and disable manual submission until the cumulative counter recovers, preventing known-reverting transactions.

## [0.0.9] - 2026-08-18

### macOS application

- simplified the dashboard around one primary `Pending Tokens` metric;
- combined the last accepted submission into one line, compacted Lifetime usage, and placed Epoch progress and countdown on one row;
- hid routine automatic-submission status while preserving loading, success, warning, and error feedback;
- replaced the fixed dashboard height with content-derived sizing and protected wallet, balance, and status rows from vertical compression;
- clarified that the menu-bar number is the pending token delta rather than a separate weight score.

## [0.0.8] - 2026-08-18

### macOS application

- separated current pending mining weight, the last accepted submission, and lifetime usage into a clearer metric hierarchy;
- persisted the exact accepted delta for new weighted submissions and identified baseline submissions without assigning them mining weight;
- migrated an existing accepted Epoch 0 submission to the correct baseline presentation without guessing unknown historical deltas;
- clarified whether new tokens are ready for the current epoch or eligible in the next epoch.

## [0.0.7] - 2026-08-18

### macOS application

- added native action-required badges to `Submit Now` after an automatic-submission problem and to `Finalize Previous Epoch` when a reward-bearing previous epoch is ready to settle;
- disabled submission and finalization actions when their onchain preconditions are not met;
- made errors visually distinct with semantic red text, an explicit `Error:` prefix, and actionable recovery messages;
- prevented attempts to finalize Epoch 0 or an already settled or empty previous epoch;
- priced Base transactions from the live RPC gas quote with a 25% safety margin and one bounded 25% fee-bump retry for `transaction underpriced` responses.

## [0.0.6] - 2026-08-18

### Fixed

- explicitly signed Base Mainnet transactions with chain ID `8453` instead of web3swift's Ethereum Mainnet default.

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
[0.0.6]: https://github.com/smallyunet/agentore/releases/tag/v0.0.6
[0.0.7]: https://github.com/smallyunet/agentore/releases/tag/v0.0.7
[0.0.8]: https://github.com/smallyunet/agentore/releases/tag/v0.0.8
[0.0.9]: https://github.com/smallyunet/agentore/releases/tag/v0.0.9
[0.0.10]: https://github.com/smallyunet/agentore/releases/tag/v0.0.10
[0.0.11]: https://github.com/smallyunet/agentore/releases/tag/v0.0.11
[Unreleased]: https://github.com/smallyunet/agentore/compare/v0.0.11...HEAD
