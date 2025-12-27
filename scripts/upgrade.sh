#!/bin/bash

# Solana Production Cluster - Upgrade Script
# Safely upgrades Solana version with rollback capability

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/configs/config.env" ]; then
    source "$REPO_ROOT/configs/config.env"
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

echo "=========================================="
echo "Solana Production Cluster - Upgrade"
echo "=========================================="
echo ""

# Get current version
CURRENT_VERSION=$(solana --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
log_info "Current Solana version: $CURRENT_VERSION"
log_info "Configured version in config.env: $SOLANA_VERSION"
echo ""

# Prompt for new version
echo "Available options:"
echo "  1. stable (latest stable version)"
echo "  2. beta (latest beta version)"
echo "  3. Custom version (e.g., 1.19.0)"
echo ""
read -p "Enter Solana version to install [$SOLANA_VERSION]: " NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
    NEW_VERSION="$SOLANA_VERSION"
fi

# Check if upgrade is needed
if [ "$NEW_VERSION" = "stable" ] || [ "$NEW_VERSION" = "beta" ]; then
    log_info "Will install latest $NEW_VERSION version"
else
    if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
        log_warning "Version $NEW_VERSION is already installed"
        read -p "Continue anyway? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Upgrade cancelled"
            exit 0
        fi
    fi
fi

echo ""
log_warning "This will upgrade Solana from $CURRENT_VERSION to $NEW_VERSION"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Upgrade cancelled"
    exit 0
fi

# Step 1: Stop validator
log_info "[1/6] Stopping validator..."
if pgrep -f "solana-test-validator" > /dev/null; then
    "$SCRIPT_DIR/stop-validator.sh"
    sleep 3
    log_success "Validator stopped"
else
    log_info "Validator not running"
fi

# Step 2: Create backup
log_info "[2/6] Creating backup..."
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/solana-backup-$BACKUP_TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

# Backup Solana installation
SOLANA_INSTALL_DIR="$HOME/.local/share/solana"
if [ -d "$SOLANA_INSTALL_DIR" ]; then
    log_info "Backing up Solana installation..."
    tar -czf "$BACKUP_FILE" -C "$HOME/.local/share" solana 2>/dev/null || true
    log_success "Backup created: $BACKUP_FILE"
else
    log_warning "No existing installation to backup"
fi

# Backup configuration
CONFIG_BACKUP="$BACKUP_DIR/config-backup-$BACKUP_TIMESTAMP.tar.gz"
tar -czf "$CONFIG_BACKUP" -C "$REPO_ROOT" configs/ 2>/dev/null || true
log_success "Configuration backed up: $CONFIG_BACKUP"

# Step 3: Update config.env
log_info "[3/6] Updating configuration..."
OLD_VERSION="$SOLANA_VERSION"
sed -i "s|SOLANA_VERSION=\"$OLD_VERSION\"|SOLANA_VERSION=\"$NEW_VERSION\"|" "$REPO_ROOT/configs/config.env"
log_success "Configuration updated"

# Step 4: Install new version
log_info "[4/6] Installing Solana CLI $NEW_VERSION..."

# Determine installation URL
if [ "$NEW_VERSION" = "stable" ]; then
    INSTALL_URL="https://release.solana.com/stable/install"
elif [ "$NEW_VERSION" = "beta" ]; then
    INSTALL_URL="https://release.solana.com/beta/install"
else
    INSTALL_URL="https://release.solana.com/$NEW_VERSION/install"
fi

# Install Solana
sh -c "$(curl -sSfL "$INSTALL_URL")"

# Update PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
if command -v solana &> /dev/null; then
    INSTALLED_VERSION=$(solana --version 2>/dev/null | head -1 || echo "")
    log_success "Solana CLI installed successfully"
    echo "  Installed: $INSTALLED_VERSION"
else
    log_error "Installation failed"
    log_info "Restoring previous version..."
    sed -i "s|SOLANA_VERSION=\"$NEW_VERSION\"|SOLANA_VERSION=\"$OLD_VERSION\"|" "$REPO_ROOT/configs/config.env"
    exit 1
fi

# Step 5: Verify compatibility
log_info "[5/6] Verifying installation..."
if solana --version > /dev/null 2>&1; then
    log_success "Solana CLI is working correctly"
else
    log_error "Solana CLI verification failed"
    exit 1
fi

# Step 6: Document upgrade
log_info "[6/6] Documenting upgrade..."
UPGRADE_LOG="$REPO_ROOT/logs/upgrades.log"
mkdir -p "$REPO_ROOT/logs"
echo "$(date -Iseconds) | Upgraded from $CURRENT_VERSION to $NEW_VERSION | Backup: $BACKUP_FILE" >> "$UPGRADE_LOG"
log_success "Upgrade documented"

echo ""
log_success "=========================================="
echo "Upgrade Complete!"
log_success "=========================================="
echo ""
echo "Upgrade Summary:"
echo "  Previous version: $CURRENT_VERSION"
echo "  New version: $NEW_VERSION"
echo "  Backup location: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "1. Test the new version: ./scripts/verify-setup.sh"
echo "2. Start validator: ./scripts/start-validator.sh"
echo "3. Monitor logs: tail -f $REPO_ROOT/logs/validator.log"
echo ""
echo "If you encounter issues, you can rollback using:"
echo "  tar -xzf $BACKUP_FILE -C $HOME/.local/share/"
echo ""

