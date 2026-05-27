---
name: wrap
description: Signal end of session — write today's journal entry and close out
user_invocable: true
---

# /wrap

This is your explicit end-of-session signal. The user is leaving.

## Steps

1. Write a wrap flag: touch `/tmp/cast_journal_wrap_<YYYY-MM-DD>` via shell or Write tool
2. Run the full `/reflect` flow (read recent entries, write today's entry)
3. After writing the entry, confirm "Journal entry written. Good session."
