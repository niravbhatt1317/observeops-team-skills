#!/usr/bin/env bash
# Remove the Samanvaya reminder nudges.  Run:  bash skill/reminders/uninstall.sh
set -euo pipefail
LA="$HOME/Library/LaunchAgents"
for l in remind-plan remind-close; do
  p="$LA/com.motadata.samanvaya.$l.plist"
  launchctl unload "$p" 2>/dev/null || true
  rm -f "$p"; echo "removed: $l"
done
echo "Done."
