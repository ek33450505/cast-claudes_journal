#!/usr/bin/env bash
# cast-journal-extract-predictions.sh — grep journal entries for predictions/questions,
# write to ~/Documents/Claude/.predictions.json as {date, text, status: "open"} array.
# Idempotent: never duplicates a prediction already present in the file.

if [[ "${CLAUDE_SUBPROCESS:-0}" == "1" ]]; then exit 0; fi
[[ -n "${HOME:-}" ]] || exit 0
set -euo pipefail

VAULT="${CAST_JOURNAL_VAULT:-$HOME/Documents/Claude}"
PRED_FILE="${VAULT}/.predictions.json"
LOG_FILE="${HOME}/.claude/logs/cast-journal-predictions.log"

mkdir -p "$(dirname "$LOG_FILE")" "$VAULT" 2>/dev/null || true

_log() { echo "$(date +%Y-%m-%dT%H:%M:%S) $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Initialize file if absent
if [[ ! -f "$PRED_FILE" ]]; then
  echo "[]" > "$PRED_FILE"
fi

# Find all daily entries, extract lines matching prediction patterns (case-insensitive),
# emit (date, line) pairs to stdin of Python
# shellcheck disable=SC2034  # PATTERN documents the regex; Python heredoc re-declares it inline
PATTERN='(I predict|I expect|open thread:|question:)'

export CAST_JOURNAL_VAULT="$VAULT"

python3 << 'PYEOF'
import json, os, re, glob

vault = os.environ.get("CAST_JOURNAL_VAULT", os.path.expanduser("~/Documents/Claude"))
pred_file = os.path.join(vault, ".predictions.json")

with open(pred_file) as f:
    existing = json.load(f)

# Build a set of (date, text) tuples already recorded
seen = {(p["date"], p["text"]) for p in existing if "date" in p and "text" in p}

pattern = re.compile(r"(I predict|I expect|open thread:|question:)", re.IGNORECASE)
added = 0

for entry_path in sorted(glob.glob(os.path.join(vault, "????-??", "????-??-??.md"))):
    date = os.path.basename(entry_path).replace(".md", "")
    try:
        with open(entry_path) as f:
            for line in f:
                stripped = line.strip()
                if pattern.search(stripped):
                    key = (date, stripped)
                    if key not in seen:
                        existing.append({"date": date, "text": stripped, "status": "open"})
                        seen.add(key)
                        added += 1
    except (IOError, OSError):
        continue

with open(pred_file, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")

print(f"added={added} total={len(existing)}")
PYEOF

_log "extract complete"
exit 0
