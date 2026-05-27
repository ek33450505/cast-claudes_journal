#!/usr/bin/env bash
# cast-journal-eod-flag.sh — mark when end-of-day passes without a journal entry
# Intended to run via cron at 23:30 daily

if [[ "${CLAUDE_SUBPROCESS:-0}" = "1" ]]; then exit 0; fi
[[ -n "${HOME:-}" ]] || exit 0
set -euo pipefail

TODAY="$(date +%Y-%m-%d)"
MONTH="$(date +%Y-%m)"
VAULT="$HOME/Documents/Claude"
NOTE="$VAULT/$MONTH/$TODAY.md"
FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

# If entry exists and has substantive content (not whitespace-only), nothing to do
if [[ -f "$NOTE" ]]; then
  if grep -q '[^[:space:]]' "$NOTE" 2>/dev/null; then
    exit 0
  fi
fi

# Entry missing, empty, or whitespace-only — write eod-missed flag
touch "$FLAG" 2>/dev/null || true

exit 0
