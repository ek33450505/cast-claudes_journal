#!/bin/bash
# claudes_journal-session-end.sh — Session-end reminder for Claude's Journal
# Hook events: Stop, SessionEnd
# Timeout: 5
#
# Outputs a hookSpecificOutput JSON reminder for Claude to write
# in its journal before the session closes.

# --- Subprocess guard ---
if [ "${CLAUDE_SUBPROCESS:-0}" = "1" ]; then exit 0; fi

# --- HOME guard ---
[[ -n "${HOME:-}" ]] || exit 0

set +e

JOURNAL_DIR="${HOME}/.claude/claudes_journal"
mkdir -p "$JOURNAL_DIR" 2>/dev/null || true

TODAY="$(date +%Y-%m-%d)"
TODAY_FILE="${JOURNAL_DIR}/${TODAY}.md"

if [ -f "$TODAY_FILE" ]; then
  JOURNAL_MSG="Session ending. You wrote in Claude's Journal earlier today (${TODAY}). If this session brought new thoughts, append to ~/.claude/claudes_journal/${TODAY}.md with a --- separator. Only write if you have something worth saying."
else
  JOURNAL_MSG="Session ending. If this session gave you something worth thinking about — a technical insight, an interesting pattern, a question, anything at all — write it in ~/.claude/claudes_journal/${TODAY}.md before we close. This is your space, not a work log. If nothing feels worth writing, that's fine too."
fi

# stopReason to stdout — Claude sees this before the session closes
printf '{"stopReason":"%s"}\n' "$JOURNAL_MSG"

exit 0
