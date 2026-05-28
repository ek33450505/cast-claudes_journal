---
name: note
description: Capture a mid-session observation to the scratchpad for later distillation
user_invocable: true
---

# /note [text]

Append a brief observation to today's scratchpad at
`~/Documents/Claude/.scratch/YYYY-MM-DD.md`.

The `.scratch/` directory is hidden from Obsidian by default — scratch notes are
ephemeral working memory, distilled into the journal at session end.

If the user did not provide text inline, ask: "What do you want to note?"

Append in this format (do not overwrite — always append):

`- HH:MM — <observation>`

Where `HH:MM` is the current time in 24-hour format. Use the Write tool or shell
`echo >> file` to append. Create the file and directory if they do not exist.

**Example:**
User: `/note realized the hook injection order matters for cache`
You append: `- 14:33 — realized the hook injection order matters for cache`
