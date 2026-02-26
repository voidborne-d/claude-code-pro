#!/usr/bin/env bash
# Start a Claude Code task in a tmux session (print mode — no interactivity issues)
# Usage: start.sh --label <name> --workdir <path> [--task <prompt>] [--task-file <file>] [--mode <plan|auto>] [--model <model>]

set -euo pipefail

LABEL=""
WORKDIR=""
TASK=""
TASK_FILE=""
MODE="auto"
MODEL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --label) LABEL="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --task) TASK="$2"; shift 2;;
    --task-file) TASK_FILE="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$LABEL" || -z "$WORKDIR" ]]; then
  echo "Usage: start.sh --label <name> --workdir <path> [--task <prompt>] [--task-file <file>] [--mode plan|auto] [--model <model>]"
  exit 1
fi

SESSION="cc-${LABEL}"

# Load task from file if specified
if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
  TASK=$(cat "$TASK_FILE")
fi

# Guard: must have a task
if [[ -z "$TASK" ]]; then
  echo "Error: --task or --task-file required"
  exit 1
fi

# Kill existing session if any
tmux -L cc kill-session -t "$SESSION" 2>/dev/null || true

# Build claude command — always use -p (print mode) for non-interactive execution
# This avoids: permission confirmation dialogs, plan mode, paste issues
CLAUDE_CMD="claude -p --dangerously-skip-permissions --verbose"

case $MODE in
  plan) CLAUDE_CMD="$CLAUDE_CMD --permission-mode plan";;
  auto) CLAUDE_CMD="$CLAUDE_CMD --permission-mode bypassPermissions";;
  *) echo "Unknown mode: $MODE"; exit 1;;
esac

if [[ -n "$MODEL" ]]; then
  CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"
fi

# Write task to temp file for safe quoting
TMPFILE=$(mktemp /tmp/cc-task-XXXXXX.txt)
printf '%s' "$TASK" > "$TMPFILE"

# Create tmux session running claude in print mode
# Task is passed via stdin from the temp file
tmux -L cc new-session -d -s "$SESSION" -c "$WORKDIR" \
  "bash -c '${CLAUDE_CMD} < \"${TMPFILE}\" 2>&1; CODE=\$?; rm -f \"${TMPFILE}\"; echo; echo \"[EXIT CODE: \$CODE]\"; exec bash'"

echo "✅ Session started: $SESSION"
echo "📂 Workdir: $WORKDIR"
echo "🔧 Mode: $MODE (print, non-interactive)"
echo "👁️ Attach: tmux -L cc attach -t $SESSION"
echo "📋 Monitor: $(dirname "$0")/monitor.sh --session $SESSION"
