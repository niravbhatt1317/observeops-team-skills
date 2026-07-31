#!/bin/sh
# dhun — play a notification sound, whatever the OS.
#
#   usage: dhun-play.sh <done|attention|error> [volume 0.0-1.0]
#
# Always exits 0: a missing audio player must never fail a Claude Code hook.

set -u

NAME="${1:-}"
VOL="${2:-0.75}"
[ -z "$NAME" ] && exit 0

BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd) || exit 0
FILE="$BASE/sounds/wav/$NAME.wav"
[ -f "$FILE" ] || exit 0

# --- mute -------------------------------------------------------------------
# A flag file silences playback. Empty file = indefinite; a file containing an
# epoch timestamp = paused until then, and the file deletes itself on expiry.
# Checked here so every hook honours it from one place, with no restart needed.
muted() {
  [ -f "$1" ] || return 1
  expiry=$(cat "$1" 2>/dev/null)
  if [ -n "$expiry" ] && [ "$(date +%s)" -ge "$expiry" ] 2>/dev/null; then
    rm -f "$1"
    return 1
  fi
  return 0
}

muted "$BASE/muted"       && exit 0   # everything
muted "$BASE/muted.$NAME" && exit 0   # just this one

# Test seam. Set DHUN_DRY_RUN to a file path and playback is logged instead of played,
# so CI can assert *which* sound would fire — including that mute suppressed it — on
# runners that have no sound device. Deliberately placed after the mute checks.
if [ -n "${DHUN_DRY_RUN:-}" ]; then
  echo "PLAYED $NAME" >> "$DHUN_DRY_RUN"
  exit 0
fi

play_macos() {
  afplay -v "$VOL" "$FILE"
}

play_linux() {
  # paplay takes volume as 0-65536; everything else ignores it.
  if command -v paplay >/dev/null 2>&1; then
    paplay --volume="$(awk -v v="$VOL" 'BEGIN{printf "%d", v*65536}')" "$FILE"
  elif command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit -loglevel quiet -volume "$(awk -v v="$VOL" 'BEGIN{printf "%d", v*100}')" "$FILE"
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "$FILE"
  elif command -v mpv >/dev/null 2>&1; then
    mpv --no-video --really-quiet --volume="$(awk -v v="$VOL" 'BEGIN{printf "%d", v*100}')" "$FILE"
  fi
}

play_windows() {
  # Media.SoundPlayer is WAV-only and has no volume control — hence wav/ being canonical.
  win_path=$FILE
  command -v cygpath >/dev/null 2>&1 && win_path=$(cygpath -w "$FILE")
  powershell.exe -NoProfile -Command \
    "(New-Object Media.SoundPlayer '$win_path').PlaySync()" >/dev/null 2>&1
}

case "$(uname -s 2>/dev/null)" in
  Darwin)                      play_macos   ;;
  Linux)
    # WSL reaches the Windows host's audio; native Linux uses its own stack.
    if grep -qi microsoft /proc/version 2>/dev/null; then play_windows; else play_linux; fi ;;
  CYGWIN*|MINGW*|MSYS*|Windows_NT) play_windows ;;
esac

exit 0
