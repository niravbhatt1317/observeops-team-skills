<#
  sam_daily.ps1 — Samanvaya daily automation engine (Windows / PowerShell).
  Mirrors sam_daily.py. Modes:
    morning       ensure today's day is planned (+5) and write a Desktop brief
    close         close today's day with per-item remarks (+8)
    remind-plan   toast nudge to plan (only if not planned)
    remind-close  toast nudge to close (only if planned & not closed)
  -DryRun computes/logs intended actions but sends NO writes.

  Password is read from a DPAPI-encrypted file at runtime (see WINDOWS-SETUP.md).
#>
param(
  [Parameter(Position=0)][ValidateSet('morning','close','remind-plan','remind-close')][string]$Mode='morning',
  [switch]$DryRun
)
$ErrorActionPreference='Stop'

# ---------- config ----------
$BASE   = if ($env:SAM_BASE) { $env:SAM_BASE } else { 'http://172.16.15.82:5000' }
$ID     = if ($env:SAM_ID)   { $env:SAM_ID }   else { 'nirav.bhatt@motadata.com' }
$STATE  = if ($env:SAM_STATE){ $env:SAM_STATE }else { "$env:USERPROFILE\.samanvaya" }
$PWFILE = Join-Path $STATE 'pw.txt'
$BRIEF  = "$env:USERPROFILE\Desktop\Samanvaya-Today.md"
$TEAMS  = Join-Path $STATE 'teams.json'
$ICON   = Join-Path $STATE 'icon.png'
$AUMID  = if ($env:MYDAY_AUMID) { $env:MYDAY_AUMID } else { 'Motadata.Samanvaya' }  # branded toast identity
$TODAY  = (Get-Date).ToString('yyyy-MM-dd')
New-Item -ItemType Directory -Force $STATE | Out-Null
$script:Session = $null
$script:MEMBER  = $null

function Log($m){ Write-Host ("[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss'), $m) }

function Toast-Args($base){
  # add logo + branded AppId (if the AUMID is registered) to a BurntToast splat
  if (Test-Path $ICON) { $base.AppLogo = $ICON }
  if (Test-Path "HKCU:\Software\Classes\AppUserModelId\$AUMID") { $base.AppId = $AUMID }
  return $base
}
function Notify($title,$msg){
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction Stop
      $a = Toast-Args @{ Text=@($title,$msg) }
      New-BurntToastNotification @a | Out-Null
      return
    }
  } catch {}
  try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($msg,$title) | Out-Null } catch {}
}

function Notify-Action($title,$msg,$proto,$btnText){
  # Clickable toast: the button opens a myday:// URL that launches Claude (see register-protocol.ps1).
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction Stop
      $btn = New-BTButton -Content $btnText -Arguments $proto -ActivationType Protocol
      $a = Toast-Args @{ Text=@($title,$msg); Button=$btn }
      New-BurntToastNotification @a | Out-Null
      return
    }
  } catch {}
  Notify $title $msg
}

function Test-Reachable {
  try { Invoke-WebRequest "$BASE/login" -TimeoutSec 6 -UseBasicParsing | Out-Null; $true } catch { $false }
}

function Get-PlainPassword {
  if (-not (Test-Path $PWFILE)) { throw "no stored password at $PWFILE (see WINDOWS-SETUP.md step 3)" }
  $sec  = Get-Content $PWFILE | ConvertTo-SecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Connect-Sam {
  if (-not (Test-Reachable)) {
    Notify 'Samanvaya' 'Not reachable — connect the VPN. Daily run skipped.'
    Log 'VPN off / unreachable — aborting.'; exit 3
  }
  $pw = Get-PlainPassword
  $body = @{ identifier=$ID; password=$pw } | ConvertTo-Json -Compress
  $pw = $null
  $r = Invoke-RestMethod "$BASE/api/admin/login" -Method Post -Body $body -ContentType 'application/json' -SessionVariable sess -TimeoutSec 20
  if (-not $r.ok) { throw "login rejected: $($r | ConvertTo-Json -Compress)" }
  $script:Session = $sess
  $me = ApiGet '/api/admin/me'
  $script:MEMBER = $me.member_id
  Log ("logged in as {0} (member {1})" -f $r.name, $script:MEMBER)
}

function ApiGet($path){ Invoke-RestMethod "$BASE$path" -WebSession $script:Session -TimeoutSec 25 }
function ApiPost($path,$obj){
  Invoke-RestMethod "$BASE$path" -Method Post -Body ($obj | ConvertTo-Json -Depth 6) -ContentType 'application/json' -WebSession $script:Session -TimeoutSec 25
}
function Wallet(){ try { (ApiGet "/api/portal/$($script:MEMBER)/gam/wallet").total_xp } catch { $null } }

function Teams-Post($url,$text){
  if (-not $url) { return }
  $card = @{ type='message'; attachments=@(@{
    contentType='application/vnd.microsoft.card.adaptive'
    content=@{ '$schema'='http://adaptivecards.io/schemas/adaptive-card.json'; type='AdaptiveCard'; version='1.4'
              body=@(@{ type='TextBlock'; text=$text; wrap=$true }) } }) }
  try { Invoke-RestMethod $url -Method Post -Body ($card|ConvertTo-Json -Depth 10) -ContentType 'application/json' -TimeoutSec 15 | Out-Null; Log 'posted to Teams' } catch {}
}
function Teams-Urls(){ if (Test-Path $TEAMS) { $c=Get-Content $TEAMS -Raw | ConvertFrom-Json; return @($c.channel,$c.dm) } else { return @($null,$null) } }

# ------------------------------------------------ MORNING (auto-plan)
function Do-Morning {
  Connect-Sam
  $m=$script:MEMBER
  $plan = ApiGet "/api/day/plan?member_id=$m&date=$TODAY"
  $status = $plan.plan.status
  $items  = @($plan.items)
  Log "plan status=$status items=$($items.Count)"
  if ($items.Count -eq 0) {
    $av = ApiGet "/api/day/available?member_id=$m&date=$TODAY"
    $cands = @($av.assigned) | Sort-Object @{e={ @{critical=0;high=1;medium=2;low=3}[$_.priority] }}
    foreach ($t in ($cands | Select-Object -First 6)) {
      if ($DryRun) { Log "DRY would add task $($t.id)" }
      else { $r = ApiPost '/api/day/add-from-task' @{member_id=$m;date=$TODAY;task_id=$t.id}; if ($r.ok){ Log "added task $($t.id)" } }
    }
    $plan = ApiGet "/api/day/plan?member_id=$m&date=$TODAY"; $status=$plan.plan.status; $items=@($plan.items)
  }
  if ($status -ne 'planned' -and $items.Count -gt 0) {
    if ($DryRun) { Log 'DRY would commit plan (+5)' }
    else { $r = ApiPost "/api/portal/$m/day/plan" @{date=$TODAY}; Log "plan commit ok=$($r.ok) (+5 if newly planned)" }
  } else { Log 'already planned; not re-committing' }
  Write-Brief $plan
  $open = @($items | Where-Object { -not $_.completed_at -and $_.status -ne 'done' }).Count
  Notify 'Morning brief' "$($items.Count) planned - $open open. Brief on your Desktop."
  $u = Teams-Urls
  if ($u[0]) { $roll = Team-Rollup; if ($roll) { Teams-Post $u[0] $roll } }
  if ($u[1]) { Teams-Post $u[1] "**Plan your day** - $($items.Count) items, $open open. (+5 when you plan)" }
}

function Team-Rollup {
  $ma = @(ApiGet '/api/admin/member-analytics')
  if ($ma.Count -le 1) { return $null }
  $lines = @("**Samanvaya team status - $TODAY**")
  foreach ($x in ($ma | Sort-Object name)) {
    $dot = if ($x.planned_today) {'🟢'} else {'⚪️'}
    $lines += "$dot $($x.name) - $($x.tasks_open) open, $($x.tasks_overdue) overdue, $($x.tasks_done_today) done today"
  }
  ($lines -join "`n`n")
}

function Write-Brief($plan){
  $items=@($plan.items)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("# Samanvaya - $TODAY`n")
  [void]$sb.AppendLine("## Today's plan")
  foreach ($i in $items) { $d = if ($i.completed_at -or $i.status -eq 'done') {'[x]'} else {'[ ]'}; [void]$sb.AppendLine("- $d **[$($i.priority)]** $($i.title)") }
  try { $sb.ToString() | Set-Content -Path $BRIEF -Encoding UTF8; Log "brief -> $BRIEF" } catch { Log "brief write failed: $_" }
}

# ------------------------------------------------ CLOSE (auto, +8)
function Do-Close {
  Connect-Sam
  $m=$script:MEMBER
  $plan = ApiGet "/api/day/plan?member_id=$m&date=$TODAY"
  if ($plan.plan.status -eq 'closed') { Log 'already closed'; Notify 'Samanvaya' 'Day already closed.'; return }
  $items=@($plan.items)
  if ($items.Count -eq 0) { Log 'no items'; return }
  $tasks = @(ApiGet '/api/tasks')
  $doneTasks = @($tasks | Where-Object { $_.completed_at } | ForEach-Object { $_.id })
  $closeItems=@(); $done=0
  foreach ($i in $items) {
    $isDone = $i.completed_at -or $i.status -eq 'done' -or ($doneTasks -contains $i.source_task_id)
    $es = if ($isDone) {'done'} else {'carried'}
    $rmk = if ($isDone) {'Done'} else {'Carried over'}   # +8 requires NON-EMPTY per-item remark
    if ($isDone) { $done++ }
    $closeItems += @{ id=$i.id; end_status=$es; remark=$rmk }
  }
  $note = "Completed $done/$($items.Count). (auto-closed via Claude)"
  $before = Wallet
  if ($DryRun) { Log "DRY would close: $note"; return }
  $r = ApiPost "/api/portal/$m/day/close" @{ date=$TODAY; note=$note; items=$closeItems }
  if ($r.ok) { $after = Wallet; Log "closed OK  XP $before -> $after"; Notify 'Day closed' "$done/$($items.Count) done. XP $before to $after." }
  else { Log "close failed"; Notify 'Samanvaya' 'Close failed - see log.' }
}

# ------------------------------------------------ REMINDERS (nudge only)
function Do-RemindPlan {
  Connect-Sam
  $plan = ApiGet "/api/day/plan?member_id=$($script:MEMBER)&date=$TODAY"
  if ($plan.plan.status -eq 'planned') { Log 'already planned - no nudge'; return }
  Notify-Action 'Plan your day' 'Click to plan today with Claude (+5)' 'myday://plan' 'Plan now'
}
function Do-RemindClose {
  Connect-Sam
  $plan = ApiGet "/api/day/plan?member_id=$($script:MEMBER)&date=$TODAY"
  if ($plan.plan.status -eq 'closed') { Log 'already closed - no nudge'; return }
  if ($plan.plan.status -ne 'planned') { Log 'not planned - skip'; return }
  Notify-Action 'Close your day' 'Click to close with Claude (+8)' 'myday://close' 'Close now'
}

switch ($Mode) {
  'morning'      { Do-Morning }
  'close'        { Do-Close }
  'remind-plan'  { Do-RemindPlan }
  'remind-close' { Do-RemindClose }
}
