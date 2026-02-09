#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Install Solana CLI & Agave validator
# Usage: ./scripts/install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
source "$(dirname "$0")/common.sh"

BIN_DIR="$HOME/.local/share/solana/install/active_release/bin"

# Already installed?
if [[ -f "$BIN_DIR/solana" ]] && [[ -f "$BIN_DIR/agave-validator" ]]; then
    log_info "Already installed"
    export PATH="$BIN_DIR:$PATH"
    solana --version 2>/dev/null || true
    agave-validator --version 2>/dev/null || true
    exit 0
fi

# ── Solana CLI ──────────────────────────────────────────────────────────────
log_info "Installing Solana CLI..."
curl -sSfL https://release.solana.com/stable/install 2>/dev/null | sh 2>/dev/null || \
    log_warn "Solana installer had issues"

# ── Agave validator ─────────────────────────────────────────────────────────
log_info "Installing Agave validator..."
export PATH="$BIN_DIR:/usr/local/bin:$PATH"
curl -sSfL https://release.anza.xyz/stable/install 2>&1 | sh 2>&1 || true

# Check all known locations
for loc in "$BIN_DIR/agave-validator" "/usr/local/bin/agave-validator"; do
    if [[ -f "$loc" ]]; then
        [[ "$loc" != "$BIN_DIR/agave-validator" ]] && {
            mkdir -p "$BIN_DIR"; cp "$loc" "$BIN_DIR/agave-validator" 2>/dev/null || true
        }
        break
    fi
done

# ── Verify ──────────────────────────────────────────────────────────────────
export PATH="$BIN_DIR:$PATH"
OK=0
[[ -f "$BIN_DIR/solana" ]] && { log_success "Solana CLI: $(solana --version 2>/dev/null)"; OK=1; } || log_error "Solana CLI not found"
if [[ -f "$BIN_DIR/agave-validator" ]]; then
    log_success "Agave validator: $(agave-validator --version 2>/dev/null)"
elif [[ -f "$BIN_DIR/solana-validator" ]]; then
    log_warn "Only solana-validator found (not agave-validator)"
    OK=1
else
    log_error "Validator binary not found"
fi

echo ""
log_info "Add to ~/.bashrc:"
log_info '  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
exit $((1 - OK))
