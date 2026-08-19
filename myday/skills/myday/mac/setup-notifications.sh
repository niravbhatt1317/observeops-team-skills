#!/usr/bin/env bash
# setup-notifications.sh (macOS) — branded + click-to-open notifications for myday.
# Installs terminal-notifier, builds ~/Applications/Samanvaya.app (logo + "Samanvaya" name),
# grabs the logo, creates Warp launch configs, and pre-trusts the launch folder.
# Run AFTER the core scripts are in ~/bin (sam, sam_daily.py, sam-open-claude). Idempotent.
set -uo pipefail
STATE="$HOME/.samanvaya"; mkdir -p "$STATE"
BASE="${SAM_BASE:-http://172.16.15.82:5000}"
WORKDIR="$HOME/Claude-Projects"; mkdir -p "$WORKDIR"
say(){ printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# Which terminal opens when a notification is clicked: warp | terminal | iterm | auto
OPENER="${1:-auto}"
echo "$OPENER" > "$STATE/opener"
echo "click-to-open terminal: $OPENER  (change later: echo <warp|terminal|iterm> > ~/.samanvaya/opener)"

say "1) terminal-notifier"
if ! command -v terminal-notifier >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then brew install terminal-notifier >/dev/null && echo "  installed";
  else echo "  ! Homebrew missing — install from https://brew.sh, then re-run"; fi
else echo "  already installed"; fi
TN="$(command -v terminal-notifier 2>/dev/null || echo /opt/homebrew/bin/terminal-notifier)"

say "2) Samanvaya logo"
"$HOME/bin/sam" login >/dev/null 2>&1 || true
if /usr/bin/curl -sS -b "$STATE/cookies.txt" "$BASE/static/samanvaya-icon.png" -o "$STATE/icon.png" && [ -s "$STATE/icon.png" ]; then
  echo "  saved $STATE/icon.png"
else echo "  ! couldn't fetch icon (VPN off?) — branding will be skipped"; fi

say "3) Samanvaya.app (branded notifier)"
if [ -s "$STATE/icon.png" ] && command -v brew >/dev/null 2>&1; then
  APP_SRC="$(brew --prefix terminal-notifier 2>/dev/null)/terminal-notifier.app"
  DEST="$HOME/Applications/Samanvaya.app"
  if [ -d "$APP_SRC" ]; then
    mkdir -p "$HOME/Applications"; rm -rf "$DEST"; /bin/cp -R "$APP_SRC" "$DEST"
    ICO="$STATE/samanvaya.iconset"; rm -rf "$ICO"; mkdir -p "$ICO"
    for s in 16 32 64 128 256 512; do
      /usr/bin/sips -z $s $s "$STATE/icon.png" --out "$ICO/icon_${s}x${s}.png" >/dev/null 2>&1
      d=$((s*2)); /usr/bin/sips -z $d $d "$STATE/icon.png" --out "$ICO/icon_${s}x${s}@2x.png" >/dev/null 2>&1
    done
    /usr/bin/iconutil -c icns "$ICO" -o "$STATE/Samanvaya.icns" 2>/dev/null
    /bin/cp "$STATE/Samanvaya.icns" "$DEST/Contents/Resources/Terminal.icns"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.motadata.samanvaya.notifier" "$DEST/Contents/Info.plist" 2>/dev/null
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Samanvaya" "$DEST/Contents/Info.plist" 2>/dev/null
    /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
    /usr/bin/codesign --force --deep -s - "$DEST" >/dev/null 2>&1
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$DEST" 2>/dev/null
    echo "  built $DEST"
  else echo "  ! terminal-notifier.app not found at $APP_SRC — skipped"; fi
else echo "  skipped (no icon or no brew)"; fi

say "4) Warp launch configs"
USE_WARP=0
{ [ "$OPENER" = warp ] || { [ "$OPENER" = auto ] && [ -d /Applications/Warp.app ]; }; } && USE_WARP=1
if [ "$USE_WARP" = 1 ] && [ -d /Applications/Warp.app ]; then
  mkdir -p "$HOME/.warp/launch_configurations"
  PREFIX=""; [ -d "$HOME/.claude-max" ] && PREFIX="CLAUDE_CONFIG_DIR=$HOME/.claude-max "
  for pair in "plan|plan my day" "close|close my day"; do
    c="${pair%%|*}"; phrase="${pair#*|}"
    cat > "$HOME/.warp/launch_configurations/myday-$c.yaml" <<YAML
name: myday-$c
windows:
  - tabs:
      - layout:
          cwd: "$WORKDIR"
          commands:
            - exec: ${PREFIX}claude "$phrase"
YAML
  done
  echo "  wrote myday-plan.yaml / myday-close.yaml (cwd=$WORKDIR)"
else echo "  using $OPENER — clicks open Terminal/iTerm directly (no Warp config needed)"; fi

say "5) pre-trust $WORKDIR (no trust prompt)"
CFGDIR="$HOME/.claude-max"; [ -d "$CFGDIR" ] || CFGDIR="$HOME/.claude"
CJSON="$CFGDIR/.claude.json"; [ -f "$CJSON" ] || CJSON="$HOME/.claude.json"
/usr/bin/python3 - "$CJSON" "$WORKDIR" <<'PY' 2>/dev/null || echo "  (skipped — accept the trust prompt once, or re-run with Claude closed)"
import json,sys
f,folder=sys.argv[1],sys.argv[2]
d=json.load(open(f))
d.setdefault("projects",{}).setdefault(folder,{})["hasTrustDialogAccepted"]=True
json.dump(d,open(f,"w"),indent=2)
print("  pre-trusted",folder,"in",f)
PY

say "done"
echo "Test:  \"$TN\" -title 'Plan your day' -message 'test' -execute \"\$HOME/bin/sam-open-claude plan\""
echo "(If the trust pre-set was skipped, close Claude/VS Code and re-run step 5, or just accept the prompt once.)"
