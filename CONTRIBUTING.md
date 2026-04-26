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

**Hook script** (`scripts/cast-journal-session-end.sh`): The session-end reminder logic. Must output valid JSON with a `hookSpecificOutput` key to stdout. Test with:
```bash
bash scripts/cast-journal-session-end.sh | python3 -c "import sys,json; json.load(sys.stdin)"
```

**Rules file** (`rules/claudes_journal.md`): Guidelines Claude reads every session. Keep it concise — every line adds to the context window.

**Skill** (`skills/reflect/instructions.md`): The `/reflect` slash command. Edit steps or guidelines here.

**Settings merge** (`scripts/claudes_journal-merge-settings.sh`): Modifies `~/.claude/settings.json`. Test in a safe environment before submitting changes.

## PR Checklist

- [ ] `bash install.sh` runs cleanly (no `[fail]` lines)
- [ ] `bash -n scripts/cast-journal-session-end.sh` passes
- [ ] Hook script outputs valid JSON: `bash scripts/cast-journal-session-end.sh | python3 -m json.tool`
- [ ] No hardcoded paths — use `$HOME` or `~/` instead of `/Users/<username>/`
- [ ] `CHANGELOG.md` updated for any user-visible changes
