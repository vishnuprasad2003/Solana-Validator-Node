#!/bin/bash
# Install Solana CLI and Agave validator
# Uses direct download method (like Dockerfile) for reliability

set -uo pipefail  # Remove -e to allow graceful error handling

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
            # Verify file was downloaded and has content
            if [[ -f "$output" ]] && [[ -s "$output" ]]; then
                return 0
            fi
        fi
        if curl -sSfL --insecure "$url" -o "$output" 2>/dev/null; then
            # Verify file was downloaded and has content
            if [[ -f "$output" ]] && [[ -s "$output" ]]; then
                return 0
            fi
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
export PATH="$BIN_DIR:/usr/local/bin:$PATH"

# Run installer and capture output
INSTALL_OUTPUT=$(curl -sSfL https://release.anza.xyz/stable/install 2>&1 | sh 2>&1) || true
INSTALL_STATUS=$?

# Check multiple possible locations for agave-validator (including common install paths)
AGAVE_FOUND=""
AGAVE_LOCATIONS=(
    "$BIN_DIR/agave-validator"
    "/usr/local/bin/agave-validator"
    "$HOME/.local/share/solana/install/active_release/bin/agave-validator"
    "$HOME/.cargo/bin/agave-validator"
)

for loc in "${AGAVE_LOCATIONS[@]}"; do
    if [[ -f "$loc" ]]; then
        AGAVE_FOUND="$loc"
        break
    fi
done

# Also check PATH
if [[ -z "$AGAVE_FOUND" ]] && command -v agave-validator >/dev/null 2>&1; then
    AGAVE_FOUND=$(command -v agave-validator)
fi

if [[ -n "$AGAVE_FOUND" ]] && [[ -f "$AGAVE_FOUND" ]]; then
    log_success "Agave validator found at: $AGAVE_FOUND"
    # Copy to expected location if not already there
    if [[ "$AGAVE_FOUND" != "$BIN_DIR/agave-validator" ]]; then
        mkdir -p "$BIN_DIR" || true
        cp "$AGAVE_FOUND" "$BIN_DIR/agave-validator" 2>/dev/null || true
    fi
    "$AGAVE_FOUND" --version 2>/dev/null || true
elif echo "$INSTALL_OUTPUT" | grep -qi "up to date\|already installed\|latest"; then
    log_warn "Anza installer says up to date, but agave-validator not found"
    log_info "Searched locations: ${AGAVE_LOCATIONS[*]}"
    log_info "Installer output: $(echo "$INSTALL_OUTPUT" | tail -3)"
else
    log_warn "Anza installer had issues, trying direct download..."
    log_info "Installer output: $(echo "$INSTALL_OUTPUT" | tail -3)"
fi

# Method 3: Direct download of Agave release from Anza (if installer didn't work)
if [[ ! -f "$BIN_DIR/agave-validator" ]] && [[ -z "${AGAVE_FOUND:-}" ]]; then
    log_info "Attempting direct download of Agave validator..."
    TEMP_DIR=$(mktemp -d)
    TARBALL="$TEMP_DIR/agave-release.tar.bz2"
    
    # Try to get latest stable version from Anza releases
    # Anza uses different versioning, try latest release tag
    AGAVE_VERSIONS=("v1.18.26" "v1.18" "latest")
    AGAVE_DOWNLOADED=0
    
    for AGAVE_VERSION in "${AGAVE_VERSIONS[@]}"; do
        AGAVE_RELEASE_URL="https://github.com/anza-xyz/agave/releases/download/${AGAVE_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2"
        log_info "Trying Agave version: $AGAVE_VERSION"
        
        if download_file "$AGAVE_RELEASE_URL" "$TARBALL"; then
            # Verify tarball is valid
            if [[ ! -f "$TARBALL" ]] || [[ ! -s "$TARBALL" ]]; then
                log_warn "Downloaded file is empty or missing for $AGAVE_VERSION"
                rm -f "$TARBALL" 2>/dev/null || true
                continue
            fi
            
            log_info "Extracting Agave release..."
            mkdir -p "$INSTALL_DIR/active_release" || true
            
            # Try extraction with different methods (don't fail script on error)
            EXTRACT_SUCCESS=0
            
            # Method 1: Try with strip-components
            if tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" --strip-components=1 2>/dev/null; then
                EXTRACT_SUCCESS=1
            # Method 2: Try without strip-components
            elif tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" 2>/dev/null; then
                # Handle nested directory structure
                if [[ -d "$INSTALL_DIR/active_release/solana-release" ]]; then
                    mv "$INSTALL_DIR/active_release/solana-release/bin" "$INSTALL_DIR/active_release/" 2>/dev/null || true
                    mv "$INSTALL_DIR/active_release/solana-release"/* "$INSTALL_DIR/active_release/" 2>/dev/null || true
                    rmdir "$INSTALL_DIR/active_release/solana-release" 2>/dev/null || true
                fi
                EXTRACT_SUCCESS=1
            else
                log_warn "Extraction failed for $AGAVE_VERSION (tar returned error)"
            fi
            
            if [[ $EXTRACT_SUCCESS -eq 1 ]]; then
                # Check if agave-validator was extracted
                if [[ -f "$INSTALL_DIR/active_release/bin/agave-validator" ]]; then
                    log_success "Agave validator extracted successfully"
                    AGAVE_DOWNLOADED=1
                    rm -f "$TARBALL" 2>/dev/null || true
                    break
                else
                    # Search for agave-validator in extracted directory
                    FOUND_AGAVE=$(find "$INSTALL_DIR/active_release" -name "agave-validator" -type f 2>/dev/null | head -1)
                    if [[ -n "$FOUND_AGAVE" ]] && [[ -f "$FOUND_AGAVE" ]]; then
                        mkdir -p "$INSTALL_DIR/active_release/bin" || true
                        if cp "$FOUND_AGAVE" "$INSTALL_DIR/active_release/bin/agave-validator" 2>/dev/null; then
                            log_success "Agave validator found and copied to bin/"
                            AGAVE_DOWNLOADED=1
                            rm -f "$TARBALL" 2>/dev/null || true
                            break
                        fi
                    fi
                fi
            else
                log_warn "Extraction failed for version $AGAVE_VERSION, trying next..."
            fi
            
            rm -f "$TARBALL" 2>/dev/null || true
            # Continue to next version if this one didn't work
        else
            log_warn "Download failed for version $AGAVE_VERSION, trying next..."
        fi
    done
    
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    
    if [[ $AGAVE_DOWNLOADED -eq 0 ]]; then
        log_warn "Direct Agave download failed, will try Solana release as fallback..."
    fi
fi

# Method 4: Fallback - Direct download of Solana Labs release (includes solana-validator, not agave)
# Only if agave-validator still not found
if [[ ! -f "$BIN_DIR/agave-validator" ]] && [[ -z "${AGAVE_FOUND:-}" ]]; then
    log_info "Installing Solana release (includes validator) as fallback..."
    TEMP_DIR=$(mktemp -d)
    TARBALL="$TEMP_DIR/solana-release.tar.bz2"
    RELEASE_URL="https://github.com/solana-labs/solana/releases/download/${SOLANA_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2"

    log_info "Downloading Solana ${SOLANA_VERSION}..."
    if download_file "$RELEASE_URL" "$TARBALL"; then
        # Verify tarball is valid
        if [[ ! -f "$TARBALL" ]] || [[ ! -s "$TARBALL" ]]; then
            log_warn "Downloaded file is empty or missing"
            rm -f "$TARBALL" 2>/dev/null || true
            rm -rf "$TEMP_DIR" 2>/dev/null || true
        else
            log_info "Extracting Solana release..."
            mkdir -p "$INSTALL_DIR/active_release" || true
            
            # Try extraction (don't fail script on error)
            EXTRACT_OK=0
            if tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" --strip-components=1 2>/dev/null; then
                EXTRACT_OK=1
                log_success "Solana release extracted"
            elif tar -xjf "$TARBALL" -C "$INSTALL_DIR/active_release" 2>/dev/null; then
                # Move bin directory if needed
                if [[ -d "$INSTALL_DIR/active_release/solana-release" ]]; then
                    mv "$INSTALL_DIR/active_release/solana-release/bin" "$INSTALL_DIR/active_release/" 2>/dev/null || true
                    mv "$INSTALL_DIR/active_release/solana-release"/* "$INSTALL_DIR/active_release/" 2>/dev/null || true
                    rmdir "$INSTALL_DIR/active_release/solana-release" 2>/dev/null || true
                fi
                EXTRACT_OK=1
                log_success "Solana release extracted (alternative method)"
            else
                log_warn "Extraction failed (tar returned error)"
            fi
            
            rm -f "$TARBALL" 2>/dev/null || true
            rmdir "$TEMP_DIR" 2>/dev/null || true
        fi
    else
        log_warn "Direct download failed, checking if installer worked..."
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
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
    
    # Final check - look in multiple locations
    AGAVE_FINAL=""
    if [[ -f "$BIN_DIR/agave-validator" ]]; then
        AGAVE_FINAL="$BIN_DIR/agave-validator"
    elif [[ -f "/usr/local/bin/agave-validator" ]]; then
        AGAVE_FINAL="/usr/local/bin/agave-validator"
        # Copy to expected location
        mkdir -p "$BIN_DIR"
        cp "$AGAVE_FINAL" "$BIN_DIR/agave-validator" 2>/dev/null || true
    elif command -v agave-validator >/dev/null 2>&1; then
        AGAVE_FINAL=$(command -v agave-validator)
        # Copy to expected location
        mkdir -p "$BIN_DIR"
        cp "$AGAVE_FINAL" "$BIN_DIR/agave-validator" 2>/dev/null || true
    fi
    
    if [[ -n "$AGAVE_FINAL" ]] && [[ -f "$AGAVE_FINAL" ]]; then
        log_success "Agave validator found at: $AGAVE_FINAL"
        "$AGAVE_FINAL" --version 2>/dev/null || true
    elif command -v solana-validator >/dev/null 2>&1; then
        log_warn "Only solana-validator found in PATH (not agave-validator)"
        log_info "Manual installation: https://release.anza.xyz/stable/install"
        solana-validator --version 2>/dev/null || true
    else
        log_error "Validator not found. You may need to install manually."
        log_info "Try manual installation:"
        log_info "  curl -sSfL https://release.anza.xyz/stable/install | sh"
        log_info "  export PATH=\"\$HOME/.local/share/solana/install/active_release/bin:\$PATH\""
        log_info "Or check: https://github.com/anza-xyz/agave/releases"
    fi
fi

# Final summary
log_info ""
INSTALL_SUCCESS=0
if [[ -f "$BIN_DIR/agave-validator" ]] || command -v agave-validator >/dev/null 2>&1; then
    log_success "Installation complete! Agave validator is ready."
    INSTALL_SUCCESS=1
elif [[ -f "$BIN_DIR/solana-validator" ]] || command -v solana-validator >/dev/null 2>&1; then
    log_warn "Installation complete, but only solana-validator found (not agave-validator)"
    log_info "To install agave-validator manually, run:"
    log_info "  curl -sSfL https://release.anza.xyz/stable/install | sh"
    INSTALL_SUCCESS=1
else
    log_error "Installation incomplete - validator not found"
    log_info "Please install manually:"
    log_info "  curl -sSfL https://release.anza.xyz/stable/install | sh"
    log_info "  export PATH=\"\$HOME/.local/share/solana/install/active_release/bin:\$PATH\""
    INSTALL_SUCCESS=0
fi

log_info ""
log_info "Add to your shell profile (~/.bashrc or ~/.zshrc):"
log_info 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'

# Exit with appropriate code (don't fail make if solana-validator is available)
exit $((1 - INSTALL_SUCCESS))
