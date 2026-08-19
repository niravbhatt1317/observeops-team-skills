<#
  open-claude.ps1 — invoked by the myday:// URL protocol when a toast button is clicked.
  Opens Windows Terminal (or PowerShell) running `claude "<phrase>"` in a TRUSTED folder,
  so Claude comes up already asking what you're planning — no typing.
  Windows parallel of macOS sam-open-claude (which opens Warp).

  Arg is the full URI, e.g. "myday://plan" or "myday://close".
#>
param([string]$Uri = 'myday://plan')

$cmd = ($Uri -replace '^myday://','').TrimEnd('/').ToLower()
switch ($cmd) {
  'close' { $phrase = 'close my day' }
  default { $phrase = 'plan my day' }
}

# Launch in a trusted folder so Claude never shows the trust prompt (pre-trust it with Trust-Folder.ps1).
$work = "$env:USERPROFILE\Claude-Projects"
if (-not (Test-Path $work)) { $work = $env:USERPROFILE }

# If you use a custom Claude config dir, set it here (macOS used CLAUDE_CONFIG_DIR=~/.claude-max).
$prefix = ''
if ($env:MYDAY_CLAUDE_CONFIG_DIR) { $prefix = "`$env:CLAUDE_CONFIG_DIR='$($env:MYDAY_CLAUDE_CONFIG_DIR)'; " }

$inner = "$prefix Set-Location `"$work`"; claude `"$phrase`""

if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
  # Windows Terminal
  Start-Process wt.exe -ArgumentList @('new-tab','powershell','-NoExit','-NoProfile','-Command', $inner)
} else {
  # fallback: plain PowerShell window
  Start-Process powershell -ArgumentList @('-NoExit','-NoProfile','-Command', $inner)
}
