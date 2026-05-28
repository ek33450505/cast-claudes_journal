#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/cast-journal-weekly-synthesis.sh"

setup() {
  # Create isolated tmpdir with subdirs
  VAULT_DIR="$BATS_TMPDIR/vault"
  mkdir -p "$VAULT_DIR/2026-05"

  # Create mock claude binary
  MOCK_BIN="$BATS_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/claude" <<'MOCK_EOF'
#!/usr/bin/env bash
# Mock claude binary — reads stdin, writes canned synthesis
cat > /dev/null  # consume stdin
echo "SYNTHESIS_MOCK_OUTPUT"
exit 0
MOCK_EOF
  chmod +x "$MOCK_BIN/claude"

  # Create HOME and logs directories
  HOME_DIR="$BATS_TMPDIR/home"
  mkdir -p "$HOME_DIR/.claude/logs"

  # Export env overrides for this test
  export PATH="$MOCK_BIN:$PATH"
  export CAST_JOURNAL_VAULT="$VAULT_DIR"
  export HOME="$HOME_DIR"
  export TMP="$BATS_TMPDIR/tmp"
  mkdir -p "$TMP"
}

teardown() {
  # Guarded cleanup — only delete under BATS_TMPDIR
  if [[ "$VAULT_DIR" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$VAULT_DIR"
  fi
  if [[ "$MOCK_BIN" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$MOCK_BIN"
  fi
  if [[ "$HOME_DIR" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$HOME_DIR"
  fi
  if [[ "$TMP" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$TMP"
  fi
}

# ---------------------------------------------------------------------------
# Test 1: With claude mock + 3 entries → weekly-<TODAY>.md written
# ---------------------------------------------------------------------------
@test "with claude mock + 3 entries: weekly synthesis file created" {
  # Create 3 dummy entries
  echo "# Entry 1" > "$VAULT_DIR/2026-05/2026-05-01.md"
  echo "# Entry 2" > "$VAULT_DIR/2026-05/2026-05-02.md"
  echo "# Entry 3" > "$VAULT_DIR/2026-05/2026-05-03.md"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Output file should exist
  TODAY=$(date +%Y-%m-%d)
  MONTH=$(date +%Y-%m)
  OUT_FILE="$VAULT_DIR/$MONTH/weekly-${TODAY}.md"
  [ -f "$OUT_FILE" ]

  # Content should include mock output
  grep -q "SYNTHESIS_MOCK_OUTPUT" "$OUT_FILE"

  # Title should be present
  grep -q "# Weekly synthesis" "$OUT_FILE"
}

# ---------------------------------------------------------------------------
# Test 2: With claude mock + 1 entry only → no output file (threshold)
# ---------------------------------------------------------------------------
@test "with 1 entry only: no synthesis written (requires >= 2 entries)" {
  # Create only 1 entry
  echo "# Entry 1" > "$VAULT_DIR/2026-05/2026-05-01.md"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Output file should NOT exist
  TODAY=$(date +%Y-%m-%d)
  MONTH=$(date +%Y-%m)
  OUT_FILE="$VAULT_DIR/$MONTH/weekly-${TODAY}.md"
  [ ! -f "$OUT_FILE" ]

  # Log should have skip line
  LOG_FILE="$HOME_DIR/.claude/logs/cast-journal-synthesis.log"
  [ -f "$LOG_FILE" ]
  grep -q "skip.*only 1 entries" "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Test 3: claude NOT on PATH → no output, exit 0, log present
# ---------------------------------------------------------------------------
@test "without claude CLI on PATH: exits 0, no output file, log skip line" {
  # Create 3 entries for this test
  echo "# Entry 1" > "$VAULT_DIR/2026-05/2026-05-01.md"
  echo "# Entry 2" > "$VAULT_DIR/2026-05/2026-05-02.md"
  echo "# Entry 3" > "$VAULT_DIR/2026-05/2026-05-03.md"

  # Override PATH to exclude the mock
  run env PATH="/usr/bin:/bin" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Output file should NOT exist
  TODAY=$(date +%Y-%m-%d)
  MONTH=$(date +%Y-%m)
  OUT_FILE="$VAULT_DIR/$MONTH/weekly-${TODAY}.md"
  [ ! -f "$OUT_FILE" ]

  # Log should have skip line
  LOG_FILE="$HOME_DIR/.claude/logs/cast-journal-synthesis.log"
  [ -f "$LOG_FILE" ]
  grep -q "skip.*claude CLI not on PATH" "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Test 4: CAST_JOURNAL_VAULT override honored
# ---------------------------------------------------------------------------
@test "CAST_JOURNAL_VAULT override: output written under override path" {
  OVERRIDE_VAULT="$BATS_TMPDIR/override-vault"
  mkdir -p "$OVERRIDE_VAULT/2026-05"

  # Create entries in override vault
  echo "# Entry 1" > "$OVERRIDE_VAULT/2026-05/2026-05-01.md"
  echo "# Entry 2" > "$OVERRIDE_VAULT/2026-05/2026-05-02.md"

  # Run with override
  run env CAST_JOURNAL_VAULT="$OVERRIDE_VAULT" PATH="$MOCK_BIN:$PATH" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # File should exist in override vault, not default
  TODAY=$(date +%Y-%m-%d)
  MONTH=$(date +%Y-%m)
  OUT_FILE="$OVERRIDE_VAULT/$MONTH/weekly-${TODAY}.md"
  [ -f "$OUT_FILE" ]

  # Should not exist in original CAST_JOURNAL_VAULT
  [ ! -f "$VAULT_DIR/$MONTH/weekly-${TODAY}.md" ]

  # Cleanup
  if [[ "$OVERRIDE_VAULT" == "$BATS_TMPDIR"/* ]]; then
    rm -rf "$OVERRIDE_VAULT"
  fi
}

# ---------------------------------------------------------------------------
# Test 5: CLAUDE_SUBPROCESS guard: exits 0, no output
# ---------------------------------------------------------------------------
@test "CLAUDE_SUBPROCESS guard: exits 0 silently with no side effects" {
  # Create 3 entries
  echo "# Entry 1" > "$VAULT_DIR/2026-05/2026-05-01.md"
  echo "# Entry 2" > "$VAULT_DIR/2026-05/2026-05-02.md"
  echo "# Entry 3" > "$VAULT_DIR/2026-05/2026-05-03.md"

  run env CLAUDE_SUBPROCESS=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # No output file should be created
  TODAY=$(date +%Y-%m-%d)
  MONTH=$(date +%Y-%m)
  OUT_FILE="$VAULT_DIR/$MONTH/weekly-${TODAY}.md"
  [ ! -f "$OUT_FILE" ]
}
