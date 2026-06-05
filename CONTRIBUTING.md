# Contributing to Claude's Journal

## Prerequisites

- **Claude Code CLI** — `claude` must be on your PATH. That's all.
- No CAST required. No external dependencies.

## Quick Start

```bash
git clone https://github.com/ek33450505/cast-claudes_journal
cd cast-claudes_journal
bash install.sh
```

`install.sh` is idempotent — safe to re-run after pulling changes.

## How to Modify

**Hook scripts (3 total):**
- `scripts/cast-journal-session-end.sh` — Stop hook: session-end reminder with time-of-day guard and scratchpad distillation. Must output valid JSON with a `hookSpecificOutput` key. Test with:
  ```bash
  bash scripts/cast-journal-session-end.sh | python3 -c "import sys,json; json.load(sys.stdin)"
  ```
- `scripts/cast-session-start-journal.sh` — SessionStart hook: injects prior-day context, weekly nudge, missed-entry check, predictions-due alerts.
- `scripts/cast-journal-userprompt-inject.sh` — UserPromptSubmit hook: injects last 20 lines of today's journal + scratchpad at every turn.

**Rules file** (`rules/claudes_journal.md`): Guidelines Claude reads every session. Keep it concise — every line adds to the context window.

**Skills (3 total):**
- `skills/reflect/instructions.md` — `/reflect`: on-demand reflection entry.
- `skills/wrap/instructions.md` — `/wrap`: explicit session-end signal, bypasses time guards.
- `skills/note/instructions.md` — `/note [text]`: mid-session scratchpad append.

**Settings merge** (`scripts/claudes_journal-merge-settings.sh`): Modifies `~/.claude/settings.json`. Test in a safe environment before submitting changes.

## PR Checklist

- [ ] `bash install.sh` runs cleanly (no `[fail]` lines)
- [ ] `bash -n scripts/cast-journal-session-end.sh` passes (and same for the other two hook scripts)
- [ ] Hook scripts output valid JSON: `bash scripts/cast-journal-session-end.sh | python3 -m json.tool`
- [ ] No hardcoded paths — use `$HOME` or `~/` instead of `/Users/<username>/`
- [ ] `CHANGELOG.md` updated for any user-visible changes
- [ ] `VERSION` bumped if releasing
