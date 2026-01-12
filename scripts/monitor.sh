#!/bin/bash
#
# Monitor Validator Status
# This script provides monitoring information for running validators
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Parse arguments
NODE_NAME="${1:-all}"
METRIC="${2:-status}"  # Options: status, health, slots, stake, all

check_validator_status() {
    local node_name=$1
    local rpc_port=$2
    
    local rpc_url="http://localhost:${rpc_port}"
    
    log_info "Checking validator: $node_name (RPC: $rpc_port)"
    
    # Health check
    if command_exists curl; then
        local health_response
        health_response=$(curl -s -X POST "$rpc_url" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' 2>/dev/null || echo "ERROR")
        
        if [[ "$health_response" == "ERROR" ]] || [[ -z "$health_response" ]]; then
            log_error "  Health: Unreachable"
            return 1
        else
            log_success "  Health: OK"
        fi
        
        # Get slot
        local slot_response
        slot_response=$(curl -s -X POST "$rpc_url" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null || echo "{}")
        
        local slot
        slot=$(echo "$slot_response" | grep -o '"result":[0-9]*' | cut -d: -f2 || echo "unknown")
        log_info "  Current Slot: $slot"
        
        # Get epoch info
        local epoch_response
        epoch_response=$(curl -s -X POST "$rpc_url" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getEpochInfo"}' 2>/dev/null || echo "{}")
        
        local epoch
        epoch=$(echo "$epoch_response" | grep -o '"epoch":[0-9]*' | cut -d: -f2 || echo "unknown")
        log_info "  Current Epoch: $epoch"
        
        # Get validator info if identity key exists
        if [[ "$node_name" == "bootstrap" ]]; then
            local identity_key="${IDENTITY_KEY_DIR}/bootstrap-identity.json"
        else
            local identity_key="${IDENTITY_KEY_DIR}/${node_name}-identity.json"
        fi
        
        if [[ -f "$identity_key" ]]; then
            local pubkey
            pubkey=$(get_pubkey "$identity_key" 2>/dev/null || echo "")
            if [[ -n "$pubkey" ]]; then
                log_info "  Identity: $pubkey"
                
                # Get vote account if vote key exists
                if [[ "$node_name" == "bootstrap" ]]; then
                    local vote_key="${VOTE_KEY_DIR}/bootstrap-vote.json"
                else
                    local vote_key="${VOTE_KEY_DIR}/${node_name}-vote.json"
                fi
                
                if [[ -f "$vote_key" ]]; then
                    local vote_pubkey
                    vote_pubkey=$(get_pubkey "$vote_key" 2>/dev/null || echo "")
                    if [[ -n "$vote_pubkey" ]]; then
                        log_info "  Vote Account: $vote_pubkey"
                    fi
                fi
            fi
        fi
    else
        log_warn "  curl not available, limited monitoring"
    fi
    
    # Check log file
    local log_file="${LOG_DIR}/${node_name}.log"
    if [[ -f "$log_file" ]]; then
        local log_size
        log_size=$(du -h "$log_file" | cut -f1)
        log_info "  Log file: $log_file ($log_size)"
        
        # Check for recent actual errors (exclude metric names containing "error")
        local error_count
        error_count=$(tail -n 100 "$log_file" | grep -iE "ERROR|panic|fatal" | grep -v "datapoint\|metrics" | wc -l 2>/dev/null || echo "0")
        # Handle case where wc returns "0\n0" or similar
        error_count=$(echo "$error_count" | head -1 | tr -d '[:space:]')
        if [[ -n "$error_count" ]] && [[ "$error_count" != "0" ]] && [[ "$error_count" =~ ^[0-9]+$ ]]; then
            if [[ $error_count -gt 0 ]]; then
                log_warn "  Recent errors in log: $error_count (last 100 lines)"
            fi
        fi
        
        # Check if validator is producing blocks
        local slot_info
        slot_info=$(tail -n 50 "$log_file" | grep -i "produced block\|skipping my leader slot" | tail -1 || echo "")
        if [[ -n "$slot_info" ]]; then
            if echo "$slot_info" | grep -q "skipping my leader slot"; then
                log_info "  Status: Waiting for vote (normal for bootstrap validator)"
            elif echo "$slot_info" | grep -q "produced block"; then
                log_success "  Status: Producing blocks"
            fi
        fi
    fi
    
    echo ""
}

# Main monitoring logic
main() {
    log_info "Validator Monitoring"
    log_info "==================="
    echo ""
    
    if [[ "$NODE_NAME" == "all" ]]; then
        # Monitor bootstrap
        if [[ -f "${WORKSPACE_ROOT}/bootstrap.pid" ]]; then
            local pid
            pid=$(cat "${WORKSPACE_ROOT}/bootstrap.pid")
            if ps -p "$pid" > /dev/null 2>&1; then
                check_validator_status "bootstrap" "${RPC_PORT:-8899}"
            fi
        fi
        
        # Monitor additional validators
        for pid_file in "${WORKSPACE_ROOT}"/validator-*.pid; do
            if [[ -f "$pid_file" ]]; then
                local node_name
                node_name=$(basename "$pid_file" .pid)
                local pid
                pid=$(cat "$pid_file")
                if ps -p "$pid" > /dev/null 2>&1; then
                    # Try to determine RPC port from config or use default
                    local node_config="${WORKSPACE_ROOT}/configs/${node_name}.conf"
                    local rpc_port="${RPC_PORT:-8899}"
                    if [[ -f "$node_config" ]]; then
                        source "$node_config"
                        rpc_port="${NODE_RPC_PORT:-${RPC_PORT:-8899}}"
                    fi
                    check_validator_status "$node_name" "$rpc_port"
                fi
            fi
        done
    else
        # Monitor specific validator
        local rpc_port="${RPC_PORT:-8899}"
        if [[ "$NODE_NAME" != "bootstrap" ]]; then
            local node_config="${WORKSPACE_ROOT}/configs/${NODE_NAME}.conf"
            if [[ -f "$node_config" ]]; then
                source "$node_config"
                rpc_port="${NODE_RPC_PORT:-${RPC_PORT:-8899}}"
            fi
        fi
        check_validator_status "$NODE_NAME" "$rpc_port"
    fi
}

main "$@"
