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

### setup  (one-time onboarding)
If `sam check` errors with "no stored password" or `~/bin/sam` is missing, walk them through install:
1. Confirm `~/bin/sam` and `~/bin/sam_daily.py` exist (the skill ships them in `bin/`; copy to `~/bin`, `chmod +x`).
2. Have THEM store their password (typed hidden — never ask them to paste it in chat):
   `security add-generic-password -U -a "<their-email>" -s "samanvaya" -w`
   (macOS 26 Passwords-app items are NOT CLI-readable — a generic item is required.)
   Set `SAM_ID` in `~/bin/sam` to their email, or export `SAM_ID`.
3. `sam login` to verify. Then offer to install reminders (see `reminders`).

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
