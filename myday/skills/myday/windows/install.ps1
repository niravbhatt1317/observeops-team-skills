<#
  install.ps1 (Windows) — one-command myday setup. Run from the skill folder:
     powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
  Prompts for your email + password (hidden), then does everything Claude can't
  (it's blocked from secret entry / registry / scheduled tasks by design).
  Idempotent. -NoProtocol skips the click-to-open handler (use if you don't need it).
#>
param([string]$Email, [switch]$NoProtocol)
$ErrorActionPreference = 'Continue'
$skill = Split-Path $PSScriptRoot -Parent      # ...\skills\myday
Set-Location $skill
$STATE = "$env:USERPROFILE\.samanvaya"
New-Item -ItemType Directory -Force $STATE, "$env:USERPROFILE\bin", "$env:USERPROFILE\Claude-Projects" | Out-Null

if (-not $Email) { $Email = Read-Host "Your Samanvaya email" }

Write-Host "`n[1/8] Password (typed hidden, DPAPI-encrypted to you)" -ForegroundColor Cyan
if (Test-Path "$STATE\pw.txt") { Write-Host "  password already stored — skipping (delete $STATE\pw.txt to re-enter)" }
else { Read-Host -AsSecureString "  Samanvaya password" | ConvertFrom-SecureString | Out-File "$STATE\pw.txt"; Write-Host "  saved" }

Write-Host "[2/8] Scripts -> ~\bin" -ForegroundColor Cyan
Copy-Item .\bin\*.ps1 "$env:USERPROFILE\bin\" -Force

Write-Host "[3/8] BurntToast (toast notifications)" -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable BurntToast)) { Install-Module BurntToast -Scope CurrentUser -Force -AllowClobber } else { Write-Host "  already installed" }

Write-Host "[4/8] Your email -> SAM_ID" -ForegroundColor Cyan
setx SAM_ID $Email | Out-Null; $env:SAM_ID = $Email

Write-Host "[5/8] Samanvaya logo + branded toast identity" -ForegroundColor Cyan
try { curl.exe -s "http://172.16.15.82:5000/static/samanvaya-icon.png" -o "$STATE\icon.png" } catch {}
powershell -ExecutionPolicy Bypass -File .\windows\register-appid.ps1

Write-Host "[6/8] Pre-trust ~\Claude-Projects (CLOSE Claude/VS Code first for this to stick)" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .\bin\Trust-Folder.ps1 -Folder "$env:USERPROFILE\Claude-Projects"

if ($NoProtocol) { Write-Host "[7/8] Click-to-open protocol — SKIPPED (-NoProtocol)" -ForegroundColor DarkYellow }
else {
  Write-Host "[7/8] Click-to-open protocol (myday://)" -ForegroundColor Cyan
  powershell -ExecutionPolicy Bypass -File .\windows\register-protocol.ps1
}

Write-Host "[8/8] Daily schedule (5 tasks)" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .\windows\register-tasks.ps1

Write-Host "`nDone. Verify:" -ForegroundColor Green
Write-Host "  powershell -File `"$env:USERPROFILE\bin\sam.ps1`" check"
Write-Host "  powershell -File `"$env:USERPROFILE\bin\sam.ps1`" login"
Write-Host "  (click-to-open needs the 'claude' CLI on PATH; VS Code-only users can just run /myday plan)"
