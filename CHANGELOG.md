# Claude's Journal Changelog

## [0.3.1] — 2026-07-01

### Changed
- v9 ecosystem sync: version bump for the CAST v9 ecosystem consolidation.
- Corrected the public description to reflect the full feature set — three hooks (Stop / SessionStart / UserPromptSubmit) and three skills (`/reflect`, `/wrap`, `/note`), not just `/reflect`.

## [0.3.0] — 2026-06-05

### Added
- **Phase 3: Weekly synthesis + prediction tracking**
  - `cast-journal-weekly-synthesis.sh` — pipes last 7 entries to `claude --print` for 200–300 word synthesis (Sunday cron, requires `claude` CLI)
  - `cast-journal-extract-predictions.sh` — nightly extraction of `/predict` and `/question` entries (daily 23:45 cron)
  - `cast-journal-check-predictions.sh` — surfaces 30+ day-old open predictions via SessionStart alert (Sunday 09:05 cron)
- **Phase 2: Working memory scratchpad + UserPromptSubmit injection**
  - `cast-journal-userprompt-inject.sh` — UserPromptSubmit hook: injects last 20 lines of today's journal + scratchpad at every turn (capped at 40 combined lines)
  - Scratchpad at `$VAULT/.scratch/<DATE>.md` with marker-fence preservation
- **`/wrap` skill** — explicit session-end signal, bypasses time guards; writes `/tmp/cast_journal_wrap_<DATE>` flag
- **`/note [text]` skill** — mid-session scratchpad append in `HH:MM — <observation>` format
- **MOC builder** (`cast-journal-build-mocs.sh`) with hand-curated content preservation via `<!-- CAST-JOURNAL-AUTO-ENTRIES-START/END -->` marker fence
- **5 cron jobs** (all opt-in): weekly MOC rebuild, weekly synthesis, daily prediction extraction, weekly prediction check, optional EOD missed-entry flag

### Fixed
- `install.sh` now installs all 3 skills (`/reflect`, `/wrap`, `/note`) — previously `/wrap` was omitted

## v0.2.0 — 2026-04-26
- Added: SessionStart hook — injects latest journal excerpt into session context at startup
- Added: re-prompt hardening — bypasses cancel flag when no entry exists or session starts late in the day
- Fixed: reflect path resolution bug in SessionStart hook
- Fixed: BSD `sed` bug in SessionStart hook that collapsed journal excerpt into a single line
- Fixed: guard cancel-flag `touch` against unwritable `/tmp` on restricted systems

## v0.1.0 — 2026-04-07
- Initial release
- Session-end hook reminder (blocks stop until journal entry is written)
- `/reflect` skill for on-demand journaling
- CLAUDE.md rules for journal guidelines and session-start continuity
- Settings merge script for hook registration
- install.sh and uninstall.sh
