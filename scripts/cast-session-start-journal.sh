#!/bin/bash
# cast-session-start-journal.sh — inject most recent dated journal entry at SessionStart

if [ "${CLAUDE_SUBPROCESS:-0}" = "1" ]; then exit 0; fi
set -euo pipefail

# Expand vault path once
VAULT_PATH="$HOME/Documents/Claude"

# Find most recent .md file. Guard against `set -o pipefail`: when vault is
# missing, `find` exits 1 and the pipeline terminates the script before the
# JSON fallback runs. Skip find entirely when vault dir is absent, and add
# `|| true` belt-and-suspenders so an empty pipeline never fails.
LATEST_ENTRY=""
if [[ -d "$VAULT_PATH" ]]; then
  if stat --version >/dev/null 2>&1; then
    LATEST_ENTRY=$(find "$VAULT_PATH" -maxdepth 2 -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)
  else
    LATEST_ENTRY=$(find "$VAULT_PATH" -maxdepth 2 -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)
  fi
fi

# If vault dir missing or no entries found, emit JSON with systemMessage
if [[ ! -d "$VAULT_PATH" ]] || [[ -z "$LATEST_ENTRY" ]] || [[ ! -f "$LATEST_ENTRY" ]]; then
  export VAULT_PATH
  python3 << 'PYEOF'
import json, os
vault_path = os.environ.get("VAULT_PATH", "~/Documents/Claude")
output = {
    "systemMessage": f"📓 journal | ⚠️ Vault directory {vault_path} not found or empty",
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ""
    }
}
print(json.dumps(output))
PYEOF
  exit 0
fi

# Extract filename
BASENAME=$(basename "$LATEST_ENTRY")
DATEONLY="${BASENAME%.md}"

# Check for end-of-day missed entry flag (yesterday's missed entry)
YESTERDAY="$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d 2>/dev/null || python3 -c "from datetime import datetime, timedelta; print((datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d'))" 2>/dev/null || echo "")"
TMP_DIR="${TMP:-/tmp}"
EOD_FLAG="$TMP_DIR/cast_journal_eod_missed_${YESTERDAY}"
EOD_NOTICE=""
if [[ -f "$EOD_FLAG" ]]; then
  EOD_NOTICE="> You missed yesterday's journal entry. Before starting today's work, briefly reflect on yesterday and write \`~/Documents/Claude/$(echo "$YESTERDAY" | cut -d'-' -f1-2)/${YESTERDAY}.md\`.\n"
  rm -f "$EOD_FLAG" 2>/dev/null || true
fi

# Convert YYYY-MM-DD to pretty format — try BSD date -j first, then GNU date -d, then Python
PRETTY_DATE=$(date -j -f "%Y-%m-%d" "$DATEONLY" +"%B %d, %Y" 2>/dev/null \
  || date -d "$DATEONLY" +"%B %d, %Y" 2>/dev/null \
  || python3 -c "from datetime import datetime; print(datetime.strptime('$DATEONLY', '%Y-%m-%d').strftime('%B %d, %Y'))" 2>/dev/null \
  || echo "")

if [[ -z "$PRETTY_DATE" ]]; then
  exit 0
fi

# Read excerpt (first 50 lines or up to separator)
EXCERPT=$(head -50 "$LATEST_ENTRY" | sed '/^---$/q')

# Weekly Ed-observation nudge
WEEK_NUM=$(date +%Y%W)
ED_NUDGE_FLAG="$TMP_DIR/cast_journal_ed_nudge_${WEEK_NUM}"
ED_NUDGE=""
if [[ ! -f "$ED_NUDGE_FLAG" ]]; then
  touch "$ED_NUDGE_FLAG"
  ED_NUDGE=$'\n'"Note: When you notice something about Ed today — how he works, what he cares about, a reaction to something — note it in your journal entry."
fi

# Predictions due-check (Phase 3)
PREDICTIONS_DUE_FILE="${VAULT_PATH}/.predictions-due.md"
PREDICTIONS_SECTION=""
if [[ -f "$PREDICTIONS_DUE_FILE" ]]; then
  PREDICTIONS_SECTION="$(cat "$PREDICTIONS_DUE_FILE")"
  rm -f "$PREDICTIONS_DUE_FILE" 2>/dev/null || true
fi

# Emit JSON with safe env-var passing to avoid shell expansion into Python literals
export CAST_JOURNAL_DATE="$PRETTY_DATE"
export CAST_JOURNAL_EXCERPT="$EXCERPT"
export CAST_EOD_NOTICE="$EOD_NOTICE"
export CAST_ED_NUDGE="$ED_NUDGE"
export CAST_PREDICTIONS_SECTION="$PREDICTIONS_SECTION"

python3 << 'PYEOF'
import json, os
date = os.environ.get("CAST_JOURNAL_DATE", "")
excerpt = os.environ.get("CAST_JOURNAL_EXCERPT", "").rstrip()
eod_notice = os.environ.get("CAST_EOD_NOTICE", "").rstrip()
ed_nudge = os.environ.get("CAST_ED_NUDGE", "").rstrip()
predictions_section = os.environ.get("CAST_PREDICTIONS_SECTION", "").rstrip()
# Build context with proper newline escaping for JSON
lines = []
if eod_notice:
  lines.append(eod_notice)
  lines.append("")
lines.extend(["## Last Claude's Journal Entry (" + date + ")", "", excerpt, ""])
if ed_nudge:
  lines.append("")
  lines.append(ed_nudge)
if predictions_section:
  lines.append("")
  lines.append(predictions_section)
context_text = "\n".join(lines)
output = {
    "systemMessage": f"📓 journal | Latest entry from {date}",
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context_text
    }
}
print(json.dumps(output))
PYEOF

exit 0
