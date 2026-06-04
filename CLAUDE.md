# cast-claudes_journal

## Install
```bash
bash install.sh          # interactive; use --yes for CI/unattended
bash uninstall.sh        # reverses install
```
Install copies scripts to `~/.claude/scripts/`, rules to `~/.claude/rules/`, and merges hook entries into `~/.claude/settings.json`. Optionally installs cron jobs for weekly MOC rebuild, synthesis, and prediction tracking (all Sunday 09:00).

## Test
```bash
bats tests/              # 9 .bats files, one per script
```
Tests MUST isolate via a temp HOME — never run against real `$HOME` (the scripts touch `~/.claude/` and the vault).

## Non-obvious
- **Vault path:** defaults to `~/Documents/Claude/`; override with `CAST_JOURNAL_VAULT=/path/to/vault` before running any script.
- **Script naming:** all hook scripts follow `cast-journal-<event>.sh`; the session-start hook is `cast-session-start-journal.sh` (no `journal-` prefix inversion).
- **`article/` directory:** contains an unpublished draft — not part of the shipped product; do not install or reference it.
- **CHANGELOG:** stalled at v0.2.0; Phase 3 features are shipped but undocumented there — do not rely on it for feature inventory.
- **Hook wiring:** `install.sh` calls `claudes_journal-merge-settings.sh` to patch `~/.claude/settings.json`. If that merge is skipped, the session-end and session-start hooks are not active even though the scripts are copied.
