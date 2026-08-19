#!/usr/bin/env bash
# Team laggard nudges (MANAGER-only) — post to the Teams channel naming reportees who
# haven't planned / closed their day yet, at set times (after checking each one's status).
# Requires: workspace access + a channel webhook in ~/.samanvaya/teams.json.
# Usage:  bash setup-team-nudges.sh [PLAN_HH:MM] [CLOSE_HH:MM]     (default 11:15 and 18:30)
#         bash setup-team-nudges.sh -remove
set -euo pipefail
LA="$HOME/Library/LaunchAgents"; mkdir -p "$LA" "$HOME/.samanvaya"
PY=/usr/bin/python3; SCRIPT="$HOME/bin/sam_daily.py"
PATHVAL="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

if [ "${1:-}" = "-remove" ]; then
  for l in team-plan-nudge team-close-nudge; do
    p="$LA/com.motadata.samanvaya.$l.plist"; launchctl unload "$p" 2>/dev/null||true; rm -f "$p"; echo "removed $l"
  done; exit 0
fi

PLAN="${1:-11:15}"; CLOSE="${2:-18:30}"
gen(){  # $1=label  $2=mode  $3=HH:MM
  local plist="$LA/com.motadata.samanvaya.$1.plist" H="${3%%:*}" M="${3##*:}"
  M="${M#0}"; H="${H#0}"; : "${M:=0}"; : "${H:=0}"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.motadata.samanvaya.$1</string>
  <key>ProgramArguments</key><array><string>$PY</string><string>$SCRIPT</string><string>$2</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHVAL</string></dict>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$H</integer><key>Minute</key><integer>$M</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.samanvaya/team-nudge.log</string>
  <key>StandardErrorPath</key><string>$HOME/.samanvaya/team-nudge.log</string>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist"
  echo "loaded: $1 at $3 (mode=$2)"
}

gen team-plan-nudge  team-plan-nudge  "$PLAN"
gen team-close-nudge team-close-nudge "$CLOSE"
echo
echo "Done. Posts to the Teams channel in ~/.samanvaya/teams.json."
echo "Change times: re-run with  bash setup-team-nudges.sh 11:00 18:45   ·  Remove: -remove"
