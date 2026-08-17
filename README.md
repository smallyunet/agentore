# AgentOre

**Turn AI usage into onchain mining power.**

AgentOre is an experimental, serverless protocol that treats locally reported AI token usage as lottery weight. A native macOS menu bar app reads aggregate Codex usage from local session logs, maintains a local Ethereum wallet, and submits one cumulative usage value per day. An ERC-20 contract selects one weighted winner per epoch and mints a geometrically decreasing block reward.

> [!IMPORTANT]
> AgentOre does not prove usage reported by OpenAI. Local logs, the app, and direct contract calls are controlled by the user and can be modified. The current design is suitable only for testnets, research, and tokens with no monetary value.

## Protocol at a glance

| Property | MVP decision |
| --- | --- |
| Epoch | Fixed 24 hours |
| User transactions | At most one `submit` transaction per epoch |
| Usage accounting | Monotonic cumulative counter; first submission establishes a baseline |
| Mining weight | Linear daily delta in reported tokens |
| Winner | One address per non-empty epoch |
| Reward | 1,000 AORE per epoch at genesis |
| Halving | Every 365 epochs |
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

The deployment script defaults to a one-day epoch, a 365-epoch halving interval, an initial reward of 1,000 AORE, and a 1% finalizer incentive. No contract has been deployed by this repository.

## macOS app

The app is a Swift Package targeting macOS 14 or newer.

```bash
cd macos/AgentOre
swift test
swift run AgentOre
```

On first launch it creates `~/.agentore/`, generates a local Ethereum private key, and writes a default configuration. Automatic onchain submission remains disabled until the user supplies an RPC URL and contract address in `~/.agentore/config.json`.

The initial key-file approach intentionally favors prototype simplicity. Use only a testnet-funded wallet. A production version should migrate private-key material to macOS Keychain or an external wallet.

## Status

AgentOre is a prototype. The contract and local parser are implemented and tested, but the following are deliberately out of scope for the first version:

- trusted OpenAI attestation;
- Sybil-resistant identity;
- production-grade randomness;
- relayers, paymasters, or gas sponsorship;
- a backend, database, or hosted indexer;
- mainnet deployment or a token sale.

See the [whitepaper](docs/WHITEPAPER.md) before evaluating or extending the protocol.

## License

MIT

