#!/usr/bin/env python3
"""
sam_daily.py — Samanvaya daily automation engine.

  morning : ensure today's day is planned (earns +5 plan-my-day) and write a morning brief.
  close   : close today's day with an auto-generated remark (earns +8 close-my-day).

HTTP is done via curl + the cookie jar that ~/bin/sam maintains (curl handles the
HttpOnly session cookie cleanly). Login/keychain/VPN-preflight are delegated to `sam`.

Env:
  SAM_DRY=1   -> compute + log intended actions, but send NO writes.
"""
import os, sys, json, subprocess, datetime, shutil

HOME   = os.path.expanduser("~")
SAM    = os.path.join(HOME, "bin", "sam")
JAR    = os.path.join(HOME, ".samanvaya", "cookies.txt")
BASE   = os.environ.get("SAM_BASE", "http://172.16.15.82:5000")
MEMBER = int(os.environ.get("SAM_ID_NUM", "22"))   # overwritten from login.json after login
IS_ADMIN = True                                     # set False on a portal (member) session
DRY    = os.environ.get("SAM_DRY", "0") == "1"
BRIEF  = os.path.join(HOME, "Desktop", "Samanvaya-Today.md")
TODAY  = datetime.date.today().isoformat()

def log(m): print(f"[{datetime.datetime.now():%H:%M:%S}] {m}", flush=True)

_BRANDED = os.path.join(HOME, "Applications", "Samanvaya.app", "Contents", "MacOS", "terminal-notifier")
TN = _BRANDED if os.path.exists(_BRANDED) else (shutil.which("terminal-notifier") or "/opt/homebrew/bin/terminal-notifier")
OPENER = os.path.join(HOME, "bin", "sam-open-claude")
_MODE  = "morning"   # set from argv in __main__; used by the VPN-off retry notification

def notify(title, msg, action=None):
    """action='plan'|'close' -> clickable notification that opens Claude with that command."""
    if os.path.exists(TN):
        args = [TN, "-title", title, "-message", msg, "-sound", "Glass"]
        icon = os.path.join(HOME, ".samanvaya", "icon.png")
        if os.path.exists(icon):
            args += ["-appIcon", icon, "-contentImage", icon]
        if action:
            args += ["-subtitle", "Click to open Claude →", "-execute", f"{OPENER} {action}"]
        subprocess.run(args, check=False, capture_output=True)
        return
    try:
        subprocess.run(["osascript", "-e",
            f'display notification {json.dumps(msg)} with title {json.dumps(title)}'],
            check=False, capture_output=True)
    except Exception:
        pass

# ---------------------------------------------------------------- TEAMS
# Config file ~/.samanvaya/teams.json  ->  {"channel": "<url>", "dm": "<url>"}
# Both optional. Webhook URLs are capability URLs (semi-secret); file is chmod 600.
TEAMS_CFG = os.path.join(HOME, ".samanvaya", "teams.json")
def teams_urls():
    try:
        with open(TEAMS_CFG) as f: c = json.load(f)
        return c.get("channel"), c.get("dm")
    except Exception:
        return None, None

def teams_post(url, text, entities=None):
    """POST an Adaptive Card (Teams 'Workflows' webhook shape). `entities` = @mention list."""
    if not url: return
    if DRY: log("(DRY) would post to Teams - skipped"); return
    content = {"$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
               "type": "AdaptiveCard", "version": "1.4",
               "body": [{"type": "TextBlock", "text": text, "wrap": True}]}
    if entities:
        content["msteams"] = {"entities": entities}
    card = {"type": "message", "attachments": [{
        "contentType": "application/vnd.microsoft.card.adaptive", "content": content}]}
    subprocess.run(["/usr/bin/curl", "-sS", "-m", "15", "-X", "POST",
                    "-H", "Content-Type: application/json",
                    "--data-binary", json.dumps(card), url],
                   check=False, capture_output=True)
    log("posted to Teams")

# name -> Teams email (UPN) for @mentions. ~/.samanvaya/team-mentions.json = {"Full Name":"email"}
def _mentions_map():
    try:
        with open(os.path.join(HOME, ".samanvaya", "team-mentions.json")) as f: return json.load(f)
    except Exception: return {}

def _mention(name, mapp):
    """Return (token, entity) — a Teams <at> mention if we have the email, else plain name."""
    email = mapp.get(name)
    if not email: return name, None
    tok = f"<at>{name}</at>"
    return tok, {"type": "mention", "text": tok, "mentioned": {"id": email, "name": name}}

def _on_leave_today():
    """Names on leave today. ~/.samanvaya/on-leave.json = {"Full Name":[{"from":"YYYY-MM-DD","to":"YYYY-MM-DD"}]}."""
    try:
        cfg = json.load(open(os.path.join(HOME, ".samanvaya", "on-leave.json")))
    except Exception:
        return set()
    out = set()
    for name, ranges in (cfg or {}).items():
        for r in (ranges if isinstance(ranges, list) else []):
            frm = r.get("from", ""); to = r.get("to", frm)
            if frm and frm <= TODAY <= to: out.add(name); break
    return out

def team_rollup():
    """Manager-only: one-line status per reportee for the shared channel."""
    if not IS_ADMIN: return None
    _, ma, _ = get("/api/admin/member-analytics")
    if not isinstance(ma, list) or len(ma) <= 1: return None
    lines = [f"**Samanvaya team status — {TODAY}**"]
    for m in sorted(ma, key=lambda x: x.get("name","")):
        planned = "🟢" if m.get("planned_today") else "⚪️"
        lines.append(f"{planned} {m.get('name')} — {m.get('tasks_open',0)} open, "
                     f"{m.get('tasks_overdue',0)} overdue, {m.get('tasks_done_today',0)} done today")
    return "\n\n".join(lines)

def notify_retry(title, msg):
    """VPN-off notification that is CLICKABLE — clicking re-runs THIS same job (after you connect)."""
    retry = f"/usr/bin/python3 {os.path.join(HOME, 'bin', 'sam_daily.py')} {_MODE}"
    if os.path.exists(TN):
        args = [TN, "-title", title, "-message", msg, "-sound", "Basso",
                "-subtitle", "Connect the VPN, then click to retry →", "-execute", retry]
        icon = os.path.join(HOME, ".samanvaya", "icon.png")
        if os.path.exists(icon): args += ["-appIcon", icon, "-contentImage", icon]
        subprocess.run(args, check=False, capture_output=True); return
    try:
        subprocess.run(["osascript", "-e",
            f'display notification {json.dumps(msg)} with title {json.dumps(title)}'],
            check=False, capture_output=True)
    except Exception:
        pass

def ensure_login():
    # suppress the wrapper's own VPN notification — we show the clickable one below
    r = subprocess.run([SAM, "login"], capture_output=True, text=True,
                       env={**os.environ, "SAM_NO_NOTIFY": "1"})
    if r.returncode == 3:
        notify_retry("Samanvaya", "Not reachable — connect the VPN, then click to retry.")
        log("VPN off / unreachable — aborting.")
        sys.exit(3)
    if r.returncode != 0:
        log(f"login failed: {r.stderr.strip()}")
        sys.exit(1)
    # resolve our member id + whether this is an admin (workspace) or portal (member) session
    global MEMBER, IS_ADMIN
    try:
        lj = json.load(open(os.path.join(HOME, ".samanvaya", "login.json")))
        if lj.get("member_id"): MEMBER = int(lj["member_id"])
        IS_ADMIN = not lj.get("portal")   # the portal fallback sets portal:true
    except Exception:
        pass
    log(f"logged in (member {MEMBER}, admin={IS_ADMIN})")

def _curl(args):
    p = subprocess.run(["/usr/bin/curl", "-sS", "-m", "25", "-b", JAR,
                        "-w", "\n%{http_code}"] + args, capture_output=True, text=True)
    out = p.stdout
    nl = out.rfind("\n")
    body, code = out[:nl], out[nl+1:].strip()
    try: data = json.loads(body) if body.strip() else None
    except Exception: data = None
    return int(code or 0), data, body

def get(path): return _curl([f"{BASE}{path}"])
def post(path, obj):
    return _curl(["-X", "POST", "-H", "Content-Type: application/json",
                  "--data-binary", json.dumps(obj), f"{BASE}{path}"])

def wallet():
    c, d, _ = get(f"/api/portal/{MEMBER}/gam/wallet")
    return d or {}

# ---------------------------------------------------------------- MORNING
def morning():
    ensure_login()
    _, plan, _ = get(f"/api/portal/{MEMBER}/day?date={TODAY}")
    plan = plan or {}
    pmeta = plan.get("plan") or {}
    status = pmeta.get("status")
    items  = plan.get("items", [])
    log(f"plan status={status} items={len(items)}")

    added = []
    if len(items) == 0:
        # portal/tasks is a FLAT array; candidates = not-completed tasks not already in the plan
        _, tasks, _ = get(f"/api/portal/{MEMBER}/tasks")
        tasks = tasks if isinstance(tasks, list) else []
        in_plan = {i.get("source_task_id") for i in items}
        cands = [t for t in tasks if not t.get("completed_at") and t.get("id") not in in_plan]
        def rank(t):
            pr = {"critical":0,"high":1,"medium":2,"low":3}.get(t.get("priority"),4)
            overdue = 0 if (t.get("due_date") and t["due_date"] < TODAY) else 1
            duetoday = 0 if t.get("due_date") == TODAY else 1
            return (overdue, duetoday, pr)
        pick = sorted(cands, key=rank)[:6]
        for t in pick:
            if DRY:
                added.append(t); log(f"DRY would add task {t['id']} {t.get('title')}")
            else:
                c, r, _ = post(f"/api/portal/{MEMBER}/day/add-from-task",
                               {"date": TODAY, "task_id": t["id"]})
                if c == 200 and (r or {}).get("ok"):
                    added.append(t); log(f"added task {t['id']} {t.get('title')}")
        # refresh
        _, plan, _ = get(f"/api/portal/{MEMBER}/day?date={TODAY}")
        plan = plan or {}; pmeta = plan.get("plan") or {}; status = pmeta.get("status")
        items = plan.get("items", [])

    committed = False
    if status != "planned" and len(items) > 0:
        if DRY:
            log("DRY would POST /api/day/plan (commit -> +5)")
        else:
            c, r, _ = post(f"/api/portal/{MEMBER}/day/plan", {"date": TODAY})
            committed = c == 200 and (r or {}).get("ok")
            log(f"plan commit -> {c} ok={committed} (+5 if newly planned)")
    else:
        log("already planned; not re-committing")

    write_brief(plan, added, committed)
    open_n = sum(1 for i in items if not i.get("completed_at") and i.get("status")!="done")
    notify("Morning brief",
           f"{len(items)} planned · {open_n} open. Brief on your Desktop.")
    # Teams: manager roll-up -> shared channel; personal summary -> your DM
    chan, dm = teams_urls()
    if chan:
        rollup = team_rollup()
        if rollup: teams_post(chan, rollup)
    if dm:
        teams_post(dm, f"🌅 **Plan your day** — {len(items)} items, {open_n} open. (+5 when you plan)")

def write_brief(plan, added, committed):
    _, tasks, _ = get(f"/api/portal/{MEMBER}/tasks")
    tasks = tasks or []
    _, disc, _ = get("/api/discussions"); disc = disc or []
    w = wallet()
    items = plan.get("items", [])
    op = [t for t in tasks if not t.get("completed_at")]
    overdue = sorted([t for t in op if t.get("is_overdue")], key=lambda x: x.get("due_date") or "")
    due_today = [t for t in op if t.get("due_date") == TODAY]
    inplan = {i.get("source_task_id") for i in items}
    disc_today = [d for d in disc if d.get("planned_date") == TODAY]

    L = []
    L.append(f"# Samanvaya — {TODAY}\n")
    lvl = w.get("level_name","?"); xp = w.get("total_xp","?"); rem = w.get("xp_remaining")
    nxt = w.get("next_level_name"); strk = w.get("current_streak")
    L.append(f"**{lvl}** · {xp} XP" + (f" · {rem} to {nxt}" if rem is not None else "")
             + (f" · 🔥 streak {strk}" if strk is not None else ""))
    if committed: L.append("\n> ✅ Day planned automatically (+5).")
    if added: L.append("> ➕ Auto-added: " + ", ".join(f"#{t['id']} {t.get('title')}" for t in added))
    L.append("\n## 📋 Today's plan")
    if not items: L.append("_no items_")
    for i in sorted(items, key=lambda x: x.get("sort_order",0)):
        dn = "✓" if (i.get("completed_at") or i.get("status")=="done") else "⬜"
        L.append(f"- {dn} **[{i.get('priority','-')}]** {i.get('title','')}")
    if overdue:
        L.append("\n## ⚠️ Overdue")
        for t in overdue:
            tag = " _(in plan)_" if t.get("id") in inplan else ""
            cm  = f" · {t['comment_count']}💬" if t.get("comment_count") else ""
            L.append(f"- **[{t.get('priority','-')}]** due {t.get('due_date')} — {t.get('title','')}{cm}{tag}")
    dt_missing = [t for t in due_today if t.get("id") not in inplan]
    if dt_missing:
        L.append("\n## 🟠 Due today, not in plan")
        for t in dt_missing: L.append(f"- **[{t.get('priority','-')}]** {t.get('title','')}")
    if disc_today:
        L.append("\n## 🗣️ Discussions today")
        for d in disc_today: L.append(f"- {d.get('planned_time','')} — {d.get('person_name') or ''} · {d.get('notes','')}")
    L.append(f"\n---\n_generated {datetime.datetime.now():%H:%M} · Claude via sam_daily.py_")
    txt = "\n".join(L)
    try:
        with open(BRIEF, "w") as f: f.write(txt)
        log(f"brief written -> {BRIEF}")
    except Exception as e:
        log(f"brief write failed: {e}")
    print("\n" + txt)

# ---------------------------------------------------------------- CLOSE
def close():
    ensure_login()
    _, plan, _ = get(f"/api/portal/{MEMBER}/day?date={TODAY}")
    plan = plan or {}
    pmeta = plan.get("plan") or {}
    if pmeta.get("status") == "closed":
        log("already closed — nothing to do."); notify("Samanvaya", "Day already closed."); return
    items = plan.get("items", [])
    if not items:
        log("no plan items; skipping close."); notify("Samanvaya", "No plan to close today."); return

    # Cross-check REAL task completion — the day-plan item's done-flag can lag the task,
    # which otherwise mislabels a finished task as "carried".
    _, tasks, _ = get(f"/api/portal/{MEMBER}/tasks")
    done_tasks = {t.get("id") for t in (tasks or []) if t.get("completed_at")}
    close_items, done, carried = [], [], []
    for i in items:
        is_done = (bool(i.get("completed_at")) or i.get("status") == "done"
                   or i.get("source_task_id") in done_tasks)
        es = "done" if is_done else "carried"
        # +8 close-my-day requires a NON-EMPTY per-item remark; keep it neutral + accurate.
        remark = "Done" if is_done else "Carried over"
        close_items.append({"id": i["id"], "end_status": es, "remark": remark})
        (done if is_done else carried).append(i.get("title",""))

    note = f"Completed {len(done)}/{len(items)}."
    if done:    note += " Done: " + "; ".join(done[:5]) + "."
    if carried: note += " Carrying: " + "; ".join(carried[:5]) + "."
    note += " (auto-closed via Claude)"

    b = wallet().get("total_xp")
    log(f"closing with note: {note}")
    if DRY:
        log("DRY — not sending close."); print("would close:", json.dumps({"note":note,"items":close_items})); return
    # portal self-close endpoint (member-scoped) is the one that awards +8
    c, r, body = post(f"/api/portal/{MEMBER}/day/close",
                      {"date": TODAY, "note": note, "items": close_items})
    if c == 200 and (r or {}).get("ok"):
        a = wallet().get("total_xp")
        log(f"closed ✓  XP {b} -> {a}")
        notify("Day closed ✓", f"{len(done)}/{len(items)} done. XP {b}→{a}.")
    else:
        log(f"close FAILED {c}: {body}")
        notify("Samanvaya", f"Close failed ({c}). See log.")

# ---------------------------------------------------------------- REMINDERS
# Interactive mode: don't act, just nudge the person to talk to Claude.
def remind_plan():
    # Only nudge if today isn't planned yet.
    ensure_login()
    _, plan, _ = get(f"/api/portal/{MEMBER}/day?date={TODAY}")
    if ((plan or {}).get("plan") or {}).get("status") == "planned":
        log("already planned — no plan nudge."); return
    notify("Plan your day 🌅", "Plan today's work with Claude (+5)", action="plan")
    _, dm = teams_urls()
    if dm: teams_post(dm, "🌅 **Plan your day** in Samanvaya — run `/myday plan` in Claude (+5)")
    log("plan reminder sent")

def remind_close():
    ensure_login()
    _, plan, _ = get(f"/api/portal/{MEMBER}/day?date={TODAY}")
    pmeta = (plan or {}).get("plan") or {}
    if pmeta.get("status") == "closed":
        log("already closed — no close nudge."); return
    if pmeta.get("status") != "planned":
        log("not planned; skipping close nudge."); return
    notify("Close your day 🌆", "Wrap up & close with Claude (+8)", action="close")
    _, dm = teams_urls()
    if dm: teams_post(dm, "🌆 **Close your day** in Samanvaya — run `/myday close` in Claude (+8)")
    log("close reminder sent")

# ---------------------------------------------------------------- TEAM NUDGES (manager-only)
# Post to the Teams channel naming reportees who haven't planned / closed yet.
def _reportees():
    if not IS_ADMIN: return None
    _, ma, _ = get("/api/admin/member-analytics")
    return ma if isinstance(ma, list) and len(ma) > 1 else None

def team_plan_nudge():
    ensure_login()
    ma = _reportees()
    if ma is None: log("not a manager / no reportees"); return
    leave = _on_leave_today()
    late = sorted([m for m in ma if not m.get("planned_today") and m.get("name") not in leave], key=lambda x: x.get("name",""))
    chan, _ = teams_urls()
    if not late:
        if chan: teams_post(chan, f"✅ **Plan check · {TODAY}** — everyone has planned. 🎉")
        log("plan check: all planned"); return
    mapp = _mentions_map(); toks = []; ents = []
    for m in late:
        t, e = _mention(m.get("name"), mapp); toks.append(t)
        if e: ents.append(e)
    msg = (f"🕙 **Plan check · {TODAY}** — not planned yet ({len(late)}/{len(ma)}): " + ", ".join(toks) +
           "\n\nClick your reminder or run `/myday plan` (+5).")
    if chan: teams_post(chan, msg, ents or None)
    log(f"team plan nudge: {len(late)} not planned")

def team_close_nudge():
    ensure_login()
    ma = _reportees()
    if ma is None: log("not a manager / no reportees"); return
    leave = _on_leave_today()
    late = []
    for m in ma:
        if m.get("name") in leave: continue
        _, plan, _ = get(f"/api/day/plan?member_id={m.get('id')}&date={TODAY}")
        status = ((plan or {}).get("plan") or {}).get("status")
        if status != "closed":
            late.append((m, "not planned" if status != "planned" else "planned, not closed"))
    chan, _ = teams_urls()
    if not late:
        if chan: teams_post(chan, f"✅ **Close check · {TODAY}** — everyone has closed. 🎉")
        log("close check: all closed"); return
    mapp = _mentions_map(); parts = []; ents = []
    for m, s in sorted(late, key=lambda x: x[0].get("name","")):
        t, e = _mention(m.get("name"), mapp); parts.append(f"{t} ({s})")
        if e: ents.append(e)
    msg = (f"🌆 **Close check · {TODAY}** — not closed yet ({len(late)}/{len(ma)}): " + "; ".join(parts) +
           "\n\nClick your reminder or run `/myday close` (+8).")
    if chan: teams_post(chan, msg, ents or None)
    log(f"team close nudge: {len(late)} not closed")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "morning"
    _MODE = cmd
    # Skip scheduled runs on weekends (Sat/Sun). Override: touch ~/.samanvaya/work-weekends
    if datetime.date.today().weekday() >= 5 and not os.path.exists(os.path.join(HOME, ".samanvaya", "work-weekends")):
        print(f"[{datetime.datetime.now():%H:%M:%S}] weekend - skipping {cmd}"); sys.exit(0)
    # Skip on company holidays (not Floater Leave). ~/.samanvaya/holidays.json = {"YYYY-MM-DD":"Name"}
    try:
        _hol = json.load(open(os.path.join(HOME, ".samanvaya", "holidays.json")))
        _hname = _hol.get(TODAY) if isinstance(_hol, dict) else (TODAY if TODAY in _hol else None)
    except Exception:
        _hname = None
    if _hname:
        print(f"[{datetime.datetime.now():%H:%M:%S}] holiday ({_hname}) - skipping {cmd}"); sys.exit(0)
    {"morning": morning, "close": close,
     "remind-plan": remind_plan, "remind-close": remind_close,
     "team-plan-nudge": team_plan_nudge, "team-close-nudge": team_close_nudge}.get(cmd, morning)()
