#!/bin/bash
# Download Metaplex Token Metadata Program

set -e

PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

mkdir -p "$PROGRAMS_DIR"

if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo "Token Metadata program already exists. Removing old version..."
    rm -f "$METADATA_PROGRAM_FILE"
fi

echo "Downloading Token Metadata program from mainnet..."
echo "  Program ID: $METADATA_PROGRAM_ID"
echo "  Output: $METADATA_PROGRAM_FILE"

if solana program dump -u m "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE"; then
    echo "✓ Token Metadata program downloaded successfully"
    echo "  File: $METADATA_PROGRAM_FILE"
    echo "  Size: $(du -h "$METADATA_PROGRAM_FILE" | cut -f1)"
    echo ""
    echo "The program will be automatically loaded when you restart the validator."
else
    echo "✗ Failed to download Token Metadata program"
    echo "  Make sure you have internet connection and Solana CLI is installed"
    exit 1
fi
