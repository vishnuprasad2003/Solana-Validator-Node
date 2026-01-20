#!/bin/bash
# Download essential programs for genesis

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Use Azure File Share for programs if mounted, otherwise project root
if [[ -d "/solana" ]]; then
    PROGRAMS_DIR="/solana/programs"
else
    PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"
fi
mkdir -p "$PROGRAMS_DIR"

declare -A PROGRAMS=(
    ["spl_token.so"]="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    ["spl_token_2022.so"]="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    ["spl_associated_token_account.so"]="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    ["mpl_token_metadata.so"]="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
)

echo "Downloading programs from mainnet..."
for FILE in "${!PROGRAMS[@]}"; do
    PATH_FILE="${PROGRAMS_DIR}/${FILE}"
    [[ -f "$PATH_FILE" ]] && { echo "  ✓ $FILE exists"; continue; }
    echo "  Downloading $FILE..."
    solana program dump "${PROGRAMS[$FILE]}" "$PATH_FILE" --url https://api.mainnet-beta.solana.com 2>/dev/null || \
        { echo "  ✗ Failed: $FILE"; continue; }
    echo "  ✓ $FILE"
done
echo "Done!"
