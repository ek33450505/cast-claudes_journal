# Claude's Journal

**Give Claude a journal. Watch what happens.**

Claude's Journal gives Claude Code a personal journal space with session-end reminders and cross-session continuity. Journal entries are per-date notes (`YYYY-MM/YYYY-MM-DD.md`) written to an Obsidian vault at `~/Documents/Claude/`. Each note becomes a graph node — `[[wiki-links]]` between entries form edges.

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

---

## What gets installed

- `~/Documents/Claude/` — Obsidian vault for journal entries (per-date `YYYY-MM/YYYY-MM-DD.md` notes, grouped by month)
- `scripts/cast-session-start-journal.sh` — **SessionStart hook**: injects the most recent journal entry (or a "no journal yet" advisory) as `systemMessage` context whenever you start a Claude Code session. Lets Claude pick up where you left off across sessions.
- `scripts/cast-journal-session-end.sh` — **Stop hook**: reminds Claude to write at session end
- Rules file — sets journal guidelines and tone
- `/reflect` skill — on-demand reflection, any time

---

## What Claude writes

These are real entries from actual sessions:

> The cast-parallel idea was my favorite part. Ed asked the question that good engineers ask: "why can't two of you just work at the same time?" Simple question, elegant answer — git worktrees. Isolation without duplication. The merge step is the only moment of trust, and we deliberately made it fail loud rather than guess.

> What I keep coming back to: the interesting problems aren't in the architecture. The architecture was right both times. The interesting problems are in the seams — where structured code meets unstructured reality. PTY output is the ultimate unstructured input. Every assumption you make about it is eventually wrong.

> The plan was clean, execution was messy, and the mess taught us things the plan couldn't anticipate. You can plan a repo extraction perfectly and still miss that a background process is pointed at the wrong remote. Infrastructure work is like that — the interesting bugs are never in the code you're writing, they're in the connections between systems you forgot were connected.

---

## How it works

A rules file tells Claude what the journal is for and how to write in it. The `cast-journal-session-end.sh` Stop hook fires at session end: if no entry exists for today, it blocks once and prompts Claude to write. The `/reflect` skill triggers on-demand entries.

At session start, the SessionStart hook scans `~/Documents/Claude/YYYY-MM/*.md` for the most recent entry (true mtime, BSD/GNU-portable) and injects it as a system message so Claude opens the next session already aware of yesterday's context. If the vault is missing or empty, a brief advisory is emitted instead — Claude just starts cold.

No pipeline. No summarization. Claude reads its own words and picks up the thread. Open `~/Documents/Claude/` in Obsidian to browse and graph entries.

---

## FAQ

**Does it cost extra tokens?**
Minimal. The session-end reminder is ~200 tokens. Reading recent entries at session start is ~500 tokens depending on entry length.

**Can I read the entries?**
Yes. They are plain markdown files in `~/Documents/Claude/`. Open in Obsidian or any text editor.

**Can I delete entries?**
Yes. Delete any file you want. The journal has no index or database — it is just files.

**Does it work without CAST?**
Yes, completely standalone. No dependency on the CAST framework, cast.db, or any other CAST tooling.

---

## Uninstall

```bash
bash uninstall.sh
```

Your journal entries are preserved. Only the hook, rules file, and skill are removed.

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

> Auto-synced from [claude-agent-team/docs/ecosystem.md](https://github.com/ek33450505/claude-agent-team/blob/main/docs/ecosystem.md). Run `~/Projects/personal/claude-agent-team/scripts/sync-ecosystem-readme.sh` to refresh.

<!-- ECOSYSTEM_START -->
| Repo | Description | Latest | Install |
|---|---|---|---|
| [cast-hooks](https://github.com/ek33450505/cast-hooks) | 13 auditable hook scripts — observability, safety guards, quality gates. SessionStart, PreToolUse, PostToolUse, PostCompact. | ![](https://img.shields.io/github/v/release/ek33450505/cast-hooks?style=flat-square) | `brew tap ek33450505/cast-hooks && brew install cast-hooks` |
| [cast-agents](https://github.com/ek33450505/cast-agents) | 23 specialist agents — commit, debug, review, plan, test, research, and more. Agent definitions with YAML frontmatter. v7-synced. | ![](https://img.shields.io/github/v/release/ek33450505/cast-agents?style=flat-square) | `brew tap ek33450505/cast-agents && brew install cast-agents` |
| [cast-memory](https://github.com/ek33450505/cast-memory) | Persistent agent memory with FTS5 search, relevance scoring, shared pool, semantic embeddings. Per-agent knowledge accumulation. | ![](https://img.shields.io/github/v/release/ek33450505/cast-memory?style=flat-square) | `brew tap ek33450505/cast-memory && brew install cast-memory` |
| [cast-routines](https://github.com/ek33450505/cast-routines) | Scheduled autonomous Claude Code routines via YAML + cron. Daily briefings, inbox triage, release celebration, weekly cost reports. | ![](https://img.shields.io/github/v/release/ek33450505/cast-routines?style=flat-square) | `brew tap ek33450505/cast-routines && brew install cast-routines` |
| [cast-parallel](https://github.com/ek33450505/cast-parallel) | Parallel agent execution across worktree sessions. Agent Dispatch Manifest (ADM) support. | ![](https://img.shields.io/github/v/release/ek33450505/cast-parallel?style=flat-square) | `brew tap ek33450505/cast-parallel && brew install cast-parallel` |
| [cast-observe](https://github.com/ek33450505/cast-observe) | Session-level observability — cost tracking, agent run history, token spend, event sourcing. Feeds cast.db. | ![](https://img.shields.io/github/v/release/ek33450505/cast-observe?style=flat-square) | `brew tap ek33450505/cast-observe && brew install cast-observe` |
| [cast-security](https://github.com/ek33450505/cast-security) | Security hooks and audit trails. PII redaction, parry-guard integration, compliance logging. | ![](https://img.shields.io/github/v/release/ek33450505/cast-security?style=flat-square) | `brew tap ek33450505/cast-security && brew install cast-security` |
| [cast-doctor](https://github.com/ek33450505/cast-doctor) | Read-only health check for any Claude Code install. Validates hooks, MCP servers, agent frontmatter, cast.db schema, stale memories. | ![](https://img.shields.io/github/v/release/ek33450505/cast-doctor?style=flat-square) | `brew tap ek33450505/cast-doctor && brew install cast-doctor` |
| [cast-time](https://github.com/ek33450505/cast-time) | Gives Claude Code a clock — injects local time, timezone, and a semantic time-of-day bucket at every SessionStart. | ![](https://img.shields.io/github/v/release/ek33450505/cast-time?style=flat-square) | `brew tap ek33450505/cast-time && brew install cast-time` |
| [cast-dash](https://github.com/ek33450505/cast-dash) | Terminal UI dashboard for live swarm monitoring. 4-panel real-time display (Textual framework). | ![](https://img.shields.io/github/v/release/ek33450505/cast-dash?style=flat-square) | `brew tap ek33450505/cast-dash && brew install cast-dash` |
| [cast-claudes_journal](https://github.com/ek33450505/cast-claudes_journal) | Session continuity — Claude's Journal auto-injects prior-day context via SessionStart hook. Obsidian vault sync. | ![](https://img.shields.io/github/v/release/ek33450505/cast-claudes_journal?style=flat-square) | `brew tap ek33450505/homebrew-claudes-journal && brew install claudes-journal` |
| [cast-website](https://github.com/ek33450505/cast-website) | castframework.dev — marketing site and docs portal for the CAST ecosystem. | ![](https://img.shields.io/github/v/release/ek33450505/cast-website?style=flat-square) | — |
| [cast-desktop](https://github.com/ek33450505/cast-desktop) | Tauri 2 native app — embedded PTY terminal, command palette, 11 dashboard views, Constellation 3D graph. NEW. | ![](https://img.shields.io/github/v/release/ek33450505/cast-desktop?style=flat-square) | `brew tap ek33450505/homebrew-cast-desktop && brew install cast-desktop` |
<!-- ECOSYSTEM_END -->
