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

**2. Install the publish skill:**

```
/plugin install publish
```

**3. Choose the install scope.** Claude Code will ask *where* to install it and
show three options. **Select the first one:**

> ▸ **Install for you (user scope)**  ← pick this one, then press **Enter**

This makes `/publish` work **globally — in every project and folder** on your
device. (The other two options — *project scope* and *local scope* — limit the
skill to a single repo, which is **not** what you want here.)

**4. Restart Claude Code.**

Done ✅ — now type `/publish` in **any** project, in any folder, and it works.
It is installed globally on your device, not tied to a specific repo.

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

When new skills are added or `publish` is improved, refresh with:

```
/plugin marketplace update observeops-team-skills
```

```
/plugin install publish
```

Then restart Claude Code.

---

## 🧰 What's inside

| Skill | What it does |
|-------|--------------|
| `publish` | Push the current project to GitHub and deploy it live on GitHub Pages. Sets up GitHub access on first use, creates the repo, enables Pages, and returns a copyable live URL. Remembers the repo + URL in `CLAUDE.md` so later runs just push and redeploy. |
| `tata` | Run it when you're leaving for the day. Creates/updates `CLAUDE.md` (whole-project context) and `HANDOFF.md` (this session's summary, decisions, next steps) so the next Claude session resumes with full context — then offers to publish the changes live. |

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

## ➕ Adding a new skill (maintainer)

1. Create `<skill-name>/skills/<skill-name>/SKILL.md` (copy `publish/` as a template).
2. Add a `<skill-name>/.claude-plugin/plugin.json`.
3. Add an entry to `.claude-plugin/marketplace.json`.
4. Commit and push. Teammates run the **Getting updates** commands to receive it.

---

## Maintainer

Nirav Bhatt · nirav.bhatt@motadata.com
