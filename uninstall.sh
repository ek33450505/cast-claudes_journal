#!/bin/bash
# uninstall.sh — Claude's Journal uninstaller
# Removes hook, rules, and skill. Journal entries are preserved.
set -uo pipefail

# Colors
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  C_BOLD='\033[1m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'; C_RESET='\033[0m'
else
  C_BOLD='' C_GREEN='' C_YELLOW='' C_RED='' C_RESET=''
fi

_ok()   { printf "${C_GREEN}  [ok]${C_RESET} %s\n" "$*"; }
_warn() { printf "${C_YELLOW}  [warn]${C_RESET} %s\n" "$*" >&2; }
_step() { printf "\n${C_BOLD}%s${C_RESET}\n" "$*"; }

printf "\n${C_BOLD}Claude's Journal uninstaller${C_RESET}\n"
printf "══════════════════════════════════════\n"
printf "  Note: ~/.claude/claudes_journal/ journal will NOT be removed.\n\n"

CLAUDE_DIR="${HOME}/.claude"

# Remove hook script
_step "Removing hook script..."
rm -f "${CLAUDE_DIR}/scripts/claudes_journal-session-end.sh" && _ok "removed claudes_journal-session-end.sh"

# Remove rules
_step "Removing rules..."
rm -f "${CLAUDE_DIR}/rules/claudes_journal.md" && _ok "removed claudes_journal.md"

# Remove skill
_step "Removing /reflect skill..."
rm -rf "${CLAUDE_DIR}/skills/reflect" && _ok "removed /reflect skill"

# Remove hook from settings.json
_step "Removing hook from settings.json..."
SETTINGS="${CLAUDE_DIR}/settings.json"
if [ -f "$SETTINGS" ] && command -v python3 &>/dev/null; then
  SETTINGS="$SETTINGS" python3 -c '
import json, os, sys
try:
    settings_path = os.environ["SETTINGS"]
    with open(settings_path) as f:
        s = json.load(f)
    hooks = s.get("hooks", {})
    for event in list(hooks.keys()):
        hooks[event] = [h for h in hooks[event] if h.get("id") != "claudes_journal-session-end"]
        if not hooks[event]:
            del hooks[event]
    if hooks:
        s["hooks"] = hooks
    elif "hooks" in s:
        del s["hooks"]
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("  [ok] hook entry removed from settings.json")
except Exception as e:
    print(f"  [warn] Could not update settings.json: {e}", file=sys.stderr)
' 2>/dev/null || _warn "Could not update settings.json"
else
  _warn "settings.json not found or python3 unavailable — remove hook entry manually"
fi

printf "\n${C_GREEN}Claude's Journal uninstalled.${C_RESET}\n"
printf "  Journal preserved at ~/.claude/claudes_journal/\n\n"
