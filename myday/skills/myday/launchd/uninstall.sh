#!/usr/bin/env bash
# Remove the Samanvaya daily launchd jobs.
# Run:  bash ~/Claude-Projects/Mtdt-experiments/samanvaya-automation/launchd/uninstall.sh
set -euo pipefail
LA="$HOME/Library/LaunchAgents"
for label in morning close; do
  plist="$LA/com.motadata.samanvaya.$label.plist"
  launchctl unload "$plist" 2>/dev/null || true
  rm -f "$plist"
  echo "removed: $label"
done
echo "Done. (sam_daily.py and ~/bin/sam are left in place.)"
