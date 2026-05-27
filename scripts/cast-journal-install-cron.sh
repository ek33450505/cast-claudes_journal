#!/usr/bin/env bash
# cast-journal-install-cron.sh — helper to install end-of-day reminder cron job

if [[ "${CLAUDE_SUBPROCESS:-0}" = "1" ]]; then exit 0; fi
set -euo pipefail

# Resolve script's own directory to get install path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$(dirname "$SCRIPT_DIR")"

# Check if cron line already exists
if crontab -l 2>/dev/null | grep -q "cast-journal-eod-flag.sh"; then
  # Already installed
  exit 0
fi

# Ask user
echo "Install end-of-day reminder cron? (y/n)"
read -r response

if [[ "$response" != "y" && "$response" != "Y" ]]; then
  echo "Skipped — you can add it later with \`crontab -e\`"
  exit 0
fi

# Add cron line
(crontab -l 2>/dev/null || true; echo "30 23 * * * /usr/bin/env bash \"${INSTALL_PATH}/scripts/cast-journal-eod-flag.sh\"") | crontab -

echo "Cron job installed successfully."
exit 0
