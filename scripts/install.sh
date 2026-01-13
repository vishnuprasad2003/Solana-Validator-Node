#!/bin/bash
# Install Solana CLI and Agave validator
# Uses direct download method (like Dockerfile) for reliability

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

INSTALL_DIR="$HOME/.local/share/solana/install"
BIN_DIR="$INSTALL_DIR/active_release/bin"
SOLANA_VERSION="${SOLANA_VERSION:-v1.18.26}"

# Function to download with retry
download_file() {
    local url=$1
    local output=$2
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if wget -q --no-check-certificate "$url" -O "$output" 2>/dev/null; then
            return 0
        fi
        if curl -sSfL --insecure "$url" -o "$output" 2>/dev/null; then
            return 0
        fi
        ((retry++))
        log_warn "Download attempt $retry failed, retrying..."
        sleep 2
    done
    return 1
}

# Check if already installed
if [[ -f "$BIN_DIR/solana" ]] && ([[ -f "$BIN_DIR/agave-validator" ]] || [[ -f "$BIN_DIR/solana-validator" ]]); then
    log_info "Solana tools already installed"
    export PATH="$BIN_DIR:$PATH"
    solana --version 2>/dev/null || true
    agave-validator --version 2>/dev/null || solana-validator --version 2>/dev/null || true
    exit 0
fi

# Method 1: Try Solana installer script (for CLI tools)
log_info "Installing Solana CLI tools..."
if curl -sSfL https://release.solana.com/stable/install 2>/dev/null | sh 2>/dev/null; then
    log_success "Solana CLI installed via installer"
else
    log_warn "Solana installer had issues, trying direct download..."
fi

# Method 2: Direct download of full Solana release (includes validator)
log_info "Installing Solana release (includes validator)..."
TEMP_DIR=$(mktemp -d)
TARBALL="$TEMP_DIR/solana-release.tar.bz2"
RELEASE_URL="https://github.com/solana-labs/solana/releases/download/${SOLANA_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2"

log_info "Downloading Solana ${SOLANA_VERSION}..."
if download_file "$RELEASE_URL" "$TARBALL"; then
    log_info "Extracting Solana release..."
    mkdir -p "$INSTALL_DIR/active_release"
    tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" --strip-components=1 2>/dev/null || {
        # Try without strip-components if that fails
        tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" 2>/dev/null
        # Move bin directory if needed
        if [[ -d "$INSTALL_DIR/active_release/solana-release" ]]; then
            mv "$INSTALL_DIR/active_release/solana-release/bin" "$INSTALL_DIR/active_release/" 2>/dev/null || true
        fi
    }
    rm -f "$TARBALL"
    rmdir "$TEMP_DIR" 2>/dev/null || true
    log_success "Solana release extracted"
else
    log_warn "Direct download failed, checking if installer worked..."
    rm -rf "$TEMP_DIR"
fi

# Verify installation
export PATH="$BIN_DIR:$PATH"

# Check Solana CLI
if [[ -f "$BIN_DIR/solana" ]]; then
    log_success "Solana CLI found"
    solana --version 2>/dev/null || true
else
    log_error "Solana CLI not found"
    log_info "Manual installation: https://docs.solana.com/cli/install-solana-cli-tools"
fi

# Check Validator (agave-validator or solana-validator)
if [[ -f "$BIN_DIR/agave-validator" ]]; then
    log_success "Agave validator found"
    agave-validator --version 2>/dev/null || true
elif [[ -f "$BIN_DIR/solana-validator" ]]; then
    log_success "Solana validator found"
    solana-validator --version 2>/dev/null || true
else
    log_warn "Validator binary not found in $BIN_DIR"
    log_info "Checking alternative locations..."
    
    # Check if agave-install can install it
    if [[ -f "$BIN_DIR/agave-install" ]]; then
        log_info "Found agave-install, attempting to install validator..."
        "$BIN_DIR/agave-install" init "$SOLANA_VERSION" 2>/dev/null || true
    fi
    
    # Final check
    if command -v agave-validator >/dev/null 2>&1 || command -v solana-validator >/dev/null 2>&1; then
        log_success "Validator found in PATH"
        agave-validator --version 2>/dev/null || solana-validator --version 2>/dev/null || true
    else
        log_error "Validator not found. You may need to install manually."
        log_info "Alternative: Download from https://github.com/solana-labs/solana/releases"
        log_info "Or build from source: https://github.com/anza-xyz/agave"
    fi
fi

log_info ""
log_info "Add to your shell profile (~/.bashrc or ~/.zshrc):"
log_info 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
