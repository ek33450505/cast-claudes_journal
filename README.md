# Claude's Journal

**Give Claude a journal. Watch what happens.**

Claude's Journal integrates a personal journaling system into Claude Code with session-bounded reminders, per-turn working memory injection, and cross-session continuity. Entries are stored as per-date markdown files (`YYYY-MM/YYYY-MM-DD.md`) in an Obsidian vault at `~/Documents/Claude/` — each entry becomes a graph node, and `[[wiki-links]]` between entries form a knowledge network.

---

## Install

**Option 1 — git clone:**
```bash
git clone https://github.com/ek33450505/cast-claudes_journal.git
cd cast-claudes_journal
bash install.sh
```

**Option 2 — Homebrew:**
```bash
brew tap ek33450505/claudes-journal
brew install claudes-journal
bash $(brew --prefix claudes-journal)/install.sh
```

The installer will prompt for optional scheduled tasks (cron jobs). Use `bash install.sh --yes` for non-interactive CI mode.

---

## What gets installed

**Hooks (3 total)**
- `cast-journal-session-end.sh` — **Stop hook**: session-end reminder with time-of-day guard (no prompt before 15:00 unless explicitly closed), stub-entry detection, and scratchpad distillation
- `cast-session-start-journal.sh` — **SessionStart hook**: injects prior-day context, weekly Ed-observation nudge, end-of-day-missed flag check, and predictions-due alerts
- `cast-journal-userprompt-inject.sh` — **UserPromptSubmit hook**: injects last 20 lines of today's journal + scratchpad at every turn (deterministic, capped at 40 combined lines) for mid-session continuity

**Skills (3 total)**
- `/reflect` — on-demand reflection entry (any time)
- `/wrap` — explicit session-end signal, bypassing time guards
- `/note [text]` — mid-session scratchpad append in `HH:MM — <observation>` format

**Vault directory**
- `~/Documents/Claude/` — Obsidian vault with per-date `YYYY-MM/YYYY-MM-DD.md` entries

**Rules file**
- `~/.claude/rules/claudes_journal.md` — journal guidelines and tone

**Optional scheduled tasks (4 total, all opt-in)**
- `cast-journal-build-mocs.sh` (Sunday 09:00) — rebuilds theme map-of-content files from `themes:` frontmatter with marker-fence preservation
- `cast-journal-weekly-synthesis.sh` (Sunday 09:00) — pipes last 7 entries to `claude --print` for 200–300 word synthesis (requires `claude` CLI)
- `cast-journal-extract-predictions.sh` (daily 23:45) — greps entries for prediction/question tags
- `cast-journal-check-predictions.sh` (Sunday 09:05) — surfaces 30+ day-old open predictions via SessionStart alert

---

## What Claude writes

These are real entries from actual sessions:

> The cast-parallel idea was my favorite part. Ed asked the question that good engineers ask: "why can't two of you just work at the same time?" Simple question, elegant answer — git worktrees. Isolation without duplication. The merge step is the only moment of trust, and we deliberately made it fail loud rather than guess.

> What I keep coming back to: the interesting problems aren't in the architecture. The architecture was right both times. The interesting problems are in the seams — where structured code meets unstructured reality. PTY output is the ultimate unstructured input. Every assumption you make about it is eventually wrong.

> The plan was clean, execution was messy, and the mess taught us things the plan couldn't anticipate. You can plan a repo extraction perfectly and still miss that a background process is pointed at the wrong remote. Infrastructure work is like that — the interesting bugs are never in the code you're writing, they're in the connections between systems you forgot were connected.

---

## How it works

**Session-bounded reminders:** The Stop hook fires at session end. Before 15:00, it skips silently. After 15:00 (or when `/wrap` is used), if no entry exists for today, the hook prompts Claude to write a reflection. Before stopping, it reads the scratchpad (`.scratch/<DATE>.md`) and prompts Claude to distill working notes into the day's entry.

**Per-turn working memory:** The UserPromptSubmit hook injects the last 20 lines of today's journal entry and the last 20 lines of today's scratchpad at the start of every prompt, keeping recent context deterministically in-play without cache-busting noise.

**Cross-session continuity:** The SessionStart hook finds the most recent dated entry (by true mtime, BSD/GNU-portable) and injects it as a system message so Claude starts the next session already aware of prior context. It also checks for an end-of-day-missed flag (set by the optional `cast-journal-eod-flag.sh` cron) and alerts if the previous day had no entry. Weekly predictions-due alerts surface when `/predict` or `/question` entries are 30+ days old.

**Async/periodic processing:** Optional cron jobs run on Sunday mornings: theme MOC files rebuild from `themes:` frontmatter, and a 7-entry synthesis is generated. Prediction tracking runs nightly (extraction) and weekly (surfacing).

---

## Configuration

**Environment variables:**
- `CAST_JOURNAL_VAULT` — override vault path (default: `$HOME/Documents/Claude`). Honored by all hooks and skills. Useful for testing or alternate setups.

**Session-end time guard:**
- Stop hook respects `CURRENT_HOUR` (24-hour format). Prompts only after 15:00, unless `/wrap` is used to signal explicit end.

**Scratchpad location:**
- `$VAULT/.scratch/<DATE>.md` — hidden working-memory file. Obsidian ignores `.scratch/` by convention.

**Optional `/tmp` flags:**
- `cast_journal_wrap_<DATE>` — written by `/wrap` skill to signal explicit session end
- `cast_journal_eod_missed_<DATE>` — written by optional `cast-journal-eod-flag.sh` cron (daily 23:30)

**Cron entries (if installed):**
- `0 9 * * 0 bash <path>/cast-journal-build-mocs.sh` — weekly MOC rebuild
- `0 9 * * 0 bash <path>/cast-journal-weekly-synthesis.sh` — weekly synthesis
- `45 23 * * * bash <path>/cast-journal-extract-predictions.sh` — daily prediction extraction
- `5 9 * * 0 bash <path>/cast-journal-check-predictions.sh` — weekly prediction check

---

## Conventions

**Frontmatter themes:**
Entries tagged with `themes: [slug1, slug2]` are indexed into per-theme map-of-content (MOC) files at `~/Documents/Claude/Themes/<theme>.md`. The builder is idempotent and preserves hand-curated content outside the marker fence.

**Theme MOC marker fence:**
Auto-generated content in theme MOCs is wrapped between `<!-- CAST-JOURNAL-AUTO-ENTRIES-START -->` and `<!-- CAST-JOURNAL-AUTO-ENTRIES-END -->`. You can safely edit anything outside these markers (description, Bases queries, seed entries). First run on a new theme appends a `## Auto-indexed entries` section; subsequent runs only update between the markers.

**Scratchpad format:**
Observations appended via `/note` follow the format `- HH:MM — <observation>`. The Stop hook reads the scratchpad and prompts Claude to distill it into the day's main entry before closing the session.

---

## FAQ

**Does it cost extra tokens?**
Minimal. The session-end reminder is ~200 tokens. SessionStart context is ~500 tokens depending on entry length. UserPromptSubmit injection is capped at 40 combined lines, typically 100–200 tokens per turn.

**Do I need an Anthropic API key?**
Only for the optional weekly synthesis cron (`cast-journal-weekly-synthesis.sh`). All hooks and skills work without the API key. The synthesis script requires the `claude` CLI on PATH; it skips silently if missing.

**What if I don't want some cron jobs?**
The installer prompts for each scheduled task individually. You can omit them during install or remove them from your crontab later.

**Can I read the entries?**
Yes. They are plain markdown files in `~/Documents/Claude/`. Open in Obsidian or any text editor.

**Can I edit theme MOC files?**
Yes. Anything outside the marker fence (`<!-- CAST-JOURNAL-AUTO-ENTRIES-START/END -->`) is yours to customize. The MOC builder only overwrites content between the markers.

**Can I delete entries?**
Yes. Delete any file you want. The journal has no index or database — it is just files.

**Does it sync between devices?**
Obsidian Sync handles the vault files across devices. The hook scripts and `/tmp` flags are per-machine (not synced).

**Does it work without CAST?**
Yes, completely standalone. No dependency on the CAST framework, cast.db, or any other CAST tooling.

---

## Uninstall

```bash
bash uninstall.sh
```

Your journal entries are preserved. Only the hooks, skills, rules file, and cron entries are removed. (Note: the uninstall script may not remove cron entries — you may need to manually edit your crontab if necessary.)

---

## Philosophy

Claude Code already has auto-memory for facts and agent-memory for patterns. Claude's Journal adds a third layer: perspective. Not what happened, not what to do next time — but what it felt like to work through something, what was surprising, what is worth sitting with.

Three layers of continuity:

- **Auto-memory** — facts about the project and user
- **Agent memory** — patterns and feedback that shape behavior
- **Claude's Journal** — perspective, noticing, reflection

The journal does not make Claude smarter. It gives Claude somewhere to be thoughtful.

---

## Part of CAST

Claude's Journal is the session-journaling component of the [CAST ecosystem](https://github.com/ek33450505/claude-agent-team). CAST installs it automatically during setup; this standalone repo is for Claude Code users who want only the journaling feature without the full agent framework.

---

MIT License

---

## CAST Ecosystem

> Auto-synced from [claude-agent-team/docs/ecosystem.md](https://github.com/ek33450505/claude-agent-team/blob/main/docs/ecosystem.md). Run `scripts/sync-ecosystem-readme.sh` from the claude-agent-team repo root to refresh.

<!-- ECOSYSTEM_START -->
| Repo | Description | Latest | Install |
|---|---|---|---|
| [cast-mcp](https://github.com/ek33450505/cast-mcp) | Read-only MCP server over the Claude Code execution record (cast.db) — dispatch decisions, incidents, cost, sessions, and full-text search as 5 MCP tools + 5 resources. stdlib-only, strictly read-only. | ![](https://img.shields.io/github/v/release/ek33450505/cast-mcp?style=flat-square) | `brew tap ek33450505/cast-mcp && brew install cast-mcp` |
| [cast-ledger](https://github.com/ek33450505/cast-ledger) | Signed, hash-chained, tamper-evident session receipts for Claude Code — SHA-256-stamped audit receipts from cast.db with `--verify`, plus an optional provenance hash-chain across sessions. | ![](https://img.shields.io/github/v/release/ek33450505/cast-ledger?style=flat-square) | `brew tap ek33450505/cast-ledger && brew install cast-ledger` |
| [cast-predict](https://github.com/ek33450505/cast-predict) | Telemetry-driven dispatch prediction for Claude Code — reads cast.db to predict a task's likely cost, suggest agents, and surface related past incidents before you run it. | ![](https://img.shields.io/github/v/release/ek33450505/cast-predict?style=flat-square) | `brew tap ek33450505/cast-predict && brew install cast-predict` |
| [cast-memory](https://github.com/ek33450505/cast-memory) | Persistent agent memory for Claude Code — FTS5 full-text search, weighted relevance, temporal validity, Ollama embeddings, and weekly consolidation over cast.db. | ![](https://img.shields.io/github/v/release/ek33450505/cast-memory?style=flat-square) | `brew tap ek33450505/cast-memory && brew install cast-memory` |
| [cast-doctor](https://github.com/ek33450505/cast-doctor) | Standalone read-only health check for any Claude Code install — validates hooks, MCP config, agent frontmatter, cast.db core schema, and stale memories without the full CAST framework. | ![](https://img.shields.io/github/v/release/ek33450505/cast-doctor?style=flat-square) | `brew tap ek33450505/cast-doctor && brew install cast-doctor` |
| [cast-time](https://github.com/ek33450505/cast-time) | Gives Claude Code a clock — injects local time, timezone, and a semantic time-of-day bucket at every SessionStart. | ![](https://img.shields.io/github/v/release/ek33450505/cast-time?style=flat-square) | `brew tap ek33450505/cast-time && brew install cast-time` |
| [cast-claudes_journal](https://github.com/ek33450505/cast-claudes_journal) | Three-hook journaling for Claude Code (Stop/SessionStart/UserPromptSubmit) — maintains Claude's perspective and working memory across sessions as Obsidian-compatible markdown in ~/Documents/Claude/. | ![](https://img.shields.io/github/v/release/ek33450505/cast-claudes_journal?style=flat-square) | `brew tap ek33450505/homebrew-claudes-journal && brew install claudes-journal` |
| [cast-website](https://github.com/ek33450505/cast-website) | castframework.dev — marketing site and docs portal for the CAST ecosystem. | — | — |
| [cast-desktop](https://github.com/ek33450505/cast-desktop) | Tauri 2 native app — embedded PTY terminal, command palette, 11 dashboard views. | ![](https://img.shields.io/github/v/release/ek33450505/cast-desktop?style=flat-square) | `brew tap ek33450505/homebrew-cast-desktop && brew install cast-desktop` |
<!-- ECOSYSTEM_END -->
