#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
EOD_SCRIPT="$REPO_DIR/scripts/cast-journal-eod-flag.sh"

setup() {
  # Create an isolated temp HOME to avoid touching the real vault
  # Use BATS_TMPDIR (already writable in sandbox)
  export ORIG_HOME="$HOME"
  export HOME
  HOME="$BATS_TMPDIR/home"
  mkdir -p "$HOME/Documents/Claude/$(date +%Y-%m)"

  # Unset subprocess guard
  export CLAUDE_SUBPROCESS=0

  # Clean up any leaked eod flags from prior test runs
  TODAY="$(date +%Y-%m-%d)"
  rm -f "/tmp/cast_journal_eod_missed_${TODAY}"
}

teardown() {
  TODAY="$(date +%Y-%m-%d)"
  rm -f "/tmp/cast_journal_eod_missed_${TODAY}"
  rm -rf "$HOME"
  export HOME="$ORIG_HOME"
}

# ---------------------------------------------------------------------------
# Test 1: No entry → flag created
# ---------------------------------------------------------------------------
@test "flag created when no entry exists" {
  TODAY="$(date +%Y-%m-%d)"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

  # Ensure flag doesn't exist before the test
  rm -f "$FLAG"

  # Run the eod-flag script with isolated vault
  run bash "$EOD_SCRIPT"

  # Should exit 0
  [ "$status" -eq 0 ]

  # Flag should exist
  [[ -f "$FLAG" ]]
}

# ---------------------------------------------------------------------------
# Test 2: Entry exists with content → flag NOT created
# ---------------------------------------------------------------------------
@test "flag NOT created when entry exists with content" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

  # Create a note with content
  cat > "$NOTE" <<'EOF'
# Today's Entry

Some meaningful reflection.
This has content and will prevent the flag.
EOF

  # Ensure flag doesn't exist before the test
  rm -f "$FLAG"

  # Run the eod-flag script
  run bash "$EOD_SCRIPT"

  # Should exit 0
  [ "$status" -eq 0 ]

  # Flag should NOT exist
  [[ ! -f "$FLAG" ]]
}

# ---------------------------------------------------------------------------
# Test 3: Entry exists but empty → flag IS created
# ---------------------------------------------------------------------------
@test "flag created when entry exists but is empty" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

  # Create an empty note file
  touch "$NOTE"

  # Ensure flag doesn't exist before the test
  rm -f "$FLAG"

  # Run the eod-flag script
  run bash "$EOD_SCRIPT"

  # Should exit 0
  [ "$status" -eq 0 ]

  # Flag SHOULD exist (empty file is treated as missing)
  [[ -f "$FLAG" ]]
}

# ---------------------------------------------------------------------------
# Test 4: Idempotent re-runs (no entry) → flag created/recreated safely
# ---------------------------------------------------------------------------
@test "idempotent re-runs: script handles flag recreation without error" {
  TODAY="$(date +%Y-%m-%d)"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

  # Ensure flag doesn't exist initially
  rm -f "$FLAG"

  # First run
  run bash "$EOD_SCRIPT"
  [ "$status" -eq 0 ]
  [[ -f "$FLAG" ]]
  FIRST_MTIME=$(stat -f '%m' "$FLAG" 2>/dev/null || stat -c '%Y' "$FLAG")

  # Wait a moment to ensure different mtime
  sleep 0.1

  # Second run (should recreate flag or leave it alone without error)
  run bash "$EOD_SCRIPT"
  [ "$status" -eq 0 ]
  [[ -f "$FLAG" ]]
  SECOND_MTIME=$(stat -f '%m' "$FLAG" 2>/dev/null || stat -c '%Y' "$FLAG")

  # Either the flag was recreated or left alone — either is acceptable
  # The key: no error occurred
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: Subprocess guard (CLAUDE_SUBPROCESS=1) → exits 0 silently
# ---------------------------------------------------------------------------
@test "subprocess guard: CLAUDE_SUBPROCESS=1 → exits 0 silently" {
  TODAY="$(date +%Y-%m-%d)"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"
  rm -f "$FLAG"

  run env CLAUDE_SUBPROCESS=1 bash "$EOD_SCRIPT"

  [ "$status" -eq 0 ]
  # Flag should NOT be created when subprocess guard blocks execution
  [[ ! -f "$FLAG" ]]
}

# ---------------------------------------------------------------------------
# Test 6: Note with only whitespace → treated as empty, flag created
# ---------------------------------------------------------------------------
@test "whitespace-only note treated as empty → flag created" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"
  FLAG="/tmp/cast_journal_eod_missed_${TODAY}"

  # Create a note with only whitespace
  cat > "$NOTE" <<'EOF'



EOF

  rm -f "$FLAG"

  run bash "$EOD_SCRIPT"

  [ "$status" -eq 0 ]
  # Flag should exist because the file has no non-whitespace content
  [[ -f "$FLAG" ]]
}
