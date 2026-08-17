#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${AGENTORE_ENV_FILE:-$CONTRACTS_DIR/.env}"

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || fail "$name is missing in $ENV_FILE"
}

[[ -f "$ENV_FILE" ]] || fail "Missing $ENV_FILE. Copy .env.example to .env first."

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_command forge
require_command cast
require_value BASE_RPC_URL
require_value BASE_CHAIN_ID
require_value PRIVATE_KEY
require_value ETHERSCAN_API_KEY

[[ "$BASE_CHAIN_ID" == "8453" ]] || fail "BASE_CHAIN_ID must be 8453 for Base Mainnet."
[[ "$PRIVATE_KEY" =~ ^0x[0-9a-fA-F]{64}$ ]] || fail "PRIVATE_KEY must be 32 bytes with a 0x prefix."

RPC_CHAIN_ID="$(cast chain-id --rpc-url "$BASE_RPC_URL")"
[[ "$RPC_CHAIN_ID" == "$BASE_CHAIN_ID" ]] || fail "RPC returned chain ID $RPC_CHAIN_ID, expected $BASE_CHAIN_ID."

DEPLOYER_ADDRESS="$(cast wallet address --private-key "$PRIVATE_KEY")"
DEPLOYER_BALANCE_WEI="$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$BASE_RPC_URL")"
DEPLOYER_BALANCE_ETH="$(cast to-unit "$DEPLOYER_BALANCE_WEI" ether)"

echo "Base Mainnet preflight"
echo "  Chain ID: $RPC_CHAIN_ID"
echo "  Deployer: $DEPLOYER_ADDRESS"
echo "  Balance:  $DEPLOYER_BALANCE_ETH ETH"

[[ "$DEPLOYER_BALANCE_WEI" != "0" ]] || fail "The deployer has no ETH on Base Mainnet."

cd "$CONTRACTS_DIR"

forge fmt --check
forge test -vv
forge build --sizes

echo
echo "Running a non-broadcast Base Mainnet deployment simulation..."
forge script script/Deploy.s.sol:DeployAgentOre \
  --rpc-url "$BASE_RPC_URL" \
  -vvv

echo
echo "Preflight complete. No transaction was broadcast."
