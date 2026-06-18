# Handoff — 2026-06-18 20:50

## Read first
`CLAUDE.md` → "Editing or adding a skill — the routine" and "Manifest schema
rules". Those two sections are what you need before touching any skill.

## What we worked on this session
Built this team plugin marketplace from scratch: created the `publish` skill,
hardened it through real teammate bug reports + a live Angular test, then created
the `tata` wrap-up skill and redesigned it after an auto-mode incident.

## Completed
- **Marketplace scaffolded** and pushed to GitHub (public), with README install/usage docs.
- **`publish` skill (v0.2.0)** — push to GitHub + deploy to GitHub Pages, returns live URL. Includes:
  - GitHub access preflight (`gh` install + `gh auth`), secret/`.gitignore` scan, public-repo consent.
  - Framework awareness: detects the app subfolder, the build **output folder** (NOT always `dist`), and sets the correct **base path** (`/<repo>/`).
  - Enables Pages via **`gh api ... build_type=workflow` with the user's auth** (the workflow's own token CANNOT create a Pages site on a new repo — confirmed live).
  - Polls the live URL, writes repo + URL into the target project's `CLAUDE.md`.
- **`tata` skill (v0.2.0)** — saves `CLAUDE.md` + `HANDOFF.md`; points user to `/publish`.
- **Tested `publish` end-to-end with a throwaway Angular 18 app** — went live, then cleaned up (repo + local folder deleted).
- **Tested `tata`** (first-run create + update-path merge) on a throwaway project; both passed.
- Added `CLAUDE.md` + `HANDOFF.md` to THIS repo (this task).

## In progress
Nothing mid-flight. Both skills are shipped and documented.

## Next steps
- (Optional) Announce `tata` v0.2.0 to the team — they should re-run
  `/plugin marketplace update observeops-team-skills` + `/plugin install tata`.
- (Optional) End-to-end test the full `tata` → manual `/publish` flow now that they're decoupled.
- Future skill ideas discussed but not built: `/sites` (live-URL dashboard),
  `/share` (link + screenshot + QR), `/brand-check` (audit vs design tokens),
  `/new-prototype` (on-brand scaffold), `/unpublish`.

## Decisions made
- **Distribution = plugin marketplace in a git repo** (not zip/copy): teammates
  install once and get updates by re-installing. User scope = global on device.
- **`publish` deploys via a GitHub Actions workflow uniformly** (static + build
  apps), adopted from the older dhoom `/publish`; more reliable than branch-root.
- **Enable Pages with the user's `gh` auth, not the workflow token** — the
  Angular test proved `enablement: true` alone fails ("Resource not accessible by
  integration") on brand-new repos.
- **tata skill redesigned — IMPORTANT CHANGE:**
  - **v0.1.0 (first version):** tata did BOTH things — saved the two files AND
    then offered to publish, chaining into `/publish` on "yes".
  - **Problem:** a teammate ran it in **auto mode**, where Claude pushes to
    complete the task and skipped the confirmation — it **auto-published** instead
    of asking. Instruction wording ("ask first") can't guarantee a stop in auto mode.
  - **v0.2.0 (current):** tata now does **only ONE thing — save the files.** It
    never publishes; it just tells the user to run `/publish` themselves.
    Decoupling is the only bulletproof fix (nothing to auto-trigger). Publishing
    is always a separate, deliberate `/publish`.
- **Naming:** the wrap-up skill went through names wrap-up → byebye → **tata**
  (chosen: short, all left-hand to type, fun, "leaving the office" vibe).

## Gotchas & notes
- This machine uses `CLAUDE_CONFIG_DIR=~/.claude-max` — personal skills live in
  `~/.claude-max/skills/`, NOT `~/.claude/skills/`. Sync maintainer copies there.
- Manifest schema is strict: `owner` and `author` must be **objects**; bad shapes
  cause install-time validation errors (we hit both early).
- Deleting a repo via `gh` needs the `delete_repo` scope (the token didn't have
  it by default) — use the web UI or `gh auth refresh -s delete_repo`.
- `gh`/`node` aren't on PATH in non-interactive shells here; node is via nvm
  (`~/.nvm/versions/node/v18.20.8/bin`).
- Skills are instructions, not code — design safety as behavior that can't be
  bypassed (the tata lesson), don't rely on Claude choosing to pause.
