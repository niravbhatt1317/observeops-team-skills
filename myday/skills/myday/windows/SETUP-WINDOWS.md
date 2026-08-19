# myday on Windows — setup (click-to-plan, no typing)

Same experience as the Mac routine: a toast reminder fires, you **click it**, and Claude opens
already asking what you're planning — you never type a command. Everything runs on **your** PC
with **your** Samanvaya login (password stays in Windows' DPAPI store).

> ⚠️ **First-run status:** this Windows port mirrors the working macOS setup but has **not yet been
> tested on a real Windows machine**. If you're the first to try it, follow the steps, run the tests
> at the bottom, and report anything that breaks so we can fix it.

---

## What you'll end up with
| Time | What happens |
|---|---|
| 09:00 | 🔔 toast **"Plan your day"** → click **Plan now** → Windows Terminal opens Claude planning your day (+5) |
| 11:00 | 🔔 second nudge (only if still unplanned) |
| 11:30 | 🤖 silent auto-plan fallback (so you never lose the +5) |
| 17:35 | 🔔 toast **"Close your day"** → click **Close now** → Claude drafts remarks & closes (+8) |
| 18:00 | 🤖 silent auto-close fallback (with per-item remarks, +8) |

---

## Prerequisites
- **Windows 10 or 11**, on the office **VPN** (Samanvaya is a private address, `172.16.15.82`).
- **Claude Code CLI** installed and on your PATH — test with `claude --version`.
  (The VS Code extension alone is not enough; the click-to-open runs the `claude` CLI in a terminal.)
  You must be **logged in** to Claude Code at least once.
- **PowerShell 5.1+** (built in). **Windows Terminal** (`wt.exe`) recommended; PowerShell console works as fallback.
- Your Samanvaya **email + password**.

Open **PowerShell** (normal, not admin unless noted) in the repo folder, then:

## 1. Get the files onto PATH
```powershell
# from the repo root
Copy-Item .\bin\*.ps1  "$env:USERPROFILE\bin\" -Force  # create ~\bin if needed
# (or just run scripts by full path — up to you)
```
Create `%USERPROFILE%\bin` first if it doesn't exist: `New-Item -ItemType Directory -Force "$env:USERPROFILE\bin"`.

## 2. Install the toast module
```powershell
Install-Module BurntToast -Scope CurrentUser        # answer Yes to prompts
```

## 3. Store your password (typed hidden, DPAPI-encrypted to just you)
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.samanvaya" | Out-Null
Read-Host -AsSecureString "Samanvaya password" |
    ConvertFrom-SecureString | Out-File "$env:USERPROFILE\.samanvaya\pw.txt"
```

## 4. Set your identity
```powershell
setx SAM_ID "you@motadata.com"      # then reopen PowerShell so it takes effect
```
(Or edit the `$ID` default at the top of `sam_daily.ps1` / `sam.ps1`.)

## 5. Install the `myday` skill for Claude
```powershell
$dest = "$env:USERPROFILE\.claude\skills\myday"
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
Copy-Item -Recurse -Force "." $dest
```
(If you run Claude with a custom config dir, copy into `<that dir>\skills\myday` instead, and set
`setx MYDAY_CLAUDE_CONFIG_DIR "<that dir>"` so the launcher uses it.)

## 6. Brand the notifications as "Samanvaya" (logo + name)
Grab the Samanvaya icon (while on VPN), then register the branded toast identity so toasts show
**Samanvaya** + the logo instead of "Windows PowerShell":
```powershell
curl.exe "http://172.16.15.82:5000/static/samanvaya-icon.png" -o "$env:USERPROFILE\.samanvaya\icon.png"
powershell -ExecutionPolicy Bypass -File .\windows\register-appid.ps1
```

## 7. Make a trusted folder (so Claude never asks "trust this folder?")
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Claude-Projects" | Out-Null
# CLOSE Claude / VS Code first, then:
powershell -ExecutionPolicy Bypass -File .\bin\Trust-Folder.ps1 `
  -Folder "$env:USERPROFILE\Claude-Projects"
```
The launcher opens Claude in `%USERPROFILE%\Claude-Projects`, which this pre-trusts.

## 8. Register the click-to-open protocol
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\register-protocol.ps1
```
This wires `myday://plan` / `myday://close` → `open-claude.ps1`.

## 9. Schedule the daily routine
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\register-tasks.ps1
```
Creates 5 tasks (`MyDay-*`) at 9:00 / 11:00 / 11:30 / 17:35 / 18:00. Remove later with `-Remove`.

---

## Test it (do these in order)
```powershell
# a) login + reachability
powershell -File "$env:USERPROFILE\bin\sam.ps1" check        # -> reachable (need VPN)
powershell -File "$env:USERPROFILE\bin\sam.ps1" login        # -> logged in as you

# b) the launcher directly — should open a terminal running: claude "plan my day"
Start-Process "myday://plan"

# c) a real clickable reminder toast (only nudges if today isn't planned yet)
powershell -File "$env:USERPROFILE\bin\sam_daily.ps1" remind-plan

# d) dry-run the auto modes (no writes)
powershell -File "$env:USERPROFILE\bin\sam_daily.ps1" morning -DryRun
powershell -File "$env:USERPROFILE\bin\sam_daily.ps1" close   -DryRun
```
Expected: (b) opens Windows Terminal and Claude starts the plan flow (asks what you're working on);
(c) shows a toast with a **Plan now** button that does the same when clicked.

## Troubleshooting
- **Toast shows no button / nothing happens on click** → BurntToast missing (step 2) or protocol not
  registered (step 8). Re-run and test `Start-Process "myday://plan"`.
- **"Unknown command / skill not found"** in Claude → skill not in the right config dir (step 5), or
  wrong config dir (set `MYDAY_CLAUDE_CONFIG_DIR`).
- **Trust prompt still appears** → the launcher folder ≠ the pre-trusted folder, or Claude was open
  when you ran step 7. Close Claude, re-run `Trust-Folder.ps1` for `%USERPROFILE%\Claude-Projects`.
- **`claude` not found** → install the Claude Code CLI and ensure it's on PATH (`claude --version`).
- **Nothing fires at 9:00** → PC asleep or off-VPN at run time (same constraint as Mac). Tasks have
  *StartWhenAvailable*, so they run at next wake — but still need the VPN.
- **Toast says "Windows PowerShell" at the top** → step 6 (`register-appid.ps1`) didn't run, or the
  AUMID isn't registered. Re-run it, then send a fresh toast. Windows caches toast identity — if it
  won't update, sign out/in or run `Get-Process explorer | Stop-Process` to refresh the shell.

## Notes / limits
- Outbound Teams messages (personal DM / team roll-up) work the same — put your webhook(s) in
  `%USERPROFILE%\.samanvaya\teams.json` as `{ "channel": "...", "dm": "..." }`.
- Everything is per-user and self-serve; no admin needed except accepting UAC when scheduling tasks.
- The click-to-open runs the `claude` CLI in a terminal (like the Mac click opens Warp) — it is *not*
  inside the VS Code panel; that's the same trade-off as the Mac version.
