---
name: byebye
description: >-
  Heading out for the day? Wrap up the session: create or update CLAUDE.md (the
  durable, whole-project context) and HANDOFF.md (this session's summary, changes,
  and decisions) so the next Claude session — or teammate — resumes with full
  context. Always updates BOTH files, then offers to publish the changes live. Use
  when leaving for the day, signing off, wrapping up, ending a session, saving
  progress, checkpointing, or handing off work.
argument-hint: "[anything to highlight for next time]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# Bye-bye — wrap up the session

You save everything needed for the next person (or next Claude session) to pick
this project up cold. You **always update two files** — `CLAUDE.md` and
`HANDOFF.md` — then offer to publish. Work from the project root. Keep the writing
clear and concise; teammates here are often designers, not engineers.

The two files have different jobs — don't mix them up:

- **`CLAUDE.md`** = the **durable, overall project context**. What this project
  *is*, its purpose, stack, structure, how to run it. Evolves slowly. Not a log.
- **`HANDOFF.md`** = the **latest session state**. What was done *this* session,
  decisions made, what's in progress, what's next. Rewritten each session.

---

## Step 1 — Gather what to save

1. Ask the teammate: *"Anything specific you want me to highlight for the next
   session?"* They can say "skip" to let you use only what you already know from
   this conversation. (If they passed text as the argument, use that and don't
   re-ask.)
2. From this session's conversation, work out: what was worked on, what got
   finished, what's mid-flight, any decisions made and why, and any gotchas.
3. Get a timestamp for the handoff:
   ```bash
   date "+%Y-%m-%d %H:%M"
   ```

---

## Step 2 — Create or update `CLAUDE.md` (whole-project context)

Check whether `CLAUDE.md` exists in the project root.

**If it does NOT exist** — explore the project and create it. Look at
`package.json`, `README.md`, the folder structure, and the main entry files to
understand the project, then write `CLAUDE.md` with these sections:
```markdown
**On session start:** If `HANDOFF.md` exists in this directory, read it before
anything else for the latest state of the work.

# <Project Name>

## What this is
<1-3 sentences: the project's purpose / what it does.>

## Tech stack
<languages, frameworks, key tools.>

## Structure
<the important folders/files and what they hold.>

## How to run
<install/dev/build commands.>

## Key context
<anything important that isn't obvious from the code — conventions, constraints,
who it's for.>

## Handoff
Latest session state is in [HANDOFF.md](HANDOFF.md) — read it first.
```

**If it DOES exist** — update it, don't replace it wholesale:
- Refresh any section that changed this session (new dependencies, new structure,
  new commands, changed purpose).
- Make sure the **"On session start … read `HANDOFF.md`"** line is at the very
  top — add it if missing.
- Make sure there's a **`## Handoff`** section (or at least a link) pointing to
  `HANDOFF.md` — add it if missing.
- Preserve everything else the teammate has written.

`CLAUDE.md` should always reflect the *current* overall project — not a list of
sessions.

---

## Step 3 — Create or update `HANDOFF.md` (this session)

Write `HANDOFF.md` in the project root with this exact structure (overwrite the
previous one — it always reflects the most recent session):
```markdown
# Handoff — <timestamp from Step 1>

## Read first
<Which CLAUDE.md sections the next session should focus on, and why. If CLAUDE.md
was just created, say "See CLAUDE.md for full project context.">

## What we worked on this session
<1-3 sentences summarising the focus of this session.>

## Completed
- <what was finished and is working>

## In progress
<What is mid-flight. Name the files / functions / components so the next session
knows exactly where to look. If nothing, write "Nothing mid-flight.">

## Next steps
- <ordered, most important first>

## Decisions made
- <approach/design/architecture decisions + the reason. If none, "None this session.">

## Gotchas & notes
<Non-obvious things: quirks, dead ends, blockers, environment notes. If none, "None.">
```

---

## Step 4 — Confirm both files are saved

Tell the teammate, plainly:
- `CLAUDE.md` was created/updated (whole-project context + link to the handoff).
- `HANDOFF.md` was written with this session's state.
- The next time anyone runs Claude in this folder, it reads `HANDOFF.md` first and
  has full context.

**Both files must be updated every time this skill runs** — never skip one.

---

## Step 5 — Offer to publish

Ask the teammate clearly:

> *"Both files are updated. Do you want to publish these changes live now?"*

- **If yes** → run the **`publish`** skill to push and deploy (invoke it via the
  Skill tool, the same as if they typed `/publish`). Let `publish` handle the
  commit, push, GitHub Pages deploy, and live URL.
  - If the `publish` skill isn't installed on their machine, tell them to install
    it first: `/plugin install publish` (from the same `observeops-team-skills`
    marketplace), then re-run.
- **If no** → you're done. Remind them their context is saved and they can publish
  anytime later with `/publish`.

---

## Guardrails

- Always update **both** `CLAUDE.md` and `HANDOFF.md` — even if one only needs a
  small change.
- Don't put session-specific logs in `CLAUDE.md`, and don't put long-term project
  docs in `HANDOFF.md`. Keep their jobs separate.
- Never invent work that didn't happen — base the handoff on the actual session.
- Preserve any existing content the teammate wrote in `CLAUDE.md`; merge, don't
  clobber.
