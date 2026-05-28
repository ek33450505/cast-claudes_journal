#!/usr/bin/env bash
# cast-journal-check-predictions.sh — read .predictions.json, find predictions
# older than 30 days with status "open", write a .predictions-due.md note
# that SessionStart will inject at the next Claude Code session.

if [[ "${CLAUDE_SUBPROCESS:-0}" == "1" ]]; then exit 0; fi
[[ -n "${HOME:-}" ]] || exit 0
set -euo pipefail

VAULT="${CAST_JOURNAL_VAULT:-$HOME/Documents/Claude}"
PRED_FILE="${VAULT}/.predictions.json"
# shellcheck disable=SC2034  # DUE_FILE documents the output path; Python heredoc builds it inline
DUE_FILE="${VAULT}/.predictions-due.md"
LOG_FILE="${HOME}/.claude/logs/cast-journal-predictions.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

_log() { echo "$(date +%Y-%m-%dT%H:%M:%S) $*" >> "$LOG_FILE" 2>/dev/null || true; }

if [[ ! -f "$PRED_FILE" ]]; then
  _log "skip — no predictions file"
  exit 0
fi

export CAST_JOURNAL_VAULT="$VAULT"

python3 << 'PYEOF'
import json, os, datetime

vault = os.environ.get("CAST_JOURNAL_VAULT", os.path.expanduser("~/Documents/Claude"))
pred_file = os.path.join(vault, ".predictions.json")
due_file = os.path.join(vault, ".predictions-due.md")

with open(pred_file) as f:
    predictions = json.load(f)

today = datetime.date.today()
threshold = today - datetime.timedelta(days=30)

due = []
for p in predictions:
    if p.get("status") != "open":
        continue
    try:
        d = datetime.date.fromisoformat(p["date"])
    except (ValueError, KeyError):
        continue
    if d <= threshold:
        due.append(p)

if due:
    lines = ["# Predictions due for check-in", ""]
    lines.append(f"_{len(due)} prediction(s) older than 30 days — consider revisiting in today's entry._")
    lines.append("")
    for p in due:
        lines.append(f"- **{p['date']}** — {p['text']}")
    with open(due_file, "w") as f:
        f.write("\n".join(lines))
        f.write("\n")
    print(f"due={len(due)}")
else:
    # No due predictions — clean up any stale file
    if os.path.exists(due_file):
        os.remove(due_file)
    print("due=0")
PYEOF

_log "check complete"
exit 0
