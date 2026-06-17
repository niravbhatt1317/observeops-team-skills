---
name: publish
description: >-
  Push the current project to GitHub and deploy it live on GitHub Pages, then
  return the shareable live URL. Sets up GitHub access if needed, creates the
  repo on first run, and remembers the repo + live URL in CLAUDE.md so future
  runs just commit, push, and redeploy. Use when someone says publish, deploy,
  ship, go live, push to github, make it live, or update the live page.
argument-hint: "[optional repo name]"
allowed-tools: Bash, Read, Write, Edit
---

# Publish to GitHub Pages

You help a teammate take the project they're working on and put it **live on the
web** via GitHub Pages, then hand them a copyable URL. Be friendly and explain
each step in one short line — many teammates are designers, not git experts.

Work through the steps in order. Stop and ask whenever a step needs the
teammate's input or consent. Never assume; confirm anything destructive or
public-facing.

---

## Step 0 — Preflight: tools & GitHub access

This is the "is this device connected to GitHub?" check.

1. **Confirm `git` and `gh` (GitHub CLI) are installed:**
   ```bash
   git --version; gh --version
   ```
   - If `gh` is missing, tell them to install it (macOS: `brew install gh`;
     Windows: `winget install GitHub.cli`; Linux: see https://cli.github.com).
2. **Check they're logged in to GitHub:**
   ```bash
   gh auth status
   ```
   - If NOT logged in: `gh auth login` is **interactive**, so it can't run
     through me. Ask the teammate to run it themselves by typing this in the
     Claude prompt (the leading `!` runs it in their terminal):
     ```
     ! gh auth login
     ```
     Tell them to choose **GitHub.com → HTTPS → Login with a web browser**, then
     come back and run `/publish` again. Assume they already have a GitHub
     account; if not, point them to https://github.com/signup.
3. **Confirm git identity is set** (needed for commits):
   ```bash
   git config user.name; git config user.email
   ```
   - If empty, set them using their GitHub name/email (`git config --global ...`).

Only continue once `gh auth status` reports they are logged in.

---

## Step 1 — Understand the project

1. Confirm the current directory is the project they want to publish (ask if
   unsure). All following commands run from the project root.
2. Is it already a git repo? `git rev-parse --is-inside-work-tree` — if not,
   run `git init -b main`.
3. **Detect the project type** (this decides how to deploy):
   - **Static site** — there's an `index.html` and no build step. Deploys
     directly from the repo.
   - **Build app** — there's a `package.json` with a `build` script (Vite,
     React, Vue, etc.). Needs a build + a Pages GitHub Action.
   Remember which one; you'll use it in Step 5.

---

## Step 2 — Safety: .gitignore & secrets

1. Ensure a `.gitignore` exists with at least: `node_modules/`, `.env`,
   `.env.*`, `.DS_Store`, and `dist/` (for build apps). Create or append it.
2. **Scan for secrets before pushing.** Check whether any `.env*` file, private
   key, or obvious credential is tracked / about to be committed:
   ```bash
   git status --porcelain; git ls-files | grep -Ei '\.env|secret|\.pem|credential' || true
   ```
   If anything sensitive would be committed, **STOP**, tell the teammate exactly
   which file, and fix `.gitignore` / untrack it before continuing. Never push
   secrets to a public repo.

---

## Step 3 — Find or create CLAUDE.md and read deployment info

1. Look for `CLAUDE.md` in the project root. If it doesn't exist, create it with
   a minimal header and an empty deployment block:
   ```markdown
   # <Project Name>

   ## Deployment
   Repo: (none yet)
   Live URL: (none yet)
   ```
2. Read the `## Deployment` block. Also check `git remote get-url origin`.
   - If a real **Repo** URL exists (and/or an `origin` remote is set) → go to
     **Step 4A**.
   - Otherwise → go to **Step 4B**.

---

## Step 4A — Repo already exists: commit & push

1. Stage changes: `git add -A`.
2. If nothing changed (`git diff --cached --quiet`), tell them it's already up to
   date and skip to Step 6 to re-show the live URL.
3. Generate a short, meaningful commit message from the diff (e.g.
   "Update hero section and pricing copy"). Commit and push:
   ```bash
   git commit -m "<message>"
   git push
   ```
4. GitHub Pages redeploys automatically (Actions, if build app). Go to Step 6.

---

## Step 4B — No repo yet: create it

1. **Suggest a repo name** from the folder name, sanitized to lowercase with
   hyphens (no spaces or special characters). Show it and ask:
   *"I'll create a GitHub repo named **`<name>`** — keep this name, or give me a
   different one?"* Use their choice.
2. **Public/private consent (required for free Pages):** Tell them plainly:
   *"GitHub Pages is free only for **public** repos, so your code will be
   visible to anyone. OK to make it public?"* If they need it private, explain
   Pages on private repos requires GitHub Pro/Team, and let them decide.
3. Create the repo, set it as `origin`, and push in one go:
   ```bash
   git add -A
   git commit -m "Initial commit"
   gh repo create <name> --public --source=. --remote=origin --push
   ```
   (Use `--private` instead of `--public` only if they chose private.)

---

## Step 5 — Set up GitHub Pages (via GitHub Actions)

Deploy through a **GitHub Actions workflow for BOTH static and build projects** —
it's the most reliable method. Skip this whole step if
`.github/workflows/deploy.yml` already exists (a previous run created it) —
just continue.

Get the owner/repo: `gh repo view --json nameWithOwner -q .nameWithOwner`.

1. **Create `.github/workflows/deploy.yml`** based on the project type from Step 1.

   - **Static site** — upload the repo as-is:
     ```yaml
     name: Deploy to GitHub Pages
     on:
       push:
         branches: [main]
       workflow_dispatch:
     permissions:
       contents: read
       pages: write
       id-token: write
     concurrency:
       group: pages
       cancel-in-progress: false
     jobs:
       deploy:
         environment:
           name: github-pages
           url: ${{ steps.deployment.outputs.page_url }}
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v4
           - uses: actions/configure-pages@v5
             with:
               enablement: true
           - uses: actions/upload-pages-artifact@v3
             with:
               path: .
           - uses: actions/deploy-pages@v4
             id: deployment
     ```

   - **Build app (Vite/Vue/React, etc.)** — build first, then upload the output
     folder (`dist`). Also set the build **base path** to `/<repo>/` so assets
     resolve (e.g. Vite: `base: '/<repo>/'` in `vite.config`):
     ```yaml
     name: Deploy to GitHub Pages
     on:
       push:
         branches: [main]
       workflow_dispatch:
     permissions:
       contents: read
       pages: write
       id-token: write
     concurrency:
       group: pages
       cancel-in-progress: false
     jobs:
       build:
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v4
           - uses: actions/setup-node@v4
             with:
               node-version: 20
           - run: npm ci
           - run: npm run build
           - uses: actions/configure-pages@v5
             with:
               enablement: true
           - uses: actions/upload-pages-artifact@v3
             with:
               path: dist
       deploy:
         needs: build
         environment:
           name: github-pages
           url: ${{ steps.deployment.outputs.page_url }}
         runs-on: ubuntu-latest
         steps:
           - uses: actions/deploy-pages@v4
             id: deployment
     ```
   Tell the teammate an extra file (the workflow) was added, and why.

   The `enablement: true` on `configure-pages` makes the **workflow itself**
   turn Pages on and set the source to "GitHub Actions" — so this works even if
   the `gh` CLI is unavailable.

2. **Best-effort: also point Pages at Actions via API** (harmless if it fails,
   since the workflow self-enables — ignore any error):
   ```bash
   gh api -X POST repos/{owner}/{repo}/pages -f build_type=workflow 2>/dev/null || true
   ```

3. **Commit and push the workflow** so the deploy actually runs:
   ```bash
   git add .github/workflows/deploy.yml
   git commit -m "Add GitHub Pages deployment"
   git push
   ```

4. Deploy progress is visible at `https://github.com/<owner>/<repo>/actions`.

**If the page is still 404 after a few minutes:** the first run occasionally
needs Pages enabled by hand. Tell the teammate to open
`https://github.com/<owner>/<repo>/settings/pages`, set **Source → GitHub
Actions**, then re-run the latest workflow from the Actions tab. After that it
publishes normally on every push.

---

## Step 6 — Wait for it to go live, then show the URL

1. The live URL is: `https://<owner>.github.io/<repo>/`
   (If the repo is named exactly `<owner>.github.io`, the URL is just
   `https://<owner>.github.io/`.)
2. Pages takes up to ~1–2 minutes the first time. Poll until it's live:
   ```bash
   for i in $(seq 1 20); do
     code=$(curl -s -o /dev/null -w "%{http_code}" "<live-url>")
     [ "$code" = "200" ] && echo "LIVE" && break
     sleep 8
   done
   ```
   Let them know it can take a minute on the very first deploy.

---

## Step 7 — Record it in CLAUDE.md

Update the `## Deployment` block so future `/publish` runs find it instantly:
```markdown
## Deployment
Repo: https://github.com/<owner>/<repo>
Live URL: https://<owner>.github.io/<repo>/
```

---

## Step 8 — Hand off the URL

Finish with the live URL on its own line so it's easy to copy and share, e.g.:

> ✅ Published! Your page is live at:
> **https://<owner>.github.io/<repo>/**

If it was the first deploy, remind them it may take a minute to appear.

---

## Guardrails

- Never create a **public** repo, or push for the first time, without the
  teammate's explicit OK.
- Never commit or push `.env` files, keys, or credentials.
- Always confirm the repo **name** before creating it.
- If a `gh` command fails, show the error in plain language and suggest the fix
  (usually `! gh auth login` or installing `gh`) rather than retrying blindly.
- The **first** time you `git push`, Claude Code will ask the teammate for
  permission. Tell them: if they pick the **"Yes, and don't ask again for git
  push"** option, they'll never be prompted to push again — on any project. This
  is the one-time, no-command way to make `/publish` frictionless going forward.
