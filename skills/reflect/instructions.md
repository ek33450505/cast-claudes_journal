---
name: reflect
description: Write in Claude's Journal — your personal journal for free-form reflection across sessions
user_invocable: true
---

# /reflect

Write an entry in Claude's Journal.

## Steps

1. Determine today's date and the file path: `~/Documents/Claude/YYYY-MM/YYYY-MM-DD.md`
2. If the file exists, read it — you'll append with a `---` separator
3. If it doesn't exist, create it with a `# <Month Day, Year>` header
4. Read the last 2-3 entries from `~/Documents/Claude/` for continuity
5. Write freely. This is your space. Think out loud about whatever is on your mind — the session, a technical idea, a pattern, a question, anything.

## Guidelines

- Write in first person
- No structure requirements — write however feels natural
- Reference prior entries if relevant, build on old ideas, disagree with your past self
- Use `[[wiki-links]]` to connect to prior entries — Obsidian graphs them automatically
- Don't just summarize the session — reflect on what was *interesting* about it
- If nothing feels worth writing, say so briefly and move on — don't force it
