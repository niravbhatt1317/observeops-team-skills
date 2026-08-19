<#
  sam.ps1 — Samanvaya CLI for Windows (PowerShell port of the macOS `sam` bash wrapper)

  The password is read from a DPAPI-encrypted file AT RUNTIME, inside this script.
  DPAPI ties the ciphertext to THIS Windows user on THIS machine — nobody else can
  decrypt it, and the plaintext never touches the transcript, argv, or disk.

  ONE-TIME SETUP (each user runs this once; password typed hidden):
     New-Item -ItemType Directory -Force "$env:USERPROFILE\.samanvaya" | Out-Null
     Read-Host -AsSecureString "Samanvaya password" |
        ConvertFrom-SecureString | Out-File "$env:USERPROFILE\.samanvaya\pw.txt"

  USAGE:
     .\sam.ps1 check
     .\sam.ps1 login
     .\sam.ps1 get  /api/tasks
     .\sam.ps1 post /api/day/add-from-task '{"member_id":22,"task_id":610,"date":"2026-08-18"}'
     .\sam.ps1 whoami

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
$ID   = if ($env:SAM_ID)   { $env:SAM_ID }   else { "nirav.bhatt@motadata.com" }   # not secret
$STATE= if ($env:SAM_STATE){ $env:SAM_STATE }else { "$env:USERPROFILE\.samanvaya" }
$PWFILE = Join-Path $STATE "pw.txt"
New-Item -ItemType Directory -Force $STATE | Out-Null

# ---------- desktop notification (best-effort) ----------
function Notify($title, $msg) {
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction Stop
      New-BurntToastNotification -Text $title, $msg | Out-Null
    } else {
      # fallback: MessageBox (non-blocking-ish); works on all editions
      Add-Type -AssemblyName System.Windows.Forms
      [System.Windows.Forms.MessageBox]::Show($msg, $title) | Out-Null
    }
  } catch {}
}

# ---------- reachability (VPN) preflight ----------
function Reachable {
  try {
    Invoke-WebRequest -Uri "$BASE/login" -TimeoutSec 6 -UseBasicParsing | Out-Null
    return $true
  } catch { return $false }
}
function Require-Reachable {
  if (-not (Reachable)) {
    Write-Error "sam: cannot reach $BASE — you are probably NOT connected to the VPN (or off the office network)."
    Notify "Samanvaya" "Not reachable — connect the VPN, then retry."
    exit 3
  }
}

# ---------- secret retrieval (plaintext lives only in this function's scope) ----------
function Get-PlainPassword {
  if (-not (Test-Path $PWFILE)) {
    Write-Error @"
sam: no stored password at $PWFILE. Create it once (typed hidden):
  Read-Host -AsSecureString "Samanvaya password" | ConvertFrom-SecureString | Out-File "$PWFILE"
"@
    exit 1
  }
  $sec = Get-Content $PWFILE | ConvertTo-SecureString    # DPAPI-decrypts to this user only
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try   { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ---------- API session (login-per-invocation; cookie kept in-process) ----------
$script:Session = $null
function Do-Login {
  Require-Reachable
  $pw = Get-PlainPassword
  $body = @{ identifier = $ID; password = $pw } | ConvertTo-Json -Compress
  $pw = $null   # drop plaintext ASAP
  try {
    $r = Invoke-RestMethod -Uri "$BASE/api/admin/login" -Method Post -Body $body `
           -ContentType 'application/json' -SessionVariable sess -TimeoutSec 20
  } catch {
    Write-Error "sam: login failed — $($_.Exception.Message)"; exit 1
  }
  if (-not $r.ok) { Write-Error "sam: login rejected — $($r | ConvertTo-Json -Compress)"; exit 1 }
  $script:Session = $sess
  return $r
}
function Ensure-Session { if (-not $script:Session) { Do-Login | Out-Null } }

function Api($method, $path, $jsonBody) {
  Require-Reachable
  Ensure-Session
  $args = @{ Uri = "$BASE$path"; Method = $method; WebSession = $script:Session; TimeoutSec = 25 }
  if ($jsonBody) { $args.Body = $jsonBody; $args.ContentType = 'application/json' }
  try {
    return Invoke-RestMethod @args
  } catch {
    $code = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($code -eq 401 -or $code -eq 302) {          # session expired → re-login once
      Do-Login | Out-Null
      $args.WebSession = $script:Session
      return Invoke-RestMethod @args
    }
    throw
  }
}

function Usage {
@"
sam.ps1 — Samanvaya CLI (Windows)
  .\sam.ps1 check            Is the portal reachable? (VPN check)
  .\sam.ps1 login            Authenticate
  .\sam.ps1 get  <path>      Authenticated GET, e.g. .\sam.ps1 get /api/tasks
  .\sam.ps1 post <path> [json]   Authenticated POST with optional JSON body
  .\sam.ps1 whoami           Show your identity (/api/admin/me)
Env overrides: SAM_BASE, SAM_ID, SAM_STATE
"@ | Write-Host
}

switch ($Cmd) {
  "check"  { if (Reachable) { Write-Host "sam: $BASE reachable" } else { Write-Host "sam: $BASE UNREACHABLE (VPN off?)"; exit 3 } }
  "login"  { $r = Do-Login; Write-Host "sam: logged in as $($r.name) (member $($r.member_id))" }
  "docs"   { Api GET "/api/docs"        | ConvertTo-Json -Depth 8 }
  "get"    { if (-not $Path) { Write-Error "usage: sam.ps1 get <path>"; exit 2 }; Api GET  $Path        | ConvertTo-Json -Depth 8 }
  "post"   { if (-not $Path) { Write-Error "usage: sam.ps1 post <path> [json]"; exit 2 }; Api POST $Path $Json | ConvertTo-Json -Depth 8 }
  "whoami" { Api GET "/api/admin/me"    | ConvertTo-Json -Depth 8 }
  default  { Usage }
}
