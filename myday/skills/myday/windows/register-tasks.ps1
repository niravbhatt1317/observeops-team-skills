<#
  register-tasks.ps1 — install the Samanvaya daily routine as Windows Scheduled Tasks.
  Mirrors the macOS launchd setup:
     09:00 remind-plan  |  11:00 remind-plan  |  11:30 auto-plan
     17:35 remind-close |  18:00 auto-close
  Run in an ADMIN PowerShell (or accept the per-task UAC).  Uses the current user.
  Remove with:  .\register-tasks.ps1 -Remove
#>
param([switch]$Remove)
$ErrorActionPreference='Stop'
$engine = Join-Path $PSScriptRoot '..\bin\sam_daily.ps1'
$engine = (Resolve-Path $engine).Path
$psExe  = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

$jobs = @(
  @{ Name='MyDay-RemindPlanAM';   Mode='remind-plan';  Time='09:00' },
  @{ Name='MyDay-RemindPlanLate'; Mode='remind-plan';  Time='11:00' },
  @{ Name='MyDay-PlanFallback';   Mode='morning';      Time='11:30' },
  @{ Name='MyDay-RemindClose';    Mode='remind-close'; Time='17:35' },
  @{ Name='MyDay-Close';          Mode='close';        Time='18:00' }
)

if ($Remove) {
  foreach ($j in $jobs) { Unregister-ScheduledTask -TaskName $j.Name -Confirm:$false -ErrorAction SilentlyContinue }
  Write-Host "Removed all MyDay scheduled tasks."; exit 0
}

foreach ($j in $jobs) {
  $action  = New-ScheduledTaskAction -Execute $psExe `
             -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$engine`" $($j.Mode)"
  $trigger = New-ScheduledTaskTrigger -Daily -At $j.Time
  # only run when the user is logged on and (optionally) on any network
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $j.Name -Action $action -Trigger $trigger -Settings $settings -Force `
    -Description "Samanvaya $($j.Mode) at $($j.Time)" | Out-Null
  Write-Host ("registered: {0,-22} {1}  ({2})" -f $j.Name, $j.Time, $j.Mode)
}
Write-Host "`nDone. See them in Task Scheduler, or:  Get-ScheduledTask MyDay-*"
Write-Host "Note: runs only while you're logged in AND on the office VPN (private portal)."
