#!/usr/bin/env bash
# cast-journal-weekly-synthesis.sh — read last 7 journal entries, ask claude --print
# for a 200-300 word synthesis, write to ~/Documents/Claude/<YYYY-MM>/weekly-<DATE>.md
# Best-effort: if claude CLI is missing or fails, log and skip.

if [[ "${CLAUDE_SUBPROCESS:-0}" == "1" ]]; then exit 0; fi
[[ -n "${HOME:-}" ]] || exit 0
set -euo pipefail

VAULT="${CAST_JOURNAL_VAULT:-$HOME/Documents/Claude}"
TODAY="$(date +%Y-%m-%d)"
MONTH="$(date +%Y-%m)"
OUT_DIR="${VAULT}/${MONTH}"
OUT_FILE="${OUT_DIR}/weekly-${TODAY}.md"
LOG_FILE="${HOME}/.claude/logs/cast-journal-synthesis.log"

mkdir -p "$(dirname "$LOG_FILE")" "$OUT_DIR" 2>/dev/null || true

_log() { echo "$(date +%Y-%m-%dT%H:%M:%S) $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Bail if claude CLI is missing — synthesis is best-effort
if ! command -v claude >/dev/null 2>&1; then
  _log "skip — claude CLI not on PATH"
  exit 0
fi

# Gather last 7 daily entries (most recent first, then reverse for chronological)
ENTRIES_TMP="$(mktemp "${TMPDIR:-/tmp}/cast_journal_synthesis.XXXXXX")"
trap 'rm -f "$ENTRIES_TMP" "${ENTRIES_TMP}.list"' EXIT

# Find all entries, sort, take last 7
find "$VAULT" -path "$VAULT/????-??/????-??-??.md" -type f 2>/dev/null \
  | sort | tail -7 > "${ENTRIES_TMP}.list"

ENTRY_COUNT=$(wc -l < "${ENTRIES_TMP}.list" | tr -d ' ')
if [[ "$ENTRY_COUNT" -lt 2 ]]; then
  _log "skip — only ${ENTRY_COUNT} entries available (need >=2)"
  rm -f "${ENTRIES_TMP}.list"
  exit 0
fi

# Concatenate entries with separators
while IFS= read -r entry; do
  echo "=== ${entry##*/} ==="
  cat "$entry"
  echo
done < "${ENTRIES_TMP}.list" > "$ENTRIES_TMP"
rm -f "${ENTRIES_TMP}.list"

SYNTHESIS_PROMPT='Read the following journal entries. Write a 200-300 word synthesis: recurring themes, open threads, any predictions or questions worth checking. Format as a plain markdown note. No headers.'

# Run claude --print; capture output and exit code
if SYNTH_OUTPUT=$(claude --print "$SYNTHESIS_PROMPT" < "$ENTRIES_TMP" 2>>"$LOG_FILE"); then
  {
    echo "# Weekly synthesis — ${TODAY}"
    echo
    echo "_Auto-generated from the last ${ENTRY_COUNT} daily entries. Do not edit; will be regenerated next Sunday._"
    echo
    echo "$SYNTH_OUTPUT"
  } > "$OUT_FILE"
  _log "wrote ${OUT_FILE} (${ENTRY_COUNT} source entries)"
else
  _log "skip — claude --print failed (see log for stderr)"
fi

exit 0
