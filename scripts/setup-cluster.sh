#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

command -v solana > /dev/null || { echo "Error: Solana CLI not found. Run ./scripts/install.sh first"; exit 1; }

echo "Solana Validator Node - Setup"
echo ""

LEDGER_DIR="${LEDGER_DIR:-$HOME/solana-local-ledger}"
PROGRAMS_DIR="${PROGRAMS_DIR:-$HOME/.local/share/solana-programs}"

mkdir -p "$LEDGER_DIR" "$HOME/.config/solana" "$PROGRAMS_DIR"

VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
DEFAULT_KEYPAIR="$HOME/.config/solana/id.json"

[ ! -f "$VALIDATOR_KEYPAIR" ] && solana-keygen new --outfile "$VALIDATOR_KEYPAIR" --no-bip39-passphrase --force && echo "✓ Validator keypair generated" || echo "✓ Using existing validator keypair"
VALIDATOR_ADDRESS=$(solana address -k "$VALIDATOR_KEYPAIR" 2>/dev/null || echo "unknown")

[ ! -f "$DEFAULT_KEYPAIR" ] && solana-keygen new --outfile "$DEFAULT_KEYPAIR" --no-bip39-passphrase --force && echo "✓ Default keypair generated" || echo "✓ Using existing default keypair"
DEFAULT_ADDRESS=$(solana address -k "$DEFAULT_KEYPAIR" 2>/dev/null || echo "unknown")

solana config set --url "http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}" > /dev/null 2>&1 || true
echo "✓ Solana CLI configured"

if [ "${DOWNLOAD_METAPLEX_PROGRAM:-true}" = "true" ] && [ ! -f "${METADATA_PROGRAM_FILE:-$PROGRAMS_DIR/mpl-token-metadata.so}" ]; then
    echo "Downloading Metaplex Token Metadata program..."
    solana program dump "${METADATA_PROGRAM_ID:-metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s}" "${METADATA_PROGRAM_FILE:-$PROGRAMS_DIR/mpl-token-metadata.so}" --url https://api.mainnet-beta.solana.com 2>/dev/null && echo "✓ Metaplex program downloaded" || echo "⚠ Metaplex download failed (non-critical)"
fi

echo ""
echo "Setup Complete!"
echo "  Validator: $VALIDATOR_ADDRESS"
echo "  Default: $DEFAULT_ADDRESS"
echo "  RPC: http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}"
echo ""
echo "Next: ./scripts/start-validator.sh"
