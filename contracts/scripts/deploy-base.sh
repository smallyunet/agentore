#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${AGENTORE_ENV_FILE:-$CONTRACTS_DIR/.env}"
EXPECTED_CONFIRMATION="DEPLOY AGENTORE V0.0.1 TO BASE MAINNET"

if [[ "${1:-}" != "--broadcast" || $# -ne 1 ]]; then
  echo "Usage: $0 --broadcast" >&2
  echo "Run ./scripts/preflight-base.sh first." >&2
  exit 1
fi

"$SCRIPT_DIR/preflight-base.sh"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

echo
echo "This will broadcast an irreversible AgentOre v0.0.1 deployment to Base Mainnet."
echo "The contract is non-upgradeable and its epoch duration and finalizer share are immutable."
read -r -p "Type '$EXPECTED_CONFIRMATION' to continue: " confirmation

if [[ "$confirmation" != "$EXPECTED_CONFIRMATION" ]]; then
  echo "Deployment cancelled."
  exit 1
fi

cd "$CONTRACTS_DIR"

forge script script/Deploy.s.sol:DeployAgentOre \
  --rpc-url "$BASE_RPC_URL" \
  --broadcast \
  --slow \
  --verify \
  --verifier etherscan \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvv

echo
echo "Deployment command completed."
echo "Review broadcast/Deploy.s.sol/8453/run-latest.json and confirm the address on BaseScan."
