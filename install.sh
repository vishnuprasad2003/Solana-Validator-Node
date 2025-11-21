#!/bin/bash

# Solana Validator Node Installation Script
# This script installs Rust, Solana CLI, and configures the environment

set -e

echo "=========================================="
echo "Solana Validator Node Installation"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}Please do not run this script as root${NC}"
   exit 1
fi

# Step 1: Install Rust
echo -e "${YELLOW}[1/4] Checking Rust installation...${NC}"
if command -v rustc &> /dev/null; then
    echo -e "${GREEN}✓ Rust is already installed${NC}"
    rustc --version
else
    echo -e "${YELLOW}Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "${GREEN}✓ Rust installed successfully${NC}"
    rustc --version
fi

# Ensure cargo is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    # Defaults if config.env doesn't exist
    SOLANA_VERSION="stable"
fi

# Step 2: Install Solana CLI
echo ""
echo -e "${YELLOW}[2/4] Installing Solana CLI ($SOLANA_VERSION version)...${NC}"

# Check if Solana is already installed
if command -v solana &> /dev/null; then
    echo -e "${GREEN}✓ Solana CLI is already installed${NC}"
    solana --version
    echo -e "${YELLOW}Updating to $SOLANA_VERSION version...${NC}"
    if [ "$SOLANA_VERSION" = "stable" ]; then
        sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
    elif [ "$SOLANA_VERSION" = "beta" ]; then
        sh -c "$(curl -sSfL https://release.solana.com/beta/install)"
    else
        sh -c "$(curl -sSfL https://release.solana.com/$SOLANA_VERSION/install)"
    fi
else
    echo -e "${YELLOW}Installing Solana CLI ($SOLANA_VERSION)...${NC}"
    if [ "$SOLANA_VERSION" = "stable" ]; then
        sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
    elif [ "$SOLANA_VERSION" = "beta" ]; then
        sh -c "$(curl -sSfL https://release.solana.com/beta/install)"
    else
        sh -c "$(curl -sSfL https://release.solana.com/$SOLANA_VERSION/install)"
    fi
fi

# Add Solana to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify Solana installation
if command -v solana &> /dev/null; then
    echo -e "${GREEN}✓ Solana CLI installed successfully${NC}"
    solana --version
else
    echo -e "${RED}✗ Solana CLI installation failed${NC}"
    exit 1
fi

# Step 3: Install Anchor (for program development)
echo ""
echo -e "${YELLOW}[3/4] Installing Anchor framework...${NC}"
if command -v anchor &> /dev/null; then
    echo -e "${GREEN}✓ Anchor is already installed${NC}"
    anchor --version
else
    echo -e "${YELLOW}Installing Anchor...${NC}"
    cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
    export PATH="$HOME/.cargo/bin:$PATH"
    avm install latest
    avm use latest
    echo -e "${GREEN}✓ Anchor installed successfully${NC}"
    anchor --version
fi

# Step 4: Configure PATH in shell profile
echo ""
echo -e "${YELLOW}[4/4] Configuring PATH in shell profile...${NC}"

SHELL_PROFILE=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
fi

if [ -n "$SHELL_PROFILE" ]; then
    # Check if PATH entries already exist
    if ! grep -q "export PATH.*solana" "$SHELL_PROFILE"; then
        echo "" >> "$SHELL_PROFILE"
        echo "# Solana CLI PATH" >> "$SHELL_PROFILE"
        echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$SHELL_PROFILE"
        echo -e "${GREEN}✓ Added Solana to $SHELL_PROFILE${NC}"
    else
        echo -e "${GREEN}✓ Solana PATH already configured in $SHELL_PROFILE${NC}"
    fi
    
    if ! grep -q "export PATH.*cargo" "$SHELL_PROFILE"; then
        echo "" >> "$SHELL_PROFILE"
        echo "# Rust/Cargo PATH" >> "$SHELL_PROFILE"
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$SHELL_PROFILE"
        echo -e "${GREEN}✓ Added Rust/Cargo to $SHELL_PROFILE${NC}"
    else
        echo -e "${GREEN}✓ Rust/Cargo PATH already configured in $SHELL_PROFILE${NC}"
    fi
fi

# Step 5: Install additional dependencies
echo ""
echo -e "${YELLOW}Installing additional dependencies...${NC}"

# Check for required system packages
REQUIRED_PACKAGES=("build-essential" "pkg-config" "libudev-dev" "libssl-dev")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${MISSING_PACKAGES[*]}${NC}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PACKAGES[@]}"
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ All required dependencies are installed${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Source your shell profile: source $SHELL_PROFILE"
echo "2. Run: ./setup-validator.sh"
echo ""
echo "Current versions:"
echo "  Rust: $(rustc --version 2>/dev/null || echo 'Not in PATH')"
echo "  Solana: $(solana --version 2>/dev/null || echo 'Not in PATH')"
echo "  Anchor: $(anchor --version 2>/dev/null || echo 'Not in PATH')"
echo ""

