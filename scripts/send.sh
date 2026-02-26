#!/usr/bin/env bash
# Send follow-up input to a Claude Code tmux session
# In print mode (-p), the original session cannot accept follow-up input.
# This script starts a NEW continuation session with --continue flag.
#
# Usage: send.sh --session <name> --text <message>
#        send.sh --session <name> --text-file <file>

set -euo pipefail

SESSION=""
TEXT=""
TEXT_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --session) SESSION="$2"; shift 2;;
    --text) TEXT="$2"; shift 2;;
    --text-file) TEXT_FILE="$2"; shift 2;;
    --approve|--reject|--compact)
      echo "⚠️  $1 is not supported in print mode. Claude Code runs non-interactively."
      exit 1;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$SESSION" ]]; then
  echo "Usage: send.sh --session <name> --text <message> | --text-file <file>"
  exit 1
fi

[[ "$SESSION" != cc-* ]] && SESSION="cc-${SESSION}"

# Load from file if specified
if [[ -n "$TEXT_FILE" && -f "$TEXT_FILE" ]]; then
  TEXT=$(cat "$TEXT_FILE")
fi

if [[ -z "$TEXT" ]]; then
  echo "Error: --text or --text-file required"
  exit 1
fi

# Check if original session is still alive
if tmux -L cc has-session -t "$SESSION" 2>/dev/null; then
  echo "⚠️  Session $SESSION is still running. Wait for it to finish or kill it first."
  exit 1
fi

# Get workdir from the original session's pane (fallback to cwd)
WORKDIR=$(tmux -L cc display-message -t "$SESSION" -p '#{pane_current_path}' 2>/dev/null || pwd)

# Start a continuation session
FOLLOW_SESSION="${SESSION}-follow"
tmux -L cc kill-session -t "$FOLLOW_SESSION" 2>/dev/null || true

TMPFILE=$(mktemp /tmp/cc-send-XXXXXX.txt)
printf '%s' "$TEXT" > "$TMPFILE"

CLAUDE_CMD="claude -p --dangerously-skip-permissions --permission-mode bypassPermissions --continue --verbose"

tmux -L cc new-session -d -s "$FOLLOW_SESSION" -c "$WORKDIR" \
  "bash -c '${CLAUDE_CMD} < \"${TMPFILE}\" 2>&1; CODE=\$?; rm -f \"${TMPFILE}\"; echo; echo \"[EXIT CODE: \$CODE]\"; exec bash'"

echo "📤 Follow-up session started: $FOLLOW_SESSION"
echo "📋 Monitor: $(dirname "$0")/monitor.sh --session $FOLLOW_SESSION"
