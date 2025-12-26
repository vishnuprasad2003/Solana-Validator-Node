#!/bin/bash

# Maintenance Script for Solana Validator
# Provides monitoring, health checks, and maintenance tasks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

RPC_URL="http://127.0.0.1:8899"
LEDGER_DIR="$HOME/solana-local-ledger"

show_menu() {
    echo "=========================================="
    echo "Solana Validator Maintenance"
    echo "=========================================="
    echo ""
    echo "1. Health Check"
    echo "2. View Status"
    echo "3. Check Disk Usage"
    echo "4. View Logs"
    echo "5. Backup Ledger"
    echo "6. Restart Validator"
    echo "7. Network Status"
    echo "8. Performance Metrics"
    echo "9. Exit"
    echo ""
}

health_check() {
    echo -e "${BLUE}Health Check${NC}"
    echo "============"
    
    # Check process
    if pgrep -f solana-test-validator > /dev/null; then
        echo -e "${GREEN}✓ Validator process: Running${NC}"
    else
        echo -e "${RED}✗ Validator process: Not running${NC}"
        return 1
    fi
    
    # Check RPC
    if curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q "ok"; then
        echo -e "${GREEN}✓ RPC endpoint: Healthy${NC}"
    else
        echo -e "${RED}✗ RPC endpoint: Not responding${NC}"
        return 1
    fi
    
    # Check disk space
    DISK_USAGE=$(df -h "$LEDGER_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 80 ]; then
        echo -e "${GREEN}✓ Disk usage: ${DISK_USAGE}%${NC}"
    else
        echo -e "${YELLOW}⚠ Disk usage: ${DISK_USAGE}% (consider cleanup)${NC}"
    fi
    
    echo ""
}

view_status() {
    echo -e "${BLUE}Validator Status${NC}"
    echo "================"
    
    if pgrep -f solana-test-validator > /dev/null; then
        PID=$(pgrep -f solana-test-validator | head -1)
        echo "Process ID: $PID"
        echo "Uptime: $(ps -p $PID -o etime= | xargs)"
        echo ""
        
        # Cluster version
        VERSION=$(solana cluster-version 2>/dev/null || echo "unknown")
        echo "Cluster Version: $VERSION"
        
        # Account balance
        BALANCE=$(solana balance 2>/dev/null | awk '{print $1}' || echo "0")
        echo "Account Balance: $BALANCE SOL"
    else
        echo -e "${RED}Validator is not running${NC}"
    fi
    
    echo ""
}

check_disk() {
    echo -e "${BLUE}Disk Usage${NC}"
    echo "=========="
    df -h "$LEDGER_DIR"
    echo ""
    
    LEDGER_SIZE=$(du -sh "$LEDGER_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    echo "Ledger Size: $LEDGER_SIZE"
    echo ""
}

view_logs() {
    echo -e "${BLUE}Recent Logs${NC}"
    echo "==========="
    
    if tmux has-session -t solana-validator 2>/dev/null; then
        echo "Viewing tmux logs (last 50 lines)..."
        tmux capture-pane -t solana-validator -p | tail -50
    elif systemctl is-active --quiet solana-validator 2>/dev/null; then
        echo "Viewing systemd logs (last 50 lines)..."
        journalctl -u solana-validator -n 50 --no-pager
    else
        echo "No logs available (validator not running in tmux or systemd)"
    fi
    
    echo ""
}

backup_ledger() {
    echo -e "${BLUE}Backup Ledger${NC}"
    echo "============="
    
    BACKUP_DIR="$HOME/solana-backups"
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/ledger-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo "Creating backup..."
    echo "  Source: $LEDGER_DIR"
    echo "  Destination: $BACKUP_FILE"
    
    tar -czf "$BACKUP_FILE" -C "$HOME" solana-local-ledger 2>/dev/null
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
        echo -e "${GREEN}✓ Backup created: $BACKUP_FILE (${SIZE})${NC}"
    else
        echo -e "${RED}✗ Backup failed${NC}"
    fi
    
    echo ""
}

restart_validator() {
    echo -e "${BLUE}Restart Validator${NC}"
    echo "================"
    
    read -p "Stop and restart validator? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        ./stop-validator.sh
        sleep 2
        ./start-validator-tmux.sh
        echo -e "${GREEN}✓ Validator restarted${NC}"
    else
        echo "Restart cancelled"
    fi
    
    echo ""
}

network_status() {
    echo -e "${BLUE}Network Status${NC}"
    echo "=============="
    
    # Check ports
    echo "Port Status:"
    netstat -tlnp 2>/dev/null | grep -E ":(8899|9900|8001)" || ss -tlnp 2>/dev/null | grep -E ":(8899|9900|8001)"
    
    # Check firewall
    echo ""
    echo "Firewall Status:"
    sudo ufw status 2>/dev/null || echo "UFW not configured"
    
    echo ""
}

performance_metrics() {
    echo -e "${BLUE}Performance Metrics${NC}"
    echo "==================="
    
    if pgrep -f solana-test-validator > /dev/null; then
        PID=$(pgrep -f solana-test-validator | head -1)
        
        echo "CPU Usage:"
        ps -p $PID -o %cpu= | xargs echo "  "
        
        echo "Memory Usage:"
        ps -p $PID -o %mem=,rss= | awk '{printf "  %.1f%% (%d MB)\n", $1, $2/1024}'
        
        echo "Threads:"
        ps -p $PID -o nlwp= | xargs echo "  "
    else
        echo "Validator not running"
    fi
    
    echo ""
}

# Main menu loop
while true; do
    show_menu
    read -p "Select option (1-9): " choice
    
    case $choice in
        1) health_check ;;
        2) view_status ;;
        3) check_disk ;;
        4) view_logs ;;
        5) backup_ledger ;;
        6) restart_validator ;;
        7) network_status ;;
        8) performance_metrics ;;
        9) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; echo "" ;;
    esac
    
    read -p "Press Enter to continue..."
    clear
done

