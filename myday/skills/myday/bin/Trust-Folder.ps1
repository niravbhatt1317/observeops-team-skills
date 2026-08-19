<#
  Trust-Folder.ps1 — pre-accept Claude Code's folder-trust for a folder, so it never prompts.
  Safely merges  projects.<folder>.hasTrustDialogAccepted = $true  into the Claude config JSON.
  RUN WHILE CLAUDE / VS CODE IS CLOSED (Claude rewrites this file on exit).

  Usage:
    .\Trust-Folder.ps1                      # trusts your user profile folder
    .\Trust-Folder.ps1 -Folder "C:\work\x"  # trusts a specific folder
    .\Trust-Folder.ps1 -ConfigDir "$env:USERPROFILE\.claude"   # if you use a custom config dir
#>
param(
  [string]$Folder   = $env:USERPROFILE,
  [string]$ConfigDir = $env:USERPROFILE      # dir that holds .claude.json (or CLAUDE_CONFIG_DIR)
)
$ErrorActionPreference='Stop'
$cfg = Join-Path $ConfigDir '.claude.json'
if (-not (Test-Path $cfg)) { Write-Error "No Claude config at $cfg. Open Claude once, then re-run."; exit 1 }

# back up first
Copy-Item $cfg "$cfg.bak" -Force

$json = Get-Content $cfg -Raw | ConvertFrom-Json
if (-not $json.projects) { $json | Add-Member -NotePropertyName projects -NotePropertyValue (@{}) -Force }

# projects is an object keyed by absolute path; add/update the entry
$proj = $json.projects
if ($proj.PSObject.Properties.Name -contains $Folder) {
  $proj.$Folder | Add-Member -NotePropertyName hasTrustDialogAccepted -NotePropertyValue $true -Force
} else {
  $proj | Add-Member -NotePropertyName $Folder -NotePropertyValue ([pscustomobject]@{ hasTrustDialogAccepted = $true }) -Force
}

$json | ConvertTo-Json -Depth 40 | Set-Content -Path $cfg -Encoding UTF8
Write-Host "Trusted folder: $Folder  (in $cfg)"
Write-Host "Backup saved:   $cfg.bak"
