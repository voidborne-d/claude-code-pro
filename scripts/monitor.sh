#!/usr/bin/env bash
# Monitor a Claude Code tmux session
# Usage: monitor.sh --session <name> [--lines <n>] [--watch] [--json]

set -euo pipefail

SESSION=""
LINES=100
WATCH=false
JSON=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --session) SESSION="$2"; shift 2;;
    --lines) LINES="$2"; shift 2;;
    --watch) WATCH=true; shift;;
    --json) JSON=true; shift;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$SESSION" ]]; then
  echo "Usage: monitor.sh --session <name> [--lines <n>] [--watch] [--json]"
  exit 1
fi

# Add cc- prefix if not present
[[ "$SESSION" != cc-* ]] && SESSION="cc-${SESSION}"

capture() {
  local output
  output=$(tmux -L cc capture-pane -p -J -t "$SESSION" -S "-${LINES}" 2>/dev/null)
  
  if [[ "$JSON" == true ]]; then
    # Extract last exchange
    local last_prompt last_reply
    last_prompt=$(echo "$output" | grep -n '❯' | tail -1 | cut -d: -f1)
    last_reply=$(echo "$output" | grep -n '⏺' | tail -1 | cut -d: -f1)
    
    local alive="true"
    tmux -L cc has-session -t "$SESSION" 2>/dev/null || alive="false"
    
    jq -n \
      --arg session "$SESSION" \
      --arg alive "$alive" \
      --arg output "$output" \
      --arg last_prompt_line "${last_prompt:-}" \
      --arg last_reply_line "${last_reply:-}" \
      '{session: $session, alive: ($alive == "true"), lastPromptLine: $last_prompt_line, lastReplyLine: $last_reply_line, output: $output}'
  else
    echo "=== $SESSION (last $LINES lines) ==="
    echo "$output"
  fi
}

if [[ "$WATCH" == true ]]; then
  while true; do
    clear
    capture
    sleep 5
  done
else
  capture
fi
