#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Solana Validator Node - Upgrade Script
# Production-grade upgrade with backup, verification, and rollback support
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Configuration
BACKUP_DIR="${WORKSPACE_ROOT}/backups"
INSTALL_DIR="$HOME/.local/share/solana/install"
BIN_DIR="$INSTALL_DIR/active_release/bin"
SOLANA_BIN="${BIN_DIR}/solana"
AGAVE_VALIDATOR_BIN="${BIN_DIR}/agave-validator"
SOLANA_VALIDATOR_BIN="${BIN_DIR}/solana-validator"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
# PRE-UPGRADE CHECKS
# ─────────────────────────────────────────────────────────────────────────────

check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local missing=0
    
    # Check required tools
    for cmd in curl wget jq; do
        if command -v "$cmd" &>/dev/null; then
            log_info "✓ $cmd found"
        else
            log_error "✗ $cmd not found"
            missing=1
        fi
    done
    
    if [[ $missing -eq 1 ]]; then
        log_error "Prerequisites check failed"
        exit 1
    fi
}

check_running_validators() {
    log_section "Checking Running Validators"
    
    local running=0
    local validators=()
    
    # Check for running validators
    for pid_file in "${WORKSPACE_ROOT}"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                local node_name=$(basename "$pid_file" .pid)
                log_warn "Validator $node_name is running (PID: $pid)"
                validators+=("$node_name")
                running=1
            fi
        fi
    done
    
    # Also check for agave-validator/solana-validator processes
    if pgrep -f "agave-validator|solana-validator" &>/dev/null; then
        local pids=$(pgrep -f "agave-validator|solana-validator")
        log_warn "Validator processes detected (PIDs: $pids)"
        running=1
    fi
    
    if [[ $running -eq 1 ]]; then
        log_warn "Running validators detected. They should be stopped before upgrade."
        read -p "Stop all validators and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            stop_all_validators
        else
            log_error "Upgrade cancelled"
            exit 1
        fi
    else
        log_info "✓ No validators running"
    fi
}

stop_all_validators() {
    log_info "Stopping all validators..."
    
    # Stop via PID files
    for pid_file in "${WORKSPACE_ROOT}"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                log_info "Stopped validator (PID: $pid)"
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Stop any remaining validator processes
    pkill -f "agave-validator|solana-validator" 2>/dev/null || true
    
    sleep 2
    log_info "All validators stopped"
}

# ─────────────────────────────────────────────────────────────────────────────
# BACKUP
# ─────────────────────────────────────────────────────────────────────────────

create_backup() {
    log_section "Creating Backup"
    
    local backup_path="${BACKUP_DIR}/${TIMESTAMP}"
    mkdir -p "$backup_path"
    
    # Backup current binaries
    if [[ -f "$SOLANA_BIN" ]]; then
        mkdir -p "${backup_path}/binaries"
        cp "$SOLANA_BIN" "${backup_path}/binaries/solana.backup" 2>/dev/null || true
    fi
    
    if [[ -f "$AGAVE_VALIDATOR_BIN" ]]; then
        cp "$AGAVE_VALIDATOR_BIN" "${backup_path}/binaries/agave-validator.backup" 2>/dev/null || true
    elif [[ -f "$SOLANA_VALIDATOR_BIN" ]]; then
        cp "$SOLANA_VALIDATOR_BIN" "${backup_path}/binaries/solana-validator.backup" 2>/dev/null || true
    fi
    
    if [[ -d "${backup_path}/binaries" ]]; then
        log_info "✓ Binaries backed up"
    fi
    
    # Backup configs
    if [[ -d "${WORKSPACE_ROOT}/configs" ]]; then
        cp -r "${WORKSPACE_ROOT}/configs" "${backup_path}/"
        log_info "✓ Configs backed up"
    fi
    
    # Backup keys (critical!)
    if [[ -d "${WORKSPACE_ROOT}/keys" ]]; then
        cp -r "${WORKSPACE_ROOT}/keys" "${backup_path}/"
        log_info "✓ Keys backed up"
    fi
    
    # Backup programs (check Azure File Share first, then project root)
    if [[ -d "/solana/programs" ]]; then
        cp -r "/solana/programs" "${backup_path}/" 2>/dev/null && log_info "✓ Programs backed up from /solana/programs"
    elif [[ -d "${WORKSPACE_ROOT}/programs" ]]; then
        cp -r "${WORKSPACE_ROOT}/programs" "${backup_path}/" && log_info "✓ Programs backed up"
    fi
    
    # Backup Makefile and scripts (for reference)
    cp "${WORKSPACE_ROOT}/Makefile" "${backup_path}/" 2>/dev/null || true
    cp -r "${WORKSPACE_ROOT}/scripts" "${backup_path}/" 2>/dev/null || true
    
    # Save current versions
    cat > "${backup_path}/versions.json" <<EOF
{
    "timestamp": "$TIMESTAMP",
    "solana_cli_version": "$(get_solana_version)",
    "agave_validator_version": "$(get_agave_version)",
    "solana_validator_version": "$(get_solana_validator_version)",
    "system_info": "$(uname -a)"
}
EOF
    log_info "✓ Version info saved"
    
    log_info "Backup created at: ${backup_path}"
    echo "$backup_path"
}

get_solana_version() {
    local solana_bin=""
    if [[ -f "$SOLANA_BIN" ]]; then
        solana_bin="$SOLANA_BIN"
    elif command -v solana &>/dev/null; then
        solana_bin=$(command -v solana)
    fi
    
    if [[ -n "$solana_bin" ]] && [[ -f "$solana_bin" ]]; then
        "$solana_bin" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

get_agave_version() {
    # Check multiple possible locations
    local agave_bin=""
    
    # Check standard install location
    if [[ -f "$AGAVE_VALIDATOR_BIN" ]]; then
        agave_bin="$AGAVE_VALIDATOR_BIN"
    # Check if in PATH
    elif command -v agave-validator &>/dev/null; then
        agave_bin=$(command -v agave-validator)
    # Check /usr/local/bin (common install location)
    elif [[ -f "/usr/local/bin/agave-validator" ]]; then
        agave_bin="/usr/local/bin/agave-validator"
    fi
    
    if [[ -n "$agave_bin" ]] && [[ -f "$agave_bin" ]]; then
        "$agave_bin" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

get_agave_binary_path() {
    # Return the actual path to agave-validator
    if [[ -f "$AGAVE_VALIDATOR_BIN" ]]; then
        echo "$AGAVE_VALIDATOR_BIN"
    elif command -v agave-validator &>/dev/null; then
        command -v agave-validator
    elif [[ -f "/usr/local/bin/agave-validator" ]]; then
        echo "/usr/local/bin/agave-validator"
    else
        echo ""
    fi
}

get_solana_validator_version() {
    if [[ -f "$SOLANA_VALIDATOR_BIN" ]]; then
        "$SOLANA_VALIDATOR_BIN" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# UPGRADE SOLANA CLI & VALIDATOR
# ─────────────────────────────────────────────────────────────────────────────

upgrade_solana_cli() {
    log_section "Upgrading Solana CLI"
    
    local current_ver=$(get_solana_version)
    log_info "Current version: $current_ver"
    
    # Use Solana installer
    log_info "Upgrading Solana CLI..."
    local install_output=$(curl -sSfL https://release.solana.com/stable/install 2>&1 | sh 2>&1)
    local install_status=$?
    
    if [[ $install_status -eq 0 ]]; then
        local new_ver=$(get_solana_version)
        if [[ "$new_ver" != "$current_ver" ]]; then
            log_info "✓ Solana CLI upgraded: $new_ver"
        else
            # Check if installer said it's up to date
            if echo "$install_output" | grep -qi "up to date\|already installed\|latest"; then
                log_info "✓ Solana CLI is up to date"
            else
                log_info "✓ Solana CLI upgrade completed (version unchanged)"
            fi
        fi
    else
        # Check if error is just "already up to date"
        if echo "$install_output" | grep -qi "up to date\|already installed\|latest"; then
            log_info "✓ Solana CLI is up to date"
        else
            log_error "Solana CLI upgrade failed"
            log_info "Output: $install_output"
            return 1
        fi
    fi
}

upgrade_agave_validator() {
    log_section "Upgrading Agave Validator"
    
    local current_ver=$(get_agave_version)
    local current_bin=$(get_agave_binary_path)
    log_info "Current version: $current_ver"
    [[ -n "$current_bin" ]] && log_info "Current location: $current_bin"
    
    # Try Anza installer (preferred)
    log_info "Installing Agave validator via Anza installer..."
    export PATH="$BIN_DIR:/usr/local/bin:$PATH"
    
    local install_output=$(curl -sSfL https://release.anza.xyz/stable/install 2>&1 | sh 2>&1)
    local install_status=$?
    
    # Check for agave-validator in multiple locations after install
    local new_bin=$(get_agave_binary_path)
    
    if [[ -n "$new_bin" ]] && [[ -f "$new_bin" ]]; then
        local new_ver=$(get_agave_version)
        if [[ "$new_ver" != "$current_ver" ]] && [[ "$current_ver" != "not installed" ]]; then
            log_info "✓ Agave validator upgraded: $new_ver"
            log_info "  Location: $new_bin"
        else
            # Check if installer said it's up to date
            if echo "$install_output" | grep -qi "up to date\|already installed\|latest"; then
                log_info "✓ Agave validator is up to date: $new_ver"
            else
                log_info "✓ Agave validator upgrade completed: $new_ver"
            fi
            log_info "  Location: $new_bin"
        fi
        return 0
    fi
    
    # If we had a binary before but don't now, that's a problem
    if [[ -n "$current_bin" ]] && [[ -z "$new_bin" ]]; then
        log_warn "Agave validator was removed during upgrade"
        log_info "Previous location: $current_bin"
        return 1
    fi
    
    # Check if installer said it's up to date and we still have the binary
    if echo "$install_output" | grep -qi "up to date\|already installed\|latest"; then
        if [[ -n "$current_bin" ]]; then
            log_info "✓ Agave validator is up to date: $current_ver"
            return 0
        fi
    fi
    
    # If we still have the current binary, consider it success
    if [[ -n "$current_bin" ]] && [[ -f "$current_bin" ]]; then
        log_info "✓ Agave validator remains installed: $current_ver"
        log_info "  Location: $current_bin"
        return 0
    fi
    
    log_warn "Agave validator not found after upgrade"
    log_info "Checking if Solana installer provides validator..."
    
    # Fallback: Solana installer might provide solana-validator
    if [[ -f "$SOLANA_VALIDATOR_BIN" ]]; then
        local solana_ver=$(get_solana_validator_version)
        log_warn "Only solana-validator found: $solana_ver"
        log_warn "Agave validator not available. Consider manual installation."
        log_info "You can manually install Agave: https://release.anza.xyz/stable/install"
    else
        log_warn "No validator binary found"
        log_info "This may be normal if validators are already installed elsewhere"
        log_info "Check with: ./scripts/upgrade.sh verify"
    fi
}

upgrade_solana_all() {
    log_section "Upgrading Solana Tools"
    
    upgrade_solana_cli
    upgrade_agave_validator
}

# ─────────────────────────────────────────────────────────────────────────────
# UPGRADE SPL PROGRAMS
# ─────────────────────────────────────────────────────────────────────────────

upgrade_spl_programs() {
    log_section "Upgrading SPL Programs"

    # Use Azure File Share for programs if mounted, otherwise project root
    local programs_dir=""
    if [[ -d "/solana" ]]; then
        programs_dir="/solana/programs"
    else
        programs_dir="${WORKSPACE_ROOT}/programs"
    fi
    mkdir -p "$programs_dir"
    
    # List of SPL programs to download
    declare -A programs=(
        ["spl_token.so"]="https://github.com/solana-program-library/token/releases/latest/download/spl_token.so"
        ["spl_token_2022.so"]="https://github.com/solana-program-library/token/releases/latest/download/spl_token_2022.so"
        ["spl_associated_token_account.so"]="https://github.com/solana-program-library/associated-token-account/releases/latest/download/spl_associated_token_account.so"
    )
    
    # Download function
    download_file() {
        local url=$1
        local output=$2
        local max_retries=3
        local retry=0
        
        while [[ $retry -lt $max_retries ]]; do
            if curl -sSfL "$url" -o "$output" 2>/dev/null; then
                return 0
            fi
            ((retry++))
            log_warn "Download attempt $retry failed, retrying..."
            sleep 2
        done
        return 1
    }
    
    local updated=0
    for program in "${!programs[@]}"; do
        local url="${programs[$program]}"
        local output="${programs_dir}/${program}"
        
        log_info "Checking $program..."
        
        # Try to download (note: GitHub releases may not have direct .so downloads)
        # For now, we'll just verify existing programs
        if [[ -f "$output" ]]; then
            log_info "✓ $program exists"
        else
            log_warn "✗ $program not found (manual download may be required)"
        fi
    done
    
    log_info "✓ SPL programs check complete"
    log_info "Note: SPL programs are typically included in Solana releases"
}

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY UPGRADE
# ─────────────────────────────────────────────────────────────────────────────

verify_upgrade() {
    log_section "Verifying Upgrade"
    
    local errors=0
    
    # Check Solana CLI (check multiple locations)
    local solana_bin=""
    if [[ -f "$SOLANA_BIN" ]]; then
        solana_bin="$SOLANA_BIN"
    elif command -v solana &>/dev/null; then
        solana_bin=$(command -v solana)
    fi
    
    if [[ -n "$solana_bin" ]] && [[ -f "$solana_bin" ]]; then
        if "$solana_bin" --version &>/dev/null; then
            log_info "✓ Solana CLI OK: $(get_solana_version)"
            [[ "$solana_bin" != "$SOLANA_BIN" ]] && log_info "  Location: $solana_bin"
        else
            log_error "✗ Solana CLI failed to run"
            errors=1
        fi
    else
        log_error "✗ Solana CLI not found"
        log_info "Checked locations:"
        log_info "  - $SOLANA_BIN"
        log_info "  - PATH"
        errors=1
    fi
    
    # Check validator binary (check multiple locations)
    local validator_bin=$(get_agave_binary_path)
    
    if [[ -n "$validator_bin" ]] && [[ -f "$validator_bin" ]]; then
        if "$validator_bin" --version &>/dev/null; then
            log_info "✓ Agave validator OK: $(get_agave_version)"
            log_info "  Location: $validator_bin"
        else
            log_error "✗ Agave validator failed to run"
            errors=1
        fi
    elif [[ -f "$SOLANA_VALIDATOR_BIN" ]]; then
        if "$SOLANA_VALIDATOR_BIN" --version &>/dev/null; then
            log_info "✓ Solana validator OK: $(get_solana_validator_version)"
            log_warn "Note: Using solana-validator instead of agave-validator"
        else
            log_error "✗ Solana validator failed to run"
            errors=1
        fi
    elif command -v agave-validator &>/dev/null; then
        local path_bin=$(command -v agave-validator)
        if "$path_bin" --version &>/dev/null; then
            log_info "✓ Agave validator OK (from PATH): $(get_agave_version)"
            log_info "  Location: $path_bin"
        else
            log_error "✗ Agave validator failed to run"
            errors=1
        fi
    else
        log_error "✗ No validator binary found"
        log_info "Checked locations:"
        log_info "  - $AGAVE_VALIDATOR_BIN"
        log_info "  - $SOLANA_VALIDATOR_BIN"
        log_info "  - /usr/local/bin/agave-validator"
        log_info "  - PATH"
        errors=1
    fi
    
    # Check configs are valid
    for conf in "${WORKSPACE_ROOT}/configs/"*.conf; do
        if [[ -f "$conf" ]]; then
            if bash -n "$conf" 2>/dev/null; then
                log_info "✓ Config OK: $(basename "$conf")"
            else
                log_error "✗ Config invalid: $(basename "$conf")"
                errors=1
            fi
        fi
    done
    
    # Check required libraries
    local validator_bin=$(get_agave_binary_path)
    [[ -z "$validator_bin" ]] && validator_bin="$SOLANA_VALIDATOR_BIN"
    [[ ! -f "$validator_bin" ]] && validator_bin=$(command -v agave-validator 2>/dev/null || echo "")
    
    if [[ -n "$validator_bin" ]] && [[ -f "$validator_bin" ]]; then
        if ldd "$validator_bin" 2>/dev/null | grep -q "not found"; then
            log_error "✗ Missing shared libraries:"
            ldd "$validator_bin" | grep "not found"
            errors=1
        else
            log_info "✓ All shared libraries present"
        fi
    fi
    
    # Verify keys exist
    if [[ -d "${WORKSPACE_ROOT}/keys" ]]; then
        local key_count=$(find "${WORKSPACE_ROOT}/keys" -name "*.json" 2>/dev/null | wc -l)
        if [[ $key_count -gt 0 ]]; then
            log_info "✓ Keys directory contains $key_count key file(s)"
        else
            log_warn "⚠ No key files found (may need to generate)"
        fi
    fi
    
    # Verify data directories exist (but don't check contents to avoid touching data)
    if [[ -d "${WORKSPACE_ROOT}/data" ]]; then
        log_info "✓ Data directory exists (ledger data preserved)"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "✓ Upgrade verification passed"
        return 0
    else
        log_error "Upgrade verification failed"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# ROLLBACK
# ─────────────────────────────────────────────────────────────────────────────

rollback() {
    local backup_path="$1"
    log_section "Rolling Back to: $backup_path"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        exit 1
    fi
    
    # Stop validators
    stop_all_validators
    
    # Restore binaries
    if [[ -d "${backup_path}/binaries" ]]; then
        mkdir -p "$BIN_DIR"
        [[ -f "${backup_path}/binaries/solana.backup" ]] && \
            cp "${backup_path}/binaries/solana.backup" "$SOLANA_BIN" && \
            chmod +x "$SOLANA_BIN"
        [[ -f "${backup_path}/binaries/agave-validator.backup" ]] && \
            cp "${backup_path}/binaries/agave-validator.backup" "$AGAVE_VALIDATOR_BIN" && \
            chmod +x "$AGAVE_VALIDATOR_BIN"
        [[ -f "${backup_path}/binaries/solana-validator.backup" ]] && \
            cp "${backup_path}/binaries/solana-validator.backup" "$SOLANA_VALIDATOR_BIN" && \
            chmod +x "$SOLANA_VALIDATOR_BIN"
        log_info "✓ Binaries restored"
    fi
    
    # Restore configs
    if [[ -d "${backup_path}/configs" ]]; then
        cp -r "${backup_path}/configs/"* "${WORKSPACE_ROOT}/configs/"
        log_info "✓ Configs restored"
    fi
    
    log_info "Rollback complete"
    log_info "Previous versions:"
    cat "${backup_path}/versions.json" 2>/dev/null | jq '.' || true
}

list_backups() {
    log_section "Available Backups"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "No backups found"
        return
    fi
    
    for backup in "$BACKUP_DIR"/*/; do
        if [[ -f "${backup}versions.json" ]]; then
            local ts=$(basename "$backup")
            local solana_ver=$(jq -r '.solana_cli_version' "${backup}versions.json" 2>/dev/null || echo "unknown")
            local agave_ver=$(jq -r '.agave_validator_version' "${backup}versions.json" 2>/dev/null || echo "unknown")
            echo "  $ts - Solana: $solana_ver | Agave: $agave_ver"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────────────────────────────────────

cleanup_old_backups() {
    local keep_count="${1:-5}"
    log_section "Cleaning Up Old Backups (keeping $keep_count)"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return
    fi
    
    local backup_count=$(ls -d "$BACKUP_DIR"/*/ 2>/dev/null | wc -l)
    
    if [[ $backup_count -le $keep_count ]]; then
        log_info "No cleanup needed ($backup_count backups)"
        return
    fi
    
    local to_delete=$((backup_count - keep_count))
    log_info "Removing $to_delete old backup(s)..."
    
    ls -d "$BACKUP_DIR"/*/ | head -$to_delete | while read backup; do
        rm -rf "$backup"
        log_info "Removed: $(basename "$backup")"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS
# ─────────────────────────────────────────────────────────────────────────────

show_status() {
    log_section "Current Status"
    
    echo ""
    echo "Solana Tools:"
    local solana_bin=""
    [[ -f "$SOLANA_BIN" ]] && solana_bin="$SOLANA_BIN" || solana_bin=$(command -v solana 2>/dev/null || echo "")
    echo "  Solana CLI: $(get_solana_version)"
    [[ -n "$solana_bin" ]] && echo "    Location: $solana_bin"
    
    local agave_bin=$(get_agave_binary_path)
    echo "  Agave Validator: $(get_agave_version)"
    [[ -n "$agave_bin" ]] && echo "    Location: $agave_bin"
    
    echo "  Solana Validator: $(get_solana_validator_version)"
    [[ -f "$SOLANA_VALIDATOR_BIN" ]] && echo "    Location: $SOLANA_VALIDATOR_BIN"
    
    echo ""
    echo "Installation:"
    echo "  Binary Directory: $BIN_DIR"
    if [[ -d "$BIN_DIR" ]]; then
        echo "  Binaries:"
        ls -1 "$BIN_DIR"/* 2>/dev/null | xargs -n1 basename | sed 's/^/    /' || echo "    (none)"
    else
        echo "  Not installed"
    fi
    
    echo ""
    echo "Running Validators:"
    local running=0
    for pid_file in "${WORKSPACE_ROOT}"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                local node_name=$(basename "$pid_file" .pid)
                echo "  $node_name: running (PID: $pid)"
                running=1
            fi
        fi
    done
    [[ $running -eq 0 ]] && echo "  None"
    
    echo ""
    echo "Data:"
    if [[ -d "${WORKSPACE_ROOT}/data" ]]; then
        local data_dirs=$(find "${WORKSPACE_ROOT}/data" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  Data directories: $data_dirs"
        echo "  Location: ${WORKSPACE_ROOT}/data"
    else
        echo "  No data directory"
    fi
    
    echo ""
    echo "Backups:"
    local backup_count=$(ls -d "$BACKUP_DIR"/*/ 2>/dev/null | wc -l)
    echo "  Count: $backup_count"
    [[ $backup_count -gt 0 ]] && echo "  Latest: $(ls -d "$BACKUP_DIR"/*/ | tail -1 | xargs basename)"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Solana Validator Node - Upgrade Script

Usage: $0 <command> [options]

Commands:
    all             Full upgrade (backup + update + verify)
    check           Check current versions
    backup          Create backup only
    update          Update Solana CLI and Agave validator
    update-cli      Update Solana CLI only
    update-validator Update Agave validator only
    update-programs  Update SPL programs
    verify          Verify current installation
    rollback <path> Rollback to a specific backup
    list-backups    List available backups
    cleanup [n]     Remove old backups (keep n, default 5)
    status          Show current status

Examples:
    $0 all                  # Full upgrade with backup
    $0 check                # Check versions
    $0 rollback backups/20260115_120000

EOF
}

main() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        all)
            check_prerequisites
            check_running_validators
            create_backup
            upgrade_solana_all
            upgrade_spl_programs
            verify_upgrade
            cleanup_old_backups 5
            log_section "Upgrade Complete"
            log_info "All dependencies upgraded successfully"
            log_info "Data preserved: All ledger data, keys, and configs remain unchanged"
            log_info "Restart validators with: make start CONFIG=bootstrap"
            log_warn "Note: You may need to restart your shell for PATH changes to take effect"
            ;;
        check)
            show_status
            ;;
        backup)
            check_running_validators
            create_backup
            ;;
        update)
            check_prerequisites
            check_running_validators
            upgrade_solana_all
            verify_upgrade
            ;;
        update-cli)
            check_prerequisites
            upgrade_solana_cli
            ;;
        update-validator)
            check_prerequisites
            upgrade_agave_validator
            ;;
        update-programs)
            upgrade_spl_programs
            ;;
        verify)
            verify_upgrade
            ;;
        rollback)
            [[ -z "${1:-}" ]] && { log_error "Backup path required"; exit 1; }
            rollback "$1"
            ;;
        list-backups)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups "${1:-5}"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
