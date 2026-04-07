## Summary

<!-- What does this PR change and why? -->

## Changes

- 

## Checklist

- [ ] `bash install.sh` runs cleanly (no `[fail]` lines)
- [ ] `bash -n scripts/claudes_journal-session-end.sh` passes
- [ ] Hook script outputs valid JSON: `bash scripts/claudes_journal-session-end.sh | python3 -m json.tool`
- [ ] No hardcoded absolute paths (use `$HOME` or `~/`)
- [ ] `CHANGELOG.md` updated if user-visible change
