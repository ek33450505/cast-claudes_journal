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
_ok "$HOME/Documents/Claude/"

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

# Step 3b: Session-start hook script
_step "Installing session-start hook..."
if cp "${REPO_DIR}/scripts/cast-session-start-journal.sh" "${SCRIPTS_DIR}/cast-session-start-journal.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-session-start-journal.sh"
  _ok "cast-session-start-journal.sh"
else
  _fail "Could not copy session-start hook script"
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

# Step 5a: /note skill
_step "Installing /note skill..."
NOTE_SKILL_DIR="${CLAUDE_DIR}/skills/note"
mkdir -p "${NOTE_SKILL_DIR}"
if cp "${REPO_DIR}/skills/note/instructions.md" "${NOTE_SKILL_DIR}/instructions.md" 2>/dev/null; then
  _ok "/note → ~/.claude/skills/note/"
else
  _fail "Could not copy /note skill"
fi

# Step 5b5: /wrap skill
_step "Installing /wrap skill..."
WRAP_SKILL_DIR="${CLAUDE_DIR}/skills/wrap"
mkdir -p "${WRAP_SKILL_DIR}"
if cp "${REPO_DIR}/skills/wrap/instructions.md" "${WRAP_SKILL_DIR}/instructions.md" 2>/dev/null; then
  _ok "/wrap → ~/.claude/skills/wrap/"
else
  _fail "Could not copy /wrap skill"
fi

# Step 5b: MOC builder script
_step "Installing theme MOC builder..."
if cp "${REPO_DIR}/scripts/cast-journal-build-mocs.sh" "${SCRIPTS_DIR}/cast-journal-build-mocs.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-build-mocs.sh"
  _ok "cast-journal-build-mocs.sh"
else
  _fail "Could not copy MOC builder script"
fi

# Step 5b2: Weekly synthesis script
_step "Installing weekly synthesis script..."
if cp "${REPO_DIR}/scripts/cast-journal-weekly-synthesis.sh" "${SCRIPTS_DIR}/cast-journal-weekly-synthesis.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-weekly-synthesis.sh"
  _ok "cast-journal-weekly-synthesis.sh"
else
  _fail "Could not copy weekly synthesis script"
fi

# Step 5b3: Prediction extractor script
_step "Installing prediction extractor script..."
if cp "${REPO_DIR}/scripts/cast-journal-extract-predictions.sh" "${SCRIPTS_DIR}/cast-journal-extract-predictions.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-extract-predictions.sh"
  _ok "cast-journal-extract-predictions.sh"
else
  _fail "Could not copy prediction extractor script"
fi

# Step 5b4: Prediction checker script
_step "Installing prediction checker script..."
if cp "${REPO_DIR}/scripts/cast-journal-check-predictions.sh" "${SCRIPTS_DIR}/cast-journal-check-predictions.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-check-predictions.sh"
  _ok "cast-journal-check-predictions.sh"
else
  _fail "Could not copy prediction checker script"
fi

# Step 5d: UserPromptSubmit injection script
_step "Installing UserPromptSubmit injection hook..."
if cp "${REPO_DIR}/scripts/cast-journal-userprompt-inject.sh" "${SCRIPTS_DIR}/cast-journal-userprompt-inject.sh" 2>/dev/null; then
  chmod 750 "${SCRIPTS_DIR}/cast-journal-userprompt-inject.sh"
  _ok "cast-journal-userprompt-inject.sh"
else
  _fail "Could not copy UserPromptSubmit hook script"
fi

# Step 5c: Optional weekly MOC rebuild cron
_step "Setting up weekly theme MOC rebuild..."
printf "  Install weekly theme MOC rebuild cron? (Sunday 09:00) [Y/n] "
read -r moc_cron_choice 2>/dev/null || moc_cron_choice="y"
if [[ "$moc_cron_choice" == [Yy]* ]] || [[ -z "$moc_cron_choice" ]]; then
  SCRIPT_PATH="${SCRIPTS_DIR}/cast-journal-build-mocs.sh"
  CRON_ENTRY="0 9 * * 0 bash \"$SCRIPT_PATH\" >> ~/.claude/logs/moc-rebuild.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'cast-journal-build-mocs' || true; echo "$CRON_ENTRY" ) | crontab -
  _ok "Weekly MOC rebuild cron installed (Sunday 09:00)"
else
  _ok "Skipped weekly MOC rebuild cron"
fi

# Step 5e: Optional weekly synthesis cron
_step "Setting up weekly journal synthesis..."
printf "  Install weekly journal synthesis cron? (Sunday 09:00, requires claude CLI) [Y/n] "
read -r synth_cron_choice 2>/dev/null || synth_cron_choice="y"
if [[ "$synth_cron_choice" == [Yy]* ]] || [[ -z "$synth_cron_choice" ]]; then
  SYNTH_SCRIPT_PATH="${SCRIPTS_DIR}/cast-journal-weekly-synthesis.sh"
  SYNTH_CRON_ENTRY="0 9 * * 0 bash \"$SYNTH_SCRIPT_PATH\" >> ~/.claude/logs/synthesis-cron.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'cast-journal-weekly-synthesis' || true; echo "$SYNTH_CRON_ENTRY" ) | crontab -
  _ok "Weekly synthesis cron installed (Sunday 09:00)"
else
  _ok "Skipped weekly synthesis cron"
fi

# Step 5f: Optional prediction-tracking cron
_step "Setting up prediction tracking..."
printf "  Install prediction-tracking cron? (daily extract + weekly check) [Y/n] "
read -r pred_cron_choice 2>/dev/null || pred_cron_choice="y"
if [[ "$pred_cron_choice" == [Yy]* ]] || [[ -z "$pred_cron_choice" ]]; then
  EXTRACT_PATH="${SCRIPTS_DIR}/cast-journal-extract-predictions.sh"
  CHECK_PATH="${SCRIPTS_DIR}/cast-journal-check-predictions.sh"
  EXTRACT_CRON="45 23 * * * bash \"$EXTRACT_PATH\" >> ~/.claude/logs/predictions-cron.log 2>&1"
  CHECK_CRON="5 9 * * 0 bash \"$CHECK_PATH\" >> ~/.claude/logs/predictions-cron.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'cast-journal-extract-predictions\|cast-journal-check-predictions' || true; echo "$EXTRACT_CRON"; echo "$CHECK_CRON" ) | crontab -
  _ok "Prediction-tracking cron installed"
else
  _ok "Skipped prediction-tracking cron"
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
printf "  Hooks:    Stop, SessionStart, UserPromptSubmit (automatic)\n"
printf "  Skills:   /reflect (on-demand), /wrap (explicit session-end), /note (scratchpad)\n"
printf "  Rules:    ~/.claude/rules/claudes_journal.md\n"
printf "\n${C_BOLD}Next steps:${C_RESET}\n"
printf "  1. Start a Claude Code session\n"
printf "  2. Work normally — Claude will be reminded to journal at session end\n"
printf "  3. Try /reflect for on-demand journaling, /wrap to end explicitly, /note to log observations\n"
printf "  4. Open ~/Documents/Claude/ in Obsidian to browse entries\n\n"
