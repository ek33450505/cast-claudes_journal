#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/cast-journal-extract-predictions.sh"

setup() {
  VAULT_DIR="$BATS_TMPDIR/vault"
  mkdir -p "$VAULT_DIR/2026-05"

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
# Test 1: Entries with predictions → JSON contains correct objects
# ---------------------------------------------------------------------------
@test "entries with predictions: .predictions.json contains all matches" {
  # Create 4 entries: 3 with matches, 1 without
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
# Entry 1
I predict the weather will be sunny tomorrow.
Some other text here.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-02.md" <<'EOF'
# Entry 2
Open thread: should we refactor the auth system?
More notes.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-03.md" <<'EOF'
# Entry 3
Question: how many users are on premium?
Another line.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-04.md" <<'EOF'
# Entry 4
Just some random notes.
No predictions here.
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # JSON file should exist
  PRED_FILE="$VAULT_DIR/.predictions.json"
  [ -f "$PRED_FILE" ]

  # Should have 3 objects (one per matching line)
  COUNT=$(python3 -c "import json; d = json.load(open('$PRED_FILE')); print(len(d))")
  [ "$COUNT" -eq 3 ]

  # Check that the 3 expected lines are present
  python3 << PYEOF
import json
with open('$PRED_FILE') as f:
  preds = json.load(f)
texts = [p['text'] for p in preds]
assert 'I predict the weather will be sunny tomorrow.' in texts
assert 'Open thread: should we refactor the auth system?' in texts
assert 'Question: how many users are on premium?' in texts
PYEOF
  [ "$?" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 2: Idempotency — running twice does NOT duplicate
# ---------------------------------------------------------------------------
@test "idempotency: running twice does not duplicate entries" {
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
I predict tomorrow will be good.
EOF

  # First run
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  PRED_FILE="$VAULT_DIR/.predictions.json"
  COUNT_1=$(python3 -c "import json; d = json.load(open('$PRED_FILE')); print(len(d))")
  [ "$COUNT_1" -eq 1 ]

  # Second run
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  COUNT_2=$(python3 -c "import json; d = json.load(open('$PRED_FILE')); print(len(d))")
  [ "$COUNT_2" -eq 1 ]

  # Content should be identical
  python3 << PYEOF
import json
with open('$PRED_FILE') as f:
  preds = json.load(f)
assert len(preds) == 1
assert preds[0]['text'] == 'I predict tomorrow will be good.'
assert preds[0]['status'] == 'open'
PYEOF
  [ "$?" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 3: Case-insensitive matching
# ---------------------------------------------------------------------------
@test "case-insensitive: I PREDICT, i predict, QUESTION:, etc. all match" {
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
I PREDICT tomorrow is good.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-02.md" <<'EOF'
i predict nothing.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-03.md" <<'EOF'
QUESTION: should we?
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-04.md" <<'EOF'
I expect good outcomes.
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  PRED_FILE="$VAULT_DIR/.predictions.json"
  COUNT=$(python3 -c "import json; d = json.load(open('$PRED_FILE')); print(len(d))")
  [ "$COUNT" -eq 4 ]
}

# ---------------------------------------------------------------------------
# Test 4: Entries without matches → file remains []
# ---------------------------------------------------------------------------
@test "no matches: entries without prediction patterns → .predictions.json is []" {
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
Just some normal journaling.
No predictions or open threads here.
EOF

  cat > "$VAULT_DIR/2026-05/2026-05-02.md" <<'EOF'
More text.
Random notes.
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  PRED_FILE="$VAULT_DIR/.predictions.json"
  [ -f "$PRED_FILE" ]

  # File should be empty array
  python3 << PYEOF
import json
with open('$PRED_FILE') as f:
  preds = json.load(f)
assert preds == []
PYEOF
  [ "$?" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: CAST_JOURNAL_VAULT override honored
# ---------------------------------------------------------------------------
@test "CAST_JOURNAL_VAULT override: predictions written to override path" {
  OVERRIDE_VAULT="$BATS_TMPDIR/override-vault"
  mkdir -p "$OVERRIDE_VAULT/2026-05"

  cat > "$OVERRIDE_VAULT/2026-05/2026-05-01.md" <<'EOF'
I predict success.
EOF

  run env CAST_JOURNAL_VAULT="$OVERRIDE_VAULT" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # File should exist in override vault
  OVERRIDE_PRED="$OVERRIDE_VAULT/.predictions.json"
  [ -f "$OVERRIDE_PRED" ]

  # Should NOT exist in default vault
  DEFAULT_PRED="$VAULT_DIR/.predictions.json"
  [ ! -f "$DEFAULT_PRED" ]

  # Content should be correct
  python3 << PYEOF
import json
with open('$OVERRIDE_PRED') as f:
  preds = json.load(f)
assert len(preds) == 1
assert 'I predict success.' in preds[0]['text']
PYEOF
  [ "$?" -eq 0 ]

  # Cleanup
  if [[ "$OVERRIDE_VAULT" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$OVERRIDE_VAULT"
  fi
}

# ---------------------------------------------------------------------------
# Test 6: CLAUDE_SUBPROCESS guard: no side effects
# ---------------------------------------------------------------------------
@test "CLAUDE_SUBPROCESS guard: exits 0 with no side effects" {
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
I predict something.
EOF

  run env CLAUDE_SUBPROCESS=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # No JSON file should be created
  PRED_FILE="$VAULT_DIR/.predictions.json"
  [ ! -f "$PRED_FILE" ]
}

# ---------------------------------------------------------------------------
# Test 7: Multiple lines in same entry — all matches captured
# ---------------------------------------------------------------------------
@test "multiple matches in one entry: all lines captured" {
  cat > "$VAULT_DIR/2026-05/2026-05-01.md" <<'EOF'
# Session Notes

I predict good weather.
Some content.
Question: should we hire?
More text.
Open thread: design review needed.
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  PRED_FILE="$VAULT_DIR/.predictions.json"
  COUNT=$(python3 -c "import json; d = json.load(open('$PRED_FILE')); print(len(d))")
  [ "$COUNT" -eq 3 ]
}
