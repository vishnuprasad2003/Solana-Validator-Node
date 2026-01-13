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

# Check if agave-validator already installed (target binary)
if [[ -f "$BIN_DIR/solana" ]] && [[ -f "$BIN_DIR/agave-validator" ]]; then
    log_info "Agave validator already installed"
    export PATH="$BIN_DIR:$PATH"
    solana --version 2>/dev/null || true
    agave-validator --version 2>/dev/null || true
    exit 0
fi

# Method 1: Install Solana CLI tools (needed regardless of validator)
log_info "Installing Solana CLI tools..."
if curl -sSfL https://release.solana.com/stable/install 2>/dev/null | sh 2>/dev/null; then
    log_success "Solana CLI installed via installer"
else
    log_warn "Solana installer had issues, trying direct download..."
fi

# Method 2: Try Anza installer for agave-validator (PRIORITY)
log_info "Installing Agave validator via Anza installer..."
export PATH="$BIN_DIR:$PATH"
if curl -sSfL https://release.anza.xyz/stable/install 2>/dev/null | sh 2>/dev/null; then
    # Check if agave-validator was installed
    if [[ -f "$BIN_DIR/agave-validator" ]]; then
        log_success "Agave validator installed via Anza installer"
        agave-validator --version 2>/dev/null || true
    else
        log_warn "Anza installer ran but agave-validator not found in expected location"
    fi
else
    log_warn "Anza installer had issues, trying direct download..."
fi

# Method 3: Direct download of Agave release from Anza (if installer didn't work)
if [[ ! -f "$BIN_DIR/agave-validator" ]]; then
    log_info "Attempting direct download of Agave validator..."
    # Try to get latest version from Anza releases
    TEMP_DIR=$(mktemp -d)
    TARBALL="$TEMP_DIR/agave-release.tar.bz2"
    # Anza releases may use different naming, try common patterns
    AGAVE_RELEASE_URL="https://github.com/anza-xyz/agave/releases/download/${SOLANA_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2"
    
    if download_file "$AGAVE_RELEASE_URL" "$TARBALL"; then
        log_info "Extracting Agave release..."
        mkdir -p "$INSTALL_DIR/active_release"
        tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" --strip-components=1 2>/dev/null || {
            tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" 2>/dev/null
            if [[ -d "$INSTALL_DIR/active_release/solana-release" ]]; then
                mv "$INSTALL_DIR/active_release/solana-release/bin" "$INSTALL_DIR/active_release/" 2>/dev/null || true
            fi
        }
        rm -f "$TARBALL"
        rmdir "$TEMP_DIR" 2>/dev/null || true
        log_success "Agave release extracted"
    else
        log_warn "Direct Agave download failed, will try Solana release as fallback..."
        rm -rf "$TEMP_DIR"
    fi
fi

# Method 4: Fallback - Direct download of Solana Labs release (includes solana-validator, not agave)
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

# Check Validator (prioritize agave-validator)
if [[ -f "$BIN_DIR/agave-validator" ]]; then
    log_success "Agave validator found (preferred)"
    agave-validator --version 2>/dev/null || true
elif [[ -f "$BIN_DIR/solana-validator" ]]; then
    log_warn "Only solana-validator found (not agave-validator)"
    log_warn "Attempting to install agave-validator..."
    # Try Anza installer one more time
    if curl -sSfL https://release.anza.xyz/stable/install 2>/dev/null | sh 2>/dev/null; then
        if [[ -f "$BIN_DIR/agave-validator" ]]; then
            log_success "Agave validator installed successfully"
            agave-validator --version 2>/dev/null || true
        else
            log_error "Failed to install agave-validator. Only solana-validator available."
            log_info "Manual installation: https://release.anza.xyz/stable/install"
            solana-validator --version 2>/dev/null || true
        fi
    else
        log_error "Failed to install agave-validator. Only solana-validator available."
        log_info "Manual installation: https://release.anza.xyz/stable/install"
        solana-validator --version 2>/dev/null || true
    fi
else
    log_warn "Validator binary not found in $BIN_DIR"
    log_info "Checking alternative locations..."
    
    # Check if agave-install can install it
    if [[ -f "$BIN_DIR/agave-install" ]]; then
        log_info "Found agave-install, attempting to install validator..."
        "$BIN_DIR/agave-install" init "$SOLANA_VERSION" 2>/dev/null || true
    fi
    
    # Final check
    if command -v agave-validator >/dev/null 2>&1; then
        log_success "Agave validator found in PATH"
        agave-validator --version 2>/dev/null || true
    elif command -v solana-validator >/dev/null 2>&1; then
        log_warn "Only solana-validator found in PATH (not agave-validator)"
        log_info "Manual installation: https://release.anza.xyz/stable/install"
        solana-validator --version 2>/dev/null || true
    else
        log_error "Validator not found. You may need to install manually."
        log_info "Install agave-validator: https://release.anza.xyz/stable/install"
        log_info "Or build from source: https://github.com/anza-xyz/agave"
    fi
fi

log_info ""
log_info "Add to your shell profile (~/.bashrc or ~/.zshrc):"
log_info 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
