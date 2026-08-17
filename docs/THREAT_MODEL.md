# Threat Model

## Assets

- the integrity of the daily weighted draw;
- the fixed AORE issuance schedule;
- participants' local private keys;
- the privacy of local AI conversations and source code;
- clear communication of what the system does and does not prove.

## Trusted components

In v0.0.1, a participant trusts their own macOS environment, downloaded app build, configured RPC response, and selected EVM chain. The contract does not trust the app.

## Threats

| Threat | v0.0.1 status | Consequence | Required mitigation for valuable assets |
| --- | --- | --- | --- |
| Patched app/direct contract call | Unresolved | Arbitrary counters despite account usage reads | Provider-signed receipts verified onchain |
| Account usage unavailable or delayed | Fail closed in the client | Submission is paused | Surface freshness metadata if the service provides it |
| Address splitting | Economically neutral for fixed total | More gas, no extra linear weight | Preserve linear weighting |
| Fabricated new usage | Unresolved | Dominates lottery | Cannot solve without a trusted measurement source |
| Finalizer timing/address search | Unresolved | Biased randomness | VRF or analyzed commit-reveal |
| Validator block influence | Unresolved | Biased randomness | Verifiable randomness |
| Private-key theft | Partially mitigated by file permissions | Wallet loss | Keychain, Secure Enclave-backed policy, or external wallet |
| Malicious RPC | Partially mitigated by chain verification | Censorship or misleading reads | Multiple/configurable RPCs and receipt verification |
| Parser format drift | Detected through tests, not prevented | Under/overcounting | Versioned adapters and fixtures |
| Token-waste incentives | Unresolved | Artificial AI traffic | Keep v0.0.1 valueless; add quality or cost constraints before valuable use |

## Security boundary

An Ethereum signature proves control of an address. A monotonic counter proves consistency relative to prior submissions. Neither proves that the counter came from an AI provider.

Version v0.0.1 must not be deployed where AORE can be redeemed, sold, used as collateral, or exchanged for valuable benefits.
