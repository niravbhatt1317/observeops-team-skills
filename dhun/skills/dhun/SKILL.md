---
name: dhun
description: >-
  Dhun (धुन — "tune"). Give Claude Code a voice: distinct sounds when Claude
  finishes a turn, needs your input, or a tool call fails — plus one that fires
  back when you praise it — so you know what's happening without watching the
  terminal. Installs sound hooks globally for every project and every surface
  (terminal, VS Code, JetBrains, desktop app) on this machine. Use when someone
  says: install dhun, set up sounds, sound notifications, play a sound when
  Claude finishes or errors, play a sound when I say thanks, mute/pause the
  sounds, resume sounds, change a notification sound or volume, or "I can't
  hear anything".
argument-hint: "[install|test|status|pause|resume|doctor|why|set|volume|uninstall] [args]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# dhun — sound cues for Claude Code

Five sounds, five lifecycle events:

| Event | Sound | Meaning |
|---|---|---|
| `Stop` | chime | Claude finished the turn |
| `PermissionRequest` / `Elicitation` / `Notification`→`agent_needs_input` | *"Ye koi tareeka hai bheek mangne ka?"* | Claude is blocked, needs approval |
| `Notification` → `idle_prompt` | *"Kuchu puchu tum kaha ho"* | You've gone idle |
| `PostToolUseFailure` | *"Are maalik wo thoda sa galti ho gayi"* | A tool call failed |
| `UserPromptSubmit` | *owww* | You praised Claude |

The skill is an **installer and manager**. The sounds are played by hooks in
`settings.json` — not by this skill. That matters when debugging: if the hooks are
wired, sounds work whether or not this skill is ever invoked again.

Two directories matter, and confusing them is the easiest mistake to make here:

- **`$SKILL_DIR`** — the folder containing this file. The *source*. Used for
  `install.sh` and for editing sound files.
- **`$DHUN_DIR`** — the *installed* copy the hooks actually run, and where mute flags
  live. Resolve it as:

  ```sh
  DHUN_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/dhun"
  ```

Always run `dhunctl.sh` from `$DHUN_DIR`, never from `$SKILL_DIR` — pausing the source
copy has no effect on the hooks. After editing a sound in `$SKILL_DIR`, re-run
`install.sh` to copy it across.

## Routing

Pick by what the user asked for. With no argument, run **install** if hooks aren't
wired yet, otherwise **status**.

| User says | Do |
|---|---|
| install, set up, add sounds | Install |
| test, play, let me hear | Test |
| status, what's set up | Status |
| pause, mute, quiet, stop the sounds | Pause |
| resume, unmute, turn back on | Resume |
| doctor, not working, can't hear anything | Doctor |
| why did/didn't the praise sound fire | Why |
| praise sound fires too often / never fires | Why, then tune the tiers |
| change/swap a sound | Set a sound |
| louder, quieter, volume | Volume |
| uninstall, remove | Uninstall |

## Install

```sh
"$SKILL_DIR/install.sh"           # active config dir      (macOS / Linux / Git Bash)
"$SKILL_DIR/install.sh" --all     # every config dir found
```

On Windows without Git Bash, use the PowerShell installer instead:

```powershell
.\install.ps1          # or -All / -Dir PATH / -Uninstall
```

Either installer wires the **`.ps1` hooks** on Windows, so the runtime never needs Git
Bash. Neither `jq` nor any other dependency is required: `install.sh` falls back to
`python3`, and the PowerShell path uses built-in `ConvertFrom-Json`.

Installing **user-level** makes it global: every project, every directory, and every
surface on this machine (terminal, VS Code, JetBrains, desktop app, Conductor) reads
the same `settings.json`. Install once from anywhere; it works everywhere.

The installer backs up `settings.json`, merges rather than overwrites, and is
idempotent.

**Before installing**, check for the config-dir trap:

```sh
grep -n "CLAUDE_CONFIG_DIR" ~/.zshrc ~/.zprofile ~/.zshenv ~/.bashrc 2>/dev/null
```

If `CLAUDE_CONFIG_DIR` is set by an **alias** rather than exported, only terminal
sessions using that alias will see the hooks — VS Code and the desktop app launch
`claude` directly and read `~/.claude`. Say so plainly and offer `--all`.

**After installing, always tell the user to restart Claude Code.** Hooks load at
session start; the running session will stay silent. This is the single most common
"it doesn't work" report. Then offer the demo sequence in `DEMO.md`.

## The praise sound

`UserPromptSubmit` fires the instant the user presses enter — **before Claude sees the
message**. So `dhun-praise.sh` reads the payload, decides, and plays. Claude is not in
the loop, and nothing about this depends on the model noticing anything.

It decides in four steps. Read them in order; each exists because the one before it
would otherwise be wrong:

1. **Hard negatives** — `no thanks`, `thanks but`, `not great`, `it doesn't work`.
   These outrank everything below, because they are *built out of* praise words.
2. **Strong tier** — unambiguous praise (`thanks`, `great work`, `well done`,
   `shabash`, `kya baat`, 🎉). Fires anywhere in the message, so
   *"thanks! now refactor the auth module"* still counts.
3. **Request guard** — kills the weak tier for `make it nicer`, `is this good?`,
   `update the …`. Applies only to the weak tier, so step 2 is unaffected.
4. **Weak tier** — bare adjectives that double as instructions (`perfect`, `nice`,
   `clean`). Only fires as a **leading clause of ≤ 3 words**, which is what separates
   *"perfect!"* from *"make the header perfect and add a hover state"*.

**To answer "why did/didn't it fire", don't reason about it — run it:**

```sh
"$DHUN_DIR/hooks/dhunctl.sh" why "perfect, now ship it"     # -> PRAISE
"$DHUN_DIR/hooks/dhunctl.sh" why "make the spacing nicer"   # -> silent
```

Tuning knobs, in order of usefulness: `DHUN_PRAISE_MAXWORDS` (default 3) widens or
narrows the weak tier; `DHUN_PRAISE_MAXLEN` (default 40) is a secondary char guard;
`DHUN_VOLUME_PRAISE` sets volume. To add a phrase, edit the `STRONG` or `WEAK` list in
`$SKILL_DIR/hooks/dhun-praise.sh` **and** the matching list in `dhun-praise.ps1` — the
two must stay in step — then re-run `install.sh`.

Three constraints on this hook specifically. Do not "clean these up":

- **It must never write to stdout.** `UserPromptSubmit` is the one event whose output
  is fed back into the model as `additionalContext`, so a stray `echo` becomes text in
  the conversation. CI asserts stdout stays empty.
- **Its hook command must not end in `&`.** Every other dhun hook backgrounds itself
  that way, but this one has to read the payload off stdin, and backgrounding detaches
  it from that stdin. It backgrounds the *playback* internally instead.
- **It must never match the raw payload.** The JSON also carries `cwd`,
  `session_id` and `transcript_path` — so grepping the blob means a project folder
  named `nice-dashboard` fires the sound on every prompt, forever. The `prompt` field
  is extracted first. CI has a regression test for exactly this.

Known limitation: **sarcasm reads as praise.** *"great, it broke again"* fires. Fixing
it properly needs sentiment, not pattern matching; `pause praise` is the answer if it
ever grates.

## Test

```sh
"$DHUN_DIR/hooks/dhunctl.sh" test              # all five
"$DHUN_DIR/hooks/dhunctl.sh" test error        # just one
```

Plays immediately, bypassing mute and needing no restart. Use this to confirm audio
works before blaming the hooks.

## Status / Doctor

```sh
"$DHUN_DIR/hooks/dhunctl.sh" status
"$DHUN_DIR/hooks/dhunctl.sh" doctor
```

`doctor` checks install dir, config dir, whether hooks are wired, whether an audio
player exists, and mute state. Run it first for any "I hear nothing" report.

Common causes, in order of likelihood:

1. **Session not restarted** — by far the most common
2. **Wrong config dir** — the alias trap above
3. **Muted** — check `status`
4. **Remote context** — SSH, dev container, or claude.ai/code. Hooks run where the
   Claude process lives; there is no audio path back to the user's machine. Not
   fixable — say so rather than debugging further.
5. **No audio player** — Linux without `paplay`/`aplay`/`ffplay`/`mpv`

## Pause / Resume

Mute is a flag file, so it applies instantly with no restart, persists across
sessions, and leaves the hooks installed.

```sh
dhunctl.sh pause                 # everything, indefinitely
dhunctl.sh pause 1h              # everything, auto-resumes after an hour
dhunctl.sh pause error           # just the failure sound
dhunctl.sh pause 30m attention   # one event, timed
dhunctl.sh resume                # everything
dhunctl.sh resume error          # one event
```

Suggest `pause error` when someone is deep in a debugging session — that sound fires
most and annoys first. Suggest `pause praise` on a screen share, where a meme firing
because someone typed "perfect" is the wrong kind of memorable. Suggest a timed `pause`
before meetings.

## Set a sound

Replace any of `done`, `attention`, `permission`, `error`, `praise`.

**From a local file:**

```sh
ffmpeg -y -i INPUT -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -ar 44100 -ac 2 -c:a pcm_s16le "$SKILL_DIR/sounds/wav/NAME.wav"
```

**From a YouTube/Instagram URL** — needs `yt-dlp` and `ffmpeg`:

1. Download: `yt-dlp -x --audio-format wav -o raw.wav "URL"`
2. Find speech segments: `ffmpeg -i raw.wav -af silencedetect=noise=-30dB:d=0.25 -f null -`
3. Cut candidates and **play each for the user one at a time** — you cannot hear
   audio, so they must choose. Label each with its time range.
4. Trim the chosen range, normalize, fade:
   ```sh
   ffmpeg -ss START -t LEN -i raw.wav \
     -af "loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=0.04,afade=t=out:st=END:d=0.16" \
     -ar 44100 -ac 2 -c:a pcm_s16le "$SKILL_DIR/sounds/wav/NAME.wav"
   ```
5. Re-run `install.sh` to copy it into the config dir.

**Keep `Stop` short — ideally a chime, not speech.** It fires on every turn, dozens of
times an hour. A voice clip is funny at ten repetitions and unbearable at fifty. The
voice memes work on `Notification`, `PostToolUseFailure` and `UserPromptSubmit`
precisely because those are rare. Push back if someone asks for a long clip on `Stop`.

Always normalize to −16 LUFS so all five sit at equal loudness.

## Volume

Edit the number in the hook command in `settings.json` (`... done 0.75 &`). Range
0.0–1.0.

`afplay -v` only attenuates — values above 1.0 do nothing. To make a sound *louder*
than its file level, re-normalize the file itself.

## Uninstall

```sh
"$SKILL_DIR/install.sh" --uninstall
```

Removes only dhun's hooks; other hooks are preserved. A backup is left at
`settings.json.dhun-backup`.

## Platform notes

WAV is canonical because Windows' `Media.SoundPlayer` accepts nothing else. The MP3
copies are for sharing, never used by hooks.

`dhun-play.sh` detects macOS (`afplay`), Linux (`paplay`/`ffplay`/`aplay`/`mpv`),
Windows and WSL (PowerShell).

**Windows and Linux are verified in CI** — ubuntu × macos × (jq, python3), plus Windows
on PowerShell 5.1 and 7. What CI cannot prove is that a sound is *audible*: runners have
no sound device, so audio has only ever been heard on macOS. If someone asks about
platform support, that is the honest split — the logic is tested everywhere, the
loudspeaker only on a Mac. WSL is untested either way.

Both hook scripts always `exit 0`: a missing audio player must never fail a tool call.

## Note on the error hook

**`PostToolUse` fires only on success. `PostToolUseFailure` fires on failure.** dhun
wires the latter. If someone reports "the error sound never plays", check they have not
wired `PostToolUse` — that was dhun's original bug, and it fails silently because the
hook is simply never invoked.

Since the event fires only on failure, nothing is parsed: the hook plays the sound
directly. There is no payload inspection, no `jq`, and no false positives.
