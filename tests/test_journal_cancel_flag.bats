#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_SH="$REPO_DIR/scripts/cast-journal-session-end.sh"

setup() {
  # Redirect HOME so the script writes to a temp vault
  export ORIG_HOME="$HOME"
  export HOME
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/Documents/Claude/$(date +%Y-%m)"

  # Use a unique session ID per test
  export CLAUDE_SESSION_ID="test-session-$$-$RANDOM"
  export CLAUDE_SUBPROCESS=""

  # Remove any real cancel or session flags that might bleed in
  TODAY="$(date +%Y-%m-%d)"
  rm -f "/tmp/cast_journal_cancelled_${TODAY}"
  rm -f "/tmp/cast_journal_session_${CLAUDE_SESSION_ID}"
}

teardown() {
  TODAY="$(date +%Y-%m-%d)"
  rm -f "/tmp/cast_journal_cancelled_${TODAY}"
  rm -f "/tmp/cast_journal_session_${CLAUDE_SESSION_ID}"
  rm -rf "$HOME"
  export HOME="$ORIG_HOME"
}

# ---------------------------------------------------------------------------
# Test 1: cancel flag + no entry + hour >= 18 → re-prompt (cancel flag cleared)
# ---------------------------------------------------------------------------
@test "cancel flag + no entry + after 18:00 → re-prompt occurs" {
  TODAY="$(date +%Y-%m-%d)"
  touch "/tmp/cast_journal_cancelled_${TODAY}"

  # Stub date to return hour 19 (>= 18)
  # We wrap the script with a PATH-prepended fake date binary
  FAKE_BIN="$(mktemp -d)"
  cat > "$FAKE_BIN/date" <<'DATEEOF'
#!/usr/bin/env bash
# Return hour 19 when called with +%H, delegate everything else to real date
if [[ "${1:-}" == "+%H" ]]; then
  echo "19"
  exit 0
fi
exec /bin/date "$@"
DATEEOF
  chmod +x "$FAKE_BIN/date"

  run env PATH="$FAKE_BIN:$PATH" bash "$HOOK_SH"

  rm -rf "$FAKE_BIN"

  # Script should have fallen through to re-prompt — output contains "block"
  [[ "$output" == *"block"* ]]
  # Cancel flag should have been cleared then re-set (re-prompt path sets it again)
  # The key assertion: the script did NOT exit silently (output is non-empty)
  [[ -n "$output" ]]
}

# ---------------------------------------------------------------------------
# Test 2: cancel flag + entry exists → honor flag, exit silently
# ---------------------------------------------------------------------------
@test "cancel flag + entry exists → honor flag, no re-prompt" {
  TODAY="$(date +%Y-%m-%d)"
  MONTH="$(date +%Y-%m)"
  TODAY_NOTE="$HOME/Documents/Claude/${MONTH}/${TODAY}.md"

  # Write a real journal entry
  echo "# Today's entry" > "$TODAY_NOTE"

  # Set cancel flag
  touch "/tmp/cast_journal_cancelled_${TODAY}"

  run bash "$HOOK_SH"

  # Should exit silently — no block output
  [[ -z "$output" ]]
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 3: second call same session → honor flag always (session marker present)
# ---------------------------------------------------------------------------
@test "second call same session → honor flag regardless of hour or entry" {
  TODAY="$(date +%Y-%m-%d)"
  touch "/tmp/cast_journal_cancelled_${TODAY}"
  # Simulate "already prompted once this session" by pre-creating the session marker
  touch "/tmp/cast_journal_session_${CLAUDE_SESSION_ID}"

  run bash "$HOOK_SH"

  # Should exit silently regardless
  [[ -z "$output" ]]
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 4 (bonus): old cancel flags cleaned at script start
# ---------------------------------------------------------------------------
@test "cancel flags older than 1 day are cleaned at script start" {
  # Create a cancel flag with yesterday's date name and force mtime to >1 day ago
  OLD_FLAG="/tmp/cast_journal_cancelled_2020-01-01"
  touch "$OLD_FLAG"
  touch -t "202001010000" "$OLD_FLAG"  # set mtime to 2020-01-01 (far in the past)

  # No cancel flag for today — script will prompt and produce output
  run bash "$HOOK_SH"

  # Old flag should be gone
  [[ ! -f "$OLD_FLAG" ]]
}
