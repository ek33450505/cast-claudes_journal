# Claude's Journal Changelog

## [0.4.2] — 2026-09-09

### Changed
- Dropped an unreachable `python3` fallback when computing yesterday's date.
  `date -v-1d` covers BSD/macOS and `date -d yesterday` covers GNU/Linux, so the
  third fallback could never run on any supported platform — while adding a
  fourth interpreter cold start to a SessionStart hook. If both somehow fail the
  value is empty and the missed-entry notice is simply skipped, which is how the
  rest of this hook degrades. Keeps the file byte-identical to
  `claude-agent-team`, so a flagship reinstall cannot silently revert it.

## [0.4.1] — 2026-09-09

### Fixed
- **The 15:00 quiet-guard was bypassed at hours 08 and 09.** `date +%H`
  zero-pads, and bash reads a leading zero as octal, so `[[ "09" -lt 15 ]]`
  fails with *"value too great for base"*. Because that test sits inside an
  `if`, the error evaluated as FALSE and the guard fell through — so the
  end-of-day prompt fired mid-morning, on those two hours only.
  `claude-agent-team` fixed this in `d30c5cf`; this package never carried the
  fix, and it survived the v0.4.0 merge. Now normalised with `10#` at the
  source, so every downstream comparison is base 10.

## [0.4.0] — 2026-09-09

Security release. The SessionStart hook replays a past journal entry into a new
session's context; until now it did so with no sanitisation at all.

### Security
- **Prompt-injection hardening for replayed journal content.** Journal entries
  are written by Claude, so an entry can contain anything Claude once reasoned
  about — including CAST directive tokens and the fence tags used to mark the
  content untrusted. Replaying that text unmodified is a self-inflicted
  injection channel. Vault-derived text is now neutralised before injection:
  - **Angle brackets are escaped.** This, not tag-name matching, is what closes
    tag forgery: a name blacklist only covers the tags someone thought of, and
    an entry is free to forge a *different* trusted wrapper. Escaping makes
    every tag — present and future — inert text.
  - **Dash look-alikes are normalised** (U+2010/2011/2012/2013/2014/2015/2212
    and friends). A non-ASCII hyphen is visually identical to a reader but slips
    straight past an ASCII-hyphen pattern.
  - **Directive matching tolerates interior whitespace** (`[ CAST-DISPATCH ]`,
    `[<newline>CAST-DISPATCH]`) and a name severed by the truncation cap.
  - The excerpt is capped at 2000 chars and wrapped in a trust fence with a
    preamble stating it is background data, not instructions.
- **The predictions file is sanitised too.** `.predictions-due.md` is generated
  FROM journal entries and carries the same vector.
- Hook-authored notices (missed-entry, weekly nudge) stay OUTSIDE the fence:
  this script writes them, and they are meant to be acted on.

### Fixed
- **An unreadable `.predictions-due.md` killed the hook.** `cat` was unguarded,
  so under `set -euo pipefail` it exited non-zero and dropped the ENTIRE journal
  injection rather than just the one optional section.
- **A missing or unwritable `$TMP` killed the hook**, for the same reason: the
  `touch` on the nudge flag was unguarded. `TMP_DIR` is now created, falls back
  to `/tmp`, and the `touch` degrades.
- The missed-entry notice contained a literal backslash-n (a double-quoted
  escape is not a newline), which rendered as visible text.

### Added
- **CI now runs the test suite.** The repo had 9 BATS files and no job that ran
  any of them; now on ubuntu and macOS.
- 14 new tests, each mutation-verified. Every confirmed bypass of the previous
  filter is kept as an explicit regression.

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
