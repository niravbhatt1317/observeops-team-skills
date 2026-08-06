#!/bin/sh
# dhun -- play a sound when the user's prompt is praise.
#
#   Wired to UserPromptSubmit, which fires the moment you press enter -- before Claude
#   has seen the message at all. This script reads the hook payload on stdin, decides,
#   and hands off to dhun-play.sh. Claude is not involved in the decision.
#
# Three rules specific to this event, each easy to get wrong:
#
#   * Never write to stdout. UserPromptSubmit is the one event whose output is fed
#     back into the model (hookSpecificOutput.additionalContext), so a stray echo
#     becomes text in the conversation. Every diagnostic here goes to stderr.
#   * Read stdin synchronously; background only the playback. A trailing `&` on the
#     hook command would detach this process from the payload it still has to read.
#   * Never grep the raw payload. It also carries cwd, session_id and transcript_path,
#     so a project folder named "nice-dashboard" would fire the sound on every single
#     prompt, forever. The prompt field is extracted first.
#
# Always exits 0: a sound must never block a prompt from being submitted.

set -u

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0

# How long a leading clause may be and still count as a reaction rather than an
# instruction. "perfect!" is praise; "make the header perfect and ..." is a task.
#
# Word count does the real work here. A character limit alone lets "update the
# nice-dashboard project" (33 chars) through, because the giveaway is not length but
# that praise arrives as an interjection: one to three words, then a break.
MAXWORDS=${DHUN_PRAISE_MAXWORDS:-3}
MAXLEN=${DHUN_PRAISE_MAXLEN:-40}

# If the payload has no prompt field, stdin is treated as the prompt itself. That seam
# is what lets CI and `dhunctl praise-check` feed plain strings instead of fake JSON.
PROMPT=$(awk '
  { buf = buf $0 "\n" }
  END {
    i = index(buf, "\"prompt\"")
    if (i == 0) {
      # Plain-string mode, for CI and `dhunctl why`. Refused for anything that looks
      # like JSON: a payload that lost its prompt field must go silent rather than
      # fall back to matching cwd and transcript_path.
      sub(/^[[:space:]]+/, "", buf)
      if (substr(buf, 1, 1) == "{") exit
      printf "%s", buf; exit
    }
    s = substr(buf, i + 8)
    q = index(s, "\"")                              # opening quote of the value
    if (q == 0) exit
    s = substr(s, q + 1)

    # Walk quote to quote rather than character to character: JSON strings have few
    # quotes and many characters, and the per-character version is quadratic.
    pos = 0
    while (1) {
      q = index(substr(s, pos + 1), "\"")
      if (q == 0) { out = s; break }
      q = pos + q
      bs = 0; j = q - 1
      while (j >= 1 && substr(s, j, 1) == "\\") { bs++; j-- }
      if (bs % 2 == 0) { out = substr(s, 1, q - 1); break }
      pos = q                                       # escaped quote, keep going
    }
    gsub(/\\[nrt]/, "\n", out)
    gsub(/\\"/, "\"", out)
    gsub(/\\\\/, "\\", out)
    printf "%s", out
  }')

[ -n "$PROMPT" ] || exit 0

LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# The leading clause: everything up to the first sentence break. Praise that leads a
# message is a reaction to the last turn; the same word buried mid-sentence is almost
# always part of an instruction.
LEAD=$(printf '%s' "$LOWER" | tr '\n' '.' | cut -d'.' -f1 | cut -d',' -f1 \
       | cut -d'!' -f1 | cut -d'?' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

play() {
  # Backgrounded so a 2s clip never delays prompt submission. stdout is closed on
  # purpose -- see the header note about additionalContext.
  #
  # Under DHUN_DRY_RUN there is no audio to wait for, and detaching would make the
  # decision unobservable: the caller can exit before the child appends its line.
  # Running synchronously there keeps CI deterministic without a sleep.
  if [ -n "${DHUN_DRY_RUN:-}" ]; then
    "$DIR/dhun-play.sh" praise "${DHUN_VOLUME_PRAISE:-0.75}" >/dev/null 2>&1
  else
    "$DIR/dhun-play.sh" praise "${DHUN_VOLUME_PRAISE:-0.75}" >/dev/null 2>&1 &
  fi
  exit 0
}

# --- 1. hard negatives -------------------------------------------------------
# Explicit anti-praise. These outrank everything, including the strong tier, because
# they are built out of praise words: "no thanks" and "not great" both match below.
if printf '%s' "$LOWER" | grep -qE \
  "(^|[^a-z])(no|nope|nah)[[:space:],]+(thank|thanks|thanku|thx|ty)|\
(thanks|thank you|thx|ty)[^a-z]{0,3}(but|however|though|except|still|unfortunately)|\
(not|isn.?t|aren.?t|does ?n.?t|did ?n.?t|do ?n.?t|was ?n.?t|wo ?n.?t|ca ?n.?t|hardly|barely)[[:space:]]+\
(really[[:space:]]+)?(that[[:space:]]+|very[[:space:]]+|so[[:space:]]+|quite[[:space:]]+)?\
(great|good|nice|perfect|awesome|amazing|right|correct|clean|work|works|working|worked|it|the best)"
then
  exit 0
fi

# --- 2. strong tier: fires anywhere in the message ---------------------------
# Unambiguous praise. Safe mid-sentence, so "thanks! now refactor the auth module"
# still counts. -w keeps "thanks" out of "thanksgiving" and "love it" out of "glove it".
STRONG="thank(s| ?you| ?u)|thanx|thnx|thx|tysm|tqsm|ty|tq\
|dhanyaw?ad|dhanyavaad|shukriya\
|(good|great|nice|awesome|amazing|excellent|brilliant|fantastic|solid|clean) (job|work|catch|stuff|one|find)\
|well done|nailed it|crushed it|killed it|smashed it|aced it|knocked it out\
|spot on|bang on|on point\
|love (it|this|that)|loving (it|this)\
|you.?re (the best|a legend|a star|amazing|awesome|great|brilliant|the goat)\
|chef.?s kiss\
|(what a|you.?re a|absolute) legend\
|shabash|shaabash|shabaash\
|wah wah|waah|wah bhai|wah yaar|wah re\
|kya baat\
|zabardast|jhakaas|jhakas|kamaal|gazab|ghazab\
|(bohot|bahut|bht|ekdum) (badhiya|badiya|accha|acha|sahi|mast)\
|bilkul sahi|sahi hai|mast hai|ekdum mast\
|works? perfectly|worked perfectly|working perfectly\
|exactly what i (wanted|needed|was looking for)\
|that.?s exactly it\
|(really|very|so|super|damn|bloody|pretty) (nice|clean|good|great|slick|neat|elegant|smart)"

printf '%s' "$LOWER" | grep -qEw "$STRONG" && play

# Emoji are matched literally: they are not word characters, so -w cannot be used.
printf '%s' "$PROMPT" | grep -qF -e '🎉' -e '🙌' -e '👏' -e '🔥' -e '💯' \
                                 -e '👌' -e '😍' -e '🥳' -e '✨' -e '🚀' && play

# --- 3. request shape gates the weak tier ------------------------------------
# "make it nicer" and "is this good?" are not praise. This guard applies only to the
# weak tier -- the strong tier already passed, so "thanks, can you also..." is safe.
WORDS=$(printf '%s' "$LEAD" | wc -w | tr -d '[:space:]')

# A bare one-word lead is skipped: an instruction needs an object, so "clean up the
# imports" is a request while "clean" on its own can only be a reaction. Without this,
# the verb list below swallows every weak word that is also a verb.
if [ "$WORDS" -gt 1 ] && printf '%s' "$LEAD" | grep -qE \
  "^(can|could|would|will|shall|please|pls|make|write|add|use|keep|try|give|show|let|do|does|is|are|was|should|need|want|i need|i want|we need|lets|let.s|now|also|next|then|clean|polish|tidy|refactor|fix|improve|update|run|build|create|check|test|implement|install|deploy|commit|push|pull|merge|revert|undo|remove|delete|move|rename|bump|sync|set|change|switch|replace|rewrite|document|explain|generate|open|close|start|stop|apply|convert|extract|split|handle|support|enable|disable|review|look|find|search|tell|help|why|what|how|where|when|which|who)([^a-z]|$)|\
(please|make it|make this|needs? to be|should be|has to be|want it|want this)"
then
  exit 0
fi
case "$PROMPT" in *\?) exit 0 ;; esac     # "nice?" is a question, not praise

# --- 4. weak tier: only as a short leading reaction --------------------------
# Single adjectives that double as instructions. Gated on the leading clause being
# an interjection -- first, and no more than a few words -- which is what separates
# "perfect!" from "make the header perfect and add a hover state".
[ "$WORDS" -le "$MAXWORDS" ] || exit 0
[ "${#LEAD}" -le "$MAXLEN" ] || exit 0

WEAK="perfect|great|awesome|amazing|excellent|brilliant|superb|fantastic|wonderful\
|beautiful|lovely|gorgeous|elegant|slick|neat|solid|clean|nice|noice|niice|cool|sweet\
|dope|epic|clutch|goated|banger\
|yay|yaay|woohoo|woot|nailed\
|mast|badhiya|badiya|badhia|sahi|sundar|accha|acha|bindaas\
|yes+|yep|yup|yess+|w"

printf '%s' "$LEAD" | grep -qEw "$WEAK" && play

exit 0
