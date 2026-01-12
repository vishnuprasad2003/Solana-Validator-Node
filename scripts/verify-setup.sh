#!/bin/bash
#
# Verify Setup
# This script verifies that the setup is correctly configured
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

ERRORS=0
WARNINGS=0

log_info "Verifying Solana Validator Node Setup"
log_info "======================================"
echo ""

# Check directory structure
log_info "Checking directory structure..."
for dir in configs scripts keys/identity keys/vote keys/stake data logs bin; do
    if [[ -d "${WORKSPACE_ROOT}/${dir}" ]]; then
        log_success "  ✓ $dir exists"
    else
        log_error "  ✗ $dir missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check configuration files
log_info ""
log_info "Checking configuration files..."
if [[ -f "${WORKSPACE_ROOT}/configs/cluster.conf" ]]; then
    log_success "  ✓ cluster.conf exists"
    # Source and check for required variables
    source "${WORKSPACE_ROOT}/configs/cluster.conf"
    if [[ -z "${WORKSPACE_ROOT:-}" ]]; then
        log_warn "  ⚠ WORKSPACE_ROOT not set in cluster.conf"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_error "  ✗ cluster.conf missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "${WORKSPACE_ROOT}/configs/node.conf.template" ]]; then
    log_success "  ✓ node.conf.template exists"
else
    log_warn "  ⚠ node.conf.template missing"
    WARNINGS=$((WARNINGS + 1))
fi

# Check scripts
log_info ""
log_info "Checking scripts..."
REQUIRED_SCRIPTS=(
    "common.sh"
    "install.sh"
    "init-genesis.sh"
    "start-bootstrap.sh"
    "start-validator.sh"
    "stop-validator.sh"
    "list-validators.sh"
    "gen-keys.sh"
    "monitor.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    script_path="${WORKSPACE_ROOT}/scripts/${script}"
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            log_success "  ✓ $script (executable)"
        else
            log_warn "  ⚠ $script (not executable)"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        log_error "  ✗ $script missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for Agave validator
log_info ""
log_info "Checking Agave validator installation..."
    if check_agave_installed; then
        AGAVE_BINARY=$(get_agave_binary)
        if command_exists solana-keygen && command_exists solana-genesis; then
            log_success "  ✓ Agave validator and CLI tools installed"
            version=$($AGAVE_BINARY --version 2>/dev/null | head -n1 || echo "unknown")
            log_info "    Version: $version"
    else
        log_warn "  ⚠ Agave validator found but CLI tools missing"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_warn "  ⚠ Agave validator not installed"
    log_info "    Run: ./scripts/install.sh"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for genesis
log_info ""
log_info "Checking genesis configuration..."
if [[ -f "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" ]]; then
    log_success "  ✓ Genesis exists"
    genesis_size=$(du -h "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" | cut -f1)
    log_info "    Size: $genesis_size"
else
    log_warn "  ⚠ Genesis not initialized"
    log_info "    Run: ./scripts/init-genesis.sh"
    WARNINGS=$((WARNINGS + 1))
fi

# Check bootstrap keys
log_info ""
log_info "Checking bootstrap validator keys..."
BOOTSTRAP_KEYS=(
    "${IDENTITY_KEY_DIR}/bootstrap-identity.json"
    "${VOTE_KEY_DIR}/bootstrap-vote.json"
    "${STAKE_KEY_DIR}/bootstrap-stake.json"
    "${IDENTITY_KEY_DIR}/faucet.json"
)

for key in "${BOOTSTRAP_KEYS[@]}"; do
    if [[ -f "$key" ]]; then
        if validate_keypair "$key" 2>/dev/null; then
            log_success "  ✓ $(basename $key)"
        else
            log_error "  ✗ $(basename $key) (invalid)"
            ERRORS=$((ERRORS + 1))
        fi
    else
        log_warn "  ⚠ $(basename $key) missing"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Check port availability
log_info ""
log_info "Checking port availability..."
PORTS=(
    "${GOSSIP_PORT:-8001}"
    "${RPC_PORT:-8899}"
    "${RPC_WEBSOCKET_PORT:-8900}"
    "${TPU_PORT:-8003}"
    "${METRICS_PORT:-9090}"
)

for port in "${PORTS[@]}"; do
    if port_available "$port"; then
        log_success "  ✓ Port $port available"
    else
        log_warn "  ⚠ Port $port in use"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Check disk space
log_info ""
log_info "Checking disk space..."
if command_exists df; then
    available_space=$(df -h "${WORKSPACE_ROOT}" | tail -1 | awk '{print $4}')
    log_info "  Available space: $available_space"
    
    # Check if less than 10GB
    available_bytes=$(df "${WORKSPACE_ROOT}" | tail -1 | awk '{print $4}')
    if [[ $available_bytes -lt 10485760 ]]; then  # 10GB in KB
        log_warn "  ⚠ Low disk space (< 10GB)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Summary
log_info ""
log_info "Verification Summary"
log_info "==================="
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    log_success "✓ Setup is ready!"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    log_warn "⚠ Setup has $WARNINGS warning(s) but should work"
    exit 0
else
    log_error "✗ Setup has $ERRORS error(s) and $WARNINGS warning(s)"
    log_info "Please fix the errors before proceeding"
    exit 1
fi
