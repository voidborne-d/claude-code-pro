#!/usr/bin/env bash
# Start a Claude Code task in a tmux session
# Usage: start.sh --label <name> --workdir <path> [--task <prompt>] [--task-file <file>] [--mode <plan|auto>] [--model <model>]
#
# Modes:
#   auto  — print mode (-p), non-interactive, direct execution (default)
#   plan  — interactive mode with plan confirmation, background watcher auto-approves

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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Build model flag
MODEL_FLAG=""
if [[ -n "$MODEL" ]]; then
  MODEL_FLAG="--model $MODEL"
fi

case $MODE in
  auto)
    # ── Print mode: non-interactive, no dialogs ──
    CLAUDE_CMD="claude -p --dangerously-skip-permissions --permission-mode bypassPermissions --verbose ${MODEL_FLAG}"

    TMPFILE=$(mktemp /tmp/cc-task-XXXXXX.txt)
    printf '%s' "$TASK" > "$TMPFILE"

    tmux -L cc new-session -d -s "$SESSION" -c "$WORKDIR" \
      "bash -c '${CLAUDE_CMD} < \"${TMPFILE}\" 2>&1; CODE=\$?; rm -f \"${TMPFILE}\"; echo; echo \"[EXIT CODE: \$CODE]\"; exec bash'"

    echo "✅ Session started: $SESSION"
    echo "📂 Workdir: $WORKDIR"
    echo "🔧 Mode: auto (print, non-interactive)"
    ;;

  plan)
    # ── Interactive mode with plan: watcher auto-approves dialogs ──
    CLAUDE_CMD="claude --dangerously-skip-permissions ${MODEL_FLAG}"

    # Create tmux session and start claude
    tmux -L cc new-session -d -s "$SESSION" -c "$WORKDIR"
    sleep 0.5
    tmux -L cc send-keys -t "$SESSION" "$CLAUDE_CMD" Enter
    sleep 3

    # Send task via load-buffer (safe for multi-line)
    TMPFILE=$(mktemp /tmp/cc-task-XXXXXX.txt)
    printf '%s' "$TASK" > "$TMPFILE"
    tmux -L cc load-buffer "$TMPFILE"
    tmux -L cc paste-buffer -t "$SESSION"
    rm -f "$TMPFILE"
    sleep 0.3
    tmux -L cc send-keys -t "$SESSION" Enter

    # Start background watcher to auto-approve plan confirmation + permission dialogs
    nohup bash "${SCRIPT_DIR}/watcher.sh" "$SESSION" 1 \
      > "/tmp/cc-watcher-${LABEL}.log" 2>&1 &
    WATCHER_PID=$!

    echo "✅ Session started: $SESSION"
    echo "📂 Workdir: $WORKDIR"
    echo "🔧 Mode: plan (interactive + auto-approve watcher PID $WATCHER_PID)"
    echo "📄 Watcher log: /tmp/cc-watcher-${LABEL}.log"
    ;;

  *)
    echo "Unknown mode: $MODE (use 'auto' or 'plan')"
    exit 1
    ;;
esac

echo "👁️ Attach: tmux -L cc attach -t $SESSION"
echo "📋 Monitor: ${SCRIPT_DIR}/monitor.sh --session $SESSION"
