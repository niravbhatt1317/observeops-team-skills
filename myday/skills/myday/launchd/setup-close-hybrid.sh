#!/usr/bin/env bash
# Hybrid evening routine:
#   17:35  interactive close nudge (click -> Claude drafts remarks & closes, +8)
#   18:00  silent auto-close fallback (per-item remarks, +8) — only if still open
# Both skip if the day is already closed. Run:  bash launchd/setup-close-hybrid.sh
set -euo pipefail
LA="$HOME/Library/LaunchAgents"; mkdir -p "$LA" "$HOME/.samanvaya"
PY=/usr/bin/python3; SCRIPT="$HOME/bin/sam_daily.py"
PATHVAL="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

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
  <key>StandardOutPath</key><string>$HOME/.samanvaya/close.log</string>
  <key>StandardErrorPath</key><string>$HOME/.samanvaya/close.log</string>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist"
  echo "loaded: $1  ($3:$(printf %02d "$4"), mode=$2)"
}

gen remind-close remind-close 17 35   # 17:35 interactive nudge
gen close        close        18 0    # 18:00 silent auto-close fallback

echo
echo "Done. Verify:  launchctl list | grep samanvaya"
echo "Evening is now: 17:35 nudge -> 18:00 auto-close. Skips if already closed."
