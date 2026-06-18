---
name: tata
description: >-
  Tata! Heading out for the day? Wrap up the session: create or update CLAUDE.md (the
  durable, whole-project context) and HANDOFF.md (this session's summary, changes,
  and decisions) so the next Claude session — or teammate — resumes with full
  context. Always updates BOTH files, then reminds you to run /publish if you want
  to go live (it never publishes by itself). Use when leaving for the day, signing
  off, wrapping up, ending a session, saving progress, checkpointing, or handing
  off work.
argument-hint: "[anything to highlight for next time]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Tata — wrap up the session before you head out

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

## Step 5 — Point to publish (DO NOT publish yourself)

🛑 **This skill never publishes. Saving the two files is the entire job.** Do not
run `publish`, do not `git push`, do not deploy — not even if the teammate seems
to want it, and **not even in auto / don't-ask mode**. Publishing a live, public
site must always be a separate, deliberate action the teammate takes themselves.

Finish by telling them, plainly:

> *"✅ Saved your context (`CLAUDE.md` + `HANDOFF.md`). To put these changes live,
> run `/publish` whenever you're ready."*

That's it — end your turn here. If they explicitly ask you to publish in a
**later** message, that's when `/publish` runs — as its own separate command, not
chained from this skill.

---

## Guardrails

- Always update **both** `CLAUDE.md` and `HANDOFF.md` — even if one only needs a
  small change.
- Don't put session-specific logs in `CLAUDE.md`, and don't put long-term project
  docs in `HANDOFF.md`. Keep their jobs separate.
- Never invent work that didn't happen — base the handoff on the actual session.
- Preserve any existing content the teammate wrote in `CLAUDE.md`; merge, don't
  clobber.
- **This skill NEVER publishes or pushes** — not even in auto mode, not even to
  "finish the task." It only writes the two files and then tells the teammate to
  run `/publish` themselves. Publishing is always a separate, deliberate command.
