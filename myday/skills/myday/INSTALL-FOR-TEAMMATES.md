# Samanvaya skill — teammate setup (≈5 min, Mac)

Plan and close your Samanvaya day through Claude, and get a daily nudge to do it.
Everything runs on YOUR machine with YOUR login — your password lives only in your Keychain.

## Prerequisites
- macOS, on the office **VPN** (Samanvaya is a private address).
- Claude Code installed.
- Your Samanvaya email + password.

## 1. Get the skill
Install it from the team marketplace in Claude Code (this makes `/myday` work):
```
/plugin marketplace add niravbhatt1317/observeops-team-skills
/plugin install myday@observeops-team-skills
```
Then clone the repo for the scripts below and `cd` into the skill folder — **all commands below run from here**:
```bash
git clone https://github.com/niravbhatt1317/observeops-team-skills
cd observeops-team-skills/myday/skills/myday
```

## 2. Install the scripts
```bash
mkdir -p ~/bin
cp bin/sam ~/bin/ && chmod +x ~/bin/sam
cp bin/sam_daily.py ~/bin/ && chmod +x ~/bin/sam_daily.py
cp bin/sam-open-claude ~/bin/ && chmod +x ~/bin/sam-open-claude
```
Set your identity — edit the `IDENTIFIER=` line near the top of `~/bin/sam` to your email
(or `export SAM_ID="you@motadata.com"` in your shell profile).

## 3. Store your password (typed hidden — not echoed, not in history)
```bash
security add-generic-password -U -a "you@motadata.com" -s "samanvaya" -w
```
Paste your Samanvaya password when prompted. (macOS 26's Passwords app isn't readable by the CLI,
so this classic Keychain item is required.)

## 4. Verify
```bash
~/bin/sam check      # portal reachable? (VPN)
~/bin/sam login      # should say: logged in as you@motadata.com
```

## 5. Turn on daily reminders (optional but recommended)
```bash
bash reminders/install.sh
```
You'll get a 09:00 "plan your day" notification and a 17:45 "close your day" notification.
Remove anytime: `bash reminders/uninstall.sh`.

## Use it
In Claude:
- `/myday plan` — Claude asks what you're working on, builds your day (**+5**)
- `/myday close` — Claude drafts a remark, you confirm, closes your day (**+8**)
- `/myday status` — today's plan, overdue, your XP/level/streak
- `/myday add "review the BOM doc"` — quick task

## Notes
- Points: plan +5/day, close-with-remark +8/day, 7-day streak +30, 30-day +150. Consistency wins.
- Reminders/actions only work when your Mac is awake and on the VPN.
- Managers (workspace access) also get `/myday team` — your reportees' status.
- Your password never enters Claude's chat; the scripts read it from Keychain at runtime.
