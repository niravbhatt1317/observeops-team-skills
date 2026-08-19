---
name: myday
description: Plan and close your day in Samanvaya through Claude — interactive daily planning, day-close with a suggested remark, quick task add, and status. Use when the user says "plan my day", "close my day", "samanvaya", "add a task to my day", "what's on my plate", or when a Samanvaya reminder notification fired. Earns the daily +5 (plan) and +8 (close) points.
---

# Samanvaya — daily planning through Claude

Samanvaya is Motadata's internal work portal (`http://172.16.15.82:5000`, private — needs office VPN).
This skill lets a team member run their day through Claude. All calls go through the `sam` wrapper,
which logs in with the user's OWN Keychain-stored credentials (never printed). The user only ever
sees/does what their Samanvaya account permits — this skill automates their existing access, nothing more.

**Prereq:** `~/bin/sam` + `~/bin/sam_daily.py` installed and the Keychain item created (see `setup`).
Always begin by confirming reachability: `sam check` (if it fails → tell them to connect the VPN, stop).

Resolve the user's own member id once per session: `sam get /api/admin/me` → `member_id` (call it MID).

## Commands / intents

### setup  ("set me up", "install myday", or whenever `sam check` / `sam.ps1 check` fails because nothing is configured yet)

**GUIDED onboarding — do it ONE STEP AT A TIME.** Present a step, have the user run it, confirm the
result, THEN go to the next. Never dump all steps at once. Number each step and say plainly whether
**you** run it or **they** run it, and in **which window** (Terminal on Mac, PowerShell on Windows).

**Two hard rules:**
- **Never ask the user to type or paste their password into chat.** The password only ever goes into
  the OS secret store (Keychain / DPAPI) via a hidden prompt THEY run in their terminal.
- Their **Samanvaya email is not secret** — ask for it up front, call it EMAIL, and use it below.

**Before the steps:** detect the OS (`uname` = `Darwin` → macOS; else Windows / `$env:OS`), ask for
EMAIL, and confirm they're on the **office VPN** (the portal is a private address). If reachability
fails, stop and tell them to connect the VPN. Then follow their branch. From the cloned repo, `cd`
into `myday/skills/myday` first so the relative paths below work.

#### macOS  (run in Terminal)
1. **Scripts →** `mkdir -p ~/bin && cp bin/sam bin/sam_daily.py bin/sam-open-claude ~/bin/ && chmod +x ~/bin/sam ~/bin/sam_daily.py ~/bin/sam-open-claude`
2. **Your email →** set it: edit the `IDENTIFIER=` line at the top of `~/bin/sam` to EMAIL, or `export SAM_ID="EMAIL"` in the shell profile.
3. **Password — THEY run this** (it prompts hidden; type it, Enter — never paste in chat):
   `security add-generic-password -U -a "EMAIL" -s "samanvaya" -w`
   (macOS 26 Passwords-app items are NOT CLI-readable — this generic item is required.)
4. **Verify →** `~/bin/sam check` (reachable) then `~/bin/sam login` (should say: logged in as EMAIL).
5. **Branded + click-to-open notifications →** first ASK which terminal the click should open —
   **Warp**, **Terminal**, or **iTerm** (their default/preference) — then run
   `bash mac/setup-notifications.sh <warp|terminal|iterm>`. It installs `terminal-notifier`, builds the
   branded **Samanvaya.app** (logo + name), stores the choice in `~/.samanvaya/opener`, writes Warp
   configs only if Warp, and pre-trusts `~/Claude-Projects` (no trust prompt). Change the terminal later
   with `echo <warp|terminal|iterm> > ~/.samanvaya/opener`.
6. **Routine →** `bash launchd/setup-morning-hybrid.sh` then `bash launchd/setup-close-hybrid.sh`; confirm with `launchctl list | grep samanvaya`.

#### Windows  (run in **Windows PowerShell**)
Tell them to open **PowerShell**. Note which steps need **them** (password) or a **UAC prompt** (tasks).
0. **Prereqs →** `claude --version` works, they're signed in, and on the VPN.
1. **Scripts →** `New-Item -ItemType Directory -Force "$env:USERPROFILE\bin" | Out-Null; Copy-Item .\bin\*.ps1 "$env:USERPROFILE\bin\" -Force`
2. **Toast module →** `Install-Module BurntToast -Scope CurrentUser`  (answer **Yes** to the prompts)
3. **Your email →** `setx SAM_ID "EMAIL"`  — then **reopen PowerShell** so it takes effect.
4. **Password — THEY run these two lines** (the prompt is hidden + DPAPI-encrypted to their account; never paste in chat):
   `New-Item -ItemType Directory -Force "$env:USERPROFILE\.samanvaya" | Out-Null`
   `Read-Host -AsSecureString "Samanvaya password" | ConvertFrom-SecureString | Out-File "$env:USERPROFILE\.samanvaya\pw.txt"`
5. **Install the skill for Claude →** `Copy-Item -Recurse -Force "." "$env:USERPROFILE\.claude\skills\myday"`  (skip if they used `/plugin install myday`)
6. **Branded toasts →** `curl.exe "http://172.16.15.82:5000/static/samanvaya-icon.png" -o "$env:USERPROFILE\.samanvaya\icon.png"` then `powershell -ExecutionPolicy Bypass -File .\windows\register-appid.ps1`
7. **Trusted folder (kills the trust prompt) →** `New-Item -ItemType Directory -Force "$env:USERPROFILE\Claude-Projects" | Out-Null`, then **close Claude/VS Code**, then `powershell -ExecutionPolicy Bypass -File .\bin\Trust-Folder.ps1 -Folder "$env:USERPROFILE\Claude-Projects"`
8. **Click-to-open protocol →** `powershell -ExecutionPolicy Bypass -File .\windows\register-protocol.ps1`
9. **Schedule the routine (accept the UAC prompt) →** `powershell -ExecutionPolicy Bypass -File .\windows\register-tasks.ps1`
10. **Verify →** `powershell -File "$env:USERPROFILE\bin\sam.ps1" check` and `... login`; then `Start-Process "myday://plan"` should open a terminal with Claude already planning.

**Finish (either OS):** confirm `sam login` / `sam.ps1 login` succeeds, then offer to run `/myday plan` right now so they see it work. Full written guides: `INSTALL-FOR-TEAMMATES.md` (Mac) · `windows/SETUP-WINDOWS.md` (Windows).

### plan  ("plan my day")  → earns +5
1. `sam check`; resolve MID; TODAY = local date.
2. `sam get "/api/day/plan?member_id=MID&date=TODAY"` — if `plan.status == "planned"`, tell them it's
   already planned, show the items, and stop (don't double-commit).
3. `sam get "/api/day/available?member_id=MID&date=TODAY"` → `assigned[]` (and `backlog`).
4. **Ask them conversationally:** show the available tasks (title, priority, due, flag overdue/due-today)
   and ask *"Which of these are you taking on today?"* Let them pick by number, or add new ones.
5. For each chosen existing task: `sam post /api/day/add-from-task '{"member_id":MID,"date":"TODAY","task_id":ID}'`.
   For a brand-new item they name: `sam post /api/tasks '{"title":"…","assignee_ids":[MID],"due_date":"TODAY","priority":"medium"}'`.
6. Commit the plan (earns +5, and must be BEFORE ~9:00 AM to count as "on time"):
   `sam post /api/portal/MID/day/plan '{"date":"TODAY"}'`  (portal self-plan is the one that awards).
7. Confirm: "Day planned · N items · +5." Show the final list.

### close  ("close my day")  → earns +8
1. `sam check`; MID; TODAY. `sam get "/api/day/plan?member_id=MID&date=TODAY"`.
   If `plan.status == "closed"` → tell them, stop. If not `planned` → offer to plan first.
2. For each item decide disposition: `done` if `completed_at` or `status=="done"`, else default `carried`
   (never `dropped` unless they say so). Show the list and let them adjust.
3. **CRITICAL — the +8 requires a NON-EMPTY `remark` on EVERY item** (not just the day `note`).
   Draft a short per-item remark (e.g. done→"Completed"; carried→"Carrying to tomorrow" or the real reason)
   and a day-level `note`. Show them, ask *"Close with these?"*, let them edit.
4. Use the PORTAL self-close (the endpoint that awards): `sam post /api/portal/MID/day/close
   '{"date":"TODAY","note":"<day reflection>","items":[{"id":ITEM_ID,"end_status":"done|carried|dropped","remark":"<non-empty>"}, …]}'`.
5. Confirm and show XP change: `sam get /api/portal/MID/gam/wallet` → total_xp (expect +8), streak.

### status  ("what's on my plate", "my status")
`sam get "/api/day/plan?member_id=MID&date=TODAY"`, `sam get /api/tasks`, `sam get /api/portal/MID/gam/wallet`.
Summarize: today's plan (done/open), overdue, due-today-not-in-plan, XP + distance to next level + streak.

### add  ("add a task …")
`sam post /api/tasks '{"title":"…","assignee_ids":[MID],"due_date":"TODAY","priority":"medium"}'`,
then offer to pull it into today's plan via add-from-task.

### team  (managers only — access_level "workspace")
`sam get /api/admin/member-analytics` (your reportees' live tasks/planned/overdue) and
`sam get "/api/day/team-summary?date=TODAY"` (who planned/closed). Summarize who's on track / needs a nudge.
If it 403s or returns just the user, they're not a manager — say so.

### reminders  (install / remove the daily nudges)
The nudges are OS notifications (not auto-actions) telling them to run `/myday plan` / `close`:
- `sam_daily.py remind-plan` and `remind-close` send the notifications (only if not already planned/closed).
- Install via the launchd templates in `skill/reminders/` → `bash skill/reminders/install.sh`
  (plan 09:00, close 17:45 daily). Remove: `bash skill/reminders/uninstall.sh`.
- The user installs these themselves (the harness blocks Claude from writing to ~/Library/LaunchAgents).

## Points (why the daily habit matters)
plan-my-day +5 · close-my-day-with-remark +8 · 7-day streak +30 · 30-day streak +150.
See `GAMIFICATION.md` for the full table. Reward the habit; play it straight (there are anti-farm caps).

## Guardrails
- If `sam check` fails: it's the VPN. Say so, don't retry endlessly.
- Never ask the user to type their password in chat — it goes into Keychain via `security … -w`.
- Writes act as the user; keep them scoped to the user's own day/tasks. Don't touch other members' data.
- Confirm the remark before closing; confirm the task list before committing the plan.
