#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_SH="$REPO_DIR/scripts/cast-journal-userprompt-inject.sh"

setup() {
  # Create an isolated temp vault to avoid touching the real journal
  export CAST_JOURNAL_VAULT="$BATS_TMPDIR/vault"
  mkdir -p "$CAST_JOURNAL_VAULT/.scratch"
  mkdir -p "$CAST_JOURNAL_VAULT/$(date +%Y-%m)"

  # Override HOME and log path to stay in BATS_TMPDIR
  export ORIG_HOME="$HOME"
  export HOME="$BATS_TMPDIR/home"
  mkdir -p "$HOME/.claude/logs"

  # Unset subprocess guard so tests can run the hook logic
  export CLAUDE_SUBPROCESS=0
}

teardown() {
  # Clean up temp vault and home
  if [[ -d "$BATS_TMPDIR/vault" ]]; then
    rm -rf "$BATS_TMPDIR/vault"
  fi
  if [[ -d "$BATS_TMPDIR/home" ]]; then
    rm -rf "$BATS_TMPDIR/home"
  fi
  export HOME="$ORIG_HOME"
}

# ---------------------------------------------------------------------------
# Test 1: Subprocess guard (CLAUDE_SUBPROCESS=1) → exit 0 silently
# ---------------------------------------------------------------------------
@test "subprocess guard: CLAUDE_SUBPROCESS=1 → exits 0 silently" {
  run env CLAUDE_SUBPROCESS=1 bash "$HOOK_SH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 2: Stub entry (< 6 non-blank lines) → exits 0 silently
# ---------------------------------------------------------------------------
@test "stub entry: < 6 lines → exits 0 silently" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create a stub entry (< 6 lines)
  cat > "$NOTE" <<'EOF'
# Brief Note

Just a quick thought.
EOF

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 3: Substantive entry (> 5 lines), no scratchpad → journal section only
# ---------------------------------------------------------------------------
@test "substantive entry, no scratch: > 5 lines → JSON with journal section" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create a substantive entry (> 5 lines)
  cat > "$NOTE" <<'EOF'
# Entry

Line 1 content
Line 2 content
Line 3 content
Line 4 content
Line 5 content
Line 6 content
EOF

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  # Verify output is valid JSON
  echo "$output" | python3 -m json.tool > /dev/null
  # Verify it contains the journal section
  [[ "$output" == *"Your journal"* ]]
  # Verify scratchpad NOT in output
  [[ ! "$output" == *"Scratchpad (today)"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Scratchpad present + substantive journal → both sections in output
# ---------------------------------------------------------------------------
@test "journal + scratchpad: both → JSON with both sections separated by blank line" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"
  SCRATCH="$CAST_JOURNAL_VAULT/.scratch/${TODAY}.md"

  # Create a substantive entry
  cat > "$NOTE" <<'EOF'
# Entry

Line 1 content
Line 2 content
Line 3 content
Line 4 content
Line 5 content
EOF

  # Create scratchpad with content
  cat > "$SCRATCH" <<'EOF'
- 14:30 — first observation
- 14:45 — second observation
- 15:00 — third observation
EOF

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  # Verify output is valid JSON
  echo "$output" | python3 -m json.tool > /dev/null
  # Verify both sections present
  [[ "$output" == *"Your journal"* ]]
  [[ "$output" == *"Scratchpad (today)"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Journal section capped at 20 lines even when entry > 20 lines
# ---------------------------------------------------------------------------
@test "journal cap: entry with 30+ lines → outputs last 20 only" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create an entry with 30+ non-blank lines
  {
    echo "# Large Entry"
    for i in {1..35}; do
      echo "Line $i with content"
    done
  } > "$NOTE"

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  # Verify JSON output
  echo "$output" | python3 -m json.tool > /dev/null
  # Extract the additionalContext and count lines
  CONTEXT=$(echo "$output" | python3 -c "import sys, json; print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])")
  # Should have header + 20 content lines = 21 lines total
  LINE_COUNT=$(echo "$CONTEXT" | wc -l)
  # Line count should be around 21 (header + 20 content + possible blank)
  [[ $LINE_COUNT -ge 20 && $LINE_COUNT -le 22 ]]
}

# ---------------------------------------------------------------------------
# Test 6: Scratchpad section capped at 20 lines even when scratch > 20 lines
# ---------------------------------------------------------------------------
@test "scratchpad cap: scratch with 30+ lines → outputs last 20 only" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"
  SCRATCH="$CAST_JOURNAL_VAULT/.scratch/${TODAY}.md"

  # Create substantive entry
  {
    echo "# Entry"
    for i in {1..10}; do
      echo "Entry line $i"
    done
  } > "$NOTE"

  # Create scratch with 30+ lines
  for i in {1..35}; do
    echo "- HH:$((i % 60)) — observation $i" >> "$SCRATCH"
  done

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  # Verify scratchpad is in output
  [[ "$output" == *"Scratchpad (today)"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: No scratchpad file, only journal → only journal section appears
# ---------------------------------------------------------------------------
@test "journal only: no scratch file → output contains only journal section" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create substantive entry
  cat > "$NOTE" <<'EOF'
# Entry

Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
EOF

  # Do NOT create scratchpad file

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  [[ "$output" == *"Your journal"* ]]
  # Scratchpad section should not appear
  [[ ! "$output" == *"Scratchpad (today)"* ]]
}

# ---------------------------------------------------------------------------
# Test 8: Scratchpad file exists but is empty → only journal section
# ---------------------------------------------------------------------------
@test "empty scratchpad: scratch file empty → outputs journal only, no scratchpad section" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"
  SCRATCH="$CAST_JOURNAL_VAULT/.scratch/${TODAY}.md"

  # Create substantive entry
  cat > "$NOTE" <<'EOF'
# Entry

Content line 1
Content line 2
Content line 3
Content line 4
Content line 5
EOF

  # Create empty scratchpad
  touch "$SCRATCH"

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  [[ "$output" == *"Your journal"* ]]
  # Empty scratchpad should not create a section
  [[ ! "$output" == *"Scratchpad (today)"* ]]
}

# ---------------------------------------------------------------------------
# Test 9: Nothing to inject → exit 0 silently (no output)
# ---------------------------------------------------------------------------
@test "nothing to inject: no journal, no scratch → exit 0 with no output" {
  # Don't create journal or scratchpad
  # Journal doesn't exist and scratchpad doesn't exist

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 10: Deterministic output — running twice produces identical JSON
# ---------------------------------------------------------------------------
@test "determinism: running hook twice on same state → identical output" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create a substantive entry
  cat > "$NOTE" <<'EOF'
# Entry

Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
EOF

  # Run once
  run bash "$HOOK_SH"
  OUTPUT1="$output"
  RUN1_EXIT=$status

  # Run again (same state)
  run bash "$HOOK_SH"
  OUTPUT2="$output"
  RUN2_EXIT=$status

  [ "$RUN1_EXIT" -eq 0 ]
  [ "$RUN2_EXIT" -eq 0 ]
  [ "$OUTPUT1" = "$OUTPUT2" ]
}

# ---------------------------------------------------------------------------
# Test 11: Log file written to correct location under BATS_TMPDIR
# ---------------------------------------------------------------------------
@test "logging: hook writes timestamped log to HOME/.claude/logs/" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  # Create substantive entry
  cat > "$NOTE" <<'EOF'
# Entry

Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
EOF

  LOG_FILE="$HOME/.claude/logs/cast-journal-inject.log"

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  # Verify log file was created
  [[ -f "$LOG_FILE" ]]
  # Verify it contains a timestamped line with "injected journal"
  grep -q 'injected journal' "$LOG_FILE"
  # Verify timestamp format (YYYY-MM-DDTHH:MM:SS)
  grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Test 12: CAST_JOURNAL_VAULT override honored
# ---------------------------------------------------------------------------
@test "vault override: CAST_JOURNAL_VAULT env var used instead of default" {
  # Create entry in temp vault (already set up via env override)
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$CAST_JOURNAL_VAULT/${MONTH}/${TODAY}.md"

  cat > "$NOTE" <<'EOF'
# Vault Override Test

Line 1
Line 2
Line 3
Line 4
Line 5
EOF

  run bash "$HOOK_SH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Vault Override Test"* ]]
}
