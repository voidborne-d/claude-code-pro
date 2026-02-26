#!/usr/bin/env bash
# Background watcher: auto-approve plan mode confirmations and permission dialogs
# Usage: watcher.sh <session-name> [auto-approve-choice]
#   auto-approve-choice: 1 = clear context + bypass (default), 2 = bypass only
#
# Detects these patterns and auto-responds:
#   1. Plan confirmation ("Yes, clear context", "Yes, and bypass permissions")
#   2. Permission bypass dialog ("No, exit" / "Yes, I accept")
#
# Exits when the tmux session dies.

set -euo pipefail

SESSION="${1:?Usage: watcher.sh <session-name> [choice]}"
CHOICE="${2:-1}"
POLL_INTERVAL=5
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo "[watcher:${SESSION}] $(date +%H:%M:%S) $*"; }

# Wait for session to exist
for i in {1..10}; do
  tmux -L cc has-session -t "$SESSION" 2>/dev/null && break
  sleep 1
done

if ! tmux -L cc has-session -t "$SESSION" 2>/dev/null; then
  log "Session $SESSION not found, exiting"
  exit 1
fi

log "Watching session $SESSION (auto-approve: $CHOICE)"

while tmux -L cc has-session -t "$SESSION" 2>/dev/null; do
  # Capture last 30 lines of tmux pane
  CONTENT=$(tmux -L cc capture-pane -t "$SESSION" -p -S -30 2>/dev/null || true)

  if [[ -z "$CONTENT" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  # Pattern 1: Permission bypass dialog — need to move to option 2 then confirm
  # "› 1. No, exit"  "  2. Yes, I accept"
  if echo "$CONTENT" | grep -q "No, exit" && echo "$CONTENT" | grep -q "Yes, I accept"; then
    log "Detected permission dialog → navigating to 'Yes, I accept' and confirming"
    tmux -L cc send-keys -t "$SESSION" Down Enter
    sleep 3
    continue
  fi

  # Pattern 2: Plan mode confirmation — option 1 is already selected by default
  # These are interactive select menus, NOT text inputs. Just press Enter.
  if echo "$CONTENT" | grep -q "Yes, clear context\|Yes, and bypass permissions\|Would you like to proceed"; then
    log "Detected plan confirmation → pressing Enter to confirm default selection"
    tmux -L cc send-keys -t "$SESSION" Enter
    sleep 3
    continue
  fi

  sleep "$POLL_INTERVAL"
done

log "Session $SESSION ended, watcher exiting"
