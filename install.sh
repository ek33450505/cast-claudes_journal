#!/bin/bash
# install.sh — Claude's Journal installer
# Gives Claude a personal journal with session-end reminders and cross-session continuity.
# Only requirement: Claude Code CLI installed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CJ_VERSION="$(cat "${REPO_DIR}/VERSION" 2>/dev/null || echo "unknown")"

# Colors
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  C_BOLD='\033[1m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'; C_RESET='\033[0m'
else
  C_BOLD='' C_GREEN='' C_YELLOW='' C_RED='' C_RESET=''
fi

_ok()   { printf "${C_GREEN}  [ok]${C_RESET} %s\n" "$*"; }
_warn() { printf "${C_YELLOW}  [warn]${C_RESET} %s\n" "$*" >&2; }
_fail() { printf "${C_RED}  [fail]${C_RESET} %s\n" "$*" >&2; }
_step() { printf "\n${C_BOLD}%s${C_RESET}\n" "$*"; }

printf "\n${C_BOLD}Claude's Journal v${CJ_VERSION} installer${C_RESET}\n"
printf "══════════════════════════════════════\n"
printf "  Give Claude a journal.\n\n"

# Step 1: Prerequisites
_step "Checking prerequisites..."
if command -v claude &>/dev/null; then
  _ok "Claude Code CLI found"
else
  _warn "claude CLI not found — install from https://install.anthropic.com"
fi

CLAUDE_DIR="${HOME}/.claude"
mkdir -p "${CLAUDE_DIR}"

# Step 2: Vault directory
_step "Creating Obsidian vault directory..."
VAULT_DIR="${HOME}/Documents/Claude"
mkdir -p "${VAULT_DIR}"
_ok "~/Documents/Claude/"

# Step 3: Hook script
_step "Installing session-end hook..."
SCRIPTS_DIR="${CLAUDE_DIR}/scripts"
mkdir -p "${SCRIPTS_DIR}"
if cp "${REPO_DIR}/scripts/cast-journal-session-end.sh" "${SCRIPTS_DIR}/cast-journal-session-end.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-session-end.sh"
  _ok "cast-journal-session-end.sh"
else
  _fail "Could not copy hook script"
fi

# Step 4: Rules
_step "Installing rules..."
RULES_DIR="${CLAUDE_DIR}/rules"
mkdir -p "${RULES_DIR}"
if cp "${REPO_DIR}/rules/claudes_journal.md" "${RULES_DIR}/claudes_journal.md" 2>/dev/null; then
  _ok "claudes_journal.md → ~/.claude/rules/"
else
  _fail "Could not copy rules file"
fi

# Step 5: Skill
_step "Installing /reflect skill..."
SKILL_DIR="${CLAUDE_DIR}/skills/reflect"
mkdir -p "${SKILL_DIR}"
if cp "${REPO_DIR}/skills/reflect/instructions.md" "${SKILL_DIR}/instructions.md" 2>/dev/null; then
  _ok "/reflect → ~/.claude/skills/reflect/"
else
  _fail "Could not copy skill"
fi

# Step 6: Merge hook settings
_step "Registering session-end hook..."
MERGE_SCRIPT="${REPO_DIR}/scripts/claudes_journal-merge-settings.sh"
if [ -f "$MERGE_SCRIPT" ]; then
  if [ "${1:-}" = "--yes" ] || [ "${CI:-}" = "true" ]; then
    bash "$MERGE_SCRIPT" --yes
  else
    printf "  Merge hook settings into ~/.claude/settings.json? [Y/n] "
    read -r reply 2>/dev/null || reply="y"
    case "${reply}" in
      [Yy]*|"") bash "$MERGE_SCRIPT" --yes ;;
      *) _ok "Skipped — run manually: bash ${MERGE_SCRIPT}" ;;
    esac
  fi
else
  _warn "Settings merge script not found — register hook manually in ~/.claude/settings.json"
fi

# Summary
printf "\n${C_BOLD}══════════════════════════════════════${C_RESET}\n"
printf "${C_GREEN}Claude's Journal v${CJ_VERSION} installed.${C_RESET}\n\n"
printf "  Vault:    ~/Documents/Claude/\n"
printf "  Hook:     session-end reminder (automatic)\n"
printf "  Skill:    /reflect (on-demand)\n"
printf "  Rules:    ~/.claude/rules/claudes_journal.md\n"
printf "\n${C_BOLD}Next steps:${C_RESET}\n"
printf "  1. Start a Claude Code session\n"
printf "  2. Work normally — Claude will be reminded to journal at session end\n"
printf "  3. Try /reflect for on-demand journaling\n"
printf "  4. Open ~/Documents/Claude/ in Obsidian to browse entries\n\n"
