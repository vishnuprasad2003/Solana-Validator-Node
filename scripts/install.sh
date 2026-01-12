#!/bin/bash
#
# Install/Upgrade Agave Validator and Solana CLI Tools
# This script installs the latest stable version of Agave validator
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Installation options
INSTALL_METHOD="${INSTALL_METHOD:-sh}"  # Options: sh (install.sh), cargo
AGAVE_VERSION="${AGAVE_VERSION:-latest}"
INSTALL_DIR="${AGAVE_INSTALL_DIR:-${WORKSPACE_ROOT}/bin}"

log_info "Installing Agave Validator and Solana CLI Tools"
log_info "Install method: $INSTALL_METHOD"
log_info "Version: $AGAVE_VERSION"
log_info "Install directory: $INSTALL_DIR"

# Create install directory
check_directory "$INSTALL_DIR"

install_via_sh() {
    log_info "Installing via official Solana install script..."
    
    # Download and run the official Solana install script
    if ! command_exists sh; then
        log_error "sh command not found"
        return 1
    fi
    
    # Use the official Solana install script
    sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)" || {
        log_error "Failed to install Solana via install script"
        return 1
    }
    
    # Add to PATH for current session
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    
    log_success "Solana CLI tools installed successfully"
    
    # Verify installation - check for both agave-validator and solana-validator
    local validator_found=false
    local validator_path=""
    local validator_name=""
    
    # Check for agave-validator (preferred)
    if command_exists agave-validator; then
        validator_found=true
        validator_path="agave-validator"
        validator_name="agave-validator"
        local version
        version=$(agave-validator --version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Agave validator installed: $version"
    # Check for solana-validator (legacy)
    elif command_exists solana-validator; then
        validator_found=true
        validator_path="solana-validator"
        validator_name="solana-validator"
        local version
        version=$(solana-validator --version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Solana validator (legacy) installed: $version"
    # Check default installation location
    else
        local solana_bin_dir="$HOME/.local/share/solana/install/active_release/bin"
        
        if [[ -f "${solana_bin_dir}/agave-validator" ]]; then
            validator_found=true
            validator_path="${solana_bin_dir}/agave-validator"
            validator_name="agave-validator"
            log_info "Found Agave validator at: ${validator_path}"
            # Create symlink in install directory
            mkdir -p "$INSTALL_DIR"
            ln -sf "${validator_path}" "${INSTALL_DIR}/agave-validator"
            log_success "Created symlink in ${INSTALL_DIR}"
        elif [[ -f "${solana_bin_dir}/solana-validator" ]]; then
            validator_found=true
            validator_path="${solana_bin_dir}/solana-validator"
            validator_name="solana-validator"
            log_info "Found Solana validator at: ${validator_path}"
            # Create symlink in install directory
            mkdir -p "$INSTALL_DIR"
            ln -sf "${validator_path}" "${INSTALL_DIR}/solana-validator"
            log_success "Created symlink in ${INSTALL_DIR}"
        else
            log_warn "Validator binary not found in standard locations"
            log_info "The Solana installer may not include the production validator binary"
            log_info "For production use, you may need to build from source:"
            log_info "  INSTALL_METHOD=cargo ./scripts/install.sh"
        fi
    fi
    
    # Verify other tools
    for tool in solana solana-keygen solana-genesis; do
        if command_exists "$tool"; then
            log_success "Installed: $tool"
        else
            log_warn "Tool not found in PATH: $tool"
        fi
    done
}

install_via_cargo() {
    log_info "Installing via Cargo (Rust)..."
    
    if ! command_exists cargo; then
        log_error "Cargo not found. Please install Rust first: https://rustup.rs/"
        return 1
    fi
    
    log_info "Building Agave from source (this may take a while)..."
    
    # Clone Agave repository if needed
    local agave_repo_dir="${WORKSPACE_ROOT}/.agave-src"
    if [[ ! -d "$agave_repo_dir" ]]; then
        log_info "Cloning Agave repository..."
        git clone https://github.com/anza-xyz/agave.git "$agave_repo_dir" || {
            log_error "Failed to clone Agave repository"
            return 1
        }
    else
        log_info "Updating Agave repository..."
        cd "$agave_repo_dir"
        git pull || log_warn "Failed to update repository"
    fi
    
    cd "$agave_repo_dir"
    
    # Build validator (Agave uses agave-validator as the binary name)
    log_info "Building agave-validator..."
    
    # Try building agave-validator first (new name)
    if cargo build --release --bin agave-validator 2>/dev/null; then
        # Copy binary to install directory
        mkdir -p "$INSTALL_DIR"
        cp target/release/agave-validator "${INSTALL_DIR}/" || {
            log_error "Failed to copy validator binary"
            return 1
        }
        log_success "Agave validator built and installed to ${INSTALL_DIR}"
    # Fallback to solana-validator (legacy)
    elif cargo build --release --bin solana-validator 2>/dev/null; then
        # Copy binary to install directory
        mkdir -p "$INSTALL_DIR"
        cp target/release/solana-validator "${INSTALL_DIR}/" || {
            log_error "Failed to copy validator binary"
            return 1
        }
        log_success "Solana validator (legacy) built and installed to ${INSTALL_DIR}"
    else
        log_error "Failed to build validator binary"
        log_info "Tried both 'agave-validator' and 'solana-validator' binary names"
        return 1
    fi
}

# Main installation logic
main() {
    case "$INSTALL_METHOD" in
        sh)
            install_via_sh
            ;;
        cargo)
            install_via_cargo
            ;;
        *)
            log_error "Unknown install method: $INSTALL_METHOD"
            log_info "Supported methods: sh, cargo"
            exit 1
            ;;
    esac
    
    # Verify installation
    if check_agave_installed; then
        log_success "Installation completed successfully!"
        log_info "Validator binary location:"
        get_agave_binary
        log_info ""
        log_info "Note: If the validator binary is not in your PATH,"
        log_info "the scripts will automatically use the full path."
    else
        log_warn "Installation completed but production validator binary not found"
        log_info ""
        log_info "The standard Solana installer includes CLI tools but may not include"
        log_info "the production validator binary (agave-validator)."
        log_info ""
        log_info "To install the production validator, you have two options:"
        log_info ""
        log_info "1. Build from source (recommended for production):"
        log_info "   INSTALL_METHOD=cargo ./scripts/install.sh"
        log_info ""
        log_info "2. For local testing, you can use solana-test-validator, but"
        log_info "   it's not suitable for production multi-node clusters."
        log_info ""
        log_info "The scripts will work once you build the validator from source."
        exit 1
    fi
}

main "$@"
