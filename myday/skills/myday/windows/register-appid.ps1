<#
  register-appid.ps1 - brand the toast identity as "Samanvaya" (name + logo).
  Registers a custom AppUserModelID so notifications show "Samanvaya" and the logo at the top,
  instead of "Windows PowerShell". Windows twin of the macOS Samanvaya.app.
  Run:  .\register-appid.ps1        (remove with -Remove)
  Do step 6 (grab icon.png) first so the logo is available.
#>
param([switch]$Remove)
$ErrorActionPreference='Stop'
$aumid = if ($env:MYDAY_AUMID) { $env:MYDAY_AUMID } else { 'Motadata.Samanvaya' }
$root  = "HKCU:\Software\Classes\AppUserModelId\$aumid"

if ($Remove) {
  if (Test-Path $root) { Remove-Item $root -Recurse -Force }
  Write-Host "Removed AUMID '$aumid'."; exit 0
}

$png = "$env:USERPROFILE\.samanvaya\icon.png"
$ico = "$env:USERPROFILE\.samanvaya\icon.ico"

# Prefer an .ico for the notification identity; build one from the png if possible.
$iconPath = $null
if (Test-Path $ico) { $iconPath = $ico }
elseif (Test-Path $png) {
  try {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap $png
    $h   = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $fs  = [System.IO.File]::Create($ico); $h.Save($fs); $fs.Close()
    $iconPath = $ico
  } catch { $iconPath = $png }   # fall back to png if conversion fails
}

New-Item -Path $root -Force | Out-Null
New-ItemProperty -Path $root -Name 'DisplayName'          -Value 'Samanvaya' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $root -Name 'IconBackgroundColor'  -Value 'FF0B0D12' -PropertyType String -Force | Out-Null
if ($iconPath) { New-ItemProperty -Path $root -Name 'IconUri' -Value $iconPath -PropertyType String -Force | Out-Null }

Write-Host "Registered AUMID '$aumid' as 'Samanvaya'"
$iconMsg = if ([string]::IsNullOrEmpty($iconPath)) { '(none - run the icon step to grab icon.png)' } else { $iconPath }
Write-Host "  icon: $iconMsg"
Write-Host "Toasts from sam_daily.ps1 will now show under this identity."
