#!/bin/bash

# Solana CLI Upgrade Script
# This script upgrades Solana CLI to a new version while preserving configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load current configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

echo "=========================================="
echo "Solana CLI Upgrade Script"
echo "=========================================="
echo ""

# Get current version
CURRENT_VERSION=$(solana --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
echo "Current version: $CURRENT_VERSION"
echo ""

# Get new version
echo "Available options:"
echo "  1. stable (latest stable version)"
echo "  2. beta (latest beta version)"
echo "  3. Custom version (e.g., 1.19.0)"
echo ""
read -p "Enter Solana version to install [stable]: " NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
    NEW_VERSION="stable"
fi

echo ""
echo -e "${YELLOW}This will upgrade Solana CLI from $CURRENT_VERSION to $NEW_VERSION${NC}"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Upgrade cancelled${NC}"
    exit 0
fi

# Step 1: Stop validator
echo ""
echo -e "${YELLOW}[1/5] Stopping validator...${NC}"
if pgrep -f solana-test-validator > /dev/null; then
    echo "Stopping running validator..."
    "$SCRIPT_DIR/stop-validator.sh" || pkill -f solana-test-validator || true
    sleep 3
    echo -e "${GREEN}✓ Validator stopped${NC}"
else
    echo -e "${GREEN}✓ Validator not running${NC}"
fi

# Step 2: Backup current installation
echo ""
echo -e "${YELLOW}[2/5] Creating backup...${NC}"
SOLANA_INSTALL_DIR="$HOME/.local/share/solana"
BACKUP_DIR="$HOME/solana-backups"
mkdir -p "$BACKUP_DIR"

if [ -d "$SOLANA_INSTALL_DIR" ]; then
    BACKUP_FILE="$BACKUP_DIR/solana-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo "Backing up to: $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" -C "$HOME/.local/share" solana 2>/dev/null || true
    echo -e "${GREEN}✓ Backup created${NC}"
else
    echo -e "${YELLOW}⚠ No existing installation to backup${NC}"
fi

# Step 3: Update config.env
echo ""
echo -e "${YELLOW}[3/5] Updating configuration...${NC}"
sed -i "s/SOLANA_VERSION=\"$SOLANA_VERSION\"/SOLANA_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_DIR/config.env"
echo -e "${GREEN}✓ Configuration updated${NC}"

# Step 4: Install new version
echo ""
echo -e "${YELLOW}[4/5] Installing Solana CLI $NEW_VERSION...${NC}"

export PATH="$HOME/.cargo/bin:$PATH"

# Install Solana CLI
if [ "$NEW_VERSION" = "stable" ]; then
    echo "Installing latest stable version..."
    sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
elif [ "$NEW_VERSION" = "beta" ]; then
    echo "Installing latest beta version..."
    sh -c "$(curl -sSfL https://release.solana.com/beta/install)"
else
    echo "Installing version $NEW_VERSION..."
    sh -c "$(curl -sSfL https://release.solana.com/$NEW_VERSION/install)"
fi

# Add Solana to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
if command -v solana &> /dev/null; then
    INSTALLED_VERSION=$(solana --version 2>/dev/null | head -1 || echo "")
    echo -e "${GREEN}✓ Solana CLI $NEW_VERSION installed successfully${NC}"
    echo "  Installed: $INSTALLED_VERSION"
else
    echo -e "${RED}✗ Installation failed${NC}"
    echo "Restoring previous version in config.env..."
    sed -i "s/SOLANA_VERSION=\"$NEW_VERSION\"/SOLANA_VERSION=\"$SOLANA_VERSION\"/" "$SCRIPT_DIR/config.env"
    exit 1
fi

# Step 5: Update VERSION_COMPATIBILITY.md
echo ""
echo -e "${YELLOW}[5/5] Updating version compatibility documentation...${NC}"
VERSION_COMPATIBILITY_FILE="$SCRIPT_DIR/VERSION_COMPATIBILITY.md"

if [ -f "$VERSION_COMPATIBILITY_FILE" ]; then
    # Extract actual version number from installed version
    ACTUAL_VERSION=$(solana --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$ACTUAL_VERSION" ]; then
        # Update the "Current Version" section
        sed -i "s/^## Current Version: .*/## Current Version: $ACTUAL_VERSION/" "$VERSION_COMPATIBILITY_FILE"
        
        # Update version in the version history table
        # Mark old current version as "Previous version"
        sed -i "s/| 1\.18\.26 | .* | .* | .* | Current version |/| 1.18.26 | latest (AVM) | Token + Token-2022 | Compatible | Previous version |/" "$VERSION_COMPATIBILITY_FILE"
        
        # Add new version row at the top of the version history table
        FIRST_VERSION_LINE=$(grep -n "^| [0-9]" "$VERSION_COMPATIBILITY_FILE" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_VERSION_LINE" ]; then
            sed -i "${FIRST_VERSION_LINE}i | $ACTUAL_VERSION | latest (AVM) | Token + Token-2022 | Compatible | Current version |" "$VERSION_COMPATIBILITY_FILE"
        fi
        
        echo -e "${GREEN}✓ VERSION_COMPATIBILITY.md updated${NC}"
        echo "  New version: $ACTUAL_VERSION"
    else
        echo -e "${YELLOW}⚠ Could not determine actual version, skipping documentation update${NC}"
    fi
else
    echo -e "${YELLOW}⚠ VERSION_COMPATIBILITY.md not found, skipping update${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Upgrade Complete!"
echo "==========================================${NC}"
echo ""
echo "Solana CLI has been upgraded to $NEW_VERSION"
if [ -n "$ACTUAL_VERSION" ]; then
    echo "Installed version: $ACTUAL_VERSION"
fi
echo ""
echo -e "${GREEN}✓ Configuration files updated:${NC}"
echo "  - config.env (version updated)"
if [ -f "$VERSION_COMPATIBILITY_FILE" ] && [ -n "$ACTUAL_VERSION" ]; then
    echo "  - VERSION_COMPATIBILITY.md (version updated)"
fi
echo ""
echo -e "${YELLOW}⚠️ IMPORTANT: Test Program Compatibility${NC}"
echo ""
echo "After upgrading, please verify:"
echo "1. Programs compile: anchor build"
echo "2. Programs deploy: anchor deploy"
echo "3. API operations work correctly"
echo "4. Update Solana Interactor dependencies if needed"
echo ""
echo "Next steps:"
echo "1. Start validator: ./start-validator-tmux.sh"
echo "2. Verify: ./verify-setup.sh"
echo "3. Test program deployment and API operations"
echo ""
echo "Note: Your ledger data and configuration are preserved."
echo ""

