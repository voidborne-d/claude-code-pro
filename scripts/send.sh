#!/usr/bin/env bash
# Send input to a Claude Code tmux session
# Usage: send.sh --session <name> --text <message>
#        send.sh --session <name> --approve
#        send.sh --session <name> --reject
#        send.sh --session <name> --compact
#        send.sh --session <name> --cancel-ralph

set -euo pipefail

SESSION=""
TEXT=""
ACTION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --session) SESSION="$2"; shift 2;;
    --text) TEXT="$2"; shift 2;;
    --approve) ACTION="approve"; shift;;
    --reject) ACTION="reject"; shift;;
    --compact) ACTION="compact"; shift;;
    --cancel-ralph) ACTION="cancel-ralph"; shift;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$SESSION" ]]; then
  echo "Usage: send.sh --session <name> --text <message> | --approve | --reject | --compact | --cancel-ralph"
  exit 1
fi

[[ "$SESSION" != cc-* ]] && SESSION="cc-${SESSION}"

case "$ACTION" in
  approve)
    # In plan mode, type 'y' to approve
    tmux -L cc send-keys -t "$SESSION" "y" Enter
    echo "✅ Approved"
    ;;
  reject)
    tmux -L cc send-keys -t "$SESSION" "n" Enter
    echo "❌ Rejected"
    ;;
  compact)
    tmux -L cc send-keys -t "$SESSION" -l "/compact"
    tmux -L cc send-keys -t "$SESSION" Enter
    echo "🗜️ Compact triggered"
    ;;
  cancel-ralph)
    tmux -L cc send-keys -t "$SESSION" -l "/cancel-ralph"
    tmux -L cc send-keys -t "$SESSION" Enter
    echo "🛑 Ralph cancelled"
    ;;
  "")
    if [[ -z "$TEXT" ]]; then
      echo "Error: --text or an action flag required"
      exit 1
    fi
    tmux -L cc send-keys -t "$SESSION" -l "$TEXT"
    tmux -L cc send-keys -t "$SESSION" Enter
    echo "📤 Sent"
    ;;
esac
