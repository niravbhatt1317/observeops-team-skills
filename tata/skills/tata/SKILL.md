---
name: tata
description: >-
  Tata! Heading out for the day? Wrap up the session: create or update CLAUDE.md (the
  durable, whole-project context) and HANDOFF.md (this session's summary, changes,
  and decisions) so the next Claude session — or teammate — resumes with full
  context. Always updates BOTH files. By default it does NOT publish — it points
  you to /publish. Run `/tata publish` (or say "tata and publish") to save AND go
  live in one step. Use when leaving for the day, signing off, wrapping up, ending
  a session, saving progress, checkpointing, or handing off work.
argument-hint: "[publish] [note to highlight for next time]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# Tata — wrap up the session before you head out

You save everything needed for the next person (or next Claude session) to pick
this project up cold. You **always update two files** — `CLAUDE.md` and
`HANDOFF.md`. You publish **only if** the teammate explicitly asked (see Step 5).
Work from the project root. Keep the writing clear and concise; teammates here are
often designers, not engineers.

The two files have different jobs — don't mix them up:

- **`CLAUDE.md`** = the **durable, overall project context**. What this project
  *is*, its purpose, stack, structure, how to run it. Evolves slowly. Not a log.
- **`HANDOFF.md`** = the **latest session state**. What was done *this* session,
  decisions made, what's in progress, what's next. Rewritten each session.

---

## Step 1 — Gather what to save (and check for a publish request)

1. **Check whether the teammate asked to publish too.** Set "publish intent =
   YES" only if it's explicit in THIS invocation:
   - the argument contains `publish`, `ship`, `deploy`, or `live` (e.g. they ran
     `/tata publish`), OR
   - their message clearly says to publish (e.g. "tata and publish", "wrap up and
     go live").
   Otherwise publish intent = NO (the default). Remember this for Step 5. Treat
   any remaining argument text (after removing a publish keyword) as the highlight
   note for the handoff.
2. Ask the teammate: *"Anything specific you want me to highlight for the next
   session?"* They can say "skip" to let you use only what you already know from
   this conversation. (If they already gave highlight text in the argument, use it
   and don't re-ask.)
3. From this session's conversation, work out: what was worked on, what got
   finished, what's mid-flight, any decisions made and why, and any gotchas.
4. Get a timestamp for the handoff:
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

## Step 5 — Publish ONLY if explicitly requested

Use the "publish intent" you determined in Step 1.

**If publish intent = NO (the default `/tata`):**
🛑 Do **not** publish. Do not run `publish`, `git push`, or deploy — not even if
it seems like they'd want it, and **not even in auto / don't-ask mode**. Finish by
telling them, plainly:

> *"✅ Saved your context (`CLAUDE.md` + `HANDOFF.md`). To put these changes live,
> run `/publish` (or next time, `/tata publish` to do both at once)."*

Then end your turn.

**If publish intent = YES (they ran `/tata publish`, or clearly asked to publish):**
They explicitly opted in, so it's safe to chain. After the two files are saved,
run the **`publish`** skill (invoke it via the Skill tool, the same as if they
typed `/publish`) and let it handle the commit, push, GitHub Pages deploy, and
live URL. Tell them you're saving first, then publishing.
- If the `publish` skill isn't installed, tell them to install it:
  `/plugin install publish` (same `observeops-team-skills` marketplace), then re-run.

**The rule:** publishing happens only when the teammate explicitly asked in this
invocation. No explicit publish request → never publish. This is what keeps it
safe in auto mode while still letting "do both at once" be a single command.

---

## Guardrails

- Always update **both** `CLAUDE.md` and `HANDOFF.md` — even if one only needs a
  small change.
- Don't put session-specific logs in `CLAUDE.md`, and don't put long-term project
  docs in `HANDOFF.md`. Keep their jobs separate.
- Never invent work that didn't happen — base the handoff on the actual session.
- Preserve any existing content the teammate wrote in `CLAUDE.md`; merge, don't
  clobber.
- **Never publish unless the teammate explicitly asked in this invocation** (via
  `/tata publish` or a clear "publish" request). With no explicit request, only
  write the two files and point them to `/publish` — not even in auto mode, not to
  "finish the task." Explicit request = OK to chain; inferred desire = NOT OK.
