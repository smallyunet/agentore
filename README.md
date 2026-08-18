# AgentOre

<img src="assets/agentore-token.png" alt="AgentOre token logo" width="128" height="128">

**Turn AI usage into onchain mining power.**

AgentOre is a self-reported AI usage mining protocol with no AgentOre-operated backend. A native macOS menu bar app reads the authenticated account lifetime token count from Codex App Server, maintains a local Ethereum wallet, and submits one cumulative usage value per day. An ERC-20 contract selects one weighted winner per epoch and mints a geometrically decreasing block reward.

Current development version: **v0.0.4** · Latest release: **v0.0.4**

See the [changelog](CHANGELOG.md) for release scope and security boundaries.

> [!IMPORTANT]
> AgentOre does not make the account usage value independently verifiable onchain. The app and direct contract calls are controlled by the user and can be modified. The Base Mainnet deployment is intended for protocol operation with no promise of monetary value and is not suitable for production-grade financial use.

## Protocol at a glance

| Property | v0.0.1 protocol |
| --- | --- |
| Epoch | Fixed 24 hours |
| User transactions | At most one `submit` transaction per epoch |
| Usage accounting | Monotonic cumulative counter; first submission establishes a baseline |
| Mining weight | Linear daily delta in reported tokens |
| Winner | One address per non-empty epoch |
| Reward | 50 AORE per synthetic 10-minute block; normally 7,200 AORE per pre-halving day |
| Halving | Every 210,000 synthetic blocks, matching Bitcoin's issuance cadence |
| Maximum supply | 21,000,000 AORE |
| Settlement | Permissionless `finalize`; 99% to winner and 1% to finalizer |
| Infrastructure | macOS app + configurable RPC + one contract |
| Gas | Paid by users |
| Trust model | Self-reported and tamper-evident onchain, not independently verified |

For address splitting, linear weight is neutral: splitting the same reported token total across multiple wallets does not increase aggregate winning probability and costs more gas.

## Repository

```text
agentore/
├── contracts/              Foundry project and AgentOre ERC-20 protocol
├── macos/AgentOre/         Native AppKit menu bar app
└── docs/
    ├── WHITEPAPER.md       Design, economics, and limitations
    ├── ARCHITECTURE.md     Components and data flow
    ├── PROTOCOL.md         Contract state machine and parameters
    ├── THREAT_MODEL.md     Security boundaries and known attacks
    └── PRIVACY.md          Local data handling rules
```

## Contracts

Requirements: [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
cd contracts
forge test
```

For Base Mainnet preparation, preflight, deployment, and verification, follow the [deployment runbook](contracts/DEPLOYMENT.md).

The deployment script uses one-day epochs. Each epoch represents 144 synthetic ten-minute blocks; issuance starts at 50 AORE per synthetic block and halves every 210,000 blocks. Supply can never exceed 21,000,000 AORE, and the finalizer receives 1% of each minted epoch reward.

### Base Mainnet deployment

| Property | Value |
| --- | --- |
| Network | Base Mainnet |
| Chain ID | `8453` |
| Contract | [`0xcd5aB54841e0571671CbFBf15328097D6143De76`](https://basescan.org/address/0xcd5ab54841e0571671cbfbf15328097d6143de76) |
| Deployment transaction | [`0x47c29eb9…a6a6a37`](https://basescan.org/tx/0x47c29eb9a655f8a81f0219a5dababf9b67f2e8a7331d74f1e38ea18e3a6a6a37) |
| Deployment block | `50,097,341` |
| Genesis time | `2026-08-17 16:27:09 UTC` |
| Deployer | [`0x570fB687Ce1E2Ff5f87B1956f6464C00D8724f75`](https://basescan.org/address/0x570fb687ce1e2ff5f87b1956f6464c00d8724f75) |

The deployed source is verified on BaseScan. The contract is non-upgradeable, has no owner mint function, and had zero supply at deployment.

## macOS app

The app is a Swift Package targeting macOS 14 or newer.

Download the signed release archive from [GitHub Releases](https://github.com/smallyunet/agentore/releases/latest). The v0.0.4 archive is a universal macOS app for Apple Silicon and Intel Macs. It uses an ad-hoc code signature and is not notarized.

It requires a local Codex executable signed in with a Codex-services-backed authentication mode. API-key-only and Bedrock authentication cannot provide account token activity. AgentOre uses `account/usage/read` exclusively and stops with an error when `lifetimeTokens` is unavailable; it never scans local Codex session files.

```bash
cd macos/AgentOre
swift test
swift run AgentOre
```

On first launch it creates `~/.agentore/`, generates a local Ethereum private key, and writes the verified Base Mainnet deployment to `~/.agentore/config.json`. Existing configurations with an empty contract address are migrated to the Base Mainnet contract. Automatic onchain submission is enabled by default and runs at most once per daily epoch; Base ETH for gas is paid by the local wallet.

The menu bar prioritizes pending mining weight—the increase since the contract last accepted the wallet's cumulative counter. Its expanded dashboard keeps lifetime Codex usage as context and shows current epoch progress, the automatic-attempt countdown, full local wallet address, Base ETH balance, AORE balance, and actionable status.

Version v0.0.1 stores the wallet in a local permission-restricted key file. Use a dedicated wallet funded only with the Base ETH required for gas. A future release intended for assets with monetary value must migrate private-key material to macOS Keychain or an external wallet.

## Protocol scope

AgentOre v0.0.1 includes the tested smart contract, Bitcoin-aligned issuance schedule, native macOS menu bar client, Codex App Server account-usage integration, local wallet management, and configurable EVM submission.

The following capabilities are not included in v0.0.1:

- trusted OpenAI attestation;
- Sybil-resistant identity;
- production-grade randomness;
- relayers, paymasters, or gas sponsorship;
- a backend, database, or hosted indexer;
- a token sale or liquidity program.

The v0.0.1 contract is deployed on Base Mainnet. The contracts have not been professionally audited, usage values remain self-reported, and the current randomness and key-storage designs are not suitable for assets with monetary value.

See the [whitepaper](docs/WHITEPAPER.md) before evaluating or extending the protocol.

## License

MIT
