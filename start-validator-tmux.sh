#!/bin/bash
# Start validator in tmux session

SESSION_NAME="solana-validator"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "tmux is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Validator session already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
else
    echo "Starting validator in tmux session: $SESSION_NAME"
    # Use the script directory as working directory so config.env can be found
    tmux new-session -d -s "$SESSION_NAME" -c "$SCRIPT_DIR" "$SCRIPT_DIR/start-validator.sh"
    echo "Validator started in tmux session: $SESSION_NAME"
    echo "To attach: tmux attach -t $SESSION_NAME"
    echo "To detach: Press Ctrl+B, then D"
    echo "To view logs: tmux attach -t $SESSION_NAME"
fi
