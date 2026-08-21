<#
  sam.ps1 - Samanvaya CLI for Windows (PowerShell port of the macOS `sam` wrapper).
  Login: admin JSON login, falling back to the team-member /portal/login form on 403.
  Password read from a DPAPI-encrypted file at runtime; never printed or on argv.

  USAGE: .\sam.ps1 check | login | get <path> | post <path> [json] | whoami
  ENV OVERRIDES: SAM_BASE, SAM_ID, SAM_STATE
#>
param(
  [Parameter(Position=0)][string]$Cmd = "usage",
  [Parameter(Position=1)][string]$Path,
  [Parameter(Position=2)][string]$Json
)
$ErrorActionPreference = "Stop"

# ---------- config ----------
$BASE = if ($env:SAM_BASE) { $env:SAM_BASE } else { "http://172.16.15.82:5000" }
$STATE= if ($env:SAM_STATE){ $env:SAM_STATE }else { "$env:USERPROFILE\.samanvaya" }
$PWFILE = Join-Path $STATE "pw.txt"
New-Item -ItemType Directory -Force $STATE | Out-Null
# Identity: env SAM_ID, else ~/.samanvaya/id (scheduled tasks don't inherit setx/shell env). Never guess.
$ID = if ($env:SAM_ID) { $env:SAM_ID }
      elseif (Test-Path "$STATE\id") { (Get-Content "$STATE\id" -Raw).Trim() }
      else { $null }
if (-not $ID) { Write-Error "sam: no identity set. Run: Set-Content `"$STATE\id`" 'you@motadata.com' (or set SAM_ID)"; exit 2 }

function Notify($title, $msg) {
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction Stop
      New-BurntToastNotification -Text $title, $msg | Out-Null
    } else { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($msg, $title) | Out-Null }
  } catch {}
}

function Reachable {
  try { Invoke-WebRequest -Uri "$BASE/login" -TimeoutSec 6 -UseBasicParsing | Out-Null; return $true } catch { return $false }
}
function Require-Reachable {
  if (-not (Reachable)) {
    Write-Error "sam: cannot reach $BASE - you are probably NOT connected to the VPN."
    if (-not $env:SAM_NO_NOTIFY) { Notify "Samanvaya" "Not reachable - connect the VPN, then retry." }
    exit 3
  }
}

function Get-PlainPassword {
  if (-not (Test-Path $PWFILE)) { Write-Error "sam: no stored password at $PWFILE. Create it: Read-Host -AsSecureString 'Samanvaya password' | ConvertFrom-SecureString | Out-File `"$PWFILE`""; exit 1 }
  $sec = Get-Content $PWFILE | ConvertTo-SecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try   { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ---------- API session (login-per-invocation; cookie kept in-process) ----------
$script:Session = $null
$script:Member  = $null
function Do-Login {
  Require-Reachable
  $pw = Get-PlainPassword
  # 1st door: admin JSON login (admin / workspace accounts)
  $body = @{ identifier = $ID; password = $pw } | ConvertTo-Json -Compress
  try {
    $r = Invoke-RestMethod -Uri "$BASE/api/admin/login" -Method Post -Body $body -ContentType 'application/json' -SessionVariable sess -TimeoutSec 20
    if ($r.ok) { $pw = $null; $script:Session = $sess; $script:Member = $r.member_id; return $r }
  } catch {
    $code = 0; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -ne 403) { $pw = $null; Write-Error "sam: login failed - $($_.Exception.Message)"; exit 1 }
    # 403 = valid creds, plain team member -> portal door
  }
  # 2nd door: team-member portal FORM login (follows the 302 to /portal/<id>)
  try {
    $pr = Invoke-WebRequest -Uri "$BASE/portal/login" -Method Post -Body @{ identifier = $ID; password = $pw } -SessionVariable psess -TimeoutSec 20 -UseBasicParsing
  } catch { $pw = $null; Write-Error "sam: portal login failed - $($_.Exception.Message)"; exit 1 }
  $pw = $null
  $landed = "$($pr.BaseResponse.ResponseUri)"
  if ($landed -match '/portal/(\d+)') {
    $script:Session = $psess; $script:Member = [int]$Matches[1]
    return [pscustomobject]@{ ok = $true; name = $ID; member_id = [int]$Matches[1]; via = 'portal' }
  }
  Write-Error "sam: portal login rejected - check the stored password (landed on $landed)"; exit 1
}
function Ensure-Session { if (-not $script:Session) { Do-Login | Out-Null } }

function Api($method, $path, $jsonBody) {
  Require-Reachable
  Ensure-Session
  $a = @{ Uri = "$BASE$path"; Method = $method; WebSession = $script:Session; TimeoutSec = 25 }
  if ($jsonBody) { $a.Body = $jsonBody; $a.ContentType = 'application/json' }
  try { return Invoke-RestMethod @a }
  catch {
    $code = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($code -eq 401 -or $code -eq 302) { Do-Login | Out-Null; $a.WebSession = $script:Session; return Invoke-RestMethod @a }
    throw
  }
}

function Usage {
@"
sam.ps1 - Samanvaya CLI (Windows)
  .\sam.ps1 check | login | get <path> | post <path> [json] | whoami
Env overrides: SAM_BASE, SAM_ID, SAM_STATE
"@ | Write-Host
}

switch ($Cmd) {
  "check"  { if (Reachable) { Write-Host "sam: $BASE reachable" } else { Write-Host "sam: $BASE UNREACHABLE (VPN off?)"; exit 3 } }
  "login"  { $r = Do-Login; Write-Host "sam: logged in as $($r.name) (member $($r.member_id), $(if($r.via){$r.via}else{'admin'}))" }
  "docs"   { Api GET "/api/docs" | ConvertTo-Json -Depth 8 }
  "get"    { if (-not $Path) { Write-Error "usage: sam.ps1 get <path>"; exit 2 }; Api GET  $Path | ConvertTo-Json -Depth 8 }
  "post"   { if (-not $Path) { Write-Error "usage: sam.ps1 post <path> [json]"; exit 2 }; Api POST $Path $Json | ConvertTo-Json -Depth 8 }
  "whoami" { $r = Do-Login; $r | ConvertTo-Json -Depth 8 }   # member id from login, NOT /api/admin/me (admin-only)
  default  { Usage }
}
