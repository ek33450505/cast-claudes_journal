#!/usr/bin/env bash
# claudes_journal-merge-settings.sh — Merge claudes_journal hook into user's settings.json
#
# Usage: bash claudes_journal-merge-settings.sh [--yes]
#   --yes  Skip confirmation prompt

set -uo pipefail

USER_SETTINGS="${HOME}/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SETTINGS="${REPO_DIR}/config/settings.json"

# ── Colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  C_BOLD='\033[1m' C_GREEN='\033[0;32m' C_YELLOW='\033[0;33m' C_RED='\033[0;31m' C_RESET='\033[0m'
else
  C_BOLD='' C_GREEN='' C_YELLOW='' C_RED='' C_RESET=''
fi

_ok()   { printf '%s  [ok]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
_warn() { printf '%s  [warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
_fail() { printf '%s  [fail]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# ── Validate source ──────────────────────────────────────────────────────────
if [ ! -f "$HOOKS_SETTINGS" ]; then
  _fail "Hook settings not found: $HOOKS_SETTINGS"
fi

HOOKS_SETTINGS="$HOOKS_SETTINGS" python3 -c "import json, os; json.load(open(os.environ['HOOKS_SETTINGS']))" 2>/dev/null || _fail "Invalid JSON in $HOOKS_SETTINGS"

# ── Create user settings if missing ──────────────────────────────────────────
mkdir -p "${HOME}/.claude"
if [ ! -f "$USER_SETTINGS" ]; then
  echo '{}' > "$USER_SETTINGS"
  _ok "Created $USER_SETTINGS"
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
if [ "${1:-}" != "--yes" ] && [ "${CI:-}" != "true" ]; then
  printf '\n%sMerge claudes_journal into %s?%s\n' "$C_BOLD" "$USER_SETTINGS" "$C_RESET"
  printf "  This will add/update the cast-journal-session-end hook entry. Existing settings are preserved.\n"
  printf "  A backup will be created first.\n\n"
  printf "  Proceed? [Y/n] "
  read -r reply 2>/dev/null || reply="n"
  case "${reply}" in
    [Yy]*|"") ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# ── Backup ────────────────────────────────────────────────────────────────────
BACKUP="${USER_SETTINGS}.bak"
cp "$USER_SETTINGS" "$BACKUP"
_ok "Backup saved to ${BACKUP}"

# ── Merge ─────────────────────────────────────────────────────────────────────
USER_SETTINGS="$USER_SETTINGS" HOOKS_SETTINGS="$HOOKS_SETTINGS" python3 << 'PYEOF'
import json, os, sys

with open(os.environ["USER_SETTINGS"]) as f:
    user = json.load(f)

with open(os.environ["HOOKS_SETTINGS"]) as f:
    hooks = json.load(f)

# Merge hooks: add/update the Stop event entry by id
if "hooks" not in user:
    user["hooks"] = {}

added = 0
updated = 0

for event, entries in hooks.get("hooks", {}).items():
    if event not in user["hooks"]:
        user["hooks"][event] = []

    existing_ids = {e.get("id") for e in user["hooks"][event] if isinstance(e, dict)}

    for entry in entries:
        entry_id = entry.get("id", "")
        if entry_id in existing_ids:
            # Replace existing entry with same id
            user["hooks"][event] = [entry if e.get("id") == entry_id else e for e in user["hooks"][event]]
            updated += 1
        else:
            user["hooks"][event].append(entry)
            added += 1

with open(os.environ["USER_SETTINGS"], "w") as f:
    json.dump(user, f, indent=2)
    f.write("\n")

print(f"  Added {added} hook(s), updated {updated} hook(s)")
PYEOF
MERGE_EXIT=$?

if [ "$MERGE_EXIT" -eq 0 ]; then
  _ok "Settings merged successfully"
else
  cp "$BACKUP" "$USER_SETTINGS"
  _fail "Merge failed — backup restored"
fi
