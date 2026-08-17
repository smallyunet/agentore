# Contributing

AgentOre is intentionally small. Before proposing infrastructure, preserve the MVP constraints: no required backend, one user submission per day, permissionless settlement, and an explicit self-reported trust model.

Run the relevant checks before opening a pull request:

```bash
cd contracts && forge test
cd macos/AgentOre && swift test
```

Changes to issuance, winner selection, wallet handling, randomness, or usage parsing should include tests and an update to the relevant document in `docs/`.

