# dhun — the demo

Run these in a **fresh Claude Code session** after installing. Restart first, or you'll
hear nothing and think it's broken.

Turn your volume up. One prompt at a time.

---

## 0. Warm-up — hear all five at once

```
/dhun test
```

Plays every sound directly, no hooks involved. If this is silent, the problem is
audio, not Claude. If it works, the sounds are fine and everything below is about
whether the hooks fire.

---

## 1. The finish chime 🔔

```
What is 2 + 2?
```

Claude answers instantly and the turn ends → **chime**.

You'll now hear this after every single reply. That's the point: you can look away,
and you'll know the moment it's done.

---

## 2. The mistake sound 🎙️

```
Run this command: ls /definitely-not-a-real-directory-xyz
```

The command exits non-zero → **"Are maalik wo thoda sa galti ho gayi"**
*("Oh boss, a small mistake happened.")*

Then the chime, because the turn also ends. Failure and completion are different
events, so you hear both.

> Use a **shell command that exits non-zero**, not "read a missing file". Asking
> Claude to read a nonexistent file just gets you a calm "that file doesn't exist"
> — it reads as a conversation, not a failure, which makes for a flat demo.

Another one, if you want to be sure it wasn't a fluke:

```
Run this command: cat /etc/definitely-not-here.conf
```

---

## 3. The "may I?" sound 🎙️

```
can you ask me some options in the chat to select anything
```

Claude shows you a multiple-choice picker and waits → **"Ye koi tareeka hai bheek
mangne ka?"** *("Is this any way to beg?")* — Claude, indignant, needing you.

This is the most reliable trigger, because Claude genuinely cannot continue until
you pick something.

> Permission sounds fire on `PermissionRequest`, which is immediate. The
> `Notification` route lags several seconds, so dhun deliberately avoids it.

A permission prompt works too, if the command isn't already allowlisted:

```
Run this command: ls -la ~/Downloads
```

> Won't fire if you've allowlisted it, or in bypass-permissions mode — Claude
> never has to ask, so there's nothing to notify about.

---

## 3b. The "where are you?" sound 🎙️

```
Now walk away. Don't type anything for a minute.
```

After ~60s idle → **"Kuchu puchu tum kaha ho"** *("Kuchu puchu, where are you?")*

This is the one worth understanding: **permission and idle are different sounds**,
because they're different problems. One means *decide something*; the other means
*come back*. Same hook event, split by notification type.

---

## 3c. The praise sound 🎙️

```
thanks, that's perfect
```

Fires the *instant you press enter* — before Claude has read a word of it. This is the
one sound that comes from you rather than from Claude.

Then show the discrimination, which is the actually impressive part:

```
make the header perfect
```

Silence. Same word, no sound: praise is an interjection, an instruction is not. Two
more if the room is interested — `no thanks` (silent) and `perfect!` (fires).

To check any phrase without typing it as a real prompt:

```
/dhun why "kya baat hai"
```

---

## 4. Errors are *only* errors

```
Run this command: echo "this works fine"
```

Silence — then the finish chime. No error sound.

This is the bit worth appreciating: Claude Code has a dedicated `PostToolUseFailure`
event, separate from `PostToolUse` (which fires on success). So the failure sound is
wired to failures at the source — you are not hearing a sound per tool call, and
nothing is guessing at what "failed" means.

---

## 5. It works from anywhere

```
cd ~/any-other-project
```

Start Claude there. Same sounds. The hooks are installed user-level, so they apply to
every project and every directory on this machine.

Then open **VS Code** and try prompt #1 again. Same chime — the extension reads the
same config.

---

## 6. Silence it when you need to

```
/dhun pause error
```

Now re-run prompt #2. The tool still fails, but no meme — just the chime. Useful when
you're deep in a debugging session and failures are constant.

```
/dhun pause 30m
```

Everything goes quiet for half an hour, then comes back by itself. Good before a
meeting or a screen share.

```
/dhun status
```

Shows exactly what's on, what's paused, and when it resumes.

```
/dhun resume
```

Everything's back. **No restart needed for any of these** — mute is a flag file, so it
takes effect immediately.

---

## If you hear nothing

```
/dhun doctor
```

In order of likelihood:

1. **You didn't restart Claude Code** — hooks load at session start
2. **Wrong config dir** — if `CLAUDE_CONFIG_DIR` is set by a shell *alias*, VS Code
   and the desktop app won't see the hooks. Run `/dhun install --all`
3. **It's muted** — `/dhun status`
4. **You're on SSH, a dev container, or claude.ai/code** — hooks run where the Claude
   process lives. There's no audio path back to your machine. Not fixable
5. **Linux with no audio player** — install `pulseaudio-utils` or `ffmpeg`
