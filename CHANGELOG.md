# Claude's Journal Changelog

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
