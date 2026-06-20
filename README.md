# ObserveOps Team Skills

Shared [Claude Code skills](https://code.claude.com/docs/en/skills) for the
ObserveOps / Design System team. **Install once — the skills work globally on
your device, in every project and folder.**

---

## 🚀 Install (do this once)

> **Requirement:** [Claude Code](https://code.claude.com/docs) is installed and
> you're signed in.

Open Claude Code and run these two commands. Each fenced block below has a
**copy button** in the top-right corner on GitHub — click it to copy.

**1. Add this skills marketplace:**

```
/plugin marketplace add https://github.com/niravbhatt1317/observeops-team-skills
```

**2. Install the skills:**

```
/plugin install publish
```
```
/plugin install tata
```
```
/plugin install tatago
```

**3. Choose the install scope.** Claude Code will ask *where* to install each one
and show three options. **Select the first one:**

> ▸ **Install for you (user scope)**  ← pick this one, then press **Enter**

This makes `/publish` work **globally — in every project and folder** on your
device. (The other two options — *project scope* and *local scope* — limit the
skill to a single repo, which is **not** what you want here.)

**4. Restart Claude Code.**

Done ✅ — now type `/publish` or `/tata` in **any** project, in any folder, and
they work. They're installed globally on your device, not tied to a specific repo.

### 💡 First time you publish: pick "don't ask again"

The **first** time `/publish` pushes your code, Claude Code will ask permission
to run `git push` (a normal safety check before sending code to GitHub). In that
prompt, choose the option like:

> ✅ **Yes, and don't ask again for git push commands**

Pick that **once** and you'll never be asked again — on this or any other
project. No command to run, no file to edit; just select that option the first
time. (If you only pick plain "Yes", it'll ask again on the next publish.)

---

## ✅ Verify it worked

Type `/` in Claude Code and you should see **`publish`** in the list. Or just run:

```
/publish
```

---

## 🔄 Getting updates

When new skills are added or a skill is improved, refresh with:

```
/plugin marketplace update observeops-team-skills
```
```
/plugin install publish
```
```
/plugin install tata
```
```
/plugin install tatago
```

Then restart Claude Code.

---

## 🧰 What's inside

| Skill | What it does |
|-------|--------------|
| `publish` | Push the current project to GitHub and deploy it live on GitHub Pages. Sets up GitHub access on first use, creates the repo, enables Pages, and returns a copyable live URL. Remembers the repo + URL in `CLAUDE.md` so later runs just push and redeploy. |
| `tata` | Run it when you're leaving for the day. Creates/updates `CLAUDE.md` (whole-project context) and `HANDOFF.md` (this session's summary, decisions, next steps) so the next Claude session resumes with full context. Default does **not** publish; run `/tata publish` to save **and** go live in one step. |
| `tatago` | The short "do both" command — saves your context **and** publishes live in one go (same as `/tata publish`). |

### `tata` vs `tatago` — which do I use?

| | `/tata` | `/tatago` |
|---|---|---|
| Saves `CLAUDE.md` + `HANDOFF.md` | ✅ | ✅ |
| Publishes live to GitHub Pages | ❌ (never — points you to `/publish`) | ✅ (saves **then** publishes) |
| Use it when… | You're saving progress / leaving, but **not** ready to go live | You want to **save and ship** in one step |

**Rule of thumb:** `/tata` = *save only.* `/tatago` = *save + go live.*
(`/tata publish` does the same as `/tatago` — just longer to type.)

### Using `/publish`

From any project folder, run:

```
/publish
```

The skill will: check your GitHub access → create or update the repo → deploy to
GitHub Pages → give you the live URL to share. First run will ask you to confirm
the repo name and that the repo can be public (free GitHub Pages requires it).

> **First time only:** if you're not logged in to GitHub on your machine, the
> skill will ask you to run this once (the leading `!` runs it in your terminal):
>
> ```
> ! gh auth login
> ```
>
> Don't have the GitHub CLI? Install it: macOS `brew install gh` · Windows
> `winget install GitHub.cli` · Linux → https://cli.github.com

### ✅ After you publish — check it actually rendered

A plain HTML page goes live almost instantly. A **build app (Vite / React / Vue)
takes a minute and has more moving parts**, so confirm it before sharing:

1. **Open the live URL.** You should see your *app*, not a page of text. If you
   see the README rendered as a webpage, the app wasn't built/published — tell
   Claude "the live page is showing the README, not my app" and it'll fix the
   deploy.
2. **Blank white page?** That's almost always a missing **base path**. The app
   must be built with base `/<repo-name>/`. Tell Claude "the page is blank,
   check the Vite base path" — it sets `base: '/<repo>/'` in the Vite config.
3. **Still 404 after a few minutes?** Pages source isn't set. Go to
   **Settings → Pages → Source → GitHub Actions**, then re-run the latest run
   from the **Actions** tab.
4. **Red ✗ in the Actions tab?** Open the failed run, copy the red error lines,
   and paste them to Claude — it'll patch the workflow.

> Tip: if your app lives in a subfolder (e.g. `app/`), make sure `/publish` is
> building *that* folder — Claude detects this, but double-check the live page
> shows the app.

### Using `/tata` — wrap up when you leave

When you're done for the day, from the project folder run:

```
/tata
```

It will:
1. **Update `CLAUDE.md`** — the durable, whole-project context (creates it if the
   project doesn't have one yet).
2. **Update `HANDOFF.md`** — what you did this session, decisions made, and the
   next steps.
3. **Remind you to publish** — by default it does **not** publish on its own, so
   nothing goes public by accident (even in auto mode). It just tells you to run
   `/publish` when you're ready.

**Want to do both at once?** Either of these saves your context **and** publishes
live in one step:

```
/tatago
```
```
/tata publish
```

`/tatago` is just the short form. Publishing only happens when you explicitly run
`/tatago` or add `publish` — so the plain `/tata` stays safe and never ships by
accident.

Next time anyone opens the project, Claude reads `HANDOFF.md` first and already
knows the full history and the latest state — no "where did we leave off?"

---

## 🙋 No GitHub CLI / prefer manual install?

You can skip the marketplace and copy the skill folder directly into your Claude
config. Find your Claude config directory (usually `~/.claude`, or `~/.claude-max`
if you use that setup), then:

```
mkdir -p ~/.claude/skills && cp -r publish/skills/publish ~/.claude/skills/publish
```

This works too, but you won't get automatic updates — the plugin route above is
recommended.

---

## 🛠️ Troubleshooting

### `JSON Parse error: Unrecognized token ''` when adding the marketplace

This is **not a problem with the repo** — its `marketplace.json` is valid and has
no BOM. The empty `''` token means Claude Code received an **empty file** when it
tried to clone/read the marketplace. In practice this is almost always an
**outdated Claude Code** (especially on Windows). Work through these in order:

**1. Update Claude Code first** ⭐ (this is the most common fix)
Update to the latest version, restart, then retry:
```
/plugin marketplace add https://github.com/niravbhatt1317/observeops-team-skills
```
Then `/plugin install publish` · `tata` · `tatago` (choose **"Install for you
(user scope)"**). Check your version with `claude --version`.

**2. If it still fails — install manually from the ZIP** (no marketplace needed)
Download the repo: https://github.com/niravbhatt1317/observeops-team-skills →
green **Code** → **Download ZIP**, then:

*Windows (PowerShell) — paste as ONE line:*
```powershell
Expand-Archive -Force "$env:USERPROFILE\Downloads\observeops-team-skills-main.zip" "$env:USERPROFILE\Downloads\oots"; $src=(Get-ChildItem -Recurse "$env:USERPROFILE\Downloads\oots" -Filter "marketplace.json" | Select-Object -First 1).Directory.Parent.FullName; New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null; "publish","tata","tatago" | ForEach-Object { Copy-Item -Recurse -Force "$src\$_\skills\$_" "$env:USERPROFILE\.claude\skills\$_" }; Get-ChildItem "$env:USERPROFILE\.claude\skills"
```
*macOS / Linux:*
```
cd ~/Downloads && unzip -o observeops-team-skills-main.zip && mkdir -p ~/.claude/skills && for s in publish tata tatago; do cp -R observeops-team-skills-main/$s/skills/$s ~/.claude/skills/$s; done
```
Restart Claude Code → `/publish`, `/tata`, `/tatago` appear. (Manual installs
don't auto-update — re-run this when skills change, or switch to the marketplace
once step 1 works.)

**3. Rare — stale cache from an earlier failed add**
If you previously had a broken add cached, clear it and redo step 1:
```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\marketplaces\observeops-team-skills" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\temp_local_*" -ErrorAction SilentlyContinue
```
(macOS/Linux: `rm -rf ~/.claude/plugins/marketplaces/observeops-team-skills ~/.claude/plugins/cache/temp_local_*`)

> ⚠️ **Don't run a "BOM fix" script** on the manifest — the repo file is clean,
> and on Windows PowerShell `Out-File` / `>` can *add* a BOM/UTF-16 and create a
> real problem. The fix is updating Claude Code, not editing the file. (If your
> config dir is `.claude-max` instead of `.claude`, swap that into the paths.)

---

## ➕ Adding a new skill (maintainer)

1. Create `<skill-name>/skills/<skill-name>/SKILL.md` (copy `publish/` as a template).
2. Add a `<skill-name>/.claude-plugin/plugin.json`.
3. Add an entry to `.claude-plugin/marketplace.json`.
4. Commit and push. Teammates run the **Getting updates** commands to receive it.

---

## Maintainer

Nirav Bhatt · nirav.bhatt@motadata.com
