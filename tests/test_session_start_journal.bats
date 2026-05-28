#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/cast-session-start-journal.sh"

setup() {
  TMPDIR="$BATS_TMPDIR/home_$$"
  mkdir -p "$TMPDIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# Test 1: CLAUDE_SUBPROCESS=1 → empty output, exit 0
# ---------------------------------------------------------------------------
@test "subprocess guard: CLAUDE_SUBPROCESS=1 exits 0 silently" {
  run env CLAUDE_SUBPROCESS=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 2: No vault dir → exits 0 with fallback JSON
# ---------------------------------------------------------------------------
@test "no vault dir: exits 0 with fallback JSON" {
  # TMPDIR has no Documents/Claude at all
  run env HOME="$TMPDIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Must be valid JSON with warning systemMessage
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
  MESSAGE=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['systemMessage'])")
  [[ "$MESSAGE" == *"not found or empty"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Vault dir exists but no matching files → exits 0 with fallback JSON
# ---------------------------------------------------------------------------
@test "empty vault: vault dir exists but no entries → exits 0 with fallback JSON" {
  mkdir -p "$TMPDIR/Documents/Claude"
  run env HOME="$TMPDIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Must be valid JSON with warning systemMessage
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
  MESSAGE=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['systemMessage'])")
  [[ "$MESSAGE" == *"not found or empty"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Valid entry emits correct hookSpecificOutput shape
# ---------------------------------------------------------------------------
@test "valid entry: emits hookSpecificOutput JSON with SessionStart and date" {
  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Session Notes 2026-05-04

Worked on the journal hook wiring.

---
EOF

  run env HOME="$TMPDIR" TMP="$BATS_TMPDIR/tmp" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Must be valid JSON
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"

  # hookEventName must be SessionStart
  EVENT_NAME=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['hookEventName'])")
  [ "$EVENT_NAME" = "SessionStart" ]

  # additionalContext must contain the pretty date
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT" == *"May 04, 2026"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Lexical sort correctness — newest YYYY-MM-DD wins
# ---------------------------------------------------------------------------
@test "lexical sort: newest entry wins across months" {
  mkdir -p "$TMPDIR/Documents/Claude/2026-01"
  mkdir -p "$TMPDIR/Documents/Claude/2026-03"
  mkdir -p "$TMPDIR/Documents/Claude/2026-05"

  echo "# January entry" > "$TMPDIR/Documents/Claude/2026-01/2026-01-15.md"
  echo "# March entry" > "$TMPDIR/Documents/Claude/2026-03/2026-03-22.md"
  echo "# May entry" > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md"

  run env HOME="$TMPDIR" TMP="$BATS_TMPDIR/tmp" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Must contain the May entry date, not January or March
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT" == *"May 04, 2026"* ]]
  [[ "$CONTEXT" != *"January"* ]]
  [[ "$CONTEXT" != *"March"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Ed-observation nudge appears when sentinel does not exist
# ---------------------------------------------------------------------------
@test "ed-nudge: nudge line appears in output when sentinel absent" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry for nudge test

Content here.
EOF

  # Override /tmp to use BATS_TEST_TMPDIR (no pre-existing sentinel)
  export TMP="$BATS_TEST_TMPDIR/tmp"

  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"

  [ "$status" -eq 0 ]

  # Ed-nudge line must appear
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT" == *"When you notice something about Ed today"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Ed-nudge is suppressed on second run (same week)
# ---------------------------------------------------------------------------
@test "ed-nudge: nudge suppressed on second run (same YYYYWW)" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry for nudge test

Content here.
EOF

  export TMP="$BATS_TEST_TMPDIR/tmp"

  # First run — nudge should appear
  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  CONTEXT_1=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT_1" == *"When you notice something about Ed today"* ]]

  # Second run (same week) — nudge should NOT appear
  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  CONTEXT_2=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT_2" != *"When you notice something about Ed today"* ]]
}

# ---------------------------------------------------------------------------
# Test 8: Removing sentinel and changing week causes nudge to reappear
# ---------------------------------------------------------------------------
@test "ed-nudge: nudge reappears after removing sentinel and advancing week" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry for nudge test

Content here.
EOF

  export TMP="$BATS_TEST_TMPDIR/tmp"

  # First run — nudge appears and sentinel created
  WEEK_NUM_1=$(date +%Y%W)
  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  CONTEXT_1=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT_1" == *"When you notice something about Ed today"* ]]

  # Sentinel file should exist
  [ -f "$TMP/cast_journal_ed_nudge_${WEEK_NUM_1}" ]

  # Mock date to return a different week number
  FAKE_BIN="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%Y%W" ]]; then
  echo "202699"  # Different week number
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  # Second run with mocked date showing different week
  run env HOME="$TMPDIR" TMP="$TMP" PATH="$FAKE_BIN:$PATH" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  CONTEXT_2=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")

  # New week sentinel should not exist yet, so nudge should appear
  [[ "$CONTEXT_2" == *"When you notice something about Ed today"* ]]

  rm -rf "$FAKE_BIN"
}

# ---------------------------------------------------------------------------
# Test 9: .predictions-due.md present → SessionStart includes its content
# ---------------------------------------------------------------------------
@test "predictions injection: .predictions-due.md present → content injected into context" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry for predictions test

Content here.
EOF

  # Create .predictions-due.md
  cat > "$TMPDIR/Documents/Claude/.predictions-due.md" <<'EOF'
# Predictions due for check-in

_2 prediction(s) older than 30 days — consider revisiting in today's entry._

- **2026-04-01** — I predict we'll finish refactoring
- **2026-04-05** — Question: should we upgrade Node?
EOF

  export TMP="$BATS_TEST_TMPDIR/tmp"

  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Context should include predictions section
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT" == *"Predictions due for check-in"* ]]
  [[ "$CONTEXT" == *"I predict we'll finish refactoring"* ]]
  [[ "$CONTEXT" == *"Question: should we upgrade Node?"* ]]
}

# ---------------------------------------------------------------------------
# Test 10: .predictions-due.md deleted after SessionStart reads it
# ---------------------------------------------------------------------------
@test "predictions cleanup: .predictions-due.md removed after hook runs" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry

Content.
EOF

  # Create .predictions-due.md
  cat > "$TMPDIR/Documents/Claude/.predictions-due.md" <<'EOF'
# Predictions due for check-in

_1 prediction(s) older than 30 days._

- **2026-04-01** — I predict
EOF

  export TMP="$BATS_TEST_TMPDIR/tmp"

  # File should exist before run
  [ -f "$TMPDIR/Documents/Claude/.predictions-due.md" ]

  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # File should be deleted after run
  [ ! -f "$TMPDIR/Documents/Claude/.predictions-due.md" ]
}

# ---------------------------------------------------------------------------
# Test 11: .predictions-due.md absent → SessionStart output unchanged
# ---------------------------------------------------------------------------
@test "predictions absent: .predictions-due.md missing → no predictions section in output" {
  set -euo pipefail

  mkdir -p "$TMPDIR/Documents/Claude/2026-05"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"

  cat > "$TMPDIR/Documents/Claude/2026-05/2026-05-04.md" <<'EOF'
# Entry

Content.
EOF

  # Do NOT create .predictions-due.md

  export TMP="$BATS_TEST_TMPDIR/tmp"

  run env HOME="$TMPDIR" TMP="$TMP" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")

  # Should not contain predictions section
  [[ "$CONTEXT" != *"Predictions due for check-in"* ]]

  # Should still have the entry section
  [[ "$CONTEXT" == *"Last Claude's Journal Entry"* ]]
}
