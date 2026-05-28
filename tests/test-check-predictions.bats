#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/cast-journal-check-predictions.sh"

setup() {
  VAULT_DIR="$BATS_TMPDIR/vault"
  mkdir -p "$VAULT_DIR"

  # Create HOME for log writes
  HOME_DIR="$BATS_TMPDIR/home"
  mkdir -p "$HOME_DIR/.claude/logs"

  export CAST_JOURNAL_VAULT="$VAULT_DIR"
  export HOME="$HOME_DIR"
  export TMP="$BATS_TMPDIR/tmp"
  mkdir -p "$TMP"
}

teardown() {
  # Guarded cleanup
  if [[ "$VAULT_DIR" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$VAULT_DIR"
  fi
  if [[ "$HOME_DIR" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$HOME_DIR"
  fi
  if [[ "$TMP" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$TMP"
  fi
}

# ---------------------------------------------------------------------------
# Helper: Calculate date N days ago in YYYY-MM-DD format
# ---------------------------------------------------------------------------
date_ago() {
  local days=$1
  python3 -c "from datetime import datetime, timedelta; d = datetime.now() - timedelta(days=$days); print(d.strftime('%Y-%m-%d'))"
}

# ---------------------------------------------------------------------------
# Test 1: Predictions 60+ days old with status open → .predictions-due.md created
# ---------------------------------------------------------------------------
@test "old open predictions: 60+ days old, status=open → .predictions-due.md created" {
  TODAY=$(date +%Y-%m-%d)
  DATE_60_DAYS_AGO=$(date_ago 60)
  DATE_5_DAYS_AGO=$(date_ago 5)

  # Create .predictions.json with:
  # - 2 predictions 60 days ago (open)
  # - 1 prediction 5 days ago (open) — too recent
  # - 1 prediction 60 days ago (closed) — status != open
  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict we'll finish refactoring", "status": "open"},
  {"date": "$DATE_60_DAYS_AGO", "text": "Question: should we upgrade Node?", "status": "open"},
  {"date": "$DATE_5_DAYS_AGO", "text": "I expect good results next week", "status": "open"},
  {"date": "$DATE_60_DAYS_AGO", "text": "This was addressed already", "status": "closed"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # .predictions-due.md should exist
  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  [ -f "$DUE_FILE" ]

  # Should contain the 2 old open predictions
  grep -q "I predict we'll finish refactoring" "$DUE_FILE"
  grep -q "should we upgrade Node?" "$DUE_FILE"

  # Should NOT contain the recent one or the closed one
  ! grep -q "I expect good results next week" "$DUE_FILE"
  ! grep -q "This was addressed already" "$DUE_FILE"

  # Should have a header
  grep -q "# Predictions due for check-in" "$DUE_FILE"

  # Should mention "2 prediction(s)"
  grep -q "2 prediction" "$DUE_FILE"
}

# ---------------------------------------------------------------------------
# Test 2: All predictions recent → no .predictions-due.md created
# ---------------------------------------------------------------------------
@test "all predictions recent: no predictions >= 30 days old → no .predictions-due.md" {
  TODAY=$(date +%Y-%m-%d)
  DATE_5_DAYS_AGO=$(date_ago 5)
  DATE_10_DAYS_AGO=$(date_ago 10)

  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_5_DAYS_AGO", "text": "I predict success", "status": "open"},
  {"date": "$DATE_10_DAYS_AGO", "text": "Question: how?", "status": "open"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # .predictions-due.md should NOT exist
  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  [ ! -f "$DUE_FILE" ]
}

# ---------------------------------------------------------------------------
# Test 3: Stale .predictions-due.md removed when no current dues
# ---------------------------------------------------------------------------
@test "stale due file: existing .predictions-due.md removed when no dues" {
  # Create a stale .predictions-due.md
  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  echo "# Old due predictions" > "$DUE_FILE"

  # Create .predictions.json with only recent predictions
  DATE_5_DAYS_AGO=$(date_ago 5)
  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_5_DAYS_AGO", "text": "I predict", "status": "open"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Stale file should be removed
  [ ! -f "$DUE_FILE" ]
}

# ---------------------------------------------------------------------------
# Test 4: Status != "open" predictions excluded
# ---------------------------------------------------------------------------
@test "status filter: only status=open predictions included" {
  DATE_60_DAYS_AGO=$(date_ago 60)

  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict A", "status": "open"},
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict B", "status": "closed"},
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict C", "status": "resolved"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  [ -f "$DUE_FILE" ]

  # Only the open one should appear
  grep -q "I predict A" "$DUE_FILE"
  ! grep -q "I predict B" "$DUE_FILE"
  ! grep -q "I predict C" "$DUE_FILE"

  # Should mention "1 prediction"
  grep -q "1 prediction" "$DUE_FILE"
}

# ---------------------------------------------------------------------------
# Test 5: No .predictions.json file → script skips gracefully
# ---------------------------------------------------------------------------
@test "no predictions file: missing .predictions.json → skip with log" {
  # Don't create .predictions.json
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # No due file should be created
  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  [ ! -f "$DUE_FILE" ]

  # Log should have skip line
  LOG_FILE="$HOME_DIR/.claude/logs/cast-journal-predictions.log"
  [ -f "$LOG_FILE" ]
  grep -q "skip.*no predictions file" "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Test 6: CAST_JOURNAL_VAULT override honored
# ---------------------------------------------------------------------------
@test "CAST_JOURNAL_VAULT override: check uses override path" {
  OVERRIDE_VAULT="$BATS_TMPDIR/override-vault"
  mkdir -p "$OVERRIDE_VAULT"

  DATE_60_DAYS_AGO=$(date_ago 60)

  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict", "status": "open"}
]
with open('$OVERRIDE_VAULT/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run env CAST_JOURNAL_VAULT="$OVERRIDE_VAULT" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Due file should exist in override vault
  OVERRIDE_DUE="$OVERRIDE_VAULT/.predictions-due.md"
  [ -f "$OVERRIDE_DUE" ]

  # Should NOT exist in default vault
  DEFAULT_DUE="$VAULT_DIR/.predictions-due.md"
  [ ! -f "$DEFAULT_DUE" ]

  # Cleanup
  if [[ "$OVERRIDE_VAULT" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$OVERRIDE_VAULT"
  fi
}

# ---------------------------------------------------------------------------
# Test 7: CLAUDE_SUBPROCESS guard: no side effects
# ---------------------------------------------------------------------------
@test "CLAUDE_SUBPROCESS guard: exits 0 with no side effects" {
  DATE_60_DAYS_AGO=$(date_ago 60)
  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_60_DAYS_AGO", "text": "I predict", "status": "open"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run env CLAUDE_SUBPROCESS=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # No due file should be created
  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  [ ! -f "$DUE_FILE" ]
}

# ---------------------------------------------------------------------------
# Test 8: Boundary — exactly 30 days old → NOT included (d <= threshold check)
# ---------------------------------------------------------------------------
@test "boundary check: exactly 30 days old → included in due predictions" {
  DATE_30_DAYS_AGO=$(date_ago 30)

  python3 << PYEOF
import json
preds = [
  {"date": "$DATE_30_DAYS_AGO", "text": "I predict", "status": "open"}
]
with open('$VAULT_DIR/.predictions.json', 'w') as f:
  json.dump(preds, f, indent=2)
PYEOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  DUE_FILE="$VAULT_DIR/.predictions-due.md"
  # 30 days ago should be included (d <= threshold, where threshold = today - 30 days)
  [ -f "$DUE_FILE" ]
}
