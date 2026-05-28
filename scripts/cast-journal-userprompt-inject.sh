#!/usr/bin/env bash
# cast-journal-userprompt-inject.sh — inject today's journal excerpt + scratchpad at UserPromptSubmit
# Hook event: UserPromptSubmit
#
# Output: additionalContext JSON with last 20 non-blank lines of today's entry (if > 5 lines).
# Also injects scratchpad section (last 20 non-blank lines) if .scratch/<TODAY>.md is non-empty.
# Injection is deterministic (always last-N lines, stable order) to minimize cache busting.

if [[ "${CLAUDE_SUBPROCESS:-0}" == "1" ]]; then exit 0; fi

[[ -n "${HOME:-}" ]] || exit 0

set -euo pipefail

VAULT="${CAST_JOURNAL_VAULT:-$HOME/Documents/Claude}"
TODAY="$(date +%Y-%m-%d)"
MONTH="$(date +%Y-%m)"
TODAY_NOTE="${VAULT}/${MONTH}/${TODAY}.md"
SCRATCH_FILE="${VAULT}/.scratch/${TODAY}.md"
LOG_FILE="${HOME}/.claude/logs/cast-journal-inject.log"

# Ensure log dir exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# --- Journal injection ---
JOURNAL_SECTION=""
if [[ -f "$TODAY_NOTE" ]]; then
  # Count non-blank lines
  ENTRY_LINES=$(grep -c '[^[:space:]]' "$TODAY_NOTE" 2>/dev/null || echo 0)
  if [[ "$ENTRY_LINES" -gt 5 ]]; then
    # Extract last 20 non-blank lines (stable, deterministic for cache)
    JOURNAL_CONTENT=$(grep '[^[:space:]]' "$TODAY_NOTE" | tail -20)
    JOURNAL_SECTION="## Your journal (last 20 lines)
${JOURNAL_CONTENT}"
    echo "$(date +%Y-%m-%dT%H:%M:%S) injected journal (${ENTRY_LINES} lines)" >> "$LOG_FILE" 2>/dev/null || true
  else
    echo "$(date +%Y-%m-%dT%H:%M:%S) skip inject — stub entry (${ENTRY_LINES} lines)" >> "$LOG_FILE" 2>/dev/null || true
  fi
fi

# --- Scratchpad injection ---
SCRATCH_SECTION=""
if [[ -f "$SCRATCH_FILE" ]] && [[ -s "$SCRATCH_FILE" ]]; then
  SCRATCH_CONTENT=$(grep '[^[:space:]]' "$SCRATCH_FILE" | tail -20)
  SCRATCH_SECTION="## Scratchpad (today)
${SCRATCH_CONTENT}"
  echo "$(date +%Y-%m-%dT%H:%M:%S) injected scratchpad" >> "$LOG_FILE" 2>/dev/null || true
fi

# Exit silently with no output if nothing to inject
if [[ -z "$JOURNAL_SECTION" && -z "$SCRATCH_SECTION" ]]; then
  exit 0
fi

# Combine sections with blank-line separator
export CAST_JOURNAL_SECTION="$JOURNAL_SECTION"
export CAST_SCRATCH_SECTION="$SCRATCH_SECTION"
python3 << 'PYEOF'
import json, os
journal_section = os.environ.get("CAST_JOURNAL_SECTION", "").rstrip()
scratch_section = os.environ.get("CAST_SCRATCH_SECTION", "").rstrip()
parts = [s for s in [journal_section, scratch_section] if s]
context_text = "\n\n".join(parts)
output = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": context_text
    }
}
print(json.dumps(output))
PYEOF

exit 0
