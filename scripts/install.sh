#!/bin/bash

# Solana Validator Node - Installation Script
# Installs Rust, Solana CLI, and all required dependencies
# This script is idempotent - safe to run multiple times

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/configs/config.env" ]; then
    source "$REPO_ROOT/configs/config.env"
else
    echo -e "${RED}Error: config.env not found at $REPO_ROOT/configs/config.env${NC}"
    exit 1
fi

# Setup logging
mkdir -p "$REPO_ROOT/logs"
LOG_FILE="$REPO_ROOT/logs/install.log"

# Logging functions (write to both console and log file)
log_info() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$timestamp [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$timestamp [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$timestamp [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$timestamp [ERROR] $1" >> "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root"
    exit 1
fi

echo "=========================================="
echo "Solana Validator Node - Installation"
echo "=========================================="
echo ""

# Step 1: Update system packages
log_info "[1/6] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
log_success "System packages updated"

# Step 2: Install system dependencies
log_info "[2/6] Installing system dependencies..."
REQUIRED_PACKAGES=(
    "build-essential"
    "pkg-config"
    "libudev-dev"
    "libssl-dev"
    "curl"
    "git"
    "wget"
    "jq"
    "tmux"
    "ufw"
)

MISSING_PACKAGES=()
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log_info "Installing missing packages: ${MISSING_PACKAGES[*]}"
    sudo apt-get install -y "${MISSING_PACKAGES[@]}" > /dev/null
    log_success "Dependencies installed"
else
    log_success "All required dependencies are installed"
fi

# Step 3: Install Rust
log_info "[3/6] Checking Rust installation..."
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log_success "Rust is already installed (version $RUST_VERSION)"
else
    log_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
    log_success "Rust installed successfully"
    rustc --version
fi

# Ensure cargo is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Step 4: Install Solana CLI
log_info "[4/6] Installing Solana CLI ($SOLANA_VERSION version)..."

# Determine installation URL
if [ "$SOLANA_VERSION" = "stable" ]; then
    INSTALL_URL="https://release.solana.com/stable/install"
elif [ "$SOLANA_VERSION" = "beta" ]; then
    INSTALL_URL="https://release.solana.com/beta/install"
else
    INSTALL_URL="https://release.solana.com/$SOLANA_VERSION/install"
fi

# Install or update Solana
if command -v solana &> /dev/null; then
    CURRENT_VERSION=$(solana --version 2>/dev/null | head -1 || echo "unknown")
    log_info "Solana CLI is already installed ($CURRENT_VERSION)"
    log_info "Updating to $SOLANA_VERSION version..."
else
    log_info "Installing Solana CLI ($SOLANA_VERSION)..."
fi

sh -c "$(curl -sSfL "$INSTALL_URL")"

# Add Solana to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
if command -v solana &> /dev/null; then
    INSTALLED_VERSION=$(solana --version 2>/dev/null | head -1 || echo "")
    log_success "Solana CLI installed successfully"
    echo "  Version: $INSTALLED_VERSION"
else
    log_error "Solana CLI installation failed"
    exit 1
fi

# Step 5: Install Anchor (optional, for program development)
log_info "[5/6] Installing Anchor framework..."
if command -v anchor &> /dev/null; then
    log_success "Anchor is already installed"
    anchor --version
else
    log_info "Installing Anchor..."
    cargo install --git https://github.com/coral-xyz/anchor avm --locked --force > /dev/null 2>&1
    export PATH="$HOME/.cargo/bin:$PATH"
    avm install latest > /dev/null 2>&1
    avm use latest > /dev/null 2>&1
    log_success "Anchor installed successfully"
    anchor --version
fi

# Step 6: Configure shell profile
log_info "[6/6] Configuring shell profile..."

SHELL_PROFILE=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
fi

if [ -n "$SHELL_PROFILE" ]; then
    # Add Solana to PATH if not already present
    if ! grep -q "export PATH.*solana" "$SHELL_PROFILE"; then
        {
            echo ""
            echo "# Solana CLI PATH"
            echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
        } >> "$SHELL_PROFILE"
        log_success "Added Solana to $SHELL_PROFILE"
    else
        log_success "Solana PATH already configured in $SHELL_PROFILE"
    fi
    
    # Add Rust/Cargo to PATH if not already present
    if ! grep -q "export PATH.*cargo" "$SHELL_PROFILE"; then
        {
            echo ""
            echo "# Rust/Cargo PATH"
            echo 'export PATH="$HOME/.cargo/bin:$PATH"'
        } >> "$SHELL_PROFILE"
        log_success "Added Rust/Cargo to $SHELL_PROFILE"
    else
        log_success "Rust/Cargo PATH already configured in $SHELL_PROFILE"
    fi
fi

# Create necessary directories
log_info "Creating necessary directories..."
mkdir -p "$BACKUP_DIR"
mkdir -p "$PROGRAMS_DIR"
mkdir -p "$REPO_ROOT/logs"
log_success "Directories created"

echo ""
log_success "=========================================="
echo "Installation Complete!"
log_success "=========================================="
echo ""
echo "Installed versions:"
echo "  Rust: $(rustc --version 2>/dev/null || echo 'Not in PATH')"
echo "  Solana: $(solana --version 2>/dev/null || echo 'Not in PATH')"
echo "  Anchor: $(anchor --version 2>/dev/null || echo 'Not in PATH')"
echo ""
echo "Next steps:"
echo "1. Source your shell profile: source $SHELL_PROFILE"
echo "2. Run: ./scripts/setup-cluster.sh"
echo ""

