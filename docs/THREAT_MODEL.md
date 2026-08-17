# Threat Model

## Assets

- the integrity of the daily weighted draw;
- the fixed AORE issuance schedule;
- participants' local private keys;
- the privacy of local AI conversations and source code;
- clear communication of what the system does and does not prove.

## Trusted components

For the MVP, a participant trusts their own macOS environment, downloaded app build, configured RPC response, and selected EVM chain. The contract does not trust the app.

## Threats

| Threat | MVP status | Consequence | Future mitigation |
| --- | --- | --- | --- |
| Edited Codex logs | Unresolved | Inflated weight | Provider-signed receipts |
| Patched app/direct contract call | Unresolved | Arbitrary counters | Independently authenticated meter |
| Address splitting | Economically neutral for fixed total | More gas, no extra linear weight | Preserve linear weighting |
| Fabricated new usage | Unresolved | Dominates lottery | Cannot solve without a trusted measurement source |
| Finalizer timing/address search | Unresolved | Biased randomness | VRF or analyzed commit-reveal |
| Validator block influence | Unresolved | Biased randomness | Verifiable randomness |
| Private-key theft | Partially mitigated by file permissions | Wallet loss | Keychain, Secure Enclave-backed policy, or external wallet |
| Malicious RPC | Partially mitigated by chain verification | Censorship or misleading reads | Multiple/configurable RPCs and receipt verification |
| Parser format drift | Detected through tests, not prevented | Under/overcounting | Versioned adapters and fixtures |
| Token-waste incentives | Unresolved | Artificial AI traffic | No-value MVP; later quality/cost constraints |

## Security boundary

An Ethereum signature proves control of an address. A monotonic counter proves consistency relative to prior submissions. Neither proves that the counter came from an AI provider.

The MVP should not be deployed where AORE can be redeemed, sold, used as collateral, or exchanged for valuable benefits.

