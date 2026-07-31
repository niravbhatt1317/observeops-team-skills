#!/bin/sh
# dhun — install the sound hooks into a Claude Code config directory.
#
#   ./install.sh              install into the active config dir
#   ./install.sh --all        install into every config dir found
#   ./install.sh --dir PATH   install into a specific one
#   ./install.sh --uninstall  remove dhun hooks (leaves other hooks alone)
#
# Copies sounds + scripts into <config>/dhun/ so the install is self-contained
# and survives this project folder being moved or deleted.

set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=install
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all)       TARGETS="$HOME/.claude ${CLAUDE_CONFIG_DIR:-}" ;;
    --dir)       shift; TARGETS="$1" ;;
    --uninstall) MODE=uninstall ;;
    -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

[ -z "$TARGETS" ] && TARGETS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Merging settings.json needs a JSON tool. jq is preferred; python3 is the fallback so
# a machine with neither is the only hard failure.
# DHUN_JSON forces a backend. Exists so CI can exercise the python3 path on runners
# where jq sits on a read-only filesystem and cannot be hidden.
if [ "${DHUN_JSON:-}" = python3 ] && command -v python3 >/dev/null 2>&1; then JSON=python3
elif [ "${DHUN_JSON:-}" = jq ] && command -v jq >/dev/null 2>&1; then JSON=jq
elif command -v jq >/dev/null 2>&1;      then JSON=jq
elif command -v python3 >/dev/null 2>&1; then JSON=python3
else
  echo "error: need jq or python3 to edit settings.json safely" >&2
  echo "       macOS: brew install jq   ·   Debian/Ubuntu: apt install jq" >&2
  exit 1
fi

# merge_json <settings> <play> <errh> <mode>   -> writes <settings>.tmp
merge_json() {
  _s=$1; _play=$2; _errh=$3; _mode=$4
  if [ "$JSON" = jq ]; then
    if [ "$_mode" = uninstall ]; then
      jq '
        if .hooks then
          .hooks |= with_entries(
            .value |= map(select(
              [.hooks[]?.command // "" | test("/dhun/")] | any | not))
          ) | .hooks |= with_entries(select(.value | length > 0))
        else . end
        | if (.hooks // {}) == {} then del(.hooks) else . end
      ' "$_s" > "$_s.tmp"
    else
      jq --arg play "$_play" --arg errh "$_errh" '
        .hooks //= {}
        | .hooks |= with_entries(
            .value |= map(select(
              [.hooks[]?.command // "" | test("/dhun/")] | any | not)))
        | .hooks.Stop         = ((.hooks.Stop // []) + [{hooks:[{type:"command", command:($play + " done 0.75 &")}]}])
        | .hooks.PermissionRequest = ((.hooks.PermissionRequest // []) + [{hooks:[{type:"command", command:($play + " permission 0.75 &")}]}])
        | .hooks.Elicitation       = ((.hooks.Elicitation // []) + [{hooks:[{type:"command", command:($play + " permission 0.75 &")}]}])
        | .hooks.Notification = ((.hooks.Notification // []) + [
            {matcher:"agent_needs_input", hooks:[{type:"command", command:($play + " permission 0.75 &")}]},
            {matcher:"idle_prompt",       hooks:[{type:"command", command:($play + " attention 0.75 &")}]}
          ])
        | .hooks.PostToolUseFailure = ((.hooks.PostToolUseFailure // []) + [{matcher:"*", hooks:[{type:"command", command:($play + " error 0.75 &")}]}])
        | .hooks |= with_entries(select(.value | length > 0))
      ' "$_s" > "$_s.tmp"
    fi
  else
    DHUN_S="$_s" DHUN_PLAY="$_play" DHUN_ERRH="$_errh" DHUN_MODE="$_mode" python3 - <<'PY'
import json, os
s, play, errh, mode = (os.environ[k] for k in
                       ("DHUN_S", "DHUN_PLAY", "DHUN_ERRH", "DHUN_MODE"))
with open(s) as f:
    cfg = json.load(f)
hooks = cfg.get("hooks", {})

def is_dhun(entry):
    return any("/dhun/" in h.get("command", "") for h in entry.get("hooks", []))

# Strip previous dhun entries first, so install is idempotent.
hooks = {k: [e for e in v if not is_dhun(e)] for k, v in hooks.items()}

if mode != "uninstall":
    def cmd(c):
        return {"hooks": [{"type": "command", "command": c}]}
    def mcmd(m, c):
        return {"matcher": m, "hooks": [{"type": "command", "command": c}]}
    hooks.setdefault("Stop", []).append(cmd(play + " done 0.75 &"))
    hooks.setdefault("PermissionRequest", []).append(cmd(play + " permission 0.75 &"))
    hooks.setdefault("Elicitation", []).append(cmd(play + " permission 0.75 &"))
    hooks.setdefault("Notification", []).extend([
        mcmd("agent_needs_input", play + " permission 0.75 &"),
        mcmd("idle_prompt",       play + " attention 0.75 &"),
    ])
    hooks.setdefault("PostToolUseFailure", []).append(
        {"matcher": "*", "hooks": [{"type": "command", "command": play + " error 0.75 &"}]})

hooks = {k: v for k, v in hooks.items() if v}
if hooks:
    cfg["hooks"] = hooks
else:
    cfg.pop("hooks", None)
with open(s + ".tmp", "w") as f:
    json.dump(cfg, f, indent=2)
PY
  fi
}

# validate_json <file> -> exit status
validate_json() {
  if [ "$JSON" = jq ]; then jq empty "$1"
  else python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1"; fi
}

for CONFIG in $TARGETS; do
  [ -z "$CONFIG" ] && continue
  CONFIG=$(eval echo "$CONFIG")
  SETTINGS="$CONFIG/settings.json"
  DEST="$CONFIG/dhun"

  mkdir -p "$CONFIG"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

  # Never edit settings.json without a backup — it holds unrelated config.
  cp "$SETTINGS" "$SETTINGS.dhun-backup"

  if [ "$MODE" = uninstall ]; then
    merge_json "$SETTINGS" "" "" uninstall && mv "$SETTINGS.tmp" "$SETTINGS"
    rm -rf "$DEST"
    echo "uninstalled from $CONFIG (backup: $SETTINGS.dhun-backup)"
    continue
  fi

  # Replace rather than copy over the top: a plain cp -R leaves scripts behind that
  # a newer version has deleted, and a stale hook can still be referenced by an old
  # settings.json. Mute flags live at $DEST root, so they survive this.
  rm -rf "$DEST/hooks" "$DEST/sounds"
  mkdir -p "$DEST"
  cp -R "$SRC/sounds" "$DEST/"
  cp -R "$SRC/hooks"  "$DEST/"
  chmod +x "$DEST"/hooks/*.sh

  # On Windows, wire the PowerShell hooks. Claude Code falls back to PowerShell when
  # Git Bash isn't installed, and PowerShell cannot execute .sh at all. Doing this
  # regardless of how install ran means the runtime never depends on Git Bash.
  case "$(uname -s 2>/dev/null)" in
    CYGWIN*|MINGW*|MSYS*|Windows_NT)
      _p=$(cygpath -w "$DEST/hooks/dhun-play.ps1" 2>/dev/null || echo "$DEST/hooks/dhun-play.ps1")
      PLAY="powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$_p\""
      ;;
    *)
      PLAY="$DEST/hooks/dhun-play.sh"
      ;;
  esac

  merge_json "$SETTINGS" "$PLAY" "" install && mv "$SETTINGS.tmp" "$SETTINGS"

  validate_json "$SETTINGS" || { echo "error: produced invalid JSON, restoring" >&2
                                 mv "$SETTINGS.dhun-backup" "$SETTINGS"; exit 1; }

  echo "installed into $CONFIG"
  echo "  sounds : $DEST/sounds/wav/"
  echo "  backup : $SETTINGS.dhun-backup"
done

echo
echo "Restart Claude Code — hooks are loaded at session start."
