# dhun (धुन — "tune")

Audio cues for Claude Code. Five sounds, mapped to distinct lifecycle events, so you
know what Claude is doing without watching the terminal.

| Event | Sound | Meaning | Length |
|---|---|---|---|
| `Stop` | `done.wav` — Glass chime | Claude finished the turn | 1.65s |
| `PermissionRequest` · `Elicitation` · `Notification`→`agent_needs_input` | `permission.wav` — *"Ye koi tareeka hai bheek mangne ka?"* | Claude is blocked, needs your approval | 1.71s |
| `Notification` → `idle_prompt` | `attention.wav` — *"Kuchu puchu tum kaha ho"* | You've gone idle (60s, by design) | 2.50s |
| `PostToolUseFailure` | `error.wav` — *"Are maalik wo thoda sa galti ho gayi"* | A tool call failed | 3.10s |
| `UserPromptSubmit` | `praise.wav` — *owww* | You praised Claude | — |

The voice clips are memes: *"is this any way to beg?"* when Claude wants permission,
*"where are you?"* when you've wandered off, *"sorry boss, small mistake happened"* when
something breaks, and an *owww* when you say something nice.

**Four of the five need no decision** — the event firing *is* the meaning. `praise` is
the exception and the only place dhun contains logic worth reviewing; see
[Praise detection](#praise-detection).

## Install

```sh
./install.sh              # into the active config dir ($CLAUDE_CONFIG_DIR, else ~/.claude)
./install.sh --all        # into every config dir found
./install.sh --dir PATH   # into a specific one
./install.sh --uninstall  # remove dhun hooks, leave all others untouched
```

Then **restart Claude Code** — hooks are read once at session start, so a running
session keeps the old config.

The installer copies `sounds/` and `hooks/` into `<config>/dhun/`, so an install is
self-contained and survives this project folder moving or being deleted. It backs up
`settings.json` to `settings.json.dhun-backup`, merges rather than overwrites (your
existing hooks are preserved), and is idempotent — re-running replaces dhun's entries
instead of duplicating them.

## Layout

```
dhun/                           ← this folder IS the skill; copy it to <config>/skills/dhun/
├── SKILL.md                    # the /dhun skill: routing + instructions
├── DEMO.md                     # post-install demo sequence to run on a teammate
├── CLAUDE.md                   # this file
├── install.sh                  # merge/remove hooks (macOS/Linux/Git Bash)
├── install.ps1                 # same, for Windows without Git Bash
├── hooks/
│   ├── dhun-play.sh            # cross-platform player: <name> [volume]; honours mute
│   ├── dhun-play.ps1           # Windows player; same mute contract
│   ├── dhun-praise.sh          # UserPromptSubmit: decides whether a prompt is praise
│   ├── dhun-praise.ps1         # the same decision on Windows; keep the two in step
│   └── dhunctl.sh              # test / pause / resume / status / doctor / why
└── sounds/
    ├── wav/  done · attention · permission · error · praise   ← canonical
    ├── mp3/  done · attention · permission · error · praise   ← convenience copies
    └── candidates/  unwired alternates (hukum.wav)
```

**Two directories, don't confuse them.** The project folder is the *source*. Installing
copies `sounds/` and `hooks/` into `<config>/dhun/`, and that installed copy is what the
hooks run and where mute flags live. Editing a sound in the source has no effect until
you re-run `install.sh`.

## Pause / resume

Mute is a flag file, checked in one place inside `dhun-play.sh`. That means it applies
instantly with no session restart, persists across restarts, and leaves the hooks
installed.

```sh
dhunctl.sh pause                 # all sounds, indefinitely
dhunctl.sh pause 1h              # auto-resumes after an hour
dhunctl.sh pause error           # just the failure sound
dhunctl.sh pause 30m attention   # one event, timed
dhunctl.sh resume [event|all]
dhunctl.sh status                # what's on, what's paused, when it resumes
dhunctl.sh why "nice one"        # would this phrase fire the praise sound?
```

An empty flag file means indefinite; a file containing an epoch timestamp means paused
until then, and it deletes itself on expiry.

## Why WAV is canonical

WAV is the only format that plays on all three OSes with no dependencies:

| OS | Player | Formats |
|---|---|---|
| macOS | `afplay` | wav, aiff, mp3, m4a, caf |
| Linux | `paplay` / `aplay` / `ffplay` / `mpv` | wav always; others vary |
| Windows | PowerShell `Media.SoundPlayer` | **WAV only** |

Windows is the constraint — `SoundPlayer` refuses anything but WAV and has no volume
control. The MP3 copies exist for size (~35KB vs ~500KB) and for pasting into Slack or
a phone; the hooks never use them.

All voice clips are normalized to **−16 LUFS** with −1.5 dBTP ceiling, so they sit at
equal loudness. Volume is then set per-hook via the play script's second argument
(default `0.75`).

## Where this actually works

Three independent conditions must all hold:

1. **The hook fires** — the real Claude Code CLI is running, not a cloud sandbox
2. **It finds the hooks** — the process reads the config dir they're installed in
3. **The sound reaches you** — the process is on the same machine as your speakers

| Context | Works | Note |
|---|:--:|---|
| Terminal / Warp / iTerm2 | ✅ | |
| VS Code, JetBrains, desktop app | ✅ | Same machine, same config dir |
| Conductor | ✅ | Runs the local CLI *(reasoned from architecture, not tested)* |
| Linux | ✅ | Verified in CI on `ubuntu-latest`, both JSON backends |
| Windows (with or without Git Bash) | ✅ | Verified in CI on PowerShell 5.1 **and** 7 |
| WSL | ⚠️ | Routes to the Windows host player; untested |
| SSH / dev container | ❌ | Hook runs on the remote box — no audio path back |
| claude.ai/code (web) | ❌ | Cloud sandbox, no speakers |
| Scheduled/cloud agents, CI | ❌ | Headless |

The ❌ rows are a boundary, not a bug: hooks execute wherever the Claude process
lives. Nothing can route that audio back to you.

**Config-dir gotcha.** If `CLAUDE_CONFIG_DIR` is set via a shell *alias* rather than
exported, only terminal sessions using that alias see the hooks — VS Code and the
desktop app launch `claude` directly and read `~/.claude`. Use `--all` to cover both.

### Cross-platform design

**Windows never depends on Git Bash.** Claude Code runs hook commands via *"bash, or
powershell on Windows when Git Bash isn't installed"* — and PowerShell cannot execute
`.sh`. So on Windows the installer wires the **`.ps1` hooks** with `powershell.exe`,
regardless of which installer ran. `install.ps1` exists for boxes that can't run
`install.sh` at all.

**No dependency is hard.** JSON handling degrades in this order:

| Component | Preferred | Fallback |
|---|---|---|
| `install.sh` | `jq` | `python3` (errors only if neither exists) |
| `install.ps1` | `ConvertFrom-Json` — built into PowerShell | none needed |

The hooks themselves parse nothing at all, so at runtime dhun has **no dependencies**.

`Media.SoundPlayer` has no gain control, so **volume is ignored on Windows** — the
argument is accepted and discarded. It's also WAV-only, which is why `wav/` is
canonical.

### CI

`.github/workflows/test.yml` runs the whole install lifecycle on real runners:

| Job | Matrix | Covers |
|---|---|---|
| `posix` | ubuntu-latest × macos-latest × (jq, python3) | both JSON backends must agree |
| `windows` | powershell (5.1) × pwsh (7) | 5.1 is what teammates actually have |

Asserted on every push: scripts parse, `settings.json` merges without eating foreign
hooks, install is idempotent, uninstall is clean, timed mute self-expires, and the error
hook fires on failures while staying silent on success and on malformed payloads.

**All six combinations pass.** Repo: <https://github.com/niravbhatt1317/dhun> (private).

**`DHUN_DRY_RUN`** is the seam that makes this possible — set it to a file path and the
player logs `PLAYED <name>` instead of playing, so CI can assert *which* sound would
fire on a runner with no sound device. It sits **after** the mute checks deliberately,
so mute behaviour is exercised for real rather than stubbed around.

### What "tested" means here — three levels

| Level | Question | How |
|---|---|---|
| **Decision** | Did dhun decide to play, and which sound? | `DHUN_DRY_RUN` log |
| **Invocation** | Was the audio backend actually called, with the right file? | A fake `afplay`/`paplay` is put on `PATH` and asserted against. On Windows, `SoundPlayer.Load()` parses the WAV header without hardware |
| **Audible** | Did a human hear it? | **Not testable in CI.** Needs a real machine |

Level 2 matters because `DHUN_DRY_RUN` short-circuits *before* the playback branch —
without the shim, OS detection and player selection would never execute in CI and a
typo in `play_linux` would pass unnoticed.

### Still untested

**Audio has only been *heard* on macOS.** CI proves the logic runs correctly on Linux
and Windows; it cannot prove a sound is audible, because runners have no sound device.
Two narrow unknowns remain:

- Does `Media.SoundPlayer` actually produce sound on real Windows hardware?
- Does a given Linux desktop have one of `paplay`/`aplay`/`ffplay`/`mpv` installed?

Both are five-second checks once someone has the hardware. WSL is also unverified.

### Encoding rule for `.ps1` files

**Keep every `.ps1` pure ASCII.** PowerShell 5.1 — which is what Windows ships and what
teammates will actually run — reads `.ps1` as Windows-1252 unless the file has a BOM.
A UTF-8 em dash becomes `â€"` and breaks the enclosing string, and CI caught exactly
that: `install.ps1` failed to parse at all. No em dashes, curly quotes, or ellipses in
PowerShell sources, comments included.

### Lessons from the first CI runs

Three of the four failures were in the *test harness*, not the product. Worth knowing
before editing the workflow:

- `jq` cannot be hidden on macOS runners — `/usr/bin/jq` sits on a read-only
  filesystem. Use the `DHUN_JSON` seam to pin the backend instead.
- `Media.SoundPlayer` needs no `Add-Type` on 5.1 and is not reachable that way on 7.
  Validate the RIFF/WAVE header directly, then use `Load()` only when the type exists.
- Piping a string to a `.ps1` **inside** PowerShell feeds the pipeline, not stdin, so
  `[Console]::In.ReadToEnd()` reads nothing. The hook must be spawned as a real process
  (`powershell.exe -File`) — which is how Claude Code invokes it anyway.

## Notification is split by type

`Notification` supports a `matcher` on the notification **type**, so "blocked on your
decision" and "you walked away" get different sounds. An unmatched entry would fire on
every type — including alongside the matched ones — so dhun installs matchers only.

Documented types: `permission_prompt`, `idle_prompt`, `auth_success`,
`elicitation_dialog`, `elicitation_complete`, `elicitation_response`,
`agent_needs_input`, `agent_completed`.

### All eight types, and what dhun does with each

| Type | Fires when | dhun sound |
|---|---|---|
| `permission_prompt` | Claude needs approval | *unused* — `PermissionRequest` fires sooner |
| `elicitation_dialog` | An MCP server pauses to ask you something | *unused* — `Elicitation` fires sooner |
| `agent_needs_input` | A subagent needs input | `permission.wav` — no first-class equivalent |
| `idle_prompt` | You've been idle ~60s with Claude waiting | `attention.wav` |
| `agent_completed` | A subagent finished | *silent* — a completion, not a block |
| `auth_success` | Authentication succeeded | *silent* |
| `elicitation_complete` | The elicitation exchange finished | *silent* |
| `elicitation_response` | You answered an elicitation | *silent* |

**The rule:** every "blocked on you" state gets `permission.wav` — Claude asking
permission, an MCP server prompting mid-call, or a subagent needing input. Same
situation from your side: work has stopped until you respond.

**Prefer the first-class event over the `Notification` equivalent.** `Notification`
dispatch lags by seconds — measured here at **6s** between `PermissionRequest` (19:06:06)
and `Notification`→`permission_prompt` (19:06:12), and reported as much worse by others.
It is a known upstream issue: [#19627](https://github.com/anthropics/claude-code/issues/19627)
(hook invocation latency) and [#23383](https://github.com/anthropics/claude-code/issues/23383)
(*"Notification hook has noticeable delay compared to Stop hook"*).

So dhun wires `PermissionRequest` and `Elicitation` directly, and **must not** also wire
`permission_prompt` or `elicitation_dialog` — that would play the same clip twice,
seconds apart. CI asserts this.

`idle_prompt` stays on `Notification` because it has no first-class equivalent, and its
~60s delay is intentional rather than latency ([#13922](https://github.com/anthropics/claude-code/issues/13922),
[#32634](https://github.com/anthropics/claude-code/issues/32634)).

The rest are deliberately silent. `elicitation_response` and `elicitation_complete`
fire *after* you've already acted, so a sound would only confirm what you just did.
`agent_completed` is a completion — the obvious candidate if you later want it on the
`Stop` chime. Mapping every type would put us back where an unmatched entry was, firing
constantly and meaning nothing.

### Elicitation, briefly

"Elicitation" is an MCP concept: a server running a tool can pause and request input
from you before continuing — a confirmation, a missing value, a choice. The three
`elicitation_*` types are one such exchange's lifecycle: dialog appears → you respond →
exchange completes. Claude Code also exposes dedicated `Elicitation` and
`ElicitationResult` hook *events* if you ever need the payload rather than just a sound.

Note this is **not** the AskUserQuestion picker, which is a built-in tool, not MCP.
Which type that fires is still unverified.

### Real situations — what you actually hear

| What happens | Sound |
|---|---|
| "What is 2+2?" → Claude answers | 🔔 chime |
| Claude ends with **"want me to do X next?"** | 🔔 chime *only* — this is `Stop`, not a notification |
| Claude asks to run `rm file.txt` → you must approve | 🎙️ *bheek mangne ka* |
| …you approve, it runs, turn ends | 🔔 chime |
| Claude asks to edit a file → approval needed | 🎙️ *bheek mangne ka* |
| A subagent needs input | 🎙️ *bheek mangne ka* |
| An MCP server pauses to ask you something | 🎙️ *bheek mangne ka* |
| **You walk away** — 60s idle | 🎙️ *Kuchu puchu* |
| Tool fails (missing file, bad command) | 🎙️ *Are maalik*, then 🔔 |
| Tool succeeds | silence, then 🔔 |
| A subagent completes | silence |
| Claude is thinking / running a long command | silence |

Key distinction: **`Stop` = Claude finished talking. `Notification` = Claude is blocked
and cannot continue.** A turn that *ends* with "want me to do X next?" is `Stop`, not a
notification — the question is just text, and you're free to walk away.

**Watch the frequency.** With a thin allowlist, `permission_prompt` fires on nearly
every tool call, and any voice clip there becomes noise — the same trap that keeps
`Stop` a chime. Thinning the allowlist (allowing common read-only commands) is the real
fix; it also makes the sound *mean* something, since it then only fires on genuine
decisions.

Unverified: which type fires for the **AskUserQuestion** tool. Not `elicitation_dialog`
— that's MCP-only. Needs a live test rather than a guess.

`sounds/candidates/` holds clips that aren't wired to anything —
`hukum.wav` (*"Jo hukum mere aaka"*, 1.60s) is the alternate permission sound.

## Praise detection

`UserPromptSubmit` fires the moment the user presses enter — **before Claude receives
the message**. The decision is therefore made entirely in `dhun-praise.sh` /
`dhun-praise.ps1`; the model is not consulted and cannot be. That is what makes the
feature possible at all: "did the user praise Claude" is answered by pattern matching on
the prompt, not by asking Claude how it felt.

### Four steps, in this order

| Step | Does | Exists because |
|---|---|---|
| 1. Hard negatives | `no thanks`, `thanks but`, `not great`, `doesn't work` → silent | They are *built from* praise words, so they must outrank the strong tier |
| 2. Strong tier | `thanks`, `great work`, `well done`, `shabash`, `kya baat`, 🎉 → play | Unambiguous, so it can fire mid-sentence: *"thanks! now refactor auth"* counts |
| 3. Request guard | `make it nicer`, `is this good?`, `update the …` → silent | Instructions routinely contain praise words |
| 4. Weak tier | `perfect`, `nice`, `clean` as a lead clause of ≤ 3 words → play | Bare adjectives are praise as interjections and instructions otherwise |

The guard in step 3 applies **only** to the weak tier. Putting it first would have
killed *"thanks, can you also…"*, which is praise plus a request.

**Word count, not character count, is what makes step 4 work.** The first version
gated on length (≤ 60 chars) and fired on *"update the nice-dashboard project"* — 33
characters. The giveaway is not that praise is short but that it arrives as an
interjection: one to three words, then a break.

**A one-word lead skips the request guard.** Otherwise `clean` — which is both a weak
praise word and a verb in the guard list — could never fire. An instruction needs an
object, so a bare single word cannot be one.

### Three constraints specific to this hook

- **Never write to stdout.** `UserPromptSubmit` is the only event whose hook output is
  fed back into the model as `hookSpecificOutput.additionalContext`. A stray `echo`
  becomes text in the conversation. Asserted in CI.
- **Never put `&` on the hook command.** Every other dhun hook backgrounds itself in
  `settings.json`; this one must not, because it reads the payload from stdin and
  backgrounding detaches it from that stdin. It backgrounds the *playback* internally.
  Asserted in CI.
- **Never match the raw payload.** It also carries `cwd`, `session_id` and
  `transcript_path`. Grepping the blob means a project folder named `nice-dashboard`
  fires the sound on **every prompt, forever** — and it would look like a detector bug,
  not a payload bug. The `prompt` field is extracted first, and a payload that somehow
  lacks that field goes silent rather than falling back to the blob. Both asserted.

`DHUN_DRY_RUN` makes `play()` synchronous. There is no audio to wait for in dry-run
mode, and detaching would make the decision unobservable — the caller can exit before
the child appends its line. That is why the CI praise assertions need no `sleep`.

### Tuning

`DHUN_PRAISE_MAXWORDS` (3) is the real knob; `DHUN_PRAISE_MAXLEN` (40) is a secondary
guard; `DHUN_VOLUME_PRAISE` sets volume. Phrases live in the `STRONG` and `WEAK` lists
in **both** `dhun-praise.sh` and `dhun-praise.ps1` — they must stay in step, and nothing
enforces that but the CI cases, which run the same phrase table against both.

`dhunctl.sh why "some phrase"` answers "would this fire?" without a restart. Use it
instead of reasoning about the regexes.

### Known limitation: sarcasm

*"great, it broke again"* fires. So does *"perfect, now nothing works"*. Detecting this
needs sentiment analysis, not pattern matching, and a blunt fix — suppressing anything
containing failure vocabulary — would break *"thanks, that fixed the bug"*, which is
real praise. Left deliberately unsolved; `pause praise` is the escape hatch.

Related: praise aimed at something other than Claude (*"tailwind is great"*) also
fires. Same reason, and much rarer.

## Design decisions

**Use `PostToolUseFailure`, never `PostToolUse`.** They are different events:
`PostToolUse` fires only when a tool call **succeeds**; `PostToolUseFailure` fires when
it **fails**. dhun originally wired `PostToolUse` and parsed the payload looking for
failure signals — which could never work, because the hook was not invoked at all on
failure. Verified empirically: a `ls /nonexistent` (exit 1) produced no `PostToolUse`
event, while `echo hi` did.

Because `PostToolUseFailure` fires *only* on failure, **there is nothing to detect**.
The hook plays the sound directly. That removed an entire script, the `jq` dependency
in the error path, a POSIX pattern-matching fallback, and the false-positive risk where
a tool whose *output* contained `"is_error":true` would have triggered a sound.

Its payload is a plain string, e.g. `"Exit code 1\nls: ...: No such file or directory"`
— no structure to parse even if we wanted to.

**Both scripts always `exit 0`.** A missing audio player or a jq parse failure must
never block a tool call.

**`Stop` is a chime, not speech, by design.** It fires on every single turn — dozens of
times an hour. Speech clips are funny at ten repetitions and unbearable at fifty. The
voice memes are on `Notification` and `PostToolUse` precisely because those fire
rarely, which is what keeps the joke working.

**Volume note:** `afplay -v` only attenuates. To make something louder than its file
level, re-normalize the file — raising the flag past 1.0 does nothing.

## Known limitations

- Long clips can overlap if events fire in quick succession; each plays detached.
- `error.wav` at 3.1s is long for a per-failure sound. A tighter trim to just
  *"thoda sa galti ho gayi"* (~1.5s) is the obvious fix if it wears thin.
- `done.wav` is derived from Apple's `Glass.aiff` (a macOS system asset). Fine for
  internal use; replace it with an original or royalty-free chime before publishing
  this anywhere public.
- `praise.wav` came from <https://soundinstants.com/sound/aww>, licence unverified —
  the page is behind a Cloudflare challenge and was never read. Shipped knowingly on
  the same basis as the meme clips: acceptable for an internal notification sound,
  and the fix if it is ever challenged is a neutral chime in the public plugin with
  the real clip as a local overlay. Do not assume it is cleared for reuse elsewhere.

## Changing sounds

Drop a WAV into `sounds/wav/` using the same name and re-run `install.sh`. To change a
volume, edit the number in the `settings.json` hook command (`... done 0.75 &`), or set
`DHUN_VOLUME_ERROR` for the error hook.

To rebuild a clip from a source video:

```sh
yt-dlp -x --audio-format wav -o raw.wav "URL"
ffmpeg -i raw.wav -af silencedetect=noise=-30dB:d=0.25 -f null -   # find segments
ffmpeg -ss START -t LEN -i raw.wav \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=0.04,afade=t=out:st=END:d=0.16" \
  -ar 44100 -ac 2 -c:a pcm_s16le sounds/wav/NAME.wav
```

## Status

**Shipped.** dhun is live in the team marketplace alongside `publish`, `tata` and
`tatago`. Teammates install with `/plugin install dhun` → user scope → restart.

| | |
|---|---|
| Version | 0.2.0 — adds the praise sound on `UserPromptSubmit` |
| CI | ubuntu × macos × (jq, python3), plus Windows on PowerShell 5.1 and 7 |
| Verified by ear | macOS only — runners have no sound device |
| Install target | user scope, so every project and surface on the machine |

**This folder is the shipping copy.** The development history lives in the archived
standalone repo (`niravbhatt1317/dhun`); changes to dhun happen here.

**Decided: bundle the WAVs rather than fetching them.** The other three plugins are
pure instruction files; dhun ships ~2 MB of audio, cloned by everyone on
`marketplace add`. A one-time clone beats adding a network fetch and its failure modes
to an install that otherwise has zero dependencies. Do not "optimise" this into a
release-download step without a reason.

**The public-repo trade-off was accepted knowingly:** the team repo is public, so the
meme audio is published under Nirav's name. Judged fine for an internal notification
sound. If it ever needs undoing, the fix is neutral chimes in the public plugin with
the memes as a private overlay.
