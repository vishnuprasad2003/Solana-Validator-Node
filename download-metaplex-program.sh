#!/bin/bash

# Download Metaplex Token Metadata Program
# This script downloads the Token Metadata program from mainnet for use in local validator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Downloading Metaplex Token Metadata Program"
echo "=========================================="
echo ""

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Configuration
PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

# Create programs directory
mkdir -p "$PROGRAMS_DIR"

# Check if program already exists
if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo -e "${YELLOW}Token Metadata program already exists at:${NC}"
    echo "  $METADATA_PROGRAM_FILE"
    read -p "Download again? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing program file${NC}"
        exit 0
    fi
    rm -f "$METADATA_PROGRAM_FILE"
fi

echo -e "${YELLOW}Downloading Token Metadata program from mainnet...${NC}"
echo "  Program ID: $METADATA_PROGRAM_ID"
echo "  Output: $METADATA_PROGRAM_FILE"
echo ""

# Download program from mainnet
if solana program dump -u m "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE"; then
    echo ""
    echo -e "${GREEN}✓ Token Metadata program downloaded successfully${NC}"
    echo "  File: $METADATA_PROGRAM_FILE"
    echo "  Size: $(du -h "$METADATA_PROGRAM_FILE" | cut -f1)"
    echo ""
    echo "The program will be automatically loaded when starting the validator."
else
    echo -e "${RED}✗ Failed to download Token Metadata program${NC}"
    echo "  Make sure you have internet connection and Solana CLI is installed"
    exit 1
fi

echo -e "${GREEN}=========================================="
echo "Download Complete!"
echo "==========================================${NC}"

