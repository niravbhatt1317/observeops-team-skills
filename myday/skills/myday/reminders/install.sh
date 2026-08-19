#!/usr/bin/env bash
# Install the Samanvaya daily REMINDER nudges (notify only — you plan/close via Claude).
# Run yourself:  bash skill/reminders/install.sh
# Notifications: 09:00 "plan your day"  ·  17:45 "close your day"
set -euo pipefail
LA="$HOME/Library/LaunchAgents"; mkdir -p "$LA" "$HOME/.samanvaya"
PY=/usr/bin/python3; SCRIPT="$HOME/bin/sam_daily.py"

gen() {  # $1=label(plan|close)  $2=mode  $3=hour  $4=min
  local plist="$LA/com.motadata.samanvaya.remind-$1.plist"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.motadata.samanvaya.remind-$1</string>
  <key>ProgramArguments</key><array>
    <string>$PY</string><string>$SCRIPT</string><string>$2</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin</string></dict>
  <key>StartCalendarInterval</key><dict>
    <key>Hour</key><integer>$3</integer><key>Minute</key><integer>$4</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.samanvaya/remind.log</string>
  <key>StandardErrorPath</key><string>$HOME/.samanvaya/remind.log</string>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist"
  echo "loaded: remind-$1 at $3:$(printf %02d "$4")"
}

gen plan  remind-plan  9  0
gen close remind-close 17 45
echo "Done. Verify: launchctl list | grep samanvaya"
