#!/bin/sh
# dhun control — test, mute and inspect an installed sound pack.
#
#   dhunctl.sh test [done|attention|permission|error]
#   dhunctl.sh pause [30m|2h|1d] [done|attention|permission|error]
#   dhunctl.sh resume [done|attention|error|all]
#   dhunctl.sh status
#   dhunctl.sh doctor
#
# Mute is a flag file, so it takes effect immediately — no session restart.

set -u

BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLAY="$BASE/hooks/dhun-play.sh"
EVENTS="done attention permission error"

# "90m" / "2h" / "1d" -> seconds
to_seconds() {
  n=$(printf '%s' "$1" | tr -dc '0-9')
  case "$1" in
    *s) echo $((n)) ;;
    *m) echo $((n * 60)) ;;
    *h) echo $((n * 3600)) ;;
    *d) echo $((n * 86400)) ;;
    *)  echo $((n * 60)) ;;   # bare number = minutes
  esac
}

mute_state() {
  f="$BASE/muted${1:+.$1}"
  if [ -f "$f" ]; then
    expiry=$(cat "$f" 2>/dev/null)
    if [ -n "$expiry" ]; then
      now=$(date +%s)
      if [ "$now" -ge "$expiry" ] 2>/dev/null; then rm -f "$f"; echo "on"; return; fi
      echo "until $(date -r "$expiry" '+%H:%M' 2>/dev/null || date -d "@$expiry" '+%H:%M' 2>/dev/null)"
      return
    fi
    echo "paused"
  else
    echo "on"
  fi
}

cmd=${1:-status}; shift 2>/dev/null || true

case "$cmd" in
  test)
    for e in ${1:-$EVENTS}; do
      printf '  %-10s ' "$e"
      # Bypass mute for tests — you asked to hear it.
      case "$(uname -s)" in
        Darwin) afplay -v 0.75 "$BASE/sounds/wav/$e.wav" ;;
        *)      "$PLAY" "$e" 0.75 ;;
      esac
      echo "played"
    done
    ;;

  pause)
    dur=""; ev=""
    for a in "$@"; do
      case "$a" in
        done|attention|permission|error) ev=$a ;;
        *) dur=$a ;;
      esac
    done
    f="$BASE/muted${ev:+.$ev}"
    if [ -n "$dur" ]; then
      echo $(( $(date +%s) + $(to_seconds "$dur") )) > "$f"
      echo "paused ${ev:-all sounds} for $dur — resumes automatically"
    else
      : > "$f"
      echo "paused ${ev:-all sounds} — run 'resume' to turn back on"
    fi
    ;;

  resume)
    ev=${1:-all}
    if [ "$ev" = all ]; then
      rm -f "$BASE"/muted "$BASE"/muted.*
      echo "resumed all sounds"
    else
      rm -f "$BASE/muted.$ev"
      echo "resumed $ev"
    fi
    ;;

  status)
    echo "dhun — installed at $BASE"
    echo
    printf "  %-12s %-10s %s\n" EVENT STATE SOUND
    printf "  %-12s %-10s %s\n" "all" "$(mute_state)" "-"
    for e in $EVENTS; do
      d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$BASE/sounds/wav/$e.wav" 2>/dev/null)
      printf "  %-12s %-10s %s\n" "$e" "$(mute_state "$e")" "$e.wav${d:+ (${d%.*}s)}"
    done
    ;;

  doctor)
    echo "dhun doctor"
    echo
    echo "  install dir   : $BASE"
    echo "  config dir    : ${CLAUDE_CONFIG_DIR:-$HOME/.claude (default)}"
    printf "  hooks wired   : "
    s="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    if [ -f "$s" ] && grep -q "dhun" "$s" 2>/dev/null; then echo "yes"; else echo "NO — run install"; fi
    printf "  audio player  : "
    case "$(uname -s)" in
      Darwin) command -v afplay >/dev/null && echo "afplay" || echo "MISSING" ;;
      Linux)  for p in paplay ffplay aplay mpv; do command -v $p >/dev/null && { echo "$p"; break; }; done ;;
      *)      echo "powershell (assumed)" ;;
    esac
    printf "  muted         : %s\n" "$(mute_state)"
    echo
    echo "  If you hear nothing: restart Claude Code — hooks load at session start."
    echo "  Remote/SSH/web sessions cannot play audio on your machine at all."
    ;;

  *) sed -n '2,12p' "$0" ;;
esac
