<#
  register-protocol.ps1 - register the  myday://  URL protocol for the current user (no admin).
  Toast buttons open  myday://plan / myday://close , which Windows routes to open-claude.ps1.
  Run:  .\register-protocol.ps1        (remove with -Remove)
#>
param([switch]$Remove)
$ErrorActionPreference='Stop'
$root = 'HKCU:\Software\Classes\myday'

if ($Remove) {
  if (Test-Path $root) { Remove-Item $root -Recurse -Force }
  Write-Host "Removed myday:// protocol."; exit 0
}

# Point at the STABLE ~\bin copy (survives plugin version bumps); fall back to the cache if missing.
$launcher = "$env:USERPROFILE\bin\open-claude.ps1"
if (-not (Test-Path $launcher)) { $launcher = (Resolve-Path (Join-Path $PSScriptRoot 'open-claude.ps1')).Path }
$psExe    = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$command  = "`"$psExe`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`" `"%1`""

New-Item -Path $root -Force | Out-Null
New-ItemProperty -Path $root -Name '(default)'    -Value 'URL:MyDay Protocol' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $root -Name 'URL Protocol' -Value ''                    -PropertyType String -Force | Out-Null
New-Item -Path "$root\shell\open\command" -Force | Out-Null
New-ItemProperty -Path "$root\shell\open\command" -Name '(default)' -Value $command -PropertyType String -Force | Out-Null

Write-Host "Registered myday:// -> $launcher"
Write-Host "Test it:  Start-Process 'myday://plan'"
