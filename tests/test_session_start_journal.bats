#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/cast-session-start-journal.sh"

setup() {
  TMPDIR="$(mktemp -d)"
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

  run env HOME="$TMPDIR" bash "$SCRIPT"
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

  run env HOME="$TMPDIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Must contain the May entry date, not January or March
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'])")
  [[ "$CONTEXT" == *"May 04, 2026"* ]]
  [[ "$CONTEXT" != *"January"* ]]
  [[ "$CONTEXT" != *"March"* ]]
}
