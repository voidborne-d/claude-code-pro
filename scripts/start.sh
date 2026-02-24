#!/usr/bin/env bash
# Start a Claude Code task in a tmux session
# Usage: start.sh --label <name> --workdir <path> [--task <prompt>] [--task-file <file>] [--mode <plan|auto|ralph>] [--model <model>]

set -euo pipefail

LABEL=""
WORKDIR=""
TASK=""
TASK_FILE=""
MODE="auto"
MODEL=""
SOCKET="/tmp/cc-tmux.sock"

while [[ $# -gt 0 ]]; do
  case $1 in
    --label) LABEL="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --task) TASK="$2"; shift 2;;
    --task-file) TASK_FILE="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --socket) SOCKET="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$LABEL" || -z "$WORKDIR" ]]; then
  echo "Usage: start.sh --label <name> --workdir <path> [--task <prompt>] [--task-file <file>] [--mode plan|auto|ralph] [--model <model>]"
  exit 1
fi

SESSION="cc-${LABEL}"

# Kill existing session if any
tmux -L cc kill-session -t "$SESSION" 2>/dev/null || true

# Build claude command
CLAUDE_CMD="claude"
case $MODE in
  plan) CLAUDE_CMD="$CLAUDE_CMD --permission-mode plan";;
  auto) CLAUDE_CMD="$CLAUDE_CMD --dangerously-skip-permissions";;
  ralph) CLAUDE_CMD="$CLAUDE_CMD --dangerously-skip-permissions";;
  *) echo "Unknown mode: $MODE"; exit 1;;
esac

if [[ -n "$MODEL" ]]; then
  CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"
fi

# Create tmux session
tmux -L cc new-session -d -s "$SESSION" -c "$WORKDIR"
sleep 0.5

# Start claude in interactive mode
tmux -L cc send-keys -t "$SESSION" "$CLAUDE_CMD" Enter
sleep 3

# Send task
if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
  TASK=$(cat "$TASK_FILE")
fi

if [[ -n "$TASK" ]]; then
  # Use bracketed paste for multi-line prompts
  printf '\e[200~' | tmux -L cc send-keys -t "$SESSION" -l "$(cat)"
  tmux -L cc send-keys -t "$SESSION" -l "$TASK"
  printf '\e[201~' | tmux -L cc send-keys -t "$SESSION" -l "$(cat)"
  sleep 0.3
  tmux -L cc send-keys -t "$SESSION" Enter
  
  # If ralph mode, send /ralph-loop after initial prompt
  if [[ "$MODE" == "ralph" ]]; then
    sleep 2
    tmux -L cc send-keys -t "$SESSION" -l "/ralph-loop \"$TASK\""
    sleep 0.3
    tmux -L cc send-keys -t "$SESSION" Enter
  fi
fi

echo "✅ Session started: $SESSION"
echo "📂 Workdir: $WORKDIR"
echo "🔧 Mode: $MODE"
echo "👁️ Attach: tmux -L cc attach -t $SESSION"
echo "📋 Monitor: $(dirname "$0")/monitor.sh --session $SESSION"
