# dhun -- play a notification sound on Windows.
#
#   dhun-play.ps1 <done|attention|permission|error> [volume]
#
# Volume is accepted and ignored: Media.SoundPlayer has no gain control. It is the
# only WAV player guaranteed present on a clean Windows box, which is why wav/ is
# canonical. Always exits 0 -- a hook must never fail a tool call.

param(
  [string]$Name = "",
  [double]$Volume = 0.75
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $Name) { exit 0 }

$base = Split-Path -Parent $PSScriptRoot
$file = Join-Path $base "sounds\wav\$Name.wav"
if (-not (Test-Path -LiteralPath $file)) { exit 0 }

# A flag file silences playback. Empty = indefinite; an epoch timestamp = paused
# until then, and the file removes itself on expiry. Same contract as the sh player.
function Test-Muted([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  $raw = (Get-Content -LiteralPath $path -Raw)
  if ($raw -and $raw.Trim()) {
    [int64]$expiry = 0
    if ([int64]::TryParse($raw.Trim(), [ref]$expiry)) {
      $now = [int64][Math]::Floor(
        (New-TimeSpan -Start (Get-Date "1970-01-01Z").ToUniversalTime() `
                      -End (Get-Date).ToUniversalTime()).TotalSeconds)
      if ($now -ge $expiry) {
        Remove-Item -LiteralPath $path -Force
        return $false
      }
    }
  }
  return $true
}

if (Test-Muted (Join-Path $base "muted"))       { exit 0 }
if (Test-Muted (Join-Path $base "muted.$Name")) { exit 0 }

# Test seam -- see dhun-play.sh. Logged instead of played when DHUN_DRY_RUN is set,
# so CI can assert which sound would fire on a runner with no sound device.
if ($env:DHUN_DRY_RUN) {
  Add-Content -LiteralPath $env:DHUN_DRY_RUN -Value "PLAYED $Name"
  exit 0
}

try {
  $player = New-Object Media.SoundPlayer $file
  $player.PlaySync()
} catch { }

exit 0
