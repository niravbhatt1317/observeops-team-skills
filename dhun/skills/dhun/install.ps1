# dhun -- install the sound hooks into a Claude Code config directory (Windows).
#
#   .\install.ps1                 install into the active config dir
#   .\install.ps1 -All            install into every config dir found
#   .\install.ps1 -Dir PATH       install into a specific one
#   .\install.ps1 -Uninstall      remove dhun hooks, leave others alone
#
# The sh installer is the one to use on macOS/Linux, or on Windows with Git Bash.
# This exists so a clean Windows box with neither Git Bash nor jq can still install.

param(
  [switch]$All,
  [string]$Dir = "",
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$src = $PSScriptRoot

$targets = @()
if ($Dir)      { $targets += $Dir }
elseif ($All)  { $targets += (Join-Path $env:USERPROFILE ".claude")
                 if ($env:CLAUDE_CONFIG_DIR) { $targets += $env:CLAUDE_CONFIG_DIR } }
else           { $targets += $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR }
                               else { Join-Path $env:USERPROFILE ".claude" }) }

# PowerShell 5.1 has no ConvertFrom-Json -AsHashtable, so convert by hand.
function ConvertTo-Hashtable($obj) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
    return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
  }
  if ($obj -is [PSCustomObject]) {
    $h = @{}
    foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
    return $h
  }
  return $obj
}

function Test-DhunEntry($entry) {
  if (-not $entry.hooks) { return $false }
  foreach ($h in @($entry.hooks)) {
    if ("$($h.command)" -match 'dhun') { return $true }
  }
  return $false
}

foreach ($config in ($targets | Select-Object -Unique)) {
  if (-not $config) { continue }
  $settings = Join-Path $config "settings.json"
  $dest     = Join-Path $config "dhun"

  New-Item -ItemType Directory -Force -Path $config | Out-Null
  if (-not (Test-Path -LiteralPath $settings)) { Set-Content -LiteralPath $settings -Value "{}" }

  # Never edit settings.json without a backup -- it holds unrelated config.
  Copy-Item -LiteralPath $settings -Destination "$settings.dhun-backup" -Force

  $cfg = ConvertTo-Hashtable ((Get-Content -LiteralPath $settings -Raw) | ConvertFrom-Json)
  if ($null -eq $cfg) { $cfg = @{} }
  $hooks = if ($cfg.hooks) { $cfg.hooks } else { @{} }

  # Strip previous dhun entries first, so re-running is idempotent.
  $clean = @{}
  foreach ($k in $hooks.Keys) {
    $kept = @(@($hooks[$k]) | Where-Object { -not (Test-DhunEntry $_) })
    if ($kept.Count -gt 0) { $clean[$k] = $kept }
  }
  $hooks = $clean

  if ($Uninstall) {
    if ($hooks.Count -gt 0) { $cfg.hooks = $hooks } else { $cfg.Remove("hooks") }
    $cfg | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settings
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Write-Host "uninstalled from $config (backup: $settings.dhun-backup)"
    continue
  }

  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Path (Join-Path $src "sounds") -Destination $dest -Recurse -Force
  Copy-Item -Path (Join-Path $src "hooks")  -Destination $dest -Recurse -Force

  $ps   = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File"
  $play = "$ps `"$(Join-Path $dest 'hooks\dhun-play.ps1')`""

  function New-Cmd($c)     { @{ hooks = @(@{ type = "command"; command = $c }) } }
  function New-MCmd($m,$c) { @{ matcher = $m; hooks = @(@{ type = "command"; command = $c }) } }

  $hooks["Stop"]         = @(@($hooks["Stop"])         | Where-Object { $_ }) + @(New-Cmd "$play done 0.75")
  $hooks["PermissionRequest"] = @(@($hooks["PermissionRequest"]) | Where-Object { $_ }) + @(New-Cmd "$play permission 0.75")
  $hooks["Elicitation"]       = @(@($hooks["Elicitation"])       | Where-Object { $_ }) + @(New-Cmd "$play permission 0.75")
  $hooks["Notification"] = @(@($hooks["Notification"]) | Where-Object { $_ }) + @(
      (New-MCmd "agent_needs_input" "$play permission 0.75"),
      (New-MCmd "idle_prompt"       "$play attention 0.75"))
  $hooks["PostToolUseFailure"] = @(@($hooks["PostToolUseFailure"]) | Where-Object { $_ }) + @(
      @{ matcher = "*"; hooks = @(@{ type = "command"; command = "$play error 0.75" }) })

  $cfg.hooks = $hooks
  $cfg | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settings

  try { (Get-Content -LiteralPath $settings -Raw) | ConvertFrom-Json | Out-Null }
  catch {
    Write-Error "produced invalid JSON, restoring"
    Copy-Item -LiteralPath "$settings.dhun-backup" -Destination $settings -Force
    exit 1
  }

  Write-Host "installed into $config"
  Write-Host "  sounds : $dest\sounds\wav\"
  Write-Host "  backup : $settings.dhun-backup"
}

Write-Host ""
Write-Host "Restart Claude Code -- hooks are loaded at session start."
