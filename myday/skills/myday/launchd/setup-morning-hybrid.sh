#!/usr/bin/env bash
# Hybrid morning routine:
#   09:00  interactive nudge  (click -> Claude asks what you're planning)
#   11:00  interactive nudge  (only if still unplanned)
#   11:30  silent auto-plan fallback (so you never lose the +5)
# Replaces the old silent 09:00 auto-plan job. Leaves the 18:00 close job alone.
# Run:  bash launchd/setup-morning-hybrid.sh
set -euo pipefail
LA="$HOME/Library/LaunchAgents"; mkdir -p "$LA" "$HOME/.samanvaya"
PY=/usr/bin/python3; SCRIPT="$HOME/bin/sam_daily.py"
PATHVAL="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

# 1) remove the old silent morning job
OLD="$LA/com.motadata.samanvaya.morning.plist"
[ -f "$OLD" ] && { launchctl unload "$OLD" 2>/dev/null || true; rm -f "$OLD"; echo "removed old silent morning job"; }

gen() {  # $1=label  $2=mode  $3=hour  $4=min
  local plist="$LA/com.motadata.samanvaya.$1.plist"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.motadata.samanvaya.$1</string>
  <key>ProgramArguments</key><array>
    <string>$PY</string><string>$SCRIPT</string><string>$2</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHVAL</string></dict>
  <key>StartCalendarInterval</key><dict>
    <key>Hour</key><integer>$3</integer><key>Minute</key><integer>$4</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.samanvaya/morning.log</string>
  <key>StandardErrorPath</key><string>$HOME/.samanvaya/morning.log</string>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist"
  echo "loaded: $1  ($3:$(printf %02d "$4"), mode=$2)"
}

gen remind-plan-am   remind-plan 9  0    # 09:00 interactive nudge
gen remind-plan-late remind-plan 11 0    # 11:00 interactive nudge
gen plan-fallback    morning     11 30   # 11:30 silent auto-plan fallback

echo
echo "Done. Verify:  launchctl list | grep samanvaya"
echo "Morning is now: 09:00 nudge -> 11:00 nudge -> 11:30 auto-plan fallback. Close stays at 18:00."
