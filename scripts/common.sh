#!/bin/bash
#
# Common functions and utilities for Solana validator scripts
#

set -euo pipefail

# Get the script directory and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Support both local and containerized environments
if [[ -d "/app" ]] && [[ -f "/app/scripts/common.sh" ]]; then
    WORKSPACE_ROOT="/app"
else
    WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

# Source cluster configuration
if [[ -f "${WORKSPACE_ROOT}/configs/cluster.conf" ]]; then
    # Source with error handling for unset variables
    set +u
    source "${WORKSPACE_ROOT}/configs/cluster.conf"
    set -u
else
    echo "ERROR: cluster.conf not found at ${WORKSPACE_ROOT}/configs/cluster.conf"
    exit 1
fi

# Set WORKSPACE_ROOT if not already set from config
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is available
port_available() {
    local port=$1
    ! (ss -tuln | grep -q ":${port} ")
}

# Check file descriptor limits
check_file_descriptor_limits() {
    local required_limit=${1:-1000000}
    local current_soft
    local current_hard
    
    current_soft=$(ulimit -Sn 2>/dev/null || echo "0")
    current_hard=$(ulimit -Hn 2>/dev/null || echo "0")
    
    if [[ -z "$current_soft" ]] || [[ "$current_soft" == "unlimited" ]]; then
        current_soft=999999999
    fi
    if [[ -z "$current_hard" ]] || [[ "$current_hard" == "unlimited" ]]; then
        current_hard=999999999
    fi
    
    # Check if we can set limits via prlimit or systemd-run (even if session limits are low)
    if command_exists prlimit || command_exists systemd-run; then
        if [[ $current_hard -lt $required_limit ]]; then
            log_warn "File descriptor limit is low, but will use prlimit/systemd-run to set process limits"
            log_info "  Current soft limit: $current_soft"
            log_info "  Current hard limit: $current_hard"
            log_info "  Required: $required_limit"
            log_info "  Will set limit for validator process using prlimit/systemd-run"
            return 0  # Allow starting since we can set limits for the process
        elif [[ $current_soft -lt $required_limit ]]; then
            log_info "File descriptor soft limit is low, will use prlimit/systemd-run to set process limits"
            return 0  # Allow starting since we can set limits for the process
        fi
        return 0
    fi
    
    # No prlimit/systemd-run available, check session limits
    if [[ $current_hard -lt $required_limit ]]; then
        log_warn "File descriptor limit is too low"
        log_info "  Current soft limit: $current_soft"
        log_info "  Current hard limit: $current_hard"
        log_info "  Required: $required_limit"
        log_info ""
        log_info "To fix this, run:"
        log_info "  sudo ./scripts/configure-limits.sh"
        log_info "  Then log out and log back in"
        log_info "  Or install 'util-linux' package for prlimit support"
        return 1
    elif [[ $current_soft -lt $required_limit ]]; then
        log_warn "File descriptor soft limit is too low"
        log_info "  Current soft limit: $current_soft"
        log_info "  Current hard limit: $current_hard"
        log_info "  Required: $required_limit"
        log_info ""
        log_info "The hard limit is sufficient, but soft limit needs to be increased."
        log_info "Run: ulimit -n $required_limit"
        log_info "Or configure permanently: sudo ./scripts/configure-limits.sh"
        return 1
    fi
    
    return 0
}

# Check if directory exists and is writable
check_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
    if [[ ! -w "$dir" ]]; then
        log_error "Directory is not writable: $dir"
        return 1
    fi
    return 0
}

# Generate keypair if it doesn't exist
generate_keypair() {
    local key_path=$1
    local key_type=${2:-"identity"}
    
    if [[ -f "$key_path" ]]; then
        log_warn "Keypair already exists: $key_path"
        return 0
    fi
    
    log_info "Generating ${key_type} keypair: $key_path"
    
    # Ensure parent directory exists
    mkdir -p "$(dirname "$key_path")"
    
    # Generate keypair using solana-keygen
    if ! command_exists solana-keygen; then
        log_error "solana-keygen not found. Please install Solana CLI tools."
        return 1
    fi
    
    solana-keygen new --no-bip39-passphrase --outfile "$key_path" --force >/dev/null 2>&1 || {
        log_error "Failed to generate keypair: $key_path"
        return 1
    }
    
    log_success "Generated keypair: $key_path"
    return 0
}

# Get public key from keypair file
get_pubkey() {
    local key_path=$1
    if [[ ! -f "$key_path" ]]; then
        log_error "Keypair file not found: $key_path"
        return 1
    fi
    
    # Change to the key file's directory to avoid issues with paths containing spaces
    local key_dir
    local key_file
    key_dir=$(dirname "$key_path")
    key_file=$(basename "$key_path")
    
    # Use absolute path resolution to handle spaces
    (cd "$key_dir" && solana-keygen pubkey "$key_file" 2>/dev/null) || {
        log_error "Failed to extract public key from: $key_path"
        return 1
    }
}

# Validate keypair file
validate_keypair() {
    local key_path=$1
    if [[ ! -f "$key_path" ]]; then
        log_error "Keypair file not found: $key_path"
        return 1
    fi
    
    # Try to extract public key as validation
    if ! get_pubkey "$key_path" >/dev/null 2>&1; then
        log_error "Invalid keypair file: $key_path"
        return 1
    fi
    
    return 0
}

# Setup log rotation
setup_log_rotation() {
    local log_file=$1
    local max_size_mb=${LOG_FILE_MAX_SIZE_MB:-100}
    local max_count=${LOG_FILE_MAX_COUNT:-10}
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$log_file")"
    
    # Create logrotate config if it doesn't exist
    local logrotate_config="${WORKSPACE_ROOT}/configs/logrotate.conf"
    if [[ ! -f "$logrotate_config" ]]; then
        cat > "$logrotate_config" <<EOF
${log_file} {
    daily
    rotate ${max_count}
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $(whoami) $(whoami)
    maxsize ${max_size_mb}M
    copytruncate
}
EOF
        log_info "Created logrotate configuration: $logrotate_config"
    fi
}

# Check if Agave validator is installed
check_agave_installed() {
    # Check for agave-validator first (new name)
    if command_exists agave-validator; then
        local version
        version=$(agave-validator --version 2>/dev/null | head -n1 || echo "unknown")
        log_info "Found Agave validator: $version"
        return 0
    fi
    
    # Check for solana-validator (legacy/backward compatibility)
    if command_exists solana-validator; then
        local version
        version=$(solana-validator --version 2>/dev/null | head -n1 || echo "unknown")
        log_info "Found Solana validator (legacy): $version"
        return 0
    fi
    
    # Check in install directory for agave-validator
    if [[ -f "${AGAVE_INSTALL_DIR}/agave-validator" ]]; then
        log_info "Found Agave validator in ${AGAVE_INSTALL_DIR}"
        return 0
    fi
    
    # Check in install directory for solana-validator
    if [[ -f "${AGAVE_INSTALL_DIR}/solana-validator" ]]; then
        log_info "Found Solana validator in ${AGAVE_INSTALL_DIR}"
        return 0
    fi
    
    # Check default Solana installation location
    local solana_bin_dir="$HOME/.local/share/solana/install/active_release/bin"
    if [[ -f "${solana_bin_dir}/agave-validator" ]]; then
        log_info "Found Agave validator in ${solana_bin_dir}"
        return 0
    fi
    
    if [[ -f "${solana_bin_dir}/solana-validator" ]]; then
        log_info "Found Solana validator in ${solana_bin_dir}"
        return 0
    fi
    
    return 1
}

# Get Agave validator binary path
get_agave_binary() {
    # Try agave-validator first (preferred)
    if command_exists agave-validator; then
        echo "agave-validator"
        return 0
    fi
    
    # Try solana-validator (legacy)
    if command_exists solana-validator; then
        echo "solana-validator"
        return 0
    fi
    
    # Check install directory
    if [[ -f "${AGAVE_INSTALL_DIR}/agave-validator" ]]; then
        echo "${AGAVE_INSTALL_DIR}/agave-validator"
        return 0
    fi
    
    if [[ -f "${AGAVE_INSTALL_DIR}/solana-validator" ]]; then
        echo "${AGAVE_INSTALL_DIR}/solana-validator"
        return 0
    fi
    
    # Check default Solana installation location
    local solana_bin_dir="$HOME/.local/share/solana/install/active_release/bin"
    if [[ -f "${solana_bin_dir}/agave-validator" ]]; then
        echo "${solana_bin_dir}/agave-validator"
        return 0
    fi
    
    if [[ -f "${solana_bin_dir}/solana-validator" ]]; then
        echo "${solana_bin_dir}/solana-validator"
        return 0
    fi
    
    log_error "Agave validator binary not found"
    log_info "Please install it using: ./scripts/install.sh"
    log_info "Or build from source: INSTALL_METHOD=cargo ./scripts/install.sh"
    return 1
}

# Wait for validator to be ready
wait_for_validator() {
    local rpc_url=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    log_info "Waiting for validator to be ready at $rpc_url..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s -X POST "$rpc_url" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
            >/dev/null 2>&1; then
            log_success "Validator is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "Validator failed to become ready after $max_attempts attempts"
    return 1
}

# Export environment variables for validator
export_validator_env() {
    export RUST_LOG="${LOG_LEVEL:-info}"
    export RUST_BACKTRACE=1
}

# Cleanup function for traps
cleanup() {
    log_info "Cleaning up..."
    # Add any cleanup logic here
}

trap cleanup EXIT INT TERM
