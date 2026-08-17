# AgentOre Whitepaper

## A Self-Reported AI Usage Mining Protocol

Version 0.1 — August 2026

## Abstract

AgentOre explores a simple question: can the resource consumption of everyday AI-assisted work become a visible, onchain mining game without introducing a central service?

The protocol maps locally observed AI token usage to mining weight. A desktop client submits a monotonically increasing usage counter once per fixed daily epoch. The contract derives each participant's new usage, assigns a proportional interval in the epoch's weight space, and uses a future onchain random value to select one winner. The epoch reward follows a Bitcoin-inspired geometric issuance schedule and halves every 365 epochs.

AgentOre deliberately makes a narrower claim than a proof-of-usage protocol. A blockchain can verify who submitted a value, when it was submitted, and whether it is consistent with that address's previous value. It cannot verify that a user-controlled computer obtained the value from OpenAI or any other AI provider. The MVP is therefore an honest-client experiment, not a trustless metering system.

## 1. Motivation

Proof-of-work networks convert externally costly computation into a scarce right to extend consensus. AI coding tools also consume a measurable computational resource—tokens—but consumer applications generally expose usage only as local telemetry or account-level summaries. AgentOre uses that telemetry as the input to a daily, fixed-supply lottery.

The goal is not to make token consumption economically productive or to encourage waste. The goal is to prototype a legible feedback loop:

```text
use an AI coding tool
        ↓
accumulate locally reported usage
        ↓
submit one daily cumulative counter
        ↓
receive proportional mining weight
        ↓
compete for a decreasing epoch reward
```

The mechanism rewards usage rather than online time. A user who leaves the app open without generating tokens receives no additional weight.

## 2. Design principles

AgentOre's MVP follows six constraints:

1. **Serverless core.** The protocol requires no AgentOre backend, database, attestor, or account system.
2. **Low interaction.** A participant sends at most one submission transaction per day. One shared finalization transaction settles an epoch.
3. **Fixed monetary policy.** Epoch duration and halving cadence do not change with wallet count.
4. **Sybil-neutral linear weight.** Splitting the same claimed usage across addresses does not create more aggregate weight.
5. **Honest claims.** Documentation distinguishes onchain consistency from independently verified usage.
6. **Prototype safety.** The first deployment belongs on a testnet with a valueless token.

## 3. System model

### 3.1 Actors

- **Participant:** runs the macOS app, controls an Ethereum key, pays gas, and submits a cumulative token count.
- **Finalizer:** calls `finalize(epoch)` after an epoch closes. Any address may act as finalizer.
- **Contract:** stores usage deltas, selects a winner, and mints AORE.
- **RPC provider:** relays standard EVM JSON-RPC requests. It is configurable and is not trusted for token accounting.

### 3.2 Local usage source

The initial client reads aggregate `token_count` events from local Codex JSONL session files. For each file it takes the highest cumulative total observed, then sums those per-session totals. It ignores lines without token-count events and never intentionally exports prompts, responses, paths, or source code.

This file format is an integration adapter, not a stable public proof interface. Parser changes must be versioned and tested.

### 3.3 Wallet

The app generates a secp256k1 private key locally. For the MVP, the key is stored in a passwordless Web3 V3 keystore at `~/.agentore/wallet.json` with POSIX mode `0600`; the directory uses mode `0700`. File permissions, rather than a user password, are the effective protection. This is intentionally simple and intentionally unsuitable for valuable assets. The user must fund the address with testnet gas.

## 4. Epoch protocol

Let:

- `E = 86,400 seconds`, the immutable epoch duration;
- `g`, the immutable genesis timestamp;
- `e(t) = floor((t - g) / E)`, the epoch containing timestamp `t`;
- `C_i`, the latest cumulative token value reported by address `i`;
- `C'_i`, its prior accepted cumulative value;
- `w_i = C_i - C'_i`, its weight in the current epoch.

Each address may submit once in an epoch. The first submission establishes `C'_i` and receives no weight. Later submissions require `C_i > C'_i`.

The total epoch weight is:

```text
W_e = Σ w_i
```

As submissions arrive, the contract stores an ordered entry containing the participant and the cumulative epoch weight after that submission. For example:

```text
Alice  w=1,000,000  cumulative=1,000,000
Bob    w=3,000,000  cumulative=4,000,000
Carol  w=6,000,000  cumulative=10,000,000
```

After the epoch closes, finalization derives a random integer `r` and computes:

```text
p = r mod W_e
```

The winner is the first entry whose cumulative weight is greater than `p`. Binary search makes selection logarithmic in the number of participants.

For honest, unbiased randomness:

```text
Pr[i wins] = w_i / W_e
```

## 5. Difficulty

Bitcoin adjusts a hash target to keep block arrival near a target interval. AgentOre already creates epochs on a fixed clock, so an explicit target adjustment would add complexity without stabilizing anything.

AgentOre instead has endogenous economic difficulty:

```text
difficulty_e = W_e / R_e
```

where `R_e` is the epoch reward. More participants and more reported usage increase `W_e`, reducing each token's winning probability. A halving reduces `R_e`, reducing expected reward per unit of weight. Wallet count is not used as a protocol input because an address is not an identity and can be created cheaply.

## 6. Issuance

The default parameters are:

```text
initial reward       1,000 AORE
epoch duration       1 day
halving interval     365 epochs
winner share         99%
finalizer share      1%
```

For epoch `e`:

```text
h(e) = floor(e / 365)
R_e  = R_0 / 2^h(e)
```

The upper bound if every epoch is non-empty is approximately:

```text
2 × R_0 × 365 = 730,000 AORE
```

Integer rounding makes the realized supply slightly lower. Empty epochs mint nothing and missed rewards do not roll forward. The contract has no owner mint function.

The finalizer receives one percent of `R_e`; the winner receives the remainder. This internalizes the shared settlement cost without increasing issuance.

## 7. Solo and pool interpretations

The MVP pays a single winner. Its expected payout is:

```text
E[payout_i] = R_e × w_i / W_e
```

A pool could distribute the same fixed reward proportionally to every participant, producing the same expectation with lower variance. Pool distribution is excluded from the base contract because it requires many transfers or a claim tree and weakens the simplicity of the one-block-one-winner narrative.

## 8. Trust and verification

AgentOre verifies only an onchain statement:

> Address `A` reported cumulative counter `C` during epoch `e`, and `C` was greater than its previously accepted counter.

It does not verify:

- that OpenAI produced the usage value;
- that local JSONL files were not edited;
- that the official app constructed the transaction;
- that one address corresponds to one person;
- that reported usage represents valuable work;
- that consuming more tokens was necessary or efficient.

Code signing can identify an application build to macOS, but it cannot make a smart contract trust a user-controlled process. App-generated signatures authenticate the wallet, not the truth of the measurement.

## 9. Security limitations

### 9.1 Forged usage

An attacker can patch the app or call `submit` directly with arbitrary values. Monotonic counters prevent replay but not inflation.

### 9.2 Randomness bias

The MVP derives randomness from EVM block context at finalization. Validators and a strategic finalizer may influence or selectively delay the result. This is acceptable only for a valueless testnet experiment. A valuable deployment requires an independently verifiable randomness source or a carefully analyzed commit-reveal scheme.

### 9.3 Key storage

A passwordless local keystore can be stolen by malware, backups, or another process with sufficient privileges. The MVP wallet must not hold valuable assets.

### 9.4 Incentive to waste tokens

Linear weight makes more reported tokens more valuable in expectation. If AORE becomes valuable, users may generate useless traffic. A future design would need provider-backed attestations and quality or cost constraints; merely adjusting difficulty does not solve this externality.

### 9.5 Sybil behavior

Linear weight makes address splitting neutral when total reported usage is fixed. It does not prevent an attacker from fabricating more usage. Per-wallet caps, base tickets, and concave weight functions are intentionally avoided because they create a benefit from splitting identities.

## 10. MVP implementation

The MVP consists of:

- `AgentOre.sol`, a non-upgradeable ERC-20 and epoch lottery;
- Foundry unit and invariant-oriented tests;
- a native macOS menu bar app;
- a local Codex usage adapter;
- a local wallet and configurable JSON-RPC client;
- no deployment performed by the repository itself.

The app may automatically submit after the user explicitly enables onchain submission. Automatic actions must show the destination chain, contract address, estimated cadence, and the fact that gas is paid from the local wallet.

## 11. Path to stronger verification

AgentOre can become less trusting only if an independent party can authenticate metering. Plausible future paths include:

1. provider-signed usage receipts bound to a public key;
2. an API proxy that meters requests, with the tradeoff of centralization;
3. trusted execution environments with remote attestation, still dependent on provider and hardware assumptions;
4. a different definition of work that is natively verifiable onchain.

Submitting frequently, chaining receipts, or requiring locally consistent timestamps does not turn self-reported data into a cryptographic proof. Those techniques can make editing more visible, but not impossible.

## 12. Conclusion

AgentOre is a minimal experiment in AI usage mining: one local client, one daily submission, one permissionless settlement transaction, one winner, and a fixed halving schedule. Its value is in making the mechanism testable while keeping the trust boundary explicit. The protocol should be evaluated first as a product interaction and cryptoeconomic toy, not as a financial primitive.
