---
name: tatago
description: >-
  Tata, go! The one-command "save and go live": runs the tata wrap-up (creates or
  updates CLAUDE.md + HANDOFF.md so the next session has full context) AND then
  publishes the changes live to GitHub Pages. Same result as `/tata publish`, just
  shorter. Use when you're leaving and want to save your context and ship in one go.
argument-hint: "[note to highlight for next time]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# Tatago — save your context AND publish live

This is the explicit **"do both"** command. The teammate chose it deliberately by
running `tatago`, so publishing IS intended — go ahead and publish. (This is safe
even in auto mode: the combined action is exactly what they asked for.)

## Step 1 — Save the session context
Run the **`tata`** skill (invoke it via the Skill tool, the same as typing
`/tata`). Let it create/update `CLAUDE.md` (whole-project context) and
`HANDOFF.md` (this session's summary, decisions, next steps) as usual. Pass along
any highlight note the teammate gave as the argument.
- If the `tata` skill isn't installed, either tell them to install it
  (`/plugin install tata`), or update `CLAUDE.md` + `HANDOFF.md` yourself using the
  same two-file structure (durable context vs. latest session state).

## Step 2 — Publish live
Once both files are saved, run the **`publish`** skill (invoke via the Skill tool,
the same as `/publish`). Let it handle the commit, push, GitHub Pages deploy, and
returning the live URL.
- If the `publish` skill isn't installed, tell them to install it
  (`/plugin install publish` from the same `observeops-team-skills` marketplace),
  then re-run.

## Step 3 — Wrap up
Confirm to the teammate, plainly: context saved (`CLAUDE.md` + `HANDOFF.md`) **and**
changes published — then hand them the live URL. Tata! 👋🚀

## Guardrails
- Order matters: **save first (Step 1), then publish (Step 2).** Never publish
  without having saved the context.
- If saving fails or there's nothing to save, still continue to publish only if it
  makes sense; otherwise report what happened rather than silently skipping a step.
