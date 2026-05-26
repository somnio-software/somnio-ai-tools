#!/usr/bin/env bash
set -euo pipefail

# Recursion guard: the Haiku subprocess also triggers Stop; exit immediately.
[ -n "${WORK_LOG_CHILD:-}" ] && exit 0

DATE=$(date '+%Y-%m-%d')
LOG=~/.work-log/$DATE.md
mkdir -p ~/.work-log

# Debounce: skip if the log was written less than 5 seconds ago.
LAST=$(stat -f %m "$LOG" 2>/dev/null || echo 0)
AGE=$(( $(date +%s) - LAST ))
[ "$AGE" -lt 5 ] && exit 0

STDIN=$(cat)

CWD=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null || true)
[ -z "$CWD" ] && CWD=$(pwd)

BRANCH=$(cd "$CWD" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-git')

# Log root repo + worktree so Clockify mapping works at the repo level.
GIT_COMMON=$(cd "$CWD" && git rev-parse --git-common-dir 2>/dev/null || echo "")
if [ -n "$GIT_COMMON" ]; then
  ROOT_REPO=$(basename "$(dirname "$GIT_COMMON")")
  WORKTREE=$(basename "$CWD")
  if [ "$ROOT_REPO" = "$WORKTREE" ]; then
    PROJ="$ROOT_REPO"
  else
    PROJ="$ROOT_REPO/$WORKTREE"
  fi
else
  PROJ=$(basename "$CWD")
fi

LAST_MSG=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("last_assistant_message","")[:3000])' 2>/dev/null || true)

printf "\n## %s - %s (%s)\n" "$(date '+%H:%M')" "$PROJ" "$BRANCH" >> "$LOG"

if [ "${#LAST_MSG}" -lt 20 ]; then
  printf "No significant output.\n" >> "$LOG"
  exit 0
fi

GIT_STAT=$(cd "$CWD" && { git log --oneline -3 2>/dev/null; echo "---"; git diff --stat HEAD 2>/dev/null | head -5; } || true)

PROMPT=$(printf 'Write 2-3 sentences for a work log entry. Be specific: name files, functions, root causes, decisions. Cover: what was accomplished, the key technical finding, and any open question or next step. Output ONLY the sentences.\n\nProject: %s (%s)\nRecent git:\n%s\n\nFinal response:\n%s' \
  "$PROJ" "$BRANCH" "$GIT_STAT" "$LAST_MSG")

CLAUDE_BIN=$(which claude 2>/dev/null || echo "claude")

(
  WORK_LOG_CHILD=1 "$CLAUDE_BIN" -p \
    --model claude-haiku-4-5-20251001 \
    --no-session-persistence \
    "$PROMPT" >> "$LOG" 2>/dev/null \
  || printf "(summary unavailable)\n" >> "$LOG"
) &

exit 0
