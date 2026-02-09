#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Upgrade Solana CLI & Agave validator (with backup/rollback)
# Usage: ./scripts/upgrade.sh <all|check|backup|update|verify|rollback|status>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${WORKSPACE_ROOT}/configs/bootstrap.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

BIN_DIR="$HOME/.local/share/solana/install/active_release/bin"
BACKUP_DIR="${BASE_DIR:-/solana}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

_ver() { "$1" --version 2>/dev/null | head -1 || echo "n/a"; }

stop_all() {
    for conf in "${WORKSPACE_ROOT}/configs/"*.conf; do
        [[ -f "$conf" ]] || continue
        source "$conf"
        is_running "$PID_FILE" && graceful_stop "$PID_FILE" "$NODE_NAME" 15
    done
}

create_backup() {
    log_info "Creating backup..."
    local p="${BACKUP_DIR}/${TIMESTAMP}"; mkdir -p "$p/binaries"
    [[ -f "$BIN_DIR/solana" ]]           && cp "$BIN_DIR/solana" "$p/binaries/"
    [[ -f "$BIN_DIR/agave-validator" ]]  && cp "$BIN_DIR/agave-validator" "$p/binaries/"
    cp -r "${WORKSPACE_ROOT}/configs" "$p/" 2>/dev/null || true
    cp -r "${BASE_DIR:-/solana}/keys"   "$p/" 2>/dev/null || true
    cat > "$p/versions.json" <<EOF
{"timestamp":"$TIMESTAMP","solana":"$(_ver solana)","agave":"$(_ver agave-validator)"}
EOF
    log_success "Backup → $p"
    # Keep last 5
    local cnt; cnt=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    (( cnt > 5 )) && find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | head -$((cnt-5)) | xargs rm -rf
}

do_update() {
    log_info "Upgrading Solana CLI..."
    curl -sSfL https://release.solana.com/stable/install 2>/dev/null | sh 2>/dev/null || true
    log_info "Upgrading Agave validator..."
    export PATH="$BIN_DIR:/usr/local/bin:$PATH"
    curl -sSfL https://release.anza.xyz/stable/install 2>&1 | sh 2>&1 || true
    log_success "Solana: $(_ver solana)"
    log_success "Agave:  $(_ver agave-validator)"
}

do_verify() {
    local ok=0
    [[ -f "$BIN_DIR/solana" ]] && log_success "solana OK" || { log_error "solana missing"; ok=1; }
    command_exists agave-validator && log_success "agave-validator OK" || \
        { command_exists solana-validator && log_warn "only solana-validator" || { log_error "no validator"; ok=1; }; }
    for conf in "${WORKSPACE_ROOT}/configs/"*.conf; do
        bash -n "$conf" 2>/dev/null && log_success "Config: $(basename "$conf")" || { log_error "Invalid: $(basename "$conf")"; ok=1; }
    done
    return $ok
}

do_rollback() {
    local p="${1:?backup path required}"; [[ -d "$p" ]] || { log_error "Not found: $p"; exit 1; }
    stop_all
    [[ -f "$p/binaries/solana" ]]          && { cp "$p/binaries/solana" "$BIN_DIR/"; chmod +x "$BIN_DIR/solana"; }
    [[ -f "$p/binaries/agave-validator" ]] && { cp "$p/binaries/agave-validator" "$BIN_DIR/"; chmod +x "$BIN_DIR/agave-validator"; }
    [[ -d "$p/configs" ]] && cp -r "$p/configs/"* "${WORKSPACE_ROOT}/configs/"
    log_success "Rolled back to $(basename "$p")"
}

show_status() {
    echo ""
    echo "  Solana CLI:       $(_ver solana)"
    echo "  Agave validator:  $(_ver agave-validator)"
    echo ""
    for conf in "${WORKSPACE_ROOT}/configs/"*.conf; do
        [[ -f "$conf" ]] || continue
        source "$conf"
        is_running "$PID_FILE" && echo "  ${NODE_NAME}: running (PID $(cat "$PID_FILE"))" || echo "  ${NODE_NAME}: stopped"
    done
    echo ""
    echo "  Storage: $(du -sh "${BASE_DIR:-/solana}" 2>/dev/null | cut -f1)"
    echo "  Backups: $(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
}

CMD="${1:-help}"; shift || true
case "$CMD" in
    all)      stop_all; create_backup; do_update; do_verify; log_success "Upgrade complete" ;;
    check|status) show_status ;;
    backup)   create_backup ;;
    update)   stop_all; do_update; do_verify ;;
    verify)   do_verify ;;
    rollback) do_rollback "${1:-}" ;;
    *) echo "Usage: $0 <all|check|backup|update|verify|rollback <path>|status>"; exit 1 ;;
    esac
