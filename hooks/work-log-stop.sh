#!/usr/bin/env bash
set -euo pipefail

# Recursion guard: the Haiku subprocess also triggers Stop; exit immediately.
[ -n "${WORK_LOG_CHILD:-}" ] && exit 0

DATE=$(date '+%Y-%m-%d')
LOG=~/.work-log/$DATE.md
mkdir -p ~/.work-log

STDIN=$(cat)

CWD=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null || true)
[ -z "$CWD" ] && CWD=$(pwd)

BRANCH=$(cd "$CWD" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-git')

# Log root repo + worktree so Clockify mapping works at the repo level.
GIT_COMMON=$(cd "$CWD" && git rev-parse --git-common-dir 2>/dev/null || echo "")
if [ -n "$GIT_COMMON" ]; then
  # git rev-parse --git-common-dir returns a relative path (possibly with ..
  # segments) for main checkouts, e.g. ../.git from a subdirectory.
  # Resolve to absolute before dirname/basename so ROOT_REPO is correct in both cases.
  case "$GIT_COMMON" in /*) ;; *) GIT_COMMON="$CWD/$GIT_COMMON" ;; esac
  ROOT_REPO=$(basename "$(cd "$(dirname "$GIT_COMMON")" 2>/dev/null && pwd)")
  WORKTREE=$(basename "$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")")
  if [ "$ROOT_REPO" = "$WORKTREE" ]; then
    PROJ="$ROOT_REPO"
  else
    PROJ="$ROOT_REPO/$WORKTREE"
  fi
else
  PROJ=$(basename "$CWD")
fi

LAST_MSG=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("last_assistant_message","")[:3000])' 2>/dev/null || true)

# Skip trivially short turns (one-liners, empty responses) without a Haiku call.
[ "${#LAST_MSG}" -lt 300 ] && exit 0

# Debounce per session (falls back to cwd) so concurrent projects never block
# each other. Stamped synchronously here: the daily log's own mtime is useless
# as a key because the write happens later, in the background Haiku subprocess.
SESSION=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id",""))' 2>/dev/null || true)
KEY=$(printf '%s' "${SESSION:-$CWD}" | shasum | awk '{print $1}')
mkdir -p ~/.work-log/.debounce
STAMP=~/.work-log/.debounce/$KEY
LAST=$(python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$STAMP" 2>/dev/null || echo 0)
[ $(( $(date +%s) - LAST )) -lt 5 ] && exit 0
touch "$STAMP"

GIT_STAT=$(cd "$CWD" && { git log --oneline -3 2>/dev/null; echo "---"; git diff --stat HEAD 2>/dev/null | head -5; } || true)

# Capture the stop time now so the log entry reflects when the session ended,
# not when the background Haiku process finishes writing.
TIMESTAMP=$(date '+%H:%M')

PROMPT=$(printf 'You are writing a developer work log. Classify this session and respond accordingly.\n\nIf the session is purely conversational Q&A (factual questions, general explanations, no real investigation or decision-making): output exactly the word SKIP and nothing else.\n\nOtherwise write 2-3 sentences: what was accomplished or investigated, the key technical finding or decision, and any next step. Be specific — name files, functions, concepts, root causes. For research or investigation sessions with no code changes, describe what was explored and what was found. Do NOT reference git commits unless they are directly mentioned in the session response.\n\nProject: %s (%s)\nRecent git (supplementary context only):\n%s\n\nSession response:\n%s' \
  "$PROJ" "$BRANCH" "$GIT_STAT" "$LAST_MSG")

CLAUDE_BIN=$(which claude 2>/dev/null || echo "claude")

(
  SUMMARY=$(WORK_LOG_CHILD=1 "$CLAUDE_BIN" -p \
    --model claude-haiku-4-5-20251001 \
    --no-session-persistence \
    "$PROMPT" 2>/dev/null \
    || echo "(summary unavailable)")

  # Write nothing for Q&A sessions; write header + summary for everything else.
  case "$SUMMARY" in
    [Ss][Kk][Ii][Pp]*) ;;
    *)
      {
        printf "\n## %s - %s (%s)\n" "$TIMESTAMP" "$PROJ" "$BRANCH"
        printf "%s\n" "$SUMMARY"
      } >> "$LOG"
    ;;
  esac
) &

exit 0
