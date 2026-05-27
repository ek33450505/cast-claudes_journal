#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_SH="$REPO_DIR/scripts/cast-journal-session-end.sh"

setup() {
  # Create an isolated temp HOME and TMP to avoid touching the real vault
  # Use BATS_TMPDIR (already writable in sandbox)
  export ORIG_HOME="$HOME"
  export ORIG_TMP="${TMP:-}"
  export HOME
  export TMP="$BATS_TMPDIR/tmp"
  mkdir -p "$TMP"
  HOME="$BATS_TMPDIR/home"
  mkdir -p "$HOME/Documents/Claude/$(date +%Y-%m)"

  # Unset subprocess guard so tests can actually run the hook logic
  export CLAUDE_SUBPROCESS=0
  export CLAUDE_SESSION_ID="test-session-$$-$RANDOM"

  # Clean up any leaked state from prior runs
  TODAY="$(date +%Y-%m-%d)"
  rm -f "$TMP/cast_journal_wrap_${TODAY}"
  rm -f "$TMP/cast_journal_cancelled_${TODAY}"
  rm -f "$TMP/cast_journal_session_${CLAUDE_SESSION_ID}"
}

teardown() {
  TODAY="$(date +%Y-%m-%d)"
  rm -f "$TMP/cast_journal_wrap_${TODAY}"
  rm -f "$TMP/cast_journal_cancelled_${TODAY}"
  rm -f "$TMP/cast_journal_session_${CLAUDE_SESSION_ID}"
  rm -rf "$BATS_TMPDIR/tmp" "$BATS_TMPDIR/home"
  export HOME="$ORIG_HOME"
  export TMP="${ORIG_TMP}"
}

# ---------------------------------------------------------------------------
# Test 1: Early-hour guard (before 15:00, no entry, no wrap) → exit 0 silently
# ---------------------------------------------------------------------------
@test "early-hour guard: CURRENT_HOUR < 15 → exits 0 silently" {
  # Stub date to return 10 (< 15)
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%H" ]]; then
  echo "10"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Should exit cleanly with no output
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 2: Wrap-flag override of time guard → wrap flag bypasses 15:00 guard
# ---------------------------------------------------------------------------
@test "wrap-flag override: CURRENT_HOUR=10 + wrap flag → emits prompt" {
  TODAY="$(date +%Y-%m-%d)"
  WRAP_FLAG="$TMP/cast_journal_wrap_${TODAY}"
  touch "$WRAP_FLAG"

  # Stub date to return 10 (before 15:00)
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%H" ]]; then
  echo "10"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Should emit a prompt (JSON with "decision": "block")
  [[ "$output" == *"block"* ]]
  [[ "$output" == *"decision"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Stub-entry deepening → brief entry + hour >= 18 → deepening prompt
# ---------------------------------------------------------------------------
@test "stub-entry deepening: brief entry + CURRENT_HOUR >= 18 → deepening prompt" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"

  # Create a stub entry (< 25 lines)
  cat > "$NOTE" <<'EOF'
# Brief Entry

Just a quick note.
EOF

  # Stub date to return 19 (>= 18)
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%H" ]]; then
  echo "19"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Should emit a block with "brief" in the message (deepening prompt)
  [[ "$output" == *"block"* ]]
  [[ "$output" == *"brief"* || "$output" == *"Brief"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Substantive-entry exit → >= 25 lines → exits 0 silently
# ---------------------------------------------------------------------------
@test "substantive-entry exit: >= 25 lines → exits 0 silently" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"

  # Create a substantive entry (>= 25 non-blank lines)
  cat > "$NOTE" <<'EOF'
# Substantive Entry

Line 3 with content
Line 4 with content
Line 5 with content
Line 6 with content
Line 7 with content
Line 8 with content
Line 9 with content
Line 10 with content
Line 11 with content
Line 12 with content
Line 13 with content
Line 14 with content
Line 15 with content
Line 16 with content
Line 17 with content
Line 18 with content
Line 19 with content
Line 20 with content
Line 21 with content
Line 22 with content
Line 23 with content
Line 24 with content
Line 25 with content
Line 26 with content
EOF

  # Any hour should work for substantive entry
  run bash "$HOOK_SH"

  # Should exit 0 silently (no prompt)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 5: Wrap-flag cleanup of stale flags
# ---------------------------------------------------------------------------
@test "wrap-flag cleanup: flags older than 1 day are removed" {
  # Create a stale wrap flag with very old mtime
  OLD_WRAP="$TMP/cast_journal_wrap_2020-01-01"
  touch "$OLD_WRAP"
  touch -t "202001010000" "$OLD_WRAP"

  # No wrap flag for today, no entry → script will prompt
  TODAY="$(date +%Y-%m-%d)"
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%H" ]]; then
  echo "18"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Old flag should be gone
  [[ ! -f "$OLD_WRAP" ]]
}

# ---------------------------------------------------------------------------
# Test 6: Happy path — no entry + after 15:00 + no wrap → journal prompt
# ---------------------------------------------------------------------------
@test "happy path: no entry + CURRENT_HOUR >= 15 → journal prompt" {
  # Stub date to return 18 (>= 15 and >= 18)
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%H" ]]; then
  echo "18"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Should emit a journal entry prompt
  [[ "$output" == *"block"* ]]
  [[ "$output" == *"decision"* ]]
  [[ "$output" == *"No journal entry written today"* || "$output" == *"no journal entry"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Subprocess guard (CLAUDE_SUBPROCESS=1) → exit 0 silently
# ---------------------------------------------------------------------------
@test "subprocess guard: CLAUDE_SUBPROCESS=1 → exits 0 silently" {
  run env CLAUDE_SUBPROCESS=1 bash "$HOOK_SH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Test 8: No HOME set → exits 0 silently
# ---------------------------------------------------------------------------
@test "no HOME: exits 0 silently" {
  run env -u HOME bash "$HOOK_SH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
