#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

CURRENT_VERSION=$(solana --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

echo "Solana Validator Node - Upgrade"
echo "Current version: $CURRENT_VERSION"
echo "Configured version: ${SOLANA_VERSION:-stable}"
echo ""
echo "Options:"
echo "  1. stable (latest stable)"
echo "  2. beta (latest beta)"
echo "  3. Custom version (e.g., 1.19.0)"
echo ""

read -p "Enter version [${SOLANA_VERSION:-stable}]: " NEW_VERSION
NEW_VERSION="${NEW_VERSION:-${SOLANA_VERSION:-stable}}"

[ "$NEW_VERSION" != "stable" ] && [ "$NEW_VERSION" != "beta" ] && [ "$NEW_VERSION" = "$CURRENT_VERSION" ] && read -p "Version already installed. Continue? (yes/no): " confirm && [ "$confirm" != "yes" ] && exit 0

read -p "Upgrade from $CURRENT_VERSION to $NEW_VERSION? (yes/no): " confirm
[ "$confirm" != "yes" ] && exit 0

echo ""
echo "[1/4] Stopping validator..."
pgrep -f "solana-test-validator" > /dev/null && "$SCRIPT_DIR/stop-validator.sh" && sleep 2 || echo "Validator not running"

echo "[2/4] Creating backup..."
BACKUP_DIR="$HOME/solana-backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/solana-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
[ -d "$HOME/.local/share/solana" ] && tar -czf "$BACKUP_FILE" -C "$HOME/.local/share" solana 2>/dev/null && echo "✓ Backup: $BACKUP_FILE" || echo "⚠ No existing installation to backup"

echo "[3/4] Installing Solana $NEW_VERSION..."
if [ "$NEW_VERSION" = "stable" ]; then
    INSTALL_URL="https://release.solana.com/stable/install"
elif [ "$NEW_VERSION" = "beta" ]; then
    INSTALL_URL="https://release.solana.com/beta/install"
else
    INSTALL_URL="https://release.solana.com/$NEW_VERSION/install"
fi

sh -c "$(curl -sSfL "$INSTALL_URL")" || { echo "✗ Installation failed"; exit 1; }

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
command -v solana > /dev/null || { echo "✗ Solana CLI not found after installation"; exit 1; }

INSTALLED_VERSION=$(solana --version 2>/dev/null | head -1)
echo "✓ Installed: $INSTALLED_VERSION"

echo "[4/4] Updating configuration..."
sed -i "s|SOLANA_VERSION=.*|SOLANA_VERSION=\"$NEW_VERSION\"|" "$REPO_ROOT/configs/config.env" 2>/dev/null || true

echo ""
echo "Upgrade Complete!"
echo "  Previous: $CURRENT_VERSION"
echo "  New: $NEW_VERSION"
echo "  Backup: $BACKUP_FILE"
echo ""
echo "Next: ./scripts/verify-setup.sh"
