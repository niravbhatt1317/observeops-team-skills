**On session start:** If `HANDOFF.md` exists in this directory, read it before
anything else for the latest state of the work.

# ObserveOps Team Skills

## What this is
A **Claude Code plugin marketplace** for the ObserveOps / Design System team.
It packages shareable skills (slash commands) that teammates install once and use
globally on their own machines. Maintained by Nirav Bhatt (nirav.bhatt@motadata.com).

- **GitHub:** https://github.com/niravbhatt1317/observeops-team-skills (public)
- **GitHub account used:** `niravbhatt1317`
- Teammates install with:
  `/plugin marketplace add https://github.com/niravbhatt1317/observeops-team-skills`
  then `/plugin install <skill>`, choosing **"Install for you (user scope)"** so it
  works in every project on their device.

## Skills in this marketplace
| Skill | Version | What it does |
|-------|---------|--------------|
| `publish` | 0.2.0 | Push the current project to GitHub and deploy it live on GitHub Pages, returning a copyable URL. Framework-aware (HTML, Vite/React/Vue, Angular, CRA, Gatsby, Astro; warns on SSR). |
| `tata` | 0.3.0 | "Heading out" wrap-up: create/update `CLAUDE.md` + `HANDOFF.md` so the next session has context. Default does NOT publish; `/tata publish` saves AND goes live (explicit opt-in keeps it safe in auto mode). |
| `tatago` | 0.1.1 | Shortcut that does both at once: runs `tata` (save context) then `publish` (go live). Posts a non-blocking "publishing live now…" heads-up first. Thin orchestrator — invokes the `tata` and `publish` skills via the Skill tool. |

## Structure
```
.claude-plugin/marketplace.json   # marketplace manifest: lists all three plugins
publish/
  .claude-plugin/plugin.json      # plugin manifest for publish
  skills/publish/SKILL.md         # the publish skill (instructions Claude follows)
tata/
  .claude-plugin/plugin.json      # plugin manifest for tata
  skills/tata/SKILL.md            # the tata skill
tatago/
  .claude-plugin/plugin.json      # plugin manifest for tatago
  skills/tatago/SKILL.md          # the tatago skill (orchestrates tata + publish)
README.md                         # install + usage docs for teammates
CLAUDE.md / HANDOFF.md            # this project's own context (open Claude here)
```

## How a skill works
A skill is **plain-English instructions in `SKILL.md`** that Claude reads and
follows when the user types the slash command — it is NOT deterministic code.
This means skills are flexible but not 100% mechanical; important guarantees
(like "never publish without consent") must be designed as behavior that doesn't
rely on Claude choosing to stop (see the tata decoupling in HANDOFF.md).

## Editing or adding a skill — the routine (do ALL of these)
1. **Edit** the skill's `SKILL.md` (and/or `plugin.json`) in this repo.
2. **Sync the maintainer's personal copy** so Nirav's own command updates:
   `cp <skill>/skills/<skill>/SKILL.md ~/.claude-max/skills/<skill>/SKILL.md`
   (Note: this machine uses `CLAUDE_CONFIG_DIR=~/.claude-max`, NOT `~/.claude`.)
3. **Bump the version** in BOTH `plugin.json` and the `marketplace.json` entry
   (patch for fixes, minor for features/behavior changes). Version drives the
   "update available" signal for teammates.
4. **Validate JSON:** `python3 -c "import json;json.load(open('<file>'))"`.
5. **Commit & push.** Teammates then run
   `/plugin marketplace update observeops-team-skills` + `/plugin install <skill>`.

To add a NEW skill: create `<name>/.claude-plugin/plugin.json` and
`<name>/skills/<name>/SKILL.md`, add an entry to `marketplace.json` `plugins`,
document it in `README.md`, then follow the routine above.

## Manifest schema rules (these caused real install failures — get them right)
- `marketplace.json`: requires top-level **`name`** (string, kebab-case, not a
  reserved name) and **`owner`** (an **object** `{name, email}`), plus a
  `plugins` array. Each plugin entry needs `name` + `source` (`"./<dir>"`).
- `plugin.json`: `name` required; **`author` must be an object** `{name, email}`,
  not a string. `version` optional but we set it.
- Both carry a `$schema` line for editor-time validation in VS Code.
- Plugin/skill names must be **kebab-case**, no spaces or special chars.

## Key context / conventions
- Commits in this repo are authored as `Nirav Bhatt <nirav.bhatt@motadata.com>`.
- The marketplace name `observeops-team-skills` is what teammates register; don't
  rename it without telling everyone (each user registers one marketplace per name).
- Skill behavior should be safe under **auto mode**: never rely on Claude pausing
  to ask before a high-impact action — design the skill so the risky action simply
  doesn't happen automatically.

## Handoff
Latest session state is in [HANDOFF.md](HANDOFF.md) — read it first.
