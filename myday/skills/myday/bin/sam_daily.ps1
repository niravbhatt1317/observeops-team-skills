<#
  sam_daily.ps1 - Samanvaya daily automation engine (Windows / PowerShell). Mirrors sam_daily.py.
  Modes: morning | close | remind-plan | remind-close | team-plan-nudge | team-close-nudge
  -DryRun computes/logs intended actions but sends NO writes.
  ASCII-only on purpose (PS 5.1 misreads BOM-less UTF-8). Login: admin JSON, fall back to /portal/login.
#>
param(
  [Parameter(Position=0)][ValidateSet('morning','close','remind-plan','remind-close','team-plan-nudge','team-close-nudge')][string]$Mode='morning',
  [switch]$DryRun
)
$ErrorActionPreference='Stop'

# ---------- config ----------
$BASE   = if ($env:SAM_BASE) { $env:SAM_BASE } else { 'http://172.16.15.82:5000' }
$STATE  = if ($env:SAM_STATE){ $env:SAM_STATE }else { "$env:USERPROFILE\.samanvaya" }
New-Item -ItemType Directory -Force $STATE | Out-Null
# Identity: env SAM_ID, else ~/.samanvaya/id (scheduled tasks don't inherit setx/shell env). Never guess.
$ID     = if ($env:SAM_ID) { $env:SAM_ID } elseif (Test-Path "$STATE\id") { (Get-Content "$STATE\id" -Raw).Trim() } else { $null }
if (-not $ID) { Write-Error "sam_daily: no identity set. Set-Content `"$STATE\id`" 'you@motadata.com' (or SAM_ID)"; exit 2 }
$PWFILE = Join-Path $STATE 'pw.txt'
$BRIEF  = "$env:USERPROFILE\Desktop\Samanvaya-Today.md"
$TEAMS  = Join-Path $STATE 'teams.json'
$ICON   = Join-Path $STATE 'icon.png'
$AUMID  = if ($env:MYDAY_AUMID) { $env:MYDAY_AUMID } else { 'Motadata.Samanvaya' }
$TODAY  = (Get-Date).ToString('yyyy-MM-dd')
$LOGFILE= Join-Path $STATE 'daily.log'
$script:Session = $null
$script:MEMBER  = $null
$script:IsAdmin = $true

function Log($m){ $line = "[{0}] {1}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $m; Write-Host $line; try { Add-Content -Path $LOGFILE -Value $line } catch {} }

function Toast-Args($base){
  if (Test-Path $ICON) { $base.AppLogo = $ICON }
  $btSupportsAppId = @((Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue).Parameters.Keys) -contains 'AppId'
  if ($btSupportsAppId -and (Test-Path "HKCU:\Software\Classes\AppUserModelId\$AUMID")) { $base.AppId = $AUMID }
  return $base
}
function Notify($title,$msg){
  try { if (Get-Module -ListAvailable -Name BurntToast) { Import-Module BurntToast -ErrorAction Stop; $a = Toast-Args @{ Text=@($title,$msg) }; New-BurntToastNotification @a | Out-Null; return } } catch {}
  try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($msg,$title) | Out-Null } catch {}
}
function Notify-Action($title,$msg,$proto,$btnText){
  try { if (Get-Module -ListAvailable -Name BurntToast) { Import-Module BurntToast -ErrorAction Stop; $btn = New-BTButton -Content $btnText -Arguments $proto -ActivationType Protocol; $a = Toast-Args @{ Text=@($title,$msg); Button=$btn }; New-BurntToastNotification @a | Out-Null; return } } catch {}
  Notify $title $msg
}
function Notify-Retry($title,$msg,$mode){
  try { if (Get-Module -ListAvailable -Name BurntToast) { Import-Module BurntToast -ErrorAction Stop; $btn = New-BTButton -Content 'Retry' -Arguments "myday://retry/$mode" -ActivationType Protocol; $a = Toast-Args @{ Text=@($title,$msg); Button=$btn }; New-BurntToastNotification @a | Out-Null; return } } catch {}
  Notify $title $msg
}

function Test-Reachable { try { Invoke-WebRequest "$BASE/login" -TimeoutSec 6 -UseBasicParsing | Out-Null; $true } catch { $false } }

function Get-PlainPassword {
  if (-not (Test-Path $PWFILE)) { throw "no stored password at $PWFILE (run install.ps1)" }
  $sec  = Get-Content $PWFILE | ConvertTo-SecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Connect-Sam {
  if (-not (Test-Reachable)) { Notify-Retry 'Samanvaya' 'Not reachable - connect the VPN, then click Retry.' $Mode; Log 'VPN off / unreachable - aborting.'; exit 3 }
  $pw = Get-PlainPassword
  # 1st door: admin JSON login (admin / workspace accounts)
  $body = @{ identifier=$ID; password=$pw } | ConvertTo-Json -Compress
  try {
    $r = Invoke-RestMethod "$BASE/api/admin/login" -Method Post -Body $body -ContentType 'application/json' -SessionVariable sess -TimeoutSec 20
    if ($r.ok) {
      $pw = $null; $script:Session = $sess; $script:IsAdmin = $true
      $me = Invoke-RestMethod "$BASE/api/admin/me" -WebSession $sess -TimeoutSec 25
      $script:MEMBER = $me.member_id
      Log ("logged in as {0} (member {1}, admin)" -f $r.name, $script:MEMBER); return
    }
  } catch {
    $code = 0; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -ne 403) { $pw = $null; throw }
    # 403 NOT_ADMIN = valid creds, plain team member -> portal door
  }
  # 2nd door: team-member portal FORM login (follows the 302 to /portal/<id>)
  $pr = Invoke-WebRequest "$BASE/portal/login" -Method Post -Body @{ identifier=$ID; password=$pw } -SessionVariable psess -TimeoutSec 20 -UseBasicParsing
  $pw = $null
  $landed = "$($pr.BaseResponse.ResponseUri)"
  if ($landed -match '/portal/(\d+)') { $script:Session = $psess; $script:MEMBER = [int]$Matches[1]; $script:IsAdmin = $false; Log ("logged in as {0} (member {1}, portal)" -f $ID, $script:MEMBER); return }
  throw "portal login rejected (landed on $landed)"
}
function ApiGet($path){ Invoke-RestMethod "$BASE$path" -WebSession $script:Session -TimeoutSec 25 }
function ApiPost($path,$obj){ Invoke-RestMethod "$BASE$path" -Method Post -Body ($obj | ConvertTo-Json -Depth 8) -ContentType 'application/json' -WebSession $script:Session -TimeoutSec 25 }
function Wallet(){ try { (ApiGet "/api/portal/$($script:MEMBER)/gam/wallet").total_xp } catch { $null } }

function Teams-Urls(){ if (Test-Path $TEAMS) { $c=Get-Content $TEAMS -Raw | ConvertFrom-Json; return @($c.channel,$c.dm) } else { return @($null,$null) } }
function Teams-Post($url,$text,$entities){
  if (-not $url) { return }
  $content = [ordered]@{ '$schema'='http://adaptivecards.io/schemas/adaptive-card.json'; type='AdaptiveCard'; version='1.4'; body=@(@{ type='TextBlock'; text=$text; wrap=$true }) }
  if ($entities -and @($entities).Count -gt 0) { $content.msteams = @{ entities = $entities } }
  $card = @{ type='message'; attachments=@(@{ contentType='application/vnd.microsoft.card.adaptive'; content=$content }) }
  try { Invoke-RestMethod $url -Method Post -Body ($card|ConvertTo-Json -Depth 12) -ContentType 'application/json' -TimeoutSec 15 | Out-Null; Log 'posted to Teams' } catch {}
}
function Mentions-Map(){ $f = Join-Path $STATE 'team-mentions.json'; if (Test-Path $f) { try { return (Get-Content $f -Raw | ConvertFrom-Json) } catch {} }; return $null }
function Mention($name,$map){
  $email = $null; if ($map) { $p = $map.PSObject.Properties[$name]; if ($p) { $email = $p.Value } }
  if ($email) { $tok = "<at>$name</at>"; return @{ tok=$tok; ent=@{ type='mention'; text=$tok; mentioned=@{ id=$email; name=$name } } } }
  return @{ tok=$name; ent=$null }
}

# ------------------------------------------------ MORNING (auto-plan)
function Do-Morning {
  Connect-Sam
  $m=$script:MEMBER
  $plan = ApiGet "/api/portal/$m/day?date=$TODAY"
  $status = $plan.plan.status; $items = @($plan.items)
  Log "plan status=$status items=$($items.Count)"
  if ($items.Count -eq 0) {
    $tasks = @(ApiGet "/api/portal/$m/tasks")
    $inPlan = @($items | ForEach-Object { $_.source_task_id })
    $cands = @($tasks | Where-Object { $_.status -ne 'done' -and -not $_.completed_at -and ($inPlan -notcontains $_.id) }) | Sort-Object @{e={ @{critical=0;high=1;medium=2;low=3}[$_.priority] }}
    foreach ($t in ($cands | Select-Object -First 6)) {
      if ($DryRun) { Log "DRY would add task $($t.id)" }
      else { $r = ApiPost "/api/portal/$m/day/add-from-task" @{date=$TODAY;task_id=$t.id}; if ($r.ok){ Log "added task $($t.id)" } }
    }
    $plan = ApiGet "/api/portal/$m/day?date=$TODAY"; $status=$plan.plan.status; $items=@($plan.items)
  }
  if ($status -ne 'planned' -and $items.Count -gt 0) {
    if ($DryRun) { Log 'DRY would commit plan (+5)' } else { $r = ApiPost "/api/portal/$m/day/plan" @{date=$TODAY}; Log "plan commit ok=$($r.ok) (+5 if newly planned)" }
  } else { Log 'already planned; not re-committing' }
  Write-Brief $plan
  $open = @($items | Where-Object { -not $_.completed_at -and $_.status -ne 'done' }).Count
  Notify 'Morning brief' "$($items.Count) planned - $open open. Brief on your Desktop."
  $u = Teams-Urls
  if ($u[0]) { $roll = Team-Rollup; if ($roll) { Teams-Post $u[0] $roll $null } }
  if ($u[1]) { Teams-Post $u[1] "**Plan your day** - $($items.Count) items, $open open. (+5 when you plan)" $null }
}

function Team-Rollup {
  if (-not $script:IsAdmin) { return $null }
  $ma = @(); try { $ma = @(ApiGet '/api/admin/member-analytics') } catch { Log 'member-analytics unavailable (not a manager)'; return $null }
  if ($ma.Count -le 1) { return $null }
  $lines = @("**Samanvaya team status - $TODAY**")
  foreach ($x in ($ma | Sort-Object name)) {
    $dot = if ($x.planned_today) {'[+]'} else {'[ ]'}
    $lines += "$dot $($x.name) - $($x.tasks_open) open, $($x.tasks_overdue) overdue, $($x.tasks_done_today) done today"
  }
  ($lines -join "`n`n")
}

function Write-Brief($plan){
  $items=@($plan.items)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("# Samanvaya - $TODAY`n"); [void]$sb.AppendLine("## Today's plan")
  foreach ($i in $items) { $d = if ($i.completed_at -or $i.status -eq 'done') {'[x]'} else {'[ ]'}; [void]$sb.AppendLine("- $d **[$($i.priority)]** $($i.title)") }
  try { $sb.ToString() | Set-Content -Path $BRIEF -Encoding UTF8; Log "brief -> $BRIEF" } catch { Log "brief write failed: $_" }
}

# ------------------------------------------------ CLOSE (auto, +8)
function Do-Close {
  Connect-Sam
  $m=$script:MEMBER
  $plan = ApiGet "/api/portal/$m/day?date=$TODAY"
  if ($plan.plan.status -eq 'closed') { Log 'already closed'; Notify 'Samanvaya' 'Day already closed.'; return }
  $items=@($plan.items); if ($items.Count -eq 0) { Log 'no items'; return }
  $tasks = @(); try { $tasks = @(ApiGet "/api/portal/$m/tasks") } catch {}
  $doneTasks = @($tasks | Where-Object { $_.completed_at } | ForEach-Object { $_.id })
  $closeItems=@(); $done=0
  foreach ($i in $items) {
    $isDone = $i.completed_at -or $i.status -eq 'done' -or ($doneTasks -contains $i.source_task_id)
    $es = if ($isDone) {'done'} else {'carried'}; $rmk = if ($isDone) {'Done'} else {'Carried over'}
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
  $plan = ApiGet "/api/portal/$($script:MEMBER)/day?date=$TODAY"
  if ($plan.plan.status -eq 'planned') { Log 'already planned - no nudge'; return }
  Notify-Action 'Plan your day' 'Click to plan today with Claude (+5)' 'myday://plan' 'Plan now'
}
function Do-RemindClose {
  Connect-Sam
  $plan = ApiGet "/api/portal/$($script:MEMBER)/day?date=$TODAY"
  if ($plan.plan.status -eq 'closed') { Log 'already closed - no nudge'; return }
  if ($plan.plan.status -ne 'planned') { Log 'not planned - skip'; return }
  Notify-Action 'Close your day' 'Click to close with Claude (+8)' 'myday://close' 'Close now'
}

# ------------------------------------------------ TEAM NUDGES (manager-only)
function Reportees(){ if (-not $script:IsAdmin) { return $null }; try { $ma = @(ApiGet '/api/admin/member-analytics'); if ($ma.Count -gt 1) { return $ma } } catch {}; return $null }
function Do-TeamPlanNudge(){
  Connect-Sam
  $ma = Reportees; if (-not $ma) { Log 'not a manager / no reportees'; return }
  $late = @($ma | Where-Object { -not $_.planned_today } | Sort-Object name)
  $chan = (Teams-Urls)[0]
  if ($late.Count -eq 0) { if ($chan) { Teams-Post $chan "Plan check - $TODAY - everyone has planned." $null }; Log 'all planned'; return }
  $map = Mentions-Map; $toks=@(); $ents=@()
  foreach ($x in $late) { $mm = Mention $x.name $map; $toks += $mm.tok; if ($mm.ent) { $ents += $mm.ent } }
  $msg = "**Plan check - $TODAY** - not planned yet ($($late.Count)/$($ma.Count)): " + ($toks -join ', ') + "`n`nClick your reminder or run /myday plan (+5)."
  if ($chan) { Teams-Post $chan $msg $ents }
  Log "team plan nudge: $($late.Count) not planned"
}
function Do-TeamCloseNudge(){
  Connect-Sam
  $ma = Reportees; if (-not $ma) { Log 'not a manager / no reportees'; return }
  $late = @()
  foreach ($x in $ma) {
    $st = $null; try { $p = ApiGet "/api/day/plan?member_id=$($x.id)&date=$TODAY"; $st = $p.plan.status } catch {}
    if ($st -ne 'closed') { $late += [pscustomobject]@{ name=$x.name; s=(if ($st -ne 'planned') {'not planned'} else {'planned, not closed'}) } }
  }
  $chan = (Teams-Urls)[0]
  if ($late.Count -eq 0) { if ($chan) { Teams-Post $chan "Close check - $TODAY - everyone has closed." $null }; Log 'all closed'; return }
  $map = Mentions-Map; $parts=@(); $ents=@()
  foreach ($x in ($late | Sort-Object name)) { $mm = Mention $x.name $map; $parts += "$($mm.tok) ($($x.s))"; if ($mm.ent) { $ents += $mm.ent } }
  $msg = "**Close check - $TODAY** - not closed yet ($($late.Count)/$($ma.Count)): " + ($parts -join '; ') + "`n`nClick your reminder or run /myday close (+8)."
  if ($chan) { Teams-Post $chan $msg $ents }
  Log "team close nudge: $($late.Count) not closed"
}

try {
  switch ($Mode) {
    'morning'          { Do-Morning }
    'close'            { Do-Close }
    'remind-plan'      { Do-RemindPlan }
    'remind-close'     { Do-RemindClose }
    'team-plan-nudge'  { Do-TeamPlanNudge }
    'team-close-nudge' { Do-TeamCloseNudge }
  }
} catch {
  # never crash silently again: record the real error (incl. the server body) to the log
  Log ("ERROR [$Mode]: " + $_.Exception.Message)
  $b = ""; try { $r = $_.Exception.Response; if ($r) { $b = (New-Object IO.StreamReader($r.GetResponseStream())).ReadToEnd() } } catch {}
  if ($b) { Log ("  server: $b") }
  exit 1
}
