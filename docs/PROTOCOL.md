# Protocol Specification

## Constants and immutables

- token name: `Agent Ore`
- token symbol: `AORE`
- decimals: `18`
- epoch duration: constructor parameter, recommended `1 days`
- synthetic blocks per epoch: `144`
- initial synthetic-block reward: `50 ether`
- halving interval: `210_000` synthetic blocks
- maximum supply: `21_000_000 ether`
- finalizer share: constructor parameter, recommended `100` basis points

The Bitcoin-aligned issuance parameters are constants. Epoch duration and finalizer share are immutable. Changing any of them requires deploying a new contract rather than introducing an owner or upgrade proxy.

## Registration and submission

`submit(cumulativeTokens)` operates on the current epoch.

1. Reject a second submission from the same address in the epoch.
2. If the address is unregistered, store the counter as its baseline and emit `BaselineEstablished`.
3. Otherwise require the new counter to be greater than the prior counter.
4. Set `delta = cumulativeTokens - previous`.
5. Update the global counter and append an entry with cumulative epoch weight.

Counters are scoped to addresses. They are raw integer AI-token units and are unrelated to AORE's 18-decimal ERC-20 units.

## Finalization

`finalize(epoch)` requires `epoch < currentEpoch()` and can execute once. Empty epochs finalize with zero issuance. Non-empty epochs:

1. derive a prototype random value from the prior block hash, `prevrandao`, epoch, total weight, contract, and caller;
2. reduce it modulo total epoch weight;
3. binary-search the cumulative entry array;
4. compute the epoch reward;
5. mint the finalizer share and winner share;
6. record the winner and emit `EpochFinalized`.

Including the caller does not make the random source secure; it only domain-separates candidate results. The finalizer can choose when and from which address to call.

## Reward

```solidity
firstSyntheticBlock = epoch * 144;
for each halving segment touched by the epoch:
    halvings = syntheticBlock / 210_000;
    blockReward = 50 ether >> halvings;
    reward += blocksInSegment * blockReward;
reward = min(reward, MAX_SUPPLY - totalSupply);
```

An epoch can cross a halving boundary, in which case its 144 blocks use the rewards on their respective sides of the boundary. There is no catch-up minting for empty epochs and no privileged mint method.

## Views

- `currentEpoch()`
- `rewardForEpoch(epoch)`
- `entryCount(epoch)`
- `entryAt(epoch, index)`
- public mappings for totals, winners, finalization, and address counters

## Events

- `BaselineEstablished`
- `UsageSubmitted`
- `EpochFinalized`

## Invariants

- a wallet has at most one accepted submission per epoch;
- accepted counters never decrease;
- epoch cumulative weights are strictly increasing;
- no epoch is finalized twice;
- total supply increases by at most `rewardForEpoch(epoch)` per finalized epoch;
- total supply never exceeds `21_000_000 ether`;
- no owner can mint additional AORE;
- the winner belongs to the finalized epoch's entry set.
