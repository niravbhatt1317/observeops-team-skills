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

Resolve the user's own member id: after `sam login`, read it from `sam whoami` (the wrapper resolves it
from the admin login OR, for a regular member, the `/portal/login` redirect). Call it MID. Do NOT call
`/api/admin/me` — it is admin-only and 401s for regular members. Everything personal uses `/api/portal/MID/...`
(works for members AND admins); only the `team` recipe needs admin endpoints.

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
The plugin cache already has the scripts — no clone needed. Have them open **PowerShell** and `cd` to the
skill folder (the `/plugin` path, e.g. `...\.claude\plugins\cache\observeops-team-skills\myday\<ver>\skills\myday`).
Then run the **one-shot installer** — it prompts for their **email** and **password** (hidden) inline, then
does everything else Claude is blocked from (secret entry, registry, scheduled tasks are user-only by design):

`powershell -ExecutionPolicy Bypass -File .\windows\install.ps1`   (add `-NoProtocol` to skip click-to-open)

It sets up: password (DPAPI), scripts→`~\bin`, BurntToast, `SAM_ID`, branded toast, trusted folder, the
`myday://` protocol, and the 5 scheduled tasks. Accept any Windows prompts. **Close Claude/VS Code first**
so the trusted-folder step sticks.
Prereqs: on the VPN; for click-to-open the `claude` CLI must be on PATH (`claude --version`) — VS Code-only
users can skip it (`-NoProtocol`) and just run `/myday plan` in the panel when the toast nudges them.
Verify: `powershell -File "$env:USERPROFILE\bin\sam.ps1" login`, then `Start-Process "myday://plan"`.

**Finish (either OS):** confirm `sam login` / `sam.ps1 login` succeeds, then offer to run `/myday plan` right now so they see it work. Full written guides: `INSTALL-FOR-TEAMMATES.md` (Mac) · `windows/SETUP-WINDOWS.md` (Windows).

### plan  ("plan my day")  → earns +5
1. `sam check`; resolve MID; TODAY = local date.
2. `sam get "/api/portal/MID/day?date=TODAY"` — same `.plan`/`.items` shape; if `plan.status == "planned"`,
   tell them it's already planned, show the items, and stop (don't double-commit).
3. `sam get "/api/portal/MID/tasks"` → a **flat array** of the member's tasks (NOT `{assigned:[…]}`).
   Candidates to add = tasks not completed and not already in today's `items` (match on task id).
4. **Ask them conversationally:** show the candidates (title, priority, due, flag overdue/due-today)
   and ask *"Which of these are you taking on today?"* Let them pick by number, or add new ones.
5. For each chosen existing task: `sam post /api/portal/MID/day/add-from-task '{"date":"TODAY","task_id":ID}'` (no member_id).
   For a brand-new item they name: `sam post /api/portal/MID/tasks '{"title":"…","due_date":"TODAY","priority":"medium"}'`.
6. Commit the plan (earns +5, and must be BEFORE ~9:00 AM to count as "on time"):
   `sam post /api/portal/MID/day/plan '{"date":"TODAY"}'`  (portal self-plan is the one that awards).
7. Confirm: "Day planned · N items · +5." Show the final list.

### close  ("close my day")  → earns +8
1. `sam check`; MID; TODAY. `sam get "/api/portal/MID/day?date=TODAY"`.
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
`sam get "/api/portal/MID/day?date=TODAY"`, `sam get /api/portal/MID/tasks`, `sam get /api/portal/MID/gam/wallet`.
Summarize: today's plan (done/open), overdue, due-today-not-in-plan, XP + distance to next level + streak.

### add  ("add a task …")
`sam post /api/portal/MID/tasks '{"title":"…","due_date":"TODAY","priority":"medium"}'`,
then offer to pull it into today's plan via `add-from-task`.

### team  (managers only — needs an ADMIN/workspace login, not a portal member session)
`sam get /api/admin/member-analytics` (reportees' live tasks/planned/overdue) and
`sam get "/api/day/team-summary?date=TODAY"`. Summarize who's on track / needs a nudge.
If `sam login` fell back to `/portal/login` (regular member) or these 401/403, they're not a manager —
say so and skip; don't let a failed admin call abort the rest.

### reminders / routine  (install / remove — the user runs these; Claude can't install scheduled jobs)
Clickable nudges + auto-plan/close, scheduled locally:
- **Mac:** `bash launchd/setup-morning-hybrid.sh` (09:00 nudge · 11:00 nudge · 11:30 auto-plan) and
  `bash launchd/setup-close-hybrid.sh` (17:35 nudge · 18:00 auto-close). Managers add `bash launchd/setup-team-nudges.sh`.
- **Windows:** `install.ps1` already schedules them (09:00, 11:00, 11:30, 17:35, 18:00).
- ⚠️ Say plainly at install time: the **11:30 auto-plan** and **18:00 auto-close WRITE to the record
  unattended** (+5/+8) — it's an informed opt-in, not a silent default.

## Points (why the daily habit matters)
plan-my-day +5 · close-my-day-with-remark +8 · 7-day streak +30 · 30-day streak +150.
See `GAMIFICATION.md` for the full table. Reward the habit; play it straight (there are anti-farm caps).

## Guardrails
- If `sam check` fails: it's the VPN. Say so, don't retry endlessly.
- Never ask the user to type their password in chat — it goes into Keychain via `security … -w`.
- Writes act as the user; keep them scoped to the user's own day/tasks. Don't touch other members' data.
- Confirm the remark before closing; confirm the task list before committing the plan.
