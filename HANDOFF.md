# Handoff — 2026-06-25 22:57

## Read first
`CLAUDE.md` → "Skills in this marketplace", "Editing or adding a skill — the
routine", and "Manifest schema rules". Those cover what each skill does and how to
change one safely.

## What we worked on this session
Added the `tatago` skill, refined `tata`'s publish behavior after an auto-mode
incident, and spent significant time helping Windows teammates install the
marketplace (root cause turned out to be outdated Claude Code).

## Completed
- **`tata` evolved to v0.3.0**:
  - v0.1.0 saved files AND auto-offered publish (chained to `/publish`).
  - v0.2.0 **decoupled** — never publishes, just points to `/publish` (after a
    teammate's auto-mode session auto-published instead of asking).
  - v0.3.0 — `/tata` = save only (default, safe in auto mode); **`/tata publish`**
    (explicit) = save AND go live. Explicit keyword = deliberate consent.
- **`tatago` skill added (v0.1.1)** — short "do both" command: runs `tata` then
  `publish`. v0.1.1 added a **non-blocking heads-up** ("publishing live now…") so
  it's never a surprise, without a blocking prompt (Step 0 in its SKILL.md).
- **Naming journey** for the wrap-up skill: wrap-up → byebye → **tata** (short,
  left-hand, fun, "leaving the office"). Combo command named **tatago** ("tata, go!").
- **README** updated: `tata` usage, `tata` vs `tatago` comparison table, install +
  update lists include all three skills, and a **Troubleshooting** section.
- **Project context files** (CLAUDE.md + HANDOFF.md) added to THIS repo and now
  refreshed.

## In progress
Nothing mid-flight. All three skills shipped, documented, and pushed.

## Next steps
- (Optional) **End-to-end test `/tatago`** on a throwaway project — the save→publish
  chain has not been run live yet (publish itself was proven via the Angular test).
- (Optional) Announce `tatago` + `tata` v0.3.0 to the team (re-run
  `/plugin marketplace update observeops-team-skills` then install).
- Future skill ideas discussed, not built: `/sites` (live-URL dashboard),
  `/share` (link + screenshot + QR), `/brand-check` (audit vs design tokens),
  `/new-prototype` (on-brand scaffold), `/unpublish`.

## Decisions made
- **Auto-mode safety is a design constraint, not a wording fix.** You can't force
  Claude to stop-and-ask in auto mode, so risky actions must be opt-in by command
  choice: `/tata` never publishes; only `/tata publish` or `/tatago` do.
- **`tatago` is a thin orchestrator** — it invokes the `tata` and `publish` skills
  via the Skill tool rather than duplicating their logic.
- **Windows install error `JSON Parse error: Unrecognized token ''` = outdated
  Claude Code**, NOT a repo BOM. Confirmed the repo's `marketplace.json` is valid
  and BOM-free (local + raw GitHub). The empty `''` token = an empty file from a
  failed clone. README troubleshooting now leads with "update Claude Code first",
  then ZIP/manual install, then cache-clear.

## Gotchas & notes
- **Maintainer's config dir is `~/.claude-max`** (not `~/.claude`). After editing a
  skill, sync the personal copy:
  `cp <skill>/skills/<skill>/SKILL.md ~/.claude-max/skills/<skill>/SKILL.md`.
- **Open Claude FROM this folder** (`observeops-team-skills/`) so these context
  files auto-load. The parent `Observe-Ops-Code/` has no CLAUDE.md.
- **Bump version in BOTH** `plugin.json` and `marketplace.json` on every change —
  it drives the teammate "update available" signal.
- **Manual/ZIP installs don't auto-update** — teammate Nikhil installed via ZIP and
  must re-copy on changes (or switch to marketplace now that his Claude is current).
- **Don't run a PowerShell "BOM fix"** on the manifest — Windows PowerShell can
  *add* a BOM/UTF-16 and create the very problem it claims to fix.
- Deleting a GitHub repo via `gh` needs the `delete_repo` scope (not default).
