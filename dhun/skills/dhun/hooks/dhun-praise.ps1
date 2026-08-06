# dhun -- play a sound when the user's prompt is praise (Windows).
#
#   Wired to UserPromptSubmit, which fires the moment you press enter, before Claude
#   has seen the message. Mirrors dhun-praise.sh exactly; see that file for why each
#   tier exists. Keep the two in step.
#
# Three rules specific to this event:
#
#   * Never write to stdout. UserPromptSubmit output is fed back into the model as
#     additionalContext, so a stray Write-Host becomes text in the conversation.
#   * This must be spawned as a real process (powershell.exe -File), which is how
#     Claude Code invokes hooks. Piping a string to a .ps1 from inside PowerShell
#     feeds the pipeline rather than stdin, and ReadToEnd() then returns nothing.
#   * Never match against the raw payload. It carries cwd and transcript_path too, so
#     a folder named "nice-dashboard" would fire the sound on every prompt.
#
# ASCII ONLY. PowerShell 5.1 reads .ps1 as Windows-1252 without a BOM, so a single
# non-ASCII character breaks the enclosing string. Emoji are built from codepoints
# below for exactly this reason. Always exits 0.

$ErrorActionPreference = "SilentlyContinue"

$dir = $PSScriptRoot

$maxWords = if ($env:DHUN_PRAISE_MAXWORDS) { [int]$env:DHUN_PRAISE_MAXWORDS } else { 3 }
$maxLen   = if ($env:DHUN_PRAISE_MAXLEN)   { [int]$env:DHUN_PRAISE_MAXLEN }   else { 40 }

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

# If the payload has no prompt field, stdin is treated as the prompt itself. That seam
# lets CI feed plain strings instead of hand-built JSON.
$prompt = $null
try { $prompt = ($raw | ConvertFrom-Json).prompt } catch { }
if ($null -eq $prompt) { $prompt = $raw }
$prompt = "$prompt"
if (-not $prompt.Trim()) { exit 0 }

$lower = $prompt.ToLowerInvariant()

# The leading clause: everything up to the first sentence break.
$lead = ($lower -split '[\r\n,.!?]', 2)[0].Trim()
$words = @($lead -split '\s+' | Where-Object { $_ }).Count

function Invoke-Praise {
  $vol = if ($env:DHUN_VOLUME_PRAISE) { $env:DHUN_VOLUME_PRAISE } else { "0.75" }
  & (Join-Path $dir "dhun-play.ps1") "praise" $vol | Out-Null
  exit 0
}

# --- 1. hard negatives -------------------------------------------------------
# Built out of praise words, so these have to outrank the strong tier.
$negative = '(^|[^a-z])(no|nope|nah)[\s,]+(thank|thanks|thanku|thx|ty)' +
            '|(thanks|thank you|thx|ty)[^a-z]{0,3}(but|however|though|except|still|unfortunately)' +
            '|(not|isn.?t|aren.?t|does ?n.?t|did ?n.?t|do ?n.?t|was ?n.?t|wo ?n.?t|ca ?n.?t|hardly|barely)\s+' +
            '(really\s+)?(that\s+|very\s+|so\s+|quite\s+)?' +
            '(great|good|nice|perfect|awesome|amazing|right|correct|clean|work|works|working|worked|it|the best)'
if ($lower -match $negative) { exit 0 }

# --- 2. strong tier: fires anywhere in the message ---------------------------
$strong = '\b(thank(s| ?you| ?u)|thanx|thnx|thx|tysm|tqsm|ty|tq' +
          '|dhanyaw?ad|dhanyavaad|shukriya' +
          '|(good|great|nice|awesome|amazing|excellent|brilliant|fantastic|solid|clean) (job|work|catch|stuff|one|find)' +
          '|well done|nailed it|crushed it|killed it|smashed it|aced it|knocked it out' +
          '|spot on|bang on|on point' +
          '|love (it|this|that)|loving (it|this)' +
          '|you.?re (the best|a legend|a star|amazing|awesome|great|brilliant|the goat)' +
          '|chef.?s kiss' +
          '|(what a|you.?re a|absolute) legend' +
          '|shabash|shaabash|shabaash' +
          '|wah wah|waah|wah bhai|wah yaar|wah re' +
          '|kya baat' +
          '|zabardast|jhakaas|jhakas|kamaal|gazab|ghazab' +
          '|(bohot|bahut|bht|ekdum) (badhiya|badiya|accha|acha|sahi|mast)' +
          '|bilkul sahi|sahi hai|mast hai|ekdum mast' +
          '|works? perfectly|worked perfectly|working perfectly' +
          '|exactly what i (wanted|needed|was looking for)' +
          '|that.?s exactly it' +
          '|(really|very|so|super|damn|bloody|pretty) (nice|clean|good|great|slick|neat|elegant|smart))\b'
if ($lower -match $strong) { Invoke-Praise }

# Emoji, by codepoint so this file stays ASCII. Order matches dhun-praise.sh.
$emoji = @(0x1F389, 0x1F64C, 0x1F44F, 0x1F525, 0x1F4AF,
           0x1F44C, 0x1F60D, 0x1F973, 0x2728,  0x1F680)
foreach ($cp in $emoji) {
  if ($prompt.Contains([char]::ConvertFromUtf32($cp))) { Invoke-Praise }
}

# --- 3. request shape gates the weak tier ------------------------------------
# A bare one-word lead is skipped: an instruction needs an object, so "clean up the
# imports" is a request while "clean" on its own can only be a reaction.
$request = '^(can|could|would|will|shall|please|pls|make|write|add|use|keep|try|give|show|let|do|does|is|are|was|should|need|want|i need|i want|we need|lets|let.s|now|also|next|then|clean|polish|tidy|refactor|fix|improve|update|run|build|create|check|test|implement|install|deploy|commit|push|pull|merge|revert|undo|remove|delete|move|rename|bump|sync|set|change|switch|replace|rewrite|document|explain|generate|open|close|start|stop|apply|convert|extract|split|handle|support|enable|disable|review|look|find|search|tell|help|why|what|how|where|when|which|who)([^a-z]|$)' +
           '|(please|make it|make this|needs? to be|should be|has to be|want it|want this)'
if ($words -gt 1 -and $lead -match $request) { exit 0 }
if ($prompt.TrimEnd().EndsWith("?")) { exit 0 }

# --- 4. weak tier: only as a short leading reaction --------------------------
if ($words -gt $maxWords) { exit 0 }
if ($lead.Length -gt $maxLen) { exit 0 }

$weak = '\b(perfect|great|awesome|amazing|excellent|brilliant|superb|fantastic|wonderful' +
        '|beautiful|lovely|gorgeous|elegant|slick|neat|solid|clean|nice|noice|niice|cool|sweet' +
        '|dope|epic|clutch|goated|banger' +
        '|yay|yaay|woohoo|woot|nailed' +
        '|mast|badhiya|badiya|badhia|sahi|sundar|accha|acha|bindaas' +
        '|yes+|yep|yup|yess+|w)\b'
if ($lead -match $weak) { Invoke-Praise }

exit 0
