# Samanvaya → Microsoft Teams setup

Two independent webhooks:
- **Channel** (manager, once): your Mac posts a daily team-of-6 roll-up to a shared channel.
- **DM** (each person, once): each Mac posts that person's plan/close reminders to their own Teams.

The scripts send an **Adaptive Card** payload, which is exactly what the Teams "Workflows"
webhook template expects — so there is **no flow editing**. Create → copy URL → paste into config.

---

## Part A — Shared roll-up (manager does once)  — channel OR group chat

Same Adaptive Card payload works for both; the `teams.json` key stays `"channel"` either way.

**Option 1 — Group chat (recommended: everyone gets pinged on each post):**
1. In Teams, create/open a **group chat** with your team (name it e.g. "Samanvaya Team").
2. Teams left rail → **Apps** → **Workflows** → **Create**.
3. Template: **"Post to a chat when a webhook request is received."**
4. Sign in, **select your group chat**. **Create.**
5. Copy the **HTTP POST URL** → config key `"channel"`.

**Option 2 — Team channel (tidier/threaded, only followers pinged):**
1. Pick/create a channel (e.g. **"Samanvaya"**).
2. Beside the channel name: **⋯ → Workflows** (or Apps → **Workflows** → Create).
3. Template: **"Post to a channel when a webhook request is received."**
4. Set **Team + Channel**. **Create.**
5. Copy the **HTTP POST URL** → config key `"channel"`.

(Find the URL later: Teams → Apps → Workflows → **My workflows** → open it → the trigger shows the URL.)

## Part B — Personal DM reminders (each teammate does once)

1. Teams left rail → **Apps** → search **Workflows** → **Create** (or **+ New flow**).
2. Choose the template **"Post to a chat when a webhook request is received"** if present.
   - If only the *channel* template exists: use **Power Automate** (make.powerautomate.com) →
     **Create → Instant cloud flow** → trigger **"When a Teams webhook request is received"** →
     add action **"Post message in a chat or channel"** → **Post as: Flow bot**,
     **Post in: Chat with Flow bot**, **Recipient: yourself**, **Message: the incoming text**.
3. Set the chat = a chat with **yourself** (or Flow bot). **Create**.
4. Copy the **HTTP POST URL**.
5. Put it in your config under `"dm"`.

---

## Wire it up (each machine)

Create `~/.samanvaya/teams.json` (either key is optional):

```json
{
  "channel": "https://prod-XX.westus.logic.azure.com:443/workflows/....",
  "dm":      "https://prod-YY.westus.logic.azure.com:443/workflows/...."
}
```

```bash
chmod 600 ~/.samanvaya/teams.json    # webhook URLs are capability URLs — keep them private
```

Test:
```bash
python3 ~/bin/sam_daily.py remind-close   # should DM you in Teams (if "dm" set)
python3 ~/bin/sam_daily.py morning        # manager: posts roll-up to channel (if "channel" set)
```

## What posts where
- **Channel** (managers only — needs workspace access): one card per morning, a line per reportee
  — planned? open / overdue / done-today. (`team_rollup()`)
- **DM**: 09:00 "plan your day", 17:45 "close your day", plus the morning brief summary.

## Notes
- Outbound only: your Mac → Teams. No inbound, no tunnel, no portal admin.
- A Teams message can't launch Claude on click (that stays the Mac notification's job). Teams =
  readable status anywhere (incl. phone); Mac notification = click-to-open-Claude action.
- Mac must be awake + on VPN when the scheduled jobs run.
- "One bot auto-DMs everyone with zero per-person setup" = the central-server model (needs Teams/IT admin).

---

## Manager: team plan/close nudges (@mention who hasn't done it)

At set times, post to the channel naming (and **@mentioning**) reportees who haven't planned / closed.

1. **Enable @mentions:** copy `team-mentions.example.json` → `~/.samanvaya/team-mentions.json` and map
   each reportee's **exact Samanvaya display name → their Teams email**. Names without an entry just
   appear as plain text (no ping). `chmod 600` it.
2. **Schedule the checks:** `bash launchd/setup-team-nudges.sh 11:15 18:30`
   (plan-check 11:15, close-check 18:30 — change by re-running; remove with `-remove`).
3. Each run checks live status (`member-analytics` for planned, per-member day-plan for closed) and posts
   e.g. *"Close check — not closed yet (2/6): @Nikhil (planned, not closed); @Pranjal (planned, not closed)"*,
   or a "✅ everyone's done 🎉" if none. Requires **workspace access** + a `channel` webhook.

### Weekends & leave
- **Weekends:** scheduled runs (nudges, auto-plan/close, team posts) skip Sat/Sun automatically.
  To work a weekend: `touch ~/.samanvaya/work-weekends` (Windows: `New-Item "$env:USERPROFILE\.samanvaya\work-weekends"`).
- **On leave:** copy `on-leave.example.json` -> `~/.samanvaya/on-leave.json` and list names + date ranges.
  People on leave today are **not @mentioned** in the plan/close team nudges. Names must match Samanvaya exactly.
- **Company holidays:** `holidays.json` (shipped; copied to `~/.samanvaya/` by setup) = `{"YYYY-MM-DD":"Name"}`.
  On a listed holiday the whole scheduled run skips (no nudges/posts). Floater/optional leaves are NOT
  listed here (they act as personal leave -> use `on-leave.json`). Edit the file to add future years.
