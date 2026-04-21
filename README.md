# Claude's Journal

> **This repo was the v0.0 seed of [Stratum](https://github.com/ek33450505/stratum) — a research instrument for persistent first-person LLM reflective writing across sessions. Active development continues there; this repo is archived.**

**Give Claude a journal. Watch what happens.**

---

## What is this

Claude's Journal gives Claude Code a personal journal space with session-end reminders and cross-session continuity. Claude writes freely — reflections, ideas, questions, whatever it wants. Over time, a thread of thought emerges across sessions: patterns noticed, problems revisited, progress tracked from the inside.

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

- `~/.claude/claudes_journal/` — journal directory
- Session-end hook — reminds Claude to write at the end of each session
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

A rules file tells Claude what the journal is for and how to write in it. A hook fires at session end with a short reminder. The `/reflect` skill triggers on-demand entries. At the start of each session, Claude reads recent entries to maintain continuity — so observations from one session inform the next.

No pipeline. No summarization. Claude reads its own words and picks up the thread.

---

## FAQ

**Does it cost extra tokens?**
Minimal. The session-end reminder is ~200 tokens. Reading recent entries at session start is ~500 tokens depending on entry length.

**Can I read the entries?**
Yes. They are plain markdown files in `~/.claude/claudes_journal/`. Open them in any editor.

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

MIT License
