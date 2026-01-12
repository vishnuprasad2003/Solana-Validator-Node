#!/bin/bash
#
# Configure System Limits for Solana Validator
# This script helps configure file descriptor limits required by Agave validator
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

REQUIRED_LIMIT=1000000
LIMITS_FILE="/etc/security/limits.conf"
SYSCTL_FILE="/etc/sysctl.conf"

log_info "Configuring System Limits for Solana Validator"
log_info "Required file descriptor limit: $REQUIRED_LIMIT"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    log_info "Usage: sudo ./scripts/configure-limits.sh"
    exit 1
fi

# Get current user (if running via sudo)
CURRENT_USER="${SUDO_USER:-${USER}}"
if [[ -z "$CURRENT_USER" ]] || [[ "$CURRENT_USER" == "root" ]]; then
    log_error "Cannot determine non-root user"
    log_info "Please run as: sudo -u <your-username> ./scripts/configure-limits.sh"
    exit 1
fi

log_info "Configuring limits for user: $CURRENT_USER"

# Check current limits
CURRENT_SOFT=$(su - "$CURRENT_USER" -c "ulimit -Sn" 2>/dev/null || echo "0")
CURRENT_HARD=$(su - "$CURRENT_USER" -c "ulimit -Hn" 2>/dev/null || echo "0")

log_info "Current limits:"
log_info "  Soft: $CURRENT_SOFT"
log_info "  Hard: $CURRENT_HARD"

# Backup limits.conf
if [[ -f "$LIMITS_FILE" ]]; then
    cp "$LIMITS_FILE" "${LIMITS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backed up $LIMITS_FILE"
fi

# Add limits configuration
log_info "Adding limits configuration to $LIMITS_FILE"

# Remove existing entries for this user (if any)
sed -i "/^${CURRENT_USER}.*nofile/d" "$LIMITS_FILE" 2>/dev/null || true

# Add new entries
cat >> "$LIMITS_FILE" <<EOF

# Solana Validator limits (added by configure-limits.sh)
${CURRENT_USER} soft nofile ${REQUIRED_LIMIT}
${CURRENT_USER} hard nofile ${REQUIRED_LIMIT}
${CURRENT_USER} soft memlock unlimited
${CURRENT_USER} hard memlock unlimited
EOF

log_success "Added limits configuration"

# Configure system-wide file-max
log_info "Configuring system-wide file-max limit..."

# Check current system limit
CURRENT_FILE_MAX=$(sysctl -n fs.file-max 2>/dev/null || echo "0")
REQUIRED_FILE_MAX=$((REQUIRED_LIMIT * 2))  # System-wide should be higher

if [[ $CURRENT_FILE_MAX -lt $REQUIRED_FILE_MAX ]]; then
    # Set temporarily
    sysctl -w fs.file-max="$REQUIRED_FILE_MAX" >/dev/null 2>&1 || {
        log_warn "Failed to set fs.file-max temporarily"
    }
    
    # Make permanent
    if grep -q "^fs.file-max" "$SYSCTL_FILE" 2>/dev/null; then
        sed -i "s/^fs.file-max.*/fs.file-max = ${REQUIRED_FILE_MAX}/" "$SYSCTL_FILE"
    else
        echo "fs.file-max = ${REQUIRED_FILE_MAX}" >> "$SYSCTL_FILE"
    fi
    
    log_success "Configured system-wide file-max: $REQUIRED_FILE_MAX"
else
    log_info "System-wide file-max is already sufficient: $CURRENT_FILE_MAX"
fi

log_success "System limits configured successfully!"
log_info ""
log_info "IMPORTANT: You need to log out and log back in for ALL limits to take effect."
log_info ""
log_info "Configured limits:"
log_info "  - File descriptors (nofile): $REQUIRED_LIMIT"
log_info "  - Memory lock (memlock): unlimited"
log_info ""
log_info "To verify the limits after logging back in:"
log_info "  ulimit -Sn  # Should show $REQUIRED_LIMIT"
log_info "  ulimit -Hn  # Should show $REQUIRED_LIMIT"
log_info "  ulimit -Sl  # Should show 'unlimited'"
log_info "  ulimit -Hl  # Should show 'unlimited'"
log_info ""
log_info "Note: Memory lock limits require a new login session to take effect."
